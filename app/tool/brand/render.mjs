// Renderiza los SVG de la marca a PNG con Chrome (sin dependencias). Uso, desde app/:
//   node tool/brand/render.mjs tool/brand/icon_full.svg assets/icon/icon.png 1024
//   node tool/brand/render.mjs tool/brand/icon_fg.svg assets/icon/icon_foreground.png 1024
//   node tool/brand/render.mjs tool/brand/splash.svg assets/icon/splash.png 960
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
const [,, svgPath, outPath, sizeArg] = process.argv;
const size = Number(sizeArg || 512);
const svg = readFileSync(svgPath, 'utf8');
const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',
  ['--headless=new', '--remote-debugging-port=9334', '--user-data-dir=' + process.env.TEMP + '/mdg-render', 'about:blank']);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let t; for (let i = 0; i < 40; i++) { try { t = (await (await fetch('http://127.0.0.1:9334/json/list')).json()).find(x => x.type === 'page'); if (t) break; } catch {} await sleep(250); }
const ws = new WebSocket(t.webSocketDebuggerUrl); await new Promise(r => ws.addEventListener('open', r));
let id = 0; const pend = new Map();
ws.addEventListener('message', e => { const m = JSON.parse(e.data); if (pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); } });
const send = (method, params = {}) => new Promise(r => { const n = ++id; pend.set(n, r); ws.send(JSON.stringify({ id: n, method, params })); });
await send('Emulation.setDeviceMetricsOverride', { width: size, height: size, deviceScaleFactor: 1, mobile: false });
await send('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });
const html = `<html><body style="margin:0;background:transparent">${svg.replace(/width="\d+" height="\d+"/, `width="${size}" height="${size}"`)}</body></html>`;
await send('Page.navigate', { url: 'data:text/html;base64,' + Buffer.from(html).toString('base64') });
await sleep(700);
await send('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });
await sleep(100);
const { result } = await send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: size, height: size, scale: 1 } });
writeFileSync(outPath, Buffer.from(result.data, 'base64'));
ws.close(); chrome.kill(); process.exit(0);
