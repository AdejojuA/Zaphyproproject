# Zahpy Business Pro

Zahpy Business Pro is a Windows desktop invoicing app packaged with Electron. It helps small businesses create invoices and estimates, manage saved clients, reuse product or service catalog items, track payments, and export finished documents as PDFs.

## For Users

- Download the Windows zip, extract it, and double-click `Zahpy Business Pro.exe` from the extracted folder.
- The core app runs locally on the device and does not require internet for invoice creation, saved history, client records, catalog records, payment tracking, PDF export, or dashboard totals.
- Email buttons, PayPal links, Stripe links, GitHub downloads, and any other external services require internet access.
- App data is stored locally on the device. Use the History tab's Backup button regularly so invoices, clients, catalog items, payments, and settings can be restored later.
- Windows may show a SmartScreen warning because this build is not code-signed yet.

Website download link:

```html
<a href="https://github.com/AdejojuA/Zaphyproproject/releases/latest/download/ZahpyBusinessPro-Windows.zip">
  Download Zahpy Business Pro
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

Create a portable Windows executable:

```bash
npm run dist
```

The build output is configured to write to:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs
```

The downloadable package is:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs\ZahpyBusinessPro-Windows.zip
```
