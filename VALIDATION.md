# Validation

- Flutter analyze: no issues.
- 12 automated tests pass: concurrent refresh, token rotation failure, network recovery, replayable multipart, public auth headers, logout/refresh race, light/dark narrow login, large-text auth screens, large-text dashboard. The live contract test is skipped by default.
- Live contract test separately passes against NestJS/PostgreSQL/R2/ML: login, me, upload, CLOTHES prediction, protected photo, filter, edit, statistics, refresh rotation/replay rejection, status history, processed-report edit rejection, soft deletion and logout.
- Debug APK builds for ARM64 and x64.
- Physical Xiaomi Android 16: installation succeeds with adb install --no-streaming; login UI inspected in dark theme. The user retains control of the phone for their own login.
- Emulator Android 15: login with a temporary verified account, dashboard, list, protected image, detail/prediction and new-report form visually inspected. Map tiles load. Temporary users, reports and R2 photos removed; audit retained. Emulator stopped.
- Camera capture, GPS precision and real email delivery remain device/user checks; they are implemented but not claimed as automatically exercised.

Design delivery gate: existing approved Siklus identity preserved, purpose of each visual element documented in DESIGN.md, no invented dashboard metrics, light/dark themes and large text tested, visible native controls and labels, no decorative motion or fabricated imagery. Launcher glyph reuses the existing Lucide Route symbol and retains its license.
