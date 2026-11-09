// Renderiza los SVG de la marca a PNG con Chrome (sin dependencias). Uso, desde app/:
//   node tool/brand/render.mjs tool/brand/icon_full.svg assets/icon/icon.png 1024
//   node tool/brand/render.mjs tool/brand/icon_fg.svg assets/icon/icon_foreground.png 1024
//   node tool/brand/render.mjs tool/brand/splash.svg assets/icon/splash.png 960
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative, resolve, isAbsolute } from 'node:path';

// Solo se leen y escriben archivos dentro de la carpeta app/ (donde se ejecuta).
function insideProject(path, extension) {
  const full = resolve(path);
  const rel = relative(process.cwd(), full);
  if (rel.startsWith('..') || isAbsolute(rel) || !full.endsWith(extension)) {
    throw new Error(`Ruta no permitida: ${path}`);
  }
  return full;
}

const [, , svgArg, outArg, sizeArg] = process.argv;
const svgPath = insideProject(svgArg, '.svg');
const outPath = insideProject(outArg, '.png');
const size = Number(sizeArg || 512);
if (!Number.isInteger(size) || size < 16 || size > 4096) throw new Error('Tamaño inválido');

const chromePath = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
// Perfil temporal propio (único y solo del usuario), se borra al terminar.
const profile = mkdtempSync(join(tmpdir(), 'mandidog-render-'));
const svg = readFileSync(svgPath, 'utf8');
const chrome = spawn(chromePath, [
  '--headless=new',
  '--remote-debugging-port=9334',
  `--user-data-dir=${profile}`,
  'about:blank',
]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let t;
for (let i = 0; i < 40; i++) {
  try {
    t = (await (await fetch('http://127.0.0.1:9334/json/list')).json()).find((x) => x.type === 'page');
    if (t) break;
  } catch {}
  await sleep(250);
}
const ws = new WebSocket(t.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r));
let id = 0;
const pend = new Map();
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data);
  if (pend.has(m.id)) {
    pend.get(m.id)(m);
    pend.delete(m.id);
  }
});
const send = (method, params = {}) =>
  new Promise((r) => {
    const n = ++id;
    pend.set(n, r);
    ws.send(JSON.stringify({ id: n, method, params }));
  });
await send('Emulation.setDeviceMetricsOverride', { width: size, height: size, deviceScaleFactor: 1, mobile: false });
const html = `<html><body style="margin:0;background:transparent">${svg.replace(/width="\d+" height="\d+"/, `width="${size}" height="${size}"`)}</body></html>`;
await send('Page.navigate', { url: 'data:text/html;base64,' + Buffer.from(html).toString('base64') });
await sleep(700);
await send('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });
await sleep(100);
const { result } = await send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: size, height: size, scale: 1 } });
writeFileSync(outPath, Buffer.from(result.data, 'base64'));
ws.close();
chrome.kill();
await sleep(300);
rmSync(profile, { recursive: true, force: true });
process.exit(0);
