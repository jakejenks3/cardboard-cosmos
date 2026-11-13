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
const DEFAULT_LOADOUT = {"body": "tee_grey", "legs": "shorts_navy", "feet": "trainers_worn"}

## Source of truth: {profile, settings, sessions, claims, body, loadout, activePet, strava, updatedAt}
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
## What the Log tab shows: null = picker, a discipline id, or "body".
var log_discipline = null
var editing_session_id = null
var editing_body_id = null

var _quests = null
var _photo_cache = {}
## Set when the save file could not be written (shown once to the player).
var _write_failed = false


func _ready() -> void:
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
	_recompute()
	var t = Timer.new()
	t.wait_time = 30.0
	t.timeout.connect(_tick)
	add_child(t)
	t.start()


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


## {"daily": [...], "weekly": [...]} for today (cached until the data changes).
func quests() -> Dictionary:
	if _quests == null:
		_quests = {
			"daily": Quests.daily_quests(today, state, saved.sessions, saved.claims),
			"weekly": Quests.weekly_quests(Dates.week_key(today), state, saved.sessions, saved.claims, saved.settings),
		}
	return _quests


## How many finished quests are waiting to be claimed.
func claimable_quests() -> int:
	var q = quests()
	var n = 0
	for x in q.daily + q.weekly:
		if x.done and not x.claimed:
			n += 1
	return n


func next_goals(limit: int = 4) -> Array:
	return NextUp.next_goals(state, limit)


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


## Stamp a new session with an id, creation time and the perk snapshot.
## `partial` holds discipline, date and the discipline's own fields.
func build_session(partial: Dictionary) -> Dictionary:
	var s = partial.duplicate(true)
	s["id"] = Rng.uid("s")
	if s.get("createdAt") == null:
		s["createdAt"] = now_ms()
	if not s.has("source"):
		s["source"] = "manual"
	s["bonusPct"] = TTUtil.jsround(float(perks.xp[s.discipline]) * 1000.0) / 1000.0
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
	var ids = []
	for s in fresh:
		ids.append(s.id)
	result_ready.emit({"key": ",".join(PackedStringArray(ids)), "events": events, "title": title})


func update_session(session: Dictionary) -> void:
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
	result_ready.emit({"key": entry.id, "events": Diff.diff_body(before, state, entry), "title": "Checked in!"})


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
	toast("+%s XP — %s" % [Xp.fmt_int(q.xp), q.title], "good", "gift")


func equip(slot: String, id) -> void:
	saved.loadout[slot] = id
	_commit()


func set_active_pet(id) -> void:
	saved.activePet = id
	_commit()


## Replace the whole saved state (import / tests). `data` must come from `parse_saved` or `empty_saved`.
func replace_all(data: Dictionary) -> void:
	saved = data
	_photo_cache.clear()
	_commit()
	nav_changed.emit()


## Wipe everything (Settings → reset). Photos are deleted too.
func reset_all() -> void:
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
func export_backup(path: String) -> String:
	var out = saved.duplicate(true)
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
		var v = str(photos[id])
		var comma = v.find(",")
		if v.begins_with("data:") and comma > 0:
			v = v.substr(comma + 1)
		var bytes = Marshalls.base64_to_raw(v)
		if bytes.is_empty():
			continue
		var f = FileAccess.open(photo_path(str(id)), FileAccess.WRITE)
		if f != null:
			f.store_buffer(bytes)
			f.close()
			n += 1
	_photo_cache.clear()
	saved = backup.data
	_commit()
	tab = "home"
	nav_changed.emit()
	return n


# ---------------------------------------------------------------------------
# Saving / loading
# ---------------------------------------------------------------------------

static func empty_saved() -> Dictionary:
	return {
		"profile": null,
		"settings": TT.DEFAULT_SETTINGS.duplicate(true),
		"sessions": [],
		"claims": [],
		"body": [],
		"loadout": DEFAULT_LOADOUT.duplicate(true),
		"activePet": null,
		"strava": {"lastSyncAt": null, "athleteName": null},
		"updatedAt": 0,
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
	if o.get("loadout") is Dictionary:
		out.loadout = o.loadout.duplicate(true)
	if o.get("activePet") is String:
		out.activePet = o.activePet
	if o.get("updatedAt") is int or o.get("updatedAt") is float:
		out.updatedAt = int(o.updatedAt)
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
		"weeklyGoal": saved.settings.weeklyGoal,
		"today": today,
	})
	perks = Perks.compute_perks(state, saved.loadout, saved.get("activePet"))
	_quests = null
	Sfx.enabled = bool(saved.settings.get("sound", true))
