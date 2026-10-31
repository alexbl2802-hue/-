// Запекает мир для Godot-версии: высоты рельефа, цвета вершин и расстановку растительности.
// Формулы и зерна те же, что в веб-версии (docs/index.html), поэтому мир получается тем же.
// Запуск: node tools/bake_world.mjs  →  godot/data/world.bin и godot/data/props.json
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'godot', 'data');

// ---------- Шум
function mulberry32(a) {
  return function () {
    a |= 0; a = a + 0x6D2B79F5 | 0;
    let t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20261030);
const perm = new Uint8Array(256);
{
  const p = [...Array(256).keys()];
  for (let i = 255; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [p[i], p[j]] = [p[j], p[i]]; }
  perm.set(p);
}
const lerp = (a, b, t) => a + (b - a) * t;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const smoothstep = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
const hash2 = (ix, iz) => perm[(perm[ix & 255] + iz) & 255] / 255;
function vnoise(x, z) {
  const ix = Math.floor(x), iz = Math.floor(z);
  const fx = x - ix, fz = z - iz;
  const ux = fx * fx * (3 - 2 * fx), uz = fz * fz * (3 - 2 * fz);
  const a = hash2(ix, iz), b = hash2(ix + 1, iz), c = hash2(ix, iz + 1), d = hash2(ix + 1, iz + 1);
  return lerp(lerp(a, b, ux), lerp(c, d, ux), uz) * 2 - 1;
}
function fbm(x, z, oct = 5) {
  let sum = 0, amp = 1, norm = 0;
  for (let i = 0; i < oct; i++) { sum += vnoise(x, z) * amp; norm += amp; amp *= 0.5; x *= 2.03; z *= 2.03; }
  return sum / norm;
}
function ridged(x, z, oct = 5) {
  let sum = 0, amp = 1, norm = 0;
  for (let i = 0; i < oct; i++) { const n = 1 - Math.abs(vnoise(x, z)); sum += n * n * amp; norm += amp; amp *= 0.5; x *= 2.1; z *= 2.1; }
  return sum / norm;
}

// ---------- Рельеф
const WORLD = 900, HALF = WORLD / 2, SEG = 360, STEP = WORLD / SEG;
const TOWN_Y = 4;
const townDist = (x, z) => Math.max(Math.abs(x), Math.abs(z));
const SITES = [
  { x: -175, z: 135, r: 12, name: 'Древний склеп' },
  { x: 75, z: -205, r: 12, name: 'Пещера кристаллов' },
];
function rawHeight(x, z) {
  const d = Math.hypot(x, z) / HALF;
  let h = fbm(x * 0.006 + 10, z * 0.006 - 4, 5) * 11 + 3.5;
  h += fbm(x * 0.025, z * 0.025, 3) * 1.4;
  const r = ridged(x * 0.008 + 3, z * 0.008 + 7, 5);
  const ring = smoothstep(0.62, 0.95, d);
  h += ring * (r * r * 75 + 12);
  const md = Math.hypot(x - 90, z + 300) / 170;
  const massif = Math.max(0, 1 - md);
  h += massif * massif * (r * 70 + 25);
  h = lerp(TOWN_Y, h, smoothstep(40, 72, townDist(x, z)));
  return h;
}
for (const s of SITES) s.h = Math.max(2, rawHeight(s.x, s.z));
function heightFn(x, z) {
  let h = rawHeight(x, z);
  for (const s of SITES) {
    const w = 1 - smoothstep(s.r * 0.5, s.r, Math.hypot(x - s.x, z - s.z));
    if (w > 0) h = lerp(h, s.h, w);
  }
  return h;
}
const N = SEG + 1;
const heights = new Float32Array(N * N);
for (let j = 0; j <= SEG; j++)
  for (let i = 0; i <= SEG; i++)
    heights[j * N + i] = heightFn(-HALF + i * STEP, -HALF + j * STEP);
function groundAt(x, z) {
  const fx = clamp((x + HALF) / STEP, 0, SEG - 0.001), fz = clamp((z + HALF) / STEP, 0, SEG - 0.001);
  const i = Math.floor(fx), j = Math.floor(fz), tx = fx - i, tz = fz - j;
  const k = j * N + i;
  return lerp(lerp(heights[k], heights[k + 1], tx), lerp(heights[k + N], heights[k + N + 1], tx), tz);
}
function normalYAt(x, z) {
  const e = 1.0;
  const dx = (groundAt(x + e, z) - groundAt(x - e, z)) / (2 * e);
  const dz = (groundAt(x, z + e) - groundAt(x, z - e)) / (2 * e);
  return 1 / Math.sqrt(1 + dx * dx + dz * dz);
}

// ---------- Цвета (как в three.js: смешиваем в линейном пространстве, сохраняем в sRGB)
const toLin = c => c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
const toSrgb = c => c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
const hex = h => [toLin(((h >> 16) & 255) / 255), toLin(((h >> 8) & 255) / 255), toLin((h & 255) / 255)];
const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
const toByte = c => Math.round(clamp(toSrgb(clamp(c, 0, 1)), 0, 1) * 255);
const toHex = c => (toByte(c[0]) << 16) | (toByte(c[1]) << 8) | toByte(c[2]);
function hsl(h, s, l) {
  // как THREE.Color.setHSL: значения в рабочем (линейном) пространстве
  const hue2rgb = (p, q, t) => { if (t < 0) t += 1; if (t > 1) t -= 1; if (t < 1 / 6) return p + (q - p) * 6 * t; if (t < 1 / 2) return q; if (t < 2 / 3) return p + (q - p) * 6 * (2 / 3 - t); return p; };
  h = ((h % 1) + 1) % 1; s = clamp(s, 0, 1); l = clamp(l, 0, 1);
  if (s === 0) return [l, l, l];
  const p = l <= 0.5 ? l * (1 + s) : l + s - l * s, q = 2 * l - p;
  return [hue2rgb(q, p, h + 1 / 3), hue2rgb(q, p, h), hue2rgb(q, p, h - 1 / 3)];
}

const colors = new Uint8Array(N * N * 3);
{
  const sand = hex(0xd8c88f), grassA = hex(0x5f9a3c), grassB = hex(0x3f7a2e), dirt = hex(0x7d6a45),
    rock = hex(0x7c776f), rockDark = hex(0x5b5650), snow = hex(0xf4f7fb);
  for (let j = 0; j <= SEG; j++) for (let i = 0; i <= SEG; i++) {
    const k = j * N + i, h = heights[k], x = -HALF + i * STEP, z = -HALF + j * STEP;
    const ny = normalYAt(x, z), n = fbm(x * 0.05, z * 0.05, 3);
    let c = mix(grassA, grassB, smoothstep(-0.3, 0.4, n));
    c = mix(c, dirt, smoothstep(0.35, 0.7, fbm(x * 0.02 + 50, z * 0.02, 3)) * 0.6);
    c = mix(c, sand, 1 - smoothstep(0.6, 1.6, h));
    const rockT = 1 - smoothstep(0.72, 0.86, ny);
    c = mix(c, mix(rock, rockDark, (n + 1) / 2), Math.max(rockT, smoothstep(30, 45, h) * 0.9));
    c = mix(c, snow, smoothstep(52, 62, h + n * 6) * smoothstep(0.55, 0.75, ny));
    for (const s of SITES) c = mix(c, dirt, (1 - smoothstep(4, 9, Math.hypot(x - s.x, z - s.z))) * 0.7);
    if (Math.abs(x) < 3.5 && Math.abs(z) > 30 && Math.abs(z) < 90) c = mix(c, dirt, 0.75);
    colors[k * 3] = toByte(c[0]); colors[k * 3 + 1] = toByte(c[1]); colors[k * 3 + 2] = toByte(c[2]);
  }
}

// ---------- Растительность и камни (тот же порядок вызовов rand, что в веб-версии)
const Q = { trees: 1800, rocks: 420, tufts: 3800 };
const r3 = v => Math.round(v * 1000) / 1000;
const pines = [], oaks = [];
for (let n = 0; n < 16000 && pines.length + oaks.length < Q.trees; n++) {
  const x = (rand() * 2 - 1) * (HALF - 10), z = (rand() * 2 - 1) * (HALF - 10);
  const h = groundAt(x, z);
  if (h < 1.3 || h > 42) continue;
  if (normalYAt(x, z) < 0.82) continue;
  if (townDist(x, z) < 42) continue;
  if (SITES.some(s => Math.hypot(x - s.x, z - s.z) < s.r + 3)) continue;
  const forest = fbm(x * 0.012 + 100, z * 0.012 - 30, 3);
  if (forest < -0.05 && rand() > 0.08) continue;
  const t = { x, z, h, s: 0.8 + rand() * 0.6, rot: rand() * Math.PI * 2 };
  (h > 18 || rand() < 0.45 ? pines : oaks).push(t);
}
// Цвета в том же порядке, что и при сборке мешей в веб-версии
for (let layer = 0; layer < 3; layer++) for (const t of pines) (t.c ??= []).push(toHex(hsl(0.33 + rand() * 0.04, 0.45, 0.2 + rand() * 0.06)));
for (const t of oaks) t.c = [toHex(hsl(0.22 + rand() * 0.08, 0.5, 0.3 + rand() * 0.1))];
for (const t of oaks) t.c.push(toHex(hsl(0.24 + rand() * 0.08, 0.5, 0.34 + rand() * 0.1)));

const rocks = [];
for (let n = 0; n < 6000 && rocks.length < Q.rocks; n++) {
  const x = (rand() * 2 - 1) * (HALF - 5), z = (rand() * 2 - 1) * (HALF - 5);
  const h = groundAt(x, z);
  if (h < 0.5 || townDist(x, z) < 42) continue;
  if (SITES.some(s => Math.hypot(x - s.x, z - s.z) < s.r)) continue;
  const big = rand() < 0.3;
  rocks.push({ x, z, h, s: big ? 1.2 + rand() * 1.6 : 0.3 + rand() * 0.6, rot: rand() * 6.28 });
}
for (const r of rocks) r.c = toHex(hsl(0.08, 0.05, 0.38 + rand() * 0.15));

const tufts = [];
for (let n = 0; n < 40000 && tufts.length < Q.tufts; n++) {
  const x = (rand() * 2 - 1) * (HALF - 20), z = (rand() * 2 - 1) * (HALF - 20);
  if (townDist(x, z) < 37) continue;
  const h = groundAt(x, z);
  if (h < 1.4 || h > 30 || normalYAt(x, z) < 0.86) continue;
  tufts.push({ x, z, h, s: 0.5 + rand() * 0.6, rot: rand() * 6.28 });
}
for (const t of tufts) t.c = toHex(hsl(0.24 + rand() * 0.07, 0.55, 0.3 + rand() * 0.12));

// ---------- Места появления монстров (как в веб-версии: зерно 555)
const obstacles = [];
for (const t of [...pines, ...oaks]) obstacles.push({ x: t.x, z: t.z, r: 0.45 * t.s });
for (const r of rocks) if (r.s > 0.9) obstacles.push({ x: r.x, z: r.z, r: r.s * 0.95 });
obstacles.push({ x: 4, z: 3, r: 1.0 });
const entrances = SITES.map(s => {
  const angle = Math.atan2(-s.x, -s.z), dir = [Math.sin(angle), Math.cos(angle)];
  for (const px of [-1.9, 1.9]) obstacles.push({ x: s.x + Math.cos(angle) * px, z: s.z - Math.sin(angle) * px, r: 0.7 });
  obstacles.push({ x: s.x - dir[0] * 5.2, z: s.z - dir[1] * 5.2, r: 4.8 });
  return { door: [s.x + dir[0], s.z + dir[1]], dir };
});
const enemies = [];
{
  const er = mulberry32(555);
  const ok = (x, z) => {
    const h = groundAt(x, z);
    return h > 1.5 && h < 30 && normalYAt(x, z) > 0.85 && townDist(x, z) > 55
      && !SITES.some(s => Math.hypot(x - s.x, z - s.z) < 10)
      && obstacles.every(o => Math.hypot(o.x - x, o.z - z) > o.r + 1);
  };
  // Больше монстров, чем в веб-версии: 30 слизней, 14 гоблинов и 12 кроликов-бродяг
  const want = { slime: 30, goblin: 14, rabbit: 12 };
  const have = { slime: 0, goblin: 0, rabbit: 0 };
  for (let n = 0; n < 16000 && Object.keys(want).some(k => have[k] < want[k]); n++) {
    const x = (er() * 2 - 1) * (HALF - 40), z = (er() * 2 - 1) * (HALF - 40);
    if (!ok(x, z)) continue;
    const kind = Object.keys(want).find(k => have[k] < want[k]);
    enemies.push([kind, r3(x), r3(z)]);
    have[kind]++;
  }
  // Гоблины охраняют входы в подземелья
  for (const en of entrances) for (const side of [-1, 1])
    enemies.push(['goblin', r3(en.door[0] + en.dir[0] * 8 + en.dir[1] * side * 3.5), r3(en.door[1] + en.dir[1] * 8 - en.dir[0] * side * 3.5)]);
}

// ---------- Запись
mkdirSync(OUT, { recursive: true });
const head = new Int32Array([SEG]);
writeFileSync(join(OUT, 'world.bin'), Buffer.concat([Buffer.from(head.buffer), Buffer.from(heights.buffer), Buffer.from(colors)]));
const pack = (list, f) => list.map(f);
const props = {
  world: WORLD, seg: SEG, townY: TOWN_Y,
  sites: SITES.map(s => ({ x: s.x, z: s.z, r: s.r, h: r3(s.h), name: s.name })),
  pines: pack(pines, t => [r3(t.x), r3(t.z), r3(t.h), r3(t.s), r3(t.rot), ...t.c]),
  oaks: pack(oaks, t => [r3(t.x), r3(t.z), r3(t.h), r3(t.s), r3(t.rot), ...t.c]),
  rocks: pack(rocks, t => [r3(t.x), r3(t.z), r3(t.h), r3(t.s), r3(t.rot), t.c]),
  tufts: pack(tufts, t => [r3(t.x), r3(t.z), r3(t.h), r3(t.s), r3(t.rot), t.c]),
  enemies,
};
writeFileSync(join(OUT, 'props.json'), JSON.stringify(props));
console.log(`world.bin: ${N}×${N}, pines ${pines.length}, oaks ${oaks.length}, rocks ${rocks.length}, tufts ${tufts.length}, enemies ${enemies.length}`);
