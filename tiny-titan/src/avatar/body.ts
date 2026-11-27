// Procedural pixel-art hero. The silhouette is computed from the player's
// levels: lifting widens shoulders and arms, climbing grows forearms,
// cycling grows thighs, running leans the waist and builds calves, and the
// overall hero level scales everything up — so every level-up is visible.

import { Pix, OUTLINE, shade, mix } from './pixel';
import type { Slot } from '../game/types';
import type { ItemVisual } from '../game/items';
import { stageForLevel } from '../game/xp';
import { drawBackItem, drawLegGarment, drawFeet, drawBodyGarment, drawHands, drawAccessory, drawHeadItem, drawFaceItem, drawAura } from './equipment';

export const HERO_W = 48;
export const HERO_H = 60;

export const SKIN_TONES = ['#f6d7b8', '#e8b98f', '#c98e5f', '#a86b3f', '#7a4a2a', '#4e2e1b'];
export const HAIR_COLORS = ['#2b1b12', '#6b3f1f', '#c9842a', '#e9d37a', '#b52e2e', '#4b4b55', '#e8e8ee', '#6a3fb5', '#2e8b57', '#ff7ab6'];
export const HAIR_STYLES = ['Short', 'Spiky', 'Long', 'Bun', 'Curly', 'Buzz', 'Mohawk'];

export type Pose = 'idle' | 'flex';

export interface BodyInput {
  heroLevel: number;
  liftLevel: number;
  climbLevel: number;
  runLevel: number;
  rideLevel: number;
  skin: number;
  hairStyle: number;
  hairColor: number;
  pose: Pose;
  frame: number;
  blink: boolean;
  happy: boolean;
}

export interface Pt {
  x: number;
  y: number;
}
export interface Arm {
  shoulder: Pt;
  elbow: Pt;
  wrist: Pt;
  upperW: number;
  foreW: number;
  /** Hand rectangle. */
  hand: { x: number; y: number; w: number; h: number };
  side: -1 | 1;
}
export interface Leg {
  /** Left-most column of the thigh. */
  x: number;
  thighW: number;
  calfX: number;
  calfW: number;
  top: number;
  kneeY: number;
  side: -1 | 1;
}

export interface Metrics {
  t: { bulk: number; lift: number; climb: number; run: number; ride: number };
  stage: number;
  cx: number;
  baseline: number;
  bob: number;
  headW: number;
  headH: number;
  headTop: number;
  headLeft: number;
  eyeY: number;
  neckW: number;
  neckTop: number;
  neckH: number;
  torsoTop: number;
  torsoBottom: number;
  torsoH: number;
  shoulderW: number;
  waistW: number;
  torsoW: (y: number) => number;
  torsoLeft: (y: number) => number;
  armL: Arm;
  armR: Arm;
  legL: Leg;
  legR: Leg;
  legTop: number;
  legLen: number;
  feetTop: number;
  footH: number;
  footL: { x: number; w: number };
  footR: { x: number; w: number };
  pose: Pose;
  skin: string;
  hair: string;
}

const clamp01 = (x: number) => Math.max(0, Math.min(1, x));
const lvT = (level: number) => clamp01((level - 1) / 35);
const bulkT = (level: number) => clamp01((level - 1) / 50);

export function bodyMetrics(i: BodyInput): Metrics {
  const bulk = bulkT(i.heroLevel);
  const lift = lvT(i.liftLevel);
  const climb = lvT(i.climbLevel);
  const run = lvT(i.runLevel);
  const ride = lvT(i.rideLevel);
  const stage = stageForLevel(i.heroLevel);
  const cx = HERO_W / 2;
  const baseline = HERO_H - 3; // bottom row of the feet is baseline - 1
  const bob = i.pose === 'idle' ? (i.frame % 4 < 2 ? 0 : 1) : 0;

  const footH = 3;
  const legLen = 12 + Math.round(bulk * 3);
  const torsoH = 12 + Math.round(bulk * 3);
  const neckH = 2;
  const headW = 12;
  const headH = 11;
  const neckW = 2 + Math.round(bulk * 2);
  let shoulderW = 10 + Math.round(lift * 8 + bulk * 4);
  if (shoulderW % 2) shoulderW++;
  let waistW = Math.max(6, 8 + Math.round(bulk * 3) - Math.round(run * 2));
  if (waistW % 2) waistW++;
  waistW = Math.min(waistW, shoulderW);
  const upperArmW = 2 + Math.round(lift * 2.5 + bulk * 1.5);
  const forearmW = Math.max(2, Math.min(upperArmW + 1, 2 + Math.round(climb * 3 + bulk * 0.5)));
  const handW = Math.max(2, Math.min(forearmW, 4));
  const upperArmLen = 7 + Math.round(bulk);
  const forearmLen = 6 + Math.round(bulk);
  const thighW = 3 + Math.round(ride * 3 + bulk * 1.5);
  const calfW = Math.min(thighW, 2 + Math.round(run * 1.5 + ride * 1.5));

  const feetTop = baseline - footH;
  const legTop = feetTop - legLen;
  const torsoBottom = legTop - 1 + bob;
  const torsoTop = torsoBottom - torsoH + 1;
  const neckTop = torsoTop - neckH;
  const hunch = stage === 0 ? 1 : 0;
  const headTop = neckTop - headH + hunch;
  const headLeft = cx - headW / 2;
  const eyeY = headTop + 5;

  const torsoW = (y: number) => {
    const t = clamp01((y - torsoTop) / Math.max(1, torsoH - 1));
    const eased = Math.pow(t, 1.4);
    let w = Math.round(shoulderW + (waistW - shoulderW) * eased);
    if (w % 2) w++;
    return Math.max(waistW, Math.min(shoulderW, w));
  };
  const torsoLeft = (y: number) => cx - torsoW(y) / 2;

  const makeArm = (side: -1 | 1): Arm => {
    const w = upperArmW;
    const half = Math.floor(w / 2);
    const tl = torsoLeft(torsoTop);
    const tr = tl + torsoW(torsoTop) - 1;
    const sx = side < 0 ? tl - w + half : tr + 1 + half;
    const sy = torsoTop + half + (stage === 0 ? 1 : 0);
    const spread = Math.round(lift * 2 + bulk);
    let elbow: Pt;
    let wrist: Pt;
    if (i.pose === 'flex') {
      elbow = { x: sx + side * (upperArmLen - 1), y: sy + 1 };
      wrist = { x: elbow.x + side, y: elbow.y - forearmLen };
    } else {
      elbow = { x: sx + side * spread, y: sy + upperArmLen };
      wrist = { x: elbow.x, y: elbow.y + forearmLen };
    }
    const hw = handW;
    const hand =
      i.pose === 'flex'
        ? { x: wrist.x - Math.floor(hw / 2), y: wrist.y - 3, w: hw, h: 3 }
        : { x: wrist.x - Math.floor(hw / 2), y: wrist.y + Math.floor(forearmW / 2), w: hw, h: 3 };
    return { shoulder: { x: sx, y: sy }, elbow, wrist, upperW: w, foreW: forearmW, hand, side };
  };

  const thighLen = Math.round(legLen * 0.5);
  const makeLeg = (side: -1 | 1): Leg => {
    const x = side < 0 ? cx - 1 - thighW : cx + 1;
    const calfX = x + Math.floor((thighW - calfW) / 2);
    return { x, thighW, calfX, calfW, top: legTop, kneeY: legTop + thighLen, side };
  };
  const legL = makeLeg(-1);
  const legR = makeLeg(1);

  return {
    t: { bulk, lift, climb, run, ride },
    stage,
    cx,
    baseline,
    bob,
    headW,
    headH,
    headTop,
    headLeft,
    eyeY,
    neckW,
    neckTop,
    neckH,
    torsoTop,
    torsoBottom,
    torsoH,
    shoulderW,
    waistW,
    torsoW,
    torsoLeft,
    armL: makeArm(-1),
    armR: makeArm(1),
    legL,
    legR,
    legTop,
    legLen,
    feetTop,
    footH,
    footL: { x: legL.x - 1, w: thighW + 1 },
    footR: { x: legR.x, w: thighW + 1 },
    pose: i.pose,
    skin: SKIN_TONES[i.skin % SKIN_TONES.length],
    hair: HAIR_COLORS[i.hairColor % HAIR_COLORS.length],
  };
}

export type Visuals = Partial<Record<Slot, ItemVisual | null>>;

export function drawArmSkin(p: Pix, a: Arm, color: string) {
  p.limb(a.shoulder.x, a.shoulder.y, a.elbow.x, a.elbow.y, a.upperW, color);
  p.limb(a.elbow.x, a.elbow.y, a.wrist.x, a.wrist.y, a.foreW, color);
}

function drawLegsSkin(p: Pix, m: Metrics) {
  for (const leg of [m.legL, m.legR]) {
    p.rect(leg.x, leg.top, leg.thighW, leg.kneeY - leg.top, m.skin);
    p.rect(leg.calfX, leg.kneeY, leg.calfW, m.feetTop - leg.kneeY, m.skin);
    // calf bump on the outside
    if (leg.calfW >= 3 && m.t.run + m.t.ride > 0.5) {
      const bx = leg.side < 0 ? leg.calfX - 1 : leg.calfX + leg.calfW;
      p.rect(bx, leg.kneeY + 1, 1, 3, m.skin);
    }
  }
}

function drawTorsoSkin(p: Pix, m: Metrics) {
  for (let y = m.torsoTop; y <= m.torsoBottom; y++) {
    p.hline(m.torsoLeft(y), y, m.torsoW(y), m.skin);
  }
  // Deltoid caps
  if (m.t.lift > 0.3) {
    const tl = m.torsoLeft(m.torsoTop);
    const w = m.torsoW(m.torsoTop);
    p.set(tl - 1, m.torsoTop + 1, m.skin);
    p.set(tl + w, m.torsoTop + 1, m.skin);
  } else {
    // soften shoulders when scrawny
    const tl = m.torsoLeft(m.torsoTop);
    const w = m.torsoW(m.torsoTop);
    p.set(tl, m.torsoTop, null);
    p.set(tl + w - 1, m.torsoTop, null);
  }
}

function drawDefinition(p: Pix, m: Metrics) {
  const dark = shade(m.skin, 0.78);
  // pecs
  if (m.t.lift > 0.45 || m.t.bulk > 0.5) {
    const y = m.torsoTop + 4;
    p.hline(m.cx - 4, y, 3, dark);
    p.hline(m.cx + 1, y, 3, dark);
  }
  // abs
  if (m.t.run > 0.3 && m.t.bulk > 0.25) {
    const y0 = m.torsoTop + 6;
    for (let r = 0; r < 3; r++) {
      const y = y0 + r * 2;
      if (y >= m.torsoBottom - 1) break;
      p.set(m.cx - 2, y, dark);
      p.set(m.cx + 1, y, dark);
    }
    p.vline(m.cx - 1, y0, Math.min(6, m.torsoBottom - y0 - 1), mix(m.skin, dark, 0.5));
  }
}

function drawArmDefinition(p: Pix, m: Metrics) {
  const hi = shade(m.skin, 1.18);
  for (const a of [m.armL, m.armR]) {
    if (a.upperW >= 4) {
      // bicep highlight
      const mx = Math.round((a.shoulder.x + a.elbow.x) / 2) - Math.floor(a.upperW / 2);
      const my = m.pose === 'flex' ? a.shoulder.y - 1 : Math.round((a.shoulder.y + a.elbow.y) / 2) - 1;
      p.set(mx + (a.side < 0 ? 0 : a.upperW - 1), my, hi);
      if (m.pose === 'flex') p.rect(mx + 1, a.shoulder.y - Math.floor(a.upperW / 2) - 1, 2, 1, m.skin);
    }
    if (a.foreW >= 4) {
      const fx = a.wrist.x - Math.floor(a.foreW / 2);
      const fy = Math.round((a.elbow.y + a.wrist.y) / 2);
      p.set(fx + (a.side < 0 ? 0 : a.foreW - 1), fy, hi);
    }
  }
}

function drawHead(p: Pix, m: Metrics, i: BodyInput) {
  p.roundRect(m.headLeft, m.headTop, m.headW, m.headH, m.skin, 2);
  // ears
  p.rect(m.headLeft - 1, m.headTop + 5, 1, 2, m.skin);
  p.rect(m.headLeft + m.headW, m.headTop + 5, 1, 2, m.skin);
  // cheek shade
  const cheek = shade(m.skin, 0.88);
  p.vline(m.headLeft + m.headW - 1, m.headTop + 2, m.headH - 4, cheek);
  // eyes
  const eye = OUTLINE;
  const lx = m.cx - 3;
  const rx = m.cx + 2;
  if (i.blink) {
    p.set(lx, m.eyeY + 1, eye);
    p.set(rx, m.eyeY + 1, eye);
  } else {
    p.rect(lx, m.eyeY, 1, 2, eye);
    p.rect(rx, m.eyeY, 1, 2, eye);
    p.set(lx, m.eyeY, '#ffffff');
    p.set(rx, m.eyeY, '#ffffff');
    p.set(lx, m.eyeY + 1, eye);
    p.set(rx, m.eyeY + 1, eye);
  }
  // brows
  if (m.stage === 0) {
    p.set(lx + 1, m.eyeY - 2, shade(m.skin, 0.7));
    p.set(rx - 1, m.eyeY - 2, shade(m.skin, 0.7));
  } else if (m.stage >= 3) {
    p.set(lx, m.eyeY - 2, shade(m.skin, 0.6));
    p.set(lx + 1, m.eyeY - 1, shade(m.skin, 0.6));
    p.set(rx, m.eyeY - 2, shade(m.skin, 0.6));
    p.set(rx - 1, m.eyeY - 1, shade(m.skin, 0.6));
  }
  // mouth
  const mouth = shade(m.skin, 0.6);
  const my = m.headTop + 8;
  if (i.happy) {
    p.hline(m.cx - 1, my + 1, 2, mouth);
    p.set(m.cx - 2, my, mouth);
    p.set(m.cx + 1, my, mouth);
    p.set(m.cx - 3, my, '#ff9aa2');
    p.set(m.cx + 2, my, '#ff9aa2');
  } else if (m.stage === 0) {
    p.hline(m.cx - 1, my + 1, 2, mouth);
  } else {
    p.hline(m.cx - 1, my, 2, mouth);
    if (m.stage >= 2) p.set(m.cx + 1, my - 1, mouth);
  }
}

function drawHair(p: Pix, m: Metrics, i: BodyInput, hatCoversTop: boolean) {
  const c = m.hair;
  const dark = shade(c, 0.75);
  const style = i.hairStyle % HAIR_STYLES.length;
  const x = m.headLeft;
  const y = m.headTop;
  if (style === 5) {
    // buzz
    if (!hatCoversTop) p.roundRect(x, y, m.headW, 3, mix(m.skin, c, 0.55), 1);
    return;
  }
  if (style === 2) {
    // long: sides down past the shoulders
    p.rect(x - 1, y + 2, 2, m.headH + 2, c);
    p.rect(x + m.headW - 1, y + 2, 2, m.headH + 2, c);
    p.rect(x - 1, y + m.headH + 2, 2, 2, dark);
    p.rect(x + m.headW - 1, y + m.headH + 2, 2, 2, dark);
  }
  if (hatCoversTop) {
    // only sideburns / fringe peek out
    p.rect(x, y + 2, 1, 3, c);
    p.rect(x + m.headW - 1, y + 2, 1, 3, c);
    return;
  }
  // base cap
  p.roundRect(x, y - 1, m.headW, 4, c, 1);
  p.rect(x, y + 2, 1, 3, c);
  p.rect(x + m.headW - 1, y + 2, 1, 3, c);
  // fringe
  p.set(x + 3, y + 3, c);
  p.set(x + 8, y + 3, c);
  switch (style) {
    case 1: // spiky
      p.set(x + 1, y - 2, c);
      p.set(x + 4, y - 2, c);
      p.set(x + 7, y - 2, c);
      p.set(x + 10, y - 2, c);
      p.set(x + 2, y - 3, c);
      p.set(x + 6, y - 3, c);
      p.set(x + 9, y - 3, c);
      break;
    case 3: // bun
      p.roundRect(x + 4, y - 4, 4, 3, c, 1);
      p.set(x + 5, y - 3, dark);
      break;
    case 4: // curly
      for (let k = 0; k < m.headW; k += 2) p.set(x + k, y - 2, c);
      for (let k = 1; k < m.headW; k += 2) p.set(x + k, y - 3, c);
      p.rect(x - 1, y, 1, 4, c);
      p.rect(x + m.headW, y, 1, 4, c);
      break;
    case 6: // mohawk
      p.rect(x, y - 1, m.headW, 4, null);
      p.rect(x, y + 2, 1, 2, mix(m.skin, c, 0.5));
      p.rect(x + m.headW - 1, y + 2, 1, 2, mix(m.skin, c, 0.5));
      p.rect(x + 5, y - 4, 2, 5, c);
      p.set(x + 4, y - 2, c);
      p.set(x + 7, y - 2, c);
      break;
  }
}

/** Darken the right-most pixel of every horizontal run: cheap pixel-art lighting. */
function shadeRuns(p: Pix) {
  for (let y = 0; y < p.h; y++) {
    let x = 0;
    while (x < p.w) {
      const c = p.get(x, y);
      if (!c) {
        x++;
        continue;
      }
      let run = 1;
      while (x + run < p.w && p.get(x + run, y) === c) run++;
      if (run >= 3) p.set(x + run - 1, y, shade(c, 0.82));
      x += run;
    }
  }
}

export interface DrawOptions {
  visuals: Visuals;
  /** Skip the outline (used when compositing into a scene that outlines later). */
  noOutline?: boolean;
}

export function drawHero(p: Pix, i: BodyInput, opts: DrawOptions): Metrics {
  const m = bodyMetrics(i);
  const v = opts.visuals;
  const frame = i.frame;

  if (v.back) drawBackItem(p, v.back, m, frame);

  drawLegsSkin(p, m);
  if (v.legs) drawLegGarment(p, v.legs, m);
  if (v.body && v.body.kind === 'singlet') drawLegGarment(p, { kind: 'shorts', color: v.body.color }, m);

  drawTorsoSkin(p, m);
  drawArmSkin(p, m.armL, m.skin);
  drawArmSkin(p, m.armR, m.skin);
  // hands (skin)
  for (const a of [m.armL, m.armR]) p.rect(a.hand.x, a.hand.y, a.hand.w, a.hand.h, m.skin);

  if (v.body) drawBodyGarment(p, v.body, m);
  else drawDefinition(p, m);
  drawArmDefinition(p, m);

  if (v.hands) drawHands(p, v.hands, m);
  if (v.accessory) drawAccessory(p, v.accessory, m, frame);

  drawFeet(p, v.feet ?? null, m, frame);

  // neck
  p.rect(m.cx - Math.floor(m.neckW / 2), m.neckTop, m.neckW, m.neckH + 1, m.skin);

  drawHead(p, m, i);
  const hat = v.head;
  const coversTop = !!hat && ['beanie', 'cap', 'helmet', 'bandana'].includes(hat.kind) && !(hat.kind === 'cap' && hat.visor);
  drawHair(p, m, i, coversTop);
  if (hat) drawHeadItem(p, hat, m);
  if (v.face) drawFaceItem(p, v.face, m);

  shadeRuns(p);
  if (!opts.noOutline) p.outline(OUTLINE);
  if (v.aura && v.aura.kind === 'aura') drawAura(p, v.aura.style, m, frame);
  return m;
}
