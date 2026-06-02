# Zahpy Business Pro

Zahpy Business Pro is a desktop invoicing app packaged with Electron for Windows.

## Features

- Create invoices and estimates
- Track saved invoice history locally
- Manage saved clients and quickly apply them to invoices
- Maintain a product and service catalog for reusable line items
- Record invoice payments and view paid, partial, and outstanding balances
- Save tax, business, currency, payment link, and default due-date settings
- Export invoices as PDF
- Generate email message templates
- Dashboard charting and payment-link helpers
- PIN-based local data protection
- Offline bundled styles, fonts, icons, and browser libraries

## Requirements

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

## Build

Create a portable Windows executable:

```bash
npm run dist
```

The build output is configured to write to the parent workspace `outputs` folder.

Current package files are written to:

```text
C:\Users\akere\Documents\Codex\2026-05-30\files-mentioned-by-the-user-zahpybusinesspro\outputs
```

## Notes

The core app now runs offline because Tailwind, Font Awesome, fonts, Chart.js, html2pdf, qrcodejs, and crypto-js are bundled locally. External services such as Gmail, Outlook, Yahoo Mail, PayPal, and Stripe still require internet access when opened.
