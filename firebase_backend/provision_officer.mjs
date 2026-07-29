import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const offices = [
  {
    id: "official:admissions",
    shortId: "admissions",
    name: "admissions@regent.edu.gh",
    office: "Admissions Office",
    email: "admissions@regent.edu.gh",
    description:
      "Application, admission requirements, enrolment and applicant support.",
    responseHours: "Monday–Friday, 8:00 AM–5:00 PM",
  },
  {
    id: "official:registrar",
    shortId: "registrar",
    name: "registrar@regent.edu.gh",
    office: "Registrar Office",
    email: "registrar@regent.edu.gh",
    description:
      "Registration, student records, letters, transcripts and graduation support.",
    responseHours: "Monday–Friday, 8:00 AM–5:00 PM",
  },
  {
    id: "official:academic-unit",
    shortId: "academic-unit",
    name: "academics@regent.edu.gh",
    office: "Academic Affairs",
    email: "academics@regent.edu.gh",
    description:
      "Academic programmes, course registration, timetables and academic guidance.",
    responseHours: "Monday–Friday, 8:00 AM–5:00 PM",
  },
  {
    id: "official:finance",
    shortId: "finance",
    name: "accounts@regent.edu.gh",
    office: "Finance and Accounts Office",
    email: "accounts@regent.edu.gh",
    description:
      "Fees, payment confirmation, statements and student account support.",
    responseHours: "Monday–Friday, 8:00 AM–5:00 PM",
  },
  {
    id: "official:ess-client-assurance",
    shortId: "ess-client-assurance",
    name: "ess@regent.edu.gh",
    office: "ESS / Client Assurance",
    email: "ess@regent.edu.gh",
    description:
      "Student services, client assurance, complaints and general support.",
    responseHours: "Monday–Friday, 8:00 AM–5:00 PM",
  },
  {
    id: "official:src",
    shortId: "src",
    name: "src@regent.edu.gh",
    office: "Student Parliament / SRC",
    email: "src@regent.edu.gh",
    description:
      "Student representation, welfare concerns, campus feedback and advocacy.",
    responseHours: "Mondayâ€“Friday, 8:00 AMâ€“5:00 PM",
  },
];

const args = new Map(
  process.argv.slice(2).map((argument) => {
    const [key, ...rest] = argument.replace(/^--/, "").split("=");
    return [key, rest.join("=")];
  }),
);
const requestedOffice = args.get("office") || process.env.OFFICE_ID;
if (!requestedOffice) {
  throw new Error(
    "Choose an office with --office=admissions (or set OFFICE_ID).",
  );
}

const office = offices.find(
  (entry) =>
    entry.id === requestedOffice ||
    entry.shortId === requestedOffice ||
    entry.id === `official:${requestedOffice}`,
);
if (!office) {
  throw new Error(
    `Unknown office "${requestedOffice}". Valid values: ${offices
      .map((entry) => entry.shortId)
      .join(", ")}`,
  );
}

const temporaryPassword = process.env.OFFICER_TEMP_PASSWORD;
if (temporaryPassword && temporaryPassword.length < 12) {
  throw new Error("OFFICER_TEMP_PASSWORD must contain at least 12 characters.");
}

const currentDirectory = dirname(fileURLToPath(import.meta.url));
const firebaseConfig = JSON.parse(
  await readFile(resolve(currentDirectory, "..", ".firebaserc"), "utf8"),
);
const projectId =
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  firebaseConfig.projects?.default;
if (!projectId) throw new Error("Firebase project ID could not be resolved.");

const usingEmulators =
  Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST) ||
  Boolean(process.env.FIRESTORE_EMULATOR_HOST);

initializeApp(
  usingEmulators
    ? { projectId }
    : {
        credential: applicationDefault(),
        projectId,
      },
);

const auth = getAuth();
const firestore = getFirestore();
let user;
try {
  user = await auth.getUserByEmail(office.email);
  const update = {
    displayName: office.name,
    emailVerified: true,
    disabled: false,
  };
  if (temporaryPassword) update.password = temporaryPassword;
  user = await auth.updateUser(user.uid, update);
} catch (error) {
  if (error.code !== "auth/user-not-found") throw error;
  if (!temporaryPassword) {
    throw new Error(
      "This account does not exist. Set OFFICER_TEMP_PASSWORD before the first provisioning run.",
    );
  }
  user = await auth.createUser({
    email: office.email,
    emailVerified: true,
    password: temporaryPassword,
    displayName: office.name,
    disabled: false,
  });
}

await auth.setCustomUserClaims(user.uid, {
  ...(user.customClaims || {}),
  role: "official",
  officialAccountId: office.id,
});

const timestamp = FieldValue.serverTimestamp();
const batch = firestore.batch();
batch.set(
  firestore.collection("users").doc(user.uid),
  {
    uid: user.uid,
    email: office.email,
    displayName: office.name,
    fullName: office.name,
    program: office.office,
    department: office.office,
    role: "official",
    isOfficial: true,
    officialAccountId: office.id,
    chatIdentity: office.id,
    about: office.description,
    emailVerified: true,
    isOnline: false,
    lastSeen: timestamp,
    showOnlineStatus: true,
    readReceipts: true,
    pushNotifications: true,
    updatedAt: timestamp,
  },
  { merge: true },
);
batch.set(
  firestore.collection("official_offices").doc(office.id),
  {
    ...office,
    chatIdentity: office.id,
    linkedAuthUid: user.uid,
    active: true,
    isVerified: true,
    accessMode: "firebase_auth",
    updatedAt: timestamp,
  },
  { merge: true },
);
await batch.commit();

const chats = await firestore
  .collection("chats")
  .where("participants", "array-contains", office.id)
  .get();
const writer = firestore.bulkWriter();
for (const chat of chats.docs) {
  writer.update(chat.ref, {
    participantAuthIds: FieldValue.arrayUnion(user.uid),
    updatedAt: FieldValue.serverTimestamp(),
  });
}
await writer.close();

console.log(`Provisioned ${office.name} in Firebase project ${projectId}.`);
console.log(`Officer sign-in email: ${office.email}`);
console.log(
  "The officer can now sign in through Regent staff / officer access. Share the temporary password privately and require a password reset.",
);
