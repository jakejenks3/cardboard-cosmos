// Parity fixture generator for the "second ring" of the Godot port
// (quests, diff, nextup, chatter, funfacts, format, summary, liftHistory).
//
// Run it from the web app's folder, where tsx and the TypeScript engine live:
//
//   cd tiny-titan && npx tsx ../tiny-titan-godot/tests/parity/gen_misc.ts
//
// It builds a few deterministic logs, derives PlayerStates with the real TS
// engine and writes misc_cases.json next to this file: the inputs and the TS
// outputs of every function the GDScript port has to reproduce. The Godot side
// (tests/parity_misc.gd) replays the inputs and compares.
//
// The file has two shared tables so that big inputs are stored once:
//   states: { <key>: PlayerState }        referenced by cases as "state": "<key>"
//   logs:   { <key>: { sessions, claims, body } }   referenced as "log": "<key>"

import { writeFileSync } from 'node:fs';
import path from 'node:path';
import type { BodyEntry, ClimbResult, LiftSession, LiftSet, QuestClaim, Session, Settings } from '../../../tiny-titan/src/game/types';
import type { PlayerState } from '../../../tiny-titan/src/game/state';
import type { ProgressUnit } from '../../../tiny-titan/src/game/goals';
import { derive } from '../../../tiny-titan/src/game/derive';
import { dailyQuests, weeklyQuests } from '../../../tiny-titan/src/game/quests';
import { diffBody, diffBulk, diffStates, totalDisciplineXp, type ResultEvent } from '../../../tiny-titan/src/game/diff';
import { allOpenGoals, nextGoals, type NextGoal } from '../../../tiny-titan/src/game/nextup';
import { petLine, type ChatterCtx } from '../../../tiny-titan/src/game/chatter';
import { funFacts } from '../../../tiny-titan/src/game/funfacts';
import * as F from '../../../tiny-titan/src/game/format';
import { DEFAULT_EXERCISES, summarizeSession } from '../../../tiny-titan/src/game/summary';
import * as LH from '../../../tiny-titan/src/game/liftHistory';
import { makeRng } from '../../../tiny-titan/src/game/rng';
import { addDays, weekKey } from '../../../tiny-titan/src/game/dates';
import { bossAt } from '../../../tiny-titan/src/game/campaign';

const OUT_FILE = path.join(path.dirname(path.resolve(process.argv[1])), 'misc_cases.json');

const KG: Settings = { weightUnit: 'kg', distanceUnit: 'km', sound: true, weeklyGoal: 3 };
const LB: Settings = { weightUnit: 'lb', distanceUnit: 'mi', sound: true, weeklyGoal: 4, weightStep: 5 };
const BOTH: Settings[] = [KG, LB];

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Error(`gen_misc: ${msg}`);
}

// ---------------------------------------------------------------------------
// Logs
// ---------------------------------------------------------------------------

interface Log {
  sessions: Session[];
  claims: QuestClaim[];
  body: BodyEntry[];
}

const set = (reps: number, weightKg: number): LiftSet => ({ reps, weightKg });
const T0 = Date.UTC(2026, 2, 2, 7, 0, 0); // only used as a replay-order clock

function lift(id: string, date: string, n: number, exercises: LiftSession['exercises'], over: Partial<LiftSession> = {}): LiftSession {
  return { id, discipline: 'lift', date, createdAt: T0 + n * 3_600_000, source: 'manual', exercises, ...over };
}
function climb(id: string, date: string, n: number, climbs: [number, ClimbResult, number][], over: Partial<Session> = {}): Session {
  return { id, discipline: 'climb', date, createdAt: T0 + n * 3_600_000, source: 'manual', climbs: climbs.map(([grade, result, count]) => ({ grade, result, count })), ...over } as Session;
}
function cardio(id: string, discipline: 'run' | 'ride', date: string, n: number, distanceM: number, elevationM: number, durationSec?: number, over: Partial<Session> = {}): Session {
  const s = { id, discipline, date, createdAt: T0 + n * 3_600_000, source: 'manual', distanceM, elevationM, ...over } as Session;
  if (durationSec !== undefined) s.durationSec = durationSec;
  return s;
}

/** Hand-written: two weeks that walk through every kind of PR. */
const WEEK: Log = {
  sessions: [
    lift('w01', '2026-03-02', 1, [
      { name: 'Squat', sets: [set(5, 100), set(5, 100), set(5, 100)] },
      { name: 'Bench Press', sets: [set(5, 60), set(5, 60), set(4, 60)] },
      { name: 'Pull-up', sets: [set(8, 0), set(7, 0)] },
    ], { durationSec: 3600 }),
    climb('w02', '2026-03-03', 25, [[2, 'send', 3], [3, 'flash', 1], [4, 'attempt', 2]], { durationSec: 5400 }),
    cardio('w03', 'run', '2026-03-04', 49, 5200, 40, 1680),
    cardio('w04', 'ride', '2026-03-05', 73, 24000, 210, 3600),
    lift('w05', '2026-03-06', 97, [
      { name: 'squat ', sets: [set(5, 102.5), set(5, 102.5), set(5, 102.5)] },
      { name: 'Bench Press', sets: [set(6, 60), set(5, 60)] },
      { name: 'Deadlift', sets: [set(5, 140)] },
      { name: 'Overhead Press', sets: [set(5, 41.25), set(5, 41.25), set(5, 41.25)] },
    ], { durationSec: 4200, bonusPct: 0.04 }),
    climb('w06', '2026-03-07', 121, [[4, 'flash', 1], [1, 'send', 4], [-1, 'send', 2]]),
    cardio('w07', 'run', '2026-03-08', 145, 8046.72, 1, 2400, { bonusPct: 0.03, luckPct: 0.08 }),
    cardio('w08', 'ride', '2026-03-09', 169, 40233.6, 1, 5400, { source: 'strava', stravaId: 123456789, title: 'Morning Ride' }),
    lift('w09', '2026-03-09', 170, [
      { name: 'Pull-Up', sets: [set(5, 5), set(5, 5)] },
      { name: 'Dip', sets: [set(12, 0), set(0, 0)] },
      { name: '', sets: [set(5, 20)] },
      { name: 'Face Pull', sets: [] },
    ]),
    lift('w10', '2026-03-11', 217, [
      { name: 'Overhead Press', sets: [set(5, 43.75), set(4, 43.75), set(3, 43.75)] },
      { name: 'Squat', sets: [set(8, 100)] },
    ], { durationSec: 2700, notes: 'felt strong' }),
    cardio('w11', 'run', '2026-03-12', 241, 3000, 0),
    climb('w12', '2026-03-14', 289, [[1, 'send', 1], [5, 'attempt', 3]], { durationSec: 1800 }),
  ],
  claims: [
    { id: 'wc1', questId: 'd:2026-03-02:0', xp: 150, claimedAt: T0 + 2 * 3_600_000, date: '2026-03-02' },
    { id: 'wc2', questId: 'w:2026-03-02:0', xp: 400, claimedAt: T0 + 122 * 3_600_000, date: '2026-03-07' },
    { id: 'wc3', questId: 'd:2026-03-09:2', xp: 150, claimedAt: T0 + 171 * 3_600_000, date: '2026-03-09' },
  ],
  body: [],
};

const FIRST: Log = { sessions: [WEEK.sessions[0]], claims: [], body: [] };
const EMPTY: Log = { sessions: [], claims: [], body: [] };

/** The log from tests/liftHistory.test.ts. */
const SPLIT: Log = {
  sessions: [
    lift('a1', '2026-03-02', 1, [
      { name: 'Squat', sets: [set(5, 100), set(5, 100), set(5, 100)] },
      { name: 'Bench Press', sets: [set(5, 60), set(5, 60), set(4, 60)] },
    ]),
    lift('b1', '2026-03-04', 2, [
      { name: 'Deadlift', sets: [set(5, 120), set(3, 130), set(1, 140)] },
      { name: 'Pull-up', sets: [set(8, 0), set(7, 0)] },
    ]),
    lift('a2', '2026-03-09', 3, [
      { name: 'squat ', sets: [set(5, 105), set(5, 105)] },
      { name: 'Bench Press', sets: [set(5, 62.5)] },
    ]),
    cardio('r', 'run', '2026-03-10', 4, 5000, 0),
    lift('s', '2026-03-11', 5, []),
  ],
  claims: [],
  body: [],
};

/**
 * Seeded-random log with check-ins and quest claims. `mix` holds the cumulative
 * chances of a session being a lift / climb / run (anything above is a ride).
 */
function buildLog(seed: string, count: number, mix: [number, number, number] = [0.4, 0.6, 0.85]): Log {
  const rng = makeRng(seed);
  const sessions: Session[] = [];
  const claims: QuestClaim[] = [];
  const body: BodyEntry[] = [];
  const start = '2025-09-01';
  const base = Date.UTC(2025, 8, 1, 6, 0, 0);
  const liftNames = ['Squat', 'squat ', 'Bench Press', 'bench  press', 'Deadlift', 'Overhead Press', 'Barbell Row', 'Pull-up', 'Dip', 'Hip Thrust', 'Romanian Deadlift', 'Bicep Curl'];
  const baseKg: Record<string, number> = { squat: 80, 'bench press': 55, deadlift: 100, 'overhead press': 35, 'barbell row': 50, 'pull-up': 0, dip: 0, 'hip thrust': 90, 'romanian deadlift': 70, 'bicep curl': 12.5 };
  const claimed = new Set<string>();
  let day = 0;
  let lastBodyDay = 20;
  let nBody = 0;
  let nClaim = 0;
  for (let i = 0; i < count; i++) {
    day += rng.int(4);
    if (i === 55) day += 12;
    if (i === 105) day += 24;
    const date = addDays(start, day);
    const createdAt = base + day * 86_400_000 + i * 1000;
    const id = `s${String(i).padStart(3, '0')}`;
    const roll = rng.next();
    let s: Session;
    if (roll < mix[0]) {
      const nEx = 2 + rng.int(4);
      const exercises: LiftSession['exercises'] = [];
      for (let e = 0; e < nEx; e++) {
        const name = rng.pick(liftNames);
        const key = name.trim().toLowerCase().replace(/\s+/g, ' ');
        const nSets = 1 + rng.int(5);
        const sets: LiftSet[] = [];
        const b = baseKg[key];
        for (let k = 0; k < nSets; k++) {
          const reps = rng.next() < 0.05 ? 0 : 1 + rng.int(12);
          let w = 0;
          if (b > 0) w = b + Math.round(i / 6) * 1.25 + (rng.int(5) - 2) * 2.5;
          else if (rng.next() < 0.2) w = 2.5 * (1 + rng.int(4));
          sets.push(set(reps, Math.max(0, w)));
        }
        exercises.push({ name, sets });
      }
      if (rng.next() < 0.08) exercises.push({ name: 'Plank', sets: [] });
      s = { id, discipline: 'lift', date, createdAt, source: 'manual', exercises };
      if (rng.next() < 0.6) s.durationSec = 1800 + rng.int(4500);
    } else if (roll < mix[1]) {
      const n = 2 + rng.int(5);
      const top = Math.min(9, 2 + Math.floor(i / 22));
      const climbs = [];
      for (let k = 0; k < n; k++) {
        const result = rng.pick<ClimbResult>(['flash', 'send', 'send', 'attempt']);
        climbs.push({ grade: -1 + rng.int(top + 2), result, count: rng.next() < 0.06 ? 0 : 1 + rng.int(5) });
      }
      s = { id, discipline: 'climb', date, createdAt, source: 'manual', climbs };
      if (rng.next() < 0.7) s.durationSec = 2400 + rng.int(6000);
    } else if (roll < mix[2]) {
      const distanceM = 2000 + rng.int(19000) + (rng.next() < 0.3 ? 0.5 : 0);
      s = { id, discipline: 'run', date, createdAt, source: 'manual', distanceM, elevationM: rng.next() < 0.3 ? 0 : rng.int(400) };
      if (rng.next() < 0.85) s.durationSec = Math.round((distanceM / 1000) * (270 + rng.int(120)));
    } else {
      const distanceM = 8000 + rng.int(112000);
      s = { id, discipline: 'ride', date, createdAt, source: 'manual', distanceM, elevationM: rng.int(1500) };
      if (rng.next() < 0.85) s.durationSec = Math.round((distanceM / 1000 / (18 + rng.int(15))) * 3600);
      if (rng.next() < 0.4) {
        s.source = 'strava';
        s.stravaId = 9_000_000_000 + i;
        s.title = `Ride ${i}`;
      }
    }
    if (rng.next() < 0.3) s.bonusPct = rng.pick([0.01, 0.03, 0.04, 0.08, 0.12]);
    if (rng.next() < 0.1) s.luckPct = 0.08;
    if (rng.next() < 0.1) s.notes = `note ${i}`;
    sessions.push(s);

    if (rng.next() < 0.3 && !claimed.has(`d:${date}:0`)) {
      claimed.add(`d:${date}:0`);
      claims.push({ id: `c${String(nClaim++).padStart(3, '0')}`, questId: `d:${date}:0`, xp: 150, claimedAt: createdAt + 400, date });
    }
    if (rng.next() < 0.12) {
      const q = `w:${weekKey(date)}:${rng.int(3)}`;
      if (!claimed.has(q)) {
        claimed.add(q);
        claims.push({ id: `c${String(nClaim++).padStart(3, '0')}`, questId: q, xp: [400, 500, 400][Number(q.slice(-1))], claimedAt: createdAt + 600, date });
      }
    }
    if (day - lastBodyDay >= 6 && rng.next() < 0.6) {
      lastBodyDay = day;
      const e: BodyEntry = { id: `b${String(nBody++).padStart(3, '0')}`, date, createdAt: createdAt + 800 };
      const kind = rng.int(5);
      if (kind !== 4) e.weightKg = Math.round((82 - nBody * 0.3 + rng.next()) * 10) / 10;
      if (kind === 1 || kind === 3) e.bodyFatPct = Math.round((19 - nBody * 0.1 + rng.next()) * 10) / 10;
      if (kind === 2 || kind === 3) e.photos = { front: `${e.id}-f`, side: `${e.id}-s`, back: `${e.id}-b` };
      if (kind === 4) e.photos = { front: `${e.id}-f` };
      if (rng.next() < 0.2) e.note = 'check-in';
      body.push(e);
    }
  }
  return { sessions, claims, body };
}

/** ~150 sessions over most of a year. */
const BIG = buildLog('parity-misc-v1', 150);
const LOGS: Record<string, Log> = { empty: EMPTY, first: FIRST, week: WEEK, split: SPLIT, big: BIG };

// ---------------------------------------------------------------------------
// States (stored once, referenced by key)
// ---------------------------------------------------------------------------

const STATES: Record<string, PlayerState> = {};

function reg(key: string, s: PlayerState): string {
  if (!STATES[key]) STATES[key] = s;
  return key;
}

/** Everything in the log logged strictly before time `t`. */
function cut(log: Log, t: number): Log {
  return { sessions: log.sessions.filter((x) => x.createdAt < t), claims: log.claims.filter((x) => x.claimedAt < t), body: log.body.filter((x) => x.createdAt < t) };
}
function D(log: Log, today: string, weeklyGoal = 3): PlayerState {
  return derive({ sessions: log.sessions, claims: log.claims, body: log.body, weeklyGoal, today });
}
function lastDate(log: Log, fallback: string): string {
  return log.sessions.length ? log.sessions[log.sessions.length - 1].date : fallback;
}

const sEmpty = reg('empty', D(EMPTY, '2026-03-02'));
const sFirst = reg('first', D(FIRST, '2026-03-02'));
const sWeek = reg('week', D(WEEK, '2026-03-14'));
const bigAt = (n: number): string => {
  const t = n >= BIG.sessions.length ? Infinity : BIG.sessions[n].createdAt;
  const part = cut(BIG, t);
  return reg(`big@${Math.min(n, BIG.sessions.length)}`, D(part, lastDate(part, '2025-09-01')));
};
const sBig40 = bigAt(40);
const sBig90 = bigAt(90);
const sBig = bigAt(BIG.sessions.length);

// ---------------------------------------------------------------------------
// quests
// ---------------------------------------------------------------------------

const quests: unknown[] = [];
function daily(date: string, state: string, log: string) {
  quests.push({ fn: 'daily', key: date, state, log, out: dailyQuests(date, STATES[state], LOGS[log].sessions, LOGS[log].claims) });
}
function weekly(wk: string, state: string, log: string, settings: Settings) {
  quests.push({ fn: 'weekly', key: wk, state, log, settings, out: weeklyQuests(wk, STATES[state], LOGS[log].sessions, LOGS[log].claims, settings) });
}
daily('2026-03-02', sEmpty, 'empty');
daily('2026-04-01', sEmpty, 'empty');
daily('2026-03-02', sFirst, 'first');
daily('2026-03-03', sFirst, 'first');
for (const date of ['2026-03-02', '2026-03-06', '2026-03-09', '2026-03-10', '2026-03-12', '2026-03-15']) daily(date, sWeek, 'week');
for (const i of [3, 20, 39]) daily(BIG.sessions[i].date, sBig40, 'big');
for (const i of [60, 89, 120]) daily(BIG.sessions[i].date, sBig90, 'big');
for (const i of [0, 12, 33, 57, 76, 101, 118, 133, 149]) daily(BIG.sessions[i].date, sBig, 'big');
daily(addDays(BIG.sessions[149].date, 1), sBig, 'big');
daily(addDays(BIG.sessions[149].date, 30), sBig, 'big');

weekly('2026-03-02', sEmpty, 'empty', KG);
weekly('2026-03-02', sFirst, 'first', KG);
weekly('2026-03-02', sFirst, 'first', { ...KG, weeklyGoal: 0 });
weekly('2026-03-02', sWeek, 'week', KG);
weekly('2026-03-09', sWeek, 'week', LB);
weekly('2026-03-16', sWeek, 'week', KG);
for (const i of [5, 30]) weekly(weekKey(BIG.sessions[i].date), sBig40, 'big', KG);
for (const i of [70, 110]) weekly(weekKey(BIG.sessions[i].date), sBig90, 'big', LB);
for (const i of [0, 22, 48, 64, 85, 99, 127, 140, 149]) weekly(weekKey(BIG.sessions[i].date), sBig, 'big', i % 2 ? LB : KG);
weekly(weekKey(addDays(BIG.sessions[149].date, 21)), sBig, 'big', { ...KG, weeklyGoal: 5 });

// ---------------------------------------------------------------------------
// diff
// ---------------------------------------------------------------------------

const diff: unknown[] = [];

function features(ev: ResultEvent[]): string[] {
  const f: string[] = [];
  for (const e of ev) {
    if (e.type === 'pr') f.push(`pr:${e.title.endsWith(' est. 1RM PR') ? 'e1rm' : e.title.endsWith(' PR') ? 'weight' : e.title}`);
    else if (e.type === 'boss') f.push(`boss:${e.defeated ? 'defeated' : 'hit'}:${e.weak ? 'weak' : 'plain'}`);
    else if (e.type === 'item') f.push(`item:${e.how}`);
    else if (e.type === 'levelup') f.push(`levelup:${e.track === 'hero' ? 'hero' : 'disc'}`);
    else if (e.type === 'xp') f.push(`xp:${e.discipline}`, e.prBonus > 0 ? 'xp:prBonus' : 'xp:plain', e.bonusPct > 0 ? 'xp:perk' : 'xp:noperk');
    else f.push(e.type);
  }
  const bosses = ev.filter((e) => e.type === 'boss').length;
  if (bosses > 1) f.push('boss:multi');
  return f;
}

function stepStates(log: Log, logKey: string, k: number): { before: string; after: string; session: Session } {
  const session = log.sessions[k];
  const before = cut(log, session.createdAt);
  const after: Log = { ...before, sessions: [...before.sessions, session] };
  return {
    before: reg(`${logKey}#${k}-`, D(before, session.date)),
    after: reg(`${logKey}#${k}+`, D(after, session.date)),
    session,
  };
}
function addStep(log: Log, logKey: string, k: number) {
  const st = stepStates(log, logKey, k);
  diff.push({ fn: 'states', before: st.before, after: st.after, session: st.session, out: diffStates(STATES[st.before], STATES[st.after], st.session) });
}

// Every step of the hand-written log (small states).
for (let k = 0; k < WEEK.sessions.length; k++) addStep(WEEK, 'week', k);

// From the big log: the steps that add event kinds not seen yet (greedy), up to 10.
{
  const seen = new Set<string>();
  for (const c of diff as { out: ResultEvent[] }[]) for (const f of features(c.out)) seen.add(f);
  const picked: number[] = [];
  for (let k = 1; k < BIG.sessions.length && picked.length < 10; k++) {
    const session = BIG.sessions[k];
    const before = cut(BIG, session.createdAt);
    const ev = diffStates(D(before, session.date), D({ ...before, sessions: [...before.sessions, session] }, session.date), session);
    const fresh = features(ev).filter((f) => !seen.has(f));
    if (fresh.length) {
      for (const f of fresh) seen.add(f);
      picked.push(k);
    }
  }
  for (const k of [...picked, BIG.sessions.length - 1]) addStep(BIG, 'big', k);
}

function addBulk(beforeKey: string, afterKey: string, sessions: Session[]) {
  diff.push({ fn: 'bulk', before: beforeKey, after: afterKey, sessions, out: diffBulk(STATES[beforeKey], STATES[afterKey], sessions) });
}
addBulk(sEmpty, sWeek, WEEK.sessions);
addBulk(sWeek, sWeek, []);
addBulk(sBig40, sBig90, BIG.sessions.slice(40, 90));
addBulk(reg('empty@big', D(EMPTY, lastDate(BIG, ''))), sBig, BIG.sessions);
addBulk(sFirst, reg('week@first-day', D(WEEK, '2026-03-02')), WEEK.sessions.slice(1));

function addBody(log: Log, logKey: string, entry: BodyEntry) {
  const before = cut(log, entry.createdAt);
  const after: Log = { ...before, body: [...before.body, entry] };
  const b = reg(`${logKey}~${entry.id}-`, D(before, entry.date));
  const a = reg(`${logKey}~${entry.id}+`, D(after, entry.date));
  diff.push({ fn: 'body', before: b, after: a, entry, out: diffBody(STATES[b], STATES[a], entry) });
}
addBody(EMPTY, 'empty', { id: 'e1', date: '2026-03-02', createdAt: T0, weightKg: 81.4 });
addBody(EMPTY, 'empty', { id: 'e2', date: '2026-03-02', createdAt: T0, weightKg: 81.4, bodyFatPct: 18.5, photos: { front: 'a', side: 'b', back: 'c' }, note: 'day one' });
addBody(WEEK, 'week', { id: 'e3', date: '2026-03-10', createdAt: T0 + 200 * 3_600_000, photos: { side: 'x' } });
{
  const full = BIG.body.find((e) => e.photos?.back && e.weightKg);
  const fat = BIG.body.find((e) => e.bodyFatPct && !e.photos);
  assert(full && fat, 'big log has no suitable body entries');
  addBody(BIG, 'big', BIG.body[0]);
  addBody(BIG, 'big', full);
  addBody(BIG, 'big', fat);
  addBody(BIG, 'big', BIG.body[BIG.body.length - 1]);
}

const totals = [sEmpty, sFirst, sWeek, sBig40, sBig].map((state) => ({ state, out: totalDisciplineXp(STATES[state]) }));

// ---------------------------------------------------------------------------
// nextup
// ---------------------------------------------------------------------------

const nextup = [sEmpty, sFirst, sWeek, sBig40, sBig90, sBig].map((state) => ({
  state,
  next3: nextGoals(STATES[state], 3),
  next4: nextGoals(STATES[state]),
  next9: nextGoals(STATES[state], 9),
  open: allOpenGoals(STATES[state]),
}));

// ---------------------------------------------------------------------------
// chatter
// ---------------------------------------------------------------------------

const chatter: unknown[] = [];
type CtxIn = Omit<ChatterCtx, 's'> & { s: string };
function line(expectStart: string, c: Partial<CtxIn> & { s: string; today: string }) {
  const s = STATES[c.s];
  const boss = c.boss ?? bossAt(s.campaign.index);
  const ctx: CtxIn = {
    s: c.s,
    today: c.today,
    daysSinceLast: c.daysSinceLast === undefined ? 1 : c.daysSinceLast,
    trainedToday: c.trainedToday ?? false,
    claimable: c.claimable ?? 0,
    boss,
    bossHpLeft: c.bossHpLeft ?? boss.hp,
  };
  if (c.nearest) ctx.nearest = c.nearest;
  const out = petLine({ ...ctx, s });
  assert(out.startsWith(expectStart), `chatter case expected "${expectStart}…" but got "${out}"`);
  chatter.push({ ctx, out });
}
const sOneMore = reg('week@one-more', D(cut(WEEK, WEEK.sessions[9].createdAt), '2026-03-10'));
assert(STATES[sOneMore].streak.goal - STATES[sOneMore].streak.thisWeek === 1, 'one-more state is not one session short');
const sGoalDone = reg('week@goal-done', D(WEEK, '2026-03-12'));
assert(STATES[sGoalDone].streak.thisWeek >= STATES[sGoalDone].streak.goal, 'goal-done state has not reached the goal');
const sQuiet = reg('week@quiet', D(WEEK, '2026-03-30'));
const near: NextGoal = nextGoals(STATES[sWeek], 1)[0];
assert(near, 'week state has no next goal');

line('Log your first session', { s: sEmpty, today: '2026-03-02', daysSinceLast: null });
line('Psst — 1 quest reward waiting', { s: sWeek, today: '2026-03-14', claimable: 1 });
line('Psst — 3 quest rewards waiting', { s: sBig, today: '2026-03-14', claimable: 3, daysSinceLast: 9 });
line('9 days since your last session', { s: sQuiet, today: '2026-03-30', daysSinceLast: 9 });
line('7 days since your last session', { s: sQuiet, today: '2026-03-30', daysSinceLast: 7, trainedToday: true });
line('4 days off', { s: sQuiet, today: '2026-03-30', daysSinceLast: 4 });
line('One more session', { s: sOneMore, today: '2026-03-10', daysSinceLast: 1 });
line('One more session', { s: sOneMore, today: '2026-03-10', daysSinceLast: null });
line('Iron Golem is nearly down — only 1,500 HP left!', { s: sQuiet, today: '2026-03-30', boss: bossAt(7), bossHpLeft: 1500 });
line('Snooze Button is nearly down — only 87 HP left!', { s: sQuiet, today: '2026-03-30', boss: bossAt(0), bossHpLeft: 87, trainedToday: true });
line('Echo of Doubt III is nearly down — only 9,500 HP left!', { s: sQuiet, today: '2026-03-30', boss: bossAt(26), bossHpLeft: 9500 });
line('So close to “', { s: sQuiet, today: '2026-03-30', nearest: { ...near, ratio: 0.8 } });
line('So close to “', { s: sGoalDone, today: '2026-03-12', nearest: { ...near, ratio: 0.93 }, trainedToday: true });
line('Weekly goal done', { s: sGoalDone, today: '2026-03-12', trainedToday: true, daysSinceLast: 0, nearest: { ...near, ratio: 0.79 } });
line('Nice work today', { s: sOneMore, today: '2026-03-10', trainedToday: true, daysSinceLast: 0 });
line('Nice work today', { s: sQuiet, today: '2026-03-30', trainedToday: true, daysSinceLast: 5 });
for (const i of [1, 2, 4, 6]) line(`${bossAt(i).name} hates`, { s: sQuiet, today: '2026-03-30', boss: bossAt(i) });
for (const today of ['2026-03-30', '2026-03-31', '2026-04-01', '2026-04-02', '2026-04-03', '2026-04-04', '2026-04-05', '2026-12-25']) {
  line('', { s: sQuiet, today, boss: bossAt(today < '2026-04-02' ? 0 : 23), bossHpLeft: 399 });
}

// ---------------------------------------------------------------------------
// funfacts (totals patched onto a small real state to reach the big scales)
// ---------------------------------------------------------------------------

function patched(key: string, base: PlayerState, totals: Partial<PlayerState['totals']>, totalDamage: number): string {
  const s: PlayerState = JSON.parse(JSON.stringify(base));
  Object.assign(s.totals, totals);
  s.campaign.totalDamage = totalDamage;
  return reg(key, s);
}
const sMega = patched('week*mega', STATES[sWeek], { liftVolumeKg: 12_345_678, climbSends: 3000, runDistanceM: 45_000_000, rideDistanceM: 3_500_000, runElevationM: 150_000, rideElevationM: 250_000.5, durationSec: 1_234_567 }, 1_234_567.5);
const sMid = patched('week*mid', STATES[sWeek], { liftVolumeKg: 455, climbSends: 1543, runDistanceM: 421_950, rideDistanceM: 1_700_000, runElevationM: 49.9, rideElevationM: 0, durationSec: 7200 }, 999.6);
const sEdge = patched('week*edge', STATES[sWeek], { liftVolumeKg: 44.775, climbSends: 25, runDistanceM: 399.9, rideDistanceM: 169_999, runElevationM: 2.5, rideElevationM: 2.5, durationSec: 7199 }, 1000);
const funfacts = [sEmpty, sFirst, sWeek, sBig40, sBig, sMega, sMid, sEdge].map((state) => ({ state, out: funFacts(STATES[state]) }));

// ---------------------------------------------------------------------------
// format
// ---------------------------------------------------------------------------

const fmt: { fn: string; args: unknown[]; out: unknown }[] = [];
/** Numbers with at most 15 significant digits read back as the same double in any JSON parser. */
function checkArgs(fn: string, args: unknown[]) {
  for (const a of args) {
    if (typeof a === 'number') assert(Number.isFinite(a) && Number(a.toPrecision(15)) === a, `${fn}: argument ${a} needs more than 15 digits`);
    else if (a && typeof a === 'object') checkArgs(fn, Object.values(a));
  }
}
function v(fn: string, args: unknown[], out: unknown) {
  checkArgs(fn, args);
  fmt.push({ fn, args, out });
}

for (const x of [0, 1, 2.5, 20, 61.25, 100, 102.5, 225, 1000.5, -5]) {
  for (const u of ['kg', 'lb'] as const) {
    v('kgToUnit', [x, u], F.kgToUnit(x, u));
    v('unitToKg', [x, u], F.unitToKg(x, u));
  }
  for (const u of ['km', 'mi'] as const) {
    v('mToUnit', [x * 100, u], F.mToUnit(x * 100, u));
    v('unitToM', [x, u], F.unitToM(x, u));
  }
}
for (const x of [0, 0.4, 0.5, 1.5, 2.5, 0.05, 0.25, 0.45, 1.005, 1.45, 2.675, 8.345, 12, 999.5, 999.95, 1000, 1234.5, 1234.5678, 12345.678, 999999.5, 1234567.891, 1e9, 123456789012, 1e15, 0.001, 0.0004, 0.0005, 0.00049, -0.4, -1.5, -2.5, -1234.5678, -0.0004, -1000000]) {
  v('fmtNum', [x], F.fmtNum(x));
  for (const d of [1, 2, 3]) v('fmtNum', [x, d], F.fmtNum(x, d));
}
for (const x of [0, 20, 62.5, 61.25, 41.25, 100, 102.5, 0.45359237, 45.359237, 1000, 1234.5, 99.95, 99.96, 0.04, 2267.96185]) {
  for (const u of ['kg', 'lb'] as const) {
    v('fmtWeight', [x, u], F.fmtWeight(x, u));
    v('fmtWeight', [x, u, 0], F.fmtWeight(x, u, 0));
    v('fmtWeight', [x, u, 2], F.fmtWeight(x, u, 2));
  }
}
for (const x of [0, 5, 49, 50, 999, 1000, 1050, 5234, 10000, 21097.5, 42195, 100000, 1609.344, 160934.4, 1234567, 8046.72]) {
  for (const u of ['km', 'mi'] as const) {
    v('fmtDistance', [x, u], F.fmtDistance(x, u));
    v('fmtDistance', [x, u, 0], F.fmtDistance(x, u, 0));
    v('fmtDistance', [x, u, 2], F.fmtDistance(x, u, 2));
  }
}
for (const x of [0, 0.4, 0.5, 1, 99.5, 304.8, 1000, 1234.5, 8849, 12345.6]) for (const u of ['km', 'mi'] as const) v('fmtElevation', [x, u], F.fmtElevation(x, u));
for (const x of [0, 0.4, 0.5, 1, 59, 59.5, 60, 61, 599, 600, 3599, 3599.5, 3600, 3661, 36000, 86399, 90061, 359999, 1234567]) v('fmtDuration', [x], F.fmtDuration(x));
for (const x of [0, 29, 30, 89, 90, 1770, 3569, 3570, 3600, 5400, 7170, 7200, 86400, 90000]) v('fmtDurationShort', [x], F.fmtDurationShort(x));
for (const x of [59.4, 240, 299.4, 299.5, 300, 312.3456, 359.7, 600, 3600.5]) for (const u of ['km', 'mi'] as const) v('fmtPace', [x, u], F.fmtPace(x, u));
for (const x of [0, 12.25, 12.35, 24.95, 25, 30.05, 32.18688, 16.09344, 100.449, 0.05]) for (const u of ['km', 'mi'] as const) v('fmtSpeed', [x, u], F.fmtSpeed(x, u));
for (const x of [0, 0.4, 999.5, 9999, 9999.4, 9999.5, 10000, 12345, 12350, 99950, 999999, 1000000, 1005000, 1234567, 12345678.9, 4535.9237, 453592.37, 123456789012]) for (const u of ['kg', 'lb'] as const) v('fmtBigKg', [x, u], F.fmtBigKg(x, u));
const durationInputs: [string | number, string | number, string | number][] = [
  [1, 2, 3], ['1', '30', '15'], ['', '45', ''], ['abc', '10', 'x'], [' 2 ', '0', '0.6'], ['1.5', '', ''], [0, 0, 0], [-1, 0, 0], ['1e1', 0, 0], [0, 90, 90], ['0', '0', '59.5'], ['.5', '5.', ''], ['-2', '30', '0'], ['12abc', '1', '1'], [0, 0, 0.4], ['+1', '+2', '+3'], ['1e', '2', '3'], ['1.2.3', '-', '+'], ['\t7\n', ' 8 ', '9 '], ['1e2', '1E1', '5e-1'], ['.', 'e5', '2.'], ['0x10', '0b101', '0o17'], ['0X1f', '-0x10', '0x'], ['0b12', '0o8', '0xg'],
];
for (const a of durationInputs) v('parseDurationInput', a, F.parseDurationInput(a[0], a[1], a[2]));
const goalValues: Record<ProgressUnit, number[]> = {
  count: [0, 3.7, 1234, 1234567.8],
  kg: [0, 62.5, 41.25, 9999, 10000, 50000, 1000000, 4535.9237, 4535.9],
  m: [0, 5000, 5234, 99999, 100000, 250000, 160934.4],
  elev: [0, 1000, 8849.4],
  level: [1, 12.9],
  grade: [-2, -1.5, -1, -0.5, 0, 4, 4.9, 17],
  weeks: [0, 8, 26.5],
  xp: [0, 999, 1000, 12345.6],
  min: [0, 45, 59.6, 60, 90, 600],
  ratio: [0, 1, 1.25, 1.005, 1.115, 2.675],
};
for (const unit of Object.keys(goalValues) as ProgressUnit[]) for (const n of goalValues[unit]) for (const st of BOTH) v('fmtGoalValue', [n, unit, st], F.fmtGoalValue(n, unit, st));
const progresses: [number, number, ProgressUnit][] = [
  [39000, 100000, 'm'], [150000, 100000, 'm'], [3, 4, 'grade'], [6, 4, 'grade'], [-2, 3, 'grade'], [12, 10, 'count'], [5000, 50000, 'kg'], [1.1, 1.5, 'ratio'], [45, 180, 'min'], [7, 10, 'level'], [3, 8, 'weeks'], [2500, 12000, 'xp'], [120, 1000, 'elev'],
];
for (const [cur, target, unit] of progresses) for (const st of BOTH) v('fmtProgress', [{ cur, target, unit }, st], F.fmtProgress({ cur, target, unit }, st));
for (const x of [0, 0.004, 0.005, 0.125, 0.5, 0.995, 1, 1.5, -0.25, 0.015, 0.285]) v('pct', [x], F.pct(x));

// ---------------------------------------------------------------------------
// summary
// ---------------------------------------------------------------------------

const summarySessions: Session[] = [
  ...WEEK.sessions,
  lift('x1', '2026-03-20', 400, [{ name: 'Squat', sets: Array.from({ length: 10 }, () => set(10, 140)) }], { durationSec: 5400 }),
  lift('x2', '2026-03-20', 401, []),
  lift('x3', '2026-03-20', 402, [], { durationSec: 1500 }),
  lift('x4', '2026-03-20', 403, [{ name: 'Leg Press', sets: Array.from({ length: 40 }, () => set(25, 1000)) }]),
  climb('x5', '2026-03-20', 404, [[0, 'send', 1]]),
  climb('x6', '2026-03-20', 405, [[6, 'attempt', 5]], { durationSec: 600 }),
  climb('x7', '2026-03-20', 406, [[-1, 'flash', 1], [-1, 'flash', 1]]),
  climb('x8', '2026-03-20', 407, []),
  cardio('x9', 'run', '2026-03-20', 408, 0, 0),
  cardio('x10', 'run', '2026-03-20', 409, 10000, 0, 2997),
  cardio('x11', 'ride', '2026-03-20', 410, 100000, 1524, 12345),
  cardio('x12', 'ride', '2026-03-20', 411, 16093.44, 0.4),
  BIG.sessions[10], BIG.sessions[50], BIG.sessions[100], BIG.sessions[140],
];
const summary: unknown[] = [];
for (const session of summarySessions) for (const settings of BOTH) summary.push({ session, settings, out: summarizeSession(session, settings) });

// ---------------------------------------------------------------------------
// liftHistory
// ---------------------------------------------------------------------------

const liftCases: unknown[] = [];
const SHORT_DEFAULTS = ['Squat', 'Overhead Press', 'Deadlift'];
for (const [log, exclude] of [['split', undefined], ['split', 'a2'], ['split', 'nope'], ['week', undefined], ['week', 'w10'], ['big', undefined], ['big', 's149'], ['empty', undefined]] as [string, string | undefined][]) {
  const sessions = LOGS[log].sessions;
  liftCases.push({ fn: 'lastPerformances', log, exclude: exclude ?? null, out: LH.lastPerformances(sessions, exclude) });
  for (const [dk, defaults] of [['short', SHORT_DEFAULTS], ['default', DEFAULT_EXERCISES]] as [string, string[]][]) {
    liftCases.push({ fn: 'exerciseSuggestions', log, defaults: dk, exclude: exclude ?? null, out: LH.exerciseSuggestions(sessions, defaults, exclude) });
  }
  for (const n of [1, 3, 6]) liftCases.push({ fn: 'recentWorkouts', log, n, exclude: exclude ?? null, out: LH.recentWorkouts(sessions, n, exclude) });
}
liftCases.push({ fn: 'recentWorkouts', log: 'big', n: null, exclude: null, out: LH.recentWorkouts(BIG.sessions) });

const prev = set(5, 100);
const compare: [LiftSet, LiftSet | undefined, boolean, number][] = [
  [set(5, 102.5), prev, true, 110], [set(6, 100), prev, true, 110], [set(5, 100), undefined, true, 110], [set(1, 112.5), prev, true, 110],
  [set(5, 100), prev, true, 110], [set(8, 90), prev, true, 110], [set(0, 200), prev, true, 110], [set(5, 50), undefined, false, 0],
  [set(5, 110), prev, true, 110], [set(5, 110.0000001), prev, true, 110], [set(5, 110.5), undefined, true, 110], [set(9, 0), set(8, 0), true, 0],
  [set(8, 0), set(8, 0), true, 0], [set(3, 20), set(8, 0), true, 0], [set(3, 20), undefined, false, 0], [set(5, 100.0000001), prev, true, 0], [set(-1, 100), prev, true, 0],
];
for (const [cur, p, had, best] of compare) liftCases.push({ fn: 'compareSet', cur, prev: p ?? null, hadHistory: had, best, out: LH.compareSet(cur, p, had, best) });

const steps: [number, number, 1 | -1, number?][] = [
  [61, 2.5, 1], [62.5, 2.5, 1], [62.5, 2.5, -1], [61, 2.5, -1], [0, 2.5, -1], [79.9, 0.1, 1], [0, 2.5, 1], [100, 5, 1], [100, 5, -1], [102.5, 5, 1], [102.5, 5, -1],
  [135, 10, 1], [137.5, 10, -1], [7, 1, 1], [7, 1, -1], [7.4, 1, 1], [7.4, 1, -1], [22.5, 2.5, -1, 20], [20, 2.5, -1, 20], [1, 2.5, -1, 1], [5, 1, -1, 1], [1, 1, -1, 1],
  [59.999999, 2.5, 1], [60.0000004, 2.5, 1], [60.0000004, 2.5, -1], [0.3, 0.1, 1], [0.3, 0.1, -1], [12.5, 1.25, 1], [8, 0.5, 1], [3, 5, 1], [3, 5, -1],
];
for (const a of steps) liftCases.push({ fn: 'stepValue', args: a, out: a.length === 4 ? LH.stepValue(a[0], a[1], a[2], a[3]) : LH.stepValue(a[0], a[1], a[2]) });

const setLists: LiftSet[][] = [
  [set(5, 100), set(5, 100), set(5, 100)],
  [set(5, 60), set(5, 60), set(4, 60)],
  [set(5, 120), set(3, 130), set(1, 140)],
  [set(8, 0), set(8, 0)],
  [set(8, 0), set(7, 0)],
  [],
  [set(0, 100), set(0, 50)],
  [set(5, 62.5)],
  [set(0, 200), set(5, 61.25), set(5, 61.25)],
  [set(10, 20), set(8, 22.5), set(6, 25), set(6, 25)],
  [set(5, 0), set(5, 10)],
  [set(5, 10), set(5, 0)],
  [set(3, 102.05), set(3, 102.05)],
  [set(12, 1000.5), set(1, 2267.96185)],
  [set(5, 41.25), set(5, 43.75), set(-2, 500)],
  [set(8, 100), set(8, 100.0000004)],
];
for (const sets of setLists) {
  liftCases.push({ fn: 'volumeKg', sets, out: LH.volumeKg(sets) });
  for (const unit of ['kg', 'lb'] as const) {
    liftCases.push({ fn: 'describeSets', sets, unit, out: LH.describeSets(sets, (kg) => F.fmtWeight(kg, unit)) });
    liftCases.push({ fn: 'topSetLabel', sets, unit, out: LH.topSetLabel(sets, (kg) => F.kgToUnit(kg, unit)) });
  }
}

// ---------------------------------------------------------------------------
// write
// ---------------------------------------------------------------------------

const groups: Record<string, unknown[]> = { quests, diff, totals, nextup, chatter, funfacts, fmt, summary, lift: liftCases };
const counts: Record<string, number> = {};
for (const [k, list] of Object.entries(groups)) counts[k] = list.length;

// One case per line: compact, but still readable in a diff.
const rows = (list: unknown[]) => `[\n${list.map((c) => JSON.stringify(c)).join(',\n')}\n]`;
const table = (t: Record<string, unknown>) => `{\n${Object.entries(t).map(([k, val]) => `${JSON.stringify(k)}:${JSON.stringify(val)}`).join(',\n')}\n}`;
const meta = { generator: 'tests/parity/gen_misc.ts', counts, states: Object.keys(STATES).length, bigLog: { sessions: BIG.sessions.length, claims: BIG.claims.length, body: BIG.body.length } };
const text = `{\n"meta":${JSON.stringify(meta)},\n"logs":${table(LOGS)},\n"states":${table(STATES)},\n${Object.entries(groups).map(([k, list]) => `${JSON.stringify(k)}:${rows(list)}`).join(',\n')}\n}\n`;
JSON.parse(text); // must be valid JSON
writeFileSync(OUT_FILE, text);

const total = Object.values(counts).reduce((a, n) => a + n, 0);
console.log(`wrote ${OUT_FILE}`);
console.log(`${(text.length / 1024).toFixed(0)} KB, ${total} cases, ${Object.keys(STATES).length} states`);
console.log(counts);
const kinds = new Set<string>();
for (const c of diff as { out?: ResultEvent[] }[]) for (const f of features(c.out ?? [])) kinds.add(f);
console.log('diff coverage:', [...kinds].sort().join(' '));
console.log('quest titles:', [...new Set((quests as { out: { title: string }[] }[]).flatMap((c) => c.out.map((q) => q.title)))].join(' | '));
