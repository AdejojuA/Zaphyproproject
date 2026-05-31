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
    ...failedLibs.map((name) => `${name} library did not load`),
    ...remoteRequests.map((url) => `remote request blocked: ${url}`),
    ...loadFailures.map((failure) => `load failure ${failure.errorCode}: ${failure.validatedURL}`),
    ...consoleErrors.map((error) => `console error: ${error.message}`)
  ];

  console.log(JSON.stringify({ ...result, remoteRequests, loadFailures, consoleErrors }, null, 2));

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
