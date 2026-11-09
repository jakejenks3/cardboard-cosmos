import { useStore } from '../store/useStore';
import { useUi } from '../store/ui';
import { useDerived, usePerks, useQuests } from '../store/derived';
import { HeroScene } from '../avatar/HeroScene';
import { Bar, Button, Card, SectionTitle } from '../components/ui';
import { QuestList } from '../components/QuestList';
import { DISCIPLINES, DISCIPLINE_META } from '../game/types';
import { STAGES } from '../game/xp';
import { SessionRow } from './Journey';
import { useState } from 'react';

export function Home() {
  const derived = useDerived();
  const profile = useStore((s) => s.profile)!;
  const loadout = useStore((s) => s.loadout);
  const activePet = useStore((s) => s.activePet);
  const sessions = useStore((s) => s.sessions);
  const setTab = useUi((s) => s.setTab);
  const setSettingsOpen = useUi((s) => s.setSettingsOpen);
  const setLogDiscipline = useUi((s) => s.setLogDiscipline);
  const setEditingSession = useUi((s) => s.setEditingSession);
  const perks = usePerks(derived);
  const { daily } = useQuests(derived);
  const [tapped, setTapped] = useState(0);

  const lv = derived.levels.hero;
  const stage = STAGES[derived.stage];
  const next = STAGES[derived.stage + 1];
  const streak = derived.streak;
  const recent = [...sessions].sort((a, b) => b.createdAt - a.createdAt).slice(0, 3);
  const perkBits = DISCIPLINES.filter((d) => perks.xp[d] > 0).map((d) => `+${Math.round(perks.xp[d] * 100)}% ${DISCIPLINE_META[d].name.toLowerCase()}`);
  if (perks.luck > 0) perkBits.push(`+${Math.round(perks.luck * 100)}% luck`);

  return (
    <div className="screen">
      <header className="topbar">
        <div>
          <div className="hero-name">{profile.name}</div>
          <div className="hero-title">{derived.title}</div>
        </div>
        <button className="icon-btn" onClick={() => setSettingsOpen(true)} aria-label="Settings">
          ⚙️
        </button>
      </header>

      <div className="hero-stage">
        <HeroScene state={derived} profile={profile} loadout={loadout} activePet={activePet} onTap={() => setTapped((t) => t + 1)} />
        <div className="hero-hint muted small">{tapped === 0 ? 'Tap your hero to flex' : tapped < 3 ? 'Looking strong.' : 'Okay, okay, we get it.'}</div>
      </div>

      <Card className="level-card">
        <div className="level-row">
          <span className="pixel-font level-num">LV {lv.level}</span>
          <span className="stage-name">{stage.name}</span>
          <span className="muted small right">{next ? `${next.name} at Lv ${next.minLevel}` : 'Max stage'}</span>
        </div>
        <Bar value={lv.progress} height={14} label="Hero XP" />
        <div className="row between small muted">
          <span>
            {lv.into.toLocaleString('en-US')} / {lv.toNext.toLocaleString('en-US')} XP
          </span>
          <span>{derived.xp.hero.toLocaleString('en-US')} total</span>
        </div>
      </Card>

      <div className="stats-grid">
        {DISCIPLINES.map((d) => {
          const l = derived.levels[d];
          const m = DISCIPLINE_META[d];
          return (
            <Card key={d} className="stat-card" onClick={() => { setLogDiscipline(d); setEditingSession(null); setTab('log'); }}>
              <div className="stat-head">
                <span className="stat-icon">{m.icon}</span>
                <span className="stat-name">{m.stat}</span>
                <span className="stat-level pixel-font">{l.level}</span>
              </div>
              <Bar value={l.progress} color={`var(--${d})`} height={7} label={`${m.name} XP`} />
              <div className="muted tiny">{m.name} · {l.toNext - l.into} XP to next</div>
            </Card>
          );
        })}
      </div>

      <Card className="streak-card">
        <div className="streak-left">
          <span className="streak-flame">{streak.current > 0 ? '🔥' : '🪵'}</span>
          <div>
            <div className="streak-num">
              {streak.current} week{streak.current === 1 ? '' : 's'} streak
            </div>
            <div className="muted small">Best {streak.best} · {streak.thisWeek}/{streak.goal} sessions this week</div>
          </div>
        </div>
        <div className="streak-dots" aria-label="This week's progress">
          {Array.from({ length: streak.goal }, (_, i) => (
            <span key={i} className={`dot ${i < streak.thisWeek ? 'dot-on' : ''}`} />
          ))}
        </div>
      </Card>

      {perkBits.length > 0 && <div className="perk-line">✨ Gear bonus: {perkBits.join(', ')}</div>}

      <SectionTitle
        right={
          <button className="link" onClick={() => setTab('quests')}>
            All quests →
          </button>
        }
      >
        Today's quests
      </SectionTitle>
      <QuestList quests={daily} compact />

      <SectionTitle
        right={
          sessions.length > 0 ? (
            <button className="link" onClick={() => setTab('journey')}>
              History →
            </button>
          ) : undefined
        }
      >
        Recent
      </SectionTitle>
      {recent.length === 0 ? (
        <Card className="muted center">No sessions yet. Your first one levels you up instantly.</Card>
      ) : (
        <div className="session-list">
          {recent.map((s) => (
            <SessionRow key={s.id} session={s} xp={derived.sessionXp[s.id] ?? 0} />
          ))}
        </div>
      )}

      <Button size="lg" className="fab-wide" onClick={() => { setLogDiscipline(null); setEditingSession(null); setTab('log'); }}>
        + Log a workout
      </Button>
    </div>
  );
}
