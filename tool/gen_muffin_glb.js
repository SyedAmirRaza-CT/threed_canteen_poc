// Generates assets/models/fruit_muffin.glb from the reference photos in
// D:\WORKSPACE\productImages\product56 (24 turntable frames of one muffin: a
// golden domed top with red fruit pieces in a white fluted paper liner printed
// with red and brown oval dots).
//
// Built procedurally (the photos are 360 px, far too small to scan): the shapes
// are measured by eye and the surface detail is painted into embedded PNG
// textures. Units are metres, base on y = 0, about 10 cm tall.
// Run:  node tool/gen_muffin_glb.js
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const PI = Math.PI;

// ---------------------------------------------------------------- PNG + painting
const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
function crc32(b) { let c = 0xFFFFFFFF; for (const x of b) c = CRC[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type, 'ascii'), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td)); return Buffer.concat([len, td, crc]); }
function encodePng(w, h, px) {
  const raw = Buffer.alloc(h * (1 + w * 4));
  for (let y = 0; y < h; y++) { raw[y * (1 + w * 4)] = 0; Buffer.from(px.buffer, px.byteOffset + y * w * 4, w * 4).copy(raw, y * (1 + w * 4) + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
function hash(x, y, s = 0) { let h = (x * 374761393 + y * 668265263 + s * 982451653) | 0; h = (h ^ (h >>> 13)) * 1274126177 | 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967295; }
function vnoise(x, y, s = 0) { const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi, u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf); const a = hash(xi, yi, s), b = hash(xi + 1, yi, s), c = hash(xi, yi + 1, s), d = hash(xi + 1, yi + 1, s); return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v; }
function fbm(x, y, s = 0) { return 0.5 * vnoise(x, y, s) + 0.3 * vnoise(x * 2.1, y * 2.1, s + 1) + 0.2 * vnoise(x * 4.3, y * 4.3, s + 2); }
// noise that repeats every `period` cells horizontally (so a texture wraps around a lathe seamlessly)
function wnoise(x, y, period, s = 0) { const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi, u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf); const m = (k) => ((k % period) + period) % period; const a = hash(m(xi), yi, s), b = hash(m(xi + 1), yi, s), c = hash(m(xi), yi + 1, s), d = hash(m(xi + 1), yi + 1, s); return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v; }
class Img {
  constructor(w, h) { this.w = w; this.h = h; this.px = new Uint8Array(w * h * 4); }
  get(x, y) { const o = (((y + this.h) % this.h) * this.w + ((x + this.w) % this.w)) * 4; return [this.px[o] / 255, this.px[o + 1] / 255, this.px[o + 2] / 255]; }
  set(x, y, c, a = 1) { x = ((x % this.w) + this.w) % this.w; if (y < 0 || y >= this.h) return; const o = (y * this.w + x) * 4, p = this.px; for (let k = 0; k < 3; k++) p[o + k] = Math.round(Math.max(0, Math.min(1, p[o + 3] ? p[o + k] / 255 * (1 - a) + c[k] * a : c[k])) * 255); p[o + 3] = 255; }
  ellipse(cx, cy, rx, ry, c, a = 1, rot = 0) { const cs = Math.cos(rot), sn = Math.sin(rot), R = Math.ceil(Math.max(rx, ry)) + 1; for (let y = Math.floor(cy - R); y <= Math.ceil(cy + R); y++) for (let x = Math.floor(cx - R); x <= Math.ceil(cx + R); x++) { const dx = x + 0.5 - cx, dy = y + 0.5 - cy, ux = (dx * cs + dy * sn) / rx, uy = (-dx * sn + dy * cs) / ry, d = Math.hypot(ux, uy); if (d <= 1) this.set(x, y, c, a * Math.min(1, (1 - d) * Math.max(rx, ry) * 0.8 + 0.25)); } }
  png() { return encodePng(this.w, this.h, this.px); }
}
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const shade = (c, k) => [c[0] * k, c[1] * k, c[2] * k];

// paper liner: u around, v up the liner (v = 0 top rim, 1 bottom). 24 pleats, two staggered rows of red and brown ovals
function linerTexture() {
  const W = 512, H = 160, img = new Img(W, H), PAPER = [0.965, 0.935, 0.865], PLEATS = 24;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const pleat = Math.sin((x / W) * PLEATS * PI * 2), n = fbm(x / 3, y / 3, 3);
    img.set(x, y, shade(PAPER, 0.93 + 0.045 * pleat + (n - 0.5) * 0.05 + (y / H) * -0.03), 1);
  }
  const RED = [0.78, 0.13, 0.13], BROWN = [0.55, 0.31, 0.22];
  const rows = [{ v: 0.33, off: 0 }, { v: 0.74, off: 0.5 }], COUNT = 12;
  for (const row of rows) for (let i = 0; i < COUNT; i++) {
    const cx = ((i + row.off + (hash(i, row.v * 9, 5) - 0.5) * 0.12) / COUNT) * W, cy = row.v * H + (hash(i, 2, 5) - 0.5) * 6;
    const colr = hash(i, row.v * 7, 6) < 0.58 ? RED : BROWN, rx = 11 + hash(i, 3, 5) * 3, ry = 22 + hash(i, 4, 5) * 4;
    img.ellipse(cx, cy, rx, ry, shade(colr, 0.92 + hash(i, 8, 5) * 0.16), 0.96);
    for (let k = -3; k <= 3; k++) img.ellipse(cx + k * 3.2, cy + k * 2.2, 1.0, ry * 0.9, shade(colr, 1.28), 0.35, 0.5); // pale diagonal hatching inside the oval
  }
  return img.png();
}
// golden muffin top: u around, v along the profile (0 = under the rim, 1 = crown)
function topTexture() {
  const W = 512, H = 256, img = new Img(W, H), PERIOD = 8;
  const SIDE = [0.93, 0.80, 0.50], GOLD = [0.95, 0.77, 0.36], TOAST = [0.76, 0.48, 0.20];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const v = y / H, u = x / W;
    const n = wnoise(u * PERIOD * 3, y / 18, PERIOD * 3, 11), n2 = wnoise(u * PERIOD * 9, y / 6, PERIOD * 9, 17);
    let c = mix(SIDE, GOLD, Math.min(1, v * 1.6));
    const toast = Math.max(0, (n - 0.45) * 2.2) * (0.35 + 0.65 * v);
    c = mix(c, TOAST, Math.min(0.85, toast));
    c = shade(c, 0.93 + n2 * 0.14);
    if (wnoise(u * PERIOD * 14, y / 3.5, PERIOD * 14, 23) > 0.74 && v > 0.15) c = shade(c, 0.88); // crumb pits
    img.set(x, y, c, 1);
  }
  // red fruit pieces dotted over the dome, with a dark baked edge and a glossy highlight
  for (let i = 0; i < 34; i++) {
    const u = hash(i, 1, 31), v = 0.34 + hash(i, 2, 31) * 0.5, cx = u * W, cy = v * H, rx = 4 + hash(i, 3, 31) * 6, ry = 3 + hash(i, 4, 31) * 5, rot = hash(i, 5, 31) * PI;
    img.ellipse(cx, cy, rx + 2, ry + 2, [0.38, 0.1, 0.06], 0.7, rot); // baked edge
    img.ellipse(cx, cy, rx, ry, [0.73 + hash(i, 6, 31) * 0.1, 0.14, 0.11], 0.97, rot);
    img.ellipse(cx - rx * 0.25, cy - ry * 0.3, rx * 0.35, ry * 0.3, [0.96, 0.55, 0.45], 0.55, rot);
  }
  for (let i = 0; i < 90; i++) img.ellipse(hash(i, 7, 33) * W, (0.2 + hash(i, 8, 33) * 0.75) * H, 1.5, 1.2, [0.62, 0.40, 0.2], 0.5); // sugary specks
  return img.png();
}

// ---------------------------------------------------------------- geometry
class Geo { constructor() { this.p = []; this.uv = []; this.i = []; } get n() { return this.p.length / 3; } }
function gridSurface(nu, nv, fn) {
  const g = new Geo();
  for (let j = 0; j <= nv; j++) for (let i = 0; i <= nu; i++) { const r = fn(i / nu, j / nv); g.p.push(r[0], r[1], r[2]); g.uv.push(i / nu, j / nv); }
  for (let j = 0; j < nv; j++) for (let i = 0; i < nu; i++) { const a = j * (nu + 1) + i, b = a + 1, c = a + nu + 1, d = c + 1; g.i.push(a, b, c, b, d, c); }
  return g;
}
function latheRaw(pts, seg) {
  const g = new Geo(), L = pts.length;
  for (let i = 0; i <= seg; i++) { const phi = (i / seg) * PI * 2, s = Math.sin(phi), c = Math.cos(phi); for (let j = 0; j < L; j++) { g.p.push(pts[j][0] * s, pts[j][1], pts[j][0] * c); g.uv.push(i / seg, j / (L - 1)); } }
  for (let i = 0; i < seg; i++) for (let j = 0; j < L - 1; j++) { const base = j + i * L, a = base, b = base + L, c = base + L + 1, d = base + 1; g.i.push(a, b, d, c, d, b); }
  return g;
}
function orient(g, cx, cy, cz) {
  for (let t = 0; t < g.i.length; t += 3) {
    const [a, b, c] = [g.i[t] * 3, g.i[t + 1] * 3, g.i[t + 2] * 3];
    const ux = g.p[b] - g.p[a], uy = g.p[b + 1] - g.p[a + 1], uz = g.p[b + 2] - g.p[a + 2], vx = g.p[c] - g.p[a], vy = g.p[c + 1] - g.p[a + 1], vz = g.p[c + 2] - g.p[a + 2];
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    const mx = (g.p[a] + g.p[b] + g.p[c]) / 3 - cx, my = (g.p[a + 1] + g.p[b + 1] + g.p[c + 1]) / 3 - cy, mz = (g.p[a + 2] + g.p[b + 2] + g.p[c + 2]) / 3 - cz;
    if (nx * mx + ny * my + nz * mz < 0) { const k = g.i[t + 1]; g.i[t + 1] = g.i[t + 2]; g.i[t + 2] = k; }
  }
  return g;
}
function normals(g) {
  const n = new Float64Array(g.p.length);
  for (let t = 0; t < g.i.length; t += 3) {
    const [a, b, c] = [g.i[t] * 3, g.i[t + 1] * 3, g.i[t + 2] * 3];
    const ux = g.p[b] - g.p[a], uy = g.p[b + 1] - g.p[a + 1], uz = g.p[b + 2] - g.p[a + 2], vx = g.p[c] - g.p[a], vy = g.p[c + 1] - g.p[a + 1], vz = g.p[c + 2] - g.p[a + 2];
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    for (const k of [a, b, c]) { n[k] += nx; n[k + 1] += ny; n[k + 2] += nz; }
  }
  for (let k = 0; k < n.length; k += 3) { const l = Math.hypot(n[k], n[k + 1], n[k + 2]) || 1; n[k] /= l; n[k + 1] /= l; n[k + 2] /= l; }
  return n;
}

// paper liner: a flared, pleated cup (outside surface, open at the top)
const R0 = 0.034, R1 = 0.0455, HL = 0.05, PLEATS = 24;
function liner() {
  const g = gridSurface(PLEATS * 6, 14, (u, v) => {
    const phi = u * PI * 2, y = (1 - v) * HL; // v = 0 is the top rim, matching the texture
    const t = y / HL, flare = t > 0.9 ? 0.0022 * Math.pow((t - 0.9) / 0.1, 2) : 0;
    const r = (R0 + (R1 - R0) * t + flare) * (1 + (0.02 + 0.03 * t) * Math.sin(phi * PLEATS));
    return [r * Math.sin(phi), y, r * Math.cos(phi)];
  });
  return orient(g, 0, HL / 2, 0);
}
function linerBase() { // closes the bottom
  const seg = 48, g = new Geo();
  g.p.push(0, 0, 0); g.uv.push(0.5, 0.95);
  for (let i = 0; i <= seg; i++) { const a = (i / seg) * PI * 2; g.p.push(R0 * Math.sin(a), 0, R0 * Math.cos(a)); g.uv.push(i / seg, 0.95); }
  for (let i = 1; i <= seg; i++) g.i.push(0, i + 1, i);
  return orient(g, 0, HL / 2, 0);
}
// muffin top: spills slightly over the rim, then rises to a rounded crown, with a lumpy baked surface
function top() {
  const pts = [[0.0432, 0.0485], [0.0484, 0.0535], [0.0516, 0.0615], [0.0521, 0.0685], [0.0502, 0.0752], [0.0448, 0.0818], [0.0362, 0.0868], [0.0245, 0.0902], [0.0125, 0.0922], [0.0001, 0.0928]];
  const g = latheRaw(pts, 96);
  for (let k = 0; k < g.p.length; k += 3) { // crumbly bumps, strongest on the crown
    const x = g.p[k], y = g.p[k + 1], z = g.p[k + 2], r = Math.hypot(x, z) || 1e-6, ang = Math.atan2(x, z);
    const bump = (wnoise((ang / (PI * 2) + 1) * 14, y * 260, 14, 41) - 0.5) * 0.0034 + (fbm(ang * 3, y * 120, 43) - 0.5) * 0.0022;
    const f = Math.min(1, Math.max(0, (y - 0.054) / 0.02));
    g.p[k] = x + (x / r) * bump * f; g.p[k + 2] = z + (z / r) * bump * f; g.p[k + 1] = y + bump * 0.7 * f;
  }
  return g;
}

// ---------------------------------------------------------------- glTF writer
const MATS = {
  liner: { tex: 'liner', rough: 0.85, metal: 0 },
  muffinTop: { tex: 'top', rough: 0.7, metal: 0 },
};
const TEX = { liner: linerTexture(), top: topTexture() };
const parts = [
  { name: 'liner', mat: 'liner', geo: liner() },
  { name: 'liner_base', mat: 'liner', geo: linerBase() },
  { name: 'top', mat: 'muffinTop', geo: top() },
];

function writeGlb(file) {
  const chunks = [], bufferViews = [], accessors = [], meshes = [], nodes = [], materials = [], images = [], textures = [];
  let offset = 0;
  const push = (buf, target) => { const pad = (4 - (buf.length % 4)) % 4; const v = { buffer: 0, byteOffset: offset, byteLength: buf.length }; if (target) v.target = target; bufferViews.push(v); chunks.push(buf, Buffer.alloc(pad)); offset += buf.length + pad; return bufferViews.length - 1; };
  const texIndex = {};
  for (const [name, buf] of Object.entries(TEX)) { images.push({ bufferView: push(buf), mimeType: 'image/png' }); textures.push({ sampler: 0, source: images.length - 1 }); texIndex[name] = textures.length - 1; }
  const matIndex = {};
  for (const [name, m] of Object.entries(MATS)) { materials.push({ name, pbrMetallicRoughness: { baseColorFactor: [1, 1, 1, 1], baseColorTexture: { index: texIndex[m.tex] }, metallicFactor: m.metal, roughnessFactor: m.rough } }); matIndex[name] = materials.length - 1; }
  const kids = [];
  for (const part of parts) {
    const g = part.geo, nrm = normals(g), pos = Float32Array.from(g.p), min = [1e9, 1e9, 1e9], max = [-1e9, -1e9, -1e9];
    for (let k = 0; k < pos.length; k += 3) for (let c = 0; c < 3; c++) { min[c] = Math.min(min[c], pos[k + c]); max[c] = Math.max(max[c], pos[k + c]); }
    const big = g.n > 65535;
    const vp = push(Buffer.from(pos.buffer), 34962), vn = push(Buffer.from(Float32Array.from(nrm).buffer), 34962), vt = push(Buffer.from(Float32Array.from(g.uv).buffer), 34962), vi = push(Buffer.from((big ? Uint32Array : Uint16Array).from(g.i).buffer), 34963);
    const a = accessors.length;
    accessors.push({ bufferView: vp, componentType: 5126, count: g.n, type: 'VEC3', min, max }, { bufferView: vn, componentType: 5126, count: g.n, type: 'VEC3' }, { bufferView: vt, componentType: 5126, count: g.n, type: 'VEC2' }, { bufferView: vi, componentType: big ? 5125 : 5123, count: g.i.length, type: 'SCALAR' });
    meshes.push({ name: part.name, primitives: [{ attributes: { POSITION: a, NORMAL: a + 1, TEXCOORD_0: a + 2 }, indices: a + 3, material: matIndex[part.mat] }] });
    nodes.push({ name: part.name, mesh: meshes.length - 1 }); kids.push(nodes.length);
  }
  const json = { asset: { version: '2.0', generator: 'tool/gen_muffin_glb.js' }, scene: 0, scenes: [{ nodes: [0] }], nodes: [{ name: 'fruit_muffin', children: kids }, ...nodes], meshes, materials, textures, images, samplers: [{ magFilter: 9729, minFilter: 9987, wrapS: 10497, wrapT: 10497 }], accessors, bufferViews, buffers: [{ byteLength: offset }] };
  let jb = Buffer.from(JSON.stringify(json)); jb = Buffer.concat([jb, Buffer.alloc((4 - (jb.length % 4)) % 4, 0x20)]);
  const bin = Buffer.concat(chunks), total = 12 + 8 + jb.length + 8 + bin.length;
  const h = Buffer.alloc(12); h.write('glTF', 0, 'ascii'); h.writeUInt32LE(2, 4); h.writeUInt32LE(total, 8);
  const jh = Buffer.alloc(8); jh.writeUInt32LE(jb.length, 0); jh.write('JSON', 4, 'ascii');
  const bh = Buffer.alloc(8); bh.writeUInt32LE(bin.length, 0); bh.write('BIN\0', 4, 'ascii');
  fs.writeFileSync(file, Buffer.concat([h, jh, jb, bh, bin]));
  console.log('wrote', path.relative(process.cwd(), file), total, 'bytes,', parts.length, 'parts');
}
writeGlb(path.join(__dirname, '..', 'assets', 'models', 'fruit_muffin.glb'));
const dbg = path.join(__dirname, '..', 'build', 'muffin_textures');
try { fs.mkdirSync(dbg, { recursive: true }); for (const [n, b] of Object.entries(TEX)) fs.writeFileSync(path.join(dbg, n + '.png'), b); } catch (e) { /* optional */ }
