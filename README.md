# Zahpy Business Pro

Zahpy Business Pro is a Windows desktop invoicing app packaged with Electron. It helps small businesses create invoices and estimates, manage saved clients, reuse product or service catalog items, track payments, and export finished documents as PDFs.

## Editions

Zahpy Business Pro now has three Windows delivery options:

- Standalone edition: a zip file that runs from an extracted folder and keeps the core app fully local/offline.
- One-file standalone edition: a single portable `.exe` that extracts the app to a temporary cache and launches without creating shortcuts or installer registry entries.
- Installer edition: a Windows setup app that shows install details and terms before installation, installs to the current user's local Programs folder, creates shortcuts, and can check GitHub Releases for newer versions.

## For Users

- Download the Windows zip, extract it, and double-click `Zahpy Business Pro.exe` from the extracted folder.
- The core app runs locally on the device and does not require internet for invoice creation, saved history, client records, catalog records, payment tracking, PDF export, or dashboard totals.
- Email buttons, PayPal links, Stripe links, update checks, GitHub downloads, and any other external services require internet access.
- App data is stored locally on the device. Use the History tab's Backup button regularly so invoices, clients, catalog items, payments, and settings can be restored later.
- Windows may show a SmartScreen warning because this build is not code-signed yet.

Standalone download link for your product/download page:

```html
<a href="https://github.com/AdejojuA/Zaphyproproject/releases/latest/download/ZahpyBusinessPro-Windows.zip">
  Download Zahpy Business Pro Standalone
</a>
```

Clear standalone filename:

```html
<a href="https://github.com/AdejojuA/Zaphyproproject/releases/latest/download/ZahpyBusinessPro-Standalone.zip">
  Download Zahpy Business Pro Standalone
</a>
```

Installer download link for your product/download page:

```html
<a href="https://github.com/AdejojuA/Zaphyproproject/releases/latest/download/ZahpyBusinessPro-Setup.exe">
  Download Zahpy Business Pro Installer
</a>
```

One-file standalone download link:

```html
<a href="https://github.com/AdejojuA/Zaphyproproject/releases/latest/download/ZahpyBusinessPro-Standalone.exe">
  Download Zahpy Business Pro One-File Standalone
</a>
```

## Features

- Create invoices and estimates
- Save editable invoice history locally
- Manage saved clients and quickly apply them to invoices
- Maintain a product and service catalog for reusable line items
- Record invoice payments and view paid, partial, and outstanding balances
- Save business, tax, currency, payment link, and default due-date settings
- Export invoices as PDF
- Generate email message templates
- View dashboard totals and payment status summaries
- Protect the local workspace with an optional PIN lock
- Check GitHub Releases for updates from the desktop app
- Run with bundled styles, fonts, icons, and browser libraries

## Important Notes

Zahpy Business Pro is a business document tool, not legal, tax, accounting, or financial advice. Users are responsible for verifying invoice totals, tax rates, payment terms, business details, and recordkeeping requirements before sending documents to clients.

The optional PIN lock protects the local app workspace, but forgotten PINs cannot be recovered. Keep separate backups of important business records.

Both Windows editions are desktop apps. The standalone edition runs from an extracted folder, while the installer edition copies the app to the current user's local Programs folder, creates shortcuts, registers an uninstall entry, and can check GitHub Releases for newer versions. In both editions, core workspace records are stored locally for the Windows user profile unless the user chooses to open an external service or download link.

## Developer Requirements

- Node.js
- npm

## Development

Install dependencies:

```bash
npm install
```

Run the desktop app:

```bash
npm start
```

Run the offline smoke test:

```bash
npm run smoke:offline
```

## Build

Create the standalone folder zip:

```bash
npm run dist:standalone
```

Create the installer build:

```bash
npm run dist:installer
```

Create the one-file standalone executable:

```bash
npm run dist:portable
```

The build output is configured to write to:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs
```

The downloadable package is:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro-Windows.zip
```

The same standalone zip is also copied to a clearer filename:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro-Standalone.zip
```

The installer package is:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro-Setup.exe
```

The one-file standalone executable is:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro-Standalone.exe
```

The desktop source HTML copy is also written beside the release files. For moving it to another device, use the all-in-one HTML file or the HTML bundle zip.

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro_html.html
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\vendor
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro_all_in_one.html
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro-HTML-Bundle.zip
```

For online update checks to work from the installed app, publish a GitHub Release and upload the installer asset. If electron-builder generates update metadata such as `latest.yml` or `.blockmap` files, upload those assets to the same release too.
