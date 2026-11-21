// Lifetime totals, put in perspective.

import type { PlayerState } from './state';

export interface FunFact {
  icon: string;
  /** e.g. "3.0 elephants" */
  headline: string;
  detail: string;
}

type Scale = [name: string, size: number, icon: string][];

const WEIGHT: Scale = [
  ['house cats', 4.5, '🐈'],
  ['grand pianos', 450, '🎹'],
  ['cars', 1500, '🚗'],
  ['elephants', 5000, '🐘'],
  ['blue whales', 150000, '🐋'],
  ['Eiffel Towers', 10100000, '🗼'],
];
const HEIGHT: Scale = [
  ['giraffes', 5, '🦒'],
  ['Statues of Liberty', 93, '🗽'],
  ['Eiffel Towers', 330, '🗼'],
  ['El Capitans', 914, '🧗'],
  ['Mount Everests', 8849, '🏔️'],
];
const RUN: Scale = [
  ['laps of a track', 400, '🏟️'],
  ['marathons', 42195, '🏅'],
  ['lengths of Great Britain', 1407000, '🇬🇧'],
  ['crossings of the USA', 4500000, '🗺️'],
  ['laps of the Earth', 40075000, '🌍'],
];
const RIDE: Scale = [
  ['Tour de France stages', 170000, '🚴'],
  ['Tours de France', 3400000, '🇫🇷'],
  ['laps of the Earth', 40075000, '🌍'],
];

function pick(total: number, scale: Scale): { name: string; n: number; icon: string } | null {
  let best: { name: string; n: number; icon: string } | null = null;
  for (const [name, size, icon] of scale) {
    const n = total / size;
    if (n >= 1) best = { name, n, icon };
  }
  return best;
}

function num(n: number): string {
  return n >= 100 ? Math.round(n).toLocaleString('en-US') : n >= 10 ? n.toFixed(0) : n.toFixed(1);
}

export function funFacts(s: PlayerState): FunFact[] {
  const out: FunFact[] = [];
  const t = s.totals;
  const w = pick(t.liftVolumeKg, WEIGHT);
  if (w) out.push({ icon: w.icon, headline: `${num(w.n)} ${w.name}`, detail: 'lifted, in total volume' });
  // A boulder problem is roughly 4 m of climbing.
  const climbed = t.climbSends * 4;
  const c = pick(climbed, HEIGHT);
  if (c) out.push({ icon: c.icon, headline: `${num(c.n)} ${c.name}`, detail: `of rock climbed (${t.climbSends} sends)` });
  const r = pick(t.runDistanceM, RUN);
  if (r) out.push({ icon: r.icon, headline: `${num(r.n)} ${r.name}`, detail: 'covered on foot' });
  const b = pick(t.rideDistanceM, RIDE);
  if (b) out.push({ icon: b.icon, headline: `${num(b.n)} ${b.name}`, detail: 'ridden' });
  const e = pick(t.runElevationM + t.rideElevationM, HEIGHT);
  if (e) out.push({ icon: e.icon, headline: `${num(e.n)} ${e.name}`, detail: 'of elevation gained running and riding' });
  const hours = t.durationSec / 3600;
  if (hours >= 2) out.push({ icon: '🎬', headline: `${num(hours / 2)} feature films`, detail: `worth of training (${num(hours)} hours)` });
  if (s.campaign.totalDamage >= 1000) out.push({ icon: '💥', headline: `${Math.round(s.campaign.totalDamage).toLocaleString('en-US')} damage`, detail: `dealt to ${Object.keys(s.campaign.defeated).length} defeated bosses and counting` });
  return out;
}
