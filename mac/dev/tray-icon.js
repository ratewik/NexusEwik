// NexusEwik — Copyright (C) 2026 ratewik. GPL-3.0, see LICENSE.
// Writes assets/trayTemplate.png (18 pt) and @2x: the mark's four-diamond lattice as a
// menu bar template image (black + alpha; macOS tints it). Run: node dev/tray-icon.js
'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// The brand lattice on an 18 × 18 point canvas: four small solid diamonds.
const CANVAS = 18;
const WIDTH = 0.36 * CANVAS;               // diamond extent across the canvas
const SIDE = WIDTH / Math.sqrt(2);         // underlying rounded square's side
const CORNER = 0.18 * SIDE;                // its corner rounding
const POSITIONS = [ // lattice centres, as fractions of the canvas
  [0.5, 0.26], [0.26, 0.5], [0.74, 0.5], [0.5, 0.74],
].map(([fx, fy]) => [fx * CANVAS, fy * CANVAS]);

// Signed distance of a rounded square in a diamond's local frame (after rotating -45°).
function inside(cx, cy, px, py) {
  const dx = px - cx, dy = py - cy;
  const u = (dx + dy) / Math.SQRT2, v = (-dx + dy) / Math.SQRT2; // rotate -45°
  const half = SIDE / 2;
  const du = Math.max(Math.abs(u) - (half - CORNER), 0);
  const dv = Math.max(Math.abs(v) - (half - CORNER), 0);
  return Math.hypot(du, dv) - CORNER < 0;
}

function alphaAt(px, py) {
  for (const [cx, cy] of POSITIONS) if (inside(cx, cy, px, py)) return 1;
  return 0;
}

function png(size) {
  const k = size / CANVAS, ss = 4;
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0; // filter: none
    for (let x = 0; x < size; x++) {
      let a = 0;
      for (let i = 0; i < ss; i++) for (let j = 0; j < ss; j++) a += alphaAt((x + (i + 0.5) / ss) / k, (y + (j + 0.5) / ss) / k);
      raw[y * (size * 4 + 1) + 1 + x * 4 + 3] = Math.round((255 * a) / (ss * ss));
    }
  }
  const crc = (buf) => {
    let c = ~0;
    for (const b of buf) { c ^= b; for (let i = 0; i < 8; i++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1)); }
    return ~c >>> 0;
  };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
    return Buffer.concat([len, td, c]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8-bit RGBA
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

const out = path.join(__dirname, '..', 'assets');
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, 'trayTemplate.png'), png(18));
fs.writeFileSync(path.join(out, 'trayTemplate@2x.png'), png(36));
console.log('wrote assets/trayTemplate.png, @2x');
