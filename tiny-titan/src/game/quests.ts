import type { Discipline, QuestClaim, Session, Settings } from './types';
import { DISCIPLINES, DISCIPLINE_META } from './types';
import type { PlayerState } from './state';
import { sessionStats } from './xp';
import { makeRng } from './rng';
import { weekKey } from './dates';

export interface Quest {
  id: string;
  kind: 'daily' | 'weekly';
  periodKey: string;
  title: string;
  desc: string;
  icon: string;
  discipline?: Discipline;
  target: number;
  progress: number;
  /** Renders a progress number (unit-aware formatting is done by the caller). */
  unit: 'sessions' | 'days' | 'kg' | 'sends' | 'm' | 'xp' | 'min' | 'disciplines';
  xp: number;
  done: boolean;
  claimed: boolean;
}

function roundTo(n: number, step: number): number {
  return Math.max(step, Math.round(n / step) * step);
}

function dailyTarget(d: Discipline, s: PlayerState): { target: number; unit: Quest['unit']; title: string; icon: string } {
  const lv = s.levels[d].level;
  switch (d) {
    case 'lift':
      return { target: roundTo(1500 + 350 * lv, 500), unit: 'kg', title: 'Move some iron', icon: '🏋️' };
    case 'climb':
      return { target: 4 + Math.floor(lv * 0.6), unit: 'sends', title: 'Send it', icon: '🧗' };
    case 'run':
      return { target: roundTo((2 + lv * 0.35) * 1000, 500), unit: 'm', title: 'Get the miles in', icon: '👟' };
    case 'ride':
      return { target: roundTo((8 + lv * 1.5) * 1000, 1000), unit: 'm', title: 'Spin the wheels', icon: '🚴' };
  }
}

function disciplineProgress(d: Discipline, sessions: Session[]): number {
  let p = 0;
  for (const s of sessions) {
    if (s.discipline !== d) continue;
    const st = sessionStats(s);
    if (d === 'lift') p += st.volumeKg;
    else if (d === 'climb') p += st.sends;
    else p += st.distanceM;
  }
  return p;
}

function pickDiscipline(rng: { next(): number }, s: PlayerState): Discipline | null {
  const used = DISCIPLINES.filter((d) => s.totals.byDiscipline[d] > 0);
  if (!used.length) return null;
  // Weighted by how much the player actually does each discipline.
  const total = used.reduce((a, d) => a + s.totals.byDiscipline[d], 0);
  let r = rng.next() * total;
  for (const d of used) {
    r -= s.totals.byDiscipline[d];
    if (r < 0) return d;
  }
  return used[used.length - 1];
}

function finish(q: Omit<Quest, 'done' | 'claimed'>, claims: QuestClaim[]): Quest {
  const done = q.progress >= q.target;
  return { ...q, done, claimed: claims.some((c) => c.questId === q.id) };
}

export function dailyQuests(dateKey: string, s: PlayerState, allSessions: Session[], claims: QuestClaim[]): Quest[] {
  const rng = makeRng(`daily:${dateKey}`);
  const sessions = allSessions.filter((x) => x.date === dateKey);
  const out: Quest[] = [];
  const heroLv = s.levels.hero.level;

  out.push(
    finish(
      {
        id: `d:${dateKey}:0`,
        kind: 'daily',
        periodKey: dateKey,
        title: 'Show up',
        desc: 'Log any session today.',
        icon: '🙌',
        target: 1,
        progress: sessions.length,
        unit: 'sessions',
        xp: 150,
      },
      claims,
    ),
  );

  const d = pickDiscipline(rng, s);
  if (d) {
    const t = dailyTarget(d, s);
    out.push(
      finish(
        {
          id: `d:${dateKey}:1`,
          kind: 'daily',
          periodKey: dateKey,
          title: t.title,
          desc: `${DISCIPLINE_META[d].name} volume today.`,
          icon: t.icon,
          discipline: d,
          target: t.target,
          progress: disciplineProgress(d, sessions),
          unit: t.unit,
          xp: 200,
        },
        claims,
      ),
    );
  } else {
    out.push(
      finish(
        {
          id: `d:${dateKey}:1`,
          kind: 'daily',
          periodKey: dateKey,
          title: 'Break a sweat',
          desc: 'Train for 30 minutes today.',
          icon: '⏱️',
          target: 30,
          progress: Math.round(sessions.reduce((a, x) => a + (x.durationSec ?? 0), 0) / 60),
          unit: 'min',
          xp: 200,
        },
        claims,
      ),
    );
  }

  if (rng.next() < 0.6) {
    const target = roundTo(300 + 60 * heroLv, 50);
    out.push(
      finish(
        {
          id: `d:${dateKey}:2`,
          kind: 'daily',
          periodKey: dateKey,
          title: 'XP hunter',
          desc: `Earn ${target.toLocaleString('en-US')} XP from sessions today.`,
          icon: '✨',
          target,
          progress: sessions.reduce((a, x) => a + (s.sessionXp[x.id] ?? 0), 0),
          unit: 'xp',
          xp: 150,
        },
        claims,
      ),
    );
  } else {
    out.push(
      finish(
        {
          id: `d:${dateKey}:2`,
          kind: 'daily',
          periodKey: dateKey,
          title: 'Put in the time',
          desc: 'Train for 45 minutes today.',
          icon: '⏱️',
          target: 45,
          progress: Math.round(sessions.reduce((a, x) => a + (x.durationSec ?? 0), 0) / 60),
          unit: 'min',
          xp: 150,
        },
        claims,
      ),
    );
  }
  return out;
}

export function weeklyQuests(wk: string, s: PlayerState, allSessions: Session[], claims: QuestClaim[], settings: Settings): Quest[] {
  const rng = makeRng(`weekly:${wk}`);
  const sessions = allSessions.filter((x) => weekKey(x.date) === wk);
  const out: Quest[] = [];
  const heroLv = s.levels.hero.level;
  const goal = Math.max(1, settings.weeklyGoal);

  out.push(
    finish(
      {
        id: `w:${wk}:0`,
        kind: 'weekly',
        periodKey: wk,
        title: 'Consistency',
        desc: `Train on ${goal} different days this week.`,
        icon: '📆',
        target: goal,
        progress: new Set(sessions.map((x) => x.date)).size,
        unit: 'days',
        xp: 400,
      },
      claims,
    ),
  );

  const target = roundTo(2000 + 300 * heroLv, 100);
  out.push(
    finish(
      {
        id: `w:${wk}:1`,
        kind: 'weekly',
        periodKey: wk,
        title: 'Grind',
        desc: `Earn ${target.toLocaleString('en-US')} XP from sessions this week.`,
        icon: '⚔️',
        target,
        progress: sessions.reduce((a, x) => a + (s.sessionXp[x.id] ?? 0), 0),
        unit: 'xp',
        xp: 500,
      },
      claims,
    ),
  );

  const used = DISCIPLINES.filter((d) => s.totals.byDiscipline[d] > 0);
  const d = pickDiscipline(rng, s);
  if (used.length >= 2 && rng.next() < 0.4) {
    out.push(
      finish(
        {
          id: `w:${wk}:2`,
          kind: 'weekly',
          periodKey: wk,
          title: 'Cross-training',
          desc: 'Log sessions in two different disciplines this week.',
          icon: '🔀',
          target: 2,
          progress: new Set(sessions.map((x) => x.discipline)).size,
          unit: 'disciplines',
          xp: 300,
        },
        claims,
      ),
    );
  } else if (d) {
    const t = dailyTarget(d, s);
    out.push(
      finish(
        {
          id: `w:${wk}:2`,
          kind: 'weekly',
          periodKey: wk,
          title: `${DISCIPLINE_META[d].name} focus`,
          desc: `${DISCIPLINE_META[d].name} volume this week.`,
          icon: t.icon,
          discipline: d,
          target: t.target * 3,
          progress: disciplineProgress(d, sessions),
          unit: t.unit,
          xp: 400,
        },
        claims,
      ),
    );
  } else {
    out.push(
      finish(
        {
          id: `w:${wk}:2`,
          kind: 'weekly',
          periodKey: wk,
          title: 'Hours in',
          desc: 'Train for 3 hours this week.',
          icon: '⏳',
          target: 180,
          progress: Math.round(sessions.reduce((a, x) => a + (x.durationSec ?? 0), 0) / 60),
          unit: 'min',
          xp: 400,
        },
        claims,
      ),
    );
  }

  // Only offered once the player has opted into body tracking.
  if (s.body.entries > 0) {
    out.push(
      finish(
        {
          id: `w:${wk}:3`,
          kind: 'weekly',
          periodKey: wk,
          title: 'Check in',
          desc: 'Log your weight or progress photos this week.',
          icon: '📸',
          target: 1,
          progress: (s.body.weekFlags[wk] ?? 0) > 0 ? 1 : 0,
          unit: 'sessions',
          xp: 150,
        },
        claims,
      ),
    );
  }
  return out;
}
