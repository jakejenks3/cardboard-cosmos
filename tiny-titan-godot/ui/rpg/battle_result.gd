class_name BattleResult
extends Control
## The end of a battle (RPG_PLAN.md 10.2): BattleView shows it inside its own
## overlay once the battle is over.
##
##   var r = BattleResult.new()
##   parent.add_child(r)                       # it fills its parent
##   r.setup(RpgBattle.summary(B), info)
##   r.chosen.connect(func(what): ...)         # "next" | "again" | "back"
##
## info = {"win": bool, "title": the stage, "stars": [bool x3] or null, "objectives": [3 strings] or null,
##         "rewards": {"xp", "ore", "items": [{id, n}], "runes": [rune rows or words], "relic": id or "",
##                     "scroll": move id or "", "first": bool} or null,
##         "level_before": {"lvl", "into", "need"}, "level_after": the same,
##         "learned": ["Dust Bunny is weak to Legs", ...], "next": bool}
## Every part may be left out: what is not given is not shown.
##
## A win: the stars pop in one by one beside their objectives, the XP bar fills
## (XpBarAnim), "LEVEL UP" when the level rose, the loot, what was learned. A
## loss: a kind line and what was learned. A tap anywhere shows the end state
## at once (skip()). The keys sit in three fixed places at the bottom ("Next
## stage" is there only when there is one; its place stays empty otherwise) and
## work from the first moment. Metas: bv_result ("win" | "loss") on the root,
## br_key on the keys, br_star (its place) / br_on on the stars, br_xp,
## br_level_up, br_loot, br_loot_row, br_learned, br_kind.
## Every pause is a Tween bound to this node and every step checks `_gen`, as
## in ResultsOverlay.

signal chosen(what: String)

const KIND_LINE = "Nothing is lost. Train, tune the build, try again."
const KEY_H = 46

var summary: Dictionary = {}
var info: Dictionary = {}
var win: bool = false
## True once nothing is left to play (or after skip()).
var done: bool = false

var _gen: int = 0
var _picked: bool = false
var _stars: Array = []
var _earned: Array = []
var _xp: XpBarAnim = null
var _level_up: Control = null
var _rose: bool = false
var _late: Array = []


func setup(summary_in: Dictionary, info_in: Dictionary) -> void:
	summary = summary_in
	info = info_in
	win = bool(info.get("win", summary.get("win", false)))
	_build()
	_run()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("bv_result", "win" if win else "loss")
	var base = ColorRect.new()
	base.color = Pal.BG
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col = Kit.vbox(10)
	add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_right = -12
	col.offset_top = 14
	col.offset_bottom = -10

	var head_color = Pal.ACCENT if win else Pal.MUTED
	var head = PixelFont.rect("VICTORY" if win else "KNOCKED DOWN", 4 if win else 3, head_color)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(head)
	var title = Kit.clip(str(info.get("title", "")), 15, Pal.MUTED, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(scroll)
	var body = Kit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(body)

	if not win:
		var kind = Kit.row(Callable(), Pal.SECOND, Pal.SECOND, 10, 4)
		var line = Kit.para(KIND_LINE, 15, null, true)
		line.set_meta("br_kind", true)
		kind.add(line)
		body.add_child(kind)
	if win and info.get("stars") is Array:
		body.add_child(_stars_block(info.stars, info.get("objectives") if info.get("objectives") is Array else []))
	body.add_child(_facts())
	if win and info.get("level_before") is Dictionary and info.get("level_after") is Dictionary:
		_xp = XpBarAnim.new()
		_xp.setup(_level_info(info.level_before), _level_info(info.level_after), RpgUi.color("realm"), "Fighter", "realm" if Icons.has_icon("realm") else "star")
		_xp.set_meta("br_xp", true)
		body.add_child(_xp)
		_rose = int(info.level_after.get("lvl", 1)) > int(info.level_before.get("lvl", 1))
		if _rose:
			# Its place is there from the start, so nothing under it moves when it lights up.
			var lv = PixelFont.rect("LEVEL UP", 3, Pal.ACCENT)
			lv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			lv.modulate.a = 0.0
			lv.set_meta("br_level_up", false)
			_level_up = lv
			body.add_child(lv)
	if win and info.get("rewards") is Dictionary:
		var loot = _loot(info.rewards)
		_late.append(loot)
		body.add_child(loot)
	var learned = info.get("learned") if info.get("learned") is Array else []
	if not learned.is_empty():
		var lb = _learned(learned)
		_late.append(lb)
		body.add_child(lb)

	col.add_child(_keys())


func _level_info(l: Dictionary) -> Dictionary:
	var need = maxi(1, int(l.get("need", 1)))
	return {"level": int(l.get("lvl", 1)), "progress": clampf(float(l.get("into", 0)) / float(need), 0.0, 1.0), "toNext": need}


func _stars_block(stars: Array, objectives: Array) -> Control:
	var sec = Kit.section("br_stars", "Stars", "star_on" if Icons.has_icon("star_on") else "star", Pal.ACCENT)
	for i in range(3):
		var on = i < stars.size() and bool(stars[i])
		_earned.append(on)
		var row = Kit.hbox(10)
		var star = Icons.rect("star_off" if Icons.has_icon("star_off") else "star", 32)
		star.set_meta("br_star", i)
		star.set_meta("br_on", false)
		_stars.append(star)
		row.add_child(star)
		var words = str(objectives[i]) if i < objectives.size() else ""
		var l = Kit.para(words, 14, null if on else Pal.MUTED, on)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		sec.add(row)
	return sec


## How the fight went, as three small tiles.
func _facts() -> Control:
	var row = Kit.hbox(8)
	for f in [["Turns", int(summary.get("turns", 0)), Pal.SECOND], ["Dealt", int(summary.get("dealt", 0)), Pal.ACCENT2], ["Taken", int(summary.get("taken", 0)), Pal.DANGER]]:
		var t = Kit.row(Callable(), f[2], f[2], 8, 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add(Kit.label(Xp.fmt_int(int(f[1])), 17, null, true))
		t.add(Kit.clip(str(f[0]), 11, Pal.MUTED, true))
		row.add_child(t)
	row.set_meta("br_facts", true)
	return row


func _loot(rw: Dictionary) -> Control:
	var sec = Kit.section("br_loot", "Loot", "chest_gold" if Icons.has_icon("chest_gold") else "star", RpgUi.color("realm"),
		Kit.tag("FIRST CLEAR", Pal.ACCENT) if bool(rw.get("first", false)) else null)
	sec.set_meta("br_loot", true)
	var flow = Kit.flow(6)
	var xp = int(round(float(rw.get("xp", 0))))
	if xp > 0:
		flow.add_child(Kit.pill("star", "+%s XP" % Xp.fmt_int(xp), Pal.ACCENT))
	var ore = int(round(float(rw.get("ore", 0))))
	if ore > 0:
		flow.add_child(RpgUi.ore_pill(ore))
	if flow.get_child_count() > 0:
		sec.add(flow)
	var items = rw.get("items") if rw.get("items") is Array else []
	for it in items:
		if not (it is Dictionary):
			continue
		var row_it = RpgItems.by_id(str(it.get("id", "")))
		var item_name = str(row_it.name) if row_it != null else str(it.get("id", "")).capitalize()
		var icon_name = str(row_it.icon) if row_it != null else "belt"
		sec.add(_loot_row(icon_name, "%s x%d" % [item_name, maxi(1, int(it.get("n", 1)))], RpgItems.words(row_it) if row_it != null else ""))
	var runes = rw.get("runes") if rw.get("runes") is Array else []
	for r in runes:
		var words = str(r)
		if r is Dictionary:
			words = RpgGear.rune_words(r) if r.has("k") else str(r.get("name", r.get("id", "")))
		sec.add(_loot_row("rune", "Rune", words))
	var relic = RpgRelics.by_id(str(rw.get("relic", ""))) if str(rw.get("relic", "")) != "" else null
	if relic != null:
		sec.add(_loot_row(str(relic.get("icon", "relic")), str(relic.get("name", "")), str(relic.get("text", ""))))
	var scroll = RpgMoves.by_id(str(rw.get("scroll", ""))) if str(rw.get("scroll", "")) != "" else null
	if scroll != null:
		sec.add(_loot_row("scroll", "Scroll: %s" % str(scroll.get("name", "")), "A new move to learn"))
	return sec


func _loot_row(icon_name: String, title: String, words: String) -> Control:
	var row = Kit.hbox(8)
	row.add_child(Icons.rect(icon_name if Icons.has_icon(icon_name) else "star", 32))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(Kit.clip(title, 14, null, true))
	if words != "":
		v.add_child(Kit.clip(words, 12, Pal.MUTED))
	row.add_child(v)
	row.set_meta("br_loot_row", title)
	return row


func _learned(lines: Array) -> Control:
	var sec = Kit.section("br_learned", "Learned", "fx_insight" if Icons.has_icon("fx_insight") else "star", Pal.READ)
	sec.set_meta("br_learned", lines.size())
	for i in range(mini(4, lines.size())):
		sec.add(Kit.para(str(lines[i]), 13))
	if lines.size() > 4:
		sec.add(Kit.muted("+%d more" % (lines.size() - 4), 12))
	return sec


## Three places of one width: Back, Again, Next stage. Without a next stage the
## third stays empty and Again is the main key.
func _keys() -> Control:
	var row = Kit.hbox(8)
	var has_next = win and bool(info.get("next", false))
	row.add_child(_key("back", "Back", "ghost"))
	row.add_child(_key("again", "Again", "secondary" if has_next else "primary"))
	if has_next:
		row.add_child(_key("next", "Next stage", "primary"))
	else:
		var empty = Control.new()
		empty.custom_minimum_size = Vector2(0, KEY_H)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(empty)
	return row


func _key(what: String, word: String, variant: String) -> Button:
	var b = Kit.button(word, variant, _choose.bind(what), "md")
	b.custom_minimum_size = Vector2(0, KEY_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.set_meta("br_key", what)
	b.set_meta("anchor_id", "br_key:" + what)
	return b


func _choose(what: String) -> void:
	if _picked:
		return
	_picked = true
	_gen += 1
	chosen.emit(what)


# ---------------------------------------------------------------------------
# Timeline
# ---------------------------------------------------------------------------

func _wait(secs: float) -> void:
	var tw = create_tween()
	tw.tween_interval(secs)
	await tw.finished


func _alive(gen: int) -> bool:
	return is_instance_valid(self) and is_inside_tree() and gen == _gen


func _run() -> void:
	_gen += 1
	var gen = _gen
	if not is_inside_tree():
		_finish()
		return
	for c in _late:
		c.modulate.a = 0.0
	await _wait(0.25)
	if not _alive(gen):
		return
	for i in range(_stars.size()):
		if not _earned[i]:
			continue
		_light(i, true)
		await _wait(0.34)
		if not _alive(gen):
			return
	if _xp != null:
		if _rose:
			_xp.level_up.connect(_on_level_up, CONNECT_ONE_SHOT)
		var secs = _xp.play()
		await _wait(secs)
		if not _alive(gen):
			return
	for c in _late:
		Kit.fade_in(c, 0.2)
		await _wait(0.18)
		if not _alive(gen):
			return
	done = true


func _light(i: int, lively: bool) -> void:
	var star = _stars[i]
	if bool(star.get_meta("br_on", false)):
		return
	star.texture = Icons.tex("star_on" if Icons.has_icon("star_on") else "star", null, 2)
	star.set_meta("br_on", true)
	if lively:
		Kit.pop(star, 1.5, 0.3)
		Kit.burst(star, Pal.ACCENT, 12)
		Sfx.claim()


func _on_level_up(_level) -> void:
	if _level_up != null:
		_level_up.modulate.a = 1.0
		_level_up.set_meta("br_level_up", true)
		Kit.pop(_level_up, 1.3, 0.3)


## Everything as it ends, at once.
func skip() -> void:
	if done:
		return
	_gen += 1
	_finish()


func _finish() -> void:
	for i in range(_stars.size()):
		if _earned[i]:
			_light(i, false)
	if _xp != null:
		_xp.finish_now()
	if _level_up != null:
		_level_up.modulate.a = 1.0
		_level_up.set_meta("br_level_up", true)
	for c in _late:
		c.modulate.a = 1.0
	done = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		skip()
