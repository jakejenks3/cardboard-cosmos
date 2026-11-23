extends RefCounted
## A run's best splits (run with the "year" data): the fields that come by
## themselves in the run form once the distance has a mile, a 5K, a 10K in it,
## the time as it is read while it is typed, what is stored, the session's
## sheet, the bests on Journey -> Stats, the record in the results reel, and
## editing a run. Prints CHECK lines.

const MI = 1609.344

var main: Node
var tree: SceneTree
var fails = 0
var reels = []


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func screen() -> LogScreen:
	for n in ShotHelper.walk(main):
		if n is LogScreen:
			return n
	return null


func field(key: String):
	var s = screen()
	return s._find_fkey(s, key) if s != null else null


func _find(meta: String, root = null):
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			return n
	return null


func _all(meta: String, root = null) -> Array:
	var out = []
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			out.append(n)
	return out


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()
	await ShotHelper.wait(tree, 0.4)


func dismiss_results() -> void:
	await ShotHelper.frames(tree, 3)
	if main.get("_results") != null:
		main._results.finished.emit()
	await ShotHelper.frames(tree, 3)


func last_run():
	var best = null
	for s in App.sessions():
		if s.discipline == "run" and (best == null or s.createdAt > best.createdAt):
			best = s
	return best


## What is written beside a split's box.
func echo(id: String) -> String:
	for n in _all("split_echo"):
		if str(n.get_meta("split_echo")) == id:
			return str(n.text)
	return "(none)"


func rows_shown() -> Array:
	return _all("split_row").map(func(n): return str(n.get_meta("split_row")))


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	App.result_ready.connect(func(r): reels.append(r))
	await ShotHelper.wait(tree, 1.0)
	App.update_settings({"distanceUnit": "mi", "weightUnit": "lb"})
	var bests0 = RunSplits.bests(App.sessions())
	print("BESTS before ", bests0)

	# --- the form: nothing to ask until the distance has a split in it ------------------------
	App.open_log("run")
	await ShotHelper.wait(tree, 0.6)
	# (A hidden card is not found: the helper only walks what is on screen.)
	check(_find("splits_card") == null and rows_shown().is_empty(), "a new run: no split is asked for yet")
	ShotHelper.type_into(field("distance"), "0.8")
	await ShotHelper.frames(tree, 3)
	check(_find("splits_card") == null and rows_shown().is_empty(), "under a mile: still none")
	ShotHelper.type_into(field("distance"), "4")
	await ShotHelper.frames(tree, 3)
	var card = _find("splits_card")
	check(card != null and rows_shown() == ["mile", "5k"], "4 miles: the best mile and the best 5K (%s)" % str(rows_shown()))
	# A half marathon.
	ShotHelper.type_into(field("distance"), "13.1")
	await ShotHelper.frames(tree, 3)
	check(rows_shown() == ["mile", "5k", "10k", "10mi"], "13.1 miles: best mile, 5K, 10K and 10 mile (%s)" % str(rows_shown()))
	var whole = _find("split_whole")
	check(whole != null and whole.visible and str(whole.text) == "Half marathon: add the run's time above", "and the run itself is a half marathon (%s)" % (str(whole.text) if whole != null else "-"))
	ShotHelper.type_into(field("dur.h"), "1")
	ShotHelper.type_into(field("dur.m"), "55")
	ShotHelper.type_into(field("dur.s"), "20")
	await ShotHelper.frames(tree, 3)
	check(str(whole.text) == "Half marathon: 1:55:20, this run's own time", "with the time, the half marathon has its own (%s)" % str(whole.text))
	check(echo("mile") == "avg 8:48" and echo("5k") == "avg 27:21", "an empty box shows what the run's average pace would make of it (%s, %s)" % [echo("mile"), echo("5k")])
	ShotHelper.reveal(card)
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "splits_1_fields")

	# --- typing times: a phone's number pad has a dot and no colon -----------------------------
	var mile_box = field("split.mile")
	var before_rows = rows_shown()
	ShotHelper.type_into(mile_box, "7.45")
	await ShotHelper.frames(tree, 2)
	check(echo("mile") == "7:45 · 7:45 /mi" and field("split.mile") == mile_box and rows_shown() == before_rows, "7.45 is read as 7:45, and the box being typed in was not rebuilt (%s)" % echo("mile"))
	ShotHelper.type_into(field("split.5k"), "2530")
	ShotHelper.type_into(field("split.10k"), "52:10")
	await ShotHelper.frames(tree, 2)
	check(echo("5k") == "25:30 · 8:12 /mi" and echo("10k") == "52:10 · 8:24 /mi", "2530 is 25:30 and 52:10 is itself, each with its pace (%s, %s)" % [echo("5k"), echo("10k")])
	ShotHelper.type_into(field("split.10mi"), "abc")
	await ShotHelper.frames(tree, 2)
	check(echo("10mi") == "? write 7.45", "what is no time says so (%s)" % echo("10mi"))
	ShotHelper.type_into(field("split.10mi"), "1.40.00")
	await ShotHelper.frames(tree, 2)
	var note = _find("split_note")
	check(echo("10mi") == "1:40:00 ? · 10:00 /mi" and note != null and note.visible, "a best 10 mile slower than the run's average is marked (%s)" % echo("10mi"))
	await ShotHelper.snap(tree, "splits_2_typed")
	ShotHelper.type_into(field("split.10mi"), "1.26.40")
	await ShotHelper.frames(tree, 2)
	check(echo("10mi") == "1:26:40 · 8:40 /mi" and not note.visible, "put right, the mark goes (%s)" % echo("10mi"))
	check(ShotHelper.find_button(main, "Finish session") != null and not ShotHelper.find_button(main, "Finish session").disabled, "the run can be saved")

	# --- saved: the splits are in the session ----------------------------------------------------
	var n0 = App.sessions().size()
	ShotHelper.press(ShotHelper.find_button(main, "Finish session"))
	await ShotHelper.frames(tree, 4)
	var r = last_run()
	print("RUN ", JSON.stringify(r))
	check(App.sessions().size() == n0 + 1 and r.get("splits") == {"mile": 465, "5k": 1530, "10k": 3130, "10mi": 5200} and absf(float(r.distanceM) - 13.1 * MI) < 0.01 and int(r.durationSec) == 6920, "the run is stored with its four splits, in seconds")
	check(RunSplits.of_session(r).get("half", 0) == 6920, "and it counts as a half marathon in 1:55:20")
	# (The rules have records of their own, "Fastest pace (5 km+)!" among them: only the splits' are counted.)
	var is_split = func(e): return str(e.type) == "pr" and RunSplits.DISTS.any(func(d): return str(e.title) == str(d.best) + "!")
	var prs = reels[reels.size() - 1].events.filter(is_split) if not reels.is_empty() else []
	print("REEL records ", prs.map(func(e): return [e.title, e.detail]))
	var expect = RunSplits.records(App.sessions().filter(func(s): return s.id != r.id), [r])
	check(prs.size() == expect.size(), "the reel has a record card for each best it beat (%d; a first time over a distance is no record)" % expect.size())
	await ShotHelper.wait(tree, 1.2)
	await ShotHelper.snap(tree, "splits_3_reel")
	await dismiss_results()

	# --- the session's sheet -------------------------------------------------------------------
	SessionView.open(r)
	await ShotHelper.wait(tree, 0.7)
	var sheet = _sheet()
	var list = _find("split_rows", sheet) if sheet != null else null
	var said = ShotHelper.all_text(list) if list != null else ""
	check(list != null and said.contains("Mile") and said.contains("7:45") and said.contains("5K") and said.contains("25:30") and said.contains("10 mile") and said.contains("1:26:40") and said.contains("Half marathon (the run)") and said.contains("1:55:20") and said.contains("BEST"), "the run's sheet lists its splits, the run itself among them, the bests tagged")
	await ShotHelper.snap(tree, "splits_4_sheet")
	await _close_sheets()

	# --- Journey -> Stats: the best of each distance -----------------------------------------------
	App.go("journey", "stats")
	await ShotHelper.wait(tree, 0.8)
	var stats = ShotHelper.all_text(main)
	var b = RunSplits.bests(App.sessions())
	check(stats.contains("Fastest mile") and stats.contains("Fastest 5K") and stats.contains("Fastest 10K") and stats.contains("Fastest 10 mile") and stats.contains("Fastest half marathon") and stats.contains(RunSplits.fmt_time(int(b["mile"].sec))) and stats.contains("1:55:20"), "Journey, Stats: the running card has the best time over each distance")
	var tip = ShotHelper.find_text(main, "Fastest 10 mile")
	if tip != null:
		ShotHelper.reveal(tip)
		await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "splits_5_journey")

	# --- a second run with a faster 5K in it: a record in the reel ---------------------------------
	App.open_log("run")
	await ShotHelper.wait(tree, 0.6)
	ShotHelper.type_into(field("distance"), "4")
	ShotHelper.type_into(field("dur.m"), "33")
	await ShotHelper.frames(tree, 3)
	ShotHelper.type_into(field("split.5k"), "24.59")
	ShotHelper.type_into(field("split.mile"), "7.50")
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(ShotHelper.find_button(main, "Finish session"))
	await ShotHelper.frames(tree, 4)
	var r2 = last_run()
	var prs2 = reels[reels.size() - 1].events.filter(is_split)
	print("REEL 2 records ", prs2.map(func(e): return [e.title, e.detail]))
	var fast5 = prs2.filter(func(e): return str(e.title) == "Fastest 5K!")
	check(r2.get("splits") == {"mile": 470, "5k": 1499} and fast5.size() == 1 and str(fast5[0].detail).begins_with("24:59 (was 25:30)") and not prs2.any(func(e): return str(e.title) == "Fastest mile!"), "a faster 5K inside a 4 mile run: one record card for it, none for the slower mile")
	await ShotHelper.wait(tree, 1.2)
	await ShotHelper.snap(tree, "splits_6_record")
	await dismiss_results()

	# --- editing: the times are there; a shorter distance drops what no longer fits ---------------
	App.open_log("run", r.id)
	await ShotHelper.wait(tree, 0.7)
	check(rows_shown() == ["mile", "5k", "10k", "10mi"] and str(field("split.mile").text) == "7:45" and str(field("split.10mi").text) == "1:26:40" and echo("5k") == "25:30 · 8:12 /mi", "editing the half marathon: its splits are in their boxes")
	ShotHelper.type_into(field("split.mile"), "7.40")
	ShotHelper.type_into(field("distance"), "6")
	await ShotHelper.frames(tree, 3)
	check(rows_shown() == ["mile", "5k"], "made 6 miles: the 10K and the 10 mile no longer fit (%s)" % str(rows_shown()))
	ShotHelper.press(ShotHelper.find_button(main, "Save changes"))
	await ShotHelper.frames(tree, 4)
	var edited = App.session_by_id(r.id)
	check(edited != null and edited.get("splits") == {"mile": 460, "5k": 1530}, "saved: the mile as changed, the 5K kept, the others gone (%s)" % str(edited.get("splits") if edited != null else null))

	# --- kilometres: the kilometre in place of the mile; a ride has no splits -----------------------
	App.update_settings({"distanceUnit": "km"})
	App.open_log("run")
	await ShotHelper.wait(tree, 0.6)
	ShotHelper.type_into(field("distance"), "12")
	await ShotHelper.frames(tree, 3)
	check(rows_shown() == ["1k", "5k", "10k"], "in kilometres a 12 km run asks for the best km, 5K and 10K (%s)" % str(rows_shown()))
	await ShotHelper.snap(tree, "splits_7_km")
	App.open_log("ride")
	await ShotHelper.wait(tree, 0.6)
	ShotHelper.type_into(field("distance"), "40")
	await ShotHelper.frames(tree, 3)
	check(_find("splits_card") == null and rows_shown().is_empty(), "a ride has no split fields")
	App.open_log(null)
	App.go("home")
	await ShotHelper.wait(tree, 0.5)
	print("SPLITS %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
