// What you did last time. Powers the lifting form's prefill, exercise picker
// and the "you beat last time" badges, so logging is mostly tapping + / −.

import type { LiftSession, LiftSet, Session } from './types';
import { normalizeExercise } from './xp';

export interface LastPerformance {
  /** Display name as last typed. */
  name: string;
  date: string;
  sets: LiftSet[];
  sessionId: string;
}

function liftSessionsNewestFirst(sessions: Session[], excludeId?: string): LiftSession[] {
  return sessions
    .filter((s): s is LiftSession => s.discipline === 'lift' && s.id !== excludeId)
    .sort((a, b) => b.date.localeCompare(a.date) || b.createdAt - a.createdAt);
}

/** The most recent logged sets for every exercise, keyed by normalized name. */
export function lastPerformances(sessions: Session[], excludeId?: string): Record<string, LastPerformance> {
  const out: Record<string, LastPerformance> = {};
  for (const s of liftSessionsNewestFirst(sessions, excludeId)) {
    for (const ex of s.exercises) {
      const key = normalizeExercise(ex.name);
      const sets = ex.sets.filter((x) => x.reps > 0);
      if (!key || !sets.length || out[key]) continue;
      out[key] = { name: ex.name.trim(), date: s.date, sets, sessionId: s.id };
    }
  }
  return out;
}

export interface ExerciseSuggestion {
  key: string;
  name: string;
  /** How many sessions included it (0 = never done, from the default list). */
  count: number;
  last?: LastPerformance;
}

/** Exercises to offer: yours first (most recent first), then common defaults. */
export function exerciseSuggestions(sessions: Session[], defaults: string[], excludeId?: string): ExerciseSuggestion[] {
  const last = lastPerformances(sessions, excludeId);
  const counts: Record<string, number> = {};
  for (const s of liftSessionsNewestFirst(sessions, excludeId)) {
    const seen = new Set<string>();
    for (const ex of s.exercises) {
      const key = normalizeExercise(ex.name);
      if (!key || seen.has(key) || !ex.sets.some((x) => x.reps > 0)) continue;
      seen.add(key);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  const mine: ExerciseSuggestion[] = Object.values(last)
    .map((lp) => ({ key: normalizeExercise(lp.name), name: lp.name, count: counts[normalizeExercise(lp.name)] ?? 1, last: lp }))
    .sort((a, b) => b.last!.date.localeCompare(a.last!.date) || b.count - a.count || a.name.localeCompare(b.name));
  const have = new Set(mine.map((m) => m.key));
  const rest = defaults.filter((d) => !have.has(normalizeExercise(d))).map((d) => ({ key: normalizeExercise(d), name: d, count: 0 }));
  return [...mine, ...rest];
}

/** Recent workouts with different exercise line-ups (so A/B splits each show up once). */
export function recentWorkouts(sessions: Session[], n = 3, excludeId?: string): LiftSession[] {
  const out: LiftSession[] = [];
  const seen = new Set<string>();
  for (const s of liftSessionsNewestFirst(sessions, excludeId)) {
    const names = s.exercises.filter((e) => e.sets.some((x) => x.reps > 0)).map((e) => normalizeExercise(e.name));
    if (!names.length) continue;
    const sig = [...names].sort().join('|');
    if (seen.has(sig)) continue;
    seen.add(sig);
    out.push(s);
    if (out.length >= n) break;
  }
  return out;
}

export type SetTrend = { kind: 'pr' } | { kind: 'weight'; deltaKg: number } | { kind: 'reps'; delta: number } | { kind: 'extra' } | null;

/**
 * How a set compares with the same set last time.
 * @param prev   the set at the same position last time, if there was one
 * @param hadHistory  whether this exercise has been logged before at all
 * @param bestWeightKg  heaviest weight ever lifted for this exercise (0 if none)
 */
export function compareSet(cur: { reps: number; weightKg: number }, prev: LiftSet | undefined, hadHistory: boolean, bestWeightKg: number): SetTrend {
  const eps = 1e-6;
  if (cur.reps <= 0) return null;
  if (cur.weightKg > 0 && bestWeightKg > 0 && cur.weightKg > bestWeightKg + eps) return { kind: 'pr' };
  if (!prev) return hadHistory ? { kind: 'extra' } : null;
  if (cur.weightKg > prev.weightKg + eps) return { kind: 'weight', deltaKg: cur.weightKg - prev.weightKg };
  if (Math.abs(cur.weightKg - prev.weightKg) <= eps && cur.reps > prev.reps) return { kind: 'reps', delta: cur.reps - prev.reps };
  return null;
}

/** Step a value to the next / previous multiple of `step` (61 → 62.5 → 65 with step 2.5). */
export function stepValue(value: number, step: number, dir: 1 | -1, min = 0): number {
  const eps = 1e-6;
  const q = value / step;
  const next = dir > 0 ? Math.floor(q + eps) + 1 : Math.ceil(q - eps) - 1;
  return Math.max(min, Math.round(next * step * 10000) / 10000);
}

export function volumeKg(sets: LiftSet[]): number {
  return sets.reduce((a, s) => a + Math.max(0, s.reps) * Math.max(0, s.weightKg), 0);
}

/** "3×5 @ 100 kg", "5, 5, 4 @ 62.5 kg", "3 sets, top 100 kg × 5", "3×8 bodyweight". */
export function describeSets(sets: LiftSet[], fmtW: (kg: number) => string): string {
  const valid = sets.filter((s) => s.reps > 0);
  if (!valid.length) return '';
  const w0 = valid[0].weightKg;
  const sameW = valid.every((s) => Math.abs(s.weightKg - w0) < 1e-6);
  const r0 = valid[0].reps;
  const sameR = valid.every((s) => s.reps === r0);
  const wLabel = w0 > 0 ? ` @ ${fmtW(w0)}` : ' bodyweight';
  if (sameW && sameR) return `${valid.length}×${r0}${wLabel}`;
  if (sameW) return `${valid.map((s) => s.reps).join(', ')}${wLabel}`;
  const top = valid.reduce((a, s) => (s.weightKg > a.weightKg ? s : a), valid[0]);
  return `${valid.length} sets, top ${fmtW(top.weightKg)} × ${top.reps}`;
}

/** Short label for a chip: the heaviest set, e.g. "105×5" (weight in display units). */
export function topSetLabel(sets: LiftSet[], toUnit: (kg: number) => number): string {
  const valid = sets.filter((s) => s.reps > 0);
  if (!valid.length) return '';
  const top = valid.reduce((a, s) => (s.weightKg > a.weightKg ? s : a), valid[0]);
  if (top.weightKg <= 0) return `${valid.length}×${top.reps}`;
  const w = Math.round(toUnit(top.weightKg) * 10) / 10;
  return `${w}×${top.reps}`;
}
