const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '..');
const sourceHtml = path.join(projectRoot, 'src', 'index.html');
const outputRoot = path.resolve(projectRoot, '..', '..', 'outputs');
const outputHtml = path.join(outputRoot, 'ZahpyBusinessPro_all_in_one.html');

const mimeTypes = {
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf'
};

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function resolveFromHtml(reference) {
  const cleanReference = reference.split(/[?#]/)[0];
  return path.resolve(path.dirname(sourceHtml), cleanReference);
}

function getMimeType(filePath) {
  return mimeTypes[path.extname(filePath).toLowerCase()] || 'application/octet-stream';
}

function inlineCssUrls(css, cssPath) {
  return css.replace(/url\((['"]?)([^'")]+)\1\)/g, (match, quote, rawUrl) => {
    const trimmedUrl = rawUrl.trim();

    if (/^(data:|https?:|about:|#)/i.test(trimmedUrl)) {
      return match;
    }

    const cleanUrl = trimmedUrl.split(/[?#]/)[0];
    const assetPath = path.resolve(path.dirname(cssPath), decodeURIComponent(cleanUrl));

    if (!fs.existsSync(assetPath) || !fs.statSync(assetPath).isFile()) {
      return match;
    }

    const encoded = fs.readFileSync(assetPath).toString('base64');
    return `url("data:${getMimeType(assetPath)};base64,${encoded}")`;
  });
}

function inlineStylesheet(reference) {
  const cssPath = resolveFromHtml(reference);
  if (!fs.existsSync(cssPath)) {
    throw new Error(`Stylesheet was not found: ${reference}`);
  }

  const css = inlineCssUrls(readText(cssPath), cssPath);
  return `<style data-inlined-from="${reference}">\n${css}\n</style>`;
}

function inlineScript(reference) {
  const scriptPath = resolveFromHtml(reference);
  if (!fs.existsSync(scriptPath)) {
    throw new Error(`Script was not found: ${reference}`);
  }

  const script = readText(scriptPath).replace(/<\/script/gi, '<\\/script');
  return `<script data-inlined-from="${reference}">\n${script}\n</script>`;
}

function buildSingleHtml() {
  if (!fs.existsSync(sourceHtml)) {
    throw new Error(`Source HTML was not found: ${sourceHtml}`);
  }

  fs.mkdirSync(outputRoot, { recursive: true });

  let html = readText(sourceHtml);

  html = html.replace(/<link\b([^>]*?)\bhref=["']([^"']+)["']([^>]*?)>/gi, (match, beforeHref, href, afterHref) => {
    const attributes = `${beforeHref} ${afterHref}`;
    if (!/\brel=["']stylesheet["']/i.test(attributes)) {
      return match;
    }

    if (/^(https?:|data:|about:)/i.test(href)) {
      return match;
    }

    return inlineStylesheet(href);
  });

  html = html.replace(/<script\b([^>]*?)\bsrc=["']([^"']+)["']([^>]*?)>\s*<\/script>/gi, (match, beforeSrc, src) => {
    if (/^(https?:|data:|about:)/i.test(src)) {
      return match;
    }

    return inlineScript(src);
  });

  fs.writeFileSync(outputHtml, html, 'utf8');
  console.log(`Single-file HTML written to ${outputHtml}`);
}

buildSingleHtml();
