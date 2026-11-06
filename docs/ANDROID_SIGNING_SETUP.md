# NIARIM Android signing setup (development + Google Play)

This is a **normal development** setup guide. Private keystores and passwords must
**never** be pushed to the repository or attached to publicly accessible GitHub Releases.

## Fixed keys and Android OAuth SHA-1

Package name: `com.niarim.niarim`.

| Build / certificate | SHA-1 |
|---|---|
| GitHub Actions debug | `5B:AA:90:49:23:7A:54:A8:81:6F:52:DA:D6:6C:09:ED:2C:C4:F4:57` |
| Google Play upload key | `FF:D0:6D:05:5B:11:78:32:5C:44:14:09:EB:96:CB:CA:C3:F7:ED:3D` |
| **Google Play app-signing key** | **Get this distinct certificate from Play Console after enrolling in Play App Signing.** |

The debug and upload keys are RSA 3072-bit and valid until 2054-03-17.
The two SHA-1 strings above are **public certificate fingerprints**, not secret
credentials. Their corresponding private keystores are intentionally absent from git.

Create a Google Cloud Android OAuth client for the **CI debug SHA-1** to
authenticate APKs created by the debug workflow. When publishing to Google
Play, create **another** Android OAuth client using the **Play app-signing
certificate SHA-1** found in Play Console. The upload certificate SHA-1
alone does not authenticate the APK actually delivered by Google Play.

## One-time GitHub Actions Secrets setup

The repo administrator must configure these four secrets in
`Settings → Secrets and variables → Actions → New repository secret`:

| Secret name | Value |
|---|---|
| `NIARIM_DEBUG_KEYSTORE_BASE64` | Base64 of the persistent `niarim-ci-debug.jks`, without line breaks |
| `NIARIM_DEBUG_STORE_PASSWORD` | Password for the debug keystore (also used for its key) |
| `NIARIM_UPLOAD_KEYSTORE_BASE64` | Base64 of `niarim-upload.jks`, without line breaks |
| `NIARIM_UPLOAD_STORE_PASSWORD` | Password for the upload keystore (also used for its key) |

These secrets are **not stored in the source tree**. Keep the original keystore
files and passwords in secure, independent backups accessible to the owner.
Repository Secrets cannot be read back as plaintext after they are created.
If migrating to new runners, keep and restore these same keys.

The `.github/workflows/build-apk.yml` workflow restores the correct keystore
to `RUNNER_TEMP` and fails if the relevant secrets are missing. It does
**not** silently fall back to GitHub's temporary debug key. The
`android/app/build.gradle.kts` build selects the keystore from environment
variables, keeping the debug and upload identities separate.

### Local build / CI environment variables

For debug APKs:

- `NIARIM_DEBUG_KEYSTORE_PATH`: absolute path to `niarim-ci-debug.jks`
- `NIARIM_DEBUG_STORE_PASSWORD`: its password
- key alias: `niarim_ci_debug`

For release APKs or app bundles:

- `NIARIM_UPLOAD_KEYSTORE_PATH`: absolute path to `niarim-upload.jks`
- `NIARIM_UPLOAD_STORE_PASSWORD`: its password
- key alias: `niarim_upload`

Do not set the release variables to the debug keystore.

To check the public SHA-1 **without printing passwords**:

```bash
keytool -list -v -keystore /path/to/niarim-ci-debug.jks -alias niarim_ci_debug
keytool -list -v -keystore /path/to/niarim-upload.jks -alias niarim_upload
```

The `keytool` command will prompt for the respective password.

## Important operational notes

- `flutter build apk --release` requires the persistent upload key. The
  old `release` → `debug` signing fallback has been removed.
- You can develop with a local default debug key, but its SHA-1 will **not**
  equal the CI debug SHA-1; Google OAuth needs the SHA-1 of the **actual
  installed APK**. Use the persistent CI debug key for GitHub workflow builds.
- **Play App Signing:** Google Play uses its **own app-signing certificate**
  when distributing the installed app; register **that** SHA-1 for production
  Google Sign-In. Upload SHA-1 is used for local installation of upload-signed
  APKs, not Play-distributed versions.
- Do not replace the CI debug key casually: it will change the OAuth SHA-1
  and prevent updates to installed CI-debug builds until the old APK is
  uninstalled or the key identity is restored.
- The upload key is replaceable by the Play Console reset process if
  compromised; do **not** assume this means other app-signing keys can be
  replaced freely.
- Workflow configuration and checks can be reviewed without running
  GitHub Actions; final confirmation needs a real signed APK, then
  `keytool -printcert -jarfile app-debug.apk` (or `apksigner verify --print-certs`).
