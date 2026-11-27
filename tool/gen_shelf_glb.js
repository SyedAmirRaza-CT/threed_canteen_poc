// Generates assets/models/shelf_half.glb: one face of the store's wooden
// gondola shelf (face looks toward +x, the back panel is at x = 0, length runs
// along z and is centred on 0). Two of them back to back make a double sided
// aisle unit. Run:  node tool/gen_shelf_glb.js
//
// Materials are only named (oak, walnut, metal, band); the app swaps in its own
// wood textures and the category colour when it loads the file.
const fs = require('fs');
const path = require('path');

const D = 0.6; // SceneConfig.shelfDepth
const H = 3.4; // SceneConfig.shelfHeight
const L = 5.4; // shelfZEnd - shelfZStart
const LEVELS = [0.45, 1.1, 1.75, 2.4]; // SceneConfig.boardHeights

const mats = {
  oak: { color: [0.74, 0.56, 0.35], rough: 0.55, metal: 0 },
  walnut: { color: [0.35, 0.24, 0.15], rough: 0.6, metal: 0 },
  metal: { color: [0.14, 0.15, 0.16], rough: 0.4, metal: 0.5 },
  band: { color: [1, 1, 1], rough: 0.7, metal: 0 },
};
const groups = {};
for (const k of Object.keys(mats)) groups[k] = { p: [], n: [], t: [], i: [] };

// face: normal, then 4 corners (CCW seen from outside)
function box(mat, cx, cy, cz, sx, sy, sz) {
  const g = groups[mat];
  const x = sx / 2, y = sy / 2, z = sz / 2;
  const faces = [
    [[1, 0, 0], [x, -y, z], [x, -y, -z], [x, y, -z], [x, y, z]],
    [[-1, 0, 0], [-x, -y, -z], [-x, -y, z], [-x, y, z], [-x, y, -z]],
    [[0, 1, 0], [-x, y, z], [x, y, z], [x, y, -z], [-x, y, -z]],
    [[0, -1, 0], [-x, -y, -z], [x, -y, -z], [x, -y, z], [-x, -y, z]],
    [[0, 0, 1], [-x, -y, z], [x, -y, z], [x, y, z], [-x, y, z]],
    [[0, 0, -1], [x, -y, -z], [-x, -y, -z], [-x, y, -z], [x, y, -z]],
  ];
  const uv = [[0, 0], [1, 0], [1, 1], [0, 1]];
  for (const f of faces) {
    const base = g.p.length / 3;
    for (let c = 0; c < 4; c++) {
      const v = f[c + 1];
      g.p.push(cx + v[0], cy + v[1], cz + v[2]);
      g.n.push(...f[0]);
      g.t.push(...uv[c]);
    }
    g.i.push(base, base + 1, base + 2, base, base + 2, base + 3);
  }
}

// back panel, posts, base, top
box('walnut', 0.02, H / 2, 0, 0.04, H, L);
for (const z of [-L / 2, 0, L / 2]) box('metal', 0.025, H / 2, z, 0.05, H, 0.07);
box('walnut', (D + 0.02) / 2, 0.11, 0, D + 0.02, 0.22, L + 0.04);
box('oak', (D + 0.02) / 2, H, 0, D + 0.02, 0.08, L + 0.08);
// boards, front lips, dark price-tag rails
for (const lv of LEVELS) {
  box('oak', D / 2, lv, 0, D, 0.04, L);
  box('oak', D - 0.015, lv + 0.025, 0, 0.03, 0.04, L);
  box('metal', D + 0.005, lv - 0.05, 0, 0.02, 0.1, L - 0.06);
}
// end caps with a band that the app tints per category
for (const z of [-L / 2, L / 2]) {
  box('oak', D / 2, H / 2, z, D, H, 0.08);
  box('band', D / 2, H - 0.35, z, D + 0.01, 0.35, 0.09);
}

// header board with a category-colour stripe (the printed name plane stays in code)
box('walnut', 0.1, H + 0.55, 0, 0.1, 0.95, 4.1);
box('band', 0.1, H + 0.12, 0, 0.11, 0.1, 4.1);

// ---- pack into a binary glTF ------------------------------------------------
const chunks = [];
let offset = 0;
const bufferViews = [], accessors = [], meshes = [], nodes = [], materials = [];
function push(buf, target) {
  const pad = (4 - (buf.length % 4)) % 4;
  const view = { buffer: 0, byteOffset: offset, byteLength: buf.length };
  if (target) view.target = target;
  bufferViews.push(view);
  chunks.push(buf, Buffer.alloc(pad));
  offset += buf.length + pad;
  return bufferViews.length - 1;
}
for (const [name, g] of Object.entries(groups)) {
  const pos = Float32Array.from(g.p);
  let min = [1e9, 1e9, 1e9], max = [-1e9, -1e9, -1e9];
  for (let i = 0; i < pos.length; i += 3) {
    for (let k = 0; k < 3; k++) {
      min[k] = Math.min(min[k], pos[i + k]);
      max[k] = Math.max(max[k], pos[i + k]);
    }
  }
  const vp = push(Buffer.from(pos.buffer), 34962);
  const vn = push(Buffer.from(Float32Array.from(g.n).buffer), 34962);
  const vt = push(Buffer.from(Float32Array.from(g.t).buffer), 34962);
  const vi = push(Buffer.from(Uint16Array.from(g.i).buffer), 34963);
  const a = accessors.length;
  accessors.push(
    { bufferView: vp, componentType: 5126, count: pos.length / 3, type: 'VEC3', min, max },
    { bufferView: vn, componentType: 5126, count: pos.length / 3, type: 'VEC3' },
    { bufferView: vt, componentType: 5126, count: pos.length / 3, type: 'VEC2' },
    { bufferView: vi, componentType: 5123, count: g.i.length, type: 'SCALAR' },
  );
  const m = mats[name];
  materials.push({
    name,
    pbrMetallicRoughness: { baseColorFactor: [...m.color, 1], metallicFactor: m.metal, roughnessFactor: m.rough },
  });
  meshes.push({
    name,
    primitives: [{ attributes: { POSITION: a, NORMAL: a + 1, TEXCOORD_0: a + 2 }, indices: a + 3, material: materials.length - 1 }],
  });
  nodes.push({ name, mesh: meshes.length - 1 });
}
const json = {
  asset: { version: '2.0', generator: 'tool/gen_shelf_glb.js' },
  scene: 0,
  scenes: [{ nodes: nodes.map((_, i) => i + 1) }],
  nodes: [{ name: 'shelf_half' }, ...nodes],
  meshes, materials, accessors, bufferViews,
  buffers: [{ byteLength: offset }],
};
// make node 0 the parent of the parts
json.nodes[0].children = nodes.map((_, i) => i + 1);
json.scenes = [{ nodes: [0] }];

let jsonBuf = Buffer.from(JSON.stringify(json));
jsonBuf = Buffer.concat([jsonBuf, Buffer.alloc((4 - (jsonBuf.length % 4)) % 4, 0x20)]);
const bin = Buffer.concat(chunks);
const total = 12 + 8 + jsonBuf.length + 8 + bin.length;
const header = Buffer.alloc(12);
header.write('glTF', 0, 'ascii');
header.writeUInt32LE(2, 4);
header.writeUInt32LE(total, 8);
const jh = Buffer.alloc(8); jh.writeUInt32LE(jsonBuf.length, 0); jh.write('JSON', 4, 'ascii');
const bh = Buffer.alloc(8); bh.writeUInt32LE(bin.length, 0); bh.write('BIN\0', 4, 'ascii');
const out = path.join(__dirname, '..', 'assets', 'models', 'shelf_half.glb');
fs.writeFileSync(out, Buffer.concat([header, jh, jsonBuf, bh, bin]));
console.log('wrote', out, total, 'bytes');
