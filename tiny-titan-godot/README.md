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
v4 flash x2, v5 send 3 attempts
tr 5.10a flash, 5.11b
hang 20mm 10s x6, one arm 15mm 7s x3 +10
run 5.2km 27:30 +80m
ride 40km 1h35
vest walk 3km 40:00 10kg
weight 82.4  bf 18
read 20 pages
```

Weights are in your weight unit unless you write `kg` / `lb`; distances in your distance unit unless
you write `km` / `mi` / `k`. One set per line works too (`backsquat x5 135`, then `backsquat x5 195`:
same exercise, sets add up). V grades are boulders; `5.xx` grades (`5.10a`, `tr 5.9`, `lead 5.11c`)
are roped routes; `hang 20mm 10s x6` logs dead hangs (edge, seconds, how many; add `one arm`,
`+10` for added weight or `-20` for assistance, `jug` for a bar). `title: Push day`, `note: felt strong` and `duration 70min` attach to the
session above them; `---` starts a second session on the same day; `#` starts a comment.
An exercise name may hold a number of its own (`neck 4 way - 3x20@10`, `1 arm row 3x10 @ 40`): put
a dash or a colon between such a name and its sets the first time; once it is in your log the game
knows it. A decimal may be typed without its zero (`.5 mile`).

A stretch or any other hold is written with its seconds, marked `"`, where the weight would
be: `(PT) calf stretch 3x1@30"` is three holds of 30 seconds, and so are `3@30"`, `3x30"`
and `30" x3` (`30s` and `30 sec` work too). The game then counts seconds, not weight: the
lift's page shows the longest hold and a Hold trend.

A table works as well as typed lines. Give its first row the names of the columns and the
game reads the rows under it:

```
| Date  | Exercise     | Variation    | Weight | Reps       |
| 11/14 | Seated row   | cable, 1 arm | 70     | 12, 10, 9  |
|       | Calf stretch | wall         | 30"    | 3          |
```

The columns it knows: Date, Exercise, Variation (it joins the name: "Seated row - cable,
1 arm"), PT (anything in the cell marks it), Weight (or `30"` for a hold), Hold, Sets, Reps
("3x10", or "12, 10, 9"), a column per set ("Set 1", "Set 2"...) and Notes. A date is only
needed in the first row of a day; empty rows are skipped.

A lift name does not have to be exact. The game compares the words, not the letters: another
order, dashes and commas, plurals, short forms (`db`, `1UE`, `pulley`) and a small typo all read as
the same lift, and one of your own lifts wins over the library's name for it, so your history
stays in one piece. In the review each such name gets a row saying what it was taken as, with
three keys: the tick (yes), the cross (no, it is a lift of its own) and the pencil (pick another
lift, or type a name). A name it has never seen is marked as a new lift, with the closest one
offered when there is one. What you answer, or import as shown, is remembered, so the same words
are asked about once (Settings → Phone inbox → Forget starts over). A line the game cannot read
at all is listed with the reason and an example of how to write it.
`vest walk 3km 40:00 10kg` logs a weighted vest walk (see Miscellaneous below); leave the weight
out and the last vest you logged is used, or put `vest 10kg` on the line under it. Written as a
sentence it works too: `2.5 mile walk with 30 lb vest`.

On a climb, every result word is its own tally and takes the number beside it. `v3 send 3 attempts`
is one send plus three tries that did not go (the same as logging one Send and three Attempts in
the Log tab); `v4 5 attempts` is five tries and no send; `v3 2 sends 3 attempts` and
`v3 send, 3 attempts` work too. `v3 3rd go` (or `v3 send in 3`) says which go it went on: one send
and two tries, and `1st go` is a flash. `v4 x3 no send` is three tries. A climb the game cannot
tell apart is shown as a line it could not read, never guessed.

`read 20 pages` (or `reading 20`, or just `20 pages`) adds to the pages you read that day; two
such lines on a day add up. If you change the number after importing it, the day changes by the
difference instead of counting the line twice.

**Miscellaneous** (Log tab, under the four disciplines): activities that are not lifting,
climbing, running or cycling. For now there is one, the **weighted vest walk**: distance, time,
climb and the weight of the vest (quick picks, and "same as last" fills the whole form). It earns
XP for the hero (60 per km, 0.8 per metre climbed, both +2.5% for every kg in the vest up to
double, plus the usual 2 per minute: about 490 for an hour's 5 km with a 20 lb vest), so it hits
the boss and the weekly bounty, pays coins, can drop loot and counts for the weekly goal and the
streak. It has no level of its own and leaves the four disciplines alone: their XP, totals,
records and quests never see it. The longest walk and the heaviest vest are records. Vest walks
show in Journey (the log, a card in Stats, the Story), on the Hero tab's week card and in the
recaps.

**Lift library** (Journey → Lifts): about 170 lifts grouped by body part, with equipment
chips (barbell, dumbbell, cable, machine…), a search box and sorting by name, most done,
heaviest or most recent. Tap a lift for form notes, your best set, estimated 1RM, rep
records, its trends, every session you did it in, variations to try and a button that
adds it to today's workout. "New to me" shows what you have never done.

**What you did, and how it is going.** The review of a phone note lists every exercise of a
lift as its own row: the sets, and a tag that compares them with the last time (NEW, PR,
+2.5 lb, -4 reps, same). A session in your log opens the same list (Journey → Log, or the
recent ones on the Hero tab), with the XP it earned and an Edit key. Click any exercise for
the lift's page. It reads from the top: your newest session in big numbers with the change
since the time before; one line graph of the lift over time (Weight to start with; Reps,
Volume and How often are one tap away), with how much it changed since the first day; then
the history as a list, one row per day with that day's change; then your records.

**Physical therapy.** Write `(PT)` in front of an exercise (`(PT) neck 4 way - 3x20@10`), in
the phone note or in the Log tab, and that lift becomes a physical therapy exercise; the
tag is not part of its name. The switch on a lift's page does the same. The Hero tab then
shows a Physical therapy card: for each of them the days of this week, done or not, against
the days a week you aim for (3 to start with; − / + changes it). The sheet behind it shows
eight weeks of bars against that goal, when you last did it, and how many weeks in a row
you kept it up. A lift you tag for the first time is asked about once in the review ("is it
the lift you already do?"); say no and it is kept apart as "PT ...".

Edited a day after importing it? The game notices, shows "Updates the one already imported"
on the review sheet, and replaces that session instead of adding a copy. Once everything in
the note is in the game, the Hero tab says so and it is safe to clear the note.

**Progress pictures** go in the same doc: write a line like `progress pics 11/15` (any date line
works) and put up to three pictures under it, front, side and back in that order. The game shows
them on the review sheet and imports them as that day's photo check-in, downscaled and stored in
its own data folder, so once they are in the game you can delete them from the doc and your phone.

**Screenshots** work as well (Windows only): paste a Strava run or ride, or your scale app's
weigh-in screen, into the doc and the game reads the numbers off the picture with the text reader
that is part of Windows (nothing leaves the computer, nothing is installed). A run or ride comes in
with its distance, moving time, elevation gain and title; the other numbers on the screen (steps,
max elevation, calories...) are kept as its note. A weigh-in comes in with weight and body fat, and
the other readings (muscle, body water, bone mass...) as its note. The review sheet shows the
picture next to what was read, so you can check it before importing. A date printed on the picture
is used; a picture that only says "Today" counts as the day the game first saw it (the arrows on
the review sheet move it). A walk comes in as a weighted vest walk, with the vest you logged last
(write `vest 20` under the picture to set it). Hikes and other sports are left out with the reason
shown, and a picture with no writing on it is still a progress photo.

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
- **A weekly bounty.** A new small monster every Monday, sized from your own last four weeks.
  Beat it by Sunday night for coins, crush it (150% of its HP) for more, and keep a winning run
  going. Winning bounties also earns its own set of gear.
- **Coins and a shop.** Every 10 XP is a coin; bounties, bosses, trophies and quests pay extra.
  Armory → Shop sells 33 pieces of gear (hats, masks, wings, a greatsword, auras…). Each tile
  shows your own hero trying the piece on, and one item is 30% off every week.
- **187 trophies, 124 pieces of gear, 16 companions**, daily and weekly quests, weekly streaks, PRs,
  mastery ranks per discipline, and an "Almost there" list of the goals you are closest to.
- **See what you are wearing.** The Armory opens on your hero standing on a stage with a slot on
  each side for everything worn (head, face, body, hands, legs, feet, back, extra, aura) and for
  your companion. Hover a slot (or any piece of gear) for a card that says how and when you got
  it (found after which session, bought for how many coins, earned for what) and what it does.
  The **Equipped** tab lists the same as rows, with every active bonus and where it comes from.
- **Reading.** A card on the Hero tab counts the pages you read: tap +1, +5, +10 or +25. A page
  is worth 2 XP (for the first 100 pages of a day) and a few coins, reading has a level of its
  own and a day streak, every hundred pages puts a book on your shelf, and there are trophies,
  an owl and reading glasses to earn. Tap the card for the bookshelf, other days and your daily
  goal. In the phone note, write `read 20 pages`.
- **Fast logging.** Pick an exercise and last time's sets come up already filled in; − / + (hold to
  repeat) on every number; one tap to repeat a previous workout.
- **Looking back.** Then-vs-now, a dated story of every milestone, weekly XP, training heatmap,
  strength progression, send pyramid, body-weight trend and photo comparison.
- **Recaps.** Any week or month as one poster: XP, sessions, records, bosses, trophies, the
  bounty, and a then / now photo pair. Journey → Stats → Recaps, or tap "This week" on the Hero
  tab. **Save picture** writes it to your Pictures folder (in "Tiny Titan") to keep or share.

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

Coins: 1 per 10 XP of a session, check-in or claimed quest; a campaign boss 40 (zone boss 150);
a trophy 10 / 25 / 50 / 100 by tier; a weekly bounty 100, +10 for each win in a row (up to +50)
and +50 for a crush. Coins are counted from your log like everything else, so editing or deleting
an entry recounts them; only what you bought is saved.

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
Everything is drawn at whole-number scales (an icon is 16, 32 or 48 pixels, never in between), so
no pixel is wider than its neighbour. The hero, companions and monsters are lit from the top left
and outlined in a darker shade of their own colours; the home gym has a window with the real time
of day in it. Things move: the hero breathes, blinks and glances about, companions hop, flying
monsters float over their shadows, clouds and stars drift behind the screen, bars glint, rare
gear twinkles, and what a quick tap just earned rises from the button.
**Settings → Theme** switches between Arcade, Ember, Forest and Slate; to add your own, add an entry
to `Pal.THEMES`.

### Window size

The game is a phone-shaped column. It opens at 440 × 900, grows on high-DPI screens and shrinks to
fit short ones; resize or maximise the window freely (the column stays centred and the screens scroll).

### Tests

The rules and the pixel art were ported from a TypeScript version and are checked against it:
`tests/parity/*.json` hold inputs and the original engine's outputs, and these scripts replay them.
(The art has since been reworked; the original look is still in the code as `Pix.classic`, and
that is what the art test compares.)

```
godot --headless --path . --import
godot --headless --path . --script res://tests/parity_derive.gd
godot --headless --path . --script res://tests/parity_misc.gd
godot --headless --path . --script res://tests/parity_art.gd
godot --headless --path . --script res://tests/quick_log_test.gd   # the phone-inbox parser
godot --headless --path . --script res://tests/shot_reader_test.gd # reading screenshots
godot --headless --path . --script res://tests/misc_test.gd        # misc activities (vest walks)
godot --headless --path . --script res://tests/reading_test.gd     # pages read
godot --headless --path . --script res://tests/lift_match_test.gd  # which lift a typed name means
godot --headless --path . --script res://tests/lift_trend_test.gd  # a lift over time; physical therapy
godot --headless --path . --script res://tests/bounty_test.gd      # weekly bounty, coins, shop
```

`tests/shots/*.gd` are scripted walkthroughs that drive the real screens and save screenshots, for
example a whole first day (onboarding, logging a session through the form, the results reel, every
tab, a body check-in):

```
TINY_TITAN_DATA=/tmp/tt-data TINY_TITAN_SHOTS=/tmp/tt-shots \
  godot --path . res://tests/shots.tscn -- res://tests/shots/e2e.gd fresh
```

`TINY_TITAN_DATA` points the game at a throwaway save folder, so tests never touch your real data.
