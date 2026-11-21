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

- `game/`    Rules engine: XP, levels, PRs, 24-boss campaign, 187 trophies, 124 items,
             16 pets, quests, streaks, loot. Everything is derived by replaying the log,
             never stored. Ported from a TypeScript version and locked to it by fixtures
             in `tests/parity/`. Don't change rules or numbers unless asked; if you do,
             the parity tests fail by design.
- `avatar/`  Procedural pixel art (hero body from training levels, gear, pets, bosses,
             home gym). Pixel-exact parity test.
- `app/`     `app.gd` (autoload App: save file, derived state, all commands, navigation),
             `sfx.gd` (synthesized sounds), `inbox.gd` (phone inbox).
- `ui/`      `pal.gd` (colours as theme variables: Arcade, Ember, Forest, Slate),
             `pix_box.gd` (pixel-art 9-patch panels/buttons), `kit.gd` (toolkit),
             `widgets/`, `parts.gd` (shared rows/tiles), `icons.gd` (86 pixel icons, no
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
- Lift library (added 2026-11-15, evening; rebuilt 2026-11-20 around movements, see "Movement
  and variation" below): Journey → Lifts. `game/lift_library.gd` holds the catalog (`MOVES`:
  101 movements, 339 variations, rows of [name, part, usual, only, also-works, tip, variations,
  other names]) and the pure logic: `catalog()`, `stats(sessions)` (per full lift name),
  `rows(sessions)` (one row per MOVEMENT, `done` = the variations logged, `st` merged; unknown
  logged movements appear as "Your own"), `variation_list(row)`, `query` filters/sorts,
  `rep_bests`. `ui/screens/journey_lifts.gd` is the screen and the movement's page (variation
  chips at the top switch it); typing in the search box refills only the list. "Add to today's
  workout" sets `App.pending_exercise`, which `LogLiftEditor.build` consumes. Tests:
  `tests/lift_library_test.gd`, walkthrough `tests/shots/lifts.gd` (year data).
- Movement and variation (2026-11-20, the user's rule): the exercise NAME is the movement,
  the VARIATION is the position or equipment. A lift is stored as ONE name, "Movement -
  Variation" (`LiftNames.SEP` = " - "), or the movement alone ("Pull-up", "Calf Raise"). The
  rules engine is untouched: it keys PRs by that name, so each variation has its own records
  and parity does not move. Screens split it (`LiftNames.split`): the movement big, the
  variation as a chip (`SessionView.variation_tag`, `Kit.clip_fit`).
  - `game/lift_names.gd` (`LiftNames`, pure): `VOCAB` (variation words: positions, grips,
    band colours, equipment), `canon(words, move)` writes a variation one way (positions
    first, then colours, then equipment: "Single arm cable", "Incline dumbbell"). A movement's
    `only` equipment is never said (Lat Pulldown is a cable, Pull-up bodyweight, Face Pull cable
    + rope); its `usual` equipment is the variation when nothing is written ("squat" is Squat -
    Barbell) and is dropped next to another word ("front squat" is Squat - Front). `ALIASES`:
    names that hide a variation (pec deck, skull crusher, slant board).
  - `resolve(typed, own)` -> {name, move, variation, kind, closest}: "exact" (one of the
    player's lifts, an alias, or a movement found by its words), "match" (found through one
    word several movements share, "row" / "curl" / "fly", or a typo: the review asks), "new"
    (`plain`: their words in title case without plural endings, equipment words moved to the
    variation; `closest` when one movement is clearly nearest). `QuickLog.pick_exercise` and
    `App.absorb_pt` (names typed in the Log tab) go through it, so a lift is filed the same way
    from the note, a table row or the Log tab.
  - `migrate(old, specials)` turns an old-style name into this form; it was run once on the
    user's real save (2026-11-20, backup in Documents\Tiny Titan backups), with the user's own
    shorthand passed as `specials` (never committed). The demo data uses the new names.
  - The Log tab's exercise keys show movement + variation; its search matches every typed
    word. The review's "pick another lift" lists every movement with its variations.
  - Tests: `tests/lift_names_test.gd` (catalog sanity, every variation reads back as itself,
    the ways of writing a lift, migration), `tests/lift_library_test.gd`.
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
- Also 2026-11-17, two things the phone note could not read:
  - A decimal typed without its zero (`.75 mile walk 15lb vest`, `@ .5`): `QuickLog.lead_zeros`,
    applied in `_line` BELOW the title / note lines, so a note keeps its words and an entry
    imported earlier keeps its key (the key is made from the normalised lines).
  - A number inside an exercise name (`neck 4 way - 3x20@10`, `1 arm row 3x10 @ 40`). A lifting
    line is still cut at its first number; only when that does not read, `_later_cut` tries a
    later start, and takes it only when the words before it are clearly a name: an exercise
    already logged (`_knows_exercise`), a name cut off by a dash or a colon, or a number followed
    by a word from `NAME_NUMBER_WORDS` ("way", "arm", "degree"...) or a short form names use
    (`LiftMatch.WORDS`: "1UE"). Amounts (`AMOUNT_WORDS`: `bench 3 sets of 5 at 80`,
    `bench 80 - 3x5`) stay problem lines, with the same message.
  - The review sheet says WHY a line was not read (`InboxSheet._unread_card`: the line and its
    reason, which carries an example); the reason used to sit in a tooltip.
- Lift names that are not exact (added 2026-11-17): `game/lift_match.gd` (`LiftMatch`, pure).
  A typed lift name is compared by its WORDS: order, dashes, commas, plurals, short forms
  (`WORDS`: db, 1UE, pulley...), words written apart (`PAIRS`, `TAILS`: "push down") and one
  typo in a word of five letters or more do not count; a word that only says a library lift's
  equipment or body part is not held against it ("chest fly - cable" is Cable Fly), other
  equipment costs (`WRONG_GEAR`). `find(typed, known)` scores candidates: `SAME` (0.95) and up
  is the same lift, `CLOSE` (0.5) and up is offered as closest.
  - `QuickLog.pick_exercise(typed, ctx)` returns {key, typed, name, kind, closest}: a name
    already decided, else `LiftNames.resolve` (since 2026-11-20; see "Movement and
    variation"). Needs `opts.own` (lifts actually logged) and `opts.names` (decisions).
    `LiftMatch` now only reads words (`tokens`, `words`, `key`, `typo`, `alike`) and ranks
    names for the picker (`find(typed, names)`).
  - A lift entry carries `names` (the picks that are not exact). The review sheet shows a row
    per name (`InboxSheet._name_row`): what was written, what it is taken as, and three keys:
    yes / no (a lift of its own) / another (`_pick_other`: nearest lifts, search, or a typed
    name). An answer is stored at once in `saved.inbox.names` = {`LiftMatch.key(typed)`: lift
    name, "" = its own lift} (`PhoneInbox.name_lift`), the note is read again
    (`PhoneInbox.reparse`, nothing is fetched) and the sheet is rebuilt in place (`_fill` /
    `_refill`: ticks and moved dates are kept, the answered row stays put). A row imported as
    shown is remembered too (`import_entries`), so the same words are asked about once.
    Settings -> Phone inbox shows the count with a Forget key. A decision never changes an
    entry's key (keys are made from the typed lines).
  - `Sheet` (ui/widgets/sheet.gd): the slide-in now goes through `_layout` (`_rise`). Before,
    a sheet whose wrapped text settled after opening (the review sheet) was left hanging above
    the bottom edge, and jumped down the first time its content changed.
  - Tests: `tests/lift_match_test.gd`, more in `tests/quick_log_test.gd`, walkthrough
    `tests/shots/names.gd` (`new` data).
- What you did, trends, physical therapy (added 2026-11-19):
  - `ui/screens/session_view.gd` (`SessionView`). `lift_rows(data, opts)` lists a lift session
    exercise by exercise: name, sets, and a tag from `LiftTrend.compare` (NEW, PR, +2.5 lb,
    -4 reps, same); a row opens the lift's page. The phone note's review uses it for a lift
    entry (no longer one paragraph; `opts.pending`, `opts.skip_id` for an edited day), and so
    does `SessionView.open(session)`: the detail sheet a session row now opens
    (`Parts.session_row`; the Edit key is inside the sheet).
  - `game/lift_trend.gd` (`LiftTrend`, pure): `day`, `by_day`, `series(history, "weight" |
    "reps" | "volume" | "e1rm" | "hold")`, `per_week`, `weekly_rate`, `compare`, `change`.
    `ui/charts/week_bars.gd` (`WeekBars`, and `WeekBars.Dots` for one week) draws days done
    per week.
  - The lift page (`JourneyLifts.open_detail`, or `open_named(name, opts)` from any list of
    exercises): the movement, its variation chips (only the ones done and "+N more" when
    there are many), three view keys (see "Three views of a lift" below), the physical
    therapy card, "How to do it", the Add key.
  - Physical therapy: `game/pt.gd` (`Pt`). Which lifts are PT is STORED, not derived:
    `saved.pt` = {normalized lift name: {name, perWeek}} (`App.pt()`, `set_pt`, `set_pt_goal`).
    A lift gets there by "(PT)" in front of an exercise in the phone note (`Pt.untag` in
    `QuickLog._parse_lift`; the exercise carries a transient `pt: true`) or typed in the Log
    tab, both through `App.absorb_pt` (called by `commit_sessions` / `update_session`: the tag
    comes off the name, the lift is marked, the flag is dropped), or by the switch on the
    lift's page. Names: the tag is part of the decision's key (`pick_exercise(typed, ctx, pt)`:
    "ptsquat"), a lift the player already does and tags for the first time is a "match" (the
    review asks once), and "no" keeps it apart as "PT <name>" (`_apart_name`).
    `Pt.status(sessions, marks, today)` gives a row per PT lift: this week's days (Monday
    first), days left, state done / on / behind, eight weeks against the goal, the run of
    weeks on target; a mark on another name of a library lift covers the lift (`Pt.mark_of`).
    UI: `ui/screens/pt_view.gd` (`PtView.card()` on the Hero tab under the bounty, only when a
    lift is marked; `PtView.open()` the sheet with a goal per lift, 3 days a week to start
    with), PT badges in exercise rows and the lift library, colour `Pal.PT`, icon `pt`.
    Being PT changes no XP and no rule, so parity is untouched.
  - Tests: `tests/lift_trend_test.gd` (trends and `Pt`), more in `tests/quick_log_test.gd`,
    walkthrough `tests/shots/detail.gd` (year data).
- Holds and tables in the phone note (added 2026-11-19):
  - A hold (a stretch): a set with `holdSec` (seconds each rep is held) and no weight:
    `{reps, weightKg: 0, holdSec}`. In the note seconds are written `30"` (also `30''`, `30s`,
    `30 sec`), where a weight would be or as the set itself: `3x1@30"`, `3@30"`, `3x30"`,
    `30" x3` (`QuickLog.parse_sets` turns them into a `30sec` token: `hold_token`,
    `_hold_item`). The rules engine does not know holds: a hold counts as the rep it is
    stored as, so no XP number changed and parity is untouched. What does know them:
    `LiftTrend` (`is_hold`, `hold_text`, `held`, `day().holdSec` / `holdTotal`, series
    "hold", `compare().sec`), `LiftHistory.describe_sets` ("3 x 30 s hold"),
    `LiftLibrary.stats` (keeps `holdSec`), the lift page (a Hold trend and "s longest hold"
    where the weight would be) and `LogLiftEditor.draft_from_sets` / `sets_from_draft`, which
    carry the seconds through an edit (the editor has no field for them yet).
  - Google's export writes some characters as codes (`3x30&rdquo;` for the curly quote a
    phone types after 30): `PhoneInbox.decode_entities` (named, decimal and hex codes) runs at
    the end of `html_to_text`. An undecoded code is why a line can look fine in the doc and
    still be "not read": print `App.inbox.last_text` (the `realdoc` walkthrough does).
  - A table: `PhoneInbox.html_to_text` turns every table of the Google Doc into one line per
    row, `| cell | cell |` (`_tables_to_rows`). `QuickLog._table_line` reads those: a row
    naming its columns is a header (`table_role`: date, exercise, variation, pt, weight, hold,
    sets, reps, "Set 1"..., note), the rows under it become ordinary lines (`table_row`:
    `<exercise> - <variation> - <reps> @ <weight>`, a date cell as a date line, a PT cell
    as "(PT)", a note cell as `note:`), so names, PT and holds work as in typed lines. Rows
    that are empty are skipped; a row that cannot be read is a problem with its reason; a
    table without a header is read row by row as a line. Typed `| a | b |` lines work too.
    A row with one filled cell is that cell typed as a line (a date that starts a day),
    unless it is just words in the Exercise column (`_lone_exercise`: an exercise with no
    sets yet, reported as "no sets or reps in this row").
  - Table rows as they get filled in mid-workout (2026-11-20): a row with numbers and no
    exercise goes on with the exercise of the row above (`ctx.table_last`; a date row or a
    header ends it), so a second weight is its own row; words in the Weight cell ("blue
    band") are the resistance: they join the variation and the sets get `@ bw`, so no
    "no weight given" warning. `table_row` writes `name ¦ sets` (`TABLE_MARK`): the lift
    parser cuts the name there instead of at the first number (a "1 arm" variation is
    safe), and `_line` sends such a line straight to the lift parser (`_lift_line`), so
    "rope pushdown" or "dead hang" in the Exercise column is never read as a climb or a hang.
    Verified 2026-11-19 on the real doc: it now begins with a `#` hint line (skipped, like
    every `#` line) and a table headed Exercise, Variation, Weight, Set 1 to Set 4 with empty
    rows; the typed lines under it read exactly as before (same entries, same keys).
- Three views of a lift (added 2026-11-20, after "still not great how it shows exercise
  progress"; modelled on Hevy's "previous" column, Fitbod's "estimated strength" and time
  ranges, PR crowns on charts, heatmap calendars): `ui/screens/lift_views.gd` (`LiftViews`).
  Three keys under the variation chips; only the part under them is rebuilt when one is
  picked; `LiftViews.last_view` remembers the last one (from a list of exercises the page
  opens on Compare: `opts.view`). `ctx` = {sheet, lift, history (newest first, the note's
  sets among them), cur, st, wu, goal}; `opts.session_id` makes a logged session `cur`.
  - Compare: a versus card (last time or the best day, chips to switch, against this time,
    "IN YOUR NOTE" for the note's sets), a verdict banner (record gold, up green, down
    orange, same grey), the sets side by side with a change pill each (`LiftTrend.pairs`),
    three total tiles, the records beaten (`LiftTrend.records`) or the best still to beat,
    and a "Next time" target (`LiftTrend.next_target`, double progression: +1 rep on the
    weakest working set until all match, then +2.5 kg / 5 lb). No target for a PT lift.
  - Progress: a metric picker (Top set, Strength = estimated 1RM, Reps, Moved; holds: Hold,
    Reps; bodyweight: Best set, Reps in all), range chips 1M / 3M / 1Y / All (only those
    shorter than the history), a headline (change, sessions, per month), `ProgressChart`
    (`ui/charts/progress_chart.gd`: line, the day's work as bars, gold squares on new bests
    from `LiftTrend.record_points` over ALL the history, a crown on the best, the note's
    point green), the records tiles (`JourneyLifts._records`) and `RepLadder`
    (`LiftTrend.rep_ladder`: heaviest weight for 1, 2-3... reps).
  - Logbook: `LiftCalendar` (`LiftTrend.calendar`: 8 to 16 weeks depending on how long the
    lift has been done, bigger days brighter, new bests ringed gold), WeekBars with the goal
    for a PT lift, then sessions month by month as `SetBlocks` (a block per set, height =
    weight against the lift's best, reps on top), 10 then "Show all".
  - `SparkBars` (`ui/charts/spark_bars.gd`): the last 7 times + this time as small bars,
    beside every exercise in `SessionView.lift_rows` (the review: green, gold for a record)
    and every movement in Journey -> Lifts.
  - Tests: more in `tests/lift_trend_test.gd`; walkthrough `tests/shots/progress.gd` (year
    data; it logs a lighter day and a day of 8s first, since the demo bench only goes up).

- Missions, the day's plan, morning goals on the phone (added 2026-11-20, after "there's
  always a time task but we never input workout time"):
  - `game/missions.gd` (`Missions`, pure) replaces the ported quests IN THE GAME;
    `game/quests.gd` stays only for the parity test. `day_plan(sessions, today, marks)` is
    worked out from the log BEFORE today (so it does not move while the day is logged):
    `likely_lifts` (done on this weekday before, or due by the lift's usual gap; a lift with
    a weekday habit is not "due" on other days), the day's body area (`GROUP`, "Back day"),
    a movement of that area never done (`STAPLES` first, three to pick from by the date),
    PT still to do this week, `likely_others` (climb, run, ride, misc).
  - `daily(today, data, state, claims)`: show up, "Beat it" on the two likeliest non-PT
    lifts (done when today's sets compare "up" or set a record; `aim` = next_target),
    try something new, physical therapy, the likely climb / run / ride, read; "XP hunter"
    only on a day with fewer than three. `weekly(...)`: days, set a record, explore (a new
    movement), PT on target, the main other activity of the last four weeks, XP, body
    check-in. Ids `t:<date>:<slug>` / `tw:<week>:<slug>`. NO mission is about minutes.
    Missions use the Quests dictionary shape (+ `lift`, `aim`, `why`), so `Parts.quest_list`,
    claims, coins and the replay are unchanged (a claim stores its own XP).
  - `App.quests()` = {daily, weekly, yesterday (done, unclaimed: workouts are often imported
    the day after)}, `App.plan()`, `App.mission_data()`; both cached until the data changes.
  - `ui/screens/today_view.gd` (`TodayView.card()`): first on the Hero tab, then "From
    yesterday" and "Missions". A lift row opens its page on Compare; a mission with `lift`
    does too (`Parts.quest_list`). The Adventure tab shows missions with their words.
  - Morning message: `app/morning_alert.gd` (`MorningAlert`) + `tools/morning.gd`. Windows Task
    Scheduler runs `godot --headless --path <project> --script res://tools/morning.gd` daily
    (Settings -> Morning goals: switch, time, Send a test, Copy topic; `settings.morning` =
    {on, topic, time, server}). The tool reads save.json itself (never writes; `App._ready`
    returns at once when the command line has `res://tools/morning.gd`) and posts
    `Missions.morning_text` to ntfy (https://ntfy.sh/<topic>; the phone runs the ntfy app).
    `-- --dry-run` prints, `-- --test` sends even when off; after noon it sends nothing.
    Verified 2026-11-20 against a local stand-in server and a copy of the real save; the
    task itself was NOT created (the switch is the user's to flip; `schedule_command` was
    checked by building its objects without `Register-ScheduledTask`).
  - Tests: `tests/missions_test.gd`; walkthrough `tests/shots/today.gd` (year data).

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

- Equipped view and hover cards (added 2026-11-16, evening): the Armory's hero card is a
  paper doll: the hero on a `Stage` (`ui/widgets/stage.gd`) with a slot tile on each side for
  the nine gear slots and the companion (`ArmoryScreen._slot_tile`, `DOLL_LEFT` / `DOLL_RIGHT`).
  A slot shows the item by itself (`Art.item_icon_pix`: the mannequin drawn with and without
  the item, the difference cropped; back gear is drawn alone, hands with the forearm, an aura
  round a dark figure). The Armory opens on the "Equipped" tab: one row per slot with where it
  came from and what it does, and an "Active effects" card (`ArmoryScreen.effect_sources`).
  `HoverCard.attach(control, builder, ring, beside)` (`ui/widgets/hover_card.gd`) shows a
  floating card while the mouse is over a control; the builders are `ArmoryDetail.hover_item`
  / `hover_pet` / `hover_empty`, and `ArmoryDetail.item_origin` / `pet_origin` say how and when
  something was obtained (from `state.items[id]` = {at, how, sessionId} and `saved.purchases`).
  Gear tiles of a slot's grid zoom in on that part of the hero (`ArmoryScreen.slot_view`).
  `PixFit` (`ui/widgets/pix_fit.gd`) shows any texture at the largest whole-number scale that
  fits a box. Walkthrough: `tests/shots/armory.gd`.
- Reading (added 2026-11-16, evening): `game/reading.gd` (`Reading`). The log is
  `saved.reading` = [{id, date, pages, createdAt, inbox?}], ONE entry per day; each is a step
  of the replay (`Derive._apply_reading`). It is NOT a session: no boss damage, no loot, no
  workout streak. It pays 2 hero XP a page for the first 100 pages of a day (and coins through
  `Wallet.tally`, `coins.by.reading`), has its own level (`Reading.level`, in pages), a day
  streak, and counts days with both reading and a workout. `state.reading` only exists once
  pages were logged (parity untouched). 16 `read_*` trophies in a new group
  (`Achievements.MORE_GROUPS`; the UI uses `Achievements.groups()`), the owl companion
  (`Pets`, pinned for parity with `Pets.restrict_to`), two pieces of gear (`read_glasses`,
  `read_satchel`). `App.add_reading` / `set_reading` / `import_reading`; unlocks are announced
  as toasts (`App.announce_unlocks`), there is no results reel. UI: `ui/screens/reading_view.gd`
  (`ReadingView.card()` on the Hero tab with +1 / +5 / +10 / +25, `ReadingView.open()` the sheet
  with the bookshelf, the day editor, two weeks of bars and the daily goal
  `settings.readingGoal`), a key on the Log tab, a card in Journey -> Stats, a tile in the
  recap. Phone note: `read 20 pages` / `20 pages` (`QuickLog._parse_reading`, entry kind
  "reading"); an edited line changes the day by the difference (`inbox` map on the day's
  entry). Tests: `tests/reading_test.gd`, walkthrough `tests/shots/reading.gd` (year data).
- The look (2026-11-16, evening): `Pix.classic` picks between the original port (true: what
  `tests/parity_art.gd` sets and compares with the TypeScript renders) and the game's own look
  (false, the default): the reworked face (`HeroBody._draw_head_lit`), `Pix.light()` (parts lit
  from the top left), `Pix.bevel()` (pets, bosses), `Pix.outline_tinted()`, the fuller gym
  (`GymScene._draw_scene_lit`). New drawing code must keep the classic branch pixel-identical.
  Everything is shown at WHOLE-number scales: `Icons.rect(icon, px)` snaps to 16 / 32 / 48 and
  never stretches, `PetView` / `BossView` / `HeroView` / `PixFit` floor their scale. Motion:
  `ui/widgets/fx.gd` (`Fx.shine`, `embers`, `twinkle`, `flicker`), `Kit.floater` ("+20 XP"
  rising from a key), `Kit.purse_pill` (coins count up), glints on thick bars (`Bar.glint`),
  the pixel `Ring`, pets that hop, bosses that float over a shadow, the sky's clouds / stars
  (`Backdrop.SkyFx`), the tab icon bounce and tab fade in `main.gd`.
- Every walkthrough screenshot is also a layout check: `ShotHelper.snap` prints a CHECK FAIL
  when anything is wider than the column it scrolls in (a non-clipped long label once pushed
  the Adventure page off the right edge: use `Kit.clip`, not `Kit.muted`, in a row).

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
godot --headless --path . --script res://tests/reading_test.gd
godot --headless --path . --script res://tests/lift_match_test.gd
godot --headless --path . --script res://tests/lift_names_test.gd
godot --headless --path . --script res://tests/lift_library_test.gd
godot --headless --path . --script res://tests/lift_trend_test.gd
godot --headless --path . --script res://tests/missions_test.gd
```

After adding a script with a `class_name`, run the `--import` line first: until then other
scripts cannot see the new class and every run fails with "Identifier not declared".

Walkthroughs that drive the real UI and save screenshots (set `TINY_TITAN_DATA` and
`TINY_TITAN_SHOTS` to temp folders first):

```
godot --path . res://tests/shots.tscn -- res://tests/shots/e2e.gd fresh
```

Scenarios: e2e, anchor, home, log, adventure, results, journey, armory, shop, bounty, settings, inbox,
themes, climb_more (routes and hangboard), pictures (screenshots in the note, `new` data, Windows only),
misc (the Miscellaneous section and vest walks), reading (pages read, year data),
names (lift names that are not exact: the review's yes / no / another, `new` data),
detail (a session's detail, a lift's trends, physical therapy, year data),
progress (a lift's three views: Compare, Progress, Logbook, and the review's history bars, year data),
today (the Today card, missions, claiming, yesterday's missions, the Morning goals card, year data),
realdoc (the real Google Doc, see below). Demo data: fresh, new, week, year.

To check the phone inbox against the user's real Google Doc, set `TINY_TITAN_INBOX_URL`
to the doc link and run the `realdoc` scenario with `new` data: it prints the text the
game received, every entry it understood, and saves a screenshot of the review sheet.
Verified 2026-11-15: the link, fetch and export all work; the doc was still empty then.

`--check-only` does not work for scripts that use the App/Sfx autoloads; a real run is
the check.

## Known rough edges

- A hold's seconds cannot be typed in the Log tab's lift editor: a hold made in the phone
  note shows there as reps without weight (its seconds are kept when the session is saved).
- A hold earns XP as the reps it is stored as (a 30 second stretch is one rep): the rules
  have no timed sets.
- Switching "Physical therapy" on a lift's page does not redraw the view above it (the
  Logbook's goal bars and the Compare target change the next time the page opens).
- "Next time" is a rule of thumb (one more rep, then more weight), not a programme; the
  weight step is 2.5 kg or 5 lb whatever the lift.
- The day's plan is a guess from weekdays and gaps; it does not know a programme or a
  split the player has in mind. A lift done once in six weeks on this weekday counts.
- The morning message only goes out when the computer is on or asleep (woken by the task)
  at that time; a run after noon sends nothing. It runs the Godot editor's exe headless, so
  moving Godot or the project folder needs the switch turned off and on again.
- Lift names are filed when a lift is imported or saved, not afterwards: changing `MOVES`,
  `VOCAB` or `ALIASES` does not rename what is already in a save. To bring a save in line,
  run `LiftNames.migrate` over it on a copy (as was done 2026-11-20) and check XP is unchanged.
- A "no" in the review keeps a lift as a movement of its own ("Jefferson Curl"); there is no
  screen yet to rename a lift or move it under another movement afterwards.
- A note line whose date header was used before is checked against what was imported under
  it (`PhoneInbox.split_entries` / `_resolve_updates`): the same day changed is an edit that
  REPLACES the session it came from. The user clears the note between visits and may write
  the same date again for another workout, so for lifts `PhoneInbox.same_workout` decides:
  an edit keeps the exercises, adds to them or drops some (by `LiftMatch.key`); a workout
  sharing few is a second session, and the review says "A second lift on this day"
  (`SECOND_LIFT`, also shown for any new lift on a day that already has one). Found
  2026-11-20 on a copy of the real save, before it happened: a new table under 11/19 would
  have replaced that day's earlier lift. Climbs under a reused date still count as an edit.
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
