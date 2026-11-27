class_name RealmMap
extends RefCounted
## The Map page of the Realm tab (RPG_PLAN.md 10.1, 8): where to fight.
##
##   RealmMap.fill(box, screen)     # `screen` is the RealmScreen (asked to rebuild when a region is picked)
##
## Three sections, top to bottom:
##   map_hunts   the DAILY HUNT row (today's pack as small sprites, the day's rule, the two schools the pack is
##               weak to, "WON" once won; a tap opens the prep sheet; after the day's first win a "Prize" key
##               opens the three prizes to pick one from) and the WEEKLY RIVAL row when there is a bounty
##               monster this week.
##   map_road    the eight regions as numbered keys (a locked one dimmed with a lock; the chosen one is kept in
##               `region_id`, by default the furthest open); with the echoes open a "The road / Echoes" track;
##               the region's card (a strip of its backdrop, name, blurb, what it teaches, its stars and the
##               three star chests at 8 / 16 / 24: locked, ready to open, opened); then its ten stages as a
##               path of node keys two across (number, name, kind icon, the stars earned; done / open / locked,
##               every tile the same size).
##   map_spire   the Spire: what opens it, or "Floor N" with a Fight key.
##
## SHEETS: open_prep(what) (the stage's story, its rules, the foes of each wave as tiles with the weaknesses the
## player has learned and "?" for the rest, the recommended power against the hero's with a word, the three
## stars, the first-win rewards, a big Fight key); open_foe(...) from a foe tile (RpgFoes.words); open_cache
## (a cache node: three finds as big pick keys); open_prizes (the hunt's three prizes).
##
## Everything goes through RpgUi (save, stage_of, fight, apply); nothing here reads the log.
##
## Metas for tests: map_hunt (date; map_hunt_state open | won | prize; map_hunt_prize on the Prize key),
## map_rival (week; map_rival_state open | won), map_region (region id; map_region_state chosen | open | locked),
## map_echo, map_stars (the count), star_chest ("<region>:<n>"; star_chest_state locked | ready | opened),
## map_stage (stage id; map_state done | open | locked), map_spire ("locked" or the floor), map_spire_fight;
## in the sheets: prep_sheet (stage id), prep_foe (foe id), prep_weak (the schools shown) and prep_unknown (how
## many "?"), prep_power (the word), prep_star (0..2; prep_star_on), prep_first, prep_fight (stage id),
## foe_sheet (foe id), cache_pick (index), hunt_prize (index).

## A cache and a star chest hold the same finds every time they are looked at.
const CACHE_SEED = 1
const CHEST_SEED = 1
const KIND_ICONS = {"battle": "sword", "elite": "skull", "cache": "chest_wood", "boss": "crown", "hunt": "hunt", "rival": "rival", "spire": "spire", "dare": "flame"}
const STAR_CHEST_ICONS = ["chest_wood", "chest_iron", "chest_gold"]
## The strip of a region's backdrop on its card: this part of the 110 x 60 picture, x4.
const STRIP = Rect2(6, 22, 98, 22)
const STRIP_SCALE = 4
## The stars a region's road holds: three for each of its nine battles.
const STARS_MAX = 27

## The region in view ("" = the furthest open) and whether its echo is shown.
static var region_id = ""
static var echo = false


## The furthest region of the road that is open (where the hero is on his way).
static func furthest(rpg: Dictionary) -> Dictionary:
	var out = RpgWorld.regions()[0]
	for r in RpgWorld.regions():
		if region_open(rpg, r, false):
			out = r
	return out


## The place on the road to go to next: the first open stage of the furthest region that is not won yet
## (a cache not taken counts), or null when the whole road is done.
static func next_place(rpg: Dictionary):
	var reg = furthest(rpg)
	for st in stages_of(reg, false):
		if RpgWorld.is_open(rpg, str(st.id)) and not RpgWorld.done(rpg, str(st.id)):
			return {"stage": st, "region": reg}
	return null


## Go to a place of the road as a tap on it would (its prep sheet, or the cache's three finds).
static func go_to(stage_id: String) -> void:
	_tap_node(stage_id, "")


## How many regions were open the last time the map was drawn (-1: not yet in this visit).
static var _open_seen = -1


## A region that has opened since the map was last drawn gets its moment (not at the first drawing of a visit).
static func _greet_new_region(rpg: Dictionary) -> void:
	var open = []
	for r in RpgWorld.regions():
		if region_open(rpg, r, false):
			open.append(r)
	if _open_seen >= 0 and open.size() > _open_seen and not open.is_empty():
		var reg = open[open.size() - 1]
		LootPop.open("New region", "map", [str(reg.name), str(reg.get("blurb", "")), "Teaches: %s" % str(reg.get("teaches", ""))], RpgUi.color("realm"), "unlock")
	_open_seen = open.size()


static func fill(box: VBoxContainer, screen) -> void:
	var rpg = RpgUi.save()
	_greet_new_region(rpg)
	box.add_child(_hunts(rpg))
	box.add_child(_road(rpg, screen))
	box.add_child(_spire(rpg))
	box.add_child(RealmBestiary.card(rpg))
	box.add_child(RealmHelp.link())
	box.add_child(RealmHelp.yard_link())


## Is there something to pick up on the map: a star chest that can be opened, or the hunt's prize?
static func something_waits(rpg: Dictionary) -> bool:
	var today = RpgUi.today()
	var h = rpg.get("hunt", {})
	if str(h.get("date", "")) == today and bool(h.get("won", false)) and RpgLoot.hunt_prize_left(rpg, today):
		return true
	var opened = rpg.get("starChests", {})
	for reg in RpgWorld.regions():
		var stars = RpgWorld.star_count(rpg, str(reg.id))
		for n in RpgDefs.STAR_CHESTS:
			if stars >= int(n) and not bool(opened.get("%s:%d" % [str(reg.id), int(n)], false)):
				return true
	return false


# =============================================================================
# Loot in words, and how it rises
# =============================================================================

## The runes of `after` that `before` did not hold.
static func new_runes(before: Dictionary, after: Dictionary) -> Array:
	var had = {}
	for r in before.get("runes", []):
		if r is Dictionary:
			had[str(r.get("id", ""))] = true
	var out = []
	for r in after.get("runes", []):
		if r is Dictionary and not had.has(str(r.get("id", ""))):
			out.append(r)
	return out


static func _items_words(items) -> Array:
	var out = []
	if items is Array:
		for it in items:
			if not (it is Dictionary):
				continue
			var row = RpgItems.by_id(str(it.get("id", "")))
			out.append("%d %s" % [int(it.get("n", 1)), str(row.name) if row != null else str(it.get("id", ""))])
	return out


## What a reward holds, a line each: {"ore", "items", "runes", "relic", "scroll"} (any may be missing).
static func pack_lines(pack: Dictionary) -> Array:
	var out = []
	if int(pack.get("ore", 0)) > 0:
		out.append("+%s ore" % Xp.fmt_int(int(pack.ore)))
	out.append_array(_items_words(pack.get("items")))
	if pack.get("runes") is Array:
		for r in pack.runes:
			if r is Dictionary:
				out.append("Rune: %s" % RpgGear.rune_words(r))
	var relic = RpgRelics.by_id(str(pack.get("relic", "")))
	if relic != null:
		out.append("Relic: %s" % str(relic.name))
	var scroll = RpgMoves.by_id(str(pack.get("scroll", "")))
	if scroll != null and str(pack.get("scroll", "")) != "":
		out.append("Scroll: %s" % str(scroll.name))
	return out


## One find of a cache or one prize of a hunt as a reward.
static func option_pack(option: Dictionary) -> Dictionary:
	match str(option.get("kind", "")):
		"relic":
			return {"relic": str(option.get("relic", ""))}
		"rune":
			return {"runes": [option.get("rune")]}
		"items":
			return {"items": option.get("items", [])}
		"ore":
			return {"ore": int(option.get("ore", 0))}
	return {}


## Something was opened: sparks from `key`, then the moment itself over the whole screen (LootPop), what was
## in it a line at a time.
static func loot_fx(row: Control, key: Control, lines: Array, title: String = "Loot", icon: String = "chest_wood") -> void:
	var from = key if (key != null and is_instance_valid(key)) else row
	Kit.burst(from, Pal.ACCENT, 26)
	RpgSfx.buzz(2)
	LootPop.open(title, icon, lines)


static func _say(why: String) -> void:
	RpgUi.apply({"ok": false, "why": why})


static func _redraw(screen) -> void:
	if screen != null and is_instance_valid(screen) and screen.has_method("rebuild"):
		screen.rebuild()


static func _finger(b: Control) -> Control:
	if Kit.fingers:
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 40.0)
	return b


## A slot of one width at the end of a row, its content in the middle (so a
## tag, a key and a word all leave the row the same).
static func _end_slot(c: Control, w: int = 72) -> Control:
	var cc = CenterContainer.new()
	cc.custom_minimum_size = Vector2(w, 0)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


## The schools a pack is weak to, as icons after the word.
static func _weak_line(weak: Array, extra: String = "") -> Control:
	var h = Kit.hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Kit.label("Weak to", 11, Pal.MUTED)))
	for s in weak:
		h.add_child(Kit.vcenter(Icons.rect(RpgUi.school_icon(str(s)), 16)))
	var names = []
	for s in weak:
		names.append(str(RpgDefs.SCHOOL_NAMES.get(str(s), str(s))))
	h.add_child(Kit.vcenter(Kit.clip(" and ".join(PackedStringArray(names)) + extra, 11, Pal.MUTED)))
	return h


static func _sprites(wave: Array, px: float) -> Control:
	var h = Kit.hbox(0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(mini(wave.size(), RpgDefs.FOES_MAX)):
		var fv = FoeView.new()
		fv.setup(str(wave[i].get("foe", "")), px, true)
		fv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(fv)
	return h


# =============================================================================
# The hunt and the rival
# =============================================================================

static func _hunts(rpg: Dictionary) -> Control:
	var sec = Kit.section("map_hunts", "HUNTS", "hunt", Pal.DANGER, null, Callable(), 6, 10)
	var today = RpgUi.today()
	var hunt = RpgUi.stage_of({"kind": "hunt", "id": "hunt:" + today})
	if hunt is Dictionary:
		sec.add(_hunt_row(hunt, rpg, today))
	var rival = RpgUi.stage_of({"kind": "rival", "id": ""})
	if rival is Dictionary:
		sec.add(_rival_row(rival, rpg))
	return sec


static func _hunt_row(hunt: Dictionary, rpg: Dictionary, today: String) -> Control:
	var weak = hunt.get("weak", [])
	var col = RpgUi.color(str(weak[0])) if not weak.is_empty() else Pal.DANGER
	var h_rec = rpg.get("hunt", {})
	var won = str(h_rec.get("date", "")) == today and bool(h_rec.get("won", false))
	var prize = won and RpgLoot.hunt_prize_left(rpg, today)
	var what = {"kind": "hunt", "id": str(hunt.id)}
	var row = Kit.row(open_prep.bind(what), col, col, 8, 2, 0.12)
	row.set_meta("map_hunt", today)
	row.set_meta("map_hunt_state", "prize" if prize else ("won" if won else "open"))
	row.set_meta("anchor_id", "map_hunt")
	row.custom_minimum_size.y = 56
	var h = Kit.hbox(8)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var waves = hunt.get("waves", [])
	if not waves.is_empty():
		h.add_child(_sprites(waves[0], 32.0))
	var mid = Kit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = Kit.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(Kit.vcenter(Kit.clip("Daily Hunt", 14, null, true)))
	var rule = RpgWorld.RULES.get(str(hunt.get("rule", "")))
	if rule != null:
		top.add_child(Kit.tag(str(rule.name), Pal.ACCENT2))
	# Days in a row with the hunt won (alive while yesterday's or today's is).
	var streak = RpgWorld.hunt_streak(rpg, today)
	row.set_meta("map_hunt_streak", streak)
	if streak >= 2:
		top.add_child(Kit.tag("%d days" % streak, Pal.ACCENT))
	mid.add_child(top)
	mid.add_child(_weak_line(weak))
	h.add_child(mid)
	if prize:
		var key = Kit.button("Prize", "primary", open_prizes, "sm")
		key.set_meta("map_hunt_prize", today)
		key.set_meta("anchor_id", "map_hunt_prize")
		h.add_child(Kit.vcenter(_end_slot(_finger(key))))
	elif won:
		h.add_child(Kit.vcenter(_end_slot(Kit.tag("WON", Pal.GOOD))))
	else:
		h.add_child(Kit.vcenter(_end_slot(Kit.tag("FIGHT", col))))
	row.add(h)
	return row


static func _rival_row(rival: Dictionary, rpg: Dictionary) -> Control:
	var weak = rival.get("weak", [])
	var rec = rpg.get("rival", {})
	var won = str(rec.get("week", "")) == str(rival.get("week", "")) and bool(rec.get("won", false))
	var what = {"kind": "rival", "id": str(rival.id)}
	var row = Kit.row(open_prep.bind(what), Pal.BOUNTY, Pal.BOUNTY, 8, 2, 0.12)
	row.set_meta("map_rival", str(rival.get("week", "")))
	row.set_meta("map_rival_state", "won" if won else "open")
	row.set_meta("anchor_id", "map_rival")
	row.custom_minimum_size.y = 56
	var h = Kit.hbox(8)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fv = FoeView.new()
	fv.setup(str(rival.get("monster", "")), 40.0, true)
	fv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(fv)
	var mid = Kit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = Kit.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(Kit.tag("RIVAL", Pal.BOUNTY))
	top.add_child(Kit.vcenter(Kit.clip(str(rival.get("name", "")), 14, null, true)))
	mid.add_child(top)
	mid.add_child(_weak_line(weak, " · this week"))
	h.add_child(mid)
	h.add_child(Kit.vcenter(_end_slot(Kit.tag("WON", Pal.GOOD) if won else Kit.tag("FIGHT", Pal.BOUNTY))))
	row.add(h)
	return row


# =============================================================================
# The road
# =============================================================================

static func _first_id(reg: Dictionary, in_echo: bool) -> String:
	return "%s%ds1" % ["e" if in_echo else "r", int(reg.r)]


static func region_open(rpg: Dictionary, reg: Dictionary, in_echo: bool = false) -> bool:
	return RpgWorld.is_open(rpg, _first_id(reg, in_echo))


## The stages of a region as shown: its road, or its echo.
static func stages_of(reg: Dictionary, in_echo: bool) -> Array:
	if not in_echo:
		return reg.stages
	var out = []
	for st in RpgWorld.echo_stages():
		if int(st.get("r", 0)) == int(reg.r):
			out.append(st)
	return out


## The region in view: the chosen one while it is open, else the furthest open.
static func chosen(rpg: Dictionary) -> Dictionary:
	if echo and not RpgWorld.echoes_open(rpg):
		echo = false
	var regs = RpgWorld.regions()
	var pick = RpgWorld.region(region_id) if region_id != "" else null
	if pick != null and region_open(rpg, pick, echo):
		return pick
	# Not chosen by hand (or no longer open): the furthest open one, which moves on by itself when a boss falls.
	region_id = ""
	pick = regs[0]
	for reg in regs:
		if region_open(rpg, reg, echo):
			pick = reg
	return pick


static func _road(rpg: Dictionary, screen) -> Control:
	var reg = chosen(rpg)
	var stars = RpgWorld.star_count(rpg, str(reg.id))
	var count = Kit.hbox(4)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.set_meta("map_stars", stars)
	count.add_child(Kit.vcenter(Icons.rect("star_on", 16)))
	count.add_child(Kit.vcenter(Kit.label("%d/%d" % [stars, STARS_MAX], 12, Pal.TEXT, true)))
	var realm = RpgUi.color("realm")
	var sec = Kit.section("map_road", "ECHOES" if echo else "THE ROAD", "map", realm, count, Callable(), 8, 10)

	var chips = Kit.hbox(4)
	for r in RpgWorld.regions():
		var open = region_open(rpg, r, echo)
		var on = str(r.id) == str(reg.id)
		var b = Kit.chip(str(int(r.r)) if open else " ", on, _pick_region.bind(str(r.id), screen), realm, 14)
		b.custom_minimum_size = Vector2(40, 40 if Kit.fingers else 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("map_region", str(r.id))
		b.set_meta("map_region_state", "chosen" if on else ("open" if open else "locked"))
		b.set_meta("anchor_id", "map_region:" + str(r.id))
		if not open:
			var cc = CenterContainer.new()
			cc.set_anchors_preset(Control.PRESET_FULL_RECT)
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cc.add_child(Icons.rect("lock", 16))
			b.add_child(cc)
			b.modulate.a = 0.55
		chips.add_child(b)
	sec.add(chips)

	if RpgWorld.echoes_open(rpg):
		var road_key = Kit.choice("The road", not echo, _pick_echo.bind(false, screen), realm, 13)
		road_key.set_meta("anchor_id", "map_echo:road")
		var echo_key = Kit.choice("Echoes", echo, _pick_echo.bind(true, screen), realm, 13)
		echo_key.set_meta("map_echo", true)
		echo_key.set_meta("anchor_id", "map_echo:echo")
		sec.add(Kit.choice_track([_finger(road_key), _finger(echo_key)]))

	sec.add(_region_card(reg, rpg, stars))

	# The stages as places on a winding path (RoadMap), the boss alone at its end.
	var road = RoadMap.new()
	road.setup(stages_of(reg, echo), rpg, RealmMap._tap_node, RealmScenes.scene_of(str(reg.get("scene", reg.id))))
	road.set_meta("map_road_path", str(reg.id))
	sec.add(road)
	return sec


static func _pick_region(id: String, screen) -> void:
	var rpg = RpgUi.save()
	var reg = RpgWorld.region(id)
	if reg == null:
		return
	if not region_open(rpg, reg, echo):
		var before = RpgWorld.regions()[maxi(0, int(reg.r) - 2)]
		var boss = RpgFoes.by_id(str(before.boss))
		_say("%s opens when %s falls in %s." % [str(reg.name), str(boss.name) if boss != null else "the boss", str(before.name)])
		return
	if str(chosen(rpg).id) == id:
		return
	# The furthest open region is not a pick: the map goes on following the road.
	region_id = ""
	if str(chosen(rpg).id) != id:
		region_id = id
	_redraw(screen)


static func _pick_echo(on: bool, screen) -> void:
	if echo == on:
		return
	echo = on
	_redraw(screen)


## A strip of the region's backdrop at a whole-number scale, centred, cut off at the sides.
static func _strip(scene_id: String) -> Control:
	var clip = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.custom_minimum_size = Vector2(0, STRIP.size.y * STRIP_SCALE)
	var at = AtlasTexture.new()
	at.atlas = RealmScenes.texture(scene_id)
	at.region = STRIP
	var pic = TextureRect.new()
	pic.texture = at
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size = STRIP.size * STRIP_SCALE
	clip.add_child(pic)
	var place = func():
		pic.size = STRIP.size * STRIP_SCALE
		pic.position = Vector2(floor((clip.size.x - pic.size.x) / 2.0), 0)
	clip.resized.connect(place)
	return clip


static func _region_card(reg: Dictionary, rpg: Dictionary, stars: int) -> Control:
	var realm = RpgUi.color("realm")
	var v = Kit.vbox(6)
	v.set_meta("map_region_card", str(reg.id))
	v.add_child(_strip(str(reg.get("scene", reg.id))))
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Kit.clip(str(reg.name), 17, null, true)))
	head.add_child(Kit.tag("ECHO %d" % int(reg.r) if echo else "REGION %d OF %d" % [int(reg.r), RpgWorld.regions().size()], realm))
	v.add_child(head)
	v.add_child(Kit.muted_para(str(reg.get("blurb", "")), 12))
	var teach = Kit.hbox(6)
	teach.add_child(Kit.tag("TEACHES", Pal.SECOND, false))
	teach.add_child(Kit.vcenter(Kit.clip(str(reg.get("teaches", "")), 12, Pal.TEXT)))
	v.add_child(teach)
	if echo:
		v.add_child(Kit.muted_para("The same road again, far harder, each stage with a rule of its own. Stars and star chests belong to the road.", 12))
		return v
	var chests = Kit.hbox(6)
	chests.set_meta("map_star_chests", str(reg.id))
	var opened = rpg.get("starChests", {})
	for i in range(RpgDefs.STAR_CHESTS.size()):
		var n = int(RpgDefs.STAR_CHESTS[i])
		var key_id = "%s:%d" % [str(reg.id), n]
		var state = "opened" if bool(opened.get(key_id, false)) else ("ready" if stars >= n else "locked")
		var words = "Taken" if state == "opened" else ("Open" if state == "ready" else "%d stars" % n)
		var b = Kit.button(words, "primary" if state == "ready" else "ghost", Callable(), "sm", "check" if state == "opened" else str(STAR_CHEST_ICONS[mini(i, STAR_CHEST_ICONS.size() - 1)]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("star_chest", key_id)
		b.set_meta("star_chest_state", state)
		if state == "ready":
			Fx.shine(b, 3.2, 0.6, 0.5)
		b.set_meta("anchor_id", "star_chest:" + key_id)
		if state != "ready":
			b.modulate.a = 0.7
		b.pressed.connect(_open_star_chest.bind(str(reg.id), n, chests, b))
		chests.add_child(_finger(b))
	v.add_child(chests)
	var dares = _dares_row(reg, rpg)
	if dares != null:
		v.add_child(dares)
	return v


## A region's dares in one row (once a stage of it is won): how many are won, a key to the next one, and the
## dare chest when all are.
static func _dares_row(reg: Dictionary, rpg: Dictionary) -> Variant:
	var prog = RpgWorld.dare_progress(rpg, str(reg.id))
	if int(prog.of) <= 0 or (int(prog.won) == 0 and str(prog.next) == ""):
		return null
	var taken = bool(rpg.get("starChests", {}).get("%s:dare" % str(reg.id), false))
	var all = int(prog.won) >= int(prog.of)
	var row = Kit.hbox(6)
	row.set_meta("map_dares", str(reg.id))
	row.set_meta("map_dares_won", int(prog.won))
	row.add_child(Kit.vcenter(Icons.rect("flame", 16)))
	var words = Kit.clip("Dares %d of %d" % [int(prog.won), int(prog.of)], 13, Pal.TEXT, true)
	row.add_child(Kit.vcenter(words))
	var tail = Kit.clip("" if taken else ("the chest is yours" if all else "all %d: a chest" % int(prog.of)), 11, Pal.MUTED)
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(Kit.vcenter(tail))
	var b
	if all:
		b = Kit.button("Taken" if taken else "Open", "ghost" if taken else "primary", Callable(), "sm", "check" if taken else "chest_gold")
		b.set_meta("dare_chest", str(reg.id))
		b.set_meta("dare_chest_state", "opened" if taken else "ready")
		if taken:
			b.modulate.a = 0.7
		else:
			Fx.shine(b, 3.2, 0.6, 0.5)
		b.pressed.connect(_open_dare_chest.bind(str(reg.id), row, b))
	elif str(prog.next) != "":
		b = Kit.button("Next dare", "secondary", Callable(), "sm", "flame")
		b.set_meta("dare_next", str(prog.next))
		b.pressed.connect(open_prep.bind({"kind": "dare", "id": "dare:" + str(prog.next)}))
	else:
		return row
	b.set_meta("anchor_id", "dares:" + str(reg.id))
	row.add_child(_finger(b))
	return row


static func _open_dare_chest(reg_id: String, row: Control, key: Control) -> void:
	var rpg = RpgUi.save()
	var contents = RpgLoot.dare_chest(reg_id, CHEST_SEED, rpg)
	var res = RpgSave.open_dare_chest(rpg, reg_id, contents)
	if bool(res.get("ok", false)):
		loot_fx(row, key, pack_lines(contents), "Dare chest", "chest_gold")
	RpgUi.apply(res)


static func _open_star_chest(reg_id: String, n: int, row: Control, key: Control) -> void:
	var rpg = RpgUi.save()
	var contents = RpgLoot.star_chest(reg_id, n, CHEST_SEED, rpg)
	var res = RpgSave.open_star_chest(rpg, reg_id, n, contents)
	if bool(res.get("ok", false)):
		loot_fx(row, key, pack_lines(contents), "Star chest", str(STAR_CHEST_ICONS[clampi(int(n / 8.0) - 1, 0, 2)]))
	RpgUi.apply(res)


static func stage_state(rpg: Dictionary, stage_id: String) -> String:
	if RpgWorld.done(rpg, stage_id):
		return "done"
	return "open" if RpgWorld.is_open(rpg, stage_id) else "locked"


static func _tap_node(id: String, before_name: String) -> void:
	var rpg = RpgUi.save()
	var st = RpgWorld.stage(id)
	if not (st is Dictionary):
		return
	if not RpgWorld.is_open(rpg, id):
		_say("Win %s first." % before_name if before_name != "" else "This stage is not open yet.")
		return
	if str(st.kind) == "cache":
		if RpgWorld.done(rpg, id):
			_say("This cache has been taken already.")
		else:
			open_cache(id)
		return
	open_prep({"kind": "echo" if bool(st.get("echo", false)) else "stage", "id": id})


# =============================================================================
# The Spire
# =============================================================================

static func _spire(rpg: Dictionary) -> Control:
	var sec = Kit.section("map_spire", "THE SPIRE", "spire", Pal.SECOND, null, Callable(), 6, 10)
	if not RpgWorld.spire_open(rpg):
		var gate = RpgWorld.regions()[clampi(RpgDefs.SPIRE_AFTER_REGION - 1, 0, RpgWorld.regions().size() - 1)]
		var boss = RpgFoes.by_id(str(gate.boss))
		var row = Kit.row(Callable(), Pal.LINE, null, 8, 2)
		row.set_meta("map_spire", "locked")
		row.custom_minimum_size.y = 48
		var h = Kit.hbox(8)
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		h.add_child(Kit.vcenter(Icons.rect("lock", 24)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(Kit.clip("A tower with no top floor", 14, null, true))
		v.add_child(Kit.clip("Opens when %s falls in %s" % [str(boss.name) if boss != null else "the boss", str(gate.name)], 12, Pal.MUTED))
		h.add_child(v)
		row.add(h)
		sec.add(row)
		return sec
	var best = int(rpg.get("spire", {}).get("best", 0))
	var f = best + 1
	var st = RpgWorld.spire(f)
	var what = {"kind": "spire", "id": str(st.id)}
	var row = Kit.row(open_prep.bind(what), Pal.SECOND, Pal.SECOND, 8, 2, 0.12)
	row.set_meta("map_spire", f)
	row.set_meta("anchor_id", "map_spire")
	row.custom_minimum_size.y = 56
	var h = Kit.hbox(8)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var waves = st.get("waves", [])
	if not waves.is_empty():
		h.add_child(_sprites(waves[0], 32.0))
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip("Floor %d" % f, 15, null, true))
	v.add_child(Kit.clip(("Best: floor %d · " % best if best > 0 else "") + "Power %s" % Xp.fmt_int(int(round(float(st.get("rec", 0.0))))), 12, Pal.MUTED))
	h.add_child(v)
	var key = Kit.button("Fight", "primary", _fight.bind(what, null), "sm")
	key.set_meta("map_spire_fight", f)
	key.set_meta("anchor_id", "map_spire_fight")
	h.add_child(Kit.vcenter(_finger(key)))
	row.add(h)
	sec.add(row)
	sec.add(_blessings_row(rpg))
	return sec


## The Spire's blessings: the ones held as tags, how far the next one is, and a key to pick one that is owed.
static func _blessings_row(rpg: Dictionary) -> Control:
	var held = RpgWorld.blessings_held(rpg)
	var owed = RpgWorld.blessings_owed(rpg)
	var best = int(rpg.get("spire", {}).get("best", 0))
	var v = Kit.vbox(4)
	v.set_meta("map_bless", RpgWorld.blessings_total(rpg))
	v.set_meta("map_bless_owed", owed)
	var top = Kit.hbox(6)
	top.add_child(Kit.vcenter(Icons.rect("sparkle" if Icons.has_icon("sparkle") else "star", 16)))
	top.add_child(Kit.vcenter(Kit.clip("Blessings", 13, Pal.TEXT, true)))
	var to_next = RpgDefs.BLESSING_EVERY - (best % RpgDefs.BLESSING_EVERY)
	var tail = Kit.clip("one is yours to pick" if owed == 1 else ("%d are yours to pick" % owed if owed > 1 else "the next in %d floor%s" % [to_next, "" if to_next == 1 else "s"]), 11, Pal.ACCENT if owed > 0 else Pal.MUTED)
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(Kit.vcenter(tail))
	if owed > 0:
		var b = Kit.button("Pick one", "primary", open_blessings, "sm", "sparkle" if Icons.has_icon("sparkle") else "star")
		b.set_meta("bless_pick", owed)
		b.set_meta("anchor_id", "bless_pick")
		Fx.shine(b, 3.2, 0.6, 0.5)
		top.add_child(_finger(b))
	v.add_child(top)
	if held.is_empty():
		v.add_child(Kit.muted_para("Every %d floors climbed, pick one of three bonuses that hold in the Spire for good." % RpgDefs.BLESSING_EVERY, 11))
	else:
		var flow = Kit.flow(6)
		for id in RpgDefs.BLESSING_IDS:
			if not held.has(id):
				continue
			var row = RpgDefs.BLESSINGS[id]
			var tag = Kit.tag("%s%s" % [str(row.name), " x%d" % int(held[id]) if int(held[id]) > 1 else ""], Pal.SECOND)
			tag.set_meta("bless_held", id)
			tag.tooltip_text = str(row.text)
			flow.add_child(tag)
		v.add_child(flow)
	return v


## The three blessings on offer: one to take.
static func open_blessings() -> void:
	var rpg = RpgUi.save()
	var options = RpgWorld.blessing_options(rpg)
	if options.is_empty():
		_say("No blessing to pick yet")
		return
	var held = RpgWorld.blessings_held(rpg)
	var sh = Kit.sheet("A blessing of the Spire")
	sh.box.set_meta("bless_sheet", true)
	sh.box.add_child(Kit.para("It holds in the Spire for good. The same one can be taken up to %d times." % RpgDefs.BLESSING_STACKS, 13, Pal.TEXT))
	sh.box.add_child(Kit.sub_head("PICK ONE OF THREE", Pal.ACCENT))
	for id in options:
		var row = RpgDefs.BLESSINGS[id]
		var card = Kit.row(Callable(), Pal.SECOND, Pal.SECOND, 10, 2, 0.16)
		card.custom_minimum_size = Vector2(0, 60)
		card.set_meta("bless_option", id)
		var h = Kit.hbox(10)
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(Kit.vcenter(Icons.rect(str(row.icon) if Icons.has_icon(str(row.icon)) else "spire", 32)))
		var v = Kit.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(Kit.clip(str(row.name), 15, null, true))
		v.add_child(Kit.para(str(row.text) + (" (you hold %d)" % int(held.get(id, 0)) if int(held.get(id, 0)) > 0 else ""), 12, Pal.MUTED))
		h.add_child(v)
		card.add(h)
		card.on_tap(_take_blessing.bind(str(id), card, sh))
		sh.box.add_child(card)
	sh.open()


static func _take_blessing(id: String, card: Control, sh) -> void:
	var res = RpgSave.take_blessing(RpgUi.save(), id)
	if bool(res.get("ok", false)):
		var row = RpgDefs.BLESSINGS[id]
		loot_fx(card, card, ["%s: %s" % [str(row.name), str(row.text)]], "Blessing", "spire")
		if sh != null and is_instance_valid(sh):
			sh.close()
	RpgUi.apply(res)


## The build's moves against the foes of a stage: a chip a move, lit and marked WEAK when a foe here is KNOWN
## to be weak to its school (a weakness found before, or one the stage shows). With weaknesses known and no
## move that hits one, a line says so: that is what the Moves page is for.
static func _moves_block(waves: Array, rpg: Dictionary) -> Variant:
	var weak_n = {}
	var any_known = false
	var counted = {}
	for wave in waves:
		for en in wave:
			var fid = str(en.get("foe", ""))
			if counted.has(fid):
				continue
			counted[fid] = true
			for sc in weak_marks(en, rpg).known:
				weak_n[str(sc)] = int(weak_n.get(str(sc), 0)) + 1
				any_known = true
	var flow = Kit.flow(6)
	flow.set_meta("prep_moves", true)
	var hits = 0
	for mid in RpgSave.build_of(rpg).get("moves", []):
		var mv = RpgMoves.by_id(str(mid)) if str(mid) != "" else null
		if mv == null:
			continue
		var school = str(mv.get("school", "plain"))
		var strikes = str(mv.get("kind", "attack")) == "attack" and float(mv.get("power", 0.0)) > 0.0
		var n = int(weak_n.get(school, 0)) if strikes else 0
		var chip = Kit.tag("%s · WEAK" % str(mv.name) if n > 0 else str(mv.name), RpgUi.color(school) if n > 0 else Pal.PANEL2, n > 0)
		chip.set_meta("prep_move", str(mid))
		chip.set_meta("prep_move_weak", n)
		flow.add_child(chip)
		if n > 0:
			hits += 1
	if flow.get_child_count() == 0:
		flow.free()
		return null
	var v = Kit.vbox(4)
	var said = ""
	if hits > 0:
		said = "%d hit%s a weakness here" % [hits, "s" if hits == 1 else ""]
	elif any_known:
		said = "none hits a weakness here"
	v.add_child(Kit.sub_head("YOUR MOVES", RpgUi.color("realm"), Kit.label(said, 11, Pal.GOOD if hits > 0 else Pal.ACCENT2) if said != "" else null))
	v.add_child(flow)
	if hits == 0 and any_known:
		var tip = Kit.muted_para("You know what these foes are weak to, and no move of yours is of that school. Swap one in on the Moves page.", 11)
		tip.set_meta("prep_moves_tip", true)
		v.add_child(tip)
	return v


## The dare of a won stage, as a row of its prep sheet: its rule, how strong its foes are, what the first win
## pays (or that it is won). A tap opens the dare's own sheet.
static func _dare_row(dr: Dictionary, rpg: Dictionary, sh) -> Control:
	var of = str(dr.get("of", ""))
	var won = RpgWorld.dared(rpg, of)
	var rule = RpgWorld.RULES.get(str(dr.get("rule", "")), {})
	var row = Kit.row(_open_dare.bind(of, sh), Pal.ACCENT2, Pal.ACCENT2, 8, 2, 0.12)
	row.set_meta("prep_dare", of)
	row.set_meta("prep_dare_won", won)
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect("flame", 24)))
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip("Dare: %s" % str(rule.get("name", "")), 14, null, true))
	v.add_child(Kit.clip(str(rule.get("text", "")), 12, Pal.TEXT))
	v.add_child(Kit.clip("Foes as strong as you · recommended power %s" % Xp.fmt_int(int(round(float(dr.get("rec", 0.0))))), 11, Pal.MUTED))
	h.add_child(v)
	if won:
		h.add_child(Kit.vcenter(Kit.tag("WON", Pal.GOOD)))
	else:
		h.add_child(Kit.vcenter(RpgUi.ore_pill(int(dr.get("first", {}).get("ore", 0)))))
	row.add(h)
	return row


static func _open_dare(stage_id: String, sh) -> void:
	if sh != null and is_instance_valid(sh):
		sh.close()
	open_prep.call_deferred({"kind": "dare", "id": "dare:" + stage_id})


static func _fight(what: Dictionary, sh) -> void:
	if sh != null and is_instance_valid(sh):
		sh.close()
	RpgUi.fight(what)


# =============================================================================
# The prep sheet
# =============================================================================

## The weak schools of a wave's foe the player knows, and how many are still to find.
static func weak_marks(entry: Dictionary, rpg: Dictionary) -> Dictionary:
	if entry.get("weak") is Array and not entry.weak.is_empty():
		return {"known": entry.weak.duplicate(), "unknown": 0}
	var id = str(entry.get("foe", ""))
	var weak = RpgFoes.weak_of(id)
	var seen = rpg.get("seen", {}).get(RpgFoes.key_of(id), [])
	var known = []
	for s in weak:
		if seen is Array and seen.has(s):
			known.append(s)
	return {"known": known, "unknown": weak.size() - known.size()}


static func _foe_row(entry: Dictionary):
	if entry.get("row") is Dictionary:
		return entry.row
	return RpgFoes.by_id(str(entry.get("foe", "")))


## A foe's role in a word.
static func role_word(foe) -> String:
	if not (foe is Dictionary):
		return ""
	if bool(foe.get("boss", false)):
		return "Boss"
	if bool(foe.get("elite", false)):
		return "Elite"
	return str(foe.get("role", "")).capitalize()


static func _weak_icons(marks: Dictionary) -> Control:
	var h = Kit.hbox(3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in marks.known:
		h.add_child(Kit.vcenter(Icons.rect(RpgUi.school_icon(str(s)), 16)))
	for i in range(int(marks.unknown)):
		var q = Kit.label("?", 13, Pal.MUTED, true)
		q.custom_minimum_size = Vector2(16, 16)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(Kit.vcenter(q))
	return h


## A foe of a wave as a tile: its sprite, name, role, and what is known of its weaknesses.
static func foe_tile(entry: Dictionary, rpg: Dictionary) -> Control:
	var id = str(entry.get("foe", ""))
	var foe = _foe_row(entry)
	var marks = weak_marks(entry, rpg)
	var col = RpgUi.color(str(marks.known[0])) if not marks.known.is_empty() else Pal.LINE
	var tile = Kit.row(open_foe.bind(entry), col, null, 6, 2)
	tile.custom_minimum_size = Vector2(126, 0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.set_meta("prep_foe", id)
	tile.set_meta("prep_weak", marks.known)
	tile.set_meta("prep_unknown", int(marks.unknown))
	var fv = FoeView.new()
	fv.setup(id, 48.0, true)
	fv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc = CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(fv)
	tile.add(cc)
	var name_l = Kit.clip(str(foe.name) if foe is Dictionary else id.capitalize(), 12, null, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add(name_l)
	var role_l = Kit.clip(role_word(foe), 11, Pal.MUTED)
	role_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add(role_l)
	tile.add(_weak_icons(marks))
	return tile


## A foe in full: what kind it is and what its moves ask of the player.
static func open_foe(entry: Dictionary) -> void:
	var id = str(entry.get("foe", ""))
	var foe = _foe_row(entry)
	if not (foe is Dictionary):
		return
	var rpg = RpgUi.save()
	var marks = weak_marks(entry, rpg)
	var sh = Kit.sheet(str(foe.name))
	sh.box.set_meta("foe_sheet", id)
	var top = Kit.hbox(10)
	var fv = FoeView.new()
	fv.setup(id, 96.0, true)
	top.add_child(fv)
	var v = Kit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(Kit.tag(role_word(foe).to_upper(), Pal.DANGER if bool(foe.get("boss", false)) else Pal.SECOND, false))
	if str(foe.get("text", "")) != "":
		v.add_child(Kit.muted_para(str(foe.text), 12))
	top.add_child(v)
	sh.box.add_child(top)
	sh.box.add_child(Kit.sub_head("WEAK TO", Pal.ACCENT2))
	var weak = Kit.hbox(6)
	for s in marks.known:
		weak.add_child(Kit.icon_chip(RpgUi.school_icon(str(s)), str(RpgDefs.SCHOOL_NAMES.get(str(s), str(s))), RpgUi.color(str(s))))
	if int(marks.unknown) > 0:
		weak.add_child(Kit.vcenter(Kit.clip("%d still to find: hit it with other schools" % int(marks.unknown) if not marks.known.is_empty() else "Not known yet: hit it with different schools to find out", 12, Pal.MUTED)))
	sh.box.add_child(weak)
	sh.box.add_child(Kit.sub_head("WHAT IT DOES", Pal.SECOND))
	for w in RpgFoes.words(foe):
		var r = Kit.row(Callable(), Pal.LINE, null, 6, 0)
		r.add(Kit.para(str(w), 13, Pal.TEXT))
		sh.box.add_child(r)
	sh.box.add_child(_finger(Kit.button("Close", "ghost", sh.close, "lg")))
	sh.open()


## How the hero's power stands against a stage's: the word and its colour.
static func power_word(mine: float, rec: float) -> Dictionary:
	var ratio = mine / maxf(1.0, rec)
	if ratio >= 1.15:
		return {"word": "comfortable", "color": Pal.GOOD}
	if ratio >= 0.9:
		return {"word": "even", "color": Pal.SECOND}
	if ratio >= 0.7:
		return {"word": "hard", "color": Pal.ACCENT2}
	return {"word": "very hard", "color": Pal.DANGER}


## What a first win pays, as chips.
static func _first_chips(first: Dictionary) -> Control:
	var f = Kit.flow(6)
	if int(first.get("ore", 0)) > 0:
		f.add_child(RpgUi.ore_pill(int(first.ore)))
	if first.get("items") is Array:
		for it in first.items:
			var row = RpgItems.by_id(str(it.get("id", "")))
			var icon_name = str(row.get("icon", "belt")) if row != null else "belt"
			f.add_child(Kit.icon_chip(icon_name if Icons.has_icon(icon_name) else "belt", "%d %s" % [int(it.get("n", 1)), str(row.name) if row != null else str(it.get("id", ""))], Pal.GOOD))
	var scroll = str(first.get("scroll", ""))
	if scroll != "":
		var mv = RpgMoves.by_id(scroll)
		f.add_child(Kit.icon_chip("scroll", "Scroll: %s" % (str(mv.name) if mv != null else scroll), Pal.READ))
	var relic = str(first.get("relic", ""))
	if relic != "":
		var rl = RpgRelics.by_id(relic)
		f.add_child(Kit.icon_chip("relic", str(rl.name) if rl != null else "A relic", Pal.BOUNTY))
	if bool(first.get("rune", false)):
		f.add_child(Kit.icon_chip("rune", "A rune", Pal.SECOND))
	return f


## The prep sheet of a battle. `what` = {"kind": "stage" | "echo" | "hunt" | "rival" | "spire", "id"}.
static func open_prep(what: Dictionary) -> void:
	var st = RpgUi.stage_of(what)
	if not (st is Dictionary) or st.get("waves", []).is_empty():
		_say("Nothing to fight there")
		return
	var rpg = RpgUi.save()
	var id = str(st.id)
	var kind = str(st.get("kind", "battle"))
	# The fight is a tap away: its music is made ready now, so it is there when the fight opens.
	RpgSfx.tune_ready("boss" if kind == "boss" else "battle", RpgSfx.region_of_scene(str(st.get("scene", "rustyard"))))
	var sh = Kit.sheet(str(st.get("name", "")))
	sh.box.set_meta("prep_sheet", id)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Icons.rect(str(KIND_ICONS.get(kind, "sword")), 24)))
	head.add_child(Kit.para(str(st.get("text", "")), 13, Pal.TEXT))
	sh.box.add_child(head)
	for rule_id in st.get("rules", []):
		var rule = RpgWorld.RULES.get(str(rule_id))
		if rule == null:
			continue
		var rr = Kit.row(Callable(), Pal.ACCENT2, Pal.ACCENT2, 6, 0, 0.12)
		rr.set_meta("prep_rule", str(rule_id))
		var rh = Kit.hbox(8)
		rh.add_child(Kit.tag(str(rule.name), Pal.ACCENT2))
		rh.add_child(Kit.vcenter(Kit.clip(str(rule.text), 12, Pal.TEXT)))
		rr.add(rh)
		sh.box.add_child(rr)

	var waves = RpgWorld.waves_fought(st)
	for w in range(waves.size()):
		sh.box.add_child(Kit.sub_head("THE FOES" if waves.size() == 1 else "WAVE %d OF %d" % [w + 1, waves.size()], Pal.DANGER, Kit.label("Tap one to see what it does", 11, Pal.MUTED) if w == 0 else null))
		var line = Kit.hbox(6)
		for i in range(mini(waves[w].size(), RpgDefs.FOES_MAX)):
			line.add_child(foe_tile(waves[w][i], rpg))
		sh.box.add_child(line)

	var mine = RpgHero.power(RpgUi.hero())
	var rec = float(st.get("rec", 0.0))
	var word = power_word(mine, rec)
	var pr = Kit.row(Callable(), word.color, word.color, 8, 0, 0.12)
	pr.set_meta("prep_power", str(word.word))
	var ph = Kit.hbox(8)
	ph.add_child(Kit.vcenter(Icons.rect("power", 24)))
	var pv = Kit.vbox(0)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(Kit.clip("Your power %s" % Xp.fmt_int(int(round(mine))), 14, null, true))
	pv.add_child(Kit.clip("Recommended %s" % Xp.fmt_int(int(round(rec))), 12, Pal.MUTED))
	ph.add_child(pv)
	ph.add_child(Kit.tag(str(word.word).to_upper(), word.color))
	pr.add(ph)
	sh.box.add_child(pr)

	var objs = st.get("stars", [])
	if not objs.is_empty():
		sh.box.add_child(Kit.sub_head("STARS", Pal.ACCENT))
		var got = rpg.get("stages", {}).get(id, {}).get("stars", [])
		for i in range(mini(3, objs.size())):
			var on = got is Array and i < got.size() and bool(got[i])
			var line = Kit.hbox(8)
			line.set_meta("prep_star", i)
			line.set_meta("prep_star_on", on)
			line.add_child(Kit.vcenter(Icons.rect("star_on" if on else "star_off", 16)))
			line.add_child(Kit.vcenter(Kit.clip(RpgWorld.objective_words(objs[i]), 13, Pal.TEXT if not on else Pal.MUTED)))
			if on:
				line.add_child(Kit.tag("EARNED", Pal.GOOD))
			sh.box.add_child(line)

	var first_left = RpgLoot.is_first(st, rpg)
	if kind == "hunt":
		# The hunt streak: what a win today makes of it, and what that pays.
		var s_next = RpgWorld.hunt_streak_next(rpg, str(st.get("date", "")))
		var s_ore = RpgWorld.hunt_streak_ore(s_next)
		var s_words = ""
		if not first_left:
			s_words = "Hunt streak: %d day%s. Come back tomorrow to keep it." % [s_next, "" if s_next == 1 else "s"]
		elif s_next >= 2:
			s_words = "Hunt streak: a win today makes it %d days in a row and pays %d ore more." % [s_next, s_ore]
		else:
			s_words = "Win the hunt on days in a row: every day after the first adds %d ore, up to %d." % [RpgWorld.HUNT_STREAK_ORE, RpgWorld.HUNT_STREAK_ORE * RpgWorld.HUNT_STREAK_MAX]
		var s_line = Kit.muted_para(s_words, 12)
		s_line.set_meta("prep_streak", s_next)
		sh.box.add_child(s_line)
		sh.box.add_child(Kit.sub_head("FIRST WIN TODAY", Pal.ACCENT))
		var said = Kit.muted_para("Pick one of three prizes: ore, a stack of belt items or a rune." if RpgLoot.hunt_prize_left(rpg, str(st.get("date", ""))) else "Today's prize is picked. A win still pays experience and ore.", 12)
		said.set_meta("prep_first", first_left)
		sh.box.add_child(said)
	else:
		var chips = _first_chips(st.get("first", {}))
		if chips.get_child_count() > 0:
			sh.box.add_child(Kit.sub_head("FIRST WIN" if first_left else "FIRST WIN · TAKEN", Pal.ACCENT))
			chips.set_meta("prep_first", first_left)
			if not first_left:
				chips.modulate.a = 0.5
			sh.box.add_child(chips)
		else:
			chips.free()

	# A stage that is won can be dared: the same place at the player's own level, with a rule.
	if str(what.get("kind", "stage")) == "stage":
		var dr = RpgUi.stage_of({"kind": "dare", "id": "dare:" + id})
		if dr is Dictionary:
			sh.box.add_child(_dare_row(dr, rpg, sh))

	var my_moves = _moves_block(waves, rpg)
	if my_moves != null:
		sh.box.add_child(my_moves)

	var go = Kit.button("Fight", "primary", _fight.bind({"kind": str(what.get("kind", "stage")), "id": id}, sh), "lg", "sword")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.set_meta("prep_fight", id)
	sh.box.add_child(_finger(go))
	sh.open()


# =============================================================================
# A cache, and the hunt's prizes
# =============================================================================

## One find as a big pick key.
static func _option_card(option: Dictionary, tap: Callable) -> Control:
	var icon_name = "ore"
	var title = ""
	var sub = ""
	var col = RpgUi.color("realm")
	match str(option.get("kind", "")):
		"relic":
			var rl = RpgRelics.by_id(str(option.get("relic", "")))
			icon_name = str(rl.get("icon", "relic")) if rl != null else "relic"
			title = "Relic: %s" % (str(rl.name) if rl != null else "?")
			sub = str(rl.get("text", "")) if rl != null else ""
			col = RpgUi.rarity_color(str(rl.get("rarity", "rare"))) if rl != null else Pal.BOUNTY
		"rune":
			var rune = option.get("rune", {})
			icon_name = "rune"
			title = "Rune (%s)" % str(rune.get("rarity", "common"))
			sub = "%s. Goes into a piece of gear." % RpgGear.rune_words(rune)
			col = RpgUi.rarity_color(str(rune.get("rarity", "common")))
		"items":
			var words = _items_words(option.get("items"))
			var first = RpgItems.by_id(str(option.items[0].get("id", ""))) if (option.get("items") is Array and not option.items.is_empty()) else null
			icon_name = str(first.get("icon", "belt")) if first != null else "belt"
			title = "Supplies for the belt"
			sub = ", ".join(PackedStringArray(words))
			col = Pal.GOOD
		"ore":
			icon_name = "ore"
			title = "%s ore" % Xp.fmt_int(int(option.get("ore", 0)))
			sub = "For gear upgrades and the camp shop."
	var card = Kit.row(tap, col, col, 10, 2, 0.16)
	card.custom_minimum_size = Vector2(0, 60)
	var h = Kit.hbox(10)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect(icon_name if Icons.has_icon(icon_name) else "gift", 32)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip(title, 15, null, true))
	if sub != "":
		v.add_child(Kit.para(sub, 12, Pal.MUTED))
	h.add_child(v)
	card.add(h)
	return card


## A cache node: three finds, one to take.
static func open_cache(stage_id: String) -> void:
	var st = RpgWorld.stage(stage_id)
	if not (st is Dictionary):
		return
	var rpg = RpgUi.save()
	var sh = Kit.sheet(str(st.get("name", "A cache")))
	sh.box.set_meta("cache_sheet", stage_id)
	sh.box.add_child(Kit.para(str(st.get("text", "")), 13, Pal.TEXT))
	sh.box.add_child(Kit.sub_head("PICK ONE OF THREE", Pal.ACCENT))
	var options = RpgLoot.cache(stage_id, rpg, CACHE_SEED)
	for i in range(options.size()):
		var card = _option_card(options[i], Callable())
		card.set_meta("cache_pick", i)
		card.on_tap(_take_cache.bind(stage_id, options[i], card, sh))
		sh.box.add_child(card)
	sh.open()


static func _take_cache(stage_id: String, option: Dictionary, card: Control, sh) -> void:
	var res = RpgSave.take_cache(RpgUi.save(), stage_id, option)
	if bool(res.get("ok", false)):
		loot_fx(card, card, pack_lines(option_pack(option)), "Cache", "chest_iron")
		if sh != null and is_instance_valid(sh):
			sh.close()
	RpgUi.apply(res)


## The hunt's prizes after the day's first win: three, one to take.
static func open_prizes() -> void:
	var today = RpgUi.today()
	var hunt = RpgUi.stage_of({"kind": "hunt", "id": "hunt:" + today})
	if not (hunt is Dictionary):
		return
	var sh = Kit.sheet("The hunt's prize")
	sh.box.set_meta("prize_sheet", today)
	sh.box.add_child(Kit.para("The pack is beaten. Take one thing home.", 13, Pal.TEXT))
	sh.box.add_child(Kit.sub_head("PICK ONE OF THREE", Pal.ACCENT))
	var options = hunt.get("prizes", [])
	for i in range(options.size()):
		var card = _option_card(options[i], Callable())
		card.set_meta("hunt_prize", i)
		card.on_tap(_take_prize.bind(today, options[i], card, sh))
		sh.box.add_child(card)
	sh.open()


static func _take_prize(date: String, option: Dictionary, card: Control, sh) -> void:
	var res = RpgSave.take_hunt_prize(RpgUi.save(), date, option)
	if bool(res.get("ok", false)):
		loot_fx(card, card, pack_lines(option_pack(option)), "Hunt prize", "hunt")
		if sh != null and is_instance_valid(sh):
			sh.close()
	RpgUi.apply(res)
