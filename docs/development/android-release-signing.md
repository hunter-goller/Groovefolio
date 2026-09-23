# Android upload signing

The Android application ID is `app.groovefolio`. A release APK or app bundle must
be signed with the developer's upload key. Debug builds need no upload key. CI
generates a different, disposable key for its release compilation check; never
upload a CI build to Google Play.

## Create and keep the upload key (Windows PowerShell)

Do this on your own computer, not in CI or a shared workspace. Install Android
Studio and a JDK so `keytool` is available. Choose a private path outside the
repository and run:

```powershell
keytool -genkeypair -v -keystore "$env:USERPROFILE\groovefolio-upload.jks" -alias groovefolio-upload -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=Groovefolio Upload"
```

Enter a strong keystore password when prompted. If prompted for a separate key
password, record it too; pressing Enter reuses the keystore password. Keep a
backup of the `.jks` file away from the computer and record both passwords and
the alias in a password manager. Do not commit the key or passwords, paste them
into issues/chat, or store them in GitHub Actions. The repository ignores JKS
files, but keep the actual key outside the checkout regardless.

In the **same PowerShell session** as the build, set the signing variables:

```powershell
$env:GROOVEFOLIO_UPLOAD_KEYSTORE = "$env:USERPROFILE\groovefolio-upload.jks"
$env:GROOVEFOLIO_UPLOAD_KEY_ALIAS = "groovefolio-upload"
$env:GROOVEFOLIO_UPLOAD_STORE_PASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Keystore password' -AsSecureString)).Password
$env:GROOVEFOLIO_UPLOAD_KEY_PASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Key password' -AsSecureString)).Password
flutter build appbundle --release
```

If you reused the keystore password for the key, enter it twice. Build from the
repository root. The signed bundle is under `build/app/outputs/bundle/release/`.
Gradle stops with a clear error if a signing variable or keystore is missing.
An incorrect alias/password also fails the build. Never publish a build signed
with a debug or disposable CI key.

For Google Play, enroll the app in Play App Signing and keep this key as the
**upload key**; Google signs the APKs delivered to users with the separate app
signing key. Verify the chosen upload certificate in Play Console before the
first upload. Back up the upload key even though Play provides a reset process.

The signing setup does not mean the app is ready for public release. Complete
the Discogs credential strategy, policy/Data Safety review, store listing and
device testing before distribution.

References: [Flutter Android release guide](https://docs.flutter.dev/deployment/android),
[Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).
