import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const firebaseConfig = JSON.parse(
  await readFile(resolve(process.cwd(), '..', '.firebaserc'), 'utf8'),
);
const projectId =
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  firebaseConfig.projects?.default;
const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();

if (!projectId) throw new Error('Firebase project ID could not be resolved.');
if (!email) throw new Error('Set ADMIN_EMAIL to an existing Firebase Auth email.');

initializeApp({
  credential: applicationDefault(),
  projectId,
});

const auth = getAuth();
const user = await auth.getUserByEmail(email);
await auth.setCustomUserClaims(user.uid, {
  ...(user.customClaims || {}),
  role: 'admin',
});

console.log(`Granted admin claim to ${email}.`);
console.log('The account must sign out and sign in again before the new claim is used.');
