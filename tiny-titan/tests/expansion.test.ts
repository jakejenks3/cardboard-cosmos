import { describe, it, expect } from 'vitest';
import type { BodyEntry, CardioSession, ClimbSession, LiftSession, Session } from '../src/game/types';
import { DEFAULT_SETTINGS } from '../src/game/types';
import { baseSessionXp, rankForLevel, RANKS } from '../src/game/xp';
import { derive, bodyEntryReward, BODY_XP } from '../src/game/derive';
import { diffStates, diffBody, diffBulk } from '../src/game/diff';
import { BOSSES, bossAt, ZONES, bossesInZone } from '../src/game/campaign';
import { ACHIEVEMENTS, tierOf } from '../src/game/achievements';
import { ITEMS, unlockProgress } from '../src/game/items';
import { PETS } from '../src/game/pets';
import { nextGoals, allOpenGoals } from '../src/game/nextup';
import { progressRatio } from '../src/game/goals';
import { weeklyQuests } from '../src/game/quests';
import { addDays } from '../src/game/dates';
import { fmtGoalValue, fmtProgress } from '../src/game/format';

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
  climbs: [{ grade: 2, result: 'flash', count: 3 }, { grade: 3, result: 'send', count: 2 }],
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

const D = (sessions: Session[], bodyEntries: BodyEntry[] = [], today = '2026-03-08') => derive({ sessions, claims: [], body: bodyEntries, weeklyGoal: 3, today });

describe('campaign', () => {
  it('has four bosses per zone and a reward item on every zone boss', () => {
    expect(BOSSES.length).toBe(ZONES.length * 4);
    ZONES.forEach((_, z) => {
      const list = bossesInZone(z);
      expect(list.length).toBe(4);
      expect(list[3].boss.zoneBoss).toBe(true);
      expect(ITEMS.some((i) => i.id === list[3].boss.rewardItem)).toBe(true);
    });
  });

  it('the first session defeats the Snooze Button and overkill carries over', () => {
    const s = D([lift()]); // 425 XP vs 400 HP
    expect(s.campaign.index).toBe(1);
    expect(s.campaign.damage).toBe(25);
    expect(s.campaign.totalDamage).toBe(425);
    expect(s.campaign.defeated.snooze_button).toBeTruthy();
    expect(s.achievements.boss_first).toBeTruthy();
  });

  it('multiplies damage against a boss weak to the session discipline', () => {
    const r = run();
    expect(baseSessionXp(r).xp).toBe(1196);
    const s = D([r]);
    // 400 kills Snooze; the remaining 796 ×1.5 = 1194 kills Couch Potato (900, weak to running)
    // using 600 of the pool; the last 196 lands on the Elevator Imp at ×1.
    expect(s.campaign.index).toBe(2);
    expect(s.campaign.damage).toBe(196);
    expect(s.sessionDamage.r1).toBe(400 + 900 + 196);
  });

  it('awards the zone trophy and achievement when a zone is cleared', () => {
    const sessions: Session[] = [];
    for (let i = 0; i < 6; i++) sessions.push(ride({ id: `ride${i}`, createdAt: i + 1, date: addDays('2026-03-02', i) }));
    const s = D(sessions);
    expect(s.campaign.index).toBeGreaterThanOrEqual(4);
    expect(s.campaign.defeated.sunday_scaries).toBeTruthy();
    expect(s.items.comfy_slippers?.how).toBe('unlock');
    expect(s.achievements.zone_1).toBeTruthy();
    expect(s.chronicle.some((e) => e.kind === 'boss' && e.ref === 'sunday_scaries')).toBe(true);
  });

  it('continues with endless echoes after the final boss', () => {
    const echo = bossAt(BOSSES.length);
    expect(echo.id).toBe('echo_1');
    expect(bossAt(BOSSES.length + 3).hp).toBeGreaterThan(echo.hp);
  });

  it('reports boss damage in the results reel', () => {
    const before = D([]);
    const after = D([climb()]);
    const ev = diffStates(before, after, climb());
    const bosses = ev.filter((e) => e.type === 'boss');
    expect(bosses.length).toBeGreaterThanOrEqual(1);
    const first = bosses[0];
    if (first.type === 'boss') {
      expect(first.index).toBe(0);
      expect(first.hpBefore).toBe(400);
    }
    const total = bosses.reduce((a, e) => a + (e.type === 'boss' ? e.damage : 0), 0);
    expect(total).toBe(after.sessionDamage.c1);
  });
});

describe('body check-ins', () => {
  it('pays each weekly component once', () => {
    expect(bodyEntryReward(0, { weightKg: 80 }).xp).toBe(BODY_XP.weight);
    const first = bodyEntryReward(0, { weightKg: 80 });
    const second = bodyEntryReward(first.flags, { weightKg: 79.5, photos: { front: 'a', side: 'b', back: 'c' } });
    expect(second.xp).toBe(BODY_XP.photo * 3);
    expect(bodyEntryReward(second.flags, { weightKg: 79, bodyFatPct: 18 }).xp).toBe(BODY_XP.bodyFat);
  });

  it('tracks weight, body fat, photos and credits hero XP only', () => {
    const entries = [
      body(),
      body({ id: 'w2', createdAt: 101, date: '2026-03-04', weightKg: 79.4, bodyFatPct: 18, photos: { front: 'p1', side: 'p2', back: 'p3' } }),
    ];
    const s = D([], entries);
    expect(s.body.entries).toBe(2);
    expect(s.body.firstWeightKg).toBe(80);
    expect(s.body.latestWeightKg).toBe(79.4);
    expect(s.body.latestBodyFat).toBe(18);
    expect(s.body.fullSets).toBe(1);
    expect(s.bodyXp.w1).toBe(60);
    expect(s.bodyXp.w2).toBe(20 + 45);
    expect(s.achievements.body_first).toBeTruthy();
    expect(s.achievements.body_photos).toBeTruthy();
    expect(s.achievements.body_bf).toBeTruthy();
    expect(s.xp.lift + s.xp.climb + s.xp.run + s.xp.ride).toBe(0);
    expect(s.xp.hero).toBeGreaterThan(60 + 65);
    expect(s.campaign.totalDamage).toBe(0);
  });

  it('unlocks bodyweight-relative strength goals once a weight is logged', () => {
    const noWeight = D([lift()]);
    expect(noWeight.bests.benchRatio).toBe(0);
    const s = D([lift()], [body({ weightKg: 80, createdAt: 0 })]);
    expect(s.bests.benchRatio).toBeCloseTo(1);
    expect(s.bests.squatRatio).toBeCloseTo(1.25);
    expect(s.achievements.rel_bench_1).toBeTruthy();
    expect(s.achievements.rel_squat_15).toBeFalsy();
    // Logging the weight after the lift works too.
    const later = D([lift()], [body({ weightKg: 80, createdAt: 500 })]);
    expect(later.achievements.rel_bench_1).toBeTruthy();
  });

  it('counts consecutive weekly check-ins and rewards the streak', () => {
    const entries = [0, 7, 14, 21].map((d, i) => body({ id: `w${i}`, createdAt: 100 + i, date: addDays('2026-03-02', d) }));
    const s = D([], entries, '2026-03-24');
    expect(s.body.bestStreak).toBe(4);
    expect(s.body.streak).toBe(4);
    expect(s.achievements.body_streak_4).toBeTruthy();
    expect(s.pets.sprout).toBeTruthy();
  });

  it('adds a weekly check-in quest only for players who track their body', () => {
    const none = D([lift()]);
    expect(weeklyQuests('2026-03-02', none, [lift()], [], DEFAULT_SETTINGS).length).toBe(3);
    const withBody = D([lift()], [body()]);
    const quests = weeklyQuests('2026-03-02', withBody, [lift()], [], DEFAULT_SETTINGS);
    expect(quests.length).toBe(4);
    expect(quests[3].done).toBe(true);
  });

  it('produces a results reel for a check-in', () => {
    const e = body({ photos: { front: 'a', side: 'b', back: 'c' } });
    const ev = diffBody(D([]), D([], [e]), e);
    expect(ev[0]).toMatchObject({ type: 'bodyxp', amount: 60 + 45 });
    expect(ev.some((x) => x.type === 'achievement' && x.id === 'body_photos')).toBe(true);
  });
});

describe('ranks, goals and chronicle', () => {
  it('maps levels to ranks', () => {
    expect(rankForLevel(1)).toBe(0);
    expect(rankForLevel(5)).toBe(1);
    expect(rankForLevel(49)).toBe(6);
    expect(RANKS[rankForLevel(60)].name).toBe('Legend');
  });

  it('ranks up a discipline and records it', () => {
    const sessions: Session[] = [];
    for (let i = 0; i < 10; i++) sessions.push(ride({ id: `ride${i}`, createdAt: i + 1, date: addDays('2026-03-02', i) }));
    const s = D(sessions);
    expect(s.levels.ride.level).toBeGreaterThanOrEqual(5);
    expect(s.ranks.ride).toBeGreaterThanOrEqual(1);
    expect(s.ranks.lift).toBe(0);
    expect(s.chronicle.some((e) => e.kind === 'rank' && e.discipline === 'ride')).toBe(true);
    const before = D(sessions.slice(0, 1));
    expect(diffBulk(before, s, sessions.slice(1)).some((e) => e.type === 'rank')).toBe(true);
  });

  it('keeps every progress bar consistent with its unlock check', () => {
    const states = [D([]), D([lift()]), D([lift(), climb(), run(), ride()], [body()])];
    for (const s of states) {
      for (const a of ACHIEVEMENTS) {
        if (!a.progress) continue;
        const p = a.progress(s);
        expect(a.check(s), a.id).toBe(p.cur >= p.target);
      }
      for (const pet of PETS) {
        const p = pet.progress!(s);
        expect(pet.check(s), pet.id).toBe(p.cur >= p.target);
      }
    }
  });

  it('gives every unlockable item a hint and most of them progress', () => {
    const s = D([lift()]);
    const unlocks = ITEMS.filter((i) => i.unlock.kind === 'unlock');
    expect(unlocks.length).toBeGreaterThan(30);
    for (const it of unlocks) expect(unlockProgress(it, s), it.id).not.toBeNull();
  });

  it('surfaces the nearest goals', () => {
    const s = D([lift(), climb(), run(), ride()]);
    const goals = nextGoals(s, 4);
    expect(goals.length).toBe(4);
    for (let i = 1; i < goals.length; i++) expect(goals[i - 1].ratio).toBeGreaterThanOrEqual(goals[i].ratio);
    for (const g of goals) {
      expect(g.ratio).toBeGreaterThan(0);
      expect(g.ratio).toBeLessThan(1);
    }
    expect(allOpenGoals(s).every((g) => !s.achievements[g.key.slice(2)] || !g.key.startsWith('a:'))).toBe(true);
  });

  it('writes a chronicle that starts with the beginning', () => {
    const s = D([lift(), climb()]);
    expect(s.chronicle[0].kind).toBe('start');
    const kinds = new Set(s.chronicle.map((e) => e.kind));
    expect(kinds.has('achievement')).toBe(true);
    expect(kinds.has('pet')).toBe(true);
    expect(kinds.has('boss')).toBe(true);
  });

  it('tracks variety and monthly bests', () => {
    const s = D([lift(), climb(), run(), ride()]);
    expect(s.bests.weekDisciplines).toBe(4);
    expect(s.achievements.week_4_disc).toBeTruthy();
    expect(s.bests.monthSessions).toBe(4);
    const gap = D([lift(), lift({ id: 'l2', createdAt: 9, date: '2026-03-20' })]);
    expect(gap.bests.gapDays).toBe(18);
    expect(gap.achievements.comeback).toBeTruthy();
  });

  it('assigns tiers and formats goal values', () => {
    const tiers = new Set(ACHIEVEMENTS.map(tierOf));
    expect(tiers.size).toBe(4);
    expect(fmtGoalValue(4, 'grade', DEFAULT_SETTINGS)).toBe('V4');
    expect(fmtGoalValue(-2, 'grade', DEFAULT_SETTINGS)).toBe('—');
    expect(fmtGoalValue(1.25, 'ratio', DEFAULT_SETTINGS)).toBe('1.25×');
    expect(fmtProgress({ cur: 39000, target: 100000, unit: 'm' }, DEFAULT_SETTINGS)).toBe('39 km / 100 km');
    expect(progressRatio({ cur: 2, target: 4, unit: 'grade' })).toBeCloseTo(4 / 6);
  });
});
