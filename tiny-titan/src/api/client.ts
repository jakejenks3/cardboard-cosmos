// Thin wrapper over the optional Node server. Every call fails soft: the app
// is fully usable from localStorage alone; the server adds Strava + sync.

import type { Session } from '../game/types';
import type { SavedState } from '../store/useStore';

export interface Health {
  ok: true;
  strava: { configured: boolean; connected: boolean; athlete: string | null };
}

const BASE = (import.meta.env.VITE_API_BASE as string | undefined) ?? '';

async function req<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}/api${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
  });
  if (!res.ok) {
    let msg = `${res.status} ${res.statusText}`;
    try {
      const j = await res.json();
      if (j?.error) msg = j.error;
    } catch {
      /* ignore */
    }
    throw new Error(msg);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export const api = {
  health: () => req<Health>('/health'),
  getState: () => req<{ state: SavedState | null }>('/state'),
  putState: (state: SavedState) => req<{ ok: true }>('/state', { method: 'PUT', body: JSON.stringify(state) }),
  stravaConnectUrl: () => `${BASE}/api/strava/connect`,
  stravaDisconnect: () => req<{ ok: true }>('/strava/disconnect', { method: 'POST' }),
  /** Normalized sessions (without ids) for activities after the given epoch seconds. */
  stravaActivities: (afterSec: number) =>
    req<{ sessions: Omit<Session, 'id' | 'createdAt'>[]; truncated: boolean }>(`/strava/activities?after=${afterSec}`),
};
