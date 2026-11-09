# Tiny Titan

A pixel-RPG fitness tracker. Log your **lifting** (reps × weight), **bouldering** (V-grades), **running** and **cycling** (distance, time, elevation) — or sync them from **Strava** — and watch a scrawny little hero grow into an absolute unit. Every session earns XP, damages the boss you are fighting, moves a dozen progress bars, and can drop loot. Check in with your **weight, body fat and front / side / back photos** to see the real you change alongside the pixel one.

Everything in the game — levels, body shape, items, pets, trophies, the campaign — is **derived by replaying your log**, so editing or deleting an entry simply recomputes your hero. Nothing is ever lost or double counted.

## What's in it

**Your hero**
- **Procedural pixel avatar.** Lifting widens shoulders and arms, climbing grows forearms, cycling builds thighs, running leans you out and builds calves; hero level scales everything. Six body stages (Scrawny → Budding → Fit → Athletic → Jacked → Titanic). Tap to flex.
- **A home gym that fills up** with a rack, climbing holds, a hangboard, a wall-mounted bike, a treadmill, trophies and string lights as you level.
- **75 pieces of gear** across 9 slots and **15 companions**, most with XP or loot-luck perks. Some drop randomly (with pity), most unlock from milestones, six are trophies from zone bosses.

**The game**
- **Campaign.** 24 bosses across 6 zones, from the Snooze Button to *The Old You*. Every XP you earn deals 1 damage; train a boss's weakness for ×1.5; overkill carries over. Zone bosses drop unique gear. After the summit: endless Echoes.
- **4 disciplines + 1 hero level**, balanced to ~1,000 XP per solid hour in any sport, with **mastery ranks** (Novice → Apprentice → … → Legend) per discipline.
- **114 trophies** in four tiers, every one with a live progress bar — including bodyweight-relative strength goals (1× BW bench, 2× BW deadlift…) once you log your weight.
- **"Almost there"** on the home screen: the three goals you are closest to, across trophies, gear, companions, ranks and evolutions.
- **Daily + weekly quests**, weekly streaks (you pick the goal), PR bonuses.
- **A results reel** after every session: XP ticking up, bars wrapping on level-up, the boss taking the hit, loot by rarity, new companions, rank-ups, body evolutions — with tiny synthesized sound effects.
- **Your companion talks.** One contextual nudge per visit ("Iron Golem is nearly down — only 13 HP left!").

**Looking back**
- **Then vs now**: Day-1 you next to today's you, with your first and best lifts, grades and distances.
- **Story**: a dated timeline of every level, boss, trophy, record, drop and check-in.
- **Stats**: weekly XP by discipline, training heatmap, est.-1RM progression per lift, send pyramid, lifetime totals "in perspective" (elephants lifted, El Capitans climbed).

**Body tracking**
- Log **weight**, **body fat %** and **front / side / back progress photos** in one check-in.
- Weight and body-fat trends, lean mass, and a **then-and-now photo comparison** per angle between any two dates, plus a gallery.
- A weekly check-in earns a little XP (consistency only — the game never rewards a number on the scale).
- **Photos are private**: stored on your device (IndexedDB), downscaled first, and mirrored only to *your own* server if you run one. Backups can include them.

**Plumbing**
- Works offline with no server: data lives in the browser (export / import JSON backups, photos included).
- The included Node server adds **Strava import**, cross-device sync and photo mirroring, with an optional password.
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

Set `APP_URL` to your public URL and the Strava callback domain to match. Deploys to Render, Railway, Fly.io or any Node 20+ host; persist the data directory (`server/data`, or point `DATA_DIR` at a volume) so tokens, the synced state and photos survive restarts.

> **Set `APP_PASSWORD` on anything public.** The server holds your training log, body measurements and progress photos. With `APP_PASSWORD` set, every API route needs a login cookie; the app asks for the password once under **Settings → Server**. Without it the server is open, which is only appropriate on localhost or a private network.

**Static-only hosting** (GitHub Pages, Netlify, …): deploy `dist/` as-is. Everything works except Strava and cross-device sync. To point a static build at a server on the same site, set `VITE_API_BASE` at build time.

## Scripts

| Command | What |
|---|---|
| `npm run dev` | Vite + API server with reload |
| `npm run build` | Production client build |
| `npm start` | Run the API server (serves `dist/` if present) |
| `npm test` | Unit tests (XP, levels, PRs, drops, streaks, quests, campaign, body check-ins, goals) |
| `npm run typecheck` | Type-check client and server |

Visit `/?preview=avatar` in dev to see every body stage, boss, item and companion on one page.

## How the numbers work

| Discipline | Base XP | PR bonus |
|---|---|---|
| Lifting | volume ÷ 10 (kg) + 1/weighted rep + 3/bodyweight rep + 5/set | +150 per exercise with a new best weight or est. 1RM (max 3) |
| Climbing | per climb by grade (VB 12 … V4 78 … V7 185 … V10 400 … V17 1550); flash ×1.3, attempt ×0.35 | +200 new max grade, +100 new max flash |
| Running | 100/km + 0.8/m elevation | +150 longest run |
| Cycling | 32/km + 0.8/m elevation | +150 longest ride |
| Any | +2/min of duration (up to 3 h) | |

- **Hero level** needs `400 + 90·L + 6·L²` XP per level; discipline levels use a gentler curve. Hero XP also comes from trophies, quests, boss kills and weekly check-ins.
- **Boss damage** = session XP, ×1.5 if the session's discipline is the boss's weakness. Boss HP runs from 400 (Snooze Button) to 40,000 (The Old You); defeating one pays 10–15% of its HP as hero XP.
- **Weekly check-in**: 60 XP for a weight, 20 for body fat, 15 per photo angle — each paid once per Monday-to-Sunday week.
- **Perks** from gear and companions are snapshotted onto each session when it is logged, so swapping gear later never rewrites history.

## Project layout

```
src/game      pure game engine — xp, derive (replay), campaign, achievements/goals, items, pets, quests,
              diff (results reel), nextup, chatter, funfacts. Fully unit-tested.
src/avatar    procedural pixel-art body, equipment templates, pet + boss sprites, home-gym scene
src/screens   Home · Adventure (campaign / quests / trophies) · Log (+ body check-in) · Results ·
              Journey (stats / body / story / log) · Armory · Settings · Onboarding
src/store     zustand store (localStorage), IndexedDB photo store, derived-state hooks, server sync
server        Express: Strava OAuth + import, state mirror, photo store, optional password gate
```
