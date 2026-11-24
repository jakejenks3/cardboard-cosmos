extends Node
## Autoload "App": the single source of truth.
##
## `saved` is everything the player has entered (same shape as the web app's
## backup file). Levels, gear, pets, trophies and the campaign are never
## stored: `state` is derived by replaying the log, so editing or deleting an
## entry simply recomputes the hero.

## The saved data changed and `state` was recomputed. Screens rebuild on this.
signal changed
## The current tab / sub-tab / thing being edited changed.
signal nav_changed
## Something was logged: `result` = {"key", "title", "events"} for the results reel.
signal result_ready(result)
signal toast_requested(text, kind, icon)

## Where everything is stored. "user://" is Godot's per-user data folder for this
## game (Project → Open User Data Folder). Setting the TINY_TITAN_DATA environment
## variable to a folder path redirects it (used by the automated tests).
static var DATA_DIR = "user://"
static var SAVE_PATH = "user://save.json"
static var SAVE_BAK = "user://save.bak.json"
static var BACKUP_DIR = "user://backups"
static var PHOTO_DIR = "user://photos"
const KEEP_BACKUPS = 14
const PHOTO_MAX_SIDE = 1280
## The phone app reminds the player to make a backup file this often (days).
const BACKUP_EVERY_DAYS = 7
const DEFAULT_LOADOUT = {"body": "tee_grey", "legs": "shorts_navy", "feet": "trainers_worn"}

## Source of truth: {profile, settings, sessions, claims, body, purchases, reading, loadout, activePet, strava, updatedAt}
var saved: Dictionary = {}
## Derived PlayerState (see game/player_state.gd).
var state: Dictionary = {}
## {"xp": {lift, climb, run, ride}, "luck"} from equipped gear + pet.
var perks: Dictionary = {}
## Local date, YYYY-MM-DD. Rolls over at midnight while the game is open.
var today: String = ""

# --- navigation -------------------------------------------------------------
var tab: String = "home"  # home | adventure | log | journey | armory
var adventure_tab: String = "campaign"  # campaign | quests | trophies
var journey_tab: String = "stats"  # stats | body | chronicle | history
## Set by `open_shop`: the Armory shows its Shop tab the next time it is shown.
var armory_tab_request: String = ""
## What the Log tab shows: null = picker, a discipline id, or "body".
var log_discipline = null
## An exercise the lift form should add the next time it builds (set by the
## lift library's "Add to today's workout"; the form clears it).
var pending_exercise: String = ""
## The day's lifts sent over from the Today card's "Start workout" (names; the
## lift form adds each with last time's sets and clears this).
var pending_workout: Array = []
var editing_session_id = null
var editing_body_id = null

## The phone inbox (app/inbox.gd): reads workouts jotted in a note on the phone.
var inbox = null
## The phone app's own morning message (app/phone_push.gd).
var push = null
## The save shared with the phone app through the note's script (app/cloud_sync.gd).
var cloud = null

var _quests = null
var _plan = null
var _ahead = null
var _photo_cache = {}
## Set when the save file could not be written (shown once to the player).
var _write_failed = false


func _ready() -> void:
	if OS.get_cmdline_args().has("res://tools/morning.gd"):
		# The morning message (tools/morning.gd) reads the save by itself and
		# must leave everything alone: no load, no backup, no phone note.
		return
	var custom = OS.get_environment("TINY_TITAN_DATA")
	if custom != "":
		DATA_DIR = custom.trim_suffix("/") + "/"
		SAVE_PATH = DATA_DIR + "save.json"
		SAVE_BAK = DATA_DIR + "save.bak.json"
		BACKUP_DIR = DATA_DIR + "backups"
		PHOTO_DIR = DATA_DIR + "photos"
	today = Dates.today_key()
	DirAccess.make_dir_recursive_absolute(BACKUP_DIR)
	DirAccess.make_dir_recursive_absolute(PHOTO_DIR)
	saved = _load()
	_daily_backup()
	var fixed = _local_fixes()
	_recompute()
	if not fixed.is_empty():
		_write()
		get_tree().create_timer(4.0).timeout.connect(func():
			for line in fixed:
				toast(str(line), "good", "book"))
	var t = Timer.new()
	t.wait_time = 30.0
	t.timeout.connect(_tick)
	add_child(t)
	t.start()
	inbox = PhoneInbox.new()
	inbox.name = "PhoneInbox"
	add_child(inbox)
	cloud = CloudSync.new()
	cloud.name = "CloudSync"
	add_child(cloud)
	push = PhonePush.new()
	push.name = "PhonePush"
	add_child(push)


## A one-time repair of the player's own save that is not in the source (it
## holds their own data): app/fixes_local.gd, when the build has it. Only in
## the phone app (TINY_TITAN_FIX_TEST=1 tries it on a scratch save). The save
## was copied to the backups just before (_daily_backup). Returns what it did.
const LOCAL_FIXES = "res://app/fixes_local.gd"


func _local_fixes() -> Array:
	if not OS.has_feature("web") and OS.get_environment("TINY_TITAN_FIX_TEST") != "1":
		return []
	if not ResourceLoader.exists(LOCAL_FIXES):
		return []
	var script = load(LOCAL_FIXES)
	if script == null:
		return []
	var said = script.apply(saved, now_ms())
	if said is Array and not said.is_empty():
		saved.updatedAt = now_ms()
		return said
	return []


func _tick() -> void:
	var k = Dates.today_key()
	if k != today:
		today = k
		_recompute()
		changed.emit()


# ---------------------------------------------------------------------------
# Reading
# ---------------------------------------------------------------------------

func profile():
	return saved.get("profile")


func has_profile() -> bool:
	return saved.get("profile") != null


func settings() -> Dictionary:
	return saved.settings


func sessions() -> Array:
	return saved.sessions


func claims() -> Array:
	return saved.claims


func body() -> Array:
	return saved.body


## What has been bought in the shop: [{id, itemId, cost, at, date}].
func purchases() -> Array:
	return saved.purchases


## Physical therapy lifts (game/pt.gd): {normalized lift name: {"name", "perWeek"}}.
func pt() -> Dictionary:
	return saved.pt


## Mark a lift as a physical therapy exercise, or take the mark off.
func set_pt(lift_name: String, on: bool) -> void:
	var at = Pt.mark_of(saved.pt, lift_name)
	if on and at == "" and Pt.key(lift_name) != "":
		saved.pt[Pt.key(lift_name)] = {"name": lift_name.strip_edges(), "perWeek": Pt.DEFAULT_PER_WEEK}
	elif not on and at != "":
		saved.pt.erase(at)
	else:
		return
	saved.updatedAt = now_ms()
	_write()
	# (the day is planned differently around a PT lift: the plan is made again)
	_quests = null
	_plan = null
	_ahead = null
	changed.emit()


## Is this lift logged as both sides added up: a single arm or single leg lift
## typed as one number for left and right (game/sides.gd)?
func both_sides(lift_name: String) -> bool:
	return Sides.both(saved.settings, lift_name)


## Say that a lift's reps are both sides added up, or that they are not. No
## XP and no record changes; the day's plan and the missions are made again,
## since their aims go by it.
func set_both_sides(lift_name: String, on: bool) -> void:
	if Sides.key(lift_name) == "" or Sides.both(saved.settings, lift_name) == on:
		return
	saved.settings[Sides.KEY] = Sides.with_mark(saved.settings, lift_name, on)
	saved.updatedAt = now_ms()
	_write()
	_quests = null
	_plan = null
	_ahead = null
	changed.emit()


## How many sessions hold a lift of this name.
func lift_sessions(lift_name: String) -> int:
	var k = Xp.normalize_exercise(lift_name)
	var n = 0
	for s in saved.sessions:
		for ex in s.get("exercises", []):
			if ex is Dictionary and Xp.normalize_exercise(ex.get("name", "")) == k:
				n += 1
				break
	return n


## Rename a lift everywhere in the log: every session's exercise of that name,
## its physical therapy mark, whether its reps are both sides added up
## (Sides) and the phone note's name decisions. When a lift
## of the new name exists already the two become one lift (its spelling is
## kept). Nothing else changes: no set, no date. A copy of the save is kept
## first (backups/save-<day>-before-rename-...). Returns {"ok", "sessions",
## "joined", "name"}.
func rename_lift(old_name: String, new_name: String) -> Dictionary:
	var old_key = Xp.normalize_exercise(old_name)
	var want = new_name.strip_edges()
	var new_key = Xp.normalize_exercise(want)
	var none = {"ok": false, "sessions": 0, "joined": false, "name": want}
	if old_key == "" or new_key == "" or lift_sessions(old_name) == 0:
		return none
	var joined = false
	if new_key != old_key:
		for s in saved.sessions:
			for ex in s.get("exercises", []):
				if ex is Dictionary and Xp.normalize_exercise(ex.get("name", "")) == new_key:
					joined = true
					want = str(ex.name).strip_edges()
	elif want == old_name.strip_edges():
		return none
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.make_dir_recursive_absolute(BACKUP_DIR)
		DirAccess.copy_absolute(SAVE_PATH, "%s/save-%s-before-rename-%d.json" % [BACKUP_DIR, today, now_ms()])
	var n = 0
	for s in saved.sessions:
		var hit = false
		for ex in s.get("exercises", []):
			if ex is Dictionary and Xp.normalize_exercise(ex.get("name", "")) == old_key:
				ex["name"] = want
				hit = true
		if hit:
			n += 1
	if saved.pt.has(old_key):
		var mark = saved.pt[old_key]
		saved.pt.erase(old_key)
		if not saved.pt.has(new_key):
			mark["name"] = want
			saved.pt[new_key] = mark
	# Reps logged as both sides added up (Sides): the lift stays what it was.
	var both_marks = Sides.renamed(saved.settings, old_name, want, joined)
	if not both_marks.is_empty() or saved.settings.has(Sides.KEY):
		saved.settings[Sides.KEY] = both_marks
	var names = saved.inbox.get("names", {}) if saved.get("inbox") is Dictionary else {}
	if names is Dictionary:
		for k in names.keys():
			if Xp.normalize_exercise(str(names[k])) == old_key:
				names[k] = want
	_commit()
	return {"ok": true, "sessions": n, "joined": joined, "name": want}


## The to-do list (game/todos.gd), as stored. A plain list: no mission or plan
## reads it, so a change only saves and redraws. The one exception is a tick
## that pays its small bonus (set_todo_done): that is a claim, and the hero is
## worked out again.
func todos() -> Array:
	if not (saved.get("todos") is Array):
		saved["todos"] = []
	return saved.todos


func _todo(id: String):
	for t in todos():
		if str(t.id) == id:
			return t
	return null


func _todos_changed() -> void:
	saved.updatedAt = now_ms()
	_write()
	changed.emit()


## Add an item. Returns it, or null when there are no words in it.
func add_todo(text: String):
	if Todos.clean(text) == "":
		return null
	var t = Todos.new_item(text, now_ms())
	todos().append(t)
	_todos_changed()
	return t


## Tick an item off, or untick it. A tick pays a small bonus the first time
## (Todos.bonus_for: once per item, a few a day) as a claim, so the XP and the
## coins come from the replay; unticking takes nothing back. Returns the XP
## it paid (0 for none).
func set_todo_done(id: String, done: bool) -> int:
	var t = _todo(id)
	if t == null or bool(t.done) == done:
		return 0
	t.done = done
	t.doneOn = today if done else ""
	var xp = Todos.bonus_for(saved.claims, id, today) if done else 0
	if xp <= 0:
		_todos_changed()
		return 0
	var before = state
	saved.claims.append({"id": Rng.uid("q"), "questId": Todos.claim_id(id), "xp": xp, "claimedAt": now_ms(), "date": today})
	_commit()
	announce_unlocks(before)
	return xp


func remove_todo(id: String) -> void:
	var t = _todo(id)
	if t == null:
		return
	todos().erase(t)
	_todos_changed()


## Take every ticked item off the list. Returns how many went.
func clear_done_todos() -> int:
	var n = Todos.done_count(todos())
	if n == 0:
		return 0
	saved.todos = todos().filter(func(t): return not bool(t.done))
	_todos_changed()
	return n


## Books (game/books.gd), as stored: the shelf and the book being read. A
## change saves and redraws; only the pages a bookmark adds go into the
## reading log (set_book_page), and that works the hero out again.
func books() -> Array:
	if not (saved.get("books") is Array):
		saved["books"] = []
	return saved.books


func _books_changed() -> void:
	saved.updatedAt = now_ms()
	_write()
	changed.emit()


## Add books (Books.parse_list rows, or one). A book already there (the same
## title and author) is left as it is. Returns how many were added.
func add_books(items: Array) -> int:
	var have = {}
	for b in books():
		have[Books.key(str(b.title), str(b.author))] = true
		have[Books.key(str(b.title))] = true
	var n = 0
	for it in items:
		if not (it is Dictionary) or Books.clean(it.get("title", "")) == "":
			continue
		var k = Books.key(str(it.title), str(it.get("author", "")))
		if have.has(k) or (str(it.get("author", "")) == "" and have.has(Books.key(str(it.title)))):
			continue
		have[k] = true
		var status = str(it.get("status", "finished"))
		var b = Books.new_book(str(it.title), str(it.get("author", "")), str(it.get("series", "")), int(it.get("num", 0)), int(it.get("pages", 0)),
			status, int(it.get("page", 0)), now_ms() + n, "")
		books().append(b)
		n += 1
	if n > 0:
		_books_changed()
	return n


## The page the reading of a book stopped on, today: the day's pages of it
## change by what the bookmark moved (Books.set_page), and the reading log
## with them. Returns {"delta", "pages" (of this book today), "day" (all the
## day's pages)}, or {} when there is no such book.
func set_book_page(id: String, page: int) -> Dictionary:
	var b = Books.find(books(), id)
	if b == null:
		return {}
	var r = Books.set_page(b, page, today)
	var i = books().find(b)
	saved.books[i] = r.book
	var e = Reading.entry_on(reading(), today)
	var cur = int(e.pages) if e != null else 0
	var want = Reading.clamp_pages(cur + int(r.delta))
	var day = cur
	if want != cur:
		# (set_reading saves the book with the day's pages)
		day = set_reading(today, want)
	else:
		_books_changed()
	return {"delta": day - cur, "pages": int(r.pages), "day": day}


## Finish a book (today), or put it back to being read.
func set_book_finished(id: String, finished: bool) -> void:
	var b = Books.find(books(), id)
	if b == null:
		return
	b.status = "finished" if finished else "reading"
	b.finished = today if finished else ""
	_books_changed()


## Change what is known of a book: {"title", "author", "series", "num", "pages", "page"}.
## The bookmark set here moves no pages (it is where the reading stands, not reading done).
func update_book(id: String, fields: Dictionary) -> void:
	var b = Books.find(books(), id)
	if b == null:
		return
	for k in ["title", "author", "series"]:
		if fields.has(k) and (k != "title" or Books.clean(fields[k]) != ""):
			b[k] = Books.clean(fields[k])
	for k in ["num", "pages", "page"]:
		if fields.has(k):
			b[k] = clampi(int(fields[k]), 0, Books.MAX_PAGE)
	_books_changed()


## Take a book off the shelf. The pages it added to the reading log stay.
func remove_book(id: String) -> void:
	var b = Books.find(books(), id)
	if b == null:
		return
	books().erase(b)
	_books_changed()


## Climbing projects (game/projects.gd), as stored: open, sent and set aside.
func projects() -> Array:
	return saved.projects


func open_projects() -> Array:
	return saved.projects.filter(func(p): return Projects.is_open(p))


## Pick a new project. Returns it, or null when MAX_OPEN are already open.
func add_project(grade: int, yds: String, name: String):
	if open_projects().size() >= Projects.MAX_OPEN:
		return null
	var p = Projects.new_project(grade, yds, name, today)
	saved.projects.append(p)
	saved.updatedAt = now_ms()
	_write()
	changed.emit()
	return p


func _project(id: String):
	for p in saved.projects:
		if str(p.id) == id:
			return p
	return null


## The project is sent: on `date`, in session `session_id` (may be ""). Pays
## Projects.SEND_XP as a claim, so the XP and coins come from the replay.
func send_project(id: String, session_id: String, date: String) -> void:
	var p = _project(id)
	if p == null or str(p.sent) != "":
		return
	p.sent = date if date != "" else today
	p.sessionId = session_id
	p.aside = ""
	var qid = "project:" + id
	if not saved.claims.any(func(c): return str(c.get("questId", "")) == qid):
		saved.claims.append({"id": Rng.uid("q"), "questId": qid, "xp": Projects.SEND_XP, "claimedAt": now_ms(), "date": str(p.sent)})
	_commit()


## Set a project aside (on = true) or bring it back. A sent project brought
## back is open again (its XP stays: it was earned).
func set_project_aside(id: String, on: bool) -> void:
	var p = _project(id)
	if p == null:
		return
	if on:
		p.aside = today
	else:
		if not Projects.is_open(p) and open_projects().size() >= Projects.MAX_OPEN:
			return
		p.aside = ""
		p.sent = ""
		p.sessionId = ""
	saved.updatedAt = now_ms()
	_write()
	changed.emit()


## Rename a project (its words; the grade stays).
func rename_project(id: String, name: String) -> void:
	var p = _project(id)
	if p == null:
		return
	p.name = name.strip_edges()
	saved.updatedAt = now_ms()
	_write()
	changed.emit()


## The reel's project cards for newly logged climbs: "was it your project?"
## for a send of its grade, else how many sessions it has been.
func _project_events(fresh: Array) -> Array:
	var out = []
	var seen = {}
	for s in fresh:
		for p in Projects.sent_in(saved.projects, s):
			if not seen.has(p.id):
				seen[p.id] = true
				out.append({"type": "project", "id": str(p.id), "ask": true, "sessionId": str(s.id), "date": str(s.date)})
	for s in fresh:
		for p in Projects.tried_in(saved.projects, s):
			if not seen.has(p.id):
				seen[p.id] = true
				out.append({"type": "project", "id": str(p.id), "ask": false, "sessionId": str(s.id), "date": str(s.date)})
	return out


## Days a week to aim for with a PT lift.
func set_pt_goal(lift_name: String, per_week: int) -> void:
	var at = Pt.mark_of(saved.pt, lift_name)
	if at == "":
		return
	saved.pt[at]["perWeek"] = clampi(per_week, 1, Pt.MAX_PER_WEEK)
	saved.updatedAt = now_ms()
	_write()
	_quests = null
	_plan = null
	_ahead = null
	changed.emit()


## "(PT)" in front of an exercise name (typed in the Log tab), or the mark the
## phone note left on an exercise, makes that lift a PT lift: the tag comes off
## the name and the lift goes into saved.pt. Called for every session that is saved.
##
## A name typed in the Log tab is also put in the "Movement - Variation" form
## (game/lift_names.gd: "barbell shrug" is saved as Shrug - Barbell), unless it
## is already a lift in the log. The phone note's sessions were named in its
## review already (they carry inboxKey), so their names are kept.
##
## The Log tab's "L+R" key leaves "bothSides" (true / false) on an exercise it
## was touched on: the lift's reps are, or are not, both sides added up
## (Sides). It is stored for the lift under its final name and the flag is
## taken off.
func absorb_pt(session: Dictionary) -> void:
	if str(session.get("discipline", "")) != "lift":
		return
	var typed_here = str(session.get("inboxKey", "")) == ""
	var own = lift_names() if typed_here else []
	var have = {}
	for n in own:
		have[Xp.normalize_exercise(str(n))] = true
	for ex in session.get("exercises", []):
		var tag = Pt.untag(str(ex.get("name", "")))
		var on = bool(tag.pt) or bool(ex.get("pt", false))
		ex.erase("pt")
		var both = ex.get("bothSides")
		ex.erase("bothSides")
		var n = str(tag.name).strip_edges()
		if n == "":
			continue
		if typed_here and not have.has(Xp.normalize_exercise(n)):
			n = str(LiftNames.resolve(n, own).name)
		ex["name"] = n
		if on and Pt.mark_of(saved.pt, n) == "":
			saved.pt[Pt.key(n)] = {"name": n, "perWeek": Pt.DEFAULT_PER_WEEK}
		if both is bool and Sides.both(saved.settings, n) != both:
			saved.settings[Sides.KEY] = Sides.with_mark(saved.settings, n, both)


## Every exercise name in the log, most recent first.
func lift_names() -> Array:
	var out = []
	var seen = {}
	var lifts = saved.sessions.filter(func(x): return str(x.get("discipline", "")) == "lift")
	TTUtil.stable_sort(lifts, func(a, b): return str(a.date) > str(b.date))
	for x in lifts:
		for ex in x.get("exercises", []):
			var k = Xp.normalize_exercise(str(ex.get("name", "")))
			if k != "" and not seen.has(k):
				seen[k] = true
				out.append(str(ex.name))
	return out


## Pages read: [{id, date, pages, createdAt}], one entry per day (see Reading).
func reading() -> Array:
	var r = saved.get("reading")
	return r if r is Array else []


## Coins to spend (see Wallet).
func coins() -> int:
	return Wallet.balance(state)


func loadout() -> Dictionary:
	return saved.loadout


func active_pet():
	return saved.get("activePet")


func weight_unit() -> String:
	return saved.settings.weightUnit


func distance_unit() -> String:
	return saved.settings.distanceUnit


func session_by_id(id):
	if id == null:
		return null
	for s in saved.sessions:
		if s.id == id:
			return s
	return null


func body_by_id(id):
	if id == null:
		return null
	for e in saved.body:
		if e.id == id:
			return e
	return null


## What the missions read from the save (Missions.daily / weekly).
func mission_data() -> Dictionary:
	return {"sessions": saved.sessions, "pt": pt(), "settings": saved.settings, "reading": reading(), "now": today}


## {"daily": [...], "weekly": [...], "yesterday": [...]} for today (cached until
## the data changes). The missions are made from the player's own log
## (Missions); "yesterday" holds yesterday's finished missions not claimed yet,
## since a workout is often imported the day after.
func quests() -> Dictionary:
	if _quests == null:
		var data = mission_data()
		var yday = Dates.add_days(today, -1)
		_quests = {
			"daily": Missions.daily(today, data, state, saved.claims),
			"weekly": Missions.weekly(Dates.week_key(today), today, data, state, saved.claims),
			"yesterday": Missions.daily(yday, data, state, saved.claims).filter(func(m): return m.done and not m.claimed),
		}
		for m in _quests.yesterday:
			m.desc = str(m.desc).replace("today", "yesterday")
	return _quests


## What the player will probably do today (Missions.day_plan; cached).
func plan() -> Dictionary:
	if _plan == null:
		_plan = Missions.day_plan(saved.sessions, today, pt(), saved.settings)
	return _plan


## The next days as they will probably go (Missions.ahead; cached). Read only:
## nothing of it is stored.
func ahead() -> Array:
	if _ahead == null:
		_ahead = Missions.ahead(saved.sessions, today, pt(), saved.settings)
	return _ahead


## How many finished quests are waiting to be claimed.
func claimable_quests() -> int:
	var q = quests()
	var n = 0
	for x in q.daily + q.weekly + q.get("yesterday", []):
		if x.done and not x.claimed:
			n += 1
	return n


func next_goals(limit: int = 4) -> Array:
	# Not the goals of a discipline kept in the Miscellaneous area (cycling,
	# Misc.SIDE): it is done now and then and is nothing to chase. The ported
	# NextUp is left as it is (the parity tests compare it).
	var out = []
	for g in NextUp.next_goals(state, 100000):
		if g.get("discipline") != null and Misc.SIDE.has(str(g.discipline)):
			continue
		out.append(g)
		if out.size() >= limit:
			break
	return out


## True when the data folder was redirected with TINY_TITAN_DATA (the automated tests).
func is_test_data() -> bool:
	return OS.get_environment("TINY_TITAN_DATA") != ""


## Where recap pictures are saved: "Tiny Titan" inside the Pictures folder
## (inside the data folder during tests, or when there is no Pictures folder).
func recap_dir() -> String:
	var pics = "" if is_test_data() else OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics == "":
		return DATA_DIR + "recaps"
	return pics.path_join("Tiny Titan")


## The last recap of each kind the player opened from the Hero tab:
## {"week": Monday key, "month": "YYYY-MM"} (either may be missing).
func recap_seen() -> Dictionary:
	var v = saved.settings.get("recapSeen")
	return v if v is Dictionary else {}


## Remember that a recap was opened, so the Hero tab stops offering it.
## Saved without re-deriving the hero: it does not change the log.
func mark_recap_seen(kind: String, key: String) -> void:
	var seen = recap_seen().duplicate()
	seen[kind] = key
	saved.settings["recapSeen"] = seen
	_write()
	changed.emit()


func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


# ---------------------------------------------------------------------------
# Commands (every change to the saved data goes through one of these)
# ---------------------------------------------------------------------------

func set_profile(p: Dictionary) -> void:
	saved.profile = p
	_commit()


func update_profile(patch: Dictionary) -> void:
	if saved.get("profile") == null:
		return
	saved.profile.merge(patch, true)
	_commit()


func update_settings(patch: Dictionary) -> void:
	saved.settings.merge(patch, true)
	_commit()


## A workout being entered in the Log tab is kept in a small file as it
## changes (a phone may close the app between sets). null drops it.
func draft_store(discipline: String, d) -> void:
	var path = DATA_DIR + "draft-%s.json" % discipline
	if d == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()


## Today's kept draft of that kind of workout, or null (an older one is dropped).
func draft_load(discipline: String):
	var path = DATA_DIR + "draft-%s.json" % discipline
	if not FileAccess.file_exists(path):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or str(d.get("day", "")) != today:
		DirAccess.remove_absolute(path)
		return null
	return TTUtil.normalize_json(d)


## Today's lift session (the newest), or null.
func lift_today():
	var out = null
	for s in saved.sessions:
		if str(s.get("discipline", "")) == "lift" and str(s.get("date", "")) == today:
			if out == null or float(s.get("createdAt", 0)) >= float(out.get("createdAt", 0)):
				out = s
	return out


## Stamp a new session with an id, creation time and the perk snapshot.
## `partial` holds discipline, date and the discipline's own fields.
func build_session(partial: Dictionary) -> Dictionary:
	var s = partial.duplicate(true)
	s["id"] = Rng.uid("s")
	if s.get("createdAt") == null:
		s["createdAt"] = now_ms()
	if not s.has("source"):
		s["source"] = "manual"
	# Gear bonuses are per discipline; a misc activity (game/misc.gd) has none.
	s["bonusPct"] = TTUtil.jsround(float(perks.xp.get(s.discipline, 0.0)) * 1000.0) / 1000.0
	s["luckPct"] = TTUtil.jsround(float(perks.luck) * 1000.0) / 1000.0
	return s


## Add sessions to the log and queue the results reel.
func commit_sessions(new_sessions: Array, title: String) -> void:
	if new_sessions.is_empty():
		return
	var before = state
	var known = {}
	for s in saved.sessions:
		known[s.id] = true
	var fresh = []
	for s in new_sessions:
		if not known.has(s.id):
			absorb_pt(s)
			fresh.append(s)
			saved.sessions.append(s)
	if fresh.is_empty():
		return
	_commit()
	var events
	if fresh.size() == 1:
		events = Diff.diff_states(before, state, fresh[0])
	else:
		events = Diff.diff_bulk(before, state, fresh)
	# The rules word their record cards in kg and km: in the player's units.
	events = Units.records(events, before.prs, state.prs, settings())
	# (a lift logged as both sides added up: its estimate goes by one side)
	var fresh_ids = fresh.map(func(s): return s.id)
	events = Sides.fix_estimates(events, fresh, saved.sessions.filter(func(s): return not fresh_ids.has(s.id)), settings())
	events = _with_extras(events, Diff.diff_extras(before, state, fresh[0].discipline if fresh.size() == 1 else null, settings()))
	events = _with_extras(events, _project_events(fresh))
	events = _with_extras(events, _split_events(fresh))
	var ids = []
	for s in fresh:
		ids.append(s.id)
	var res = {"key": ",".join(PackedStringArray(ids)), "events": events, "title": title}
	if fresh.size() == 1 and str(fresh[0].get("discipline", "")) == "lift":
		res["replay"] = replay_moves(fresh[0])
	result_ready.emit(res)


## Record cards for the reel: a run's time over a distance (its best mile,
## 5K... typed as a split, or the run itself) that beats the best before it
## (game/run_splits.gd). A first time over a distance is no record yet.
func _split_events(fresh: Array) -> Array:
	var out = []
	var fresh_ids = {}
	for s in fresh:
		fresh_ids[s.id] = true
	var du = distance_unit()
	for r in RunSplits.records(saved.sessions.filter(func(s): return not fresh_ids.has(s.id)), fresh):
		out.append({"type": "pr", "icon": str(TT.DISCIPLINE_META.run.icon), "title": "%s!" % str(RunSplits.by_id(str(r.id)).best),
			"detail": "%s (was %s) · %s" % [RunSplits.fmt_time(int(r.sec)), RunSplits.fmt_time(int(r.was)), Fmt.fmt_pace(RunSplits.pace(str(r.id), float(r.sec)), du)]})
	return out


## The workout replay of a lift session (the results reel's hero acts it out):
## up to REPLAY_MAX exercises as {move, variation, sets (in words), pose, n, vol}.
const REPLAY_MAX = 5
func replay_moves(session: Dictionary) -> Array:
	var wu = weight_unit()
	var fw = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var out = []
	for ex in session.get("exercises", []):
		var sets = LiftTrend.real_sets(ex.get("sets", []))
		if sets.is_empty():
			continue
		var vol = 0.0
		for st in sets:
			vol += float(st.get("weightKg", 0.0)) * float(st.get("reps", 0))
		var sp = LiftNames.split(str(ex.get("name", "")))
		out.append({"move": str(sp.move), "variation": str(sp.variation), "sets": LiftHistory.describe_sets(sets, fw),
			"pose": Missions.pose_of(str(ex.get("name", ""))), "n": sets.size(), "vol": vol})
		if out.size() >= REPLAY_MAX:
			break
	return out


func update_session(session: Dictionary) -> void:
	absorb_pt(session)
	for i in range(saved.sessions.size()):
		if saved.sessions[i].id == session.id:
			saved.sessions[i] = session
	_commit()


func delete_session(id) -> void:
	saved.sessions = saved.sessions.filter(func(x): return x.id != id)
	_commit()


## Add a body check-in and queue its results reel.
func commit_body(entry: Dictionary) -> void:
	for e in saved.body:
		if e.id == entry.id:
			return
	var before = state
	saved.body.append(entry)
	_commit()
	result_ready.emit({"key": entry.id, "events": _with_extras(Diff.diff_body(before, state, entry), Diff.diff_extras(before, state)), "title": "Checked in!"})


func update_body(entry: Dictionary) -> void:
	for i in range(saved.body.size()):
		if saved.body[i].id == entry.id:
			saved.body[i] = entry
	_commit()
	_prune_photos()


func delete_body(id) -> void:
	saved.body = saved.body.filter(func(x): return x.id != id)
	_commit()
	_prune_photos()


## Claim a finished quest (a quest Dictionary from `quests()`).
func claim_quest(q: Dictionary) -> void:
	for c in saved.claims:
		if c.questId == q.id:
			return
	saved.claims.append({"id": Rng.uid("q"), "questId": q.id, "xp": q.xp, "claimedAt": now_ms(), "date": today})
	_commit()
	Sfx.claim()
	toast("+%s XP, +%s coins — %s" % [Xp.fmt_int(q.xp), Xp.fmt_int(Wallet.xp_coins(q.xp)), q.title], "good", "gift")


## Reel events with the bounty card right after the boss cards and the coins last.
func _with_extras(events: Array, extras: Array) -> Array:
	var out: Array = events.duplicate()
	var at: int = 0
	for i in range(out.size()):
		if ["xp", "import", "bodyxp", "boss"].has(out[i].type):
			at = i + 1
	for e in extras:
		if e.type == "bounty" or e.type == "pr" or e.type == "project":
			out.insert(at, e)
			at += 1
		else:
			out.append(e)
	return out


## Buy a shop item with coins. Returns "" when bought, else why not
## ("owned" | "level" | "coins" | "unknown"). Nothing is charged twice:
## the purchase is a line in the save and the coins are counted from the log.
func buy_item(id: String) -> String:
	var it = Items.by_id(id)
	if it == null or not Wallet.is_shop(it):
		return "unknown"
	var check = Wallet.can_buy(state, it, Dates.week_key(today))
	if not check.ok:
		return check.why
	var before = state
	saved.purchases.append({"id": Rng.uid("b"), "itemId": id, "cost": int(check.price), "at": now_ms(), "date": today})
	_commit()
	announce_unlocks(before)
	return ""


## Toasts for what the state has now and `before` did not: trophies, gear,
## companions and levels. For changes that have no results reel of their own
## (the shop, reading).
func announce_unlocks(before: Dictionary) -> void:
	for ach_id in state.achievements:
		if not before.achievements.has(ach_id):
			var a = Achievements.by_id(ach_id)
			if a != null:
				toast("Trophy: %s (+%s XP)" % [a.name, Xp.fmt_int(a.xp)], "good", "trophy")
	for item_id in state.items:
		if not before.items.has(item_id) and str(state.items[item_id].get("how", "")) != "shop":
			var it = Items.by_id(item_id)
			if it != null:
				toast("New gear: %s" % it.name, "good", "chest")
	for pet_id in state.pets:
		if not before.pets.has(pet_id):
			var p = Pets.by_id(pet_id)
			if p != null:
				toast("%s the %s joined you" % [p.name, p.species], "good", "paw")
	if int(state.levels.hero.level) > int(before.levels.hero.level):
		toast("Hero level %d!" % int(state.levels.hero.level), "good", "star")
	var read_lv = int(Reading.level_of(state).level)
	if read_lv > int(Reading.level_of(before).level):
		toast("Reading level %d!" % read_lv, "good", "book")


## Add `pages` to what was read on `date` ("" = today); a negative number takes
## pages back. Returns the day's new number of pages.
func add_reading(pages: int, date: String = "") -> int:
	var day = today if date == "" else date
	var e = Reading.entry_on(reading(), day)
	var cur = int(e.pages) if e != null else 0
	return set_reading(day, cur + pages)


## Pages read that came from the phone note: added to the day, and remembered
## under the note entry's `key`. With `replaces_key` (the key of the same line
## before it was edited) the day changes by the difference.
func import_reading(date: String, pages: int, key: String, replaces_key: String = "") -> void:
	var log = reading()
	var day = date
	var e = Reading.entry_on(log, day)
	var old_pages = 0
	if replaces_key != "":
		var was = Reading.entry_with_key(log, replaces_key)
		if was != null and str(was.date) == day:
			old_pages = int(was.inbox.get(replaces_key, 0))
	var cur = int(e.pages) if e != null else 0
	var record = e.inbox.duplicate() if (e != null and e.get("inbox") is Dictionary) else {}
	record.erase(replaces_key)
	record[key] = int(record.get(key, 0)) + pages
	var before = state
	saved["reading"] = Reading.with_day(log, day, maxi(1, cur - old_pages + pages), Rng.uid("r"), now_ms(), record)
	_commit()
	announce_unlocks(before)


## Set the pages read on a day (0 takes the day out of the log). Returns the
## day's pages. Unlocks are announced as toasts: reading has no results reel.
func set_reading(date: String, pages: int) -> int:
	var want = Reading.clamp_pages(pages)
	var e = Reading.entry_on(reading(), date)
	if (int(e.pages) if e != null else 0) == want:
		return want
	var before = state
	saved["reading"] = Reading.with_day(reading(), date, want, Rng.uid("r"), now_ms())
	_commit()
	announce_unlocks(before)
	return want


func equip(slot: String, id) -> void:
	saved.loadout[slot] = id
	_commit()


## Phone inbox settings ({source, imported, lastChecked, auto, names}). Saved
## without re-deriving the hero: none of it changes the log.
func update_inbox(patch: Dictionary) -> void:
	saved.inbox.merge(patch, true)
	_write()


func set_active_pet(id) -> void:
	saved.activePet = id
	_commit()


## Replace the whole saved state (import / tests). `data` must come from `parse_saved` or `empty_saved`.
func replace_all(data: Dictionary) -> void:
	saved = data
	_photo_cache.clear()
	_commit()
	nav_changed.emit()


## The save as merged with the phone's (or the PC's) copy (app/cloud_sync.gd):
## taken on like a load, without counting as a change made here. False (and
## nothing changed) when it is not a save.
func apply_synced(data: Dictionary) -> bool:
	var parsed = parse_saved(data)
	if parsed == null:
		return false
	var had_profile = has_profile()
	saved = parsed
	_photo_cache.clear()
	_write()
	_recompute()
	changed.emit()
	if had_profile != has_profile():
		nav_changed.emit()
	return true


## Progress photos were fetched from the other device (app/cloud_sync.gd): the
## screens showing an empty frame are drawn again.
func photos_arrived() -> void:
	_photo_cache.clear()
	changed.emit()


## Wipe everything (Settings → reset). Photos are deleted too.
func reset_all() -> void:
	for d in ["lift", "climb"]:
		draft_store(d, null)
	saved = empty_saved()
	_commit()
	_prune_photos()
	tab = "home"
	nav_changed.emit()


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

## Switch tab. `sub` optionally picks the Adventure / Journey sub-tab.
func go(to_tab: String, sub = null) -> void:
	tab = to_tab
	if sub != null:
		if to_tab == "adventure":
			adventure_tab = sub
		elif to_tab == "journey":
			journey_tab = sub
	nav_changed.emit()


## Open the Log tab. discipline: null (picker), "lift" | "climb" | "run" | "ride" | "body".
## Pass `edit_id` to edit an existing session (or body check-in when discipline is "body").
func open_log(discipline = null, edit_id = null) -> void:
	log_discipline = discipline
	editing_session_id = null
	editing_body_id = null
	if edit_id != null:
		if discipline == "body":
			editing_body_id = edit_id
		else:
			editing_session_id = edit_id
	tab = "log"
	nav_changed.emit()


## Go to the Armory with the shop open.
func open_shop() -> void:
	armory_tab_request = "shop"
	tab = "armory"
	nav_changed.emit()


func set_adventure_tab(t: String) -> void:
	adventure_tab = t
	nav_changed.emit()


func set_journey_tab(t: String) -> void:
	journey_tab = t
	nav_changed.emit()


## kind: "info" | "good" | "bad". icon: an Icons name ("" for the default).
func toast(text: String, kind: String = "info", icon: String = "") -> void:
	toast_requested.emit(text, kind, icon)


# ---------------------------------------------------------------------------
# Progress photos (files in user://photos, never inside the save file)
# ---------------------------------------------------------------------------

func photo_path(id: String) -> String:
	return "%s/%s.jpg" % [PHOTO_DIR, id]


func has_photo(id) -> bool:
	return id != null and FileAccess.file_exists(photo_path(str(id)))


## Copy a picture from disk into the game (downscaled). Returns the new photo id, or "" on failure.
func import_photo(source_path: String) -> String:
	var img = Image.load_from_file(source_path)
	if img == null or img.is_empty():
		return ""
	return _store_image(img)


## Picture bytes (jpg, png or webp, judged by `name`'s extension) -> Image, or null.
func decode_image(bytes: PackedByteArray, name: String):
	var order = ["jpg", "png", "webp"]
	var ext = name.get_extension().to_lower()
	if ext == "jpeg":
		ext = "jpg"
	if order.has(ext):
		order.erase(ext)
		order.push_front(ext)
	for kind in order:
		var img = Image.new()
		var err = ERR_FILE_UNRECOGNIZED
		match kind:
			"jpg":
				err = img.load_jpg_from_buffer(bytes)
			"png":
				err = img.load_png_from_buffer(bytes)
			"webp":
				err = img.load_webp_from_buffer(bytes)
		if err == OK and not img.is_empty():
			return img
	return null


## Store picture bytes (from the phone note) as a photo. Returns the new id, or "" on failure.
func import_photo_bytes(bytes: PackedByteArray, name: String) -> String:
	var img = decode_image(bytes, name)
	if img == null:
		return ""
	return _store_image(img)


func _store_image(img: Image) -> String:
	var w = img.get_width()
	var h = img.get_height()
	var longest = max(w, h)
	if longest > PHOTO_MAX_SIDE:
		var k = float(PHOTO_MAX_SIDE) / float(longest)
		img.resize(maxi(1, int(round(w * k))), maxi(1, int(round(h * k))), Image.INTERPOLATE_LANCZOS)
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	var id = Rng.uid("p").replace("_", "").replace("-", "").to_lower()
	var err = img.save_jpg(photo_path(id), 0.85)
	if err != OK:
		return ""
	return id


## The photo as a texture (cached), or null when the file is missing.
func photo_texture(id):
	if id == null:
		return null
	var key = str(id)
	if _photo_cache.has(key):
		return _photo_cache[key]
	if not FileAccess.file_exists(photo_path(key)):
		return null
	var img = Image.load_from_file(photo_path(key))
	if img == null or img.is_empty():
		return null
	var tex = ImageTexture.create_from_image(img)
	if _photo_cache.size() > 24:
		_photo_cache.clear()
	_photo_cache[key] = tex
	return tex


func referenced_photo_ids() -> Array:
	var ids = []
	for e in saved.body:
		var photos = e.get("photos")
		if photos is Dictionary:
			for k in photos:
				if photos[k] != null and str(photos[k]) != "":
					ids.append(str(photos[k]))
	return ids


## Delete photo files that no check-in refers to any more.
func _prune_photos() -> void:
	var keep = {}
	for id in referenced_photo_ids():
		keep[id] = true
	var d = DirAccess.open(PHOTO_DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".jpg") and not keep.has(f.get_basename()):
			d.remove(f)
			_photo_cache.erase(f.get_basename())


# ---------------------------------------------------------------------------
# Backups
# ---------------------------------------------------------------------------

## Write a backup file anyone can keep (same format as the web app's export,
## photos included). Returns "" on success or an error message.
## Without photos (`with_photos` false) the file is the log alone: small, and
## the photos already on a device stay when it is restored there.
func export_backup(path: String, with_photos: bool = true) -> String:
	var out = saved.duplicate(true)
	if with_photos:
		var photos = {}
		for id in referenced_photo_ids():
			if FileAccess.file_exists(photo_path(id)):
				var bytes = FileAccess.get_file_as_bytes(photo_path(id))
				photos[id] = "data:image/jpeg;base64," + Marshalls.raw_to_base64(bytes)
		out["photos"] = photos
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "Could not write to that location."
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	return ""


## A backup file was made on this device just now (Settings -> Export backup):
## remembered next to the save, for "last backed up" and the reminder.
func note_backup(with_photos: bool = true) -> void:
	var info = backup_info()
	info["at"] = now_ms()
	info["updatedAt"] = saved.get("updatedAt", 0)
	if with_photos:
		# Which photos that file holds, and of what day it is.
		info["photoIds"] = photos_here()
		info["photosDay"] = today
	var f = FileAccess.open(DATA_DIR + "backup.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(info))
		f.close()
	changed.emit()


## The photos the log names that are on this device.
func photos_here() -> Array:
	return referenced_photo_ids().filter(func(id): return FileAccess.file_exists(photo_path(id)))


## The photos the log names that are NOT on this device (a log restored without them).
func photos_missing() -> Array:
	return referenced_photo_ids().filter(func(id): return not FileAccess.file_exists(photo_path(id)))


## Photos on this device that are in no backup file made here yet.
func photos_unsaved() -> Array:
	var ids = backup_info().get("photoIds", [])
	var kept = {}
	if ids is Array:
		for id in ids:
			kept[str(id)] = true
	return photos_here().filter(func(id): return not kept.has(str(id)))


## How many photos a backup (from read_backup) holds that are missing here.
func photos_to_take(backup: Dictionary) -> int:
	var photos = backup.get("photos", {})
	return photos_missing().filter(func(id): return photos.has(id)).size()


## Take only the photos missing here out of a backup; the log stays as it is.
## Returns how many were added.
func take_photos(backup: Dictionary) -> int:
	var photos = backup.get("photos", {})
	var n = 0
	for id in photos_missing():
		if photos.has(id) and _store_photo_text(str(id), str(photos[id])):
			n += 1
	if n > 0:
		_photo_cache.clear()
		changed.emit()
	return n


func _store_photo_text(id: String, v: String) -> bool:
	var comma = v.find(",")
	if v.begins_with("data:") and comma > 0:
		v = v.substr(comma + 1)
	var bytes = Marshalls.base64_to_raw(v)
	if bytes.is_empty():
		return false
	var f = FileAccess.open(photo_path(id), FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	return true


## {"at": ms, "updatedAt": the save's updatedAt then}, or {} when none was made here.
func backup_info() -> Dictionary:
	var path = DATA_DIR + "backup.json"
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## Days since a backup file was last made here; -1 when never.
func backup_age_days() -> int:
	var at = float(backup_info().get("at", 0))
	if at <= 0.0:
		return -1
	return maxi(0, int((float(now_ms()) - at) / 86400000.0))


## "today", "3 days ago", "never".
func backup_age_text() -> String:
	var d = backup_age_days()
	if d < 0:
		return "never"
	if d == 0:
		return "today"
	return "yesterday" if d == 1 else "%d days ago" % d


## Is it time to remind the player: there is a log to lose, it changed since the
## last backup file, and that was BACKUP_EVERY_DAYS ago or more (or never).
func backup_due() -> bool:
	if not has_profile() or saved.sessions.size() + saved.body.size() < 3:
		return false
	var info = backup_info()
	if info.is_empty():
		return true
	if float(saved.get("updatedAt", 0)) <= float(info.get("updatedAt", 0)):
		return false
	return backup_age_days() >= BACKUP_EVERY_DAYS


## Read a backup file. Returns {"ok": bool, "error": String, "sessions": int, "body": int, "data": parsed}.
## Nothing is changed until `apply_backup(result)` is called.
func read_backup(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "File not found."}
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	var parsed = parse_saved(raw)
	if parsed == null:
		return {"ok": false, "error": "That is not a Tiny Titan backup."}
	var photos = {}
	if raw is Dictionary and raw.get("photos") is Dictionary:
		photos = raw.photos
	return {"ok": true, "error": "", "sessions": parsed.sessions.size(), "body": parsed.body.size(), "data": parsed, "photos": photos}


## Replace the current data with a backup returned by `read_backup`. Returns the number of photos restored.
func apply_backup(backup: Dictionary) -> int:
	var n = 0
	var photos = backup.get("photos", {})
	for id in photos:
		if _store_photo_text(str(id), str(photos[id])):
			n += 1
	_photo_cache.clear()
	for d in ["lift", "climb"]:
		draft_store(d, null)
	saved = backup.data
	_commit()
	tab = "home"
	nav_changed.emit()
	return n


# ---------------------------------------------------------------------------
# Saving / loading
# ---------------------------------------------------------------------------

static func empty_saved() -> Dictionary:
	# The training focus (game/dose.gd) is ON unless switched off: a save that
	# never chose gets "Upper body first" (the user asked for the plan to work
	# that way and then found nothing had changed, 2026-11-22). "" = From my log.
	var settings = TT.DEFAULT_SETTINGS.duplicate(true)
	settings["focus"] = "upper"
	return {
		"profile": null,
		"settings": settings,
		"sessions": [],
		"claims": [],
		"body": [],
		"purchases": [],
		"reading": [],
		"loadout": DEFAULT_LOADOUT.duplicate(true),
		"activePet": null,
		"strava": {"lastSyncAt": null, "athleteName": null},
		"updatedAt": 0,
		"inbox": {"source": "", "imported": {}, "lastChecked": 0, "auto": true, "names": {}},
		"pt": {},
		"projects": [],
		"todos": [],
		"books": [],
	}


## Validate a parsed JSON value into a saved-state Dictionary, or null when it is not one.
static func parse_saved(raw):
	if not (raw is Dictionary) or not (raw.get("sessions") is Array):
		return null
	var o = TTUtil.normalize_json(raw)
	var out = empty_saved()
	if o.get("profile") is Dictionary:
		out.profile = o.profile.duplicate(true)
	if o.get("settings") is Dictionary:
		out.settings.merge(o.settings, true)
	for s in o.sessions:
		if s is Dictionary and s.get("id") is String and s.get("discipline") is String:
			out.sessions.append(s)
	if o.get("claims") is Array:
		for c in o.claims:
			if c is Dictionary and c.has("questId"):
				out.claims.append(c)
	if o.get("body") is Array:
		for b in o.body:
			if b is Dictionary and b.get("id") is String:
				out.body.append(b)
	if o.get("purchases") is Array:
		for p in o.purchases:
			if p is Dictionary and p.get("itemId") is String and (p.get("at") is int or p.get("at") is float) and (p.get("cost") is int or p.get("cost") is float):
				out.purchases.append({"id": str(p.get("id", "")), "itemId": p.itemId, "cost": int(p.cost), "at": int(p.at), "date": str(p.get("date", ""))})
	out.reading = Reading.parse_log(o.get("reading"))
	out.projects = Projects.parse(o.get("projects"))
	out.todos = Todos.parse(o.get("todos"))
	out.books = Books.parse(o.get("books"))
	if o.get("loadout") is Dictionary:
		out.loadout = o.loadout.duplicate(true)
	if o.get("activePet") is String:
		out.activePet = o.activePet
	if o.get("updatedAt") is int or o.get("updatedAt") is float:
		out.updatedAt = int(o.updatedAt)
	var ib = o.get("inbox")
	if ib is Dictionary:
		if ib.get("source") is String:
			out.inbox.source = ib.source
		if ib.get("imported") is Dictionary:
			for k in ib.imported:
				if ib.imported[k] is int or ib.imported[k] is float:
					out.inbox.imported[str(k)] = int(ib.imported[k])
		if ib.get("lastChecked") is int or ib.get("lastChecked") is float:
			out.inbox.lastChecked = int(ib.lastChecked)
		if ib.get("auto") is bool:
			out.inbox.auto = ib.auto
		if ib.get("autoImport") is bool:
			out.inbox["autoImport"] = ib.autoImport
		# (physical therapy lifts are read below, after the inbox)
		# What the player decided a typed lift name means ("" = a lift of its own).
		if ib.get("names") is Dictionary:
			for k in ib.names:
				if ib.names[k] is String:
					out.inbox.names[str(k)] = ib.names[k]
		# Emptying the note's table (app/doc_clear.gd): the script's link and token.
		var cl = ib.get("clear")
		if cl is Dictionary:
			out.inbox["clear"] = {"url": str(cl.get("url", "")), "token": str(cl.get("token", "")),
				"on": bool(cl.get("on", false)), "plan": bool(cl.get("plan", true))}
	# Physical therapy lifts: {normalized name: {"name", "perWeek"}}.
	var marks = o.get("pt")
	if marks is Dictionary:
		for k in marks:
			if marks[k] is Dictionary and str(k) != "":
				var per = marks[k].get("perWeek", Pt.DEFAULT_PER_WEEK)
				out.pt[str(k)] = {"name": str(marks[k].get("name", k)), "perWeek": clampi(int(per) if (per is int or per is float) else Pt.DEFAULT_PER_WEEK, 1, Pt.MAX_PER_WEEK)}
	return out


func _load() -> Dictionary:
	var candidates = [SAVE_PATH, SAVE_BAK]
	var d = DirAccess.open(BACKUP_DIR)
	if d != null:
		var files = Array(d.get_files())
		files.sort()
		files.reverse()
		for f in files:
			candidates.append(BACKUP_DIR + "/" + f)
	var first = true
	for path in candidates:
		if FileAccess.file_exists(path):
			var parsed = parse_saved(JSON.parse_string(FileAccess.get_file_as_string(path)))
			if parsed != null:
				if not first:
					push_warning("Tiny Titan: save file was unreadable, restored from %s" % path)
				return parsed
			# Keep the unreadable file for inspection rather than overwriting it silently.
			if path == SAVE_PATH:
				DirAccess.copy_absolute(SAVE_PATH, "%ssave.unreadable-%d.json" % [DATA_DIR, int(Time.get_unix_time_from_system())])
		first = false
	return empty_saved()


func _write() -> void:
	# Keep the previous good file next to the new one: if a write is ever cut
	# short, loading falls back to it.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_BAK)
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		if not _write_failed:
			_write_failed = true
			toast("Could not save your data to disk!", "bad", "warning")
		return
	f.store_string(JSON.stringify(saved, "  "))
	f.close()
	_write_failed = false
	if cloud != null:
		cloud.local_changed()


## One dated copy per day the game is opened; the newest KEEP_BACKUPS are kept.
func _daily_backup() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dest = "%s/save-%s.json" % [BACKUP_DIR, today]
	if not FileAccess.file_exists(dest):
		DirAccess.copy_absolute(SAVE_PATH, dest)
	var d = DirAccess.open(BACKUP_DIR)
	if d == null:
		return
	var files = Array(d.get_files())
	files.sort()
	while files.size() > KEEP_BACKUPS:
		d.remove(files.pop_front())


func _commit() -> void:
	saved.updatedAt = now_ms()
	_write()
	_recompute()
	changed.emit()


func _recompute() -> void:
	state = Derive.derive({
		"sessions": saved.sessions,
		"claims": saved.claims,
		"body": saved.body,
		"purchases": saved.get("purchases", []),
		"reading": reading(),
		"weeklyGoal": saved.settings.weeklyGoal,
		"today": today,
	})
	perks = Perks.compute_perks(state, saved.loadout, saved.get("activePet"))
	_quests = null
	_plan = null
	_ahead = null
	Art.mood = Recovery.mood(saved.sessions, today)
	# The gym shows today's kind of day (the split's), else a climb day.
	var pl = plan()
	Art.focus = str(pl.kind) if str(pl.kind) != "" else ("climb" if not pl.others.is_empty() and str(pl.others[0].discipline) == "climb" and pl.lifts.is_empty() else "")
	Sfx.enabled = bool(saved.settings.get("sound", true))
	Sfx.buzz_on = bool(saved.settings.get("haptics", true))
