const { app, BrowserWindow, session } = require('electron');
const os = require('os');
const path = require('path');

const remoteRequests = [];
const consoleErrors = [];
const loadFailures = [];

app.setPath('userData', path.join(os.tmpdir(), 'zahpy-business-pro-smoke'));

async function main() {
  await app.whenReady();

  const testSession = session.fromPartition('offline-smoke');
  await testSession.clearStorageData();
  testSession.webRequest.onBeforeRequest((details, callback) => {
    if (/^https?:\/\//i.test(details.url)) {
      remoteRequests.push(details.url);
      callback({ cancel: true });
      return;
    }

    callback({});
  });

  const window = new BrowserWindow({
    show: false,
    width: 1440,
    height: 960,
    webPreferences: {
      partition: 'offline-smoke',
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  window.webContents.on('console-message', (_event, level, message, line, sourceId) => {
    if (level >= 3) {
      consoleErrors.push({ message, line, sourceId });
    }
  });

  window.webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL) => {
    loadFailures.push({ errorCode, errorDescription, validatedURL });
  });

  await window.loadFile(path.join(__dirname, '..', 'src', 'index.html'));
  await new Promise((resolve) => setTimeout(resolve, 1500));

  const result = await window.webContents.executeJavaScript(`
    (async () => {
      await document.fonts.load('900 16px "Font Awesome 6 Free"');
      await document.fonts.load('400 16px "Font Awesome 6 Brands"');
      await document.fonts.load('400 16px "Great Vibes"');
      await document.fonts.ready;

      const main = document.getElementById('appMainContent');
      const createView = document.getElementById('createView');

      return {
        title: document.title,
        visibleMain: !!main && !main.classList.contains('hidden'),
        createViewVisible: !!createView && !createView.classList.contains('hidden'),
        bodyBackground: getComputedStyle(document.body).backgroundColor,
        fontAwesomeReady: document.fonts.check('900 16px "Font Awesome 6 Free"'),
        fontAwesomeBrandsReady: document.fonts.check('400 16px "Font Awesome 6 Brands"'),
        interReady: document.fonts.check('16px Inter'),
        greatVibesReady: document.fonts.check('400 16px "Great Vibes"'),
        libs: {
          Chart: typeof window.Chart,
          QRCode: typeof window.QRCode,
          CryptoJS: typeof window.CryptoJS,
          html2pdf: typeof window.html2pdf
        },
        stylesheets: Array.from(document.querySelectorAll('link[rel="stylesheet"]')).map((node) => node.href),
        scripts: Array.from(document.scripts).map((node) => node.src).filter(Boolean)
      };
    })()
  `);

  const featureSmoke = await window.webContents.executeJavaScript(`
    (async () => {
      const set = (id, value) => {
        const node = document.getElementById(id);
        node.value = value;
        node.dispatchEvent(new Event('input', { bubbles: true }));
        node.dispatchEvent(new Event('change', { bubbles: true }));
      };

      document.querySelector('[data-target="settingsView"]').click();
      set('managerClientName', 'Acme Test Co');
      set('managerClientEmail', 'billing@acme.test');
      set('managerClientPhone', '555-0101');
      set('managerClientTaxId', 'TAX-123');
      set('managerClientAddress', '100 Test Ave');
      document.getElementById('saveClientBtn').click();

      set('managerServiceName', 'Offline Test Service');
      set('managerServiceDescription', 'Offline readiness package');
      set('managerServicePrice', '125');
      set('managerServiceUnit', 'Hours');
      document.getElementById('saveServiceBtn').click();

      document.querySelector('[data-target="createView"]').click();
      const clientValue = Array.from(document.getElementById('clientQuickSelect').options).find(option => option.text.includes('Acme Test Co'))?.value || '';
      document.getElementById('clientQuickSelect').value = clientValue;
      document.getElementById('clientQuickSelect').dispatchEvent(new Event('change', { bubbles: true }));

      const serviceValue = Array.from(document.getElementById('serviceCatalogSelect').options).find(option => option.text.includes('Offline Test Service'))?.value || '';
      document.getElementById('serviceCatalogSelect').value = serviceValue;
      document.getElementById('addCatalogItemBtn').click();

      set('docNumber', 'INV-SMOKE-1');
      document.getElementById('saveHistoryBtn').click();

      document.querySelector('[data-target="historyView"]').click();
      const invoiceValue = document.getElementById('paymentInvoiceSelect').options[1]?.value || '';
      document.getElementById('paymentInvoiceSelect').value = invoiceValue;
      document.getElementById('paymentInvoiceSelect').dispatchEvent(new Event('change', { bubbles: true }));
      set('paymentAmountInput', '50');
      set('paymentMethodInput', 'Smoke Test');
      document.getElementById('addPaymentBtn').click();

      const workspace = JSON.parse(localStorage.getItem('zahpy_workspace_v3'));
      const invoice = workspace.historyInvoices.find(item => item.docNumber === 'INV-SMOKE-1');

      return {
        clients: workspace.clients.length,
        services: workspace.serviceCatalog.length,
        invoices: workspace.historyInvoices.length,
        invoiceStatus: invoice?.docStatus,
        payments: invoice?.payments?.length || 0,
        paidAmount: invoice?.paidAmount || 0,
        clientApplied: document.getElementById('clientName').value,
        serviceAdded: Array.from(document.querySelectorAll('.item-name')).some(input => input.value.includes('Offline readiness package'))
      };
    })()
  `);

  const darkModeSmoke = await window.webContents.executeJavaScript(`
    (async () => {
      document.getElementById('themeToggle').click();
      document.querySelector('[data-target="emailView"]').click();
      await new Promise((resolve) => setTimeout(resolve, 1000));

      const emailCard = document.querySelector('#emailView > div');
      const emailInput = document.getElementById('emailTo');

      return {
        htmlDark: document.documentElement.classList.contains('dark'),
        bodyDark: document.body.classList.contains('dark'),
        bodyClassName: document.body.className,
        htmlStyleBackground: document.documentElement.style.backgroundColor,
        htmlBackground: getComputedStyle(document.documentElement).backgroundColor,
        bodyStyleBackground: document.body.style.backgroundColor,
        bodyBackground: getComputedStyle(document.body).backgroundColor,
        emailCardBackground: getComputedStyle(emailCard).backgroundColor,
        emailInputBackground: getComputedStyle(emailInput).backgroundColor
      };
    })()
  `);

  const calculatorSmoke = await window.webContents.executeJavaScript(`
    (() => {
      const set = (id, value) => {
        const node = document.getElementById(id);
        node.value = value;
        node.dispatchEvent(new Event('input', { bubbles: true }));
        node.dispatchEvent(new Event('change', { bubbles: true }));
      };

      document.querySelector('[data-target="calcView"]').click();
      set('calcQty', '10435');
      set('calcRate', '75345');
      set('calcTax', '8345');
      set('calcDisc', '3.453453534535347e92');

      const card = document.querySelector('.calculator-result-card');
      const values = ['calcSub', 'calcTaxAmt', 'calcTotal'].map((id) => document.getElementById(id));
      const cardRect = card.getBoundingClientRect();
      const measurements = values.map((node) => {
        const rect = node.getBoundingClientRect();
        return {
          id: node.id,
          text: node.innerText,
          left: rect.left,
          right: rect.right,
          cardLeft: cardRect.left,
          cardRight: cardRect.right
        };
      });
      const styles = Object.fromEntries(values.map((node) => {
        const style = getComputedStyle(node);
        return [node.id, {
          overflowX: style.overflowX,
          textOverflow: style.textOverflow,
          whiteSpace: style.whiteSpace
        }];
      }));

      return {
        values: Object.fromEntries(values.map((node) => [node.id, node.innerText])),
        measurements,
        styles,
        withinCard: measurements.every((item) => item.left >= item.cardLeft - 1 && item.right <= item.cardRight + 1),
        overflowProtected: Object.values(styles).every((style) => style.overflowX === 'hidden' && style.textOverflow === 'ellipsis' && style.whiteSpace === 'nowrap'),
        compactTotal: document.getElementById('calcTotal').innerText === '-$3.45e92'
      };
    })()
  `);

  const datePickerSmoke = await window.webContents.executeJavaScript(`
    (() => {
      const ids = ['docDate', 'dueDate', 'sigDate', 'paymentDateInput'];
      const calls = {};
      const ready = {};
      const values = {};

      ids.forEach((id) => {
        const input = document.getElementById(id);
        if (!input) return;

        calls[id] = 0;
        ready[id] = input.dataset.datePickerReady;
        values[id] = input.value;
        input.showPicker = () => {
          calls[id] += 1;
        };

        input.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
        input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
      });

      return {
        ids,
        found: ids.filter((id) => !!document.getElementById(id)),
        ready,
        calls,
        values
      };
    })()
  `);

  const failedLibs = Object.entries(result.libs)
    .filter(([, value]) => value !== 'function' && value !== 'object')
    .map(([key]) => key);

  const failures = [
    ...(!result.visibleMain ? ['main content is not visible'] : []),
    ...(!result.createViewVisible ? ['create view is not visible'] : []),
    ...(!result.fontAwesomeReady ? ['Font Awesome did not load'] : []),
    ...(!result.fontAwesomeBrandsReady ? ['Font Awesome brands did not load'] : []),
    ...(!result.interReady ? ['Inter font did not load'] : []),
    ...(!result.greatVibesReady ? ['Great Vibes font did not load'] : []),
    ...(featureSmoke.clients < 1 ? ['client manager smoke failed'] : []),
    ...(featureSmoke.services < 1 ? ['service catalog smoke failed'] : []),
    ...(featureSmoke.invoices < 1 ? ['invoice save smoke failed'] : []),
    ...(featureSmoke.payments < 1 ? ['payment tracking smoke failed'] : []),
    ...(featureSmoke.invoiceStatus !== 'Partial Paid' ? ['payment status smoke failed'] : []),
    ...(!featureSmoke.serviceAdded ? ['service insertion smoke failed'] : []),
    ...(!darkModeSmoke.htmlDark ? ['dark mode did not apply to document root'] : []),
    ...(!darkModeSmoke.bodyDark ? ['dark mode did not apply to body'] : []),
    ...(darkModeSmoke.htmlStyleBackground !== 'rgb(15, 23, 42)' ? ['dark mode html background did not switch to slate-900'] : []),
    ...(darkModeSmoke.htmlBackground !== 'rgb(15, 23, 42)' ? ['dark mode computed html background stayed light'] : []),
    ...(darkModeSmoke.bodyStyleBackground !== 'rgb(15, 23, 42)' ? ['dark mode body background did not switch to slate-900'] : []),
    ...(darkModeSmoke.emailInputBackground === 'rgb(255, 255, 255)' ? ['email input stayed light in dark mode'] : []),
    ...(!calculatorSmoke.withinCard ? ['calculator result text overflowed its card'] : []),
    ...(!calculatorSmoke.overflowProtected ? ['calculator result overflow protection is not active'] : []),
    ...(!calculatorSmoke.compactTotal ? ['calculator high total did not use compact scientific format'] : []),
    ...(datePickerSmoke.found.length !== datePickerSmoke.ids.length ? ['date picker fields missing'] : []),
    ...datePickerSmoke.ids
      .filter((id) => datePickerSmoke.ready[id] !== 'true')
      .map((id) => `date picker not initialized: ${id}`),
    ...datePickerSmoke.ids
      .filter((id) => (datePickerSmoke.calls[id] || 0) < 2)
      .map((id) => `date picker activation failed: ${id}`),
    ...failedLibs.map((name) => `${name} library did not load`),
    ...remoteRequests.map((url) => `remote request blocked: ${url}`),
    ...loadFailures.map((failure) => `load failure ${failure.errorCode}: ${failure.validatedURL}`),
    ...consoleErrors.map((error) => `console error: ${error.message}`)
  ];

  console.log(JSON.stringify({ ...result, featureSmoke, darkModeSmoke, calculatorSmoke, datePickerSmoke, remoteRequests, loadFailures, consoleErrors }, null, 2));

  if (failures.length > 0) {
    console.error(failures.join('\n'));
  }

  await window.close();
  app.exit(failures.length > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error(error);
  app.quit();
  process.exitCode = 1;
});
