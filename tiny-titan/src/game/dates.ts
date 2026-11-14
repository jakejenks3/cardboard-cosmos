// Local-date helpers. Dates are stored as YYYY-MM-DD in the user's local
// calendar; weeks start on Monday.

export function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

export function toDateKey(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

export function todayKey(now = new Date()): string {
  return toDateKey(now);
}

export function parseDateKey(key: string): Date {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, (m || 1) - 1, d || 1);
}

export function addDays(key: string, n: number): string {
  const d = parseDateKey(key);
  d.setDate(d.getDate() + n);
  return toDateKey(d);
}

export function daysBetween(a: string, b: string): number {
  const da = parseDateKey(a).getTime();
  const db = parseDateKey(b).getTime();
  return Math.round((db - da) / 86400000);
}

/** Monday of the week containing `key`, as a date key. */
export function weekKey(key: string): string {
  const d = parseDateKey(key);
  const diff = (d.getDay() + 6) % 7; // Mon=0 … Sun=6
  d.setDate(d.getDate() - diff);
  return toDateKey(d);
}

export function addWeeks(wk: string, n: number): string {
  return addDays(wk, n * 7);
}

/** 0 = Monday … 6 = Sunday */
export function weekdayIndex(key: string): number {
  return (parseDateKey(key).getDay() + 6) % 7;
}

export function formatDate(key: string, opts: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric' }): string {
  return parseDateKey(key).toLocaleDateString(undefined, opts);
}

export function formatDateLong(key: string): string {
  return parseDateKey(key).toLocaleDateString(undefined, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

export function relativeDay(key: string, today = todayKey()): string {
  const diff = daysBetween(key, today);
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  if (diff < 7) return parseDateKey(key).toLocaleDateString(undefined, { weekday: 'long' });
  return formatDate(key);
}
