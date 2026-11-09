import type { Discipline, QuestClaim, Session } from './types';
import { DISCIPLINES } from './types';
import {
  baseSessionXp,
  discLevel,
  e1rm,
  heroLevel,
  normalizeExercise,
  PR_BONUS,
  sessionStats,
  stageForLevel,
  STAGES,
} from './xp';
import type { PlayerState, StreakInfo } from './state';
import { initialState } from './state';
import { ACHIEVEMENTS } from './achievements';
import { ITEMS, RARITY_WEIGHT } from './items';
import { PETS } from './pets';
import { makeRng } from './rng';
import { addWeeks, weekKey, weekdayIndex } from './dates';

export interface DeriveInput {
  sessions: Session[];
  claims: QuestClaim[];
  weeklyGoal: number;
  /** Date key used for the "current" streak at the end of the replay. */
  today: string;
}

export const DROP_BASE_CHANCE = 0.22;
export const DROP_XP_DIVISOR = 6000;
export const DROP_MAX_CHANCE = 0.6;
export const DROP_PITY = 3;
export const MAX_PR_BONUSES_PER_SESSION = 3;

export function computeStreak(weekCounts: Record<string, number>, goal: number, nowWeek: string): StreakInfo {
  const count = (wk: string) => weekCounts[wk] ?? 0;
  let current = 0;
  let wk = nowWeek;
  if (count(wk) >= goal) {
    current++;
  }
  wk = addWeeks(wk, -1);
  while (count(wk) >= goal) {
    current++;
    wk = addWeeks(wk, -1);
  }
  let best = 0;
  let run = 0;
  const keys = Object.keys(weekCounts).sort();
  for (const k of keys) {
    if (count(k) >= goal) {
      run = count(addWeeks(k, -1)) >= goal ? run + 1 : 1;
      best = Math.max(best, run);
    }
  }
  return { current, best: Math.max(best, current), thisWeek: count(nowWeek), goal };
}

function recomputeLevels(s: PlayerState) {
  s.levels.hero = heroLevel(s.xp.hero);
  for (const d of DISCIPLINES) s.levels[d] = discLevel(s.xp[d]);
}

const NOUNS: Record<Discipline | 'all', string[]> = {
  lift: ['Lifter', 'Ironhand', 'Powerhouse'],
  climb: ['Climber', 'Crusher', 'Stoneborn'],
  run: ['Runner', 'Pacer', 'Windstrider'],
  ride: ['Rider', 'Rouleur', 'Wheelborn'],
  all: ['All-Rounder', 'Polymath', 'Paragon'],
};

export function computeTitle(s: PlayerState): { title: string; dominant: Discipline | null; stage: number } {
  const stage = stageForLevel(s.levels.hero.level);
  const adj = STAGES[stage].name;
  if (s.totals.sessions === 0) return { title: `${adj} Newcomer`, dominant: null, stage };
  const total = DISCIPLINES.reduce((a, d) => a + s.xp[d], 0);
  let dominant: Discipline | null = null;
  let max = 0;
  for (const d of DISCIPLINES) {
    if (s.xp[d] > max) {
      max = s.xp[d];
      dominant = d;
    }
  }
  const used = DISCIPLINES.filter((d) => s.totals.byDiscipline[d] > 0).length;
  const share = total > 0 ? max / total : 0;
  const key: Discipline | 'all' = used >= 2 && share < 0.55 ? 'all' : dominant ?? 'all';
  const tier = stage <= 1 ? 0 : stage <= 3 ? 1 : 2;
  return { title: `${adj} ${NOUNS[key][tier]}`, dominant: key === 'all' ? null : dominant, stage };
}

function applySession(s: PlayerState, session: Session) {
  const st = sessionStats(session);
  const base = baseSessionXp(session).xp;
  let prBonus = 0;
  let prCount = 0;
  const prs = s.prs;

  // --- PR detection ---------------------------------------------------------
  if (session.discipline === 'lift') {
    for (const ex of session.exercises) {
      const name = normalizeExercise(ex.name);
      if (!name) continue;
      let bestW = 0;
      let bestE = 0;
      let bestReps = 0;
      for (const set of ex.sets) {
        if (set.weightKg <= 0 || set.reps <= 0) continue;
        bestW = Math.max(bestW, set.weightKg);
        const e = e1rm(set.weightKg, set.reps);
        if (e > bestE) {
          bestE = e;
          bestReps = set.reps;
        }
      }
      if (bestW <= 0) continue;
      const prev = prs.lifts[name];
      if (prev) {
        const improved = bestW > prev.weightKg + 1e-9 || bestE > prev.e1rm + 1e-6;
        if (improved && prCount < MAX_PR_BONUSES_PER_SESSION) {
          prBonus += PR_BONUS.liftExercise;
          prCount++;
        }
        if (improved) {
          prs.lifts[name] = {
            weightKg: Math.max(prev.weightKg, bestW),
            e1rm: Math.max(prev.e1rm, bestE),
            reps: bestE > prev.e1rm ? bestReps : prev.reps,
            date: session.date,
          };
        }
      } else {
        prs.lifts[name] = { weightKg: bestW, e1rm: bestE, reps: bestReps, date: session.date };
      }
    }
  } else if (session.discipline === 'climb') {
    if (st.maxGradeSent !== null) {
      if (prs.climbMaxSend !== null && st.maxGradeSent > prs.climbMaxSend) prBonus += PR_BONUS.climbMaxSend;
      prs.climbMaxSend = Math.max(prs.climbMaxSend ?? -99, st.maxGradeSent);
    }
    if (st.maxGradeFlashed !== null) {
      if (prs.climbMaxFlash !== null && st.maxGradeFlashed > prs.climbMaxFlash) prBonus += PR_BONUS.climbMaxFlash;
      prs.climbMaxFlash = Math.max(prs.climbMaxFlash ?? -99, st.maxGradeFlashed);
    }
  } else if (session.discipline === 'run') {
    if (prs.longestRunM > 0 && st.distanceM > prs.longestRunM) prBonus += PR_BONUS.longestRun;
    prs.longestRunM = Math.max(prs.longestRunM, st.distanceM);
    prs.bestRunElevM = Math.max(prs.bestRunElevM, st.elevationM);
    if (st.distanceM >= 5000 && st.paceSecPerKm !== null) {
      if (prs.bestPaceSecPerKm === null || st.paceSecPerKm < prs.bestPaceSecPerKm) prs.bestPaceSecPerKm = st.paceSecPerKm;
    }
  } else {
    if (prs.longestRideM > 0 && st.distanceM > prs.longestRideM) prBonus += PR_BONUS.longestRide;
    prs.longestRideM = Math.max(prs.longestRideM, st.distanceM);
    prs.bestRideElevM = Math.max(prs.bestRideElevM, st.elevationM);
    if (st.distanceM >= 20000 && st.speedKmh !== null) {
      if (prs.bestRideSpeedKmh === null || st.speedKmh > prs.bestRideSpeedKmh) prs.bestRideSpeedKmh = st.speedKmh;
    }
  }

  // --- XP -------------------------------------------------------------------
  const xp = Math.round(base * (1 + (session.bonusPct ?? 0))) + prBonus;
  s.xp[session.discipline] += xp;
  s.xp.hero += xp;
  s.sessionXp[session.id] = xp;
  s.xpByDate[session.date] = (s.xpByDate[session.date] ?? 0) + xp;

  // --- totals ---------------------------------------------------------------
  const t = s.totals;
  t.sessions++;
  t.byDiscipline[session.discipline]++;
  t.durationSec += st.durationSec;
  s.dateCounts[session.date] = (s.dateCounts[session.date] ?? 0) + 1;
  if (s.dateCounts[session.date] === 1) t.activeDays++;
  if (session.discipline === 'lift') {
    t.liftVolumeKg += st.volumeKg;
    t.liftReps += st.reps;
    t.liftSets += st.sets;
    for (const n of st.exerciseNames) t.liftExercises[n] = true;
  } else if (session.discipline === 'climb') {
    t.climbSends += st.sends;
    t.climbFlashes += st.flashes;
    t.climbAttempts += st.attempts;
  } else if (session.discipline === 'run') {
    t.runDistanceM += st.distanceM;
    t.runElevationM += st.elevationM;
  } else {
    t.rideDistanceM += st.distanceM;
    t.rideElevationM += st.elevationM;
  }

  // --- weeks / streak -------------------------------------------------------
  const wk = weekKey(session.date);
  s.weekCounts[wk] = (s.weekCounts[wk] ?? 0) + 1;
  s.weekDays[wk] = (s.weekDays[wk] ?? 0) | (1 << weekdayIndex(session.date));
  s.streak = computeStreak(s.weekCounts, s.streak.goal, wk);

  recomputeLevels(s);

  // --- achievements (loop: an unlock's XP can trigger level-based ones) -----
  for (let pass = 0; pass < 3; pass++) {
    let any = false;
    for (const ach of ACHIEVEMENTS) {
      if (s.achievements[ach.id]) continue;
      if (ach.check({ s, session, st })) {
        s.achievements[ach.id] = { at: session.date, sessionId: session.id };
        s.xp.hero += ach.xp;
        s.xpByDate[session.date] = (s.xpByDate[session.date] ?? 0) + ach.xp;
        any = true;
      }
    }
    recomputeLevels(s);
    if (!any) break;
  }

  // --- condition-based items & pets -----------------------------------------
  for (const item of ITEMS) {
    if (s.items[item.id]) continue;
    if (item.unlock.kind === 'unlock' && item.unlock.check(s)) {
      s.items[item.id] = { at: session.date, sessionId: session.id, how: 'unlock' };
    }
  }
  for (const pet of PETS) {
    if (s.pets[pet.id]) continue;
    if (pet.check(s)) s.pets[pet.id] = { at: session.date, sessionId: session.id };
  }

  // --- loot roll ------------------------------------------------------------
  const rng = makeRng(`drop:${session.id}`);
  const luck = 1 + (session.luckPct ?? 0);
  let chance = Math.min(DROP_MAX_CHANCE, DROP_BASE_CHANCE + xp / DROP_XP_DIVISOR) * luck;
  if (s.sessionsSinceDrop >= DROP_PITY) chance = 1;
  const roll = rng.next();
  const heroLv = s.levels.hero.level;
  const pool = ITEMS.filter(
    (i) => i.unlock.kind === 'drop' && !s.items[i.id] && (i.unlock.minHeroLevel ?? 0) <= heroLv,
  );
  if (pool.length && roll < chance) {
    const picked = rng.weighted(pool, (i) => {
      const r = RARITY_WEIGHT[i.rarity];
      const dm = !i.discipline ? 1.5 : i.discipline === session.discipline ? 3 : 0.4;
      return r * dm;
    });
    if (picked) {
      s.items[picked.id] = { at: session.date, sessionId: session.id, how: 'drop' };
      s.sessionsSinceDrop = 0;
    }
  } else if (pool.length) {
    s.sessionsSinceDrop++;
  }

  const t2 = computeTitle(s);
  s.title = t2.title;
  s.dominant = t2.dominant;
  s.stage = t2.stage;
}

function applyClaim(s: PlayerState, claim: QuestClaim) {
  s.xp.hero += claim.xp;
  s.xpByDate[claim.date] = (s.xpByDate[claim.date] ?? 0) + claim.xp;
  recomputeLevels(s);
  const t2 = computeTitle(s);
  s.title = t2.title;
  s.dominant = t2.dominant;
  s.stage = t2.stage;
}

export function derive(input: DeriveInput): PlayerState {
  const s = initialState(input.weeklyGoal);
  for (const item of ITEMS) {
    if (item.unlock.kind === 'start') s.items[item.id] = { at: '', how: 'start' };
  }
  type Step = { t: number; session?: Session; claim?: QuestClaim };
  const steps: Step[] = [
    ...input.sessions.map((session) => ({ t: session.createdAt, session })),
    ...input.claims.map((claim) => ({ t: claim.claimedAt, claim })),
  ].sort((a, b) => a.t - b.t);
  for (const step of steps) {
    if (step.session) applySession(s, step.session);
    else if (step.claim) applyClaim(s, step.claim);
  }
  s.streak = computeStreak(s.weekCounts, input.weeklyGoal, weekKey(input.today));
  if (s.totals.sessions === 0) {
    const t2 = computeTitle(s);
    s.title = t2.title;
    s.stage = t2.stage;
  }
  return s;
}
