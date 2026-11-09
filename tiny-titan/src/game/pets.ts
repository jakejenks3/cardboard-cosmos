import type { Discipline, Rarity } from './types';
import type { PlayerState } from './state';
import type { Perk } from './items';

export interface PetDef {
  id: string;
  name: string;
  species: string;
  rarity: Rarity;
  discipline?: Discipline;
  flavor: string;
  perk: Perk;
  hint: string;
  check: (s: PlayerState) => boolean;
}

export const PETS: PetDef[] = [
  { id: 'slime', name: 'Gloop', species: 'Gym Slime', rarity: 'common', flavor: 'Found under the squat rack. Very supportive.', perk: { xp: { all: 0.01 } }, hint: 'Log your first session', check: (s) => s.totals.sessions >= 1 },
  { id: 'bulldog', name: 'Rep', species: 'Bulldog', rarity: 'common', discipline: 'lift', flavor: 'Counts your reps. Loudly.', perk: { xp: { lift: 0.03 } }, hint: 'Log a lifting session', check: (s) => s.totals.byDiscipline.lift >= 1 },
  { id: 'gecko', name: 'Crimpy', species: 'Gecko', rarity: 'common', discipline: 'climb', flavor: 'Sticks to anything. Shows off about it.', perk: { xp: { climb: 0.03 } }, hint: 'Log a climbing session', check: (s) => s.totals.byDiscipline.climb >= 1 },
  { id: 'pigeon', name: 'Coach', species: 'Pigeon', rarity: 'common', discipline: 'run', flavor: 'Keeps pace. Judges your form.', perk: { xp: { run: 0.03 } }, hint: 'Log a run', check: (s) => s.totals.byDiscipline.run >= 1 },
  { id: 'hamster', name: 'Pedals', species: 'Hamster', rarity: 'common', discipline: 'ride', flavor: 'Born for the wheel.', perk: { xp: { ride: 0.03 } }, hint: 'Log a ride', check: (s) => s.totals.byDiscipline.ride >= 1 },
  { id: 'ox', name: 'Tonnage', species: 'Ox', rarity: 'rare', discipline: 'lift', flavor: 'Strong as, well, you know.', perk: { xp: { lift: 0.05 } }, hint: 'Reach lifting level 10', check: (s) => s.levels.lift.level >= 10 },
  { id: 'goat', name: 'Cliff', species: 'Mountain Goat', rarity: 'rare', discipline: 'climb', flavor: 'Has never fallen. Ever. Allegedly.', perk: { xp: { climb: 0.05 } }, hint: 'Reach climbing level 10', check: (s) => s.levels.climb.level >= 10 },
  { id: 'greyhound', name: 'Zoom', species: 'Greyhound', rarity: 'rare', discipline: 'run', flavor: 'Fast. Elegant. Naps 20 hours a day.', perk: { xp: { run: 0.05 } }, hint: 'Reach running level 10', check: (s) => s.levels.run.level >= 10 },
  { id: 'falcon', name: 'Draft', species: 'Falcon', rarity: 'rare', discipline: 'ride', flavor: 'Rides your slipstream. Takes the KOM.', perk: { xp: { ride: 0.05 } }, hint: 'Reach cycling level 10', check: (s) => s.levels.ride.level >= 10 },
  { id: 'tortoise', name: 'Steady', species: 'Tortoise', rarity: 'rare', flavor: 'Slow is smooth. Smooth is eight weeks straight.', perk: { xp: { all: 0.04 } }, hint: 'Keep an 8-week streak', check: (s) => s.streak.best >= 8 },
  { id: 'cat', name: 'Deload', species: 'Cat', rarity: 'rare', flavor: 'Knocks loot off the shelf. Into your bag.', perk: { luck: 0.08 }, hint: 'Log 50 sessions', check: (s) => s.totals.sessions >= 50 },
  { id: 'phoenix', name: 'Ember', species: 'Phoenix', rarity: 'epic', flavor: 'Half a year of fire, reborn weekly.', perk: { xp: { all: 0.06 } }, hint: 'Keep a 26-week streak', check: (s) => s.streak.best >= 26 },
  { id: 'dragon', name: 'Titan Jr.', species: 'Baby Dragon', rarity: 'legendary', flavor: 'Tiny now. Give it a few hundred sessions.', perk: { xp: { all: 0.08 } }, hint: 'Reach hero level 30', check: (s) => s.levels.hero.level >= 30 },
];

export const PET_BY_ID: Record<string, PetDef> = Object.fromEntries(PETS.map((p) => [p.id, p]));
