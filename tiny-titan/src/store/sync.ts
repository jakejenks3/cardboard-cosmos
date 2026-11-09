// Keeps localStorage and the (optional) server copy of the saved state in
// step: newest `updatedAt` wins, pushes are debounced.

import { api } from '../api/client';
import { useStore, pickSaved, parseSavedState } from './useStore';
import { useUi } from './ui';

let pushTimer: ReturnType<typeof setTimeout> | null = null;
let lastPushed = 0;
let started = false;

async function push() {
  const s = useStore.getState();
  if (!s.updatedAt || s.updatedAt === lastPushed) return;
  try {
    await api.putState(pickSaved(s));
    lastPushed = s.updatedAt;
  } catch {
    /* server offline — ignore, localStorage is the primary copy */
  }
}

export function schedulePush() {
  if (useUi.getState().serverOnline === false) return;
  if (pushTimer) clearTimeout(pushTimer);
  pushTimer = setTimeout(push, 1500);
}

export async function refreshHealth(): Promise<boolean> {
  try {
    const h = await api.health();
    useUi.getState().setServerOnline(true);
    useUi.getState().setStravaStatus(h.strava.configured, h.strava.connected);
    if (h.strava.athlete && useStore.getState().strava.athleteName !== h.strava.athlete) {
      useStore.getState().setStrava({ athleteName: h.strava.athlete });
    }
    return true;
  } catch {
    useUi.getState().setServerOnline(false);
    return false;
  }
}

export async function startSync() {
  if (started) return;
  started = true;
  const online = await refreshHealth();
  if (online) {
    try {
      const { state } = await api.getState();
      const local = useStore.getState();
      if (state && state.updatedAt > (local.updatedAt || 0)) {
        useStore.getState().replaceAll(parseSavedState(state));
        lastPushed = state.updatedAt;
      } else if (local.updatedAt && (!state || local.updatedAt > state.updatedAt)) {
        await push();
      } else if (state) {
        lastPushed = state.updatedAt;
      }
    } catch {
      /* ignore */
    }
  }
  useStore.subscribe((s, prev) => {
    if (s.updatedAt !== prev.updatedAt) schedulePush();
  });
}
