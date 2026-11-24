extends RefCounted
## How a new exercise typed in the Log tab will be filed (run with the "year"
## data, also with --fingers). "March - banded" is saved as the movement March
## with the variation Band, and the form says so while it is typed: at the
## search box, and under the name on its card. A name without a dash gets the
## tip; a lift that is in the log already says nothing; what the line says is
## what the saved workout holds. Prints CHECK lines.

const TYPED = "March - banded"
const FILED = "March - Band"

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _dismiss_reels() -> void:
	for k in range(6):
		var b = null
		for i in range(40):
			await ShotHelper.wait(tree, 0.4)
			b = ShotHelper.find_button(main, "Continue")
			if b != null and not b.disabled:
				break
		if b == null:
			return
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.5)


func _form():
	for n in ShotHelper.walk(main):
		if n is LogScreen:
			return n.form()
	return null


func _field(key: String):
	for n in ShotHelper.walk(main):
		if n is LineEdit and n.has_meta(LogWidgets.FKEY) and str(n.get_meta(LogWidgets.FKEY)) == key:
			return n
	return null


func _type(key: String, text: String) -> void:
	var box = _field(key)
	if box != null:
		ShotHelper.type_into(box, text)
	await ShotHelper.frames(tree, 4)


## The note under the search box, "" when it is not shown.
func _note() -> String:
	var ed = _form().lift
	return str(ed._no_match.text) if is_instance_valid(ed._no_match) and ed._no_match.visible else ""


## The "saved as" line of the first exercise card: what it says it will be
## saved as ("" when it is not shown), and its words.
func _line() -> Dictionary:
	var ed = _form().lift
	if ed._filed.is_empty() or not is_instance_valid(ed._filed[0]):
		return {"as": "", "words": "", "shown": false}
	var slot = ed._filed[0]
	var shown = slot.get_parent().visible
	return {"as": str(slot.get_meta("filed_as", "")) if shown else "", "words": ShotHelper.all_text(slot) if shown else "", "shown": shown}


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	await ShotHelper.wait(tree, 0.8)
	check(not App.lift_names().any(func(n): return str(n).to_lower().contains("march")), "the demo player has never done a march")
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.9)
	var form = _form()
	check(form != null and form.discipline == "lift" and form.editing == null, "a new lift in the Log tab")

	# --- at the search box --------------------------------------------------------------------------
	await _type("search", TYPED)
	check(_note() == "New exercise: tap Add. It is saved as March, variation Band.", "typed with a dash: the movement and its variation, said before it is added (%s)" % _note())
	check(str(form.lift._no_match.get_meta("filed_as", "")) == FILED, "as %s" % FILED)
	ShotHelper.reveal(form.lift._no_match)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "filed_1_search")
	await _type("search", "banded march")
	check(_note() == "New exercise: tap Add. It is saved as March, variation Band.", "an equipment word needs no dash (%s)" % _note())
	await _type("search", "high knee march")
	check(_note() == "New exercise: tap Add. It is saved as High Knee March, no variation. A variation goes after a dash: High Knee March - banded.", "other words without a dash are the movement: the note says how to write a variation (%s)" % _note())
	await _type("search", "March - high knee")
	check(_note() == "New exercise: tap Add. It is saved as March, variation High knee.", "after a dash they are the variation (%s)" % _note())
	await _type("search", "bench press")
	check(_note() == "", "a lift of the log is found, nothing to say (%s)" % _note())

	# --- on its card --------------------------------------------------------------------------------
	await _type("search", TYPED)
	ShotHelper.press(form.lift._add_btn)
	await ShotHelper.wait(tree, 0.6)
	form = _form()
	check(form.lift.exercises.size() == 1 and str(form.lift.exercises[0].name) == TYPED, "Add puts it on a card, named as it was typed (%s)" % str(form.lift.exercises.map(func(e): return str(e.name))))
	var line = _line()
	check(line.shown and line.as == FILED and line.words.contains("SAVED AS") and line.words.contains("March") and line.words.contains("Band"), "under the name: saved as March, with Band as its variation (%s)" % line.words.replace("\n", " | "))
	ShotHelper.reveal(_field("ex0.name"))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "filed_2_card")
	await _type("ex0.name", "high knee march")
	line = _line()
	check(line.as == "High Knee March" and line.words.contains("A variation goes after a dash"), "the line follows the name as it is typed, with the tip when there is no variation (%s)" % line.words.replace("\n", " | "))
	await ShotHelper.snap(tree, "filed_3_tip")
	await _type("ex0.name", "(PT) march - banded")
	line = _line()
	check(line.as == FILED and line.words.contains("PT"), "a (PT) in front is not part of the name: the line shows the PT tag (%s)" % line.words.replace("\n", " | "))
	await _type("ex0.name", "Bench Press - Barbell")
	check(not _line().shown, "a lift that is in the log already keeps its name: no line")
	await _type("ex0.name", "")
	check(not _line().shown, "an empty name: no line")
	await _type("ex0.name", TYPED)
	check(_line().as == FILED, "back to the march")

	# --- saved as the line said ---------------------------------------------------------------------
	await _type("ex0.s0.reps", "12")
	var save = ShotHelper.find_button(main, "Finish session")
	check(save != null and not save.disabled, "the workout can be finished")
	if save != null:
		ShotHelper.press(save)
	await ShotHelper.wait(tree, 0.6)
	await _dismiss_reels()
	var mine = App.lift_names().filter(func(n): return str(n).to_lower().contains("march"))
	check(mine == [FILED], "the saved workout holds it as %s (%s)" % [FILED, str(mine)])
	var sp = LiftNames.split(FILED)
	check(str(sp.move) == "March" and str(sp.variation) == "Band", "which is the movement March and the variation Band")

	# --- the next time ------------------------------------------------------------------------------
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.9)
	form = _form()
	await _type("search", "march")
	check(_note() == "" and form.lift._chips.get_children().any(func(c): return c is Button and str(c.text) == FILED), "the next time it is one of the keys to pick (%s)" % _note())
	await _type("search", "March - seated")
	check(_note() == "New exercise: tap Add. It is saved as March, variation Seated.", "another variation of it goes under the same movement (%s)" % _note())
	ShotHelper.reveal(form.lift._no_match)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "filed_4_second_variation")
	ShotHelper.press(form.lift._add_btn)
	await ShotHelper.wait(tree, 0.6)
	line = _line()
	check(line.as == "March - Seated" and not bool(_form().lift._filed[0].get_meta("filed_tip", false)), "and its card says so, without the tip (%s)" % line.words.replace("\n", " | "))
	App.draft_store("lift", null)
	App.open_log(null)
	App.go("home")
	await ShotHelper.wait(tree, 0.5)
	print("FILED WALK: %d failed" % fails)
