import type { ReactNode, ButtonHTMLAttributes, InputHTMLAttributes } from 'react';
import type { Discipline, Rarity } from '../game/types';
import { DISCIPLINE_META, RARITY_COLOR } from '../game/types';

export function Card({ children, className = '', onClick, style }: { children: ReactNode; className?: string; onClick?: () => void; style?: React.CSSProperties }) {
  return (
    <div className={`card ${onClick ? 'card-tap' : ''} ${className}`} onClick={onClick} style={style}>
      {children}
    </div>
  );
}

export function Button({
  children,
  variant = 'primary',
  size = 'md',
  className = '',
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'good'; size?: 'sm' | 'md' | 'lg' }) {
  return (
    <button className={`btn btn-${variant} btn-${size} ${className}`} {...rest}>
      {children}
    </button>
  );
}

export function Bar({ value, color, height = 10, className = '', label }: { value: number; color?: string; height?: number; className?: string; label?: string }) {
  const pct = Math.max(0, Math.min(1, value)) * 100;
  return (
    <div className={`bar ${className}`} style={{ height }} role="progressbar" aria-valuenow={Math.round(pct)} aria-valuemin={0} aria-valuemax={100} aria-label={label}>
      <div className="bar-fill" style={{ width: `${pct}%`, background: color ?? 'var(--accent)' }} />
    </div>
  );
}

export function Chip({ children, color, active, onClick, className = '' }: { children: ReactNode; color?: string; active?: boolean; onClick?: () => void; className?: string }) {
  return (
    <button type="button" className={`chip ${active ? 'chip-active' : ''} ${className}`} style={color ? ({ '--chip': color } as React.CSSProperties) : undefined} onClick={onClick}>
      {children}
    </button>
  );
}

export function RarityBadge({ rarity }: { rarity: Rarity }) {
  return (
    <span className="rarity" style={{ color: RARITY_COLOR[rarity], borderColor: RARITY_COLOR[rarity] }}>
      {rarity}
    </span>
  );
}

export function DiscIcon({ d, size = 18 }: { d: Discipline; size?: number }) {
  return (
    <span className="disc-icon" style={{ fontSize: size, lineHeight: 1 }} aria-label={DISCIPLINE_META[d].name}>
      {DISCIPLINE_META[d].icon}
    </span>
  );
}

export function DiscTag({ d }: { d: Discipline }) {
  return (
    <span className="disc-tag" style={{ background: `var(--${d})` }}>
      {DISCIPLINE_META[d].icon} {DISCIPLINE_META[d].name}
    </span>
  );
}

export function Field({ label, hint, children, className = '' }: { label: string; hint?: string; children: ReactNode; className?: string }) {
  return (
    <label className={`field ${className}`}>
      <span className="field-label">{label}</span>
      {children}
      {hint && <span className="field-hint">{hint}</span>}
    </label>
  );
}

export function Input({ className = '', ...rest }: InputHTMLAttributes<HTMLInputElement>) {
  return <input className={`input ${className}`} {...rest} />;
}

export function Segmented<T extends string>({ value, options, onChange, color }: { value: T; options: { value: T; label: ReactNode }[]; onChange: (v: T) => void; color?: string }) {
  return (
    <div className="segmented" role="tablist">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="tab"
          aria-selected={o.value === value}
          className={`segment ${o.value === value ? 'segment-active' : ''}`}
          style={o.value === value && color ? { background: color } : undefined}
          onClick={() => onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function Sheet({ open, onClose, title, children, wide }: { open: boolean; onClose: () => void; title?: ReactNode; children: ReactNode; wide?: boolean }) {
  if (!open) return null;
  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div className={`sheet ${wide ? 'sheet-wide' : ''}`} onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
        <div className="sheet-handle" />
        {title && <div className="sheet-title">{title}</div>}
        <div className="sheet-body">{children}</div>
      </div>
    </div>
  );
}

export function Stat({ label, value, sub, color }: { label: string; value: ReactNode; sub?: ReactNode; color?: string }) {
  return (
    <div className="stat">
      <div className="stat-value" style={color ? { color } : undefined}>
        {value}
      </div>
      <div className="stat-label">{label}</div>
      {sub && <div className="stat-sub">{sub}</div>}
    </div>
  );
}

export function Empty({ icon, title, body, action }: { icon: string; title: string; body?: string; action?: ReactNode }) {
  return (
    <div className="empty">
      <div className="empty-icon">{icon}</div>
      <div className="empty-title">{title}</div>
      {body && <div className="empty-body">{body}</div>}
      {action}
    </div>
  );
}

export function SectionTitle({ children, right }: { children: ReactNode; right?: ReactNode }) {
  return (
    <div className="section-title">
      <h2>{children}</h2>
      {right}
    </div>
  );
}
