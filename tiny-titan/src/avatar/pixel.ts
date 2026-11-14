// A tiny pixel buffer. Everything in the avatar is drawn into one of these
// and then blitted to a canvas with nearest-neighbour scaling.

export type Color = string;

export class Pix {
  readonly w: number;
  readonly h: number;
  readonly data: (Color | null)[];

  constructor(w: number, h: number) {
    this.w = w;
    this.h = h;
    this.data = new Array(w * h).fill(null);
  }

  inBounds(x: number, y: number): boolean {
    return x >= 0 && y >= 0 && x < this.w && y < this.h;
  }

  get(x: number, y: number): Color | null {
    if (!this.inBounds(x, y)) return null;
    return this.data[y * this.w + x];
  }

  set(x: number, y: number, c: Color | null): void {
    x = Math.round(x);
    y = Math.round(y);
    if (!this.inBounds(x, y)) return;
    this.data[y * this.w + x] = c;
  }

  rect(x: number, y: number, w: number, h: number, c: Color | null): void {
    x = Math.round(x);
    y = Math.round(y);
    for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.set(xx, yy, c);
  }

  hline(x: number, y: number, w: number, c: Color | null): void {
    this.rect(x, y, w, 1, c);
  }

  vline(x: number, y: number, h: number, c: Color | null): void {
    this.rect(x, y, 1, h, c);
  }

  /** Rectangle with the four corner pixels chamfered off. */
  roundRect(x: number, y: number, w: number, h: number, c: Color, r = 1): void {
    this.rect(x, y, w, h, c);
    for (let i = 0; i < r; i++) {
      for (let j = 0; j < r - i; j++) {
        this.set(x + i, y + j, null);
        this.set(x + w - 1 - i, y + j, null);
        this.set(x + i, y + h - 1 - j, null);
        this.set(x + w - 1 - i, y + h - 1 - j, null);
      }
    }
  }

  /** Filled ellipse. */
  ellipse(cx: number, cy: number, rx: number, ry: number, c: Color): void {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) {
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
        const dx = (x + 0.5 - cx) / (rx + 0.5);
        const dy = (y + 0.5 - cy) / (ry + 0.5);
        if (dx * dx + dy * dy <= 1) this.set(x, y, c);
      }
    }
  }

  /** A thick line drawn with a square brush — used for limbs so they can bend. */
  limb(x0: number, y0: number, x1: number, y1: number, width: number, c: Color): void {
    const steps = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1);
    const half = Math.floor(width / 2);
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const x = Math.round(x0 + (x1 - x0) * t);
      const y = Math.round(y0 + (y1 - y0) * t);
      this.rect(x - half, y - half, width, width, c);
    }
  }

  /** Draw a sprite given as rows of characters, mapping chars to colors. */
  sprite(x: number, y: number, rows: string[], palette: Record<string, Color>, flipX = false): void {
    for (let r = 0; r < rows.length; r++) {
      const row = rows[r];
      for (let i = 0; i < row.length; i++) {
        const ch = row[i];
        if (ch === '.' || ch === ' ') continue;
        const c = palette[ch];
        if (!c) continue;
        const px = flipX ? x + (row.length - 1 - i) : x + i;
        this.set(px, y + r, c);
      }
    }
  }

  /** Blit another buffer onto this one. */
  blit(src: Pix, x: number, y: number): void {
    for (let yy = 0; yy < src.h; yy++) {
      for (let xx = 0; xx < src.w; xx++) {
        const c = src.data[yy * src.w + xx];
        if (c) this.set(x + xx, y + yy, c);
      }
    }
  }

  /** Add a 1px outline around every filled pixel (into empty pixels only). */
  outline(color: Color): void {
    const add: number[] = [];
    for (let y = 0; y < this.h; y++) {
      for (let x = 0; x < this.w; x++) {
        if (this.data[y * this.w + x]) continue;
        if (this.get(x - 1, y) || this.get(x + 1, y) || this.get(x, y - 1) || this.get(x, y + 1)) add.push(y * this.w + x);
      }
    }
    for (const i of add) this.data[i] = color;
  }

  /** Paint to a canvas context, `scale` device pixels per buffer pixel. */
  paint(ctx: CanvasRenderingContext2D, scale: number, ox = 0, oy = 0): void {
    for (let y = 0; y < this.h; y++) {
      let x = 0;
      while (x < this.w) {
        const c = this.data[y * this.w + x];
        if (!c) {
          x++;
          continue;
        }
        let run = 1;
        while (x + run < this.w && this.data[y * this.w + x + run] === c) run++;
        ctx.fillStyle = c;
        ctx.fillRect(ox + x * scale, oy + y * scale, run * scale, scale);
        x += run;
      }
    }
  }
}

// --- colour helpers ---------------------------------------------------------

export function hexToRgb(hex: string): [number, number, number] {
  let h = hex.replace('#', '');
  if (h.length === 3) h = h.split('').map((c) => c + c).join('');
  const n = parseInt(h, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

export function rgbToHex(r: number, g: number, b: number): string {
  const c = (v: number) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0');
  return `#${c(r)}${c(g)}${c(b)}`;
}

/** factor < 1 darkens, > 1 lightens. */
export function shade(hex: string, factor: number): string {
  const [r, g, b] = hexToRgb(hex);
  if (factor >= 1) {
    const t = Math.min(1, factor - 1);
    return rgbToHex(r + (255 - r) * t, g + (255 - g) * t, b + (255 - b) * t);
  }
  return rgbToHex(r * factor, g * factor, b * factor);
}

export function mix(a: string, b: string, t: number): string {
  const [r1, g1, b1] = hexToRgb(a);
  const [r2, g2, b2] = hexToRgb(b);
  return rgbToHex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t);
}

export const OUTLINE = '#1a1026';
