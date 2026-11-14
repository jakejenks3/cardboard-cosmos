import { create } from 'zustand';
import type { ResultEvent } from '../game/diff';

export type Tab = 'home' | 'adventure' | 'log' | 'journey' | 'armory';
export type AdventureTab = 'campaign' | 'quests' | 'trophies';
export type JourneyTab = 'stats' | 'body' | 'chronicle' | 'history';

export interface Toast {
  id: number;
  text: string;
  icon?: string;
  kind?: 'info' | 'good' | 'bad';
}

export interface PendingResult {
  /** Unique per reel so the overlay remounts. */
  key: string;
  events: ResultEvent[];
  title: string;
}

interface UiStore {
  tab: Tab;
  setTab: (t: Tab) => void;
  adventureTab: AdventureTab;
  setAdventureTab: (t: AdventureTab) => void;
  journeyTab: JourneyTab;
  setJourneyTab: (t: JourneyTab) => void;
  settingsOpen: boolean;
  setSettingsOpen: (v: boolean) => void;
  editingSessionId: string | null;
  setEditingSession: (id: string | null) => void;
  editingBodyId: string | null;
  setEditingBody: (id: string | null) => void;
  /** A discipline id, or 'body' for the check-in form. */
  logDiscipline: string | null;
  setLogDiscipline: (d: string | null) => void;
  result: PendingResult | null;
  setResult: (r: PendingResult | null) => void;
  toasts: Toast[];
  toast: (text: string, icon?: string, kind?: Toast['kind']) => void;
  dismissToast: (id: number) => void;
  serverOnline: boolean | null;
  setServerOnline: (v: boolean) => void;
  /** The server wants a password before it will sync. */
  serverLocked: boolean;
  setServerLocked: (v: boolean) => void;
  stravaConnected: boolean;
  stravaConfigured: boolean;
  setStravaStatus: (configured: boolean, connected: boolean) => void;
  syncing: boolean;
  setSyncing: (v: boolean) => void;
}

let toastId = 1;

export const useUi = create<UiStore>()((set) => ({
  tab: 'home',
  setTab: (tab) => set({ tab }),
  adventureTab: 'campaign',
  setAdventureTab: (adventureTab) => set({ adventureTab }),
  journeyTab: 'stats',
  setJourneyTab: (journeyTab) => set({ journeyTab }),
  settingsOpen: false,
  setSettingsOpen: (settingsOpen) => set({ settingsOpen }),
  editingSessionId: null,
  setEditingSession: (editingSessionId) => set({ editingSessionId }),
  editingBodyId: null,
  setEditingBody: (editingBodyId) => set({ editingBodyId }),
  logDiscipline: null,
  setLogDiscipline: (logDiscipline) => set({ logDiscipline }),
  result: null,
  setResult: (result) => set({ result }),
  toasts: [],
  toast: (text, icon, kind = 'info') => {
    const id = toastId++;
    set((s) => ({ toasts: [...s.toasts, { id, text, icon, kind }] }));
    setTimeout(() => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })), 3200);
  },
  dismissToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),
  serverOnline: null,
  setServerOnline: (serverOnline) => set({ serverOnline }),
  serverLocked: false,
  setServerLocked: (serverLocked) => set({ serverLocked }),
  stravaConnected: false,
  stravaConfigured: false,
  setStravaStatus: (stravaConfigured, stravaConnected) => set({ stravaConfigured, stravaConnected }),
  syncing: false,
  setSyncing: (syncing) => set({ syncing }),
}));
