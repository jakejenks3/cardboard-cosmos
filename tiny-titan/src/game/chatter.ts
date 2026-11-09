// What your companion says when you open the app: one contextual nudge,
// chosen by priority, stable for the day so it does not flicker.

import type { PlayerState } from './state';
import type { NextGoal } from './nextup';
import type { BossDef } from './campaign';
import { hashString } from './rng';

export interface ChatterCtx {
  s: PlayerState;
  today: string;
  /** Days since the last logged session (null when there are none). */
  daysSinceLast: number | null;
  trainedToday: boolean;
  claimable: number;
  boss: BossDef;
  bossHpLeft: number;
  nearest?: NextGoal;
}

const IDLE = [
  'Ready when you are.',
  'Today is a good day to deal some damage.',
  'Small sessions count. All of them.',
  'I believe in you. Also I live here now.',
  'Future you says thanks in advance.',
  'Log it or it did not happen.',
  'One session at a time. That is the whole trick.',
];

export function petLine(c: ChatterCtx): string {
  const { s } = c;
  if (s.totals.sessions === 0) return 'Log your first session and watch what happens.';
  if (c.claimable > 0) return `Psst — ${c.claimable} quest reward${c.claimable === 1 ? '' : 's'} waiting to be claimed.`;
  if (c.daysSinceLast !== null && c.daysSinceLast >= 7) return `${c.daysSinceLast} days since your last session. No judgment — the door is open.`;
  if (c.daysSinceLast !== null && c.daysSinceLast >= 3 && !c.trainedToday) return `${c.daysSinceLast} days off. I have been practising my cheering.`;
  if (!c.trainedToday && s.streak.goal - s.streak.thisWeek === 1) return 'One more session and this week’s goal is done!';
  if (c.bossHpLeft / c.boss.hp <= 0.25) return `${c.boss.name} is nearly down — only ${c.bossHpLeft.toLocaleString('en-US')} HP left!`;
  if (c.nearest && c.nearest.ratio >= 0.8) return `So close to “${c.nearest.title}”. One good session might do it.`;
  if (c.trainedToday) return s.streak.thisWeek >= s.streak.goal ? 'Weekly goal done. Rest is part of the plan.' : 'Nice work today. I saw everything.';
  if (c.boss.weak) return `${c.boss.name} hates ${{ lift: 'lifting', climb: 'climbing', run: 'running', ride: 'cycling' }[c.boss.weak]}. Just saying.`;
  return IDLE[hashString(c.today) % IDLE.length];
}
