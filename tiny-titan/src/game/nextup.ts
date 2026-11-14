// "What am I closest to?" — surfaces the nearest unfinished goals across
// achievements, gear, pets, body stages and mastery ranks.

import type { Discipline } from './types';
import { DISCIPLINES, DISCIPLINE_META } from './types';
import type { PlayerState } from './state';
import { ACHIEVEMENTS } from './achievements';
import { ITEMS } from './items';
import { PETS } from './pets';
import { progressRatio, type Progress } from './goals';
import { discXpToReach, heroXpToReach, RANKS, STAGES } from './xp';

export interface NextGoal {
  key: string;
  kind: 'achievement' | 'item' | 'pet' | 'stage' | 'rank';
  icon: string;
  title: string;
  /** What you get, or how to get it. */
  sub: string;
  progress: Progress;
  ratio: number;
  discipline?: Discipline;
}

export function allOpenGoals(s: PlayerState): NextGoal[] {
  const out: NextGoal[] = [];

  for (const a of ACHIEVEMENTS) {
    if (s.achievements[a.id] || !a.progress || a.secret) continue;
    const p = a.progress(s);
    out.push({ key: `a:${a.id}`, kind: 'achievement', icon: a.icon, title: a.name, sub: `${a.desc} · +${a.xp} XP`, progress: p, ratio: progressRatio(p), discipline: isDisc(a.group) ? a.group : undefined });
  }
  for (const it of ITEMS) {
    if (s.items[it.id] || it.unlock.kind !== 'unlock' || !it.unlock.progress) continue;
    const p = it.unlock.progress(s);
    out.push({ key: `i:${it.id}`, kind: 'item', icon: '🎁', title: it.name, sub: it.unlock.hint, progress: p, ratio: progressRatio(p), discipline: it.discipline });
  }
  for (const pet of PETS) {
    if (s.pets[pet.id] || !pet.progress) continue;
    const p = pet.progress(s);
    out.push({ key: `p:${pet.id}`, kind: 'pet', icon: '🐾', title: `${pet.name} the ${pet.species}`, sub: pet.hint, progress: p, ratio: progressRatio(p), discipline: pet.discipline });
  }

  const nextStage = STAGES[s.stage + 1];
  if (nextStage) {
    out.push({
      key: 'stage',
      kind: 'stage',
      icon: '🧬',
      title: `Evolve: ${nextStage.name}`,
      sub: `New body stage at hero level ${nextStage.minLevel}`,
      progress: { cur: s.levels.hero.level, target: nextStage.minLevel, unit: 'level' },
      ratio: Math.min(1, s.xp.hero / heroXpToReach(nextStage.minLevel)),
    });
  }
  for (const d of DISCIPLINES) {
    if (s.totals.byDiscipline[d] === 0) continue;
    const next = RANKS[s.ranks[d] + 1];
    if (!next) continue;
    out.push({
      key: `r:${d}`,
      kind: 'rank',
      icon: DISCIPLINE_META[d].icon,
      title: `${DISCIPLINE_META[d].name} ${next.name}`,
      sub: `Rank up at ${DISCIPLINE_META[d].name.toLowerCase()} level ${next.minLevel}`,
      progress: { cur: s.levels[d].level, target: next.minLevel, unit: 'level' },
      ratio: Math.min(1, s.xp[d] / discXpToReach(next.minLevel)),
      discipline: d,
    });
  }
  return out.filter((g) => g.ratio < 1);
}

/** The nearest goals, with at most two of any one kind so the list stays varied. */
export function nextGoals(s: PlayerState, limit = 4): NextGoal[] {
  const sorted = allOpenGoals(s).sort((a, b) => b.ratio - a.ratio);
  const perKind: Record<string, number> = {};
  const picked: NextGoal[] = [];
  for (const g of sorted) {
    if (picked.length >= limit) break;
    if (g.ratio <= 0) continue;
    if ((perKind[g.kind] ?? 0) >= 2) continue;
    perKind[g.kind] = (perKind[g.kind] ?? 0) + 1;
    picked.push(g);
  }
  return picked;
}

function isDisc(x: string): x is Discipline {
  return x === 'lift' || x === 'climb' || x === 'run' || x === 'ride';
}
