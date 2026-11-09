import type { Discipline } from './types';
import { DISCIPLINES } from './types';
import type { PlayerState } from './state';
import { defeatedCount, ownedItemCount, ownedPetCount } from './state';
import { atLeast, type Goal, type ProgressUnit } from './goals';

export type AchGroup = Discipline | 'general' | 'campaign' | 'body' | 'collection';

export const ACH_GROUPS: { id: AchGroup; name: string; icon: string }[] = [
  { id: 'general', name: 'General', icon: '⭐' },
  { id: 'lift', name: 'Lifting', icon: '🏋️' },
  { id: 'climb', name: 'Climbing', icon: '🧗' },
  { id: 'run', name: 'Running', icon: '👟' },
  { id: 'ride', name: 'Cycling', icon: '🚴' },
  { id: 'campaign', name: 'Adventure', icon: '⚔️' },
  { id: 'body', name: 'Body', icon: '📸' },
  { id: 'collection', name: 'Collection', icon: '🎒' },
];

export interface AchievementDef extends Goal {
  id: string;
  name: string;
  desc: string;
  icon: string;
  xp: number;
  group: AchGroup;
  /** Hide the description until unlocked. */
  secret?: boolean;
}

export type Tier = 'bronze' | 'silver' | 'gold' | 'platinum';
export const TIER_COLOR: Record<Tier, string> = { bronze: '#c98a5a', silver: '#c9d1d9', gold: '#ffc83d', platinum: '#7fe7ff' };
export function tierOf(a: AchievementDef): Tier {
  return a.xp <= 150 ? 'bronze' : a.xp <= 400 ? 'silver' : a.xp <= 800 ? 'gold' : 'platinum';
}

type Get = (s: PlayerState) => number;

/** Threshold achievement with a progress bar. */
const g = (id: string, name: string, desc: string, icon: string, xp: number, group: AchGroup, get: Get, target: number, unit: ProgressUnit = 'count', secret = false): AchievementDef => ({
  id,
  name,
  desc,
  icon,
  xp,
  group,
  secret,
  ...atLeast(get, target, unit),
});

/** Custom-condition achievement (no progress bar). */
const c = (id: string, name: string, desc: string, icon: string, xp: number, group: AchGroup, check: (s: PlayerState) => boolean, secret = false): AchievementDef => ({
  id,
  name,
  desc,
  icon,
  xp,
  group,
  secret,
  check,
});

const disciplinesUsed: Get = (s) => DISCIPLINES.filter((d) => s.totals.byDiscipline[d] > 0).length;
const minDiscLevel: Get = (s) => Math.min(...DISCIPLINES.map((d) => s.levels[d].level));
const maxSend: Get = (s) => s.prs.climbMaxSend ?? -2;
const maxFlash: Get = (s) => s.prs.climbMaxFlash ?? -2;

export const ACHIEVEMENTS: AchievementDef[] = [
  // --- first steps -------------------------------------------------------
  g('first_session', 'First Step', 'Log your very first session.', '🥾', 100, 'general', (s) => s.totals.sessions, 1),
  g('first_lift', 'Iron Curious', 'Log a lifting session.', '🏋️', 100, 'lift', (s) => s.totals.byDiscipline.lift, 1),
  g('first_climb', 'Chalk Up', 'Log a climbing session.', '🧗', 100, 'climb', (s) => s.totals.byDiscipline.climb, 1),
  g('first_run', 'Lace Up', 'Log a run.', '👟', 100, 'run', (s) => s.totals.byDiscipline.run, 1),
  g('first_ride', 'Clip In', 'Log a ride.', '🚴', 100, 'ride', (s) => s.totals.byDiscipline.ride, 1),
  g('all_four', 'Jack of All Trades', 'Log a session in all four disciplines.', '🃏', 300, 'general', disciplinesUsed, 4),

  // --- consistency -------------------------------------------------------
  g('sessions_10', 'Regular', 'Log 10 sessions.', '📅', 200, 'general', (s) => s.totals.sessions, 10),
  g('sessions_50', 'Dedicated', 'Log 50 sessions.', '🗓️', 300, 'general', (s) => s.totals.sessions, 50),
  g('sessions_100', 'Centurion', 'Log 100 sessions.', '💯', 500, 'general', (s) => s.totals.sessions, 100),
  g('sessions_365', 'Year of Sweat', 'Log 365 sessions.', '🏆', 1000, 'general', (s) => s.totals.sessions, 365),
  g('active_days_100', 'Hundred Days', 'Train on 100 different days.', '🌅', 500, 'general', (s) => s.totals.activeDays, 100),
  g('hours_100', 'Hundred Hours', 'Train for 100 hours in total.', '⌛', 600, 'general', (s) => s.totals.durationSec / 60, 6000, 'min'),
  g('double_day', 'Two-a-Day', 'Log two sessions on the same day.', '🔁', 150, 'general', (s) => s.bests.daySessions, 2),
  g('weekend_warrior', 'Weekend Warrior', 'Train on both Saturday and Sunday of the same week.', '🛡️', 150, 'general', (s) => s.bests.weekendWarrior, 1),
  g('week_3_disc', 'Triple Threat', 'Train three different disciplines in one week.', '🔱', 200, 'general', (s) => s.bests.weekDisciplines, 3),
  g('week_4_disc', 'Full House', 'Train all four disciplines in one week.', '🎰', 400, 'general', (s) => s.bests.weekDisciplines, 4),
  g('month_12', 'Monthly Regular', 'Log 12 sessions in one calendar month.', '🗓️', 300, 'general', (s) => s.bests.monthSessions, 12),
  g('month_20', 'Machine', 'Log 20 sessions in one calendar month.', '🤖', 600, 'general', (s) => s.bests.monthSessions, 20),
  g('streak_4', 'On a Roll', 'Hit your weekly goal 4 weeks in a row.', '🔥', 200, 'general', (s) => s.streak.best, 4, 'weeks'),
  g('streak_12', 'Unbreakable', 'Hit your weekly goal 12 weeks in a row.', '🔥', 500, 'general', (s) => s.streak.best, 12, 'weeks'),
  g('streak_26', 'Half-Year Hero', 'Hit your weekly goal 26 weeks in a row.', '🔥', 800, 'general', (s) => s.streak.best, 26, 'weeks'),
  g('streak_52', 'Iron Will', 'Hit your weekly goal 52 weeks in a row.', '🔥', 1500, 'general', (s) => s.streak.best, 52, 'weeks'),
  g('big_day', 'Big Day', 'Earn 3,000 XP in a single day.', '☀️', 200, 'general', (s) => s.bests.dayXp, 3000, 'xp'),
  g('long_session', 'Marathon Session', 'Log a session lasting 2 hours or more.', '⏳', 150, 'general', (s) => s.bests.sessionDurationSec / 60, 120, 'min'),
  g('hat_trick', 'Hat Trick', 'Set three personal records in a single session.', '🎩', 300, 'general', (s) => s.bests.sessionPrs, 3),
  g('comeback', 'Comeback Kid', 'Come back and log a session after two weeks away. The door is always open.', '🚪', 200, 'general', (s) => s.bests.gapDays, 14, 'count', true),

  // --- lifting -----------------------------------------------------------
  g('lift_60', 'One Plate', 'Lift 60 kg in a set.', '🍽️', 100, 'lift', (s) => s.bests.maxSetKg, 60, 'kg'),
  g('lift_100', 'Two Plates', 'Lift 100 kg in a set.', '🍽️', 200, 'lift', (s) => s.bests.maxSetKg, 100, 'kg'),
  g('lift_140', 'Three Plates', 'Lift 140 kg in a set.', '🍽️', 300, 'lift', (s) => s.bests.maxSetKg, 140, 'kg'),
  g('lift_180', 'Four Plates', 'Lift 180 kg in a set.', '🍽️', 400, 'lift', (s) => s.bests.maxSetKg, 180, 'kg'),
  g('lift_220', 'Five Plates', 'Lift 220 kg in a set.', '🍽️', 600, 'lift', (s) => s.bests.maxSetKg, 220, 'kg'),
  g('lift_session_10t', 'Ten Tonnes', 'Move 10,000 kg in one session.', '🐘', 200, 'lift', (s) => s.bests.sessionVolumeKg, 10000, 'kg'),
  g('lift_session_20t', 'Twenty Tonnes', 'Move 20,000 kg in one session.', '🐘', 350, 'lift', (s) => s.bests.sessionVolumeKg, 20000, 'kg'),
  g('lift_total_100k', '100 Tonne Club', 'Lift 100,000 kg lifetime.', '⚙️', 300, 'lift', (s) => s.totals.liftVolumeKg, 100000, 'kg'),
  g('lift_total_500k', 'Half-Million Club', 'Lift 500,000 kg lifetime.', '⚙️', 600, 'lift', (s) => s.totals.liftVolumeKg, 500000, 'kg'),
  g('lift_total_1m', 'Million Kilo Club', 'Lift 1,000,000 kg lifetime.', '⚙️', 1200, 'lift', (s) => s.totals.liftVolumeKg, 1000000, 'kg'),
  g('lift_reps_1000', 'Thousand Reps', '1,000 weighted reps lifetime.', '🔢', 200, 'lift', (s) => s.totals.liftReps, 1000),
  g('lift_reps_10000', 'Ten Thousand Reps', '10,000 weighted reps lifetime.', '🔢', 700, 'lift', (s) => s.totals.liftReps, 10000),
  g('lift_variety', 'Variety Pack', 'Log 10 different exercises.', '🎒', 150, 'lift', (s) => Object.keys(s.totals.liftExercises).length, 10),
  g('lift_bw_100', 'Calisthenics Curious', '100 bodyweight reps in a session.', '🤸', 150, 'lift', (s) => s.bests.sessionBwReps, 100),
  g('rel_bench_1', 'Bodyweight Bench', 'Bench press your own bodyweight. Needs a logged body weight.', '⚖️', 300, 'lift', (s) => s.bests.benchRatio, 1, 'ratio'),
  g('rel_squat_15', 'Squat Rack Citizen', 'Squat 1.5× your bodyweight.', '⚖️', 400, 'lift', (s) => s.bests.squatRatio, 1.5, 'ratio'),
  g('rel_deadlift_2', 'Double Bodyweight Pull', 'Deadlift 2× your bodyweight.', '⚖️', 500, 'lift', (s) => s.bests.deadliftRatio, 2, 'ratio'),
  g('rel_bench_15', 'Bench Boss', 'Bench press 1.5× your bodyweight.', '⚖️', 800, 'lift', (s) => s.bests.benchRatio, 1.5, 'ratio'),
  g('rel_squat_2', 'Double Bodyweight Squat', 'Squat 2× your bodyweight.', '⚖️', 900, 'lift', (s) => s.bests.squatRatio, 2, 'ratio'),
  g('rel_deadlift_25', 'Gravity Is Optional', 'Deadlift 2.5× your bodyweight.', '⚖️', 1000, 'lift', (s) => s.bests.deadliftRatio, 2.5, 'ratio'),

  // --- climbing ----------------------------------------------------------
  g('climb_v2', 'Getting Grippy', 'Send a V2.', '🪨', 100, 'climb', maxSend, 2, 'grade'),
  g('climb_v4', 'Crimp Master', 'Send a V4.', '🪨', 200, 'climb', maxSend, 4, 'grade'),
  g('climb_v6', 'Project Crusher', 'Send a V6.', '🪨', 350, 'climb', maxSend, 6, 'grade'),
  g('climb_v8', 'Stone Cold', 'Send a V8.', '🪨', 600, 'climb', maxSend, 8, 'grade'),
  g('climb_v10', 'Double Digits', 'Send a V10.', '💎', 1000, 'climb', maxSend, 10, 'grade'),
  g('climb_v12', 'Mythic', 'Send a V12.', '💎', 1500, 'climb', maxSend, 12, 'grade'),
  g('climb_flash_v4', 'Flash Bang', 'Flash a V4.', '⚡', 250, 'climb', maxFlash, 4, 'grade'),
  g('climb_flash_v6', 'Lightning Hands', 'Flash a V6.', '⚡', 500, 'climb', maxFlash, 6, 'grade'),
  g('climb_sends_100', 'Hundred Sends', '100 sends lifetime.', '🧮', 300, 'climb', (s) => s.totals.climbSends, 100),
  g('climb_sends_500', 'Five Hundred Sends', '500 sends lifetime.', '🧮', 500, 'climb', (s) => s.totals.climbSends, 500),
  g('climb_sends_1000', 'Thousand Sends', '1,000 sends lifetime.', '🧮', 1000, 'climb', (s) => s.totals.climbSends, 1000),
  g('climb_flashes_100', 'Lightning Rod', '100 flashes lifetime.', '🌩️', 400, 'climb', (s) => s.totals.climbFlashes, 100),
  g('climb_pump', 'Pump City', '20 sends in one session.', '💪', 200, 'climb', (s) => s.bests.sessionSends, 20),
  g('climb_flash_flood', 'Flash Flood', '10 flashes in one session.', '🌊', 250, 'climb', (s) => s.bests.sessionFlashes, 10),
  g('climb_vpoints_50', 'V-Point Hoarder', 'Send 50 V-points in one session (a V4 is 4 points).', '🧺', 300, 'climb', (s) => s.bests.sessionVPoints, 50),
  g('climb_project', 'Project Mode', '10 attempts in one session. Respect the process.', '🧠', 100, 'climb', (s) => s.bests.sessionAttempts, 10),

  // --- running -----------------------------------------------------------
  g('run_5k', 'Parkrun', 'Run 5 km in one go.', '🏃', 100, 'run', (s) => s.prs.longestRunM, 5000, 'm'),
  g('run_10k', 'Ten K', 'Run 10 km in one go.', '🏃', 200, 'run', (s) => s.prs.longestRunM, 10000, 'm'),
  g('run_half', 'Half Marathon', 'Run 21.1 km in one go.', '🎽', 500, 'run', (s) => s.prs.longestRunM, 21097, 'm'),
  g('run_marathon', 'Marathon', 'Run 42.2 km in one go.', '🏅', 1200, 'run', (s) => s.prs.longestRunM, 42195, 'm'),
  g('run_total_100', 'Century', 'Run 100 km lifetime.', '🛣️', 300, 'run', (s) => s.totals.runDistanceM, 100000, 'm'),
  g('run_total_500', 'Road Warrior', 'Run 500 km lifetime.', '🛣️', 600, 'run', (s) => s.totals.runDistanceM, 500000, 'm'),
  g('run_total_1000', 'Thousand K', 'Run 1,000 km lifetime.', '🛣️', 1200, 'run', (s) => s.totals.runDistanceM, 1000000, 'm'),
  g('run_sessions_50', 'Fifty Runs', 'Log 50 runs.', '👟', 400, 'run', (s) => s.totals.byDiscipline.run, 50),
  c('run_pace_5', 'Speed Demon', 'Average 5:00 /km or faster over 5 km+.', '💨', 250, 'run', (s) => s.prs.bestPaceSecPerKm !== null && s.prs.bestPaceSecPerKm <= 300),
  c('run_pace_4', 'Rocket Legs', 'Average 4:00 /km or faster over 5 km+.', '🚀', 500, 'run', (s) => s.prs.bestPaceSecPerKm !== null && s.prs.bestPaceSecPerKm <= 240),
  g('run_elev_500', 'Hill Hunter', 'Climb 500 m of elevation in one run.', '⛰️', 200, 'run', (s) => s.prs.bestRunElevM, 500, 'elev'),
  g('run_elev_total_5000', 'Vert Collector', 'Climb 5,000 m of elevation lifetime on foot.', '🗻', 500, 'run', (s) => s.totals.runElevationM, 5000, 'elev'),

  // --- cycling -----------------------------------------------------------
  g('ride_25', 'Quarter Century', 'Ride 25 km in one go.', '🚲', 100, 'ride', (s) => s.prs.longestRideM, 25000, 'm'),
  g('ride_50', 'Half Century', 'Ride 50 km in one go.', '🚲', 200, 'ride', (s) => s.prs.longestRideM, 50000, 'm'),
  g('ride_100', 'Century Ride', 'Ride 100 km in one go.', '🚲', 500, 'ride', (s) => s.prs.longestRideM, 100000, 'm'),
  g('ride_160', 'Imperial Century', 'Ride 160 km (100 miles) in one go.', '👑', 800, 'ride', (s) => s.prs.longestRideM, 160934, 'm'),
  g('ride_total_500', 'Rolling', 'Ride 500 km lifetime.', '🛞', 300, 'ride', (s) => s.totals.rideDistanceM, 500000, 'm'),
  g('ride_total_2000', 'Touring', 'Ride 2,000 km lifetime.', '🛞', 600, 'ride', (s) => s.totals.rideDistanceM, 2000000, 'm'),
  g('ride_total_5000', 'Grand Tour', 'Ride 5,000 km lifetime.', '🛞', 1200, 'ride', (s) => s.totals.rideDistanceM, 5000000, 'm'),
  g('ride_sessions_50', 'Fifty Rides', 'Log 50 rides.', '🚴', 400, 'ride', (s) => s.totals.byDiscipline.ride, 50),
  g('ride_elev_1000', 'Mountain Goat', 'Climb 1,000 m of elevation in one ride.', '🐐', 300, 'ride', (s) => s.prs.bestRideElevM, 1000, 'elev'),
  g('ride_everest', 'Everested', 'Climb 8,848 m of elevation lifetime on the bike.', '🏔️', 500, 'ride', (s) => s.totals.rideElevationM, 8848, 'elev'),
  c('ride_speed_30', 'Fast Wheels', 'Average 30 km/h over a 20 km+ ride.', '💨', 300, 'ride', (s) => s.prs.bestRideSpeedKmh !== null && s.prs.bestRideSpeedKmh >= 30),

  // --- hero --------------------------------------------------------------
  g('hero_10', 'Rising Hero', 'Reach hero level 10.', '⭐', 200, 'general', (s) => s.levels.hero.level, 10, 'level'),
  g('hero_25', 'Seasoned Hero', 'Reach hero level 25.', '🌟', 500, 'general', (s) => s.levels.hero.level, 25, 'level'),
  g('hero_50', 'Titan', 'Reach hero level 50.', '💫', 1500, 'general', (s) => s.levels.hero.level, 50, 'level'),
  g('hero_75', 'Beyond', 'Reach hero level 75.', '🌌', 2500, 'general', (s) => s.levels.hero.level, 75, 'level'),
  g('balanced_10', 'Well Rounded', 'Reach level 10 in all four disciplines.', '⚖️', 600, 'general', minDiscLevel, 10, 'level'),
  g('rank_journeyman', 'Journeyman', 'Reach the Journeyman rank in any discipline.', '🎖️', 250, 'general', (s) => s.bests.maxRank, 2),
  g('rank_expert', 'Expert', 'Reach the Expert rank in any discipline.', '🎖️', 600, 'general', (s) => s.bests.maxRank, 4),
  g('rank_master', 'Mastery', 'Reach the Master rank in any discipline.', '🏵️', 1200, 'general', (s) => s.bests.maxRank, 5),

  // --- adventure ---------------------------------------------------------
  g('boss_first', 'First Blood', 'Defeat your first boss.', '⚔️', 100, 'campaign', defeatedCount, 1),
  g('zone_1', 'Off the Couch', 'Clear the Couch Kingdom.', '🛋️', 300, 'campaign', defeatedCount, 4),
  g('zone_2', 'Golem Breaker', 'Clear the Iron Foothills.', '🗿', 500, 'campaign', defeatedCount, 8),
  g('zone_3', 'Dragonslayer', 'Clear Chalk Canyon.', '🐉', 700, 'campaign', defeatedCount, 12),
  g('zone_4', 'Through the Wall', 'Clear the Windswept Steppe.', '🧱', 900, 'campaign', defeatedCount, 16),
  g('zone_5', 'King of the Col', 'Clear the Spoke Highlands.', '⛰️', 1200, 'campaign', defeatedCount, 20),
  g('zone_6', 'Titan Ascendant', "Defeat The Old You and clear Titan's Summit.", '👑', 2500, 'campaign', defeatedCount, 24),
  g('damage_100k', 'Heavy Hitter', 'Deal 100,000 total damage.', '💥', 500, 'campaign', (s) => s.campaign.totalDamage, 100000),

  // --- body --------------------------------------------------------------
  g('body_first', 'Baseline', 'Log your body weight for the first time.', '⚖️', 100, 'body', (s) => s.body.weightEntries, 1),
  g('body_bf', 'Know Thyself', 'Log a body fat percentage.', '📏', 100, 'body', (s) => s.body.bfEntries, 1),
  g('body_photos', 'Say Cheese', 'Take a full set of progress photos: front, side and back.', '📸', 200, 'body', (s) => s.body.fullSets, 1),
  g('body_album_5', 'Photo Album', 'Five check-ins with progress photos.', '🖼️', 300, 'body', (s) => s.body.photoEntries, 5),
  g('body_album_20', 'Time-Lapse', 'Twenty check-ins with progress photos.', '🎞️', 800, 'body', (s) => s.body.photoEntries, 20),
  g('body_streak_4', 'Checking In', 'Check in four weeks in a row.', '🗓️', 200, 'body', (s) => s.body.bestStreak, 4, 'weeks'),
  g('body_streak_12', 'Accountable', 'Check in twelve weeks in a row.', '🗓️', 500, 'body', (s) => s.body.bestStreak, 12, 'weeks'),
  g('body_streak_26', 'Half a Year in Frames', 'Check in twenty-six weeks in a row.', '🗓️', 900, 'body', (s) => s.body.bestStreak, 26, 'weeks'),

  // --- collection --------------------------------------------------------
  g('items_10', 'Collector', 'Own 10 pieces of gear.', '🎒', 150, 'collection', ownedItemCount, 10),
  g('items_25', 'Hoarder', 'Own 25 pieces of gear.', '🧳', 400, 'collection', ownedItemCount, 25),
  g('items_45', 'Walking Wardrobe', 'Own 45 pieces of gear.', '🏬', 900, 'collection', ownedItemCount, 45),
  g('pets_5', 'Animal Friend', 'Befriend 5 companions.', '🐾', 200, 'collection', ownedPetCount, 5),
  g('pets_10', 'Zookeeper', 'Befriend 10 companions.', '🦁', 700, 'collection', ownedPetCount, 10),
];

export const ACHIEVEMENT_BY_ID: Record<string, AchievementDef> = Object.fromEntries(ACHIEVEMENTS.map((x) => [x.id, x]));

export function trophyPoints(s: PlayerState): number {
  return ACHIEVEMENTS.reduce((a, x) => a + (s.achievements[x.id] ? x.xp : 0), 0);
}
