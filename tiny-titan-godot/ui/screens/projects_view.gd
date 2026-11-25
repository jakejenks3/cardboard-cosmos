class_name ProjectsView
extends RefCounted
## Climbing projects (game/projects.gd): a boulder or route the player works on
## until it goes.
##
##   ProjectsView.card()   the Hero tab's section "PROJECTS" (Kit.section, the
##                         climbing colour): the open projects and how long
##                         they have taken so far; for a climber with none, a
##                         line to pick one (null for a player who does not climb)
##   ProjectsView.open()   the sheet: the open ones with "I sent it!" and "Set
##                         aside", the form to pick a new one, then the sent ones.
##                         The sheet grows from the bottom, so a project added
##                         above the form leaves the form where it was; once the
##                         sheet scrolls, _fill scrolls by what was added.

## A climber: a climb logged in the last this many days.
const CLIMBER_DAYS = 45


static func _ig(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The grade, big, on a plate in the climbing colour.
static func grade_badge(p: Dictionary, px: int = 44) -> Control:
	var plate = PanelContainer.new()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(px + 12, px)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sent = str(p.sent) != ""
	var col = Pal.ACCENT if sent else Pal.CLIMB
	plate.add_theme_stylebox_override("panel", PixBox.make(Pal.deep(col), {"ring": col, "lip": 1, "lip_color": Pal.OUTLINE, "pad_h": 3, "pad_v": 2}))
	var text = Projects.grade_text(p)
	var t = PixelFont.rect(text, 2 if text.length() <= 3 else 1, Color.WHITE)
	plate.add_child(Kit.center(t))
	return plate


static func _climbs_lately() -> bool:
	for s in App.sessions():
		if str(s.get("discipline", "")) == "climb" and Dates.days_between(str(s.date), App.today) <= CLIMBER_DAYS:
			return true
	return false


## The Hero tab's section, or null for a player who does not climb.
static func card():
	var open_list = App.open_projects()
	if open_list.is_empty() and not _climbs_lately():
		return null
	var right = _ig(Kit.hbox(6))
	if open_list.is_empty():
		right.add_child(Kit.vcenter(Kit.tag("+ Pick one", Pal.CLIMB, true, 11)))
	right.add_child(Kit.vcenter(_ig(Icons.rect("chevron_right", 16))))
	var c = Kit.section("projects", "PROJECTS", "climb", Pal.CLIMB, right, ProjectsView.open, 6, 10)
	c.tooltip_text = "Climbing projects: the climbs you are working on"
	if open_list.is_empty():
		c.add(_ig(Kit.clip("A climb you cannot send yet: see how many sessions it takes.", 12, Pal.MUTED)))
		return c
	for p in open_list.slice(0, 3):
		var st = Projects.status(p, App.sessions(), App.today)
		var row = _ig(Kit.hbox(10))
		row.add_child(grade_badge(p, 32))
		var v = _ig(Kit.vbox(0))
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.clip(str(p.name) if str(p.name) != "" else "Project", 14, null, true))
		v.add_child(Kit.clip(Projects.progress_text(st), 11, Pal.MUTED))
		row.add_child(v)
		c.add(row)
	return c


static func open() -> void:
	Sfx.tap()
	var sh = Kit.sheet("Climbing projects")
	_fill(sh, {"route": false, "grade": -99, "name": ""})
	sh.open()


## (Re)build the sheet. `form` keeps what was being picked across a rebuild;
## the form stays where it was on the screen.
static func _fill(sh, form: Dictionary) -> void:
	var before = null
	var old = sh.get_meta("form_card") if sh.has_meta("form_card") else null
	if old != null and is_instance_valid(old) and old.is_inside_tree():
		before = old.global_position.y
	for ch in sh.box.get_children():
		sh.box.remove_child(ch)
		ch.queue_free()
	var all = App.projects()
	var open_list = App.open_projects()
	sh.box.add_child(Kit.muted_para("A climb you cannot send yet. Every session with its grade in it counts as a session on it; sending it is worth %d XP." % Projects.SEND_XP, 13))
	if not open_list.is_empty():
		sh.box.add_child(Kit.section_title("Working on"))
		for p in open_list:
			sh.box.add_child(_open_card(sh, p))
	var fc = _form(sh, form, open_list.size())
	sh.set_meta("form_card", fc)
	sh.box.add_child(fc)
	var sent = all.filter(func(p): return str(p.sent) != "")
	sent.sort_custom(func(a, b): return str(a.sent) > str(b.sent))
	if not sent.is_empty():
		sh.box.add_child(Kit.section_title("Sent"))
		for p in sent:
			sh.box.add_child(_done_card(sh, p, true))
	var aside = all.filter(func(p): return str(p.sent) == "" and str(p.aside) != "")
	if not aside.is_empty():
		sh.box.add_child(Kit.section_title("Set aside"))
		for p in aside:
			sh.box.add_child(_done_card(sh, p, false))
	var ok = Kit.button("Close", "ghost", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)
	if before != null:
		_keep_form(sh, fc, float(before))


## Once the sheet scrolls, content added above the form would push it down:
## scroll by as much, so it stays under the finger.
static func _keep_form(sh, fc: Control, before: float) -> void:
	await sh.get_tree().process_frame
	await sh.get_tree().process_frame
	if not is_instance_valid(sh) or sh._closing or not is_instance_valid(fc):
		return
	var moved = fc.global_position.y - before
	if absf(moved) >= 1.0:
		sh._scroll.scroll_vertical += int(round(moved))


## Pick a new project: boulder or route, the grade, a name (optional), Add.
static func _form(sh, form: Dictionary, n_open: int) -> Control:
	var c = Kit.card(8, Callable(), 12)
	c.accent(Pal.CLIMB)
	c.add(Kit.label("New project", 15, Pal.CLIMB, true))
	if n_open >= Projects.MAX_OPEN:
		c.add(Kit.muted_para("%d projects are open: send one or set one aside first." % Projects.MAX_OPEN, 12))
		return c
	var kinds = Kit.hbox(6)
	kinds.add_child(Kit.chip("Boulder", not form.route, func():
		form.route = false
		form.grade = -99
		_fill(sh, form), Pal.CLIMB))
	kinds.add_child(Kit.chip("Route", form.route, func():
		form.route = true
		form.grade = -99
		_fill(sh, form), Pal.CLIMB))
	c.add(kinds)
	var grades = Kit.flow(4)
	if form.route:
		for i in range(Xp.YDS_GRADES.size()):
			var g = Xp.YDS_GRADES[i]
			if Xp.yds_index(g) < Xp.yds_index("5.8") or Xp.yds_index(g) > Xp.yds_index("5.14a"):
				continue
			grades.add_child(Kit.chip(g, int(form.grade) == i, _pick_grade.bind(sh, form, i), Pal.CLIMB, 12))
	else:
		for v in range(0, 13):
			grades.add_child(Kit.chip(Xp.grade_label(v), int(form.grade) == v, _pick_grade.bind(sh, form, v), Pal.CLIMB, 12))
	c.add(grades)
	var name_in = Kit.input(str(form.name), "Name it (optional): blue overhang, the arete...")
	name_in.text_changed.connect(func(t): form.name = t)
	c.add(name_in)
	var add = Kit.button("Add project", "primary", func():
		if int(form.grade) == -99:
			App.toast("Pick its grade first", "info", "climb")
			return
		var yds = Xp.YDS_GRADES[int(form.grade)] if form.route else ""
		var boulder = Xp.YDS_TO_V[int(form.grade)] if form.route else int(form.grade)
		var p = App.add_project(boulder, yds, str(form.name))
		if p == null:
			return
		Sfx.claim()
		App.toast("New project: %s" % Projects.title(p), "good", "climb")
		_fill(sh, {"route": form.route, "grade": -99, "name": ""}), "md")
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add(add)
	return c


static func _pick_grade(sh, form: Dictionary, g: int) -> void:
	Sfx.tap()
	form.grade = g
	_fill(sh, form)


static func _open_card(sh, p: Dictionary) -> Control:
	var st = Projects.status(p, App.sessions(), App.today)
	var c = Kit.card(8, Callable(), 12)
	c.accent(Pal.CLIMB)
	var row = Kit.hbox(12)
	row.add_child(grade_badge(p))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.clip(str(p.name) if str(p.name) != "" else "Project", 16, null, true))
	v.add_child(Kit.clip(Projects.progress_text(st), 12, Pal.TEXT))
	var since = "Picked %s" % ClimbCard.when_text(str(p.since))
	if str(st.last) != "":
		since += " · last tried %s" % ClimbCard.when_text(str(st.last))
	v.add_child(Kit.clip(since, 11, Pal.MUTED))
	row.add_child(v)
	c.add(row)
	var keys = Kit.hbox(8)
	var sent = Kit.button("I sent it!", "primary", func(): _send(sh, p, c), "md")
	sent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.add_child(sent)
	keys.add_child(Kit.button("Set aside", "ghost", func():
		Sfx.tap()
		App.set_project_aside(str(p.id), true)
		_fill(sh, {"route": false, "grade": -99, "name": ""}), "md"))
	c.add(keys)
	return c


## "I sent it!": the latest session that sent its grade, else today.
static func _send(sh, p: Dictionary, card: Control) -> void:
	var s = Projects.last_send(p, App.sessions())
	App.send_project(str(p.id), str(s.id) if s != null else "", str(s.date) if s != null else App.today)
	Sfx.pr()
	Sfx.level_up()
	Kit.burst(card, Pal.ACCENT, 30)
	App.toast("Project sent: %s! +%d XP" % [Projects.title(p), Projects.SEND_XP], "good", "trophy")
	var tw = card.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func(): _fill(sh, {"route": false, "grade": -99, "name": ""}))


## A sent or set-aside project, and a key to work on it again.
static func _done_card(sh, p: Dictionary, sent: bool) -> Control:
	var st = Projects.status(p, App.sessions(), App.today)
	var c = Kit.card(4, Callable(), 10)
	if sent:
		c.accent(Pal.ACCENT)
	var row = Kit.hbox(10)
	row.add_child(grade_badge(p, 32))
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.clip(str(p.name) if str(p.name) != "" else "Project", 14, null, true))
	var what = ("Sent %s · " % ClimbCard.when_text(str(p.sent))) if sent else ("Set aside %s · " % ClimbCard.when_text(str(p.aside)))
	v.add_child(Kit.clip(what + Projects.progress_text(st), 11, Pal.MUTED))
	row.add_child(v)
	if not sent:
		row.add_child(Kit.vcenter(Kit.button("Back on", "ghost", func():
			Sfx.tap()
			App.set_project_aside(str(p.id), false)
			_fill(sh, {"route": false, "grade": -99, "name": ""}), "sm")))
	c.add(row)
	return c
