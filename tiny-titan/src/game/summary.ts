import type { Session, Settings } from './types';
import { gradeLabel, sessionStats } from './xp';
import { fmtBigKg, fmtDistance, fmtDuration, fmtElevation, fmtPace, fmtSpeed } from './format';

/** One-line description of a session for lists. */
export function summarizeSession(s: Session, settings: Settings): string {
  const st = sessionStats(s);
  const parts: string[] = [];
  if (s.discipline === 'lift') {
    const n = s.exercises.filter((e) => e.sets.length).length;
    parts.push(`${n} exercise${n === 1 ? '' : 's'}`, `${st.sets} sets`);
    if (st.volumeKg) parts.push(fmtBigKg(st.volumeKg, settings.weightUnit));
    if (st.bwReps) parts.push(`${st.bwReps} BW reps`);
  } else if (s.discipline === 'climb') {
    parts.push(`${st.sends} send${st.sends === 1 ? '' : 's'}`);
    if (st.maxGradeSent !== null) parts.push(`max ${gradeLabel(st.maxGradeSent)}`);
    if (st.flashes) parts.push(`${st.flashes} flash${st.flashes === 1 ? '' : 'es'}`);
    if (st.attempts) parts.push(`${st.attempts} attempts`);
  } else {
    parts.push(fmtDistance(st.distanceM, settings.distanceUnit));
    if (s.durationSec) parts.push(fmtDuration(s.durationSec));
    if (st.paceSecPerKm !== null && s.discipline === 'run') parts.push(fmtPace(st.paceSecPerKm, settings.distanceUnit));
    if (st.speedKmh !== null && s.discipline === 'ride') parts.push(fmtSpeed(st.speedKmh, settings.distanceUnit));
    if (st.elevationM) parts.push(`${fmtElevation(st.elevationM, settings.distanceUnit)} ↑`);
  }
  if (!parts.length && s.durationSec) parts.push(fmtDuration(s.durationSec));
  return parts.join(' · ');
}

export const DEFAULT_EXERCISES = [
  'Squat',
  'Bench Press',
  'Deadlift',
  'Overhead Press',
  'Barbell Row',
  'Pull-up',
  'Chin-up',
  'Dip',
  'Push-up',
  'Front Squat',
  'Romanian Deadlift',
  'Hip Thrust',
  'Lunge',
  'Leg Press',
  'Lat Pulldown',
  'Dumbbell Press',
  'Incline Bench Press',
  'Bicep Curl',
  'Tricep Pushdown',
  'Lateral Raise',
  'Face Pull',
  'Plank',
  'Weighted Pull-up',
  'Clean',
  'Snatch',
  'Kettlebell Swing',
];
