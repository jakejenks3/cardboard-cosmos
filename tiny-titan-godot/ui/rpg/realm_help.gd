class_name RealmHelp
extends RefCounted
## "How fights work": the rules of a fight in a few short points, as a sheet.
## The first fight teaches the first of them by doing; this is where the rest
## can be looked up. A link at the foot of the Map opens it, and so does a key
## in a fight's log. The numbers are read from RpgDefs, so they stay true when
## the game is tuned.
##
## Metas: realm_help (the link), help_sheet, help_point (a point's id).

## [id, icon, title, words]. {..} are filled in from RpgDefs.
const POINTS = [
	["turns", "energy", "Energy", "A move costs energy (its pips). You start a fight with {start} and gain {turn} every turn. Strike is free and gives {strike}; Guard gives {guard}."],
	["guard", "guard", "Guard", "Guard cuts every hit until your next turn by half or more (more with a strong Core). Use it when a foe's intent shows a big number or beats red."],
	["weak", "sch_legs", "Weaknesses", "A foe is weak to some schools (most to two) and may resist one. A weak hit does {weak}% more and knocks a pip off its guard; a resisted one does {resist}% less. A \"?\" on its plate is a weakness you have not found yet."],
	["break", "fx_broken", "Breaking a guard", "When a foe's last guard pip goes, it is BROKEN: it loses its next action and takes {broken}% more damage. That is the moment for your hardest move."],
	["intent", "in_attack", "Intents", "A foe shows what it will do next on its plate. Tap a plate to read a fighter in full: its statuses and what its moves do."],
	["gauge", "gauge", "The ultimate", "The gauge fills as you act, hit weaknesses, break guards and take hits. At 100% your Ultimate is ready (learn one on the Skills page)."],
	["boosts", "bolt", "Boosts", "Training gives boosts for that day and the next: lifting pumps the schools of what you trained, a run, a climb, reading and physical therapy each give their own. They are always a bonus on top."],
	["stats", "muscle", "Your stats", "Chest, shoulders and arms drive Push moves, back drives Pull, legs and core drive Legs; speed, grip and reading drive the other schools. They only ever go up, with your training."],
	["stars", "star_on", "Stars", "Every stage has three goals. Stars open a region's star chests. A stage can be fought again for the ones you missed."],
	["auto", "sword", "AUTO and speed", "AUTO lets the hero fight by himself until you tap it again; x1 / x2 sets how fast a fight plays. A tap anywhere skips what is playing. Tap the message line to read back what happened."],
]


static func _fill(words: String) -> String:
	return words.format({
		"start": RpgDefs.EN_START, "turn": RpgDefs.EN_TURN, "strike": RpgDefs.EN_STRIKE, "guard": RpgDefs.EN_GUARD,
		"weak": int(round((RpgDefs.WEAK_MULT - 1.0) * 100.0)), "resist": int(round((1.0 - RpgDefs.RESIST_MULT) * 100.0)),
		"broken": int(round((RpgDefs.BROKEN_MULT - 1.0) * 100.0)),
	})


## The link that opens it (a slim row for the foot of a page).
static func link() -> Control:
	var row = Kit.row(RealmHelp.open, RpgUi.color("realm"), RpgUi.color("realm"), 8, 0, 0.12)
	row.set_meta("realm_help", true)
	row.set_meta("anchor_id", "realm_help")
	if Kit.fingers:
		row.custom_minimum_size.y = 44
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect("book" if Icons.has_icon("book") else "star", 16)))
	var l = Kit.clip("How fights work", 14, null, true)
	h.add_child(Kit.vcenter(l))
	h.add_child(Kit.vcenter(Kit.clip("energy, guard, weaknesses, breaks", 12, Pal.MUTED)))
	row.add(h)
	return row


static func open() -> void:
	RpgSfx.play("select")
	var sh = Kit.sheet("How fights work")
	sh.box.set_meta("help_sheet", POINTS.size())
	for p in POINTS:
		var row = Kit.row(Callable(), RpgUi.color("realm"), null, 8, 2)
		row.set_meta("help_point", str(p[0]))
		var head = Kit.hbox(8)
		head.add_child(Kit.vcenter(Icons.rect(str(p[1]) if Icons.has_icon(str(p[1])) else "star", 16)))
		head.add_child(Kit.vcenter(Kit.label(str(p[2]), 14, null, true)))
		row.add(head)
		row.add(Kit.para(_fill(str(p[3])), 13, Pal.TEXT))
		sh.box.add_child(row)
	var close = Kit.button("Close", "ghost", sh.close, "lg")
	if Kit.fingers:
		close.custom_minimum_size.y = 44
	sh.box.add_child(close)
	sh.open()
