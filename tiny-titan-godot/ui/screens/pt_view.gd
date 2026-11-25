class_name PtView
extends RefCounted
## Physical therapy: are you keeping up? The rules are in game/pt.gd; a lift
## becomes a PT lift by "(PT)" in the phone note or the Log tab, or by the
## switch on its page (JourneyLifts).
##
##   PtView.card()        the Hero tab's section "PT THIS WEEK" (Kit.section,
##                        sets done / sets aimed for in its band): this week
##                        for every PT lift (null when there is none)
##   PtView.open()        the sheet: each lift's week, eight weeks of bars, the
##                        days a week to aim for
##   PtView.state_tag(r)  "Done" / "4 sets to go" / "Behind" for a row of Pt.status
##
## Everything is counted in SETS (Pt.SETS_A_DAY of a lift count on a day, so a
## single set is a third of a day): a day's square fills by that share, and a
## lift's goal is its days a week x Pt.SETS_A_DAY sets.

## How many lifts the Hero tab's card lists.
const CARD_ROWS = 4


static func state_color(r: Dictionary) -> Color:
	match str(r.state):
		"done":
			return Pal.GOOD
		"behind":
			return Pal.DANGER
	return Pal.TEXT


static func state_tag(r: Dictionary) -> Control:
	match str(r.state):
		"done":
			return Kit.tag("Done", Pal.GOOD, true, 10)
		"behind":
			return Kit.tag("Behind", Pal.DANGER, false, 10)
	return Kit.tag("%d %s to go" % [int(r.left), "set" if int(r.left) == 1 else "sets"], Pal.PANEL2, false, 10)


## "Last done 2 days ago · 3 weeks in a row", or that it was never done.
static func facts(r: Dictionary) -> String:
	if int(r.daysSince) < 0:
		return "Not done yet"
	var when = Dates.relative_day(str(r.last), App.today)
	if int(r.daysSince) <= 1:
		when = when.to_lower()
	var out = "Last done %s" % when
	if int(r.run) >= 2:
		out += " · %d weeks in a row" % int(r.run)
	return out


static func _ig(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The Hero tab's section, or null when no lift is marked as physical therapy.
static func card():
	var rows = Pt.status(App.sessions(), App.pt(), App.today)
	if rows.is_empty():
		return null
	var sum = Pt.summary(rows)
	var right = _ig(Kit.hbox(6))
	# (on the PT band: light text, a green tag once the week is done)
	if int(sum.left) == 0:
		right.add_child(Kit.vcenter(Kit.tag("%d / %d" % [int(sum.done), int(sum.goal)], Pal.GOOD, true, 12)))
	else:
		right.add_child(Kit.vcenter(Kit.label("%d / %d" % [int(sum.done), int(sum.goal)], 14, Pal.TEXT, true)))
	right.add_child(Kit.vcenter(_ig(Icons.rect("chevron_right", 16))))
	var c = Kit.section("pt", "PT THIS WEEK", "pt", Pal.PT, right, PtView.open, 6, 10)
	# The section alone carries this tooltip (the detail walkthrough finds the card by it).
	c.tooltip_text = "Physical therapy: are you keeping up?"
	c.add(Kit.bar(float(sum.done) / float(maxi(1, int(sum.goal))), Pal.PT, 10))
	var today_i = Dates.weekday_index(App.today)
	for i in range(mini(rows.size(), CARD_ROWS)):
		var r = rows[i]
		var line = _ig(Kit.hbox(8))
		line.add_child(Kit.clip(str(r.name), 13, null, true))
		# (a day's square fills by its share of Pt.SETS_A_DAY sets)
		var dots = WeekBars.Dots.new()
		dots.setup(r.weekShare, today_i, Pal.PT, 10)
		line.add_child(dots)
		var count = Kit.label("%d/%d" % [int(r.sets), int(r.setsGoal)], 13, state_color(r), true)
		count.custom_minimum_size.x = 40
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(Kit.vcenter(count))
		c.add(line)
	if rows.size() > CARD_ROWS:
		c.add(Kit.clip("and %d more" % (rows.size() - CARD_ROWS), 12, Pal.MUTED))
	return c


static func open() -> void:
	Sfx.tap()
	var sheet = Kit.sheet("Physical therapy")
	_fill(sheet)
	sheet.open()


## Everything in the sheet. Runs again when a goal changes; the lifts keep the
## order they had when the sheet opened, so the key just pressed stays put.
static func _fill(sheet: Sheet) -> void:
	if not is_instance_valid(sheet):
		return
	var box = sheet.box
	for old in box.get_children():
		box.remove_child(old)
		old.queue_free()
	var rows = Pt.status(App.sessions(), App.pt(), App.today)
	var order = sheet.get_meta("order", [])
	if order.is_empty():
		for r in rows:
			order.append(str(r.key))
		sheet.set_meta("order", order)
	else:
		TTUtil.stable_sort(rows, func(a, b): return order.find(str(a.key)) < order.find(str(b.key)))
	if rows.is_empty():
		var none = Kit.vbox(8)
		var ic = Icons.rect("pt", 32)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		none.add_child(ic)
		none.add_child(JourneyScreen.caption("No physical therapy exercises yet", 15, Pal.TEXT))
		box.add_child(none)
	else:
		var sum = Pt.summary(rows)
		var top = Kit.hbox(10)
		top.add_child(Kit.vcenter(PixelFont.rect("%d/%d" % [int(sum.done), int(sum.goal)], 4, Pal.PT)))
		var words = Kit.vbox(2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.add_child(Kit.clip("sets done this week", 13, null, true))
		var note = "All done for the week" if int(sum.left) == 0 else "%d %s to go" % [int(sum.left), "set" if int(sum.left) == 1 else "sets"]
		if int(sum.behind) > 0:
			note += " · %d behind" % int(sum.behind)
		words.add_child(Kit.clip(note, 12, Pal.MUTED))
		words.add_child(Kit.bar(float(sum.done) / float(maxi(1, int(sum.goal))), Pal.PT, 10))
		top.add_child(words)
		box.add_child(top)
		for r in rows:
			box.add_child(_lift_card(sheet, r))
	box.add_child(Kit.muted_para("To add one: write (PT) in front of an exercise in your phone note, or switch it on on a lift's page.", 12))


## "days a week · 3 sets a day": the words after the Aim for stepper (the goal
## is kept in days; each day is Pt.SETS_A_DAY sets).
static func aim_words(per_week: int) -> String:
	return "day%s a week · %d sets a day" % ["" if per_week == 1 else "s", Pt.SETS_A_DAY]


## One PT lift: this week's sets (a square a day, filled by its share of
## Pt.SETS_A_DAY), eight weeks of bars of sets against its goal, and the goal
## itself, in days a week.
static func _lift_card(sheet: Sheet, r: Dictionary) -> Card:
	var c = Kit.card(6, Callable(), 10)
	c.accent(Pal.DANGER if str(r.state) == "behind" else Pal.PT)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Kit.clip(str(r.name), 15, null, true)))
	head.add_child(Kit.vcenter(state_tag(r)))
	c.add(head)
	var week = Kit.hbox(8)
	var dots = WeekBars.Dots.new()
	dots.setup(r.weekShare, Dates.weekday_index(App.today), Pal.PT, 14)
	week.add_child(dots)
	week.add_child(Kit.vcenter(Kit.clip("%d of %d sets this week" % [int(r.sets), int(r.setsGoal)], 13, null, true)))
	c.add(week)
	var bars = WeekBars.new()
	bars.setup(r.weeks, Pal.PT, int(r.setsGoal), "set")
	c.add(bars)
	# (the Trends key sits here, beside the facts, so the Aim for row has room
	# for its words)
	var foot = Kit.hbox(6)
	foot.add_child(Kit.vcenter(Kit.clip(facts(r), 12, Pal.MUTED)))
	var more = Kit.button("Trends", "ghost", JourneyLifts.open_named.bind(str(r.name), {}), "sm", "chevron_right")
	more.tooltip_text = "Weight, reps and history of %s" % str(r.name)
	foot.add_child(Kit.vcenter(more))
	c.add(foot)
	var goal = Kit.hbox(6)
	goal.add_child(Kit.vcenter(Kit.label("Aim for", 13, Pal.MUTED)))
	goal.add_child(Kit.vcenter(Kit.icon_button("minus", PtView._set_goal.bind(sheet, str(r.name), int(r.perWeek) - 1), "One day fewer", 28)))
	goal.add_child(Kit.vcenter(PixelFont.rect(str(int(r.perWeek)), 2, Pal.PT)))
	goal.add_child(Kit.vcenter(Kit.icon_button("plus", PtView._set_goal.bind(sheet, str(r.name), int(r.perWeek) + 1), "One day more", 28)))
	goal.add_child(Kit.vcenter(Kit.clip(aim_words(int(r.perWeek)), 13, Pal.MUTED)))
	c.add(goal)
	return c


static func _set_goal(sheet: Sheet, lift: String, per_week: int) -> void:
	if per_week < 1 or per_week > Pt.MAX_PER_WEEK:
		Sfx.error()
		return
	Sfx.tick()
	App.set_pt_goal(lift, per_week)
	_fill(sheet)
