# Regent Connect Admin Architecture

## Trust boundaries

- Firebase Authentication identifies the caller.
- The Firebase Auth custom claim `role: admin` is the only source of administrator authority.
- Firestore and Storage security rules are the backend authorization middleware. A hidden Flutter button is not security.
- Admin data lives in `admin_announcements` and `admin_audit_logs`; it is not stored in `/users`.

## Client structure

Admin UI and services are isolated under `lib/features/admin/`:

- `screens/admin_gate.dart` refreshes the ID token and blocks non-admin users.
- `screens/admin_dashboard_screen.dart` contains admin-only workflows.
- `services/admin_service.dart` validates the claim, sanitizes input, and writes audit records.

The guarded route is `/admin`.

## Provisioning an administrator

Do not edit `users.role` to grant access. From `firebase_backend/`, authenticate the Firebase Admin SDK with a protected service-account environment and run:

```powershell
$env:ADMIN_EMAIL = 'existing-admin@regent.edu.gh'
pnpm provision:admin
```

The administrator must sign out and sign in again so Firebase issues a token containing the new claim. Keep service-account credentials and `ADMIN_EMAIL` provisioning access out of the client and Git repository.

## Rate limiting and abuse controls

The client includes a small duplicate-submit guard. For production-scale rate limiting, put high-volume admin actions behind callable Cloud Functions/API endpoints with App Check, server-side quotas, and structured audit logging. Firestore rules remain mandatory even when callable functions are added.
