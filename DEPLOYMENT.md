# Mobile distribution

Development pushes run analysis/tests and publish an ARM64 debug APK as a GitHub Actions artifact. Set Development environment secret API_BASE_URL to the public HTTPS backend URL ending /api/v1. No VPS SSH secrets are needed for mobile. This workflow distributes a demo APK, not a Play Store release or automatic installation on users' phones. Release signing and store distribution require a separate keystore/configuration; never commit the keystore or signing passwords.
