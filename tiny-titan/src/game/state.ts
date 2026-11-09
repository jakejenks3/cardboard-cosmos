import type { Discipline, Session } from './types';
import type { LevelInfo, SessionStats } from './xp';
import { heroLevel, discLevel } from './xp';

export type Track = 'hero' | Discipline;

export interface Unlock {
  /** Date key of the session that unlocked it. */
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

export interface StreakInfo {
  current: number;
  best: number;
  thisWeek: number;
  goal: number;
}

export interface PlayerState {
  xp: Record<Track, number>;
  levels: Record<Track, LevelInfo>;
  totals: Totals;
  prs: Prs;
  achievements: Record<string, Unlock>;
  items: Record<string, ItemOwned>;
  pets: Record<string, Unlock>;
  streak: StreakInfo;
  /** Sessions per Monday-week key. */
  weekCounts: Record<string, number>;
  /** Weekday bitmask per week (bit 0 = Monday … bit 6 = Sunday). */
  weekDays: Record<string, number>;
  dateCounts: Record<string, number>;
  xpByDate: Record<string, number>;
  /** XP credited per session id (base + PR bonuses + perks). */
  sessionXp: Record<string, number>;
  sessionsSinceDrop: number;
  stage: number;
  title: string;
  dominant: Discipline | null;
}

export interface AchievementCtx {
  s: PlayerState;
  session: Session;
  st: SessionStats;
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
    achievements: {},
    items: {},
    pets: {},
    streak: { current: 0, best: 0, thisWeek: 0, goal },
    weekCounts: {},
    weekDays: {},
    dateCounts: {},
    xpByDate: {},
    sessionXp: {},
    sessionsSinceDrop: 0,
    stage: 0,
    title: 'Scrawny Newcomer',
    dominant: null,
  };
}

export function hasAch(s: PlayerState, id: string): boolean {
  return !!s.achievements[id];
}
