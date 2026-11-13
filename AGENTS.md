# PasteReady project workflow

- Create a dedicated `feat/<short-description>` branch for new features and visual improvements.
- Use `fix/<short-description>` for bug fixes.
- Do not implement changes directly on `main`.
- Push work branches for review; do not merge into `main` or publish a stable release until the user approves the work.
- Keep clipboard history, pins, preferences, and the app's bundle identity intact when installing local test builds.
- Keep update notifications deferred unless the user explicitly resumes that feature.
