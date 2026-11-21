import { useEffect, useRef, useState } from 'react';
import { bossBuffer, bossLook } from './bossSprites';

interface Props {
  id: string;
  size?: number;
  /** Unknown boss: draw a dark silhouette. */
  silhouette?: boolean;
  /** Idle bob / hover animation. */
  animate?: boolean;
  /** Flash briefly whenever this number changes (taking a hit). */
  hit?: number;
  className?: string;
}

export function BossPortrait({ id, size = 64, silhouette = false, animate = false, hit = 0, className = '' }: Props) {
  const ref = useRef<HTMLCanvasElement>(null);
  const [flash, setFlash] = useState(false);

  useEffect(() => {
    if (!hit) return;
    setFlash(true);
    const t = setTimeout(() => setFlash(false), 450);
    return () => clearTimeout(t);
  }, [hit]);

  useEffect(() => {
    const c = ref.current;
    if (!c) return;
    const buf = bossBuffer(id, { silhouette });
    const pad = 2; // room for the bob
    const scale = Math.max(1, Math.floor((size * 2) / Math.max(buf.w, buf.h + pad)));
    c.width = buf.w * scale;
    c.height = (buf.h + pad) * scale;
    const ctx = c.getContext('2d');
    if (!ctx) return;
    const hover = bossLook(id).hover;
    let raf = 0;
    let alive = true;
    let lastPhase = -1;
    const draw = (t: number) => {
      if (!alive) return;
      const phase = animate ? Math.floor(t / (hover ? 260 : 420)) % 2 : 0;
      if (phase !== lastPhase) {
        lastPhase = phase;
        ctx.clearRect(0, 0, c.width, c.height);
        buf.paint(ctx, scale, 0, (pad - phase) * scale);
      }
      if (animate) raf = requestAnimationFrame(draw);
    };
    draw(0);
    return () => {
      alive = false;
      cancelAnimationFrame(raf);
    };
  }, [id, size, silhouette, animate]);

  return <canvas ref={ref} className={`boss-portrait ${flash ? 'boss-hit' : ''} ${className}`} style={{ width: size, height: size }} role="img" aria-label="Boss" />;
}
