# Tiny Titan

A pixel-RPG fitness tracker. Log your **lifting** (reps × weight), **bouldering** (V-grades), **running** and **cycling** (distance, time, elevation) — or sync them from **Strava** — and watch a scrawny little hero grow into an absolute unit. Earn XP, level up four disciplines, unlock gear and pets, hit PRs, clear daily/weekly quests and keep your streak alive.

Everything in the game — levels, body shape, items, pets, achievements — is **derived by replaying your session log**, so editing or deleting a session simply recomputes your hero. No grind is ever lost or double counted.

## Features

- **Procedural pixel avatar.** Lifting widens shoulders and arms, climbing grows forearms, cycling builds thighs, running leans you out and builds calves; the overall hero level scales everything. Six body stages (Scrawny → Budding → Fit → Athletic → Jacked → Titanic). Tap the hero to flex.
- **Home gym that fills up.** Dumbbells, a squat rack, climbing holds and a hangboard, a bike on the wall, a treadmill, trophies, plants and string lights appear as you level.
- **4 disciplines, 1 hero level.** ~1,000 XP for a solid hour of effort in any sport, so nothing feels like the "wrong" workout. PR bonuses for new lifts, grades, distances, paces.
- **59 pieces of equipment** across 9 slots (head, face, body, hands, legs, feet, back, accessory, aura) — some drop randomly after sessions (with pity so dry streaks end), most unlock from milestones ("send a V5", "lift 50,000 kg lifetime", "run a half marathon"). Rare+ gear carries XP perks.
- **13 pets** with their own perks: a gym slime, a bulldog, a gecko, a mountain goat, a greyhound, a falcon, a tortoise for streaks, a phoenix, a baby dragon…
- **68 achievements**, daily + weekly quests with claimable XP, weekly streaks (you set the goal), PR board, send pyramid, weekly XP chart and a training heatmap.
- **Satisfying results reel** after every session: XP ticking up, bars filling and wrapping on level-up, confetti, loot reveals by rarity, new pets, body evolutions — with tiny synthesized sound effects (mutable).
- **Works offline / without a server.** Data lives in your browser (export/import JSON backups). Run the included Node server to add Strava import and cross-device sync.
- Installable PWA, mobile-first.

## Quick start

```bash
cd tiny-titan
npm install
npm run dev
```

Open <http://localhost:5173>. That runs the Vite dev server **and** the API server (port 8787). You can log workouts immediately; Strava needs the keys below.

### Connect Strava

1. Create an app at <https://www.strava.com/settings/api>.
   - **Authorization Callback Domain:** `localhost` for development, or your deployed hostname (no `https://`, no path).
2. Copy `.env.example` to `.env` and fill in:
   ```
   STRAVA_CLIENT_ID=12345
   STRAVA_CLIENT_SECRET=…
   APP_URL=http://localhost:5173
   ```
3. Restart `npm run dev`, open **Settings ⚙️ → Connect Strava**.

The first sync imports the last 12 months of activities (as one big results reel). After that, the app syncs quietly when opened and on **Sync now**.

| Strava sport type | Becomes |
|---|---|
| Run, TrailRun, VirtualRun | Running session (distance, time, elevation) |
| Ride, GravelRide, MountainBikeRide, EBikeRide, VirtualRide… | Cycling session |
| WeightTraining, Workout, Crossfit | Lifting session (duration only — open it and add your sets to earn full XP) |
| RockClimbing | Climbing session (duration only — add your climbs) |

Tokens are stored in `server/data/strava.json` (git-ignored). The server is single-user by design.

## Production

```bash
npm run build   # builds the client into dist/
npm start       # serves dist/ + the API on $PORT (default 8787)
```

Set `APP_URL` to your public URL (e.g. `https://titan.example.com`) and the Strava callback domain to match. Deploys fine to Render, Railway, Fly.io or any Node 20+ host; persist the `server/data` directory (or point `DATA_DIR` at a volume) so tokens and the synced state survive restarts.

**Static-only hosting** (GitHub Pages, Netlify, …): deploy `dist/` as-is. Everything works except Strava and cross-device sync, which need the server. To point a static build at a server elsewhere, set `VITE_API_BASE=https://api.example.com` at build time.

## Scripts

| Command | What |
|---|---|
| `npm run dev` | Vite + API server with reload |
| `npm run build` | Production client build |
| `npm start` | Run the API server (serves `dist/` if present) |
| `npm test` | Engine unit tests (XP, levels, PRs, drops, streaks, quests) |
| `npm run typecheck` | Type-check client and server |

Visit `/?preview=avatar` in dev to see every body stage, item and pet on one page.

## How XP works

| Discipline | Base XP | PR bonus |
|---|---|---|
| Lifting | volume ÷ 10 (kg) + 1/weighted rep + 3/bodyweight rep + 5/set | +150 per exercise with a new best weight or est. 1RM (max 3) |
| Climbing | per climb by grade (VB 12 … V4 78 … V7 185 … V10 400 … V17 1550); flash ×1.3, attempt ×0.35 | +200 new max grade, +100 new max flash |
| Running | 100/km + 0.8/m elevation | +150 longest run |
| Cycling | 32/km + 0.8/m elevation | +150 longest ride |
| Any | +2/min of duration (up to 3 h) | |

Hero level needs `400 + 90·L + 6·L²` XP per level (≈ level 10 after ~10 sessions, level 25 after ~3 months at 4 sessions/week). Discipline levels use a gentler curve. Equipment/pet perks are snapshotted onto each session when it is logged, so swapping gear later never rewrites history.

## Project layout

```
src/game      pure game engine (types, xp, derive, achievements, items, pets, quests, diff) — fully unit-tested
src/avatar    procedural pixel-art body, equipment templates, pet sprites, home-gym scene, canvas component
src/screens   Home · Log · Results · Journey · Armory · Quests · Settings · Onboarding
src/store     zustand store (localStorage), derived-state hooks, server sync
server        Express: Strava OAuth + activity import, state mirror, static hosting
```
