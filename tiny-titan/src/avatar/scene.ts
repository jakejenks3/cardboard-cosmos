// The hero's home gym. It fills up with equipment as disciplines level up.

import { Pix, shade } from './pixel';
import { makeRng } from '../game/rng';

export const SCENE_W = 96;
export const SCENE_H = 72;
/** Where the hero buffer is blitted. Hero baseline lands on FLOOR_Y - 1. */
export const HERO_X = 24;
export const HERO_Y = 10;
export const FLOOR_Y = 67;

export interface SceneInput {
  stage: number;
  liftLevel: number;
  climbLevel: number;
  runLevel: number;
  rideLevel: number;
  achievements: number;
  sessions: number;
  /** 0-23 local hour for the window. */
  hour: number;
  frame: number;
}

const WALLS = ['#3a3350', '#3d3a5e', '#43406c', '#494578', '#4f4a82', '#58508f'];
const FLOORS = ['#2b2540', '#2e2a48', '#332e52', '#36305a', '#3a3460', '#3f3868'];

function skyColors(hour: number): { sky: string; sky2: string; night: boolean; dawn: boolean } {
  if (hour >= 6 && hour < 8) return { sky: '#ffb27a', sky2: '#ffd9a0', night: false, dawn: true };
  if (hour >= 8 && hour < 18) return { sky: '#6fc3ff', sky2: '#bfe6ff', night: false, dawn: false };
  if (hour >= 18 && hour < 20) return { sky: '#ff7f6e', sky2: '#8e5aa8', night: false, dawn: true };
  return { sky: '#1b1f4b', sky2: '#2a2f6b', night: true, dawn: false };
}

export function drawScene(p: Pix, s: SceneInput) {
  const wall = WALLS[Math.min(5, s.stage)];
  const floor = FLOORS[Math.min(5, s.stage)];
  p.rect(0, 0, SCENE_W, FLOOR_Y, wall);
  p.rect(0, FLOOR_Y, SCENE_W, SCENE_H - FLOOR_Y, floor);
  // floor mats
  for (let x = 0; x < SCENE_W; x += 12) p.vline(x, FLOOR_Y, SCENE_H - FLOOR_Y, shade(floor, 0.85));
  p.hline(0, FLOOR_Y, SCENE_W, shade(floor, 1.25));
  // wainscot
  if (s.stage >= 2) {
    p.rect(0, 56, SCENE_W, FLOOR_Y - 56, shade(wall, 0.9));
    p.hline(0, 56, SCENE_W, shade(wall, 1.25));
  }
  // baseboard
  p.hline(0, FLOOR_Y - 1, SCENE_W, shade(wall, 0.75));

  // --- window -------------------------------------------------------------
  {
    const x = 6;
    const y = 12;
    const w = 16;
    const h = 14;
    const sky = skyColors(s.hour);
    p.rect(x - 1, y - 1, w + 2, h + 2, '#d9c8a9');
    p.rect(x, y, w, h, sky.sky);
    p.rect(x, y, w, 5, sky.sky2);
    if (sky.night) {
      p.set(x + 3, y + 2, '#ffffff');
      p.set(x + 9, y + 4, '#ffffff');
      p.set(x + 12, y + 1, '#ffffff');
      p.rect(x + 10, y + 6, 3, 3, '#fff3b0');
      p.set(x + 11, y + 7, sky.sky);
    } else if (!sky.dawn) {
      p.rect(x + 11, y + 2, 3, 3, '#fff176');
    } else {
      p.rect(x + 2, y + 8, 4, 2, '#ffe0b2');
    }
    // hills
    p.rect(x, y + h - 4, w, 4, sky.night ? '#15213a' : '#4f8f5a');
    p.hline(x + 2, y + h - 5, 5, sky.night ? '#15213a' : '#4f8f5a');
    p.hline(x + 9, y + h - 6, 6, sky.night ? '#15213a' : '#4f8f5a');
    // cross bars
    p.vline(x + Math.floor(w / 2), y, h, '#d9c8a9');
    p.hline(x, y + Math.floor(h / 2), w, '#d9c8a9');
  }

  // --- poster -------------------------------------------------------------
  {
    const x = 74;
    const y = 14;
    p.rect(x, y, 10, 12, '#f4ecd8');
    p.rect(x + 1, y + 1, 8, 6, ['#ff7a59', '#8ad46a', '#5ad1e6', '#c792ea'][s.stage % 4]);
    p.hline(x + 2, y + 8, 6, '#555555');
    p.hline(x + 2, y + 10, 4, '#777777');
    p.set(x + 1, y + 2, '#fff3b0');
  }

  // --- trophy shelf -------------------------------------------------------
  if (s.achievements >= 3) {
    const x = 2;
    const y = 8;
    p.hline(x, y, 22, '#8d6e4c');
    p.hline(x, y + 1, 22, '#6b4f36');
    const n = Math.min(5, Math.floor(s.achievements / 6) + 1);
    for (let i = 0; i < n; i++) {
      const tx = x + 1 + i * 4;
      const gold = i % 3 === 0 ? '#ffd54f' : i % 3 === 1 ? '#cfd8dc' : '#ffab91';
      p.rect(tx, y - 4, 3, 3, gold);
      p.set(tx + 1, y - 1, shade(gold, 0.7));
      p.set(tx, y - 5, gold);
      p.set(tx + 2, y - 5, gold);
    }
  }

  // --- string lights ------------------------------------------------------
  if (s.stage >= 3) {
    p.hline(0, 2, SCENE_W, '#2a2340');
    const cols = ['#ff5252', '#ffd740', '#69f0ae', '#40c4ff', '#ff4081'];
    for (let x = 3; x < SCENE_W; x += 6) {
      const i = (x / 6) | 0;
      const on = (i + s.frame) % 5 !== 0;
      p.set(x, 3, on ? cols[i % cols.length] : shade(cols[i % cols.length], 0.5));
      if (on && s.frame % 2 === 0) p.set(x, 4, shade(cols[i % cols.length], 1.4));
    }
  }

  // --- climbing wall (center, behind the hero) ----------------------------
  if (s.climbLevel >= 1) {
    const rng = makeRng('holds');
    const n = Math.min(16, 3 + s.climbLevel);
    const cols = ['#ff5252', '#ffd740', '#69f0ae', '#40c4ff', '#ff4081', '#ffab40'];
    for (let i = 0; i < n; i++) {
      const hx = 28 + rng.int(40);
      const hy = 7 + rng.int(28);
      const c = cols[i % cols.length];
      const shapeW = 2 + rng.int(2);
      p.rect(hx, hy, shapeW, 2, c);
      p.set(hx, hy, shade(c, 1.3));
    }
    if (s.climbLevel >= 8) {
      // hangboard
      p.rect(36, 4, 24, 4, '#a9825a');
      p.hline(36, 4, 24, '#c9a27a');
      for (let k = 0; k < 4; k++) p.rect(38 + k * 6, 6, 3, 1, '#4e3a28');
    }
  }

  // --- squat rack + dumbbells (left) --------------------------------------
  if (s.liftLevel >= 10) {
    p.rect(3, 24, 2, 43, '#5c6673');
    p.rect(19, 24, 2, 43, '#5c6673');
    p.hline(3, 24, 18, '#5c6673');
    for (let y = 30; y < 60; y += 6) {
      p.set(5, y, '#8a97a6');
      p.set(18, y, '#8a97a6');
    }
    // loaded bar on the rack
    p.hline(0, 34, 24, '#aab2bd');
    p.rect(0, 31, 2, 7, '#d64545');
    p.rect(22, 31, 2, 7, '#d64545');
  }
  if (s.liftLevel >= 3) {
    const x = 2;
    const shelves = s.liftLevel >= 6 ? 2 : 1;
    for (let sh = 0; sh < shelves; sh++) {
      const y = FLOOR_Y - 2 - sh * 6;
      p.hline(x, y, 18, '#4a3a2c');
      p.hline(x, y + 1, 18, '#2e2419');
      for (let d = 0; d < 3; d++) {
        const dx = x + 1 + d * 6;
        const c = ['#9e9e9e', '#78909c', '#546e7a'][(d + sh) % 3];
        p.rect(dx, y - 3, 1, 3, c);
        p.rect(dx + 3, y - 3, 1, 3, c);
        p.hline(dx + 1, y - 2, 2, '#bdbdbd');
      }
    }
    p.vline(x, FLOOR_Y - 2 - (shelves - 1) * 6, (shelves - 1) * 6 + 2, '#4a3a2c');
    p.vline(x + 17, FLOOR_Y - 2 - (shelves - 1) * 6, (shelves - 1) * 6 + 2, '#4a3a2c');
  }

  // --- bike on the wall (right) --------------------------------------------
  if (s.rideLevel >= 5) {
    const bx = 66;
    const by = 30;
    const tire = '#263238';
    const rim = '#90a4ae';
    const frameC = s.rideLevel >= 20 ? '#ffeb3b' : '#e53935';
    for (const cx of [bx + 5, bx + 20]) {
      p.ellipse(cx, by + 10, 5, 5, tire);
      p.ellipse(cx, by + 10, 3.5, 3.5, wall);
      p.set(cx, by + 10, rim);
      p.set(cx - 2, by + 10, rim);
      p.set(cx + 2, by + 10, rim);
      p.set(cx, by + 8, rim);
      p.set(cx, by + 12, rim);
    }
    p.limb(bx + 5, by + 10, bx + 11, by + 3, 1, frameC);
    p.limb(bx + 11, by + 3, bx + 18, by + 3, 1, frameC);
    p.limb(bx + 18, by + 3, bx + 20, by + 10, 1, frameC);
    p.limb(bx + 11, by + 3, bx + 12, by + 10, 1, frameC);
    p.limb(bx + 12, by + 10, bx + 5, by + 10, 1, frameC);
    p.limb(bx + 12, by + 10, bx + 18, by + 3, 1, frameC);
    p.rect(bx + 10, by + 1, 3, 1, '#263238'); // saddle
    p.rect(bx + 18, by + 1, 2, 1, '#263238'); // bars
    // wall hook
    p.vline(bx + 12, by - 4, 5, '#5c6673');
  }

  // --- treadmill (right, behind the pet) ----------------------------------
  if (s.runLevel >= 5) {
    const x = 62;
    p.rect(x, FLOOR_Y - 4, 29, 4, '#37474f');
    p.rect(x + 1, FLOOR_Y - 3, 27, 2, '#546e7a');
    for (let k = 0; k < 27; k += 3) p.set(x + 1 + ((k + s.frame) % 27), FLOOR_Y - 2, '#90a4ae');
    p.rect(x + 25, FLOOR_Y - 16, 2, 12, '#546e7a');
    p.rect(x + 20, FLOOR_Y - 19, 10, 4, '#37474f');
    p.rect(x + 21, FLOOR_Y - 18, 5, 2, s.frame % 6 < 3 ? '#69f0ae' : '#40c4ff');
  }

  // --- plant --------------------------------------------------------------
  if (s.sessions >= 5) {
    const x = 86;
    p.rect(x, FLOOR_Y - 6, 6, 6, '#b5651d');
    p.hline(x - 1, FLOOR_Y - 6, 8, '#d2843b');
    const g = '#43a047';
    const g2 = '#66bb6a';
    p.rect(x + 1, FLOOR_Y - 12, 4, 6, g);
    p.set(x, FLOOR_Y - 10, g2);
    p.set(x + 5, FLOOR_Y - 11, g2);
    p.set(x - 1, FLOOR_Y - 9, g);
    p.set(x + 6, FLOOR_Y - 10, g);
    p.set(x + 2, FLOOR_Y - 14, g2);
    p.set(x + 3, FLOOR_Y - 13, g);
    p.set(x + 1, FLOOR_Y - 13, g);
  }

  // --- rug ----------------------------------------------------------------
  if (s.stage >= 2) {
    p.rect(28, FLOOR_Y + 1, 40, 3, '#8e2a3a');
    p.hline(28, FLOOR_Y + 1, 40, '#c9a24c');
    p.hline(28, FLOOR_Y + 3, 40, '#c9a24c');
  }
}
