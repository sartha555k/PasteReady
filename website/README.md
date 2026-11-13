# PasteReady website

A buildless showcase with a copyable terminal installer, native app previews, features, and setup/privacy details.

Preview from this directory:

```sh
python3 -m http.server 4173 --directory dist
```

Open `http://localhost:4173`. No dependencies or build step are required. Serve `dist/` over HTTPS for clipboard access outside localhost; manual copying remains available if permission is denied.

`DESIGN.md` and `.impeccable/design.json` describe the website. The native app’s design system remains at the repository root. Font licenses are in `dist/assets/fonts/`.

Screenshots use illustrative clipboard content, rendered from the actual SwiftUI app by `../scripts/RenderWebsiteScreenshots.swift`. They show the current development UI; the installer downloads the latest published release.

Sites identity and static directory are preserved in `.openai/hosting.json`. Source changes stay on a `feat/` or `fix/` branch until reviewed.
