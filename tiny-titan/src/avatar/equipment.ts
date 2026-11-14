// Draws equipment onto the procedural body using its anchors. Each visual
// "kind" is a template shared by several items that differ only in colour.

import { Pix, shade, mix } from './pixel';
import type { ItemVisual } from '../game/items';
import type { Metrics } from './body';

type Aura = Extract<ItemVisual, { kind: 'aura' }>['style'];

// --- back ---------------------------------------------------------------

export function drawBackItem(p: Pix, v: ItemVisual, m: Metrics, frame: number) {
  switch (v.kind) {
    case 'cape': {
      const top = m.torsoTop + 1;
      const bottom = m.legTop + 4;
      const wave = frame % 4 < 2 ? 0 : 1;
      for (let y = top; y <= bottom; y++) {
        const t = (y - top) / Math.max(1, bottom - top);
        let w = Math.round(m.shoulderW + 2 + t * 6);
        if (w % 2) w++;
        const x = m.cx - w / 2 + (y > top + 3 ? wave : 0);
        p.hline(x, y, w, v.color);
        p.set(x + 1, y, v.inner);
        if (y === bottom) {
          for (let k = 0; k < w; k += 3) p.set(x + k + 1, y + 1, v.color);
        }
      }
      break;
    }
    case 'crashpad': {
      const w = m.shoulderW + 10;
      const h = m.torsoH + 6;
      const x = m.cx - Math.floor(w / 2);
      const y = m.torsoTop - 3;
      p.roundRect(x, y, w, h, v.color, 1);
      p.hline(x, y + Math.floor(h / 2), w, v.accent);
      p.vline(x + w - 2, y + 1, h - 2, shade(v.color, 0.8));
      // straps on the shoulders
      p.rect(m.cx - 4, m.torsoTop, 2, 3, shade(v.accent, 0.7));
      p.rect(m.cx + 2, m.torsoTop, 2, 3, shade(v.accent, 0.7));
      break;
    }
    case 'barbell': {
      const y = m.torsoTop + 1;
      const half = 18;
      p.hline(m.cx - half, y, half * 2, '#aab2bd');
      p.hline(m.cx - half, y + 1, half * 2, '#7b8491');
      for (const side of [-1, 1]) {
        const px = side < 0 ? m.cx - half - 1 : m.cx + half - 3;
        p.rect(px, y - 3, 3, 8, '#3b4452');
        p.rect(px + 1, y - 2, 1, 6, '#d64545');
      }
      break;
    }
    case 'backpack': {
      const tl = m.torsoLeft(m.torsoTop + 2);
      const tw = m.torsoW(m.torsoTop + 2);
      p.rect(tl - 2, m.torsoTop + 1, 2, 8, v.color);
      p.rect(tl + tw, m.torsoTop + 1, 2, 8, v.color);
      if (v.accent) {
        p.rect(tl - 2, m.torsoTop + 2, 1, 3, v.accent);
        p.rect(tl + tw + 1, m.torsoTop + 2, 1, 3, v.accent);
      }
      break;
    }
    case 'saddlebag': {
      const tr = m.torsoLeft(m.torsoBottom) + m.torsoW(m.torsoBottom);
      p.roundRect(tr, m.torsoBottom - 3, 4, 4, v.color, 1);
      p.set(tr + 1, m.torsoBottom - 2, shade(v.color, 1.4));
      break;
    }
    case 'shield': {
      // A chainring slung across the back: toothed disc peeking out behind the torso.
      const cy = m.torsoTop + Math.floor(m.torsoH / 2);
      const r = Math.floor(m.shoulderW / 2) + 3;
      p.ellipse(m.cx, cy, r, r, v.color);
      p.ellipse(m.cx, cy, r - 2, r - 2, shade(v.color, 0.75));
      for (let a = 0; a < 12; a++) {
        const ang = (a / 12) * Math.PI * 2;
        p.set(Math.floor(m.cx + Math.cos(ang) * (r + 1.2)), Math.floor(cy + Math.sin(ang) * (r + 1.2)), v.accent);
      }
      p.rect(m.cx - 3, m.torsoTop, 2, 3, shade(v.accent, 0.7));
      p.rect(m.cx + 1, m.torsoTop, 2, 3, shade(v.accent, 0.7));
      break;
    }
  }
}

// --- legs ---------------------------------------------------------------

export function drawLegGarment(p: Pix, v: ItemVisual, m: Metrics) {
  const legs = [m.legL, m.legR];
  switch (v.kind) {
    case 'shorts': {
      for (const l of legs) {
        p.rect(l.x, l.top, l.thighW, l.kneeY - l.top - 1, v.color);
        p.hline(l.x, l.top, l.thighW, shade(v.color, 0.8));
        if (v.accent) p.vline(l.side < 0 ? l.x : l.x + l.thighW - 1, l.top + 1, l.kneeY - l.top - 2, v.accent);
        if (v.knee) {
          p.rect(l.calfX, l.kneeY - 1, l.calfW, 3, v.knee);
        }
      }
      // waistband across the hips
      p.hline(m.torsoLeft(m.torsoBottom), m.torsoBottom, m.torsoW(m.torsoBottom), shade(v.color, 0.9));
      break;
    }
    case 'tights': {
      for (const l of legs) {
        p.rect(l.x, l.top, l.thighW, l.kneeY - l.top, v.color);
        p.rect(l.calfX, l.kneeY, l.calfW, m.feetTop - l.kneeY, v.color);
        if (v.accent && v.accent !== v.color) {
          p.vline(l.side < 0 ? l.x : l.x + l.thighW - 1, l.top + 1, l.kneeY - l.top - 1, v.accent);
        }
      }
      p.hline(m.torsoLeft(m.torsoBottom), m.torsoBottom, m.torsoW(m.torsoBottom), shade(v.color, 0.9));
      break;
    }
    case 'harness': {
      drawLegGarment(p, { kind: 'shorts', color: v.shorts }, m);
      p.hline(m.torsoLeft(m.torsoBottom), m.torsoBottom, m.torsoW(m.torsoBottom), v.color);
      for (const l of legs) {
        p.hline(l.x, l.top + 3, l.thighW, v.color);
        p.set(l.side < 0 ? l.x + l.thighW - 1 : l.x, l.top + 1, v.color);
        p.set(l.side < 0 ? l.x + l.thighW - 1 : l.x, l.top + 2, v.color);
      }
      p.rect(m.cx - 1, m.torsoBottom - 1, 2, 2, shade(v.color, 1.3));
      break;
    }
  }
}

// --- feet ---------------------------------------------------------------

export function drawFeet(p: Pix, v: ItemVisual | null, m: Metrics, frame: number) {
  const feet = [m.footL, m.footR];
  const y = m.feetTop;
  const h = m.footH;
  if (!v) {
    for (const f of feet) p.rect(f.x, y, f.w, h, m.skin);
    for (const f of feet) p.hline(f.x, y + h - 1, f.w, shade(m.skin, 0.85));
    return;
  }
  switch (v.kind) {
    case 'shoes': {
      for (const f of feet) {
        p.rect(f.x, y, f.w, h, v.color);
        p.hline(f.x, y + h - 1, f.w, v.sole ?? shade(v.color, 0.6));
        const ax = f === m.footL ? f.x : f.x + f.w - 2;
        p.hline(ax, y + 1, 2, v.accent);
        p.set(f === m.footL ? f.x + f.w - 1 : f.x, y, shade(v.color, 0.8));
      }
      break;
    }
    case 'climbshoes': {
      for (const f of feet) {
        p.rect(f.x, y, f.w, h, v.color);
        p.hline(f.x, y + h - 1, f.w, '#222222');
        // pointed toe
        p.set(f === m.footL ? f.x - 1 : f.x + f.w, y + h - 2, v.color);
        p.set(f === m.footL ? f.x - 1 : f.x + f.w, y + h - 1, '#222222');
        p.set(f === m.footL ? f.x + f.w - 1 : f.x, y, shade(v.color, 0.7));
      }
      break;
    }
    case 'sandals': {
      for (const f of feet) {
        p.rect(f.x, y, f.w, h, m.skin);
        p.hline(f.x, y, f.w, v.color);
        p.hline(f.x, y + h - 1, f.w, shade(v.color, 0.6));
        if (v.wings) {
          const up = frame % 2;
          const wx = f === m.footL ? f.x + f.w - 1 : f.x;
          const dir = f === m.footL ? 1 : -1;
          p.set(wx + dir, y - up, '#ffffff');
          p.set(wx + dir * 2, y - 1 - up, '#ffffff');
          p.set(wx + dir, y + 1 - up, '#e0e0e0');
        }
      }
      break;
    }
    default:
      for (const f of feet) p.rect(f.x, y, f.w, h, m.skin);
  }
}

// --- body ---------------------------------------------------------------

function fillTorso(p: Pix, m: Metrics, color: string, fromRow = 0) {
  for (let y = m.torsoTop + fromRow; y <= m.torsoBottom; y++) p.hline(m.torsoLeft(y), y, m.torsoW(y), color);
}

function sleeves(p: Pix, m: Metrics, color: string, rows = 3) {
  for (const a of [m.armL, m.armR]) {
    const half = Math.floor(a.upperW / 2);
    if (m.pose === 'flex') {
      const x0 = a.side < 0 ? a.shoulder.x - 2 : a.shoulder.x - half;
      p.rect(x0, a.shoulder.y - half, 3, a.upperW, color);
    } else {
      p.rect(a.shoulder.x - half, a.shoulder.y - half, a.upperW, rows, color);
    }
  }
}

export function drawBodyGarment(p: Pix, v: ItemVisual, m: Metrics) {
  switch (v.kind) {
    case 'shirt': {
      fillTorso(p, m, v.color);
      sleeves(p, m, v.color);
      const collar = shade(v.color, 0.75);
      p.hline(m.cx - 2, m.torsoTop, 4, collar);
      const acc = v.accent ?? shade(v.color, 1.3);
      if (v.pattern === 'stripe') {
        p.hline(m.torsoLeft(m.torsoTop + 4), m.torsoTop + 4, m.torsoW(m.torsoTop + 4), acc);
        p.hline(m.torsoLeft(m.torsoTop + 7), m.torsoTop + 7, m.torsoW(m.torsoTop + 7), acc);
      } else if (v.pattern === 'polka') {
        for (let y = m.torsoTop + 2; y < m.torsoBottom; y += 3) {
          const l = m.torsoLeft(y);
          const w = m.torsoW(y);
          for (let x = l + ((y / 3) | 0) % 2; x < l + w; x += 3) p.set(x, y, acc);
        }
      } else if (v.pattern === 'reflective') {
        for (let y = m.torsoTop + 2; y < m.torsoBottom; y += 4) p.hline(m.torsoLeft(y), y, m.torsoW(y), acc);
      } else if (v.pattern === 'hood') {
        const hl = m.torsoLeft(m.torsoTop) - 1;
        const hw = m.torsoW(m.torsoTop) + 2;
        p.hline(hl, m.torsoTop, hw, acc);
        p.hline(hl, m.torsoTop + 1, hw, acc);
        p.vline(m.cx - 2, m.torsoTop + 2, 3, shade(acc, 1.5));
        p.vline(m.cx + 1, m.torsoTop + 2, 3, shade(acc, 1.5));
        // front pocket
        p.hline(m.cx - 3, m.torsoBottom - 3, 6, shade(v.color, 0.8));
      }
      break;
    }
    case 'tank': {
      fillTorso(p, m, v.color, 2);
      const tl = m.torsoLeft(m.torsoTop);
      const tw = m.torsoW(m.torsoTop);
      p.rect(tl + 1, m.torsoTop, 2, 2, v.color);
      p.rect(tl + tw - 3, m.torsoTop, 2, 2, v.color);
      if (v.accent) p.hline(m.cx - 2, m.torsoTop + 5, 4, v.accent);
      break;
    }
    case 'singlet': {
      fillTorso(p, m, v.color, 1);
      const tl = m.torsoLeft(m.torsoTop);
      const tw = m.torsoW(m.torsoTop);
      p.rect(tl + 1, m.torsoTop, 2, 1, v.color);
      p.rect(tl + tw - 3, m.torsoTop, 2, 1, v.color);
      if (v.accent) {
        p.vline(m.cx - 1, m.torsoTop + 3, 4, v.accent);
        p.vline(m.cx, m.torsoTop + 3, 4, v.accent);
      }
      break;
    }
  }
}

// --- hands ---------------------------------------------------------------

export function drawHands(p: Pix, v: ItemVisual, m: Metrics) {
  for (const a of [m.armL, m.armR]) {
    const h = a.hand;
    switch (v.kind) {
      case 'chalk': {
        const c = mix(m.skin, '#ffffff', 0.7);
        p.rect(h.x, h.y, h.w, h.h, c);
        p.set(a.wrist.x + (a.side < 0 ? -1 : 1), a.wrist.y - 1, '#ffffff');
        break;
      }
      case 'wraps': {
        const half = Math.floor(a.foreW / 2);
        if (v.long) {
          p.limb(a.elbow.x, a.elbow.y + (m.pose === 'flex' ? -1 : 1), a.wrist.x, a.wrist.y, a.foreW, v.color);
          p.set(a.wrist.x - half, Math.round((a.elbow.y + a.wrist.y) / 2), shade(v.color, 0.8));
        } else {
          const dir = m.pose === 'flex' ? -1 : 1;
          p.rect(a.wrist.x - half, a.wrist.y - (dir < 0 ? 0 : 1), a.foreW, 2, v.color);
          p.rect(a.wrist.x - half, a.wrist.y - (dir < 0 ? -1 : 0), a.foreW, 1, shade(v.color, 0.8));
        }
        p.rect(h.x, h.y, h.w, 1, v.color);
        break;
      }
      case 'gloves': {
        p.rect(h.x, h.y, h.w, h.h, v.color);
        if (v.fingerless) p.rect(h.x, h.y + (m.pose === 'flex' ? 0 : h.h - 1), h.w, 1, m.skin);
        break;
      }
    }
  }
}

// --- accessory ------------------------------------------------------------

export function drawAccessory(p: Pix, v: ItemVisual, m: Metrics, frame: number) {
  switch (v.kind) {
    case 'belt': {
      const y = m.torsoBottom - 1;
      for (let yy = y; yy <= m.torsoBottom; yy++) p.hline(m.torsoLeft(yy), yy, m.torsoW(yy), v.color);
      p.rect(m.cx - 1, y, 2, 2, v.buckle);
      break;
    }
    case 'chalkbag': {
      const tr = m.torsoLeft(m.torsoBottom) + m.torsoW(m.torsoBottom);
      p.roundRect(tr - 1, m.torsoBottom - 1, 4, 5, v.color, 1);
      p.hline(tr - 1, m.torsoBottom - 1, 4, '#f4f4f4');
      p.set(tr, m.torsoBottom + 1, shade(v.color, 1.3));
      break;
    }
    case 'pendant': {
      const y = m.torsoTop;
      p.set(m.cx - 2, y, '#c0c0c0');
      p.set(m.cx + 1, y, '#c0c0c0');
      p.set(m.cx - 1, y + 1, '#c0c0c0');
      p.set(m.cx, y + 1, '#c0c0c0');
      p.rect(m.cx - 1, y + 2, 2, 2, v.color);
      p.set(m.cx - 1, y + 2, shade(v.color, 1.3));
      break;
    }
    case 'medal': {
      const tl = m.torsoLeft(m.torsoTop);
      const tw = m.torsoW(m.torsoTop);
      for (let k = 0; k < 4; k++) {
        p.set(tl + 2 + k, m.torsoTop + k, v.ribbon);
        p.set(tl + tw - 3 - k, m.torsoTop + k, v.ribbon);
      }
      p.rect(m.cx - 1, m.torsoTop + 4, 3, 3, v.disc);
      p.set(m.cx, m.torsoTop + 5, shade(v.disc, 0.7));
      if (frame % 8 === 0) p.set(m.cx + 1, m.torsoTop + 4, '#ffffff');
      break;
    }
    case 'bib': {
      const w = Math.min(7, m.torsoW(m.torsoTop + 3) - 2);
      const x = m.cx - Math.floor(w / 2);
      const y = m.torsoTop + 3;
      p.rect(x, y, w, 4, v.color);
      p.set(x + 1, y + 2, '#222222');
      p.set(x + 3, y + 2, '#222222');
      p.set(x + 5, y + 2, '#222222');
      p.set(x, y, '#9e9e9e');
      p.set(x + w - 1, y, '#9e9e9e');
      break;
    }
  }
}

// --- head / face ----------------------------------------------------------

export function drawHeadItem(p: Pix, v: ItemVisual, m: Metrics) {
  const x = m.headLeft;
  const y = m.headTop;
  const w = m.headW;
  switch (v.kind) {
    case 'headband':
      p.hline(x - 1, m.eyeY - 3, w + 2, v.color);
      p.hline(x - 1, m.eyeY - 2, w + 2, shade(v.color, 0.8));
      break;
    case 'beanie': {
      p.roundRect(x - 1, y - 3, w + 2, 7, v.color, 2);
      p.hline(x - 1, y + 2, w + 2, v.accent ?? shade(v.color, 0.75));
      p.hline(x - 1, y + 3, w + 2, v.accent ?? shade(v.color, 0.75));
      p.rect(m.cx - 1, y - 5, 2, 2, shade(v.color, 1.3));
      break;
    }
    case 'cap': {
      if (!v.visor) {
        p.roundRect(x, y - 2, w, 5, v.color, 1);
        if (v.accent) p.rect(m.cx - 1, y - 1, 2, 2, v.accent);
      } else {
        p.hline(x - 1, y + 1, w + 2, v.color);
        p.hline(x - 1, y + 2, w + 2, v.color);
      }
      const brimY = y + 3;
      p.hline(x - 2, brimY, w + 4, v.accent && v.visor ? v.accent : shade(v.color, 0.8));
      break;
    }
    case 'helmet': {
      p.roundRect(x - 1, y - 3, w + 2, 7, v.color, 2);
      const d = shade(v.color, 0.7);
      if (v.aero) {
        p.hline(x - 1, y + 3, w + 2, '#444a52');
        p.hline(x + 2, y - 1, w - 4, shade(v.color, 1.4));
      } else {
        p.vline(x + 2, y - 2, 4, d);
        p.vline(x + 5, y - 3, 5, d);
        p.vline(x + 8, y - 2, 4, d);
      }
      // chin strap
      p.set(x - 1, y + 6, '#222222');
      p.set(x + w, y + 6, '#222222');
      break;
    }
    case 'crown': {
      p.rect(x, y - 2, w, 2, v.color);
      p.set(x + 1, y - 3, v.color);
      p.set(x + 5, y - 3, v.color);
      p.set(x + 6, y - 3, v.color);
      p.set(x + 10, y - 3, v.color);
      p.set(x + 5, y - 4, v.color);
      p.set(x + 6, y - 4, v.color);
      p.set(m.cx - 1, y - 2, v.gem);
      p.set(m.cx, y - 2, v.gem);
      p.set(x + 2, y - 1, shade(v.color, 1.3));
      break;
    }
    case 'laurel': {
      // Wreath of leaves around the brow with a golden clasp.
      for (let k = 0; k < w; k += 2) {
        p.set(x + k, y, v.accent);
        p.set(x + k + 1, y - 1, shade(v.accent, k % 4 === 0 ? 1.25 : 0.85));
      }
      for (const sx of [x - 1, x + w]) {
        p.set(sx, y + 1, v.accent);
        p.set(sx, y + 2, shade(v.accent, 0.85));
        p.set(sx, y + 3, v.accent);
      }
      p.set(x - 2, y, v.accent);
      p.set(x + w + 1, y, v.accent);
      p.set(x - 2, y - 2, shade(v.accent, 1.25));
      p.set(x + w + 1, y - 2, shade(v.accent, 1.25));
      p.rect(m.cx - 1, y - 2, 2, 2, v.color);
      p.set(m.cx - 1, y - 2, shade(v.color, 1.4));
      break;
    }
    case 'bandana': {
      p.roundRect(x, y - 1, w, 4, v.color, 1);
      p.rect(x + w, y + 1, 2, 2, v.color);
      p.set(x + w + 2, y + 3, v.color);
      p.set(x + w + 1, y + 3, shade(v.color, 0.8));
      p.set(x + 3, y, shade(v.color, 1.25));
      break;
    }
    case 'headlamp': {
      p.hline(x - 1, m.eyeY - 3, w + 2, v.color);
      p.rect(m.cx - 1, m.eyeY - 4, 3, 2, shade(v.color, 1.2));
      p.set(m.cx, m.eyeY - 4, '#fff176');
      break;
    }
  }
}

export function drawFaceItem(p: Pix, v: ItemVisual, m: Metrics) {
  if (v.kind !== 'sunglasses') return;
  const y = m.eyeY;
  const frame = v.frame ?? shade(v.color, 0.6);
  p.rect(m.cx - 4, y, 3, 2, v.color);
  p.rect(m.cx + 1, y, 3, 2, v.color);
  p.set(m.cx - 1, y, frame);
  p.set(m.cx, y, frame);
  p.set(m.headLeft, y, frame);
  p.set(m.headLeft + m.headW - 1, y, frame);
  p.set(m.cx - 3, y, shade(v.color, 1.5));
  p.set(m.cx + 2, y, shade(v.color, 1.5));
}

// --- aura -----------------------------------------------------------------

function hsl(h: number, s: number, l: number): string {
  return `hsl(${Math.round(h)}, ${s}%, ${l}%)`;
}

/** Aura pixels are drawn only into empty cells so they sit "behind" the hero. */
export function drawAura(p: Pix, style: Aura, m: Metrics, frame: number) {
  const put = (x: number, y: number, c: string) => {
    if (!p.get(x, y)) p.set(x, y, c);
  };
  const left = m.cx - m.shoulderW / 2 - m.armL.upperW - 2;
  const right = m.cx + m.shoulderW / 2 + m.armR.upperW + 1;
  const top = m.headTop - 4;
  const bottom = m.baseline - 1;
  switch (style) {
    case 'flame': {
      const cols = ['#ff7a1a', '#ffb13b', '#ffe066', '#ff5a1a'];
      for (let i = 0; i < 18; i++) {
        const side = i % 2 === 0 ? -1 : 1;
        const h = bottom - top;
        const yy = bottom - ((frame * 2 + i * 5) % h);
        const wiggle = ((frame + i) % 3) - 1;
        const x = side < 0 ? left - (i % 3) + wiggle : right + (i % 3) + wiggle;
        const c = cols[(i + frame) % cols.length];
        put(x, yy, c);
        if (i % 3 === 0) put(x, yy + 1, c);
      }
      for (let x = left - 2; x <= right + 2; x += 2) put(x + (frame % 2), bottom, '#ff7a1a');
      break;
    }
    case 'gold': {
      for (let i = 0; i < 10; i++) {
        const phase = (frame + i * 4) % 16;
        const x = left - 3 + ((i * 7 + frame) % (right - left + 8));
        const y = top + ((i * 11 + phase * 2) % (bottom - top));
        const c = phase < 8 ? '#ffd54f' : '#fff8e1';
        put(x, y, c);
        if (phase % 8 < 3) {
          put(x - 1, y, c);
          put(x + 1, y, c);
          put(x, y - 1, c);
          put(x, y + 1, c);
        }
      }
      break;
    }
    case 'frost': {
      for (let i = 0; i < 14; i++) {
        const x = left - 2 + ((i * 5) % (right - left + 6));
        const y = top + ((i * 9 + frame * 1) % (bottom - top + 2));
        put(x, y, i % 3 === 0 ? '#e3f2fd' : '#81d4fa');
      }
      break;
    }
    case 'rainbow': {
      const cy = (top + bottom) / 2;
      const rx = (right - left) / 2 + 3;
      const ry = (bottom - top) / 2 + 1;
      for (let i = 0; i < 12; i++) {
        const a = ((frame * 0.25 + i) / 12) * Math.PI * 2;
        const x = Math.round(m.cx + Math.cos(a) * rx);
        const y = Math.round(cy + Math.sin(a) * ry);
        put(x, y, hsl(((i * 30 + frame * 6) % 360), 90, 60));
      }
      break;
    }
  }
}
