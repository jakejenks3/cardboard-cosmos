import { useEffect } from 'react';
import { useStore } from './store/useStore';
import { useUi, type Tab } from './store/ui';
import { startSync, refreshHealth } from './store/sync';
import { syncStrava } from './store/derived';
import { setSfxEnabled } from './sfx/sounds';
import { AvatarPreview } from './screens/AvatarPreview';
import { Onboarding } from './screens/Onboarding';
import { Home } from './screens/Home';
import { LogScreen } from './screens/Log';
import { Journey } from './screens/Journey';
import { Armory } from './screens/Armory';
import { Quests } from './screens/Quests';
import { ResultsOverlay } from './screens/Results';
import { SettingsSheet } from './screens/Settings';
import { Toasts } from './components/Toasts';

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: 'home', label: 'Hero', icon: '🏠' },
  { id: 'quests', label: 'Quests', icon: '📜' },
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
  const tab = useUi((s) => s.tab);
  const setTab = useUi((s) => s.setTab);
  const setLogDiscipline = useUi((s) => s.setLogDiscipline);
  const setEditingSession = useUi((s) => s.setEditingSession);
  const toast = useUi((s) => s.toast);
  const result = useUi((s) => s.result);

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
      // Quiet background sync when it has been a while.
      const ui = useUi.getState();
      const st = useStore.getState();
      if (ui.stravaConnected && st.profile && (!st.strava.lastSyncAt || Date.now() - st.strava.lastSyncAt > 15 * 60_000)) {
        await syncStrava({ silent: true });
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!profile) return <Onboarding />;

  return (
    <div className={`app ${result ? 'app-locked' : ''}`}>
      <main className="main">
        {tab === 'home' && <Home />}
        {tab === 'quests' && <Quests />}
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
              }
              setTab(t.id);
              window.scrollTo({ top: 0 });
            }}
            aria-current={tab === t.id ? 'page' : undefined}
          >
            <span className="nav-icon">{t.icon}</span>
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
