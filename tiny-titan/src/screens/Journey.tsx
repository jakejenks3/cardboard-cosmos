import { useMemo } from 'react';
import { useStore } from '../store/useStore';
import { useUi } from '../store/ui';
import { useDerived } from '../store/derived';
import { Card, SectionTitle, Stat, Empty, Button } from '../components/ui';
import { GradePyramid, Heatmap, WeeklyXpChart, type WeekPoint } from '../components/charts';
import type { Discipline, Session } from '../game/types';
import { DISCIPLINE_META } from '../game/types';
import { summarizeSession } from '../game/summary';
import { addWeeks, formatDateLong, relativeDay, todayKey, weekKey } from '../game/dates';
import { fmtBigKg, fmtDistance, fmtDurationShort, fmtElevation, fmtPace, fmtSpeed, fmtWeight } from '../game/format';
import { gradeLabel } from '../game/xp';

export function SessionRow({ session, xp }: { session: Session; xp: number }) {
  const settings = useStore((s) => s.settings);
  const setEditingSession = useUi((s) => s.setEditingSession);
  const setTab = useUi((s) => s.setTab);
  const d = session.discipline;
  return (
    <button
      className="session-row"
      onClick={() => {
        setEditingSession(session.id);
        setTab('log');
      }}
    >
      <span className="session-icon" style={{ background: `var(--${d})` }}>
        {DISCIPLINE_META[d].icon}
      </span>
      <span className="session-main">
        <span className="session-title">
          {session.title || DISCIPLINE_META[d].name}
          {session.source === 'strava' && <span className="strava-tag">Strava</span>}
        </span>
        <span className="session-sub muted small">{summarizeSession(session, settings)}</span>
      </span>
      <span className="session-right">
        <span className="session-xp">+{xp.toLocaleString('en-US')}</span>
        <span className="muted tiny">{relativeDay(session.date)}</span>
      </span>
    </button>
  );
}

export function Journey() {
  const derived = useDerived();
  const sessions = useStore((s) => s.sessions);
  const settings = useStore((s) => s.settings);
  const setTab = useUi((s) => s.setTab);
  const t = derived.totals;

  const weekly = useMemo<WeekPoint[]>(() => {
    const thisWeek = weekKey(todayKey());
    const out: WeekPoint[] = [];
    for (let i = 11; i >= 0; i--) {
      const wk = addWeeks(thisWeek, -i);
      out.push({ week: wk, byDiscipline: { lift: 0, climb: 0, run: 0, ride: 0 }, total: 0 });
    }
    const idx = new Map(out.map((p, i) => [p.week, i]));
    for (const s of sessions) {
      const i = idx.get(weekKey(s.date));
      if (i === undefined) continue;
      const xp = derived.sessionXp[s.id] ?? 0;
      out[i].byDiscipline[s.discipline] += xp;
      out[i].total += xp;
    }
    return out;
  }, [sessions, derived]);

  const gradeCounts = useMemo(() => {
    const c: Record<number, { sends: number; flashes: number }> = {};
    for (const s of sessions) {
      if (s.discipline !== 'climb') continue;
      for (const cl of s.climbs) {
        if (cl.result === 'attempt') continue;
        c[cl.grade] ??= { sends: 0, flashes: 0 };
        if (cl.result === 'flash') c[cl.grade].flashes += cl.count;
        else c[cl.grade].sends += cl.count;
      }
    }
    return c;
  }, [sessions]);

  const history = useMemo(() => [...sessions].sort((a, b) => b.date.localeCompare(a.date) || b.createdAt - a.createdAt), [sessions]);
  const grouped = useMemo(() => {
    const g: { date: string; items: Session[] }[] = [];
    for (const s of history) {
      const last = g[g.length - 1];
      if (last && last.date === s.date) last.items.push(s);
      else g.push({ date: s.date, items: [s] });
    }
    return g;
  }, [history]);

  const topLifts = Object.entries(derived.prs.lifts)
    .sort((a, b) => b[1].e1rm - a[1].e1rm)
    .slice(0, 5);

  const used = (d: Discipline) => t.byDiscipline[d] > 0;

  if (sessions.length === 0) {
    return (
      <div className="screen">
        <header className="topbar">
          <h1>Journey</h1>
        </header>
        <Empty icon="🗺️" title="Your story starts with one session" body="Charts, records and history appear here once you log something." action={<Button onClick={() => setTab('log')}>Log a workout</Button>} />
      </div>
    );
  }

  return (
    <div className="screen">
      <header className="topbar">
        <h1>Journey</h1>
      </header>

      <div className="tiles">
        <Stat label="Sessions" value={t.sessions} />
        <Stat label="Active days" value={t.activeDays} />
        <Stat label="Total XP" value={derived.xp.hero.toLocaleString('en-US')} color="var(--accent)" />
        <Stat label="Best streak" value={`${derived.streak.best}w`} />
        <Stat label="Achievements" value={Object.keys(derived.achievements).length} />
        <Stat label="Time trained" value={fmtDurationShort(t.durationSec)} />
      </div>

      <SectionTitle>Weekly XP</SectionTitle>
      <Card>
        <WeeklyXpChart data={weekly} />
      </Card>

      <SectionTitle>Consistency</SectionTitle>
      <Card>
        <Heatmap xpByDate={derived.xpByDate} />
      </Card>

      {used('lift') && (
        <>
          <SectionTitle>🏋️ Lifting</SectionTitle>
          <Card>
            <div className="tiles tiles-3">
              <Stat label="Lifetime volume" value={fmtBigKg(t.liftVolumeKg, settings.weightUnit)} color="var(--lift)" />
              <Stat label="Reps" value={t.liftReps.toLocaleString('en-US')} />
              <Stat label="Sets" value={t.liftSets.toLocaleString('en-US')} />
            </div>
            {topLifts.length > 0 && (
              <div className="pr-table">
                <div className="pr-head">Top lifts (est. 1RM)</div>
                {topLifts.map(([name, pr]) => (
                  <div key={name} className="pr-row">
                    <span className="pr-name">{titleCase(name)}</span>
                    <span className="pr-val">
                      {fmtWeight(pr.weightKg, settings.weightUnit)} × {pr.reps}
                    </span>
                    <span className="pr-e1rm muted small">≈ {fmtWeight(pr.e1rm, settings.weightUnit, 0)}</span>
                  </div>
                ))}
              </div>
            )}
          </Card>
        </>
      )}

      {used('climb') && (
        <>
          <SectionTitle>🧗 Climbing</SectionTitle>
          <Card>
            <div className="tiles tiles-3">
              <Stat label="Sends" value={t.climbSends} color="var(--climb)" />
              <Stat label="Flashes" value={t.climbFlashes} />
              <Stat label="Max grade" value={derived.prs.climbMaxSend !== null ? gradeLabel(derived.prs.climbMaxSend) : '—'} sub={derived.prs.climbMaxFlash !== null ? `flash ${gradeLabel(derived.prs.climbMaxFlash)}` : undefined} />
            </div>
            <div className="pr-head">Send pyramid</div>
            <GradePyramid counts={gradeCounts} maxGrade={derived.prs.climbMaxSend ?? 3} />
            <div className="muted tiny">Lighter segment = flashes</div>
          </Card>
        </>
      )}

      {used('run') && (
        <>
          <SectionTitle>👟 Running</SectionTitle>
          <Card>
            <div className="tiles tiles-3">
              <Stat label="Distance" value={fmtDistance(t.runDistanceM, settings.distanceUnit, 0)} color="var(--run)" />
              <Stat label="Elevation" value={fmtElevation(t.runElevationM, settings.distanceUnit)} />
              <Stat label="Longest" value={fmtDistance(derived.prs.longestRunM, settings.distanceUnit)} sub={derived.prs.bestPaceSecPerKm ? `best ${fmtPace(derived.prs.bestPaceSecPerKm, settings.distanceUnit)}` : undefined} />
            </div>
          </Card>
        </>
      )}

      {used('ride') && (
        <>
          <SectionTitle>🚴 Cycling</SectionTitle>
          <Card>
            <div className="tiles tiles-3">
              <Stat label="Distance" value={fmtDistance(t.rideDistanceM, settings.distanceUnit, 0)} color="var(--ride)" />
              <Stat label="Elevation" value={fmtElevation(t.rideElevationM, settings.distanceUnit)} />
              <Stat label="Longest" value={fmtDistance(derived.prs.longestRideM, settings.distanceUnit)} sub={derived.prs.bestRideSpeedKmh ? `best ${fmtSpeed(derived.prs.bestRideSpeedKmh, settings.distanceUnit)}` : undefined} />
            </div>
          </Card>
        </>
      )}

      <SectionTitle>History</SectionTitle>
      <div className="history">
        {grouped.map((g) => (
          <div key={g.date} className="history-day">
            <div className="history-date muted small">{formatDateLong(g.date)}</div>
            <div className="session-list">
              {g.items.map((s) => (
                <SessionRow key={s.id} session={s} xp={derived.sessionXp[s.id] ?? 0} />
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function titleCase(s: string): string {
  return s.replace(/\b\w/g, (c) => c.toUpperCase());
}
