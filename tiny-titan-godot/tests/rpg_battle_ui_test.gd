extends SceneTree
## Test of the Realm's battle screen and result (RPG_PLAN.md 10.2): BattleView,
## BattleWidgets, BattleResult and the look helpers of RpgUi, built for real,
## headless, in a 440-wide column, and played by pressing the keys a player has.
##   - one foe (with the first fight's hints), a pack of three, two waves, a boss, a loss;
##   - after EVERY action: the HP / energy / gauge shown are B's, every foe's plate is its unit, no key has
##     moved, nothing is wider than the column or leaves the view, no two keys overlap;
##   - target picking, a dim key does nothing and says why, the item sheet, the companion, the ultimate,
##     flee, the speed key, a unit's sheet;
##   - the result for a win and a loss, each key's signal, the same places with and without "Next stage";
##   - a battle resumed from a stored B shows the same state and goes on as the same battle;
##   - one fight played at its own pace (awaits), so the playback is proven to end;
##   - all of it again with Kit.fingers (keys at least 40 high), and the whole view inside 440 x 720.
## The screens name autoloads (Sfx through Kit), which are only there a frame after the start, so
## they are loaded by path once App is up and never named here. Made-up data.
##   godot --headless --path . --script res://tests/rpg_battle_ui_test.gd
## TINY_TITAN_DATA must point at a throwaway folder: the test replaces the save.
## Prints RPG BATTLE UI: n/m passed and exits with 1 when anything fails.

const W = 440.0

var passed = 0
var total = 0
var kit = null
var view_script = null
var result_script = null
var ui_script = null
var app = null
var host: Control = null
var stored = 0
var got = []


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## Every node under `n` (itself too) that is not on its way out.
func _all(n: Node, out: Array = []) -> Array:
	if n.is_queued_for_deletion():
		return out
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _with(n: Node, key: String, value = null) -> Array:
	return _all(n).filter(func(c): return c.has_meta(key) and (value == null or str(c.get_meta(key)) == str(value)))


func _one(n: Node, key: String, value = null):
	var l = _with(n, key, value)
	return l[0] if not l.is_empty() else null


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _same(a, b) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


func _round_trip(B: Dictionary) -> Dictionary:
	return TTUtil.normalize_json(JSON.parse_string(JSON.stringify(B)))


# --- made-up fights ----------------------------------------------------------------------------

## The road's own hero of tier `t`, with an ultimate and a belt; `five` gives it a fifth move.
func _hero(t: float = 1.0, five: bool = false) -> Dictionary:
	var h = RpgHero.reference_hero(t, "balanced")
	h["ult"] = "titan_press"
	h["belt"] = [{"id": "protein_shake", "n": 2, "used": 0}, {"id": "energy_gel", "n": 1, "used": 0}]
	if five:
		for m in RpgMoves.all():
			if not bool(m.ult) and not h.moves.has(str(m.id)) and str(m.kind) == "attack" and int(m.cost) <= 2:
				h.moves.append(str(m.id))
				break
	return h


func _wave(ids: Array, n: float = 1.0) -> Array:
	var out = []
	for id in ids:
		out.append({"foe": str(id), "n": n})
	return out


func _setup(hero: Dictionary, waves: Array, pet: bool = false, fight_seed: int = 7) -> Dictionary:
	return {"hero": hero, "pet": {"pet": "slime", "rarity": "common", "name": "Slime"} if pet else null, "waves": waves, "seed": fight_seed, "day": "2026-01-05"}


func _open(setup: Dictionary, opts: Dictionary = {}):
	var o = opts.duplicate()
	if not o.has("hero"):
		o["hero"] = {"state": app.state, "profile": {"name": "Tester", "skin": 2, "hairStyle": 1, "hairColor": 1, "createdAt": 0}, "loadout": app.loadout()}
	var v = view_script.open(setup, o)
	await _frames(2)
	return v


func _shut(v) -> void:
	if v != null and is_instance_valid(v):
		v.close()
	# Sheets and what rose from the fight go with it.
	for c in host.get_children():
		if c != v:
			c.queue_free()
	await _frames(2)


# --- what a player sees ---------------------------------------------------------------------------

## The keys of the view by their anchor id: where they are.
func _key_rects(v) -> Dictionary:
	var out = {}
	for c in _all(v):
		if c is Button and (c.has_meta("bv_move") or c.has_meta("bv_key")):
			out[str(c.get_meta("anchor_id", ""))] = Rect2(c.global_position, c.size)
	return out


## What is wrong with what the view shows of B ([] = nothing).
func _shown_wrong(v) -> Array:
	var bad = []
	var B = v.B
	var h = B.hero
	var hp = _one(v, "bv_hp_hero")
	if hp == null or int(hp.get_meta("bv_hp_hero")) != int(h.hp) or hp.text != "%d / %d" % [int(h.hp), int(h.hp_max)]:
		bad.append("hero hp %s, B %d" % [str(hp.text) if hp != null else "-", int(h.hp)])
	var en = _one(v, "bv_energy")
	if en == null or int(en.get_meta("bv_energy")) != int(h.en) or int(en.n) != int(h.en) or int(en.of) != int(h.en_max):
		bad.append("energy %s, B %d" % [str(en.get_meta("bv_energy")) if en != null else "-", int(h.en)])
	var ga = _one(v, "bv_gauge")
	if ga == null or int(ga.get_meta("bv_gauge")) != int(floor(float(h.gauge) + 0.0001)):
		bad.append("gauge %s, B %s" % [str(ga.get_meta("bv_gauge")) if ga != null else "-", str(h.gauge)])
	elif absf(float(ga.value) - clampf(float(h.gauge) / 100.0, 0.0, 1.0)) > 0.001:
		bad.append("gauge bar %s" % str(ga.value))
	for f in B.foes:
		if not bool(f.alive):
			continue
		var plate = _one(v, "bv_plate", str(f.id))
		if plate == null or int(plate.get_meta("bv_hp")) != int(f.hp) or int(plate.get_meta("bv_guard")) != int(f.guard):
			bad.append("%s plate hp %s guard %s, B %d %d" % [str(f.id), str(plate.get_meta("bv_hp")) if plate != null else "-", str(plate.get_meta("bv_guard")) if plate != null else "-", int(f.hp), int(f.guard)])
			continue
		var kn = RpgBattle.known(B, str(f.id))
		var want = []
		for sc in kn.weak:
			want.append(str(sc))
		for i in range(maxi(0, f.weak.size() - kn.weak.size())):
			want.append("?")
		for sc in kn.resist:
			want.append("-" + str(sc))
		if plate.weak_shown() != ",".join(want):
			bad.append("%s weak shown %s, known %s" % [str(f.id), plate.weak_shown(), ",".join(want)])
		var ids = []
		if bool(f.broken):
			ids.append("broken")
		for st in f.statuses:
			ids.append(str(st.id))
		if plate.statuses_shown() != ",".join(ids):
			bad.append("%s statuses shown %s, has %s" % [str(f.id), plate.statuses_shown(), ",".join(ids)])
		if _one(v, "bv_foe", str(f.id)) == null:
			bad.append("%s has no tap area" % str(f.id))
	if not RpgBattle.over(B):
		if not RpgBattle.options(B).targets.has(v.target):
			bad.append("target %s is not a living foe" % v.target)
		var tl = _one(v, "bv_timeline")
		if tl == null or str(tl.get_meta("bv_timeline")) != ",".join(RpgBattle.timeline(B, 7)):
			bad.append("timeline %s" % (str(tl.get_meta("bv_timeline")) if tl != null else "-"))
		var o = RpgBattle.options(B)
		for m in o.moves:
			var key = _one(v, "bv_move", str(m.id))
			if key == null or bool(key.get_meta("bv_ok")) != bool(m.ok):
				bad.append("move key %s shows ok=%s, is %s" % [str(m.id), str(key.get_meta("bv_ok")) if key != null else "-", str(m.ok)])
		if bool(_one(v, "bv_key", "ult").get_meta("bv_ok")) != bool(o.ult.ok) or bool(_one(v, "bv_key", "pet").get_meta("bv_ok")) != bool(o.pet.ok):
			bad.append("the ultimate's or the companion's key is lit wrongly")
	if v.busy():
		bad.append("still busy")
	return bad


## What is wrong with the layout ([] = nothing): the column's width, the view's own height, the arena.
func _layout_wrong(v) -> Array:
	var bad = []
	var box = Rect2(host.global_position, host.size)
	if absf(v.size.x - host.size.x) > 0.5 or absf(v.size.y - host.size.y) > 0.5:
		bad.append("the view is %s in %s" % [str(v.size), str(host.size)])
	var arena = v._arena
	var arena_box = arena.get_global_rect()
	for c in _all(v):
		if not (c is Control) or not c.is_visible_in_tree() or c == v:
			continue
		var r = Rect2(c.global_position, c.size)
		if arena.is_ancestor_of(c):
			# The arena cuts off what leaves it (the hero's canvas does); its plates and tap areas must be inside.
			if (c.has_meta("bv_plate") or c.has_meta("bv_foe")) and not arena_box.grow(0.5).encloses(r):
				bad.append("%s leaves the arena: %s" % [str(c.get_meta("anchor_id", "")), str(r)])
			continue
		if r.position.x < box.position.x - 0.5 or r.end.x > box.end.x + 0.5:
			bad.append("%s is wider than the column: %s" % [c.get_class(), str(r)])
		if r.position.y < box.position.y - 0.5 or r.end.y > box.end.y + 0.5:
			bad.append("%s leaves the view: %s" % [c.get_class(), str(r)])
	if arena_box.end.x > box.end.x + 0.5 or arena_box.size.y < 239.5:
		bad.append("arena %s" % str(arena_box))
	# No two keys share a pixel; the line ends above the moves.
	var keys = []
	for c in _all(v):
		if c is Button and c.has_meta("anchor_id") and c.is_visible_in_tree():
			keys.append(c)
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			var a = Rect2(keys[i].global_position, keys[i].size).grow(-0.5)
			var b = Rect2(keys[j].global_position, keys[j].size).grow(-0.5)
			if a.intersects(b):
				bad.append("%s overlaps %s" % [str(keys[i].get_meta("anchor_id")), str(keys[j].get_meta("anchor_id"))])
	# What is on a key or a plate fits it: nothing is cut off, nothing hangs out.
	for c in _all(v):
		if not (c is Button) or not c.has_meta("anchor_id") or not c.is_visible_in_tree():
			continue
		var own = Rect2(c.global_position, c.size).grow(0.5)
		for ch in c.get_children():
			if not (ch is Control) or not ch.is_visible_in_tree():
				continue
			if ch is Container and (ch.get_combined_minimum_size().x > ch.size.x + 0.5 or ch.get_combined_minimum_size().y > ch.size.y + 0.5):
				bad.append("%s: its content needs %s of %s" % [str(c.get_meta("anchor_id")), str(ch.get_combined_minimum_size()), str(ch.size)])
			if c.has_meta("bv_plate") and not own.encloses(Rect2(ch.global_position, ch.size)):
				bad.append("%s: %s hangs out of the plate: %s in %s (scale %s, child scale %s)" % [str(c.get_meta("anchor_id")), ch.get_class(), str(Rect2(ch.position, ch.size)), str(c.size), str(c.scale), str(ch.scale)])
	for slot in [[v._top, v._top_h], [v._timeline, v._tl_h], [v._hero_plate, v._plate_h], [v._line_box, v._line_h], [v._acts, v._act_h]]:
		if absf(slot[0].size.y - float(slot[1])) > 0.5 or slot[0].size.x > host.size.x - 15.5:
			bad.append("a slot is %s, meant %s high" % [str(slot[0].size), str(slot[1])])
	var line = _one(v, "bv_line")
	if line == null or line.get_parent().get_global_rect().end.y > v._moves.global_position.y + 0.5:
		bad.append("the line runs into the moves")
	elif v._moves.global_position.y - line.get_parent().get_global_rect().end.y > 24.5:
		bad.append("a hole of %d px between the line and the keys" % int(v._moves.global_position.y - line.get_parent().get_global_rect().end.y))
	if absf(v._moves.size.y - v._moves_height(v._move_h)) > 0.5 or v._move_h > 72.5 or v._act_h > 56.5 or v._move_h < v._move_h0 - 0.5 or v._act_h < v._act_h0 - 0.5:
		bad.append("key heights %s %s" % [str(v._move_h), str(v._act_h)])
	# The hero and the companion stand on the foes' ground line; his numbers rise from over his head.
	var ground_y = arena_box.position.y + arena.ground()
	if v._hero_view != null:
		var low_y = v._hero_view.global_position.y + float(v._hero_low + 1) * 2.0
		if absf(low_y - (ground_y + 2.0)) > 0.5:
			bad.append("the hero's lowest row ends at %s, the ground line is %s" % [str(low_y), str(ground_y)])
		var head_y = v._hero_view.global_position.y + float(v._hero_top) * 2.0
		if v._anchor("hero") != v._hero_mark or v._hero_mark.get_global_rect().end.y > head_y + 0.5:
			bad.append("the hero's numbers do not start over his head")
	for id in v._foes:
		var fv = v._foes[id].view
		# (where it stands, not where a lunge or a pop has it for a moment)
		if absf(arena_box.position.y + v._foes[id].home.y + fv.feet_y() - ground_y) > 0.5:
			bad.append("%s is not on the ground line (home %s, size %s, feet %s, ground %s, arena %s)" % [str(id), str(v._foes[id].home), str(fv.size), str(fv.feet_y()), str(arena.ground()), str(arena.size)])
	if v._hero_plate.get_global_rect().position.y < v._timeline.get_global_rect().end.y - 0.5 or v._timeline.global_position.y < arena_box.end.y - 0.5:
		bad.append("the slots under the arena overlap")
	# The line that says what happened can be READ: its label has the height of its words (it once asked for
	# one pixel in the two-line box and showed nothing on any tall screen).
	if v._line.size.y < 12.0 or v._line.get_visible_line_count() < (1 if v._line.text != "" else 0):
		bad.append("the line's label is %s high and shows %d lines of \"%s\"" % [str(v._line.size.y), v._line.get_visible_line_count(), v._line.text])
	return bad


func _moved(v, base: Dictionary) -> Array:
	var bad = []
	var now = _key_rects(v)
	for id in base:
		if not now.has(id) or not now[id].is_equal_approx(base[id]):
			bad.append("%s moved: %s -> %s" % [str(id), str(base[id]), str(now.get(id, "gone"))])
	return bad


func _press(node) -> void:
	if node != null:
		node.pressed.emit()


func _aim(v, target: String) -> bool:
	if target == "" or target == v.target:
		return true
	_press(_one(v, "bv_foe", target))
	return v.target == target


## Do what a player would to take `a`: pick the target, press the key (through the belt's sheet for an item).
func _press_action(v, a: Dictionary) -> bool:
	match str(a.get("t", "")):
		"move":
			if not _aim(v, str(a.get("target", ""))):
				return false
			_press(_one(v, "bv_move", str(a.id)))
		"strike", "ult", "pet":
			if not _aim(v, str(a.get("target", ""))):
				return false
			_press(_one(v, "bv_key", str(a.t)))
		"guard":
			_press(_one(v, "bv_key", "guard"))
		"item":
			_press(_one(v, "bv_key", "item"))
			var use = _one(host, "bv_item", str(a.id))
			if use == null:
				return false
			_press(use)
		_:
			return false
	return true


## Play the battle on `v` to its end by pressing keys, skipping every playback. Returns what went wrong, by kind.
func _fight(v, policy: String = "heuristic", limit: int = 400) -> Dictionary:
	var out = {"shown": [], "moved": [], "layout": [], "input": [], "actions": 0, "kinds": {}, "aimed": 0}
	v.skip()
	var base = _key_rects(v)
	out.shown.append_array(_shown_wrong(v))
	out.layout.append_array(_layout_wrong(v))
	while v.result() == null and out.actions < limit:
		var a = RpgAi.hero_action(v.B, policy)
		var before = JSON.stringify(v.B)
		if str(a.get("target", "")) != "" and str(a.get("target", "")) != v.target:
			out.aimed += 1
		if not _press_action(v, a):
			out.input.append("could not press %s" % str(a))
			break
		if JSON.stringify(v.B) == before:
			out.input.append("%s changed nothing: %s" % [str(a), v.line_text()])
			break
		v.skip()
		out.actions += 1
		out.kinds[str(a.t)] = int(out.kinds.get(str(a.t), 0)) + 1
		if v.result() == null:
			out.shown.append_array(_shown_wrong(v))
			out.moved.append_array(_moved(v, base))
			if out.actions % 3 == 0:
				out.layout.append_array(_layout_wrong(v))
		if out.actions % 4 == 0:
			await process_frame
	await _frames(2)
	return out


func _report(name: String, v, f: Dictionary, want_win) -> void:
	ok(f.input.is_empty() and v.result() != null and RpgBattle.over(v.B), "%s: played to its end with the real keys" % name, [f.actions, f.kinds, f.input])
	ok(f.shown.is_empty(), "%s: after every action the HP, energy, gauge, plates, targets and keys shown are B's" % name, f.shown.slice(0, 4))
	ok(f.moved.is_empty(), "%s: no key moves between turns" % name, f.moved.slice(0, 4))
	ok(f.layout.is_empty(), "%s: nothing wider than the column, nothing overlaps, plates inside the arena" % name, f.layout.slice(0, 4))
	if want_win != null:
		ok(RpgBattle.won(v.B) == bool(want_win) and v.result() != null and str(v.result().get_meta("bv_result", "")) == ("win" if want_win else "loss"), "%s: the result says %s" % [name, "a win" if want_win else "a loss"], RpgBattle.summary(v.B))


## Press a key of the result; the view must say so and go.
func _leave(v, what: String, name: String) -> void:
	got = []
	v.finished.connect(func(B, s): got.append([v.choice, bool(s.win), RpgBattle.over(B)]))
	var key = _one(v.result(), "br_key", what)
	ok(key != null, "%s: the result has the %s key" % [name, what])
	_press(key)
	await _frames(3)
	ok(got.size() == 1 and str(got[0][0]) == what and bool(got[0][2]) and not is_instance_valid(v), "%s: %s is relayed through finished / choice, and the view frees itself" % [name, what], got)


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	app = root.get_node_or_null("App")
	if app == null or OS.get_environment("TINY_TITAN_DATA") == "":
		print("RPG BATTLE UI: needs the App autoload and TINY_TITAN_DATA")
		quit(1)
		return
	app.replace_all(app.empty_saved())
	kit = load("res://ui/kit.gd")
	view_script = load("res://ui/rpg/battle_view.gd")
	result_script = load("res://ui/rpg/battle_result.gd")
	ui_script = load("res://ui/rpg/rpg_ui.gd")
	var pal = load("res://ui/pal.gd")
	host = Control.new()
	host.size = Vector2(W, 900)
	root.add_child(host)
	kit.overlay_root = host
	kit.fingers = false

	# --- RpgUi's look ------------------------------------------------------------------------------
	ok(ui_script.color("push") == pal.PUSH and ui_script.color("pull") == pal.PULL and ui_script.color("legs") == pal.LEGS and ui_script.color("speed") == pal.RUN
		and ui_script.color("grip") == pal.CLIMB and ui_script.color("mind") == pal.READ and ui_script.color("flow") == pal.PT and ui_script.color("grit") == pal.GRIT
		and ui_script.color("realm") == pal.REALM and ui_script.color("plain") == pal.MUTED and ui_script.color("nobody") == pal.MUTED, "RpgUi.color: the plan's table")
	ok(ui_script.school_icon("legs") == "sch_legs" and ui_script.school_icon("plain") == "strike" and ui_script.rarity_color("epic") == pal.rarity("epic"), "school icons and rarity colours")
	var si = ui_script.status_icon({"id": "bleed", "turns": 2, "stacks": 3}, 16)
	var si2 = ui_script.status_icon("pumped", 32)
	ok(si.custom_minimum_size == Vector2(16, 16) and str(si.get_meta("rpg_status")) == "bleed" and si.get_child_count() == 2 and si2.custom_minimum_size == Vector2(32, 32), "a status icon at a whole-number size, its stacks written on it", si.custom_minimum_size)
	si.free()
	si2.free()
	ok(ui_script.status_words({"id": "exposed", "turns": 2, "stacks": 1}).begins_with("Exposed (2 turns): Takes 25% more"), "a status in words", ui_script.status_words({"id": "exposed", "turns": 2, "stacks": 1}))
	var card_box = VBoxContainer.new()
	card_box.size = Vector2(W - 16, 0)
	host.add_child(card_box)
	var shove = RpgMoves.by_id("shove")
	var card = ui_script.move_card(shove)
	card_box.add_child(card)
	card_box.add_child(ui_script.ore_pill(1240))
	card_box.add_child(ui_script.stat_chip("chest", 31.6))
	await _frames(2)
	var card_words = _all(card).filter(func(c): return c is Label).map(func(c): return c.text)
	ok(str(card.get_meta("rpg_move")) == "shove" and card_words.has("Shove") and card_words.has("Push") and card_words.any(func(t): return t.contains("15%")) and card.size.x <= W - 16 + 0.5,
		"a move card: name, school, what it does in words, no wider than its column", [card_words, card.size])
	var chip_words = _all(card_box).filter(func(c): return c is Label).map(func(c): return c.text)
	ok(chip_words.has("1,240") and chip_words.has("Chest 31"), "the ore pill and a stat chip", chip_words)
	card_box.queue_free()
	await _frames(1)

	# --- one foe, the first fight's hints, the caller's draft ---------------------------------------
	stored = 0
	var v = await _open(_setup(_hero(), [_wave(["dust_bunny"])]), {"title": "The Rustyard 1", "scene": "rustyard", "tutorial": true, "store": func(_B): stored += 1})
	ok(v.get_parent() == host and v.mouse_filter == Control.MOUSE_FILTER_STOP and v.size == Vector2(W, 900) and _all(v).filter(func(c): return c is ScrollContainer).is_empty(),
		"the battle is a full-column overlay on Kit.overlay_root that stops the mouse and scrolls nowhere", [v.size, v.mouse_filter])
	ok(v.busy(), "the opening is played back (input locked)")
	var b0 = JSON.stringify(v.B)
	_press(_one(v, "bv_move", "shove"))
	ok(not v.busy() and JSON.stringify(v.B) == b0, "a tap during a playback only skips it")
	var hint = _one(v, "bv_hint")
	ok(hint != null and hint.text.begins_with("Try each school") and _one(v, "bv_line") != null, "the tutorial's first hint, and the line", hint.text if hint != null else "-")
	ok(_with(v, "bv_move").size() == 4 and _with(v, "bv_key").size() == 9 and _with(v, "bv_foe").size() == 1 and _one(v, "bv_plate", "hero") != null and _one(v, "bv_plate", "f0") != null
		and str(_one(v, "bv_wave").get_meta("bv_wave")) == "1/1", "four move keys, five action keys, flee, auto, speed and music, a foe with a plate and a tap area", [_with(v, "bv_move").size(), _with(v, "bv_key").size()])
	var plate0 = _one(v, "bv_plate", "f0")
	ok(plate0.wide and plate0.weak_shown() == "?,?" and plate0.intent_shown().begins_with("attack:") and plate0.intent_shown().split(":")[1].is_valid_int(), "one foe: a wide plate, its weaknesses unknown, its intent with the damage", [plate0.weak_shown(), plate0.intent_shown()])
	var pv = RpgBattle.preview(v.B, {"t": "move", "id": "shove", "target": "f0"})
	var want_dmg = str(int(pv.lo)) if int(pv.lo) == int(pv.hi) else "%d-%d" % [int(pv.lo), int(pv.hi)]
	ok(str(_one(v, "bv_move", "deep_breath").get_meta("bv_tag")) == "HEAL", "a support move's key says what it does in one word (Deep Breath: HEAL)", _one(v, "bv_move", "deep_breath").get_meta("bv_tag"))
	ok(str(_one(v, "bv_move", "shove").get_meta("bv_dmg")) == want_dmg and str(_one(v, "bv_move", "deep_breath").get_meta("bv_dmg")) == "", "a move key shows the preview against the picked target (a support move shows none)", [_one(v, "bv_move", "shove").get_meta("bv_dmg"), want_dmg])
	# A weak hit: the weakness is learned, shown on the plate and on the keys of that school.
	_press(_one(v, "bv_move", "shove"))
	ok(v.busy() and v.line_text().begins_with("You use Shove on Dust Bunny"), "a move plays back; the line says what happens", v.line_text())
	v.skip()
	ok(v.line_text().begins_with("Shove: ") and v.line_text().contains(" damage"), "a skipped playback leaves the turn in one line", v.line_text())
	ok(stored == 1 and _one(v, "bv_plate", "f0").weak_shown().begins_with("push") and (RpgBattle.over(v.B) or bool(_one(v, "bv_move", "shove").get_meta("bv_tag") in ["WEAK", "KO"])),
		"a weak hit is learned: on the plate, on the key (WEAK), and the caller was handed B", [stored, _one(v, "bv_plate", "f0").weak_shown(), _one(v, "bv_move", "shove").get_meta("bv_tag", "")])
	ok(not hint.text.begins_with("Try each school"), "the hint moves on with the fight", hint.text)
	var f1 = await _fight(v)
	_report("one foe", v, f1, true)
	ok(stored == f1.actions + 1, "the caller's store is called after every hero action", [stored, f1.actions])
	var r1 = v.result()
	ok(r1 != null and r1.get_parent() == v and _one(r1, "br_key", "next") == null and _one(r1, "br_key", "again") != null and _one(r1, "br_key", "back") != null and r1.info.learned.size() >= 1,
		"a plain result inside the same overlay: Again and Back, what was learned", r1.info if r1 != null else "-")
	var again_rect = Rect2(_one(r1, "br_key", "again").global_position, _one(r1, "br_key", "again").size)
	var back_rect = Rect2(_one(r1, "br_key", "back").global_position, _one(r1, "br_key", "back").size)
	await _leave(v, "again", "one foe")
	await _shut(null)

	# --- a pack of three ---------------------------------------------------------------------------
	v = await _open(_setup(_hero(), [_wave(["dust_bunny", "rust_rat", "squeaky_plate"])], true), {"title": "Pack", "scene": "rustyard", "next": true,
		"result": func(B, s): return {"win": bool(s.win), "title": "Pack", "stars": [true, false, true], "objectives": ["Win", "Take no hit over 30%", "Break a guard"],
			"rewards": {"xp": 120, "ore": 45, "items": [{"id": "protein_shake", "n": 2}], "runes": ["A rune of might"], "relic": "frayed_bookmark", "scroll": "stomp", "first": true},
			"level_before": {"lvl": 1, "into": 40, "need": 100}, "level_after": {"lvl": 2, "into": 60, "need": 130}, "learned": ["Dust Bunny is weak to Push"], "next": true}})
	v.skip()
	var plates = _with(v, "bv_plate").filter(func(p): return str(p.get_meta("bv_plate")) != "hero")
	ok(plates.size() == 3 and plates.all(func(p): return not p.wide) and _with(v, "bv_foe").size() == 3 and plates[0].global_position.x < plates[1].global_position.x and plates[1].global_position.x < plates[2].global_position.x
		and plates.all(func(p): return absf(p.global_position.y - plates[0].global_position.y) < 0.5), "three foes: three narrow plates in a row, each over its foe", plates.map(func(p): return [p.global_position, p.size]))
	ok(v.target == "f0" and plates[0]._picked and not plates[1]._picked, "the first foe is the target to begin with")
	_press(_one(v, "bv_foe", "f2"))
	ok(v.target == "f2" and plates[2]._picked and not plates[0]._picked and v._foes["f2"].view._marked and not v._foes["f0"].view._marked, "a tap on a foe picks it: its plate and its marker say so")
	var pv2 = RpgBattle.preview(v.B, {"t": "move", "id": "shove", "target": "f2"})
	ok(str(_one(v, "bv_move", "shove").get_meta("bv_dmg")).begins_with(str(int(pv2.lo))), "the keys' previews follow the picked target")
	_press(_one(v, "bv_key", "strike"))
	v.skip()
	ok(v.target == "f2" or not bool(RpgBattle.unit(v.B, "f2").alive), "the target is kept between turns", v.target)
	ok(int(RpgBattle.unit(v.B, "f2").hp) < int(RpgBattle.unit(v.B, "f2").hp_max), "Strike hit the picked foe")
	ok(_one(v, "bv_key", "pet").get_meta("bv_badge") != "" and str(_one(v, "bv_timeline").get_meta("bv_timeline")).contains("pet"), "a companion: its charge on its key, its turns in the timeline", _one(v, "bv_key", "pet").get_meta("bv_badge"))
	var f2 = await _fight(v)
	_report("three foes", v, f2, true)
	ok(f2.aimed >= 0 and f2.actions >= 3, "the pack took several turns", [f2.actions, f2.aimed])
	var r2 = v.result()
	ok(r2 != null and not r2.done and _with(r2, "br_star").size() == 3, "the caller's result: three star places, its timeline running")
	var t0 = Time.get_ticks_msec()
	while r2 != null and not r2.done and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	ok(r2.done and _with(r2, "br_star").map(func(s): return bool(s.get_meta("br_on"))) == [true, false, true] and bool(_one(r2, "br_level_up").get_meta("br_level_up")) and _one(r2, "br_xp") != null,
		"the result plays to its end by itself: the stars earned, the XP bar, LEVEL UP", [Time.get_ticks_msec() - t0, _with(r2, "br_star").map(func(s): return bool(s.get_meta("br_on")))])
	var rows2 = _with(r2, "br_loot_row").map(func(c): return str(c.get_meta("br_loot_row")))
	ok(rows2.size() == 4 and rows2[0] == "Protein Shake x2" and rows2.has("Frayed Bookmark") and rows2.has("Scroll: Stomp") and _one(r2, "br_learned") != null, "the loot as rows, what was learned", rows2)
	var order = [_one(r2, "section", "br_stars"), _one(r2, "br_facts"), _one(r2, "br_xp"), _one(r2, "br_level_up"), _one(r2, "br_loot"), _one(r2, "br_learned")]
	var in_order = not order.has(null)
	for i in range(order.size() - 1):
		in_order = in_order and order[i].global_position.y < order[i + 1].global_position.y
	ok(in_order, "the result from the top: stars, the three tiles, the level bar, LEVEL UP, the loot, and Learned last", order.map(func(c): return c.global_position.y if c != null else -1.0))
	var nx = _one(r2, "br_key", "next")
	ok(nx != null and Rect2(_one(r2, "br_key", "again").global_position, _one(r2, "br_key", "again").size).is_equal_approx(again_rect) and Rect2(_one(r2, "br_key", "back").global_position, _one(r2, "br_key", "back").size).is_equal_approx(back_rect)
		and nx.global_position.x > again_rect.end.x and nx.get_global_rect().end.x <= W + 0.5, "Next stage in the third place; Again and Back where they are without it", [again_rect, back_rect])
	var wide2 = _all(r2).filter(func(c): return c is Control and c.is_visible_in_tree() and (c.global_position.x < -0.5 or c.global_position.x + c.size.x > W + 0.5))
	ok(wide2.is_empty(), "the result is no wider than the column", wide2.map(func(c): return "%s %s %d..%d" % [c.get_class(), str(c.get_script().resource_path.get_file()) if c.get_script() != null else "", int(c.global_position.x), int(c.global_position.x + c.size.x)]))
	await _leave(v, "next", "three foes")
	await _shut(null)

	# --- two waves ---------------------------------------------------------------------------------
	v = await _open(_setup(_hero(), [_wave(["dust_bunny"]), _wave(["rust_rat", "moldy_towel"])]), {"title": "Two waves", "scene": "greenmile", "instant": true})
	ok(not v.busy() and v.instant, "with no waits (opts.instant) a playback is over at once")
	ok(str(_one(v, "bv_wave").get_meta("bv_wave")) == "1/2" and _with(v, "bv_foe").size() == 1, "wave 1 of 2")
	var saw_two = false
	var hp_w1 = 0
	var f3 = {"shown": [], "moved": [], "layout": [], "input": [], "actions": 0, "kinds": {}, "aimed": 0}
	var base3 = _key_rects(v)
	while v.result() == null and f3.actions < 300:
		var a3 = RpgAi.hero_action(v.B, "heuristic")
		if not _press_action(v, a3):
			f3.input.append("could not press %s" % str(a3))
			break
		v.skip()
		f3.actions += 1
		if v.result() == null:
			f3.shown.append_array(_shown_wrong(v))
			f3.moved.append_array(_moved(v, base3))
			f3.layout.append_array(_layout_wrong(v))
			if not saw_two and int(v.B.wave) == 1:
				saw_two = true
				hp_w1 = int(v.B.hero.hp)
				ok(str(_one(v, "bv_wave").get_meta("bv_wave")) == "2/2" and _with(v, "bv_foe").size() == 2 and _with(v, "bv_plate").size() == 3 and _one(v, "bv_plate", "f0") == null
					and RpgBattle.options(v.B).targets.has(v.target), "wave 2: the first wave's foe is gone, two new foes with plates, a living target", [_with(v, "bv_foe").size(), v.target])
	await _frames(2)
	_report("two waves", v, f3, true)
	ok(saw_two and hp_w1 > 0, "the second wave was seen")
	await _leave(v, "back", "two waves")
	await _shut(null)

	# --- a boss ------------------------------------------------------------------------------------
	var tier = RpgDefs.tier_of_n(10.0)
	v = await _open(_setup(_hero(tier), [_wave(["old_iron_jaw"], 10.0)], true, 21), {"title": "Old Iron-Jaw", "scene": "rustyard", "instant": true})
	var boss_plate = _one(v, "bv_plate", "f0")
	ok(boss_plate != null and boss_plate.wide and _with(v, "bv_foe").size() == 2 and v._foes["f0"].view.art_scale() == 3 and v._arena.get_global_rect().grow(0.5).encloses(Rect2(v._foes["f0"].view.global_position, v._foes["f0"].view.size))
		and boss_plate.get_global_rect().end.y <= v._foes["f0"].view.global_position.y + 0.5, "a boss and its add: two wide plates, inside the arena, each plate over its foe", [boss_plate.get_global_rect(), v._foes["f0"].view.global_position, v._foes["f0"].view.size])
	var f4 = await _fight(v)
	_report("a boss", v, f4, null)
	print("  (the boss fight: %d actions, %s, %s)" % [f4.actions, "won" if RpgBattle.won(v.B) else "lost", str(f4.kinds)])
	await _shut(v)

	# --- a loss -------------------------------------------------------------------------------------
	v = await _open(_setup(_hero(), [_wave(["old_iron_jaw"], 45.0)], false, 3), {"title": "Too soon", "scene": "rustyard", "next": true})
	var f5 = await _fight(v, "loop:guard")
	if not RpgBattle.over(v.B):
		f5 = await _fight(v)
	_report("a loss", v, f5, false)
	var r5 = v.result()
	r5.skip()
	var kind = _one(r5, "br_kind")
	ok(kind != null and kind.text == "Nothing is lost. Train, tune the build, try again." and _one(r5, "br_key", "next") == null and _one(r5, "br_key", "again") != null and _one(r5, "br_key", "back") != null and _with(r5, "br_star").is_empty(),
		"a loss: the kind line, Again and Back, no stars and no next stage")
	await _leave(v, "back", "a loss")
	await _shut(null)

	# --- a dim key, the companion, the ultimate, the belt, the sheets, speed, flee -------------------
	stored = 0
	var Bq = RpgBattle.start(_setup(_hero(), [_wave(["squeaky_plate", "dust_bunny"])], true))
	Bq.hero["en"] = 0
	v = await _open({}, {"resume": _round_trip(Bq), "store": func(_B): stored += 1})
	ok(not v.busy() and v.line_text() == "Your move.", "a resumed battle waits for the player at once", v.line_text())
	var shove_key = _one(v, "bv_move", "shove")
	var bq = JSON.stringify(v.B)
	ok(not bool(shove_key.get_meta("bv_ok")) and not shove_key.disabled, "without energy a move's key is dim (and still hears the tap)")
	_press(shove_key)
	ok(JSON.stringify(v.B) == bq and not v.busy() and v.line_text().begins_with("Not enough energy") and stored == 0, "a dim key does nothing and says why", v.line_text())
	_press(_one(v, "bv_key", "ult"))
	ok(JSON.stringify(v.B) == bq and v.line_text().contains("gauge"), "the ultimate before the gauge is full: nothing, and why", v.line_text())
	_press(_one(v, "bv_key", "pet"))
	ok(JSON.stringify(v.B) == bq and v.line_text().contains("more turn"), "the companion before it is charged: nothing, and why", v.line_text())
	var keys_q = _key_rects(v)
	_press(_one(v, "bv_key", "speed"))
	ok(v.speed == 2 and _one(v, "bv_key", "speed").text == "x2" and _moved(v, keys_q).is_empty(), "the speed key: x2, in its place")
	_press(_one(v, "bv_key", "speed"))
	ok(v.speed == 1 and _one(v, "bv_key", "speed").text == "x1", "and back to x1")
	# A unit's sheet.
	_press(_one(v, "bv_plate", "f0"))
	var sh = _one(host, "bv_sheet", "f0")
	var sh_words = _all(sh).filter(func(c): return c is Label).map(func(c): return c.text) if sh != null else []
	ok(sh != null and sh_words.has("Weak to") and sh_words.has("?") and sh_words.any(func(t): return t.begins_with("Next: ")) and sh_words.any(func(t): return t.begins_with("· Guard")), "a foe's plate opens its sheet: schools as known, its intent, its ways in words", sh_words)
	sh.queue_free()
	_press(_one(v, "bv_plate", "hero"))
	sh = _one(host, "bv_sheet", "hero")
	ok(sh != null and _with(sh, "rpg_move").size() == 5 and _all(sh).any(func(c): return c is Label and c.text.begins_with("Energy 0 /")), "the hero's plate opens the hero's sheet: numbers, the moves as cards", _with(sh, "rpg_move").size() if sh != null else "-")
	sh.queue_free()
	await _frames(2)
	await _shut(v)

	var Bp = RpgBattle.start(_setup(_hero(), [_wave(["squeaky_plate", "dust_bunny"])], true))
	Bp.pet["charge"] = int(Bp.pet.charge_max)
	Bp.hero["gauge"] = 100
	stored = 0
	v = await _open({}, {"resume": _round_trip(Bp), "store": func(_B): stored += 1})
	var pet_key = _one(v, "bv_key", "pet")
	var ult_key = _one(v, "bv_key", "ult")
	var item_key = _one(v, "bv_key", "item")
	ok(bool(pet_key.get_meta("bv_ok")) and bool(ult_key.get_meta("bv_ok")) and bool(ult_key.get_meta("bv_lit")) and str(item_key.get_meta("bv_badge")) == "x3", "a charged companion, a full gauge (lit), three items on the belt")
	var keys_p = _key_rects(v)
	_press(pet_key)
	v.skip()
	ok(int(v.B.pet.charge) == 0 and bool(RpgBattle.options(v.B).guard) and not bool(pet_key.get_meta("bv_ok")) and stored == 1 and int(v.B.sum.turns) == int(Bp.sum.turns), "the companion's command is free: it is spent, the turn goes on", [v.B.pet.charge, v.B.sum.turns])
	ok(_shown_wrong(v).is_empty() and _moved(v, keys_p).is_empty(), "after it: what is shown is B, no key moved", _shown_wrong(v))
	_press(item_key)
	var belt = _one(host, "bv_sheet", "items")
	var uses = _with(host, "bv_item")
	ok(belt != null and uses.size() == 2 and not uses[0].disabled and _all(belt).any(func(c): return c is Label and c.text == "Protein Shake x2"), "the Item key opens the belt: a row and a Use key per item", uses.size())
	_press(_one(host, "bv_item", "protein_shake"))
	v.skip()
	ok(int(v.B.sum.items) == 1 and int(v.B.hero.belt[0].used) == 1 and str(item_key.get_meta("bv_badge")) == "x2" and stored == 2, "an item is used through the sheet", [v.B.sum.items, item_key.get_meta("bv_badge")])
	await _frames(2)
	if not RpgBattle.over(v.B):
		_press(ult_key)
		v.skip()
		ok(int(floor(float(v.B.hero.gauge))) < 100 and not bool(ult_key.get_meta("bv_lit")) and _shown_wrong(v).is_empty(), "the ultimate spends the gauge", [v.B.hero.gauge, _shown_wrong(v)])
	# Flee asks once.
	if not RpgBattle.over(v.B):
		got = []
		v.finished.connect(func(B, s): got.append([v.choice, bool(s.fled), bool(s.win)]))
		for c in host.get_children():
			if c != v:
				c.queue_free()
		await _frames(1)
		_press(_one(v, "bv_key", "flee"))
		var asks = _all(host).filter(func(c): return c is Button and c.text == "Flee" and not v.is_ancestor_of(c))
		ok(asks.size() == 1 and got.is_empty() and not RpgBattle.over(v.B), "Flee asks once before anything happens", asks.size())
		_press(asks[0] if not asks.is_empty() else null)
		ok(RpgBattle.over(v.B) and bool(v.B.fled), "the confirm's key flees")
		v.skip()
		await _frames(3)
		ok(got.size() == 1 and str(got[0][0]) == "flee" and bool(got[0][1]) and not bool(got[0][2]) and not is_instance_valid(v), "fleeing ends the battle as a loss with no result screen: finished, choice flee", got)
	await _shut(v if is_instance_valid(v) else null)

	# --- resuming a stored battle --------------------------------------------------------------------
	v = await _open(_setup(_hero(), [_wave(["dust_bunny", "rust_rat"])], true, 5), {"title": "Resume"})
	v.skip()
	for i in range(2):
		_press_action(v, RpgAi.hero_action(v.B, "heuristic"))
		v.skip()
	var kept = _round_trip(v.B)
	var seen = {"hp": _one(v, "bv_hp_hero").text, "en": _one(v, "bv_energy").get_meta("bv_energy"), "ga": _one(v, "bv_gauge").get_meta("bv_gauge"), "turn": _one(v, "bv_turn").get_meta("bv_turn"),
		"wave": _one(v, "bv_wave").get_meta("bv_wave"), "tl": _one(v, "bv_timeline").get_meta("bv_timeline"), "target": v.target,
		"plates": _with(v, "bv_plate").map(func(p): return [p.get_meta("bv_plate"), p.get_meta("bv_hp", -1), p.get_meta("bv_guard", -1)]),
		"keys": _with(v, "bv_move").map(func(k): return [k.get_meta("bv_move"), k.get_meta("bv_ok"), k.get_meta("bv_dmg"), k.get_meta("bv_tag")])}
	var weak_seen = _with(v, "bv_plate").filter(func(p): return str(p.get_meta("bv_plate")) != "hero").map(func(p): return p.weak_shown())
	var over_already = RpgBattle.over(v.B)
	await _shut(v)
	if not over_already:
		v = await _open({}, {"resume": kept, "title": "Resume"})
		var seen2 = {"hp": _one(v, "bv_hp_hero").text, "en": _one(v, "bv_energy").get_meta("bv_energy"), "ga": _one(v, "bv_gauge").get_meta("bv_gauge"), "turn": _one(v, "bv_turn").get_meta("bv_turn"),
			"wave": _one(v, "bv_wave").get_meta("bv_wave"), "tl": _one(v, "bv_timeline").get_meta("bv_timeline"), "target": v.target,
			"plates": _with(v, "bv_plate").map(func(p): return [p.get_meta("bv_plate"), p.get_meta("bv_hp", -1), p.get_meta("bv_guard", -1)]),
			"keys": _with(v, "bv_move").map(func(k): return [k.get_meta("bv_move"), k.get_meta("bv_ok"), k.get_meta("bv_dmg"), k.get_meta("bv_tag")])}
		var weak_seen2 = _with(v, "bv_plate").filter(func(p): return str(p.get_meta("bv_plate")) != "hero").map(func(p): return p.weak_shown())
		ok(not v.busy() and _same(seen, seen2) and weak_seen == weak_seen2 and _shown_wrong(v).is_empty(), "a battle resumed from a stored B shows the same state, ready for the player", [seen, seen2, weak_seen, weak_seen2])
		var twin = _round_trip(kept)
		var act = RpgAi.hero_action(twin, "heuristic")
		RpgBattle.act(twin, act)
		_press_action(v, act)
		v.skip()
		ok(_same(v.B, twin), "and goes on as the very same battle")
		await _shut(v)

	# --- a battle that was over when it was stored ----------------------------------------------------
	var Bo = RpgBattle.start(_setup(_hero(), [_wave(["dust_bunny"])]))
	RpgBattle.act(Bo, {"t": "flee"})
	Bo["fled"] = false
	v = await _open({}, {"resume": _round_trip(Bo)})
	ok(v.result() != null and str(v.result().get_meta("bv_result")) == "loss", "a stored battle that was over opens on its result")
	await _shut(v)

	# --- one fight at its own pace -------------------------------------------------------------------
	v = await _open(_setup(_hero(), [_wave(["dust_bunny"])], true), {"title": "Paced", "scene": "rustyard", "speed": 2})
	var paced = []
	var acts = 0
	var started = Time.get_ticks_msec()
	while v.result() == null and acts < 30 and Time.get_ticks_msec() - started < 60000:
		var w0 = Time.get_ticks_msec()
		while v.busy() and Time.get_ticks_msec() - w0 < 20000:
			await process_frame
		if v.busy():
			paced.append("a playback did not end")
			break
		if v.result() != null:
			break
		paced.append_array(_shown_wrong(v))
		paced.append_array(_layout_wrong(v))
		if not _press_action(v, RpgAi.hero_action(v.B, "heuristic")):
			paced.append("could not press")
			break
		acts += 1
	ok(paced.is_empty() and v.result() != null and RpgBattle.won(v.B) and acts >= 1, "a whole fight at its own pace (x2): every playback ends by itself, and what is shown then is B", [paced.slice(0, 4), acts, Time.get_ticks_msec() - started])
	ok(v._hero_view != null and v._hero_view.forced_pose == "flex" and not v._hero_view.animate, "the hero ends a win in the flex pose, at frame 0", v._hero_view.forced_pose if v._hero_view != null else "-")
	await _shut(v)

	# --- the whole view inside 440 x 720; then the same with fingers ----------------------------------
	for fingers in [false, true]:
		kit.fingers = fingers
		var tag = "fingers" if fingers else "normal size"
		host.size = Vector2(W, 720)
		await _frames(1)
		v = await _open(_setup(_hero(1.0, true), [_wave(["dust_bunny", "rust_rat", "squeaky_plate"]), _wave(["moldy_towel"])], true, 9), {"title": "A long stage name that will not fit the bar", "scene": "chalk", "tutorial": true})
		v.skip()
		ok(_with(v, "bv_move").size() == 5 and v.needed_height() <= 720.0 and v.size == Vector2(W, 720) and _layout_wrong(v).is_empty(), "%s: five moves (three rows) and the whole view fit 440 x 720" % tag, [v.needed_height(), _layout_wrong(v).slice(0, 4)])
		var low = _all(v).filter(func(c): return c is Button and (c.has_meta("bv_move") or c.has_meta("bv_key")) and c.size.y < (40.0 if fingers else 30.0))
		ok(low.is_empty(), "%s: every key is high enough" % tag, low.map(func(c): return [c.get_meta("anchor_id"), c.size]))
		var slots = {"top": [v._top.position.y, v._top.size.y], "arena": [v._arena.position.y, v._arena.size.y], "timeline": [v._timeline.position.y, v._timeline.size.y], "plate": [v._hero_plate.position.y, v._hero_plate.size.y],
			"line": [v._line_box.position.y, v._line_box.size.y], "moves": [v._moves.position.y, v._moves.size.y], "keys": [v._acts.position.y, v._acts.size.y]}
		print("  (%s, 440 x 720: %s)" % [tag, str(slots)])
		var ff = await _fight(v)
		_report(tag, v, ff, true)
		var rf = v.result()
		rf.skip()
		await _frames(2)
		ok(_with(rf, "br_key").all(func(k): return k.size.y >= 40.0 and k.get_global_rect().end.y <= 720.5 and k.get_global_rect().end.x <= W + 0.5), "%s: the result's keys are high enough and on the screen" % tag, _with(rf, "br_key").map(func(k): return k.get_global_rect()))
		await _shut(v)
		host.size = Vector2(W, 900)
		await _frames(1)
		v = await _open(_setup(_hero(), [_wave(["dust_bunny", "rust_rat"])], true, 4), {"title": "Tall"})
		v.skip()
		ok(_layout_wrong(v).is_empty() and v._arena.size.y > 240.0, "%s: in a taller column the arena takes some of the room, the keys stay at the bottom" % tag, [_layout_wrong(v).slice(0, 4), v._arena.size.y])
		ok(absf(v._acts.get_global_rect().end.y - (900.0 - 6.0)) < 0.5, "%s: the action keys hang from the bottom edge" % tag, v._acts.get_global_rect())
		var hole = v._moves.global_position.y - v._line_box.get_global_rect().end.y
		ok(hole <= 24.5 and hole >= 3.5 and v._move_h > v._move_h0 and v._move_h <= 72.0 and v._act_h == 56.0 and v._line_h == 42.0 and v._line.autowrap_mode != TextServer.AUTOWRAP_OFF and v._arena.size.y > 320.0,
			"%s, 440 x 900: the height is used (taller keys, a two-line line, more sky): no hole between the line and the keys" % tag, [hole, v._move_h, v._act_h, v._line_h, v._arena.size.y])
		v._say("A very long line that says what just happened and would not fit on one line of this column at all, not nearly, so it takes two.")
		await _frames(2)
		ok(v._line.get_line_count() >= 2 and absf(v._line_box.size.y - 42.0) < 0.5 and _layout_wrong(v).is_empty(), "%s, 440 x 900: a long line takes two lines and nothing moves" % tag, [v._line.get_line_count(), v._line_box.size])
		print("  (%s, 440 x 900: arena %s, timeline %s, plate %s, line %s, moves %s (key %s), keys %s)" % [tag, str([v._arena.position.y, v._arena.size.y]), str(v._timeline.position.y), str(v._hero_plate.position.y), str([v._line_box.position.y, v._line_box.size.y]),
			str([v._moves.position.y, v._moves.size.y]), str(v._move_h), str([v._acts.position.y, v._acts.size.y])])
		_press(_one(v, "bv_key", "item"))
		var use_f = _one(host, "bv_item", "protein_shake")
		ok(use_f != null and use_f.custom_minimum_size.y >= 40.0, "%s: the belt's Use key is high enough" % tag)
		await _shut(v)
	# A narrower phone (412 wide), fingers on.
	host.size = Vector2(412, 760)
	await _frames(1)
	v = await _open(_setup(_hero(1.0, true), [_wave(["dust_bunny", "rust_rat", "squeaky_plate"])], true, 9), {"title": "Narrow", "scene": "marsh", "tutorial": true, "instant": true})
	var fn = await _fight(v)
	_report("412 wide", v, fn, true)
	await _shut(v)
	host.size = Vector2(W, 900)
	kit.fingers = false

	print("RPG BATTLE UI: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
