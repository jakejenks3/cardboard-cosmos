import { create } from 'zustand';
import type { ResultEvent } from '../game/diff';
import type { Session } from '../game/types';

export type Tab = 'home' | 'quests' | 'log' | 'journey' | 'armory';

export interface Toast {
  id: number;
  text: string;
  icon?: string;
  kind?: 'info' | 'good' | 'bad';
}

export interface PendingResult {
  /** The session(s) that were just added. */
  sessions: Session[];
  events: ResultEvent[];
  title: string;
}

interface UiStore {
  tab: Tab;
  setTab: (t: Tab) => void;
  settingsOpen: boolean;
  setSettingsOpen: (v: boolean) => void;
  editingSessionId: string | null;
  setEditingSession: (id: string | null) => void;
  logDiscipline: string | null;
  setLogDiscipline: (d: string | null) => void;
  result: PendingResult | null;
  setResult: (r: PendingResult | null) => void;
  toasts: Toast[];
  toast: (text: string, icon?: string, kind?: Toast['kind']) => void;
  dismissToast: (id: number) => void;
  serverOnline: boolean | null;
  setServerOnline: (v: boolean) => void;
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
  settingsOpen: false,
  setSettingsOpen: (settingsOpen) => set({ settingsOpen }),
  editingSessionId: null,
  setEditingSession: (editingSessionId) => set({ editingSessionId }),
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
  stravaConnected: false,
  stravaConfigured: false,
  setStravaStatus: (stravaConfigured, stravaConnected) => set({ stravaConfigured, stravaConnected }),
  syncing: false,
  setSyncing: (syncing) => set({ syncing }),
}));
