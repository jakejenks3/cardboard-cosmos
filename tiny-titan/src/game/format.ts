import type { Settings } from './types';

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

export function pct(n: number): string {
  return `${Math.round(n * 100)}%`;
}
