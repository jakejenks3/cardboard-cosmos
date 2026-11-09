import type { Discipline } from './types';
import type { AchievementCtx } from './state';

export interface AchievementDef {
  id: string;
  name: string;
  desc: string;
  icon: string;
  xp: number;
  discipline?: Discipline;
  /** Hide the description until unlocked. */
  secret?: boolean;
  check: (c: AchievementCtx) => boolean;
}

const a = (
  id: string,
  name: string,
  desc: string,
  icon: string,
  xp: number,
  check: (c: AchievementCtx) => boolean,
  discipline?: Discipline,
  secret = false,
): AchievementDef => ({ id, name, desc, icon, xp, check, discipline, secret });

const satSun = (1 << 5) | (1 << 6);

export const ACHIEVEMENTS: AchievementDef[] = [
  // --- first steps -------------------------------------------------------
  a('first_session', 'First Step', 'Log your very first session.', '🥾', 100, (c) => c.s.totals.sessions >= 1),
  a('first_lift', 'Iron Curious', 'Log a lifting session.', '🏋️', 100, (c) => c.s.totals.byDiscipline.lift >= 1, 'lift'),
  a('first_climb', 'Chalk Up', 'Log a climbing session.', '🧗', 100, (c) => c.s.totals.byDiscipline.climb >= 1, 'climb'),
  a('first_run', 'Lace Up', 'Log a run.', '👟', 100, (c) => c.s.totals.byDiscipline.run >= 1, 'run'),
  a('first_ride', 'Clip In', 'Log a ride.', '🚴', 100, (c) => c.s.totals.byDiscipline.ride >= 1, 'ride'),
  a('all_four', 'Jack of All Trades', 'Log a session in all four disciplines.', '🃏', 300, (c) =>
    (['lift', 'climb', 'run', 'ride'] as Discipline[]).every((d) => c.s.totals.byDiscipline[d] >= 1),
  ),

  // --- consistency -------------------------------------------------------
  a('sessions_10', 'Regular', 'Log 10 sessions.', '📅', 200, (c) => c.s.totals.sessions >= 10),
  a('sessions_50', 'Dedicated', 'Log 50 sessions.', '🗓️', 300, (c) => c.s.totals.sessions >= 50),
  a('sessions_100', 'Centurion', 'Log 100 sessions.', '💯', 500, (c) => c.s.totals.sessions >= 100),
  a('sessions_365', 'Year of Sweat', 'Log 365 sessions.', '🏆', 1000, (c) => c.s.totals.sessions >= 365),
  a('double_day', 'Two-a-Day', 'Log two sessions on the same day.', '🔁', 150, (c) => (c.s.dateCounts[c.session.date] ?? 0) >= 2),
  a('weekend_warrior', 'Weekend Warrior', 'Train on both Saturday and Sunday of the same week.', '🛡️', 150, (c) => {
    const wk = Object.keys(c.s.weekDays).find((k) => (c.s.weekDays[k] & satSun) === satSun);
    return !!wk;
  }),
  a('streak_4', 'On a Roll', 'Hit your weekly goal 4 weeks in a row.', '🔥', 200, (c) => c.s.streak.best >= 4),
  a('streak_12', 'Unbreakable', 'Hit your weekly goal 12 weeks in a row.', '🔥', 500, (c) => c.s.streak.best >= 12),
  a('streak_26', 'Half-Year Hero', 'Hit your weekly goal 26 weeks in a row.', '🔥', 800, (c) => c.s.streak.best >= 26),
  a('streak_52', 'Iron Will', 'Hit your weekly goal 52 weeks in a row.', '🔥', 1500, (c) => c.s.streak.best >= 52),
  a('big_day', 'Big Day', 'Earn 3,000 XP in a single day.', '☀️', 200, (c) => (c.s.xpByDate[c.session.date] ?? 0) >= 3000),
  a('long_session', 'Marathon Session', 'Log a session lasting 2 hours or more.', '⏳', 150, (c) => c.st.durationSec >= 7200),

  // --- lifting -----------------------------------------------------------
  a('lift_60', 'One Plate', 'Lift 60 kg in a set.', '🍽️', 100, (c) => c.st.maxSetKg >= 60, 'lift'),
  a('lift_100', 'Two Plates', 'Lift 100 kg in a set.', '🍽️', 200, (c) => c.st.maxSetKg >= 100, 'lift'),
  a('lift_140', 'Three Plates', 'Lift 140 kg in a set.', '🍽️', 300, (c) => c.st.maxSetKg >= 140, 'lift'),
  a('lift_180', 'Four Plates', 'Lift 180 kg in a set.', '🍽️', 400, (c) => c.st.maxSetKg >= 180, 'lift'),
  a('lift_220', 'Five Plates', 'Lift 220 kg in a set.', '🍽️', 600, (c) => c.st.maxSetKg >= 220, 'lift'),
  a('lift_session_10t', 'Ten Tonnes', 'Move 10,000 kg in one session.', '🐘', 200, (c) => c.st.volumeKg >= 10000, 'lift'),
  a('lift_session_20t', 'Twenty Tonnes', 'Move 20,000 kg in one session.', '🐘', 350, (c) => c.st.volumeKg >= 20000, 'lift'),
  a('lift_total_100k', '100 Tonne Club', 'Lift 100,000 kg lifetime.', '⚙️', 300, (c) => c.s.totals.liftVolumeKg >= 100000, 'lift'),
  a('lift_total_500k', 'Half-Million Club', 'Lift 500,000 kg lifetime.', '⚙️', 600, (c) => c.s.totals.liftVolumeKg >= 500000, 'lift'),
  a('lift_total_1m', 'Million Kilo Club', 'Lift 1,000,000 kg lifetime.', '⚙️', 1200, (c) => c.s.totals.liftVolumeKg >= 1000000, 'lift'),
  a('lift_reps_1000', 'Thousand Reps', '1,000 weighted reps lifetime.', '🔢', 200, (c) => c.s.totals.liftReps >= 1000, 'lift'),
  a('lift_variety', 'Variety Pack', 'Log 10 different exercises.', '🎒', 150, (c) => Object.keys(c.s.totals.liftExercises).length >= 10, 'lift'),
  a('lift_bw_100', 'Calisthenics Curious', '100 bodyweight reps in a session.', '🤸', 150, (c) => c.st.bwReps >= 100, 'lift'),

  // --- climbing ----------------------------------------------------------
  a('climb_v2', 'Getting Grippy', 'Send a V2.', '🪨', 100, (c) => (c.s.prs.climbMaxSend ?? -9) >= 2, 'climb'),
  a('climb_v4', 'Crimp Master', 'Send a V4.', '🪨', 200, (c) => (c.s.prs.climbMaxSend ?? -9) >= 4, 'climb'),
  a('climb_v6', 'Project Crusher', 'Send a V6.', '🪨', 350, (c) => (c.s.prs.climbMaxSend ?? -9) >= 6, 'climb'),
  a('climb_v8', 'Stone Cold', 'Send a V8.', '🪨', 600, (c) => (c.s.prs.climbMaxSend ?? -9) >= 8, 'climb'),
  a('climb_v10', 'Double Digits', 'Send a V10.', '💎', 1000, (c) => (c.s.prs.climbMaxSend ?? -9) >= 10, 'climb'),
  a('climb_v12', 'Mythic', 'Send a V12.', '💎', 1500, (c) => (c.s.prs.climbMaxSend ?? -9) >= 12, 'climb'),
  a('climb_flash_v4', 'Flash Bang', 'Flash a V4.', '⚡', 250, (c) => (c.s.prs.climbMaxFlash ?? -9) >= 4, 'climb'),
  a('climb_flash_v6', 'Lightning Hands', 'Flash a V6.', '⚡', 500, (c) => (c.s.prs.climbMaxFlash ?? -9) >= 6, 'climb'),
  a('climb_sends_100', 'Hundred Sends', '100 sends lifetime.', '🧮', 300, (c) => c.s.totals.climbSends >= 100, 'climb'),
  a('climb_sends_500', 'Five Hundred Sends', '500 sends lifetime.', '🧮', 500, (c) => c.s.totals.climbSends >= 500, 'climb'),
  a('climb_sends_1000', 'Thousand Sends', '1,000 sends lifetime.', '🧮', 1000, (c) => c.s.totals.climbSends >= 1000, 'climb'),
  a('climb_pump', 'Pump City', '20 sends in one session.', '💪', 200, (c) => c.st.sends >= 20, 'climb'),
  a('climb_project', 'Project Mode', '10 attempts in one session. Respect the process.', '🧠', 100, (c) => c.st.attempts >= 10, 'climb'),

  // --- running -----------------------------------------------------------
  a('run_5k', 'Parkrun', 'Run 5 km in one go.', '🏃', 100, (c) => c.session.discipline === 'run' && c.st.distanceM >= 5000, 'run'),
  a('run_10k', 'Ten K', 'Run 10 km in one go.', '🏃', 200, (c) => c.session.discipline === 'run' && c.st.distanceM >= 10000, 'run'),
  a('run_half', 'Half Marathon', 'Run 21.1 km in one go.', '🎽', 500, (c) => c.session.discipline === 'run' && c.st.distanceM >= 21097, 'run'),
  a('run_marathon', 'Marathon', 'Run 42.2 km in one go.', '🏅', 1200, (c) => c.session.discipline === 'run' && c.st.distanceM >= 42195, 'run'),
  a('run_total_100', 'Century', 'Run 100 km lifetime.', '🛣️', 300, (c) => c.s.totals.runDistanceM >= 100000, 'run'),
  a('run_total_500', 'Road Warrior', 'Run 500 km lifetime.', '🛣️', 600, (c) => c.s.totals.runDistanceM >= 500000, 'run'),
  a('run_total_1000', 'Thousand K', 'Run 1,000 km lifetime.', '🛣️', 1200, (c) => c.s.totals.runDistanceM >= 1000000, 'run'),
  a('run_pace_5', 'Speed Demon', 'Average 5:00 /km or faster over 5 km+.', '💨', 250, (c) =>
    c.session.discipline === 'run' && c.st.distanceM >= 5000 && c.st.paceSecPerKm !== null && c.st.paceSecPerKm <= 300, 'run'),
  a('run_pace_4', 'Rocket Legs', 'Average 4:00 /km or faster over 5 km+.', '🚀', 500, (c) =>
    c.session.discipline === 'run' && c.st.distanceM >= 5000 && c.st.paceSecPerKm !== null && c.st.paceSecPerKm <= 240, 'run'),
  a('run_elev_500', 'Hill Hunter', 'Climb 500 m of elevation in one run.', '⛰️', 200, (c) => c.session.discipline === 'run' && c.st.elevationM >= 500, 'run'),

  // --- cycling -----------------------------------------------------------
  a('ride_25', 'Quarter Century', 'Ride 25 km in one go.', '🚲', 100, (c) => c.session.discipline === 'ride' && c.st.distanceM >= 25000, 'ride'),
  a('ride_50', 'Half Century', 'Ride 50 km in one go.', '🚲', 200, (c) => c.session.discipline === 'ride' && c.st.distanceM >= 50000, 'ride'),
  a('ride_100', 'Century Ride', 'Ride 100 km in one go.', '🚲', 500, (c) => c.session.discipline === 'ride' && c.st.distanceM >= 100000, 'ride'),
  a('ride_160', 'Imperial Century', 'Ride 160 km (100 miles) in one go.', '👑', 800, (c) => c.session.discipline === 'ride' && c.st.distanceM >= 160934, 'ride'),
  a('ride_total_500', 'Rolling', 'Ride 500 km lifetime.', '🛞', 300, (c) => c.s.totals.rideDistanceM >= 500000, 'ride'),
  a('ride_total_2000', 'Touring', 'Ride 2,000 km lifetime.', '🛞', 600, (c) => c.s.totals.rideDistanceM >= 2000000, 'ride'),
  a('ride_total_5000', 'Grand Tour', 'Ride 5,000 km lifetime.', '🛞', 1200, (c) => c.s.totals.rideDistanceM >= 5000000, 'ride'),
  a('ride_elev_1000', 'Mountain Goat', 'Climb 1,000 m of elevation in one ride.', '🐐', 300, (c) => c.session.discipline === 'ride' && c.st.elevationM >= 1000, 'ride'),
  a('ride_everest', 'Everested', 'Climb 8,848 m of elevation lifetime on the bike.', '🏔️', 500, (c) => c.s.totals.rideElevationM >= 8848, 'ride'),
  a('ride_speed_30', 'Fast Wheels', 'Average 30 km/h over a 20 km+ ride.', '💨', 300, (c) =>
    c.session.discipline === 'ride' && c.st.distanceM >= 20000 && c.st.speedKmh !== null && c.st.speedKmh >= 30, 'ride'),

  // --- hero --------------------------------------------------------------
  a('hero_10', 'Rising Hero', 'Reach hero level 10.', '⭐', 200, (c) => c.s.levels.hero.level >= 10),
  a('hero_25', 'Seasoned Hero', 'Reach hero level 25.', '🌟', 500, (c) => c.s.levels.hero.level >= 25),
  a('hero_50', 'Titan', 'Reach hero level 50.', '💫', 1500, (c) => c.s.levels.hero.level >= 50),
  a('balanced_10', 'Well Rounded', 'Reach level 10 in all four disciplines.', '⚖️', 600, (c) =>
    (['lift', 'climb', 'run', 'ride'] as Discipline[]).every((d) => c.s.levels[d].level >= 10)),
];

export const ACHIEVEMENT_BY_ID: Record<string, AchievementDef> = Object.fromEntries(ACHIEVEMENTS.map((x) => [x.id, x]));
