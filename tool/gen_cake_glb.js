// Generates assets/models/cake_slices.glb: a plate with two slices of pineapple
// vanilla cake (layered sponge and cream, ribbed whipped-cream side, a dark
// chocolate shard and a pineapple chunk on each). Modelled from the reference
// photos in D:\WORKSPACE\productImages\product29 (24 turntable frames of a
// cream plate with a brown rim and two wedge slices).
//
// It is built procedurally, not scanned: shapes are measured by eye from the
// photos and all surface detail (sponge crumb, cream layers, plate speckles,
// chocolate swirl) is painted into small PNG textures embedded in the file.
//
// Units are metres. The plate is centred on the origin with its base at y = 0,
// and the slices face +z. Run:  node tool/gen_cake_glb.js
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const PI = Math.PI;

// ============================================================ PNG + painting
const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
function crc32(b) { let c = 0xFFFFFFFF; for (const x of b) c = CRC[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function encodePng(w, h, px) { // px: Uint8Array RGBA
  const raw = Buffer.alloc(h * (1 + w * 4));
  for (let y = 0; y < h; y++) { raw[y * (1 + w * 4)] = 0; Buffer.from(px.buffer, px.byteOffset + y * w * 4, w * 4).copy(raw, y * (1 + w * 4) + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
// deterministic noise
function hash(x, y, s = 0) { let h = (x * 374761393 + y * 668265263 + s * 982451653) | 0; h = (h ^ (h >>> 13)) * 1274126177 | 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967295; }
function vnoise(x, y, s = 0) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi, s), b = hash(xi + 1, yi, s), c = hash(xi, yi + 1, s), d = hash(xi + 1, yi + 1, s);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
function fbm(x, y, s = 0) { return 0.5 * vnoise(x, y, s) + 0.3 * vnoise(x * 2.1, y * 2.1, s + 1) + 0.2 * vnoise(x * 4.3, y * 4.3, s + 2); }
class Img {
  constructor(w, h) { this.w = w; this.h = h; this.px = new Uint8Array(w * h * 4); }
  set(x, y, c, a = 1) { if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const o = (y * this.w + x) * 4, p = this.px; for (let k = 0; k < 3; k++) p[o + k] = Math.round(Math.max(0, Math.min(1, p[o + 3] ? p[o + k] / 255 * (1 - a) + c[k] * a : c[k])) * 255); p[o + 3] = 255; }
  dot(cx, cy, r, c, a = 1) { for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++) for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) { const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy); if (d <= r) this.set(x, y, c, a * Math.min(1, (r - d) * 1.5 + 0.2)); } }
  line(x0, y0, x1, y1, r, c, a = 1) { const n = Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 2) + 1; for (let i = 0; i <= n; i++) this.dot(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, r, c, a); }
  png() { return encodePng(this.w, this.h, this.px); }
}
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const shade = (c, k) => [c[0] * k, c[1] * k, c[2] * k];

// sponge / cream cut-face texture: row 0 is the top of the slice
const SPONGE = [0.90, 0.79, 0.55], CREAM = [0.985, 0.97, 0.92], PINE = [0.96, 0.87, 0.45];
function layersTexture() {
  const W = 256, H = 256, img = new Img(W, H);
  // bands top -> bottom as fractions of the slice height
  const bands = [['cream', 0.16], ['sponge', 0.17], ['fill', 0.13], ['sponge', 0.17], ['fill', 0.13], ['sponge', 0.20], ['cream', 0.04]];
  const edges = []; let acc = 0; for (const [k, f] of bands) { acc += f; edges.push([k, acc]); }
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const wob = (fbm(x / 22, 3.1, 7) - 0.5) * 0.035 + (fbm(x / 9, y / 9, 3) - 0.5) * 0.01; // wavy layer borders
    const v = y / H + wob;
    let kind = 'cream'; for (const [k, e] of edges) if (v < e) { kind = k; break; }
    let c;
    if (kind === 'sponge') {
      const n = fbm(x / 3.2, y / 3.2, 11), cr = fbm(x / 1.4, y / 1.4, 17);
      c = shade(SPONGE, 0.9 + n * 0.2);
      if (cr > 0.64) c = shade(c, 0.86); // crumb pits
      if (fbm(x / 6, y / 6, 29) > 0.66) c = mix(c, [1, 0.95, 0.8], 0.35); // lighter airy bits
      // slight toasted tone near the layer edges
      const edge = Math.min(Math.abs(v - 0.16), 1);
      c = shade(c, 1 - Math.max(0, 0.05 - edge) * 1.2);
    } else {
      const n = fbm(x / 2.4, y / 2.4, 5);
      c = shade(CREAM, 0.97 + n * 0.05);
    }
    img.set(x, y, c, 1);
  }
  // pineapple bits in the filling layers
  for (let i = 0; i < 70; i++) {
    const layer = i % 2 ? 0.405 + 0.0 : 0.69, y = layer * H + (hash(i, 1, 41) - 0.5) * 16, x = hash(i, 2, 41) * W, r = 1.5 + hash(i, 3, 41) * 2.4;
    img.dot(x, y, r, shade(PINE, 0.92 + hash(i, 4, 41) * 0.12), 0.9);
  }
  return img.png();
}
function creamTexture() { // whipped cream: very faint soft shading
  const W = 128, H = 128, img = new Img(W, H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) img.set(x, y, shade(CREAM, 0.965 + fbm(x / 5, y / 5, 13) * 0.07), 1);
  return img.png();
}
function chocolateTexture() { // dark chocolate with a white swirl
  const W = 128, H = 128, img = new Img(W, H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) img.set(x, y, shade([0.13, 0.08, 0.055], 0.85 + fbm(x / 7, y / 7, 23) * 0.5), 1);
  const rnd = (n) => hash(n, 9, 77);
  for (let s = 0; s < 7; s++) { // curved web lines from the edges
    let x = rnd(s * 3) * W, y = rnd(s * 3 + 1) * H, ang = rnd(s * 3 + 2) * PI * 2;
    for (let i = 0; i < 70; i++) { const nx = x + Math.cos(ang) * 2, ny = y + Math.sin(ang) * 2; img.line(x, y, nx, ny, 0.9 + rnd(s) * 0.5, [0.96, 0.94, 0.9], 0.9); x = nx; y = ny; ang += (fbm(i / 9, s, 5) - 0.5) * 0.55; }
  }
  img.dot(W * 0.5, H * 0.52, 9, [0.97, 0.95, 0.9], 0.95); // round white spot like in the photos
  return img.png();
}
// plate: u around, v along the profile (8 profile points, brown on the rim band)
function plateTexture() {
  const W = 256, H = 256, img = new Img(W, H);
  const BASE = [0.90, 0.84, 0.72], RIM = [0.70, 0.36, 0.15];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const v = y / H;
    let c = shade(BASE, 0.96 + fbm(x / 8, y / 8, 31) * 0.08);
    const b = Math.max(0, 1 - Math.abs(v - 0.495) / 0.14); // brown rim band
    if (b > 0) c = mix(c, RIM, Math.min(1, b * 2.2));
    img.set(x, y, c, 1);
  }
  for (let i = 0; i < 260; i++) { const x = hash(i, 5, 90) * W, y = (0.64 + hash(i, 6, 90) * 0.36) * H; img.dot(x, y, 0.6 + hash(i, 7, 90) * 1.0, [0.45, 0.31, 0.2], 0.65); } // speckles
  return img.png();
}

// ============================================================ geometry
class Geo { constructor() { this.p = []; this.uv = []; this.i = []; } get n() { return this.p.length / 3; } }
function grid(nu, nv, fn) { // fn(u,v) -> [x,y,z,uu,vv]
  const g = new Geo();
  for (let j = 0; j <= nv; j++) for (let i = 0; i <= nu; i++) { const r = fn(i / nu, j / nv); g.p.push(r[0], r[1], r[2]); g.uv.push(r[3], r[4]); }
  for (let j = 0; j < nv; j++) for (let i = 0; i < nu; i++) { const a = j * (nu + 1) + i, b = a + 1, c = a + nu + 1, d = c + 1; g.i.push(a, c, b, b, c, d); }
  return g;
}
function orient(g, cx, cy, cz) { // make every triangle face away from a point inside the shape
  for (let t = 0; t < g.i.length; t += 3) {
    const [a, b, c] = [g.i[t] * 3, g.i[t + 1] * 3, g.i[t + 2] * 3];
    const ux = g.p[b] - g.p[a], uy = g.p[b + 1] - g.p[a + 1], uz = g.p[b + 2] - g.p[a + 2], vx = g.p[c] - g.p[a], vy = g.p[c + 1] - g.p[a + 1], vz = g.p[c + 2] - g.p[a + 2];
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    const mx = (g.p[a] + g.p[b] + g.p[c]) / 3 - cx, my = (g.p[a + 1] + g.p[b + 1] + g.p[c + 1]) / 3 - cy, mz = (g.p[a + 2] + g.p[b + 2] + g.p[c + 2]) / 3 - cz;
    if (nx * mx + ny * my + nz * mz < 0) { const k = g.i[t + 1]; g.i[t + 1] = g.i[t + 2]; g.i[t + 2] = k; }
  }
  return g;
}
function latheRaw(pts, seg) {
  const g = new Geo(), L = pts.length;
  for (let i = 0; i <= seg; i++) { const phi = (i / seg) * PI * 2, s = Math.sin(phi), c = Math.cos(phi); for (let j = 0; j < L; j++) { g.p.push(pts[j][0] * s, pts[j][1], pts[j][0] * c); g.uv.push(i / seg, j / (L - 1)); } }
  for (let i = 0; i < seg; i++) for (let j = 0; j < L - 1; j++) { const base = j + i * L, a = base, b = base + L, c = base + L + 1, d = base + 1; g.i.push(a, b, d, c, d, b); }
  return g;
}
function xf(g, f) { for (let k = 0; k < g.p.length; k += 3) { const v = f(g.p[k], g.p[k + 1], g.p[k + 2]); g.p[k] = v[0]; g.p[k + 1] = v[1]; g.p[k + 2] = v[2]; } return g; }
function place(g, { yaw = 0, tx = 0, ty = 0, tz = 0 }) { const c = Math.cos(yaw), s = Math.sin(yaw); return xf(g, (x, y, z) => [x * c + z * s + tx, y + ty, -x * s + z * c + tz]); }

// ---- plate
function plate() {
  const pts = [[0.0001, 0.0], [0.075, 0.0], [0.125, 0.018], [0.13, 0.03], [0.126, 0.0325], [0.12, 0.029], [0.09, 0.0125], [0.0001, 0.0125]];
  return latheRaw(pts, 72);
}
const PLATE_TOP = 0.0125;

// ---- one cake slice, apex at the origin, bisector along +x, base on y = 0
const R = 0.095, HS = 0.066, THETA = 0.78;
function slice() {
  const a1 = THETA / 2, parts = {};
  // flat cut faces (layers show here)
  const cut = (s) => grid(1, 1, (u, v) => { const r = u * R, y = v * HS; return [r * Math.cos(s * a1), y, r * Math.sin(s * a1), u, 1 - v]; });
  const cutPlus = orient(cut(1), R * 0.5, HS / 2, 0), cutMinus = orient(cut(-1), R * 0.5, HS / 2, 0);
  parts.layers = [cutPlus, cutMinus];
  // ribbed whipped-cream curved side
  const ridges = 15;
  parts.ribbed = [orient(grid(26, 150, (u, v) => {
    const phi = (u - 0.5) * THETA, y = v * HS;
    const lip = v > 0.86 ? 0.0028 * Math.pow((v - 0.86) / 0.14, 1.5) : 0; // soft overhang at the top
    const rr = R + 0.0011 * Math.sin(v * ridges * PI * 2) + lip + 0.0007 * Math.sin(u * 40 + v * 6);
    return [rr * Math.cos(phi), y, rr * Math.sin(phi), u, v];
  }), R * 0.4, HS / 2, 0)];
  // whipped cream top, gently domed and swirled at the edge
  parts.cream = [orient(grid(26, 12, (u, v) => {
    const phi = (u - 0.5) * THETA, r = v * (R + 0.0025), dome = 0.0055 * Math.sin(Math.min(1, r / R) * PI * 0.62) * (1 - 0.3 * Math.abs(u - 0.5) * 2);
    return [r * Math.cos(phi), HS + dome + 0.0008 * Math.sin(u * 30 + v * 9), r * Math.sin(phi), 0.5 + (r * Math.cos(phi)) * 6, 0.5 + (r * Math.sin(phi)) * 6];
  }), R * 0.4, HS - 0.01, 0)];
  return parts;
}
function pineapple(s = 0.03) { // rounded cube chunk
  const g = new Geo();
  const faces = [[[1, 0, 0], [0, 1, 0], [0, 0, 1]], [[-1, 0, 0], [0, 1, 0], [0, 0, -1]], [[0, 1, 0], [0, 0, 1], [1, 0, 0]], [[0, -1, 0], [0, 0, -1], [1, 0, 0]], [[0, 0, 1], [1, 0, 0], [0, 1, 0]], [[0, 0, -1], [-1, 0, 0], [0, 1, 0]]];
  const N = 8;
  for (const [n, a, b] of faces) {
    const base = g.n;
    for (let j = 0; j <= N; j++) for (let i = 0; i <= N; i++) {
      const u = i / N * 2 - 1, v = j / N * 2 - 1;
      let x = n[0] + a[0] * u + b[0] * v, y = n[1] + a[1] * u + b[1] * v, z = n[2] + a[2] * u + b[2] * v;
      const l = Math.hypot(x, y, z), k = 0.62; // blend the cube towards a sphere
      x = (x * (1 - k) + (x / l) * 1.25 * k) * s / 2; y = (y * (1 - k) + (y / l) * 1.25 * k) * s / 2; z = (z * (1 - k) + (z / l) * 1.25 * k) * s / 2;
      g.p.push(x, y, z); g.uv.push(i / N, j / N);
    }
    for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) { const q = base + j * (N + 1) + i; g.i.push(q, q + 1, q + N + 1, q + 1, q + N + 2, q + N + 1); }
  }
  return orient(g, 0, 0, 0);
}
function shard(w1, w2, h, skew) { // thin chocolate plate (quad), standing on its bottom edge
  const t = 0.0032, pts = [[-w1 / 2, 0], [w1 / 2, 0], [w2 / 2 + skew, h], [-w2 / 2 + skew, h * 0.94]];
  const g = new Geo(), uvOf = (p) => [(p[0] + 0.03) / 0.06, 1 - p[1] / h];
  for (const side of [1, -1]) { const base = g.n; for (const p of pts) { g.p.push(p[0], p[1], side * t / 2); g.uv.push(...uvOf(p)); } if (side > 0) g.i.push(base, base + 1, base + 2, base, base + 2, base + 3); else g.i.push(base, base + 2, base + 1, base, base + 3, base + 2); }
  for (let k = 0; k < 4; k++) { const p = pts[k], q = pts[(k + 1) % 4], base = g.n; g.p.push(p[0], p[1], t / 2, q[0], q[1], t / 2, q[0], q[1], -t / 2, p[0], p[1], -t / 2); g.uv.push(0, 0, 1, 0, 1, 1, 0, 1); g.i.push(base, base + 1, base + 2, base, base + 2, base + 3); }
  return orient(g, skew * 0.3, h * 0.45, 0);
}

// ============================================================ scene + glTF writer
const MATS = {
  plate: { color: [1, 1, 1], tex: 'plate', rough: 0.35, metal: 0 },
  layers: { color: [1, 1, 1], tex: 'layers', rough: 0.85, metal: 0 },
  cream: { color: [1, 1, 1], tex: 'cream', rough: 0.55, metal: 0 },
  creamRibbed: { color: [1, 1, 1], tex: 'cream', rough: 0.5, metal: 0 },
  chocolate: { color: [1, 1, 1], tex: 'chocolate', rough: 0.22, metal: 0.05 },
  pineapple: { color: [0.96, 0.86, 0.45], rough: 0.3, metal: 0 },
};
const TEX = { plate: plateTexture(), layers: layersTexture(), cream: creamTexture(), chocolate: chocolateTexture() };

const parts = []; // {name, mat, geo}
parts.push({ name: 'plate', mat: 'plate', geo: plate() });
const S = slice();
// each slice: placement in plate space
const placements = [
  // A: cut face (layers) toward the viewer, apex to the back-left
  { name: 'A', yaw: -0.2, tx: -0.105, tz: 0.018, shard: { x: 0.074, z: -0.012, yaw: 0.55, lean: 0.28 }, pine: { x: 0.052, z: 0.012 } },
  // B: ribbed cream side toward the viewer (bisector pointing +z)
  { name: 'B', yaw: -PI / 2 + 0.16, tx: 0.045, tz: -0.07, shard: { x: 0.07, z: 0.0, yaw: -0.35, lean: 0.35 }, pine: { x: 0.05, z: 0.012 } },
];
const clone = (g) => { const c = new Geo(); c.p = g.p.slice(); c.uv = g.uv.slice(); c.i = g.i.slice(); return c; };
for (const pl of placements) {
  const T = { yaw: pl.yaw, tx: pl.tx, ty: PLATE_TOP, tz: pl.tz };
  for (const g of S.layers) parts.push({ name: 'slice' + pl.name + '_layers', mat: 'layers', geo: place(clone(g), T) });
  for (const g of S.ribbed) parts.push({ name: 'slice' + pl.name + '_ribbed', mat: 'creamRibbed', geo: place(clone(g), T) });
  for (const g of S.cream) parts.push({ name: 'slice' + pl.name + '_cream', mat: 'cream', geo: place(clone(g), T) });
  // chocolate shard leaning on the cream, near the wide end
  const sh = shard(0.05, 0.046, 0.05, 0.004);
  xf(sh, (x, y, z) => { // lean back
    const c = Math.cos(pl.shard.lean), s = Math.sin(pl.shard.lean); return [x, y * c - z * s, y * s + z * c];
  });
  place(sh, { yaw: pl.shard.yaw, tx: pl.shard.x, ty: HS + 0.004, tz: pl.shard.z });
  place(sh, T);
  parts.push({ name: 'slice' + pl.name + '_chocolate', mat: 'chocolate', geo: sh });
  // pineapple chunk
  const pa = pineapple(0.03 + (pl.name === 'A' ? 0.002 : 0));
  place(pa, { tx: pl.pine.x, ty: HS + 0.013, tz: pl.pine.z });
  place(pa, T);
  parts.push({ name: 'slice' + pl.name + '_pineapple', mat: 'pineapple', geo: pa });
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

function writeGlb(file) {
  const chunks = [], bufferViews = [], accessors = [], meshes = [], nodes = [], materials = [], images = [], textures = [];
  let offset = 0;
  const push = (buf, target) => { const pad = (4 - (buf.length % 4)) % 4; const v = { buffer: 0, byteOffset: offset, byteLength: buf.length }; if (target) v.target = target; bufferViews.push(v); chunks.push(buf, Buffer.alloc(pad)); offset += buf.length + pad; return bufferViews.length - 1; };
  const texIndex = {};
  for (const [name, buf] of Object.entries(TEX)) { const bv = push(buf); images.push({ bufferView: bv, mimeType: 'image/png' }); textures.push({ sampler: 0, source: images.length - 1 }); texIndex[name] = textures.length - 1; }
  const matIndex = {};
  for (const [name, m] of Object.entries(MATS)) {
    const pbr = { baseColorFactor: [...m.color, 1], metallicFactor: m.metal, roughnessFactor: m.rough };
    if (m.tex) pbr.baseColorTexture = { index: texIndex[m.tex] };
    materials.push({ name, pbrMetallicRoughness: pbr }); matIndex[name] = materials.length - 1;
  }
  const kids = [];
  for (const part of parts) {
    const g = part.geo, nrm = normals(g), pos = Float32Array.from(g.p);
    const min = [1e9, 1e9, 1e9], max = [-1e9, -1e9, -1e9];
    for (let k = 0; k < pos.length; k += 3) for (let c = 0; c < 3; c++) { min[c] = Math.min(min[c], pos[k + c]); max[c] = Math.max(max[c], pos[k + c]); }
    const big = g.n > 65535;
    const vp = push(Buffer.from(pos.buffer), 34962), vn = push(Buffer.from(Float32Array.from(nrm).buffer), 34962), vt = push(Buffer.from(Float32Array.from(g.uv).buffer), 34962), vi = push(Buffer.from((big ? Uint32Array : Uint16Array).from(g.i).buffer), 34963);
    const a = accessors.length;
    accessors.push({ bufferView: vp, componentType: 5126, count: g.n, type: 'VEC3', min, max }, { bufferView: vn, componentType: 5126, count: g.n, type: 'VEC3' }, { bufferView: vt, componentType: 5126, count: g.n, type: 'VEC2' }, { bufferView: vi, componentType: big ? 5125 : 5123, count: g.i.length, type: 'SCALAR' });
    meshes.push({ name: part.name, primitives: [{ attributes: { POSITION: a, NORMAL: a + 1, TEXCOORD_0: a + 2 }, indices: a + 3, material: matIndex[part.mat] }] });
    nodes.push({ name: part.name, mesh: meshes.length - 1 }); kids.push(nodes.length); // index + 1 because root is node 0
  }
  const json = {
    asset: { version: '2.0', generator: 'tool/gen_cake_glb.js' }, scene: 0, scenes: [{ nodes: [0] }],
    nodes: [{ name: 'cake_slices', children: kids.map((k) => k) }, ...nodes],
    meshes, materials, textures, images, samplers: [{ magFilter: 9729, minFilter: 9987, wrapS: 10497, wrapT: 10497 }], accessors, bufferViews, buffers: [{ byteLength: offset }],
  };
  let jb = Buffer.from(JSON.stringify(json)); jb = Buffer.concat([jb, Buffer.alloc((4 - (jb.length % 4)) % 4, 0x20)]);
  const bin = Buffer.concat(chunks), total = 12 + 8 + jb.length + 8 + bin.length;
  const h = Buffer.alloc(12); h.write('glTF', 0, 'ascii'); h.writeUInt32LE(2, 4); h.writeUInt32LE(total, 8);
  const jh = Buffer.alloc(8); jh.writeUInt32LE(jb.length, 0); jh.write('JSON', 4, 'ascii');
  const bh = Buffer.alloc(8); bh.writeUInt32LE(bin.length, 0); bh.write('BIN\0', 4, 'ascii');
  fs.writeFileSync(file, Buffer.concat([h, jh, jb, bh, bin]));
  console.log('wrote', path.relative(process.cwd(), file), total, 'bytes,', parts.length, 'parts');
}
const out = path.join(__dirname, '..', 'assets', 'models', 'cake_slices.glb');
writeGlb(out);
// previews of the generated textures for checking
const dbg = path.join(__dirname, '..', 'build', 'cake_textures');
try { fs.mkdirSync(dbg, { recursive: true }); for (const [n, b] of Object.entries(TEX)) fs.writeFileSync(path.join(dbg, n + '.png'), b); } catch (e) { /* optional */ }
