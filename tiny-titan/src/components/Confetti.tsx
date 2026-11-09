import { useEffect, useRef } from 'react';

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  size: number;
  color: string;
  rot: number;
  vr: number;
  life: number;
}

const COLORS = ['#ffc83d', '#ff7a59', '#6fd37a', '#5ad1e6', '#c792ea', '#ffffff', '#ff6b9d'];

/** A one-shot burst of pixel confetti. Re-fires whenever `burst` changes. */
export function Confetti({ burst, intensity = 1 }: { burst: number; intensity?: number }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (!burst) return;
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const W = (canvas.width = canvas.clientWidth || 320);
    const H = (canvas.height = canvas.clientHeight || 400);
    const parts: Particle[] = [];
    const n = Math.round(90 * intensity);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const sp = 2 + Math.random() * 6;
      parts.push({
        x: W / 2,
        y: H * 0.4,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp - 3,
        size: 3 + Math.random() * 4,
        color: COLORS[i % COLORS.length],
        rot: Math.random() * Math.PI,
        vr: (Math.random() - 0.5) * 0.3,
        life: 60 + Math.random() * 40,
      });
    }
    let raf = 0;
    const step = () => {
      ctx.clearRect(0, 0, W, H);
      let alive = false;
      for (const p of parts) {
        if (p.life <= 0) continue;
        alive = true;
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.18;
        p.vx *= 0.98;
        p.rot += p.vr;
        p.life--;
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.rot);
        ctx.globalAlpha = Math.min(1, p.life / 20);
        ctx.fillStyle = p.color;
        ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.6);
        ctx.restore();
      }
      if (alive) raf = requestAnimationFrame(step);
      else ctx.clearRect(0, 0, W, H);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [burst, intensity]);

  return <canvas ref={ref} className="confetti" aria-hidden="true" />;
}
