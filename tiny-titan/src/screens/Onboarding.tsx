import { useMemo, useState } from 'react';
import { useStore, DEFAULT_LOADOUT } from '../store/useStore';
import { HeroScene } from '../avatar/HeroScene';
import { HAIR_COLORS, HAIR_STYLES, SKIN_TONES } from '../avatar/body';
import { derive } from '../game/derive';
import { Button, Chip, Field, Input, Segmented } from '../components/ui';
import { todayKey } from '../game/dates';
import { sfx } from '../sfx/sounds';

export function AppearanceEditor({
  skin,
  hairStyle,
  hairColor,
  onChange,
}: {
  skin: number;
  hairStyle: number;
  hairColor: number;
  onChange: (p: { skin?: number; hairStyle?: number; hairColor?: number }) => void;
}) {
  return (
    <div className="appearance">
      <div className="field-label">Skin</div>
      <div className="swatches">
        {SKIN_TONES.map((c, i) => (
          <button key={c} type="button" className={`swatch-btn ${i === skin ? 'swatch-active' : ''}`} style={{ background: c }} onClick={() => onChange({ skin: i })} aria-label={`Skin ${i + 1}`} />
        ))}
      </div>
      <div className="field-label">Hair</div>
      <div className="chips">
        {HAIR_STYLES.map((h, i) => (
          <Chip key={h} active={i === hairStyle} onClick={() => onChange({ hairStyle: i })}>
            {h}
          </Chip>
        ))}
      </div>
      <div className="swatches">
        {HAIR_COLORS.map((c, i) => (
          <button key={c} type="button" className={`swatch-btn ${i === hairColor ? 'swatch-active' : ''}`} style={{ background: c }} onClick={() => onChange({ hairColor: i })} aria-label={`Hair colour ${i + 1}`} />
        ))}
      </div>
    </div>
  );
}

export function Onboarding() {
  const setProfile = useStore((s) => s.setProfile);
  const settings = useStore((s) => s.settings);
  const updateSettings = useStore((s) => s.updateSettings);
  const [name, setName] = useState('');
  const [skin, setSkin] = useState(1);
  const [hairStyle, setHairStyle] = useState(0);
  const [hairColor, setHairColor] = useState(0);
  const [step, setStep] = useState(0);
  const blank = useMemo(() => derive({ sessions: [], claims: [], weeklyGoal: 3, today: todayKey() }), []);
  const profile = { name: name || 'Hero', skin, hairStyle, hairColor, createdAt: 0 };

  return (
    <div className="onboarding">
      <div className="onboarding-hero">
        <div className="pixel-font brand">TINY TITAN</div>
        <HeroScene state={blank} profile={profile} loadout={DEFAULT_LOADOUT} activePet={null} scene={false} className="onboarding-avatar" />
      </div>
      {step === 0 && (
        <div className="onboarding-card">
          <h1>Every titan starts tiny.</h1>
          <p className="muted">
            Log your lifts, climbs, runs and rides (or sync Strava) and watch this scrawny little hero turn into an absolute unit. Gear, pets and quests along the way.
          </p>
          <Field label="What should we call your hero?">
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Jake" maxLength={20} autoFocus />
          </Field>
          <Button size="lg" onClick={() => { sfx.tap(); setStep(1); }} disabled={!name.trim()}>
            Next →
          </Button>
        </div>
      )}
      {step === 1 && (
        <div className="onboarding-card">
          <h1>Make it yours.</h1>
          <AppearanceEditor
            skin={skin}
            hairStyle={hairStyle}
            hairColor={hairColor}
            onChange={(p) => {
              if (p.skin !== undefined) setSkin(p.skin);
              if (p.hairStyle !== undefined) setHairStyle(p.hairStyle);
              if (p.hairColor !== undefined) setHairColor(p.hairColor);
            }}
          />
          <div className="row gap">
            <Button variant="ghost" onClick={() => setStep(0)}>
              ← Back
            </Button>
            <Button size="lg" onClick={() => { sfx.tap(); setStep(2); }}>
              Next →
            </Button>
          </div>
        </div>
      )}
      {step === 2 && (
        <div className="onboarding-card">
          <h1>Units &amp; goals.</h1>
          <Field label="Weight">
            <Segmented value={settings.weightUnit} options={[{ value: 'kg', label: 'kg' }, { value: 'lb', label: 'lb' }]} onChange={(v) => updateSettings({ weightUnit: v })} />
          </Field>
          <Field label="Distance">
            <Segmented value={settings.distanceUnit} options={[{ value: 'km', label: 'km' }, { value: 'mi', label: 'miles' }]} onChange={(v) => updateSettings({ distanceUnit: v })} />
          </Field>
          <Field label="Weekly goal (sessions per week to keep your streak alive)">
            <Segmented
              value={String(settings.weeklyGoal)}
              options={[2, 3, 4, 5, 6].map((n) => ({ value: String(n), label: String(n) }))}
              onChange={(v) => updateSettings({ weeklyGoal: Number(v) })}
            />
          </Field>
          <div className="row gap">
            <Button variant="ghost" onClick={() => setStep(1)}>
              ← Back
            </Button>
            <Button
              size="lg"
              variant="good"
              onClick={() => {
                sfx.levelUp();
                setProfile({ name: name.trim(), skin, hairStyle, hairColor, createdAt: Date.now() });
              }}
            >
              Start my journey 🚀
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
