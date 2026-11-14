import { useRef, useState } from 'react';
import { useStore, parseSavedState, pickSaved, referencedPhotoIds } from '../store/useStore';
import { useUi } from '../store/ui';
import { refreshHealth, unlockServer } from '../store/sync';
import { syncStrava } from '../store/derived';
import { exportPhotos, importPhotos } from '../store/photos';
import { api } from '../api/client';
import { Button, Field, Input, Segmented, Sheet } from '../components/ui';
import { setSfxEnabled } from '../sfx/sounds';

export function SettingsSheet() {
  const open = useUi((s) => s.settingsOpen);
  const setOpen = useUi((s) => s.setSettingsOpen);
  const profile = useStore((s) => s.profile);
  const settings = useStore((s) => s.settings);
  const strava = useStore((s) => s.strava);
  const photoCount = useStore((s) => referencedPhotoIds(s.body).length);
  const updateProfile = useStore((s) => s.updateProfile);
  const updateSettings = useStore((s) => s.updateSettings);
  const replaceAll = useStore((s) => s.replaceAll);
  const reset = useStore((s) => s.reset);
  const setStrava = useStore((s) => s.setStrava);
  const toast = useUi((s) => s.toast);
  const serverOnline = useUi((s) => s.serverOnline);
  const serverLocked = useUi((s) => s.serverLocked);
  const stravaConfigured = useUi((s) => s.stravaConfigured);
  const stravaConnected = useUi((s) => s.stravaConnected);
  const syncing = useUi((s) => s.syncing);
  const fileRef = useRef<HTMLInputElement>(null);
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const ready = serverOnline && !serverLocked;

  const exportJson = async () => {
    setBusy(true);
    try {
      const saved = pickSaved(useStore.getState());
      const photos = await exportPhotos(referencedPhotoIds(saved.body));
      const data = JSON.stringify({ ...saved, photos }, null, 2);
      const blob = new Blob([data], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `tiny-titan-backup-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      toast(`Export failed: ${(e as Error).message}`, '⚠️', 'bad');
    } finally {
      setBusy(false);
    }
  };

  const importJson = async (file: File) => {
    try {
      const raw = JSON.parse(await file.text());
      const parsed = parseSavedState(raw);
      if (!window.confirm(`Import ${parsed.sessions.length} sessions and ${parsed.body.length} check-ins? This replaces your current data.`)) return;
      const n = await importPhotos(raw?.photos);
      replaceAll({ ...parsed, updatedAt: Date.now() });
      toast(`Backup imported${n ? ` with ${n} photos` : ''}`, '📦', 'good');
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

  const unlock = async () => {
    if (!password) return;
    setBusy(true);
    try {
      await unlockServer(password);
      setPassword('');
      toast('Server unlocked — syncing', '🔓', 'good');
    } catch (e) {
      toast((e as Error).message || 'Could not unlock', '⚠️', 'bad');
    } finally {
      setBusy(false);
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

        <h3>Saving</h3>
        {serverOnline === false && <p className="muted small">Saved in this browser only. Start Tiny Titan with its launcher to also keep a copy on disk.</p>}
        {serverOnline && serverLocked && (
          <div>
            <p className="muted small">This server is password-protected. Enter the password to sync your data and photos.</p>
            <div className="row gap-s">
              <Input type="password" placeholder="Server password" value={password} onChange={(e) => setPassword(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && void unlock()} autoComplete="current-password" className="grow" />
              <Button variant="secondary" disabled={busy || !password} onClick={() => void unlock()}>
                Unlock
              </Button>
            </div>
          </div>
        )}
        {ready && (
          <p className="muted small">
            Saved in this browser, with a copy kept on disk by Tiny Titan (its <code>server/data</code> folder) — so your log survives even if the browser's data is cleared.
          </p>
        )}

        {/* Strava is optional: it only appears once the server has been given API keys. */}
        {ready && stravaConfigured && <h3>Strava</h3>}
        {ready && stravaConfigured && !stravaConnected && (
          <div>
            <p className="muted small">Connect to import runs, rides, weight training and climbing sessions automatically.</p>
            <Button variant="secondary" onClick={() => (window.location.href = api.stravaConnectUrl())}>
              Connect Strava
            </Button>
          </div>
        )}
        {ready && stravaConnected && (
          <div className="strava-box">
            <div>
              <div>
                <b>Connected</b>
                {strava.athleteName ? ` as ${strava.athleteName}` : ''}
              </div>
              <div className="muted small">{strava.lastSyncAt ? `Last sync ${new Date(strava.lastSyncAt).toLocaleString()}` : 'Never synced'}</div>
            </div>
            <div className="row gap-s">
              <Button
                variant="secondary"
                size="sm"
                disabled={syncing}
                onClick={() => {
                  setOpen(false);
                  void syncStrava();
                }}
              >
                {syncing ? 'Syncing…' : 'Sync now'}
              </Button>
              <Button variant="ghost" size="sm" onClick={() => void disconnect()}>
                Disconnect
              </Button>
            </div>
          </div>
        )}

        <h3>Data</h3>
        <p className="muted small">
          Backups include your sessions, check-ins{photoCount ? ` and all ${photoCount} progress photos` : ''}. Photos never leave this device{ready ? ' and your own server' : ''}.
        </p>
        <div className="row gap wrap">
          <Button variant="secondary" disabled={busy} onClick={() => void exportJson()}>
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
              if (window.confirm('Reset everything? This deletes all sessions, check-ins, gear and pets.') && window.confirm('Really? There is no undo.')) {
                reset();
                setOpen(false);
              }
            }}
          >
            Reset
          </Button>
        </div>
        <p className="muted tiny">Disk copy: {serverOnline === null ? 'checking…' : serverOnline ? (serverLocked ? 'locked' : 'on') : 'off (browser only)'}</p>
      </div>
    </Sheet>
  );
}
