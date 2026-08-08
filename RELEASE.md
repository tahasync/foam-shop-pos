# Release Process

## Prerequisites

- A `release.keystore` file at the repo root (see Setup below)
- `env/firebase_config.json` with valid Firebase config (see `env/firebase_config.example.json`)
- All environment variables exported for signing

## Quick Start (one command)

Run the release script from the repo root — it handles clean, deps, analyze, tests, and build in sequence. Any failure stops the process before the build.

### PowerShell (Windows)
```
$env:KEYSTORE_PASSWORD = "your-password"
.\scripts\release_build.ps1
```

### Bash (Linux / macOS / WSL)
```
KEYSTORE_PASSWORD="your-password" ./scripts/release_build.sh
```

> **Important:** This is the ONLY supported way to produce a release APK. Running `flutter build apk --release` directly without the script skips the pre-flight checks and is not safe.

## Keystore Setup

If no `release.keystore` exists, generate one:

```
keytool -genkey -v -keystore release.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Set the required environment variables:

| Variable | Value |
|----------|-------|
| `KEYSTORE_PATH` | Path to `release.keystore` (auto-detected if at repo root) |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias (default: `upload`) |
| `KEY_PASSWORD` | Key password (defaults to KEYSTORE_PASSWORD if not set) |

> **⚠️ CRITICAL:** Back up the keystore file and its password securely. Losing them means all future updates will require users to uninstall and reinstall, losing their local data. The keystore is excluded from git by `.gitignore`.

## Tagging a Release

1. Update `CHANGELOG.md` with the new version's user-facing notes
2. Bump version in `pubspec.yaml`
3. Create an annotated local tag:
   ```
   git tag -a vX.Y.Z -m "vX.Y.Z — description"
   ```
4. Push the tag (CI builds and publishes the release):
   ```
   git push origin vX.Y.Z
   ```

## CI/CD

The GitHub Actions workflow (`.github/workflows/build.yml`) runs on every push to `main` and on `v*` tags. It runs:
1. Flutter analyze
2. Flutter test (all tests, **blocks build on failure**)
3. Release APK build (signed with CI keystore from secrets)
4. APK artifact upload
5. GitHub Release with changelog from `CHANGELOG.md`
