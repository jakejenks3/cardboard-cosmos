import type { BodyEntry, Discipline, QuestClaim, Session } from './types';
import { DISCIPLINES, DISCIPLINE_META } from './types';
import { baseSessionXp, discLevel, e1rm, gradeLabel, heroLevel, normalizeExercise, PR_BONUS, RANKS, rankForLevel, sessionStats, stageForLevel, STAGES } from './xp';
import type { ChronicleEvent, PlayerState, StreakInfo } from './state';
import { initialState } from './state';
import { ACHIEVEMENTS } from './achievements';
import { ITEMS, RARITY_WEIGHT } from './items';
import { PETS } from './pets';
import { bossAt, WEAK_MULT } from './campaign';
import { makeRng } from './rng';
import { addWeeks, daysBetween, weekKey, weekdayIndex } from './dates';

export interface DeriveInput {
  sessions: Session[];
  claims: QuestClaim[];
  body?: BodyEntry[];
  weeklyGoal: number;
  /** Date key used for the "current" streaks at the end of the replay. */
  today: string;
}

export const DROP_BASE_CHANCE = 0.22;
export const DROP_XP_DIVISOR = 6000;
export const DROP_MAX_CHANCE = 0.6;
export const DROP_PITY = 3;
export const MAX_PR_BONUSES_PER_SESSION = 3;

/** Weekly check-in rewards: each component pays out once per Monday-week. */
export const BODY_BITS = { weight: 1, bodyFat: 2, front: 4, side: 8, back: 16 } as const;
export const BODY_XP = { weight: 60, bodyFat: 20, photo: 15 } as const;

export function bodyEntryReward(flags: number, e: Pick<BodyEntry, 'weightKg' | 'bodyFatPct' | 'photos'>): { xp: number; flags: number } {
  let xp = 0;
  let f = flags;
  const grant = (bit: number, amount: number) => {
    if (!(f & bit)) {
      f |= bit;
      xp += amount;
    }
  };
  if (e.weightKg && e.weightKg > 0) grant(BODY_BITS.weight, BODY_XP.weight);
  if (e.bodyFatPct && e.bodyFatPct > 0) grant(BODY_BITS.bodyFat, BODY_XP.bodyFat);
  if (e.photos?.front) grant(BODY_BITS.front, BODY_XP.photo);
  if (e.photos?.side) grant(BODY_BITS.side, BODY_XP.photo);
  if (e.photos?.back) grant(BODY_BITS.back, BODY_XP.photo);
  return { xp, flags: f };
}

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

function titleCase(str: string): string {
  return str.replace(/\b\w/g, (c) => c.toUpperCase());
}

function chron(s: PlayerState, e: ChronicleEvent) {
  s.chronicle.push(e);
}

function ensureStart(s: PlayerState, date: string) {
  if (s.seen.started) return;
  s.seen.started = true;
  chron(s, { date, kind: 'start', icon: '🌱', title: 'The journey begins', detail: 'Scrawny. Determined. Level 1.' });
}

function addHeroXp(s: PlayerState, date: string, amount: number) {
  if (!amount) return;
  s.xp.hero += amount;
  s.xpByDate[date] = (s.xpByDate[date] ?? 0) + amount;
  s.bests.dayXp = Math.max(s.bests.dayXp, s.xpByDate[date]);
}

function updateRanks(s: PlayerState, date: string) {
  for (const d of DISCIPLINES) {
    const r = rankForLevel(s.levels[d].level);
    if (r > s.ranks[d]) {
      s.ranks[d] = r;
      s.bests.maxRank = Math.max(s.bests.maxRank, r);
      chron(s, { date, kind: 'rank', icon: '🎖️', title: `${DISCIPLINE_META[d].name} rank: ${RANKS[r].name}`, detail: `Reached ${DISCIPLINE_META[d].name.toLowerCase()} level ${RANKS[r].minLevel}.`, discipline: d });
    }
  }
}

// Exercise names that count for the bodyweight-relative strength goals.
const REL_LIFTS = {
  benchRatio: ['bench press', 'bench', 'barbell bench press', 'flat bench press'],
  squatRatio: ['squat', 'back squat', 'barbell squat', 'low bar squat', 'high bar squat'],
  deadliftRatio: ['deadlift', 'conventional deadlift', 'sumo deadlift', 'barbell deadlift'],
} as const;

function updateRatios(s: PlayerState) {
  const bw = s.body.latestWeightKg;
  if (!bw || bw <= 0) return;
  for (const key of Object.keys(REL_LIFTS) as (keyof typeof REL_LIFTS)[]) {
    let best = 0;
    for (const name of REL_LIFTS[key]) best = Math.max(best, s.prs.lifts[name]?.weightKg ?? 0);
    if (best > 0) s.bests[key] = Math.max(s.bests[key], best / bw);
  }
}

/**
 * Resolve everything that can unlock from the current state: achievements
 * (whose XP can trigger more), ranks, condition-based gear and pets, and the
 * level / stage chronicle entries.
 */
function settle(s: PlayerState, date: string, refId?: string) {
  for (let outer = 0; outer < 4; outer++) {
    let changed = false;
    for (let pass = 0; pass < 4; pass++) {
      recomputeLevels(s);
      updateRanks(s, date);
      let any = false;
      for (const ach of ACHIEVEMENTS) {
        if (s.achievements[ach.id]) continue;
        if (ach.check(s)) {
          s.achievements[ach.id] = { at: date, sessionId: refId };
          addHeroXp(s, date, ach.xp);
          chron(s, { date, kind: 'achievement', icon: ach.icon, title: ach.name, detail: ach.desc, ref: ach.id });
          any = true;
          changed = true;
        }
      }
      if (!any) break;
    }
    recomputeLevels(s);
    updateRanks(s, date);
    for (const item of ITEMS) {
      if (s.items[item.id]) continue;
      if (item.unlock.kind === 'unlock' && item.unlock.check(s)) {
        s.items[item.id] = { at: date, sessionId: refId, how: 'unlock' };
        chron(s, { date, kind: 'item', icon: '🔓', title: `Unlocked ${item.name}`, detail: item.unlock.hint, ref: item.id });
        changed = true;
      }
    }
    for (const pet of PETS) {
      if (s.pets[pet.id]) continue;
      if (pet.check(s)) {
        s.pets[pet.id] = { at: date, sessionId: refId };
        chron(s, { date, kind: 'pet', icon: '🐾', title: `${pet.name} the ${pet.species} joined you`, detail: pet.hint, ref: pet.id });
        changed = true;
      }
    }
    if (!changed) break;
  }

  const lv = s.levels.hero.level;
  if (lv > s.seen.heroLevel) {
    for (let l = s.seen.heroLevel + 1; l <= lv; l++) {
      if (l % 5 === 0) chron(s, { date, kind: 'level', icon: '⭐', title: `Hero level ${l}` });
    }
    s.seen.heroLevel = lv;
  }
  const t = computeTitle(s);
  if (t.stage > s.seen.stage) {
    for (let st = s.seen.stage + 1; st <= t.stage; st++) {
      chron(s, { date, kind: 'stage', icon: '🧬', title: `Body evolved: ${STAGES[st].name}`, detail: STAGES[st].blurb });
    }
    s.seen.stage = t.stage;
  }
  s.title = t.title;
  s.dominant = t.dominant;
  s.stage = t.stage;
}

function dealDamage(s: PlayerState, session: Session, xp: number) {
  let pool = xp;
  let dealt = 0;
  for (let guard = 0; guard < 30 && pool > 0; guard++) {
    const boss = bossAt(s.campaign.index);
    const mult = boss.weak === session.discipline ? WEAK_MULT : 1;
    const remaining = boss.hp - s.campaign.damage;
    const potential = Math.round(pool * mult);
    if (potential >= remaining) {
      dealt += remaining;
      pool -= Math.ceil(remaining / mult);
      s.campaign.defeated[boss.id] = { at: session.date, sessionId: session.id };
      s.campaign.index++;
      s.campaign.damage = 0;
      addHeroXp(s, session.date, boss.xp);
      chron(s, { date: session.date, kind: 'boss', icon: boss.zoneBoss ? '👑' : '⚔️', title: `Defeated ${boss.name}`, detail: boss.epithet, ref: boss.id });
    } else {
      s.campaign.damage += potential;
      dealt += potential;
      pool = 0;
    }
  }
  s.campaign.totalDamage += dealt;
  s.sessionDamage[session.id] = dealt;
}

function applySession(s: PlayerState, session: Session) {
  ensureStart(s, session.date);
  const st = sessionStats(session);
  const base = baseSessionXp(session).xp;
  let prBonus = 0;
  let prBonusCount = 0;
  let prTotal = 0;
  const prs = s.prs;
  const date = session.date;

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
        const weightUp = bestW > prev.weightKg + 1e-9;
        const improved = weightUp || bestE > prev.e1rm + 1e-6;
        if (improved) {
          prTotal++;
          if (prBonusCount < MAX_PR_BONUSES_PER_SESSION) {
            prBonus += PR_BONUS.liftExercise;
            prBonusCount++;
          }
          prs.lifts[name] = {
            weightKg: Math.max(prev.weightKg, bestW),
            e1rm: Math.max(prev.e1rm, bestE),
            reps: bestE > prev.e1rm ? bestReps : prev.reps,
            date,
          };
          if (weightUp) chron(s, { date, kind: 'pr', icon: '🏋️', title: `${titleCase(name)} PR`, val: { n: bestW, unit: 'kg' }, discipline: 'lift' });
        }
      } else {
        prs.lifts[name] = { weightKg: bestW, e1rm: bestE, reps: bestReps, date };
      }
    }
  } else if (session.discipline === 'climb') {
    if (st.maxGradeSent !== null) {
      if (prs.climbMaxSend !== null && st.maxGradeSent > prs.climbMaxSend) {
        prBonus += PR_BONUS.climbMaxSend;
        prTotal++;
        chron(s, { date, kind: 'pr', icon: '🧗', title: `New max grade: ${gradeLabel(st.maxGradeSent)}`, discipline: 'climb' });
      }
      prs.climbMaxSend = Math.max(prs.climbMaxSend ?? -99, st.maxGradeSent);
    }
    if (st.maxGradeFlashed !== null) {
      if (prs.climbMaxFlash !== null && st.maxGradeFlashed > prs.climbMaxFlash) {
        prBonus += PR_BONUS.climbMaxFlash;
        prTotal++;
      }
      prs.climbMaxFlash = Math.max(prs.climbMaxFlash ?? -99, st.maxGradeFlashed);
    }
  } else if (session.discipline === 'run') {
    if (prs.longestRunM > 0 && st.distanceM > prs.longestRunM) {
      prBonus += PR_BONUS.longestRun;
      prTotal++;
      chron(s, { date, kind: 'pr', icon: '👟', title: 'Longest run', val: { n: st.distanceM, unit: 'm' }, discipline: 'run' });
    }
    prs.longestRunM = Math.max(prs.longestRunM, st.distanceM);
    prs.bestRunElevM = Math.max(prs.bestRunElevM, st.elevationM);
    if (st.distanceM >= 5000 && st.paceSecPerKm !== null) {
      if (prs.bestPaceSecPerKm === null || st.paceSecPerKm < prs.bestPaceSecPerKm) {
        if (prs.bestPaceSecPerKm !== null) prTotal++;
        prs.bestPaceSecPerKm = st.paceSecPerKm;
      }
    }
  } else {
    if (prs.longestRideM > 0 && st.distanceM > prs.longestRideM) {
      prBonus += PR_BONUS.longestRide;
      prTotal++;
      chron(s, { date, kind: 'pr', icon: '🚴', title: 'Longest ride', val: { n: st.distanceM, unit: 'm' }, discipline: 'ride' });
    }
    prs.longestRideM = Math.max(prs.longestRideM, st.distanceM);
    prs.bestRideElevM = Math.max(prs.bestRideElevM, st.elevationM);
    if (st.distanceM >= 20000 && st.speedKmh !== null) {
      if (prs.bestRideSpeedKmh === null || st.speedKmh > prs.bestRideSpeedKmh) {
        if (prs.bestRideSpeedKmh !== null) prTotal++;
        prs.bestRideSpeedKmh = st.speedKmh;
      }
    }
  }

  // --- XP -------------------------------------------------------------------
  const xp = Math.round(base * (1 + (session.bonusPct ?? 0))) + prBonus;
  s.xp[session.discipline] += xp;
  s.sessionXp[session.id] = xp;
  addHeroXp(s, date, xp);

  // --- totals ---------------------------------------------------------------
  const t = s.totals;
  const b = s.bests;
  t.sessions++;
  t.byDiscipline[session.discipline]++;
  t.durationSec += st.durationSec;
  s.dateCounts[date] = (s.dateCounts[date] ?? 0) + 1;
  if (s.dateCounts[date] === 1) t.activeDays++;
  b.daySessions = Math.max(b.daySessions, s.dateCounts[date]);
  b.sessionDurationSec = Math.max(b.sessionDurationSec, st.durationSec);
  b.sessionPrs = Math.max(b.sessionPrs, prTotal);
  if (session.discipline === 'lift') {
    t.liftVolumeKg += st.volumeKg;
    t.liftReps += st.reps;
    t.liftSets += st.sets;
    for (const n of st.exerciseNames) t.liftExercises[n] = true;
    b.maxSetKg = Math.max(b.maxSetKg, st.maxSetKg);
    b.sessionVolumeKg = Math.max(b.sessionVolumeKg, st.volumeKg);
    b.sessionBwReps = Math.max(b.sessionBwReps, st.bwReps);
    updateRatios(s);
  } else if (session.discipline === 'climb') {
    t.climbSends += st.sends;
    t.climbFlashes += st.flashes;
    t.climbAttempts += st.attempts;
    b.sessionSends = Math.max(b.sessionSends, st.sends);
    b.sessionFlashes = Math.max(b.sessionFlashes, st.flashes);
    b.sessionAttempts = Math.max(b.sessionAttempts, st.attempts);
    let vPoints = 0;
    for (const c of session.climbs) if (c.result !== 'attempt') vPoints += Math.max(0, c.grade) * Math.max(0, c.count);
    b.sessionVPoints = Math.max(b.sessionVPoints, vPoints);
  } else if (session.discipline === 'run') {
    t.runDistanceM += st.distanceM;
    t.runElevationM += st.elevationM;
  } else {
    t.rideDistanceM += st.distanceM;
    t.rideElevationM += st.elevationM;
  }

  // --- weeks / months / streak ---------------------------------------------
  const wk = weekKey(date);
  s.weekCounts[wk] = (s.weekCounts[wk] ?? 0) + 1;
  s.weekDays[wk] = (s.weekDays[wk] ?? 0) | (1 << weekdayIndex(date));
  if ((s.weekDays[wk] & 0b1100000) === 0b1100000) b.weekendWarrior = 1;
  s.weekDisc[wk] = (s.weekDisc[wk] ?? 0) | (1 << DISCIPLINES.indexOf(session.discipline));
  let bits = s.weekDisc[wk];
  let nDisc = 0;
  while (bits) {
    nDisc += bits & 1;
    bits >>= 1;
  }
  b.weekDisciplines = Math.max(b.weekDisciplines, nDisc);
  const month = date.slice(0, 7);
  s.monthCounts[month] = (s.monthCounts[month] ?? 0) + 1;
  b.monthSessions = Math.max(b.monthSessions, s.monthCounts[month]);
  if (s.lastSessionDate) {
    if (date > s.lastSessionDate) {
      b.gapDays = Math.max(b.gapDays, daysBetween(s.lastSessionDate, date));
      s.lastSessionDate = date;
    }
  } else {
    s.lastSessionDate = date;
  }
  s.streak = computeStreak(s.weekCounts, s.streak.goal, wk);

  // --- campaign -------------------------------------------------------------
  dealDamage(s, session, xp);

  settle(s, date, session.id);

  // --- loot roll ------------------------------------------------------------
  const rng = makeRng(`drop:${session.id}`);
  const luck = 1 + (session.luckPct ?? 0);
  let chance = Math.min(DROP_MAX_CHANCE, DROP_BASE_CHANCE + xp / DROP_XP_DIVISOR) * luck;
  if (s.sessionsSinceDrop >= DROP_PITY) chance = 1;
  const roll = rng.next();
  const heroLv = s.levels.hero.level;
  const pool = ITEMS.filter((i) => i.unlock.kind === 'drop' && !s.items[i.id] && (i.unlock.minHeroLevel ?? 0) <= heroLv);
  if (pool.length && roll < chance) {
    const picked = rng.weighted(pool, (i) => {
      const r = RARITY_WEIGHT[i.rarity];
      const dm = !i.discipline ? 1.5 : i.discipline === session.discipline ? 3 : 0.4;
      return r * dm;
    });
    if (picked) {
      s.items[picked.id] = { at: date, sessionId: session.id, how: 'drop' };
      s.sessionsSinceDrop = 0;
      chron(s, { date, kind: 'item', icon: '🎁', title: `Found ${picked.name}`, detail: picked.flavor, ref: picked.id });
      settle(s, date, session.id);
    }
  } else if (pool.length) {
    s.sessionsSinceDrop++;
  }
}

function bodyStreak(s: PlayerState, nowWeek: string): StreakInfo {
  const counts: Record<string, number> = {};
  for (const [wk, flags] of Object.entries(s.body.weekFlags)) if (flags) counts[wk] = 1;
  return computeStreak(counts, 1, nowWeek);
}

function applyBody(s: PlayerState, e: BodyEntry) {
  ensureStart(s, e.date);
  const b = s.body;
  b.entries++;
  const wk = weekKey(e.date);
  const r = bodyEntryReward(b.weekFlags[wk] ?? 0, e);
  if (r.flags) b.weekFlags[wk] = r.flags;

  if (e.weightKg && e.weightKg > 0) {
    b.weightEntries++;
    if (b.firstWeightDate === null) chron(s, { date: e.date, kind: 'body', icon: '⚖️', title: 'First weigh-in', val: { n: e.weightKg, unit: 'kg' } });
    if (b.firstWeightDate === null || e.date < b.firstWeightDate) {
      b.firstWeightDate = e.date;
      b.firstWeightKg = e.weightKg;
    }
    if (b.latestWeightDate === null || e.date >= b.latestWeightDate) {
      b.latestWeightDate = e.date;
      b.latestWeightKg = e.weightKg;
    }
  }
  if (e.bodyFatPct && e.bodyFatPct > 0) {
    b.bfEntries++;
    if (b.latestBodyFatDate === null || e.date >= b.latestBodyFatDate) {
      b.latestBodyFatDate = e.date;
      b.latestBodyFat = e.bodyFatPct;
    }
  }
  const nPhotos = (e.photos?.front ? 1 : 0) + (e.photos?.side ? 1 : 0) + (e.photos?.back ? 1 : 0);
  if (nPhotos > 0) b.photoEntries++;
  if (nPhotos === 3) {
    b.fullSets++;
    chron(s, { date: e.date, kind: 'body', icon: '📸', title: 'Progress photos taken', detail: 'Front, side and back.', ref: e.id });
  }
  const st = bodyStreak(s, wk);
  b.streak = st.current;
  b.bestStreak = Math.max(b.bestStreak, st.best);

  s.bodyXp[e.id] = r.xp;
  addHeroXp(s, e.date, r.xp);
  updateRatios(s);
  settle(s, e.date, e.id);
}

function applyClaim(s: PlayerState, claim: QuestClaim) {
  addHeroXp(s, claim.date, claim.xp);
  settle(s, claim.date, claim.id);
}

export function derive(input: DeriveInput): PlayerState {
  const s = initialState(input.weeklyGoal);
  for (const item of ITEMS) {
    if (item.unlock.kind === 'start') s.items[item.id] = { at: '', how: 'start' };
  }
  type Step = { t: number; session?: Session; claim?: QuestClaim; body?: BodyEntry };
  const steps: Step[] = [
    ...input.sessions.map((session) => ({ t: session.createdAt, session })),
    ...input.claims.map((claim) => ({ t: claim.claimedAt, claim })),
    ...(input.body ?? []).map((body) => ({ t: body.createdAt, body })),
  ].sort((a, b) => a.t - b.t);
  for (const step of steps) {
    if (step.session) applySession(s, step.session);
    else if (step.claim) applyClaim(s, step.claim);
    else if (step.body) applyBody(s, step.body);
  }
  const nowWeek = weekKey(input.today);
  s.streak = computeStreak(s.weekCounts, input.weeklyGoal, nowWeek);
  s.body.streak = bodyStreak(s, nowWeek).current;
  if (steps.length === 0) {
    const t = computeTitle(s);
    s.title = t.title;
    s.stage = t.stage;
  }
  return s;
}
