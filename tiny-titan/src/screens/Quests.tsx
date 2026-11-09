import { useMemo, useState } from 'react';
import { useDerived, useQuests } from '../store/derived';
import { QuestList } from '../components/QuestList';
import { Card, Chip, SectionTitle } from '../components/ui';
import { ACHIEVEMENTS } from '../game/achievements';
import { DISCIPLINES, DISCIPLINE_META, type Discipline } from '../game/types';
import { formatDate, addDays, weekKey, daysBetween, todayKey } from '../game/dates';

export function Quests() {
  const derived = useDerived();
  const { daily, weekly, today } = useQuests(derived);
  const [filter, setFilter] = useState<'all' | Discipline | 'general'>('all');

  const unlocked = Object.keys(derived.achievements).length;
  const list = useMemo(
    () =>
      ACHIEVEMENTS.filter((a) => (filter === 'all' ? true : filter === 'general' ? !a.discipline : a.discipline === filter)).sort((a, b) => {
        const ua = derived.achievements[a.id] ? 0 : 1;
        const ub = derived.achievements[b.id] ? 0 : 1;
        return ua - ub;
      }),
    [filter, derived],
  );
  const weekEnd = addDays(weekKey(today), 6);
  const daysLeft = daysBetween(todayKey(), weekEnd);

  return (
    <div className="screen">
      <header className="topbar">
        <h1>Quests</h1>
      </header>
      <SectionTitle right={<span className="muted small">Resets at midnight</span>}>Daily</SectionTitle>
      <QuestList quests={daily} />
      <SectionTitle right={<span className="muted small">{daysLeft === 0 ? 'Last day!' : `${daysLeft} day${daysLeft === 1 ? '' : 's'} left`}</span>}>Weekly</SectionTitle>
      <QuestList quests={weekly} />

      <SectionTitle
        right={
          <span className="muted small">
            {unlocked}/{ACHIEVEMENTS.length}
          </span>
        }
      >
        Achievements
      </SectionTitle>
      <div className="chips scroll-x">
        <Chip active={filter === 'all'} onClick={() => setFilter('all')}>
          All
        </Chip>
        {DISCIPLINES.map((d) => (
          <Chip key={d} active={filter === d} onClick={() => setFilter(d)}>
            {DISCIPLINE_META[d].icon} {DISCIPLINE_META[d].name}
          </Chip>
        ))}
        <Chip active={filter === 'general'} onClick={() => setFilter('general')}>
          ⭐ General
        </Chip>
      </div>
      <Card className="ach-list">
        {list.map((a) => {
          const u = derived.achievements[a.id];
          return (
            <div key={a.id} className={`ach ${u ? 'ach-done' : ''}`}>
              <span className="ach-icon">{u ? a.icon : '🔒'}</span>
              <span className="ach-main">
                <span className="ach-name">{a.name}</span>
                <span className="muted small">{u || !a.secret ? a.desc : '???'}</span>
              </span>
              <span className="ach-right">
                <span className="ach-xp">+{a.xp}</span>
                {u && <span className="muted tiny">{formatDate(u.at)}</span>}
              </span>
            </div>
          );
        })}
      </Card>
    </div>
  );
}
