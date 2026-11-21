import { describe, it, expect } from 'vitest';
import type { LiftSession, Session } from '../src/game/types';
import { weightStepOf } from '../src/game/types';
import { compareSet, describeSets, exerciseSuggestions, lastPerformances, recentWorkouts, stepValue, topSetLabel, volumeKg } from '../src/game/liftHistory';

const lift = (id: string, date: string, createdAt: number, exercises: LiftSession['exercises']): LiftSession => ({ id, discipline: 'lift', date, createdAt, source: 'manual', exercises });
const set = (reps: number, weightKg: number) => ({ reps, weightKg });

const A1 = lift('a1', '2026-03-02', 1, [
  { name: 'Squat', sets: [set(5, 100), set(5, 100), set(5, 100)] },
  { name: 'Bench Press', sets: [set(5, 60), set(5, 60), set(4, 60)] },
]);
const B1 = lift('b1', '2026-03-04', 2, [
  { name: 'Deadlift', sets: [set(5, 120), set(3, 130), set(1, 140)] },
  { name: 'Pull-up', sets: [set(8, 0), set(7, 0)] },
]);
const A2 = lift('a2', '2026-03-09', 3, [
  { name: 'squat ', sets: [set(5, 105), set(5, 105)] },
  { name: 'Bench Press', sets: [set(5, 62.5)] },
]);
const run: Session = { id: 'r', discipline: 'run', date: '2026-03-10', createdAt: 4, source: 'manual', distanceM: 5000, elevationM: 0 };
const empty = lift('s', '2026-03-11', 5, []); // e.g. a duration-only Strava import
const all: Session[] = [A1, B1, A2, run, empty];

describe('last performance', () => {
  it('returns the most recent sets per exercise, ignoring case and spacing', () => {
    const last = lastPerformances(all);
    expect(last.squat.sets).toEqual([set(5, 105), set(5, 105)]);
    expect(last.squat.date).toBe('2026-03-09');
    expect(last['bench press'].sets).toEqual([set(5, 62.5)]);
    expect(last.deadlift.sessionId).toBe('b1');
    expect(last['pull-up'].sets.length).toBe(2);
  });
  it('can exclude the session being edited', () => {
    expect(lastPerformances(all, 'a2').squat.sets[0].weightKg).toBe(100);
  });
  it('skips sets with no reps', () => {
    const s = lift('z', '2026-04-01', 9, [{ name: 'Squat', sets: [set(0, 200)] }]);
    expect(lastPerformances([A1, s]).squat.sets[0].weightKg).toBe(100);
  });
});

describe('exercise suggestions', () => {
  it('lists your exercises by recency, then defaults you have not done', () => {
    const sug = exerciseSuggestions(all, ['Squat', 'Overhead Press', 'Deadlift']);
    expect(sug.slice(0, 4).map((s) => s.key)).toEqual(['bench press', 'squat', 'deadlift', 'pull-up']);
    expect(sug[1].count).toBe(2);
    expect(sug[4]).toMatchObject({ key: 'overhead press', count: 0 });
    expect(sug.length).toBe(5);
    expect(sug[1].last?.sets[0].weightKg).toBe(105);
  });
});

describe('recent workouts', () => {
  it('returns distinct line-ups so A/B splits each appear once', () => {
    const recent = recentWorkouts(all, 3);
    expect(recent.map((s) => s.id)).toEqual(['a2', 'b1']);
  });
});

describe('set comparison', () => {
  const prev = set(5, 100);
  it('flags more weight, more reps, extra sets and PRs', () => {
    expect(compareSet({ reps: 5, weightKg: 102.5 }, prev, true, 110)).toEqual({ kind: 'weight', deltaKg: 2.5 });
    expect(compareSet({ reps: 6, weightKg: 100 }, prev, true, 110)).toEqual({ kind: 'reps', delta: 1 });
    expect(compareSet({ reps: 5, weightKg: 100 }, undefined, true, 110)).toEqual({ kind: 'extra' });
    expect(compareSet({ reps: 1, weightKg: 112.5 }, prev, true, 110)).toEqual({ kind: 'pr' });
  });
  it('stays quiet when equal, lower, empty or brand new', () => {
    expect(compareSet({ reps: 5, weightKg: 100 }, prev, true, 110)).toBeNull();
    expect(compareSet({ reps: 8, weightKg: 90 }, prev, true, 110)).toBeNull();
    expect(compareSet({ reps: 0, weightKg: 200 }, prev, true, 110)).toBeNull();
    expect(compareSet({ reps: 5, weightKg: 50 }, undefined, false, 0)).toBeNull();
  });
});

describe('stepping', () => {
  it('snaps to plate increments', () => {
    expect(stepValue(61, 2.5, 1)).toBe(62.5);
    expect(stepValue(62.5, 2.5, 1)).toBe(65);
    expect(stepValue(62.5, 2.5, -1)).toBe(60);
    expect(stepValue(61, 2.5, -1)).toBe(60);
    expect(stepValue(0, 2.5, -1)).toBe(0);
    expect(stepValue(79.9, 0.1, 1)).toBeCloseTo(80, 5);
  });
  it('picks a sensible default step per unit', () => {
    expect(weightStepOf({ weightUnit: 'kg' })).toBe(2.5);
    expect(weightStepOf({ weightUnit: 'lb' })).toBe(5);
    expect(weightStepOf({ weightUnit: 'kg', weightStep: 1 })).toBe(1);
    expect(weightStepOf({ weightUnit: 'lb', weightStep: 1 })).toBe(5); // 1 is not a lb option
  });
});

describe('descriptions', () => {
  const kg = (n: number) => `${n} kg`;
  it('summarises sets compactly', () => {
    expect(describeSets([set(5, 100), set(5, 100), set(5, 100)], kg)).toBe('3×5 @ 100 kg');
    expect(describeSets([set(5, 60), set(5, 60), set(4, 60)], kg)).toBe('5, 5, 4 @ 60 kg');
    expect(describeSets([set(5, 120), set(3, 130), set(1, 140)], kg)).toBe('3 sets, top 140 kg × 1');
    expect(describeSets([set(8, 0), set(8, 0)], kg)).toBe('2×8 bodyweight');
    expect(describeSets([], kg)).toBe('');
  });
  it('labels the top set and totals volume', () => {
    expect(topSetLabel([set(5, 120), set(1, 140)], (k) => k)).toBe('140×1');
    expect(topSetLabel([set(8, 0), set(7, 0)], (k) => k)).toBe('2×8');
    expect(volumeKg([set(5, 100), set(5, 100)])).toBe(1000);
  });
});
