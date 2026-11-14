import type { NextGoal } from '../game/nextup';
import type { Progress } from '../game/goals';
import { progressRatio } from '../game/goals';
import { fmtProgress } from '../game/format';
import { useStore } from '../store/useStore';
import { Bar } from './ui';

const KIND_LABEL: Record<NextGoal['kind'], string> = { achievement: 'Trophy', item: 'Gear', pet: 'Companion', stage: 'Evolution', rank: 'Rank' };

export function GoalRow({ goal }: { goal: NextGoal }) {
  const settings = useStore((s) => s.settings);
  const color = goal.discipline ? `var(--${goal.discipline})` : 'var(--accent)';
  return (
    <div className="goal">
      <span className="goal-icon">{goal.icon}</span>
      <div className="goal-main">
        <div className="goal-title">
          {goal.title} <span className="goal-kind">{KIND_LABEL[goal.kind]}</span>
        </div>
        <div className="muted tiny">{goal.sub}</div>
        <Bar value={goal.ratio} color={color} height={7} label={goal.title} />
        <div className="goal-progress">{fmtProgress(goal.progress, settings)}</div>
      </div>
      <span className="goal-pct">{Math.floor(goal.ratio * 100)}%</span>
    </div>
  );
}

/** A compact progress bar + "cur / target" for locked things. */
export function ProgressLine({ progress, color }: { progress: Progress; color?: string }) {
  const settings = useStore((s) => s.settings);
  return (
    <div className="progress-line">
      <Bar value={progressRatio(progress)} color={color ?? 'var(--accent)'} height={6} />
      <span className="muted tiny">{fmtProgress(progress, settings)}</span>
    </div>
  );
}
