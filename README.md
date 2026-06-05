# Zahpy Business Pro

Zahpy Business Pro is a Windows desktop invoicing app packaged with Electron. It helps small businesses create invoices and estimates, manage saved clients, reuse product or service catalog items, track payments, and export finished documents as PDFs.

## Editions

Zahpy Business Pro now has two Windows delivery options:

- Standalone edition: a zip file that runs from an extracted folder and keeps the core app fully local/offline.
- Installer edition: a Windows setup app that shows install details and terms before installation, installs to the current user's local Programs folder, creates shortcuts, and can check GitHub Releases for newer versions.

## For Users

- Download the Windows zip, extract it, and double-click `Zahpy Business Pro.exe` from the extracted folder.
- The core app runs locally on the device and does not require internet for invoice creation, saved history, client records, catalog records, payment tracking, PDF export, or dashboard totals.
- Email buttons, PayPal links, Stripe links, update checks, GitHub downloads, and any other external services require internet access.
- App data is stored locally on the device. Use the History tab's Backup button regularly so invoices, clients, catalog items, payments, and settings can be restored later.
- Windows may show a SmartScreen warning because this build is not code-signed yet.

Standalone website download link:

```html
<a href="https://github.com/AdejojuA/Zaphyproproject/releases/latest/download/ZahpyBusinessPro-Windows.zip">
  Download Zahpy Business Pro Standalone
</a>
```

Installer website download link:

```html
<a href="https://github.com/AdejojuA/Zaphyproproject/releases/latest/download/ZahpyBusinessPro-Setup.exe">
  Download Zahpy Business Pro Installer
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

The build output is configured to write to:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs
```

The downloadable package is:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro-Windows.zip
```

The installer package is:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro-Setup.exe
```

For online update checks to work from the installed app, publish a GitHub Release and upload the installer asset. If electron-builder generates update metadata such as `latest.yml` or `.blockmap` files, upload those assets to the same release too.
