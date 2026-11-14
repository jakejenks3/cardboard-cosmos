import type { Discipline } from './types';
import type { LevelInfo } from './xp';
import { heroLevel, discLevel } from './xp';
import type { ProgressUnit } from './goals';

export type Track = 'hero' | Discipline;

export interface Unlock {
  /** Date key of the event that unlocked it. */
  at: string;
  sessionId?: string;
}

export interface ItemOwned extends Unlock {
  how: 'start' | 'drop' | 'unlock';
}

export interface LiftPr {
  weightKg: number;
  reps: number;
  e1rm: number;
  date: string;
}

export interface Prs {
  lifts: Record<string, LiftPr>;
  climbMaxSend: number | null;
  climbMaxFlash: number | null;
  longestRunM: number;
  longestRideM: number;
  bestRunElevM: number;
  bestRideElevM: number;
  /** Best average pace over a run of at least 5 km. */
  bestPaceSecPerKm: number | null;
  /** Best average speed over a ride of at least 20 km. */
  bestRideSpeedKmh: number | null;
}

export interface Totals {
  sessions: number;
  byDiscipline: Record<Discipline, number>;
  durationSec: number;
  activeDays: number;
  liftVolumeKg: number;
  liftReps: number;
  liftSets: number;
  liftExercises: Record<string, true>;
  climbSends: number;
  climbFlashes: number;
  climbAttempts: number;
  runDistanceM: number;
  runElevationM: number;
  rideDistanceM: number;
  rideElevationM: number;
}

/** "Best ever" single-session / single-period feats, used by goals. */
export interface Bests {
  maxSetKg: number;
  sessionVolumeKg: number;
  sessionBwReps: number;
  sessionSends: number;
  sessionFlashes: number;
  sessionAttempts: number;
  /** Sum of V-grades sent in one session. */
  sessionVPoints: number;
  sessionDurationSec: number;
  sessionPrs: number;
  daySessions: number;
  dayXp: number;
  weekDisciplines: number;
  monthSessions: number;
  /** Longest break (days) that was followed by a logged session. */
  gapDays: number;
  weekendWarrior: number;
  maxRank: number;
  /** Best lift ÷ bodyweight (needs a logged body weight). */
  benchRatio: number;
  squatRatio: number;
  deadliftRatio: number;
}

export interface StreakInfo {
  current: number;
  best: number;
  thisWeek: number;
  goal: number;
}

export interface CampaignState {
  /** Index of the boss currently being fought. */
  index: number;
  /** Damage dealt to the current boss. */
  damage: number;
  totalDamage: number;
  defeated: Record<string, Unlock>;
}

export interface BodyState {
  entries: number;
  weightEntries: number;
  bfEntries: number;
  /** Check-ins with at least one photo. */
  photoEntries: number;
  /** Check-ins with all three angles. */
  fullSets: number;
  firstWeightKg: number | null;
  firstWeightDate: string | null;
  latestWeightKg: number | null;
  latestWeightDate: string | null;
  latestBodyFat: number | null;
  latestBodyFatDate: string | null;
  /** Weekly check-in components already rewarded (bitmask per Monday-week). */
  weekFlags: Record<string, number>;
  /** Consecutive weeks with a check-in. */
  streak: number;
  bestStreak: number;
}

export type ChronicleKind = 'start' | 'level' | 'stage' | 'rank' | 'achievement' | 'item' | 'pet' | 'boss' | 'pr' | 'body';

export interface ChronicleEvent {
  date: string;
  kind: ChronicleKind;
  icon: string;
  title: string;
  detail?: string;
  /** Optional unit-aware value appended by the UI (e.g. a PR weight). */
  val?: { n: number; unit: ProgressUnit };
  discipline?: Discipline;
  /** Catalog id for achievements / items / pets / bosses. */
  ref?: string;
}

export interface PlayerState {
  xp: Record<Track, number>;
  levels: Record<Track, LevelInfo>;
  ranks: Record<Discipline, number>;
  totals: Totals;
  prs: Prs;
  bests: Bests;
  achievements: Record<string, Unlock>;
  items: Record<string, ItemOwned>;
  pets: Record<string, Unlock>;
  campaign: CampaignState;
  body: BodyState;
  streak: StreakInfo;
  chronicle: ChronicleEvent[];
  /** Sessions per Monday-week key. */
  weekCounts: Record<string, number>;
  /** Weekday bitmask per week (bit 0 = Monday … bit 6 = Sunday). */
  weekDays: Record<string, number>;
  /** Discipline bitmask per week. */
  weekDisc: Record<string, number>;
  monthCounts: Record<string, number>;
  dateCounts: Record<string, number>;
  xpByDate: Record<string, number>;
  /** XP credited per session id (base + PR bonuses + perks). */
  sessionXp: Record<string, number>;
  /** Damage dealt per session id. */
  sessionDamage: Record<string, number>;
  /** XP credited per body check-in id. */
  bodyXp: Record<string, number>;
  sessionsSinceDrop: number;
  lastSessionDate: string | null;
  stage: number;
  title: string;
  dominant: Discipline | null;
  /** Bookkeeping for chronicle entries. */
  seen: { heroLevel: number; stage: number; started: boolean };
}

export function initialState(goal: number): PlayerState {
  const zero = { hero: 0, lift: 0, climb: 0, run: 0, ride: 0 };
  return {
    xp: { ...zero },
    levels: {
      hero: heroLevel(0),
      lift: discLevel(0),
      climb: discLevel(0),
      run: discLevel(0),
      ride: discLevel(0),
    },
    ranks: { lift: 0, climb: 0, run: 0, ride: 0 },
    totals: {
      sessions: 0,
      byDiscipline: { lift: 0, climb: 0, run: 0, ride: 0 },
      durationSec: 0,
      activeDays: 0,
      liftVolumeKg: 0,
      liftReps: 0,
      liftSets: 0,
      liftExercises: {},
      climbSends: 0,
      climbFlashes: 0,
      climbAttempts: 0,
      runDistanceM: 0,
      runElevationM: 0,
      rideDistanceM: 0,
      rideElevationM: 0,
    },
    prs: {
      lifts: {},
      climbMaxSend: null,
      climbMaxFlash: null,
      longestRunM: 0,
      longestRideM: 0,
      bestRunElevM: 0,
      bestRideElevM: 0,
      bestPaceSecPerKm: null,
      bestRideSpeedKmh: null,
    },
    bests: {
      maxSetKg: 0,
      sessionVolumeKg: 0,
      sessionBwReps: 0,
      sessionSends: 0,
      sessionFlashes: 0,
      sessionAttempts: 0,
      sessionVPoints: 0,
      sessionDurationSec: 0,
      sessionPrs: 0,
      daySessions: 0,
      dayXp: 0,
      weekDisciplines: 0,
      monthSessions: 0,
      gapDays: 0,
      weekendWarrior: 0,
      maxRank: 0,
      benchRatio: 0,
      squatRatio: 0,
      deadliftRatio: 0,
    },
    achievements: {},
    items: {},
    pets: {},
    campaign: { index: 0, damage: 0, totalDamage: 0, defeated: {} },
    body: {
      entries: 0,
      weightEntries: 0,
      bfEntries: 0,
      photoEntries: 0,
      fullSets: 0,
      firstWeightKg: null,
      firstWeightDate: null,
      latestWeightKg: null,
      latestWeightDate: null,
      latestBodyFat: null,
      latestBodyFatDate: null,
      weekFlags: {},
      streak: 0,
      bestStreak: 0,
    },
    streak: { current: 0, best: 0, thisWeek: 0, goal },
    chronicle: [],
    weekCounts: {},
    weekDays: {},
    weekDisc: {},
    monthCounts: {},
    dateCounts: {},
    xpByDate: {},
    sessionXp: {},
    sessionDamage: {},
    bodyXp: {},
    sessionsSinceDrop: 0,
    lastSessionDate: null,
    stage: 0,
    title: 'Scrawny Newcomer',
    dominant: null,
    seen: { heroLevel: 1, stage: 0, started: false },
  };
}

export function hasAch(s: PlayerState, id: string): boolean {
  return !!s.achievements[id];
}

export function ownedItemCount(s: PlayerState): number {
  return Object.keys(s.items).length;
}
export function ownedPetCount(s: PlayerState): number {
  return Object.keys(s.pets).length;
}
export function defeatedCount(s: PlayerState): number {
  return Object.keys(s.campaign.defeated).length;
}
