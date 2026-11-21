// Small deterministic PRNG. Loot is rolled from a seed derived from the
// session id so replaying the log always reproduces the same drops.

export function hashString(str: string): number {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h >>> 0;
}

export interface Rng {
  /** [0, 1) */
  next(): number;
  int(maxExclusive: number): number;
  pick<T>(arr: T[]): T;
  weighted<T>(arr: T[], weight: (t: T) => number): T | null;
}

export function makeRng(seed: number | string): Rng {
  let s = (typeof seed === 'string' ? hashString(seed) : seed >>> 0) || 1;
  const next = () => {
    // mulberry32
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    next,
    int: (max) => Math.floor(next() * max),
    pick: (arr) => arr[Math.floor(next() * arr.length)],
    weighted: (arr, weight) => {
      let total = 0;
      const ws = arr.map((a) => {
        const w = Math.max(0, weight(a));
        total += w;
        return w;
      });
      if (total <= 0) return null;
      let r = next() * total;
      for (let i = 0; i < arr.length; i++) {
        r -= ws[i];
        if (r < 0) return arr[i];
      }
      return arr[arr.length - 1];
    },
  };
}

export function uid(prefix = ''): string {
  const t = Date.now().toString(36);
  const r = Math.floor(Math.random() * 0xffffffff).toString(36);
  return `${prefix}${t}${r}`;
}
