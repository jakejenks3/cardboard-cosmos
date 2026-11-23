class_name SettingsPanel
extends VBoxContainer
## Contents of the Settings sheet (see settings.gd). Rebuilds itself after a
## picker changes; the name field is left alone while typing.

var sheet: Sheet = null


var _pending_name = null
var _pending_source = null

func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func fill() -> void:
	# A name still being typed is saved first, so the rebuilt field shows it.
	if _pending_name != null:
		_commit_name(_pending_name)
	if _pending_source != null:
		_commit_source(_pending_source)
	Kit.clear(self)
	var p = App.profile()
	var st = App.settings()

	# --- look ---------------------------------------------------------------------
	add_child(Kit.section_title("Theme"))
	var themes = Kit.grid(Pal.THEME_ORDER.size(), 8)
	for id in Pal.THEME_ORDER:
		themes.add_child(_theme_tile(id))
	add_child(themes)

	# --- hero -------------------------------------------------------------------
	if p != null:
		var hero = _card("HERO")
		var row = Kit.hbox(14)
		var pic = PixelRect.make(Art.hero_texture(App.state, p, App.loadout()), 2.0)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
		var right = Kit.vbox(10)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name_edit = Kit.input(p.get("name", ""), "Hero name")
		name_edit.max_length = 20
		name_edit.tooltip_text = "Hero name"
		name_edit.text_changed.connect(_on_name)
		right.add_child(name_edit)
		right.add_child(Parts.appearance_editor(int(p.get("skin", 0)), int(p.get("hairStyle", 0)), int(p.get("hairColor", 0)), _on_look, int(p.get("facialHair", 0))))
		row.add_child(right)
		hero.add(row)
		add_child(hero)

	# --- units & training ------------------------------------------------------------
	var train = _card("TRAINING")
	train.add(_row("scale", "Weight", Kit.segmented([{"value": "kg", "label": "kg"}, {"value": "lb", "label": "lb"}], st.get("weightUnit", "kg"), _on_weight_unit)))
	train.add(_row("road", "Distance", Kit.segmented([{"value": "km", "label": "km"}, {"value": "mi", "label": "mi"}], st.get("distanceUnit", "km"), _on_setting.bind("distanceUnit"))))
	var unit = str(st.get("weightUnit", "kg"))
	var step_opts = []
	for s in TT.WEIGHT_STEPS[unit]:
		step_opts.append({"value": float(s), "label": "%s %s" % [TTUtil.num_str(s), unit]})
	var step_row = _row("plus", "Step", Kit.segmented(step_opts, float(TT.weight_step_of(st)), _on_setting.bind("weightStep")))
	step_row.tooltip_text = "How much one − / + tap changes a weight"
	train.add(step_row)
	var goal_opts = []
	for n in range(2, 7):
		goal_opts.append({"value": n, "label": str(n)})
	var goal_row = _row("flame", "Weekly goal", Kit.segmented(goal_opts, int(st.get("weeklyGoal", 3)), _on_setting.bind("weeklyGoal")))
	goal_row.tooltip_text = "Sessions per week that keep your streak alive"
	train.add(goal_row)
	var snd = bool(st.get("sound", true))
	train.add(_row("sound_on" if snd else "sound_off", "Sound", Kit.switch(snd, _on_sound, "Sound effects")))
	add_child(train)
	_build_split()
	_build_focus()

	# --- phone app, phone inbox ----------------------------------------------------
	# The phone note and the morning pushes run on the PC; the phone app shares its log.
	add_child(PhoneAppCard.make(self))
	if not OS.has_feature("web"):
		_build_inbox()
		_build_morning()
	if PhonePush.wanted():
		_build_morning_phone()

	# --- data ---------------------------------------------------------------------
	var photos = App.referenced_photo_ids().size()
	var what = "your sessions, check-ins and all %d progress photos" % photos if photos > 0 else "your sessions and check-ins"
	var about = [
		"Backups include %s." % what,
		"Photos never leave this computer.",
		"Your save lives in %s. A dated copy is kept there automatically each day." % ProjectSettings.globalize_path(App.DATA_DIR),
	]
	if OS.has_feature("web"):
		about = [
			"Backups include %s." % what,
			"Your save lives in this app on this phone, and (when it is shared) in your note's script. A dated copy is kept automatically each day.",
		]
	var data = _card("DATA", _info_button("About your data", about))
	var web = OS.has_feature("web")
	if web:
		# The phone app: the backup file is the only copy outside this phone.
		var due = App.backup_due()
		var last = Kit.hbox(6)
		last.add_child(Kit.vcenter(Icons.rect("chest", 16)))
		last.add_child(Kit.clip("Last backup: %s" % App.backup_age_text(), 13, Pal.DANGER if due else Pal.MUTED, due))
		data.add(last)
		data.add(Kit.muted_para("Your log and photos live in this app on this phone. A backup file is your second copy: save it to Files or iCloud, or send it to yourself.", 12))
		if photos > 0:
			# Photos make a backup big, so they go in once: later backups are the
			# log alone until there is a new photo.
			var fresh = App.photos_unsaved().size()
			var pday = str(App.backup_info().get("photosDay", ""))
			var pl = Kit.hbox(6)
			pl.add_child(Kit.vcenter(Icons.rect("camera", 16)))
			var said = ""
			if fresh > 0:
				said = "%d photo%s not in a backup yet: the next backup holds all your photos." % [fresh, "" if fresh == 1 else "s"]
			else:
				said = "Your photos are in the backup of %s. Keep that file: newer backups are small, the log alone." % Dates.format_date(pday, {"month": "short", "day": "numeric"})
			var pt = Kit.muted_para(said, 12)
			pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pt.set_meta("backup_photos_line", true)
			pl.add_child(pt)
			data.add(pl)
	var btns = Kit.hbox(8)
	btns.add_child(Kit.expand(Kit.button("Back up now" if web else "Export backup", "primary" if web else "secondary", SettingsPanel.pick_export, "md", "chest")))
	btns.add_child(Kit.expand(Kit.button("Restore" if web else "Import backup", "secondary", SettingsPanel.pick_import.bind(sheet), "md", "arrow_down")))
	data.add(btns)
	var btns2 = Kit.hbox(8)
	if not OS.has_feature("web"):
		btns2.add_child(Kit.expand(Kit.button("Open data folder", "ghost", _open_folder, "md", "book")))
	elif photos > 0 and App.photos_unsaved().is_empty():
		var full = Kit.button("Back up with photos", "ghost", SettingsPanel.pick_export.bind(true), "md", "camera")
		full.tooltip_text = "One file with everything, photos too"
		btns2.add_child(Kit.expand(full))
	else:
		btns2.add_child(Kit.spacer())
	btns2.add_child(Kit.button("Reset", "danger", SettingsPanel.ask_reset.bind(sheet)))
	data.add(btns2)
	add_child(data)


## A settings card with a pixel-font heading and an optional control on the right.
func _card(title: String, right: Control = null) -> Card:
	var c = Kit.card(12, Callable(), 12)
	var h = Kit.hbox(8)
	h.custom_minimum_size = Vector2(0, 26)
	var t = PixelFont.rect(title, 2, Pal.ACCENT)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	h.add_child(Kit.spacer())
	if right != null:
		h.add_child(Kit.vcenter(right))
	c.add(h)
	return c


## icon · label · control, on one line.
func _row(icon: String, label_text: String, control: Control) -> HBoxContainer:
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(Kit.vcenter(Icons.rect(icon, 20)))
	var l = Kit.label(label_text, 14, null, true)
	l.custom_minimum_size = Vector2(92, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	if control.size_flags_horizontal != Control.SIZE_SHRINK_END:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		h.add_child(Kit.spacer())
	h.add_child(control)
	return h


## A small "i" button that opens a sheet with the explanation.
func _info_button(title: String, lines: Array) -> Button:
	return Kit.icon_button("info", SettingsPanel.show_info.bind(title, lines), title, 32)


## A sheet with a few short paragraphs (help text kept out of the way).
static func show_info(title: String, lines: Array, extra: Control = null) -> void:
	var sh = Kit.sheet(title)
	for l in lines:
		sh.box.add_child(Kit.para(str(l), 14, Pal.TEXT))
	if extra != null:
		sh.box.add_child(extra)
	var ok = Kit.button("Got it", "primary", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)
	sh.open()


func _refill() -> void:
	if is_instance_valid(self) and is_inside_tree():
		fill()


func _on_name(t: String) -> void:
	# Save once typing pauses, not on every key: each save re-derives the whole log.
	_pending_name = t
	get_tree().create_timer(0.6).timeout.connect(_commit_name.bind(t))


func _commit_name(t: String) -> void:
	if _pending_name == null or _pending_name != t:
		return
	_pending_name = null
	var clean = t.strip_edges()
	if clean == "" or App.profile() == null or clean == App.profile().name:
		return
	App.update_profile({"name": clean})


func _exit_tree() -> void:
	# The sheet was closed mid-typing: keep what was typed.
	if _pending_name != null:
		_commit_name(_pending_name)
	if _pending_source != null:
		_commit_source(_pending_source)


# ---------------------------------------------------------------------------
# Phone inbox (app/inbox.gd): workouts jotted in a note on the phone
# ---------------------------------------------------------------------------

func _build_inbox() -> void:
	var ib = App.inbox.settings()
	var card = _card("PHONE INBOX", Kit.button("How it works", "ghost", SettingsPanel.show_how, "sm"))
	card.set_meta("inbox_section", true)
	var src = Kit.input(str(ib.get("source", "")), "Google Doc link or a file path")
	src.select_all_on_focus = false
	src.tooltip_text = "Link or file"
	src.text_changed.connect(_on_source)
	card.add(src)
	var check = Kit.button("Check now", "primary", _check_now, "lg", "repeat")
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add(check)
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(Kit.expand(Kit.button("Paste text", "secondary", InboxSheet.open_paste.bind(_close_sheet), "md", "edit"))))
	row.add_child(Kit.gap(4))
	var auto_label = Kit.label("Auto-check", 14, null, true)
	auto_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(auto_label)
	row.add_child(Kit.switch(bool(ib.get("auto", true)), _on_inbox_auto, "Check when the game starts, then every ten minutes"))
	card.add(row)
	var arow = Kit.hbox(8)
	var al = Kit.label("Import on its own", 14, null, true)
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	al.tooltip_text = "Entries with nothing to ask, once the workout is over (an earlier day, or the note still for 90 minutes)"
	arow.add_child(Kit.vcenter(al))
	arow.add_child(Kit.switch(bool(ib.get("autoImport", true)), func(on): App.update_inbox({"autoImport": bool(on)}), "Entries with nothing to ask, once the workout is over"))
	card.add(arow)
	var line = App.inbox.status
	if line == "":
		line = App.inbox.last_checked_text()
	if line == "":
		line = "Not checked yet"
	var status = Kit.hbox(6)
	status.add_child(Kit.vcenter(Icons.rect("clock", 16)))
	status.add_child(Kit.clip(line, 12, Pal.MUTED))
	card.add(status)
	# Lift names the review was told about ("row - cable, 1UE" is my Single-Arm Cable Row).
	var n_names = App.inbox.names_count()
	if n_names > 0:
		var remembered = Kit.hbox(6)
		remembered.add_child(Kit.vcenter(Icons.rect("lift", 16)))
		remembered.add_child(Kit.clip("%d lift name%s remembered" % [n_names, "" if n_names == 1 else "s"], 12, Pal.MUTED))
		var forget = Kit.button("Forget", "ghost", _forget_names, "sm")
		forget.tooltip_text = "The next import works the names out again, and asks"
		remembered.add_child(forget)
		card.add(remembered)
	# Emptying the note's table after an import (app/doc_clear.gd).
	var can = App.inbox.can_clear()
	var crow = Kit.hbox(6)
	crow.add_child(Kit.vcenter(Icons.rect("sparkle", 16)))
	var cl = Kit.clip("Clear the table after import" if can else "Clear the table after import: not set up", 12, null if can else Pal.MUTED, can)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(Kit.vcenter(cl))
	if can:
		crow.add_child(Kit.switch(bool(App.inbox.clear_settings().on), _on_clear_auto, "Empty the rows that came in, after each import"))
	var setup = Kit.button("Set up" if not can else "Options", "secondary" if not can else "ghost", _open_clear_setup, "sm")
	setup.tooltip_text = "Add a small script to the doc so the game can empty the table"
	crow.add_child(Kit.vcenter(setup))
	crow.set_meta("clear_row", true)
	card.add(crow)
	# The phone logger (the note's script serves it): to the phone once, then on its home screen.
	if can:
		var lrow = Kit.hbox(6)
		lrow.add_child(Kit.vcenter(Icons.rect("edit", 16)))
		var ll = Kit.clip("Phone logger: tap to log at the gym", 12, null, true)
		ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lrow.add_child(Kit.vcenter(ll))
		var to_phone = Kit.button("Send to phone", "secondary", _send_logger, "sm")
		to_phone.tooltip_text = "A push with the logger's link: open it, then Add to Home screen"
		lrow.add_child(Kit.vcenter(to_phone))
		lrow.add_child(Kit.vcenter(Kit.button("Copy", "ghost", _copy_logger, "sm")))
		lrow.set_meta("logger_row", true)
		card.add(lrow)
	add_child(card)


## Morning goals on the phone (MorningAlert): off until the player turns it on.
## Training split: which kind of day follows which. The Today card, the
## missions and the morning message plan the day after the last lift day.
func _build_split() -> void:
	var cur = str(App.settings().get("split", "auto"))
	var card = _card("TRAINING SPLIT", _info_button("Training split", [
		"Pick the order you train in. The day after a pull day is then a push day, and so on round the cycle.",
		"The Today card, the missions and the morning message plan that day: its lifts from your log, and one of its movements you have not tried.",
		"Doing something else today? Tap another day on the Today card. Whatever you log decides what comes next.",
		"\"From my log\" has no cycle: the day is guessed from your weekdays and how often you do each lift.",
	]))
	card.set_meta("split_section", true)
	var chips = Kit.flow(6)
	for s in Missions.SPLITS:
		chips.add_child(Kit.chip(str(s.name), str(s.id) == cur, _on_setting.bind(str(s.id), "split"), Pal.LIFT))
	card.add(chips)
	var cycle = Missions.split_cycle(cur)
	if not cycle.is_empty():
		var names = []
		for k in cycle:
			names.append(str(Missions.KIND_NAMES[k]))
		names.append("again")
		card.add(Kit.para(" > ".join(PackedStringArray(names)), 12, Pal.MUTED))
	add_child(card)


## Training focus (game/dose.gd): what the weekly sets per muscle should be.
## The Today card then adds a lift for a muscle that is short, keeps the legs
## at "as last time", asks for a rest day and grows the weekly run.
func _build_focus() -> void:
	var st = App.settings()
	var cur = Dose.plan_id(st)
	var card = _card("TRAINING FOCUS", _info_button("Training focus", [
		"Pick what you are training for. Every muscle then has a number of sets it should get in a week, and the Today card shows how many it got in the last 7 days.",
		"On a day that trains a muscle that is short, the plan adds one more lift for it, with several to pick from for whatever equipment is there. A chest with no press gets a press first.",
		"Muscles that are only kept (the legs, with \"Upper body first\") never get sets added. Their lifts still have goals to beat.",
		"After 5 lifting days in a row the day is a rest day: a rest from lifting, so your run, a climb and physical therapy are still fine on it. The Rest chip on the Today card makes any day a rest day (or a rest day a lift day), and the days after follow.",
		"A climbing session counts for the forearms only, not for the back.",
		"\"From my log\" switches all of this off.",
	]))
	card.set_meta("focus_section", true)
	var chips = Kit.flow(6)
	chips.add_child(Kit.chip("From my log", cur == "", _on_setting.bind("", "focus"), Pal.LIFT))
	for id in Dose.ORDER:
		chips.add_child(Kit.chip(str(Dose.PLANS[id].name), cur == str(id), _on_setting.bind(str(id), "focus"), Pal.LIFT))
	card.add(chips)
	if cur != "":
		card.add(Kit.para(str(Dose.PLANS[cur].blurb), 12, Pal.MUTED))
		var row = Kit.hbox(8)
		var l = Kit.vbox(1)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(Kit.label("Build up my weekly run", 14, null, true))
		l.add_child(Kit.para("Each run aims about 10% further than the last; after a break it starts lower.", 11, Pal.MUTED))
		row.add_child(l)
		row.add_child(Kit.vcenter(Kit.switch(Dose.run_on(st), _on_run_goal, "Grow the weekly run a little at a time")))
		card.add(row)
		if Dose.run_on(st):
			# The run's day: its goals show on that day only.
			var picked = st.get("runDay")
			var own = int(picked) if ((picked is int or picked is float) and int(picked) >= 0 and int(picked) <= 6) else -1
			var auto_day = Dose.run_day(App.sessions(), {}, Dates.add_days(App.today, 1))
			var days = Kit.flow(4)
			days.set_meta("run_days", true)
			days.add_child(Kit.chip("Auto" + ((" (%s)" % str(Dose.WEEKDAYS[auto_day]).left(3)) if auto_day >= 0 else ""), own < 0, _on_setting.bind(-1, "runDay"), Pal.RUN, 12))
			for i in range(7):
				days.add_child(Kit.chip(str(Dose.WEEKDAYS[i]).left(3), own == i, _on_setting.bind(i, "runDay"), Pal.RUN, 12))
			card.add(Kit.label("Run day", 13, null, true))
			card.add(days)
			card.add(Kit.para("Run goals (a distance to reach, a pace to beat) show on this day only. Auto is the day you usually run.", 11, Pal.MUTED))
		var see = Kit.button("See my weekly sets", "secondary", DoseView.open, "sm")
		see.set_meta("see_dose", true)
		card.add(see)
	add_child(card)


func _on_run_goal(on: bool) -> void:
	Sfx.tick()
	App.update_settings({"runGoal": on})
	call_deferred("_refill")


func _build_morning() -> void:
	var m = MorningAlert.settings(App.settings())
	var card = _card("MORNING GOALS", Kit.button("How it works", "ghost", SettingsPanel.show_morning_how.bind(m.topic), "sm"))
	card.set_meta("morning_section", true)
	card.add(Kit.muted_para("Today's plan on your phone when you wake up: what you will probably do, what to beat, PT and something new to try.", 12))
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(Icons.rect("sun", 20)))
	var l = Kit.label("Every day at", 14, null, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(Kit.vcenter(Kit.icon_button("minus", _morning_time.bind(-30), "30 minutes earlier", 28)))
	row.add_child(Kit.vcenter(PixelFont.rect(m.time, 2, Pal.ACCENT)))
	row.add_child(Kit.vcenter(Kit.icon_button("plus", _morning_time.bind(30), "30 minutes later", 28)))
	row.add_child(Kit.spacer())
	row.add_child(Kit.switch(m.on, _on_morning, "Send it every morning"))
	card.add(row)
	# The evening check: what is still open today.
	var ev = Kit.hbox(8)
	ev.add_child(Kit.vcenter(Icons.rect("moon", 20)))
	var el = Kit.label("Evening check", 14, null, true)
	el.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ev.add_child(el)
	ev.add_child(Kit.vcenter(Kit.icon_button("minus", _evening_time.bind(-30), "30 minutes earlier", 28)))
	ev.add_child(Kit.vcenter(PixelFont.rect(m.eveningTime, 2, Pal.ACCENT)))
	ev.add_child(Kit.vcenter(Kit.icon_button("plus", _evening_time.bind(30), "30 minutes later", 28)))
	ev.add_child(Kit.spacer())
	ev.add_child(Kit.switch(m.evening, _on_evening, "In the evening: what of today is still open (nothing when all is done)"))
	ev.set_meta("evening_row", true)
	card.add(ev)
	var rc = Kit.hbox(8)
	rc.add_child(Kit.vcenter(Icons.rect("photo", 20)))
	var rl = Kit.label("Weekly recap picture", 14, null, true)
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc.add_child(rl)
	rc.add_child(Kit.switch(m.recap, func(on): _morning_patch({"recap": bool(on)}), "Last week's recap poster on your phone, when you open the game in a new week"))
	card.add(rc)
	var topic = Kit.hbox(6)
	topic.add_child(Kit.vcenter(Icons.rect("speech", 16)))
	topic.add_child(Kit.clip("Topic: %s" % (m.topic if m.topic != "" else "(made when you first send)"), 12, Pal.MUTED))
	card.add(topic)
	var keys = Kit.hbox(8)
	keys.add_child(Kit.expand(Kit.button("Send a test", "secondary", _morning_test, "md", "bolt")))
	keys.add_child(Kit.button("Copy topic", "ghost", _copy_topic, "md"))
	card.add(keys)
	add_child(card)


## Morning goals in the phone app: the app leaves the coming mornings' plans
## with ntfy itself (app/phone_push.gd), so no PC is needed.
func _build_morning_phone() -> void:
	var m = PhonePush.settings(App.settings())
	var card = _card("MORNING GOALS", Kit.button("How it works", "ghost", SettingsPanel.show_phone_morning_how.bind(m.topic), "sm"))
	card.set_meta("morning_phone", true)
	card.add(Kit.muted_para("The day's plan on this phone each morning, sent by the app itself. No PC needed.", 12))
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(Icons.rect("sun", 20)))
	var l = Kit.label("Every day at", 14, null, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(Kit.vcenter(Kit.icon_button("minus", _phone_morning_time.bind(-30), "30 minutes earlier", 28)))
	row.add_child(Kit.vcenter(PixelFont.rect(m.time, 2, Pal.ACCENT)))
	row.add_child(Kit.vcenter(Kit.icon_button("plus", _phone_morning_time.bind(30), "30 minutes later", 28)))
	row.add_child(Kit.spacer())
	row.add_child(Kit.switch(m.phone, _on_phone_morning, "Send it every morning"))
	card.add(row)
	var st = Kit.hbox(6)
	st.add_child(Kit.vcenter(Icons.rect("clock", 16)))
	var sl = Kit.muted_para(App.push.status_text(), 12)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.set_meta("push_status", true)
	st.add_child(sl)
	card.add(st)
	var topic = Kit.hbox(6)
	topic.add_child(Kit.vcenter(Icons.rect("speech", 16)))
	topic.add_child(Kit.clip("Topic: %s" % (m.topic if m.topic != "" else "(made when you first send)"), 12, Pal.MUTED))
	card.add(topic)
	var keys = Kit.hbox(8)
	keys.add_child(Kit.expand(Kit.button("Send a test", "secondary", _phone_morning_test, "md", "bolt")))
	keys.add_child(Kit.button("Copy topic", "ghost", _copy_topic, "md"))
	card.add(keys)
	add_child(card)


static func show_phone_morning_how(topic: String) -> void:
	SettingsPanel.show_info("Morning goals", [
		"1. The free app ntfy on this phone, subscribed to your topic: %s. If you had morning goals from your PC, that is already done." % (topic if topic != "" else "press Send a test once to make it"),
		"2. Press Send a test: a notification with today's plan should arrive.",
		"3. Turn the switch on. Whenever this app is open it leaves the next two mornings' plans with ntfy, which delivers each at your time.",
		"Tomorrow's plan is written as if today goes as planned. If it did not (a day off, another workout), one updated message follows the first.",
		"A message that is already waiting cannot be taken back, so a new time or the switch counts from the mornings not left yet. Open the app at least every other day, or the messages run out.",
		"If your PC still sends morning goals, turn that off there, or they arrive twice. The message goes through ntfy.sh, a free public relay: the topic is a long random name, so only someone who knows it can read it. It holds lift names and weights, nothing else.",
	])


func _on_phone_morning(on) -> void:
	Sfx.tick()
	var topic = _ensure_topic()
	_morning_patch({"phone": bool(on)})
	if on:
		App.push.run()
		App.toast("Each morning at %s, to %s" % [str(PhonePush.settings(App.settings()).time), topic], "good", "sun")
	else:
		var w = App.push.waiting_days()
		App.toast("Morning goals off" + ("" if w == "" else ". Already on their way: %s" % w), "info", "sun")
	call_deferred("_refill")


func _phone_morning_time(minutes: int) -> void:
	Sfx.tick()
	var m = PhonePush.settings(App.settings())
	var parts = m.time.split(":")
	var total = clampi(int(parts[0]) * 60 + int(parts[1]) + minutes, 0, 11 * 60 + 30)
	_morning_patch({"time": "%02d:%02d" % [int(total / 60.0), total % 60]})
	call_deferred("_refill")


func _phone_morning_test() -> void:
	Sfx.tap()
	var topic = _ensure_topic()
	App.toast("Sending…", "info", "bolt")
	var res = await App.push.send_test()
	if res.ok:
		App.toast("Sent to %s: check your phone" % topic, "good", "check")
	else:
		App.toast("Not sent: %s" % str(res.error), "bad", "warning")
	call_deferred("_refill")


static func show_morning_how(topic: String) -> void:
	SettingsPanel.show_info("Morning goals", [
		"1. Install the free app ntfy on your phone (App Store or Google Play).",
		"2. In ntfy, tap + and subscribe to your topic: %s (Copy topic puts it on the clipboard)." % (topic if topic != "" else "press Send a test once to make it"),
		"3. Press Send a test: a notification with today's plan should arrive.",
		"4. Turn the switch on. Every day at that time (midnight to start with, for an early workout) this computer works out the day's plan from your log and sends it.",
		"The computer has to be on or asleep (it is woken), not shut down. The message goes through ntfy.sh, a free public relay: the topic is a long random name, so only someone who knows it can read it. It holds lift names and weights, nothing else.",
	])


func _ensure_topic() -> String:
	var m = MorningAlert.settings(App.settings())
	if m.topic == "":
		var mm = App.settings().get("morning", {}).duplicate() if App.settings().get("morning") is Dictionary else {}
		mm["topic"] = MorningAlert.new_topic()
		App.update_settings({"morning": mm})
		return str(mm.topic)
	return m.topic


func _morning_patch(patch: Dictionary) -> void:
	var mm = App.settings().get("morning", {}).duplicate() if App.settings().get("morning") is Dictionary else {}
	mm.merge(patch, true)
	App.update_settings({"morning": mm})


func _morning_time(minutes: int) -> void:
	Sfx.tick()
	var m = MorningAlert.settings(App.settings())
	var parts = m.time.split(":")
	var total = clampi(int(parts[0]) * 60 + int(parts[1]) + minutes, 0, 11 * 60 + 30)
	var t = "%02d:%02d" % [int(total / 60.0), total % 60]
	_morning_patch({"time": t})
	if m.on:
		var res = MorningAlert.schedule(true, t)
		if not res.ok:
			App.toast("Could not move the morning task: %s" % str(res.output).substr(0, 80), "bad", "warning")
	call_deferred("_refill")


func _on_morning(on) -> void:
	Sfx.tick()
	var topic = _ensure_topic()
	var m = MorningAlert.settings(App.settings())
	var res = MorningAlert.schedule(bool(on), m.time)
	if res.ok:
		_morning_patch({"on": bool(on)})
		App.toast(("Every morning at %s it goes to %s" % [m.time, topic]) if on else "Morning goals off", "good" if on else "info", "sun")
	else:
		App.toast("Could not set it up: %s" % str(res.output).substr(0, 80), "bad", "warning")
	call_deferred("_refill")


func _on_evening(on) -> void:
	Sfx.tick()
	var topic = _ensure_topic()
	var m = MorningAlert.settings(App.settings())
	var res = MorningAlert.schedule(bool(on), m.eveningTime, MorningAlert.TASK_EVENING, "--evening")
	if res.ok:
		_morning_patch({"evening": bool(on)})
		App.toast(("Every evening at %s: what is still open, to %s" % [m.eveningTime, topic]) if on else "Evening check off", "good" if on else "info", "moon")
	else:
		App.toast("Could not set it up: %s" % str(res.output).substr(0, 80), "bad", "warning")
	call_deferred("_refill")


func _evening_time(minutes: int) -> void:
	Sfx.tick()
	var m = MorningAlert.settings(App.settings())
	var parts = m.eveningTime.split(":")
	var total = clampi(int(parts[0]) * 60 + int(parts[1]) + minutes, 12 * 60, 23 * 60 + 30)
	var t = "%02d:%02d" % [int(total / 60.0), total % 60]
	_morning_patch({"eveningTime": t})
	if m.evening:
		var res = MorningAlert.schedule(true, t, MorningAlert.TASK_EVENING, "--evening")
		if not res.ok:
			App.toast("Could not move the evening task: %s" % str(res.output).substr(0, 80), "bad", "warning")
	call_deferred("_refill")


func _morning_test() -> void:
	Sfx.tap()
	var topic = _ensure_topic()
	var m = MorningAlert.settings(App.settings())
	var msg = MorningAlert.message(App.saved, App.today)
	App.toast("Sending…", "info", "bolt")
	var res = await MorningAlert.send(self, msg.title, msg.text, topic, m.server, MorningAlert.note_link(App.saved), MorningAlert.logger_link(App.saved))
	if res.ok:
		App.toast("Sent to %s: check your phone" % topic, "good", "check")
	else:
		App.toast("Not sent: %s" % str(res.error), "bad", "warning")
	call_deferred("_refill")


func _copy_topic() -> void:
	Sfx.tick()
	var topic = _ensure_topic()
	if WebFiles.available():
		# A phone's browser only copies inside a tap on a real button.
		WebFiles.copy(topic, "Copy topic")
		call_deferred("_refill")
		return
	DisplayServer.clipboard_set(topic)
	App.toast("Copied: %s" % topic, "good", "check")
	call_deferred("_refill")


## "How it works" for the phone inbox, in its own sheet.
static func show_how() -> void:
	var cheat = PanelContainer.new()
	cheat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cheat.add_theme_stylebox_override("panel", PixBox.well(12, 10))
	cheat.add_child(Kit.para(QuickLog.CHEAT_SHEET, 13, Pal.TEXT))
	var v = Kit.vbox(10)
	v.add_child(cheat)
	v.add_child(Kit.para("4. Press Check now, or just start the game. Nothing is imported until you say so; lines it cannot read are shown, never dropped.", 14, Pal.TEXT))
	if Ocr.available():
		var shots = Kit.hbox(8)
		var cam = Icons.rect("camera", 20)
		cam.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		shots.add_child(cam)
		var words = Kit.para("Screenshots work too. Paste a Strava run, ride or walk, or your scale app's weigh-in screen, into the Doc: the game reads the numbers off the picture. A walk comes in as a weighted vest walk; write \"vest 20\" under it for the weight. Any other picture is kept as a progress photo.", 14, Pal.TEXT)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shots.add_child(words)
		v.add_child(shots)
	v.add_child(Kit.muted_para("A Google Form's responses sheet or a file in a synced folder works too. Anyone with the link can read the note, so keep it to workouts.", 12))
	SettingsPanel.show_info("How it works", [
		"1. Make a Google Doc on your phone.",
		"2. Share → General access → Anyone with the link (Viewer), and paste the link here.",
		"3. Write what you did, one thing per line, a date line to start a day:",
	], v)


func _on_source(t: String) -> void:
	_pending_source = t
	get_tree().create_timer(0.6).timeout.connect(_commit_source.bind(t))


func _commit_source(t: String) -> void:
	if _pending_source == null or _pending_source != t:
		return
	_pending_source = null
	App.inbox.set_source(t)


func _send_logger() -> void:
	Sfx.tap()
	var m = MorningAlert.settings(App.settings())
	var link = MorningAlert.logger_link(App.saved)
	if link == "":
		App.toast("Set up the note's script first", "bad", "warning")
		return
	var topic = _ensure_topic()
	var res = await MorningAlert.send(self, "Tiny Titan logger", "Tap to open your logger. Then in the browser menu: Add to Home screen, for one tap at the gym.", topic, m.server, "", link)
	App.toast(("Sent to %s: open it on your phone" % topic) if res.ok else "Not sent: %s" % str(res.error), "good" if res.ok else "bad", "check" if res.ok else "warning")


func _copy_logger() -> void:
	Sfx.tick()
	DisplayServer.clipboard_set(MorningAlert.logger_link(App.saved))
	App.toast("Logger link copied", "good", "check")


func _on_clear_auto(on) -> void:
	Sfx.tick()
	App.inbox.set_clear({"on": bool(on)})
	App.toast("The table empties itself after each import" if on else "The table is left as it is", "good" if on else "info", "sparkle")
	call_deferred("_refill")


## The set-up sheet; the Phone inbox card is drawn again when it closes (set up now?).
func _open_clear_setup() -> void:
	var sh = SettingsPanel.show_clear_setup()
	if sh != null:
		sh.tree_exited.connect(func(): if is_instance_valid(self): call_deferred("_refill"))


## How to let the game empty the table: the script to paste into the doc, the
## web app link, a test, "Clear now", the switch.
static func show_clear_setup() -> Sheet:
	var cs = App.inbox.clear_settings()
	var sh = Kit.sheet("Clear the table")
	sh.box.add_child(Kit.para("The game only reads your note. To empty the table after an import, add this small script to the doc once, on your computer (about 5 minutes):", 14, Pal.TEXT))
	var steps = [
		"Open the note in Google Docs. Extensions > Apps Script.",
		"Delete what is there and paste the script (Copy the script, below). Save.",
		"Deploy > New deployment. Click the gear and pick Web app. Execute as: Me. Who has access: Anyone. Deploy.",
		"Google asks you to allow it: pick your account. If it says Google hasn't verified this app: Advanced, then Go to the project, then Continue (or Allow). It is your own script and only works on this doc.",
		"Copy the Web app link (it ends in /exec), paste it below and press Test.",
	]
	for i in range(steps.size()):
		var row = Kit.hbox(8)
		var n = Kit.label("%d" % (i + 1), 14, Pal.ACCENT, true)
		n.custom_minimum_size = Vector2(16, 0)
		row.add_child(n)
		var p = Kit.para(str(steps[i]), 13, Pal.TEXT)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
		sh.box.add_child(row)
	var copy = Kit.button("Copy the script", "secondary", SettingsPanel._copy_clear_script, "md", "edit")
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(copy)
	var link = Kit.input(str(cs.url), "Web app link (https://script.google.com/.../exec)")
	link.select_all_on_focus = false
	link.text_changed.connect(func(t): App.inbox.set_clear({"url": str(t).strip_edges()}))
	sh.box.add_child(link)
	var keys = Kit.hbox(8)
	keys.add_child(Kit.expand(Kit.button("Test", "secondary", SettingsPanel._test_clear, "md", "check")))
	keys.add_child(Kit.expand(Kit.button("Clear now", "secondary", SettingsPanel._clear_now, "md", "sparkle")))
	sh.box.add_child(keys)
	var sw = Kit.hbox(8)
	var sl = Kit.label("After each import", 14, null, true)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw.add_child(Kit.vcenter(sl))
	sw.add_child(Kit.switch(bool(cs.on), func(on): App.inbox.set_clear({"on": bool(on)}), "Empty the rows that came in, after each import"))
	sh.box.add_child(sw)
	# The day's plan in the table: at midnight (with Morning goals), or now.
	var pw = Kit.hbox(8)
	var pl = Kit.label("Write the day's plan at midnight", 14, null, true)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw.add_child(Kit.vcenter(pl))
	pw.add_child(Kit.switch(bool(cs.plan), func(on): App.inbox.set_clear({"plan": bool(on)}), "Rows for each planned lift (marked with a small arrow): you type the reps"))
	sh.box.add_child(pw)
	var now_key = Kit.button("Write today's plan now", "secondary", SettingsPanel._write_plan_now, "md", "edit")
	now_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(now_key)
	sh.box.add_child(Kit.para("The plan goes under the last filled row of the table: a date row, then a row per lift with its variation and the weight to aim for. Type the reps; rows you leave empty are skipped, and go the next day.", 12, Pal.MUTED))
	sh.box.add_child(Kit.para("It only empties table rows that are already imported and still exactly as the game read them. Rows you are typing, rows you left out, the header row and lines outside the table stay.", 12, Pal.MUTED))
	var done = Kit.button("Done", "primary", sh.close, "lg")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(done)
	sh.open()
	return sh


static func _copy_clear_script() -> void:
	Sfx.tick()
	DisplayServer.clipboard_set(DocClear.script_for(App.inbox.clear_token()))
	App.toast("Script copied: paste it into the doc's Apps Script", "good", "check")


static func _test_clear() -> void:
	Sfx.tick()
	var cs = App.inbox.clear_settings()
	if not DocClear.looks_right(str(cs.url)):
		App.toast("Paste the web app link first (it ends in /exec)", "bad", "warning")
		return
	var res = await DocClear.send(App.inbox, str(cs.url), App.inbox.clear_token(), [], true)
	if res.ok and int(res.get("version", 1)) < DocClear.SCRIPT_VERSION:
		App.toast("It works, but it is the old script: Copy the script, paste it over the old one, Save, run authorize once (beside Run), then Deploy > Manage deployments > edit > New version", "info", "warning")
	elif res.ok:
		App.toast("It works: the script sees %d table%s in the doc" % [res.tables, "" if int(res.tables) == 1 else "s"], "good", "check")
	else:
		App.toast(str(res.error), "bad", "warning")


static func _write_plan_now() -> void:
	Sfx.tick()
	if not App.inbox.can_clear():
		App.toast("Paste the web app link first (it ends in /exec)", "bad", "warning")
		return
	var res = await App.inbox.write_plan_now()
	if not res.ok:
		App.toast(str(res.error), "bad", "warning")
	elif bool(res.get("already", false)):
		App.toast("Today's plan is already in the note", "info", "check")
	elif int(res.get("planned", 0)) == 0 and int(res.get("version", 2)) < DocClear.SCRIPT_VERSION:
		App.toast("Update the script first: copy it again and deploy a new version", "info", "warning")
	else:
		App.toast("Wrote %d row%s of today's plan into the note" % [res.planned, "" if int(res.planned) == 1 else "s"], "good", "check")


static func _clear_now() -> void:
	Sfx.tick()
	if not App.inbox.can_clear():
		App.toast("Paste the web app link first (it ends in /exec)", "bad", "warning")
		return
	var res = await App.inbox.clear_imported()
	if not res.ok:
		App.toast(str(res.error), "bad", "warning")
	elif int(res.cleared) == 0 and int(res.get("skipped", 0)) == 0:
		App.toast("Nothing to clear: no imported rows in the table (check the note first if you just typed)", "info", "sparkle")
	else:
		App.toast("Cleared %d row%s%s" % [res.cleared, "" if int(res.cleared) == 1 else "s", (", %d changed since it was read stayed" % res.skipped) if int(res.skipped) > 0 else ""], "good", "check")


func _forget_names() -> void:
	Sfx.tick()
	App.inbox.forget_names()
	App.toast("Forgotten: the next import asks about those names again", "info")
	call_deferred("_refill")


func _on_inbox_auto(on) -> void:
	Sfx.tick()
	App.inbox.set_auto(bool(on))
	call_deferred("_refill")


func _check_now() -> void:
	Sfx.tap()
	if _pending_source != null:
		_commit_source(_pending_source)
	if str(App.inbox.settings().get("source", "")).strip_edges() == "":
		App.toast("Paste the link to your phone note first", "info")
		return
	App.inbox.checked.connect(_on_checked_here, CONNECT_ONE_SHOT)
	InboxSheet.check_and_review(_close_sheet)


func _on_checked_here(_result) -> void:
	call_deferred("_refill")


## The review sheet and the results reel need the room: close Settings first.
func _close_sheet() -> void:
	if sheet != null and is_instance_valid(sheet):
		sheet.close()


func _on_look(patch: Dictionary) -> void:
	Sfx.tap()
	App.update_profile(patch)
	call_deferred("_refill")


func _on_setting(value, key: String) -> void:
	Sfx.tick()
	App.update_settings({key: value})
	call_deferred("_refill")


## A swatch of a theme: its world colour with a panel and the accent on it.
func _theme_tile(id: String) -> Button:
	var th = Pal.THEMES[id]
	var on = id == Pal.theme_id
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(60, 64)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.tooltip_text = th.name
	var looks = PixBox.button_set(Color(th.bg), Color(th.outline), 6, 6, 1, Pal.ACCENT if on else Color(th.border))
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v = Kit.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -12
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row = Kit.hbox(3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for key in ["panel2", "accent", "second"]:
		var sw = ColorRect.new()
		sw.color = Color(th[key])
		sw.custom_minimum_size = Vector2(12, 12)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
	v.add_child(row)
	var l = Kit.label(th.name, 12, Color(th.text), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	b.add_child(v)
	b.pressed.connect(_on_theme.bind(id))
	Kit.juice(b)
	return b


func _on_theme(id: String) -> void:
	if id == Pal.theme_id:
		return
	Sfx.claim()
	# The shell rebuilds itself in the new colours and reopens this sheet.
	App.update_settings({"theme": id})


func _on_sound(on) -> void:
	App.update_settings({"sound": bool(on)})
	Sfx.tick()
	call_deferred("_refill")


## Switching units keeps the weight step when it exists for the new unit,
## otherwise falls back to that unit's default (2.5 kg / 5 lb).
func _on_weight_unit(unit) -> void:
	Sfx.tick()
	App.update_settings(SettingsPanel.unit_patch(App.settings(), str(unit)))
	call_deferred("_refill")


static func unit_patch(st: Dictionary, unit: String) -> Dictionary:
	var patch = {"weightUnit": unit}
	var cur = st.get("weightStep")
	if cur == null or not TTUtil.has_number(TT.WEIGHT_STEPS[unit], cur):
		patch["weightStep"] = 2.5 if unit == "kg" else 5
	return patch


func _open_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path(App.DATA_DIR))


# ---------------------------------------------------------------------------
# Backups (static: the dialogs can outlive the sheet)
# ---------------------------------------------------------------------------

static func _dialog(mode: int) -> FileDialog:
	var dlg = FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.file_mode = mode
	dlg.filters = PackedStringArray(["*.json ; Tiny Titan backup"])
	# Start in Documents, never in the game's own folder (a backup saved there
	# would be picked up by a build of the game).
	var docs = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs != "":
		dlg.current_dir = docs
	dlg.canceled.connect(dlg.queue_free)
	var host = Kit.overlay_root
	if host == null:
		host = (Engine.get_main_loop() as SceneTree).root
	host.add_child(dlg)
	return dlg


## `full`: true = with photos, false = the log alone, null = with photos only
## when some are in no backup made here yet (the phone app's "Back up now").
static func pick_export(full = null) -> void:
	if WebFiles.available():
		# The web build: the backup goes to the browser (an iPhone's share sheet).
		var with_photos = bool(full) if full != null else not App.photos_unsaved().is_empty()
		var n_photos = App.photos_here().size()
		var tmp = App.DATA_DIR + "backup-export.json"
		var err = App.export_backup(tmp, with_photos)
		if err != "":
			App.toast("Export failed: %s" % err, "bad", "warning")
			return
		var file_name = "tiny-titan-backup-%s%s.json" % [App.today, "-with-photos" if with_photos else ""]
		WebFiles.save(file_name, "application/json", FileAccess.get_file_as_bytes(tmp), "Save the backup", func():
			App.note_backup(with_photos)
			if with_photos:
				App.toast("Saved with your %d photo%s. Keep this file somewhere safe" % [n_photos, "" if n_photos == 1 else "s"], "good", "chest")
			elif n_photos > 0:
				App.toast("Log saved. Your photos are in the earlier backup: keep that file too", "good", "chest")
			else:
				App.toast("Keep that file somewhere safe: Save to Files, or send it to yourself", "good", "chest"))
		DirAccess.remove_absolute(tmp)
		return
	var dlg = SettingsPanel._dialog(FileDialog.FILE_MODE_SAVE_FILE)
	dlg.title = "Export backup"
	dlg.current_file = "tiny-titan-backup-%s.json" % App.today
	dlg.file_selected.connect(SettingsPanel._export_to.bind(dlg))
	dlg.popup_centered_ratio(0.8)


static func _export_to(path: String, dlg: FileDialog) -> void:
	if is_instance_valid(dlg):
		dlg.queue_free()
	var err = App.export_backup(path)
	if err == "":
		App.note_backup()
		App.toast("Backup saved", "good", "chest")
	else:
		App.toast("Export failed: %s" % err, "bad", "warning")


static func pick_import(sh) -> void:
	if WebFiles.available():
		WebFiles.pick(".json,application/json", "Choose a backup", func(file_name: String, bytes: PackedByteArray):
			if file_name == "" or bytes.is_empty():
				return
			var tmp = App.DATA_DIR + "backup-import.json"
			var f = FileAccess.open(tmp, FileAccess.WRITE)
			if f == null:
				return
			f.store_buffer(bytes)
			f.close()
			SettingsPanel.confirm_import(tmp, sh))
		return
	var dlg = SettingsPanel._dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dlg.title = "Import backup"
	dlg.file_selected.connect(SettingsPanel._import_from.bind(dlg, sh))
	dlg.popup_centered_ratio(0.8)


static func _import_from(path: String, dlg, sh) -> void:
	if is_instance_valid(dlg):
		dlg.queue_free()
	SettingsPanel.confirm_import(path, sh)


## Read a backup and ask before replacing the current data.
static func confirm_import(path: String, sh = null) -> void:
	var result = App.read_backup(path)
	if not result.ok:
		App.toast("Import failed: %s" % result.error, "bad", "warning")
		return
	# A backup older than the log here that holds photos missing here (the log
	# was restored from a small backup first): only its photos are taken.
	var extra = App.photos_to_take(result)
	if extra > 0 and App.has_profile() and float(result.data.get("updatedAt", 0)) < float(App.saved.get("updatedAt", 0)):
		Kit.confirm("Add its photos?", "This backup is older than the log on this device, and it holds %d photo%s missing here. Add %s? Your log stays as it is." % [extra, "" if extra == 1 else "s", "it" if extra == 1 else "them"],
			"Add photos", SettingsPanel.do_take_photos.bind(result, sh), false)
		return
	var body = "Import %d sessions and %d check-ins? This replaces your current data." % [result.sessions, result.body]
	Kit.confirm("Import backup", body, "Import", SettingsPanel.do_import.bind(result, sh))


static func do_take_photos(result: Dictionary, sh = null) -> void:
	var n = App.take_photos(result)
	App.toast("%d photo%s added" % [n, "" if n == 1 else "s"], "good", "camera")
	if sh != null and is_instance_valid(sh):
		sh.close()


static func do_import(result: Dictionary, sh = null) -> void:
	var n = App.apply_backup(result)
	var missing = App.photos_missing().size()
	if missing > 0:
		# The log alone: its photos come from the backup that holds them.
		App.toast("Log imported. %d photo%s missing: now restore your backup with photos to add %s" % [missing, " is" if missing == 1 else "s are", "it" if missing == 1 else "them"], "info", "camera")
	else:
		App.toast("Backup imported" + (" with %d photos" % n if n > 0 else ""), "good", "chest")
	if sh != null and is_instance_valid(sh):
		sh.close()


static func ask_reset(sh = null) -> void:
	Kit.confirm("Reset everything?", "This deletes all sessions, check-ins, gear and pets.", "Reset", SettingsPanel._ask_reset_again.bind(sh))


static func _ask_reset_again(sh = null) -> void:
	Kit.confirm("Really?", "There is no undo.", "Delete everything", SettingsPanel._do_reset.bind(sh))


static func _do_reset(sh = null) -> void:
	App.reset_all()
	if sh != null and is_instance_valid(sh):
		sh.close()
