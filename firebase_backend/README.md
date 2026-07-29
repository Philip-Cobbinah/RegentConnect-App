# Regent Connect Firebase administration

This folder contains the trusted administrator-side account provisioning tool.
It must be run by a university administrator from a secure computer. Never put
a service-account key or an officer password in source control.

## One-time setup

1. Install a current Node.js LTS release.
2. Run `npm install` in this folder.
3. Authenticate with Application Default Credentials:
   `gcloud auth application-default login`, or set
   `GOOGLE_APPLICATION_CREDENTIALS` to a protected service-account JSON file.
4. Deploy the Firebase rules and indexes from the repository root:
   `firebase deploy --only firestore:rules,firestore:indexes,storage`

## Provision or repair an office account

PowerShell example:

```powershell
$env:OFFICER_TEMP_PASSWORD = '<a unique temporary password>'
npm run provision:officer -- --office=admissions
Remove-Item Env:OFFICER_TEMP_PASSWORD
```

Valid office values are `admissions`, `registrar`, `academic-unit`, `finance`,
`ess-client-assurance`, and `src`.

The tool creates or updates the Firebase Authentication user, verifies the
email, adds the restricted `official` custom claims, creates the Firestore
profile and office record, and connects the officer UID to existing office
conversations. It never prints the temporary password.

Officers then use the normal app sign-in page, open **Regent staff / officer
access**, select their office email, and enter the password supplied privately.
Their Chats page becomes the verified office inbox.

## Status retention

Statuses already contain an `expiresAt` timestamp and queries hide expired
entries. For automatic physical cleanup, enable Firestore TTL for the
`statuses` collection group on the `expiresAt` field:

```powershell
gcloud firestore fields ttls update expiresAt `
  --collection-group=statuses `
  --enable-ttl `
  --project=regent-connect-85439
```
