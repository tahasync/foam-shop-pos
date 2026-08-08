# Setup

## Firebase Configuration

Firebase API keys are supplied via `--dart-define-from-file` at build time, not hardcoded.

### First-time setup

1. Copy the example config:
   ```
   cp env/firebase_config.example.json env/firebase_config.json
   ```

2. Fill in the real values from your Firebase project console or from a local `google-services.json` / `GoogleService-Info.plist`.

3. Run the app:
   ```
   flutter run --dart-define-from-file=env/firebase_config.json
   ```

   Build a release APK:
   ```
   flutter build apk --release --dart-define-from-file=env/firebase_config.json
   ```

### ⚠️ Security note

`env/firebase_config.json` is gitignored. Never commit it. The template at
`env/firebase_config.example.json` contains placeholder values only.

If you regenerate Firebase config, update `env/firebase_config.json` locally
and the example file's structure if keys change.
