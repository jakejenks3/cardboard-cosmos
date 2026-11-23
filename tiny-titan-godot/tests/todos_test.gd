extends SceneTree
## Unit test for the to-do list (game/todos.gd), that a save keeps it
## (App.parse_saved) and that two copies of a save merge it (SaveMerge).
##   godot --headless --path . --script res://tests/todos_test.gd
## Prints TODOS: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_run()


func _run() -> void:
	var a = Todos.new_item("  Buy chalk\nand tape  ", 1000)
	ok(a.text == "Buy chalk and tape" and not a.done and a.doneOn == "" and int(a.at) == 1000 and str(a.id).begins_with("td") and Todos.new_item("x", 1).id != Todos.new_item("x", 1).id, "a new item: one trimmed line, not done, its own id", a)
	ok(Todos.clean("   ") == "" and Todos.clean("a".repeat(500)).length() == Todos.MAX_TEXT, "no words is nothing; long words are cut")
	var raw = [
		{"id": "t1", "text": "Email the landlord", "done": false, "at": 5.0, "doneOn": ""},
		{"id": "t2", "text": "Book the dentist", "done": true, "at": 6, "doneOn": "2026-11-22"},
		{"id": "t3", "text": "Old thing", "done": true, "at": 7, "doneOn": "2026-11-20"},
		{"id": "t4", "text": "   "}, {"text": "no id"}, "not an item", {"id": 5, "text": "a number for an id"},
		{"id": "t5", "text": "Just words"},
	]
	var list = Todos.parse(raw)
	ok(list.map(func(t): return str(t.id)) == ["t1", "t2", "t3", "t5"] and list[0].at is int and int(list[0].at) == 5 and not list[3].done and list[3].doneOn == "" and int(list[3].at) == 0, "the saved list, cleaned: only items with an id and words", list)
	ok(Todos.parse(null).is_empty() and Todos.parse({"a": 1}).is_empty(), "anything that is not a list is no list")
	ok(Todos.open_count(list) == 2 and Todos.done_count(list) == 2, "open and done are counted")
	ok(Todos.shown(list, "2026-11-22").map(func(t): return str(t.id)) == ["t1", "t2", "t5"] and Todos.shown(list, "2026-11-23").map(func(t): return str(t.id)) == ["t1", "t5"], "the card: the open ones, and one ticked today stays until tomorrow")

	# A save keeps the list (the App autoload is there a frame after the start).
	await process_frame
	var app = root.get_node_or_null("App")
	if app == null:
		print("SKIP  the save file: no App")
	else:
		var saved = app.parse_saved({"sessions": [], "todos": raw})
		ok(saved != null and saved.todos.map(func(t): return str(t.id)) == ["t1", "t2", "t3", "t5"], "a save file keeps its to-do list", saved.todos if saved != null else null)
		ok(app.parse_saved({"sessions": []}).todos.is_empty() and app.empty_saved().todos.is_empty(), "a save from before has an empty one")
		# The commands: add, tick, untick, take off, clear the done ones.
		app.replace_all(app.empty_saved())
		ok(app.add_todo("   ") == null and app.todos().is_empty(), "no words: nothing is added")
		var one = app.add_todo("Buy chalk")
		var two = app.add_todo("Email the landlord")
		var three = app.add_todo("Book the dentist")
		ok(app.todos().map(func(t): return str(t.text)) == ["Buy chalk", "Email the landlord", "Book the dentist"], "items are kept in the order added", app.todos())
		app.set_todo_done(str(two.id), true)
		ok(app.todos()[1].done and app.todos()[1].doneOn == app.today and app.todos().map(func(t): return str(t.id)) == [one.id, two.id, three.id], "ticked: done today, and it stays where it is")
		app.set_todo_done(str(two.id), false)
		ok(not app.todos()[1].done and app.todos()[1].doneOn == "", "unticked again")
		app.set_todo_done(str(one.id), true)
		app.set_todo_done(str(three.id), true)
		app.remove_todo(str(three.id))
		ok(app.todos().map(func(t): return str(t.id)) == [one.id, two.id], "one taken off the list")
		ok(app.clear_done_todos() == 1 and app.todos().map(func(t): return str(t.id)) == [two.id] and app.clear_done_todos() == 0, "the done ones cleared: the open one is left")
		var again = app.parse_saved(JSON.parse_string(JSON.stringify(app.saved)))
		ok(again != null and again.todos.size() == 1 and again.todos[0].text == "Email the landlord", "and the list is in what gets saved", again.todos if again != null else null)
		ok(int(app.state.xp.hero) == 0 and app.state.totals.sessions == 0, "none of it earns anything")

	# Two copies of a save: an item added on each, one ticked on one side, one removed on the other.
	var base = {"updatedAt": 10, "sessions": [], "todos": [list[0], list[1], list[3]]}
	var mine = {"updatedAt": 20, "sessions": [], "todos": [{"id": "t1", "text": "Email the landlord", "done": true, "at": 5, "doneOn": "2026-11-23"}, list[1], list[3], {"id": "m1", "text": "Added here", "done": false, "at": 20, "doneOn": ""}]}
	var theirs = {"updatedAt": 30, "sessions": [], "todos": [list[0], list[3], {"id": "x1", "text": "Added there", "done": false, "at": 30, "doneOn": ""}]}
	var merged = SaveMerge.merge(base, mine, theirs)
	var ids = merged.todos.map(func(t): return str(t.id))
	ok(ids.has("m1") and ids.has("x1") and ids.has("t5") and not ids.has("t2"), "merged: both new items are there, the one removed is gone", ids)
	ok(merged.todos.filter(func(t): return str(t.id) == "t1")[0].done, "and the tick made on one side is kept", merged.todos)

	print("TODOS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
