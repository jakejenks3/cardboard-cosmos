import { useEffect, useMemo, useRef, useState } from 'react';
import { useUi } from '../store/ui';
import { useStore } from '../store/useStore';
import { useDerived } from '../store/derived';
import type { ResultEvent } from '../game/diff';
import { DISCIPLINE_META, DISCIPLINES, RARITY_COLOR } from '../game/types';
import { ACHIEVEMENT_BY_ID } from '../game/achievements';
import { ITEM_BY_ID, perkSummary } from '../game/items';
import { PET_BY_ID } from '../game/pets';
import { STAGES } from '../game/xp';
import { HeroScene } from '../avatar/HeroScene';
import { XpBarAnim } from '../components/XpBarAnim';
import { Confetti } from '../components/Confetti';
import { Button, RarityBadge } from '../components/ui';
import { sfx } from '../sfx/sounds';
import { PetPortrait } from './Armory';

function useCountUp(target: number, play: boolean, ms = 900): number {
  const [v, setV] = useState(0);
  useEffect(() => {
    if (!play) return;
    let raf = 0;
    const t0 = performance.now();
    const step = (t: number) => {
      const k = Math.min(1, (t - t0) / ms);
      const e = 1 - Math.pow(1 - k, 3);
      setV(Math.round(target * e));
      if (k < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [target, play, ms]);
  return v;
}

export function ResultsOverlay() {
  const result = useUi((s) => s.result);
  const setResult = useUi((s) => s.setResult);
  if (!result) return null;
  return <ResultsReel key={result.sessions.map((s) => s.id).join(',')} events={result.events} title={result.title} onClose={() => setResult(null)} />;
}

function ResultsReel({ events, title, onClose }: { events: ResultEvent[]; title: string; onClose: () => void }) {
  const derived = useDerived();
  const profile = useStore((s) => s.profile)!;
  const loadout = useStore((s) => s.loadout);
  const activePet = useStore((s) => s.activePet);
  const equip = useStore((s) => s.equip);
  const setActivePet = useStore((s) => s.setActivePet);
  const toast = useUi((s) => s.toast);

  const xpEv = events.find((e) => e.type === 'xp');
  const importEv = events.find((e) => e.type === 'import');
  const cards = useMemo(() => events.filter((e) => e.type !== 'xp' && e.type !== 'import' && e.type !== 'levelup'), [events]);
  const leveled = events.some((e) => e.type === 'levelup');
  const [phase, setPhase] = useState<'xp' | 'disc' | 'hero' | 'cards' | 'done'>('xp');
  const [shown, setShown] = useState(0);
  const [confetti, setConfetti] = useState(0);
  const amount = xpEv?.type === 'xp' ? xpEv.amount : importEv?.type === 'import' ? importEv.xp : 0;
  const count = useCountUp(amount, true);
  const scrollRef = useRef<HTMLDivElement>(null);

  // timeline: number → discipline bar → hero bar → cards
  useEffect(() => {
    const t = setTimeout(() => setPhase(xpEv ? 'disc' : 'hero'), 1000);
    return () => clearTimeout(t);
  }, [xpEv]);

  useEffect(() => {
    if (phase !== 'cards') return;
    if (shown >= cards.length) {
      setPhase('done');
      return;
    }
    const ev = cards[shown];
    const t = setTimeout(() => {
      if (ev.type === 'item') sfx.drop(ITEM_BY_ID[ev.id]?.rarity ?? 'common');
      else if (ev.type === 'achievement') sfx.achievement();
      else if (ev.type === 'pet') sfx.pet();
      else if (ev.type === 'pr') sfx.pr();
      else if (ev.type === 'stage') {
        sfx.stage();
        setConfetti((c) => c + 1);
      } else sfx.tap();
      setShown((n) => n + 1);
      requestAnimationFrame(() => scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' }));
    }, shown === 0 ? 300 : 650);
    return () => clearTimeout(t);
  }, [phase, shown, cards]);

  const skip = () => {
    if (phase === 'done') return;
    setPhase('cards');
    setShown(cards.length);
  };

  const summaryLine = () => {
    if (importEv?.type === 'import') {
      const bits = DISCIPLINES.filter((d) => importEv.byDiscipline[d] > 0).map((d) => `${DISCIPLINE_META[d].icon} ${importEv.byDiscipline[d].toLocaleString('en-US')}`);
      return `${importEv.count} sessions · ${bits.join('  ')}`;
    }
    if (xpEv?.type === 'xp') return xpEv.parts.map((p) => `${p.label} +${p.xp}`).join(' · ') + (xpEv.prBonus ? ` · PR bonus +${xpEv.prBonus}` : '');
    return '';
  };

  const disc = xpEv?.type === 'xp' ? xpEv.discipline : null;
  const heroPair = xpEv?.type === 'xp' ? xpEv.hero : importEv?.type === 'import' ? importEv.hero : null;

  return (
    <div className="results" onClick={skip}>
      <Confetti burst={confetti} intensity={1.2} />
      <div className="results-scroll" ref={scrollRef}>
        <div className="results-head">
          <div className="pixel-font results-title">{title}</div>
          <div className="results-hero">
            <HeroScene state={derived} profile={profile} loadout={loadout} activePet={activePet} scene={false} happy pose={leveled || phase === 'done' ? 'flex' : 'idle'} />
          </div>
          <div className="pixel-font results-xp" style={{ color: disc ? `var(--${disc})` : 'var(--accent)' }}>
            +{count.toLocaleString('en-US')} XP
          </div>
          <div className="results-summary muted small">{summaryLine()}</div>
          {xpEv?.type === 'xp' && xpEv.bonusPct > 0 && <div className="muted tiny">includes +{Math.round(xpEv.bonusPct * 100)}% gear bonus</div>}
        </div>

        <div className="results-bars">
          {xpEv?.type === 'xp' && (phase === 'disc' || phase === 'hero' || phase === 'cards' || phase === 'done') && (
            <XpBarAnim
              before={xpEv.disc.before}
              after={xpEv.disc.after}
              color={`var(--${xpEv.discipline})`}
              label={`${DISCIPLINE_META[xpEv.discipline].icon} ${DISCIPLINE_META[xpEv.discipline].name}`}
              play={phase === 'disc'}
              onLevelUp={() => setConfetti((c) => c + 1)}
              onDone={() => setPhase('hero')}
            />
          )}
          {(phase === 'hero' || phase === 'cards' || phase === 'done') && heroPair && (
            <XpBarAnim
              before={heroPair.before}
              after={heroPair.after}
              color="var(--accent)"
              label="⭐ Hero"
              play={phase === 'hero'}
              onLevelUp={() => setConfetti((c) => c + 1)}
              onDone={() => setPhase('cards')}
            />
          )}
        </div>

        <div className="results-cards">
          {cards.slice(0, shown).map((ev, i) => (
            <ResultCard
              key={i}
              ev={ev}
              onEquip={(slot, id) => {
                equip(slot, id);
                sfx.tap();
                toast(`Equipped ${ITEM_BY_ID[id].name}`, '🎒', 'good');
              }}
              onPet={(id) => {
                setActivePet(id);
                sfx.tap();
                toast(`${PET_BY_ID[id].name} is now following you`, '🐾', 'good');
              }}
            />
          ))}
        </div>
      </div>
      <div className="results-footer">
        {phase === 'done' ? (
          <Button size="lg" onClick={onClose} className="grow">
            Continue
          </Button>
        ) : (
          <Button size="lg" variant="ghost" onClick={skip} className="grow">
            Tap to skip
          </Button>
        )}
      </div>
    </div>
  );
}

function ResultCard({ ev, onEquip, onPet }: { ev: ResultEvent; onEquip: (slot: never, id: string) => void; onPet: (id: string) => void }) {
  const loadout = useStore((s) => s.loadout);
  const activePet = useStore((s) => s.activePet);
  switch (ev.type) {
    case 'stage': {
      const to = STAGES[ev.to];
      return (
        <div className="rcard rcard-stage pop">
          <div className="rcard-kicker">BODY EVOLVED</div>
          <div className="rcard-title pixel-font">
            {STAGES[ev.from].name} → {to.name}
          </div>
          <div className="muted small">{to.blurb}</div>
        </div>
      );
    }
    case 'pr':
      return (
        <div className="rcard rcard-pr pop">
          <div className="rcard-icon">{ev.icon}</div>
          <div>
            <div className="rcard-kicker">NEW RECORD</div>
            <div className="rcard-title">{ev.title}</div>
            <div className="muted small">{ev.detail}</div>
          </div>
        </div>
      );
    case 'achievement': {
      const a = ACHIEVEMENT_BY_ID[ev.id];
      if (!a) return null;
      return (
        <div className="rcard rcard-ach pop">
          <div className="rcard-icon">{a.icon}</div>
          <div>
            <div className="rcard-kicker">ACHIEVEMENT · +{a.xp} XP</div>
            <div className="rcard-title">{a.name}</div>
            <div className="muted small">{a.desc}</div>
          </div>
        </div>
      );
    }
    case 'item': {
      const it = ITEM_BY_ID[ev.id];
      if (!it) return null;
      const equipped = loadout[it.slot] === it.id;
      const perks = perkSummary(it.perk);
      return (
        <div className={`rcard rcard-item rarity-${it.rarity} pop`} style={{ '--rc': RARITY_COLOR[it.rarity] } as React.CSSProperties}>
          <div className="rcard-icon">{ev.how === 'drop' ? '🎁' : '🔓'}</div>
          <div className="grow">
            <div className="rcard-kicker">
              {ev.how === 'drop' ? 'LOOT DROP' : 'UNLOCKED'} · <RarityBadge rarity={it.rarity} />
            </div>
            <div className="rcard-title">{it.name}</div>
            <div className="muted small">{it.flavor}</div>
            {perks.length > 0 && <div className="perk small">{perks.join(' · ')}</div>}
          </div>
          <Button size="sm" variant={equipped ? 'ghost' : 'secondary'} disabled={equipped} onClick={(e) => { e.stopPropagation(); onEquip(it.slot as never, it.id); }}>
            {equipped ? 'Equipped' : 'Equip'}
          </Button>
        </div>
      );
    }
    case 'pet': {
      const p = PET_BY_ID[ev.id];
      if (!p) return null;
      return (
        <div className={`rcard rcard-pet rarity-${p.rarity} pop`} style={{ '--rc': RARITY_COLOR[p.rarity] } as React.CSSProperties}>
          <PetPortrait id={p.id} size={56} />
          <div className="grow">
            <div className="rcard-kicker">NEW COMPANION</div>
            <div className="rcard-title">
              {p.name} the {p.species}
            </div>
            <div className="muted small">{p.flavor}</div>
            <div className="perk small">{perkSummary(p.perk).join(' · ')}</div>
          </div>
          <Button size="sm" variant={activePet === p.id ? 'ghost' : 'secondary'} disabled={activePet === p.id} onClick={(e) => { e.stopPropagation(); onPet(p.id); }}>
            {activePet === p.id ? 'Active' : 'Follow me'}
          </Button>
        </div>
      );
    }
    case 'streak':
      return (
        <div className="rcard rcard-streak pop">
          <div className="rcard-icon">🔥</div>
          <div>
            <div className="rcard-kicker">STREAK</div>
            <div className="rcard-title">{ev.current} weeks in a row</div>
            <div className="muted small">Consistency is the real superpower.</div>
          </div>
        </div>
      );
    default:
      return null;
  }
}
