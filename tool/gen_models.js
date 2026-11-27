// Generates the store's GLB models into assets/models/ :
//   service_counter, fridge_bay_36, fridge_bay_29, chef, gate, checkout_counter
//   and one geometry file per product kind in assets/models/products/.
// Run:  node tool/gen_models.js     (shelf_half.glb comes from gen_shelf_glb.js)
//
// Shapes follow three.js' own primitives (same vertex order and UV layout) so
// the printed product labels wrap exactly as they did before.
// Material names 'oak' / 'walnut' / 'shirt' / 'label' are swapped by the app.
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'assets', 'models');
fs.mkdirSync(path.join(OUT, 'products'), { recursive: true });

// ---------------------------------------------------------------- materials
const MATS = {};
function hex(c) { return [((c >> 16) & 255) / 255, ((c >> 8) & 255) / 255, (c & 255) / 255]; }
function mat(name, color, o = {}) {
  MATS[name] = { color, rough: o.rough ?? 0.75, metal: o.metal ?? 0, alpha: o.alpha ?? 1, emissive: o.emissive ?? null };
  return name;
}
function std(color, rough = 0.75, metal = 0) {
  const n = `c${color.toString(16).padStart(6, '0')}_${rough}_${metal}`;
  return MATS[n] ? n : mat(n, color, { rough, metal });
}
function glassMat(color, alpha) {
  const n = `glass${color.toString(16)}_${alpha}`;
  return MATS[n] ? n : mat(n, color, { rough: 0.1, alpha });
}
function glow(color) { // unlit look: black base + emissive
  const n = `glow${color.toString(16)}`;
  return MATS[n] ? n : mat(n, 0x000000, { rough: 1, emissive: color });
}
mat('oak', 0xBD8E58, { rough: 0.55 });
mat('walnut', 0x5A3D27, { rough: 0.6 });
mat('shirt', 0x5A1E2B);
mat('label', 0xFFFFFF, { rough: 0.5 });
mat('pot', 0x2B2E33, { rough: 0.4 });

// ---------------------------------------------------------------- geometry
class Geo { constructor() { this.p = []; this.uv = []; this.i = []; } get n() { return this.p.length / 3; } }

function buildPlane(g, u, v, w, udir, vdir, width, height, depth, gx, gy) {
  const off = g.n, sw = width / gx, sh = height / gy, wh = width / 2, hh = height / 2, dh = depth / 2;
  const gx1 = gx + 1;
  for (let iy = 0; iy <= gy; iy++) {
    const y = iy * sh - hh;
    for (let ix = 0; ix <= gx; ix++) {
      const x = ix * sw - wh;
      const vec = [0, 0, 0];
      vec[u] = x * udir; vec[v] = y * vdir; vec[w] = dh;
      g.p.push(...vec);
      g.uv.push(ix / gx, 1 - iy / gy);
    }
  }
  for (let iy = 0; iy < gy; iy++) for (let ix = 0; ix < gx; ix++) {
    const a = off + ix + gx1 * iy, b = off + ix + gx1 * (iy + 1), c = off + (ix + 1) + gx1 * (iy + 1), d = off + (ix + 1) + gx1 * iy;
    g.i.push(a, b, d, b, c, d);
  }
}
function box(w, h, d, ws = 1, hs = 1, ds = 1) {
  const g = new Geo();
  buildPlane(g, 2, 1, 0, -1, -1, d, h, w, ds, hs);
  buildPlane(g, 2, 1, 0, 1, -1, d, h, -w, ds, hs);
  buildPlane(g, 0, 2, 1, 1, 1, w, d, h, ws, ds);
  buildPlane(g, 0, 2, 1, 1, -1, w, d, -h, ws, ds);
  buildPlane(g, 0, 1, 2, 1, -1, w, h, d, ws, hs);
  buildPlane(g, 0, 1, 2, -1, -1, w, h, -d, ws, hs);
  return g;
}
function plane(w, h) {
  const g = new Geo();
  g.p.push(-w / 2, h / 2, 0, w / 2, h / 2, 0, -w / 2, -h / 2, 0, w / 2, -h / 2, 0);
  g.uv.push(0, 1, 1, 1, 0, 0, 1, 0);
  g.i.push(0, 2, 1, 2, 3, 1);
  return g;
}
function cyl(rt, rb, h, seg = 14, hs = 1, open = false) {
  const g = new Geo();
  const grid = [];
  for (let y = 0; y <= hs; y++) {
    const row = [], v = y / hs, r = v * (rb - rt) + rt;
    for (let x = 0; x <= seg; x++) {
      const u = x / seg, th = u * Math.PI * 2;
      row.push(g.n);
      g.p.push(r * Math.sin(th), -v * h + h / 2, r * Math.cos(th));
      g.uv.push(u, 1 - v);
    }
    grid.push(row);
  }
  for (let x = 0; x < seg; x++) for (let y = 0; y < hs; y++) {
    const a = grid[y][x], b = grid[y + 1][x], c = grid[y + 1][x + 1], d = grid[y][x + 1];
    if (rt > 0 || y !== 0) g.i.push(a, b, d);
    if (rb > 0 || y !== hs - 1) g.i.push(b, c, d);
  }
  if (!open) for (const top of [true, false]) {
    const r = top ? rt : rb;
    if (r <= 0) continue;
    const sign = top ? 1 : -1, y = (h / 2) * sign, start = g.n;
    g.p.push(0, y, 0); g.uv.push(0.5, 0.5);
    for (let x = 0; x <= seg; x++) {
      const th = (x / seg) * Math.PI * 2;
      g.p.push(r * Math.sin(th), y, r * Math.cos(th));
      g.uv.push(Math.cos(th) * 0.5 + 0.5, Math.sin(th) * 0.5 * sign + 0.5);
    }
    for (let x = 1; x <= seg; x++) {
      if (top) g.i.push(start + x, start + x + 1, start);
      else g.i.push(start + x + 1, start + x, start);
    }
  }
  return g;
}
function sphere(r, seg = 14) {
  const ws = seg, hs = Math.floor(seg / 2) + 2, g = new Geo(), grid = [];
  for (let iy = 0; iy <= hs; iy++) {
    const row = [], v = iy / hs;
    for (let ix = 0; ix <= ws; ix++) {
      const u = ix / ws, phi = u * Math.PI * 2, th = v * Math.PI;
      row.push(g.n);
      g.p.push(-r * Math.cos(phi) * Math.sin(th), r * Math.cos(th), r * Math.sin(phi) * Math.sin(th));
      g.uv.push(u, 1 - v);
    }
    grid.push(row);
  }
  for (let iy = 0; iy < hs; iy++) for (let ix = 0; ix < ws; ix++) {
    const a = grid[iy][ix + 1], b = grid[iy][ix], c = grid[iy + 1][ix], d = grid[iy + 1][ix + 1];
    if (iy !== 0) g.i.push(a, b, d);
    if (iy !== hs - 1) g.i.push(b, c, d);
  }
  return g;
}
function torus(R, tube, rs, ts, arc = Math.PI * 2) {
  const g = new Geo();
  for (let j = 0; j <= rs; j++) for (let i = 0; i <= ts; i++) {
    const u = (i / ts) * arc, v = (j / rs) * Math.PI * 2;
    g.p.push((R + tube * Math.cos(v)) * Math.cos(u), (R + tube * Math.cos(v)) * Math.sin(u), tube * Math.sin(v));
    g.uv.push(i / ts, j / rs);
  }
  for (let j = 1; j <= rs; j++) for (let i = 1; i <= ts; i++) {
    const a = (ts + 1) * j + i - 1, b = (ts + 1) * (j - 1) + i - 1, c = (ts + 1) * (j - 1) + i, d = (ts + 1) * j + i;
    g.i.push(a, b, d, b, c, d);
  }
  return g;
}
function lathe(h, rf, n = 28, seg = 28) {
  const pts = [[0.0001, -h / 2]];
  for (let i = 0; i <= n; i++) { const t = i / n; pts.push([Math.max(rf(t), 0.0005), -h / 2 + t * h]); }
  pts.push([0.0001, h / 2]);
  const g = new Geo(), L = pts.length;
  for (let i = 0; i <= seg; i++) {
    const phi = (i / seg) * Math.PI * 2, s = Math.sin(phi), c = Math.cos(phi);
    for (let j = 0; j < L; j++) { g.p.push(pts[j][0] * s, pts[j][1], pts[j][0] * c); g.uv.push(i / seg, j / (L - 1)); }
  }
  for (let i = 0; i < seg; i++) for (let j = 0; j < L - 1; j++) {
    const base = j + i * L, a = base, b = base + L, c = base + L + 1, d = base + 1;
    g.i.push(a, b, d, c, d, b);
  }
  return g;
}
// in-place vertex transforms (baked, like three's rotateX etc.)
function rotX(g, a) { const c = Math.cos(a), s = Math.sin(a); for (let k = 0; k < g.p.length; k += 3) { const y = g.p[k + 1], z = g.p[k + 2]; g.p[k + 1] = y * c - z * s; g.p[k + 2] = y * s + z * c; } return g; }
function rotY(g, a) { const c = Math.cos(a), s = Math.sin(a); for (let k = 0; k < g.p.length; k += 3) { const x = g.p[k], z = g.p[k + 2]; g.p[k] = x * c + z * s; g.p[k + 2] = -x * s + z * c; } return g; }
function rotZ(g, a) { const c = Math.cos(a), s = Math.sin(a); for (let k = 0; k < g.p.length; k += 3) { const x = g.p[k], y = g.p[k + 1]; g.p[k] = x * c - y * s; g.p[k + 1] = x * s + y * c; } return g; }
function move(g, x, y, z) { for (let k = 0; k < g.p.length; k += 3) { g.p[k] += x; g.p[k + 1] += y; g.p[k + 2] += z; } return g; }
function deform(g, f) { for (let k = 0; k < g.p.length; k += 3) { const v = f(g.p[k], g.p[k + 1], g.p[k + 2]); g.p[k] = v[0]; g.p[k + 1] = v[1]; g.p[k + 2] = v[2]; } return g; }

function normals(g) {
  const nrm = new Float64Array(g.p.length);
  for (let t = 0; t < g.i.length; t += 3) {
    const [a, b, c] = [g.i[t] * 3, g.i[t + 1] * 3, g.i[t + 2] * 3];
    const ux = g.p[b] - g.p[a], uy = g.p[b + 1] - g.p[a + 1], uz = g.p[b + 2] - g.p[a + 2];
    const vx = g.p[c] - g.p[a], vy = g.p[c + 1] - g.p[a + 1], vz = g.p[c + 2] - g.p[a + 2];
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    for (const k of [a, b, c]) { nrm[k] += nx; nrm[k + 1] += ny; nrm[k + 2] += nz; }
  }
  for (let k = 0; k < nrm.length; k += 3) {
    const l = Math.hypot(nrm[k], nrm[k + 1], nrm[k + 2]) || 1;
    nrm[k] /= l; nrm[k + 1] /= l; nrm[k + 2] /= l;
  }
  return nrm;
}

// ---------------------------------------------------------------- scene graph
class Node {
  constructor(name, t) { this.name = name; this.t = t || null; this.kids = []; this.prims = []; }
  add(child) { this.kids.push(child); return child; }
  // matName, geometry, position, optional mesh/node name (e.g. 'glass')
  put(m, g, x = 0, y = 0, z = 0, name) { move(g, x, y, z); this.prims.push({ m, g, name: name || m }); return this; }
}

function writeGlb(file, root) {
  const chunks = [], bufferViews = [], accessors = [], meshes = [], materials = [], nodes = [];
  let offset = 0;
  const matIndex = {};
  function push(buf, target) {
    const pad = (4 - (buf.length % 4)) % 4;
    const view = { buffer: 0, byteOffset: offset, byteLength: buf.length };
    if (target) view.target = target;
    bufferViews.push(view);
    chunks.push(buf, Buffer.alloc(pad));
    offset += buf.length + pad;
    return bufferViews.length - 1;
  }
  function useMat(name) {
    if (matIndex[name] !== undefined) return matIndex[name];
    const m = MATS[name];
    if (!m) throw new Error('no material ' + name);
    const def = { name, pbrMetallicRoughness: { baseColorFactor: [...hex(m.color), m.alpha], metallicFactor: m.metal, roughnessFactor: m.rough } };
    if (m.alpha < 1) def.alphaMode = 'BLEND';
    if (m.emissive !== null) def.emissiveFactor = hex(m.emissive);
    materials.push(def);
    return (matIndex[name] = materials.length - 1);
  }
  function emit(node) {
    const idx = nodes.length;
    const def = { name: node.name };
    nodes.push(def);
    if (node.t) def.translation = node.t;
    const kids = [];
    // merge prims sharing material + name into one mesh
    const groups = {};
    for (const p of node.prims) (groups[p.m + '|' + p.name] ||= { m: p.m, name: p.name, parts: [] }).parts.push(p.g);
    for (const gr of Object.values(groups)) {
      const merged = new Geo();
      for (const g of gr.parts) {
        const base = merged.n;
        merged.p.push(...g.p); merged.uv.push(...g.uv);
        for (const k of g.i) merged.i.push(k + base);
      }
      const nrm = normals(merged);
      const pos = Float32Array.from(merged.p);
      const min = [1e9, 1e9, 1e9], max = [-1e9, -1e9, -1e9];
      for (let k = 0; k < pos.length; k += 3) for (let c = 0; c < 3; c++) { min[c] = Math.min(min[c], pos[k + c]); max[c] = Math.max(max[c], pos[k + c]); }
      const big = merged.n > 65535;
      const vp = push(Buffer.from(pos.buffer), 34962);
      const vn = push(Buffer.from(Float32Array.from(nrm).buffer), 34962);
      const vt = push(Buffer.from(Float32Array.from(merged.uv).buffer), 34962);
      const vi = push(Buffer.from((big ? Uint32Array : Uint16Array).from(merged.i).buffer), 34963);
      const a = accessors.length;
      accessors.push(
        { bufferView: vp, componentType: 5126, count: merged.n, type: 'VEC3', min, max },
        { bufferView: vn, componentType: 5126, count: merged.n, type: 'VEC3' },
        { bufferView: vt, componentType: 5126, count: merged.n, type: 'VEC2' },
        { bufferView: vi, componentType: big ? 5125 : 5123, count: merged.i.length, type: 'SCALAR' },
      );
      meshes.push({ name: gr.name, primitives: [{ attributes: { POSITION: a, NORMAL: a + 1, TEXCOORD_0: a + 2 }, indices: a + 3, material: useMat(gr.m) }] });
      kids.push(nodes.length);
      nodes.push({ name: gr.name, mesh: meshes.length - 1 });
    }
    for (const k of node.kids) kids.push(emit(k));
    if (kids.length) def.children = kids;
    return idx;
  }
  emit(root);
  const json = { asset: { version: '2.0', generator: 'tool/gen_models.js' }, scene: 0, scenes: [{ nodes: [0] }], nodes, meshes, materials, accessors, bufferViews, buffers: [{ byteLength: offset }] };
  let jb = Buffer.from(JSON.stringify(json));
  jb = Buffer.concat([jb, Buffer.alloc((4 - (jb.length % 4)) % 4, 0x20)]);
  const bin = Buffer.concat(chunks);
  const total = 12 + 8 + jb.length + 8 + bin.length;
  const h = Buffer.alloc(12); h.write('glTF', 0, 'ascii'); h.writeUInt32LE(2, 4); h.writeUInt32LE(total, 8);
  const jh = Buffer.alloc(8); jh.writeUInt32LE(jb.length, 0); jh.write('JSON', 4, 'ascii');
  const bh = Buffer.alloc(8); bh.writeUInt32LE(bin.length, 0); bh.write('BIN\0', 4, 'ascii');
  fs.writeFileSync(file, Buffer.concat([h, jh, jb, bh, bin]));
  console.log('wrote', path.relative(process.cwd(), file), total, 'bytes');
}

// ---------------------------------------------------------------- constants
const BACK_Z = -12, FRONT_Z = 6, HALF_GATE = 2;
const C = { fridge: 0x2B2E33, brass: 0xC9A24A, lamp: 0xFFD9A0, glass: 0xB7DCEB, metalBlack: 0x23262A, doorFrame: 0x23262A, skin: 0xE8B796, doorSilver: 0xCDD2D8 };
const CAT = [0xEC6FA1, 0xF2662C, 0x2D9CDB, 0xF2B01E, 0x3BB273, 0x8E6CEF, 0xFFFFFF, 0xE8E0D2];

// ---------------------------------------------------------------- fridge bay
// built facing +z with its back panel at z = 0 and centred on x = 0
function fridgeBay(width) {
  const root = new Node('fridge_bay');
  const body = std(C.fridge, 0.5), glass = glassMat(C.glass, 0.16), brass = std(C.brass, 0.25, 0.8), led = glow(C.lamp);
  root.put(body, box(width, 2.9, 0.05), 0, 1.45, 0.03);
  for (const s of [-1, 1]) root.put(body, box(0.06, 2.9, 0.95), s * (width / 2 - 0.03), 1.45, 0.5);
  root.put(body, box(width, 0.3, 0.95), 0, 0.15, 0.5);
  root.put('oak', box(width, 0.25, 0.95), 0, 2.85, 0.5);
  root.put(led, box(width - 0.2, 0.05, 0.05), 0, 2.68, 0.95);
  for (const y of [0.45, 1.05, 1.65, 2.25]) {
    root.put('oak', box(width - 0.12, 0.03, 0.9), 0, y, 0.5);
    let x = -width / 2 + 0.25, i = 0;
    while (x < width / 2 - 0.25) {
      const h = 0.26 + (Math.floor(i * 7 + y * 13) % 3) * 0.05;
      const col = CAT[(i + Math.floor(y * 10)) % CAT.length];
      root.put(std(col, 0.5), box(0.13, h, 0.2), x, y + 0.015 + h / 2, 0.78);
      x += 0.17; i++;
    }
  }
  root.put(glass, box(width - 0.1, 2.5, 0.03), 0, 1.5, 1.0, 'glass');
  for (const s of [-0.55, 0.55]) root.put(brass, box(0.04, 1.0, 0.06), s * (width / 3.6), 1.5, 1.05);
  return root;
}

// ---------------------------------------------------------------- chef
function chef() {
  const root = new Node('chef');
  root.put('shirt', box(0.5, 0.65, 0.3), 0, 0, 0);
  root.put(std(C.skin, 0.75), sphere(0.13), 0, 0.47, 0);
  root.put(std(0xF4F4F2, 0.75), cyl(0.14, 0.15, 0.14, 12), 0, 0.64, 0);
  return root;
}

// ---------------------------------------------------------------- gate (world coordinates)
function gate() {
  const root = new Node('gate_model');
  const frame = std(C.doorFrame, 0.4, 0.4), glass = glassMat(C.glass, 0.3), brass = std(C.brass, 0.25, 0.8);
  const z = FRONT_Z + 0.15;
  for (const s of [-1, 1]) root.put(frame, box(0.3, 3.4, 0.55), s * (HALF_GATE + 0.15), 1.7, z);
  root.put(frame, box(HALF_GATE * 2 + 0.6, 0.35, 0.55), 0, 3.55, z);
  root.put('walnut', box(6.2, 1.5, 0.22), 0, 5.3, FRONT_Z + 0.3);
  for (const hinge of [-1, 1]) {
    const name = hinge < 0 ? 'Left' : 'Right';
    const pivot = root.add(new Node('door' + name, [hinge * HALF_GATE, 0, z]));
    const panel = pivot.add(new Node('panel' + name, [-hinge * 1.0, 0, 0]));
    panel.put(glass, box(1.9, 3.1, 0.03), 0, 1.7, 0, 'doorglass');
    panel.put(frame, box(2.0, 0.12, 0.08), 0, 0.1, 0);
    panel.put(frame, box(2.0, 0.12, 0.08), 0, 3.3, 0);
    for (const sx of [-0.95, 0.95]) panel.put(frame, box(0.1, 3.3, 0.08), sx, 1.65, 0);
    for (const hz of [0.1, -0.1]) panel.put(brass, cyl(0.02, 0.02, 1.0, 10), -hinge * 0.78, 1.2, hz);
  }
  return root;
}

// ---------------------------------------------------------------- checkout counter (world coordinates)
function checkout() {
  const root = new Node('checkout_counter');
  root.put('walnut', box(3.0, 1.0, 1.0), 7.0, 0.5, 3.6);
  root.put('oak', box(3.2, 0.06, 1.2), 7.0, 1.03, 3.6);
  root.put(std(0x1E2125), box(1.4, 0.04, 0.5), 6.5, 1.08, 3.6);
  root.put(std(0x111315), box(0.35, 0.28, 0.04), 7.8, 1.3, 3.4);
  root.put(std(C.doorSilver), box(0.06, 0.2, 0.06), 7.8, 1.17, 3.4);
  return root;
}

// ---------------------------------------------------------------- service counter island (world coordinates)
function serviceCounter() {
  const root = new Node('service_counter');
  const zBack = BACK_Z, cz = zBack + 0.95, depth = 1.5, front = cz + depth / 2, baseH = 0.85, cabW = 3.0, midW = 1.2;
  const cabCx = midW / 2 + cabW / 2, half = midW / 2 + cabW;
  const cream = std(0xEFE2C8, 0.8), creamDark = std(0xDCC9A6, 0.8), black = std(0x14161A, 0.35, 0.4), steel = std(0xC9CDD2, 0.3, 0.8);
  const glass = glassMat(C.glass, 0.12);
  for (const side of [-1, 1]) {
    root.put(creamDark, box(cabW, baseH - 0.05, depth - 0.06), side * cabCx, (baseH - 0.05) / 2, cz);
    for (let i = 0; i < 20; i++) {
      const x = side * cabCx - cabW / 2 + 0.075 + i * (cabW - 0.15) / 19;
      root.put(cream, box(0.06, baseH - 0.05, 0.05), x, (baseH - 0.05) / 2, front + 0.02);
    }
  }
  root.put(creamDark, box(midW, 1.25, depth), 0, 0.625, cz);
  for (let i = 0; i < 12; i++) root.put(cream, box(0.06, 1.2, 0.05), -midW / 2 + 0.06 + i * (midW - 0.12) / 11, 0.62, front + 0.03);
  root.put(cream, box(midW + 0.1, 0.05, depth + 0.1), 0, 1.275, cz);
  const shelfYs = [0.98, 1.3, 1.62];
  for (const side of [-1, 1]) {
    const cx = side * cabCx, top = baseH + 1.12;
    root.put(black, box(cabW, 0.05, depth), cx, baseH + 0.025, cz);
    root.put(black, box(cabW, 0.05, depth + 0.06), cx, top + 0.025, cz);
    for (const sx of [-1, 1]) {
      root.put(black, box(0.05, 1.12, 0.05), cx + sx * (cabW / 2 - 0.025), baseH + 0.56, front - 0.03);
      root.put(glass, box(0.03, 1.12, depth - 0.1), cx + sx * (cabW / 2 - 0.02), baseH + 0.56, cz, 'glass');
    }
    root.put(std(0xE9E4DA, 0.6), box(cabW - 0.1, 0.9, 0.04), cx, baseH + 0.6, zBack + 0.35);
    for (const y of shelfYs) root.put(steel, box(cabW - 0.1, 0.025, depth - 0.2), cx, y, cz - 0.02);
    root.put(glass, box(cabW - 0.1, 1.07, 0.025), cx, baseH + 0.575, front - 0.03, 'glass');
  }
  // kitchen pass window
  const wz = zBack + 0.07;
  root.put(std(0xE4E0D8), box(7.4, 1.3, 0.04), 0, 2.3, zBack + 0.03);
  for (const y of [1.62, 2.98]) root.put(black, box(7.6, 0.1, 0.1), 0, y, wz);
  for (const x of [-3.75, 3.75]) root.put(black, box(0.1, 1.46, 0.1), x, 2.3, wz);
  root.put(steel, box(7.2, 0.05, 0.5), 0, 1.7, zBack + 0.3);
  root.put(std(0x2A2D31, 0.75, 0.4), box(0.45, 0.25, 0.3), 2.4, 1.85, zBack + 0.35);
  // frosted side windows
  const frost = glassMat(0xDCE6EA, 0.55);
  for (const s of [-1, 1]) {
    const x = s * 4.7;
    root.put(frost, box(1.8, 1.8, 0.03), x, 1.85, zBack + 0.05, 'glass');
    for (const y of [0.93, 2.77]) root.put(black, box(1.9, 0.08, 0.08), x, y, zBack + 0.06);
    for (const dx of [-0.95, 0.95]) root.put(black, box(0.08, 1.9, 0.08), x + dx, 1.85, zBack + 0.06);
  }
  // menu screen frames (the printed screens stay in code)
  for (let i = 0; i < 4; i++) root.put(black, box(1.58, 0.92, 0.05), -2.445 + i * 1.63, 3.78, zBack + 0.1);
  return root;
}

// ---------------------------------------------------------------- plant (pot + 16 leaves, unit size)
function scaleG(g, sx, sy, sz) { for (let k = 0; k < g.p.length; k += 3) { g.p[k] *= sx; g.p[k + 1] *= sy; g.p[k + 2] *= sz; } return g; }
function plant() {
  const root = new Node('plant');
  const soil = std(0x3A2A1E, 1);
  root.put('pot', cyl(0.26, 0.19, 0.5, 16), 0, 0.25, 0);
  root.put(soil, cyl(0.25, 0.25, 0.02, 16), 0, 0.5, 0);
  root.put('pot', rotX(torus(0.25, 0.018, 8, 18), PI / 2), 0, 0.5, 0);
  const greens = [0x2F6B34, 0x3E8A43, 0x4F9E4B, 0x2A5E32];
  for (let i = 0; i < 16; i++) {
    const seed = i + 1, r = Math.abs(Math.sin(seed * 12.9898) * 43758.5453) % 1;
    const yaw = i * 2.39996, tilt = 0.18 + (i % 4) * 0.16 + r * 0.1, len = 0.55 + r * 0.45 + (i % 3) * 0.12;
    const g = scaleG(sphere(1, 10), 0.075, len / 2, 0.02);
    move(g, 0, len / 2, 0); rotX(g, tilt); rotY(g, yaw);
    root.put(std(greens[i % 4], 0.6), g, 0, 0.5, 0, 'leaf');
  }
  return root;
}

// ---------------------------------------------------------------- outside: one file per object
function outsideGround() {
  const root = new Node('outside_ground');
  const flat = (w, h, y, z, color, rough) => root.put(std(color, rough), move(rotX(plane(w, h), -PI / 2), 0, y, z), 0, 0, 0, 'ground');
  flat(160, 160, -0.03, 0, 0x6E9C62, 1);
  flat(30, 16, -0.01, 15, 0xB5AEA2, 0.9);
  flat(5, 16, 0.0, 14, 0x8F8A82, 0.9);
  return root;
}
// a tree with its base at the origin
function tree() {
  const root = new Node('tree');
  root.put(std(0x6B4B2E, 0.75), cyl(0.22, 0.28, 2.4), 0, 1.2, 0);
  root.put(std(0x3E7D3F, 1), sphere(1.5, 12), 0, 3.3, 0);
  root.put(std(0x4A8B49, 1), sphere(1.1, 12), 0.5, 4.2, -0.3);
  root.put(std(0x366F38, 1), sphere(0.9, 12), -0.6, 3.9, 0.4);
  return root;
}
// wooden planter with shrubs, base centred on the origin
function planter() {
  const root = new Node('planter');
  root.put('walnut', box(1.2, 0.6, 1.2), 0, 0.3, 0);
  for (const [ox, oz, r] of [[0, 0, 0.5], [-0.3, 0.1, 0.38], [0.3, -0.1, 0.4]]) root.put(std(0x3E7D3F, 1), sphere(r, 10), ox, 0.85 + r * 0.5, oz);
  return root;
}
// park bench facing +z, seat on the floor at the origin
function bench() {
  const root = new Node('bench');
  const iron = std(0x23262A, 0.45, 0.5);
  for (const z of [-0.17, 0, 0.17]) root.put('walnut', box(1.6, 0.04, 0.14), 0, 0.45, z);
  for (const y of [0.68, 0.84]) root.put('walnut', box(1.6, 0.12, 0.03), 0, y, -0.27);
  for (const x of [-0.72, 0.72]) {
    root.put(iron, box(0.05, 0.45, 0.5), x, 0.225, 0);
    root.put(iron, box(0.05, 0.5, 0.05), x, 0.7, -0.27);
    root.put(iron, box(0.05, 0.05, 0.5), x, 0.62, 0);
  }
  return root;
}
// one ceiling pendant with its attach point at the origin; the bulb is its own
// mesh named 'bulb' so each lamp can switch its glow on and off
function lamp() {
  const root = new Node('lamp');
  root.put(std(C.metalBlack, 0.75), cyl(0.008, 0.008, 0.9, 6), 0, -0.45, 0, 'cord');
  root.put(std(C.metalBlack, 0.5, 0.4), cyl(0.1, 0.3, 0.26, 18), 0, -0.98, 0, 'shade');
  root.put(glow(C.lamp), sphere(0.09, 10), 0, -1.06, 0, 'bulb');
  return root;
}

// copper cone pendant over the service counter, attach point at the origin (own file so it can switch on/off)
function counterLamp() {
  const root = new Node('counter_lamp');
  root.put(std(0x14161A, 0.35, 0.4), cyl(0.008, 0.008, 1.3, 6), 0, -0.65, 0, 'cord');
  root.put(std(0xB87333, 0.3, 0.85), cyl(0.05, 0.22, 0.4, 18), 0, -1.5, 0, 'shade');
  root.put(glow(C.lamp), sphere(0.07, 10), 0, -1.68, 0, 'bulb');
  return root;
}

// ---------------------------------------------------------------- products (geometry only)
const PI = Math.PI, sm = (t) => t * t * (3 - 2 * t);
const PRODUCTS = {
  bottle: () => lathe(0.42, (t) => { const r = 0.062; if (t < 0.05) return r * (0.78 + 0.22 * (t / 0.05)); if (t < 0.6) return r; if (t < 0.76) return r + (0.026 - r) * sm((t - 0.6) / 0.16); if (t < 0.9) return 0.026; if (t < 0.995) return 0.032; return 0.02; }),
  can: () => lathe(0.2, (t) => { const r = 0.05; if (t < 0.03) return r * (0.88 + 0.12 * (t / 0.03)); if (t > 0.96) return r * (0.88 + 0.12 * ((1 - t) / 0.04)); return r; }),
  cup: () => lathe(0.24, (t) => { if (t < 0.84) return 0.045 + (0.068 - 0.045) * (t / 0.84); if (t < 0.88) return 0.074; const u = (t - 0.88) / 0.12; return 0.012 + 0.06 * Math.sqrt(Math.max(0, 1 - u * u)); }),
  tub: () => lathe(0.14, (t) => { if (t < 0.8) return 0.075 + 0.015 * (t / 0.8); if (t < 0.86) return 0.098; return 0.095; }),
  iceCream: () => lathe(0.16, (t) => { if (t < 0.8) return 0.085 + 0.017 * (t / 0.8); if (t < 0.86) return 0.112; return 0.108; }),
  cake: () => lathe(0.12, (t) => { const r = 0.15; if (t < 0.04) return r * (0.92 + 0.08 * (t / 0.04)); if (t > 0.96) return r * 0.97; return r; }),
  cupcake: () => lathe(0.13, (t) => { if (t < 0.42) return 0.042 + 0.02 * (t / 0.42); const u = (t - 0.42) / 0.58; return 0.078 * Math.sqrt(Math.max(0, 1 - u * u)); }),
  burger: () => lathe(0.16, (t) => { if (t < 0.22) return 0.11 + 0.018 * (t / 0.22); if (t < 0.42) return 0.135; if (t < 0.47) return 0.14; if (t < 0.6) return 0.14 + 0.008 * Math.sin(t * 120); const u = (t - 0.6) / 0.4; return 0.13 * Math.sqrt(Math.max(0, 1 - Math.pow(u, 2.2))); }, 40),
  pizza: () => rotX(cyl(0.25, 0.25, 0.03, 32), PI / 2),
  donut: () => rotX(torus(0.1, 0.045, 12, 24), PI / 2),
  bun: () => move(rotZ(torus(0.09, 0.04, 10, 20, PI * 1.2), -PI * 0.1), 0, -0.03, 0),
  sandwich: () => move(rotZ(rotX(cyl(0.19, 0.19, 0.1, 3), PI / 2), PI), 0, -0.0475, 0),
  chips: () => { const w = 0.27, h = 0.4, d = 0.08; return deform(box(w, h, d, 6, 14, 2), (x, y, z) => { const ny = y / (h / 2), bulge = 1 - ny * ny; return [x * (1 - 0.06 * Math.pow(Math.abs(ny), 4)), y, z * (0.22 + 0.78 * bulge)]; }); },
  carton: () => { const h = 0.34; return deform(box(0.12, h, 0.09, 1, 5, 1), (x, y, z) => { const roof = y - 0.3 * h; if (roof <= 0) return [x, y, z]; const t = Math.min(1, Math.max(0, roof / (0.2 * h))); return [x, y, z * (1 - t)]; }); },
  bar: () => box(0.17, 0.3, 0.05),
  fruit: () => sphere(0.075, 14),
  banana: () => move(rotZ(torus(0.11, 0.024, 8, 14, PI * 0.7), -PI * 0.85), 0, 0.08, 0),
};

// ---------------------------------------------------------------- write everything
writeGlb(path.join(OUT, 'service_counter.glb'), serviceCounter());
writeGlb(path.join(OUT, 'fridge_bay_36.glb'), fridgeBay(3.6));
writeGlb(path.join(OUT, 'fridge_bay_29.glb'), fridgeBay(2.9));
writeGlb(path.join(OUT, 'chef.glb'), chef());
writeGlb(path.join(OUT, 'gate.glb'), gate());
writeGlb(path.join(OUT, 'checkout_counter.glb'), checkout());
writeGlb(path.join(OUT, 'plant.glb'), plant());
writeGlb(path.join(OUT, 'outside_ground.glb'), outsideGround());
writeGlb(path.join(OUT, 'tree.glb'), tree());
writeGlb(path.join(OUT, 'planter.glb'), planter());
writeGlb(path.join(OUT, 'bench.glb'), bench());
writeGlb(path.join(OUT, 'lamp.glb'), lamp());
writeGlb(path.join(OUT, 'counter_lamp.glb'), counterLamp());
for (const [kind, make] of Object.entries(PRODUCTS)) {
  const root = new Node('product_' + kind);
  root.put('label', make(), 0, 0, 0, 'product');
  writeGlb(path.join(OUT, 'products', kind + '.glb'), root);
}
