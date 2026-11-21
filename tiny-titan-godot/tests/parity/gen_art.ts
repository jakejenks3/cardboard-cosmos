// Generates the pixel-parity fixtures for the Godot art port.
//
//   cd tiny-titan && npx tsx ../tiny-titan-godot/tests/parity/gen_art.ts
//
// It renders heroes, scenes, pets and bosses with the REAL TypeScript drawing
// code (the `Pix` buffer, no DOM / canvas needed) and writes art_cases.json
// next to this file. tests/parity_art.gd renders the same cases with the
// GDScript port and compares the raw RGBA bytes.
//
// Never edit art_cases.json by hand: fix the GDScript until it matches.

import { writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { Pix, OUTLINE } from '../../../tiny-titan/src/avatar/pixel';
import { drawHero, HERO_W, HERO_H, type BodyInput, type Visuals } from '../../../tiny-titan/src/avatar/body';
import { drawScene, SCENE_W, SCENE_H, HERO_X, HERO_Y, FLOOR_Y } from '../../../tiny-titan/src/avatar/scene';
import { drawPet, PET_SPRITES } from '../../../tiny-titan/src/avatar/petSprites';
import { bossBuffer } from '../../../tiny-titan/src/avatar/bossSprites';
import { visualsFromLoadout } from '../../../tiny-titan/src/avatar/HeroScene';
import { ITEMS } from '../../../tiny-titan/src/game/items';
import { PETS } from '../../../tiny-titan/src/game/pets';
import { BOSSES } from '../../../tiny-titan/src/game/campaign';
import { initialState, type PlayerState } from '../../../tiny-titan/src/game/state';
import { stageForLevel } from '../../../tiny-titan/src/game/xp';
import { SLOTS, type Loadout, type Profile, type Slot } from '../../../tiny-titan/src/game/types';

// --- colour → RGBA -----------------------------------------------------------

/** CSS Color 4 hsl() → rgb, each channel rounded half-up to 0-255. */
function hslToRgb(h: number, s: number, l: number): [number, number, number] {
  const sat = s / 100;
  const lig = l / 100;
  const a = sat * Math.min(lig, 1 - lig);
  const f = (n: number) => {
    const k = (n + h / 30) % 12;
    return lig - a * Math.max(-1, Math.min(Math.min(k - 3, 9 - k), 1));
  };
  const ch = (v: number) => Math.max(0, Math.min(255, Math.round(v * 255)));
  return [ch(f(0)), ch(f(8)), ch(f(4))];
}

function colorToRgb(c: string): [number, number, number] {
  if (c.startsWith('#')) {
    let h = c.slice(1);
    if (h.length === 3) h = h.split('').map((x) => x + x).join('');
    if (!/^[0-9a-fA-F]{6}$/.test(h)) throw new Error(`bad hex colour ${c}`);
    const n = parseInt(h, 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  const m = /^hsl\((-?\d+(?:\.\d+)?), (\d+(?:\.\d+)?)%, (\d+(?:\.\d+)?)%\)$/.exec(c);
  if (m) return hslToRgb(Number(m[1]), Number(m[2]), Number(m[3]));
  throw new Error(`unsupported colour ${c}`);
}

function rgbaBase64(p: Pix): string {
  const out = Buffer.alloc(p.w * p.h * 4);
  for (let i = 0; i < p.w * p.h; i++) {
    const c = p.data[i];
    if (!c) continue;
    const [r, g, b] = colorToRgb(c);
    out[i * 4] = r;
    out[i * 4 + 1] = g;
    out[i * 4 + 2] = b;
    out[i * 4 + 3] = 255;
  }
  return out.toString('base64');
}

// --- state builders ----------------------------------------------------------

interface Levels {
  hero: number;
  lift: number;
  climb: number;
  run: number;
  ride: number;
}

interface StateOpts {
  items?: string[];
  pets?: string[];
  achievements?: number;
  sessions?: number;
  stage?: number;
}

/** A PlayerState shaped like initialState(), with only what the art reads filled in. */
function makeState(lv: Levels, o: StateOpts = {}): PlayerState {
  const s = initialState(3);
  s.levels.hero.level = lv.hero;
  s.levels.lift.level = lv.lift;
  s.levels.climb.level = lv.climb;
  s.levels.run.level = lv.run;
  s.levels.ride.level = lv.ride;
  s.stage = o.stage ?? stageForLevel(lv.hero);
  for (const id of o.items ?? []) s.items[id] = { at: '2026-01-01', how: 'unlock' };
  for (const id of o.pets ?? []) s.pets[id] = { at: '2026-01-01' };
  for (let i = 0; i < (o.achievements ?? 0); i++) s.achievements[`a${i}`] = { at: '2026-01-01' };
  s.totals.sessions = o.sessions ?? 0;
  return s;
}

function ownedFrom(loadout: Loadout): string[] {
  return Object.values(loadout).filter((x): x is string => !!x);
}

// --- renderers (the same composition HeroScene.tsx does in render()) ---------

function heroInput(state: PlayerState, profile: Profile, pose: 'idle' | 'flex', frame: number, happy: boolean): BodyInput {
  return {
    heroLevel: state.levels.hero.level,
    liftLevel: state.levels.lift.level,
    climbLevel: state.levels.climb.level,
    runLevel: state.levels.run.level,
    rideLevel: state.levels.ride.level,
    skin: profile.skin,
    hairStyle: profile.hairStyle,
    hairColor: profile.hairColor,
    pose,
    frame,
    // HeroScene's tick: blinkRef = frameRef % 18 === 0 after each increment,
    // and false before the first tick (frame 0).
    blink: frame > 0 && frame % 18 === 0,
    happy: happy || pose === 'flex',
  };
}

function renderHero(state: PlayerState, profile: Profile, loadout: Loadout, pose: 'idle' | 'flex', frame: number, happy: boolean): Pix {
  const hero = new Pix(HERO_W, HERO_H);
  drawHero(hero, heroInput(state, profile, pose, frame, happy), { visuals: visualsFromLoadout(loadout, state) });
  return hero;
}

function renderScene(state: PlayerState, profile: Profile, loadout: Loadout, activePet: string | null, pose: 'idle' | 'flex', frame: number, hour: number, happy: boolean): Pix {
  const hero = renderHero(state, profile, loadout, pose, frame, happy);
  const buf = new Pix(SCENE_W, SCENE_H);
  drawScene(buf, {
    stage: state.stage,
    liftLevel: state.levels.lift.level,
    climbLevel: state.levels.climb.level,
    runLevel: state.levels.run.level,
    rideLevel: state.levels.ride.level,
    achievements: Object.keys(state.achievements).length,
    sessions: state.totals.sessions,
    hour,
    frame,
  });
  buf.blit(hero, HERO_X, HERO_Y);
  if (activePet && state.pets[activePet]) drawPet(buf, activePet, 70, FLOOR_Y, frame);
  return buf;
}

/** The tight outlined pet buffer (PetPortrait in Armory.tsx, for any frame). */
function renderPet(id: string, frame: number): Pix {
  const sp = PET_SPRITES[id];
  const rows = sp.frames[frame % sp.frames.length];
  const w = Math.max(...rows.map((r) => r.length)) + 2;
  const h = rows.length + 2;
  const buf = new Pix(w, h);
  buf.sprite(1, 1, rows, sp.palette);
  buf.outline(OUTLINE);
  return buf;
}

// The "items by slot" mannequin of AvatarPreview.tsx: a Lv25 balanced body in
// the starter kit, everything owned, static (frame 0, idle).
const PREVIEW_PROFILE: Profile = { name: 'Preview', skin: 1, hairStyle: 0, hairColor: 1, createdAt: 0 };
const STARTER: Loadout = { body: 'tee_grey', legs: 'shorts_navy', feet: 'trainers_worn' };
const MANNEQUIN_LEVELS: Levels = { hero: 25, lift: 15, climb: 15, run: 15, ride: 15 };

function renderItem(id: string): Pix {
  const item = ITEMS.find((i) => i.id === id);
  const loadout: Loadout = item ? { ...STARTER, [item.slot]: id } : { ...STARTER };
  const state = makeState(MANNEQUIN_LEVELS, { items: ITEMS.map((i) => i.id) });
  return renderHero(state, PREVIEW_PROFILE, loadout, 'idle', 0, false);
}

// --- cases -------------------------------------------------------------------

interface Case {
  name: string;
  kind: 'hero' | 'visuals' | 'scene' | 'pet' | 'boss' | 'item';
  args: Record<string, unknown>;
  w: number;
  h: number;
  rgba: string;
}

const cases: Case[] = [];

function push(name: string, kind: Case['kind'], args: Record<string, unknown>, p: Pix) {
  if (cases.some((c) => c.name === name)) throw new Error(`duplicate case name ${name}`);
  cases.push({ name, kind, args, w: p.w, h: p.h, rgba: rgbaBase64(p) });
}

function heroCase(name: string, lv: Levels, profile: Profile, loadout: Loadout, pose: 'idle' | 'flex', frame: number, opts: { happy?: boolean; owned?: string[] } = {}) {
  const state = makeState(lv, { items: opts.owned ?? ownedFrom(loadout) });
  const happy = opts.happy ?? false;
  push(name, 'hero', { state, profile, loadout, pose, frame, happy }, renderHero(state, profile, loadout, pose, frame, happy));
}

const prof = (skin: number, hairStyle: number, hairColor: number): Profile => ({ name: 'Parity', skin, hairStyle, hairColor, createdAt: 0 });

const MIXES: [string, Levels][] = [
  ['scrawny', { hero: 1, lift: 1, climb: 1, run: 1, ride: 1 }],
  ['lv6', { hero: 6, lift: 4, climb: 2, run: 3, ride: 1 }],
  ['lifter14', { hero: 14, lift: 14, climb: 3, run: 3, ride: 2 }],
  ['climber14', { hero: 14, lift: 3, climb: 14, run: 3, ride: 2 }],
  ['runner14', { hero: 14, lift: 3, climb: 3, run: 14, ride: 2 }],
  ['rider14', { hero: 14, lift: 3, climb: 3, run: 2, ride: 14 }],
  ['balanced25', { hero: 25, lift: 15, climb: 15, run: 15, ride: 15 }],
  ['jacked40', { hero: 40, lift: 32, climb: 20, run: 20, ride: 18 }],
  ['titan60', { hero: 60, lift: 40, climb: 40, run: 40, ride: 40 }],
  ['lift_ride_only', { hero: 30, lift: 36, climb: 1, run: 1, ride: 36 }],
  ['run_only', { hero: 8, lift: 1, climb: 1, run: 36, ride: 1 }],
  ['bulk_only', { hero: 51, lift: 1, climb: 1, run: 1, ride: 1 }],
];

// 1. Bodies: every level mix, shirtless idle and starter-kit flex.
MIXES.forEach(([label, lv], k) => {
  heroCase(`body_${label}_idle_f0_shorts`, lv, PREVIEW_PROFILE, { legs: 'shorts_navy' }, 'idle', 0);
  heroCase(`body_${label}_flex_f${k % 4}_starter`, lv, PREVIEW_PROFILE, STARTER, 'flex', k % 4);
});
// Bob, blink, happy and a completely bare hero.
heroCase('body_scrawny_bare_idle_f0', MIXES[0][1], prof(0, 0, 0), {}, 'idle', 0);
heroCase('body_titan60_bare_flex_f5', MIXES[8][1], prof(5, 6, 4), {}, 'flex', 5);
heroCase('body_lv6_idle_f2_bob', MIXES[1][1], PREVIEW_PROFILE, STARTER, 'idle', 2);
heroCase('body_balanced25_idle_f18_blink', MIXES[6][1], PREVIEW_PROFILE, STARTER, 'idle', 18);
heroCase('body_jacked40_idle_f36_blink_shorts', MIXES[7][1], prof(3, 2, 6), { legs: 'shorts_navy' }, 'idle', 36);
heroCase('body_lifter14_idle_f1_happy', MIXES[2][1], PREVIEW_PROFILE, STARTER, 'idle', 1, { happy: true });

// 2. Hair styles × skin tones × hair colours.
for (let h = 0; h < 7; h++) {
  heroCase(`hair_style${h}_skin${h % 6}_color${(h * 3) % 10}`, MIXES[1][1], prof(h % 6, h, (h * 3) % 10), STARTER, 'idle', 0);
}
heroCase('hair_style9_wraps_skin7_color12', MIXES[4][1], prof(7, 9, 12), STARTER, 'idle', 3);

// 3. Gear: every item at least twice (idle + flex). Loadout k wears the k-th
// item of every slot (wrapping), on a rotating body, skin and haircut.
const bySlot: Record<string, string[]> = {};
for (const it of ITEMS) (bySlot[it.slot] ??= []).push(it.id);
const rounds = Math.max(...Object.values(bySlot).map((a) => a.length));
const IDLE_FRAMES = [0, 1, 2, 3, 8, 5, 6, 7, 16, 9, 10, 11, 40, 13, 14, 15];
for (let k = 0; k < rounds; k++) {
  const loadout: Loadout = {};
  for (const slot of SLOTS) {
    const ids = bySlot[slot] ?? [];
    if (ids.length) loadout[slot as Slot] = ids[k % ids.length];
  }
  const [label, lv] = MIXES[(k * 5 + 2) % MIXES.length];
  const profile = prof(k % 6, (k + 2) % 7, (k * 7) % 10);
  const fi = IDLE_FRAMES[k % IDLE_FRAMES.length];
  const ff = k * 13 + 3;
  heroCase(`gear${k}_${label}_idle_f${fi}`, lv, profile, loadout, 'idle', fi);
  heroCase(`gear${k}_${label}_flex_f${ff}`, lv, profile, loadout, 'flex', ff);
}

// Animated pieces at the frames where they change, and big frame numbers.
heroCase('anim_medal_f8_sparkle', MIXES[6][1], PREVIEW_PROFILE, { ...STARTER, accessory: 'marathon_medal' }, 'idle', 8);
heroCase('anim_wings_cape_f0', MIXES[4][1], prof(2, 2, 3), { ...STARTER, feet: 'winged_sandals', back: 'golden_cape' }, 'idle', 0);
heroCase('anim_wings_cape_f3', MIXES[4][1], prof(2, 2, 3), { ...STARTER, feet: 'winged_sandals', back: 'golden_cape' }, 'idle', 3);
heroCase('anim_flame_f1000', MIXES[7][1], prof(4, 1, 4), { ...STARTER, aura: 'flame_aura' }, 'idle', 1000);
heroCase('anim_gold_f777', MIXES[8][1], prof(0, 3, 3), { legs: 'galaxy_tights', aura: 'titan_aura' }, 'flex', 777);
heroCase('anim_frost_f123', MIXES[0][1], prof(1, 4, 6), { body: 'hoodie_grey', aura: 'frost_aura' }, 'idle', 123);
heroCase('anim_rainbow_f58', MIXES[6][1], prof(3, 6, 7), { body: 'singlet_red', aura: 'rainbow_aura' }, 'idle', 58);
heroCase('anim_rainbow_f241', MIXES[1][1], prof(5, 5, 0), { ...STARTER, aura: 'rainbow_aura' }, 'flex', 241);
heroCase('anim_rainbow_f0_scrawny', MIXES[0][1], prof(0, 0, 0), { aura: 'rainbow_aura' }, 'idle', 0);

// Loadout filtering: unowned, unknown and null entries are not drawn.
heroCase(
  'filter_unowned_unknown_null',
  MIXES[3][1],
  PREVIEW_PROFILE,
  { head: 'iron_crown', body: 'tee_grey', legs: null, feet: 'no_such_item', back: 'hero_cape', face: 'aviators' },
  'idle',
  0,
  { owned: ['tee_grey', 'aviators', 'no_such_item'] },
);

// Template branches no catalog item reaches (optional colours left out, a
// visual in the wrong slot, noOutline): drawHero() is fed visuals directly.
function visualsCase(name: string, lv: Levels, profile: Profile, visuals: Visuals, pose: 'idle' | 'flex', frame: number, noOutline = false) {
  const input = heroInput(makeState(lv), profile, pose, frame, false);
  const p = new Pix(HERO_W, HERO_H);
  drawHero(p, input, { visuals, noOutline });
  push(name, 'visuals', { input, visuals, noOutline }, p);
}
visualsCase(
  'visuals_plain_sandals_beanie_backpack_tank',
  MIXES[6][1],
  prof(1, 2, 5),
  {
    feet: { kind: 'sandals', color: '#8d6e63' },
    head: { kind: 'beanie', color: '#3949ab' },
    back: { kind: 'backpack', color: '#00897b' },
    body: { kind: 'tank', color: '#eeeeee' },
    legs: { kind: 'shorts', color: '#455a64', accent: '#ffeb3b', knee: '#b0bec5' },
    hands: { kind: 'wraps', color: '#ffffff' },
    face: { kind: 'sunglasses', color: '#1565c0' },
  },
  'idle',
  1,
);
visualsCase(
  'visuals_soleless_shoes_singlet_visor_flex',
  MIXES[2][1],
  prof(3, 0, 2),
  {
    feet: { kind: 'shoes', color: '#3949ab', accent: '#ffffff' },
    body: { kind: 'singlet', color: '#1b5e20' },
    head: { kind: 'cap', color: '#c62828', visor: true },
    hands: { kind: 'gloves', color: '#6d4c41', fingerless: true },
    legs: { kind: 'tights', color: '#37474f' },
    accessory: { kind: 'bib', color: '#fffde7' },
  },
  'flex',
  2,
);
visualsCase(
  'visuals_wrong_slots_polka_no_outline',
  MIXES[0][1],
  prof(4, 1, 8),
  {
    feet: { kind: 'headband', color: '#ff0000' },
    body: { kind: 'shirt', color: '#6a1b9a', pattern: 'polka' },
    head: { kind: 'cap', color: '#00838f' },
    aura: { kind: 'cape', color: '#000000', inner: '#111111' },
    legs: null,
    back: { kind: 'aura', style: 'flame' },
    hands: { kind: 'belt', color: '#123456', buckle: '#654321' },
    accessory: { kind: 'shorts', color: '#abcdef' },
    face: { kind: 'bandana', color: '#fedcba' },
  },
  'idle',
  0,
  true,
);
visualsCase(
  'visuals_stripe_harness_longwraps_flex',
  MIXES[7][1],
  prof(5, 3, 1),
  {
    body: { kind: 'shirt', color: '#ef6c00', pattern: 'stripe' },
    legs: { kind: 'harness', color: '#c0ca33', shorts: '#283593' },
    hands: { kind: 'wraps', color: '#00acc1', long: true },
    head: { kind: 'helmet', color: '#fdd835' },
    feet: { kind: 'climbshoes', color: '#8e24aa' },
  },
  'flex',
  3,
);
visualsCase(
  'visuals_hood_headlamp_wingless_sandals',
  MIXES[4][1],
  prof(0, 4, 4),
  {
    body: { kind: 'shirt', color: '#2e7d32', pattern: 'hood' },
    head: { kind: 'headlamp', color: '#ffb300' },
    feet: { kind: 'sandals', color: '#5d4037', wings: false },
    accessory: { kind: 'pendant', color: '#e91e63' },
    back: { kind: 'saddlebag', color: '#795548' },
  },
  'idle',
  6,
);
visualsCase(
  'visuals_reflective_chalk_no_accents',
  MIXES[8][1],
  prof(2, 5, 6),
  {
    body: { kind: 'shirt', color: '#01579b', pattern: 'reflective' },
    hands: { kind: 'chalk' },
    legs: { kind: 'shorts', color: '#4e342e' },
    head: { kind: 'laurel', color: '#ffd54f', accent: '#7cb342' },
  },
  'idle',
  0,
);

// 4. Item thumbnails on the preview mannequin.
for (const id of ['iron_crown', 'midnight_cape', 'titan_aura', 'no_such_item']) {
  push(`item_${id}`, 'item', { id }, renderItem(id));
}

// 5. The home gym at several points of the journey.
interface SceneSpec {
  name: string;
  lv: Levels;
  stage?: number;
  achievements: number;
  sessions: number;
  hour: number;
  frame: number;
  pose: 'idle' | 'flex';
  pet: string | null;
  ownedPets?: string[];
  loadout: Loadout;
  profile: Profile;
}
const SCENES: SceneSpec[] = [
  { name: 'fresh_noon', lv: { hero: 1, lift: 1, climb: 1, run: 1, ride: 1 }, achievements: 0, sessions: 0, hour: 12, frame: 0, pose: 'idle', pet: null, loadout: STARTER, profile: PREVIEW_PROFILE },
  { name: 'early_dawn_slime', lv: { hero: 6, lift: 3, climb: 5, run: 5, ride: 5 }, achievements: 3, sessions: 5, hour: 7, frame: 3, pose: 'idle', pet: 'slime', loadout: STARTER, profile: prof(0, 1, 2) },
  { name: 'mid_dusk_bulldog', lv: { hero: 14, lift: 6, climb: 8, run: 9, ride: 12 }, achievements: 14, sessions: 40, hour: 19, frame: 7, pose: 'idle', pet: 'bulldog', loadout: { head: 'sweatband', body: 'sendy_tank', legs: 'harness', feet: 'climbing_shoes', accessory: 'chalk_bag' }, profile: prof(2, 3, 4) },
  { name: 'late_night_falcon_flex', lv: { hero: 25, lift: 10, climb: 13, run: 20, ride: 20 }, achievements: 30, sessions: 120, hour: 23, frame: 10, pose: 'flex', pet: 'falcon', loadout: { head: 'aero_helmet', body: 'yellow_jersey', legs: 'bib_shorts', feet: 'clipless_shoes', face: 'sport_shades' }, profile: prof(3, 2, 8) },
  { name: 'jacked_afternoon_phoenix', lv: { hero: 40, lift: 32, climb: 20, run: 20, ride: 18 }, achievements: 23, sessions: 300, hour: 16, frame: 2, pose: 'idle', pet: 'phoenix', loadout: { body: 'stringer_black', legs: 'knee_sleeves', feet: 'retro_kicks', back: 'barbell_back', accessory: 'leather_belt', hands: 'wrist_wraps' }, profile: prof(4, 5, 0) },
  { name: 'titan_small_hours_dragon_aura', lv: { hero: 60, lift: 40, climb: 40, run: 40, ride: 40 }, achievements: 60, sessions: 900, hour: 3, frame: 27, pose: 'idle', pet: 'dragon', loadout: { head: 'titans_laurel', legs: 'galaxy_tights', feet: 'winged_sandals', back: 'golden_cape', aura: 'titan_aura' }, profile: prof(1, 6, 7) },
  { name: 'pet_not_owned_sunrise', lv: { hero: 12, lift: 2, climb: 1, run: 4, ride: 4 }, achievements: 2, sessions: 4, hour: 6, frame: 5, pose: 'idle', pet: 'cat', ownedPets: [], loadout: STARTER, profile: prof(5, 4, 5) },
  { name: 'stage_ahead_of_levels_evening', lv: { hero: 22, lift: 9, climb: 7, run: 5, ride: 19 }, stage: 5, achievements: 6, sessions: 5, hour: 18, frame: 60, pose: 'idle', pet: 'greyhound', loadout: { body: 'polka_jersey', legs: 'split_shorts', feet: 'trail_shoes', aura: 'rainbow_aura' }, profile: prof(0, 2, 9) },
];
for (const sc of SCENES) {
  const state = makeState(sc.lv, {
    stage: sc.stage,
    items: ownedFrom(sc.loadout),
    pets: sc.ownedPets ?? (sc.pet ? [sc.pet] : []),
    achievements: sc.achievements,
    sessions: sc.sessions,
  });
  const happy = false;
  push(
    `scene_${sc.name}`,
    'scene',
    { state, profile: sc.profile, loadout: sc.loadout, activePet: sc.pet, pose: sc.pose, frame: sc.frame, hour: sc.hour, happy },
    renderScene(state, sc.profile, sc.loadout, sc.pet, sc.pose, sc.frame, sc.hour, happy),
  );
}

// 6. Pets: both frames of every companion.
for (const pet of PETS) {
  if (!PET_SPRITES[pet.id]) throw new Error(`pet ${pet.id} has no sprite`);
  for (const frame of [0, 1]) push(`pet_${pet.id}_f${frame}`, 'pet', { id: pet.id, frame }, renderPet(pet.id, frame));
}

// 7. Bosses: every campaign boss, the endless "echo" look and two silhouettes.
for (const b of BOSSES) push(`boss_${b.id}`, 'boss', { id: b.id, silhouette: false }, bossBuffer(b.id));
push('boss_echo_1', 'boss', { id: 'echo_1', silhouette: false }, bossBuffer('echo_1'));
push('boss_iron_golem_silhouette', 'boss', { id: 'iron_golem', silhouette: true }, bossBuffer('iron_golem', { silhouette: true }));
push('boss_crux_wyvern_silhouette', 'boss', { id: 'crux_wyvern', silhouette: true }, bossBuffer('crux_wyvern', { silhouette: true }));

// --- coverage check + write ----------------------------------------------------

const wornKinds = new Set<string>();
const wornItems = new Set<string>();
for (const c of cases) {
  if (c.kind !== 'hero' && c.kind !== 'scene') continue;
  const state = c.args.state as PlayerState;
  for (const id of Object.values(c.args.loadout as Loadout)) {
    const item = ITEMS.find((i) => i.id === id);
    if (item && id && state.items[id]) {
      wornItems.add(item.id);
      wornKinds.add(item.visual.kind);
    }
  }
}
const allKinds = new Set(ITEMS.map((i) => i.visual.kind));
const missingKinds = [...allKinds].filter((k) => !wornKinds.has(k));
const missingItems = ITEMS.filter((i) => !wornItems.has(i.id)).map((i) => i.id);
if (missingKinds.length || missingItems.length) throw new Error(`not covered: kinds [${missingKinds}] items [${missingItems}]`);

const outPath = join(dirname(resolve(process.argv[1])), 'art_cases.json');
const json = JSON.stringify({ version: 1, generator: 'tests/parity/gen_art.ts', heroSize: [HERO_W, HERO_H], sceneSize: [SCENE_W, SCENE_H], cases });
writeFileSync(outPath, json + '\n');

const byKind: Record<string, number> = {};
for (const c of cases) byKind[c.kind] = (byKind[c.kind] ?? 0) + 1;
console.log(`wrote ${cases.length} cases (${JSON.stringify(byKind)}), ${allKinds.size} visual kinds, ${ITEMS.length} items, ${(json.length / 1024).toFixed(0)} KB -> ${outPath}`);
