import { useMemo, useState } from 'react';
import { useStore } from '../store/useStore';
import { useUi } from '../store/ui';
import { buildSession, commitSessions, syncStrava, useDerived, usePerks } from '../store/derived';
import { Button, Card, Chip, Field, Input, Segmented } from '../components/ui';
import type { CardioSession, ClimbEntry, ClimbResult, ClimbSession, Discipline, LiftSession, Session } from '../game/types';
import { DISCIPLINES, DISCIPLINE_META } from '../game/types';
import { baseSessionXp, gradeLabel, isDiscipline, MAX_V_GRADE, sessionStats } from '../game/xp';
import { BodyForm } from './Body';
import { kgToUnit, mToUnit, unitToKg, unitToM, fmtPace, fmtSpeed, fmtBigKg, parseDurationInput } from '../game/format';
import { todayKey } from '../game/dates';
import { DEFAULT_EXERCISES } from '../game/summary';
import { sfx } from '../sfx/sounds';

// ---------------------------------------------------------------------------

export function LogScreen() {
  const d = useUi((s) => s.logDiscipline);
  const setLogDiscipline = useUi((s) => s.setLogDiscipline);
  const editingId = useUi((s) => s.editingSessionId);
  const editingBodyId = useUi((s) => s.editingBodyId);
  const sessions = useStore((s) => s.sessions);
  const body = useStore((s) => s.body);
  const editing = editingId ? sessions.find((s) => s.id === editingId) ?? null : null;
  const editingBody = editingBodyId ? body.find((b) => b.id === editingBodyId) ?? null : null;
  const stravaConnected = useUi((s) => s.stravaConnected);
  const syncing = useUi((s) => s.syncing);

  if (editingBody) return <BodyForm key={editingBody.id} editing={editingBody} />;
  if (editing) return <SessionForm key={editing.id} discipline={editing.discipline} editing={editing} />;
  if (d === 'body') return <BodyForm key="new-body" editing={null} />;
  if (d && isDiscipline(d)) return <SessionForm key={d} discipline={d} editing={null} />;

  return (
    <div className="screen">
      <header className="topbar">
        <h1>Log a workout</h1>
      </header>
      <div className="picker-grid">
        {DISCIPLINES.map((x) => (
          <button key={x} className="picker" style={{ '--c': `var(--${x})` } as React.CSSProperties} onClick={() => { sfx.tap(); setLogDiscipline(x); }}>
            <span className="picker-icon">{DISCIPLINE_META[x].icon}</span>
            <span className="picker-name">{DISCIPLINE_META[x].name}</span>
            <span className="picker-sub">
              {x === 'lift' ? 'Reps × weight' : x === 'climb' ? 'V-grades' : 'Distance & time'}
            </span>
          </button>
        ))}
      </div>
      <button
        className="picker picker-wide"
        style={{ '--c': 'var(--accent)' } as React.CSSProperties}
        onClick={() => {
          sfx.tap();
          setLogDiscipline('body');
        }}
      >
        <span className="picker-icon">📸</span>
        <span className="picker-text">
          <span className="picker-name">Body check-in</span>
          <span className="picker-sub">Weight · body fat · front / side / back photos</span>
        </span>
      </button>
      {stravaConnected && (
        <Card className="strava-card">
          <div>
            <b>Strava connected</b>
            <div className="muted small">Runs, rides, weight training and climbing sessions import automatically.</div>
          </div>
          <Button variant="secondary" size="sm" disabled={syncing} onClick={() => void syncStrava()}>
            {syncing ? 'Syncing…' : 'Sync now'}
          </Button>
        </Card>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------

interface SetDraft {
  reps: string;
  weight: string;
}
interface ExerciseDraft {
  name: string;
  bodyweight: boolean;
  sets: SetDraft[];
}
interface ClimbDraft extends ClimbEntry {}

function SessionForm({ discipline, editing }: { discipline: Discipline; editing: Session | null }) {
  const settings = useStore((s) => s.settings);
  const sessions = useStore((s) => s.sessions);
  const updateSession = useStore((s) => s.updateSession);
  const deleteSession = useStore((s) => s.deleteSession);
  const setTab = useUi((s) => s.setTab);
  const setLogDiscipline = useUi((s) => s.setLogDiscipline);
  const setEditingSession = useUi((s) => s.setEditingSession);
  const toast = useUi((s) => s.toast);
  const derived = useDerived();
  const perks = usePerks(derived);
  const meta = DISCIPLINE_META[discipline];
  const wu = settings.weightUnit;
  const du = settings.distanceUnit;

  // --- shared fields ---
  const [date, setDate] = useState(editing?.date ?? todayKey());
  const dur = editing?.durationSec ?? 0;
  const [dh, setDh] = useState(dur ? String(Math.floor(dur / 3600)) : '');
  const [dm, setDm] = useState(dur ? String(Math.floor((dur % 3600) / 60)) : '');
  const [ds, setDs] = useState(dur ? String(dur % 60) : '');
  const [title, setTitle] = useState(editing?.title ?? '');
  const [notes, setNotes] = useState(editing?.notes ?? '');

  // --- lifting ---
  const [exercises, setExercises] = useState<ExerciseDraft[]>(() => {
    if (editing?.discipline === 'lift') {
      return editing.exercises.map((e) => ({
        name: e.name,
        bodyweight: e.sets.every((s) => s.weightKg === 0),
        sets: e.sets.map((s) => ({ reps: String(s.reps), weight: s.weightKg ? trimNum(kgToUnit(s.weightKg, wu)) : '' })),
      }));
    }
    return [{ name: '', bodyweight: false, sets: [{ reps: '', weight: '' }] }];
  });
  // --- climbing ---
  const [climbs, setClimbs] = useState<ClimbDraft[]>(() => (editing?.discipline === 'climb' ? editing.climbs.map((c) => ({ ...c })) : []));
  const [result, setResult] = useState<ClimbResult>('send');
  const [moreGrades, setMoreGrades] = useState(false);
  // --- cardio ---
  const [distance, setDistance] = useState(editing && editing.discipline !== 'lift' && editing.discipline !== 'climb' ? trimNum(mToUnit(editing.distanceM, du)) : '');
  const [elev, setElev] = useState(
    editing && editing.discipline !== 'lift' && editing.discipline !== 'climb' && editing.elevationM ? trimNum(du === 'km' ? editing.elevationM : editing.elevationM * 3.28084) : '',
  );

  const exerciseNames = useMemo(() => {
    const seen = new Map<string, string>();
    for (const s of sessions) if (s.discipline === 'lift') for (const e of s.exercises) seen.set(e.name.trim().toLowerCase(), e.name.trim());
    for (const n of DEFAULT_EXERCISES) if (!seen.has(n.toLowerCase())) seen.set(n.toLowerCase(), n);
    return [...seen.values()].sort();
  }, [sessions]);

  const lastLift = useMemo(() => [...sessions].filter((s): s is LiftSession => s.discipline === 'lift' && s.id !== editing?.id).sort((a, b) => b.createdAt - a.createdAt)[0], [sessions, editing]);

  // --- build the draft session ---
  const durationSec = parseDurationInput(dh, dm, ds);
  const draft: Session | null = useMemo(() => {
    const base = { id: editing?.id ?? 'draft', createdAt: editing?.createdAt ?? 0, date, source: editing?.source ?? ('manual' as const), stravaId: editing?.stravaId, title: title.trim() || undefined, notes: notes.trim() || undefined, durationSec: durationSec || undefined, bonusPct: editing?.bonusPct, luckPct: editing?.luckPct };
    if (discipline === 'lift') {
      const ex = exercises
        .map((e) => ({
          name: e.name.trim(),
          sets: e.sets
            .map((s) => ({ reps: Math.max(0, Math.round(Number(s.reps) || 0)), weightKg: e.bodyweight ? 0 : Math.max(0, unitToKg(Number(s.weight) || 0, wu)) }))
            .filter((s) => s.reps > 0),
        }))
        .filter((e) => e.name && e.sets.length);
      return { ...base, discipline: 'lift', exercises: ex } as LiftSession;
    }
    if (discipline === 'climb') {
      return { ...base, discipline: 'climb', climbs: climbs.filter((c) => c.count > 0) } as ClimbSession;
    }
    const distanceM = Math.max(0, unitToM(Number(distance) || 0, du));
    const elevationM = Math.max(0, du === 'km' ? Number(elev) || 0 : (Number(elev) || 0) / 3.28084);
    return { ...base, discipline, distanceM, elevationM } as CardioSession;
  }, [discipline, editing, date, title, notes, durationSec, exercises, climbs, distance, elev, wu, du]);

  const st = draft ? sessionStats(draft) : null;
  const baseXp = draft ? baseSessionXp(draft) : { xp: 0, parts: [] };
  const bonus = editing ? editing.bonusPct ?? 0 : perks.xp[discipline];
  const estXp = Math.round(baseXp.xp * (1 + bonus));
  const valid =
    !!draft &&
    (discipline === 'lift' ? (draft as LiftSession).exercises.length > 0 : discipline === 'climb' ? (draft as ClimbSession).climbs.length > 0 : (draft as CardioSession).distanceM > 0);

  const close = () => {
    setLogDiscipline(null);
    setEditingSession(null);
    setTab(editing ? 'journey' : 'home');
  };

  const save = () => {
    if (!draft || !valid) return;
    if (editing) {
      updateSession({ ...draft, id: editing.id, createdAt: editing.createdAt });
      toast('Session updated', '✏️', 'good');
      close();
      return;
    }
    const { id: _id, createdAt: _c, bonusPct: _b, luckPct: _l, ...rest } = draft;
    const session = buildSession<Session>(rest as Omit<Session, 'id' | 'createdAt' | 'bonusPct' | 'luckPct'>, derived);
    commitSessions([session], 'Session logged!');
    setLogDiscipline(null);
    setTab('home');
  };

  const remove = () => {
    if (!editing) return;
    if (!window.confirm('Delete this session? Your levels and unlocks will be recalculated.')) return;
    deleteSession(editing.id);
    toast('Session deleted', '🗑️');
    close();
  };

  // --- lifting helpers ---
  const setEx = (i: number, patch: Partial<ExerciseDraft>) => setExercises((xs) => xs.map((e, k) => (k === i ? { ...e, ...patch } : e)));
  const setSet = (i: number, j: number, patch: Partial<SetDraft>) =>
    setExercises((xs) => xs.map((e, k) => (k === i ? { ...e, sets: e.sets.map((s, m) => (m === j ? { ...s, ...patch } : s)) } : e)));
  const addSet = (i: number) => {
    sfx.tick();
    setExercises((xs) => xs.map((e, k) => (k === i ? { ...e, sets: [...e.sets, { ...(e.sets[e.sets.length - 1] ?? { reps: '', weight: '' }) }] } : e)));
  };
  const removeSet = (i: number, j: number) => setExercises((xs) => xs.map((e, k) => (k === i ? { ...e, sets: e.sets.filter((_, m) => m !== j) } : e)));
  const addExercise = () => {
    sfx.tick();
    setExercises((xs) => [...xs, { name: '', bodyweight: false, sets: [{ reps: '', weight: '' }] }]);
  };
  const removeExercise = (i: number) => setExercises((xs) => xs.filter((_, k) => k !== i));
  const repeatLast = () => {
    if (!lastLift) return;
    sfx.tap();
    setExercises(
      lastLift.exercises.map((e) => ({
        name: e.name,
        bodyweight: e.sets.every((s) => s.weightKg === 0),
        sets: e.sets.map((s) => ({ reps: String(s.reps), weight: s.weightKg ? trimNum(kgToUnit(s.weightKg, wu)) : '' })),
      })),
    );
  };

  // --- climbing helpers ---
  const addClimb = (grade: number) => {
    sfx.tick();
    setClimbs((cs) => {
      const i = cs.findIndex((c) => c.grade === grade && c.result === result);
      if (i >= 0) return cs.map((c, k) => (k === i ? { ...c, count: c.count + 1 } : c));
      return [...cs, { grade, result, count: 1 }];
    });
  };
  const bumpClimb = (idx: number, delta: number) =>
    setClimbs((cs) => cs.map((c, k) => (k === idx ? { ...c, count: Math.max(0, c.count + delta) } : c)).filter((c) => c.count > 0));
  const gradeList = Array.from({ length: (moreGrades ? MAX_V_GRADE : 10) + 2 }, (_, i) => i - 1);
  const sortedClimbs = climbs.map((c, idx) => ({ ...c, idx })).sort((a, b) => b.grade - a.grade || a.result.localeCompare(b.result));

  return (
    <div className="screen form-screen">
      <header className="topbar">
        <button className="icon-btn" onClick={close} aria-label="Back">
          ←
        </button>
        <h1>
          {meta.icon} {editing ? 'Edit' : 'Log'} {meta.name.toLowerCase()}
        </h1>
        {editing && (
          <button className="icon-btn" onClick={remove} aria-label="Delete">
            🗑️
          </button>
        )}
      </header>
      {editing?.source === 'strava' && (discipline === 'lift' || discipline === 'climb') && (
        <Card className="hint-card">
          Imported from Strava with duration only. Add your {discipline === 'lift' ? 'sets' : 'climbs'} below to earn full XP for it.
        </Card>
      )}

      <div className="row gap">
        <Field label="Date" className="grow">
          <Input type="date" value={date} max={todayKey()} onChange={(e) => setDate(e.target.value)} />
        </Field>
        <Field label="Duration (h : m : s)" className="grow">
          <div className="row gap-s">
            <Input inputMode="numeric" placeholder="0" value={dh} onChange={(e) => setDh(e.target.value)} className="num" />
            <Input inputMode="numeric" placeholder="45" value={dm} onChange={(e) => setDm(e.target.value)} className="num" />
            <Input inputMode="numeric" placeholder="00" value={ds} onChange={(e) => setDs(e.target.value)} className="num" />
          </div>
        </Field>
      </div>

      {discipline === 'lift' && (
        <div className="exercises">
          <datalist id="exercise-names">
            {exerciseNames.map((n) => (
              <option key={n} value={n} />
            ))}
          </datalist>
          {exercises.map((e, i) => (
            <Card key={i} className="exercise">
              <div className="row gap-s">
                <Input list="exercise-names" placeholder="Exercise (e.g. Squat)" value={e.name} onChange={(ev) => setEx(i, { name: ev.target.value })} className="grow" />
                <Chip active={e.bodyweight} onClick={() => setEx(i, { bodyweight: !e.bodyweight })}>
                  BW
                </Chip>
                <button className="icon-btn" onClick={() => removeExercise(i)} aria-label="Remove exercise">
                  ✕
                </button>
              </div>
              <div className="sets">
                <div className="set-head">
                  <span>Set</span>
                  <span>Reps</span>
                  <span>{e.bodyweight ? '' : wu}</span>
                  <span />
                </div>
                {e.sets.map((s, j) => (
                  <div key={j} className="set-row">
                    <span className="set-n">{j + 1}</span>
                    <Input inputMode="numeric" placeholder="reps" value={s.reps} onChange={(ev) => setSet(i, j, { reps: ev.target.value })} />
                    {e.bodyweight ? <span className="muted small">bodyweight</span> : <Input inputMode="decimal" placeholder={wu} value={s.weight} onChange={(ev) => setSet(i, j, { weight: ev.target.value })} />}
                    <button className="icon-btn small" onClick={() => removeSet(i, j)} aria-label="Remove set">
                      ✕
                    </button>
                  </div>
                ))}
              </div>
              <Button variant="ghost" size="sm" onClick={() => addSet(i)}>
                + Set
              </Button>
            </Card>
          ))}
          <div className="row gap">
            <Button variant="secondary" onClick={addExercise} className="grow">
              + Exercise
            </Button>
            {lastLift && !editing && (
              <Button variant="ghost" onClick={repeatLast}>
                Repeat last
              </Button>
            )}
          </div>
        </div>
      )}

      {discipline === 'climb' && (
        <div className="climbs">
          <Segmented
            value={result}
            onChange={setResult}
            color={result === 'flash' ? '#c98500' : result === 'send' ? 'var(--climb)' : 'var(--line)'}
            options={[
              { value: 'flash', label: '⚡ Flash' },
              { value: 'send', label: '✅ Send' },
              { value: 'attempt', label: '🔁 Attempt' },
            ]}
          />
          <div className="muted small">Tap a grade to add one {result}.</div>
          <div className="grade-grid">
            {gradeList.map((g) => (
              <button key={g} className="grade" onClick={() => addClimb(g)} style={{ '--g': gradeHue(g) } as React.CSSProperties}>
                {gradeLabel(g)}
              </button>
            ))}
            <button className="grade grade-more" onClick={() => setMoreGrades((m) => !m)}>
              {moreGrades ? 'Less' : 'More…'}
            </button>
          </div>
          {sortedClimbs.length > 0 && (
            <Card>
              {sortedClimbs.map((c) => (
                <div key={`${c.grade}-${c.result}`} className="climb-row">
                  <span className="climb-grade" style={{ background: gradeHue(c.grade) }}>
                    {gradeLabel(c.grade)}
                  </span>
                  <span className="climb-result">{c.result === 'flash' ? '⚡ Flash' : c.result === 'send' ? '✅ Send' : '🔁 Attempt'}</span>
                  <span className="climb-count">
                    <button className="icon-btn small" onClick={() => bumpClimb(c.idx, -1)} aria-label="Minus one">
                      −
                    </button>
                    <b>{c.count}</b>
                    <button className="icon-btn small" onClick={() => bumpClimb(c.idx, 1)} aria-label="Plus one">
                      +
                    </button>
                  </span>
                </div>
              ))}
            </Card>
          )}
        </div>
      )}

      {(discipline === 'run' || discipline === 'ride') && (
        <div className="row gap">
          <Field label={`Distance (${du})`} className="grow">
            <Input inputMode="decimal" placeholder="0.0" value={distance} onChange={(e) => setDistance(e.target.value)} autoFocus={!editing} />
          </Field>
          <Field label={`Elevation gain (${du === 'km' ? 'm' : 'ft'})`} className="grow">
            <Input inputMode="numeric" placeholder="0" value={elev} onChange={(e) => setElev(e.target.value)} />
          </Field>
        </div>
      )}

      <details className="extra">
        <summary>Title &amp; notes</summary>
        <Field label="Title">
          <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Optional" />
        </Field>
        <Field label="Notes">
          <textarea className="input" rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="How did it go?" />
        </Field>
      </details>

      <Card className="xp-preview">
        <div className="xp-preview-main">
          <span className="pixel-font xp-big" style={{ color: `var(--${discipline})` }}>
            +{estXp.toLocaleString('en-US')} XP
          </span>
          {bonus > 0 && <span className="muted small">incl. +{Math.round(bonus * 100)}% gear bonus</span>}
        </div>
        <div className="xp-preview-sub muted small">
          {st && discipline === 'lift' && `${fmtBigKg(st.volumeKg, wu)} · ${st.reps + st.bwReps} reps · ${st.sets} sets`}
          {st && discipline === 'climb' && `${st.sends} sends · ${st.flashes} flashes · ${st.attempts} attempts${st.maxGradeSent !== null ? ` · max ${gradeLabel(st.maxGradeSent)}` : ''}`}
          {st && discipline === 'run' && (st.paceSecPerKm !== null ? `Pace ${fmtPace(st.paceSecPerKm, du)}` : 'Add a duration for pace')}
          {st && discipline === 'ride' && (st.speedKmh !== null ? `Avg ${fmtSpeed(st.speedKmh, du)}` : 'Add a duration for speed')}
        </div>
      </Card>

      <div className="form-actions">
        <Button variant="ghost" onClick={close}>
          Cancel
        </Button>
        <Button size="lg" variant="good" disabled={!valid} onClick={save} className="grow">
          {editing ? 'Save changes' : 'Finish session ✓'}
        </Button>
      </div>
    </div>
  );
}

function trimNum(n: number): string {
  const r = Math.round(n * 100) / 100;
  return String(r);
}

export function gradeHue(g: number): string {
  const t = Math.max(0, Math.min(1, (g + 1) / 14));
  const h = 150 - t * 150; // green → red
  return `hsl(${h}, 60%, 38%)`;
}
