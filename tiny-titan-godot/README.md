# Tiny Titan (Godot 4.7)

A pixel-RPG fitness tracker. Log your **lifting** (sets × reps × weight), **bouldering** (V-grades),
**running** and **cycling** (distance, time, elevation), and watch a scrawny little hero grow into an
absolute unit. Every session earns XP, damages the boss you are fighting, moves a dozen progress bars
and can drop loot. Check in with your **weight, body fat and front / side / back photos** to see the
real you change alongside the pixel one.

This is the Godot version: a normal Godot project with no server, no account and no internet
connection. You open it, press Play, and log what you did today.

## Open it in Godot

1. Open **Godot 4.7**.
2. In the Project Manager click **Import**, browse to this folder and pick `project.godot`.
3. Click **Import & Edit**. The first time, Godot spends a few seconds scanning the scripts.
4. Press **F5** (or the Play button, top right).

That's it. Each day: open the project and press F5, or export it once
(**Project → Export…**) to get a double-clickable app for your computer.

## Your data

Everything you log is saved on your computer in Godot's user-data folder for this game
(**Project → Open User Data Folder** shows it):

| File | What |
|---|---|
| `save.json` | Your profile, settings, every session and check-in |
| `save.bak.json` | The previous save, used automatically if `save.json` is ever damaged |
| `backups/` | One dated copy per day you open the game (the newest 14 are kept) |
| `photos/` | Your progress photos (downscaled copies; the originals are never touched) |

**Settings → Export backup** writes a single file with everything, photos included, and **Import
backup** restores it. The format is the same as the web version's backup, so a log started there can
be brought across.

Levels, gear, pets, trophies and the campaign are never stored: they are **derived by replaying your
log**. Editing or deleting an old entry simply recomputes your hero, and nothing can be lost or
counted twice.

## Log from your phone

The **phone inbox** lets you jot workouts down on your phone in plain shorthand and import them the
next time you open the game, so you do not have to remember everything until you are back at the
computer. The game reads a note you share by link (or a file in a synced folder), shows what it
understood, and imports only what you confirm. Lines it cannot read are listed, never dropped, and
the same note can be checked again and again: entries already imported are recognised and skipped.

Set it up once with a Google Doc:

1. On your phone, create a Google Doc (say "Workouts").
2. **Share → General access → Anyone with the link** (Viewer).
3. Copy the link.
4. In the game, open **Settings → Phone inbox** and paste the link.
5. Press **Check now** (or just start the game: it checks quietly a moment after launch, and the
   Hero tab shows "N new entries from your phone" when there is something to review).

Write one thing per line, with a date line to start a day (`nov 14`, `11/14`, `yesterday`, `sat` …;
lines before any date count as today):

```
nov 14
bench 3x5 @ 80
squat 5,5,4 @ 100
pull-up 3x8
v4 flash x2, v5 send
tr 5.10a flash, 5.11b
hang 20mm 10s x6, one arm 15mm 7s x3 +10
run 5.2km 27:30 +80m
ride 40km 1h35
weight 82.4  bf 18
```

Weights are in your weight unit unless you write `kg` / `lb`; distances in your distance unit unless
you write `km` / `mi` / `k`. One set per line works too (`backsquat x5 135`, then `backsquat x5 195`:
same exercise, sets add up). V grades are boulders; `5.xx` grades (`5.10a`, `tr 5.9`, `lead 5.11c`)
are roped routes; `hang 20mm 10s x6` logs dead hangs (edge, seconds, how many; add `one arm`,
`+10` for added weight or `-20` for assistance, `jug` for a bar). `title: Push day`, `note: felt strong` and `duration 70min` attach to the
session above them; `---` starts a second session on the same day; `#` starts a comment.

**Progress pictures** go in the same doc: write a line like `progress pics 11/15` (any date line
works) and put up to three pictures under it, front, side and back in that order. The game shows
them on the review sheet and imports them as that day's photo check-in, downscaled and stored in
its own data folder, so once they are in the game you can delete them from the doc and your phone.

- **Google Form instead:** make a form with one paragraph question and share its responses sheet by
  link (Anyone with the link); paste the sheet's link. Every response is a row, dated automatically.
- **Synced file instead:** put a plain-text file in a folder synced by Drive / Dropbox / iCloud /
  Syncthing and paste its path (for example `~/Dropbox/workouts.txt`) instead of a link.
- **No link at all:** Settings → Phone inbox → **Paste text…** reads text you paste.

Privacy: the link only has to be readable, but anyone who has the link can read that note, so keep it
to workout notes.

## What's in it

- **A hero that changes shape with your training.** Lifting widens shoulders and arms, climbing grows
  forearms, cycling builds thighs, running leans you out. Six body stages from Scrawny to Titanic.
- **A boss campaign.** 24 bosses across 6 zones, from the Snooze Button to *The Old You*. Every XP is
  1 damage; training a boss's weakness hits ×1.5.
- **148 trophies, 75 pieces of gear, 15 companions**, daily and weekly quests, weekly streaks, PRs,
  mastery ranks per discipline, and an "Almost there" list of the goals you are closest to.
- **Fast logging.** Pick an exercise and last time's sets come up already filled in; − / + (hold to
  repeat) on every number; one tap to repeat a previous workout.
- **Looking back.** Then-vs-now, a dated story of every milestone, weekly XP, training heatmap,
  strength progression, send pyramid, body-weight trend and photo comparison.

## How the numbers work

| Discipline | Base XP | PR bonus |
|---|---|---|
| Lifting | volume ÷ 10 (kg) + 1/weighted rep + 3/bodyweight rep + 5/set | +150 per exercise with a new best weight or est. 1RM (max 3) |
| Climbing | per climb by grade (VB 12 … V4 78 … V7 185 … V10 400 … V17 1550); flash ×1.3, attempt ×0.35. Routes: the boulder grade they are worth (5.10a ≈ V1, 5.12a ≈ V5) ×1.5. Hangs: 1/s on a 20 mm edge, ×(20 ÷ edge mm), ×2.5 one arm, ×2 per +20 kg | +200 new max grade, +100 new max flash, +200 new max route, +100 heaviest hang |
| Running | 100/km + 0.8/m elevation | +150 longest run |
| Cycling | 32/km + 0.8/m elevation | +150 longest ride |
| Any | +2/min of duration (up to 3 h) | |

Hero level needs `400 + 90·L + 6·L²` XP per level. Boss HP runs from 400 to 40,000. A weekly check-in
pays 60 XP for a weight, 20 for body fat and 15 per photo angle, once per week: the game rewards
showing up, never a number on the scale.

## Project layout

```
project.godot   main.tscn / main.gd   the app shell: screen column, tab bar, overlays
app/            autoloads: App (save file, derived state, navigation) and Sfx (synthesized sounds)
game/           the rules, pure GDScript with no scene code: xp, derive (replay), campaign,
                achievements, items, pets, quests, diff (results reel), formatting
avatar/         procedural pixel art: hero body, gear, pets, bosses, the home gym
ui/             palette, toolkit, widgets, icons, pixel font, and one script per screen
tests/          parity tests against the original TypeScript engine, and scripted walkthroughs
```

Every screen is built in code (there is one tiny scene, `main.tscn`), so to change a screen you edit
its script in `ui/screens/`.

### Look and themes

The interface is pixel art drawn in code, like the rest of the game: panels, raised buttons that sink
when pressed, bars and inputs come from `ui/pix_box.gd`, and every colour comes from `ui/pal.gd`.
**Settings → Theme** switches between Arcade, Ember, Forest and Slate; to add your own, add an entry
to `Pal.THEMES`.

### Window size

The game is a phone-shaped column. It opens at 440 × 900, grows on high-DPI screens and shrinks to
fit short ones; resize or maximise the window freely (the column stays centred and the screens scroll).

### Tests

The rules and the pixel art were ported from a TypeScript version and are checked against it:
`tests/parity/*.json` hold inputs and the original engine's outputs, and these scripts replay them.

```
godot --headless --path . --import
godot --headless --path . --script res://tests/parity_derive.gd
godot --headless --path . --script res://tests/parity_misc.gd
godot --headless --path . --script res://tests/parity_art.gd
godot --headless --path . --script res://tests/quick_log_test.gd   # the phone-inbox parser
```

`tests/shots/*.gd` are scripted walkthroughs that drive the real screens and save screenshots, for
example a whole first day (onboarding, logging a session through the form, the results reel, every
tab, a body check-in):

```
TINY_TITAN_DATA=/tmp/tt-data TINY_TITAN_SHOTS=/tmp/tt-shots \
  godot --path . res://tests/shots.tscn -- res://tests/shots/e2e.gd fresh
```

`TINY_TITAN_DATA` points the game at a throwaway save folder, so tests never touch your real data.
