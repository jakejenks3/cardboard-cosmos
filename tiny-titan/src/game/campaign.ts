// The campaign: a road of bosses that your training damages. Every point of
// session XP is a point of damage (×1.5 when the session's discipline is the
// boss's weakness), overkill carries over, and there is no way to lose —
// the only question is how fast you get there.

import type { Discipline } from './types';

export interface ZoneDef {
  name: string;
  blurb: string;
  color: string;
}

export interface BossDef {
  id: string;
  name: string;
  epithet: string;
  zone: number;
  hp: number;
  weak?: Discipline;
  /** Hero XP granted on defeat. */
  xp: number;
  zoneBoss: boolean;
  /** Item id awarded on defeat (zone bosses). */
  rewardItem?: string;
}

export const WEAK_MULT = 1.5;

export const ZONES: ZoneDef[] = [
  { name: 'The Couch Kingdom', blurb: 'Where every journey starts: the gravitational pull of soft furniture.', color: '#b98a5a' },
  { name: 'Iron Foothills', blurb: 'Rusty racks, heavy things, and people who never re-rack them.', color: '#d95926' },
  { name: 'Chalk Canyon', blurb: 'Tall walls. Small holds. Big feelings.', color: '#199e70' },
  { name: 'Windswept Steppe', blurb: 'An endless road and a headwind in every direction.', color: '#3987e5' },
  { name: 'Spoke Highlands', blurb: "It's uphill. Both ways.", color: '#c98500' },
  { name: "Titan's Summit", blurb: 'The last climb is the one inside.', color: '#c77dff' },
];

const b = (id: string, name: string, epithet: string, zone: number, hp: number, weak: Discipline | undefined, zoneBoss = false, rewardItem?: string): BossDef => ({
  id,
  name,
  epithet,
  zone,
  hp,
  weak,
  xp: Math.round((hp * (zoneBoss ? 0.15 : 0.1)) / 10) * 10,
  zoneBoss,
  rewardItem,
});

export const BOSSES: BossDef[] = [
  // --- The Couch Kingdom ---------------------------------------------------
  b('snooze_button', 'Snooze Button', '“Five more minutes.”', 0, 400, undefined),
  b('couch_potato', 'Couch Potato', 'Has not moved since the pilot episode.', 0, 900, 'run'),
  b('elevator_imp', 'Elevator Imp', 'Whispers “take the lift” at every staircase.', 0, 1500, 'climb'),
  b('sunday_scaries', 'The Sunday Scaries', 'Lord of “I’ll start Monday.”', 0, 2500, 'lift', true, 'comfy_slippers'),
  // --- Iron Foothills ------------------------------------------------------
  b('rust_mite', 'Rust Mite', 'Eats neglected barbells.', 1, 3000, 'lift'),
  b('ego_imp', 'Ego Imp', 'Adds plates you did not ask for.', 1, 3500, 'climb'),
  b('doms_demon', 'DOMS Demon', 'Arrives two days late. Stays for three.', 1, 4000, 'ride'),
  b('iron_golem', 'Iron Golem', 'Never skipped a day. Never stretched either.', 1, 6000, 'lift', true, 'golem_bracers'),
  // --- Chalk Canyon --------------------------------------------------------
  b('greasy_sloper', 'Greasy Sloper', 'Nobody has ever held it. Nobody.', 2, 6000, 'climb'),
  b('pump_wraith', 'Pump Wraith', 'Fills forearms with concrete.', 2, 7000, 'run'),
  b('gravity_gremlin', 'Gravity Gremlin', 'Turns it up when you are on the crux.', 2, 8000, 'climb'),
  b('crux_wyvern', 'The Crux Wyvern', 'Guards the last move of every project.', 2, 11000, 'climb', true, 'wyvern_chalk_bag'),
  // --- Windswept Steppe ----------------------------------------------------
  b('side_stitch', 'Side Stitch', 'Small. Sharp. Punctual.', 3, 10000, 'run'),
  b('blister_blob', 'Blister Blob', 'Loves new shoes.', 3, 11000, 'ride'),
  b('headwind_wraith', 'Headwind Wraith', 'Somehow blowing from all four directions.', 3, 12000, 'run'),
  b('the_wall', 'The Wall', 'Lives at kilometre thirty-two.', 3, 16000, 'run', true, 'wallbreaker_visor'),
  // --- Spoke Highlands -----------------------------------------------------
  b('pothole_pixie', 'Pothole Pixie', 'Hides in every shadow on the descent.', 4, 14000, 'ride'),
  b('flat_tire_fiend', 'Flat Tire Fiend', 'Strikes furthest from home.', 4, 15000, 'ride'),
  b('bonk_beast', 'Bonk Beast', 'You should have eaten something.', 4, 17000, 'lift'),
  b('col_du_doom', 'Col du Doom', 'Twenty-one hairpins. Averages eleven percent.', 4, 22000, 'ride', true, 'chainring_shield'),
  // --- Titan's Summit ------------------------------------------------------
  b('plateau_giant', 'Plateau Giant', 'Flat on top. Goes on forever.', 5, 20000, 'climb'),
  b('excuse_hydra', 'Excuse Hydra', 'Cut one off; two more grow back.', 5, 22000, 'run'),
  b('comparison_specter', 'Comparison Specter', 'Shows you everyone else’s highlight reel.', 5, 25000, 'lift'),
  b('old_you', 'The Old You', 'Scrawny. Stubborn. Knows all your moves.', 5, 40000, undefined, true, 'titans_laurel'),
];

export const BOSS_BY_ID: Record<string, BossDef> = Object.fromEntries(BOSSES.map((x) => [x.id, x]));

const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

/** The boss at a campaign position. Past the final boss the trials go on forever. */
export function bossAt(index: number): BossDef {
  if (index < BOSSES.length) return BOSSES[index];
  const n = index - BOSSES.length;
  const numeral = n < ROMAN.length ? ROMAN[n] : String(n + 1);
  const hp = 30000 + 4000 * n;
  return {
    id: `echo_${n + 1}`,
    name: `Echo of Doubt ${numeral}`,
    epithet: 'The summit is behind you. The echoes never stop.',
    zone: ZONES.length - 1,
    hp,
    weak: (['lift', 'climb', 'run', 'ride'] as Discipline[])[n % 4],
    xp: 2500 + 250 * n,
    zoneBoss: false,
  };
}

export function isEcho(index: number): boolean {
  return index >= BOSSES.length;
}

export function bossesInZone(zone: number): { boss: BossDef; index: number }[] {
  return BOSSES.map((boss, index) => ({ boss, index })).filter((x) => x.boss.zone === zone);
}
