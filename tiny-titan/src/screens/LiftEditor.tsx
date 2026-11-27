// The lifting part of the log form. Built so a normal session is mostly
// taps: pick an exercise and last time's sets are already filled in, then
// nudge reps / weight with + and − (or bump every set at once).

import { useMemo, useState, type Dispatch, type SetStateAction } from 'react';
import { useStore } from '../store/useStore';
import { Button, Card, Chip, Input } from '../components/ui';
import { Stepper } from '../components/Stepper';
import type { LiftPr } from '../game/state';
import type { LiftSession, LiftSet, Settings } from '../game/types';
import { WEIGHT_STEPS, weightStepOf } from '../game/types';
import { normalizeExercise } from '../game/xp';
import { compareSet, describeSets, exerciseSuggestions, lastPerformances, recentWorkouts, stepValue, topSetLabel, volumeKg, type SetTrend } from '../game/liftHistory';
import { DEFAULT_EXERCISES } from '../game/summary';
import { fmtWeight, kgToUnit, unitToKg } from '../game/format';
import { relativeDay } from '../game/dates';
import { sfx } from '../sfx/sounds';

export interface SetDraft {
  reps: string;
  weight: string;
}
export interface ExerciseDraft {
  name: string;
  bodyweight: boolean;
  sets: SetDraft[];
}

type Unit = Settings['weightUnit'];

export function trimNum(n: number): string {
  return String(Math.round(n * 100) / 100);
}

export function draftFromSets(name: string, sets: LiftSet[], wu: Unit): ExerciseDraft {
  return {
    name,
    bodyweight: sets.length > 0 && sets.every((s) => s.weightKg === 0),
    sets: sets.length ? sets.map((s) => ({ reps: String(s.reps), weight: s.weightKg ? trimNum(kgToUnit(s.weightKg, wu)) : '' })) : [{ reps: '', weight: '' }],
  };
}

export function setsFromDraft(e: ExerciseDraft, wu: Unit): LiftSet[] {
  return e.sets
    .map((s) => ({ reps: Math.max(0, Math.round(Number(s.reps) || 0)), weightKg: e.bodyweight ? 0 : Math.max(0, unitToKg(Number(s.weight) || 0, wu)) }))
    .filter((s) => s.reps > 0);
}

function TrendBadge({ trend, wu }: { trend: SetTrend; wu: Unit }) {
  if (!trend) return null;
  switch (trend.kind) {
    case 'pr':
      return (
        <span className="trend trend-pr" title="Heavier than you have ever lifted on this exercise">
          PR!
        </span>
      );
    case 'weight':
      return (
        <span className="trend trend-up" title="More weight than last time">
          +{trimNum(kgToUnit(trend.deltaKg, wu))} {wu}
        </span>
      );
    case 'reps':
      return (
        <span className="trend trend-up" title="More reps than last time">
          +{trend.delta} rep{trend.delta === 1 ? '' : 's'}
        </span>
      );
    case 'extra':
      return (
        <span className="trend trend-up" title="An extra set compared with last time">
          +set
        </span>
      );
  }
}

interface Props {
  exercises: ExerciseDraft[];
  setExercises: Dispatch<SetStateAction<ExerciseDraft[]>>;
  /** Session being edited (excluded from "last time"). */
  editingId?: string;
  bests: Record<string, LiftPr>;
}

export function LiftEditor({ exercises, setExercises, editingId, bests }: Props) {
  const sessions = useStore((s) => s.sessions);
  const settings = useStore((s) => s.settings);
  const updateSettings = useStore((s) => s.updateSettings);
  const wu = settings.weightUnit;
  const step = weightStepOf(settings);
  const [query, setQuery] = useState('');

  const last = useMemo(() => lastPerformances(sessions, editingId), [sessions, editingId]);
  const suggestions = useMemo(() => exerciseSuggestions(sessions, DEFAULT_EXERCISES, editingId), [sessions, editingId]);
  const templates = useMemo(() => recentWorkouts(sessions, 3, editingId), [sessions, editingId]);

  const inForm = new Set(exercises.map((e) => normalizeExercise(e.name)));
  const q = normalizeExercise(query);
  const shown = suggestions.filter((s) => !inForm.has(s.key) && (!q || s.key.includes(q))).slice(0, q ? 12 : 10);
  const exact = suggestions.find((s) => s.key === q);
  const fmtW = (kg: number) => fmtWeight(kg, wu);

  const add = (name: string) => {
    const key = normalizeExercise(name);
    if (!key) return;
    sfx.tick();
    const lp = last[key];
    setExercises((xs) => [...xs, lp ? draftFromSets(lp.name, lp.sets, wu) : { name: name.trim(), bodyweight: false, sets: [{ reps: '', weight: '' }] }]);
    setQuery('');
  };

  const applyTemplate = (t: LiftSession) => {
    sfx.tap();
    // Same line-up, but each exercise starts from its most recent numbers.
    setExercises(
      t.exercises
        .filter((e) => e.sets.some((s) => s.reps > 0))
        .map((e) => {
          const lp = last[normalizeExercise(e.name)];
          return draftFromSets(e.name.trim(), lp?.sets ?? e.sets, wu);
        }),
    );
  };

  const setEx = (i: number, patch: Partial<ExerciseDraft>) => setExercises((xs) => xs.map((e, k) => (k === i ? { ...e, ...patch } : e)));
  const setSet = (i: number, j: number, patch: Partial<SetDraft>) =>
    setExercises((xs) => xs.map((e, k) => (k === i ? { ...e, sets: e.sets.map((s, m) => (m === j ? { ...s, ...patch } : s)) } : e)));
  const addSet = (i: number) => {
    sfx.tick();
    setExercises((xs) => xs.map((e, k) => (k === i ? { ...e, sets: [...e.sets, { ...(e.sets[e.sets.length - 1] ?? { reps: '', weight: '' }) }] } : e)));
  };
  const removeSet = (i: number, j: number) => setExercises((xs) => xs.map((e, k) => (k === i ? { ...e, sets: e.sets.filter((_, m) => m !== j) } : e)));
  const removeExercise = (i: number) => setExercises((xs) => xs.filter((_, k) => k !== i));
  const bumpAll = (i: number, field: 'reps' | 'weight') => {
    sfx.tick();
    setExercises((xs) =>
      xs.map((e, k) =>
        k !== i
          ? e
          : {
              ...e,
              sets: e.sets.map((s) =>
                field === 'reps' ? { ...s, reps: String((Number(s.reps) || 0) + 1) } : { ...s, weight: trimNum(stepValue(Number(s.weight) || 0, step, 1)) },
              ),
            },
      ),
    );
  };
  /** Typed a known exercise into a still-empty card: bring up last time's sets. */
  const maybePrefill = (i: number) =>
    setExercises((xs) =>
      xs.map((e, k) => {
        if (k !== i) return e;
        const lp = last[normalizeExercise(e.name)];
        const pristine = e.sets.every((s) => !s.reps && !s.weight);
        return lp && pristine ? draftFromSets(e.name.trim(), lp.sets, wu) : e;
      }),
    );
  const cycleStep = () => {
    const opts = WEIGHT_STEPS[wu];
    updateSettings({ weightStep: opts[(opts.indexOf(step) + 1) % opts.length] });
    sfx.tick();
  };

  return (
    <div className="exercises">
      {exercises.length === 0 && templates.length > 0 && (
        <div className="templates">
          <div className="field-label">Start from a previous workout</div>
          {templates.map((t) => (
            <button key={t.id} type="button" className="template" onClick={() => applyTemplate(t)}>
              <span className="template-date">{relativeDay(t.date)}</span>
              <span className="template-names">
                {t.exercises
                  .filter((e) => e.sets.some((s) => s.reps > 0))
                  .map((e) => e.name.trim())
                  .join(' · ')}
              </span>
              <span className="template-go">Use →</span>
            </button>
          ))}
        </div>
      )}

      {exercises.map((e, i) => {
        const key = normalizeExercise(e.name);
        const lp = last[key];
        const best = bests[key];
        const curSets = setsFromDraft(e, wu);
        const vol = volumeKg(curSets);
        const lastVol = lp ? volumeKg(lp.sets) : 0;
        const reps = curSets.reduce((a, s) => a + s.reps, 0);
        const lastReps = lp ? lp.sets.reduce((a, s) => a + s.reps, 0) : 0;
        const lastSet = (j: number) => lp?.sets[j] ?? lp?.sets[lp.sets.length - 1];
        const label = e.name.trim() || `Exercise ${i + 1}`;
        return (
          <Card key={i} className="exercise">
            <div className="row gap-s">
              <Input placeholder="Exercise name" aria-label="Exercise name" value={e.name} onChange={(ev) => setEx(i, { name: ev.target.value })} onBlur={() => maybePrefill(i)} className="grow ex-name" />
              <Chip active={e.bodyweight} onClick={() => setEx(i, { bodyweight: !e.bodyweight })}>
                BW
              </Chip>
              <button type="button" className="icon-btn" onClick={() => removeExercise(i)} aria-label="Remove exercise">
                ✕
              </button>
            </div>
            {(lp || (best && best.weightKg > 0)) && (
              <div className="ex-ref">
                {lp && (
                  <span>
                    ↩ Last ({relativeDay(lp.date)}): <b>{describeSets(lp.sets, fmtW)}</b>
                  </span>
                )}
                {best && best.weightKg > 0 && (
                  <span>
                    🏅 Best: <b>{fmtW(best.weightKg)}</b>
                  </span>
                )}
              </div>
            )}
            <div className="sets">
              <div className={`set-head ${e.bodyweight ? 'set-bw' : ''}`}>
                <span>Set</span>
                <span>Reps</span>
                {!e.bodyweight && <span>Weight ({wu})</span>}
                <span />
                <span />
              </div>
              {e.sets.map((s, j) => {
                const cur = { reps: Number(s.reps) || 0, weightKg: e.bodyweight ? 0 : unitToKg(Number(s.weight) || 0, wu) };
                const trend = compareSet(cur, lp?.sets[j], !!lp, best?.weightKg ?? 0);
                const ref = lastSet(j);
                return (
                  <div key={j} className={`set-row ${e.bodyweight ? 'set-bw' : ''}`}>
                    <span className="set-n">{j + 1}</span>
                    <Stepper value={s.reps} onChange={(v) => setSet(i, j, { reps: v })} base={ref?.reps} placeholder="reps" ariaLabel={`${label} reps for set ${j + 1}`} />
                    {!e.bodyweight && (
                      <Stepper
                        value={s.weight}
                        onChange={(v) => setSet(i, j, { weight: v })}
                        step={step}
                        snap
                        base={ref && ref.weightKg > 0 ? Math.round(kgToUnit(ref.weightKg, wu) * 100) / 100 : undefined}
                        inputMode="decimal"
                        placeholder={wu}
                        ariaLabel={`${label} weight for set ${j + 1}`}
                      />
                    )}
                    <span className="set-trend">
                      <TrendBadge trend={trend} wu={wu} />
                    </span>
                    <button type="button" className="icon-btn small" onClick={() => removeSet(i, j)} aria-label={`Remove ${label} set ${j + 1}`}>
                      ✕
                    </button>
                  </div>
                );
              })}
            </div>
            <div className="ex-actions">
              <Button variant="secondary" size="sm" onClick={() => addSet(i)}>
                + Set
              </Button>
              <span className="ex-actions-all">
                <span className="muted tiny">All sets:</span>
                <Button variant="ghost" size="sm" onClick={() => bumpAll(i, 'reps')}>
                  +1 rep
                </Button>
                {!e.bodyweight && (
                  <Button variant="ghost" size="sm" onClick={() => bumpAll(i, 'weight')}>
                    +{step} {wu}
                  </Button>
                )}
              </span>
            </div>
            {lp && curSets.length > 0 && (
              <div className="ex-delta">
                {e.bodyweight || lastVol === 0 ? (
                  reps > lastReps ? (
                    <span className="perk">▲ {reps - lastReps} more reps than last time</span>
                  ) : reps === lastReps ? (
                    <span className="muted">= Same reps as last time</span>
                  ) : (
                    <span className="muted">{lastReps - reps} reps to match last time</span>
                  )
                ) : vol > lastVol + 1e-6 ? (
                  <span className="perk">▲ {fmtW(vol - lastVol)} more volume than last time</span>
                ) : Math.abs(vol - lastVol) <= 1e-6 ? (
                  <span className="muted">= Same volume as last time</span>
                ) : (
                  <span className="muted">{fmtW(lastVol - vol)} to match last time</span>
                )}
              </div>
            )}
          </Card>
        );
      })}

      <Card className="ex-picker">
        <div className="row between">
          <span className="field-label">{exercises.length ? 'Add another exercise' : 'Add an exercise'}</span>
          <button type="button" className="step-chip" onClick={cycleStep} title="How much one tap of + or − changes a weight">
            Weight step: ± {step} {wu}
          </button>
        </div>
        <div className="row gap-s">
          <Input
            placeholder="Search or type a new exercise"
            aria-label="Search exercises"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                add(exact?.name ?? query);
              }
            }}
            className="grow"
          />
          <Button variant="secondary" disabled={!q} onClick={() => add(exact?.name ?? query)}>
            Add
          </Button>
        </div>
        <div className="ex-chips">
          {shown.map((s) => (
            <button key={s.key} type="button" className={`ex-chip ${s.last ? 'ex-chip-mine' : ''}`} onClick={() => add(s.name)}>
              <span>{s.name}</span>
              {s.last && <span className="ex-chip-last">{topSetLabel(s.last.sets, (kg) => kgToUnit(kg, wu))}</span>}
            </button>
          ))}
        </div>
        {q && shown.length === 0 && <div className="muted small">No match — tap Add to create “{query.trim()}”.</div>}
        {!q && suggestions.some((s) => s.last) && <div className="muted tiny">Your exercises come first, with your last top set. Tapping one brings up everything you did last time.</div>}
      </Card>
    </div>
  );
}
