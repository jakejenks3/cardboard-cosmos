import type { Discipline, Rarity } from './types';
import type { PlayerState } from './state';
import type { Perk } from './items';
import { atLeast, type Goal, type ProgressUnit } from './goals';

export interface PetDef extends Goal {
  id: string;
  name: string;
  species: string;
  rarity: Rarity;
  discipline?: Discipline;
  flavor: string;
  perk: Perk;
  hint: string;
}

const p = (
  id: string,
  name: string,
  species: string,
  rarity: Rarity,
  flavor: string,
  perk: Perk,
  hint: string,
  get: (s: PlayerState) => number,
  target: number,
  unit: ProgressUnit = 'count',
  discipline?: Discipline,
): PetDef => ({ id, name, species, rarity, flavor, perk, hint, discipline, ...atLeast(get, target, unit) });

export const PETS: PetDef[] = [
  p('slime', 'Gloop', 'Gym Slime', 'common', 'Found under the squat rack. Very supportive.', { xp: { all: 0.01 } }, 'Log your first session', (s) => s.totals.sessions, 1),
  p('bulldog', 'Rep', 'Bulldog', 'common', 'Counts your reps. Loudly.', { xp: { lift: 0.03 } }, 'Log a lifting session', (s) => s.totals.byDiscipline.lift, 1, 'count', 'lift'),
  p('gecko', 'Crimpy', 'Gecko', 'common', 'Sticks to anything. Shows off about it.', { xp: { climb: 0.03 } }, 'Log a climbing session', (s) => s.totals.byDiscipline.climb, 1, 'count', 'climb'),
  p('pigeon', 'Coach', 'Pigeon', 'common', 'Keeps pace. Judges your form.', { xp: { run: 0.03 } }, 'Log a run', (s) => s.totals.byDiscipline.run, 1, 'count', 'run'),
  p('hamster', 'Pedals', 'Hamster', 'common', 'Born for the wheel.', { xp: { ride: 0.03 } }, 'Log a ride', (s) => s.totals.byDiscipline.ride, 1, 'count', 'ride'),
  p('sprout', 'Sprout', 'Potted Plant', 'uncommon', 'Grows a leaf every time you check in.', { xp: { all: 0.02 } }, 'Check in (weight or photos) 4 weeks in a row', (s) => s.body.bestStreak, 4, 'weeks'),
  p('ox', 'Tonnage', 'Ox', 'rare', 'Strong as, well, you know.', { xp: { lift: 0.05 } }, 'Reach lifting level 10', (s) => s.levels.lift.level, 10, 'level', 'lift'),
  p('goat', 'Cliff', 'Mountain Goat', 'rare', 'Has never fallen. Ever. Allegedly.', { xp: { climb: 0.05 } }, 'Reach climbing level 10', (s) => s.levels.climb.level, 10, 'level', 'climb'),
  p('greyhound', 'Zoom', 'Greyhound', 'rare', 'Fast. Elegant. Naps 20 hours a day.', { xp: { run: 0.05 } }, 'Reach running level 10', (s) => s.levels.run.level, 10, 'level', 'run'),
  p('falcon', 'Draft', 'Falcon', 'rare', 'Rides your slipstream. Takes the KOM.', { xp: { ride: 0.05 } }, 'Reach cycling level 10', (s) => s.levels.ride.level, 10, 'level', 'ride'),
  p('golemling', 'Pebble', 'Golemling', 'rare', 'A chip off the old Iron Golem. Followed you home.', { xp: { all: 0.03 } }, 'Clear the Iron Foothills (defeat 8 bosses)', (s) => Object.keys(s.campaign.defeated).length, 8),
  p('tortoise', 'Steady', 'Tortoise', 'rare', 'Slow is smooth. Smooth is eight weeks straight.', { xp: { all: 0.04 } }, 'Keep an 8-week streak', (s) => s.streak.best, 8, 'weeks'),
  p('cat', 'Deload', 'Cat', 'rare', 'Knocks loot off the shelf. Into your bag.', { luck: 0.08 }, 'Log 50 sessions', (s) => s.totals.sessions, 50),
  p('phoenix', 'Ember', 'Phoenix', 'epic', 'Half a year of fire, reborn weekly.', { xp: { all: 0.06 } }, 'Keep a 26-week streak', (s) => s.streak.best, 26, 'weeks'),
  p('dragon', 'Titan Jr.', 'Baby Dragon', 'legendary', 'Tiny now. Give it a few hundred sessions.', { xp: { all: 0.08 } }, 'Reach hero level 30', (s) => s.levels.hero.level, 30, 'level'),
];

export const PET_BY_ID: Record<string, PetDef> = Object.fromEntries(PETS.map((x) => [x.id, x]));
