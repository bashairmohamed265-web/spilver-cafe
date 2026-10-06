// Local preview server for the Spilver site. No dependencies: `npm run dev` just works.
// Serves this folder with no caching, so every save shows up on refresh.
import { createServer } from 'node:http';
import { stat, readFile } from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import { extname, join, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('.', import.meta.url));
const START_PORT = Number(process.env.PORT) || 5173;
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.mp4': 'video/mp4',
  '.woff2': 'font/woff2'
};

async function handle(req, res) {
  let path = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  if (path.endsWith('/')) path += 'index.html';
  const file = normalize(join(ROOT, path));
  if (!file.startsWith(ROOT.endsWith(sep) ? ROOT : ROOT + sep)) { res.writeHead(403).end('Forbidden'); return; }

  let info;
  try { info = await stat(file); } catch { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }).end('Not found: ' + path); return; }
  if (info.isDirectory()) { res.writeHead(302, { Location: path + '/' }).end(); return; }

  const headers = { 'Content-Type': TYPES[extname(file).toLowerCase()] || 'application/octet-stream', 'Cache-Control': 'no-store', 'Accept-Ranges': 'bytes' };
  const range = req.headers.range && /bytes=(\d*)-(\d*)/.exec(req.headers.range);
  if (range) {
    const start = range[1] ? Number(range[1]) : 0;
    const end = range[2] ? Math.min(Number(range[2]), info.size - 1) : info.size - 1;
    res.writeHead(206, { ...headers, 'Content-Range': `bytes ${start}-${end}/${info.size}`, 'Content-Length': end - start + 1 });
    if (req.method === 'HEAD') { res.end(); return; }
    createReadStream(file, { start, end }).pipe(res);
    return;
  }
  res.writeHead(200, { ...headers, 'Content-Length': info.size });
  if (req.method === 'HEAD') { res.end(); return; }
  if (info.size < 1_000_000) res.end(await readFile(file));
  else createReadStream(file).pipe(res);
}

function listen(port) {
  const server = createServer((req, res) => handle(req, res).catch(err => { console.error(err); if (!res.headersSent) res.writeHead(500); res.end(); }));
  server.once('error', err => {
    if (err.code === 'EADDRINUSE' && port < START_PORT + 20) listen(port + 1);
    else { console.error(err.message); process.exit(1); }
  });
  server.listen(port, () => {
    console.log('\n  Spilver is running:\n');
    console.log(`  → http://localhost:${port}\n`);
    console.log('  Open that link in Chrome. Press Ctrl+C to stop.\n');
  });
}
listen(START_PORT);
