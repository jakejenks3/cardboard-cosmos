import { useEffect } from 'react';
import { useStore } from './store/useStore';
import { useUi, type Tab } from './store/ui';
import { startSync, refreshHealth } from './store/sync';
import { syncStrava, useDerived, useQuests } from './store/derived';
import { setSfxEnabled } from './sfx/sounds';
import { AvatarPreview } from './screens/AvatarPreview';
import { Onboarding } from './screens/Onboarding';
import { Home } from './screens/Home';
import { LogScreen } from './screens/Log';
import { Journey } from './screens/Journey';
import { Armory } from './screens/Armory';
import { Adventure } from './screens/Adventure';
import { ResultsOverlay } from './screens/Results';
import { SettingsSheet } from './screens/Settings';
import { Toasts } from './components/Toasts';

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: 'home', label: 'Hero', icon: '🏠' },
  { id: 'adventure', label: 'Adventure', icon: '⚔️' },
  { id: 'log', label: 'Log', icon: '＋' },
  { id: 'journey', label: 'Journey', icon: '📈' },
  { id: 'armory', label: 'Armory', icon: '🎒' },
];

export function App() {
  const params = new URLSearchParams(window.location.search);
  if (params.get('preview') === 'avatar') return <AvatarPreview />;
  return <Main />;
}

function Main() {
  const profile = useStore((s) => s.profile);
  const sound = useStore((s) => s.settings.sound);
  const toast = useUi((s) => s.toast);

  useEffect(() => setSfxEnabled(sound), [sound]);

  useEffect(() => {
    void (async () => {
      await startSync();
      const params = new URLSearchParams(window.location.search);
      const flag = params.get('strava');
      if (flag) {
        window.history.replaceState({}, '', window.location.pathname);
        if (flag === 'connected') {
          toast('Strava connected! Importing your activities…', '🟠', 'good');
          await refreshHealth();
          await syncStrava();
          return;
        }
        toast(`Strava connection failed: ${params.get('reason') ?? flag}`, '⚠️', 'bad');
      }
      const ui = useUi.getState();
      const st = useStore.getState();
      if (ui.serverLocked) toast('Server is locked — enter its password in Settings to sync', '🔒');
      // Quiet background sync when it has been a while.
      if (ui.stravaConnected && st.profile && (!st.strava.lastSyncAt || Date.now() - st.strava.lastSyncAt > 15 * 60_000)) {
        await syncStrava({ silent: true });
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!profile) return <Onboarding />;
  return <Shell />;
}

function Shell() {
  const tab = useUi((s) => s.tab);
  const setTab = useUi((s) => s.setTab);
  const setLogDiscipline = useUi((s) => s.setLogDiscipline);
  const setEditingSession = useUi((s) => s.setEditingSession);
  const setEditingBody = useUi((s) => s.setEditingBody);
  const result = useUi((s) => s.result);
  const derived = useDerived();
  const { daily, weekly } = useQuests(derived);
  const claimable = [...daily, ...weekly].filter((q) => q.done && !q.claimed).length;

  return (
    <div className={`app ${result ? 'app-locked' : ''}`}>
      <main className="main">
        {tab === 'home' && <Home />}
        {tab === 'adventure' && <Adventure />}
        {tab === 'log' && <LogScreen />}
        {tab === 'journey' && <Journey />}
        {tab === 'armory' && <Armory />}
      </main>
      <nav className="nav" aria-label="Main">
        {TABS.map((t) => (
          <button
            key={t.id}
            className={`nav-btn ${tab === t.id ? 'nav-active' : ''} ${t.id === 'log' ? 'nav-log' : ''}`}
            onClick={() => {
              if (t.id === 'log') {
                setLogDiscipline(null);
                setEditingSession(null);
                setEditingBody(null);
              }
              setTab(t.id);
              window.scrollTo({ top: 0 });
            }}
            aria-current={tab === t.id ? 'page' : undefined}
          >
            <span className="nav-icon">
              {t.icon}
              {t.id === 'adventure' && claimable > 0 && <span className="nav-badge">{claimable}</span>}
            </span>
            <span className="nav-label">{t.label}</span>
          </button>
        ))}
      </nav>
      <ResultsOverlay />
      <SettingsSheet />
      <Toasts />
    </div>
  );
}
