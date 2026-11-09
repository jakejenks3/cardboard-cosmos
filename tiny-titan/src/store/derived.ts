// Hooks + commands that sit between the raw store and the screens.

import { useEffect, useMemo, useState } from 'react';
import { useStore } from './useStore';
import { useUi } from './ui';
import { derive } from '../game/derive';
import { diffBody, diffBulk, diffStates } from '../game/diff';
import { computePerks } from '../game/perks';
import { dailyQuests, weeklyQuests } from '../game/quests';
import { nextGoals } from '../game/nextup';
import { todayKey, weekKey } from '../game/dates';
import { uid } from '../game/rng';
import { api } from '../api/client';
import type { PlayerState } from '../game/state';
import type { BodyEntry, Discipline, Session } from '../game/types';

/** Today's date key; re-evaluated every minute so midnight rolls over. */
export function useToday(): string {
  const [today, setToday] = useState(() => todayKey());
  useEffect(() => {
    const t = setInterval(() => {
      const k = todayKey();
      setToday((prev) => (prev === k ? prev : k));
    }, 60_000);
    return () => clearInterval(t);
  }, []);
  return today;
}

export function useDerived(): PlayerState {
  const sessions = useStore((s) => s.sessions);
  const claims = useStore((s) => s.claims);
  const body = useStore((s) => s.body);
  const goal = useStore((s) => s.settings.weeklyGoal);
  const today = useToday();
  return useMemo(() => derive({ sessions, claims, body, weeklyGoal: goal, today }), [sessions, claims, body, goal, today]);
}

export function usePerks(derived: PlayerState) {
  const loadout = useStore((s) => s.loadout);
  const activePet = useStore((s) => s.activePet);
  return useMemo(() => computePerks(derived, loadout, activePet), [derived, loadout, activePet]);
}

export function useQuests(derived: PlayerState) {
  const sessions = useStore((s) => s.sessions);
  const claims = useStore((s) => s.claims);
  const settings = useStore((s) => s.settings);
  const today = useToday();
  return useMemo(
    () => ({
      daily: dailyQuests(today, derived, sessions, claims),
      weekly: weeklyQuests(weekKey(today), derived, sessions, claims, settings),
      today,
    }),
    [derived, sessions, claims, settings, today],
  );
}

export function useNextGoals(derived: PlayerState, limit = 4) {
  return useMemo(() => nextGoals(derived, limit), [derived, limit]);
}

function snapshotInput() {
  const st = useStore.getState();
  return { sessions: st.sessions, claims: st.claims, body: st.body, weeklyGoal: st.settings.weeklyGoal, today: todayKey() };
}

function currentDerived(): PlayerState {
  return derive(snapshotInput());
}

/** Stamp a new session with an id, creation time and the perk snapshot. */
export function buildSession<T extends Session>(partial: Omit<T, 'id' | 'createdAt' | 'bonusPct' | 'luckPct'> & { createdAt?: number }, derived?: PlayerState): T {
  const st = useStore.getState();
  const d = derived ?? currentDerived();
  const perks = computePerks(d, st.loadout, st.activePet);
  const discipline = partial.discipline as Discipline;
  return {
    ...(partial as object),
    id: uid('s'),
    createdAt: partial.createdAt ?? Date.now(),
    bonusPct: Math.round(perks.xp[discipline] * 1000) / 1000,
    luckPct: Math.round(perks.luck * 1000) / 1000,
  } as T;
}

/** Add sessions to the log and queue the results reel. */
export function commitSessions(sessions: Session[], title: string) {
  if (!sessions.length) return;
  const before = currentDerived();
  useStore.getState().addSessions(sessions);
  const after = currentDerived();
  const events = sessions.length === 1 ? diffStates(before, after, sessions[0]) : diffBulk(before, after, sessions);
  useUi.getState().setResult({ key: sessions.map((s) => s.id).join(','), events, title });
}

/** Add a body check-in and queue its results reel. */
export function commitBody(entry: BodyEntry) {
  const before = currentDerived();
  useStore.getState().addBody(entry);
  const after = currentDerived();
  useUi.getState().setResult({ key: entry.id, events: diffBody(before, after, entry), title: 'Checked in!' });
}

export async function syncStrava(opts: { silent?: boolean } = {}): Promise<{ added: number; truncated: boolean }> {
  const st = useStore.getState();
  const ui = useUi.getState();
  if (ui.syncing) return { added: 0, truncated: false };
  ui.setSyncing(true);
  try {
    const last = st.strava.lastSyncAt;
    // Overlap two days so late-uploaded activities are not missed; first sync pulls a year.
    const afterSec = last ? Math.floor(last / 1000) - 2 * 86400 : Math.floor(Date.now() / 1000) - 365 * 86400;
    const { sessions: raw, truncated } = await api.stravaActivities(afterSec);
    const known = new Set(useStore.getState().sessions.map((s) => s.stravaId).filter(Boolean));
    const fresh = raw.filter((r) => r.stravaId && !known.has(r.stravaId)).sort((a, b) => a.date.localeCompare(b.date));
    const now = Date.now();
    const d = currentDerived();
    const sessions = fresh.map((r, i) => buildSession<Session>({ ...(r as Session), createdAt: now + i }, d));
    if (sessions.length) {
      commitSessions(sessions, sessions.length === 1 ? 'Synced from Strava' : `${sessions.length} activities imported from Strava`);
    } else if (!opts.silent) {
      ui.toast('Strava is up to date', '✅', 'good');
    }
    useStore.getState().setStrava({ lastSyncAt: now });
    return { added: sessions.length, truncated };
  } catch (e) {
    if (!opts.silent) ui.toast(`Strava sync failed: ${(e as Error).message}`, '⚠️', 'bad');
    return { added: 0, truncated: false };
  } finally {
    useUi.getState().setSyncing(false);
  }
}
