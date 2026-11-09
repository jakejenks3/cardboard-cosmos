// Small hand-rolled SVG charts: one y-axis, thin marks, recessive grid,
// direct labels, hover tooltips. Colours come from the discipline tokens.

import { useState } from 'react';
import type { Discipline } from '../game/types';
import { DISCIPLINES, DISCIPLINE_META } from '../game/types';
import { addDays, formatDate, todayKey, weekKey, weekdayIndex, addWeeks } from '../game/dates';

export interface WeekPoint {
  week: string;
  byDiscipline: Record<Discipline, number>;
  total: number;
}

export function WeeklyXpChart({ data, height = 150 }: { data: WeekPoint[]; height?: number }) {
  const [hover, setHover] = useState<number | null>(null);
  const W = 320;
  const padL = 34;
  const padR = 8;
  const padT = 10;
  const padB = 22;
  const innerW = W - padL - padR;
  const innerH = height - padT - padB;
  const max = Math.max(1, ...data.map((d) => d.total));
  const niceMax = niceCeil(max);
  const n = data.length;
  const slot = innerW / n;
  const barW = Math.max(6, slot - 4);
  const y = (v: number) => padT + innerH - (v / niceMax) * innerH;
  const ticks = [0, niceMax / 2, niceMax];
  const used = DISCIPLINES.filter((d) => data.some((p) => p.byDiscipline[d] > 0));

  return (
    <div className="chart">
      <svg viewBox={`0 0 ${W} ${height}`} className="chart-svg" role="img" aria-label="Weekly XP by discipline">
        {ticks.map((t) => (
          <g key={t}>
            <line x1={padL} x2={W - padR} y1={y(t)} y2={y(t)} className="chart-grid" />
            <text x={padL - 6} y={y(t) + 4} className="chart-tick" textAnchor="end">
              {fmtK(t)}
            </text>
          </g>
        ))}
        {data.map((p, i) => {
          const x = padL + i * slot + (slot - barW) / 2;
          let acc = 0;
          const segs = DISCIPLINES.filter((d) => p.byDiscipline[d] > 0).map((d) => {
            const v = p.byDiscipline[d];
            const y0 = y(acc + v);
            const h = Math.max(0, y(acc) - y0);
            acc += v;
            return { d, y0, h };
          });
          return (
            <g key={p.week} onMouseEnter={() => setHover(i)} onMouseLeave={() => setHover(null)} onTouchStart={() => setHover(i)}>
              <rect x={x - 2} y={padT} width={barW + 4} height={innerH} fill="transparent" />
              {segs.map((s, k) => (
                <rect
                  key={s.d}
                  x={x}
                  y={s.y0 + (k < segs.length - 1 ? 1 : 0)}
                  width={barW}
                  height={Math.max(0, s.h - (k < segs.length - 1 ? 1 : 0))}
                  rx={k === segs.length - 1 ? 3 : 0}
                  fill={`var(--${s.d})`}
                  opacity={hover === null || hover === i ? 1 : 0.45}
                />
              ))}
              {(i === n - 1 || i % 4 === 0) && (
                <text x={x + barW / 2} y={height - 6} className="chart-tick" textAnchor="middle">
                  {formatDate(p.week)}
                </text>
              )}
            </g>
          );
        })}
      </svg>
      {hover !== null && data[hover] && (
        <div className="chart-tip">
          <b>Week of {formatDate(data[hover].week)}</b>
          <div>{data[hover].total.toLocaleString('en-US')} XP</div>
          {DISCIPLINES.filter((d) => data[hover].byDiscipline[d] > 0).map((d) => (
            <div key={d} className="chart-tip-row">
              <span className="swatch" style={{ background: `var(--${d})` }} /> {DISCIPLINE_META[d].name}: {data[hover].byDiscipline[d].toLocaleString('en-US')}
            </div>
          ))}
        </div>
      )}
      {used.length >= 2 && (
        <div className="legend">
          {used.map((d) => (
            <span key={d} className="legend-item">
              <span className="swatch" style={{ background: `var(--${d})` }} /> {DISCIPLINE_META[d].name}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}

export function Heatmap({ xpByDate, weeks = 16 }: { xpByDate: Record<string, number>; weeks?: number }) {
  const [hover, setHover] = useState<string | null>(null);
  const today = todayKey();
  const thisWeek = weekKey(today);
  const start = addWeeks(thisWeek, -(weeks - 1));
  const max = Math.max(1, ...Object.values(xpByDate));
  const cols: string[][] = [];
  for (let w = 0; w < weeks; w++) {
    const wk = addWeeks(start, w);
    cols.push(Array.from({ length: 7 }, (_, d) => addDays(wk, d)));
  }
  const cell = 12;
  const gap = 3;
  const W = weeks * (cell + gap);
  const H = 7 * (cell + gap);
  const level = (v: number) => (v <= 0 ? 0 : v < max * 0.25 ? 1 : v < max * 0.5 ? 2 : v < max * 0.8 ? 3 : 4);
  return (
    <div className="chart">
      <svg viewBox={`0 0 ${W + 22} ${H}`} className="chart-svg heatmap" role="img" aria-label="Training heatmap">
        {['M', 'W', 'F'].map((l, i) => (
          <text key={l} x={0} y={[0, 2, 4][i] * (cell + gap) + cell - 2} className="chart-tick">
            {l}
          </text>
        ))}
        {cols.map((days, c) =>
          days.map((day, r) => {
            const v = xpByDate[day] ?? 0;
            const future = day > today;
            return (
              <rect
                key={day}
                x={22 + c * (cell + gap)}
                y={r * (cell + gap)}
                width={cell}
                height={cell}
                rx={3}
                className={`heat heat-${future ? 'future' : level(v)}`}
                onMouseEnter={() => setHover(day)}
                onMouseLeave={() => setHover(null)}
                onTouchStart={() => setHover(day)}
              />
            );
          }),
        )}
      </svg>
      {hover && (
        <div className="chart-tip">
          <b>{formatDate(hover, { weekday: 'short', month: 'short', day: 'numeric' })}</b>
          <div>{(xpByDate[hover] ?? 0).toLocaleString('en-US')} XP</div>
        </div>
      )}
    </div>
  );
}

export function GradePyramid({ counts, maxGrade }: { counts: Record<number, { sends: number; flashes: number }>; maxGrade: number }) {
  const grades: number[] = [];
  for (let g = Math.max(-1, maxGrade); g >= -1; g--) grades.push(g);
  const max = Math.max(1, ...grades.map((g) => (counts[g]?.sends ?? 0) + (counts[g]?.flashes ?? 0)));
  return (
    <div className="pyramid">
      {grades.map((g) => {
        const c = counts[g] ?? { sends: 0, flashes: 0 };
        const total = c.sends + c.flashes;
        return (
          <div key={g} className="pyramid-row">
            <span className="pyramid-label">{g < 0 ? 'VB' : `V${g}`}</span>
            <div className="pyramid-bar">
              <div className="pyramid-fill" style={{ width: `${(total / max) * 100}%` }}>
                <div className="pyramid-flash" style={{ width: total ? `${(c.flashes / total) * 100}%` : 0 }} />
              </div>
            </div>
            <span className="pyramid-n">{total}</span>
          </div>
        );
      })}
    </div>
  );
}

function niceCeil(v: number): number {
  const p = Math.pow(10, Math.floor(Math.log10(v)));
  const m = v / p;
  const n = m <= 1 ? 1 : m <= 2 ? 2 : m <= 5 ? 5 : 10;
  return n * p;
}
function fmtK(v: number): string {
  return v >= 1000 ? `${(v / 1000).toFixed(v % 1000 ? 1 : 0)}k` : String(Math.round(v));
}

export { weekdayIndex };
