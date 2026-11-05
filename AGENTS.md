# Flutter implementation

- Read DESIGN.md for the approved Siklus visual identity and the antislop skills before interface changes.
- Keep API/auth/storage in core, domain screens in features, shared visual widgets in ui. Prefer typed models and state scoped to each screen.
- API base URL is provided by --dart-define=API_BASE_URL; never ship development secrets or account credentials. Android development over USB uses http://127.0.0.1:3001/api/v1 after adb reverse.
- Persist JWT pairs together in secure storage; refresh once for concurrent requests, retry at most once, and clear invalid sessions. Never log tokens, user data, photo bytes, or GPS.
- Camera and GPS require explicit user actions. Handle denied permission and unavailable services. Do not submit invented/default coordinates; require a chosen map point or GPS fix.
- Match real backend enums and status permissions. Never invent dashboard numbers or ML accuracy. Keep OSM attribution visible.
- Use Material semantics, minimum 48dp tap targets, SafeArea, scrolling forms, labeled inputs, and accessible light/dark themes. Respect system motion settings.
- Run dart format, flutter analyze, meaningful auth/network and layout tests, and an Android build. Check the UI on the connected test phone; remove only temporary test accounts/data.
