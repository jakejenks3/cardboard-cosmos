import type { Discipline, Rarity, Slot } from './types';
import type { PlayerState } from './state';

export interface Perk {
  /** XP bonus per discipline (0.03 = +3%), or 'all'. */
  xp?: Partial<Record<Discipline | 'all', number>>;
  /** Extra loot chance multiplier (0.1 = +10%). */
  luck?: number;
}

export type ItemVisual =
  | { kind: 'headband'; color: string }
  | { kind: 'beanie'; color: string; accent?: string }
  | { kind: 'cap'; color: string; accent?: string; visor?: boolean }
  | { kind: 'helmet'; color: string; aero?: boolean }
  | { kind: 'crown'; color: string; gem: string }
  | { kind: 'bandana'; color: string }
  | { kind: 'headlamp'; color: string }
  | { kind: 'sunglasses'; color: string; frame?: string }
  | { kind: 'shirt'; color: string; accent?: string; pattern?: 'stripe' | 'polka' | 'reflective' | 'hood' }
  | { kind: 'tank'; color: string; accent?: string }
  | { kind: 'singlet'; color: string; accent?: string }
  | { kind: 'shorts'; color: string; accent?: string; knee?: string }
  | { kind: 'tights'; color: string; accent?: string }
  | { kind: 'harness'; color: string; shorts: string }
  | { kind: 'chalk' }
  | { kind: 'wraps'; color: string; long?: boolean }
  | { kind: 'gloves'; color: string; fingerless?: boolean }
  | { kind: 'shoes'; color: string; accent: string; sole?: string }
  | { kind: 'climbshoes'; color: string }
  | { kind: 'sandals'; color: string; wings?: boolean }
  | { kind: 'cape'; color: string; inner: string }
  | { kind: 'backpack'; color: string; accent?: string }
  | { kind: 'crashpad'; color: string; accent: string }
  | { kind: 'barbell' }
  | { kind: 'saddlebag'; color: string }
  | { kind: 'belt'; color: string; buckle: string }
  | { kind: 'chalkbag'; color: string }
  | { kind: 'pendant'; color: string }
  | { kind: 'medal'; ribbon: string; disc: string }
  | { kind: 'bib'; color: string }
  | { kind: 'aura'; style: 'flame' | 'gold' | 'rainbow' | 'frost' };

export type ItemUnlock =
  | { kind: 'start' }
  | { kind: 'drop'; minHeroLevel?: number }
  | { kind: 'unlock'; hint: string; check: (s: PlayerState) => boolean };

export interface ItemDef {
  id: string;
  name: string;
  slot: Slot;
  rarity: Rarity;
  discipline?: Discipline;
  flavor: string;
  perk?: Perk;
  unlock: ItemUnlock;
  visual: ItemVisual;
}

const start = (): ItemUnlock => ({ kind: 'start' });
const drop = (minHeroLevel?: number): ItemUnlock => ({ kind: 'drop', minHeroLevel });
const unlock = (hint: string, check: (s: PlayerState) => boolean): ItemUnlock => ({ kind: 'unlock', hint, check });

export const ITEMS: ItemDef[] = [
  // --- starter kit -------------------------------------------------------
  { id: 'tee_grey', name: 'Hand-Me-Down Tee', slot: 'body', rarity: 'common', flavor: 'It has seen things. Mostly couches.', unlock: start(), visual: { kind: 'shirt', color: '#8d97a5' } },
  { id: 'shorts_navy', name: 'Gym Shorts', slot: 'legs', rarity: 'common', flavor: 'Standard issue. Pockets: questionable.', unlock: start(), visual: { kind: 'shorts', color: '#2f3f63' } },
  { id: 'trainers_worn', name: 'Worn Trainers', slot: 'feet', rarity: 'common', flavor: 'The soles remember better days.', unlock: start(), visual: { kind: 'shoes', color: '#d8dbe0', accent: '#8d97a5', sole: '#6b7280' } },

  // --- lifting -----------------------------------------------------------
  { id: 'chalk_dust', name: 'Chalk Dust', slot: 'hands', rarity: 'common', discipline: 'lift', flavor: 'Grip first, questions later.', unlock: drop(), visual: { kind: 'chalk' } },
  { id: 'gym_gloves', name: 'Gym Gloves', slot: 'hands', rarity: 'common', discipline: 'lift', flavor: 'Protects the hands. Not the ego.', unlock: drop(), visual: { kind: 'gloves', color: '#2b2f3a' } },
  { id: 'bandana_red', name: 'Red Bandana', slot: 'head', rarity: 'common', discipline: 'lift', flavor: 'Instant +10 to intimidation.', unlock: drop(), visual: { kind: 'bandana', color: '#d93b3b' } },
  { id: 'wrist_wraps', name: 'Wrist Wraps', slot: 'hands', rarity: 'uncommon', discipline: 'lift', flavor: 'Wrap it before you tap it.', unlock: drop(), visual: { kind: 'wraps', color: '#e04f4f' } },
  { id: 'tank_suns_out', name: "'Sun's Out' Tank", slot: 'body', rarity: 'uncommon', discipline: 'lift', flavor: 'Guns out. Always.', unlock: unlock('Log 10 lifting sessions', (s) => s.totals.byDiscipline.lift >= 10), visual: { kind: 'tank', color: '#ff9a3c', accent: '#ffd166' } },
  { id: 'knee_sleeves', name: 'Knee Sleeves', slot: 'legs', rarity: 'uncommon', discipline: 'lift', flavor: 'Warm knees, deep squats.', unlock: unlock('Log 25 lifting sessions', (s) => s.totals.byDiscipline.lift >= 25), visual: { kind: 'shorts', color: '#1f2430', knee: '#3a4a6b' } },
  { id: 'lifting_straps', name: 'Lifting Straps', slot: 'hands', rarity: 'uncommon', discipline: 'lift', flavor: 'Your grip gives out before your back does. Not anymore.', unlock: unlock('Complete 500 sets lifetime', (s) => s.totals.liftSets >= 500), visual: { kind: 'wraps', color: '#4b6cb7', long: true } },
  { id: 'leather_belt', name: 'Leather Belt', slot: 'accessory', rarity: 'rare', discipline: 'lift', flavor: 'Brace. Breathe. Believe.', perk: { xp: { lift: 0.03 } }, unlock: unlock('Lift 50,000 kg lifetime', (s) => s.totals.liftVolumeKg >= 50000), visual: { kind: 'belt', color: '#6b3e1e', buckle: '#d9b04c' } },
  { id: 'plate_pendant', name: 'Iron Plate Pendant', slot: 'accessory', rarity: 'rare', discipline: 'lift', flavor: 'A tiny 2.5 on a chain. Still counts.', unlock: unlock('Lift 100 kg in a set', (s) => !!s.achievements.lift_100), visual: { kind: 'pendant', color: '#9aa3ad' } },
  { id: 'singlet_red', name: 'Competition Singlet', slot: 'body', rarity: 'rare', discipline: 'lift', flavor: 'Nowhere to hide. Nothing to hide.', unlock: unlock('Lift 250,000 kg lifetime', (s) => s.totals.liftVolumeKg >= 250000), visual: { kind: 'singlet', color: '#c62828', accent: '#ffcc80' } },
  { id: 'barbell_back', name: 'Barbell of Burden', slot: 'back', rarity: 'epic', discipline: 'lift', flavor: 'You carry it everywhere now. Metaphorically. And literally.', perk: { xp: { lift: 0.05 } }, unlock: unlock('Lift 1,000,000 kg lifetime', (s) => s.totals.liftVolumeKg >= 1000000), visual: { kind: 'barbell' } },
  { id: 'iron_crown', name: 'Crown of Iron', slot: 'head', rarity: 'legendary', discipline: 'lift', flavor: 'Heavy is the head. Heavier is the bar.', perk: { xp: { lift: 0.08 } }, unlock: unlock('Reach lifting level 30', (s) => s.levels.lift.level >= 30), visual: { kind: 'crown', color: '#8f98a3', gem: '#ff5252' } },

  // --- climbing ----------------------------------------------------------
  { id: 'chalk_bag', name: 'Chalk Bag', slot: 'accessory', rarity: 'common', discipline: 'climb', flavor: 'Dip, clap, send.', unlock: unlock('Log a climbing session', (s) => s.totals.byDiscipline.climb >= 1), visual: { kind: 'chalkbag', color: '#5c6bc0' } },
  { id: 'beanie_green', name: 'Crag Beanie', slot: 'head', rarity: 'common', discipline: 'climb', flavor: 'Worn indoors. Worn in summer. Worn always.', unlock: drop(), visual: { kind: 'beanie', color: '#3f8f5a', accent: '#2c6b42' } },
  { id: 'approach_shoes', name: 'Approach Shoes', slot: 'feet', rarity: 'common', discipline: 'climb', flavor: 'For the walk to the wall. The real workout.', unlock: drop(), visual: { kind: 'shoes', color: '#7a5c3e', accent: '#c7a27a', sole: '#3b2a1a' } },
  { id: 'headlamp', name: 'Headlamp', slot: 'head', rarity: 'uncommon', discipline: 'climb', flavor: 'Dawn patrol approved.', unlock: drop(), visual: { kind: 'headlamp', color: '#90a4ae' } },
  { id: 'climbing_shoes', name: 'Climbing Shoes', slot: 'feet', rarity: 'uncommon', discipline: 'climb', flavor: 'Two sizes too small. Perfect.', unlock: unlock('Log 10 climbing sessions', (s) => s.totals.byDiscipline.climb >= 10), visual: { kind: 'climbshoes', color: '#e53935' } },
  { id: 'sendy_tank', name: 'Sendy Tank', slot: 'body', rarity: 'uncommon', discipline: 'climb', flavor: '“Allez!” — someone, always.', unlock: unlock('Send a V3', (s) => (s.prs.climbMaxSend ?? -9) >= 3), visual: { kind: 'tank', color: '#26a69a', accent: '#80cbc4' } },
  { id: 'harness', name: 'Harness', slot: 'legs', rarity: 'uncommon', discipline: 'climb', flavor: 'Ready for ropes. Looks great over shorts.', unlock: unlock('Log 25 climbing sessions', (s) => s.totals.byDiscipline.climb >= 25), visual: { kind: 'harness', color: '#ff8f00', shorts: '#37474f' } },
  { id: 'crash_pad', name: 'Crash Pad', slot: 'back', rarity: 'rare', discipline: 'climb', flavor: 'A mattress you carry up a hill. For fun.', perk: { xp: { climb: 0.03 } }, unlock: unlock('100 sends lifetime', (s) => s.totals.climbSends >= 100), visual: { kind: 'crashpad', color: '#1e88e5', accent: '#ffb300' } },
  { id: 'crimp_gauntlets', name: 'Crimp Gauntlets', slot: 'hands', rarity: 'rare', discipline: 'climb', flavor: 'Tape on every finger. Skin is temporary.', unlock: unlock('Send a V5', (s) => (s.prs.climbMaxSend ?? -9) >= 5), visual: { kind: 'wraps', color: '#f5f5f5' } },
  { id: 'stone_fist_wraps', name: 'Stone Fist Wraps', slot: 'hands', rarity: 'epic', discipline: 'climb', flavor: 'Your fingers are now a geological feature.', perk: { xp: { climb: 0.05 } }, unlock: unlock('Send a V8', (s) => (s.prs.climbMaxSend ?? -9) >= 8), visual: { kind: 'gloves', color: '#78909c' } },
  { id: 'granite_crown', name: 'Granite Crown', slot: 'head', rarity: 'legendary', discipline: 'climb', flavor: 'Crowned by the stone itself.', perk: { xp: { climb: 0.08 } }, unlock: unlock('Reach climbing level 30 or send a V10', (s) => s.levels.climb.level >= 30 || (s.prs.climbMaxSend ?? -9) >= 10), visual: { kind: 'crown', color: '#90a4ae', gem: '#66bb6a' } },

  // --- running -----------------------------------------------------------
  { id: 'sweatband', name: 'Sweatband', slot: 'head', rarity: 'common', discipline: 'run', flavor: 'Retro. Functional. Iconic.', unlock: unlock('Log a run', (s) => s.totals.byDiscipline.run >= 1), visual: { kind: 'headband', color: '#42a5f5' } },
  { id: 'running_cap', name: 'Running Cap', slot: 'head', rarity: 'common', discipline: 'run', flavor: 'Shade for the long haul.', unlock: drop(), visual: { kind: 'cap', color: '#29b6f6', accent: '#ffffff' } },
  { id: 'visor', name: 'Race Visor', slot: 'head', rarity: 'common', discipline: 'run', flavor: 'Lets the heat out. Keeps the focus in.', unlock: drop(), visual: { kind: 'cap', color: '#ffffff', accent: '#29b6f6', visor: true } },
  { id: 'reflective_vest', name: 'Reflective Vest', slot: 'body', rarity: 'common', discipline: 'run', flavor: 'Be seen. Be fast.', unlock: drop(), visual: { kind: 'shirt', color: '#c6ff00', accent: '#9e9e9e', pattern: 'reflective' } },
  { id: 'arm_sleeves', name: 'Compression Sleeves', slot: 'hands', rarity: 'uncommon', discipline: 'run', flavor: 'Science says maybe. Vibes say yes.', unlock: unlock('Log 25 runs', (s) => s.totals.byDiscipline.run >= 25), visual: { kind: 'wraps', color: '#0288d1', long: true } },
  { id: 'race_bib', name: 'Race Bib #001', slot: 'accessory', rarity: 'uncommon', discipline: 'run', flavor: 'Pinned on. Slightly crooked. Perfect.', unlock: unlock('Run 10 km in one go', (s) => s.prs.longestRunM >= 10000), visual: { kind: 'bib', color: '#ffffff' } },
  { id: 'trail_shoes', name: 'Trail Shoes', slot: 'feet', rarity: 'uncommon', discipline: 'run', flavor: 'Lugs for days.', unlock: unlock('Run 100 km lifetime', (s) => s.totals.runDistanceM >= 100000), visual: { kind: 'shoes', color: '#2e7d32', accent: '#ff7043', sole: '#1b1b1b' } },
  { id: 'carbon_racers', name: 'Carbon Racers', slot: 'feet', rarity: 'rare', discipline: 'run', flavor: 'They feel like cheating. They are not cheating.', perk: { xp: { run: 0.03 } }, unlock: unlock('Run a half marathon (21.1 km) in one go', (s) => s.prs.longestRunM >= 21097), visual: { kind: 'shoes', color: '#ff1744', accent: '#ffffff', sole: '#ffea00' } },
  { id: 'hydration_vest', name: 'Hydration Vest', slot: 'back', rarity: 'rare', discipline: 'run', flavor: 'Sips on the move.', unlock: unlock('Run 500 km lifetime', (s) => s.totals.runDistanceM >= 500000), visual: { kind: 'backpack', color: '#00acc1', accent: '#ff7043' } },
  { id: 'marathon_medal', name: 'Marathon Medal', slot: 'accessory', rarity: 'epic', discipline: 'run', flavor: '42.195 km. Every one of them earned.', perk: { xp: { run: 0.05 } }, unlock: unlock('Run a marathon (42.2 km) in one go', (s) => s.prs.longestRunM >= 42195), visual: { kind: 'medal', ribbon: '#1565c0', disc: '#ffd54f' } },
  { id: 'winged_sandals', name: 'Winged Sandals', slot: 'feet', rarity: 'legendary', discipline: 'run', flavor: 'Hermes called. He wants tips.', perk: { xp: { run: 0.08 } }, unlock: unlock('Reach running level 30 or run 1,000 km lifetime', (s) => s.levels.run.level >= 30 || s.totals.runDistanceM >= 1000000), visual: { kind: 'sandals', color: '#ffd54f', wings: true } },

  // --- cycling -----------------------------------------------------------
  { id: 'bike_helmet', name: 'Bike Helmet', slot: 'head', rarity: 'common', discipline: 'ride', flavor: 'Brain: protected. Hair: compromised.', unlock: unlock('Log a ride', (s) => s.totals.byDiscipline.ride >= 1), visual: { kind: 'helmet', color: '#eceff1' } },
  { id: 'cycling_cap', name: 'Cycling Cap', slot: 'head', rarity: 'common', discipline: 'ride', flavor: 'Brim up. Always brim up.', unlock: drop(), visual: { kind: 'cap', color: '#ab47bc', accent: '#ffffff' } },
  { id: 'fingerless_gloves', name: 'Fingerless Gloves', slot: 'hands', rarity: 'common', discipline: 'ride', flavor: 'Tan lines included.', unlock: drop(), visual: { kind: 'gloves', color: '#263238', fingerless: true } },
  { id: 'saddle_bag', name: 'Saddle Bag', slot: 'back', rarity: 'common', discipline: 'ride', flavor: 'Two tubes, one lever, zero regrets.', unlock: drop(), visual: { kind: 'saddlebag', color: '#424242' } },
  { id: 'sport_shades', name: 'Sport Shades', slot: 'face', rarity: 'uncommon', discipline: 'ride', flavor: 'Looking fast is half the battle.', unlock: drop(), visual: { kind: 'sunglasses', color: '#ff6f00', frame: '#212121' } },
  { id: 'team_jersey', name: 'Team Jersey', slot: 'body', rarity: 'uncommon', discipline: 'ride', flavor: 'Sponsored by nobody. Yet.', unlock: unlock('Log 10 rides', (s) => s.totals.byDiscipline.ride >= 10), visual: { kind: 'shirt', color: '#7e57c2', accent: '#ffffff', pattern: 'stripe' } },
  { id: 'clipless_shoes', name: 'Clipless Shoes', slot: 'feet', rarity: 'uncommon', discipline: 'ride', flavor: 'Click. Clack. Fall over once. Pro.', unlock: unlock('Ride 200 km lifetime', (s) => s.totals.rideDistanceM >= 200000), visual: { kind: 'shoes', color: '#ffffff', accent: '#7e57c2', sole: '#212121' } },
  { id: 'bib_shorts', name: 'Bib Shorts', slot: 'legs', rarity: 'uncommon', discipline: 'ride', flavor: 'Padded. Dignified. Mostly.', unlock: unlock('Ride 500 km lifetime', (s) => s.totals.rideDistanceM >= 500000), visual: { kind: 'tights', color: '#212121', accent: '#7e57c2' } },
  { id: 'aero_helmet', name: 'Aero Helmet', slot: 'head', rarity: 'rare', discipline: 'ride', flavor: 'Every watt counts.', perk: { xp: { ride: 0.03 } }, unlock: unlock('Ride 100 km in one go', (s) => s.prs.longestRideM >= 100000), visual: { kind: 'helmet', color: '#212121', aero: true } },
  { id: 'polka_jersey', name: 'Polka Dot Jersey', slot: 'body', rarity: 'epic', discipline: 'ride', flavor: 'King of the Mountains.', perk: { xp: { ride: 0.05 } }, unlock: unlock('Climb 10,000 m of elevation lifetime on the bike', (s) => s.totals.rideElevationM >= 10000), visual: { kind: 'shirt', color: '#ffffff', accent: '#e53935', pattern: 'polka' } },
  { id: 'yellow_jersey', name: 'Yellow Jersey', slot: 'body', rarity: 'legendary', discipline: 'ride', flavor: 'The maillot jaune. You know what it means.', perk: { xp: { ride: 0.08 } }, unlock: unlock('Reach cycling level 30 or ride 5,000 km lifetime', (s) => s.levels.ride.level >= 30 || s.totals.rideDistanceM >= 5000000), visual: { kind: 'shirt', color: '#ffeb3b', accent: '#fbc02d' } },

  // --- general -----------------------------------------------------------
  { id: 'sunglasses_black', name: 'Black Shades', slot: 'face', rarity: 'common', flavor: 'Deal with it.', unlock: drop(), visual: { kind: 'sunglasses', color: '#111111' } },
  { id: 'hoodie_grey', name: 'Training Hoodie', slot: 'body', rarity: 'common', flavor: 'Hood up. Headphones in. Nobody talk to me.', unlock: drop(), visual: { kind: 'shirt', color: '#607d8b', accent: '#455a64', pattern: 'hood' } },
  { id: 'joggers_black', name: 'Joggers', slot: 'legs', rarity: 'common', flavor: 'Tapered for aerodynamics. Probably.', unlock: drop(), visual: { kind: 'tights', color: '#2b2b2b', accent: '#2b2b2b' } },
  { id: 'lucky_socks', name: 'Lucky Socks', slot: 'feet', rarity: 'uncommon', flavor: 'Unwashed since the last PR. Loot loves them.', perk: { luck: 0.1 }, unlock: drop(), visual: { kind: 'shoes', color: '#ffffff', accent: '#43a047', sole: '#43a047' } },
  { id: 'champion_headband', name: "Champion's Headband", slot: 'head', rarity: 'rare', flavor: 'Fifty sessions. Still showing up.', perk: { xp: { all: 0.02 } }, unlock: unlock('Log 50 sessions', (s) => s.totals.sessions >= 50), visual: { kind: 'headband', color: '#ffd54f' } },
  { id: 'hero_cape', name: 'Hero Cape', slot: 'back', rarity: 'rare', flavor: 'Does nothing. Looks incredible.', unlock: unlock('Reach hero level 10', (s) => s.levels.hero.level >= 10), visual: { kind: 'cape', color: '#d32f2f', inner: '#8e0000' } },
  { id: 'golden_cape', name: 'Golden Cape', slot: 'back', rarity: 'epic', flavor: 'Flutters even indoors.', perk: { xp: { all: 0.03 } }, unlock: unlock('Reach hero level 25', (s) => s.levels.hero.level >= 25), visual: { kind: 'cape', color: '#ffc107', inner: '#ff8f00' } },
  { id: 'frost_aura', name: 'Frost Aura', slot: 'aura', rarity: 'rare', flavor: 'Chill under pressure.', unlock: drop(15), visual: { kind: 'aura', style: 'frost' } },
  { id: 'flame_aura', name: 'Streak Flame', slot: 'aura', rarity: 'epic', flavor: 'Eight weeks of fire. Can you feel it?', perk: { xp: { all: 0.03 } }, unlock: unlock('Keep an 8-week streak', (s) => s.streak.best >= 8), visual: { kind: 'aura', style: 'flame' } },
  { id: 'titan_aura', name: 'Titan Aura', slot: 'aura', rarity: 'legendary', flavor: 'The room gets brighter when you walk in.', perk: { xp: { all: 0.05 } }, unlock: unlock('Reach hero level 50', (s) => s.levels.hero.level >= 50), visual: { kind: 'aura', style: 'gold' } },
  { id: 'rainbow_aura', name: 'Prismatic Aura', slot: 'aura', rarity: 'legendary', flavor: 'Master of all four paths.', perk: { xp: { all: 0.05 }, luck: 0.1 }, unlock: unlock('Reach level 20 in all four disciplines', (s) => (['lift', 'climb', 'run', 'ride'] as Discipline[]).every((d) => s.levels[d].level >= 20)), visual: { kind: 'aura', style: 'rainbow' } },
];

export const ITEM_BY_ID: Record<string, ItemDef> = Object.fromEntries(ITEMS.map((i) => [i.id, i]));

export const RARITY_WEIGHT: Record<Rarity, number> = {
  common: 55,
  uncommon: 30,
  rare: 12,
  epic: 3,
  legendary: 0,
};

export function perkSummary(p?: Perk): string[] {
  if (!p) return [];
  const out: string[] = [];
  if (p.xp) {
    for (const [k, v] of Object.entries(p.xp)) {
      if (!v) continue;
      const label = k === 'all' ? 'all XP' : `${{ lift: 'lifting', climb: 'climbing', run: 'running', ride: 'cycling' }[k as Discipline]} XP`;
      out.push(`+${Math.round(v * 100)}% ${label}`);
    }
  }
  if (p.luck) out.push(`+${Math.round(p.luck * 100)}% loot luck`);
  return out;
}
