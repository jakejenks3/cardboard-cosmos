class_name RealmHero
extends RefCounted
## The Hero page of the Realm (RPG_PLAN.md 10.1): what the training has made of
## the hero. It only READS (the stat sheet, the boosts, the hero as a battle
## unit); nothing here changes the save.
##
##   BODY        the hero with the six body stats around it, three a side: each a
##               tile (icon, name, the value to one decimal, the change this
##               week, a thin bar to the next whole point)
##   TRAITS      the six traits as rows with the same parts
##   IN A FIGHT  Power, HP, Defence, Speed, Crit, Dodge, Energy: a tile each with
##               one line on where the number comes from
##   BOOSTS      every boost in full: name, what it does, why, until when
## A tap on a stat opens its sheet: what it does in a fight, what it is made
## of, what raises it, and which skill tiers it has reached.
##
## Metas for tests: sections "realm_body", "realm_traits", "realm_fight",
## "realm_boosts"; "hero_stat" = stat id on every stat tile and row (its value
## in "hero_value", a gain line in "hero_gain"); "fight_num" = hp | def | spd |
## crit | dodge | energy | power; "hero_boost" = boost id; the stat sheet's box
## has "hero_stat_sheet" = stat id and its tier rows "stat_tier" = tier.


static func fill(box: VBoxContainer, _screen) -> void:
	var sheet = RpgUi.sheet()
	box.add_child(_body(sheet))
	var opens = _unlocks(sheet)
	if opens != null:
		box.add_child(opens)
	box.add_child(_traits(sheet))
	box.add_child(_fight())
	box.add_child(_boosts())
	box.add_child(_feats(_screen))
	box.add_child(_journey())


## How many rows "TRAINING OPENS NEXT" shows.
const UNLOCK_ROWS = 3
## What raises a stat in real life, in a few words.
const STAT_FROM = {"chest": "presses, push-ups, flyes", "shoulders": "overhead presses and raises", "arms": "curls and extensions",
	"back": "rows and pull-ups", "core": "core work", "legs": "squats, deadlifts, lunges", "speed": "faster runs", "endurance": "longer runs",
	"grip": "climbing and hangs", "mind": "pages read", "flow": "physical therapy", "grit": "showing up, week after week"}

## TRAINING OPENS NEXT: the real stats nearest to a mark that opens skills (RpgSkills.next_unlocks), each with
## how far it is, what waits behind it, and what raises it. Null when nothing is left to open.
static func _unlocks(sheet: Dictionary) -> Variant:
	var rows = RpgSkills.next_unlocks(RpgUi.save(), sheet)
	if rows.is_empty():
		return null
	var sec = Kit.section("realm_unlocks", "TRAINING OPENS NEXT", "muscle", Pal.GOOD, null, Callable(), 6, 10)
	for i in range(mini(UNLOCK_ROWS, rows.size())):
		var r = rows[i]
		var stat = str(r.stat)
		var col = stat_color(stat)
		var st = sheet.get("stats", {}).get(stat)
		var row = Kit.row(open_stat.bind(st) if st is Dictionary else Callable(), col, col, 8, 2, 0.1)
		row.set_meta("unlock_row", stat)
		row.set_meta("unlock_need", int(r.need))
		var head = Kit.hbox(6)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon = str(RpgDefs.STAT_ICONS.get(stat, "star"))
		head.add_child(Kit.vcenter(Icons.rect(icon if Icons.has_icon(icon) else "star", 16)))
		var title = Kit.clip("%s %d" % [str(r.name), int(floor(float(r.have)))], 14, null, true)
		head.add_child(Kit.vcenter(title))
		head.add_child(Kit.vcenter(Kit.label("at %d:" % int(r.need), 12, Pal.MUTED, true)))
		var n = r.names.size()
		var what = Kit.clip("%s%s" % [str(r.names[0]), " and %d more" % (n - 1) if n > 1 else ""], 13, col, true)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(Kit.vcenter(what))
		row.add(head)
		row.add(Kit.bar(clampf(float(r.have) / maxf(1.0, float(r.need)), 0.0, 1.0), col, 6))
		row.add(Kit.clip("%s to go · raised by %s" % [one(float(r.gap)), str(STAT_FROM.get(stat, "training"))], 11, Pal.MUTED))
		sec.add(row)
	sec.add(Kit.muted_para("Your real training opens skills. A skill may also ask for a fighter level and the tier under it.", 11))
	return sec


## The colour of a stat: its school's (Endurance: the Realm's own).
static func stat_color(id: String) -> Color:
	return RpgUi.color(str(RpgDefs.STAT_SCHOOL.get(id, "realm")))


## A stat to one decimal, never rounded up to a point it has not reached.
static func one(raw: float) -> String:
	return TTUtil.to_fixed1(floor(raw * 10.0 + 0.0001) / 10.0)


static func _gain(st: Dictionary) -> float:
	return float(st.get("raw", 1.0)) - float(st.get("was", st.get("raw", 1.0)))


## The thin bar to the next whole point.
static func _next_bar(raw: float, col: Color, h: int) -> Control:
	var b = Kit.bar(raw - floor(raw), col, h)
	b.set_meta("hero_next", raw - floor(raw))
	return b


# ---------------------------------------------------------------------------
# BODY
# ---------------------------------------------------------------------------

static func _body(sheet: Dictionary) -> Control:
	var col = RpgUi.color("push")
	var might = Kit.tag("Might %s" % one(float(sheet.get("might", 1.0))), col)
	var sec = Kit.section("realm_body", "BODY", "muscle", col, might, Callable(), 8, 10)
	var ids = sheet.get("body", RpgDefs.BODY)
	var row = Kit.hbox(6)
	var left = Kit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right = Kit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(ids.size()):
		var st = sheet.get("stats", {}).get(ids[i])
		if st == null:
			continue
		(left if i < 3 else right).add_child(_stat_tile(st))
	row.add_child(left)
	row.add_child(_figure())
	row.add_child(right)
	sec.add(row)
	sec.add(Kit.muted_para("Built by your lifting. A stat never goes down. Tap one to see what it is made of.", 12))
	return sec


## The hero in the Realm's gear, on a little stage between the two columns.
static func _figure() -> Control:
	var well = PanelContainer.new()
	well.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": null, "lip": 0, "inset": true, "pad_h": 4, "pad_v": 4}))
	well.set_meta("hero_figure", true)
	var stage = Stage.new()
	stage.setup(RpgUi.color("realm"), 2)
	well.add_child(stage)
	# The hero at x3: he is what this page is about. His picture is wider than the well, so it stands in a
	# frame that cuts it at the well's sides (only empty margin, and the tip of a wide piece of gear) and
	# never makes the well wider than it was.
	var frame = Control.new()
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(128, 214)
	var hv = hero_view(3)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(hv)
	var place = func():
		if not is_instance_valid(hv) or not is_instance_valid(frame):
			return
		hv.size = hv.get_combined_minimum_size()
		hv.position = Vector2(floor((frame.size.x - hv.size.x) / 2.0), floor(frame.size.y - hv.size.y))
	frame.resized.connect(place)
	hv.minimum_size_changed.connect(place)
	hv.ready.connect(place, CONNECT_ONE_SHOT)
	well.add_child(frame)
	return well


## The hero in the Realm's gear at a whole-number scale, standing on the floor
## of the stage it is put on. (A save with no hero made yet draws none.)
static func hero_view(art_scale: int) -> HeroView:
	var look = RpgUi.hero_look()
	var hero = HeroView.new()
	hero.min_scale = art_scale
	if look.get("state") is Dictionary and look.get("profile") is Dictionary and look.profile.has("skin"):
		hero.setup(look.state, look.profile, look.get("loadout", {}), null, false)
	else:
		hero._show_scene = false
		hero._update_min_size()
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.size_flags_vertical = Control.SIZE_SHRINK_END
	return hero


## One body stat beside the hero.
static func _stat_tile(st: Dictionary) -> Control:
	var id = str(st.id)
	var col = stat_color(id)
	var raw = float(st.get("raw", 1.0))
	var t = Kit.row(open_stat.bind(st), col, col, 6, 2)
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.set_meta("hero_stat", id)
	t.set_meta("anchor_id", "hero_stat:" + id)
	var head = Kit.hbox(4)
	head.add_child(Kit.vcenter(Icons.rect(str(RpgDefs.STAT_ICONS.get(id, "star")), 16)))
	head.add_child(Kit.vcenter(Kit.clip(str(st.get("name", id.capitalize())), 12, null, true)))
	t.add(head)
	## (the number in the stat's colour made deep enough to read on its tinted slip; the bar keeps the colour)
	var val = Kit.label(one(raw), 22, RpgUi.ink_on(col, RpgUi.slip_of(col)), true)
	val.set_meta("hero_value", raw)
	t.add(val)
	var gain = _gain(st)
	if gain >= 0.05:
		var up = Kit.clip("+%s this week" % TTUtil.to_fixed1(gain), 11, Pal.GOOD, true)
		up.set_meta("hero_gain", id)
		t.add(up)
	else:
		t.add(Kit.clip("steady this week", 11, Pal.MUTED))
	t.add(_next_bar(raw, col, 6))
	Kit.passthrough(t.box)
	return t


# ---------------------------------------------------------------------------
# TRAITS
# ---------------------------------------------------------------------------

static func _traits(sheet: Dictionary) -> Control:
	var sec = Kit.section("realm_traits", "TRAITS", "star", RpgUi.color("realm"), null, Callable(), 6, 10)
	for id in sheet.get("traits", RpgDefs.TRAITS):
		var st = sheet.get("stats", {}).get(id)
		if st != null:
			sec.add(_trait_row(st))
	sec.add(Kit.muted_para("Built by running, climbing, reading, physical therapy and showing up.", 12))
	return sec


static func _trait_row(st: Dictionary) -> Control:
	var id = str(st.id)
	var col = stat_color(id)
	var raw = float(st.get("raw", 1.0))
	var r = Kit.row(open_stat.bind(st), col, col, 8, 4)
	r.set_meta("hero_stat", id)
	r.set_meta("anchor_id", "hero_stat:" + id)
	var top = Kit.hbox(8)
	top.add_child(Kit.vcenter(Icons.rect(str(RpgDefs.STAT_ICONS.get(id, "star")), 16)))
	top.add_child(Kit.vcenter(Kit.clip(str(st.get("name", id.capitalize())), 15, null, true)))
	var gain = _gain(st)
	if gain >= 0.05:
		var up = Kit.tag("+%s this week" % TTUtil.to_fixed1(gain), Pal.GOOD, true, 10)
		up.set_meta("hero_gain", id)
		top.add_child(up)
	## (deep enough to read on its tinted slip, as the body tiles' numbers)
	var val = Kit.label(one(raw), 20, RpgUi.ink_on(col, RpgUi.slip_of(col)), true)
	val.custom_minimum_size = Vector2(50, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.set_meta("hero_value", raw)
	top.add_child(Kit.vcenter(val))
	r.add(top)
	r.add(_next_bar(raw, col, 8))
	r.add(Kit.clip(str(RpgDefs.STAT_DOES.get(id, "")), 12, Pal.MUTED))
	Kit.passthrough(r.box)
	return r


# ---------------------------------------------------------------------------
# A stat in full
# ---------------------------------------------------------------------------

## The stat's sheet: what it does, what it is made of, what raises it, and the
## skill tiers it has reached.
static func open_stat(st: Dictionary) -> void:
	var id = str(st.id)
	var col = stat_color(id)
	var raw = float(st.get("raw", 1.0))
	var stat_name = str(st.get("name", id.capitalize()))
	var sh = Kit.sheet("%s %s" % [stat_name, one(raw)])
	sh.box.set_meta("hero_stat_sheet", id)
	var prog = Kit.hbox(8)
	prog.add_child(_next_bar(raw, col, 12))
	var to_go = Kit.label("%d%% to %d" % [int(floor((raw - floor(raw)) * 100.0)), int(floor(raw)) + 1], 12, Pal.MUTED, true)
	prog.add_child(Kit.vcenter(to_go))
	sh.box.add_child(prog)
	var gain = _gain(st)
	if gain >= 0.05:
		sh.box.add_child(Kit.tag("+%s this week" % TTUtil.to_fixed1(gain), Pal.GOOD, true, 11))
	var does = Kit.row(Callable(), col, col, 8, 2)
	does.add(Kit.label("IN A FIGHT", 11, Pal.MUTED, true))
	does.add(Kit.para("%s." % str(RpgDefs.STAT_DOES.get(id, "")), 14, Pal.TEXT, true))
	sh.box.add_child(does)
	sh.box.add_child(Kit.sub_head("MADE OF", col))
	var lines = st.get("lines", [])
	if lines.is_empty():
		sh.box.add_child(RpgUi.page_note("stat_lines", "Nothing in your log feeds it yet."))
	for line in lines:
		sh.box.add_child(Kit.para(str(line), 13, Pal.TEXT))
	var next = str(st.get("next", ""))
	if next != "":
		sh.box.add_child(Kit.sub_head("WHAT RAISES IT", col))
		sh.box.add_child(Kit.para(next, 13, Pal.TEXT))
	sh.box.add_child(Kit.sub_head("SKILL TIERS", col))
	var tiers = _tiers_asking(id)
	if tiers.is_empty():
		sh.box.add_child(RpgUi.page_note("stat_tiers", "No skill asks for %s. It works in every fight instead." % stat_name))
	var v = int(floor(raw))
	for tier in tiers:
		var need = int(RpgDefs.REQ[tier])
		var met = v >= need
		var row = Kit.hbox(8)
		row.set_meta("stat_tier", tier)
		row.set_meta("stat_tier_met", met)
		row.add_child(Kit.tick_box(met, 20))
		row.add_child(Kit.vcenter(Kit.clip("Tier %d skills open at %d" % [tier, need], 13, Pal.TEXT if met else Pal.MUTED, met)))
		row.add_child(Kit.vcenter(Kit.label("reached" if met else "%d to go" % (need - v), 12, Pal.GOOD if met else Pal.ACCENT2, true)))
		sh.box.add_child(row)
	sh.box.add_child(RpgUi.page_key("Close", "ghost", sh.close, "stat_close", "lg"))
	sh.open()


## The board tiers that have a skill asking for this stat, lowest first.
static func _tiers_asking(stat_id: String) -> Array:
	var out = []
	for n in RpgSkills.all():
		if str(n.get("stat", "")) == stat_id and not out.has(int(n.tier)):
			out.append(int(n.tier))
	out.sort()
	return out


# ---------------------------------------------------------------------------
# IN A FIGHT
# ---------------------------------------------------------------------------

static func _pct(x: float) -> String:
	return "%d%%" % int(round(x * 100.0))


static func _fight() -> Control:
	var n = RpgHero.numbers(RpgUi.hero())
	var sec = Kit.section("realm_fight", "IN A FIGHT", "sword", RpgUi.color("realm"), null, Callable(), 6, 10)
	sec.add(_num_tile("power", "Power", "power", Pal.ACCENT, Xp.fmt_int(int(round(float(n.get("power", 0.0))))),
		"Everything below in one number. Compare it with the power a stage recommends."))
	var grid = Kit.grid(2, 6)
	grid.add_child(_num_tile("hp", "HP", "heart", Pal.DANGER, Xp.fmt_int(int(n.get("hp", 1))),
		"Endurance, legs and core, and %d more a fighter level." % int(RpgDefs.HP_LEVEL)))
	grid.add_child(_num_tile("def", "Defence", "shield", RpgUi.color("legs"), one(float(n.get("def", 0.0))),
		"Takes %s off every hit. Core, might and armor." % _pct(float(n.get("blocks", 0.0)))))
	grid.add_child(_num_tile("spd", "Speed", "sch_speed", RpgUi.color("speed"), one(float(n.get("spd", 0.0))),
		"Who acts first and how often. The Speed stat and your boots."))
	grid.add_child(_num_tile("crit", "Crit", "target", RpgUi.color("grip"), _pct(float(n.get("crit", 0.0))),
		"The chance of a hit for %s%%. Grip and gear." % TTUtil.num_str(RpgDefs.CRIT_MULT * 100.0)))
	grid.add_child(_num_tile("dodge", "Dodge", "wind", RpgUi.color("flow"), _pct(float(n.get("dodge", 0.0))),
		"The chance a hit misses you. Flow, from physical therapy."))
	grid.add_child(_num_tile("energy", "Energy", "energy", RpgUi.color("grit"), str(int(n.get("en_max", 0))),
		"Moves cost it. A fight starts with %d. Endurance makes the pool bigger." % int(n.get("en_start", 0))))
	sec.add(grid)
	return sec


static func _num_tile(id: String, title: String, icon: String, col: Color, value: String, from: String) -> Control:
	var t = Kit.row(Callable(), col, col, 8, 2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.set_meta("fight_num", id)
	var head = Kit.hbox(6)
	head.add_child(Kit.vcenter(Icons.rect(icon, 16)))
	head.add_child(Kit.vcenter(Kit.clip(title, 12, Pal.MUTED, true)))
	## (deep enough to read on its tinted slip, as the body tiles' numbers)
	var val = Kit.label(value, 22, RpgUi.ink_on(col, RpgUi.slip_of(col)), true)
	val.set_meta("fight_value", value)
	head.add_child(Kit.vcenter(val))
	t.add(head)
	t.add(Kit.muted_para(from, 11))
	return t


# ---------------------------------------------------------------------------
# FEATS: the long goals (RpgFeats), each step claimed for ore
# ---------------------------------------------------------------------------

static func _feats(screen) -> Control:
	var rpg = RpgUi.save()
	var rows = RpgFeats.rows(rpg, RpgUi.sheet())
	var tally = RpgFeats.tally(rpg)
	var count = Kit.label("%d of %d" % [int(tally.claimed), int(tally.of)], 12, Pal.TEXT, true)
	var sec = Kit.section("realm_feats", "FEATS", "trophy" if Icons.has_icon("trophy") else "star", Pal.ACCENT, count, Callable(), 6, 10)
	sec.set_meta("feats_ready", RpgFeats.ready(rpg, RpgUi.sheet()))
	for r in rows:
		var ready = bool(r.ready)
		var done = bool(r.done)
		var col = Pal.GOOD if done else (Pal.ACCENT if ready else Pal.LINE)
		var row = Kit.row(Callable(), col, col if (ready or done) else null, 7, 2, 0.14)
		row.set_meta("feat", str(r.id))
		row.set_meta("feat_state", "done" if done else ("ready" if ready else "open"))
		var h = Kit.hbox(8)
		h.add_child(Kit.vcenter(Icons.rect(str(r.icon) if Icons.has_icon(str(r.icon)) else "star", 24)))
		var v = Kit.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(Kit.clip(str(r.name), 13, null if not done else Pal.MUTED, true))
		v.add_child(Kit.clip(str(r.words) if not done else "Every step claimed", 11, Pal.MUTED))
		if not done:
			var line = Kit.hbox(6)
			var bar = Kit.bar(float(int(r.have)) / float(maxi(1, int(r.need))), col if ready else Pal.SECOND, 6)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(Kit.vcenter(bar))
			line.add_child(Kit.vcenter(Kit.label("%s / %s" % [Xp.fmt_int(int(r.have)), Xp.fmt_int(int(r.need))], 11, Pal.MUTED, true)))
			v.add_child(line)
		h.add_child(v)
		# The key's place is there whatever the state, so the rows are of one shape.
		var slot = Control.new()
		slot.custom_minimum_size = Vector2(92, 40 if Kit.fingers else 34)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if ready:
			var key = Kit.button("+%s ore" % Xp.fmt_int(int(r.ore)), "primary", Callable(), "sm")
			key.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			key.set_meta("feat_claim", str(r.id))
			key.set_meta("anchor_id", "feat_claim:" + str(r.id))
			key.pressed.connect(RealmHero._claim_feat.bind(str(r.id), key))
			slot.add_child(key)
			Fx.shine(key, 3.2, 0.6, 0.5)
		elif not done:
			var pay = RpgUi.ore_pill(int(r.ore))
			pay.modulate.a = 0.6
			var cc = CenterContainer.new()
			cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cc.add_child(pay)
			slot.add_child(cc)
		else:
			var tick = CenterContainer.new()
			tick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tick.add_child(Kit.tick_box(true))
			slot.add_child(tick)
		h.add_child(slot)
		row.add(h)
		sec.add(row)
	sec.add(Kit.muted_para("Long goals. Each step pays ore once; the next one is harder.", 11))
	return sec


static func _claim_feat(id: String, at) -> void:
	var res = RpgSave.claim_feat(RpgUi.save(), id, RpgUi.sheet())
	if bool(res.get("ok", false)) and at is Control and is_instance_valid(at):
		Kit.burst(at, Pal.ACCENT, 22)
		Kit.floater(at, "+%s ORE" % Xp.fmt_int(int(res.get("ore", 0))), Pal.ACCENT)
		RpgSfx.play("first_clear")
		RpgSfx.buzz(2)
	RpgUi.apply(res, "%s claimed" % str(res.get("name", "Feat")) if bool(res.get("ok", false)) else "")


# ---------------------------------------------------------------------------
# THE JOURNEY SO FAR: how much of the Realm has been won, counted from the save
# ---------------------------------------------------------------------------

## {"stars", "stars_of", "stages", "stages_of", "bosses", "bosses_of", "foes", "foes_of", "relics", "relics_of", "spire"}.
static func journey(rpg: Dictionary) -> Dictionary:
	var out = {"stars": 0, "stars_of": 0, "stages": 0, "stages_of": 0, "bosses": 0, "bosses_of": 0}
	for st in RpgWorld.all_stages():
		if bool(st.get("echo", false)):
			continue
		var boss = str(st.get("kind", "")) == "boss"
		out.stages_of += 1
		if boss:
			out.bosses_of += 1
		if RpgWorld.done(rpg, str(st.id)):
			out.stages += 1
			if boss:
				out.bosses += 1
	for reg in RpgWorld.regions():
		out.stars += RpgWorld.star_count(rpg, str(reg.id))
		out.stars_of += RealmMap.STARS_MAX
	out["foes"] = RealmBestiary.met(rpg).size()
	out["foes_of"] = RealmBestiary.total()
	var have = rpg.get("relics", {})
	out["relics"] = have.size() if have is Dictionary else 0
	out["relics_of"] = RpgRelics.all().size()
	var sp = rpg.get("spire", {})
	out["spire"] = int(sp.get("best", 0)) if sp is Dictionary else 0
	var tally = rpg.get("tally", {})
	out["best_hit"] = int(tally.get("best_hit", 0)) if tally is Dictionary else 0
	out["perfect"] = int(tally.get("perfect", 0)) if tally is Dictionary else 0
	out["dares"] = RpgWorld.dare_count(rpg)
	out["dares_of"] = 0
	for reg in RpgWorld.regions():
		out.dares_of += int(RpgWorld.dare_progress(rpg, str(reg.id)).of)
	out["mastery"] = int(RpgFeats.counts(rpg).get("mastery", 0))
	return out


static func _journey() -> Control:
	var j = journey(RpgUi.save())
	var sec = Kit.section("realm_journey", "THE JOURNEY SO FAR", "map", RpgUi.color("realm"), null, Callable(), 6, 10)
	var grid = Kit.grid(2, 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rows = [
		["stars", "Stars", "star_on", Pal.ACCENT, "%d / %d" % [int(j.stars), int(j.stars_of)], float(j.stars) / float(maxi(1, int(j.stars_of)))],
		["stages", "Stages won", "map", RpgUi.color("realm"), "%d / %d" % [int(j.stages), int(j.stages_of)], float(j.stages) / float(maxi(1, int(j.stages_of)))],
		["bosses", "Bosses felled", "crown", Pal.DANGER, "%d / %d" % [int(j.bosses), int(j.bosses_of)], float(j.bosses) / float(maxi(1, int(j.bosses_of)))],
		["foes", "Foes met", "skull", Pal.BOUNTY, "%d / %d" % [int(j.foes), int(j.foes_of)], float(j.foes) / float(maxi(1, int(j.foes_of)))],
		["relics", "Relics found", "relic", RpgUi.color("grit"), "%d / %d" % [int(j.relics), int(j.relics_of)], float(j.relics) / float(maxi(1, int(j.relics_of)))],
		["spire", "The Spire", "spire", Pal.SECOND, ("Floor %d" % int(j.spire)) if int(j.spire) > 0 else "Not climbed", -1.0],
		["hit", "Hardest hit", "power", Pal.ACCENT, Xp.fmt_int(int(j.best_hit)) if int(j.best_hit) > 0 else "None yet", -1.0],
		["perfect", "Perfect guards", "guard", Pal.SECOND, Xp.fmt_int(int(j.perfect)), -1.0],
		["dares", "Dares won", "flame", Pal.ACCENT2, "%d / %d" % [int(j.dares), int(j.dares_of)], float(j.dares) / float(maxi(1, int(j.dares_of)))],
		["mastery", "Mastery stars", "star_on", Pal.ACCENT, Xp.fmt_int(int(j.mastery)), -1.0],
	]
	for r in rows:
		var t = Kit.row(Callable(), r[3], r[3], 8, 2)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.set_meta("journey_num", str(r[0]))
		var head = Kit.hbox(6)
		head.add_child(Kit.vcenter(Icons.rect(str(r[2]) if Icons.has_icon(str(r[2])) else "star", 16)))
		head.add_child(Kit.vcenter(Kit.clip(str(r[1]), 12, Pal.MUTED, true)))
		t.add(head)
		## (the number deep enough to read on its tinted slip; the bar keeps the colour)
		var val = Kit.label(str(r[4]), 18, RpgUi.ink_on(r[3], RpgUi.slip_of(r[3])), true)
		val.set_meta("journey_value", str(r[4]))
		t.add(val)
		if float(r[5]) >= 0.0:
			t.add(Kit.bar(float(r[5]), r[3], 6))
		grid.add_child(t)
	sec.add(grid)
	sec.add(Kit.muted_para("Eight regions, a boss at the end of each, then their echoes and the Spire.", 11))
	return sec


# ---------------------------------------------------------------------------
# BOOSTS
# ---------------------------------------------------------------------------

static func _boosts() -> Control:
	var boosts = RpgUi.boosts()
	var count = Kit.label("%d in force" % boosts.size(), 12, Pal.TEXT, true) if not boosts.is_empty() else null
	var sec = Kit.section("realm_boosts", "BOOSTS", "bolt", Pal.ACCENT, count, Callable(), 6, 10)
	if boosts.is_empty():
		sec.add(RpgUi.page_note("boosts_none", "None right now. What you train today boosts the hero today and tomorrow: a pump from lifting, a second wind from a run, chalked hands from a climb, a sharp mind from 10 pages. A rest day earns one too."))
		return sec
	var today = RpgUi.today()
	for b in boosts:
		var school = str(b.get("school", ""))
		var col = RpgUi.color(school if school != "" else "realm")
		var row = Kit.row(Callable(), col, col, 8, 4)
		row.set_meta("hero_boost", str(b.get("id", "")))
		var top = Kit.hbox(8)
		var icon_name = str(b.get("icon", "bolt"))
		top.add_child(Kit.vcenter(Icons.rect(icon_name if Icons.has_icon(icon_name) else "bolt", 16)))
		top.add_child(Kit.vcenter(Kit.clip(str(b.get("name", "")), 15, null, true)))
		var until = str(b.get("until", ""))
		top.add_child(Kit.tag("until tomorrow" if until > today else "ends today", col, true, 10))
		row.add(top)
		row.add(Kit.para(str(b.get("text", "")), 13, Pal.TEXT))
		var why = str(b.get("why", ""))
		if why != "":
			row.add(Kit.muted_para(why, 12))
		sec.add(row)
	sec.add(Kit.muted_para("A boost is always a bonus on top. It ends after the day it says.", 12))
	return sec
