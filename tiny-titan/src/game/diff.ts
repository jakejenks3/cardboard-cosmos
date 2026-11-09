import type { Discipline, Session } from './types';
import { DISCIPLINES } from './types';
import type { LevelInfo, XpPart } from './xp';
import { baseSessionXp, gradeLabel } from './xp';
import type { PlayerState, Track } from './state';

export type ResultEvent =
  | {
      type: 'xp';
      discipline: Discipline;
      amount: number;
      parts: XpPart[];
      prBonus: number;
      bonusPct: number;
      hero: { before: LevelInfo; after: LevelInfo };
      disc: { before: LevelInfo; after: LevelInfo };
    }
  | { type: 'levelup'; track: Track; from: number; to: number }
  | { type: 'stage'; from: number; to: number }
  | { type: 'pr'; icon: string; title: string; detail: string }
  | { type: 'achievement'; id: string }
  | { type: 'item'; id: string; how: 'drop' | 'unlock' | 'start' }
  | { type: 'pet'; id: string }
  | { type: 'streak'; current: number }
  | { type: 'import'; count: number; xp: number; byDiscipline: Record<Discipline, number>; hero: { before: LevelInfo; after: LevelInfo } };

/** Results reel for a batch of sessions (e.g. a Strava import). */
export function diffBulk(before: PlayerState, after: PlayerState, sessions: Session[]): ResultEvent[] {
  const ev: ResultEvent[] = [];
  const byDiscipline: Record<Discipline, number> = { lift: 0, climb: 0, run: 0, ride: 0 };
  let xp = 0;
  for (const s of sessions) {
    const v = after.sessionXp[s.id] ?? 0;
    byDiscipline[s.discipline] += v;
    xp += v;
  }
  ev.push({ type: 'import', count: sessions.length, xp, byDiscipline, hero: { before: before.levels.hero, after: after.levels.hero } });
  for (const track of ['lift', 'climb', 'run', 'ride', 'hero'] as Track[]) {
    if (after.levels[track].level > before.levels[track].level) {
      ev.push({ type: 'levelup', track, from: before.levels[track].level, to: after.levels[track].level });
    }
  }
  if (after.stage > before.stage) ev.push({ type: 'stage', from: before.stage, to: after.stage });
  for (const id of Object.keys(after.achievements)) if (!before.achievements[id]) ev.push({ type: 'achievement', id });
  for (const [id, own] of Object.entries(after.items)) if (!before.items[id]) ev.push({ type: 'item', id, how: own.how });
  for (const id of Object.keys(after.pets)) if (!before.pets[id]) ev.push({ type: 'pet', id });
  if (after.streak.current > before.streak.current && after.streak.current >= 2) ev.push({ type: 'streak', current: after.streak.current });
  return ev;
}

/** Everything that changed because `session` was added: the results reel. */
export function diffStates(before: PlayerState, after: PlayerState, session: Session): ResultEvent[] {
  const ev: ResultEvent[] = [];
  const d = session.discipline;
  const amount = after.sessionXp[session.id] ?? 0;
  const base = baseSessionXp(session);
  const bonusPct = session.bonusPct ?? 0;
  const withPerk = Math.round(base.xp * (1 + bonusPct));
  ev.push({
    type: 'xp',
    discipline: d,
    amount,
    parts: base.parts,
    prBonus: Math.max(0, amount - withPerk),
    bonusPct,
    hero: { before: before.levels.hero, after: after.levels.hero },
    disc: { before: before.levels[d], after: after.levels[d] },
  });

  for (const track of [d, 'hero'] as Track[]) {
    if (after.levels[track].level > before.levels[track].level) {
      ev.push({ type: 'levelup', track, from: before.levels[track].level, to: after.levels[track].level });
    }
  }
  if (after.stage > before.stage) ev.push({ type: 'stage', from: before.stage, to: after.stage });

  // PRs
  const bp = before.prs;
  const ap = after.prs;
  for (const [name, pr] of Object.entries(ap.lifts)) {
    const prev = bp.lifts[name];
    if (!prev) continue;
    if (pr.weightKg > prev.weightKg + 1e-9) {
      ev.push({ type: 'pr', icon: '🏋️', title: `${titleCase(name)} PR`, detail: `${trim(pr.weightKg)} kg (was ${trim(prev.weightKg)} kg)` });
    } else if (pr.e1rm > prev.e1rm + 1e-6) {
      ev.push({ type: 'pr', icon: '📈', title: `${titleCase(name)} est. 1RM PR`, detail: `${trim(pr.e1rm)} kg (was ${trim(prev.e1rm)} kg)` });
    }
  }
  if (ap.climbMaxSend !== null && (bp.climbMaxSend === null || ap.climbMaxSend > bp.climbMaxSend)) {
    ev.push({
      type: 'pr',
      icon: '🧗',
      title: bp.climbMaxSend === null ? 'Max grade set' : 'New max grade!',
      detail: bp.climbMaxSend === null ? gradeLabel(ap.climbMaxSend) : `${gradeLabel(ap.climbMaxSend)} (was ${gradeLabel(bp.climbMaxSend)})`,
    });
  }
  if (ap.climbMaxFlash !== null && (bp.climbMaxFlash === null || ap.climbMaxFlash > bp.climbMaxFlash)) {
    ev.push({
      type: 'pr',
      icon: '⚡',
      title: bp.climbMaxFlash === null ? 'Max flash set' : 'New max flash!',
      detail: bp.climbMaxFlash === null ? gradeLabel(ap.climbMaxFlash) : `${gradeLabel(ap.climbMaxFlash)} (was ${gradeLabel(bp.climbMaxFlash)})`,
    });
  }
  if (bp.longestRunM > 0 && ap.longestRunM > bp.longestRunM) {
    ev.push({ type: 'pr', icon: '👟', title: 'Longest run!', detail: `${(ap.longestRunM / 1000).toFixed(1)} km (was ${(bp.longestRunM / 1000).toFixed(1)} km)` });
  }
  if (bp.longestRideM > 0 && ap.longestRideM > bp.longestRideM) {
    ev.push({ type: 'pr', icon: '🚴', title: 'Longest ride!', detail: `${(ap.longestRideM / 1000).toFixed(1)} km (was ${(bp.longestRideM / 1000).toFixed(1)} km)` });
  }
  if (bp.bestPaceSecPerKm !== null && ap.bestPaceSecPerKm !== null && ap.bestPaceSecPerKm < bp.bestPaceSecPerKm - 1e-6) {
    ev.push({ type: 'pr', icon: '💨', title: 'Fastest pace (5 km+)!', detail: `${pace(ap.bestPaceSecPerKm)} /km (was ${pace(bp.bestPaceSecPerKm)})` });
  }
  if (bp.bestRideSpeedKmh !== null && ap.bestRideSpeedKmh !== null && ap.bestRideSpeedKmh > bp.bestRideSpeedKmh + 1e-6) {
    ev.push({ type: 'pr', icon: '💨', title: 'Fastest ride (20 km+)!', detail: `${ap.bestRideSpeedKmh.toFixed(1)} km/h (was ${bp.bestRideSpeedKmh.toFixed(1)})` });
  }

  for (const id of Object.keys(after.achievements)) {
    if (!before.achievements[id]) ev.push({ type: 'achievement', id });
  }
  for (const [id, own] of Object.entries(after.items)) {
    if (!before.items[id]) ev.push({ type: 'item', id, how: own.how });
  }
  for (const id of Object.keys(after.pets)) {
    if (!before.pets[id]) ev.push({ type: 'pet', id });
  }
  if (after.streak.current > before.streak.current && after.streak.current >= 2) {
    ev.push({ type: 'streak', current: after.streak.current });
  }
  return ev;
}

export function totalDisciplineXp(s: PlayerState): number {
  return DISCIPLINES.reduce((a, d) => a + s.xp[d], 0);
}

function titleCase(s: string): string {
  return s.replace(/\b\w/g, (c) => c.toUpperCase());
}
function trim(n: number): string {
  return Number.isInteger(n) ? String(n) : n.toFixed(1);
}
function pace(secPerKm: number): string {
  const m = Math.floor(secPerKm / 60);
  const s = Math.round(secPerKm % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}
