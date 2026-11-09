// Thin wrapper over the optional Node server. Every call fails soft: the app
// is fully usable from localStorage alone; the server adds Strava + sync.

import type { Session } from '../game/types';
import type { SavedState } from '../store/useStore';

export interface Health {
  ok: true;
  auth: { required: boolean; ok: boolean };
  strava: { configured: boolean; connected: boolean; athlete: string | null };
}

const BASE = (import.meta.env.VITE_API_BASE as string | undefined) ?? '';

/** `Omit` that distributes over the Session union. */
type DistributiveOmit<T, K extends PropertyKey> = T extends unknown ? Omit<T, K> : never;
export type ImportedSession = DistributiveOmit<Session, 'id' | 'createdAt'>;

async function fail(res: Response): Promise<never> {
  let msg = `${res.status} ${res.statusText}`;
  try {
    const j = await res.json();
    if (j?.error) msg = j.error;
  } catch {
    /* ignore */
  }
  throw new Error(msg);
}

async function req<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}/api${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
  });
  if (!res.ok) await fail(res);
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export const api = {
  health: () => req<Health>('/health'),
  login: (password: string) => req<{ ok: true }>('/login', { method: 'POST', body: JSON.stringify({ password }) }),
  getState: () => req<{ state: SavedState | null }>('/state'),
  putState: (state: SavedState) => req<{ ok: true }>('/state', { method: 'PUT', body: JSON.stringify(state) }),
  stravaConnectUrl: () => `${BASE}/api/strava/connect`,
  stravaDisconnect: () => req<{ ok: true }>('/strava/disconnect', { method: 'POST' }),
  /** Normalized sessions (without ids) for activities after the given epoch seconds. */
  stravaActivities: (afterSec: number) => req<{ sessions: ImportedSession[]; truncated: boolean }>(`/strava/activities?after=${afterSec}`),

  listPhotos: () => req<{ ids: string[] }>('/photos'),
  putPhoto: async (id: string, blob: Blob): Promise<void> => {
    const res = await fetch(`${BASE}/api/photos/${encodeURIComponent(id)}`, { method: 'PUT', headers: { 'Content-Type': 'image/jpeg' }, body: blob });
    if (!res.ok) await fail(res);
  },
  getPhoto: async (id: string): Promise<Blob | null> => {
    const res = await fetch(`${BASE}/api/photos/${encodeURIComponent(id)}`);
    if (res.status === 404) return null;
    if (!res.ok) await fail(res);
    return res.blob();
  },
  deletePhoto: (id: string) => req<{ ok: true }>(`/photos/${encodeURIComponent(id)}`, { method: 'DELETE' }),
};
