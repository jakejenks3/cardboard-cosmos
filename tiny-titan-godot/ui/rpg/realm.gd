class_name RealmScreen
extends UiScreen
## The Realm tab (RPG_PLAN.md 10.1): the turn-based RPG's home, the sixth tab.
##
## A FIRST version (2026-11-26): the fights are still being built, but the
## hero's twelve stats and the day's boosts are already worked out from the
## log (game/rpg/rpg_stats.gd, rpg_boosts.gd), so the tab shows them: every
## stat with what it is made of and what raises it, and what today's and
## yesterday's training is worth tomorrow. The real hub (banner, map, moves,
## skills, gear, battles) replaces this file in the screens step.
##
## It only READS the log. It is drawn again when the log changes (App.changed:
## UiScreen does that) and when the Realm's own save changes (App.rpg_changed).

## The hub with chests, map and fights is not here yet: main.gd shows the
## tab's "a chest waits" dot only once it is (a test turns it on to try the dot).
static var hub_ready = false


func _ready() -> void:
	super._ready()
	App.rpg_changed.connect(rebuild)


## What the stat engine reads (plain data from App; nothing is changed).
static func sheet_input() -> Dictionary:
	return {"sessions": App.sessions(), "state": App.state, "reading": App.reading(), "books": App.books(),
		"body": App.body(), "claims": App.claims(), "settings": App.settings(), "marks": App.pt(), "today": App.today}


## A school's colour (a stat is shown in its school's: RpgDefs.STAT_SCHOOL).
static func color_of(school: String) -> Color:
	match school:
		"push":
			return Pal.PUSH
		"pull":
			return Pal.PULL
		"legs":
			return Pal.LEGS
		"speed":
			return Pal.RUN
		"grip":
			return Pal.CLIMB
		"mind":
			return Pal.READ
		"flow":
			return Pal.PT
		"grit":
			return Pal.GRIT
	return Pal.REALM


func build() -> void:
	var input = sheet_input()
	var sheet = RpgStats.sheet(input)

	var intro = Kit.section("realm", "THE REALM", "realm", Pal.REALM, null, Callable(), 8, 12)
	var soon = Kit.para("The Ironwild is opening soon: a land to fight through, one turn at a time.", 15, null, true)
	soon.set_meta("realm_soon", true)
	intro.add(soon)
	var counts = Kit.muted_para("Your training already counts. These are your hero's stats, worked out from your log: they only ever go up. Tap one to see what it is made of.", 13)
	counts.set_meta("realm_counts", true)
	intro.add(counts)
	add_child(intro)

	add_child(_stat_section("realm_body", "BODY", "muscle", Pal.PUSH, sheet, sheet.get("body", RpgDefs.BODY)))
	add_child(_stat_section("realm_traits", "TRAITS", "star", Pal.REALM, sheet, sheet.get("traits", RpgDefs.TRAITS)))
	add_child(_boost_section(RpgBoosts.active(input)))


## One section of stats: a row each (icon, name, a bar to 99, the value, the
## change this week, its first line). A tap opens the stat's sheet.
func _stat_section(id: String, title: String, icon: String, color: Color, sheet: Dictionary, ids: Array) -> Control:
	var sec = Kit.section(id, title, icon, color, null, Callable(), 6, 10)
	for stat_id in ids:
		var st = sheet.stats.get(stat_id)
		if st == null:
			continue
		var col = color_of(str(RpgDefs.STAT_SCHOOL.get(stat_id, "")))
		var row = Kit.row(_open_stat.bind(st), col)
		row.set_meta("realm_stat", str(stat_id))
		row.set_meta("anchor_id", "realm_stat:" + str(stat_id))
		var top = Kit.hbox(8)
		top.add_child(Kit.vcenter(Icons.rect(str(RpgDefs.STAT_ICONS.get(stat_id, "star")), 20)))
		var name_l = Kit.clip(str(st.name), 15, null, true)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(Kit.vcenter(name_l))
		var gain = float(st.raw) - float(st.get("was", st.raw))
		if gain >= 0.05:
			var up = Kit.tag("+%s this week" % TTUtil.to_fixed1(gain), Pal.GOOD, true, 10)
			up.set_meta("realm_gain", true)
			top.add_child(Kit.vcenter(up))
		var val = Kit.label(str(int(st.v)), 20, col, true)
		val.custom_minimum_size = Vector2(34, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.set_meta("realm_value", int(st.v))
		top.add_child(Kit.vcenter(val))
		row.add(top)
		row.add(Kit.bar(float(st.raw) / 99.0, col, 8))
		var lines = st.get("lines", [])
		if not lines.is_empty():
			row.add(Kit.clip(str(lines[0]), 12, Pal.MUTED))
		sec.add(row)
	return sec


## A stat in full: what it does in a fight, what it is made of, what raises it.
func _open_stat(st: Dictionary) -> void:
	var sh = Kit.sheet("%s %d" % [str(st.name), int(st.v)])
	sh.box.set_meta("realm_stat_sheet", str(st.id))
	var col = color_of(str(RpgDefs.STAT_SCHOOL.get(st.id, "")))
	sh.box.add_child(Kit.bar(float(st.raw) / 99.0, col, 12))
	sh.box.add_child(Kit.para("In a fight: %s." % str(RpgDefs.STAT_DOES.get(st.id, "")), 13, Pal.TEXT))
	sh.box.add_child(Kit.sub_head("MADE OF", col))
	for line in st.get("lines", []):
		sh.box.add_child(Kit.para(str(line), 13, Pal.TEXT))
	var next = str(st.get("next", ""))
	if next != "":
		sh.box.add_child(Kit.sub_head("WHAT RAISES IT", col))
		sh.box.add_child(Kit.para(next, 13, Pal.TEXT))
	sh.box.add_child(Kit.button("Close", "ghost", sh.close, "lg"))
	sh.open()


## Today's boosts: what today's and yesterday's training gives the hero.
func _boost_section(boosts: Array) -> Control:
	var sec = Kit.section("realm_boosts", "BOOSTS TODAY", "bolt", Pal.ACCENT, null, Callable(), 6, 10)
	if boosts.is_empty():
		sec.add(Kit.muted_para("None right now. What you train today gives the hero a boost today and tomorrow: a pump for the muscles you lift with, a second wind from a run, chalked hands from a climb, a sharp mind from 10 pages, limber from physical therapy.", 13))
		return sec
	sec.add(Kit.muted_para("From today's and yesterday's training. They will count in the fights.", 12))
	for b in boosts:
		var col = color_of(str(b.get("school", "")))
		var row = Kit.row(Callable(), col)
		row.set_meta("realm_boost", str(b.get("id", "")))
		var top = Kit.hbox(8)
		top.add_child(Kit.vcenter(Icons.rect(str(b.get("icon", "bolt")), 20)))
		var name_l = Kit.clip(str(b.get("name", "")), 14, null, true)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(Kit.vcenter(name_l))
		var until = str(b.get("until", ""))
		top.add_child(Kit.vcenter(Kit.tag("until tomorrow" if until > App.today else "today", col, true, 10)))
		row.add(top)
		row.add(Kit.para(str(b.get("text", "")), 12, Pal.TEXT))
		var why = str(b.get("why", ""))
		if why != "":
			row.add(Kit.clip(why, 11, Pal.MUTED))
		sec.add(row)
	return sec
