import { useMemo, useState } from 'react';
import { useUi } from '../store/ui';
import { useDerived, useQuests } from '../store/derived';
import { BossPortrait } from '../avatar/BossPortrait';
import { Card, Chip, SectionTitle, Stat, SubTabs } from '../components/ui';
import { QuestList } from '../components/QuestList';
import { ProgressLine } from '../components/GoalRow';
import { ACH_GROUPS, ACHIEVEMENTS, TIER_COLOR, tierOf, trophyPoints, type AchGroup, type Tier } from '../game/achievements';
import { BOSSES, bossAt, bossesInZone, isEcho, ZONES, WEAK_MULT } from '../game/campaign';
import { ITEM_BY_ID } from '../game/items';
import { DISCIPLINE_META } from '../game/types';
import type { PlayerState } from '../game/state';
import { addDays, daysBetween, formatDate, todayKey, weekKey } from '../game/dates';

export function Adventure() {
  const tab = useUi((s) => s.adventureTab);
  const setTab = useUi((s) => s.setAdventureTab);
  const derived = useDerived();
  const { daily, weekly, today } = useQuests(derived);
  const claimable = [...daily, ...weekly].filter((q) => q.done && !q.claimed).length;
  const weekEnd = addDays(weekKey(today), 6);
  const daysLeft = daysBetween(todayKey(), weekEnd);

  return (
    <div className="screen">
      <header className="topbar">
        <h1>Adventure</h1>
      </header>
      <SubTabs
        value={tab}
        onChange={setTab}
        options={[
          { value: 'campaign', label: '⚔️ Campaign' },
          {
            value: 'quests',
            label: (
              <>
                📜 Quests{claimable > 0 && <span className="badge">{claimable}</span>}
              </>
            ),
          },
          { value: 'trophies', label: '🏆 Trophies' },
        ]}
      />
      {tab === 'campaign' && <Campaign derived={derived} />}
      {tab === 'quests' && (
        <>
          <SectionTitle right={<span className="muted small">Resets at midnight</span>}>Daily</SectionTitle>
          <QuestList quests={daily} />
          <SectionTitle right={<span className="muted small">{daysLeft === 0 ? 'Last day!' : `${daysLeft} day${daysLeft === 1 ? '' : 's'} left`}</span>}>Weekly</SectionTitle>
          <QuestList quests={weekly} />
        </>
      )}
      {tab === 'trophies' && <Trophies derived={derived} />}
    </div>
  );
}

// ---------------------------------------------------------------------------

function Campaign({ derived }: { derived: PlayerState }) {
  const c = derived.campaign;
  const boss = bossAt(c.index);
  const hpLeft = boss.hp - c.damage;
  const defeated = Object.keys(c.defeated).length;
  const reward = boss.rewardItem ? ITEM_BY_ID[boss.rewardItem] : null;
  const echo = isEcho(c.index);

  return (
    <>
      <Card className="boss-card" style={{ '--zone': ZONES[boss.zone].color } as React.CSSProperties}>
        <div className="boss-zone">{echo ? 'Endless Trials' : `Zone ${boss.zone + 1} · ${ZONES[boss.zone].name}`}</div>
        <BossPortrait id={boss.id} size={132} animate />
        <div className="boss-title pixel-font">{boss.name}</div>
        <div className="muted small boss-epithet">{boss.epithet}</div>
        <div className="hpbar hpbar-big" role="progressbar" aria-label="Boss health" aria-valuemin={0} aria-valuemax={boss.hp} aria-valuenow={hpLeft}>
          <div className="hpbar-fill" style={{ width: `${(hpLeft / boss.hp) * 100}%` }} />
        </div>
        <div className="row between small boss-meta">
          <span>
            ❤️ {hpLeft.toLocaleString('en-US')} / {boss.hp.toLocaleString('en-US')} HP
          </span>
          {boss.weak ? (
            <span className="weak-tag" style={{ background: `var(--${boss.weak})` }}>
              Weak to {DISCIPLINE_META[boss.weak].icon} {DISCIPLINE_META[boss.weak].name} ×{WEAK_MULT}
            </span>
          ) : (
            <span className="muted">No weakness</span>
          )}
        </div>
        <div className="boss-reward small">
          Reward: <b>+{boss.xp.toLocaleString('en-US')} XP</b>
          {reward && (
            <>
              {' '}
              · 🎁 <b>{reward.name}</b>
            </>
          )}
        </div>
      </Card>

      <div className="tiles">
        <Stat label="Bosses down" value={`${Math.min(defeated, BOSSES.length)}/${BOSSES.length}`} />
        <Stat label="Total damage" value={Math.round(c.totalDamage).toLocaleString('en-US')} color="var(--accent)" />
        <Stat label={echo ? 'Echoes' : 'Zone'} value={echo ? defeated - BOSSES.length : `${boss.zone + 1}/${ZONES.length}`} />
      </div>
      <p className="muted small center">Every XP you earn from a session deals 1 damage. Train a boss's weakness for ×{WEAK_MULT}. Overkill carries over.</p>

      {ZONES.map((z, zi) => {
        const list = bossesInZone(zi);
        const cleared = list.filter((x) => x.index < c.index).length;
        const reached = c.index >= list[0].index;
        return (
          <Card key={z.name} className={`zone ${reached ? '' : 'zone-locked'}`} style={{ '--zone': z.color } as React.CSSProperties}>
            <div className="zone-head">
              <div>
                <div className="zone-name">
                  {zi + 1}. {z.name}
                </div>
                <div className="muted tiny">{reached ? z.blurb : 'Uncharted. Keep going.'}</div>
              </div>
              <div className="zone-pips" aria-label={`${cleared} of ${list.length} cleared`}>
                {list.map((x) => (
                  <span key={x.boss.id} className={`pip ${x.index < c.index ? 'pip-on' : ''}`} />
                ))}
              </div>
            </div>
            {list.map(({ boss: b, index }) => {
              const status = index < c.index ? 'defeated' : index === c.index ? 'current' : 'locked';
              const hp = status === 'current' ? b.hp - c.damage : b.hp;
              const known = status !== 'locked';
              return (
                <div key={b.id} className={`boss-row boss-${status}`}>
                  <BossPortrait id={b.id} size={44} silhouette={!known} className={status === 'defeated' ? 'boss-dim' : ''} />
                  <div className="grow boss-row-main">
                    <div className="boss-row-name">
                      {b.zoneBoss && <span title="Zone boss">👑 </span>}
                      {known ? b.name : '???'}
                    </div>
                    {status === 'current' ? (
                      <>
                        <div className="hpbar">
                          <div className="hpbar-fill" style={{ width: `${(hp / b.hp) * 100}%` }} />
                        </div>
                        <div className="muted tiny">
                          {hp.toLocaleString('en-US')} / {b.hp.toLocaleString('en-US')} HP
                        </div>
                      </>
                    ) : status === 'defeated' ? (
                      <div className="muted tiny">Defeated {formatDate(c.defeated[b.id]?.at ?? '')}</div>
                    ) : (
                      <div className="muted tiny">{b.hp.toLocaleString('en-US')} HP</div>
                    )}
                  </div>
                  <div className="boss-row-right">
                    {known && b.weak && <span title={`Weak to ${DISCIPLINE_META[b.weak].name}`}>{DISCIPLINE_META[b.weak].icon}</span>}
                    {b.rewardItem && <span title="Drops unique gear">🎁</span>}
                    {status === 'defeated' && <span className="boss-check">✓</span>}
                  </div>
                </div>
              );
            })}
          </Card>
        );
      })}
    </>
  );
}

// ---------------------------------------------------------------------------

const TIER_ICON: Record<Tier, string> = { bronze: '🥉', silver: '🥈', gold: '🥇', platinum: '💎' };

function Trophies({ derived }: { derived: PlayerState }) {
  const [filter, setFilter] = useState<'all' | AchGroup>('all');
  const unlocked = Object.keys(derived.achievements).length;
  const points = trophyPoints(derived);
  const maxPoints = useMemo(() => ACHIEVEMENTS.reduce((a, x) => a + x.xp, 0), []);
  const tierCounts = useMemo(() => {
    const t: Record<Tier, [number, number]> = { bronze: [0, 0], silver: [0, 0], gold: [0, 0], platinum: [0, 0] };
    for (const a of ACHIEVEMENTS) {
      const tier = tierOf(a);
      t[tier][1]++;
      if (derived.achievements[a.id]) t[tier][0]++;
    }
    return t;
  }, [derived]);

  const list = useMemo(
    () =>
      ACHIEVEMENTS.filter((a) => filter === 'all' || a.group === filter)
        .map((a) => {
          const u = derived.achievements[a.id];
          const p = !u && a.progress ? a.progress(derived) : null;
          const ratio = p ? Math.max(0, Math.min(1, p.unit === 'grade' ? (p.cur + 2) / (p.target + 2) : p.cur / p.target)) : 0;
          return { a, u, p, ratio };
        })
        .sort((x, y) => {
          if (!!x.u !== !!y.u) return x.u ? 1 : -1; // in-progress first, then earned
          if (!x.u) return y.ratio - x.ratio;
          return (y.u?.at ?? '').localeCompare(x.u?.at ?? '');
        }),
    [filter, derived],
  );

  return (
    <>
      <Card className="trophy-summary">
        <div className="trophy-score">
          <span className="pixel-font trophy-points">{points.toLocaleString('en-US')}</span>
          <span className="muted small">trophy points of {maxPoints.toLocaleString('en-US')}</span>
        </div>
        <div className="trophy-tiers">
          {(Object.keys(tierCounts) as Tier[]).map((t) => (
            <span key={t} className="trophy-tier" style={{ borderColor: TIER_COLOR[t] }}>
              {TIER_ICON[t]} {tierCounts[t][0]}/{tierCounts[t][1]}
            </span>
          ))}
        </div>
        <div className="muted small">
          {unlocked} of {ACHIEVEMENTS.length} trophies earned
        </div>
      </Card>
      <div className="chips scroll-x">
        <Chip active={filter === 'all'} onClick={() => setFilter('all')}>
          All
        </Chip>
        {ACH_GROUPS.map((g) => (
          <Chip key={g.id} active={filter === g.id} onClick={() => setFilter(g.id)}>
            {g.icon} {g.name}
          </Chip>
        ))}
      </div>
      <Card className="ach-list">
        {list.map(({ a, u, p }) => {
          const tier = tierOf(a);
          const hidden = !u && a.secret;
          return (
            <div key={a.id} className={`ach ${u ? 'ach-done' : ''}`}>
              <span className="ach-icon" style={{ borderColor: TIER_COLOR[tier] }}>
                {u ? a.icon : hidden ? '❓' : a.icon}
              </span>
              <span className="ach-main">
                <span className="ach-name">{hidden ? 'Secret trophy' : a.name}</span>
                <span className="muted small">{hidden ? 'Keep playing to discover it.' : a.desc}</span>
                {p && !hidden && <ProgressLine progress={p} color={a.group in DISCIPLINE_META ? `var(--${a.group})` : undefined} />}
              </span>
              <span className="ach-right">
                <span className="ach-xp">+{a.xp}</span>
                <span className="tiny" style={{ color: TIER_COLOR[tier] }}>
                  {u ? formatDate(u.at) : tier}
                </span>
              </span>
            </div>
          );
        })}
      </Card>
    </>
  );
}
