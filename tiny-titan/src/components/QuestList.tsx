import type { Quest } from '../game/quests';
import { useStore } from '../store/useStore';
import { useUi } from '../store/ui';
import { uid } from '../game/rng';
import { todayKey } from '../game/dates';
import { Bar, Button } from './ui';
import { sfx } from '../sfx/sounds';
import { fmtDistance, fmtWeight } from '../game/format';
import type { Settings } from '../game/types';

export function questProgressText(q: Quest, settings: Settings): string {
  const p = Math.min(q.progress, q.target);
  switch (q.unit) {
    case 'kg':
      return `${fmtWeight(p, settings.weightUnit, 0)} / ${fmtWeight(q.target, settings.weightUnit, 0)}`;
    case 'm':
      return `${fmtDistance(p, settings.distanceUnit)} / ${fmtDistance(q.target, settings.distanceUnit)}`;
    case 'xp':
      return `${Math.round(p).toLocaleString('en-US')} / ${q.target.toLocaleString('en-US')} XP`;
    case 'min':
      return `${Math.round(p)} / ${q.target} min`;
    case 'sends':
      return `${p} / ${q.target} sends`;
    case 'days':
      return `${p} / ${q.target} days`;
    case 'disciplines':
      return `${p} / ${q.target} disciplines`;
    default:
      return `${p} / ${q.target}`;
  }
}

export function QuestList({ quests, compact }: { quests: Quest[]; compact?: boolean }) {
  const settings = useStore((s) => s.settings);
  const claimQuest = useStore((s) => s.claimQuest);
  const toast = useUi((s) => s.toast);

  const claim = (q: Quest) => {
    claimQuest({ id: uid('q'), questId: q.id, xp: q.xp, claimedAt: Date.now(), date: todayKey() });
    sfx.claim();
    toast(`+${q.xp} XP — ${q.title}`, '🎁', 'good');
  };

  return (
    <div className="quest-list">
      {quests.map((q) => {
        const color = q.discipline ? `var(--${q.discipline})` : 'var(--accent)';
        return (
          <div key={q.id} className={`quest ${q.claimed ? 'quest-claimed' : q.done ? 'quest-done' : ''}`}>
            <div className="quest-icon">{q.claimed ? '✔️' : q.icon}</div>
            <div className="quest-main">
              <div className="quest-title">
                {q.title} <span className="quest-xp">+{q.xp} XP</span>
              </div>
              {!compact && <div className="quest-desc">{q.desc}</div>}
              <Bar value={q.target ? q.progress / q.target : 0} color={color} height={7} className="quest-bar" />
              <div className="quest-progress">{questProgressText(q, settings)}</div>
            </div>
            <div className="quest-action">
              {q.claimed ? (
                <span className="muted small">Claimed</span>
              ) : q.done ? (
                <Button size="sm" variant="good" onClick={() => claim(q)} className="btn-claim">
                  Claim
                </Button>
              ) : null}
            </div>
          </div>
        );
      })}
    </div>
  );
}
