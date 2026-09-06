# Windows port

The native application is SwiftUI/macOS-only. This repository now includes a
self-contained Windows-compatible dashboard in `windows-web/`. The packaged
Windows deliverable is a standalone `.exe` with an embedded Node.js runtime;
end users do not need to install Node.js.

## Run locally

1. Download `AIUsage-Windows.zip` from the GitHub Actions artifact.
2. Extract the ZIP. It contains `AIUsage.exe` and this documentation.
3. Double-click `AIUsage.exe`. The local dashboard opens automatically at
   `http://127.0.0.1:4173`.

For development without the packaged executable, install [Node.js](https://nodejs.org/)
18 or newer and double-click `windows-web/start-aiusage.cmd`.

The Windows dashboard provides a useful local baseline: provider tracking,
monthly spend and token summaries, sample data, and JSON import/export. Data
is stored in browser local storage. It deliberately does not handle provider
credentials or claim feature parity with the macOS app.

## Build the Windows executable

From PowerShell or a Windows terminal:

```powershell
cd windows-web
npm install
npm run build:windows
```

The `Windows Port` GitHub Actions workflow runs the checks, builds
`dist/AIUsage-Windows.exe`, renames the packaged binary to `AIUsage.exe`,
and uploads `AIUsage-Windows.zip` containing that executable. A separate
artifact contains the standalone executable as well.

The executable is a local dashboard rather than native feature parity with the
macOS app: provider credentials, proxy management, menu-bar controls, and
macOS Keychain integrations are not included.
