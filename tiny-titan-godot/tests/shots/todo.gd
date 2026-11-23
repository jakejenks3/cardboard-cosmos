extends RefCounted
## The to-do list (run with the "year" data): the card on the Hero tab, its
## sheet, adding several items without the Add key moving, ticking one without
## the rows moving, the card showing the open ones and the one ticked today,
## clearing the done ones, taking one off, a long list that scrolls. None of it
## earns anything. Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


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


func _find(meta: String, root = null):
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			return n
	return null


func _all(meta: String, root) -> Array:
	return ShotHelper.walk(root).filter(func(n): return n.has_meta(meta))


func _row(root, id: String):
	for n in _all("todo_row", root):
		if str(n.get_meta("todo_row")) == id:
			return n
	return null


## Type an item into the sheet's box and press Add. Returns where the Add key
## was on the screen before and after ([y before, y after]).
func _add(text: String) -> Array:
	var sh = _sheet()
	var input = _find("todo_input", sh)
	var key = _find("todo_add", sh)
	var y0 = key.global_position.y
	ShotHelper.type_into(input, text)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.click(tree, key)
	await ShotHelper.wait(tree, 0.35)
	var key2 = _find("todo_add", _sheet())
	return [y0, key2.global_position.y]


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	var xp0 = int(App.state.xp.hero)
	var sessions0 = App.sessions().size()

	# --- the card, empty ------------------------------------------------------------------
	var card = _find("todo_card")
	check(card != null and ShotHelper.all_text(card).contains("Nothing on your list") and App.todos().is_empty(), "a To do card on the Hero tab, empty to start with")
	if card != null:
		ShotHelper.reveal(card)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "todo_1_card_empty")

	# --- the sheet: add three, the Add key stays put ---------------------------------------
	var plus = _find("todo_plus")
	check(plus != null, "a plus key on the card")
	if plus != null:
		await ShotHelper.click(tree, plus)
		await ShotHelper.wait(tree, 0.7)
	check(_sheet() != null and _find("todo_input", _sheet()) != null and _find("todo_add", _sheet()) != null, "it opens the list with a box to type in and an Add key")
	var moves = []
	for text in ["Buy chalk", "Email the landlord about the heating", "Book the dentist"]:
		var ys = await _add(text)
		moves.append(absf(float(ys[1]) - float(ys[0])))
	check(App.todos().size() == 3 and App.todos().map(func(t): return str(t.text)) == ["Buy chalk", "Email the landlord about the heating", "Book the dentist"], "three items added, in the order typed")
	check(moves.all(func(m): return float(m) < 1.5), "the Add key did not move while they were added (%s px)" % str(moves))
	check(str(_find("todo_input", _sheet()).text) == "", "the box is empty again for the next one")
	await ShotHelper.snap(tree, "todo_2_sheet_three")

	# --- tick one: it stays where it is, and so do the others --------------------------------
	var ids = App.todos().map(func(t): return str(t.id))
	var y_first = _row(_sheet(), ids[0]).global_position.y
	var y_third = _row(_sheet(), ids[2]).global_position.y
	await ShotHelper.click(tree, _row(_sheet(), ids[1]))
	await ShotHelper.wait(tree, 0.35)
	check(bool(App.todos()[1].done) and str(App.todos()[1].doneOn) == App.today and App.todos().map(func(t): return str(t.id)) == ids, "a tap ticks the item off; the list keeps its order")
	check(absf(_row(_sheet(), ids[0]).global_position.y - y_first) < 1.5 and absf(_row(_sheet(), ids[2]).global_position.y - y_third) < 1.5, "no row moved when it was ticked")
	check(ShotHelper.all_text(_sheet()).contains("2 open · 1 done"), "the sheet counts them: 2 open, 1 done")
	# The tick paid its small bonus, once, as a claim; the sheet says how many are left today.
	var bonus_claims = App.saved.claims.filter(func(c): return str(c.get("questId", "")) == "todo:" + ids[1])
	check(int(App.state.xp.hero) == xp0 + Todos.BONUS_XP and bonus_claims.size() == 1 and int(bonus_claims[0].xp) == Todos.BONUS_XP, "the tick paid +%d XP, as a claim" % Todos.BONUS_XP)
	var chips = {}
	for id in ids:
		for n in ShotHelper.walk(_row(_sheet(), id)):
			if n.has_meta("todo_bonus"):
				chips[id] = str(n.get_meta("todo_bonus"))
	check(chips.get(ids[1], "") == "earned" and chips.get(ids[0], "") == "open" and chips.get(ids[2], "") == "open" and ShotHelper.all_text(_sheet()).contains("+%d XP for each one ticked off · %d of %d left today" % [Todos.BONUS_XP, Todos.BONUS_A_DAY - 1, Todos.BONUS_A_DAY]), "its row shows the bonus as earned, the open ones as still to be had, and the sheet counts what is left today (%s)" % str(chips))
	await ShotHelper.snap(tree, "todo_3_sheet_ticked")
	await _close_sheets()

	# --- the card: the open ones and the one ticked today -------------------------------------
	App.go("home")
	await ShotHelper.wait(tree, 0.6)
	card = _find("todo_card")
	var card_rows = _all("todo_row", card) if card != null else []
	check(card_rows.size() == 3 and ShotHelper.all_text(card).contains("2 open") and ShotHelper.all_text(card).contains("Buy chalk"), "the card lists them, the one ticked today still in its place (%d rows)" % card_rows.size())
	if card != null:
		ShotHelper.reveal(card)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "todo_4_card")
		# Tick the first one right on the card.
		await ShotHelper.click(tree, _row(card, ids[0]))
		await ShotHelper.wait(tree, 0.5)
	card = _find("todo_card")
	check(bool(App.todos()[0].done) and card != null and _all("todo_row", card).size() == 3 and ShotHelper.all_text(card).contains("1 open"), "ticked on the card: done, and its row stays until tomorrow")
	check(int(App.state.xp.hero) == xp0 + 2 * Todos.BONUS_XP, "and it paid its bonus too")
	# Unticked and ticked again: nothing is taken back, nothing is paid twice.
	if card != null:
		ShotHelper.reveal(_row(card, ids[0]))
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, _row(_find("todo_card"), ids[0]))
		await ShotHelper.wait(tree, 0.6)
		var after_untick = int(App.state.xp.hero)
		var was_open = not bool(App.todos()[0].done)
		await ShotHelper.click(tree, _row(_find("todo_card"), ids[0]))
		await ShotHelper.wait(tree, 0.6)
		check(was_open and bool(App.todos()[0].done) and after_untick == xp0 + 2 * Todos.BONUS_XP and int(App.state.xp.hero) == xp0 + 2 * Todos.BONUS_XP, "unticked and ticked again: the XP stays as it was")
	card = _find("todo_card")
	if card != null:
		ShotHelper.reveal(card)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "todo_5_card_ticked")

	# --- clear the done ones, take the last one off ------------------------------------------
	await ShotHelper.click(tree, _find("todo_plus"))
	await ShotHelper.wait(tree, 0.7)
	var clear = _find("todo_clear", _sheet())
	check(clear != null and not clear.disabled, "a Clear done key")
	if clear != null:
		await ShotHelper.click(tree, clear)
		await ShotHelper.wait(tree, 0.6)
	check(App.todos().size() == 1 and str(App.todos()[0].text) == "Book the dentist", "Clear done takes the two ticked ones off; the open one is left")
	var x = _find("todo_remove", _sheet())
	if x != null:
		await ShotHelper.click(tree, x)
		await ShotHelper.wait(tree, 0.6)
	check(App.todos().is_empty(), "the cross takes an item off the list")

	# --- a long list: the sheet scrolls, and the Add key still stays put --------------------
	for i in range(14):
		App.add_todo("Thing number %d to get done this week" % (i + 1))
	await _close_sheets()
	await ShotHelper.click(tree, _find("todo_plus"))
	await ShotHelper.wait(tree, 0.7)
	var input = _find("todo_input", _sheet())
	if input != null:
		ShotHelper.reveal(input)
		await ShotHelper.frames(tree, 4)
	var long_moves = []
	for text in ["One more", "And another", "A last one, with rather a lot of words in it to see that a long item wraps onto a second line"]:
		var ys = await _add(text)
		long_moves.append(absf(float(ys[1]) - float(ys[0])))
	check(App.todos().size() == 17 and long_moves.all(func(m): return float(m) < 1.5), "a long list that scrolls: three more added, the Add key still did not move (%s px)" % str(long_moves))
	await ShotHelper.snap(tree, "todo_6_sheet_long")
	await _close_sheets()
	App.go("home")
	await ShotHelper.wait(tree, 0.6)
	card = _find("todo_card")
	check(card != null and _all("todo_row", card).size() == Todos.CARD_ROWS and ShotHelper.all_text(card).contains("+14 more"), "the card shows the first three and how many more")
	if card != null:
		ShotHelper.reveal(card)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "todo_7_card_long")

	check(int(App.state.xp.hero) == xp0 + 2 * Todos.BONUS_XP and App.sessions().size() == sessions0 and not App.quests().daily.any(func(m): return str(m.title).to_lower().contains("to do")), "two ticks paid a small bonus each; nothing was logged and no mission was made")
	print("TODO %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
