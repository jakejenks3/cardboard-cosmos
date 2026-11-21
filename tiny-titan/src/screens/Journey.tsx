import { useMemo, useState } from 'react';
import { useStore, DEFAULT_LOADOUT } from '../store/useStore';
import { useUi } from '../store/ui';
import { useDerived, useToday } from '../store/derived';
import { HeroScene } from '../avatar/HeroScene';
import { Button, Card, Chip, Empty, SectionTitle, Stat, SubTabs } from '../components/ui';
import { GradePyramid, Heatmap, LineChart, WeeklyXpChart, type WeekPoint } from '../components/charts';
import type { Discipline, LiftSession, Session, Settings } from '../game/types';
import { DISCIPLINE_META } from '../game/types';
import type { ChronicleKind, PlayerState } from '../game/state';
import { summarizeSession } from '../game/summary';
import { addWeeks, daysBetween, formatDate, formatDateLong, parseDateKey, relativeDay, todayKey, weekKey } from '../game/dates';
import { fmtBigKg, fmtDistance, fmtDurationShort, fmtElevation, fmtGoalValue, fmtPace, fmtSpeed, fmtWeight, kgToUnit } from '../game/format';
import { e1rm, gradeLabel, normalizeExercise, sessionStats } from '../game/xp';
import { funFacts } from '../game/funfacts';
import { BodyJourney } from './Body';

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
  const tab = useUi((s) => s.journeyTab);
  const setTab = useUi((s) => s.setJourneyTab);
  const setMainTab = useUi((s) => s.setTab);
  const sessions = useStore((s) => s.sessions);
  const derived = useDerived();

  const noSessions = (
    <Empty icon="🗺️" title="Your story starts with one session" body="Charts, records and history appear here once you log something." action={<Button onClick={() => setMainTab('log')}>Log a workout</Button>} />
  );

  return (
    <div className="screen">
      <header className="topbar">
        <h1>Journey</h1>
      </header>
      <SubTabs
        value={tab}
        onChange={setTab}
        options={[
          { value: 'stats', label: '📈 Stats' },
          { value: 'body', label: '📸 Body' },
          { value: 'chronicle', label: '📖 Story' },
          { value: 'history', label: '🗂️ Log' },
        ]}
      />
      {tab === 'stats' && (sessions.length === 0 ? noSessions : <Stats derived={derived} />)}
      {tab === 'body' && <BodyJourney />}
      {tab === 'chronicle' && <Chronicle derived={derived} />}
      {tab === 'history' && (sessions.length === 0 ? noSessions : <History derived={derived} />)}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Then vs now
// ---------------------------------------------------------------------------

function titleCase(s: string): string {
  return s.replace(/\b\w/g, (c) => c.toUpperCase());
}

function thenNowFacts(sessions: Session[], derived: PlayerState, settings: Settings): { label: string; then: string; now: string }[] {
  const out: { label: string; then: string; now: string }[] = [];
  const byDate = [...sessions].sort((a, b) => a.date.localeCompare(b.date) || a.createdAt - b.createdAt);

  const firstLift: Record<string, number> = {};
  let firstSend: number | null = null;
  let firstRun = 0;
  let firstRide = 0;
  for (const s of byDate) {
    if (s.discipline === 'lift') {
      for (const ex of s.exercises) {
        const name = normalizeExercise(ex.name);
        const w = Math.max(0, ...ex.sets.map((x) => x.weightKg));
        if (name && w > 0 && !(name in firstLift)) firstLift[name] = w;
      }
    } else if (s.discipline === 'climb') {
      const st = sessionStats(s);
      if (firstSend === null && st.maxGradeSent !== null) firstSend = st.maxGradeSent;
    } else if (s.discipline === 'run') {
      if (!firstRun && s.distanceM > 0) firstRun = s.distanceM;
    } else if (!firstRide && s.distanceM > 0) firstRide = s.distanceM;
  }

  const lifts = Object.entries(derived.prs.lifts)
    .filter(([name, pr]) => firstLift[name] && pr.weightKg > firstLift[name])
    .sort((a, b) => b[1].weightKg / firstLift[b[0]] - a[1].weightKg / firstLift[a[0]])
    .slice(0, 2);
  for (const [name, pr] of lifts) out.push({ label: titleCase(name), then: fmtWeight(firstLift[name], settings.weightUnit), now: fmtWeight(pr.weightKg, settings.weightUnit) });
  if (firstSend !== null && derived.prs.climbMaxSend !== null && derived.prs.climbMaxSend > firstSend) {
    out.push({ label: 'Hardest send', then: gradeLabel(firstSend), now: gradeLabel(derived.prs.climbMaxSend) });
  }
  if (firstRun && derived.prs.longestRunM > firstRun) out.push({ label: 'Longest run', then: fmtDistance(firstRun, settings.distanceUnit), now: fmtDistance(derived.prs.longestRunM, settings.distanceUnit) });
  if (firstRide && derived.prs.longestRideM > firstRide) out.push({ label: 'Longest ride', then: fmtDistance(firstRide, settings.distanceUnit), now: fmtDistance(derived.prs.longestRideM, settings.distanceUnit) });
  const b = derived.body;
  if (b.firstWeightKg !== null && b.latestWeightKg !== null && b.firstWeightDate !== b.latestWeightDate) {
    out.push({ label: 'Body weight', then: fmtWeight(b.firstWeightKg, settings.weightUnit), now: fmtWeight(b.latestWeightKg, settings.weightUnit) });
  }
  return out.slice(0, 5);
}

const LEVEL_ONE = { hero: 1, lift: 1, climb: 1, run: 1, ride: 1 };

function ThenNow({ derived }: { derived: PlayerState }) {
  const profile = useStore((s) => s.profile)!;
  const loadout = useStore((s) => s.loadout);
  const sessions = useStore((s) => s.sessions);
  const settings = useStore((s) => s.settings);
  const today = useToday();
  const start = derived.chronicle[0]?.date;
  const facts = useMemo(() => thenNowFacts(sessions, derived, settings), [sessions, derived, settings]);
  if (!start) return null;
  const days = daysBetween(start, today);
  return (
    <Card className="thennow">
      <div className="thennow-heroes">
        <figure>
          <HeroScene state={derived} profile={profile} loadout={DEFAULT_LOADOUT} activePet={null} scene={false} animate={false} levelsOverride={LEVEL_ONE} />
          <figcaption>
            <b>Day 1</b>
            <span className="muted tiny">{formatDate(start, { month: 'short', day: 'numeric', year: 'numeric' })}</span>
          </figcaption>
        </figure>
        <div className="thennow-mid">
          <span className="pixel-font thennow-days">{days}</span>
          <span className="muted tiny">day{days === 1 ? '' : 's'}</span>
          <span className="thennow-arrow">→</span>
        </div>
        <figure>
          <HeroScene state={derived} profile={profile} loadout={loadout} activePet={null} scene={false} animate={false} />
          <figcaption>
            <b>Today</b>
            <span className="muted tiny">Lv {derived.levels.hero.level}</span>
          </figcaption>
        </figure>
      </div>
      <div className="thennow-facts">
        <div className="thennow-row">
          <span>Hero level</span>
          <span className="muted">Lv 1</span>
          <span className="thennow-now">Lv {derived.levels.hero.level}</span>
        </div>
        {facts.map((f) => (
          <div key={f.label} className="thennow-row">
            <span>{f.label}</span>
            <span className="muted">{f.then}</span>
            <span className="thennow-now">{f.now}</span>
          </div>
        ))}
      </div>
    </Card>
  );
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

function Stats({ derived }: { derived: PlayerState }) {
  const sessions = useStore((s) => s.sessions);
  const settings = useStore((s) => s.settings);
  const t = derived.totals;
  const wu = settings.weightUnit;
  const [exercise, setExercise] = useState<string | null>(null);

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

  const liftSessions = useMemo(() => sessions.filter((s): s is LiftSession => s.discipline === 'lift').sort((a, b) => a.date.localeCompare(b.date) || a.createdAt - b.createdAt), [sessions]);
  const topExercises = useMemo(() => {
    const counts = new Map<string, number>();
    for (const s of liftSessions) for (const ex of s.exercises) if (ex.sets.some((x) => x.weightKg > 0)) counts.set(normalizeExercise(ex.name), (counts.get(normalizeExercise(ex.name)) ?? 0) + 1);
    return [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6);
  }, [liftSessions]);
  const selected = exercise && topExercises.some(([n]) => n === exercise) ? exercise : topExercises[0]?.[0] ?? null;
  const series = useMemo(() => {
    if (!selected) return [];
    const pts: { x: string; y: number }[] = [];
    for (const s of liftSessions) {
      let best = 0;
      for (const ex of s.exercises) {
        if (normalizeExercise(ex.name) !== selected) continue;
        for (const set of ex.sets) if (set.weightKg > 0 && set.reps > 0) best = Math.max(best, e1rm(set.weightKg, set.reps));
      }
      if (best > 0) pts.push({ x: s.date, y: kgToUnit(best, wu) });
    }
    return pts;
  }, [liftSessions, selected, wu]);

  const topLifts = Object.entries(derived.prs.lifts)
    .sort((a, b) => b[1].e1rm - a[1].e1rm)
    .slice(0, 5);
  const facts = useMemo(() => funFacts(derived), [derived]);
  const used = (d: Discipline) => t.byDiscipline[d] > 0;

  return (
    <>
      <ThenNow derived={derived} />

      <div className="tiles">
        <Stat label="Sessions" value={t.sessions} />
        <Stat label="Active days" value={t.activeDays} />
        <Stat label="Total XP" value={derived.xp.hero.toLocaleString('en-US')} color="var(--accent)" />
        <Stat label="Best streak" value={`${derived.streak.best}w`} />
        <Stat label="Trophies" value={Object.keys(derived.achievements).length} />
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

      {facts.length > 0 && (
        <>
          <SectionTitle>In perspective</SectionTitle>
          <div className="facts">
            {facts.map((f) => (
              <Card key={f.headline + f.detail} className="fact">
                <span className="fact-icon">{f.icon}</span>
                <span>
                  <b>{f.headline}</b>
                  <span className="muted small"> {f.detail}</span>
                </span>
              </Card>
            ))}
          </div>
        </>
      )}

      {used('lift') && (
        <>
          <SectionTitle>🏋️ Lifting</SectionTitle>
          <Card>
            <div className="tiles tiles-3">
              <Stat label="Lifetime volume" value={fmtBigKg(t.liftVolumeKg, wu)} color="var(--lift)" />
              <Stat label="Reps" value={t.liftReps.toLocaleString('en-US')} />
              <Stat label="Sets" value={t.liftSets.toLocaleString('en-US')} />
            </div>
            {topExercises.length > 0 && (
              <>
                <div className="pr-head">Strength progression (est. 1RM)</div>
                <div className="chips scroll-x">
                  {topExercises.map(([name]) => (
                    <Chip key={name} active={name === selected} color="var(--lift)" onClick={() => setExercise(name)}>
                      {titleCase(name)}
                    </Chip>
                  ))}
                </div>
                {series.length >= 2 ? (
                  <LineChart points={series} color="var(--lift)" fmt={(v) => `${Math.round(v)} ${wu}`} label={`${selected} estimated one-rep max over time`} />
                ) : (
                  <div className="muted small">Log this lift in another session to see a trend line.</div>
                )}
              </>
            )}
            {topLifts.length > 0 && (
              <div className="pr-table">
                <div className="pr-head">Best lifts</div>
                {topLifts.map(([name, pr]) => (
                  <div key={name} className="pr-row">
                    <span className="pr-name">{titleCase(name)}</span>
                    <span className="pr-val">
                      {fmtWeight(pr.weightKg, wu)} × {pr.reps}
                    </span>
                    <span className="pr-e1rm muted small">≈ {fmtWeight(pr.e1rm, wu, 0)}</span>
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
    </>
  );
}

// ---------------------------------------------------------------------------
// Chronicle: the story so far
// ---------------------------------------------------------------------------

const CHRONICLE_FILTERS: { id: string; label: string; kinds: ChronicleKind[] | null }[] = [
  { id: 'all', label: 'Everything', kinds: null },
  { id: 'level', label: '⭐ Levels', kinds: ['start', 'level', 'stage', 'rank'] },
  { id: 'boss', label: '⚔️ Bosses', kinds: ['boss'] },
  { id: 'achievement', label: '🏆 Trophies', kinds: ['achievement'] },
  { id: 'loot', label: '🎁 Loot', kinds: ['item', 'pet'] },
  { id: 'pr', label: '📈 Records', kinds: ['pr'] },
  { id: 'body', label: '📸 Body', kinds: ['body'] },
];

function Chronicle({ derived }: { derived: PlayerState }) {
  const settings = useStore((s) => s.settings);
  const today = useToday();
  const [filter, setFilter] = useState('all');
  const kinds = CHRONICLE_FILTERS.find((f) => f.id === filter)?.kinds ?? null;

  const groups = useMemo(() => {
    const events = derived.chronicle
      .map((e, i) => ({ ...e, i }))
      .filter((e) => !kinds || kinds.includes(e.kind))
      .sort((a, b) => b.date.localeCompare(a.date) || b.i - a.i);
    const out: { month: string; events: typeof events }[] = [];
    for (const e of events) {
      const month = parseDateKey(e.date).toLocaleDateString(undefined, { month: 'long', year: 'numeric' });
      const last = out[out.length - 1];
      if (last && last.month === month) last.events.push(e);
      else out.push({ month, events: [e] });
    }
    return out;
  }, [derived, kinds]);

  const start = derived.chronicle[0]?.date;
  if (!start) {
    return <Empty icon="📖" title="An empty page" body="Your story writes itself as you train: every level, boss, trophy, record and piece of loot lands here with its date." />;
  }

  return (
    <>
      <Card className="story-head">
        <span className="pixel-font story-day">DAY {daysBetween(start, today) + 1}</span>
        <span className="muted small">
          Started {formatDate(start, { month: 'long', day: 'numeric', year: 'numeric' })} · {derived.chronicle.length} moments so far
        </span>
      </Card>
      <div className="chips scroll-x">
        {CHRONICLE_FILTERS.map((f) => (
          <Chip key={f.id} active={filter === f.id} onClick={() => setFilter(f.id)}>
            {f.label}
          </Chip>
        ))}
      </div>
      {groups.length === 0 && <Card className="muted center">Nothing here yet.</Card>}
      {groups.map((g) => (
        <div key={g.month} className="story-month">
          <div className="story-month-name">{g.month}</div>
          <div className="timeline">
            {g.events.map((e) => (
              <div key={e.i} className={`moment moment-${e.kind}`}>
                <span className="moment-icon">{e.icon}</span>
                <div className="moment-main">
                  <div className="moment-title">
                    {e.title}
                    {e.val && <span className="moment-val"> {fmtGoalValue(e.val.n, e.val.unit, settings)}</span>}
                  </div>
                  {e.detail && <div className="muted small">{e.detail}</div>}
                </div>
                <span className="moment-date muted tiny">{formatDate(e.date)}</span>
              </div>
            ))}
          </div>
        </div>
      ))}
    </>
  );
}

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

function History({ derived }: { derived: PlayerState }) {
  const sessions = useStore((s) => s.sessions);
  const grouped = useMemo(() => {
    const sorted = [...sessions].sort((a, b) => b.date.localeCompare(a.date) || b.createdAt - a.createdAt);
    const g: { date: string; items: Session[] }[] = [];
    for (const s of sorted) {
      const last = g[g.length - 1];
      if (last && last.date === s.date) last.items.push(s);
      else g.push({ date: s.date, items: [s] });
    }
    return g;
  }, [sessions]);

  return (
    <div className="history">
      <div className="muted small">Tap a session to edit it. Everything recalculates.</div>
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
  );
}
