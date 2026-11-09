import type { Discipline, Loadout } from './types';
import { DISCIPLINES } from './types';
import { ITEM_BY_ID, type Perk } from './items';
import { PET_BY_ID } from './pets';
import type { PlayerState } from './state';

export interface PerkTotals {
  xp: Record<Discipline, number>;
  luck: number;
}

function addPerk(t: PerkTotals, p?: Perk) {
  if (!p) return;
  if (p.xp) {
    for (const d of DISCIPLINES) {
      t.xp[d] += (p.xp[d] ?? 0) + (p.xp.all ?? 0);
    }
  }
  if (p.luck) t.luck += p.luck;
}

/** Bonuses from the gear and pet currently equipped (ignores anything not owned). */
export function computePerks(state: PlayerState, loadout: Loadout, activePet: string | null): PerkTotals {
  const t: PerkTotals = { xp: { lift: 0, climb: 0, run: 0, ride: 0 }, luck: 0 };
  for (const id of Object.values(loadout)) {
    if (!id || !state.items[id]) continue;
    addPerk(t, ITEM_BY_ID[id]?.perk);
  }
  if (activePet && state.pets[activePet]) addPerk(t, PET_BY_ID[activePet]?.perk);
  return t;
}

/** Drop everything from the loadout that isn't actually owned any more. */
export function sanitizeLoadout(state: PlayerState, loadout: Loadout, activePet: string | null) {
  const out: Loadout = {};
  for (const [slot, id] of Object.entries(loadout)) {
    if (id && state.items[id] && ITEM_BY_ID[id]?.slot === slot) out[slot as keyof Loadout] = id;
  }
  const pet = activePet && state.pets[activePet] ? activePet : null;
  return { loadout: out, activePet: pet };
}
