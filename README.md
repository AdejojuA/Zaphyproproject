# Zahpy Business Pro

Zahpy Business Pro is a desktop invoicing app packaged with Electron for Windows.

## Features

- Create invoices and estimates
- Track saved invoice history locally
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

## Notes

The core app now runs offline because Tailwind, Font Awesome, fonts, Chart.js, html2pdf, qrcodejs, and crypto-js are bundled locally. External services such as Gmail, Outlook, Yahoo Mail, PayPal, and Stripe still require internet access when opened.
