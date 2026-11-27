import type { Session, LiftSession, ClimbSession, CardioSession, Discipline } from './types';

// ---------------------------------------------------------------------------
// Tuning. Every discipline is balanced to land around ~1,000 XP for a solid
// hour of effort so no sport feels like the "wrong" one to play.
// ---------------------------------------------------------------------------

/** XP per climb, indexed by grade + 1 (VB, V0, V1 … V17). */
export const CLIMB_GRADE_XP = [
  12, 20, 30, 42, 58, 78, 105, 140, 185, 240, 310, 400, 500, 620, 760, 920, 1100, 1300, 1550,
];
export const MAX_V_GRADE = 17;
export const CLIMB_RESULT_MULT = { flash: 1.3, send: 1, attempt: 0.35 } as const;

export const LIFT_XP_PER_KG = 1 / 10;
export const LIFT_XP_PER_REP = 1;
export const LIFT_XP_PER_BW_REP = 3;
export const LIFT_XP_PER_SET = 5;

export const RUN_XP_PER_KM = 100;
export const RUN_XP_PER_ELEV_M = 0.8;
export const RIDE_XP_PER_KM = 32;
export const RIDE_XP_PER_ELEV_M = 0.8;

export const DURATION_XP_PER_MIN = 2;
export const DURATION_XP_MAX_MIN = 180;

export const PR_BONUS = {
  liftExercise: 150,
  climbMaxSend: 200,
  climbMaxFlash: 100,
  longestRun: 150,
  longestRide: 150,
} as const;

export const MAX_LEVEL = 99;

export function clampGrade(g: number): number {
  return Math.min(MAX_V_GRADE, Math.max(-1, Math.round(g)));
}
export function climbGradeXp(grade: number): number {
  return CLIMB_GRADE_XP[clampGrade(grade) + 1];
}
export function gradeLabel(grade: number): string {
  return grade < 0 ? 'VB' : `V${grade}`;
}

/** Epley estimated one-rep max. */
export function e1rm(weightKg: number, reps: number): number {
  if (reps <= 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

export interface XpPart {
  label: string;
  xp: number;
}

export interface SessionStats {
  // lifting
  volumeKg: number;
  reps: number;
  bwReps: number;
  sets: number;
  maxSetKg: number;
  exerciseNames: string[];
  // climbing
  sends: number;
  flashes: number;
  attempts: number;
  maxGradeSent: number | null;
  maxGradeFlashed: number | null;
  // cardio
  distanceM: number;
  elevationM: number;
  /** seconds per km, if duration known */
  paceSecPerKm: number | null;
  speedKmh: number | null;
  durationSec: number;
}

export function sessionStats(s: Session): SessionStats {
  const st: SessionStats = {
    volumeKg: 0,
    reps: 0,
    bwReps: 0,
    sets: 0,
    maxSetKg: 0,
    exerciseNames: [],
    sends: 0,
    flashes: 0,
    attempts: 0,
    maxGradeSent: null,
    maxGradeFlashed: null,
    distanceM: 0,
    elevationM: 0,
    paceSecPerKm: null,
    speedKmh: null,
    durationSec: s.durationSec ?? 0,
  };
  if (s.discipline === 'lift') {
    for (const ex of s.exercises) {
      if (ex.sets.length) st.exerciseNames.push(normalizeExercise(ex.name));
      for (const set of ex.sets) {
        const reps = Math.max(0, set.reps);
        const w = Math.max(0, set.weightKg);
        st.sets += 1;
        if (w > 0) {
          st.reps += reps;
          st.volumeKg += reps * w;
          st.maxSetKg = Math.max(st.maxSetKg, w);
        } else {
          st.bwReps += reps;
        }
      }
    }
  } else if (s.discipline === 'climb') {
    for (const c of s.climbs) {
      const n = Math.max(0, c.count);
      if (c.result === 'attempt') st.attempts += n;
      else {
        st.sends += n;
        if (n > 0) st.maxGradeSent = Math.max(st.maxGradeSent ?? -99, c.grade);
        if (c.result === 'flash') {
          st.flashes += n;
          if (n > 0) st.maxGradeFlashed = Math.max(st.maxGradeFlashed ?? -99, c.grade);
        }
      }
    }
  } else {
    st.distanceM = Math.max(0, s.distanceM);
    st.elevationM = Math.max(0, s.elevationM || 0);
    if (s.durationSec && st.distanceM > 0) {
      st.paceSecPerKm = s.durationSec / (st.distanceM / 1000);
      st.speedKmh = (st.distanceM / 1000) / (s.durationSec / 3600);
    }
  }
  return st;
}

export function normalizeExercise(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, ' ');
}

/** Base XP for a session (no PR bonuses, no perk multiplier). */
export function baseSessionXp(s: Session): { xp: number; parts: XpPart[] } {
  const parts: XpPart[] = [];
  const st = sessionStats(s);
  if (s.discipline === 'lift') {
    const vol = st.volumeKg * LIFT_XP_PER_KG;
    if (vol) parts.push({ label: `${fmtInt(st.volumeKg)} kg volume`, xp: vol });
    if (st.reps) parts.push({ label: `${st.reps} reps`, xp: st.reps * LIFT_XP_PER_REP });
    if (st.bwReps) parts.push({ label: `${st.bwReps} bodyweight reps`, xp: st.bwReps * LIFT_XP_PER_BW_REP });
    if (st.sets) parts.push({ label: `${st.sets} sets`, xp: st.sets * LIFT_XP_PER_SET });
  } else if (s.discipline === 'climb') {
    let sendXp = 0;
    let flashXp = 0;
    let attemptXp = 0;
    for (const c of s.climbs) {
      const each = climbGradeXp(c.grade) * CLIMB_RESULT_MULT[c.result];
      const total = each * Math.max(0, c.count);
      if (c.result === 'flash') flashXp += total;
      else if (c.result === 'send') sendXp += total;
      else attemptXp += total;
    }
    if (st.flashes) parts.push({ label: `${st.flashes} flashes`, xp: flashXp });
    if (st.sends - st.flashes) parts.push({ label: `${st.sends - st.flashes} sends`, xp: sendXp });
    if (st.attempts) parts.push({ label: `${st.attempts} attempts`, xp: attemptXp });
  } else {
    const km = st.distanceM / 1000;
    const perKm = s.discipline === 'run' ? RUN_XP_PER_KM : RIDE_XP_PER_KM;
    const perElev = s.discipline === 'run' ? RUN_XP_PER_ELEV_M : RIDE_XP_PER_ELEV_M;
    if (km) parts.push({ label: `${km.toFixed(1)} km`, xp: km * perKm });
    if (st.elevationM) parts.push({ label: `${fmtInt(st.elevationM)} m climbed`, xp: st.elevationM * perElev });
  }
  if (s.durationSec) {
    const min = Math.min(DURATION_XP_MAX_MIN, s.durationSec / 60);
    parts.push({ label: `${Math.round(min)} min`, xp: min * DURATION_XP_PER_MIN });
  }
  const xp = Math.round(parts.reduce((a, p) => a + p.xp, 0));
  return { xp, parts: parts.map((p) => ({ ...p, xp: Math.round(p.xp) })) };
}

// ---------------------------------------------------------------------------
// Level curves. Fast early levels (first session ≈ level 3), then a long tail.
// ---------------------------------------------------------------------------

export function heroXpForLevel(level: number): number {
  return Math.round(400 + 90 * level + 6 * level * level);
}
export function discXpForLevel(level: number): number {
  return Math.round(300 + 70 * level + 5 * level * level);
}

export interface LevelInfo {
  level: number;
  /** XP accumulated inside the current level. */
  into: number;
  /** XP needed to finish the current level. */
  toNext: number;
  total: number;
  progress: number;
}

export function levelFromXp(total: number, curve: (level: number) => number): LevelInfo {
  let level = 1;
  let rem = Math.max(0, Math.floor(total));
  while (level < MAX_LEVEL && rem >= curve(level)) {
    rem -= curve(level);
    level++;
  }
  const toNext = curve(level);
  return { level, into: rem, toNext, total, progress: level >= MAX_LEVEL ? 1 : rem / toNext };
}

export function heroLevel(total: number): LevelInfo {
  return levelFromXp(total, heroXpForLevel);
}
export function discLevel(total: number): LevelInfo {
  return levelFromXp(total, discXpForLevel);
}

/** Total XP required to *reach* a hero level. */
export function heroXpToReach(level: number): number {
  let t = 0;
  for (let l = 1; l < level; l++) t += heroXpForLevel(l);
  return t;
}

// ---------------------------------------------------------------------------
// Body evolution stages (drives the avatar silhouette + title adjective).
// ---------------------------------------------------------------------------
export const STAGES = [
  { minLevel: 1, name: 'Scrawny', blurb: 'Everyone starts somewhere.' },
  { minLevel: 5, name: 'Budding', blurb: 'Posture: improving. Vibes: immaculate.' },
  { minLevel: 12, name: 'Fit', blurb: 'People are starting to notice.' },
  { minLevel: 22, name: 'Athletic', blurb: 'Built different. Literally.' },
  { minLevel: 35, name: 'Jacked', blurb: 'Doorframes fear you.' },
  { minLevel: 50, name: 'Titanic', blurb: 'A legend walks among mortals.' },
];
export function stageForLevel(level: number): number {
  let st = 0;
  STAGES.forEach((s, i) => {
    if (level >= s.minLevel) st = i;
  });
  return st;
}

/** Total XP required to *reach* a discipline level. */
export function discXpToReach(level: number): number {
  let t = 0;
  for (let l = 1; l < level; l++) t += discXpForLevel(l);
  return t;
}

// ---------------------------------------------------------------------------
// Mastery ranks: named tiers for each discipline level track.
// ---------------------------------------------------------------------------
export const RANKS = [
  { minLevel: 1, name: 'Novice', color: '#9aa3ad' },
  { minLevel: 5, name: 'Apprentice', color: '#b98a5a' },
  { minLevel: 10, name: 'Journeyman', color: '#c9d1d9' },
  { minLevel: 15, name: 'Adept', color: '#ffd54f' },
  { minLevel: 20, name: 'Expert', color: '#4dd0e1' },
  { minLevel: 30, name: 'Master', color: '#c77dff' },
  { minLevel: 40, name: 'Grandmaster', color: '#ff7043' },
  { minLevel: 50, name: 'Legend', color: '#ffeb3b' },
];
export function rankForLevel(level: number): number {
  let r = 0;
  RANKS.forEach((x, i) => {
    if (level >= x.minLevel) r = i;
  });
  return r;
}

export function fmtInt(n: number): string {
  return Math.round(n).toLocaleString('en-US');
}

export function isDiscipline(x: string): x is Discipline {
  return x === 'lift' || x === 'climb' || x === 'run' || x === 'ride';
}

export type { LiftSession, ClimbSession, CardioSession };
