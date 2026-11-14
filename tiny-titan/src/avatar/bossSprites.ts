// Campaign bosses: nine hand-pixelled base sprites, re-coloured per boss.

import { Pix, OUTLINE } from './pixel';

const K = OUTLINE;

const BASE: Record<string, string[]> = {
  clock: [
    '..rr......rr..',
    '.rrrr....rrrr.',
    '..rrwwwwwwrr..',
    '..rwwwwwwwwr..',
    '.rwwkwwwwkwwr.',
    '.rwwkwwwwkwwr.',
    '.rwwwwyywwwwr.',
    '.rwwwwywwwwwr.',
    '.rwwkkkkkkwwr.',
    '..rwwwwwwwwr..',
    '..rrwwwwwwrr..',
    '...rrrrrrrr...',
    '..rr......rr..',
    '.rr........rr.',
  ],
  blob: [
    '....bbbbbb....',
    '..bbbbbbbbbb..',
    '.bbbdbbbbbbbb.',
    '.bbbbbbbbbdbb.',
    'bbkkkbbbbkkkbb',
    'bbbbbbbbbbbbbb',
    'bbbbbbmmbbbbbb',
    'bbdbbbbbbbbbbb',
    '.bbbbbbbbbbdb.',
    '.bbbbbbbbbbbb.',
    'ssssssssssssss',
    'ssssssssssssss',
  ],
  imp: [
    '.h..........h.',
    '.hh........hh.',
    '..iiiiiiiiii..',
    '.iiiiiiiiiiii.',
    '.iiweiiiiweii.',
    '.iiweiiiiweii.',
    '.iiiiiiiiiiii.',
    '.iikiiiiiikii.',
    '..iikkkkkkii..',
    '...iiiiiiii...',
    '..iiiiiiiiii..',
    '.ii.iiiiii.ii.',
    '.i..ii..ii..i.',
    '....ii..ii....',
  ],
  golem: [
    '....gggggg....',
    '...gggggggg...',
    '...geeggeeg...',
    '...gggggggg...',
    '.gggggggggggg.',
    'gggdggggggdggg',
    'ggg.gggggg.ggg',
    'ggg.gdggdg.ggg',
    'ggg.gggggg.ggg',
    'gg..gggggg..gg',
    'gg..ggg.ggg.gg',
    '....ggg.ggg...',
    '....ggg.ggg...',
    '...gggg.gggg..',
  ],
  wraith: [
    '....wwwwww....',
    '..wwwwwwwwww..',
    '.wwwwwwwwwwww.',
    '.wwkkwwwwkkww.',
    '.wwkkwwwwkkww.',
    '.wwwwwwwwwwww.',
    '.wwwwkkkkwwww.',
    '.wwwwwwwwwwww.',
    '.wwwwwwwwwwww.',
    '.wwwwwwwwwww..',
    '.ww.www.www...',
    '.w...ww..ww...',
    '......w...w...',
  ],
  wyvern: [
    'd............d',
    'dd....vv....dd',
    'ddd..vvvv..ddd',
    '.dddvevvevddd.',
    '..ddvvvvvvdd..',
    '...vvvkkvvv...',
    '...vvvvvvvv...',
    '..vvvbbbbvvv..',
    '..vvbbbbbbvv..',
    '..vvbbbbbbvv..',
    '...vvbbbbvv.vv',
    '...vv....vv..v',
    '..vvv....vvv..',
  ],
  mountain: [
    '......ss......',
    '.....ssss.....',
    '....ssssss....',
    '...mmssssmm...',
    '...mmmmmmmm...',
    '..mmkmmmmkmm..',
    '..mmkmmmmkmm..',
    '.mmmmmmmmmmmm.',
    '.mmmmkkkkmmmm.',
    'mmmmmmmmmmmmmm',
    'mmrmmmmmmmmrmm',
    'mmmrrmmmmrrmmm',
    'mmmmmrrrrmmmmm',
  ],
  shadow: [
    '.....kkkk.....',
    '....kkkkkk....',
    '....kekkek....',
    '....kkkkkk....',
    '.....kkkk.....',
    '......kk......',
    '....kkkkkk....',
    '...kkkkkkkk...',
    '...k.kkkk.k...',
    '...k.kkkk.k...',
    '...k.kkkk.k...',
    '.....kkkk.....',
    '.....k..k.....',
    '.....k..k.....',
    '....kk..kk....',
  ],
  wheel: [
    '....tttttt....',
    '..tttttttttt..',
    '.tttggggggttt.',
    '.ttggggggggtt.',
    'ttggkkggkkggtt',
    'ttggkkggkkggtt',
    'ttggggggggggtt',
    'ttggkggggkggtt',
    'ttgggkkkkgggtt',
    '.ttggggggggtt.',
    '.tttggggggttt.',
    '..tttttttttt..',
    '....tttttt....',
  ],
};

interface Look {
  sprite: keyof typeof BASE;
  palette: Record<string, string>;
  /** Floats above the ground. */
  hover?: boolean;
}

const imp = (horn: string, body: string): Look => ({ sprite: 'imp', palette: { h: horn, i: body, w: '#ffffff', e: K, k: K } });
const wraith = (body: string, dark: string): Look => ({ sprite: 'wraith', palette: { w: body, k: dark }, hover: true });
const golem = (body: string, seam: string, eye: string): Look => ({ sprite: 'golem', palette: { g: body, d: seam, e: eye } });
const blob = (body: string, spot: string, mouth: string, base: string): Look => ({ sprite: 'blob', palette: { b: body, d: spot, k: K, m: mouth, s: base } });

export const BOSS_LOOK: Record<string, Look> = {
  snooze_button: { sprite: 'clock', palette: { r: '#e53935', w: '#fff8e1', k: K, y: '#37474f' } },
  couch_potato: blob('#c9a36a', '#a07d48', '#5d4037', '#7e57c2'),
  elevator_imp: imp('#cfd8dc', '#5c9ded'),
  sunday_scaries: wraith('#5c6bc0', '#0d0a1a'),
  rust_mite: imp('#8d6e63', '#bf5b17'),
  ego_imp: imp('#ffd54f', '#e53935'),
  doms_demon: wraith('#d84343', '#1a0505'),
  iron_golem: golem('#90a4ae', '#546e7a', '#ff5252'),
  greasy_sloper: blob('#78909c', '#546e7a', '#263238', '#546e7a'),
  pump_wraith: wraith('#26a69a', '#04201d'),
  gravity_gremlin: imp('#ce93d8', '#8e24aa'),
  crux_wyvern: { sprite: 'wyvern', palette: { d: '#2e7d32', v: '#43a047', e: '#ffeb3b', k: K, b: '#c5e1a5' }, hover: true },
  side_stitch: imp('#ffab91', '#ec407a'),
  blister_blob: blob('#ef9a9a', '#e57373', '#b71c1c', '#e57373'),
  headwind_wraith: wraith('#b3e5fc', '#0d2a3a'),
  the_wall: golem('#a1543a', '#6d3524', '#ffeb3b'),
  pothole_pixie: imp('#bdbdbd', '#757575'),
  flat_tire_fiend: { sprite: 'wheel', palette: { t: '#263238', g: '#9e9e9e', k: K } },
  bonk_beast: blob('#fff3e0', '#ffe0b2', '#8d6e63', '#ffe0b2'),
  col_du_doom: { sprite: 'mountain', palette: { s: '#ffffff', m: '#6d4c41', k: K, r: '#ffca28' } },
  plateau_giant: golem('#d4a017', '#9a7410', '#ffffff'),
  excuse_hydra: { sprite: 'wyvern', palette: { d: '#00695c', v: '#00897b', e: '#ff5252', k: K, b: '#b2dfdb' }, hover: true },
  comparison_specter: wraith('#ba68c8', '#1f0a29'),
  old_you: { sprite: 'shadow', palette: { k: '#2a1f4a', e: '#ff5252' } },
};

const ECHO_LOOK: Look = { sprite: 'shadow', palette: { k: '#3a3a52', e: '#7fe7ff' } };

export function bossLook(id: string): Look {
  return BOSS_LOOK[id] ?? ECHO_LOOK;
}

/** Render a boss into a tight, outlined buffer. */
export function bossBuffer(id: string, opts: { silhouette?: boolean } = {}): Pix {
  const look = bossLook(id);
  const rows = BASE[look.sprite];
  const w = Math.max(...rows.map((r) => r.length));
  const buf = new Pix(w + 2, rows.length + 2);
  let palette = look.palette;
  if (opts.silhouette) {
    palette = Object.fromEntries(Object.keys(look.palette).map((k) => [k, '#0d0a1a']));
  }
  buf.sprite(1, 1, rows, palette);
  buf.outline(opts.silhouette ? '#241c40' : OUTLINE);
  return buf;
}
