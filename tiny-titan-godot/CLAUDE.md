# Tiny Titan — notes for Claude sessions

Godot 4.7 game (GDScript). A pixel-RPG fitness tracker: the user logs lifting, bouldering,
runs, rides and body check-ins; a pixel hero levels up, fights bosses, earns trophies, gear
and pets. Read README.md first. It was built in a long cloud session on Linux; this folder
is the Windows handoff.

## About the user and how to work

- Not a programmer. Give short, plain updates and small steps. Don't ask lots of
  questions: make a sensible call, do it, say what you chose.
- Limited usage. Work economically; no fan-out of parallel agents unless the job needs it.
- Test before saying something works, and say plainly what you couldn't test.
- When you change how something looks, show a screenshot.
- What matters: it should look and feel like a satisfying game (vivid, colour-coded,
  things react when clicked), NOT a wall of small text and not one colour washed over
  everything. Logging a workout must be fast, and clicking "+ Set" or "Add" several
  times must never move the screen under the cursor.

## What exists (all working as of the handoff)

- `game/`    Rules engine: XP, levels, PRs, 24-boss campaign, 171 trophies, 122 items,
             15 pets, quests, streaks, loot. Everything is derived by replaying the log,
             never stored. Ported from a TypeScript version and locked to it by fixtures
             in `tests/parity/`. Don't change rules or numbers unless asked; if you do,
             the parity tests fail by design.
- `avatar/`  Procedural pixel art (hero body from training levels, gear, pets, bosses,
             home gym). Pixel-exact parity test.
- `app/`     `app.gd` (autoload App: save file, derived state, all commands, navigation),
             `sfx.gd` (synthesized sounds), `inbox.gd` (phone inbox).
- `ui/`      `pal.gd` (colours as theme variables: Arcade, Ember, Forest, Slate),
             `pix_box.gd` (pixel-art 9-patch panels/buttons), `kit.gd` (toolkit),
             `widgets/`, `parts.gd` (shared rows/tiles), `icons.gd` (85 pixel icons, no
             emoji anywhere), `pixel_font.gd`, `backdrop.gd` (pixel sky),
             `ui_screen.gd` (base class), `screens/` (one script per screen).
- `main.gd`  The shell: column, tab bar, overlays, theme switching.
- Phone inbox: the user jots workouts in shorthand in a Google Doc on their phone; the
  game reads the doc (Settings -> Phone inbox), shows what it understood, imports what
  they confirm. Parser: `game/quick_log.gd`. A Google Doc is fetched as its zip export
  (HTML + `images/`), not plain text: `PhoneInbox.html_to_text` turns each picture into a
  `photo images/imageN.jpg` line, the parser puts up to three under a date into that day's
  body check-in (`data.photoRefs`), the review sheet shows them as thumbnails, and
  `import_entries` stores them as front/side/back photos via `App.import_photo_bytes`.
  Pictures stay in memory until import; the zip is a temp file in the data folder.
- Every screen is built in code (no .tscn per screen).
- Climb sessions (added 2026-11-15, after the handoff) can also hold roped routes and
  hangboard hangs, both inside the climb discipline so no new discipline was added:
  a route is a `climbs` entry with `style: "rope"` and `yds: "5.10a"` (its `grade` is
  the boulder grade it is worth, from `Xp.YDS_TO_V`); hangs live in an optional
  `hangs` array of `{edgeMm, sec, arms, addKg, count}`. New stats / PR / totals keys
  stay null until first used, because the parity tests compare dictionaries by key
  set and null counts as absent. Walkthrough: `tests/shots/climb_more.gd`.
- 15 "card hand" climbing trophies (ids `hand_*`: pair, straight, flush, blackjack…)
  were added 2026-11-15 on top of the ported 114. They read `s.hands`, filled by
  `Derive._deal_hands`. The parity test replays with only the fixture's 114 trophies
  (`Achievements.restrict_to`) and drops `hands` before comparing, so adding more
  trophies later means: add them, and they are simply outside parity. Unit test:
  `tests/hands_test.gd`.
- Added 2026-11-15 (afternoon): phone-note days edited after import now update the
  session/check-in they came from (sessions carry `inboxKey`; `PhoneInbox._resolve_updates`,
  entry field `replaces`); a Home card says "safe to clear it" once the whole note is imported
  (`PhoneInbox.note_all_in`); a "This week" card on Home (XP vs last week, sessions per
  discipline, PRs); hangboard records per edge (`prs.hangEdge`, `prs.hangOneArm`,
  `prs.longestHangSec`, 7 `hang_*` trophies, Journey chips); photo milestones
  (`s.body.photoSpanDays` / `photoMonths`, 5 `body_*` trophies, a "One month on" reel moment
  from `Diff.PHOTO_MILESTONES`). Parity strips `body.*` photo keys via dotted
  `POST_PORT_STATE_KEYS`. Unit test: `tests/extras_test.gd`.
- Lift library (added 2026-11-15, evening): Journey → Lifts. `game/lift_library.gd` holds the
  catalog (about 170 lifts as rows of name, part, equipment, family, also-works, tip, other
  names) and the pure logic: `rows(sessions)` joins the catalog with the log (other names
  such as "heel raise" merge into one lift; unknown logged lifts appear as "Your own"),
  `query` filters/sorts, `rep_bests`, `variations`. `ui/screens/journey_lifts.gd` is the
  screen and detail sheet; typing in the search box refills only the list. "Add to today's
  workout" sets `App.pending_exercise`, which `LogLiftEditor.build` consumes. Tests:
  `tests/lift_library_test.gd`, walkthrough `tests/shots/lifts.gd` (year data).
- 19 more chase trophies (ids `quirk_*`: Five by Five, Ladder, Pyramid, Streak Week,
  On the Nose, Commuter, Friday the 13th…) read `s.quirks`, filled by
  `Derive._deal_quirks`; also dropped by parity. Unit test: `tests/quirks_test.gd`.
- Weekly bounty, coins, shop, recaps (added 2026-11-15, night):
  - `game/bounty.gd`: a small boss every Monday-week. HP = 90% of the average session XP of
    the four weeks before (floor 500); the week's session XP is the damage (x1.5 for its
    weak discipline); beating it pays coins, 150% of its HP "crushes" it. It is a pure
    function of the log, run at the end of `Derive.derive` (`Bounty.settle` fills
    `s.weekly`); wins are NOT in `s.chronicle` (the Story page joins `Bounty.chronicle`).
    Screens: `ui/screens/bounty_view.gd` (card on Hero and Adventure, detail sheet), reel
    card type `bounty`. 18 monsters, three new boss sprites (mimic, bat, eye).
  - `game/wallet.gd`: coins are counted from the log (`Wallet.tally` fills `s.coins`;
    1 coin per 10 XP, plus bounties, bosses, trophies, quests). Purchases ARE stored:
    `saved.purchases` = [{id, itemId, cost, at, date}], replayed as steps
    (`Derive._apply_purchase`, item `how: "shop"`). `App.buy_item(id)`. Shop items are
    catalog items with `unlock.kind == "shop"`; one is 30% off each week (`Wallet.deal_id`).
    Screen: Armory -> Shop (`ui/screens/armory.gd`, buy sheet in `armory_detail.gd`);
    unowned shop gear is drawn on the hero with `Art.item_tryon_texture`.
  - 47 more pieces of gear (catalog 122): 33 in the shop, 8 for bounty wins (`bounty_*`),
    6 for hangboard / routes / photos / lift variety / card hands / Friday the 13th. New
    drawing kinds are listed at the top of `game/items.gd`; all are new `match` branches in
    `avatar/equipment.gd`, so the ported art is untouched. 11 more trophies (`bounty_*`,
    `shop_*`, `items_80`): catalog 171.
  - Parity: `Items.restrict_to(ids)` pins the 75 ported items the way
    `Achievements.restrict_to` pins the trophies, and `weekly` / `coins` are in
    `POST_PORT_STATE_KEYS`. The reel's new events come from `Diff.diff_extras`, called by
    `App`, so `diff_states` / `diff_bulk` / `diff_body` still match the fixtures.
  - `game/recap.gd` + `ui/screens/recap_sheet.gd`: a week or month as one poster (Journey ->
    Stats -> Recaps, the Hero tab's "This week" card, and a "recap is ready" card at the
    start of a week / month). "Save picture" renders the poster off screen to a PNG in
    Pictures/Tiny Titan (`App.recap_dir()`; inside the data folder during tests).
  - Shared widgets moved into `ui/kit.gd`: `pill`, `icon_chip`, `coin_pill`, `big_number`,
    `passthrough`, `hp_bar`, `switch` (`ui/widgets/pix_switch.gd`). Icons `coin`, `bag`.
  - Tests: `tests/bounty_test.gd` (bounty, coins, shop, new art), walkthroughs
    `tests/shots/shop.gd` (year and week data) and `tests/shots/bounty.gd` (year).

- Screenshots in the phone note (added 2026-11-16): a picture in the Google Doc is read, not
  just stored. `app/ocr.gd` (`Ocr`) has the text reader that is part of Windows
  (Windows.Media.Ocr) read the pictures through a PowerShell script it writes into
  `<data>/reading/` (removed afterwards; no window, nothing leaves the machine; other systems:
  `Ocr.available()` is false and every picture stays a progress photo). `PhoneInbox` starts it
  after unzipping (`_read_pictures`), polls it in `_process`, and keeps what was found per
  picture (md5 of its bytes) in `<data>/inbox_pictures.json` with the day it was first seen,
  so a picture is read once. `game/shot_reader.gd` (`ShotReader`, pure) turns the words and
  their positions into a reading: `run` / `ride` (labels Distance, Moving Time, Elevation
  Gain... with the number under or beside each), `body` (weight, body fat, the rest as a
  note), `text` (a screenshot it cannot use: shown as a "Picture left out" card with the
  reason, e.g. a walk) or `photo`. `QuickLog` gets the readings as `opts.shots` and turns a
  `photo images/x.png` line with a reading into that entry (`_shot_session`, `_shot_body`,
  `shot_date`). Dates: printed on the picture > the note's date line > the day first seen.
  Keys: a picture's entry is keyed by what it says (`shot_tag`), so a different picture is
  never an "edit" of an imported one. Entries carry `shots` (picture names) and `extras`
  for the review sheet. Tests: `tests/shot_reader_test.gd` (made-up pages laid out like real
  screenshots), walkthrough `tests/shots/pictures.gd` (`new` data; draws fake screenshots and
  runs them through the real Windows reader). The real doc was checked with `realdoc`
  (`TINY_TITAN_UNITS=lb,mi` shows pounds and miles).
- Also 2026-11-16: an undated typed line changed on a LATER day is a new entry, not an edit
  of the old one (`PhoneInbox._resolve_updates` compares the dates).
- Also 2026-11-16: one climb in the note can hold several results (`QuickLog._climb_item`).
  Every result word is its own tally with the number beside it: `v3 send 3 attempts` is
  1 send + 3 attempts (an attempt is a try that did not go, as in the Log tab), `v4 5 attempts`
  is attempts only, `v3 3rd go` / `send in 3` is a send on that go (N-1 attempts), `no send`
  makes it all attempts, and `3 attempts` with no grade after a comma belongs to the climb
  before it. What it cannot tell apart stays a problem line, never a guess.
- Also 2026-11-16: a vest walk may be written as a sentence (`2.5 mile walk with 30 lb vest`).
  `QuickLog._misc_kind` accepts a misc activity's words anywhere in a line that has a distance
  and no `NxM` sets, so `weighted vest walking lunge 3x10` stays a lift.
- Miscellaneous activities (added 2026-11-16): `game/misc.gd` (`Misc`) is a catalog of
  activities outside the four disciplines; for now one row, `vest_walk` (weighted vest walk).
  A misc activity is a normal session in `saved.sessions` with `discipline: "misc"`
  (`TT.MISC`), a `kind`, `distanceM`, `elevationM`, `loadKg`. "misc" is NOT in
  `TT.DISCIPLINES` (it has no level, rank, quest or boss weakness) but it IS in
  `TT.SESSION_KINDS` and `TT.DISCIPLINE_META` (name "Misc", colour `Pal.MISC`, icons `misc`
  and `vest`). It goes through `Derive._apply_session` like any session (hero XP, boss and
  bounty damage, coins, loot, weekly goal, streak) with three guards there: no `s.xp[disc]`,
  no `byDiscipline[disc]`, no quirks; its totals and records are `state.misc`
  (`Misc.record`), a key that only exists once a misc session was logged, so parity is
  untouched. XP: `Misc.xp_parts` (per km and per metre climbed, times `load_mult`). Adding
  an activity = one more row in `Misc.KINDS` + its id in `Misc.ORDER` (fields "distance",
  "elevation", "load"; `words` / `loadWord` for the phone note): the Log picker's
  Miscellaneous section, the form (`LogSessionForm` with `kind`; `App.open_log("misc:<kind>")`),
  the history row, the Stats card, the reel and the recap all read the catalog. Phone note:
  `vest walk 3km 40:00 10kg`, a `vest 10kg` line under one, and a walk screenshot
  (`ShotReader` kind "walk") all become vest walks; with no weight written the last one
  logged is used (`opts.lastLoadKg`). Tests: `tests/misc_test.gd`, walkthrough
  `tests/shots/misc.gd` (year data).

## Rules that matter in this codebase

- A session's discipline may be "misc": never index a four-key table with
  `session.discipline` (use `.get`, or `TT.SESSION_KINDS` for lists and charts), and never
  let an `else:` mean "it must be a ride".

- Never use `:=`. Make one operand a float when dividing. Optional dictionary fields
  need `.get()`. Stored callables are invoked with `.call()`.
- Never show a number with `str(float)`; use `Fmt.*`, `Xp.fmt_int` or `TTUtil.num_str`.
- Colours come from `Pal` and change with the theme: never copy one into a const, never
  hard-code a hex colour for a surface or text.
- No emoji on screen: use `Icons.rect(name, px)`.
- Any Control showing a PixBox style needs `texture_filter = NEAREST`; anything drawing a
  photo needs LINEAR.
- Screens extend `UiScreen` and build in `build()`. The base class keeps the scroll
  position and keeps the control under the mouse in place across rebuilds;
  `tests/shots/anchor.gd` proves it and finds buttons by their text.
- The user's real save lives in Godot's user-data folder for "Tiny Titan", outside this
  project. NEVER run tests against it: set the `TINY_TITAN_DATA` environment variable to
  a throwaway folder for every test run. The walkthrough runner (`tests/shots.tscn`) REPLACES
  the whole save with demo data when it starts. When the user asks for something to be put
  into the real save: back that folder up, do the work on a copy of it with a runner that
  loads no demo data, check the result, and only then copy the changed files back (the game
  must not be running).

## How to check your work

Godot 4.7 on this machine (use the console build so output is captured):

```
C:\Users\jdjen\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe
```

```
godot --headless --path . --import
godot --headless --path . --script res://tests/parity_derive.gd
godot --headless --path . --script res://tests/parity_misc.gd
godot --headless --path . --script res://tests/parity_art.gd
godot --headless --path . --script res://tests/quick_log_test.gd
godot --headless --path . --script res://tests/shot_reader_test.gd
godot --headless --path . --script res://tests/misc_test.gd
```

Walkthroughs that drive the real UI and save screenshots (set `TINY_TITAN_DATA` and
`TINY_TITAN_SHOTS` to temp folders first):

```
godot --path . res://tests/shots.tscn -- res://tests/shots/e2e.gd fresh
```

Scenarios: e2e, anchor, home, log, adventure, results, journey, armory, shop, bounty, settings, inbox,
themes, climb_more (routes and hangboard), pictures (screenshots in the note, `new` data, Windows only),
misc (the Miscellaneous section and vest walks),
realdoc (the real Google Doc, see below). Demo data: fresh, new, week, year.

To check the phone inbox against the user's real Google Doc, set `TINY_TITAN_INBOX_URL`
to the doc link and run the `realdoc` scenario with `new` data: it prints the text the
game received, every entry it understood, and saves a screenshot of the review sheet.
Verified 2026-11-15: the link, fetch and export all work; the doc was still empty then.

`--check-only` does not work for scripts that use the App/Sfx autoloads; a real run is
the check.

## Known rough edges

- Editing a day in the phone note after it was imported updates that session only when it
  carries `inboxKey` (imports from 2026-11-15 on); older imports still get the "adds it
  again" warning and are left unticked.
- In the Armory, clicking owned gear or a pet equips it at once; the small "i" opens
  details.
- A walkthrough that hits a script error still prints its checks: read the log for
  `ERROR` as well as for failed checks.
- Logging an old session for an earlier week changes the bounty HP of the weeks after it
  (the HP is built from the four weeks before), so a past bounty can flip. By design:
  the bounties are a pure function of the log.
- Strava import (the API) is deliberately left out for now; Strava SCREENSHOTS in the phone
  note are read (see above).
- Misc activities have no trophies, gear or pets of their own yet, and a walk screenshot
  is always taken as a weighted vest walk (there is no plain walk).
- Screenshot reading needs Windows. Only runs, rides, walks and weigh-ins are read; the layouts it
  was tried on are Strava's activity page and one smart-scale app (the user's own). A new
  layout that fails shows up as "Picture left out": get the words with `realdoc`
  (`App.inbox._readings`) and extend the label tables in `game/shot_reader.gd`.
- A picture that only says "Today" is dated by the day the game first saw it, which is wrong
  if the game is opened days later (the review sheet has arrows to move it).

## Git

- Source of truth is GitHub: `jakejenks3/cardboard-cosmos`, branch
  `claude/strava-fitness-gamification-9nu1t4`, draft PR #1, folder `tiny-titan-godot/`.
  The repo root is a different game: never touch it.
- This local folder is an unzipped copy, not a git clone (checked 2026-11-15). Ask the
  user before pushing anything.
- Commits are made in a clone at `C:\Users\jdjen\Documents\cardboard-cosmos` (same branch):
  copy the changed files into its `tiny-titan-godot/` folder (keep the clone's own
  `project.godot`; skip `.godot/` and `shots-today/`) and commit there.
