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
  - Where a lift was done is part of its variation (2026-11-21, "home cable is different than
    gym cable"): `VOCAB` has "home" (and "home gym") and "gym" as kind "place", written just
    before the equipment ("Chest Fly - Home cable", "Chest Fly - Gym cable", "Lat Pulldown -
    Single arm home"); `LiftMatch.STOP` no longer drops "home"; `LiftNames.plain` moves place
    words to the variation (`PLACE_WORDS`). A remembered name decision that only left the place
    out (made before) is worked out again (`QuickLog.pick_exercise`); one picked on purpose
    stays. Lifts logged before this keep their names ("Chest Fly - Cable").
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
    {on, topic, time ("00:00" by default, up to 11:30), server}). The tool reads save.json itself (never writes; `App._ready`
    returns at once when the command line has `res://tools/morning.gd`) and posts
    `Missions.morning_text` to ntfy (https://ntfy.sh/<topic>; the phone runs the ntfy app).
    `-- --dry-run` prints, `-- --test` sends even when off; after noon it sends nothing.
    Verified 2026-11-20 against a local stand-in server and a copy of the real save; the
    task itself was NOT created (the switch is the user's to flip; `schedule_command` was
    checked by building its objects without `Register-ScheduledTask`).
  - Tests: `tests/missions_test.gd`; walkthrough `tests/shots/today.gd` (year data).
  - Training split (2026-11-21, "I do a pull day, push day, then leg day, in that cycle"):
    `settings.split` (`Missions.SPLITS`: "auto" = none, "pull_push_legs", "push_pull_legs",
    "upper_lower"; Settings -> Training split). With a split, `Missions.day_kind` takes the
    kind of the last lift day before today (`kind_of_day`: the kind most of its working,
    non-PT exercises belong to; `kind_of(lift)` from the body part, face pulls and rear delts
    pull) and plans the next one in the cycle; only lifts of that kind are planned (forearms,
    core, stretches go with any day), "try something new" comes from that kind's staples.
    `settings.dayPick` = {date, kind}: the Today card's chips plan today as another kind
    (that date only; tapping the split's own kind drops it). Plan fields `split`, `cycle`,
    `kind`, `after`, `afterDate`, `picked`; `Missions.kind_why` ("Yesterday was a pull day").
    Rest, with or without a split: a non-PT lift done under `REST` (half) of its usual gap
    ago is not planned unless it has a weekday habit (2+ times on this weekday); before, one
    Saturday squat made a squat "due" two days after the last one. The user's save has
    "pull_push_legs" (set 2026-11-21, backup "2026-11-21 before training split").
  - The ways to do a goal (2026-11-21; a Gym / Home switch with home equipment was tried the
    same day and REMOVED: "I never asked to have separate gym and home exercises as a
    dichotomy... I want those variations to be how I used them"). `likely_lifts` plans a
    MOVEMENT (all its variations' dates together; `name` = the variation done last,
    `variations` the latest first; a PT lift stays on its own). `options_for(l, hist, avoid,
    marks)`: the lift, the other variations the player logged (all history), then one other
    movement of the same part and kind they have done and that is not in the day's plan;
    each with its own last sets and aim. The "Beat it" mission (`lift` = the first, "Or: ...",
    `ways`, id still from the planned name) is done by any way or ANY variation of the
    movement, beaten or done for the first time (`beat_any`). The Today row shows the others
    as chips; the morning message lists every way with its own aim ("  or ..."). Nothing is
    suggested from equipment the player has not used ("Try something new" aside).
    A planned lift is also done by a movement STANDING IN for it (`stands_in` / `same_of`: the
    same body part and kind, not itself a movement of the day's plan, `plan.moves`): cable
    tricep extensions tick the pushdown row.
  - Done boxes (2026-11-21, "hard to tell which ones have been completed"): every Today row
    ends in `TodayView._tick` (empty while to do, a green tick once done today; meta
    `done_tick`), the same for every colour; the card no longer turns a done lift green. "Try
    something new" ticks when its mission is done. The PT row and mission are about TODAY
    ("PHYSICAL THERAPY TODAY", done/needed today; mission "Do today: ..."). The Adventure tab
    says "Missions" (it said "Quests": the same thing).
- Clearing the note's table (2026-11-21, "takes a long time to manually clear each section"
  on mobile; "as long as it doesn't mess with the current workout I'm inputting"): the game
  only READS the doc, so `app/doc_clear.gd` (`DocClear`) holds a Google Apps Script
  (`SCRIPT`, with a token from `new_token`) the player pastes into the doc once and deploys
  as a web app ("Execute as me, anyone"; `/** @OnlyCurrentDoc */` keeps Google's consent to that
  one doc); its link and the token are `saved.inbox.clear` =
  {url, token, on} (Settings -> Phone inbox -> "Clear the table after import": switch,
  Set up sheet with Copy the script, the link, Test, Clear now). `PhoneInbox._tables`
  (`DocClear.table_rows` of the last export) + `clear_rows()` -> `DocClear.plan`: a table
  row goes when its line is in an imported entry's `raw` and in no entry not imported (the
  same text in both: neither); headers never; a date row only when its day is before today
  and every row under it is empty or going. Each row is sent as `table.row.hash` (md5 of
  `row_text`: filled cells, lower case, spaces collapsed, " | "); the script empties it only
  when its text there still hashes the same, so rows typed or changed since the note was
  read stay. `import_entries` ends with `_clear_after_import` (when on). GET, not POST
  (Apps Script answers a POST with a redirect). Not set up on the user's save: they do the
  Google part (authorising the script is theirs). Test: `tests/doc_clear_test.gd` (needs
  Node.js for the script part: `tests/doc_clear_stub.js` runs SCRIPT on a pretend doc).
- The day's plan in the note (2026-11-21): script VERSION 2 (`DocClear.SCRIPT_VERSION`; a ping
  says which; Settings' Test asks for an update when old) also writes plans (`writePlan`):
  a date row and a row per lift ([exercise, variation, weight]: `DocClear.plan_rows`, the
  weight to aim for in the player's unit; then the movement to try, then PT as "(PT) ...")
  under the table's last filled row, by its header's columns, rows added when short, never
  twice for a date. Every row it writes starts with `QuickLog.PLAN_MARK` ("▸"):
  `QuickLog._table_line` strips it and skips a marked row with no sets without a problem;
  `DocClear.row_line` strips it too (so a filled plan row clears like any other) and `plan`
  also clears marked rows never filled in (`_unfilled_plan`: only Exercise / Variation /
  Weight hold anything) once their day is over. `tools/morning.gd` writes the plan before
  the push when `saved.inbox.clear.plan` (default on) and adds "Today's plan is in your
  note"; Settings has the switch and "Write today's plan now" (`PhoneInbox.write_plan_now`).
  The user must paste the new script and deploy a new version (same link) for it to work.
- Muscle map (2026-11-21): `game/recovery.gd` (`Recovery.heat(sessions, today)`): per body part
  a heat 1 = worked hard today, fading over RECOVER_BIG (3) / RECOVER_SMALL (2) days; a lift
  warms its part fully per FULL_SETS (4) sets and the library's "also works" parts by half;
  climbs / runs / rides warm parts (`OTHER`). `HeroBody.draw_muscle_map` (the bare figure,
  parts tinted amber to red by `fig.owner` names: pec, delt, upper / peak, fore, thigh,
  calf, neck, torso = core in the middle and back at the sides), `Art.muscle_texture`
  (cached by heat). `ui/screens/recovery_view.gd` (`RecoveryView.row()` on the Today card
  when the player lifts, `open()` the sheet). Test: `tests/recovery_test.gd`.
- Perfect day (2026-11-21): `Missions.day_boxes(plan, sessions, today)` = the Today card's boxes,
  ticked the same way (`new_done` for the movement to try); a daily mission `t:<date>:perfect`
  (`perfect: true`, PERFECT_XP 300, one step per box) when there are two boxes or more.
  `TodayView._perfect_row`: a chest that fills, "Open the chest" (bursts, floaters,
  `Sfx.level_up`, `App.claim_quest`), then "Opened". Walkthrough: `tests/shots/today.gd`.
- Pushes that open the note, and an evening check (2026-11-21): `MorningAlert.send(..., click)`
  adds ntfy `Click` and an "Open note" action with the Google Doc link (`note_link`), for the
  morning push and Settings' test. Evening: `settings.morning.evening` / `eveningTime` (19:00;
  12:00 to 23:30), its own task `TASK_EVENING` running `tools/morning.gd -- --evening`
  (`schedule(on, time, task, extra)`): it reads the save and the note (`note_sessions`: what
  is typed there for today, imported or not) and sends `Missions.evening_text` (what of
  `day_boxes` is still open, "open your chest" when all are ticked, nothing when there is
  nothing to say). The switch is the user's to flip (it registers a Windows task).
- Weekly recap to the phone (2026-11-21): `app/recap_push.gd` (`RecapPush`). `main.gd` calls
  `send_if_due` 6 s after start (`MorningAlert.recap_due`, pure): Morning goals on, `settings.morning.recap` (default on), last
  week not yet sent (`recapSent`) and not empty -> the poster without progress photos
  (`r.photos = null`: ntfy.sh is public and keeps attachments a while), saved to its own
  file (`RecapSheet.save_picture(r, file_name)`) and PUT as an attachment
  (`MorningAlert.send_picture`), then deleted. Never with TINY_TITAN_DATA set (tests,
  scratch copies) unless `--recap-push-test`. Checked 2026-11-21 against a stand-in server.
- Bigger record moments (2026-11-21): a "pr" card in the results reel adds `Sfx.level_up`,
  confetti, `_shake()` (kills a running shake first) and `_fireworks(card)`.
- Hero mood (2026-11-21): `Recovery.mood(sessions, today)`: "tired" after TIRED_STREAK (6) days
  in a row with a workout (a rest day ends it), "pumped" on a day with a workout, else "".
  `App` sets `Art.mood` whenever it derives; `Art.body_input` passes `mood` and `_hero_sig`
  includes it. `HeroFigure`: pumped = lift +0.07 / bulk +0.03, a flushed skin, a grin; tired
  = shoulders a pixel lower, heavy lids, a sweat drop, paler skin (`_mood_skin`). The classic
  look ignores it (parity_art unchanged).
- Ghost rival (2026-11-21): `LiftTrend.ghost(history, cur)` = the session closest to GHOST_DAYS
  (28) before `cur`, 3 to 6 weeks back, scored by `ghost_score` (estimated 1RM, else the
  longest hold, else the most reps in a set): {ghost, days, you, them, pct, won, tie}. The
  Compare view adds `LiftViews._ghost_card` (the hero against a see-through, flipped copy, a
  bar each, the verdict; a burst on a win through a weak reference, since the page can be
  rebuilt before it fires). Tests: lift_trend_test, the progress walkthrough.
- The phone logger (2026-11-21, "I want the typing/clicking process to be as easy and smooth as
  possible"): the note's script (now `app/doc_script.js`, VERSION 3; `DocClear.script_for`
  puts `app/doc_logger.html` into it as `PAGE` and the token everywhere) serves a mobile page
  at `?page=log&token=` (`DocClear.logger_url`, `MorningAlert.logger_link`). It calls the
  script with `google.script.run` (`apiToday`, `apiLogSet`, `apiAddRow`, `apiAddLine`,
  `apiClearCell`, `apiSetCell`, `apiFeel`; in a test stand-in `?api=` with fetch) and only
  ever writes TABLE rows under today's date row, so the game imports and clears them as
  typed rows: a set goes in the next empty Set cell of the exercise's last row when the
  weight is that row's (or the row has no set yet: its weight is replaced), else a new
  row under it (a row without a name = more sets of the one above); holds are `30"` in
  Weight and times in the Set cells; bodyweight is "bw"; added exercises are marked like
  plan rows (skipped until a set is logged); climbs / pages / weigh-ins / runs / rides /
  notes are single-cell rows ("v4 send", "read 20 pages", "weight 182.4", "run 3.1 mi
  28:00", "note: ..."), which the parser reads as typed lines. The page: cards with
  steppers (only the number redraws; a redrawn button never hears the finger lift, which
  made a hold run away), LOG SET, chips to undo, a rest timer (vibrate, beep, -15/+15),
  the screen kept awake, auto-scroll to the next exercise when one reaches its sets, an
  add sheet (the player's lifts), quick adds and Tired / Okay / Strong. The game sends what
  it needs with the plan (`DocClear.plan_info`: unit, step, the day's label, the player's
  lifts with their last weight, an aim per planned lift and PT; kept under `INFO_MAX` in a
  link). Pushes carry "Log workout" (tap) and "Open note" actions; Settings -> Phone inbox
  has "Phone logger: Send to phone / Copy". Tests: `tests/doc_clear_test.gd` (the calls on
  a pretend doc, what the game reads back), and the page was driven in a browser at phone
  size against `tests/doc_clear_stub.js` (it serves `?page=log`).
- Warm-ups and plates (2026-11-21): `game/plates.gd` (`Plates`): `is_barbell(lift)`, `per_side` /
  `text` (a 45 lb or 20 kg bar and the usual plates), `warmups` / `warmup_text` (the bar
  for 10, then 40 / 60 / 80 %). Shown under barbell rows of the Today card and sent to the
  phone logger (`plan_info` aims: `warm`, `plates`). Test: `tests/plates_test.gd`.
- Importing on its own (2026-11-21): `saved.inbox.autoImport` (default on; Settings -> Phone inbox
  "Import on its own"; kept by `parse_saved`). After a check, `PhoneInbox._auto_import`
  imports `auto_pick(fresh, today, quiet_ms)`: nothing to ask (no `names`, no warnings, not
  an edit: `replaces` / `replaces_key`, no pictures, not left out) and the day `settled`
  (an earlier day, or the note unchanged for QUIET_MS = 90 min, so a workout still being
  logged on the phone is never imported, and so never cleared, under the player's thumb).
  The rest waits for the review. The note is read again every RECHECK_SEC (10 min) while
  the game is open (with Auto-check). The inbox walkthrough turns it off for the review
  and checks it at the end.
- (2026-11-22: how you feel is now ONLY A MARK. The user: "I don't want to change the goals based on
  feeling strong, okay etc. want to mark it still but don't have it change goals, it's fine not to hit
  goals sometimes." `Missions.easy_day`, `easy_sets`, `lighter_week_due` and the Today card's lighter
  week card are gone, `settings.deloadUntil` is ignored, the note's phone logger no longer starts
  lighter on a tired day. `Missions.feel_of` and the Feeling row stay. The next bullet is how it was.)
- How you feel (2026-11-21): `settings.feels` = {date: 1 tired, 2 okay, 3 strong}. Set by the
  morning push's three ntfy "http" buttons (`MorningAlert.send(..., feel)`: `feel_link` =
  the script link with the token; the script's `?feel=` keeps it in its properties), the
  phone logger's buttons (`apiFeel`) or the Today card's Feeling row (`TodayView._feel_row`).
  `PhoneInbox.fetch_feels` (after each check) merges the script's into settings (a ping
  returns `feels`). `Missions.easy_day` (tired, or `settings.deloadUntil` = a lighter week):
  the Beat it missions become "Easy day" (`easy_sets`: about EASY_SHARE 0.9 of last time)
  and are done by doing the lift any way; strong aims one `next_target` further.
  `lighter_week_due` (tired 2 of the last 3 days): a card offers 7 lighter days. The
  logger starts 10% lighter on a tired day. Mission ids do not change.
- Plateau buster (2026-11-21): `LiftTrend.plateau(history)`: the last STUCK_AFTER (3) days of at
  least 5 no better than the best before them (`ghost_score`, 1% slack); `plateau_fixes`: a
  reset week at 90%, a variation swap, another rep range. The lift page's Compare view adds
  `LiftViews._stuck_card` (not for PT); Today rows get a STUCK tag. Tests: lift_trend_test.
- Strength standards (2026-11-21): `game/standards.gd` (`Standards`): `bodyweight(body)` (the newest
  check-in with a weight), `rate(lift, e1rm_kg, best_reps, bw)` -> level 0-4 (Beginner to
  Elite) from general standards for men: one-rep max / bodyweight for barbell bench,
  squat, deadlift, overhead press, row, RDL, hip thrust (`RATIO`); reps in a set for
  pull-up, chin-up, push-up, dip (`REPS`). The Compare view adds `_standard_card` (five
  coloured steps, what the next level needs). Tests in `tests/plates_test.gd`.
- Body-part bosses (2026-11-21): every weekly bounty monster is also weak to a muscle group
  (`Bounty.weak_part_for(wk)`, one of MUSCLE_GROUPS: legs, back, chest, shoulders, arms,
  core): a session with WEAK_SETS (3) working sets or more of it (`muscles_of`, stored in
  `weeks_of` lists as `muscles`) hits for WEAK_MULT, the best of that and the weak
  discipline (never both). Records carry `weakPart`; the card and sheet show a muscle pill
  (`BountyView.part_pill`). It only ever adds damage, so no past win was lost; weekly and
  coins stay outside parity. Tests: bounty_test.
- Split combos (2026-11-21): `Missions.combo(sessions, today, cycle, marks)`: the week's lift days
  (Monday on) by `kind_of_day`; a day that is the next kind after the one before adds to
  the chain, another starts it again ({now, best, kinds}). The Today card shows "×N" (with
  embers) beside the split chips from 2; a weekly mission "Combo week" (3 in order, 300 XP)
  when a split is set. Tests: missions_test.
- The gym follows the split (2026-11-21): `GymScene.draw_focus(p, focus)` (the game's own look):
  a chalkboard top right with the day in 3x5 chalk letters (`GLYPHS`, `FOCUS_WORDS`) and its
  kit: a bench and a loaded bar (push / upper), a pull-up bar on the rack (pull / upper),
  plates piled on the rack's bar (legs / lower), a crash pad and a chalk bucket (climb).
  `Art.focus` (set by App when it derives: the plan's kind, else "climb" on a climbing day
  with no lifts) goes to the scene and into `_scene_sig`. parity_art untouched.
- Trophy room (2026-11-21): `ui/screens/trophy_room.gd` (`TrophyRoom.open`, a key on Adventure ->
  Trophies): the newest trophies on four wooden shelves (tier-coloured slots, gold and
  platinum twinkle), record plaques (the four strongest lifts by estimated 1RM, the longest
  run and ride, the hardest send, the longest hang) and the companions strolling on a floor.
- Workout replay (2026-11-21): the results reel of ONE lift session has `replay`
  (`App.replay_moves`: up to REPLAY_MAX 5 exercises {move, variation, sets, pose, n, vol});
  the hero at the top does two reps of each (`Missions.pose_of`: "press" push, "pull",
  "squat" legs, "curl" biceps / forearms, else "flex"; the poses are `HeroFigure`'s, the
  classic look draws them as idle) with the name and sets under it (a caption of fixed
  height), then "Workout done · 4 exercises · 20 sets · 14,000 kg moved". A skip ends it.
- Climbing projects (2026-11-21): `game/projects.gd` (`Projects`, pure). STORED in
  `saved.projects` = [{id, grade, yds ("" = boulder), name, since, sent, sessionId, aside}]
  (kept by `App.parse_saved`; nothing is deleted: a project is sent or set aside, "Back on"
  reopens it). Progress is from the log: every climb session since `since` with an entry of
  its grade (`matches`: a boulder's V grade, a route's YDS) is a session on it, attempts are
  its tries, until the send (`status`). `App.add_project` (MAX_OPEN 6), `send_project` (pays
  SEND_XP 250 as a claim, questId `project:<id>`, once), `set_project_aside`. The reel:
  `App._project_events` -> card "project" (`ResultsOverlay._project_card`): a send of its
  grade asks "Was it your project?" (yes: gold, fanfare, fireworks, +XP; "Not this one"),
  a session that only tried it says which session it was. UI: `ui/screens/projects_view.gd`
  (`ProjectsView.card()` on the Hero tab under PT, for a player who climbed in the last 45
  days; `open()` the sheet: open ones with "I sent it!" (the last session that sent its grade)
  and "Set aside", the form under them (the sheet grows from the bottom, and `_keep_form`
  scrolls when it is full, so adding one never moves the form), then Sent and Set aside).
  The Today card's climb row names the open project. Tests: `tests/projects_test.gd`,
  walkthrough `tests/shots/projects.gd` (year data).
- The Journey climbing card (2026-11-21, "a flash is a send, just not every send is a flash"):
  `ui/screens/climb_card.gd` (`ClimbCard`) from `game/climb_ladder.gd` (`ClimbLadder.ladder(sessions,
  routes)`, pure). Three outcomes in the Log tab's colours: flash (gold, sent first go), send (climbing
  colour, sent after tries), didn't go (`Pal.SECOND`, attempts); "sent" = flash + send, as
  `totals.climbSends` counts it, and "tries" = all three. Boulders / Routes chips (when both were
  logged), three tiles, `OutcomeBar` (`ui/charts/outcome_bar.gd`: every try, a bracket "SENT n · p%"),
  `GradeLadder` (`ui/charts/grade_ladder.gd`: a bar per grade from the hardest tried to the easiest,
  "sent/tries", a hover tip; a click picks the grade and only the detail under it is redrawn), the
  records. `ClimbCard.mode` / `picks` are static, so a rebuild keeps them. The send pyramid
  (`PyramidChart`, `Charts.pyramid`, `Charts.flash`) is gone. The Log form's climb line says "N flashed ·
  N sent after tries · N didn't go" (`st.sends` counts flashes too). Tests: `tests/climb_ladder_test.gd`,
  walkthrough `tests/shots/climbs.gd` (year data).
- Also 2026-11-21: `ShotHelper.snap` also fails when a column runs past the window's right edge (a row
  that is too wide makes the whole ScrollContainer grow, which the older check missed: the Journey
  page was 514 of 440 px since the hero was redrawn). The "Day 1 / Today" heroes are drawn x2 when two
  at x3 would not fit (`JourneyScreen._hero_scale`). The same check found the shop's "For sale" grid
  (470 px: `ArmoryScreen._zoomed(tex, slot, max_w)` trims a view wider than 112 px by a few columns at
  its sides) and the recap sheet (448 px: `RecapSheet.POSTER_W` 380, the XP number at most 110 px wide,
  the level and coin pills in a flow).
- The phone app (2026-11-21, "the end goal is to have this all on an app on my iPhone or a bookmark";
  no Mac, so no native iOS app): the game itself, exported for the web and opened from the iPhone's Home
  Screen, sharing one save with the PC through the note's script.
  - Build: `export_presets.cfg` ("Web": no threads, so no special server headers; tests/tools/web/build
    excluded), page `web/shell.html` (Godot's shell plus iPhone meta tags, a pixel loading screen, the
    typing bar `#tt-type`, the action button `#tt-act`), `web/tt.js` (ttSafe: notch / home-bar insets;
    ttApp: touch, iOS, standalone, the link's #part, wake lock; ttKb: typing; ttFile: share / pick a
    file; registers `sw.js`). `python tools/build_web.py` exports to `build/web` (`build/.gdignore` keeps
    Godot out), adds the icons (from icon.svg), `manifest.json` (no start_url: the Home Screen keeps
    the link it was added from, #c= and all), `sw.js` (offline; a new build replaces the old one the
    next time the app opens) and `.nojekyll`. `tools/publish_web.py <clone> [--push]` copies the build
    into the GitHub Pages repo: published 2026-11-21 to `jakejenks3/tiny-titan`, branch gh-pages,
    local clone `C:/Users/jdjen/Documents/tiny-titan-pages`, live at
    https://jakejenks3.github.io/tiny-titan/ (= `CloudSync.APP_URL`). To update the phone app:
    build_web.py, then publish_web.py with --push (no need to ask: 2026-11-22, "You can always publish
    to phone in future"; build and test first, then check the live site serves that build).
    The pack holds no save, no link, no token (checked 2026-11-21).
  - Phone handling: `ui/touch_scroll.gd` (`TouchScroll`, added by main.gd on any touch screen; rewritten
    2026-11-21 after "after I release it scrolls a bit and THEN the tooltip pops up, sometimes it clicks").
    It switches `Input.emulate_mouse_from_touch` OFF and swallows every raw touch in `_input` (with
    emulation off Godot's buttons act on raw touches by themselves: taps counted twice), then makes the
    clicks itself: a tap = press + release on the lift (`TAP_SEC`); a hold (`HOLD_SEC` still) = the press
    starts under the finger (a stepper repeats); a drag past `SLOP` scrolls the nearest ScrollContainer
    that can, calling off a press under way with a MOTION far away and then the release (a Button only
    learns the pointer left from a motion); the lift glides (`_fling`, own speed from the last 90 ms,
    float position); a finger on a gliding page only stops it; a swipe where nothing scrolls is not a
    tap. A text box is pressed as the finger lands (the keyboard must open inside the touch). After a
    click the pointer is moved off screen (`LINGER_SEC`), so nothing stays hovered; no motion is sent
    for a tap, so no tooltip timer starts; `HoverCard` stays shut while `TouchScroll.active`. Before,
    the emulated mouse stayed parked where the finger had been, and what glided under it was hovered
    and sometimes pressed; Godot's own ScrollContainer touch drag also fought this one. `Stepper` on a
    phone (`_touch`) steps when the finger lifts on the key (`TouchScroll.last_release_pos`). Walkthrough
    with real touch events, PC build: `tests/shots/touch.gd` (year data).
    Settings -> Phone app shows the build's date (`ttApp.build`, written into the page by build_web.py)
    and a "Show speed" switch (`main.show_speed`: frames a second and the slowest half second, in the
    corner). A frame costs about 0.5 ms and 100 draw calls on the PC, so a slow phone is not the drawing:
    look at Low Power Mode (Safari then runs pages at 30 frames a second) first. `web/tt.js` caps
    `devicePixelRatio` at 2 on touch devices.
    THE REAL CAUSE on an iPhone (found the same evening, "the hover tooltip still shows up every
    time", "like a cogwheel"): Godot's web layer takes mouse motion from the browser's `pointermove`,
    and a real finger sends those (a made-up TouchEvent does not, so every test passed). The engine's
    mouse followed the finger: a hover storm during a drag, a parked pointer and a tooltip after it.
    Now `web/tt.js` stops non-mouse pointer events before the engine sees them; `only_fingers` (set by
    main.gd when `ttApp.noHover`) drops every mouse event not made by TouchScroll (`MY_DEVICE`) and
    moves the pointer away again (hover is worked out before `_input` runs); project.godot has
    `gui/timers/tooltip_delay_sec.web` = a day (read it with `get_setting_with_override`); the page
    follows the finger in parts of a unit (`_scroll_to` returns where it is, `tt_fine` / `tt_base`
    metas, `_placed` after `sort_children`); `TouchScroll.scrolling` pauses Backdrop, Fx, Bar and Stage
    animations. When testing touch in a browser, ALSO dispatch `PointerEvent('pointermove',
    {pointerType: 'touch'})` on window: that is what a phone does.
    NEVER leave a file with the user's data in the project folder: a build exports every resource
    (a backup JSON saved there on 2026-11-21 got into an UNPUBLISHED build). Guards: export excludes
    `*.json`; `build_web.check_pack` stops a build whose pack holds anything but the game's own
    folders (publish_web.py checks again); Export backup opens in Documents.
    In the web build only: `app/web_keys.gd` (`WebKeys`: a focused LineEdit / TextEdit shows the page's real field at the top,
    which the phone's keyboard types into; text goes back as it is typed, Done / return submits; the
    field is focused inside the tap's touchend so iOS opens its keyboard, and tapping the field always
    does); `ui/symbol_font.gd` (`SymbolFont`: → ← ↑ ▲ ▼ ▾ ✓ as a small MSDF fallback font from
    `ui/symbol_font_data.gd`, made by `tools/make_symbol_font.gd` from Droid Sans Fallback, Apache 2.0,
    `ui/fonts/LICENSE-DroidSansFallback.txt`; Godot's own font lacks them and a browser has no system
    fallback); main.gd fits the column between the status bar and the home bar (`_read_insets`);
    `Stepper` steps on a tap's lift and repeats on a hold, so a scroll that starts on a key changes
    nothing (`TouchScroll.last_cancel_msec`); `app/web_files.gd` (`WebFiles`: recap pictures and backups
    go to the share sheet, backups come from the file chooser). Hidden on the web: the phone inbox (a
    browser cannot fetch a Google Doc: the PC reads the note), morning goals, Open data folder, Import
    from phone; `RecapPush` does not send. `?debug=1` in the link: `window.ttEval("expr")` evaluates a
    GDScript expression (names main, App) into `window.ttOut`; `main.debug_rect(text)` finds a button.
  - Sync: `app/cloud_sync.gd` (`CloudSync`, `App.cloud`, a child of App; reaches App as `_app()` so the
    class compiles in --script tests). The note's script, VERSION 4 (`DocClear.SCRIPT_VERSION`), keeps
    the save: GET `?save=get|head`, POST `{token, save: "put", base, data, by}` (gzip + base64, in 8000
    character script properties, two slots so the copy before stays whole; a put whose base is not the
    current rev is turned down and the game merges). A Google POST answers with a redirect: the PC
    fetches it itself (`max_redirects = 0`), a browser follows it. Local files `sync.json` ({on, url,
    token, rev, at}; on the PC the link and token come from the phone note's settings) and
    `sync_base.json` (the copy last agreed on). `game/save_merge.gd` (`SaveMerge.merge(base, mine,
    theirs)`): records by id (a change outweighs a delete; both changed: the newer save), pages read
    added up per day, everything else key by key. Guards: an empty save never goes over a full one (a
    new phone or a reset takes the copy instead); a sync that would remove more than `MAX_GONE` (10)
    sessions at once is not made; the save is copied to `backups/sync-*.json` before a merge is taken
    on (`App.apply_synced`). It syncs a moment after start, a few seconds after each change, every 3
    minutes and when the app comes back. Settings -> PHONE APP (`ui/screens/phone_app_card.gd`): the
    switch (off until the user flips it), the state, Sync now, Send to phone (an ntfy push with
    `APP_URL#c=<code>`; the code is the script's link and token), Copy; in the phone app a paste box to
    connect, and the onboarding offers "Already have a hero on your PC?". `tools/morning.gd` merges the
    script's copy in memory (never writes), so the morning plan and evening check see what the phone
    logged. Tests: `tests/sync_test.gd` (merges, and CloudSync against the real script in the Node stub,
    which now answers POSTs with a redirect like Google and keeps properties).
  - Progress photos (2026-11-21, "everything transferred except my progress pictures... blank"): the
    script, VERSION 5, keeps them as files `<id>.jpg` in a folder of the user's Google Drive, "Tiny
    Titan photos" (`photoFolder`: its id in the script's properties, else found by name, else made;
    GET `?photo=list` / `?photo=get&id=`, POST `{photo: "put", id, data}`; never deletes). DriveApp
    means Google asks for Drive when the new version is authorised: the script has `authorize()` to
    run once from the editor BEFORE deploying (an unauthorised version answers nothing at all, the
    logger included). `CloudSync._sync_photos` runs after every good sync: photos the save names
    that are missing here are fetched (checked to be a JPEG, then written to `App.photo_path`,
    `App.photos_arrived` redraws), photos here that the folder lacks are sent; one listing, and only
    when there is something to do; `sync.json` `photos` remembers what the folder has;
    `cloud.photo_note` says what is in the way (shown in Settings -> Phone app). The phone app adds
    photos itself: `LogBodyForm.pick_photo` -> `WebFiles.pick("image/*", ..., 1600)`: the page shrinks
    the picture on a canvas (which also turns a phone photo the right way up) before the game
    stores it. Tests: sync_test (the stub has a pretend Drive, `/drive`).
  - Phone only, backups by hand (2026-11-21, evening: "I don't need my pc version to stay synced...
    goal is to just have it on phone"; "I will just backup by hand from phone"). The user chose NOT to
    keep the script as a backup: the sync and the Drive photos stay in the code but are theirs to leave
    off, and script version 5 was never deployed by them. So the phone app's backup file is the only
    second copy: `App.note_backup` / `backup_info` (`backup.json` next to the save), `backup_age_text`,
    `backup_due` (a log worth keeping, changed since the last file, `BACKUP_EVERY_DAYS` 7 or never).
    On the web: Settings -> DATA shows "Last backup: ..." with Back up now (the JSON with photos, to
    the share sheet) and Restore; the Hero tab shows a "Back up your log" card when due; the first
    screen offers "Restore from a backup" (how the log and photos get into a new phone or the Home
    Screen app, whose storage is its own). The PC's photos reach the phone the same way: Export
    backup on the PC, Restore on the phone. `main.debug_do` drives these from ttEval.
  - Tried 2026-11-21 in a phone-size browser (Chromium, touch emulation) against the stub: connecting by
    link, the whole save arriving (184 sessions), logging on the phone reaching the PC copy, touch
    scrolling, taps, steppers, the typing bar. NOT tried on a real iPhone (Safari's keyboard, the Home
    Screen's handling of #c=, audio): the first real test is the user's.
- Phone only, the next batch (2026-11-21, night: "do all besides the rest timer and the walks"):
  - Start workout: the Today card's key (`TodayView._start_row`, meta `start_workout`) sends the day's
    lifts and PT still to do (`TodayView.workout_names`) as `App.pending_workout`; `LogLiftEditor.build`
    adds each with last time's sets, marked `planned: true` until touched (a quiet card edge;
    `_touched`). Finish asks once about lifts still planned ("Done as shown?",
    `LogSessionForm._save_planned`), so a skipped lift is not logged by accident. With a lift already
    saved today the key says "Continue workout" and opens that session with what is left.
  - The kept draft: a NEW lift or climb is written to `<data>/draft-lift.json` / `draft-climb.json` as it
    is entered (`App.draft_store` / `draft_load`, from `LogSessionForm.refresh`), because a phone closes
    the app between sets. Opening the form again the same day brings it back (`restored`, a "Picked up
    where you left off" card with Start over); saving drops it. Edits of a saved session are not kept.
  - Hold seconds in the lift editor: an exercise has `timed` (the "Hold" chip; a hold from the note
    arrives timed), its sets a `hold` String; a seconds stepper (step 5, starts at last time's or 30)
    takes the weight's place, "+5 s" bumps all, the note compares seconds held.
  - Finger sizes: `Kit.fingers` (main.gd: a touch screen on web / mobile, or `--fingers` after the
    data kind in a walkthrough): stepper keys 40 x 40, mini chips 38 tall, chips and small buttons
    taller, icon buttons at least 38, the weight unit dropped from set rows. Any new small key must
    look at it. `tests/shots/workout.gd` snaps every tab with it on (the snap's width check).
  - Rename or move a lift: the key at the foot of a lift's page -> `JourneyLifts.open_rename` (movement
    and variation boxes, nearest movements as chips, what will happen said first) -> `App.rename_lift`
    (every session's exercise of that name, the PT mark, `inbox.names`; an existing name = the two
    become one lift; a copy of the save in backups/save-<day>-before-rename-*). Renaming to a new
    name changes no XP; joining two lifts can (records are per name).
  - Sharper picture: `web/tt.js` caps `devicePixelRatio` at 3 (was 2) unless `localStorage.tt_sharp`
    is "0" (Settings -> Phone app -> "Sharper picture", shown when the screen has more than 2; the
    page reloads). Buzzes: `Sfx.buzz(n)` -> `ttApp.buzz` (navigator.vibrate, or on an iPhone a hidden
    switch checkbox clicked, which ticks on iOS 17.4+); with `Sfx.pr`, `level_up`, `claim`, `error`,
    + Set and Finish; `settings.haptics` (default on). NOT felt on a real iPhone by anyone yet.
  - Backups: `App.export_backup(path, with_photos)`. The phone's "Back up now" (`SettingsPanel.pick_export`)
    puts the photos in only when some are in no backup made here (`App.photos_unsaved`, from
    `backup.json` `photoIds` / `photosDay`); otherwise the log alone, and "Back up with photos" for a
    full one. Restoring a log-only file leaves the device's photos; restoring a file OLDER than the
    log that holds photos missing here offers "Add photos" only (`App.take_photos`).
  - Morning message without the PC: `app/phone_push.gd` (`PhonePush`, `App.push`; web, or
    `--phone-push-test`). The app leaves the next mornings' plans with ntfy as held messages (JSON to
    the server's root, `delay` = unix time, no headers so no CORS preflight). ntfy.sh cannot replace
    or take back a held message (tried 2026-11-21: same `sequence_id` twice = two deliveries, DELETE
    does not stop one), so it is ONE message per morning, written as if the days before go as planned
    (`forecast`: pretend sessions on days the player usually lifts, `lift_likely`) and at most one
    "(updated)" correction, a minute later, once the day before is settled. `settings.morning.phone`
    is the phone's switch (the PC's stays `on`); state in `<data>/push.json`. Settings -> MORNING GOALS
    on the web is `_build_morning_phone`. Tests: `tests/phone_push_test.gd`, walkthrough
    `tests/shots/phone.gd` (needs `node tests/push_stub.js 8799` and `--phone-push-test`).
  - `PhoneAppCard` in a phone app that is not connected shows its own switches first; sharing with a
    PC is behind "Share my log with a PC…".
  - Where this batch stands (2026-11-21, 22:05): all 24 unit suites and every walkthrough pass, and
    the walkthroughs were also run with `--fingers` after the data kind (detail, progress, settings,
    armory, climbs, reading, projects, lifts, climb_more, misc, log, shop, bounty, adventure, journey,
    today, workout). That run found two things, both fixed: a set row in pounds was 4 px too wide
    (at finger sizes the badge beside a set drops its unit: "+12.5"), and a toast took the click
    meant for a key under it (its row is now `Kit.passthrough`). Build 20261121-220221 has it all and
    was opened at phone size (Start workout). Published 2026-11-22 (the user's "Publish.").
    Walkthroughs open a window: run them only once the user says they are off the computer. A copy
    of the project with a no-focus window far off screen still went over their game; `--headless`
    does not work for walkthroughs (clicks are not delivered; `ShotHelper.snap` skips the picture).
- Typing and taps on the phone, overhauled (2026-11-22, "body check in page on mobile is all kinds of
  messed up... keyboard pops up... up or down buttons keep spamming"). What was wrong, all in the web
  build only:
  - The ENGINE has a hidden typing box of its own (`div.ime`, Godot's web IME): while a LineEdit has the
    focus it takes the page's focus every 100 ms, pulling the keyboard from `#tt-input` and pushing the
    page about. `web/tt.js` puts class `tt-touch` on the page and `web/shell.html` keeps `.ime` at
    `display: none !important` there (an element not displayed cannot take the focus).
  - The engine also focuses its canvas on every touchstart, which blurred the field: keyboard down and
    up again with each touch. While typing, `canvas.focus` is a no-op (`cv.ttFocus` keeps the real one).
  - The page opened the keyboard on the lift of ANY tap while a box was active, and the body check-in
    put the cursor in the weight box by itself. Now the keyboard belongs to a tap on a text box only:
    `TouchScroll._finger_down` calls `WebKeys.finger_on(box)`; `WebKeys._on_focus` holds a box only
    within `FINGER_MS` of that, takes over a box rebuilt under the typing (`_hold(c, true)`, `GRACE_SEC`),
    and makes any other box that got the focus from the game let go again; `kb.fresh` (set by `want`,
    `arm`) is the only thing the touchend handler opens the keyboard for. A tap or press elsewhere ends
    the typing (`TouchScroll._leave_text` -> `WebKeys.tap_away`), and so does the phone putting its
    keyboard away (`kb.onClose`). `LogBodyForm` no longer grabs the focus on a touch screen.
  - A tap's click is made INSIDE the finger's lift (press and release together; `_flash` shows the key
    pressed, a Card squashes by itself), because a phone only opens a file chooser, the share sheet or
    the clipboard from inside the finger's own event: `ttFile.pick` / `save` / `ttCopy` act at once
    when `live()` (the `#tt-act` button is the fallback; for a chooser it shows as well, and it goes
    with the next touch of the game). One tap on a photo tile opens the chooser.
  - A lift that never arrives must not leave a key held: `ttApp.fingers()` (touch events' own count,
    plus a pointer that went up with no touch event since), `TouchScroll._lost_lift` at the next touch
    or from the `_watch` in `_process`; `TouchScroll.holding` / `no_mouse`: a Stepper on a finger-only
    screen repeats only while a finger really holds it.
  - Tried in a phone-size browser with made-up touch events (ttEval helpers `main.debug_where(kind, nth)`,
    `main.debug_touch()`): no bar on opening the check-in, + / − step once, typing ends on a tap
    elsewhere, a touch of the screen keeps the field's focus, a held key with no lift is let go, the
    photo tile calls `ttFile.pick` inside the touchend. NOT tried on a real iPhone: a made-up event
    carries no "user activation", so the chooser itself opening in one tap is unproven.
  - `tests/shots/touch.gd` sets `Engine.max_fps = 120`: at 1,800 frames a second (a PC with no vsync)
    a flick's moves fell inside the 4 ms `_speed` does not read, and the glide check failed at random.
  - Published 2026-11-22 as build 20261122-071629 (the user's "Yes"); the live pack was checked to be
    the tested one. Still waiting for the user's word on how it feels on the real iPhone.
- Long lift names and the iPhone's short page (2026-11-22, "first page isn't fitting right", a
  screenshot of the Hero tab cut off at the right with a dead band under the tab bar):
  - The width: a Today row holding "Romanian Deadlift" + a four-word variation + PT + the aim + the
    tick needed about 480 of 440 px, and one row too wide widens the whole page. The demo lifts are
    short, so no walkthrough saw it. `ui/widgets/squeeze_row.gd` (`SqueezeRow`, `Kit.squeeze(sep)`): a
    row whose soft parts (`Kit.soft_name`, `SessionView.variation_tag(v, size, true)`) are cut off with
    "…" when it is short of room, the last soft part first (the variation before the movement). Used
    by the Today card's lift and "try something new" rows, `SessionView._lift_row`, the review's pick
    row. A movement name beside a variation tag goes in a squeeze row, never a plain hbox.
    Walkthrough `tests/shots/long_names.gd` (year data, also with `--fingers`): gives the planned
    lifts long variations, marks them PT and snaps every screen that lists lifts.
  - The band: WebKit bug 301994 (iOS 26.0 to 26.1, back in iOS 27, still open in Nov 2026). A Home
    Screen app with the black-translucent status bar gets a page SHORTER than the screen by the
    status bar (874 screen, 812 page on an iPhone 16 Pro); the system draws the band under it and no
    element can reach it, so the page cannot fill it (the status bar style is fixed when the app is
    added to the Home Screen, and adding it again starts with empty storage: do not suggest that).
    What the game does: `ttSafe()` (web/tt.js) reports no bottom inset in that state (the home bar
    lies in the band, not on the page), so the tab bar sits at the page's bottom edge and 34 pt come
    back. Settings -> Phone app shows "Screen WxH · page WxH · bars top / bottom · N short" under the
    version: ask for a screenshot of that line when the phone app does not fit.
  - Published 2026-11-22 as build 20261122-102403 (the user's "Yes"). How the band and the lower tab
    bar look on the real iPhone is not known yet.
- Real lifts, not estimates (2026-11-22, "it's using some of my estimated 1rm instead of my real ones
  for plaques... in some of my lift graphs too which doesn't make sense"): an estimated one-rep max
  is never shown as if it were lifted. The trophy room's lift plaques are the heaviest set really done
  ("230 lb × 5", by `bestKg` then reps); the Journey -> Stats lifting chart plots the heaviest set of
  each session (it plotted the estimate, said only in a tooltip, which a phone never shows). Where
  the estimate stays it says so in words on screen: the lift page's metric key is "Est. 1RM" (was
  "Strength") with a line under the chart, the records tile "est. 1RM", the strength-level card's
  heading, the ghost card, the reel's "est. 1RM PR". The default metric is Top set. A new number
  that is worked out and not lifted must be labelled the same way, on screen, not in a tooltip.
  Published as build 20261122-104529.
- "Try something new" with options (2026-11-22, a screenshot of Hip Thrust ticked though it was never
  logged; then "that's fine actually, if it's a new movement with same goal... give a few options
  because I only didn't do it because of equipment"): `plan.new.alts` = `NEW_ALTS` (2) more movements
  never done (the same body part first, other equipment first), shown as OR chips under the row
  (meta `new_alt`) and named in the mission and the morning / evening text (`Missions.new_words`).
  `Missions.new_by(sessions, today, plan)` = the lift that did it: one of the movements offered, else
  another never-done movement with the same goal (`same_goal`: the split's kind, else the day's area;
  not a stretch, not a PT exercise, not another area), and only with sets really logged. The mission
  carries `by`; when another movement did it the Today row names THAT lift ("SOMETHING NEW · DONE",
  a "First time" tag), so a tick never stands beside a movement that was not done. The plan carries
  `marks`. Tests: missions_test; the today walkthrough snaps the chips.
- Training summary as text (2026-11-22, "break down my exercise dosage... a pastable text I can send to
  a normal Claude chat... main goal of the app is to track and see how well I'm planning and dosing to
  improve physique"): `game/dosage.gd` (`Dosage`, pure). `text(saved, today)`: the period, body weight
  and fat (first and latest), a typical week (per week = the last `WINDOW_DAYS` 28 days, or the whole
  log when shorter, never under 7, scaled to 7; and the last 7 days as they were), working sets per
  muscle group per week (direct, with indirect = half a set per set of a lift whose library "also
  works" names it, days a week, reps a set, weight moved), sets by rep range, every lift (days, latest,
  first, heaviest REAL set: no estimates), PT and stretches apart (`is_mobility`: a PT mark, "stretch"
  in the name, or holds only), climbing (boulders and routes by grade), runs, rides, vest walks, a day
  by day list, what the log lacks, and what to analyse. A session's length is only said when most
  sessions have one. `figures()` holds the numbers. Journey -> Stats has the "Training summary" card
  with Copy (`JourneyScreen._copy_dosage`, meta `copy_dosage`; on the phone `WebFiles.copy`). The
  phone's log is the only complete one, so the text is made there. Test: `tests/dosage_test.gd` (with
  DOSAGE_SAVE / DOSAGE_TODAY it prints the text of a save kept outside the project).
- Training focus (2026-11-22, the user's priorities: 1 muscle up and fat down, the upper body most; 2 keep
  climbing and the legs, no leg size; 3 one run a week, further; "do an overhaul of my daily goals... to
  push me to add more chest exercises... I still will probably need options some days due to
  equipment"). `game/dose.gd` (`Dose`, pure), OFF unless `settings.focus` is a `PLANS` id ("upper" =
  Upper body first: chest, back, shoulders, biceps, triceps "build"; forearms, core and the legs "keep";
  "balanced" = Whole body); Settings -> TRAINING FOCUS (`SettingsPanel._build_focus`, meta
  `focus_section`). With it off nothing below happens and every older test is unchanged.
  - A week is the LAST 7 DAYS (`Dose.window`), never Monday to Sunday. A set counts 1 for the lift's main
    muscle (`Dosage.part`), a half for each muscle its library row "also works", a climbing session
    `CLIMB_SETS` = forearms 4 and NOTHING for the back or the biceps (the user, 2026-11-22: "Don't count
    back together with climbing, climbing really doesn't work that way, it's way more fingers and much
    less back in practice"); PT, stretches and holds-only exercises count nothing
    (`Dosage.is_mobility`). Targets are [least, most, mode]; state short / ok / plenty.
  - "keep" means NO SETS ARE ADDED for that muscle, nothing else: its lifts still get Beat it missions
    and aims like any other (the user, same day: "leg stuff can still have goals to beat, I just don't
    plan on adding more volume... I still want to improve the lifting but not have it take the focus").
    A "Keep it: match last time" mission was built first and taken out again.
  - The plan (`Missions.day_plan`) gets EXTRA lifts (`Dose.extras`, at most `EXTRA_LIFTS` 2, put FIRST in
    `plan.lifts`, each with `dose` {part, sets 3-5, have, cover, need, min, mode, anchor, moves}): for a
    "build" muscle of the day's kind that is still short after the day's usual lifts, or one whose
    ANCHOR was not done in `ANCHOR_DAYS` 14 (the chest's press: Bench Press, Push-up, Dip; offered as
    barbell, incline dumbbell, machine, weighted push-up, dip, the player's own first). Their movements
    go into `plan.moves`, so "try something new" and the other lifts' options never offer them. Every
    lift has `mode` ("build" / "keep" / "").
  - `Missions.lift_done(l, plan, sessions, today)` is now the ONE place that says whether a planned lift
    was done (PT, an extra lift once its sets are in: an anchor only by a lift of its sort, anything
    else as before); `day_boxes` and TodayView use it.
  - Missions: `t:<date>:dose:<part>` ("Chest: add a press", "More for your triceps"; target = the sets,
    250 XP); Beat it goes to "build" lifts first (a leg day's two go to its leg lifts); (TAKEN OUT 2026-11-23, see "EVERY DAY IS A LIFT DAY": the rest mission is now only for a day the player calls rest) after `REST_AFTER` 5 hard days in a row (`Dose.is_hard`: a
    walk, PT and stretches are not) the day's first mission is `t:<date>:rest` IN PLACE of Show up, done
    once the day is over (`data.now`, from `App.mission_data`; claimed from "From yesterday"); weekly
    `tw:<wk>:dose` "Dosed right" (every build muscle on target at once, any day of the week). The run:
    see "The run has its own day" below.
  - Screens: `ui/screens/dose_view.gd` (`DoseView.row(plan)` on the Today card, meta `dose_row`: the
    day's muscles, sets of 7 days against the least; `open()` the sheet: every muscle, what counted,
    rest, the next run). Today card: "YOUR FOCUS ADDS" rows before "PROBABLY TODAY" (a "FOR CHEST" tag,
    "ADD · N SETS", the other ways as chips), a rest banner (meta
    `rest_row`). The morning text says the same.
  - The run has its own day (2026-11-22, "make sure run goals only show up on Monday, giving them a few
    goals if needed like mileage or speed. Don't want them on most days because I specially will only
    run Mondays"). With the run being built up (`Dose.run_on`: a focus and `settings.runGoal`, on by
    default) `Dose.run_day(sessions, settings, today)` = `settings.runDay` (0 Monday .. 6 Sunday; Settings
    -> Training focus -> Run day chips, meta `run_days`) or, on "Auto" (-1), the weekday most runs of the
    last 56 days were on. `day_plan` then takes "run" OUT of `plan.others` on every other day (however
    overdue) and puts it first on the run day (`plan.runToday`, `plan.run` = `Dose.run_goal`, null on
    other days: 10% past the last run within 10 days, the same after a longer gap, 80% after 21 days,
    plus `paceSec` / `paceM`). That day has two run missions to pick from: `t:<date>:run` "Run a little
    further" (the distance; "Run day: log a run" with none to go by) and `t:<date>:pace` "Run a little
    faster" (`Dose.run_quick`: at least 75% of the last distance at a quicker pace; only when the last
    run was timed). The day's other activity (a climb) keeps its own mission. There is NO weekly run
    mission (a "Long run" one was built and taken out: it showed all week). Without a focus runs are
    as before (by habit).
  - `LiftTrend.next_target`: a weighted lift whose every working set is at `HIGH_REPS` 15 or more goes a
    step heavier and down to `DOWN_TO` 10 reps (`heavier: true`), always, focus or not: the aim used to
    be a 25th rep at a weight that is too light.
  - (It first had to be switched on in Settings; since later the same day it is on by default, see
    "Options for every movement" below.) It was tried
    on a copy of the PC's log: push days get the press, pull and leg days nothing extra.
  - Tests: `tests/dose_test.gd`, more in lift_trend_test; walkthrough `tests/shots/focus.gd` (`new` data,
    makes its own log; also with `--fingers`).
- Coming up, the days ahead (2026-11-22, "preview the next few days, so I can look ahead and make
  decisions on what lifts... and just to mentally prepare and get excited without messing with any
  inputting of data yet"). `Missions.ahead(sessions, today, marks, settings, days = AHEAD_DAYS 6)` ->
  [{date, plan, rest, lift, others}]: from today on each day's plan is PRETENDED done
  (`pretend_lift`: its lifts and PT as last time, a lift never done left out; `pretend_other`: the last
  climb / run / ride again, a run at the plan's aim), unless it is a rest day (a focus's rest due:
  nothing is pretended) or already logged, and the next day's plan is made from that: the split goes
  on, rest comes due, a muscle that got its sets stops asking. (TAKEN OUT 2026-11-23, see "EVERY DAY IS A LIFT DAY": no rest comes due and no weekday habit is needed, every day is a lift day.) `lift` needs `lift_habit` (the weekday
  rule that was PhonePush.lift_likely; PhonePush.forecast now calls these two). Another activity
  counts on its weekday or once its usual gap has passed (score 1 or more) and not within half its gap
  of the last one (`_too_soon`), so a weekly run is not shown a day early and then again. Nothing is
  stored and no session is made. `App.ahead()` caches it (cleared with the plan); it costs about seven
  day plans (48 ms on the PC for 184 sessions: on the phone several times that, once per change of
  the log). `ui/screens/ahead_view.gd` (`AheadView.card()` under the Today card, meta `ahead_card`:
  the next 4 days in a word each, `Missions.ahead_word`; `open()` the sheet: a card a day, meta
  `ahead_day`, lift rows that open the lift's page, the other ways under an extra lift, "Try:", PT,
  the climb or run, a rest day). Read only on purpose: no ticks, no Start key, no picking a day's kind.
  Tests: `tests/ahead_test.gd`; walkthrough `tests/shots/ahead.gd` (year data, then a log of its own
  with a focus).
- A to-do list, apart from the game (2026-11-22, "A separate section for random things I need to do. I
  usually do them in my notes... doesn't need to connect. Goals or points or anything, just to keep a
  list and check boxes"). `game/todos.gd` (`Todos`, pure). STORED: `saved.todos` = [{id, text, done, at,
  doneOn}] in the order added (kept by `App.parse_saved`, merged record by record: in
  `SaveMerge.RECORD_LISTS`). Nothing in the game reads it: no XP, no mission, no streak, and a change
  only saves and redraws (`App.add_todo`, `set_todo_done`, `remove_todo`, `clear_done_todos`: no
  `_recompute`). `ui/screens/todo_view.gd` (`TodoView.card()` on the Hero tab after Coming up, meta
  `todo_card`: the open items and the ones ticked TODAY, `Todos.shown`, at most `CARD_ROWS` 3, a tap
  ticks one; `open()` the sheet: every item, a cross to take one off, "Clear done", the box and Add
  key at the bottom). Nothing may move under the finger: a ticked item stays in its place, the status
  line is always there, the box is at the bottom of a sheet that grows upward (`_keep_form` once it
  scrolls), and after an item is taken off taps are ignored for `QUIET_MS`. Keep it a plain list.
  - A SMALL BONUS FOR A TICK (2026-11-23, "Add some small bonuses for doing to do list tasks, changed my
    mind about that"), so "no XP" above no longer holds. Ticking an item off pays `Todos.BONUS_XP` 20
    hero XP (and so 2 coins), ONCE per item and for at most `BONUS_A_DAY` 5 items a day; unticking takes
    nothing back and ticking again pays nothing more. It is a claim (`saved.claims`, questId
    "todo:<item id>", like a sent project), so the XP and coins come from the replay and stay when the
    item is taken off the list. `Todos.bonus_for(claims, id, day)`, `paid`, `paid_on`, `left_on`;
    `App.set_todo_done` returns the XP paid and only a tick that pays works the hero out again
    (`_commit`, `announce_unlocks`). Still no mission, streak or plan reads the list. Screen: every row
    has a "+20 XP" chip in a slot that is always there (meta `todo_bonus` = open / earned / none: bright,
    quiet, unseen), the XP rises from the row (`TodoView._tap_fx`, called BEFORE the list changes; the
    row reaches the tap as its FIRST argument, since a later `bind` goes in front), and the sheet has a
    line "+20 XP for each one ticked off · N of 5 left today" (meta `todo_pays`). Keep it small.
  Tests: `tests/todos_test.gd`; walkthrough `tests/shots/todo.gd` (year data).
- A --script test that needs the App autoload must wait a frame and take `root.get_node_or_null("App")`
  (as doc_clear_test and todos_test do): `load("res://app/app.gd")` in `_init` fails to compile
  ("Identifier not found: Sfx"), and a test that errors there never quits. Run tests under `timeout`.
- Options for every movement, and a fuller day (2026-11-22, a screenshot of Coming up with "or Shrug
  (barbell)" under a lat pulldown and nothing under a GHD sit-up: "are there options like asked for,
  because GHD is only at gym and the home cable is there for lat pulldown so that's why I needed
  options... Want to display the movements and options for that movement"; and "will it only give me
  4 strength exs?").
  - `Missions.options_for` (at most `OPTIONS` 5), in order: the lift as done last; the player's other
    variations of the movement (two, never a PT one); the same lift at the other place
    (`other_place`: "... - Single arm home" <-> "... - Single arm gym", through `LiftNames.canon`);
    with none of those, a library variation on other equipment (`other_gear`: a plain sit-up beside
    the GHD one); then up to two movements of its FAMILY (`Missions.FAMILIES`, `family_of`: lat
    pulldown / pull-up / chin-up; row / seated row...; fly / pullover; press / push-up / dip...), the
    player's own first, then the library's on other equipment (`gear_of_lift`). One never done is
    `new` with no sets. The old "another movement of the same body part they have done" is GONE: it
    made a shrug a way to do a lat pulldown.
  - `stands_in` / `same_of`: a library movement is stood in for by its family only (`same.known`,
    `same.family`); a movement of the player's own, which has none, by the body part and kind as
    before. So a push-up no longer ticks a chest fly row, and a shrug never a pulldown.
  - `way_word(o, main_move)`: a way beside its movement's name ("dumbbell", "bodyweight" for a plain
    one, "Pull-up"). Missions say "Or: home cable, Pullover (dumbbell)"; the morning text lists only
    ways done before (an extra lift of the focus: all).
  - Screens: the Today card's OR chips (meta `lift_option`); Coming up shows the MOVEMENT, then its
    ways as tags (meta `lift_ways`): the one done last lit, "or", the others (never done yet: blue).
  - A fuller day: `PLAN_LIFTS` 6 STRENGTH lifts; physical therapy no longer takes one of those
    places (a PT lift ranking in the first six of everything is listed beside them, `PLAN_PT` 2 at
    most; the PT row has them all). A lift done only ONCE has no usual gap: on a day of its own
    kind (a split) it is planned as soon as it is two days old (it used to "rest" for half a week,
    so a lift tried on the last pull day was missing from the next).
  - The training focus is ON by default: `App.empty_saved()` settings have `focus: "upper"`, so a save
    that never chose gets it (the user had asked for the overhaul and found nothing changed: it had
    to be switched on). "" (From my log) is a choice and stays. `ShotHelper.demo_saved` and the
    walkthrough runner set "" so the walkthroughs start without one.
  - Tests: missions_test (options, families, stand-ins, six lifts, a once-done lift).
- THE DAY'S PLAN COMES FROM THE WEEKLY SET TARGETS (2026-11-22, after the options: "that doesn't seem to
  line up with getting enough volume... You planned out sets of volume for those areas based on my
  priorities and was that ignored for this?... the plan should go based off that"). It had been: the
  lifts from habit, the targets only a top-up when a muscle's week fell short, and none of it shown.
  - `Dose.day_target(t, have, freq)`: a muscle being built has a SHARE to get on a day that trains it:
    its weekly least / the days a week it is trained (`freq_of`: the 14 days before, 1 to 3), or what
    the week lacks when that is more; never past its weekly most, never over `DAY_CAP` 8.
    `Dose.extras` adds a movement when the day's usual lifts leave a muscle a set or more under that
    share (it used to wait until the week itself was short), not when that would pass the most.
  - `Dose.day_dose(lifts, ...)` -> `plan.doseToday`: per muscle of the day {have (six days before),
    today (the plan's sets: `planned_sets`, a half for "also works"), share, after, min, max, mode,
    state}. The Today card's row (`DoseView.row`, `DoseView.cell`) is the plan's sum: "Chest 3 -> 10 /
    10" = now, after today's plan, the weekly least; the colour is where the plan leaves it.
  - Coming up: every day carries `week` ({part: sets in the seven days ending that evening}); a day
    card has tags "Chest +7 -> 13/10" (meta `ahead_dose`); the sheet opens with "IF IT GOES AS PLANNED
    · SETS A WEEK" (meta `ahead_week`: the average of the days' weeks, since one day's seven days dip
    whenever a rest day falls in them). For that, `Missions.pretend_lift(..., with_new = true)` also
    pretends an extra lift never done (8 reps, no weight; named in `invented`) and `_as_planned`
    marks it new again in later plans (`planned` = its sets; shown as "4 sets", no weight to aim for).
    PhonePush.forecast does not pretend new lifts.
  - On a copy of the user's log the planned week came to chest 11.5, back 17.5, biceps 13, triceps
    13 sets (all in range), shoulders 23 (over, mostly half sets from rows and presses), legs kept.
  - A change to the plan must keep this true: what is planned has to add up to the targets, and the
    screens have to show the sum. Tests: dose_test (day_target, freq_of, day_dose), ahead_test (week).
- EVERY DAY IS A LIFT DAY; A REST DAY IS ONLY EVER THE PLAYER'S TAP (2026-11-23). Asked for in two
  steps the same day. First: "Need to be able to easily adjust strength days and rest days and move them
  back a day... feeling sore today so want to use today as rest day from strength, so I'll still run and
  do PT, but want to easily be able to push back the split one day, moving today's planned strength to
  tomorrow and having everything move back accordingly 1 day". The first version still planned a rest
  day by itself after five lifting days in a row and guessed days off from the weekdays lifted on, so a
  rest called today swallowed the one due tomorrow instead of moving everything. Then: "Don't need to
  adjust where rest days are planned, just have every day be a planned strength day but be able to kick a
  button to make a rest day for that day and push the split all back a day... I know that will mess up
  the planned sets of each muscle group a week, so it might be that in the plan I have a few groups that
  will exceed the number of volume, but I don't know when rest days will need to happen so it'll equal
  itself out".
  - NO RULE PLANS A REST DAY, and no day off is guessed. Gone: `Dose.REST_AFTER`, the "5 days in a row"
    rest day and its mission, `Missions.lift_habit` / `PhonePush.lift_likely` (the weekday rule of the
    look-ahead and of the phone's morning messages), a "lift" call. Whatever this file says above about
    a rest day coming due or a lift needing a weekday habit no longer holds. `Dose.rest` only counts
    lifting days in a row ({run, today}), for a line in the Weekly sets sheet. Do not bring a planned
    rest day back to make the weekly sets fit.
  - A rest day is a rest from LIFTING: `Dose.is_hard` / `hard_on` mean strength work only (a lift with
    more than PT and stretches). A run, a ride, a climb, a walk and PT are fine on one.
  - `settings.dayCalls` = {date: "rest"} (`Missions.call_of` -> "rest" or ""; `with_call(settings, date,
    rest: bool, today)` adds or takes back a call, and drops calls older than `CALLS_KEPT` 30 days and
    anything that is not a rest call: the first version stored "lift" too).
  - NOTHING IS MOVED BY HAND: the split goes by the last day really lifted (`day_kind`), so a day
    called rest leaves its lifts to the day after and every day after that follows, exactly one day
    later (on a copy of the user's log: Mon Pull, Tue Push, Wed Legs... becomes Mon rest, Tue Pull, Wed
    Push...).
  - `Missions.day_plan`: `plan.off` = called rest and no strength work logged that day (lifting on it
    makes it a lift day again), `plan.call`, `plan.set_aside` (strength lifts left out), `plan.rest` =
    {due (= off), call}. On an off day `plan.lifts` holds only the PT, there are no extras, no "try
    something new", no `doseToday`; `others` (the run on its day, the climb) and `pt` stay; `kind` /
    `label` still name the day that waits (`off_what`, `off_moves`: "Push day moves to tomorrow";
    `kind_why`: "Your call: push day moves to tomorrow").
  - Missions: on an off day `t:<date>:rest` is first IN PLACE of Show up ("Your call. No lifting
    today..."; done once the day is over without lifting), and there is no Beat it / dose / new
    mission. `morning_text` opens with "Rest day from lifting: your call. ..." and lists no lift.
  - `Missions.ahead`: `lift` = not called rest and `can_lift` (the plan has strength lifts), on every
    weekday; `rest` = the plan is off; each day carries `call` and `can_lift`. On a rest day the PT
    and the others are pretended. Without a training split a day still only has lifts when some are
    likely (by weekday or by their usual gap), so such a player sees days with nothing to plan.
    `PhonePush.forecast` pretends every day not yet lifted; `settled` also counts a day called rest.
  - With a split a day never comes out without its lifts. When no real lift of the day's kind is
    likely because they all still rest by their usual gap (lifts done once a week, and the split came
    round sooner), `day_plan` asks `likely_lifts(..., no_rest = true)`: a lift of the kind then counts
    once it is two days old. A stretch, a lift that goes with any day and PT are not the day's work
    (`day_work`): a day with only those would not move the split on (it showed with the demo data:
    two leg days in a row).
  - The weekly sets are planned as if every day is lifted, so "If it goes as planned" can read over a
    muscle's range (on the user's log: shoulders and triceps over, chest and back near their most).
    That is wanted; the card says "Counts a lift every day. A rest day you call brings these down."
  - Screens: the Today card's chip row is `TodayView._day_row`: the split's kinds and "Rest" (meta
    `rest_chip`; without a split: Lift and Rest). Rest tapped again, a kind, or the banner's "Lift
    today" (meta `lift_today`) makes it a lift day again; `_call_day`, `_pick_kind`. The header tag
    reads "Rest day"; the banner (`_rest_row(plan)`, meta `rest_row`) says "REST DAY · YOUR CALL",
    what moves, and that the run, PT and a walk are fine. Coming up (`AheadView`): every day card has
    a key in a slot of one width (`KEY_W`; a button with an icon sets its own width), "Rest" on a lift
    day and "Lift" on a day called rest (meta `ahead_call` = "<date>:<want>"); `_call` stores it and
    `_fill(sh)` rebuilds the sheet in place (the box never gets shorter while it is open; taps are
    ignored for `QUIET_MS` after one, since the opposite key is then under the finger).
  - Tests: dose_test (the off plan, calls, with_call, the rest mission, the morning text), ahead_test
    (every day a lift day, a call moves the split a day, a Sunday never lifted on), phone_push_test,
    walkthroughs focus, ahead and today.
- Cycling and vest walks are in a Miscellaneous corner (2026-11-23, "Move cycling and weighted vest
  walks completely to their own little miscellaneous area, don't have them as daily goals or as a main
  section anywhere, just as something I still can add or track but very sporadically").
  - Never a goal: `Missions.OTHER` is ["climb", "run"], so a ride or a vest walk is never in
    `plan.others`, never a daily or weekly mission, never in Coming up or the morning text, however
    often it was done. From the week of 2026-11-23 on no bounty monster is weak to cycling
    (`Bounty.SIDE_OUT_FROM`; the weeks before keep their weakness, so no past bounty changed).
  - Never a main section: `Misc.MAIN` = ["lift", "climb", "run"] is what a screen lists (the Log tab's
    three big keys, the Hero tab's three level tiles); `Misc.SIDE` = ["ride"]. The Log tab ends in
    "Miscellaneous": small keys for Cycling (meta `side_tile`) and each misc kind (`_small_tile`, meta
    `misc_tile`, the kind's short name). Journey -> Stats ends in "Miscellaneous" (meta `misc_area`):
    one line per activity ever logged (`_side_row`, meta `side_row` = "ride" | "misc:<kind>") that
    opens a sheet with its numbers (`_open_side`: the old cycling / vest walk card, the cycling level)
    and "Log one". Gone from the main screens: the cycling card, the "Longest ride" then-and-now
    chip and trophy-room plaque, the "ridden" fact. `App.next_goals` (the Hero tab's "Almost
    there") leaves out the goals of a `Misc.SIDE` discipline (the ported `NextUp` is untouched, for
    parity); the trophy cabinet's Cycling chip goes last.
  - The RULES are untouched: cycling is still one of `TT.DISCIPLINES` (level, records, trophies, gear,
    campaign bosses weak to it, parity), a ride or a walk earns exactly what it did, shows in the
    history, the week card, recaps and the reel, and still counts as load in the muscle map. A new
    main list must loop over `Misc.MAIN`, not `TT.DISCIPLINES`.
  - Tests: ahead_test (rides and walks never planned), bounty_test, walkthrough misc.
- Best splits inside a run (2026-11-23, "add an area to runs for certain splits within that run. So if I
  run 13.1 miles, game will automatically know to add a field to input my best mile, 5k, 10k split etc.
  Normal distances within that distance I ran"). `game/run_splits.gd` (`RunSplits`, pure).
  - STORED on the run: `session.splits` = {id: seconds}, only what was typed, absent when none. The rules
    do not read it (no XP, level or trophy), so parity is untouched. `DISTS`: 1k (asked of km players),
    mile and 10mi (asked of mile players), 5k, 10k, half, full; a split stored under any id is shown.
  - A run from `SHORT` 0.25% under a distance to `NEAR` 1% past it IS that distance (13.1 miles is a
    half marathon, 3.1 miles a 5K; 13.0 miles is not, see "A race distance counts from the miles it is
    written as"): `whole(distance_m)`. Its time is the run's own, with nothing to type (`of_session`
    adds it).
    `offered(distance_m, du, also)` = the distances clearly inside the run (`fits`), for the player's
    unit plus any that already has a time: 13.1 miles asks for the mile, 5K, 10K and 10 mile.
  - `parse_time`: a phone's number pad has a dot and no colon, so "7:45", "7.45", "7 45" and "745" are
    all 7:45; "1.02.03" / "10203" an hour more; one or two digits alone are minutes; seconds of 60 or
    more are no time. `fmt_time`, `pace`, `rows(session)`, `bests(sessions)` ({id: {sec, date,
    sessionId}}, of equal times the earlier), `records(before, fresh)` (only where there was a time to
    beat), `slower_than_run` (a BEST split slower than the run's average pace is a typing slip).
  - The run form (`LogSessionForm`: `splits` = {id: typed text}, `_split_ids`, `_fill_splits`,
    `_split_row`): a card "BEST SPLITS IN THIS RUN" (meta `splits_card`, hidden until the distance has
    one) under the distance, a row per distance (meta `split_row`; box fkey "split.<id>"), the time as
    read and its pace beside the box (meta `split_echo`; empty: "avg 8:48", what the run's average
    pace would make of it; "?" when it is no time or slower than the run), a line for what the run
    itself is (meta `split_whole`), a note when one is too slow (meta `split_note`). `refresh` brings
    the words up to date on every keystroke but refills the rows ONLY when the distances change, so a
    box is never rebuilt while it is typed in. `draft()` keeps the times of the distances that still
    fit, so making a run shorter drops what is no longer inside it. Only runs: not rides, not walks.
  - Shown: a session's sheet (`SessionView.split_rows`, meta `split_rows`: time, pace, a BEST tag, the
    run itself among them), Journey -> Stats' running card ("Fastest mile", "Fastest 5K"... chips), and
    the results reel (`App._split_events`: a "pr" card "Fastest 5K!" with the time it beat).
  - Tests: `tests/run_splits_test.gd`; walkthrough `tests/shots/splits.gd` (year data, also with
    `--fingers`). `ShotHelper.walk` only sees what is on screen: a hidden card is not found.
- Reps logged as both sides added up, "L+R" (2026-11-23, "There are some exercises where I am putting
  the total reps because they're split between two single arm movements. For example, my cable lateral
  raises, not dumbbell raises... I think I've done 12 and 13 reps in a set before, so I usually put the
  combined total... Need that to be differentiated somehow so that you or the app doesn't think I need
  to increase the weight because my reps are at 25... Add that differentiation for the single arm lat
  pull down... and add an option for the future when adding new exercises"). `game/sides.gd` (`Sides`,
  pure).
  - STORED: `settings.bothSides` = {normalized lift name: {name, on}}, ONLY where the player's switch
    differs from `Sides.USUAL`. A lift with no mark goes by USUAL: a Lateral Raise whose variation
    holds "cable" and a Lat Pulldown whose variation holds "single arm" are both sides with nothing
    stored (the phone's save could not be reached, so the two lifts the user named are a rule, not
    data), and switching one off sticks. A mark is on one lift, movement and variation together (the
    dumbbell raise is plain reps). `Sides.both(settings, name)`, `n` (1 or 2), `with_mark`, `renamed`.
  - The RULES do not know it and need not: a rep is a rep, so XP, records and the weight moved are
    right for the total, and parity is untouched. What goes by ONE side: the aim
    (`LiftTrend.next_target`: "too light, go heavier" only past `HIGH_REPS` a side = 30, and down to
    `DOWN_TO` a side = 20; before, sets of about 25 on a cable raise were told to go heavier and down
    to 10 reps), the estimated one-rep max (`LiftTrend.day().e1rm`), the rep ladder, the "change the reps"
    advice, and the training summary (`Dosage`: a part's "reps a set" and the rep bands count one
    side, each such lift is marked "[.., L+R]" with "(both sides added up: 12 to 13 a side)", and two
    lines say what L+R means so a chat does not read 25 as a set of 25).
  - HOW THEY KNOW: the SETS say so. `Sides.tag_sets(sets, 2)` / `tagged(history, 2)` make COPIES of a
    lift's sets with `"sides": 2`, and the tag travels with them: `Missions.day_plan` tags the planned
    lifts and every way to do them (`_tag_sides`: `l.last.sets`, `o.last`, and `l.sides` / `o.sides`),
    so the Today card, Coming up, the missions, the morning text and the note's plan need no change
    to aim right; the lift's page tags its history (`JourneyLifts.open_detail`), TodayView its STUCK
    check. Stored sets are NEVER tagged (the tests check the log after a plan and a save). A new
    place that makes an aim from a lift's sets must get them through a plan or tag them itself.
  - Screens: the lift's page has an "L+R" tag and a card "Reps are both sides added up" with a switch
    (`JourneyLifts._sides_block`, metas `sides_card`, `sides_switch`, `sides_tag`); a tap stores it
    (`App.set_both_sides`: no derive, the plan and missions are made again), draws the views above
    again and scrolls by what they grew or shrank (`_keep_in_place`), so the switch stays under the
    finger. "Next time" says "Both sides added up: 12 to 13 a side." (meta `sides_words`); Progress:
    "lb x 20 L+R best", "est. 1RM a side", "Best for reps a side" (meta `ladder_title`). The Log
    tab's exercise card has an "L+R" key beside BW and Hold (meta `both_chip`; a line "L+R · reps
    are both sides added up", meta `both_hint`; "Last ... · 12 to 13 a side"): it is part of the
    workout's draft (`exercises[i].both`, only once touched) and is stored when the workout is
    SAVED: `session_exercises` leaves `bothSides` on the exercise, `App.absorb_pt` stores it under
    the lift's final name and takes the flag off. The Today row's aim is capped "AIM · L+R".
    `App.rename_lift` keeps a lift what it was.
  - The results reel: the rules' "est. 1RM PR" card counts reps as logged, so `Sides.fix_estimates`
    (called in `App.commit_sessions`) works it out again for one side, or drops it when one side's
    estimate is no new best.
  - Tests: `tests/sides_test.gd`; walkthrough `tests/shots/sides.gd` (year data, also with
    `--fingers`). `Kit.section_title` is drawn in the pixel font: `ShotHelper.all_text` does not see
    it, so check a meta.
- The player's units where the rules write kg and km (2026-11-23, after I pointed out that the record
  cards said kg to a player who logs in lb: "Yeah always lbs"). `game/units.gd` (`Units`, pure).
  - The ported rules count in kg and km and their TEXTS say so: the results reel's record cards
    ("104.3 kg (was 102 kg)", "Longest run! 21.1 km", "Fastest pace (5 km+)!"), the XP labels ("12,340
    kg volume", "5.2 km", "80 m climbed"), the trophies ("Lift 100 kg in a set."), what unlocks gear and
    companions ("Run 100 km lifetime"). Those texts are NOT changed (parity compares them); the SCREENS
    show them through `Units`, by `settings.weightUnit` and `settings.distanceUnit` each on its own. A
    kg and km player sees everything as before.
  - `Units.text(s, settings)`: a text of the rules with its kg, km, km/h, "m:ss /km" and metres of
    elevation ("N m of elevation", "N m climbed") in the player's units. Numbers are as exact as a
    threshold needs ("Ride 62.14 mi in one go.", "Lift 132.3 lb in a set.", "Lift 2,204,623 lb
    lifetime."), but a race on foot is said in the miles it is written as ("Run 13.1 mi in one go.":
    `RACE_MILES`, see the next block); a text that says "exactly" (the on-the-nose trophies) is left
    alone; "Ride 160 km (100
    miles)" reads "Ride 100 mi" (`WHOLE`). Used for a trophy's words (the cabinet's tile and sheet, meta
    `trophy_desc`; the reel's trophy card), `Items.unlock_hint`, a companion's hint, flavour lines, the
    Almost there rows (`goal.sub`), the reel's XP tooltip.
  - `Units.records(events, before.prs, state.prs, settings)` (in `App.commit_sessions`, before
    `Sides.fix_estimates`): the reel's record cards written again FROM THE RECORDS, so 230 lb is not
    229.9 from a kg rounded to one decimal: a lift's weight and estimate, the heaviest hang, the
    longest run and ride, the fastest pace (its title too: "Fastest pace (3.1 mi+)!") and ride. Cards
    are found by the rules' own titles. `Sides.fix_estimates` writes its one-side card in the unit too.
  - `Units.xp_label(session, label, settings)`: a session's XP chips (`SessionView`) from the
    session's own numbers (a lift's volume, a run's distance and climb, a vest walk's load).
  - A NEW text with a weight or a distance must be made with `Fmt.*` and the settings, never with a
    unit typed into the string; a text of the rules shown somewhere new goes through `Units.text`.
  - Tests: `tests/units_test.gd` (it also sweeps every trophy, gear hint and companion hint for a kg
    or km left over); walkthrough `tests/shots/units.gd` (year data).
- A race distance counts from the miles it is written as (2026-11-23, afternoon). With the trophies
  now reading in miles it showed that a run typed as 13.1 miles is 15 m short of the Half Marathon
  trophy's 21,097 m. Asked whether runs typed as 3.1, 6.2, 13.1 and 26.2 miles should earn the race
  trophies and gear, the user said "Yes". This IS a change to the ported rules, made on request.
  - `RunSplits.SHORT` (0.25%) and `RunSplits.counted(distance_m)`: a run up to SHORT under one of
    `RunSplits.DISTS` counts as that distance: 3.1 miles (4,989 m) is a 5K, 6.2 a 10K, 13.1 a half
    marathon, 26.2 a marathon; 3.0, 6.1, 13.0 and 26.1 miles are not; in kilometres 4.99 counts and
    4.98 does not. Any other value comes back as it went in (a whole number stays one). It is used
    by the getters of the trophies `run_5k`, `run_10k`, `run_half`, `run_marathon`, of the gear
    `race_bib`, `carbon_racers`, `marathon_medal`, and by the pace record in `Derive`
    (`bestPaceSecPerKm`, runs of a 5K or more: so a 3.1 mile run counts for it and for the
    `run_pace_*` trophies, at the pace it was really run). `prs.longestRunM` and every other record
    stay as typed. Everything is replayed from the log, so such runs already logged earn their
    trophies the next time the game works the hero out; nothing has to be entered again.
  - NOT changed: sums ("Marathon Month", lifetime kilometres), the secret "exactly 5.00 km" trophy,
    and every ride (a ride typed as 62.1 miles is still short of the 100 km trophy; cycling is a side
    area and was not asked about).
  - `RunSplits.whole` has the same lower edge (SHORT under, NEAR past), so a run the run form calls
    a half marathon is one that earns the trophy. Before, 13.0 and 26.1 miles were "a half" and "a
    marathon" for the best times.
  - Words: `Units.RACE_MILES` says those four distances as 3.1 / 6.2 / 13.1 / 26.2 mi, only in a text
    about ONE run (`Units._one_run`: "in one go", "km+", the marathon medal's line; never a ride, a
    month or a lifetime, which stay exact: "26.22 mi"). units_test checks that every race trophy and
    piece of race gear is earned by the miles its words say and not by a tenth of a mile less.
  - Parity still passes: no fixture has a run in those few metres. Tests: run_splits_test (the rules
    through `Derive.derive`), units_test; walkthrough units.
- "From today's plan" in the Log tab's lift form, and exercises moved up and down (2026-11-23, late
  afternoon). The user, in the middle of a workout: "it's annoying to have to click on it, press add
  to workout, then go back to hero page, then repeat. When going to log, have it maybe have an area
  that says 'from suggested workouts' based on the goals and volume we have planned and easily be
  able to add/remove from workout as I go", then "Add a way to bump exercises up and down in order
  too, helps to decrease scrolling while super setting".
  - `Missions.picks(plan, sessions, today)` (pure): the day's plan as rows in the Today card's order:
    what the focus adds ("extra"), the likely lifts ("lift"; a PT lift of the plan is "pt"), the
    movement to try ("new", its `alts` as ways), then PT still needed that has no row. A row: {kind,
    name (the way it was done last), move, variation, new, pt, part, last, sides, why, ways [{name,
    word, new}], done (the lift it was done as today, any way: `lift_done` / `new_by`), lift (the
    plan's lift; null for "new" and a bare PT row)}. `Missions.way_label` words a way.
  - `ui/screens/log_plan_card.gd` (`LogPlanCard.build(editor)`, meta `plan_card`): under the workout's
    exercise cards and above "Add exercise"; first of all (before "Repeat a workout") while the
    workout is empty. Only for a workout dated today: a new one, or today's saved one opened again
    (then the session in the form is left out of what counts as done). Header: the day's label, rows
    seen to / rows (meta `plan_count`), Hide / Show (`LogPlanCard.folded`, static; meta `plan_fold`).
    A row is one wide key (`LogWidgets.key`; meta `plan_pick` = the lift, `plan_state` = add / in /
    done): a box (plus, tick), the movement and its variation in a squeeze row, a tag (FOR CHEST, NEW,
    PT) and what to aim for on a line of its own (`TodayView.aim_words`, which the Today card's rows
    use too). Under it the other ways as chips (meta `plan_way`), each a key of its own.
  - `LogLiftEditor.plan_toggle(name)`: not in the workout -> added with last time's sets, `planned:
    true` (Finish asks "Done as shown?" about the ones never touched, as after Start workout); in it
    and still planned -> taken out; in it with the player's own numbers -> a toast, it stays (its
    card has the cross).
  - Up and down: every exercise card has two keys in its foot row, after "+ Set" and the bump chips
    (`_move_key`; metas `move_key` = up / down, `move_of` = its place; only with two exercises or
    more; the first one's up and the last one's down are there, switched off). NOT at the row's right
    end: that is under the column of the set rows' crosses, and the foot row slides there when the
    last set is taken off. `move_exercise(i, d)` swaps the exercise with its neighbour: its sets,
    `planned`, the records already celebrated (`_pr_done`) and the typing cursor go along.
  - Nothing moves under the finger. A plan key's unseen Button text ("Plan: <lift>"), a way chip's
    word and a move key's tooltip ("Move <lift> up") are the same in every state and name the LIFT,
    so `UiScreen` finds the key of the same lift again after the rebuild and keeps it where it was:
    the cards above come and go, a moved card takes the view with it, and a second tap on its up key
    moves the same exercise again. A new key here must keep to that: never change a key's text with
    its state, never name it by its place.
  - Where the page cannot follow (a card moved to the top with the page at its top, a lift taken back
    with little above it, a picker key that is gone once tapped) the key cannot stay, and the next
    tap would land on whatever slid there: a stepper, another card's key. `UiScreen.guard_shifts`
    (on for `LogScreen` only): after a rebuild that could not keep the pressed control in place
    (`_anchor_moved`), left presses are dropped for `QUIET_MS` 350 (`UiScreen.quiet_until`, read in
    `_input`). A walkthrough that makes real clicks on the Log tab waits that long after a tap that
    shifts the page (`tap` in picks.gd).
  - On the Log tab's FIRST screen too (the same evening; the user, looking for it there after the
    publish: "shouldn't it pop up as suggested like I asked earlier when going to log a workout?").
    `LogPlanCard.picker()` (meta `plan_picker`, count meta `plan_left`), between Reading and
    Miscellaneous, lists the rows still to do today (the done ones are left out; a lift the kept
    draft already holds is ticked). A row's key or a way's chip is `_open_with(lift)`:
    `App.pending_workout = [lift]` and `App.open_log("lift")`, so the lift form opens (the kept
    workout, else a new one) with that lift in it, planned. `LogLiftEditor.build` now marks a
    never-done lift that comes from `pending_workout` planned too. Both cards are filled by one
    builder (`_fill`, `_row(ctx, r, here)`; `ctx` = {wu, sessions, last, tap}).
  - Also fixed: `App.set_pt` / `set_pt_goal` clear the cached plan, missions and look-ahead (a lift
    marked PT kept its old row on the Today card until something else changed).
  - With the plan card the lift form is long enough to scroll even with one exercise: the touch
    walkthrough waits for its drag's glide to end before it holds a stepper.
  - Tests: missions_test and dose_test (`picks`); walkthrough `tests/shots/picks.gd` (year data, also
    `--fingers`): add, take back, the other way, a touched lift stays, every key under the pointer on
    every frame, up and down, the guarded second tap, fold, done after saving, no card on another
    day. long_names snaps the card with long names.
  - Held back while it was built: the user was in the middle of a workout ("Don't push anything to
    phone yet... don't wanna mess with refreshing the app"). Published and pushed that evening on
    their word ("go ahead and publish all the unpublished changes"), as build 20261123-170924-4f7936e5.
- How a new exercise's name will be filed, said as it is typed (2026-11-23, evening). The user: "If I
  want to add new exercises, how do I add the variations? Like I don't just type in 'March - banded'
  right because it takes that as the full name and not the exercise plus the variation modifier?" It
  does not: `App.absorb_pt` files a name typed in the Log tab through `LiftNames.resolve` when the
  workout is saved ("March - banded" -> "March - Band": the dash splits movement and variation;
  equipment and place words need no dash, so "banded march" is the same lift; other words without a
  dash are the movement: "High Knee March"). But nothing said so until after the save.
  - `LogLiftEditor.filed_as(typed)` (the same steps as `absorb_pt`: `Pt.untag`, a lift of the log
    keeps its name, else `LiftNames.resolve(n, App.lift_names())`; null for an empty name, a lift of
    the log, and a session from the phone note, whose names are not filed), `filed_words`,
    `filed_tip` (a movement of the player's own typed without a variation: "A variation goes after a
    dash: <Movement> - banded").
  - Under an exercise's name (`_refresh_filed(i)`, slot `_filed[i]`, metas `filed_as` = the name it
    will have, `filed_tip`): "SAVED AS", the movement, the variation as a tag, a PT tag. Only for a
    name that is new to the log; it follows the name as it is typed (`_on_name_typed`).
  - Under the search box (`_no_match`, now a label that wraps; meta `filed_as`): "New exercise: tap
    Add. It is saved as March, variation Band." when no key matches what is typed.
  - `LiftNames.resolve` takes 1 to 5 ms on the PC and now runs on each keystroke of a new name.
  - Walkthrough: `tests/shots/filed.gd` (year data, also `--fingers`): what the line says is what the
    saved workout holds.
  - Also that evening: `LogSessionForm._set_date` rebuilds the lift form when the date leaves or
    reaches today, so "From today's plan" goes (or comes back) at once. It used to stay until the
    next tap and vanish under the finger.
- "New version ready" in the phone app (2026-11-23, late evening). After a publish the user did not
  see the change, then: "its up there now, i must not have updated it correctly before". The service
  worker fetches a new build in the background and the page on screen stays the old one until the
  app is started again, and nothing said so.
  - `web/tt.js`: `window.ttUpdate` = {can, ready(), check(), restart()}. `ready()` turns true when a
    worker takes over from another one (`controllerchange` with a controller there before: the first
    worker ever is not an update). The page also asks the site for a newer worker when the app comes
    back to the front, at most every 10 minutes (a Home Screen app can stay open for days, and the
    browser itself only asks when a page is loaded). `restart()` reloads after 900 ms (the last save
    is still on its way into the browser's storage). Nothing restarts by itself.
  - `app/web_update.gd` (`WebUpdate`: `can`, `ready`, `check`, `restart`; `pretend` = "idle" | "ready"
    for a walkthrough on the PC). `main.gd` asks every 4 s on the web (`_ask_update`): once it is
    ready, one toast and `App.changed`, so the Hero tab shows `PhoneAppCard.update_card()` (meta
    `update_card`, key meta `update_restart`) above the backup card, and Settings -> Phone app its
    row (`PhoneAppCard.update_row()`, metas `update_row`, `update_key` = restart | check: "Check now"
    while there is nothing newer).
  - Tried for real 2026-11-23 in a hidden Edge on the PC (the built-in browser cannot register a
    service worker; `msedge --headless=new --remote-debugging-port` with a scratch profile, driven
    by a Node script over the DevTools port, the build folder served on http://localhost): build A
    open and kept by its worker, build B made, `check()`, B fetched, `ready()` true while the page
    still shows A, `restart()` loads B, the old build's files gone a moment after the switch. In
    the built-in browser with `ttUpdate.ready` stubbed: the toast, the Hero card, and Restart
    loading the page again. Such a hidden Edge leaves helper processes behind: stop every
    `msedge.exe` whose command line holds the scratch profile folder, and only those. NOT tried on
    an iPhone (Safari's worker).
  - The build a phone is on when this is published has no notice yet: that one update still needs
    the app closed and opened again (twice at worst).
  - Walkthrough: `tests/shots/update.gd` (year data, also `--fingers`).
- Softer clicks, and a tick in the hand with every tap (2026-11-23, night). The user: "work on the
  sound effect of clicks. The sound is really jarring, make it more satisfying/clicky/bubbly. I like
  the Stardew Valley sound effects when harvesting... Also can you add some haptic feeling during a
  click or not on iPhone".
  - What grated: every key played `tick` as it went down (`Kit.juice`), a bare 880 Hz SQUARE wave. At
    22,050 samples a second a square's overtones fold back, and a fifth of its energy sat above
    2.5 kHz. And a key's own tick and the sound its handler asked for played on top of each other.
  - `Sfx.CLICKS` (app/sfx.gd): `tick` (a key going down), `tap` (opening, moving on), `pop`
    (something added: a set, an exercise, a lift from the plan), `unpop` (taken away again). All
    sine: a soft pop whose pitch glides up (a bubble) or down, with a quiet octave over it for the
    click. Nothing above 2.5 kHz. A note of `_render` can now glide (`{"to", "glide", "attack"}`,
    the phase added up sample by sample). Each click is played a little higher or lower than the
    last (`CLICK_DRIFT`); `Sfx.step(dir)` (a stepper) is higher for plus than for minus.
  - One click a frame: `_click_sound` only notes what was asked for, `_process` plays the LAST one
    (so a key's tick and its handler's `pop` are one sound, the handler's). A new click sound goes
    in `CLICKS`; do not use square or sawtooth for anything heard at every tap.
  - The fanfares (xp, claim, level up, record, drops...) are as they were: square and triangle
    notes. Not asked about.
  - Haptics: `Sfx.click()` (a key going down: `Kit.juice`, a `Card`) and `Sfx.step` also ask for
    `buzz(1)`. `Sfx.buzz` asks AT ONCE, never a frame later: an iPhone only ticks from inside the
    finger's own event (web/tt.js clicks a hidden `<input type="checkbox" switch>`, which ticks on
    iOS 17.4 and later; Android: `navigator.vibrate`), and a tap's click is made inside the lift
    (TouchScroll). Buzzes `BUZZ_GAP_MS` (90) apart or less are one: a tap is one tick, and a longer
    buzz right after it only adds what is missing (`ttApp.buzz(n, felt)`). Settings -> Phone app:
    "Taps you can feel" (`settings.haptics`, as before).
  - Checked 2026-11-23 in a phone-size browser with made-up touches and `ttApp.buzz` wrapped: a key,
    a stepper and "+ Set" each ask for exactly one tick, from inside the touchend; a tap on empty
    space asks for none; Finish asks for 1 then 2 (one more, 110 ms later). `window.ttEval` runs
    its GDScript at once, inside the JS call: that is how to tell what happens inside an event.
    Whether the iPhone really ticks can only be felt on one: NOT felt by anyone yet. The second
    tick of a longer buzz comes from a timer, outside the event, and may not tick at all there.
  - The sounds were measured, not heard: `tests/sfx_test.gd` renders them and checks they are sine,
    quiet, short, start at once and have nothing above 2.5 kHz, that a pop rises and an unpop falls,
    and that a frame plays one click (the last asked for). A before / after WAV made from the same
    renderings was sent to the user for a listen.
- One exercise under two names, and where a muscle's sets come from (2026-11-23, night). The user,
  with a screenshot of Coming up (a push day: "Shoulders +9 -> 30.5/8", a Tricep Pushdown row AND a
  Tricep Extension - Cable row): "Why is shoulders so high? Is it just from secondary movements.
  Also, Tricep extension and push down are the same thing but both are listed in same workout."
  - `Missions.SAME_MOVES` and `Missions.move_of(lift)`: two entries of the lift library that are one
    exercise in the gym are PLANNED as one movement. A Tricep Extension whose variation holds
    "cable", "rope" or "bar" (and not "overhead", "lying", "incline") is a Tricep Pushdown. Every
    place the plan asks which movement a lift is goes through `move_of` (`likely_lifts`' groups,
    `options_for`, `stands_in` / `same_of`, `done_of`, `new_by`, `lift_done`, the missions), so the
    day lists it once (named as it was done last, the other name among its ways), either name ticks
    the row, and it is one row in `Dose.sources`. Nothing in the log is renamed: history and
    records stay per name, and Journey -> Lifts still shows two movements (the user can join them
    with "Rename or move this lift"). Another such pair is one more row in `SAME_MOVES`.
  - The shoulder number was real, not a slip of the count: on a copy of the PC's log, the week had
    lateral raises and an overhead press on each push day (three push days inside the seven days)
    plus face pulls, about two thirds of the sets; the rest were half sets from flyes and presses
    (front of the shoulder) and rows (rear). Half sets are not counted twice for a lift's own
    muscle (`Dose.add_lift`).
  - `Dose.sources(sessions, marks, today)`: {part: [{move, direct, half}]}, the most first; it adds
    up to `Dose.window`. The Weekly sets sheet (`DoseView.open`) lists them under every muscle:
    "Direct: Lateral Raise 9, Overhead Press 6" and "Half sets from: Chest Fly 4.5, Bent Over Row 3"
    (metas `dose_direct`, `dose_half`).
  - Coming up: a day's tags say the week against its WHOLE range ("Shoulders +9 -> 30.5/8-16"; the
    least alone read like thirty of eight) and end in a "What counts?" key (meta `ahead_why`) that
    opens the Weekly sets sheet.
  - NOT done, and asked of the user: the plan does not drop or mark as optional a lift whose muscle
    is already past its weekly most. Usual lifts are planned whatever the week holds; only the
    focus's extra lifts look at the range.
  - Tests: missions_test (`move_of`, a day planned once, either name ticks it), dose_test
    (`sources`); walkthroughs focus and ahead.
- The weekly sets count the shoulders as three, and the plan follows where a lift is done (2026-11-23,
  night). The user, with the Weekly sets sheet (back 28.5, shoulders 23, biceps 19, chest 7.5): "the
  only real lateral delts I do are lateral raises so the number just is so high... more specific for
  shoulders like posterior anterior lateral... Should I shift 1 shoulder activity to my pull day to
  open space for another chest/Tricep on push day?"
  - `Dose.PARTS` (this count only): chest, back, front_delts, side_delts, rear_delts, traps, biceps,
    triceps, forearms, core and the legs. `Dose.main_part(lift)`: the body part (`Dosage.part`), a
    shoulder lift as its head (`HEADS` by movement, else `head_of` by its words: rear / front, else
    side), a shrug as traps (`TRAPS_MOVES`). `Dose.also_of(lift)`: {part: share} from the library's
    "also works" (`Dose.ALSO_WORDS`, the most precise words first), half a set each unless `TOUCH`
    says otherwise (a fly gives the front delts a quarter; an overhead press also gives the side
    delts a half; a rear delt fly the back a quarter), never the main muscle. `add_lift` uses both.
  - Targets ("upper" and "balanced"): side delts [8, 16, build], rear delts [6, 16, build], front
    delts [0, 12, keep] (every press works them), traps [0, 12, keep]. `Dose.NOTES` puts a line under
    each in the Weekly sets sheet. `Dose.KIND_PARTS` (push: chest, front and side delts, triceps;
    pull: back, rear delts, traps, biceps), `Dose.AREA`, `Dose.NAMES`. `parts_today(kind, group,
    lifts, marks)` also takes the main muscle of every strength lift planned.
  - The plan's body parts, the muscle map (Recovery) and the training summary (Dosage) still say
    "shoulders". The half-set rule itself stays: it is how volume is usually counted (a row trains
    the biceps about half as much as a curl), so the biceps' "from other lifts" is real.
  - `Missions.done_kinds(sessions, today, marks)`: a movement whose last 3 times were on days of one
    kind (kind_of_day with pull, push, legs) at least twice, while days of its own kind were lifted
    without it meanwhile, is planned on that kind of day (`likely_lifts`, and the focus's
    `more_options`). Lateral raises moved to the pull day go there after two pull days; a full-body
    day (a "leg" day by its majority) moves nothing; done on push days again, they go back.
  - On a copy of the PC's log (Nov 15-21): side delts 10.5, rear 5, front 5.3, traps 1, where one
    "shoulders" number had been about 21.
  - The Today card's row (`DoseView.row`) shows the muscles being built first; a muscle with least 0
    (front delts, traps) only when there is room, and is read against its most ("3 -> 9.5").
  - Tests: dose_test (heads, `also_of`, `done_kinds`), missions_test, ahead_test; the walkthroughs
    were held while the user played a game on the PC and run once they were off it.
- Books: a shelf of finished books and a bookmark that does the page math (2026-11-23, night). The
  user: "create a bookshelf with my finished books. And to not have to figure out the number of pages
  each day, just putting the page number I finished on when I do read and have the app do the math."
  - `game/books.gd` (`Books`, pure). STORED: `saved.books` = [{id, title, author, series, num, pages
    (its length, 0 unknown), status "reading" | "finished", finished (day or ""), page (the bookmark),
    log {day: [from, to]}, at}] (kept by `App.parse_saved`, in `SaveMerge.RECORD_LISTS`). Nothing in
    the rules reads it.
  - The page math: `Books.set_page(book, page, day)`: a day's pages of a book are `to - from`, `from`
    being the bookmark as the day began (`start_of`); typing again the same day replaces the day's
    end (a correction corrects, `delta` can be negative); the next day starts where the last ended.
    `App.set_book_page(id, page)` puts the `delta` into today's reading (`set_reading`), so XP, the
    level and the streak work as for any pages; pages typed by hand (+N) stay beside it.
  - Books added as finished (read before the game) add NO pages to the log: the shelf only says them.
    A book started with a page ("reading, page 249") has that bookmark and nothing read yet today.
  - `Books.parse_list(text)`: books split by ";" or new lines (the phone's typing field is one line),
    `Title | Author | Series 1 | 541 pages | reading, page 249`; only the title is needed, finished
    unless it says reading or a page. `App.add_books` leaves out a book already there (title and
    author, any case). Also `set_book_finished`, `update_book` (the bookmark set there moves no
    pages), `remove_book` (its pages stay in the reading log).
  - Screens: `ui/screens/book_view.gd` (`BookView`). The Hero tab's reading card shows the book being
    read (`card_rows`, meta `book_row`: title, series tag, progress, "+51 pages today (from p. 249)",
    "Stopped on page [box] Save", metas `book_page_box`, `book_page_save`) IN PLACE of the +N keys;
    Done on the keyboard saves too. Its last page asks "Finished ...?" (`finish`: the shelf, a
    fanfare). The reading sheet: "Reading now" cards (meta `book_card`, "Finished it"), the bookshelf
    (meta `bookshelf`: `ReadingView.Shelf` now draws real spines, `Books.spine`: thicker for a longer
    book, a series keeps its colour; the titles under it, newest first, meta `shelf_book`, a tap opens
    the book's sheet `open_book`: title, author, series, length, bookmark, Finished / Reading it again,
    Remove), "Add a book" (meta `book_add`: title, author, length, on page; Start reading / Already
    read) with "Add several at once" (meta `book_paste`). The old shelf of "a book per 100 pages" is
    gone from the screen; `Reading.books` stays for its trophies.
  - The user never pasted their books, and with no book being read typed the page they stopped on as
    the day's pages. Repaired once by `app/fixes_local.gd` (LOCAL ONLY, never committed: it holds
    their books and that day's numbers; `sync_clone.py` skips every `*_local.*` file): the day's
    pages set right, their books added, the book being read given its bookmark and that day's log.
    `App._local_fixes` runs it at start in the web build only (`TINY_TITAN_FIX_TEST=1` on a scratch
    save), after the daily backup, once (`settings.fixes`). Test: `tests/fixes_local_test.gd` (local
    too). Built into 20261123-220030. Delete both files once the user confirms it is right.
  - Since then: with no book being read the reading card has "+ Add the book you're reading", and the
    day editor says its box is a count of pages, not a page number.
  - Tests: `tests/books_test.gd`; walkthrough `tests/shots/books.gd` (year data, also `--fingers`).
- Physical therapy is ONE goal, not single lifts of the plan (2026-11-24). The user: "Make it so individual
  PT exs don't go into the missions or plan for the day. There are individual ones and also a goal for
  doing 5+ etc, just keep that one."
  - `Missions.day_plan` leaves every PT lift out of `plan.lifts` (`PLAN_PT` is gone): no PT row among
    "PROBABLY TODAY", no box of its own, no line of its own in the morning message, none in Coming up's
    lift rows. What stays: `plan.pt` (the PT still needed this week) and everything made of it as a
    whole: the Today card's PT row and box, the daily "Physical therapy" mission (target = how many),
    the weekly "PT on target", the "PT:" line of the morning and evening messages and of Coming up.
  - Also out: the Log tab's "From today's plan" has no row per PT exercise (`Missions.picks`), and Start
    workout sends no PT (`TodayView.workout_names`). PT exercises are added from "Add exercise".
  - A rest day's plan therefore has no lifts at all; its PT row stays.
  - Tests: missions_test (one row, one box, one mission, the morning text); walkthroughs picks (a
    PT-marked lift has no key) and today (does every planned lift before the chest: a lift due by its
    gap shows up on some weekdays, which made it fail on a Tuesday).
  - THREE A DAY, NOT ALL (2026-11-24, "Make it so I'm not having to do every single PT exercise each
    day, aiming for 3+ per day"). `Missions.PT_A_DAY` 3; `pt_goal(plan)` = 3, or fewer when fewer are
    still needed this week (`plan.pt`, furthest behind first); `pt_today(plan, sessions, today)` = the
    PT lifts done today with sets, each once, ANY of the player's PT lifts (one already on target this
    week counts too); `pt_left` = the ones still needed and not done today. The daily mission's target
    is the goal ("Do 3 today, any of: ..."; the id is unchanged), the Today box and row tick at the goal
    (pips of the goal, "Any 2 of: ..."), the morning text says "PT: 3 of ...", the evening "PT: 1 more,
    any of ...", the look-ahead pretends only the goal's worth (the furthest behind). The weekly "PT on
    target" (every lift's days a week) is unchanged: with many PT lifts it may not be reachable at three
    a day; the per-lift goals are on the PT sheet.
  - COUNTED IN SETS (2026-11-25, "making it total sets instead of exercises. Sometimes I'll just do a set
    and want to make sure that doesn't get counted as much as if I did 3 sets of the same thing"; their
    PT is nearly always 3 sets an exercise). `Pt.SETS_A_DAY` 3: a day of a PT lift counts up to 3 of its
    real sets, so one set is a third of a day. The stored goal stays `perWeek` DAYS; the week's target is
    perWeek x 3 sets. `Pt.status` rows add `daySets`, `sets` (this week's credit), `setsGoal`,
    `weekShare` (7 shares 0..1: `WeekBars.Dots` part-fills a day); `left`, `state`, `weeks[].n` / `hit`
    and `Pt.summary` are in SETS; `thisWeek` (days) stays. `Pt.row_of(sessions, marks, lift, today)`.
    The day: `Missions.pt_goal` = min(9, the sets the PT lifts still need, at most 3 each), `pt_today` =
    today's sets per PT mark, each capped at 3 (two sessions of a day add up), `pt_left` = PT lifts under
    3 sets today. The mission "Do 9 sets today, up to 3 of each exercise: ...", the Today row "4 of 9
    sets" with "Up to 3 sets of each count. Any of: ...", morning "PT: 9 sets, up to 3 of each: ...",
    evening "PT: 5 more sets, any of ...". The PT sheet, the Hero's PT section, the lift page's PT card
    ("N of M sets this week", `PtView.aim_words`: "days a week · 3 sets a day") and the Logbook's PT
    bars all count sets.
- Resistance bands instead of a weight (2026-11-25, "can we add a way to add bands to exs, instead of
  weight for resistances"). `game/bands.gd` (`Bands`, pure): the ladder light to heavy yellow, orange,
  red, green, blue, black, purple, silver, gold (most therapy bands; a brand may differ), `DEFAULT`
  red, `level`, `name_of`, `words`, `color_of` (real-world swatches, consts), `text_color`, `step`,
  `is_band`, `top`, `of_name` (a colour in the variation), `says_band`. STORED on a set: `{reps,
  weightKg: 0.0, band: "<id>"}`: the rules see a bodyweight set (no XP or parity change). Carried like
  `holdSec` wherever sets are copied (LiftLibrary.stats, SessionView, the kept draft in
  `LogSessionForm._take_draft`). The phone note's "blue band" in a Weight cell still becomes part of
  the name (unchanged; the note is PC only).
  - The Log tab's exercise card (rebuilt 2026-11-25 for the PT key below): the name and the cross on
    their own line; under them a pick-one track `Kit.choice_track` of `LogLiftEditor.MODES` (Weight,
    BW, Band, Hold; meta `mode_key`; the Band key also `band_chip`), then L+R (switched off, not
    hidden, for a hold) and PT. Every key is always there, so none moves when one is tapped.
    `_mode_of(e)`, `_set_mode(i, m)` (the lit key tapped again goes back to Weight; `_toggle_bw` /
    `_toggle_timed` / `_toggle_band` call it). Draft `band: true`, set rows `band`; into Band every set
    gets this lift's last band, else the name's colour, else the band used last, else red. A new lift
    that `says_band` starts with a band. The set row: `BandPicker` (`ui/widgets/band_picker.gd`:
    lighter key, a fixed-width pill in the band's colour, heavier key; metas `band_of` "i:j",
    `band_key`) changes the band IN PLACE (`_on_band`), "+1 band" (meta `band_bump`), "+ Set" copies.
    Badges "+1 band" / "-1 band", "PR!" for a heavier band than ever.
  - `LiftHistory.describe_sets`: "3×15 · green band", "15, 15, 12 · red band". `LiftTrend`: `day().band`
    (level) / `bandId`, series "band", compare / pairs by band then reps, `records` "Heaviest band",
    `next_target` kind "band" (+1 rep to `BAND_HIGH_REPS` 20, then the next band at `BAND_DOWN_TO`
    12), `banded`, `main_value` / `best_row` with `in_band` (an older weightless day of the lift ranks
    below every band day); no ghost, plateau or strength-standard card for a band lift. The lift page:
    band words and pills, Progress metrics Band / Reps, Logbook blocks by band level, records tiles.
    The Beat it mission says "Past 20 reps a set the band is too light: the next band up".
  - Tests: `tests/bands_test.gd`; walkthrough `tests/shots/bands.gd` (year data, also `--fingers`).
- The PT key (2026-11-25, "a way to tick an exercise as PT while adding it, instead of having to go back
  and do it after logging"): on every exercise card, beside L+R (meta `pt_chip`). Lit when the lift is
  PT, or "(PT)" is typed in front of the name, or the key was tapped (draft `pt`, only once touched;
  `LogLiftEditor._pt_on`). A line says what saving will do (meta `pt_hint`, `_pt_words`).
  `session_exercises` passes `pt` true / false; `App.absorb_pt` marks the lift, or takes its mark off
  (off also drops a typed "(PT)"). Tests in bands_test and the bands walkthrough.
- The Hero tab's look (2026-11-24). The user: "Visuals are getting clunky with everything we've added... Things kinda
  blend together and are hard to look at and get a clear idea of each section and thing within them". Three design reviews,
  a mock-up the user approved ("Looks good. Can add all, plus take out the how am I feeling question"). Nothing removed but
  the Feeling row; no rule or number changed.
  - Shared pieces (ui/kit.gd, top comment; ui/widgets/card.gd): `Kit.section(id, title, icon, color, right, tap, sep, pad)`
    = one Card with a band across its top (`Pal.band(color)`, the title in pixel letters, `right` at its end: a count, a
    link, a key) and a frame in that colour; `Card.with_head` makes `add()` fill the body; meta `section` = id (pixel
    letters are not Label text: tests find a section by this meta). `Kit.row(tap, stripe, tint, pad, sep, amount)` /
    `Card.flat`: a row INSIDE a section is a flat `Pal.slot()` fill with a 4 px stripe down its left edge, never a raised
    card in a card. `Kit.sub_head` (a group inside a section), `Kit.choice` + `Kit.choice_track` (pick one: a sunken track,
    the picked key raised, both the same height), `Kit.option_chip` (an OR alternative: outlined, neutral, blue = never
    done), `Kit.tick_box` (every done box: an empty well, solid green with a tick), `Kit.pips`, `Kit.notice` (the slim rows
    above Today). `Bar.extra` (faded: today's plan after what is done) and `Bar.mark` (a target line). `Kit.link(..., color)`.
  - The colour rule (top of ui/pal.gd): gold is a reward or THE main action (XP, coins, the level, the chest, Claim, Start
    workout), never a target or a frame for everything (aims are white now); a section's colour is what it is about or the
    tab it leads to; GOOD = done, ACCENT2 = a warning, DANGER = stuck.
  - The page (`HomeScreen`, `SECTION_GAP` 22 between sections, 6 to 8 inside them): top bar; notices (phone note, new
    version, backup, recap); TODAY (`TodayView.card`: the date and why, the split track with Rest, the body row = muscle tile
    `RecoveryView.tile` + `DoseView.row(plan, true)` + a "Recovering: ..." line, YOUR FOCUS ADDS, PROBABLY TODAY with the
    shared reason and "N of M done" in its sub-head, the lift rows (name, then cap + aim on their own line, OR chips), try
    something new, physical therapy, Start workout, run / climb, the perfect-day chest with pips); COMING UP
    (`AheadView.card`, a section of its own); TO DO; READING (moved up: its page box is filled daily); MISSIONS (`_missions`:
    yesterday's and today's done ones as `Parts.quest_list(..., true, true)` rows with their Claim key, the rest as
    `Parts.mission_grid` tiles two across; the perfect-day mission is the Today chest, not listed here); the hero card (no
    ring; the companion's line in a quiet bubble inside it); ADVENTURE (`_boss_row`, red, and `BountyView.card(false)`, now a
    violet row); PT THIS WEEK; PROJECTS; YOUR WEEK (level tiles, streak row, This week row); ALMOST THERE; RECENT.
  - Gone: the Feeling row (`TodayView._feel_row`) and the PC morning message's "How do you feel?" buttons. `settings.feels`,
    `Missions.feel_of` and the note's phone logger buttons are untouched (it is a mark the player already made).
  - `quest_list`, `goal_tile`, `session_row` keep their old look by default (Adventure, Journey); `flat = true` is the Hero
    tab's. The other tabs were not restyled this time.
  - A new Hero card must be a `Kit.section` (or a `Kit.row` inside one), take its colour by the rule, use `Kit.clip` for any
    text in a row, and keep its metas. The home walkthrough checks the section order, the gap, and that MISSIONS repeats no
    Today done box.
- A run's total time is a labelled row (2026-11-26, "add a total time to runs, that got deleted somehow.
  And that I can edit my previous runs to add that time"). It was never deleted: the three small
  unlabelled boxes beside the date read as a clock, not a field. For a run, a ride and a vest walk
  `LogSessionForm.build` now puts the same three boxes (fkeys `dur.h` / `dur.m` / `dur.s`, big, with h /
  min / sec chips) in the distance card under "Total time" (meta `time_row`); lifts and climbs keep the
  small ones with their quick picks. Tab order: distance, elevation, h, m, s. A run / ride / walk with no
  time says so in its sheet with an "Add total time" key that opens it for editing (`SessionView.open`,
  metas `add_time`, `add_time_key`). Walkthroughs: splits, log.
- THE REALM, a turn-based RPG in a sixth tab (2026-11-25 to 27; "use this hero in an RPG style game...
  lifts and running and reading etc to raise player stats... turn based combat... really expansive...
  Do not touch main game besides taking out the campaign for now"). THE CONTRACT IS `RPG_PLAN.md` in the
  project root, and the head comment of `game/rpg/rpg_battle.gd` is the last word on the vocabulary
  (moves, effects, passives, foe rows): read both before touching `game/rpg/`, `ui/rpg/`, `avatar/foe_*`.
  - It only READS the log. Its own progress is `saved.rpg` (`RpgSave`: `empty` / `parse` and every change
    as a pure function returning {"ok", "why", "rpg"}); `App.rpg()` / `set_rpg()` emit `rpg_changed`, never
    `changed`, and nothing replays. A battle half way is the draft "battle" (`RpgUi.kept_battle`).
  - The main game changed only by: `Campaign.ON_SCREEN = false` (the 24-boss campaign is off every
    screen; the rules still run, so parity and everything earned are untouched; true brings it all back;
    Adventure's first sub-tab keeps the id "campaign" and is labelled "Bounty"), the sixth tab
    (`main.TAB_STRETCH`: the Log key did not move; a dot while a training chest waits), `Pal.PUSH / PULL /
    LEGS / GRIT / REALM`, the App plumbing above, 89 icons (`RpgDefs.ICONS`), five hero poses (strike,
    kick, guard, cast, hurt; the game's look only).
  - Pure logic, `game/rpg/`: `RpgDefs` (every id, constant and formula: tune numbers THERE), `RpgStats`
    (twelve stats from the log, never falling), `RpgBoosts` (boosts of today and yesterday, training
    chests), `RpgBattle` (the engine: one JSON-safe dictionary B, deterministic, resumable), `RpgAi`
    (foe intents; hero policies heuristic / random / loop for the simulator), `RpgHero` (`build`,
    `reference_hero(t, archetype)`, `power`), `RpgMoves` (90: 8 starters, 58 on boards, 8 ultimates, 16
    scrolls), `RpgPassives` (24), `RpgSkills` (eight boards, `can_learn`, `points`), `RpgGear` (battle
    stats for the game's 124 items by id, 30 uniques, 7 sets, runes), `RpgRelics` (24), `RpgItems` (8),
    `RpgPets` (16 kits), `RpgFoes` (56 foes, 162 foe moves), `RpgWorld` (8 regions x 10 stages, stars,
    hunt, rival = the week's bounty monster read only, Spire, echo regions, `setup`), `RpgLoot`.
  - Screens, `ui/rpg/`: `RpgUi` (look helpers and THE ONLY code that touches App: `sheet`, `boosts`,
    `hero`, `save`, `apply(result)`, `fight(what)`, `finish` (pays once), `resume`), `RealmScreen` (first
    visit, banner, notices, boosts, sub-tabs), `RealmMap`, `RealmHero`, `RealmMoves`, `RealmSkills`,
    `RealmGear` (each `static fill(box, screen)`), `BattleView` (a full-column overlay on
    `Kit.overlay_root`; nothing scrolls or moves between turns), `BattleWidgets`, `BattleResult`.
    Art: `avatar/foe_sprites.gd`, `foe_view.gd`, `realm_scenes.gd`.
  - Tests (headless): rpg_shell, rpg_stats, rpg_boosts, rpg_battle (562), rpg_moves, rpg_gear, rpg_foes,
    rpg_world, rpg_save, rpg_content (cross-catalog), rpg_sim (balance bands; `tests/rpg_sim.gd` is the
    simulator, `tools/rpg_balance.gd` the full sweep), rpg_art, rpg_icons, rpg_battle_ui, rpg_hub,
    rpg_pages. Walkthroughs: `realm` (first visit, hub, chest, pages, map, prep, cache), `battle`.
    `tools/rpg_sheet.gd` prints the sheet of a save given in RPG_SHEET_SAVE (a log kept OUTSIDE the project).
  - The user's real log is short (it started mid November 2026): calibrate on it, not on the demo year.
  - Known gaps: engine wishes the builders listed (a "first move of a wave is free" passive, companion
    charge rate, a foe trigger on break / recover, quicken reset by a slow); gear uniques `negative_split`
    and `rally` share ids with moves and foe move `grind` with a starter (different catalogs, harmless);
    the hub's sub-tabs sit under the boosts, so a page starts a scroll down; nothing was tried on a real
    iPhone.
  - HOW A FIGHT FEELS (2026-11-26, the user: "feels like stuff is missing. Not sure if it's combinations of
    animations, sounds and visual effects... keep working on improvements"). Three modules, all optional to
    the logic (nothing of them runs in an `instant` playback, which is what the headless tests use):
    - `ui/rpg/rpg_sfx.gd` (`RpgSfx`): the Realm's own sounds, `SOUNDS` (about 75: a hit per school, crit,
      weak, resist, miss, heal, buff, debuff, shield, guard, block, break, ko, hurt, charge, boss, victory,
      defeat, star, loot, chest, learn, upgrade, equip...). `RpgSfx.play(name, pitch, drift)`, `hit(school,
      crit, weak, resist)`, `star(n)`, `buzz(n)`. Rendered by `Sfx.play_notes` (app/sfx.gd got a "noise" wave:
      white noise through a one-pole low-pass, opts `lp`, its own generator so a sound is the same every
      time). Sine, triangle and soft noise only; `tests/rpg_sfx_test.gd` measures them and checks that every
      sound a screen asks for by name exists (it reads the scripts in its `USERS` list: add a new screen there).
    - `ui/rpg/battle_fx.gd` (`BattleFx`): pixel effects on a grid of 3 screen pixels that free themselves:
      `at(layer, kind, pos, colour, secs, opts)` with `KINDS` (impact, slash, stomp, streaks, claw, ring,
      spark, heal, up, down, shield, shards, poof, flame, drops, gather, rays, block, stars, dust, sparkle,
      orb, bite, notes, aura), `strike(layer, school, mid, feet, colour, big)` (`SCHOOL_FX`), `bolt` (a thrown
      orb), `number` (pops, hops aside, falls), `word`, `flash`, `dim`, `cutin` (an ultimate's or a boss's
      name across the arena), `knock`, `tint`, and the classes `Ambient` (a scene's air: `BattleView.AMBIENT`
      per scene: dust, leaves, snow, embers, fireflies, rain with lightning, stars) and `Vignette` (a red edge
      that beats under `LOW_HP` 30%). `BattleFx.speed` is the battle's x1 / x2.
    - `app/realm_music.gd` (`RealmMusic`, a Node made on demand under Sfx by `RpgSfx.music()`): synthesized
      looping tunes, "hub", "result", "battle" / "boss" for regions 0..7, rendered a few ms a frame and
      crossfaded. `RpgSfx.tune(theme, region)`, `tune_ready`, `hold(+1 / -1, battle)` (the Realm's screen and
      a battle hold the music; with no holder it fades out), `music_on()` = Settings' sound AND
      `settings.realmMusic` (on unless switched off; the key is on the hub's banner, meta `realm_music`,
      icons `music` / `music_off`). In a browser a looping sound restarts with a small gap and every tune
      played stays in memory (about 9 MB), so there the loop dies away at its end (`breath`), "result" plays
      the hub's tune and at most `RpgSfx.WEB_TUNES` 5 different tunes are made per visit. Test:
      `tests/realm_music_test.gd` (269 checks; `tools/realm_music_wav.gd` writes WAVs to REALM_MUSIC_OUT).
      NOBODY HAS HEARD the music or the sounds: they were measured, not listened to.
    - `BattleView`: `_intro` (the screen comes out of the dark, the hero runs in; the opening's events play
      after it), `_hero_attack` (a step in of `STEP_IN` 26 px, never under a foe's plate: a hop for legs, a
      blur for speed, a thrown orb for mind; self moves get an aura), foes lunge or cast by their move's
      kind, `_show_dmg` (the school's effect, knockback, a number, WEAK / CRIT / BLOCK words, shake and flash
      by size), a foe goes down WITH the blow that fells it (`_ko_ahead`, `_ko_done`), a boss gets a cut-in
      and its own sound, the keys dim while something plays (`_dim_keys`) and a chime says it is the
      player's turn, the gauge announces itself when full. The fighters' HP bars leave a pale trail where
      the bar was (`Bar.ghost`, off for every other bar). A shake moves the arena by parts of a pixel, so
      `_end_playback` sets its size again and `Arena.ground()` rounds (a foe was once 1 px off the ground).
    - `BattleResult`: with `info.hero` / `info.scene` / `info.hero_fit` (BattleView adds them) its head is a
      picture, the hero where the fight was beside the words (`_tableau`, meta `br_tableau`); stars slam in
      a step higher each, the three numbers count up, the loot comes one piece after the other.
    - The hub's boosts are two across (a tap opens a boost in full), so the tabs and the map come up.
    - More of the same day: the arena's plain sky has clouds by day and stars at night (`BattleFx.SkyBand`,
      only where the arena is taller than its picture); a foe about to hit for a quarter of the hero's HP or
      with a charged blow has an intent that beats red (`BattleView._mark_danger`, `FoePlate.set_danger`,
      meta `bv_danger`); a move or action key blinks and clicks when pressed (a blink, never a pop: a key
      must not change its size even for a moment, and the test checks it), a move refused for energy
      blinks the pips red; the timeline's tiles slide one place on. In an `instant` playback no plate pops
      either (the test checks the layout right after a press).
    - Lasting statuses stay drawn on a fighter (`BattleView.STATUS_LOOPS`, `_status_fx`, meta `bv_status_fx`):
      flames while it burns, drops while it bleeds, stars round a stunned or broken head, a faint bubble for a
      shield, green motes for regeneration; a foe winding up a blow gathers red motes, a charged one blazes.
    - The hub's sub-tabs are the FIRST thing on the Realm's screen (they never move when a page is picked; a
      test checks it). Under them the Map page has the banner, the notices and the boosts; the other pages
      have one slim line (`RealmScreen._slim`, section `realm_slim`: level, its bar, points, ore), so a page
      starts at the top of the screen, not a screen down.
    - THE LINE THAT SAYS WHAT HAPPENED WAS BLANK on every tall screen (a phone's among them) until
      2026-11-26: in the two-line box its label wraps and clips, such a label asks for one pixel of height,
      and it was left to shrink. `_line.size_flags_vertical = SIZE_FILL` now; the battle test checks the
      label's height and its visible lines (`_layout_wrong`). A label that wraps AND clips must be given its
      height (fill, or a minimum size): it will not ask for one.
    - AUTO (`bv_key` "auto", top bar, lit gold while on; `BattleView.auto`, static `auto_kept` for the next
      fight of the visit): the hero plays `RpgAi.hero_action(B, "heuristic")` a breath after each playback,
      waits while a sheet is open, never in the taught first fight; a tap on AUTO takes over again, Flee
      turns it off. The battle walkthrough wins a pack with it.
    - The bestiary: `ui/rpg/realm_bestiary.gd` (`RealmBestiary.card(rpg)` at the foot of the Map, section
      `map_bestiary`; `open()` the sheet: every foe by region, the ones met as they are with the weaknesses
      learned, the rest as dark shapes "???"). Nothing new is stored: met = a weakness learned
      (`saved.rpg.seen`) or standing in a stage that was won (`RealmBestiary.met`).
    - A PHONE'S SPEAKER plays next to nothing under about 250 Hz, and the phone is where this is heard: a
      thud is never only a low sine. Every hit, block, break and drum of `RpgSfx.SOUNDS` has a knock in the
      middle (a sine falling through 300 to 700 Hz), and the sound test fails a sound with less than 30% of
      its energy above 250 Hz. (The music was measured the same way: 56 to 82% above 250 Hz. It plays at
      `RpgSfx.MUSIC_VOLUME` 1.0: peaks about -18 dBFS.)
    - A tap on the fight's message line opens the log (`BattleView._open_log`, sheet meta `bv_sheet` "log",
      the last `LOG_MAX` 60 things said, newest first). An ultimate's first hit lands as a storm of bursts.
    - The Hero page ends in THE JOURNEY SO FAR (`RealmHero.journey(rpg)`, section `realm_journey`, six tiles
      `journey_num`): stars, stages won, bosses felled, foes met, relics found, the Spire. Counted from the
      save; nothing new is stored.
    - `ShotHelper.snap` also fails a label that is on screen with words and shows none of them (5 px high or
      no visible line): every walkthrough is a check for text that cannot be seen.
    - Training shows in the Realm the day it is done: `RpgUi.gains()` (today's training, else yesterday's:
      the stats it raised by `GAIN_MIN` 0.1 or more, from `RpgStats.scan_pair` / `raws_of`) is a green row
      under the hub's banner ("Today's training made you stronger", a chip a stat, metas `realm_gains`,
      `realm_gain`). And `saved.rpg.statsSeen` = {stat: whole points as the Realm last showed them}
      (`RpgSave.note_stats(rpg, values)` -> {rpg, changed, rose}; kept by `RpgSave.parse`; stored with
      `RpgUi.commit_quiet` = `App.set_rpg(d, true)`, which emits nothing): a stat that has reached a new whole
      point since the last visit gets a "Stronger" LootPop when the hub is drawn (`RealmScreen._note_stats`,
      deferred; never the first time, never during a battle).
    - `ui/rpg/realm_help.gd` (`RealmHelp.link()` at the foot of the Map, meta `realm_help`; `open()` the
      sheet "How fights work": `POINTS`, their numbers filled in from RpgDefs; also a key in a fight's log).
      The hub banner's hero stands in the furthest region the road has reached (`RealmMap.furthest`,
      `BattleWidgets.Arena` + `BattleFx.Ambient` in the well, a tag with its name; metas `realm_place`,
      `realm_where`). A move of three energy or more (or rank 1.35+) lands heavier (`_act_heavy`). A fight's
      music is made ready when its prep sheet opens (`RpgSfx.tune_ready`).
    - `tests/shots/realm_own.gd` (any data kind; env `REALM_OWN_SAVE` = a save or backup file kept OUTSIDE
      the project, read only, loaded into the run's throwaway data folder): the Realm with the player's own
      log: the stats and boosts printed, the first fight, the hub, the Hero page, r1s2 and the first boss on
      AUTO ("OWN ..." lines say how each went). Delete the run's data and shots folders afterwards: they hold
      a copy of the log. It found that the hub kept offering "Continue the battle" after a paid fight's
      result was left (the hub had been drawn while the draft was still kept): `RpgUi._after` now emits
      `rpg_changed` once the draft is cleared. With the Nov 23 backup: first fights 1 to 2 turns, the first
      boss won on AUTO in 9 turns with 61% of the HP lost and nothing learned yet.
    - After a LOST fight the result has "What would help" (`RpgUi.tips(B, stage, summary)`, at most
      `TIPS_MAX` 4, in `info.tips`; `BattleResult._tips`, meta `br_tips`): a weakness not found yet, or found
      and no move of that school in the build; skill points unspent; power under the stage's `rec`; never
      guarded; an untouched belt; no boost today; the lowest body stat when it is far under the others and
      what it is for (`STAT_GIVES`: for a low Core, "it is your armour and your guard").
    - The hours of a road (`BattleView.HOURS`, `hour()`, meta `bv_hour` on the arena): stages 1 to 3 by day,
      4 to 6 at dusk, 7 to 9 at night (the sky band shows stars when the lit sky is dark), a fight with a boss
      at the boss's own dark hour; hunts, the rival and the Spire by day. The light is the arena's
      `self_modulate` (its backdrop, sky and shadows; never the fighters) and goes to the result's picture
      as `info.light`.
    - The map's stages are a ROAD: `ui/rpg/road_map.gd` (`RoadMap`, `RoadMap.Place` = a Button with the
      old metas `map_stage`, `map_state`, `map_stage_stars`; the road has `map_road_path`). Three places to
      a row, every other row right to left, the boss alone at the end; the path swings out round the names
      at a row's end; walked stones are green, the stretch to the next place marches in gold, a marker hops
      over it. `RoadMap._seen` / `_fresh` (static): a place that changed since the road was last drawn
      lights up (coming back from a win). The ground takes its colour from the region's picture.
    - `ui/rpg/loot_pop.gd` (`LootPop.open(title, icon, lines, colour, sound)`): whatever is opened (a
      training chest, a star chest, a cache, a hunt's prize, a NEW REGION: `RealmMap._greet_new_region`) gets
      the whole screen: it drops in, rattles, opens in light, its lines come one at a time; a tap shows all,
      the next closes. It takes every tap while it is up: a walkthrough that makes real clicks calls
      `LootPop.close_all()` first (`_pops_off` in realm.gd). What was won is in the save before it opens.
    - Walkthrough `tests/shots/fx.gd` (year data): it does not snap screens but cuts the arena out of
      frames every few hundredths of a second into sheets (`fx_sheet_N.png`), plays a result, and draws every
      effect at three moments (`fx_catalogue_N.png`). Look at those when changing an effect. A walkthrough
      that waits for a playback must wait by the clock, not by frames (a PC with no vsync draws a
      thousand frames a second): `_wait_idle` in fx.gd and battle.gd.
- Reading: the page of an EARLIER day (2026-11-27, "Allow me to go back to previous day to put what page I
  ended on... I can add pages but then game gets confused about the following day"). `Books.set_page_on(b,
  page, day)`: the day starts where the last logged day before it ended, and the next logged day after it
  now starts on this page (deltas per day); `App.set_book_page(id, page, on = "")` moves each affected
  day's reading. The Hero tab's reading card has a Today / Yesterday / weekday track under the page box
  (`BookView.day_row`, meta `book_day`; `BookView.days_back` goes back to today after a save).
- The Hero tab's level tiles open a sheet (2026-11-27, "click on the main boxes (reading, running etc) on
  hero page to go deeper"): `ui/screens/discipline_sheet.gd` (no class_name; `open(d)` for lift / climb /
  run): level and XP bar, four headline tiles, the same card Journey -> Stats shows (`JourneyScreen.lift_card`
  / `run_card` are static now), week bars, the last five sessions, "Log one" and "All stats". The tiles
  used to open the log form; `Parts.stat_tile(d, level, tap)`. Test: `tests/discipline_sheet_test.gd`.
- Also 2026-11-23, found by running the walkthroughs on a Monday:
  - An exercise key of the Log tab's "Add exercise" list wrote the whole variation: a long one
    ("Single arm incline home cable") made the key, the card and so the page wider than the window
    (470 of 440 px). The movement and the variation are now `Kit.clip_fit` labels
    (`LogLiftEditor.CHIP_MOVE_W` 150, `CHIP_VARIATION_W` 120). It only showed on a day the demo
    player had already done the long-named lift, so the long_names walkthrough should also be run
    at normal size, not only with `--fingers`.
  - The bounty walkthrough pretends it is the Tuesday of next week to see last week's recap offered;
    when that Tuesday is in the first week of a month the month's recap comes first. It now takes
    that one as opened.
  - The touch walkthrough set `scroll_vertical = 0` before checking that the page follows the finger
    in parts of a unit; the glide before it had stopped between two units (the page was long enough
    for it not to reach the end), and that part of a unit stayed (`tt_fine`). It now goes back to
    the top with `ts._scroll_to`.
  - The touch walkthrough reveals the Log tab's Deadlift key and the stepper before it taps them
    (2026-11-24: on a Tuesday the day's plan card above them was long enough to push the key below
    the window, and the tap landed on nothing).
  - The demo player trains by the weekday (lifts on Mondays and Fridays), and `ShotHelper.demo_saved`
    logs today too. The `today` and `workout` walkthroughs failed on those days (rows already ticked,
    "Continue workout", the plan full of the demo's own lifts): both now take out the demo's sessions
    of today's weekday first. A walkthrough about the day's plan must do the same.
- Also 2026-11-21: switching tabs kept the old tab's scroll position (the new screen's first build in
  `UiScreen` kept what it found); `main._refresh` now resets it before adding the screen (anchor walkthrough).
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
- The hero, redrawn (2026-11-20, "looks awful, blocky and weird as it gets bigger"):
  in the game's own look (Pix.classic false) the hero is `avatar/hero_figure.gd`
  (`HeroFigure`), a 64 x 70 figure of about 5 heads (Slynyrd's 6-head model shrunk; the
  user's progress photos as the reference for build, hair and mustache). The body is
  parts on a skeleton from the levels (tapered capsules with bulges, ellipses, rows for
  the torso and head), filled pixel by pixel with a surface normal each: lit from the top
  left with a 5-step hue-shifted ramp (`skin_ramp`, `ramp`, `hair_ramp`), limbs banded
  across their width (`_band_limbs`), a 1px shadow where a part overlaps another, lone
  pixels cleaned (`_clean`), definition (sternum, abs, obliques) as the hero trains.
  `metrics(i)` returns the same Metrics fields as HeroBody (so Equipment still fits) plus
  `g` (the skeleton) and `fig` (part owner and normals per pixel). `HeroBody.width()` /
  `height()` give the canvas of the look being drawn; `GymScene.hero_x()` / `hero_y()`
  place it. `HeroBody._draw_figure` composes: back item, body, clothes from
  `avatar/figure_gear.gd` (`FigureGear`: a garment is the pixels of the parts it covers,
  shaded by the body under it: shorts, tights, harness, kilt, shirt and its patterns,
  tank, singlet, armor, gi, gloves, wraps, chalk, boxing, shoes, climbshoes, sandals,
  boots, backpack straps, saddlebag), the rest from Equipment, face, hair, hats; then
  `Pix.light()` on the gear only (pixels the figure painted are kept) and the outline.
  No legs item: plain shorts (`HeroFigure.PLAIN_SHORTS`). Profile `facialHair` (0 none,
  1 stubble, 2 mustache, 3 beard; Armory -> Look and Settings) is the game's look only.
  The classic branch (48 x 60, `parity_art`) is untouched. Test: `tests/figure_test.gd`.
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
godot --headless --path . --script res://tests/figure_test.gd
godot --headless --path . --script res://tests/doc_clear_test.gd
godot --headless --path . --script res://tests/recovery_test.gd
godot --headless --path . --script res://tests/plates_test.gd
godot --headless --path . --script res://tests/projects_test.gd
godot --headless --path . --script res://tests/climb_ladder_test.gd
godot --headless --path . --script res://tests/sync_test.gd
godot --headless --path . --script res://tests/phone_push_test.gd
godot --headless --path . --script res://tests/dosage_test.gd
godot --headless --path . --script res://tests/dose_test.gd
godot --headless --path . --script res://tests/ahead_test.gd
godot --headless --path . --script res://tests/todos_test.gd
godot --headless --path . --script res://tests/run_splits_test.gd
godot --headless --path . --script res://tests/sides_test.gd
godot --headless --path . --script res://tests/units_test.gd
godot --headless --path . --script res://tests/sfx_test.gd
godot --headless --path . --script res://tests/books_test.gd
godot --headless --path . --script res://tests/bands_test.gd
godot --headless --path . --script res://tests/rpg_shell_test.gd
godot --headless --path . --script res://tests/rpg_stats_test.gd
godot --headless --path . --script res://tests/rpg_boosts_test.gd
godot --headless --path . --script res://tests/rpg_art_test.gd
godot --headless --path . --script res://tests/rpg_icons_test.gd
(and rpg_sfx_test, realm_music_test, rpg_battle_test, rpg_moves_test, rpg_gear_test, rpg_foes_test, rpg_world_test, rpg_save_test,
 rpg_content_test, rpg_sim_test, rpg_battle_ui_test, rpg_hub_test, rpg_pages_test, discipline_sheet_test)
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
projects (climbing projects: the card, the sheet, the reel's "was it your project?", year data),
climbs (the Journey climbing card: flashes, sends, tries that did not go, per grade, routes, year data),
touch (fingers: flick, glide, stop, tap, hold, drags from keys and text boxes, year data),
workout (Start workout from the Today card, the kept draft, hold seconds, finger sizes, year data),
phone (rename a lift, small backups, the phone's own morning message: see above, year data),
long_names (long lift names on every screen that lists lifts: nothing wider than the column, year data),
focus (the training focus: an added press, weekly sets, no rest day by itself, the Rest chip / Lift today, a leg day left alone, Settings; `new` data),
ahead (the Coming up card and sheet: the next days as they will probably go, and a day's Rest / Lift key; year data),
todo (the to-do list: the card, the sheet, adding without the Add key moving; year data),
splits (a run's best splits: the fields that come with the distance, the sheet, Journey, the record; year data),
sides (reps logged as both sides added up: the lift page's switch, the Log tab's L+R key, the Today aim; year data),
units (pounds and miles where the rules write kg and km: record cards, XP chips, trophies; year data),
picks (the Log form's "From today's plan" card and an exercise card's up / down keys; year data),
filed (how a new exercise typed in the Log tab will be filed: the note at the search box, the line under its name; year data),
update (the phone app's "new version ready" card and its Settings row, pretended on the PC; year data),
books (books pasted in, the page box on the reading card doing the page math, finishing one, the bookshelf; year data),
bands (a band instead of a weight in the Log tab, the band picker, the PT key on an exercise card, the band words on the lift page; year data),
realm (the Realm: first visit, hub, training chest, the five pages, map, prep sheet, cache; year data),
battle (a fight played by its keys to the result, a pack, the first boss; year data),
realm_own (the Realm with the player's own log, from the file in REALM_OWN_SAVE; see THE REALM),
flows (the Realm's fights as a player goes through them: win and Next stage, the app closed mid-fight and
  Continue, flee, lose and Again, with the hub's state checked after each; year data),
fx (a fight's effects filmed frame by frame into sheets, the result as it plays, every effect on a catalogue page; year data),
realdoc (the real Google Doc, see below). Demo data: fresh, new, week, year.

To check the phone inbox against the user's real Google Doc, set `TINY_TITAN_INBOX_URL`
to the doc link and run the `realdoc` scenario with `new` data: it prints the text the
game received, every entry it understood, and saves a screenshot of the review sheet.
Verified 2026-11-15: the link, fetch and export all work; the doc was still empty then.

`--check-only` does not work for scripts that use the App/Sfx autoloads; a real run is
the check.

The phone app (web build): `python tools/build_web.py`, then serve `build/web` on this PC
(`python -m http.server 8765 --bind 127.0.0.1 --directory build/web`) and open it in the built-in
browser at phone size (resize_window preset mobile; add `?v=<anything>` to force a reload). For
sync, run the note's script in the stub (`DocClear.script_for(token)` written to a file, then
`node tests/doc_clear_stub.js script.js doc.json <port>`), give a "PC" copy its save with a
scenario that sets `App.cloud._cfg` and calls `sync_now`, and open the web app with
`#c=<App.cloud.connect_code()>`. Synthetic touches: dispatch `TouchEvent`s on the canvas.

## Known rough edges

- The phone app (web build): photo sync and the Drive consent were only tried against the stub, never
  against Google itself (the first real run is the user's); the phone cannot read the Google Doc (the PC imports
  it, and the import reaches the phone through the sync); its keys are sized for a 440 px column,
  so the compact −/+ steppers are small for fingers.
- The phone's morning message needs the app to have been opened in the two days before; a message
  already waiting keeps its time and cannot be stopped (a new time or the switch counts from the
  mornings not left yet). The evening check and the weekly recap picture are PC only.
- A lift logged as both sides added up (Sides) is still ONE lift to the rules: its records and the
  Journey page's four strongest lifts go by the reps as typed. An older day typed a side (before
  the player started adding both arms up) is read as a total like the rest: it has to be edited.
- Ride trophies and gear go by metres with no slack: a ride typed as 62.1 miles is 60 m short of
  the 100 km trophy (62.2 earns it). Runs were given the slack on 2026-11-23, rides were not asked
  about.
- Chronicle titles, a boss's lines and other flavour that names a unit in WORDS ("kilometre
  thirty-two") stay as written.
- A hold earns XP as the reps it is stored as (a 30 second stretch is one rep): the rules
  have no timed sets.
- Switching "Physical therapy" on a lift's page does not redraw the view above it (the
  Logbook's goal bars and the Compare target change the next time the page opens).
- "Next time" is a rule of thumb (one more rep, then more weight), not a programme; the
  weight step is 2.5 kg or 5 lb whatever the lift.
- The day's plan is a guess from weekdays and gaps unless a training split is picked;
  "From my log" does not work out a cycle by itself. A lift done once in six weeks on this
  weekday counts. A day mixing two kinds (push with a squat added) counts as the kind most
  of its exercises are.
- The morning message only goes out when the computer is on or asleep (woken by the task)
  at that time; a run after noon sends nothing. It runs the Godot editor's exe headless, so
  moving Godot or the project folder needs the switch turned off and on again.
- Lift names are filed when a lift is imported or saved, not afterwards: changing `MOVES`,
  `VOCAB` or `ALIASES` does not rename what is already in a save. To bring a save in line,
  run `LiftNames.migrate` over it on a copy (as was done 2026-11-20) and check XP is unchanged.
- A "no" in the review keeps a lift as a movement of its own ("Jefferson Curl"); it can be renamed or
  moved under another movement afterwards from its page (Rename or move this lift).
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
- The e2e walkthrough is for the normal size only. With `--fingers` the body check-in does not
  take the typing focus by itself (as on a phone), the walkthrough's typed weight goes nowhere and
  four checks fail. Seen 2026-11-23; it is not a bug of the game.
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
- This local folder is an unzipped copy, not a git clone (checked 2026-11-15).
- Pushing the source needs no asking any more (2026-11-22: asked "yes for these, or yes and always
  push source after publishing from now on?", the user answered "Always push"). After a change is
  tested and the phone app is published, commit it in the clone and `git push` the branch, then say
  so. It covers this branch only; anything else on GitHub (another branch, the repo root, a force
  push, the PR itself) is still asked first.
- Commits are made in a clone at `C:\Users\jdjen\Documents\cardboard-cosmos` (same branch):
  copy the changed files into its `tiny-titan-godot/` folder (keep the clone's own
  `project.godot`; skip `.godot/` and `shots-today/`) and commit there. `export_presets.cfg` is
  ignored by the repo's root `.gitignore`: add it with `git add -f` (it holds no secret). Before
  committing, look through what is staged for links, tokens, the ntfy topic, an email address or
  names taken from the user's own log; tests use made-up names.
