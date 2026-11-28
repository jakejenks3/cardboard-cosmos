class_name ChallengeView
extends RefCounted
## The day's lift challenges on screen (Challenges, Missions.daily; 2026-11-27).
##
##   section()            the Hero tab's CHALLENGES section, under TODAY: a card a challenge: the lift, "pick
##                        one" and the reward, its records to go for as coloured tiles side by side (what kind,
##                        the target big, what it beats), the one hit lit green with a tick, something to try,
##                        and the Claim key once done. A tap opens the lift.
##   look(type)           [icon, colour] of an option
##   chip_text(o)         an option said on a key: "Heavier 65 × 6"
##
## The look (the Workshop look, 2026-11-27 review: "a list of small text... not the mock's three coloured
## tiles"): as in the mock-up the user picked, each record is a tile with a strip in its colour (red HEAVIER,
## purple REP RECORD, blue BEST FOR N), the number big with its unit small, and what it beats under it.

const WORDS = {"heavier": "Heavier", "reps": "Rep PR", "ladder": "Best", "set_reps": "Set PR", "day_reps": "Day PR", "band": "Band up", "hold": "Longer"}
## The word on a record's tile, by its type ("BEST FOR N" for a ladder).
const HEADS = {"heavier": "HEAVIER", "reps": "REP RECORD", "set_reps": "ONE SET", "day_reps": "IN A DAY", "band": "BAND UP", "hold": "LONGER"}
## How wide the numbers of a tile may get, by how many tiles share the row (they never widen it).
const TILE_TEXT = {1: 240.0, 2: 150.0, 3: 96.0}


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


static func section():
	var list = App.quests().get("daily", []).filter(func(m): return bool(m.get("challenge", false)))
	if list.is_empty():
		return null
	var done = list.filter(func(m): return bool(m.done)).size()
	var right = Kit.label("%d / %d" % [done, list.size()], 12, Pal.TEXT, true)
	var sec = Kit.section("challenges", "CHALLENGES", "sword", Pal.ACCENT2, right, Callable(), 8, 10)
	# (the intro sentence is gone: each card says "pick one", and its tiles say the rest)
	for m in list:
		sec.add(card(m))
	return sec


static func card(m: Dictionary) -> Control:
	var done = bool(m.done)
	var claimed = bool(m.claimed)
	# A sand card in the section (paper with a dark rim), green-tinted once done; the tiles on it are cream.
	var c = Kit.card(6, JourneyLifts.open_named.bind(str(m.lift), {"view": "progress"}), 8)
	c.tint(Pal.PANEL.lerp(Pal.GOOD, 0.22) if (done and not claimed) else Pal.PANEL)
	c.set_meta("challenge", str(m.id))
	c.tooltip_text = "Open %s" % Missions.short_name(str(m.lift))
	if claimed:
		c.modulate.a = 0.65
	# The head: the body part's icon in a slot, the lift, "pick one", and the reward (or Claim, or DONE).
	var head = Kit.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var part = str(Missions.part_of(str(m.lift)))
	head.add_child(Kit.vcenter(Kit.badge(TodayView.part_icon(part), JourneyLifts.part_color(part), 24)))
	var sp = LiftNames.split(str(m.lift))
	var nm = Kit.squeeze(6)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.add_child(Kit.soft_name(str(sp.move), 17, null, true, 200.0))
	if str(sp.variation) != "":
		nm.add_child(TodayView._var_tag(str(sp.variation), 10))
	if not claimed:
		var hint = Kit.label("DONE!" if done else "PICK ONE", 11, Pal.GOOD if done else Pal.MUTED, true)
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm.add_child(hint)
	head.add_child(nm)
	if claimed:
		head.add_child(Kit.vcenter(Kit.tag("DONE", Pal.GOOD, true, 11)))
	elif done:
		var claim = Kit.button("Claim +%s" % Xp.fmt_int(m.xp), "good", Callable(), "sm")
		claim.set_meta("anchor_id", "claim:" + str(m.id))
		claim.set_meta("challenge_claim", str(m.id))
		claim.pressed.connect(Parts._claim.bind(m, claim))
		Fx.shine(claim, 2.6, 0.5, 0.45)
		head.add_child(Kit.vcenter(claim))
	else:
		head.add_child(Kit.vcenter(Parts.reward_plate(m.xp, 12)))
	c.add(head)
	var opts = m.get("options", [])
	var hit = m.get("hit", [])
	if opts.is_empty():
		c.add(Kit.para(str(m.desc), 12, Pal.MUTED))
		return c
	# The records, side by side (a third of the row each; two share it by halves).
	var shown = opts.slice(0, 3)
	var tiles = Kit.hbox(6)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for o in shown:
		tiles.add_child(_tile(o, hit.has(str(o.type)), shown.size()))
	c.add(tiles)
	if hit.has("other"):
		c.add(_note("check", "Done another way: it beat its last time.", Pal.GOOD))
	elif not done:
		var tip = _note("clock", "Try: " + str(opts[0].tip), Pal.TEXT)
		tip.set_meta("challenge_tip", true)
		c.add(tip)
	return c


## One record to go for as a tile: a strip in its colour with what kind it is (a tick once hit, the tile then
## green), the target big ("77.5 kg ×6", "9 reps"), what it beats small under it. Metas "challenge_option"
## (its type) and "challenge_hit".
static func _tile(o: Dictionary, is_hit: bool, n: int) -> Control:
	var type = str(o.type)
	var col: Color = Pal.GOOD if is_hit else look(type)[1]
	var t = PanelContainer.new()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill = Pal.PANEL2.lerp(Pal.GOOD, 0.28) if is_hit else Pal.PANEL2
	# A dark rim and a bevel (2 art px), the strip right inside it.
	t.add_theme_stylebox_override("panel", PixBox.nine([Pal.OUTLINE, PixBox.bev(fill.lightened(0.5), fill.darkened(0.18))], fill, {"cut": 1, "pad_h": 4, "pad_v": 4}))
	t.set_meta("challenge_option", type)
	t.set_meta("challenge_hit", is_hit)
	var v = Kit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The strip: what kind of record.
	var strip = PanelContainer.new()
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", PixBox.nine([PixBox.bev(col.lightened(0.3), col.darkened(0.3))], col, {"cut": 0, "pad_h": 3, "pad_v": 2}))
	var sh = Kit.hbox(3)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_hit:
		sh.add_child(Kit.vcenter(Icons.rect("check", 16, Pal.CREAM)))
	var word = str(HEADS.get(type, str(o.get("title", "")).to_upper()))
	if type == "ladder":
		word = "BEST FOR %d" % int(o.get("reps", 0))
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
	return t


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


## A slip under the tiles with an icon and a line that wraps: something to try, or how it was done.
static func _note(icon: String, text: String, color: Color) -> Control:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", PixBox.material("slip", {"pad_h": 6, "pad_v": 4}))
	var h = Kit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect(icon, 16)))
	var l = Kit.para(text, 12, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	p.add_child(h)
	return p
