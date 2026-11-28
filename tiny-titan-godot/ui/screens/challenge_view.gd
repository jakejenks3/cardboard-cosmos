class_name ChallengeView
extends RefCounted
## The day's lift challenges on screen (Challenges, Missions.daily; 2026-11-27).
##
## (2026-11-28, the user: "It like almost works but is too muddled for some reason.") The CHALLENGES section of
## the Hero tab is gone: a challenge now sits INSIDE its lift's row of the TODAY card (TodayView._lift_row), so
## each lift appears once, with its ways and its records together. This file draws those pieces:
##
##   strip(m, gi)         a challenge mission as a strip at the foot of its lift's row: a sword, "MISSION", PICK
##                        ONE (or YOUR GOAL), the reward (or MISSION DONE and the Claim key), then its records
##                        side by side as tiles (what kind on a coloured strip, the target big, what it beats
##                        small). Every tile is a KEY: a tap makes it the lift's GOAL in today's prep
##                        (App.prep_goal: its last set becomes that record; the prep is made from the day's plan
##                        when there is none); a tap on the goal takes it off. The goal's tile is gold with a
##                        star and twinkles (meta `challenge_picked`). Metas: `challenge` = the mission's id on
##                        the strip, `challenge_option` = type and `challenge_hit` on each tile, `challenge_claim`
##                        on the Claim key, `challenge_hint` (pick | goal | done) on the words in its head.
##   way_key(...)         one way to do a lift (its variation, the same lift at the other place, another movement
##                        of its family) as a small key: today's way lit orange, one never done light blue, the
##                        others tan; a tap makes it today's way in today's prep (App.prep_way; the records then
##                        follow by themselves). Metas `challenge_way` and `lift_option` = the way's full name.
##   way_word(name, ref)  a way in a word or two against the movement `ref`: "Dumbbell", "Dip".
##   look(type)           [icon, colour] of an option
##   chip_text(o)         an option said on a key: "Heavier 65 × 6"
##
## The look (the Workshop look, 2026-11-27 review: "a list of small text... not the mock's three coloured
## tiles"): as in the mock-up the user picked, each record is a tile with a strip in its colour (red HEAVIER,
## purple REP RECORD, blue BEST FOR N), the number big with its unit small, and what it beats under it.
## Nothing moves under the finger: a key's words never change with its state, every key has an anchor_id made
## from the row's place (`gi`, TodayView._stable_ways) and what it stands for, a tile keeps its place when it
## becomes the goal (`_ordered`), and after a tap that changed today's prep taps are ignored for QUIET_MS while
## the card is drawn again under the finger.

const WORDS = {"heavier": "Heavier", "reps": "Rep PR", "ladder": "Best", "set_reps": "Set PR", "day_reps": "Day PR", "band": "Band up", "hold": "Longer"}
## The word on a record's tile, by its type ("BEST FOR N" for a ladder).
const HEADS = {"heavier": "HEAVIER", "reps": "REP RECORD", "set_reps": "ONE SET", "day_reps": "IN A DAY", "band": "BAND UP", "hold": "LONGER"}
## How wide the numbers of a tile may get, by how many tiles share the row (they never widen it).
const TILE_TEXT = {1: 240.0, 2: 150.0, 3: 92.0}
## The widest a way key's words get before they end in "…" (the row is about 360 px inside).
const WAY_MAX = 170.0
## After a tap changed today's prep the card is drawn again under the finger: taps are ignored this long.
const QUIET_MS = 350
static var _quiet_until = 0


## (2026-11-27 review, the mock-up: red HEAVIER, purple REP RECORD, blue BEST FOR N; gold is kept for rewards.
## The Log tab's TRY keys and the prep sheet take the same colours from here.)
static func look(type: String) -> Array:
	match type:
		"heavier", "band":
			return ["arrow_up", Pal.DANGER]
		"ladder":
			return ["crown", Pal.SECOND]
		"hold":
			return ["stopwatch", Pal.SECOND]
	return ["plus", Pal.BOUNTY]


static func chip_text(o: Dictionary) -> String:
	var w = str(WORDS.get(str(o.type), ""))
	if str(o.type) == "ladder":
		w = "Best %d" % int(o.reps)
	return "%s %s" % [w, str(o.chip)]


## The goal picked for a challenge's lift in today's prep ({} when none).
static func _goal(m: Dictionary) -> Dictionary:
	var g = m.get("goal")
	return g if g is Dictionary else {}


## The records of a challenge in the order Challenges gives them for its lift today (the missions put the goal
## first: here it stays in its place, so a tile does not move when it becomes the goal); a goal picked on
## another day that is not among today's records comes first.
static func _ordered(m: Dictionary) -> Array:
	var opts = m.get("options", [])
	if opts.is_empty():
		return []
	var natural = App.challenge_options(str(m.lift))
	var used = {}
	var out = []
	for o in natural:
		for i in range(opts.size()):
			if not used.has(i) and Challenges.same_option(o, opts[i]):
				used[i] = true
				out.append(opts[i])
				break
	var extra = []
	for i in range(opts.size()):
		if not used.has(i):
			extra.append(opts[i])
	return (extra + out).slice(0, 3)


## A challenge mission as a strip inside its lift's row (TodayView._lift_row). `gi`: the row's place
## (TodayView._stable_ways), for the tiles' anchors.
static func strip(m: Dictionary, gi: int = 0) -> Control:
	var done = bool(m.done)
	var claimed = bool(m.claimed)
	var goal = _goal(m)
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# (a tap between the tiles is nothing: the row under it would open the lift's page)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var box_opts = {"pad_h": 5, "pad_v": 4}
	if done and not claimed:
		box_opts["fill"] = Color(Pal.MATERIALS["note"].fill).lerp(Pal.GOOD, 0.3)
	p.add_theme_stylebox_override("panel", PixBox.material("note", box_opts))
	p.set_meta("challenge", str(m.id))
	var v = Kit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The head: a sword, MISSION, what to do (pick one / your goal), the reward or the Claim key.
	var head = Kit.hbox(5)
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	head.tooltip_text = str(m.desc)
	head.add_child(Kit.vcenter(Icons.rect("check" if done else "sword", 16)))
	var title = Kit.label("MISSION DONE" if done else "MISSION", 11, Pal.GOOD_DARK if done else Pal.TEXT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var said = Kit.label("", 11, Pal.MUTED, true)
	said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.clip_text = true
	said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if done:
		said.set_meta("challenge_hint", "done")
	elif not goal.is_empty():
		said.text = "· YOUR GOAL"
		said.add_theme_color_override("font_color", Pal.ACCENT_DARK)
		said.set_meta("challenge_hint", "goal")
	else:
		said.text = "· PICK ONE"
		said.set_meta("challenge_hint", "pick")
	head.add_child(said)
	if claimed:
		head.add_child(Kit.vcenter(Kit.tag("CLAIMED", Pal.GOOD, true, 11)))
	elif done:
		var claim = Kit.button("Claim +%s" % Xp.fmt_int(m.xp), "good", Callable(), "sm")
		claim.set_meta("anchor_id", "claim:" + str(m.id))
		claim.set_meta("challenge_claim", str(m.id))
		claim.pressed.connect(Parts._claim.bind(m, claim))
		Fx.shine(claim, 2.6, 0.5, 0.45)
		head.add_child(Kit.vcenter(claim))
	else:
		head.add_child(Kit.vcenter(Parts.reward_plate(m.xp, 11)))
	v.add_child(head)
	var shown = _ordered(m)
	var hit = m.get("hit", [])
	if shown.is_empty():
		# (a lift never done: no record yet, doing it is the mission)
		var w = Kit.para(str(m.desc), 11, Pal.MUTED)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(w)
	else:
		# The records, side by side (a third of the row each; two share it by halves), each a key.
		var tiles = Kit.hbox(6)
		tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for o in shown:
			var picked = not goal.is_empty() and Challenges.same_option(o, goal)
			tiles.add_child(_tile(o, hit.has(str(o.type)), shown.size(), picked, m, gi))
		v.add_child(tiles)
	if hit.has("other"):
		var ol = Kit.clip("Done another way: it counts.", 11, Pal.GOOD_DARK, true)
		ol.set_meta("challenge_other", true)
		v.add_child(ol)
	p.add_child(v)
	return p


## One way to do a lift as a key (Kit.chip: the same size whatever its state, and its words never change with
## it, so it stays under the finger when the card is drawn again): today's way (`on`) orange, one never done
## (`fresh`) light blue, the others tan. A tap makes it today's way (`pick_way`). `planned`: the plan's lift it
## stands in for; `current`: today's way. Metas "challenge_way" and "lift_option" = the lift's full name,
## "challenge_way_on" on today's, "anchor_id" = `anchor`.
static func way_key(lift_name: String, word: String, on: bool, fresh: bool, planned: String, current: String, anchor: String, tip: String = "") -> Button:
	var face = Pal.ACCENT2 if on else (Pal.SECOND.lerp(Pal.CREAM, 0.55) if fresh else null)
	var b = Kit.chip(word, on or fresh, pick_way.bind(planned, current, lift_name), face, 12)
	var w = Kit.font_bold().get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	if w > WAY_MAX:
		# (a long variation is cut off rather than make the card wider than the column)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size.x = WAY_MAX + 30.0
	var t = Missions.short_name(lift_name)
	if on:
		t += " · today's way"
	elif fresh:
		t += " · new to you"
	if tip != "":
		t += " · " + tip
	if not on:
		t += "\nTap: do it this way today (it goes into today's prep)"
	b.tooltip_text = t
	b.set_meta("challenge_way", lift_name)
	b.set_meta("lift_option", lift_name)
	b.set_meta("anchor_id", anchor)
	if on:
		b.set_meta("challenge_way_on", true)
	return b


## A way in a word or two, against the movement `ref`: its variation ("Single arm cable"), the equipment of a
## plain one ("Bodyweight", "Plain"), or another movement by its name ("Pull-up", "Pullover (dumbbell)").
static func way_word(lift_name: String, ref: String) -> String:
	var sp = LiftNames.split(lift_name)
	var w = Missions.way_label({"name": lift_name, "move": str(sp.move), "variation": str(sp.variation)}, ref)
	if w == "":
		w = lift_name
	return w.substr(0, 1).to_upper() + w.substr(1)


static func _quiet() -> bool:
	return Time.get_ticks_msec() < _quiet_until


static func _hush() -> void:
	_quiet_until = Time.get_ticks_msec() + QUIET_MS


## Today's way of a planned lift (App.prep_way: into today's prep, made from the day's plan when there is
## none). Its row then shows that way's aim and records; a goal picked for the way before is dropped (a goal
## belongs to one way).
static func pick_way(planned: String, current: String, way: String) -> void:
	if _quiet():
		return
	if Xp.normalize_exercise(way) == Xp.normalize_exercise(current):
		Sfx.tick()
		return
	_hush()
	Sfx.pop()
	App.prep_way(planned if planned != "" else current, way)
	App.toast("Today: %s. It is in today's prep." % Missions.short_name(way), "info", "edit")


## A record tapped: today's goal for the lift (App.prep_goal: into today's prep, its last set that record), or,
## tapped again, no goal.
static func _pick_goal(m: Dictionary, o: Dictionary, picked: bool, key: Control) -> void:
	if _quiet():
		return
	_hush()
	var lift = str(m.lift)
	if picked:
		Sfx.unpop()
		App.prep_goal(lift, {})
		App.toast("Goal taken off: %s" % Missions.short_name(lift), "info", "star")
		return
	Sfx.pop()
	Kit.burst(key, Pal.ACCENT, 18)
	App.prep_goal(lift, o)
	App.toast("Goal set: %s, %s. It is in today's prep." % [Missions.short_name(lift), TodayView.goal_words(o, App.weight_unit())], "good", "star")


## One record to go for as a tile (a strip in its colour with what kind it is, a tick once hit and the tile
## then green, the target big ("77.5 kg ×6", "9 reps"), what it beats small under it), on a key: a tap makes it
## the lift's goal today, a tap on the goal takes it off. The goal: a gold rim and wash, a gold strip with a
## star before its kind ("GOAL DONE" once hit), a twinkle. Every tile has as many rings as the others, so none changes size.
## Metas on the key: "challenge_option" (its type), "challenge_hit", and "challenge_picked" (true) on the goal.
static func _tile(o: Dictionary, is_hit: bool, n: int, picked: bool = false, m: Dictionary = {}, gi: int = 0) -> Control:
	var type = str(o.type)
	var col: Color = Pal.GOOD if is_hit else (Pal.ACCENT if picked else look(type)[1])
	var t = PanelContainer.new()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill = Pal.PANEL2.lerp(Pal.GOOD, 0.28) if is_hit else (Pal.PANEL2.lerp(Pal.ACCENT, 0.3) if picked else Pal.PANEL2)
	# A dark rim and a bevel (2 art px), the strip right inside it; the goal's bevel is gold.
	var bevel = PixBox.bev(Pal.ACCENT.lightened(0.25), Pal.ACCENT_DARK) if picked else PixBox.bev(fill.lightened(0.5), fill.darkened(0.18))
	t.add_theme_stylebox_override("panel", PixBox.nine([Pal.OUTLINE, bevel], fill, {"cut": 1, "pad_h": 4, "pad_v": 4}))
	var v = Kit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The strip: what kind of record (on the goal: that it is the goal).
	var strip = PanelContainer.new()
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", PixBox.nine([PixBox.bev(col.lightened(0.3), col.darkened(0.3))], col, {"cut": 0, "pad_h": 3, "pad_v": 2}))
	var sh = Kit.hbox(3)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_hit:
		sh.add_child(Kit.vcenter(Icons.rect("check", 16, Pal.CREAM)))
	elif picked:
		# (the goal: a star before what kind of record it is, dark on the gold strip)
		sh.add_child(Kit.vcenter(Icons.rect("star", 16, Pal.INK)))
	else:
		# (its kind's icon, in the words' colour: an arrow up for heavier, a plus for more reps, a crown for N)
		sh.add_child(Kit.vcenter(Icons.rect(str(look(type)[0]), 16, Pal.INK if Ink.luminance(col) > 0.42 else Pal.CREAM)))
	var word = str(HEADS.get(type, str(o.get("title", "")).to_upper()))
	if type == "ladder":
		word = "BEST FOR %d" % int(o.get("reps", 0))
	if picked and is_hit:
		word = "GOAL DONE"
	var wl = Kit.tag_words(word, 11, col)
	wl.clip_text = true
	wl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wl.custom_minimum_size = Vector2(20, 0)
	sh.add_child(Kit.vcenter(wl))
	strip.add_child(sh)
	v.add_child(strip)
	# The target: the number big, its unit small, the reps beside it.
	var w = _tile_words(o)
	var budget = float(TILE_TEXT.get(n, 96.0))
	var num = Kit.hbox(2)
	num.alignment = BoxContainer.ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(w.get("plain", false)):
		# (an option of a kind this does not know: its words, cut off rather than widen the row)
		var pl = Kit.clip(str(w.big), 14, Pal.TEXT, true)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.custom_minimum_size = Vector2(minf(budget, _w(str(w.big), 14)), 0)
		num.add_child(pl)
	else:
		var px = 14
		for want in [22, 20, 18, 16]:
			if _w(str(w.big), want) + _w(str(w.unit), 11) + _w(str(w.times), 14) + 6.0 <= budget:
				px = want
				break
		num.add_child(_num_label(str(w.big), px, Pal.TEXT))
		if str(w.unit) != "":
			num.add_child(_num_label(str(w.unit), 11, Pal.MUTED))
		if str(w.times) != "":
			num.add_child(_num_label(str(w.times), 14, Pal.TEXT))
	v.add_child(num)
	# What it beats.
	var sub = str(w.sub)
	var sl = Kit.clip(sub, 11 if _w(sub, 11) <= budget else 10, Pal.GOOD_DARK if is_hit else Pal.MUTED, true)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sl)
	t.add_child(v)
	# The key the tile sits on: no face of its own (the tile is its face), as big as the tile.
	var k = Button.new()
	k.flat = true
	k.focus_mode = Control.FOCUS_NONE
	k.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var empty = StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		k.add_theme_stylebox_override(s, empty)
	k.set_meta("challenge_option", type)
	k.set_meta("challenge_hit", is_hit)
	if picked:
		k.set_meta("challenge_picked", true)
	k.set_meta("anchor_id", "copt:%d:%s:%d:%d:%s:%d" % [gi, type, int(round(float(o.get("kg", 0.0)) * 100.0)), int(o.get("reps", 0)), str(o.get("band", "")), int(o.get("sec", 0))])
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	k.add_child(t)
	var fit = func(): k.custom_minimum_size = t.get_combined_minimum_size()
	fit.call()
	t.minimum_size_changed.connect(fit)
	var title = str(o.get("title", "A record"))
	if m.is_empty() or bool(m.get("claimed", false)):
		k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		k.tooltip_text = "%s: %s" % [title, str(o.get("words", ""))]
	else:
		k.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if picked:
			k.tooltip_text = "Your goal today: %s, %s. Tap again to take it off." % [title.to_lower(), str(o.get("words", ""))]
		else:
			k.tooltip_text = "%s: %s. Tap to make it today's goal: it goes into today's prep as your last set, the ones before work up to it." % [title, str(o.get("words", ""))]
		# (the tile sinks while it is held, as a key's face does)
		k.button_down.connect(func():
			t.offset_top = PixBox.S
			t.offset_bottom = PixBox.S)
		k.button_up.connect(func():
			t.offset_top = 0
			t.offset_bottom = 0)
		k.button_down.connect(Sfx.click)
		k.pressed.connect(_pick_goal.bind(m, o, picked, k))
	if picked:
		Fx.twinkle(k, Pal.ACCENT_DARK, 3)
	return k


## A label of a tile's number line, sat on the line's bottom so the big and small words share a baseline.
static func _num_label(text: String, px: int, color: Color) -> Label:
	var l = Kit.label(text, px, color, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## How wide `text` is in the bold font at `px`.
static func _w(text: String, px: int) -> float:
	if text == "":
		return 0.0
	return Kit.font_bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## A tile's words for an option of Challenges: {"big", "unit", "times", "sub"} ("plain": just its words).
static func _tile_words(o: Dictionary) -> Dictionary:
	var type = str(o.get("type", ""))
	var sub = str(o.get("sub", ""))
	# "Your heaviest: 75 kg × 8" -> "75 kg × 8": what it beats, without the words before it.
	var was = sub.substr(sub.rfind(": ") + 2) if sub.contains(": ") else sub
	var reps = int(o.get("reps", 0))
	var band = str(o.get("band", ""))
	match type:
		"heavier", "ladder":
			if band == "":
				var nu = _num_unit(float(o.get("kg", 0.0)))
				return {"big": nu[0], "unit": nu[1], "times": "×%d" % reps, "sub": ("best " if type == "heavier" else "so far ") + was}
		"reps":
			var at = Bands.words(band) if band != "" else "at " + Fmt.fmt_weight(float(o.get("kg", 0.0)), App.weight_unit())
			return {"big": str(reps), "unit": "reps", "times": "", "sub": "%s · most %s" % [at, was]}
		"set_reps":
			return {"big": str(reps), "unit": "reps", "times": "", "sub": "in a set · most %s" % was}
		"day_reps":
			return {"big": str(reps), "unit": "reps", "times": "", "sub": "in a day · most %s" % was}
		"band":
			return {"big": str(reps), "unit": "reps", "times": "", "sub": Bands.words(band)}
		"hold":
			return {"big": str(int(o.get("sec", 0))), "unit": "s", "times": "", "sub": "best " + was}
	return {"plain": true, "big": str(o.get("words", "")), "unit": "", "times": "", "sub": sub}


## "77.5 kg" -> ["77.5", "kg"] in the player's unit.
static func _num_unit(kg: float) -> Array:
	var fw = Fmt.fmt_weight(kg, App.weight_unit())
	var sp = fw.find(" ")
	if sp <= 0:
		return [fw, ""]
	return [fw.substr(0, sp), fw.substr(sp + 1)]
