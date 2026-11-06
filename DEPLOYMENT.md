# Mobile distribution

Development pushes run analysis/tests and publish an ARM64 debug APK as a GitHub Actions artifact. Set Development environment secret API_BASE_URL to the public HTTPS backend URL ending /api/v1. No VPS SSH secrets are needed for mobile. This workflow distributes a demo APK, not a Play Store release or automatic installation on users' phones. Release signing and store distribution require a separate keystore/configuration; never commit the keystore or signing passwords.

For the online backend, use `https://api-bilcode-test.geats.web.id/api/v1`. The checked-in `config/production.json` contains this public URL. ML remains behind the backend; the APK needs no ML credentials.

Local release builds use `flutter build apk --release --dart-define-from-file=config/production.json`. Gradle loads the release signing identity from the ignored `android/key.properties`, which references the ignored `android/app/siklus-release.jks` generated on this workstation. Back up both files privately and keep this signing identity for later updates. The output is `build/app/outputs/flutter-apk/app-release.apk`.

The older debug APK uses a different signing identity. Android requires uninstalling that debug installation before installing this release APK; this removes local settings and sessions, but does not delete server reports.
