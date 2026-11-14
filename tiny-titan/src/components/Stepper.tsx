import { useEffect, useRef } from 'react';
import { stepValue } from '../game/liftHistory';

interface Props {
  value: string;
  onChange: (v: string) => void;
  step?: number;
  min?: number;
  max?: number;
  /** Snap to multiples of `step` (plate maths) instead of adding it. */
  snap?: boolean;
  /** Where + / − start from when the field is empty (e.g. last time's value). */
  base?: number;
  inputMode?: 'numeric' | 'decimal';
  placeholder?: string;
  ariaLabel: string;
  className?: string;
}

function fmt(n: number): string {
  return String(Math.round(n * 100) / 100);
}

/** Press-and-hold repeat for a button, with a normal click for a single step. */
function useHoldRepeat(fn: () => void) {
  const fnRef = useRef(fn);
  fnRef.current = fn;
  const timer = useRef<number | undefined>(undefined);
  const interval = useRef<number | undefined>(undefined);
  const held = useRef(false);
  const stop = () => {
    window.clearTimeout(timer.current);
    window.clearInterval(interval.current);
  };
  useEffect(() => stop, []);
  return {
    onPointerDown: () => {
      held.current = false;
      stop();
      timer.current = window.setTimeout(() => {
        held.current = true;
        interval.current = window.setInterval(() => fnRef.current(), 90);
      }, 380);
    },
    onPointerUp: stop,
    onPointerLeave: stop,
    onPointerCancel: stop,
    onClick: () => {
      // The hold already stepped repeatedly; do not add one more on release.
      if (held.current) {
        held.current = false;
        return;
      }
      fnRef.current();
    },
    onContextMenu: (e: React.MouseEvent) => e.preventDefault(),
  };
}

/** A number field with − / + buttons. Tap to step, hold to repeat, or tap the number to type. */
export function Stepper({ value, onChange, step = 1, min = 0, max, snap = false, base, inputMode = 'numeric', placeholder, ariaLabel, className = '' }: Props) {
  const bump = (dir: 1 | -1) => {
    const empty = value.trim() === '' || !Number.isFinite(Number(value));
    let next: number;
    if (empty) {
      if (base !== undefined) next = dir > 0 ? base : base - step;
      else next = dir > 0 ? Math.max(min, step) : min;
    } else {
      const cur = Number(value);
      next = snap ? stepValue(cur, step, dir, min) : cur + dir * step;
    }
    next = Math.max(min, next);
    if (max !== undefined) next = Math.min(max, next);
    onChange(fmt(next));
  };
  const minus = useHoldRepeat(() => bump(-1));
  const plus = useHoldRepeat(() => bump(1));

  return (
    <div className={`stepper ${className}`}>
      <button type="button" className="stepper-btn" aria-label={`Decrease ${ariaLabel}`} {...minus}>
        −
      </button>
      <input className="stepper-input" inputMode={inputMode} value={value} placeholder={placeholder} aria-label={ariaLabel} onChange={(e) => onChange(e.target.value)} onFocus={(e) => e.target.select()} />
      <button type="button" className="stepper-btn" aria-label={`Increase ${ariaLabel}`} {...plus}>
        +
      </button>
    </div>
  );
}
