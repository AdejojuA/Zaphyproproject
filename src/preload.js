const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('zahpyDesktop', {
  getRuntimeInfo: () => ipcRenderer.invoke('zahpy:get-runtime-info'),
  checkForUpdates: () => ipcRenderer.invoke('zahpy:check-for-updates'),
  openReleases: () => ipcRenderer.invoke('zahpy:open-releases'),
  openDownload: (url) => ipcRenderer.invoke('zahpy:open-download', url)
});
