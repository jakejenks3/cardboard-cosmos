// Keeps localStorage and the (optional) server copy of the saved state in
// step: newest `updatedAt` wins, pushes are debounced.

import { api } from '../api/client';
import { useStore, pickSaved, parseSavedState, referencedPhotoIds } from './useStore';
import { useUi } from './ui';
import { syncPhotos } from './photos';

let pushTimer: ReturnType<typeof setTimeout> | null = null;
let lastPushed = 0;
let subscribed = false;

function usable(): boolean {
  const ui = useUi.getState();
  return ui.serverOnline === true && !ui.serverLocked;
}

async function push() {
  if (!usable()) return;
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
  if (!usable()) return;
  if (pushTimer) clearTimeout(pushTimer);
  pushTimer = setTimeout(push, 1500);
}

export async function refreshHealth(): Promise<boolean> {
  const ui = useUi.getState();
  try {
    const h = await api.health();
    ui.setServerOnline(true);
    ui.setServerLocked(h.auth.required && !h.auth.ok);
    ui.setStravaStatus(h.strava.configured, h.strava.connected);
    if (h.strava.athlete && useStore.getState().strava.athleteName !== h.strava.athlete) {
      useStore.getState().setStrava({ athleteName: h.strava.athlete });
    }
    return true;
  } catch {
    ui.setServerOnline(false);
    return false;
  }
}

/** Reconcile with the server copy: newest wins. */
async function reconcile() {
  if (!usable()) return;
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
  void syncPhotos(referencedPhotoIds(useStore.getState().body));
}

export async function startSync() {
  const online = await refreshHealth();
  if (online) await reconcile();
  if (!subscribed) {
    subscribed = true;
    useStore.subscribe((s, prev) => {
      if (s.updatedAt !== prev.updatedAt) schedulePush();
    });
  }
}

/** Log in to a password-protected server, then sync. */
export async function unlockServer(password: string): Promise<void> {
  await api.login(password);
  await refreshHealth();
  await reconcile();
}
