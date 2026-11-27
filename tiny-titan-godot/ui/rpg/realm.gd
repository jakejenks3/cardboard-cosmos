class_name RealmScreen
extends UiScreen
## The Realm tab (RPG_PLAN.md 10.0 and 10.1): the turn-based RPG's home, the sixth tab.
##
## THE FIRST VISIT (`saved.rpg.opened` false): in place of the hub, the twelve
## stats count up one after another, each with its first line from the log,
## then "Your training has already earned N skill points" and two keys:
## "Enter the Ironwild" (stores RpgSave.first_open and starts the first fight,
## r1s1) and "Skip" (first_open only). The count-up takes about four seconds,
## a tap ends it, and it runs once while the app is open (a rebuild in the
## middle goes on where it was: the clock is a static).
##
## THE HUB, top to bottom (each with meta "section"):
##   realm_banner    the hero on a Stage in the Realm gear with the companion, "Fighter Lv N" and the XP bar,
##                   Power, ore (in the band), skill points left (a key to the Skills page)
##   realm_notices   only when there is one: Continue the battle · a training chest of today / yesterday with
##                   an Open key · A skill can be learned
##   realm_boosts    a row per boost of the day (a tap says where it came from), or what would earn one
##   realm_tabs      Map · Hero · Moves · Skills · Gear (RpgUi.page; a dot only when something can be done there)
##   realm_<page>    the page: RealmMap.fill, and RealmHero / RealmMoves / RealmSkills / RealmGear.fill when
##                   their files have one (asked for by path, so the hub works while a page is still a stub)
##
## Nothing jumps under the finger: every key has an "anchor_id" meta (UiScreen
## finds it again after a rebuild and keeps it where it was), a chest that was
## just opened keeps its row for the visit (the Open key becomes a tick), and
## where a key cannot stay (the first visit's Enter) presses are dropped for a
## moment (guard_shifts).
##
## Metas for tests: realm_tab (page id; realm_tab_dot on its dot), realm_chest (date) and realm_chest_open on
## its key, realm_continue, realm_skill_notice, realm_boost (id), realm_points (left), realm_level, realm_power,
## realm_page_missing; the first visit: section realm_first, first_stat (id), first_value, first_points,
## first_enter, first_skip.
##
## It only READS the log. It is drawn again when the log changes (App.changed:
## UiScreen does that) and when the Realm's own save changes (App.rpg_changed).

## The hub can open a chest: main.gd shows the tab's "a chest waits" dot.
static var hub_ready = true

const PAGES = [["map", "Map"], ["hero", "Hero"], ["moves", "Moves"], ["skills", "Skills"], ["gear", "Gear"]]
## The first visit's count-up: a stat starts every COUNT_STEP_MS and runs for COUNT_RUN_MS.
const COUNT_STEP_MS = 290.0
const COUNT_RUN_MS = 380.0
## The well the hero stands in.
const WELL_W = 168

## When the count-up began (Time.get_ticks_msec; -1: not yet) and whether it is over.
static var _count_from_ms = -1
static var _count_over = false
## Chests opened in this visit: {date: what came out}. Their rows stay until the tab is left.
static var _opened_now = {}

var _count_rows = []
var _count_tail = []
var _count_said = -1


func _ready() -> void:
	_opened_now = {}
	guard_shifts = true
	super._ready()
	App.rpg_changed.connect(rebuild)
	RpgSfx.hold(1)


func _exit_tree() -> void:
	super._exit_tree()
	RpgSfx.hold(-1)


func _toggle_music() -> void:
	RpgSfx.set_music(not RpgSfx.music_on())
	if RpgSfx.music_on():
		RpgSfx.tune("hub")
		App.toast("Music on", "info", "music")
	else:
		App.toast("Music off", "info", "music_off")


## What the stat engine reads (plain data from App; nothing is changed).
static func sheet_input() -> Dictionary:
	return RpgUi.input()


## A school's colour (a stat is shown in its school's: RpgDefs.STAT_SCHOOL).
static func color_of(school: String) -> Color:
	var c = RpgUi.color(school)
	return Pal.REALM if (c == Pal.MUTED and school != "plain") else c


## The first visit's count-up starts over (a test, a walkthrough).
static func first_reset() -> void:
	_count_from_ms = -1
	_count_over = false


## A key big enough for a finger on a phone.
static func finger(b: Control) -> Control:
	if Kit.fingers:
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 40.0)
	return b


func build() -> void:
	_count_rows = []
	_count_tail = []
	var rpg = RpgUi.save()
	if not bool(rpg.get("opened", false)):
		_build_first()
		set_process(true)
		return
	set_process(false)
	_build_hub(rpg)
	if RpgSfx.battles == 0:
		RpgSfx.tune("hub")


# =============================================================================
# The first visit
# =============================================================================

func _build_first() -> void:
	var sheet = RpgUi.sheet()
	if _count_from_ms < 0:
		_count_from_ms = Time.get_ticks_msec()
	var sec = Kit.section("realm_first", "THE IRONWILD", "realm", Pal.REALM, null, _skip_count, 4, 10)
	sec.set_meta("anchor_id", "realm_first")
	sec.add(Kit.para("A land to fight through, one turn at a time. Everything you have trained is your power here:", 13, Pal.TEXT))
	for stat_id in RpgDefs.STATS:
		var st = sheet.stats.get(stat_id)
		if st == null:
			continue
		var col = color_of(str(RpgDefs.STAT_SCHOOL.get(stat_id, "")))
		var row = Kit.row(Callable(), col, col, 5, 0, 0.12)
		row.custom_minimum_size.y = 30
		row.set_meta("first_stat", str(stat_id))
		var h = Kit.hbox(6)
		h.add_child(Kit.vcenter(Icons.rect(str(RpgDefs.STAT_ICONS.get(stat_id, "star")), 16)))
		var name_l = Kit.label(str(st.name), 13, null, true)
		name_l.custom_minimum_size = Vector2(76, 0)
		h.add_child(Kit.vcenter(name_l))
		var lines = st.get("lines", [])
		h.add_child(Kit.vcenter(Kit.clip(str(lines[0]) if not lines.is_empty() else "", 11, Pal.MUTED)))
		var val = Kit.label("", 16, col, true)
		val.custom_minimum_size = Vector2(28, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.set_meta("first_value", int(st.v))
		h.add_child(Kit.vcenter(val))
		row.add(h)
		sec.add(row)
		_count_rows.append({"row": row, "val": val, "v": int(st.v)})
	var earned = int(RpgUi.points().earned)
	var pts = Kit.hbox(8)
	pts.set_meta("first_points", earned)
	pts.add_child(Kit.vcenter(Icons.rect("sp", 32)))
	pts.add_child(Kit.para("Your training has already earned %d skill points." % earned, 14, Pal.ACCENT, true))
	sec.add(Kit.gap(2))
	sec.add(pts)
	_count_tail.append(pts)
	var enter = Kit.button("Enter the Ironwild", "primary", _enter, "lg", "sword")
	enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter.set_meta("first_enter", true)
	enter.set_meta("anchor_id", "first_enter")
	sec.add(finger(enter))
	sec.add(Kit.clip("Your first fight: one Dust Bunny. It shows you how.", 12, Pal.MUTED))
	var skip = Kit.link("Skip", _skip, 13, Pal.MUTED)
	skip.set_meta("first_skip", true)
	skip.set_meta("anchor_id", "first_skip")
	sec.add(finger(skip))
	add_child(sec)
	_paint_count()


func _process(_delta: float) -> void:
	if _count_rows.is_empty():
		set_process(false)
		return
	_paint_count()


## Is the first visit's count-up over (every stat at its value)?
static func count_done() -> bool:
	return _count_over


## The count-up as it stands now: a row lights up when its turn comes and its
## number runs up; the line about skill points comes last.
func _paint_count() -> void:
	var now = float(Time.get_ticks_msec() - _count_from_ms)
	var done = true
	var at = -1
	for i in range(_count_rows.size()):
		var e = _count_rows[i]
		if not is_instance_valid(e.val):
			continue
		var t = 1.0 if _count_over else clampf((now - float(i) * COUNT_STEP_MS) / COUNT_RUN_MS, 0.0, 1.0)
		if t < 1.0:
			done = false
		if t > 0.0:
			at = i
		var shown = int(round(float(e.v) * (1.0 - pow(1.0 - t, 2.0))))
		e.val.text = str(shown) if t > 0.0 else ""
		e.row.modulate.a = 0.3 + 0.7 * minf(1.0, t * 2.5)
	if not _count_over and at > _count_said:
		_count_said = at
		RpgSfx.play("stat", 1.0 + 0.035 * float(at))
	for c in _count_tail:
		if is_instance_valid(c):
			c.modulate.a = 1.0 if done else 0.0
	if done:
		if not _count_over:
			_count_over = true
			for c in _count_tail:
				if is_instance_valid(c) and c.is_inside_tree():
					Kit.pop(c)
		_count_rows = []


## A tap anywhere on the first visit's card: the numbers are there at once.
func _skip_count() -> void:
	if _count_over:
		return
	_count_over = true
	_paint_count()


func _open_realm() -> void:
	_count_over = true
	RpgUi.page = "map"
	scroll_to_top()
	RpgUi.commit(RpgSave.first_open(RpgUi.save(), App.loadout(), App.active_pet()))


## "Enter the Ironwild": the Realm is opened and the first fight starts.
func _enter() -> void:
	_open_realm()
	RpgUi.fight({"kind": "stage", "id": "r1s1"})


func _skip() -> void:
	_open_realm()


# =============================================================================
# The hub
# =============================================================================

func _build_hub(rpg: Dictionary) -> void:
	var can_learn = RpgSkills.learnable(rpg, RpgUi.sheet(), RpgUi.level(), RpgUi.days())
	if not PAGES.any(func(p): return str(p[0]) == str(RpgUi.page)):
		RpgUi.page = "map"
	# The tabs come first, so they are in the same place on every page and a page starts right under them
	# (they used to sit under the banner and the boosts: every page began a screen down).
	add_child(_tabs(rpg, can_learn))
	if str(RpgUi.page) == "map":
		# The Map is the Realm's front page: the banner, what waits, today's boosts.
		add_child(_banner(rpg))
		var notices = _notices(rpg, can_learn)
		if notices != null:
			add_child(notices)
		add_child(_boost_section(RpgUi.boosts()))
	else:
		# Another page: one slim line, then the page.
		add_child(_slim(rpg))
	var box = Kit.vbox(12)
	box.set_meta("section", "realm_" + str(RpgUi.page))
	_fill_page(box, str(RpgUi.page))
	add_child(box)


## Another page of the hub (also for the pages themselves: `screen.go_page("gear")`).
func go_page(page: String) -> void:
	if RpgUi.page == page:
		return
	RpgSfx.play("select")
	RpgUi.page = page
	rebuild()


## The page's own builder fills `box`. A page whose file has no `fill` yet says so in one line.
func _fill_page(box: VBoxContainer, page: String) -> void:
	if page == "map":
		RealmMap.fill(box, self)
		return
	var path = "res://ui/rpg/realm_%s.gd" % page
	var sc = load(path) if ResourceLoader.exists(path) else null
	if sc != null and has_fill(sc):
		sc.call("fill", box, self)
		return
	var soon = Kit.muted_para("This page is being built", 13)
	soon.set_meta("realm_page_missing", page)
	box.add_child(soon)


## Does a page's script have its `fill`?
static func has_fill(sc) -> bool:
	if not (sc is Script):
		return false
	for m in sc.get_script_method_list():
		if str(m.get("name", "")) == "fill":
			return true
	return false


# --- the banner ------------------------------------------------------------------------------

func _banner(rpg: Dictionary) -> Control:
	var realm = RpgUi.color("realm")
	var sec = Kit.section("realm_banner", "THE IRONWILD", "realm", realm, RpgUi.ore_pill(int(rpg.get("ore", 0))), Callable(), 8, 10)
	var h = Kit.hbox(10)

	var well = PanelContainer.new()
	well.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": null, "lip": 0, "inset": true, "pad_h": 4, "pad_v": 4}))
	well.custom_minimum_size = Vector2(WELL_W, 0)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stage = Stage.new()
	stage.setup(realm, 2)
	well.add_child(stage)
	var look = RpgUi.hero_look()
	if look.get("profile") is Dictionary:
		var hero = HeroView.new()
		hero.min_scale = 2
		hero.setup(look.state, look.profile, look.loadout, null, false)
		hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hero.size_flags_vertical = Control.SIZE_SHRINK_END
		hero.set_meta("realm_hero", true)
		well.add_child(hero)
	if look.get("pet") is String and str(look.pet) != "":
		var pv = PetView.new()
		pv.setup(str(look.pet), 40.0, true)
		pv.size_flags_horizontal = Control.SIZE_SHRINK_END
		pv.size_flags_vertical = Control.SIZE_SHRINK_END
		pv.set_meta("realm_pet", str(look.pet))
		var corner = Kit.pad(pv, 0, 0, 0, 6)
		corner.size_flags_horizontal = Control.SIZE_SHRINK_END
		corner.size_flags_vertical = Control.SIZE_SHRINK_END
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(corner)
	h.add_child(well)

	var side = Kit.vbox(6)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var info = RpgUi.level_info()
	var lvl = Kit.clip("Fighter Lv %d" % int(info.lvl), 19, null, true)
	lvl.set_meta("realm_level", int(info.lvl))
	side.add_child(lvl)
	var need = int(info.get("need", 0))
	var into = int(info.get("into", 0))
	var bar = Kit.bar(float(into) / float(need) if need > 0 else 1.0, realm, 12)
	bar.glint = true
	side.add_child(bar)
	side.add_child(Kit.clip("%s / %s XP to the next level" % [Xp.fmt_int(into), Xp.fmt_int(need)] if need > 0 else "The highest level", 11, Pal.MUTED))
	var power = int(round(RpgHero.power(RpgUi.hero())))
	var pw = Kit.pill("power", "Power %s" % Xp.fmt_int(power), Pal.LIFT)
	pw.set_meta("realm_power", power)
	var prow = Kit.hbox(6)
	prow.add_child(Kit.vcenter(pw))
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_child(gap)
	var on = RpgSfx.music_on()
	var mk = Kit.icon_button("music" if on else "music_off", _toggle_music, "Music", 40 if Kit.fingers else 34)
	mk.set_meta("realm_music", on)
	mk.set_meta("anchor_id", "realm_music")
	prow.add_child(mk)
	side.add_child(prow)
	var left = int(RpgUi.points().left)
	var words = "%d skill point%s to spend" % [left, "" if left == 1 else "s"] if left > 0 else "Skills"
	var sp = Kit.button(words, "primary" if left > 0 else "ghost", go_page.bind("skills"), "sm", "sp")
	sp.set_meta("realm_points", left)
	sp.set_meta("anchor_id", "realm_points")
	sp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.add_child(finger(sp))
	h.add_child(side)
	sec.add(h)
	return sec


## The banner in one line, over the pages that are not the Map: the level and its bar, the ore.
func _slim(rpg: Dictionary) -> Control:
	var realm = RpgUi.color("realm")
	var row = Kit.row(Callable(), realm, realm, 8, 0, 0.14)
	row.set_meta("section", "realm_slim")
	var h = Kit.hbox(8)
	h.add_child(Kit.vcenter(Icons.rect("realm", 16)))
	var info = RpgUi.level_info()
	var lvl = Kit.label("Lv %d" % int(info.lvl), 15, null, true)
	lvl.set_meta("realm_level", int(info.lvl))
	h.add_child(Kit.vcenter(lvl))
	var need = int(info.get("need", 0))
	var bar = Kit.bar(float(int(info.get("into", 0))) / float(need) if need > 0 else 1.0, realm, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(Kit.vcenter(bar))
	var left = int(RpgUi.points().left)
	if left > 0 and str(RpgUi.page) != "skills":
		h.add_child(Kit.vcenter(Kit.pill("sp", str(left), Pal.ACCENT)))
	h.add_child(Kit.vcenter(RpgUi.ore_pill(int(rpg.get("ore", 0)))))
	row.add(h)
	return row


# --- the notices -----------------------------------------------------------------------------

## The rows above the boosts, or null when there is nothing to say.
func _notices(rpg: Dictionary, can_learn: Array):
	var rows = []
	var kept = RpgUi.kept_battle()
	if kept != null:
		var st = RpgUi.stage_of(kept.what)
		var go = Kit.button("Continue", "primary", _continue, "sm")
		go.set_meta("realm_continue", true)
		go.set_meta("anchor_id", "realm_continue")
		rows.append(Kit.notice("sword", "Continue the battle", str(st.get("name", "")) if st is Dictionary else "A fight is waiting where you left it", Pal.DANGER, finger(go)))
	var today = RpgUi.today()
	for date in [today, Dates.add_days(today, -1)]:
		var row = _chest_row(rpg, date, today)
		if row != null:
			rows.append(row)
	if not can_learn.is_empty():
		var left = int(RpgUi.points().left)
		var see = Kit.button("Skills", "ghost", go_page.bind("skills"), "sm")
		see.set_meta("anchor_id", "realm_skill_notice")
		var n = Kit.notice("sp", "A skill can be learned", "%d to pick from · %d point%s to spend" % [can_learn.size(), left, "" if left == 1 else "s"], RpgUi.color("realm"), finger(see))
		n.set_meta("realm_skill_notice", can_learn.size())
		rows.append(n)
	if rows.is_empty():
		return null
	var box = Kit.vbox(6)
	box.set_meta("section", "realm_notices")
	for r in rows:
		box.add_child(r)
	return box


func _continue() -> void:
	RpgUi.resume()


## The training chest of a day as a row: what it holds and an Open key; once
## opened in this visit, what came out and a tick where the key was.
func _chest_row(rpg: Dictionary, date: String, today: String):
	var c = RpgBoosts.chest(RpgUi.input(), date)
	if c == null:
		return null
	var pay = RpgBoosts.chest_pay(c, rpg)
	var pays = bool(pay.first) or int(pay.ore) > 0
	if not pays and not _opened_now.has(date):
		return null
	var tier = str(c.get("tier", "wood"))
	var title = "%s training chest" % ("Today's" if date == today else "Yesterday's")
	var sub = ""
	var action
	if not pays:
		sub = "Opened: %s" % str(_opened_now[date])
		action = Kit.tick_box(true)
	else:
		if bool(pay.first):
			var holds = ["%s ore" % Xp.fmt_int(int(pay.ore))]
			var count = 0
			for it in pay.items:
				count += int(it.get("n", 1))
			if count > 0:
				holds.append("%d item%s" % [count, "" if count == 1 else "s"])
			if bool(pay.rune):
				holds.append("a rune")
			sub = "%s · %s" % [tier.capitalize(), " · ".join(PackedStringArray(holds))]
		else:
			sub = "+%s ore: the day grew since you opened it" % Xp.fmt_int(int(pay.ore))
		action = Kit.button("Open", "primary", Callable(), "sm")
		action.set_meta("realm_chest_open", date)
		action.set_meta("anchor_id", "realm_chest:" + date)
		finger(action)
	var row = Kit.notice(str(RpgBoosts.CHEST_ICONS.get(tier, "chest_wood")), title, sub, Pal.ACCENT, action)
	row.set_meta("realm_chest", date)
	row.set_meta("realm_chest_state", "open" if pays else "opened")
	if pays:
		action.pressed.connect(_open_chest.bind(date, row, action))
	return row


## Open a day's training chest: what is in it goes into the save, and rises from the row.
func _open_chest(date: String, row: Control, key: Control) -> void:
	var rpg = RpgUi.save()
	var c = RpgBoosts.chest(RpgUi.input(), date)
	if c == null:
		return
	var res = RpgSave.claim_chest(rpg, c)
	if not bool(res.get("ok", false)):
		RpgUi.apply(res)
		return
	var pay = RpgBoosts.chest_pay(c, rpg)
	var pack = {"ore": int(pay.ore), "items": pay.items, "runes": RealmMap.new_runes(rpg, res.rpg)}
	var lines = RealmMap.pack_lines(pack)
	_opened_now[date] = " · ".join(PackedStringArray(lines))
	var chest_icon = "chest_" + str(c.get("tier", "wood")).to_lower()
	RealmMap.loot_fx(row, key, lines, "%s training chest" % str(c.get("tier", "Wood")).capitalize(), chest_icon if Icons.has_icon(chest_icon) else "chest_wood")
	RpgUi.apply(res)


# --- the boosts ------------------------------------------------------------------------------

## Today's boosts: what today's and yesterday's training gives the hero.
func _boost_section(boosts: Array) -> Control:
	var count = Kit.label(str(boosts.size()), 12, Pal.TEXT, true) if not boosts.is_empty() else null
	var sec = Kit.section("realm_boosts", "BOOSTS TODAY", "bolt", Pal.ACCENT, count, Callable(), 6, 10)
	if boosts.is_empty():
		var none = Kit.muted_para("None right now. Train today for one today and tomorrow: a pump from lifting, a second wind from a run, chalked hands from a climb, a sharp mind from 10 pages, limber from physical therapy.", 12)
		none.set_meta("realm_no_boost", true)
		sec.add(none)
		return sec
	# Two across, so the map under them is not a scroll away (a list of five rows took a third of the
	# screen). A tile says the boost and what it does; a tap opens it in full, with how long it lasts.
	var grid = Kit.grid(2, 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in boosts:
		var col = color_of(str(b.get("school", "")))
		var row = Kit.row(_open_boost.bind(b), col, col, 6, 0, 0.12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.set_meta("realm_boost", str(b.get("id", "")))
		row.set_meta("anchor_id", "realm_boost:" + str(b.get("id", "")))
		row.custom_minimum_size.y = 44 if Kit.fingers else 40
		var h = Kit.hbox(6)
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var icon_name = str(b.get("icon", "bolt"))
		h.add_child(Kit.vcenter(Icons.rect(icon_name if Icons.has_icon(icon_name) else "bolt", 24)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(Kit.clip(str(b.get("name", "")), 13, null, true))
		v.add_child(Kit.clip(str(b.get("text", "")), 11, Pal.MUTED))
		h.add_child(v)
		row.add(h)
		grid.add_child(row)
	sec.add(grid)
	return sec


## A boost in full: what it does, where it came from, how long it lasts.
func _open_boost(b: Dictionary) -> void:
	var col = color_of(str(b.get("school", "")))
	var sh = Kit.sheet(str(b.get("name", "Boost")))
	sh.box.set_meta("realm_boost_sheet", str(b.get("id", "")))
	sh.box.add_child(Kit.para(str(b.get("text", "")), 15, Pal.TEXT, true))
	var why = str(b.get("why", ""))
	if why != "":
		sh.box.add_child(Kit.sub_head("WHERE IT CAME FROM", col))
		sh.box.add_child(Kit.para(why, 13, Pal.TEXT))
	sh.box.add_child(Kit.sub_head("HOW LONG", col))
	sh.box.add_child(Kit.para("Until the end of tomorrow." if str(b.get("until", "")) > RpgUi.today() else "Until the end of today.", 13, Pal.TEXT))
	sh.box.add_child(Kit.muted_para("A boost is always a bonus on top. Nothing is lost on a day without one.", 12))
	sh.box.add_child(finger(Kit.button("Close", "ghost", sh.close, "lg")))
	sh.open()


# --- the sub-tabs ----------------------------------------------------------------------------

## Is there something to do on a page (its tab gets a dot)?
static func page_dot(page: String, rpg: Dictionary, can_learn: Array) -> bool:
	match page:
		"skills":
			return not can_learn.is_empty()
		"map":
			return RealmMap.something_waits(rpg)
	return false


func _tabs(rpg: Dictionary, can_learn: Array) -> Control:
	var keys = []
	for p in PAGES:
		var id = str(p[0])
		var b = Kit.choice(str(p[1]), RpgUi.page == id, go_page.bind(id), RpgUi.color("realm"), 13)
		b.set_meta("realm_tab", id)
		b.set_meta("anchor_id", "realm_tab:" + id)
		finger(b)
		if page_dot(id, rpg, can_learn):
			var dot = ColorRect.new()
			dot.color = Pal.ACCENT2
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.anchor_left = 1.0
			dot.anchor_right = 1.0
			dot.offset_left = -11.0
			dot.offset_right = -5.0
			dot.offset_top = 4.0
			dot.offset_bottom = 10.0
			dot.set_meta("realm_tab_dot", id)
			b.add_child(dot)
		keys.append(b)
	var track = Kit.choice_track(keys)
	track.set_meta("section", "realm_tabs")
	return track
