// Tiny synthesized sound effects (no audio files). Everything is a few
// oscillator notes; the mute toggle lives in settings.

let ctx: AudioContext | null = null;
let enabled = true;

export function setSfxEnabled(v: boolean) {
  enabled = v;
}

function ac(): AudioContext | null {
  if (!enabled) return null;
  try {
    if (!ctx) ctx = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
    if (ctx.state === 'suspended') void ctx.resume();
    return ctx;
  } catch {
    return null;
  }
}

function note(freq: number, start: number, dur: number, type: OscillatorType = 'square', gain = 0.08) {
  const c = ac();
  if (!c) return;
  const o = c.createOscillator();
  const g = c.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, c.currentTime + start);
  g.gain.setValueAtTime(0.0001, c.currentTime + start);
  g.gain.exponentialRampToValueAtTime(gain, c.currentTime + start + 0.01);
  g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + start + dur);
  o.connect(g).connect(c.destination);
  o.start(c.currentTime + start);
  o.stop(c.currentTime + start + dur + 0.02);
}

export const sfx = {
  tick() {
    note(880, 0, 0.04, 'square', 0.03);
  },
  tap() {
    note(520, 0, 0.05, 'triangle', 0.05);
  },
  xp() {
    note(660, 0, 0.08, 'triangle', 0.06);
    note(990, 0.06, 0.1, 'triangle', 0.05);
  },
  levelUp() {
    const seq = [523, 659, 784, 1047];
    seq.forEach((f, i) => note(f, i * 0.09, 0.18, 'square', 0.07));
    note(1319, 0.38, 0.4, 'triangle', 0.06);
  },
  pr() {
    note(784, 0, 0.1, 'square', 0.06);
    note(988, 0.1, 0.1, 'square', 0.06);
    note(1175, 0.2, 0.25, 'square', 0.07);
  },
  achievement() {
    note(659, 0, 0.12, 'triangle', 0.07);
    note(880, 0.12, 0.12, 'triangle', 0.07);
    note(1319, 0.24, 0.3, 'triangle', 0.08);
  },
  drop(rarity: string) {
    const base = { common: 440, uncommon: 523, rare: 659, epic: 784, legendary: 988 }[rarity] ?? 440;
    note(base, 0, 0.1, 'sawtooth', 0.04);
    note(base * 1.5, 0.1, 0.15, 'sawtooth', 0.04);
    if (rarity === 'epic' || rarity === 'legendary') {
      note(base * 2, 0.25, 0.2, 'square', 0.05);
      note(base * 2.5, 0.4, 0.4, 'triangle', 0.06);
    }
  },
  pet() {
    note(1047, 0, 0.08, 'sine', 0.07);
    note(1319, 0.1, 0.08, 'sine', 0.07);
    note(1047, 0.2, 0.08, 'sine', 0.07);
    note(1568, 0.3, 0.25, 'sine', 0.08);
  },
  claim() {
    note(587, 0, 0.08, 'square', 0.05);
    note(880, 0.08, 0.08, 'square', 0.05);
    note(1175, 0.16, 0.2, 'square', 0.06);
  },
  stage() {
    [392, 523, 659, 784, 1047, 1319].forEach((f, i) => note(f, i * 0.1, 0.3, 'triangle', 0.07));
  },
  error() {
    note(220, 0, 0.15, 'sawtooth', 0.04);
    note(180, 0.12, 0.2, 'sawtooth', 0.04);
  },
};
