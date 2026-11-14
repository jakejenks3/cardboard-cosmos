class_name ShotHelper
extends RefCounted
## Helpers for the scripted walkthroughs in tests/shots/: screenshots, finding
## and pressing controls, and believable demo data. Not used by the game.


## Save a PNG of the whole window into $TINY_TITAN_SHOTS (or user://shots). Returns the path.
static func snap(tree: SceneTree, shot_name: String) -> String:
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var img = tree.root.get_texture().get_image()
	var dir = OS.get_environment("TINY_TITAN_SHOTS")
	if dir == "":
		dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	var path = dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("SHOT ", path)
	return path


static func wait(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds).timeout


static func frames(tree: SceneTree, n: int = 3) -> void:
	for i in range(n):
		await tree.process_frame


## Every visible node under `root` (depth first).
static func walk(root: Node, out: Array = []) -> Array:
	for c in root.get_children():
		if c is CanvasItem and not c.visible:
			continue
		out.append(c)
		walk(c, out)
	return out


## First visible Button whose text contains `text` (case-insensitive), or null.
static func find_button(root: Node, text: String):
	var want = text.to_lower()
	for n in walk(root):
		if n is Button and n.text.to_lower().contains(want):
			return n
	return null


## First visible Label / RichTextLabel containing `text`, or null.
static func find_text(root: Node, text: String):
	var want = text.to_lower()
	for n in walk(root):
		if (n is Label or n is RichTextLabel) and n.text.to_lower().contains(want):
			return n
	return null


## All visible text on screen, one item per line (for assertions and debugging).
static func all_text(root: Node) -> String:
	var parts = PackedStringArray()
	for n in walk(root):
		if n is Label or n is Button or n is LineEdit:
			if n.text != "":
				parts.append(n.text)
		elif n is RichTextLabel:
			parts.append(n.get_parsed_text())
	return "\n".join(parts)


## Press a Button exactly as a click would (does nothing if it is disabled).
static func press(b) -> bool:
	if b == null or not (b is BaseButton) or b.disabled:
		return false
	b.pressed.emit()
	return true


## Real mouse click in the middle of a control (for tappable Cards and custom controls).
static func click(tree: SceneTree, c: Control) -> void:
	var pos = c.get_global_rect().get_center()
	for down in [true, false]:
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = pos
		ev.global_position = pos
		tree.root.push_input(ev)
		await tree.process_frame


## Type into a LineEdit as a user would (fires text_changed).
static func type_into(e: LineEdit, text: String) -> void:
	e.text = text
	e.text_changed.emit(text)


## Scroll the nearest ScrollContainer so `c` is on screen.
static func reveal(c: Control) -> void:
	var p = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			p.ensure_control_visible(c)
			return
		p = p.get_parent()


## Set the vertical scroll of the main screen's ScrollContainer (pixels from the top).
static func scroll_main(root: Node, y: int) -> void:
	for n in walk(root):
		if n is ScrollContainer:
			n.scroll_vertical = y
			return


# ---------------------------------------------------------------------------
# Demo data
# ---------------------------------------------------------------------------

## A saved-state Dictionary for App.replace_all():
##   "new"  – a profile and nothing logged
##   "week" – a first week (4 sessions, one weigh-in)
##   "year" – about ten months of steady training with body check-ins
static func demo_saved(kind: String = "year") -> Dictionary:
	var out = App.empty_saved()
	var today = Dates.today_key()
	out.profile = {"name": "Jake", "skin": 1, "hairStyle": 1, "hairColor": 0, "createdAt": 1}
	if kind == "new":
		return out
	var days = 6 if kind == "week" else 300
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260101
	var n = 0
	for back in range(days, -1, -1):
		var date = Dates.add_days(today, -back)
		var progress = 1.0 - float(back) / float(maxi(days, 1))
		var wd = Dates.weekday_index(date)
		var created = 1700000000000 + (days - back) * 86400000
		var plan = ""
		if kind == "week":
			plan = ["lift", "", "run", "", "climb", "", "lift"][6 - back] if back <= 6 else ""
		else:
			# Mon lift, Tue run, Wed climb, Fri lift, Sat ride, with the odd missed day.
			plan = ["lift", "run", "climb", "", "lift", "ride", ""][wd]
			if plan != "" and rng.randf() < 0.14:
				plan = ""
		if plan == "":
			continue
		n += 1
		var s = {"id": "demo%04d" % n, "discipline": plan, "date": date, "createdAt": created + n, "source": "manual"}
		match plan:
			"lift":
				var bench = 40.0 + 45.0 * progress
				var squat = 50.0 + 70.0 * progress
				var dead = 60.0 + 90.0 * progress
				var a_day = n % 2 == 0
				var ex = []
				if a_day:
					ex.append({"name": "Bench Press", "sets": _sets(bench, 5, 3, rng)})
					ex.append({"name": "Squat", "sets": _sets(squat, 5, 3, rng)})
					ex.append({"name": "Pull-up", "sets": [{"reps": 5 + int(progress * 7), "weightKg": 0}, {"reps": 4 + int(progress * 6), "weightKg": 0}]})
				else:
					ex.append({"name": "Deadlift", "sets": _sets(dead, 3, 3, rng)})
					ex.append({"name": "Overhead Press", "sets": _sets(25.0 + 30.0 * progress, 6, 3, rng)})
					ex.append({"name": "Barbell Row", "sets": _sets(35.0 + 40.0 * progress, 8, 3, rng)})
				s["exercises"] = ex
				s["durationSec"] = 3000 + rng.randi_range(0, 1500)
			"climb":
				var top = int(round(1.0 + 4.5 * progress))
				var climbs = []
				climbs.append({"grade": maxi(-1, top - 3), "result": "flash", "count": 3})
				climbs.append({"grade": maxi(0, top - 2), "result": "flash", "count": 2})
				climbs.append({"grade": maxi(0, top - 1), "result": "send", "count": 2 + rng.randi_range(0, 2)})
				climbs.append({"grade": top, "result": "send" if rng.randf() < 0.6 else "attempt", "count": 1 + rng.randi_range(0, 1)})
				climbs.append({"grade": top + 1, "result": "attempt", "count": rng.randi_range(1, 3)})
				s["climbs"] = climbs
				s["durationSec"] = 4800 + rng.randi_range(0, 1800)
			"run":
				var km = 3.0 + 7.0 * progress + rng.randf_range(-1.0, 2.5)
				s["distanceM"] = int(km * 1000.0)
				s["elevationM"] = int(km * rng.randf_range(4.0, 14.0))
				s["durationSec"] = int(km * (390.0 - 60.0 * progress))
			"ride":
				var rkm = 18.0 + 40.0 * progress + rng.randf_range(-4.0, 12.0)
				s["distanceM"] = int(rkm * 1000.0)
				s["elevationM"] = int(rkm * rng.randf_range(6.0, 16.0))
				s["durationSec"] = int(rkm * (175.0 - 30.0 * progress))
		out.sessions.append(s)
		# A weigh-in most Sunday-ish weeks (attached to the Monday session date).
		if kind == "year" and plan == "lift" and wd == 0:
			var entry = {"id": "body%04d" % n, "date": date, "createdAt": created + n + 1, "weightKg": snappedf(84.0 - 6.5 * progress + rng.randf_range(-0.4, 0.4), 0.1)}
			if n % 3 == 0:
				entry["bodyFatPct"] = snappedf(24.0 - 7.0 * progress + rng.randf_range(-0.3, 0.3), 0.1)
			out.body.append(entry)
	if kind == "week":
		out.body.append({"id": "body0001", "date": Dates.add_days(today, -5), "createdAt": 1700000000000 + 86400000 + 500, "weightKg": 82.4})
	return out


static func _sets(top: float, reps: int, count: int, rng: RandomNumberGenerator) -> Array:
	var w = snappedf(top, 2.5)
	var sets = []
	for i in range(count):
		sets.append({"reps": maxi(1, reps - (1 if i == count - 1 and rng.randf() < 0.4 else 0)), "weightKg": w})
	return sets
