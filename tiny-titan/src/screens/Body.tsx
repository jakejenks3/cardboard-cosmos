// Body tracking: the check-in form (weight, body fat, front/side/back
// photos) and the Journey → Body view (trends, then-and-now photo compare,
// gallery).

import { useEffect, useMemo, useRef, useState } from 'react';
import { useStore } from '../store/useStore';
import { useUi } from '../store/ui';
import { commitBody, useDerived } from '../store/derived';
import { processImage, removePhoto, savePhoto, usePhotoUrl } from '../store/photos';
import { Button, Card, Empty, Field, Input, SectionTitle, Segmented, Stat } from '../components/ui';
import { LineChart, movingAverage } from '../components/charts';
import type { BodyEntry, PhotoAngle } from '../game/types';
import { PHOTO_ANGLES, PHOTO_ANGLE_NAMES } from '../game/types';
import { bodyEntryReward } from '../game/derive';
import { daysBetween, formatDate, formatDateLong, todayKey, weekKey } from '../game/dates';
import { fmtWeight, kgToUnit, unitToKg } from '../game/format';
import { uid } from '../game/rng';
import { sfx } from '../sfx/sounds';

export function PhotoThumb({ id, alt, className = '', onClick }: { id: string | undefined; alt: string; className?: string; onClick?: () => void }) {
  const url = usePhotoUrl(id);
  if (!id) return <div className={`photo-empty ${className}`} aria-label={`${alt} (none)`} />;
  if (!url) return <div className={`photo-empty photo-loading ${className}`} aria-label={`${alt} (loading)`} />;
  return <img src={url} alt={alt} className={`photo-img ${className}`} onClick={onClick} loading="lazy" />;
}

function PhotoViewer({ id, onClose }: { id: string | null; onClose: () => void }) {
  const url = usePhotoUrl(id);
  if (!id) return null;
  return (
    <div className="photo-viewer" onClick={onClose} role="dialog" aria-modal="true">
      {url ? <img src={url} alt="Progress photo" /> : <div className="muted">Loading…</div>}
      <button className="icon-btn photo-viewer-close" aria-label="Close">
        ✕
      </button>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Check-in form
// ---------------------------------------------------------------------------

interface SlotState {
  /** Existing stored photo that is being kept. */
  id?: string;
  /** Newly picked photo, not yet stored. */
  blob?: Blob;
  preview?: string;
  /** Stored photo to delete on save (replaced or cleared). */
  removedId?: string;
}

const ANGLE_HINT: Record<PhotoAngle, string> = { front: 'Facing the camera', side: 'Turned 90°', back: 'Facing away' };

function PhotoSlot({ angle, slot, busy, onPick, onClear }: { angle: PhotoAngle; slot: SlotState; busy: boolean; onPick: (f: File) => void; onClear: () => void }) {
  const stored = usePhotoUrl(slot.preview ? undefined : slot.id);
  const src = slot.preview ?? stored;
  const input = useRef<HTMLInputElement>(null);
  return (
    <div className="photo-slot">
      <label className={`photo-drop ${src ? 'photo-has' : ''}`}>
        {src ? (
          <img src={src} alt={`${PHOTO_ANGLE_NAMES[angle]} progress photo`} />
        ) : (
          <span className="photo-placeholder">
            <span className="photo-plus">{busy ? '…' : '＋'}</span>
            <span className="tiny muted">{ANGLE_HINT[angle]}</span>
          </span>
        )}
        <input
          ref={input}
          type="file"
          accept="image/*"
          hidden
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) onPick(f);
            e.target.value = '';
          }}
        />
      </label>
      <div className="photo-slot-foot">
        <span className="photo-label">{PHOTO_ANGLE_NAMES[angle]}</span>
        {src && (
          <button type="button" className="link" onClick={onClear}>
            Remove
          </button>
        )}
      </div>
    </div>
  );
}

function trimNum(n: number): string {
  return String(Math.round(n * 10) / 10);
}

export function BodyForm({ editing }: { editing: BodyEntry | null }) {
  const settings = useStore((s) => s.settings);
  const updateBody = useStore((s) => s.updateBody);
  const deleteBody = useStore((s) => s.deleteBody);
  const setTab = useUi((s) => s.setTab);
  const setJourneyTab = useUi((s) => s.setJourneyTab);
  const setLogDiscipline = useUi((s) => s.setLogDiscipline);
  const setEditingBody = useUi((s) => s.setEditingBody);
  const toast = useUi((s) => s.toast);
  const derived = useDerived();
  const wu = settings.weightUnit;

  const [date, setDate] = useState(editing?.date ?? todayKey());
  const [weight, setWeight] = useState(editing?.weightKg ? trimNum(kgToUnit(editing.weightKg, wu)) : '');
  const [bf, setBf] = useState(editing?.bodyFatPct ? String(editing.bodyFatPct) : '');
  const [note, setNote] = useState(editing?.note ?? '');
  const [slots, setSlots] = useState<Record<PhotoAngle, SlotState>>(() => ({
    front: { id: editing?.photos?.front },
    side: { id: editing?.photos?.side },
    back: { id: editing?.photos?.back },
  }));
  const [busy, setBusy] = useState<PhotoAngle | 'save' | null>(null);

  // Revoke any preview URLs when the form goes away.
  const slotsRef = useRef(slots);
  slotsRef.current = slots;
  useEffect(
    () => () => {
      for (const a of PHOTO_ANGLES) {
        const p = slotsRef.current[a].preview;
        if (p) URL.revokeObjectURL(p);
      }
    },
    [],
  );

  const pick = async (angle: PhotoAngle, file: File) => {
    setBusy(angle);
    try {
      const blob = await processImage(file);
      const preview = URL.createObjectURL(blob);
      setSlots((s) => {
        const prev = s[angle];
        if (prev.preview) URL.revokeObjectURL(prev.preview);
        return { ...s, [angle]: { blob, preview, removedId: prev.id ?? prev.removedId } };
      });
      sfx.shutter();
    } catch (e) {
      toast((e as Error).message || 'Could not read that image', '⚠️', 'bad');
    } finally {
      setBusy(null);
    }
  };

  const clear = (angle: PhotoAngle) =>
    setSlots((s) => {
      const prev = s[angle];
      if (prev.preview) URL.revokeObjectURL(prev.preview);
      return { ...s, [angle]: { removedId: prev.id ?? prev.removedId } };
    });

  const w = Number(weight);
  const weightKg = w > 0 ? Math.round(unitToKg(w, wu) * 100) / 100 : undefined;
  const fat = Number(bf);
  const bodyFatPct = fat > 0 ? Math.round(fat * 10) / 10 : undefined;
  const nPhotos = PHOTO_ANGLES.filter((a) => slots[a].blob || slots[a].id).length;
  const weightBad = weightKg !== undefined && (weightKg < 20 || weightKg > 400);
  const fatBad = bodyFatPct !== undefined && (bodyFatPct < 2 || bodyFatPct > 75);
  const valid = !weightBad && !fatBad && (weightKg !== undefined || bodyFatPct !== undefined || nPhotos > 0);

  const preview = useMemo(() => {
    if (editing) return null;
    const flags = derived.body.weekFlags[weekKey(date)] ?? 0;
    const photos: BodyEntry['photos'] = {};
    for (const a of PHOTO_ANGLES) if (slots[a].blob || slots[a].id) photos[a] = 'x';
    return bodyEntryReward(flags, { weightKg, bodyFatPct, photos }).xp;
  }, [editing, derived, date, weightKg, bodyFatPct, slots]);

  const close = () => {
    setLogDiscipline(null);
    setEditingBody(null);
    setJourneyTab('body');
    setTab('journey');
  };

  const save = async () => {
    if (!valid || busy) return;
    setBusy('save');
    try {
      const photos: Partial<Record<PhotoAngle, string>> = {};
      for (const a of PHOTO_ANGLES) {
        const slot = slots[a];
        if (slot.blob) {
          const id = uid('ph');
          await savePhoto(id, slot.blob);
          photos[a] = id;
        } else if (slot.id) {
          photos[a] = slot.id;
        }
        if (slot.removedId) await removePhoto(slot.removedId);
      }
      const entry: BodyEntry = {
        id: editing?.id ?? uid('b'),
        date,
        createdAt: editing?.createdAt ?? Date.now(),
        weightKg,
        bodyFatPct,
        photos: Object.keys(photos).length ? photos : undefined,
        note: note.trim() || undefined,
      };
      if (editing) {
        updateBody(entry);
        toast('Check-in updated', '✏️', 'good');
      } else {
        commitBody(entry);
      }
      close();
    } catch (e) {
      toast(`Could not save: ${(e as Error).message}`, '⚠️', 'bad');
      setBusy(null);
    }
  };

  const remove = async () => {
    if (!editing) return;
    if (!window.confirm('Delete this check-in and its photos?')) return;
    for (const id of Object.values(editing.photos ?? {})) if (id) await removePhoto(id);
    deleteBody(editing.id);
    toast('Check-in deleted', '🗑️');
    close();
  };

  return (
    <div className="screen form-screen">
      <header className="topbar">
        <button className="icon-btn" onClick={close} aria-label="Back">
          ←
        </button>
        <h1>📸 {editing ? 'Edit check-in' : 'Body check-in'}</h1>
        {editing && (
          <button className="icon-btn" onClick={() => void remove()} aria-label="Delete">
            🗑️
          </button>
        )}
      </header>

      <Field label="Date">
        <Input type="date" value={date} max={todayKey()} onChange={(e) => setDate(e.target.value)} />
      </Field>
      <div className="row gap">
        <Field label={`Weight (${wu})`} className="grow" hint={weightBad ? 'That does not look right.' : undefined}>
          <Input inputMode="decimal" placeholder="0.0" value={weight} onChange={(e) => setWeight(e.target.value)} />
        </Field>
        <Field label="Body fat (%)" className="grow" hint={fatBad ? 'Between 2 and 75.' : 'Optional'}>
          <Input inputMode="decimal" placeholder="—" value={bf} onChange={(e) => setBf(e.target.value)} />
        </Field>
      </div>

      <SectionTitle right={<span className="muted small">{nPhotos}/3</span>}>Progress photos</SectionTitle>
      <div className="photo-slots">
        {PHOTO_ANGLES.map((a) => (
          <PhotoSlot key={a} angle={a} slot={slots[a]} busy={busy === a} onPick={(f) => void pick(a, f)} onClear={() => clear(a)} />
        ))}
      </div>
      <p className="muted tiny">
        Tip: same spot, same light, same time of day. Photos are stored on this device{useUi.getState().serverOnline && !useUi.getState().serverLocked ? ' and on your own Tiny Titan server' : ''} — nowhere else.
      </p>

      <Field label="Note">
        <textarea className="input" rows={2} value={note} onChange={(e) => setNote(e.target.value)} placeholder="How are you feeling?" />
      </Field>

      {preview !== null && (
        <Card className="xp-preview">
          <div className="xp-preview-main">
            <span className="pixel-font xp-big" style={{ color: 'var(--accent)' }}>
              +{preview} XP
            </span>
            <span className="muted small">weekly check-in bonus</span>
          </div>
          <div className="xp-preview-sub muted small">
            {preview > 0 ? 'Weight 60 · body fat 20 · 15 per photo — each paid once per week.' : 'This week’s bonus is already earned. Still worth logging for the trend.'}
          </div>
        </Card>
      )}

      <div className="form-actions">
        <Button variant="ghost" onClick={close}>
          Cancel
        </Button>
        <Button size="lg" variant="good" disabled={!valid || busy !== null} onClick={() => void save()} className="grow">
          {busy === 'save' ? 'Saving…' : editing ? 'Save changes' : 'Check in ✓'}
        </Button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Journey → Body
// ---------------------------------------------------------------------------

export function BodyJourney() {
  const body = useStore((s) => s.body);
  const settings = useStore((s) => s.settings);
  const derived = useDerived();
  const setTab = useUi((s) => s.setTab);
  const setLogDiscipline = useUi((s) => s.setLogDiscipline);
  const setEditingBody = useUi((s) => s.setEditingBody);
  const wu = settings.weightUnit;

  const [angle, setAngle] = useState<PhotoAngle>('front');
  const [thenId, setThenId] = useState<string | null>(null);
  const [nowId, setNowId] = useState<string | null>(null);
  const [viewer, setViewer] = useState<string | null>(null);

  const entries = useMemo(() => [...body].sort((a, b) => a.date.localeCompare(b.date) || a.createdAt - b.createdAt), [body]);
  const weights = useMemo(() => entries.filter((e) => e.weightKg).map((e) => ({ x: e.date, y: kgToUnit(e.weightKg!, wu) })), [entries, wu]);
  const fats = useMemo(() => entries.filter((e) => e.bodyFatPct).map((e) => ({ x: e.date, y: e.bodyFatPct! })), [entries]);
  const withAngle = entries.filter((e) => e.photos?.[angle]);
  const withPhotos = [...entries].filter((e) => e.photos && Object.values(e.photos).some(Boolean)).reverse();

  const startCheckIn = () => {
    setEditingBody(null);
    setLogDiscipline('body');
    setTab('log');
  };
  const edit = (id: string) => {
    setEditingBody(id);
    setTab('log');
  };

  if (entries.length === 0) {
    return (
      <Empty
        icon="📸"
        title="See how far you've come"
        body="Check in with your weight, body fat or front / side / back photos. A weekly check-in earns XP, and the photos line up into a then-and-now you can actually see."
        action={<Button onClick={startCheckIn}>Start a check-in</Button>}
      />
    );
  }

  const b = derived.body;
  const delta = b.latestWeightKg !== null && b.firstWeightKg !== null ? b.latestWeightKg - b.firstWeightKg : null;
  const lean = b.latestWeightKg !== null && b.latestBodyFat !== null ? b.latestWeightKg * (1 - b.latestBodyFat / 100) : null;
  const then = withAngle.find((e) => e.id === thenId) ?? withAngle[0];
  const now = withAngle.find((e) => e.id === nowId) ?? withAngle[withAngle.length - 1];
  const caption = (e: BodyEntry) => `${formatDate(e.date, { month: 'short', day: 'numeric', year: 'numeric' })}${e.weightKg ? ` · ${fmtWeight(e.weightKg, wu)}` : ''}`;

  return (
    <>
      <div className="tiles">
        <Stat label="Weight" value={b.latestWeightKg !== null ? fmtWeight(b.latestWeightKg, wu) : '—'} sub={b.latestWeightDate ? formatDate(b.latestWeightDate) : undefined} />
        <Stat
          label="Since start"
          value={delta !== null && b.firstWeightDate !== b.latestWeightDate ? `${delta > 0 ? '+' : delta < 0 ? '−' : ''}${fmtWeight(Math.abs(delta), wu)}` : '—'}
          sub={b.firstWeightDate ? `from ${formatDate(b.firstWeightDate)}` : undefined}
        />
        <Stat label="Body fat" value={b.latestBodyFat !== null ? `${b.latestBodyFat}%` : '—'} sub={lean !== null ? `lean ${fmtWeight(lean, wu)}` : undefined} />
      </div>
      <div className="row between">
        <span className="muted small">
          🗓️ {b.streak} week check-in streak · best {b.bestStreak}
        </span>
        <Button size="sm" onClick={startCheckIn}>
          + Check in
        </Button>
      </div>

      {weights.length >= 2 && (
        <>
          <SectionTitle>Weight</SectionTitle>
          <Card>
            <LineChart points={weights} trend={weights.length >= 5 ? movingAverage(weights, 5) : undefined} color="var(--accent)" fmt={(v) => `${v.toFixed(1)} ${wu}`} label="Body weight over time" />
            {weights.length >= 5 && <div className="muted tiny">Dashed line: smoothed trend (5-entry average)</div>}
          </Card>
        </>
      )}
      {fats.length >= 2 && (
        <>
          <SectionTitle>Body fat</SectionTitle>
          <Card>
            <LineChart points={fats} color="var(--run)" fmt={(v) => `${v.toFixed(1)}%`} label="Body fat percentage over time" />
          </Card>
        </>
      )}

      {withPhotos.length > 0 && (
        <>
          <SectionTitle>Then &amp; now</SectionTitle>
          <Card className="compare">
            <Segmented value={angle} onChange={setAngle} options={PHOTO_ANGLES.map((a) => ({ value: a, label: PHOTO_ANGLE_NAMES[a] }))} />
            {withAngle.length === 0 ? (
              <div className="muted small center">No {PHOTO_ANGLE_NAMES[angle].toLowerCase()} photos yet.</div>
            ) : (
              <>
                <div className="compare-grid">
                  {[then, now].map((e, i) => (
                    <figure key={i} className="compare-cell">
                      <PhotoThumb id={e.photos?.[angle]} alt={`${PHOTO_ANGLE_NAMES[angle]} on ${e.date}`} onClick={() => setViewer(e.photos?.[angle] ?? null)} />
                      <figcaption>
                        <span className="compare-tag">{i === 0 ? 'Then' : 'Now'}</span>
                        <select className="input compare-select" value={e.id} onChange={(ev) => (i === 0 ? setThenId(ev.target.value) : setNowId(ev.target.value))} aria-label={i === 0 ? 'Then date' : 'Now date'}>
                          {withAngle.map((o) => (
                            <option key={o.id} value={o.id}>
                              {caption(o)}
                            </option>
                          ))}
                        </select>
                      </figcaption>
                    </figure>
                  ))}
                </div>
                {then.id !== now.id ? (
                  <div className="compare-delta">
                    <b>{daysBetween(then.date, now.date)} days</b> apart
                    {then.weightKg && now.weightKg ? (
                      <>
                        {' '}
                        · {fmtWeight(then.weightKg, wu)} → {fmtWeight(now.weightKg, wu)}
                      </>
                    ) : null}
                  </div>
                ) : (
                  <div className="muted small center">Add another check-in with photos to compare.</div>
                )}
              </>
            )}
          </Card>

          <SectionTitle>Gallery</SectionTitle>
          <div className="gallery">
            {withPhotos.map((e) => (
              <Card key={e.id} className="gallery-row">
                <div className="row between">
                  <b>{formatDateLong(e.date)}</b>
                  <button className="link" onClick={() => edit(e.id)}>
                    Edit
                  </button>
                </div>
                <div className="gallery-thumbs">
                  {PHOTO_ANGLES.map((a) => (
                    <PhotoThumb key={a} id={e.photos?.[a]} alt={`${PHOTO_ANGLE_NAMES[a]} on ${e.date}`} onClick={() => setViewer(e.photos?.[a] ?? null)} />
                  ))}
                </div>
                {(e.weightKg || e.bodyFatPct) && (
                  <div className="muted small">
                    {e.weightKg ? fmtWeight(e.weightKg, wu) : ''}
                    {e.weightKg && e.bodyFatPct ? ' · ' : ''}
                    {e.bodyFatPct ? `${e.bodyFatPct}% body fat` : ''}
                  </div>
                )}
              </Card>
            ))}
          </div>
        </>
      )}

      <SectionTitle>All check-ins</SectionTitle>
      <div className="session-list">
        {[...entries].reverse().map((e) => {
          const n = Object.values(e.photos ?? {}).filter(Boolean).length;
          return (
            <button key={e.id} className="session-row" onClick={() => edit(e.id)}>
              <span className="session-icon" style={{ background: 'var(--panel-2)' }}>
                {n > 0 ? '📸' : '⚖️'}
              </span>
              <span className="session-main">
                <span className="session-title">{formatDateLong(e.date)}</span>
                <span className="session-sub muted small">
                  {[e.weightKg ? fmtWeight(e.weightKg, wu) : null, e.bodyFatPct ? `${e.bodyFatPct}% fat` : null, n ? `${n} photo${n === 1 ? '' : 's'}` : null, e.note ?? null].filter(Boolean).join(' · ')}
                </span>
              </span>
              <span className="session-right">
                {(derived.bodyXp[e.id] ?? 0) > 0 && <span className="session-xp">+{derived.bodyXp[e.id]}</span>}
              </span>
            </button>
          );
        })}
      </div>
      <PhotoViewer id={viewer} onClose={() => setViewer(null)} />
    </>
  );
}
