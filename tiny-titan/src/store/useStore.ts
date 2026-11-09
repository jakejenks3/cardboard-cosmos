import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Loadout, Profile, QuestClaim, Session, Settings, Slot } from '../game/types';
import { DEFAULT_SETTINGS } from '../game/types';

export interface StravaInfo {
  lastSyncAt: number | null;
  athleteName: string | null;
}

/** Everything that is the source of truth. Mirrored to the server when one is running. */
export interface SavedState {
  profile: Profile | null;
  settings: Settings;
  sessions: Session[];
  claims: QuestClaim[];
  loadout: Loadout;
  activePet: string | null;
  strava: StravaInfo;
  updatedAt: number;
}

export interface AppStore extends SavedState {
  setProfile: (p: Profile) => void;
  updateProfile: (patch: Partial<Profile>) => void;
  updateSettings: (patch: Partial<Settings>) => void;
  addSessions: (s: Session[]) => void;
  updateSession: (s: Session) => void;
  deleteSession: (id: string) => void;
  claimQuest: (c: QuestClaim) => void;
  equip: (slot: Slot, id: string | null) => void;
  setLoadout: (l: Loadout) => void;
  setActivePet: (id: string | null) => void;
  setStrava: (patch: Partial<StravaInfo>) => void;
  /** Replace the whole saved state (import / server sync). */
  replaceAll: (s: SavedState) => void;
  reset: () => void;
}

export const STORAGE_KEY = 'tiny-titan-v1';

export const DEFAULT_LOADOUT: Loadout = { body: 'tee_grey', legs: 'shorts_navy', feet: 'trainers_worn' };

const emptyState = (): SavedState => ({
  profile: null,
  settings: { ...DEFAULT_SETTINGS },
  sessions: [],
  claims: [],
  loadout: { ...DEFAULT_LOADOUT },
  activePet: null,
  strava: { lastSyncAt: null, athleteName: null },
  updatedAt: 0,
});

export function pickSaved(s: SavedState): SavedState {
  return {
    profile: s.profile,
    settings: s.settings,
    sessions: s.sessions,
    claims: s.claims,
    loadout: s.loadout,
    activePet: s.activePet,
    strava: s.strava,
    updatedAt: s.updatedAt,
  };
}

export const useStore = create<AppStore>()(
  persist(
    (set) => ({
      ...emptyState(),
      setProfile: (profile) => set({ profile, updatedAt: Date.now() }),
      updateProfile: (patch) =>
        set((s) => ({ profile: s.profile ? { ...s.profile, ...patch } : s.profile, updatedAt: Date.now() })),
      updateSettings: (patch) => set((s) => ({ settings: { ...s.settings, ...patch }, updatedAt: Date.now() })),
      addSessions: (sessions) =>
        set((s) => {
          const known = new Set(s.sessions.map((x) => x.id));
          const stravaIds = new Set(s.sessions.map((x) => x.stravaId).filter(Boolean));
          const fresh = sessions.filter((x) => !known.has(x.id) && !(x.stravaId && stravaIds.has(x.stravaId)));
          return { sessions: [...s.sessions, ...fresh], updatedAt: Date.now() };
        }),
      updateSession: (session) =>
        set((s) => ({ sessions: s.sessions.map((x) => (x.id === session.id ? session : x)), updatedAt: Date.now() })),
      deleteSession: (id) => set((s) => ({ sessions: s.sessions.filter((x) => x.id !== id), updatedAt: Date.now() })),
      claimQuest: (claim) =>
        set((s) => (s.claims.some((c) => c.questId === claim.questId) ? {} : { claims: [...s.claims, claim], updatedAt: Date.now() })),
      equip: (slot, id) => set((s) => ({ loadout: { ...s.loadout, [slot]: id }, updatedAt: Date.now() })),
      setLoadout: (loadout) => set({ loadout, updatedAt: Date.now() }),
      setActivePet: (activePet) => set({ activePet, updatedAt: Date.now() }),
      setStrava: (patch) => set((s) => ({ strava: { ...s.strava, ...patch }, updatedAt: Date.now() })),
      replaceAll: (saved) => set({ ...pickSaved(saved) }),
      reset: () => set({ ...emptyState() }),
    }),
    {
      name: STORAGE_KEY,
      partialize: (s) => pickSaved(s),
      version: 1,
    },
  ),
);

/** Validate a JSON blob (import / server) into a SavedState, or throw. */
export function parseSavedState(raw: unknown): SavedState {
  if (!raw || typeof raw !== 'object') throw new Error('Not a Tiny Titan backup');
  const o = raw as Partial<SavedState>;
  if (!Array.isArray(o.sessions)) throw new Error('Backup has no sessions list');
  const base = emptyState();
  return {
    profile: o.profile && typeof o.profile === 'object' ? { ...o.profile } : null,
    settings: { ...base.settings, ...(o.settings ?? {}) },
    sessions: o.sessions.filter((s) => s && typeof s === 'object' && typeof s.id === 'string'),
    claims: Array.isArray(o.claims) ? o.claims : [],
    loadout: o.loadout && typeof o.loadout === 'object' ? o.loadout : { ...DEFAULT_LOADOUT },
    activePet: typeof o.activePet === 'string' ? o.activePet : null,
    strava: { ...base.strava, ...(o.strava ?? {}) },
    updatedAt: typeof o.updatedAt === 'number' ? o.updatedAt : Date.now(),
  };
}
