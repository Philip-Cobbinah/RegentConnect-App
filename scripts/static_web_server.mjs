import { createServer } from 'node:http';
import { extname, join, normalize, resolve } from 'node:path';
import { readFile, stat } from 'node:fs/promises';

const rootDir = resolve(process.argv[2] ?? 'build/web');
const port = Number(process.argv[3] ?? '7360');
const host = process.argv[4] ?? '127.0.0.1';

const contentTypes = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'application/javascript; charset=utf-8'],
  ['.mjs', 'application/javascript; charset=utf-8'],
  ['.css', 'text/css; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.wasm', 'application/wasm'],
  ['.png', 'image/png'],
  ['.jpg', 'image/jpeg'],
  ['.jpeg', 'image/jpeg'],
  ['.gif', 'image/gif'],
  ['.svg', 'image/svg+xml'],
  ['.ico', 'image/x-icon'],
  ['.ttf', 'font/ttf'],
  ['.otf', 'font/otf'],
  ['.woff', 'font/woff'],
  ['.woff2', 'font/woff2'],
  ['.txt', 'text/plain; charset=utf-8'],
  ['.xml', 'application/xml; charset=utf-8'],
]);

async function readFileSafe(pathname) {
  try {
    await stat(pathname);
    return await readFile(pathname);
  } catch {
    return null;
  }
}

createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? '/', `http://${host}:${port}`);
    let pathname = decodeURIComponent(url.pathname);
    if (pathname === '/') pathname = '/index.html';
    pathname = normalize(pathname).replace(/^([.][.][/\\])+/, '');
    const filePath = join(rootDir, pathname);

    let content = await readFileSafe(filePath);
    let resolvedPath = filePath;

    if (!content) {
      const fallbackPath = join(rootDir, 'index.html');
      content = await readFileSafe(fallbackPath);
      resolvedPath = fallbackPath;
    }

    if (!content) {
      res.statusCode = 404;
      res.setHeader('content-type', 'text/plain; charset=utf-8');
      res.end('Not found');
      return;
    }

    res.statusCode = 200;
    res.setHeader(
      'content-type',
      contentTypes.get(extname(resolvedPath).toLowerCase()) ??
        'application/octet-stream',
    );
    res.setHeader('cache-control', 'no-store');
    res.end(content);
  } catch (error) {
    res.statusCode = 500;
    res.setHeader('content-type', 'text/plain; charset=utf-8');
    res.end(String(error?.stack ?? error));
  }
}).listen(port, host, () => {
  console.log(`Serving ${rootDir} at http://${host}:${port}/`);
});
