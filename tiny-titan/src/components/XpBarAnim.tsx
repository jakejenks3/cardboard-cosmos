import { useEffect, useState } from 'react';
import type { LevelInfo } from '../game/xp';
import { sfx } from '../sfx/sounds';

interface Props {
  before: LevelInfo;
  after: LevelInfo;
  color: string;
  label: string;
  /** Called once the fill animation is complete. */
  onDone?: () => void;
  onLevelUp?: (level: number) => void;
  play: boolean;
}

/**
 * Animates an XP bar from `before` to `after`, filling to 100% and wrapping
 * on every level gained. Uses CSS transitions driven by a small timeline.
 */
export function XpBarAnim({ before, after, color, label, onDone, onLevelUp, play }: Props) {
  const [level, setLevel] = useState(before.level);
  const [pct, setPct] = useState(before.progress);
  const [instant, setInstant] = useState(false);
  const [flash, setFlash] = useState(false);

  useEffect(() => {
    if (!play) return;
    let cancelled = false;
    const timers: ReturnType<typeof setTimeout>[] = [];
    const at = (ms: number, fn: () => void) => timers.push(setTimeout(() => !cancelled && fn(), ms));
    let t = 150;
    const gained = after.level - before.level;
    const segMs = gained > 0 ? Math.max(350, 900 / (gained + 1)) : 900;
    for (let i = 0; i < gained; i++) {
      const lv = before.level + i;
      at(t, () => {
        setInstant(false);
        setPct(1);
      });
      t += segMs;
      at(t, () => {
        setFlash(true);
        sfx.levelUp();
        onLevelUp?.(lv + 1);
      });
      at(t + 220, () => {
        setFlash(false);
        setInstant(true);
        setPct(0);
        setLevel(lv + 1);
      });
      t += 260;
    }
    at(t, () => {
      setInstant(false);
      setPct(after.progress);
      sfx.xp();
    });
    t += 800;
    at(t, () => onDone?.());
    return () => {
      cancelled = true;
      timers.forEach(clearTimeout);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [play]);

  const into = Math.round(pct * (level === after.level ? after.toNext : before.toNext));
  const toNext = level === after.level ? after.toNext : before.toNext;

  return (
    <div className={`xpanim ${flash ? 'xpanim-flash' : ''}`}>
      <div className="xpanim-head">
        <span className="xpanim-label">{label}</span>
        <span className="xpanim-level">
          Lv <b>{level}</b>
        </span>
      </div>
      <div className="bar" style={{ height: 14 }}>
        <div className="bar-fill" style={{ width: `${pct * 100}%`, background: color, transition: instant ? 'none' : 'width 0.75s cubic-bezier(.2,.8,.2,1)' }} />
      </div>
      <div className="xpanim-foot">
        {into.toLocaleString('en-US')} / {toNext.toLocaleString('en-US')} XP
      </div>
    </div>
  );
}
