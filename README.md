# Zahpy Business Pro

Zahpy Business Pro is a desktop invoicing app packaged with Electron for Windows.

## Features

- Create invoices and estimates
- Track saved invoice history locally
- Export invoices as PDF
- Generate email message templates
- Dashboard charting and payment-link helpers
- PIN-based local data protection

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

This app currently loads several frontend libraries from CDNs, including Tailwind, Font Awesome, Chart.js, html2pdf, qrcodejs, and crypto-js. Internet access may be required for those pieces unless the assets are bundled locally.
