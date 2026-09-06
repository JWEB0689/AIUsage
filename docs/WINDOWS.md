# Windows port

The native application is SwiftUI/macOS-only. This repository now includes a
self-contained Windows-compatible dashboard in `windows-web/`. It runs on
Windows, macOS, and Linux with Node.js 18 or newer and does not require
third-party packages.

## Run locally

1. Install [Node.js](https://nodejs.org/) 18 or newer.
2. Double-click `windows-web/start-aiusage.cmd`.
3. The dashboard opens at `http://127.0.0.1:4173`.

The Windows dashboard provides a useful local baseline: provider tracking,
monthly spend and token summaries, sample data, and JSON import/export. Data
is stored in browser local storage. It deliberately does not handle provider
credentials or claim feature parity with the macOS app.

## Build the Windows artifact

From PowerShell:

```powershell
node --check windows-web/server.mjs
node --check windows-web/public/app.js
Compress-Archive -Path windows-web -DestinationPath AIUsage-Windows.zip -Force
```

The `Windows Port` GitHub Actions workflow runs the checks and publishes the
zip as a build artifact. A future native Windows client can replace the
dashboard while keeping this launcher and packaging contract.
