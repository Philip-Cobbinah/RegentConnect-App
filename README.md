# Regent Connect

A Flutter application for Regent University students with authentication,
direct and group messaging, status updates, calls, and an AI assistant.

## Run on Windows (web)

Flutter is installed at `C:\Users\user\development\flutter`. In a new
PowerShell window, run:

```powershell
$env:Path = 'C:\Users\user\development\flutter\bin;' + $env:Path
flutter pub get
flutter run -d chrome
```

To create a production web bundle:

```powershell
flutter build web
```

The generated site is written to `build\web`.

## Regent AI configuration

The Gemini key is read from the `GEMINI_API_KEY` compile-time environment
value. For local development:

```powershell
$env:GEMINI_API_KEY = 'your-new-key'
flutter run -d chrome --dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY
```

Do not commit an API key. A Dart define in a web build can be inspected by
users, so production AI requests should go through a server-side endpoint.

## Android setup

Android builds require Android Studio, the Android SDK, and a Firebase Android
app registered for this package. Add the generated
`android\app\google-services.json` before running on an Android emulator or
device.

## Call networking

Voice and video calls use WebRTC with Firestore signaling. The built-in STUN
servers are enough for local testing and many home or mobile networks. For
reliable production calls across restrictive networks, provide a TURN server:

```powershell
flutter run -d chrome `
  --dart-define=CALL_TURN_URL=turn:turn.example.com:3478 `
  --dart-define=CALL_TURN_USERNAME=regent-connect `
  --dart-define=CALL_TURN_CREDENTIAL=replace-me
```

Deploy `firestore.rules` before testing calls between two accounts. Web camera
and microphone access requires HTTPS, except when running on localhost.

## Quality checks

```powershell
flutter analyze
flutter test
```
