class_name ChallengeView
extends RefCounted
## The day's lift challenges on screen (Challenges, Missions.daily; 2026-11-27).
##
##   section()            the Hero tab's CHALLENGES section, under TODAY: a card a challenge: the lift, "PICK
##                        ONE" and its records to go for (an icon, what kind, the target, what it beats), a tick
##                        on the one hit, something to try, and the Claim key once done. A tap opens the lift.
##   look(type)           [icon, colour, short word] of an option
##   chip_text(o)         an option said on a key: "Heavier 65 × 6"

const WORDS = {"heavier": "Heavier", "reps": "Rep PR", "ladder": "Best", "set_reps": "Set PR", "day_reps": "Day PR", "band": "Band up", "hold": "Longer"}


static func look(type: String) -> Array:
	match type:
		"heavier", "band":
			return ["arrow_up", Pal.ACCENT]
		"ladder":
			return ["crown", Pal.SECOND]
		"hold":
			return ["stopwatch", Pal.SECOND]
	return ["plus", Pal.GOOD]


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
	sec.add(Kit.para("Set a record on each: heavier than ever, or more reps at a weight you've done. Pick one.", 12, Pal.MUTED))
	for m in list:
		sec.add(card(m))
	return sec


static func card(m: Dictionary) -> Control:
	var done = bool(m.done)
	var col = Pal.GOOD if done else Pal.ACCENT2
	var c = Kit.row(JourneyLifts.open_named.bind(str(m.lift), {"view": "progress"}), col, Pal.GOOD if (done and not bool(m.claimed)) else null, 8, 5)
	c.set_meta("challenge", str(m.id))
	c.tooltip_text = "Open %s" % Missions.short_name(str(m.lift))
	if bool(m.claimed):
		c.modulate.a = 0.65
	var head = Kit.hbox(6)
	var sp = LiftNames.split(str(m.lift))
	var nm = Kit.squeeze(6)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_child(Kit.soft_name(str(sp.move), 15, null, true, 200.0))
	if str(sp.variation) != "":
		nm.add_child(SessionView.variation_tag(str(sp.variation), 10, true))
	head.add_child(nm)
	if bool(m.claimed):
		head.add_child(Kit.vcenter(Kit.tag("DONE", Pal.GOOD, true, 10)))
	elif done:
		var claim = Kit.button("Claim +%s" % Xp.fmt_int(m.xp), "good", Callable(), "sm")
		claim.set_meta("anchor_id", "claim:" + str(m.id))
		claim.set_meta("challenge_claim", str(m.id))
		claim.pressed.connect(Parts._claim.bind(m, claim))
		Fx.shine(claim, 2.6, 0.5, 0.45)
		head.add_child(Kit.vcenter(claim))
	else:
		head.add_child(Kit.vcenter(Parts.xp_chip(m.xp, 11)))
	c.add(head)
	var opts = m.get("options", [])
	var hit = m.get("hit", [])
	if opts.is_empty():
		c.add(Kit.para(str(m.desc), 12, Pal.MUTED))
		return c
	c.add(Kit.label("PICK ONE" if not done else "DONE: ONE RECORD IS ENOUGH", 9, Pal.MUTED, true))
	for o in opts:
		var lk = look(str(o.type))
		var is_hit = hit.has(str(o.type))
		var row = Kit.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_meta("challenge_option", str(o.type))
		row.set_meta("challenge_hit", is_hit)
		row.add_child(Kit.vcenter(Icons.rect(str(lk[0]), 16, lk[1]) if Kit.look == "stripe" else Kit.badge(str(lk[0]), lk[1], 14)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t = Kit.hbox(6)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.add_child(Kit.label(str(o.title).to_upper(), 9, lk[1], true))
		t.add_child(Kit.clip(str(o.words), 13, Pal.TEXT, true))
		v.add_child(t)
		v.add_child(Kit.clip(str(o.sub), 11, Pal.MUTED))
		row.add_child(v)
		row.add_child(Kit.vcenter(Kit.tick_box(is_hit, 18)))
		c.add(row)
	if hit.has("other"):
		c.add(Kit.clip("Done another way: it beat its last time.", 11, Pal.GOOD))
	elif not done:
		var tip = Kit.para("Try: " + str(opts[0].tip), 11, Pal.MUTED)
		tip.set_meta("challenge_tip", true)
		c.add(tip)
	return c
