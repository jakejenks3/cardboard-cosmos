import { useRef } from 'react';
import { useStore, parseSavedState, pickSaved } from '../store/useStore';
import { useUi } from '../store/ui';
import { refreshHealth } from '../store/sync';
import { syncStrava } from '../store/derived';
import { api } from '../api/client';
import { Button, Field, Input, Segmented, Sheet } from '../components/ui';
import { setSfxEnabled } from '../sfx/sounds';

export function SettingsSheet() {
  const open = useUi((s) => s.settingsOpen);
  const setOpen = useUi((s) => s.setSettingsOpen);
  const profile = useStore((s) => s.profile);
  const settings = useStore((s) => s.settings);
  const strava = useStore((s) => s.strava);
  const updateProfile = useStore((s) => s.updateProfile);
  const updateSettings = useStore((s) => s.updateSettings);
  const replaceAll = useStore((s) => s.replaceAll);
  const reset = useStore((s) => s.reset);
  const setStrava = useStore((s) => s.setStrava);
  const toast = useUi((s) => s.toast);
  const serverOnline = useUi((s) => s.serverOnline);
  const stravaConfigured = useUi((s) => s.stravaConfigured);
  const stravaConnected = useUi((s) => s.stravaConnected);
  const syncing = useUi((s) => s.syncing);
  const fileRef = useRef<HTMLInputElement>(null);

  const exportJson = () => {
    const data = JSON.stringify(pickSaved(useStore.getState()), null, 2);
    const blob = new Blob([data], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `tiny-titan-backup-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const importJson = async (file: File) => {
    try {
      const parsed = parseSavedState(JSON.parse(await file.text()));
      if (!window.confirm(`Import ${parsed.sessions.length} sessions? This replaces your current data.`)) return;
      replaceAll({ ...parsed, updatedAt: Date.now() });
      toast('Backup imported', '📦', 'good');
      setOpen(false);
    } catch (e) {
      toast(`Import failed: ${(e as Error).message}`, '⚠️', 'bad');
    }
  };

  const disconnect = async () => {
    if (!window.confirm('Disconnect Strava? Imported sessions stay in your log.')) return;
    try {
      await api.stravaDisconnect();
      setStrava({ athleteName: null, lastSyncAt: null });
      await refreshHealth();
      toast('Strava disconnected', '🔌');
    } catch (e) {
      toast(`Could not disconnect: ${(e as Error).message}`, '⚠️', 'bad');
    }
  };

  return (
    <Sheet open={open} onClose={() => setOpen(false)} title="Settings" wide>
      <div className="settings">
        <h3>Hero</h3>
        <Field label="Name">
          <Input value={profile?.name ?? ''} maxLength={20} onChange={(e) => updateProfile({ name: e.target.value })} />
        </Field>
        <div className="row gap">
          <Field label="Weight" className="grow">
            <Segmented value={settings.weightUnit} options={[{ value: 'kg', label: 'kg' }, { value: 'lb', label: 'lb' }]} onChange={(v) => updateSettings({ weightUnit: v })} />
          </Field>
          <Field label="Distance" className="grow">
            <Segmented value={settings.distanceUnit} options={[{ value: 'km', label: 'km' }, { value: 'mi', label: 'mi' }]} onChange={(v) => updateSettings({ distanceUnit: v })} />
          </Field>
        </div>
        <Field label="Weekly goal (sessions per week for streaks)">
          <Segmented value={String(settings.weeklyGoal)} options={[2, 3, 4, 5, 6, 7].map((n) => ({ value: String(n), label: String(n) }))} onChange={(v) => updateSettings({ weeklyGoal: Number(v) })} />
        </Field>
        <Field label="Sound effects">
          <Segmented
            value={settings.sound ? 'on' : 'off'}
            options={[{ value: 'on', label: '🔊 On' }, { value: 'off', label: '🔇 Off' }]}
            onChange={(v) => {
              updateSettings({ sound: v === 'on' });
              setSfxEnabled(v === 'on');
            }}
          />
        </Field>

        <h3>Strava</h3>
        {serverOnline === false && (
          <p className="muted small">
            The Tiny Titan server isn't running, so Strava can't connect. Run <code>npm run dev</code> (or deploy the server) with your Strava API keys in <code>.env</code> — see the README.
          </p>
        )}
        {serverOnline && !stravaConfigured && (
          <p className="muted small">
            Server is running but has no Strava keys. Add <code>STRAVA_CLIENT_ID</code> and <code>STRAVA_CLIENT_SECRET</code> to <code>.env</code> and restart.
          </p>
        )}
        {serverOnline && stravaConfigured && !stravaConnected && (
          <div>
            <p className="muted small">Connect to import runs, rides, weight training and climbing sessions automatically.</p>
            <Button variant="secondary" onClick={() => (window.location.href = api.stravaConnectUrl())}>
              Connect Strava
            </Button>
          </div>
        )}
        {serverOnline && stravaConnected && (
          <div className="strava-box">
            <div>
              <div>
                <b>Connected</b>
                {strava.athleteName ? ` as ${strava.athleteName}` : ''}
              </div>
              <div className="muted small">{strava.lastSyncAt ? `Last sync ${new Date(strava.lastSyncAt).toLocaleString()}` : 'Never synced'}</div>
            </div>
            <div className="row gap-s">
              <Button variant="secondary" size="sm" disabled={syncing} onClick={() => { setOpen(false); void syncStrava(); }}>
                {syncing ? 'Syncing…' : 'Sync now'}
              </Button>
              <Button variant="ghost" size="sm" onClick={disconnect}>
                Disconnect
              </Button>
            </div>
          </div>
        )}

        <h3>Data</h3>
        <p className="muted small">
          Everything lives in this browser{serverOnline ? ' and is mirrored to your server' : ''}. Keep a backup.
        </p>
        <div className="row gap wrap">
          <Button variant="secondary" onClick={exportJson}>
            Export backup
          </Button>
          <Button variant="secondary" onClick={() => fileRef.current?.click()}>
            Import backup
          </Button>
          <input
            ref={fileRef}
            type="file"
            accept="application/json"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void importJson(f);
              e.target.value = '';
            }}
          />
          <Button
            variant="danger"
            onClick={() => {
              if (window.confirm('Reset everything? This deletes all sessions, gear and pets.') && window.confirm('Really? There is no undo.')) {
                reset();
                setOpen(false);
              }
            }}
          >
            Reset
          </Button>
        </div>
        <p className="muted tiny">
          Server: {serverOnline === null ? 'checking…' : serverOnline ? 'connected' : 'not running (offline mode)'}
        </p>
      </div>
    </Sheet>
  );
}
