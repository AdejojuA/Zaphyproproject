const { app, BrowserWindow, Menu, shell, ipcMain } = require('electron');
const https = require('https');
const path = require('path');
const { pathToFileURL } = require('url');

const isDev = !app.isPackaged;
const releasePageUrl = 'https://github.com/AdejojuA/Zaphyproproject/releases/latest';
const latestReleaseApiUrl = 'https://api.github.com/repos/AdejojuA/Zaphyproproject/releases/latest';
const installerDownloadUrl = 'https://github.com/AdejojuA/Zaphyproproject/releases/latest/download/ZahpyBusinessPro-Setup.exe';

let mainWindow = null;

function normalizeVersion(version) {
  return String(version || '0.0.0').replace(/^v/i, '').split('-')[0];
}

function compareVersions(currentVersion, latestVersion) {
  const current = normalizeVersion(currentVersion).split('.').map((part) => parseInt(part, 10) || 0);
  const latest = normalizeVersion(latestVersion).split('.').map((part) => parseInt(part, 10) || 0);
  const length = Math.max(current.length, latest.length);

  for (let index = 0; index < length; index += 1) {
    const currentPart = current[index] || 0;
    const latestPart = latest[index] || 0;
    if (latestPart > currentPart) return 1;
    if (latestPart < currentPart) return -1;
  }

  return 0;
}

function requestJson(url) {
  return new Promise((resolve, reject) => {
    const request = https.get(url, {
      headers: {
        Accept: 'application/vnd.github+json',
        'User-Agent': `Zahpy-Business-Pro/${app.getVersion()}`
      },
      timeout: 15000
    }, (response) => {
      let body = '';

      response.on('data', (chunk) => {
        body += chunk;
      });

      response.on('end', () => {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          reject(new Error(`GitHub returned ${response.statusCode}`));
          return;
        }

        try {
          resolve(JSON.parse(body));
        } catch (error) {
          reject(new Error('GitHub response could not be read.'));
        }
      });
    });

    request.on('timeout', () => {
      request.destroy(new Error('Update check timed out.'));
    });

    request.on('error', reject);
  });
}

function getEditionName() {
  if (isDev) return 'Development';
  if (process.env.PORTABLE_EXECUTABLE_FILE) return 'Portable';
  return 'Desktop';
}

function getInstallerAsset(release) {
  return (release.assets || []).find((asset) => /ZahpyBusinessPro-Setup.*\.exe$/i.test(asset.name))
    || (release.assets || []).find((asset) => /\.exe$/i.test(asset.name));
}

function isAllowedExternalUrl(url) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' && (
      parsed.hostname === 'github.com'
      || parsed.hostname === 'objects.githubusercontent.com'
      || parsed.hostname.endsWith('.githubusercontent.com')
    );
  } catch {
    return false;
  }
}

async function checkForUpdates() {
  const release = await requestJson(latestReleaseApiUrl);
  const latestVersion = normalizeVersion(release.tag_name);
  const currentVersion = app.getVersion();
  const asset = getInstallerAsset(release);

  return {
    currentVersion,
    latestVersion,
    releaseName: release.name || release.tag_name || 'Latest release',
    releaseUrl: release.html_url || releasePageUrl,
    updateAvailable: compareVersions(currentVersion, latestVersion) > 0,
    installerAssetName: asset?.name || 'ZahpyBusinessPro-Setup.exe',
    installerDownloadUrl: asset?.browser_download_url || installerDownloadUrl
  };
}

function registerDesktopIpc() {
  ipcMain.handle('zahpy:get-runtime-info', () => ({
    edition: getEditionName(),
    version: app.getVersion(),
    isPackaged: app.isPackaged,
    releasePageUrl,
    installerDownloadUrl
  }));

  ipcMain.handle('zahpy:check-for-updates', async () => checkForUpdates());

  ipcMain.handle('zahpy:open-releases', async () => {
    await shell.openExternal(releasePageUrl);
    return true;
  });

  ipcMain.handle('zahpy:open-download', async (_event, url) => {
    const targetUrl = url || installerDownloadUrl;
    if (!isAllowedExternalUrl(targetUrl)) {
      throw new Error('Download link is not allowed.');
    }

    await shell.openExternal(targetUrl);
    return true;
  });
}

function createMainWindow() {
  const indexPath = path.join(__dirname, 'index.html');
  const indexUrl = pathToFileURL(indexPath).href;

  mainWindow = new BrowserWindow({
    width: 1440,
    height: 960,
    minWidth: 1100,
    minHeight: 720,
    title: 'Zahpy Business Pro',
    backgroundColor: '#e2e8f0',
    show: false,
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true
    }
  });

  mainWindow.once('ready-to-show', () => {
    mainWindow.maximize();
    mainWindow.show();
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (url !== indexUrl) {
      event.preventDefault();
      shell.openExternal(url);
    }
  });

  if (!isDev) {
    mainWindow.webContents.on('devtools-opened', () => {
      mainWindow.webContents.closeDevTools();
    });
  }

  mainWindow.loadFile(indexPath);
}

app.whenReady().then(() => {
  Menu.setApplicationMenu(null);
  registerDesktopIpc();
  createMainWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
