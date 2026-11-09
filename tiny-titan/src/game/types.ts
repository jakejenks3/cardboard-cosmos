// Core data model. Everything the player "owns" (levels, items, pets,
// achievements) is DERIVED by replaying the session log — the log itself,
// quest claims, cosmetic choices and settings are the only source of truth.

export type Discipline = 'lift' | 'climb' | 'run' | 'ride';
export const DISCIPLINES: Discipline[] = ['lift', 'climb', 'run', 'ride'];

export const DISCIPLINE_META: Record<
  Discipline,
  { name: string; verb: string; icon: string; color: string; stat: string; statName: string }
> = {
  // Colours validated as a categorical set on the app's dark surfaces
  // (CVD-safe adjacent pairs, ≥3:1 contrast).
  lift: { name: 'Lifting', verb: 'Lift', icon: '🏋️', color: '#d95926', stat: 'STR', statName: 'Strength' },
  climb: { name: 'Climbing', verb: 'Climb', icon: '🧗', color: '#199e70', stat: 'GRIP', statName: 'Grip' },
  run: { name: 'Running', verb: 'Run', icon: '👟', color: '#3987e5', stat: 'STAM', statName: 'Stamina' },
  ride: { name: 'Cycling', verb: 'Ride', icon: '🚴', color: '#c98500', stat: 'PWR', statName: 'Power' },
};

export interface SessionBase {
  id: string;
  discipline: Discipline;
  /** Local calendar date, YYYY-MM-DD. */
  date: string;
  /** Epoch ms when the session was logged/imported. Replay order. */
  createdAt: number;
  durationSec?: number;
  notes?: string;
  title?: string;
  source: 'manual' | 'strava';
  stravaId?: number;
  /** XP multiplier from gear + pet perks, snapshotted at log time (0.08 = +8%). */
  bonusPct?: number;
  /** Loot-luck multiplier from perks, snapshotted at log time. */
  luckPct?: number;
}

export interface LiftSet {
  reps: number;
  /** 0 = bodyweight. */
  weightKg: number;
}
export interface LiftExercise {
  name: string;
  sets: LiftSet[];
}
export interface LiftSession extends SessionBase {
  discipline: 'lift';
  exercises: LiftExercise[];
}

export type ClimbResult = 'flash' | 'send' | 'attempt';
export interface ClimbEntry {
  /** V-scale grade. -1 = VB. */
  grade: number;
  result: ClimbResult;
  count: number;
}
export interface ClimbSession extends SessionBase {
  discipline: 'climb';
  climbs: ClimbEntry[];
}

export interface CardioSession extends SessionBase {
  discipline: 'run' | 'ride';
  distanceM: number;
  elevationM: number;
}

export type Session = LiftSession | ClimbSession | CardioSession;

export interface QuestClaim {
  id: string;
  /** Stable quest instance id (`d:2026-01-01:1` / `w:2026-01-05:2`). */
  questId: string;
  xp: number;
  claimedAt: number;
  date: string;
}

export type PhotoAngle = 'front' | 'side' | 'back';
export const PHOTO_ANGLES: PhotoAngle[] = ['front', 'side', 'back'];
export const PHOTO_ANGLE_NAMES: Record<PhotoAngle, string> = { front: 'Front', side: 'Side', back: 'Back' };

/** A body check-in: any combination of weight, body fat and progress photos. */
export interface BodyEntry {
  id: string;
  date: string;
  createdAt: number;
  weightKg?: number;
  bodyFatPct?: number;
  /** Photo ids (blobs live in IndexedDB / the server, never in this JSON). */
  photos?: Partial<Record<PhotoAngle, string>>;
  note?: string;
}

export type Slot = 'head' | 'face' | 'body' | 'hands' | 'legs' | 'feet' | 'back' | 'accessory' | 'aura';
export const SLOTS: Slot[] = ['head', 'face', 'body', 'hands', 'legs', 'feet', 'back', 'accessory', 'aura'];
export const SLOT_NAMES: Record<Slot, string> = {
  head: 'Head',
  face: 'Face',
  body: 'Body',
  hands: 'Hands',
  legs: 'Legs',
  feet: 'Feet',
  back: 'Back',
  accessory: 'Accessory',
  aura: 'Aura',
};

export type Rarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary';
export const RARITY_ORDER: Rarity[] = ['common', 'uncommon', 'rare', 'epic', 'legendary'];
export const RARITY_COLOR: Record<Rarity, string> = {
  common: '#b8c0cc',
  uncommon: '#6fd37a',
  rare: '#5aa9ff',
  epic: '#c77dff',
  legendary: '#ffc83d',
};

export type Loadout = Partial<Record<Slot, string | null>>;

export interface Profile {
  name: string;
  skin: number;
  hairStyle: number;
  hairColor: number;
  createdAt: number;
}

export interface Settings {
  weightUnit: 'kg' | 'lb';
  distanceUnit: 'km' | 'mi';
  sound: boolean;
  /** Sessions per week needed to keep the streak alive. */
  weeklyGoal: number;
}

export const DEFAULT_SETTINGS: Settings = {
  weightUnit: 'kg',
  distanceUnit: 'km',
  sound: true,
  weeklyGoal: 3,
};
