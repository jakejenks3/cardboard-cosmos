import type { Settings } from './types';
import type { Progress, ProgressUnit } from './goals';

export const KG_PER_LB = 0.45359237;
export const M_PER_MI = 1609.344;

export function kgToUnit(kg: number, unit: Settings['weightUnit']): number {
  return unit === 'kg' ? kg : kg / KG_PER_LB;
}
export function unitToKg(v: number, unit: Settings['weightUnit']): number {
  return unit === 'kg' ? v : v * KG_PER_LB;
}
export function mToUnit(m: number, unit: Settings['distanceUnit']): number {
  return unit === 'km' ? m / 1000 : m / M_PER_MI;
}
export function unitToM(v: number, unit: Settings['distanceUnit']): number {
  return unit === 'km' ? v * 1000 : v * M_PER_MI;
}

export function fmtNum(n: number, digits = 0): string {
  return n.toLocaleString('en-US', { maximumFractionDigits: digits, minimumFractionDigits: 0 });
}

export function fmtWeight(kg: number, unit: Settings['weightUnit'], digits = 1): string {
  const v = kgToUnit(kg, unit);
  return `${fmtNum(v, Number.isInteger(v) ? 0 : digits)} ${unit}`;
}

export function fmtDistance(m: number, unit: Settings['distanceUnit'], digits = 1): string {
  return `${fmtNum(mToUnit(m, unit), digits)} ${unit}`;
}

export function fmtElevation(m: number, unit: Settings['distanceUnit']): string {
  return unit === 'km' ? `${fmtNum(m)} m` : `${fmtNum(m * 3.28084)} ft`;
}

export function fmtDuration(sec: number): string {
  sec = Math.round(sec);
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  if (h) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

export function fmtDurationShort(sec: number): string {
  const m = Math.round(sec / 60);
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  const r = m % 60;
  return r ? `${h}h ${r}m` : `${h}h`;
}

/** Pace as mm:ss per km or per mile. */
export function fmtPace(secPerKm: number, unit: Settings['distanceUnit']): string {
  const per = unit === 'km' ? secPerKm : secPerKm * (M_PER_MI / 1000);
  const m = Math.floor(per / 60);
  const s = Math.round(per % 60);
  return `${m}:${String(s).padStart(2, '0')} /${unit}`;
}

export function fmtSpeed(kmh: number, unit: Settings['distanceUnit']): string {
  return unit === 'km' ? `${kmh.toFixed(1)} km/h` : `${(kmh / (M_PER_MI / 1000)).toFixed(1)} mph`;
}

export function fmtBigKg(kg: number, unit: Settings['weightUnit']): string {
  const v = kgToUnit(kg, unit);
  if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(2)}M ${unit}`;
  if (v >= 10_000) return `${(v / 1000).toFixed(1)}k ${unit}`;
  return `${fmtNum(v)} ${unit}`;
}

export function parseDurationInput(h: string | number, m: string | number, s: string | number): number {
  const hh = Number(h) || 0;
  const mm = Number(m) || 0;
  const ss = Number(s) || 0;
  return Math.max(0, Math.round(hh * 3600 + mm * 60 + ss));
}

/** Format a goal value in the player's units. */
export function fmtGoalValue(n: number, unit: ProgressUnit, settings: Pick<Settings, 'weightUnit' | 'distanceUnit'>): string {
  switch (unit) {
    case 'kg':
      return kgToUnit(n, settings.weightUnit) >= 10000 ? fmtBigKg(n, settings.weightUnit) : fmtWeight(n, settings.weightUnit, 1);
    case 'm':
      return fmtDistance(n, settings.distanceUnit, n >= 100000 ? 0 : 1);
    case 'elev':
      return fmtElevation(n, settings.distanceUnit);
    case 'level':
      return `Lv ${Math.floor(n)}`;
    case 'grade':
      return n < -1 ? '—' : n < 0 ? 'VB' : `V${Math.floor(n)}`;
    case 'weeks':
      return `${Math.floor(n)} wk`;
    case 'xp':
      return `${fmtNum(n)} XP`;
    case 'min':
      return fmtDurationShort(n * 60);
    case 'ratio':
      return `${n.toFixed(2)}×`;
    default:
      return fmtNum(Math.floor(n));
  }
}

export function fmtProgress(p: Progress, settings: Pick<Settings, 'weightUnit' | 'distanceUnit'>): string {
  const cur = p.unit === 'grade' ? p.cur : Math.min(p.cur, p.target);
  return `${fmtGoalValue(cur, p.unit, settings)} / ${fmtGoalValue(p.target, p.unit, settings)}`;
}

export function pct(n: number): string {
  return `${Math.round(n * 100)}%`;
}
