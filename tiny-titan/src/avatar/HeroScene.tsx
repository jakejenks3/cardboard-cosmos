import { useEffect, useRef, useState } from 'react';
import { Pix } from './pixel';
import { drawHero, HERO_W, HERO_H, type BodyInput, type Visuals } from './body';
import { drawScene, SCENE_W, SCENE_H, HERO_X, HERO_Y, FLOOR_Y } from './scene';
import { drawPet } from './petSprites';
import type { Loadout, Profile, Slot } from '../game/types';
import { ITEM_BY_ID } from '../game/items';
import type { PlayerState } from '../game/state';

export interface HeroSceneProps {
  state: PlayerState;
  profile: Profile;
  loadout: Loadout;
  activePet: string | null;
  /** Show the home-gym background; otherwise transparent hero only. */
  scene?: boolean;
  happy?: boolean;
  /** Force a pose (otherwise tap-to-flex). */
  pose?: 'idle' | 'flex';
  /** Animation on/off (static render for lists). */
  animate?: boolean;
  className?: string;
  /** Override levels (used by the preview page). */
  levelsOverride?: { hero: number; lift: number; climb: number; run: number; ride: number };
  onTap?: () => void;
}

export function visualsFromLoadout(loadout: Loadout, state: PlayerState): Visuals {
  const v: Visuals = {};
  for (const [slot, id] of Object.entries(loadout)) {
    if (!id || !state.items[id]) continue;
    const item = ITEM_BY_ID[id];
    if (item) v[slot as Slot] = item.visual;
  }
  return v;
}

const FRAME_MS = 170;

export function HeroScene(props: HeroSceneProps) {
  const { state, profile, loadout, activePet, scene = true, happy = false, animate = true, levelsOverride } = props;
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [tapFlexUntil, setTapFlexUntil] = useState(0);
  const frameRef = useRef(0);
  const blinkRef = useRef(false);

  const bufW = scene ? SCENE_W : HERO_W;
  const bufH = scene ? SCENE_H : HERO_H;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    let raf = 0;
    let last = 0;
    let alive = true;

    const render = () => {
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      const cssW = canvas.clientWidth || bufW * 4;
      const dpr = Math.min(3, window.devicePixelRatio || 1);
      const scale = Math.max(1, Math.floor((cssW * dpr) / bufW));
      const pw = bufW * scale;
      const ph = bufH * scale;
      if (canvas.width !== pw || canvas.height !== ph) {
        canvas.width = pw;
        canvas.height = ph;
      }
      ctx.clearRect(0, 0, pw, ph);
      const frame = frameRef.current;
      const now = Date.now();
      const pose = props.pose ?? (now < tapFlexUntil ? 'flex' : 'idle');
      const lv = levelsOverride ?? {
        hero: state.levels.hero.level,
        lift: state.levels.lift.level,
        climb: state.levels.climb.level,
        run: state.levels.run.level,
        ride: state.levels.ride.level,
      };
      const input: BodyInput = {
        heroLevel: lv.hero,
        liftLevel: lv.lift,
        climbLevel: lv.climb,
        runLevel: lv.run,
        rideLevel: lv.ride,
        skin: profile.skin,
        hairStyle: profile.hairStyle,
        hairColor: profile.hairColor,
        pose,
        frame,
        blink: blinkRef.current,
        happy: happy || pose === 'flex',
      };
      const visuals = visualsFromLoadout(loadout, state);
      const hero = new Pix(HERO_W, HERO_H);
      drawHero(hero, input, { visuals });

      if (scene) {
        const buf = new Pix(SCENE_W, SCENE_H);
        drawScene(buf, {
          stage: state.stage,
          liftLevel: lv.lift,
          climbLevel: lv.climb,
          runLevel: lv.run,
          rideLevel: lv.ride,
          achievements: Object.keys(state.achievements).length,
          sessions: state.totals.sessions,
          hour: new Date().getHours(),
          frame,
        });
        buf.blit(hero, HERO_X, HERO_Y);
        if (activePet && state.pets[activePet]) drawPet(buf, activePet, 70, FLOOR_Y, frame);
        buf.paint(ctx, scale);
      } else {
        hero.paint(ctx, scale);
      }
    };

    const tick = (t: number) => {
      if (!alive) return;
      if (t - last >= FRAME_MS) {
        last = t;
        frameRef.current++;
        // blink roughly every ~3s for one frame
        blinkRef.current = frameRef.current % 18 === 0;
        render();
      }
      raf = requestAnimationFrame(tick);
    };

    render();
    if (animate) raf = requestAnimationFrame(tick);
    const onResize = () => render();
    window.addEventListener('resize', onResize);
    return () => {
      alive = false;
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', onResize);
    };
  }, [state, profile, loadout, activePet, scene, happy, animate, props.pose, tapFlexUntil, levelsOverride, bufW, bufH]);

  return (
    <canvas
      ref={canvasRef}
      className={`hero-canvas ${props.className ?? ''}`}
      style={{ aspectRatio: `${bufW} / ${bufH}` }}
      onClick={() => {
        setTapFlexUntil(Date.now() + 1600);
        props.onTap?.();
      }}
      aria-label="Your hero"
      role="img"
    />
  );
}
