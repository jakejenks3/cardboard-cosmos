// Dev page: /?preview=avatar — renders the hero at many levels and loadouts
// so the procedural body and every item template can be eyeballed at once.

import { useMemo } from 'react';
import { HeroScene } from '../avatar/HeroScene';
import { derive } from '../game/derive';
import { ITEMS } from '../game/items';
import { PETS } from '../game/pets';
import type { Loadout, Profile, Slot } from '../game/types';
import { BOSSES } from '../game/campaign';
import { BossPortrait } from '../avatar/BossPortrait';

const profile: Profile = { name: 'Preview', skin: 1, hairStyle: 0, hairColor: 1, createdAt: 0 };

export function AvatarPreview() {
  // Everything owned, so any loadout renders.
  const state = useMemo(() => {
    const s = derive({ sessions: [], claims: [], weeklyGoal: 3, today: '2026-01-01' });
    for (const i of ITEMS) s.items[i.id] = { at: '', how: 'unlock' };
    for (const p of PETS) s.pets[p.id] = { at: '' };
    s.achievements = Object.fromEntries(Array.from({ length: 20 }, (_, i) => [`a${i}`, { at: '' }]));
    s.totals.sessions = 50;
    return s;
  }, []);

  const starter: Loadout = { body: 'tee_grey', legs: 'shorts_navy', feet: 'trainers_worn' };
  const stages = [
    { label: 'Lv1 scrawny', lv: { hero: 1, lift: 1, climb: 1, run: 1, ride: 1 } },
    { label: 'Lv6', lv: { hero: 6, lift: 4, climb: 2, run: 3, ride: 1 } },
    { label: 'Lv14 lifter', lv: { hero: 14, lift: 14, climb: 3, run: 3, ride: 2 } },
    { label: 'Lv14 climber', lv: { hero: 14, lift: 3, climb: 14, run: 3, ride: 2 } },
    { label: 'Lv14 runner', lv: { hero: 14, lift: 3, climb: 3, run: 14, ride: 2 } },
    { label: 'Lv14 rider', lv: { hero: 14, lift: 3, climb: 3, run: 2, ride: 14 } },
    { label: 'Lv25 balanced', lv: { hero: 25, lift: 15, climb: 15, run: 15, ride: 15 } },
    { label: 'Lv40 jacked', lv: { hero: 40, lift: 32, climb: 20, run: 20, ride: 18 } },
    { label: 'Lv60 titan', lv: { hero: 60, lift: 40, climb: 40, run: 40, ride: 40 } },
  ];

  const bySlot: Record<string, string[]> = {};
  for (const i of ITEMS) (bySlot[i.slot] ??= []).push(i.id);
  const slots = Object.keys(bySlot) as Slot[];

  const stateFor = (lv: { hero: number; lift: number; climb: number; run: number; ride: number }) => {
    const s = { ...state, stage: lv.hero >= 50 ? 5 : lv.hero >= 35 ? 4 : lv.hero >= 22 ? 3 : lv.hero >= 12 ? 2 : lv.hero >= 5 ? 1 : 0 };
    return s;
  };

  return (
    <div style={{ padding: 16, background: '#0f0c1e', color: '#fff', fontFamily: 'sans-serif' }}>
      <h2>Body stages (starter kit)</h2>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
        {stages.map((st) => (
          <div key={st.label} style={{ width: 240 }}>
            <HeroScene state={stateFor(st.lv)} profile={profile} loadout={starter} activePet={null} levelsOverride={st.lv} animate={false} />
            <div style={{ fontSize: 12 }}>{st.label}</div>
          </div>
        ))}
      </div>
      <h2>Flex pose + shirtless</h2>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
        {[stages[0], stages[2], stages[7]].map((st) => (
          <div key={st.label} style={{ width: 160 }}>
            <HeroScene state={stateFor(st.lv)} profile={profile} loadout={{ legs: 'shorts_navy' }} activePet={null} levelsOverride={st.lv} pose="flex" scene={false} animate={false} />
          </div>
        ))}
      </div>
      <h2>Bosses</h2>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
        {BOSSES.map((b) => (
          <div key={b.id} style={{ width: 110, textAlign: 'center', background: '#231d45', borderRadius: 8, padding: 6 }}>
            <BossPortrait id={b.id} size={88} />
            <div style={{ fontSize: 10 }}>{b.name}</div>
          </div>
        ))}
        <div style={{ width: 110, textAlign: 'center', background: '#231d45', borderRadius: 8, padding: 6 }}>
          <BossPortrait id="echo_1" size={88} />
          <div style={{ fontSize: 10 }}>Echo</div>
        </div>
        <div style={{ width: 110, textAlign: 'center', background: '#231d45', borderRadius: 8, padding: 6 }}>
          <BossPortrait id="iron_golem" size={88} silhouette />
          <div style={{ fontSize: 10 }}>silhouette</div>
        </div>
      </div>
      <h2>Items by slot (on Lv25 body)</h2>
      {slots.map((slot) => (
        <div key={slot}>
          <h3 style={{ fontSize: 14 }}>{slot}</h3>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {bySlot[slot].map((id) => (
              <div key={id} style={{ width: 96 }}>
                <HeroScene
                  state={stateFor(stages[6].lv)}
                  profile={profile}
                  loadout={{ ...starter, [slot]: id }}
                  activePet={null}
                  levelsOverride={stages[6].lv}
                  scene={false}
                  animate={false}
                />
                <div style={{ fontSize: 10 }}>{id}</div>
              </div>
            ))}
          </div>
        </div>
      ))}
      <h2>Hair styles</h2>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {[0, 1, 2, 3, 4, 5, 6].map((h) => (
          <div key={h} style={{ width: 96 }}>
            <HeroScene state={stateFor(stages[1].lv)} profile={{ ...profile, hairStyle: h, hairColor: h }} loadout={starter} activePet={null} levelsOverride={stages[1].lv} scene={false} animate={false} />
          </div>
        ))}
      </div>
      <h2>Pets</h2>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {PETS.map((p) => (
          <div key={p.id} style={{ width: 240 }}>
            <HeroScene state={stateFor(stages[1].lv)} profile={profile} loadout={starter} activePet={p.id} levelsOverride={stages[1].lv} animate={false} />
            <div style={{ fontSize: 12 }}>{p.name} the {p.species}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
