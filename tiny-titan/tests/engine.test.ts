import { describe, it, expect } from 'vitest';
import type { ClimbSession, LiftSession, CardioSession, Session } from '../src/game/types';
import { baseSessionXp, heroLevel, discLevel, heroXpForLevel, climbGradeXp, e1rm, sessionStats } from '../src/game/xp';
import { derive, computeStreak, computeTitle } from '../src/game/derive';
import { diffStates } from '../src/game/diff';
import { dailyQuests, weeklyQuests } from '../src/game/quests';
import { weekKey, addDays, weekdayIndex } from '../src/game/dates';
import { ITEMS } from '../src/game/items';
import { PETS } from '../src/game/pets';
import { ACHIEVEMENTS } from '../src/game/achievements';
import { DEFAULT_SETTINGS } from '../src/game/types';
import { makeRng } from '../src/game/rng';
import { BOSS_BY_ID } from '../src/game/campaign';

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

const D = (sessions: Session[], claims = [], today = '2026-03-08') =>
  derive({ sessions, claims, weeklyGoal: 3, today });

/** Hero XP that came from achievements and boss kills rather than sessions. */
const bonusXp = (s: ReturnType<typeof D>) =>
  ACHIEVEMENTS.reduce((a, x) => a + (s.achievements[x.id] ? x.xp : 0), 0) +
  Object.keys(s.campaign.defeated).reduce((a, id) => a + (BOSS_BY_ID[id]?.xp ?? 0), 0);

describe('xp formulas', () => {
  it('scores a lifting session from volume, reps and sets', () => {
    const { xp, parts } = baseSessionXp(lift());
    // volume 2200kg → 220, 25 weighted reps → 25, 10 bw reps → 30, 6 sets → 30, 60 min → 120
    expect(xp).toBe(425);
    expect(parts.length).toBe(5);
  });
  it('scores climbing by grade and result', () => {
    const { xp } = baseSessionXp(climb());
    const expected = 3 * climbGradeXp(2) * 1.3 + 2 * climbGradeXp(3) + 4 * climbGradeXp(5) * 0.35;
    expect(xp).toBe(Math.round(expected));
  });
  it('balances run and ride to roughly ~1000 xp per hour', () => {
    expect(baseSessionXp(run()).xp).toBeGreaterThan(900);
    expect(baseSessionXp(run()).xp).toBeLessThan(1400);
    expect(baseSessionXp(ride()).xp).toBeGreaterThan(1200);
    expect(baseSessionXp(ride()).xp).toBeLessThan(2000);
  });
  it('level curves are monotonic and start fast', () => {
    expect(heroLevel(0).level).toBe(1);
    expect(heroLevel(heroXpForLevel(1)).level).toBe(2);
    expect(heroLevel(1500).level).toBeGreaterThanOrEqual(3);
    let prev = 0;
    for (let l = 1; l < 99; l++) {
      expect(heroXpForLevel(l)).toBeGreaterThan(prev);
      prev = heroXpForLevel(l);
    }
    expect(discLevel(100000).level).toBeLessThan(99);
    expect(heroLevel(1e9).level).toBe(99);
  });
  it('estimates 1RM', () => {
    expect(e1rm(100, 1)).toBe(100);
    expect(e1rm(100, 5)).toBeCloseTo(116.67, 1);
  });
  it('computes pace and speed', () => {
    const st = sessionStats(run());
    expect(st.paceSecPerKm).toBe(300);
    expect(st.speedKmh).toBe(12);
  });
});

describe('derive', () => {
  it('starts with starter kit and nothing else', () => {
    const s = D([]);
    expect(Object.keys(s.items).sort()).toEqual(['shorts_navy', 'tee_grey', 'trainers_worn']);
    expect(s.totals.sessions).toBe(0);
    expect(s.title).toBe('Scrawny Newcomer');
    expect(s.levels.hero.level).toBe(1);
  });

  it('unlocks first-session achievements and pets', () => {
    const s = D([lift()]);
    expect(s.achievements.first_session).toBeTruthy();
    expect(s.achievements.first_lift).toBeTruthy();
    expect(s.pets.slime).toBeTruthy();
    expect(s.pets.bulldog).toBeTruthy();
    expect(s.sessionXp.l1).toBe(425);
    expect(s.xp.lift).toBe(425);
    // One Plate + Two Plates come from the 80 kg bench and 100 kg squat.
    expect(s.achievements.lift_60).toBeTruthy();
    expect(s.achievements.lift_100).toBeTruthy();
    expect(s.xp.hero).toBe(425 + bonusXp(s));
    expect(s.levels.hero.level).toBeGreaterThanOrEqual(2);
    expect(s.title).toMatch(/Lifter$/);
  });

  it('awards PR bonuses only when a previous record exists', () => {
    const first = lift();
    const second = lift({
      id: 'l2',
      date: '2026-03-09',
      createdAt: 10,
      exercises: [{ name: 'bench press', sets: [{ reps: 5, weightKg: 85 }] }],
    });
    const s = D([first, second]);
    expect(s.prs.lifts['bench press'].weightKg).toBe(85);
    const base = baseSessionXp(second).xp;
    expect(s.sessionXp.l2).toBe(base + 150);
  });

  it('tracks climbing PRs and grade achievements', () => {
    const s = D([climb()]);
    expect(s.prs.climbMaxSend).toBe(3);
    expect(s.prs.climbMaxFlash).toBe(2);
    expect(s.achievements.climb_v2).toBeTruthy();
    expect(s.items.chalk_bag).toBeTruthy();
    expect(s.items.sendy_tank).toBeTruthy();
    const s2 = D([climb(), climb({ id: 'c2', createdAt: 5, date: '2026-03-10', climbs: [{ grade: 6, result: 'send', count: 1 }] })]);
    expect(s2.sessionXp.c2).toBe(climbGradeXp(6) + 200);
    expect(s2.achievements.climb_v6).toBeTruthy();
    expect(s2.items.crimp_gauntlets).toBeTruthy();
  });

  it('tracks cardio PRs, pace and item unlocks', () => {
    const s = D([run(), ride()]);
    expect(s.prs.longestRunM).toBe(10000);
    expect(s.prs.bestPaceSecPerKm).toBe(300);
    expect(s.achievements.run_10k).toBeTruthy();
    expect(s.achievements.run_pace_5).toBeTruthy();
    expect(s.achievements.ride_25).toBeTruthy();
    expect(s.items.race_bib).toBeTruthy();
    expect(s.items.sweatband).toBeTruthy();
    expect(s.items.bike_helmet).toBeTruthy();
    expect(s.pets.pigeon).toBeTruthy();
    expect(s.pets.hamster).toBeTruthy();
  });

  it('is deterministic (loot replays identically)', () => {
    const sessions = [lift(), climb(), run(), ride()];
    const a = D(sessions);
    const b = D([...sessions].reverse());
    expect(Object.keys(a.items).sort()).toEqual(Object.keys(b.items).sort());
    expect(a.xp).toEqual(b.xp);
  });

  it('eventually drops loot thanks to pity', () => {
    const sessions: Session[] = [];
    for (let i = 0; i < 8; i++) sessions.push(lift({ id: `p${i}`, createdAt: i + 1, date: addDays('2026-03-02', i) }));
    const s = D(sessions);
    const drops = Object.values(s.items).filter((i) => i.how === 'drop');
    expect(drops.length).toBeGreaterThanOrEqual(2);
  });

  it('applies perk bonus snapshots', () => {
    const s = D([lift({ bonusPct: 0.1 })]);
    expect(s.sessionXp.l1).toBe(Math.round(425 * 1.1));
  });

  it('counts quest claims towards hero xp only', () => {
    const s = derive({
      sessions: [lift()],
      claims: [{ id: 'q1', questId: 'd:2026-03-02:0', xp: 150, claimedAt: 50, date: '2026-03-02' }],
      weeklyGoal: 3,
      today: '2026-03-08',
    });
    expect(s.xp.hero).toBe(425 + bonusXp(s) + 150);
    expect(s.xp.lift).toBe(425);
  });

  it('all four disciplines unlocks the all-rounder title', () => {
    const s = D([lift(), climb(), run(), ride()]);
    expect(s.achievements.all_four).toBeTruthy();
    expect(computeTitle(s).title).toMatch(/All-Rounder|Rider|Runner/);
  });
});

describe('streaks and weeks', () => {
  it('computes monday week keys', () => {
    expect(weekKey('2026-03-04')).toBe('2026-03-02'); // Wednesday → Monday
    expect(weekKey('2026-03-02')).toBe('2026-03-02');
    expect(weekKey('2026-03-08')).toBe('2026-03-02'); // Sunday still same week
    expect(weekdayIndex('2026-03-07')).toBe(5); // Saturday
  });
  it('keeps the streak alive during the current week', () => {
    const counts = { '2026-02-16': 3, '2026-02-23': 4, '2026-03-02': 1 };
    const st = computeStreak(counts, 3, '2026-03-02');
    expect(st.current).toBe(2);
    expect(st.thisWeek).toBe(1);
    expect(st.best).toBe(2);
    const st2 = computeStreak({ ...counts, '2026-03-02': 3 }, 3, '2026-03-02');
    expect(st2.current).toBe(3);
  });
  it('breaks the streak after a missed week', () => {
    const counts = { '2026-02-02': 3, '2026-02-09': 3, '2026-02-23': 3 };
    const st = computeStreak(counts, 3, '2026-02-23');
    expect(st.current).toBe(1);
    expect(st.best).toBe(2);
  });
});

describe('diff', () => {
  it('produces a results reel for a new session', () => {
    const before = D([]);
    const after = D([lift()]);
    const ev = diffStates(before, after, lift());
    const types = ev.map((e) => e.type);
    expect(types[0]).toBe('xp');
    expect(types).toContain('levelup');
    expect(types).toContain('achievement');
    expect(types).toContain('pet');
    const xp = ev[0];
    if (xp.type === 'xp') {
      expect(xp.amount).toBe(425);
      expect(xp.hero.after.level).toBeGreaterThan(xp.hero.before.level);
    }
  });
  it('reports PRs', () => {
    const s1 = [lift()];
    const l2 = lift({ id: 'l2', createdAt: 9, date: '2026-03-09', exercises: [{ name: 'Squat', sets: [{ reps: 3, weightKg: 110 }] }] });
    const ev = diffStates(D(s1), D([...s1, l2]), l2);
    const pr = ev.find((e) => e.type === 'pr');
    expect(pr && pr.type === 'pr' && pr.title).toBe('Squat PR');
  });
});

describe('quests', () => {
  it('generates three daily and three weekly quests with progress', () => {
    const sessions = [lift(), lift({ id: 'l2', createdAt: 6, date: '2026-03-02' })];
    const s = D(sessions);
    const daily = dailyQuests('2026-03-02', s, sessions, []);
    expect(daily.length).toBe(3);
    expect(daily[0].progress).toBe(2);
    expect(daily[0].done).toBe(true);
    expect(daily[0].claimed).toBe(false);
    const weekly = weeklyQuests('2026-03-02', s, sessions, [], DEFAULT_SETTINGS);
    expect(weekly.length).toBe(3);
    expect(weekly[0].progress).toBe(1);
    expect(weekly[1].progress).toBe(850);
  });
  it('is stable for the same date', () => {
    const s = D([lift(), climb()]);
    const a = dailyQuests('2026-04-01', s, [], []).map((q) => q.title);
    const b = dailyQuests('2026-04-01', s, [], []).map((q) => q.title);
    expect(a).toEqual(b);
  });
});

describe('catalog sanity', () => {
  it('has unique ids', () => {
    const ids = (xs: { id: string }[]) => new Set(xs.map((x) => x.id)).size === xs.length;
    expect(ids(ITEMS)).toBe(true);
    expect(ids(PETS)).toBe(true);
    expect(ids(ACHIEVEMENTS)).toBe(true);
  });
  it('rng is deterministic', () => {
    const a = makeRng('x');
    const b = makeRng('x');
    expect([a.next(), a.next()]).toEqual([b.next(), b.next()]);
  });
});
