import { useEffect, useMemo, useRef, useState } from 'react';
import { useStore } from '../store/useStore';
import { useUi } from '../store/ui';
import { useDerived, usePerks } from '../store/derived';
import { HeroScene } from '../avatar/HeroScene';
import { Pix, OUTLINE } from '../avatar/pixel';
import { PET_SPRITES } from '../avatar/petSprites';
import { Button, Chip, RarityBadge, Sheet, SectionTitle } from '../components/ui';
import { ITEMS, perkSummary, type ItemDef } from '../game/items';
import { PETS, PET_BY_ID, type PetDef } from '../game/pets';
import { SLOTS, SLOT_NAMES, RARITY_COLOR, RARITY_ORDER, DISCIPLINES, DISCIPLINE_META, type Slot } from '../game/types';
import { formatDate } from '../game/dates';
import { AppearanceEditor } from './Onboarding';
import { sfx } from '../sfx/sounds';

/** Static pixel portrait of a pet (used in grids and result cards). */
export function PetPortrait({ id, size = 48, locked = false }: { id: string; size?: number; locked?: boolean }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const c = ref.current;
    const sp = PET_SPRITES[id];
    if (!c || !sp) return;
    const rows = sp.frames[0];
    const w = Math.max(...rows.map((r) => r.length)) + 2;
    const h = rows.length + 2;
    const buf = new Pix(w, h);
    buf.sprite(1, 1, rows, sp.palette);
    buf.outline(OUTLINE);
    const scale = Math.max(1, Math.floor((size * 2) / Math.max(w, h)));
    c.width = w * scale;
    c.height = h * scale;
    const ctx = c.getContext('2d');
    if (!ctx) return;
    ctx.clearRect(0, 0, c.width, c.height);
    buf.paint(ctx, scale);
  }, [id, size]);
  return <canvas ref={ref} className={`pet-portrait ${locked ? 'locked' : ''}`} style={{ width: size, height: size }} aria-label={PET_BY_ID[id]?.species} />;
}

type Tab = Slot | 'pets' | 'look';

function unlockHint(it: ItemDef): string {
  switch (it.unlock.kind) {
    case 'drop':
      return 'Random drop';
    case 'unlock':
      return it.unlock.hint;
    default:
      return 'Starter kit';
  }
}

export function Armory() {
  const derived = useDerived();
  const profile = useStore((s) => s.profile)!;
  const loadout = useStore((s) => s.loadout);
  const activePet = useStore((s) => s.activePet);
  const equip = useStore((s) => s.equip);
  const setActivePet = useStore((s) => s.setActivePet);
  const updateProfile = useStore((s) => s.updateProfile);
  const toast = useUi((s) => s.toast);
  const perks = usePerks(derived);
  const [tab, setTab] = useState<Tab>('head');
  const [sel, setSel] = useState<ItemDef | null>(null);
  const [selPet, setSelPet] = useState<PetDef | null>(null);

  const ownedCount = Object.keys(derived.items).length;
  const petCount = Object.keys(derived.pets).length;
  const perkBits = DISCIPLINES.filter((d) => perks.xp[d] > 0).map((d) => `+${Math.round(perks.xp[d] * 100)}% ${DISCIPLINE_META[d].name.toLowerCase()} XP`);
  if (perks.luck > 0) perkBits.push(`+${Math.round(perks.luck * 100)}% loot luck`);

  const items = useMemo(
    () =>
      tab === 'pets' || tab === 'look'
        ? []
        : ITEMS.filter((i) => i.slot === tab).sort((a, b) => {
            const oa = derived.items[a.id] ? 0 : 1;
            const ob = derived.items[b.id] ? 0 : 1;
            return oa - ob || RARITY_ORDER.indexOf(a.rarity) - RARITY_ORDER.indexOf(b.rarity);
          }),
    [tab, derived],
  );

  const doEquip = (it: ItemDef) => {
    const already = loadout[it.slot] === it.id;
    equip(it.slot, already ? null : it.id);
    sfx.tap();
    toast(already ? `Unequipped ${it.name}` : `Equipped ${it.name}`, '🎒', 'good');
    setSel(null);
  };

  return (
    <div className="screen">
      <header className="topbar">
        <h1>Armory</h1>
        <span className="muted small">
          {ownedCount}/{ITEMS.length} items · {petCount}/{PETS.length} pets
        </span>
      </header>

      <div className="armory-hero">
        <HeroScene state={derived} profile={profile} loadout={loadout} activePet={activePet} scene={false} className="armory-canvas" />
        <div className="armory-perks">
          <div className="muted tiny">ACTIVE BONUSES</div>
          {perkBits.length ? perkBits.map((b) => <div key={b} className="perk">{b}</div>) : <div className="muted small">None yet — gear with perks shows up as you progress.</div>}
          {activePet && PET_BY_ID[activePet] && (
            <div className="muted small">
              🐾 {PET_BY_ID[activePet].name} the {PET_BY_ID[activePet].species}
            </div>
          )}
        </div>
      </div>

      <div className="chips scroll-x">
        {SLOTS.map((s) => (
          <Chip key={s} active={tab === s} onClick={() => setTab(s)}>
            {SLOT_NAMES[s]}
          </Chip>
        ))}
        <Chip active={tab === 'pets'} onClick={() => setTab('pets')}>
          🐾 Pets
        </Chip>
        <Chip active={tab === 'look'} onClick={() => setTab('look')}>
          ✂️ Look
        </Chip>
      </div>

      {tab === 'look' && (
        <div className="card">
          <AppearanceEditor skin={profile.skin} hairStyle={profile.hairStyle} hairColor={profile.hairColor} onChange={(p) => updateProfile(p)} />
        </div>
      )}

      {tab === 'pets' && (
        <div className="item-grid">
          {PETS.map((p) => {
            const owned = !!derived.pets[p.id];
            return (
              <button key={p.id} className={`item-tile ${owned ? '' : 'item-locked'} ${activePet === p.id ? 'item-equipped' : ''}`} style={{ '--rc': RARITY_COLOR[p.rarity] } as React.CSSProperties} onClick={() => setSelPet(p)}>
                <PetPortrait id={p.id} size={56} locked={!owned} />
                <span className="item-name">{owned ? p.name : '???'}</span>
                <span className="item-sub muted tiny">{owned ? p.species : p.hint}</span>
                {activePet === p.id && <span className="item-badge">Active</span>}
              </button>
            );
          })}
        </div>
      )}

      {tab !== 'pets' && tab !== 'look' && (
        <div className="item-grid">
          {tab === 'body' && (
            <button className={`item-tile ${!loadout.body ? 'item-equipped' : ''}`} onClick={() => { equip('body', null); sfx.tap(); }}>
              <div className="item-preview">
                <HeroScene state={derived} profile={profile} loadout={{ ...loadout, body: null }} activePet={null} scene={false} animate={false} />
              </div>
              <span className="item-name">Shirtless</span>
              <span className="item-sub muted tiny">Show off the gains</span>
              {!loadout.body && <span className="item-badge">Equipped</span>}
            </button>
          )}
          {items.map((it) => {
            const owned = !!derived.items[it.id];
            const equipped = loadout[it.slot] === it.id;
            return (
              <button key={it.id} className={`item-tile ${owned ? '' : 'item-locked'} ${equipped ? 'item-equipped' : ''}`} style={{ '--rc': RARITY_COLOR[it.rarity] } as React.CSSProperties} onClick={() => setSel(it)}>
                <div className="item-preview">
                  <HeroScene state={derived} profile={profile} loadout={{ ...loadout, [it.slot]: it.id }} activePet={null} scene={false} animate={false} />
                </div>
                <span className="item-name">{owned ? it.name : '???'}</span>
                <span className="item-sub muted tiny">{owned ? it.rarity : unlockHint(it)}</span>
                {equipped && <span className="item-badge">Equipped</span>}
              </button>
            );
          })}
        </div>
      )}

      <Sheet open={!!sel} onClose={() => setSel(null)}>
        {sel && (
          <div className="item-detail">
            <div className="item-detail-preview">
              <HeroScene state={derived} profile={profile} loadout={{ ...loadout, [sel.slot]: derived.items[sel.id] ? sel.id : loadout[sel.slot] }} activePet={null} scene={false} />
            </div>
            <div className="grow">
              <div className="row gap-s wrap">
                <RarityBadge rarity={sel.rarity} />
                <span className="muted small">{SLOT_NAMES[sel.slot]}</span>
                {sel.discipline && <span className="muted small">· {DISCIPLINE_META[sel.discipline].name}</span>}
              </div>
              <h2>{derived.items[sel.id] ? sel.name : 'Locked item'}</h2>
              <p className="muted">{derived.items[sel.id] ? sel.flavor : sel.unlock.kind === 'drop' ? 'Drops randomly after sessions. Loot luck helps.' : `Unlock: ${unlockHint(sel)}`}</p>
              {perkSummary(sel.perk).map((p) => (
                <div key={p} className="perk">
                  {p}
                </div>
              ))}
              {derived.items[sel.id] && derived.items[sel.id].at && <div className="muted tiny">Obtained {formatDate(derived.items[sel.id].at)}</div>}
              {derived.items[sel.id] && (
                <Button size="lg" className="mt" onClick={() => doEquip(sel)}>
                  {loadout[sel.slot] === sel.id ? 'Unequip' : 'Equip'}
                </Button>
              )}
            </div>
          </div>
        )}
      </Sheet>

      <Sheet open={!!selPet} onClose={() => setSelPet(null)}>
        {selPet && (
          <div className="item-detail">
            <PetPortrait id={selPet.id} size={96} locked={!derived.pets[selPet.id]} />
            <div className="grow">
              <RarityBadge rarity={selPet.rarity} />
              <h2>{derived.pets[selPet.id] ? `${selPet.name} the ${selPet.species}` : 'Unknown companion'}</h2>
              <p className="muted">{derived.pets[selPet.id] ? selPet.flavor : `Unlock: ${selPet.hint}`}</p>
              {perkSummary(selPet.perk).map((p) => (
                <div key={p} className="perk">
                  {p}
                </div>
              ))}
              {derived.pets[selPet.id] && (
                <Button
                  size="lg"
                  className="mt"
                  onClick={() => {
                    const already = activePet === selPet.id;
                    setActivePet(already ? null : selPet.id);
                    sfx.tap();
                    toast(already ? `${selPet.name} stays home` : `${selPet.name} is now following you`, '🐾', 'good');
                    setSelPet(null);
                  }}
                >
                  {activePet === selPet.id ? 'Send home' : 'Follow me'}
                </Button>
              )}
            </div>
          </div>
        )}
      </Sheet>
      <SectionTitle>
        <span className="muted small">Tip: perks stack. A full set of discipline gear plus its pet is a serious XP boost.</span>
      </SectionTitle>
    </div>
  );
}
