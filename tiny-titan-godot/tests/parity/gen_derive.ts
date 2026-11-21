// Generates the parity fixtures for the Godot port from the REAL TypeScript
// engine. Run from the web app's folder (tsx is installed there):
//
//   cd tiny-titan && npx tsx ../tiny-titan-godot/tests/parity/gen_derive.ts
//
// Writes, next to this file:
//   derive_cases.json  [{name, input: {sessions, claims, body, weeklyGoal, today}, expected: PlayerState}]
//   core_vectors.json  input -> output vectors for the small pure functions
//
// tests/parity_derive.gd replays both files against the GDScript engine.
// Everything here is deterministic (no Date.now, no Math.random), so
// re-running the script reproduces the same files byte for byte.
//
// Input numbers are kept to short decimals on purpose: Godot's JSON parser
// is not correctly rounded for 17-digit doubles, and the inputs must reach
// both engines as the same doubles.

import * as fs from 'node:fs';
import * as path from 'node:path';
import type { BodyEntry, CardioSession, ClimbEntry, ClimbResult, ClimbSession, Discipline, LiftExercise, LiftSession, Loadout, QuestClaim, Session } from '../../../tiny-titan/src/game/types';
import { DEFAULT_SETTINGS, DISCIPLINES, weightStepOf } from '../../../tiny-titan/src/game/types';
import { hashString, makeRng } from '../../../tiny-titan/src/game/rng';
import { addDays, addWeeks, daysBetween, formatDate, formatDateLong, parseDateKey, relativeDay, weekdayIndex, weekKey } from '../../../tiny-titan/src/game/dates';
import {
  baseSessionXp,
  clampGrade,
  climbGradeXp,
  discLevel,
  discXpForLevel,
  discXpToReach,
  e1rm,
  fmtInt,
  gradeLabel,
  heroLevel,
  heroXpForLevel,
  heroXpToReach,
  isDiscipline,
  levelFromXp,
  normalizeExercise,
  rankForLevel,
  sessionStats,
  stageForLevel,
} from '../../../tiny-titan/src/game/xp';
import { progressRatio, type Progress } from '../../../tiny-titan/src/game/goals';
import type { PlayerState } from '../../../tiny-titan/src/game/state';
import { defeatedCount, hasAch, ownedItemCount, ownedPetCount } from '../../../tiny-titan/src/game/state';
import { BOSSES, bossAt, bossesInZone, isEcho, WEAK_MULT, ZONES } from '../../../tiny-titan/src/game/campaign';
import { ACH_GROUPS, ACHIEVEMENTS, TIER_COLOR, tierOf, trophyPoints } from '../../../tiny-titan/src/game/achievements';
import { ITEMS, perkSummary, RARITY_WEIGHT, unlockHint, unlockProgress } from '../../../tiny-titan/src/game/items';
import { PETS } from '../../../tiny-titan/src/game/pets';
import { computePerks, sanitizeLoadout } from '../../../tiny-titan/src/game/perks';
import { bodyEntryReward, computeStreak, computeTitle, derive, type DeriveInput } from '../../../tiny-titan/src/game/derive';

const OUT_DIR = path.dirname(path.resolve(process.argv[1]));

// ---------------------------------------------------------------------------
// Session builders
// ---------------------------------------------------------------------------

const lift = (over: Partial<LiftSession> = {}): LiftSession => ({
  id: 'l1',
  discipline: 'lift',
  date: '2026-03-02',
  createdAt: 1,
  source: 'manual',
  durationSec: 3600,
  exercises: [
    { name: 'Bench Press', sets: [{ reps: 5, weightKg: 80 }, { reps: 5, weightKg: 80 }, { reps: 5, weightKg: 80 }] },
    { name: 'Squat', sets: [{ reps: 5, weightKg: 100 }, { reps: 5, weightKg: 100 }] },
    { name: 'Pull-up', sets: [{ reps: 10, weightKg: 0 }] },
  ],
  ...over,
});

const climb = (over: Partial<ClimbSession> = {}): ClimbSession => ({
  id: 'c1',
  discipline: 'climb',
  date: '2026-03-03',
  createdAt: 2,
  source: 'manual',
  climbs: [
    { grade: 2, result: 'flash', count: 3 },
    { grade: 3, result: 'send', count: 2 },
    { grade: 5, result: 'attempt', count: 4 },
  ],
  ...over,
});

const run = (over: Partial<CardioSession> = {}): CardioSession => ({
  id: 'r1',
  discipline: 'run',
  date: '2026-03-04',
  createdAt: 3,
  source: 'manual',
  distanceM: 10000,
  elevationM: 120,
  durationSec: 50 * 60,
  ...over,
});

const ride = (over: Partial<CardioSession> = {}): CardioSession => ({
  id: 'b1',
  discipline: 'ride',
  date: '2026-03-05',
  createdAt: 4,
  source: 'manual',
  distanceM: 40000,
  elevationM: 400,
  durationSec: 90 * 60,
  ...over,
});

const body = (over: Partial<BodyEntry> = {}): BodyEntry => ({ id: 'w1', date: '2026-03-02', createdAt: 100, weightKg: 80, ...over });

const sets = (n: number, reps: number, weightKg: number) => Array.from({ length: n }, () => ({ reps, weightKg }));

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

interface Case {
  name: string;
  input: DeriveInput;
}
const cases: Case[] = [];
const add = (name: string, input: DeriveInput) => cases.push({ name, input });

add('empty', { sessions: [], claims: [], body: [], weeklyGoal: 3, today: '2026-03-08' });
// `body` is optional in DeriveInput.
add('empty_without_body_key', { sessions: [], claims: [], weeklyGoal: 5, today: '2024-02-29' });

add('one_lift', { sessions: [lift()], claims: [], body: [], weeklyGoal: 3, today: '2026-03-08' });
add('one_climb', {
  sessions: [
    climb({
      durationSec: 5400,
      climbs: [
        { grade: -1, result: 'flash', count: 2 },
        { grade: 0, result: 'send', count: 1 },
        { grade: 2, result: 'flash', count: 3 },
        { grade: 3, result: 'send', count: 2 },
        { grade: 5, result: 'attempt', count: 4 },
      ],
    }),
  ],
  claims: [],
  body: [],
  weeklyGoal: 3,
  today: '2026-03-08',
});
add('one_run', { sessions: [run()], claims: [], body: [], weeklyGoal: 3, today: '2026-03-08' });
add('one_ride', { sessions: [ride()], claims: [], body: [], weeklyGoal: 3, today: '2026-03-08' });

add('bodyweight_and_vb', {
  sessions: [
    lift({
      id: 'bw1',
      durationSec: undefined,
      exercises: [
        { name: '  Push   Up ', sets: sets(6, 12, 0) },
        { name: 'PULL-UP', sets: [{ reps: 8, weightKg: 0 }, { reps: 6, weightKg: 0 }, { reps: 0, weightKg: 0 }] },
        { name: 'Dips', sets: sets(4, 10, 0) },
        { name: 'Stretching', sets: [] },
        { name: '   ', sets: [{ reps: 5, weightKg: 20 }] },
        { name: 'Goblet Squat', sets: [{ reps: 0, weightKg: 24 }, { reps: 12, weightKg: 24 }] },
      ],
    }),
    climb({
      id: 'vb1',
      createdAt: 5,
      date: '2026-03-03',
      climbs: [
        { grade: -1, result: 'flash', count: 4 },
        { grade: -1, result: 'send', count: 3 },
        { grade: -1, result: 'attempt', count: 2 },
        { grade: 4, result: 'send', count: 0 },
        { grade: 6, result: 'flash', count: 0 },
      ],
    }),
    // Attempts only: no sends, so no grade PR at all.
    climb({ id: 'vb2', createdAt: 6, date: '2026-03-04', durationSec: 2700, climbs: [{ grade: 7, result: 'attempt', count: 12 }] }),
    // Bodyweight-only day with more than 100 reps in total.
    lift({ id: 'bw2', createdAt: 7, date: '2026-03-05', durationSec: 1500, exercises: [{ name: 'push up', sets: sets(11, 10, 0) }] }),
  ],
  claims: [],
  body: [],
  weeklyGoal: 3,
  today: '2026-03-08',
});

add('prs_and_bonus_cap', {
  sessions: [
    lift({
      id: 'p-l1',
      createdAt: 10,
      date: '2026-01-05',
      exercises: [
        { name: 'Bench Press', sets: sets(3, 5, 60) },
        { name: 'Squat', sets: sets(3, 5, 80) },
        { name: 'Deadlift', sets: sets(1, 5, 100) },
        { name: 'Overhead Press', sets: sets(3, 8, 40) },
        { name: 'Barbell Row', sets: sets(3, 8, 50) },
      ],
    }),
    // Five PRs in one session: only three of them pay a bonus.
    lift({
      id: 'p-l2',
      createdAt: 20,
      date: '2026-01-07',
      exercises: [
        { name: 'bench press', sets: sets(3, 5, 62.5) },
        { name: 'SQUAT', sets: sets(3, 5, 85) },
        { name: 'Deadlift', sets: sets(1, 5, 110) },
        { name: 'Overhead  Press', sets: sets(3, 8, 42.5) },
        { name: 'Barbell Row', sets: sets(3, 8, 52.5) },
      ],
    }),
    // Same weight, more reps: an estimated-1RM PR (bonus, but no chronicle line).
    lift({ id: 'p-l3', createdAt: 30, date: '2026-01-09', exercises: [{ name: 'Bench Press', sets: [{ reps: 8, weightKg: 62.5 }, { reps: 1, weightKg: 62.5 }] }] }),
    // Lighter everywhere: no PR.
    lift({ id: 'p-l4', createdAt: 40, date: '2026-01-12', exercises: [{ name: 'Bench Press', sets: sets(3, 5, 50) }, { name: 'Squat', sets: sets(2, 3, 85) }] }),
    // Heavier single, lower estimated max.
    lift({ id: 'p-l5', createdAt: 45, date: '2026-01-13', exercises: [{ name: 'Bench Press', sets: [{ reps: 1, weightKg: 70 }] }] }),
    climb({ id: 'p-c1', createdAt: 50, date: '2026-01-14', climbs: [{ grade: 2, result: 'flash', count: 2 }, { grade: 3, result: 'send', count: 1 }] }),
    climb({ id: 'p-c2', createdAt: 60, date: '2026-01-16', climbs: [{ grade: 4, result: 'flash', count: 1 }, { grade: 5, result: 'send', count: 1 }, { grade: 6, result: 'attempt', count: 5 }] }),
    climb({ id: 'p-c3', createdAt: 70, date: '2026-01-18', climbs: [{ grade: 3, result: 'flash', count: 4 }, { grade: 4, result: 'send', count: 2 }] }),
    climb({ id: 'p-c4', createdAt: 75, date: '2026-01-19', climbs: [{ grade: 5, result: 'flash', count: 1 }] }),
    run({ id: 'p-r1', createdAt: 80, date: '2026-01-20', distanceM: 5000, elevationM: 30, durationSec: 30 * 60 }),
    run({ id: 'p-r2', createdAt: 90, date: '2026-01-22', distanceM: 8000, elevationM: 80, durationSec: 44 * 60 }),
    run({ id: 'p-r3', createdAt: 100, date: '2026-01-24', distanceM: 6000, elevationM: 20, durationSec: 40 * 60 }),
    // Short of 5 km: fast, but not eligible for the pace record.
    run({ id: 'p-r4', createdAt: 105, date: '2026-01-25', distanceM: 3000, elevationM: 0, durationSec: 11 * 60 }),
    // No duration: distance record without a pace.
    run({ id: 'p-r5', createdAt: 107, date: '2026-01-26', distanceM: 12500, elevationM: 510, durationSec: undefined }),
    ride({ id: 'p-b1', createdAt: 110, date: '2026-01-27', distanceM: 25000, elevationM: 200, durationSec: 65 * 60 }),
    ride({ id: 'p-b2', createdAt: 120, date: '2026-01-29', distanceM: 62000, elevationM: 1050, durationSec: 125 * 60 }),
    ride({ id: 'p-b3', createdAt: 130, date: '2026-01-31', distanceM: 21000, elevationM: 90, durationSec: 40 * 60 }),
    ride({ id: 'p-b4', createdAt: 140, date: '2026-02-01', distanceM: 15000, elevationM: 50, durationSec: 20 * 60 }),
  ],
  claims: [],
  body: [],
  weeklyGoal: 3,
  today: '2026-02-02',
});

add('perk_snapshots', {
  sessions: [
    lift({ id: 'k1', createdAt: 1, date: '2026-03-02', bonusPct: 0.1 }),
    lift({ id: 'k2', createdAt: 2, date: '2026-03-03', bonusPct: 0.08, luckPct: 0.1 }),
    climb({ id: 'k3', createdAt: 3, date: '2026-03-04', bonusPct: 0.135, luckPct: 0.28 }),
    run({ id: 'k4', createdAt: 4, date: '2026-03-05', bonusPct: 0, luckPct: 0 }),
    ride({ id: 'k5', createdAt: 5, date: '2026-03-06', bonusPct: 0.21, luckPct: 0.18 }),
    run({ id: 'k6', createdAt: 6, date: '2026-03-07', distanceM: 5000, elevationM: 0, durationSec: 1500, luckPct: 0.08 }),
    // 450 base XP at +5% lands exactly on a rounding boundary.
    run({ id: 'k7', createdAt: 7, date: '2026-03-08', distanceM: 4500, elevationM: 0, durationSec: undefined, bonusPct: 0.05 }),
    lift({ id: 'k8', createdAt: 8, date: '2026-03-09', bonusPct: 0.163, luckPct: 0.26 }),
    climb({ id: 'k9', createdAt: 9, date: '2026-03-10', bonusPct: 0.05 }),
    ride({ id: 'k10', createdAt: 10, date: '2026-03-11', bonusPct: 0.11, luckPct: 0.1 }),
  ],
  claims: [],
  body: [],
  weeklyGoal: 3,
  today: '2026-03-12',
});

add('equal_created_at_and_out_of_order', {
  sessions: [
    // Four sessions logged at the same instant: they replay in array order.
    ride({ id: 'e-b1', createdAt: 1000, date: '2026-03-05' }),
    lift({ id: 'e-l1', createdAt: 1000, date: '2026-03-02' }),
    run({ id: 'e-r1', createdAt: 1000, date: '2026-03-04' }),
    climb({ id: 'e-c1', createdAt: 1000, date: '2026-03-03' }),
    // Logged later, dated earlier (back-filled history).
    lift({ id: 'e-l0', createdAt: 2000, date: '2026-02-10', exercises: [{ name: 'Bench Press', sets: sets(3, 5, 90) }] }),
    run({ id: 'e-r0', createdAt: 2001, date: '2026-01-15', distanceM: 15000, elevationM: 300, durationSec: 80 * 60 }),
    // The array is not in createdAt order either.
    climb({ id: 'e-c0', createdAt: 500, date: '2026-03-20', climbs: [{ grade: 1, result: 'send', count: 6 }] }),
    ride({ id: 'e-b0', createdAt: 1500, date: '2026-03-21', distanceM: 55000, elevationM: 700, durationSec: 130 * 60 }),
    lift({ id: 'e-l2', createdAt: 2000, date: '2026-03-22' }),
    lift({ id: 'e-l3', createdAt: 2000, date: '2026-03-22', durationSec: 1800 }),
  ],
  claims: [
    { id: 'e-q1', questId: 'd:2026-03-02:0', xp: 150, claimedAt: 1000, date: '2026-03-02' },
    { id: 'e-q2', questId: 'w:2026-03-02:1', xp: 400, claimedAt: 2000, date: '2026-03-08' },
  ],
  body: [body({ id: 'e-w1', createdAt: 1000, date: '2026-03-02', weightKg: 82.4 }), body({ id: 'e-w2', createdAt: 2000, date: '2026-02-01', weightKg: 84 })],
  weeklyGoal: 3,
  today: '2026-03-23',
});

// One log, replayed with two different weekly goals.
const streakSessions: Session[] = (() => {
  // Sessions per week, starting Monday 2025-11-03 and crossing the new year.
  const perWeek = [3, 2, 5, 6, 2, 1, 0, 0, 4, 2, 2, 7, 5, 5, 0, 0, 0, 0, 0, 3, 2, 2, 2, 5, 1];
  const out: Session[] = [];
  let t = 1;
  perWeek.forEach((n, w) => {
    for (let i = 0; i < n; i++) {
      const date = addDays('2025-11-03', w * 7 + ((i * 2) % 7));
      const k = (w + i) % 4;
      const id = `s-${w}-${i}`;
      if (k === 0) out.push(lift({ id, createdAt: t++, date, durationSec: 2400 + 60 * i }));
      else if (k === 1) out.push(climb({ id, createdAt: t++, date }));
      else if (k === 2) out.push(run({ id, createdAt: t++, date, distanceM: 4000 + 500 * i, durationSec: 1500 + 200 * i }));
      else out.push(ride({ id, createdAt: t++, date, distanceM: 20000 + 1000 * w }));
    }
  });
  return out;
})();
add('gaps_and_streaks_goal_2', { sessions: streakSessions, claims: [], body: [], weeklyGoal: 2, today: '2026-04-22' });
add('gaps_and_streaks_goal_5', { sessions: streakSessions, claims: [], body: [], weeklyGoal: 5, today: '2026-04-20' });
add('gaps_and_streaks_goal_2_later', { sessions: streakSessions, claims: [], body: [], weeklyGoal: 2, today: '2026-06-01' });

add('body_checkins', {
  sessions: [
    lift({
      id: 'y-l1',
      createdAt: 150,
      date: '2026-03-03',
      exercises: [
        { name: 'Bench', sets: sets(3, 5, 80) },
        { name: 'Back Squat', sets: sets(3, 5, 125) },
        { name: 'Sumo Deadlift', sets: sets(1, 3, 165) },
      ],
    }),
    lift({
      id: 'y-l2',
      createdAt: 450,
      date: '2026-03-24',
      exercises: [
        { name: 'Flat Bench Press', sets: sets(2, 3, 122.5) },
        { name: 'High Bar Squat', sets: sets(2, 2, 160) },
        { name: 'Deadlift', sets: sets(1, 1, 200) },
      ],
    }),
  ],
  claims: [],
  body: [
    // Week 1: weight, then weight again + photos, then body fat (each part pays once).
    body({ id: 'y-w1', createdAt: 100, date: '2026-03-02', weightKg: 80 }),
    body({ id: 'y-w2', createdAt: 200, date: '2026-03-04', weightKg: 79.4, bodyFatPct: 18, photos: { front: 'p1', side: 'p2', back: 'p3' } }),
    body({ id: 'y-w3', createdAt: 210, date: '2026-03-06', weightKg: 79.8, bodyFatPct: 17.5 }),
    // Week 2: photos only, two angles.
    body({ id: 'y-w4', createdAt: 300, date: '2026-03-10', weightKg: undefined, photos: { front: 'p4', back: 'p5' } }),
    // Week 3: a note only (nothing to reward), then a zero weight (ignored), then one photo.
    body({ id: 'y-w5', createdAt: 310, date: '2026-03-16', weightKg: undefined, note: 'felt good' }),
    body({ id: 'y-w6', createdAt: 320, date: '2026-03-17', weightKg: 0, bodyFatPct: 0 }),
    body({ id: 'y-w7', createdAt: 330, date: '2026-03-18', weightKg: undefined, photos: { side: 'p6' } }),
    // Week 4 and 5.
    body({ id: 'y-w8', createdAt: 400, date: '2026-03-23', weightKg: 78.9 }),
    body({ id: 'y-w9', createdAt: 500, date: '2026-03-31', weightKg: 78.2, bodyFatPct: 16.8, photos: { front: 'p7', side: 'p8', back: 'p9' } }),
    // Back-filled: an older weigh-in logged last becomes the "first" weight.
    body({ id: 'y-w10', createdAt: 600, date: '2026-01-10', weightKg: 86.5 }),
    // Same date as the latest one, logged later: replaces it.
    body({ id: 'y-w11', createdAt: 610, date: '2026-03-31', weightKg: 78 }),
  ],
  weeklyGoal: 3,
  today: '2026-04-02',
});

add('body_before_and_after_lifts', {
  sessions: [lift({ id: 'z-l1', createdAt: 10 }), lift({ id: 'z-l2', createdAt: 30, date: '2026-03-09', exercises: [{ name: 'Barbell Squat', sets: sets(3, 5, 130) }, { name: 'Conventional Deadlift', sets: sets(1, 5, 150) }] })],
  claims: [],
  body: [body({ id: 'z-w0', createdAt: 5, date: '2026-03-01', weightKg: 90 }), body({ id: 'z-w1', createdAt: 20, date: '2026-03-05', weightKg: 80 }), body({ id: 'z-w2', createdAt: 40, date: '2026-03-10', weightKg: 74.5 })],
  weeklyGoal: 3,
  today: '2026-03-10',
});

add('quest_claims', {
  sessions: [lift({ id: 'q-l1', createdAt: 10 }), run({ id: 'q-r1', createdAt: 60, date: '2026-03-04' }), climb({ id: 'q-c1', createdAt: 70, date: '2026-03-10' })],
  claims: [
    // Claimed before anything was logged.
    { id: 'q0', questId: 'd:2026-03-01:0', xp: 100, claimedAt: 5, date: '2026-03-01' },
    { id: 'q1', questId: 'd:2026-03-02:0', xp: 150, claimedAt: 50, date: '2026-03-02' },
    { id: 'q2', questId: 'd:2026-03-02:1', xp: 200, claimedAt: 51, date: '2026-03-02' },
    { id: 'q3', questId: 'w:2026-03-02:0', xp: 400, claimedAt: 65, date: '2026-03-04' },
    { id: 'q4', questId: 'w:2026-03-02:2', xp: 2500, claimedAt: 66, date: '2026-03-04' },
    { id: 'q5', questId: 'd:2026-03-10:2', xp: 0, claimedAt: 80, date: '2026-03-10' },
    { id: 'q6', questId: 'w:2026-03-09:1', xp: 9000, claimedAt: 90, date: '2026-03-11' },
  ],
  body: [],
  weeklyGoal: 3,
  today: '2026-03-11',
});

// Huge sessions: several bosses fall per session, the whole campaign is
// cleared and the replay goes on into the endless "Echo" bosses.
add('boss_rush_into_echoes', {
  sessions: (() => {
    const out: Session[] = [];
    for (let i = 0; i < 84; i++) {
      const date = addDays('2025-06-02', i * 2);
      const id = `x${i}`;
      const k = i % 4;
      if (k === 0) out.push(ride({ id, createdAt: i + 1, date, distanceM: 150000 + 1500 * i, elevationM: 2200 + 10 * i, durationSec: 6 * 3600 }));
      else if (k === 1) out.push(run({ id, createdAt: i + 1, date, distanceM: 30000 + 400 * i, elevationM: 450, durationSec: 3 * 3600 + 60 * i }));
      else if (k === 2)
        out.push(
          lift({
            id,
            createdAt: i + 1,
            date,
            durationSec: 7200,
            exercises: [
              { name: 'Squat', sets: sets(8, 8, 140 + i) },
              { name: 'Deadlift', sets: sets(6, 6, 180 + i) },
              { name: 'Bench Press', sets: sets(8, 8, 100 + 0.5 * i) },
            ],
          }),
        );
      else out.push(climb({ id, createdAt: i + 1, date, durationSec: 3 * 3600, climbs: [{ grade: 8 + (i % 3), result: 'send', count: 9 }, { grade: 7, result: 'flash', count: 12 }, { grade: 11, result: 'attempt', count: 6 }] }));
    }
    return out;
  })(),
  claims: [],
  body: [body({ id: 'x-w', createdAt: 0, date: '2025-06-01', weightKg: 92.5 })],
  weeklyGoal: 3,
  today: '2025-11-20',
});

// --- seeded random logs -----------------------------------------------------

const EXERCISES: { name: string; base: number; bw?: boolean }[] = [
  { name: 'Bench Press', base: 60 },
  { name: 'bench press', base: 60 },
  { name: 'Squat', base: 80 },
  { name: 'Back  Squat', base: 85 },
  { name: 'Deadlift', base: 110 },
  { name: 'Sumo Deadlift', base: 105 },
  { name: 'Overhead Press', base: 35 },
  { name: 'Barbell Row', base: 50 },
  { name: 'Lat Pulldown', base: 45 },
  { name: 'Leg Press', base: 140 },
  { name: 'Bicep Curl', base: 12.5 },
  { name: 'Pull-up', base: 0, bw: true },
  { name: 'Push Up', base: 0, bw: true },
  { name: 'Dips', base: 0, bw: true },
  { name: ' Plank  Row ', base: 15 },
];
const BONUS_CHOICES = [undefined, undefined, 0, 0.03, 0.05, 0.08, 0.11, 0.163, 0.2];
const LUCK_CHOICES = [undefined, undefined, 0, 0.05, 0.08, 0.1, 0.18, 0.28];
const CLAIM_XP = [100, 150, 200, 250, 300, 400, 600];

function randomLog(seed: string, opts: { n: number; start: string; days: number; goal: number; mix: [number, number, number, number]; today: string; bodyEvery: number; claimEvery: number }): DeriveInput {
  const rng = makeRng(seed);
  const sessions: Session[] = [];
  let t = 1_700_000_000_000;
  for (let i = 0; i < opts.n; i++) {
    const progress = i / opts.n;
    let day = Math.floor((i * opts.days) / opts.n) + rng.int(3) - 1;
    // Now and then a session is back-filled days (or weeks) after the fact.
    if (rng.next() < 0.06) day -= 3 + rng.int(25);
    day = Math.max(0, Math.min(opts.days - 1, day));
    const date = addDays(opts.start, day);
    // Mostly increasing log times; a few logged in the same instant.
    if (rng.next() >= 0.07) t += 600_000 + rng.int(40_000_000);
    const d = rng.weighted(DISCIPLINES, (x) => opts.mix[DISCIPLINES.indexOf(x)]) as Discipline;
    const base = {
      id: `${seed}-${i}`,
      date,
      createdAt: t,
      source: (rng.next() < 0.15 ? 'strava' : 'manual') as 'manual' | 'strava',
      bonusPct: rng.pick(BONUS_CHOICES),
      luckPct: rng.pick(LUCK_CHOICES),
    };
    if (base.source === 'strava') Object.assign(base, { stravaId: 9_000_000 + i, title: `Activity ${i}` });
    if (rng.next() < 0.1) Object.assign(base, { notes: 'felt strong' });
    if (d === 'lift') {
      const nEx = 2 + rng.int(4);
      const exercises: LiftExercise[] = [];
      for (let e = 0; e < nEx; e++) {
        const ex = rng.pick(EXERCISES);
        const nSets = rng.int(6); // 0..5 (an exercise can be left empty)
        const top = ex.bw ? 0 : Math.round((ex.base * (1 + progress * 0.9) * (0.85 + rng.next() * 0.3)) / 2.5) * 2.5;
        const exSets = [];
        for (let k = 0; k < nSets; k++) exSets.push({ reps: ex.bw ? 4 + rng.int(22) : 1 + rng.int(12), weightKg: ex.bw ? 0 : Math.max(0, top - 2.5 * rng.int(4)) });
        exercises.push({ name: ex.name, sets: exSets });
      }
      const s: LiftSession = { ...base, discipline: 'lift', exercises };
      if (rng.next() < 0.85) s.durationSec = 1800 + rng.int(7400);
      sessions.push(s);
    } else if (d === 'climb') {
      const n = 2 + rng.int(5);
      const climbs: ClimbEntry[] = [];
      const cap = 1 + Math.floor(progress * 9);
      for (let k = 0; k < n; k++) {
        const result = rng.pick<ClimbResult>(['flash', 'send', 'send', 'attempt']);
        climbs.push({ grade: -1 + rng.int(cap + 2), result, count: rng.int(7) });
      }
      const s: ClimbSession = { ...base, discipline: 'climb', climbs };
      if (rng.next() < 0.8) s.durationSec = 2400 + rng.int(9000);
      sessions.push(s);
    } else if (d === 'run') {
      const big = rng.next() < 0.04;
      const distanceM = big ? 42195 : Math.round((2000 + rng.next() * (6000 + progress * 20000)) * 10) / 10;
      const s: CardioSession = { ...base, discipline: 'run', distanceM, elevationM: rng.next() < 0.2 ? 0 : rng.int(650) };
      if (rng.next() < 0.88) s.durationSec = Math.round((distanceM / 1000) * (235 + rng.int(200)));
      sessions.push(s);
    } else {
      const distanceM = Math.round(8000 + rng.next() * (40000 + progress * 130000));
      const s: CardioSession = { ...base, discipline: 'ride', distanceM, elevationM: rng.next() < 0.15 ? 0 : rng.int(2600) };
      if (rng.next() < 0.88) s.durationSec = Math.round((distanceM / 1000 / (17 + rng.int(18))) * 3600);
      sessions.push(s);
    }
  }
  const lastT = t;
  const span = lastT - 1_700_000_000_000;
  const bodyEntries: BodyEntry[] = [];
  let w = 84;
  let n = 0;
  for (let day = 2; day < opts.days; day += opts.bodyEvery + rng.int(5) - 1) {
    if (rng.next() < 0.12) day += 21; // a break in the check-in streak
    if (day >= opts.days) break;
    w += (rng.next() - 0.62) * 0.8;
    const e: BodyEntry = { id: `${seed}-w${n++}`, date: addDays(opts.start, day), createdAt: 1_700_000_000_000 + Math.floor((day / opts.days) * span) + rng.int(5000) };
    const kind = rng.next();
    if (kind < 0.8) e.weightKg = Math.round(w * 10) / 10;
    if (kind > 0.55) e.bodyFatPct = Math.round((19 - (day / opts.days) * 4 + rng.next()) * 10) / 10;
    const ph = rng.next();
    if (ph < 0.25) e.photos = { front: `f${n}`, side: `s${n}`, back: `b${n}` };
    else if (ph < 0.4) e.photos = { front: `f${n}` };
    else if (ph < 0.45) e.photos = { side: `s${n}`, back: `b${n}` };
    if (rng.next() < 0.1) e.note = 'after breakfast';
    bodyEntries.push(e);
  }
  const claims: QuestClaim[] = [];
  n = 0;
  for (let day = 1; day < opts.days; day += 1 + rng.int(opts.claimEvery * 2)) {
    const date = addDays(opts.start, day);
    const weekly = rng.next() < 0.3;
    claims.push({
      id: `${seed}-q${n}`,
      questId: weekly ? `w:${weekKey(date)}:${rng.int(3)}` : `d:${date}:${rng.int(3)}`,
      xp: rng.pick(CLAIM_XP) * (weekly ? 3 : 1),
      claimedAt: 1_700_000_000_000 + Math.floor((day / opts.days) * span) + rng.int(5000),
      date,
    });
    n++;
  }
  return { sessions, claims, body: bodyEntries, weeklyGoal: opts.goal, today: opts.today };
}

add('random_year_all_round', randomLog('ra', { n: 230, start: '2025-01-06', days: 365, goal: 3, mix: [4, 3, 3, 2], today: '2026-01-08', bodyEvery: 7, claimEvery: 4 }));
add('random_two_years_heavy', randomLog('rb', { n: 400, start: '2024-02-26', days: 730, goal: 4, mix: [5, 2, 4, 3], today: '2026-02-24', bodyEvery: 8, claimEvery: 6 }));
add('random_sparse_climber', randomLog('rc', { n: 150, start: '2024-11-18', days: 540, goal: 2, mix: [1, 6, 3, 1], today: '2026-07-01', bodyEvery: 12, claimEvery: 9 }));

// ---------------------------------------------------------------------------
// Run the real engine
// ---------------------------------------------------------------------------

const clone = <T>(x: T): T => JSON.parse(JSON.stringify(x));

const derived = cases.map((c) => {
  // The engine gets its own copy so the fixture input is exactly what was fed in.
  const input = clone(c.input);
  return { name: c.name, input, state: derive(clone(input)) };
});

const deriveOut = derived.map((c) => ({ name: c.name, input: c.input, expected: c.state }));
const deriveJson = '[\n' + deriveOut.map((c) => JSON.stringify(c)).join(',\n') + '\n]\n';
fs.writeFileSync(path.join(OUT_DIR, 'derive_cases.json'), deriveJson);

// ---------------------------------------------------------------------------
// Core vectors
// ---------------------------------------------------------------------------

const HASH_STRINGS = [
  '',
  'a',
  'abc',
  'drop:l1',
  'daily:2026-03-02',
  'weekly:2026-03-02',
  'Tiny Titan',
  'The quick brown fox jumps over the lazy dog',
  '2026-11-13',
  'café',
  'Ünïcödé — ✓',
  '日本語のテキスト',
  '🏋️ lift 🧗 climb',
  '𝔘𝔫𝔦𝔠𝔬𝔡𝔢 😀',
  'drop:ra-229',
  ' leading and trailing ',
  'x'.repeat(300),
];

const RNG_SEEDS: (string | number)[] = ['x', 'drop:l1', 'daily:2026-03-02', '', 0, 1, 42, 123456789, 4294967295, 4294967296 + 7, -5, 2.9];
const PICK_FROM = ['alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta', 'eta'];
const WEIGHTS = [55, 30, 12, 3, 0, 22, 165, 0.4, 82.5];

const rngVectors = RNG_SEEDS.map((seed) => {
  const r = makeRng(seed);
  const floats: number[] = [];
  const u32: number[] = [];
  for (let i = 0; i < 8; i++) {
    const f = r.next();
    floats.push(f);
    u32.push(f * 4294967296); // exact: the float is k / 2^32
  }
  const ints = [10, 1000, 7, 1, 4294967296].map((max) => ({ max, out: r.int(max) }));
  const picks = [0, 1, 2].map(() => r.pick(PICK_FROM));
  const weighted = [0, 1, 2, 3].map(() => r.weighted(WEIGHTS.map((_, i) => i), (i) => WEIGHTS[i]));
  const weightedNone = r.weighted([0, 1, 2], () => 0);
  const weightedNegative = r.weighted([0, 1, 2], (i) => (i === 1 ? 5 : -3));
  const after = r.next() * 4294967296;
  return { seed, floats, u32, ints, pickFrom: PICK_FROM, picks, weights: WEIGHTS, weighted, weightedNone, weightedNegative, after };
});

const DATE_KEYS = [
  '2026-03-02',
  '2026-03-04',
  '2026-03-07',
  '2026-03-08',
  '2026-01-01',
  '2025-12-31',
  '2025-12-29',
  '2026-01-04',
  '2024-02-28',
  '2024-02-29',
  '2024-03-01',
  '2023-02-28',
  '2023-03-01',
  '2024-12-30',
  '2024-12-31',
  '2025-01-01',
  '2020-02-29',
  '2021-01-03',
  '2000-02-29',
  '2000-01-01',
  '1999-12-31',
  '1970-01-01',
  '1969-12-31',
  '2100-02-28',
  '2100-03-01',
  '2026-03-29', // DST starts (Europe)
  '2026-10-25', // DST ends (Europe)
  '2026-11-01', // DST ends (US)
  '2026-06-15',
  '2026-11-13',
  '2031-08-09',
  '2038-01-19',
];
const DAY_OFFSETS = [0, 1, -1, 6, 7, -7, 28, 30, 59, 365, 366, -365, -400, 1461, 10000];
const WEEK_OFFSETS = [0, 1, -1, 4, 52, -52, 53, 260];
const fmt = (key: string, opts: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat('en-US', opts).format(parseDateKey(key));
const FORMAT_OPTS: Intl.DateTimeFormatOptions[] = [
  { month: 'short', day: 'numeric' },
  { weekday: 'short', month: 'short', day: 'numeric' },
  { month: 'short', day: 'numeric', year: 'numeric' },
  { month: 'long', day: 'numeric', year: 'numeric' },
  { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' },
  { weekday: 'long' },
  { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' },
  { month: 'long', year: 'numeric' },
  { month: 'short' },
  { year: 'numeric' },
];

const dateVectors = DATE_KEYS.map((key, i) => {
  const p = parseDateKey(key);
  return {
    key,
    parts: { year: p.getFullYear(), month: p.getMonth() + 1, day: p.getDate(), weekday: p.getDay() },
    weekKey: weekKey(key),
    weekdayIndex: weekdayIndex(key),
    addDays: DAY_OFFSETS.map((n) => ({ n, out: addDays(key, n) })),
    addWeeks: WEEK_OFFSETS.map((n) => ({ n, out: addWeeks(key, n) })),
    daysBetween: DATE_KEYS.filter((_, j) => (i + j) % 3 === 0).map((other) => ({ other, out: daysBetween(key, other) })),
    // The app's `formatDate` uses the browser locale; the port fixes it to en-US.
    formatDate: formatDate(key),
    formatDateLong: formatDateLong(key),
    formats: FORMAT_OPTS.map((opts) => ({ opts, out: fmt(key, opts) })),
  };
});
// Guard: the TS functions must already produce the en-US shapes in this environment.
for (const v of dateVectors) {
  if (v.formatDate !== fmt(v.key, { month: 'short', day: 'numeric' })) throw new Error(`formatDate is not en-US here: ${v.formatDate}`);
  if (v.formatDateLong !== fmt(v.key, { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })) throw new Error(`formatDateLong is not en-US here: ${v.formatDateLong}`);
}

const relativeDayVectors = [
  ['2026-03-08', '2026-03-08'],
  ['2026-03-07', '2026-03-08'],
  ['2026-03-06', '2026-03-08'],
  ['2026-03-02', '2026-03-08'],
  ['2026-03-01', '2026-03-08'],
  ['2026-02-20', '2026-03-08'],
  ['2025-12-31', '2026-01-01'],
  ['2025-12-28', '2026-01-03'],
  ['2025-12-27', '2026-01-03'],
  ['2026-03-10', '2026-03-08'], // a date in the future
  ['2024-02-29', '2024-03-01'],
  ['2024-02-23', '2024-03-01'],
].map(([key, today]) => ({ key, today, out: relativeDay(key, today) }));

const XP_TOTALS = [
  0, 1, 100, 495, 496, 497, 600, 1099, 1100, 1500, 2500, 4999.9, 5000, 7777.5, 10000, 12345, 20000, 33333, 50000, 75000, 100000, 150000, 200000, 250000, 400000, 600000, 800000, 1000000, 1500000, 2000000, 2165000, 2200000, 3000000, 1e7,
  1e9, -50, 374, 375, 376, 0.999,
];
const levelVectors = XP_TOTALS.map((xp) => ({ xp, hero: heroLevel(xp), disc: discLevel(xp), custom: levelFromXp(xp, (l) => 100 * l) }));
const LEVELS = [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 14, 15, 16, 19, 20, 21, 22, 25, 29, 30, 31, 34, 35, 39, 40, 41, 49, 50, 51, 60, 75, 98, 99, 100];
const levelTableVectors = LEVELS.map((level) => ({
  level,
  heroXpForLevel: heroXpForLevel(level),
  discXpForLevel: discXpForLevel(level),
  heroXpToReach: heroXpToReach(level),
  discXpToReach: discXpToReach(level),
  stageForLevel: stageForLevel(level),
  rankForLevel: rankForLevel(level),
}));

const e1rmVectors = [
  [100, 1],
  [100, 0],
  [100, 5],
  [62.5, 8],
  [80, 3],
  [142.5, 12],
  [0, 10],
  [200, 2],
  [37.5, 30],
  [61.23496995, 6],
].map(([weightKg, reps]) => ({ weightKg, reps, out: e1rm(weightKg, reps) }));

const GRADES = [-5, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 25, 2.4, 2.5, 2.6, -0.5, -1.5];
const gradeVectors = GRADES.map((grade) => ({ grade, clampGrade: clampGrade(grade), climbGradeXp: climbGradeXp(grade), gradeLabel: gradeLabel(grade) }));

const fmtIntVectors = [0, 1, 12, 999, 1000, 1234.4, 1234.5, 12345, 999999.5, 1000000, 1234567890, -1, -999, -1000, -1234567.8, 0.4, 0.5, -0.5, 2200].map((n) => ({ n, out: fmtInt(n) }));

const normalizeVectors = [
  'Bench Press',
  '  Bench   Press  ',
  'BENCH\tPRESS',
  'pull-up',
  '',
  '   ',
  'Overhead\n Press',
  'Back Squat',
  '　Wide Row﻿',
  'ÉPAULÉ-JETÉ',
  'Ünder Över',
  'Жим Лёжа',
  'a  b   c    d',
].map((name) => ({ name, out: normalizeExercise(name) }));

const isDisciplineVectors = ['lift', 'climb', 'run', 'ride', 'swim', '', 'Lift'].map((x) => ({ x, out: isDiscipline(x) }));

const SESSIONS: Session[] = [
  lift(),
  climb(),
  run(),
  ride(),
  lift({ id: 'v-bw', durationSec: undefined, exercises: [{ name: ' Push  Up', sets: sets(4, 25, 0) }, { name: 'Rest', sets: [] }] }),
  lift({ id: 'v-heavy', durationSec: 4 * 3600, exercises: [{ name: 'Deadlift', sets: [{ reps: 1, weightKg: 222.5 }, { reps: 3, weightKg: 201.5 }, { reps: 0, weightKg: 100 }, { reps: 5, weightKg: 0 }] }] }),
  lift({ id: 'v-frac', durationSec: 59, exercises: [{ name: 'Curl', sets: [{ reps: 7, weightKg: 12.25 }, { reps: 9, weightKg: 7.5 }, { reps: 11, weightKg: 0.5 }] }] }),
  lift({ id: 'v-empty', durationSec: 0, exercises: [] }),
  climb({ id: 'v-vb', climbs: [{ grade: -1, result: 'flash', count: 5 }, { grade: -1, result: 'attempt', count: 3 }, { grade: 0, result: 'send', count: 0 }] }),
  climb({ id: 'v-hard', durationSec: 100 * 60, climbs: [{ grade: 17, result: 'send', count: 1 }, { grade: 12, result: 'flash', count: 2 }, { grade: 9, result: 'attempt', count: 7 }, { grade: 3, result: 'send', count: 11 }] }),
  climb({ id: 'v-attempts', climbs: [{ grade: 6, result: 'attempt', count: 9 }] }),
  run({ id: 'v-quarter', distanceM: 250, elevationM: 0, durationSec: 75 }),
  run({ id: 'v-ties', distanceM: 1250, elevationM: 3, durationSec: 45 }),
  run({ id: 'v-frac', distanceM: 5234.7, elevationM: 61, durationSec: 1637 }),
  run({ id: 'v-nodur', distanceM: 21097, elevationM: 240, durationSec: undefined }),
  run({ id: 'v-zero', distanceM: 0, elevationM: 0, durationSec: 600 }),
  ride({ id: 'v-long', distanceM: 161250, elevationM: 2345, durationSec: 5 * 3600 + 17 * 60 }),
  ride({ id: 'v-short', distanceM: 2750, elevationM: 12, durationSec: 420 }),
  ride({ id: 'v-noelev', distanceM: 30000, elevationM: 0, durationSec: undefined }),
];
const sessionVectors = SESSIONS.map((s) => {
  const session = clone(s);
  return { session, baseSessionXp: baseSessionXp(session), sessionStats: sessionStats(session) };
});

const STREAK_CASES: { weekCounts: Record<string, number>; goal: number; nowWeek: string }[] = [
  { weekCounts: {}, goal: 3, nowWeek: '2026-03-02' },
  { weekCounts: { '2026-02-16': 3, '2026-02-23': 4, '2026-03-02': 1 }, goal: 3, nowWeek: '2026-03-02' },
  { weekCounts: { '2026-02-16': 3, '2026-02-23': 4, '2026-03-02': 3 }, goal: 3, nowWeek: '2026-03-02' },
  { weekCounts: { '2026-02-02': 3, '2026-02-09': 3, '2026-02-23': 3 }, goal: 3, nowWeek: '2026-02-23' },
  { weekCounts: { '2026-02-02': 3, '2026-02-09': 3, '2026-02-23': 3 }, goal: 3, nowWeek: '2026-03-09' },
  // Keys inserted out of order, across a year boundary.
  { weekCounts: { '2026-01-05': 2, '2025-12-22': 2, '2025-12-29': 5, '2025-12-15': 1, '2025-12-08': 2 }, goal: 2, nowWeek: '2026-01-12' },
  { weekCounts: { '2026-01-05': 2, '2025-12-22': 2, '2025-12-29': 5, '2025-12-15': 1, '2025-12-08': 2 }, goal: 2, nowWeek: '2026-01-05' },
  { weekCounts: { '2026-01-05': 2, '2025-12-22': 2, '2025-12-29': 5, '2025-12-15': 1, '2025-12-08': 2 }, goal: 1, nowWeek: '2026-01-19' },
  { weekCounts: { '2026-03-02': 7 }, goal: 7, nowWeek: '2026-03-02' },
  { weekCounts: { '2026-03-02': 7 }, goal: 7, nowWeek: '2026-03-09' },
  { weekCounts: { '2026-03-02': 7 }, goal: 7, nowWeek: '2026-03-16' },
  { weekCounts: Object.fromEntries(Array.from({ length: 60 }, (_, i) => [addWeeks('2024-12-30', i), i % 13 === 12 ? 1 : 2 + (i % 3)])), goal: 2, nowWeek: '2026-02-16' },
  { weekCounts: Object.fromEntries(Array.from({ length: 60 }, (_, i) => [addWeeks('2024-12-30', i), i % 13 === 12 ? 1 : 2 + (i % 3)])), goal: 3, nowWeek: '2026-02-16' },
];
const streakVectors = STREAK_CASES.map((c) => ({ ...c, out: computeStreak(c.weekCounts, c.goal, c.nowWeek) }));

type Reward = { flags: number; entry: Pick<BodyEntry, 'weightKg' | 'bodyFatPct' | 'photos'> };
const REWARD_CASES: Reward[] = [
  { flags: 0, entry: {} },
  { flags: 0, entry: { weightKg: 80 } },
  { flags: 1, entry: { weightKg: 79.5, photos: { front: 'a', side: 'b', back: 'c' } } },
  { flags: 29, entry: { weightKg: 79, bodyFatPct: 18 } },
  { flags: 31, entry: { weightKg: 79, bodyFatPct: 18, photos: { front: 'a', side: 'b', back: 'c' } } },
  { flags: 0, entry: { weightKg: 0, bodyFatPct: 0 } },
  { flags: 0, entry: { weightKg: -3, bodyFatPct: 12.5 } },
  { flags: 0, entry: { photos: {} } },
  { flags: 0, entry: { photos: { side: 'x' } } },
  { flags: 8, entry: { photos: { side: 'x', back: 'y' } } },
  { flags: 4, entry: { photos: { front: '', side: 'x' } } },
  { flags: 2, entry: { weightKg: 70.2, bodyFatPct: 11, photos: { front: 'q' } } },
];
const rewardVectors = REWARD_CASES.map((c) => ({ ...c, out: bodyEntryReward(c.flags, c.entry) }));

const RATIO_CASES: Progress[] = [
  { cur: 2, target: 4, unit: 'grade' },
  { cur: -2, target: 2, unit: 'grade' },
  { cur: -1, target: 2, unit: 'grade' },
  { cur: 12, target: 10, unit: 'grade' },
  { cur: 39000, target: 100000, unit: 'm' },
  { cur: 3, target: 10, unit: 'count' },
  { cur: 1, target: 3, unit: 'count' },
  { cur: 15, target: 10, unit: 'count' },
  { cur: 0, target: 0, unit: 'count' },
  { cur: -4, target: 10, unit: 'xp' },
  { cur: 1.25, target: 1.5, unit: 'ratio' },
  { cur: 7, target: 8, unit: 'weeks' },
];
const ratioVectors = RATIO_CASES.map((p) => ({ p, out: progressRatio(p) }));

const weightStepVectors = [
  { weightUnit: 'kg' },
  { weightUnit: 'lb' },
  { weightUnit: 'kg', weightStep: 5 },
  { weightUnit: 'kg', weightStep: 1 },
  { weightUnit: 'kg', weightStep: 10 },
  { weightUnit: 'kg', weightStep: 2.5 },
  { weightUnit: 'kg', weightStep: 3 },
  { weightUnit: 'kg', weightStep: 0 },
  { weightUnit: 'lb', weightStep: 1 },
  { weightUnit: 'lb', weightStep: 2.5 },
  { weightUnit: 'lb', weightStep: 10 },
].map((settings) => ({ settings, out: weightStepOf(settings as Parameters<typeof weightStepOf>[0]) }));

// --- catalogs: every static field, plus the functions that describe them ------

const catalog = {
  constants: { WEAK_MULT, RARITY_WEIGHT, TIER_COLOR, ACH_GROUPS, DEFAULT_SETTINGS },
  zones: ZONES,
  bosses: BOSSES,
  bossAt: [0, 3, 23, 24, 25, 27, 28, 33, 34, 35, 60].map((index) => ({ index, isEcho: isEcho(index), out: bossAt(index) })),
  bossesInZone: [0, 1, 2, 3, 4, 5, 6].map((zone) => ({ zone, out: bossesInZone(zone).map((x) => ({ id: x.boss.id, index: x.index })) })),
  achievements: ACHIEVEMENTS.map((a) => ({ id: a.id, name: a.name, desc: a.desc, icon: a.icon, xp: a.xp, group: a.group, secret: a.secret, hasProgress: !!a.progress, tier: tierOf(a) })),
  items: ITEMS.map((it) => ({
    id: it.id,
    name: it.name,
    slot: it.slot,
    rarity: it.rarity,
    discipline: it.discipline,
    flavor: it.flavor,
    perk: it.perk,
    visual: it.visual,
    unlockKind: it.unlock.kind,
    minHeroLevel: it.unlock.kind === 'drop' ? it.unlock.minHeroLevel : undefined,
    hint: it.unlock.kind === 'unlock' ? it.unlock.hint : undefined,
    hasProgress: it.unlock.kind === 'unlock' && !!it.unlock.progress,
    unlockHint: unlockHint(it),
    perkSummary: perkSummary(it.perk),
  })),
  pets: PETS.map((p) => ({ id: p.id, name: p.name, species: p.species, rarity: p.rarity, discipline: p.discipline, flavor: p.flavor, perk: p.perk, hint: p.hint, perkSummary: perkSummary(p.perk) })),
};

// --- every goal, evaluated on the final state of each derive case -------------
// (covers the unlock conditions that no scenario happens to trigger)

const LOADOUTS: { loadout: Loadout; activePet: string | null }[] = [
  { loadout: {}, activePet: null },
  { loadout: { body: 'tee_grey', legs: 'shorts_navy', feet: 'trainers_worn' }, activePet: 'slime' },
  { loadout: { head: 'champion_headband', accessory: 'leather_belt', back: 'crash_pad', feet: 'carbon_racers', aura: 'flame_aura', hands: 'golem_bracers' }, activePet: 'tortoise' },
  { loadout: { head: 'titans_laurel', feet: 'comfy_slippers', back: 'golden_cape', aura: 'rainbow_aura', body: 'polka_jersey', accessory: 'wyvern_chalk_bag', hands: 'golden_mitts' }, activePet: 'dragon' },
  { loadout: { head: 'sweatband', face: 'aviators', feet: 'lucky_socks', back: null, legs: 'no_such_item', body: 'chalk_bag' }, activePet: 'cat' },
  { loadout: { head: 'iron_crown', aura: 'titan_aura', accessory: 'marathon_medal', feet: 'winged_sandals' }, activePet: 'no_such_pet' },
];

const stateVectors = derived.map((c) => {
  const s: PlayerState = c.state;
  const prog = (p: Progress | null | undefined) => (p ? { cur: p.cur, target: p.target, unit: p.unit, ratio: progressRatio(p) } : null);
  return {
    case: c.name,
    achievements: ACHIEVEMENTS.map((a) => ({ id: a.id, check: a.check(s), progress: prog(a.progress?.(s)) })),
    items: ITEMS.filter((it) => it.unlock.kind === 'unlock').map((it) => ({ id: it.id, check: it.unlock.kind === 'unlock' && it.unlock.check(s), progress: prog(unlockProgress(it, s)) })),
    pets: PETS.map((p) => ({ id: p.id, check: p.check(s), progress: prog(p.progress?.(s)) })),
    computeTitle: computeTitle(s),
    trophyPoints: trophyPoints(s),
    counts: { items: ownedItemCount(s), pets: ownedPetCount(s), defeated: defeatedCount(s), hasFirstSession: hasAch(s, 'first_session'), hasZone6: hasAch(s, 'zone_6') },
    perks: LOADOUTS.map((l) => ({ loadout: l.loadout, activePet: l.activePet, perks: computePerks(s, l.loadout, l.activePet), sanitized: sanitizeLoadout(s, l.loadout, l.activePet) })),
  };
});

const core = {
  hashString: HASH_STRINGS.map((str) => ({ in: str, out: hashString(str) })),
  rng: rngVectors,
  dates: dateVectors,
  relativeDay: relativeDayVectors,
  levels: levelVectors,
  levelTables: levelTableVectors,
  e1rm: e1rmVectors,
  grades: gradeVectors,
  fmtInt: fmtIntVectors,
  normalizeExercise: normalizeVectors,
  isDiscipline: isDisciplineVectors,
  sessions: sessionVectors,
  computeStreak: streakVectors,
  bodyEntryReward: rewardVectors,
  progressRatio: ratioVectors,
  weightStepOf: weightStepVectors,
  catalog,
  states: stateVectors,
};

const coreJson =
  '{\n' +
  Object.entries(core)
    .map(([k, v]) => {
      if (Array.isArray(v)) return `${JSON.stringify(k)}: [\n${v.map((x) => JSON.stringify(x)).join(',\n')}\n]`;
      return `${JSON.stringify(k)}: ${JSON.stringify(v)}`;
    })
    .join(',\n') +
  '\n}\n';
fs.writeFileSync(path.join(OUT_DIR, 'core_vectors.json'), coreJson);

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

const kb = (s: string) => `${(Buffer.byteLength(s) / 1024).toFixed(0)} KB`;
console.log(`derive_cases.json: ${deriveOut.length} cases, ${kb(deriveJson)}`);
for (const c of derived) {
  const s = c.state;
  console.log(
    `  ${c.name.padEnd(34)} sessions=${String(c.input.sessions.length).padStart(3)} claims=${String(c.input.claims.length).padStart(3)} body=${String((c.input.body ?? []).length).padStart(3)}` +
      ` heroLv=${String(s.levels.hero.level).padStart(2)} bosses=${String(defeatedCount(s)).padStart(2)} campaignIndex=${String(s.campaign.index).padStart(2)}` +
      ` ach=${String(Object.keys(s.achievements).length).padStart(3)} items=${String(ownedItemCount(s)).padStart(2)} pets=${String(ownedPetCount(s)).padStart(2)} streakBest=${s.streak.best} chronicle=${s.chronicle.length}`,
  );
}
const counts = Object.entries(core).map(([k, v]) => `${k}=${Array.isArray(v) ? v.length : 1}`);
console.log(`core_vectors.json: ${kb(coreJson)} (${counts.join(', ')})`);
