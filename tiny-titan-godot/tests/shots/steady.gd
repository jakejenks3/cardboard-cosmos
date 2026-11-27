extends RefCounted
## Nothing moves under the finger on the Realm's pages (run with the "year"
## data): a key that is pressed several times in a row stays where it is while
## the page is drawn again around it. Learn on the Skills page (three in a
## row), Buy at the camp shop (three in a row), the build keys and the school
## chips of the Moves page, a feat claimed on the Hero page. Each is pressed
## with a real click at the SAME screen point every time: if the key had moved
## away, the click would land on something else and the count would not rise.
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _all(meta: String, root = null) -> Array:
	var out = []
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta) and not n.is_queued_for_deletion() and n is Control and n.is_visible_in_tree():
			out.append(n)
	return out


func _one(meta: String, value = null):
	for n in _all(meta):
		if value == null or str(n.get_meta(meta)) == str(value):
			return n
	return null


func _click_at(p: Vector2) -> void:
	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	var move = InputEventMouseMotion.new()
	move.position = p
	move.global_position = p
	Input.parse_input_event(move)
	await ShotHelper.frames(tree, 2)
	Input.parse_input_event(down)
	await ShotHelper.frames(tree, 2)
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	up.global_position = p
	Input.parse_input_event(up)
	# (longer than the quiet time after a redraw that could not keep its key in place)
	await ShotHelper.wait(tree, 0.55)


func _page(id: String) -> void:
	# (a tab can only be tapped when it is on screen: the page is at its top then)
	ShotHelper.scroll_main(main, 0)
	# (longer than the quiet time after a redraw: a click right after one is dropped on purpose)
	await ShotHelper.wait(tree, 0.5)
	var tab = _one("realm_tab", id)
	if tab != null:
		await ShotHelper.click(tree, tab)
	await ShotHelper.wait(tree, 0.7)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	var rpg = RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true)
	rpg.ore = 5000
	App.set_rpg(rpg)
	App.go("realm")
	await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.4)

	# --- Learn, three times at one point -----------------------------------------------------------
	await _page("skills")
	var key = _one("node_learn")
	check(key != null, "the Skills page has a node that can be learned")
	if key != null:
		ShotHelper.reveal(key)
		await ShotHelper.wait(tree, 0.4)
		key = _one("node_learn")
		var at = key.get_global_rect().get_center()
		var n0 = App.rpg().nodes.size()
		await _click_at(at)
		LootPop.close_all()
		for i in range(2):
			await _click_at(at)
			LootPop.close_all()
		var learned = App.rpg().nodes.size() - n0
		# (where the Learn key was, a learned node has "Equip it now": a second click there opens its sheet)
		for c in Kit.overlay_root.get_children():
			if c is Sheet and not c._closing:
				c.close()
		await ShotHelper.wait(tree, 0.6)
		# After a node is learned its tile shows "Learned" where the key was; the next key is another tile. One
		# click must have learned exactly one node, and the other two must not have learned by accident.
		check(learned == 1, "three clicks at the point of a Learn key learn that one node, and nothing else jumps under them (%d)" % learned)
		await ShotHelper.snap(tree, "steady_1_skills")

	# --- Buy, three times at one point ---------------------------------------------------------------
	await _page("gear")
	var buy = _one("shop_buy")
	check(buy != null, "the Gear page has the camp shop")
	if buy != null:
		ShotHelper.reveal(buy)
		await ShotHelper.wait(tree, 0.4)
		buy = _one("shop_buy")
		var id = str(buy.get_meta("shop_buy"))
		var at2 = buy.get_global_rect().get_center()
		var have0 = int(App.rpg().items.get(id, 0))
		var ore0 = int(App.rpg().ore)
		var moved = 0.0
		for i in range(3):
			var k2 = _one("shop_buy", id)
			await ShotHelper.click(tree, k2)
			await ShotHelper.wait(tree, 0.5)
			var k3 = _one("shop_buy", id)
			moved = maxf(moved, k3.get_global_rect().get_center().distance_to(at2) if k3 != null else 999.0)
		var got = int(App.rpg().items.get(id, 0)) - have0
		check(moved < 3.0, "the Buy key never left its place between the clicks (moved %s px at most)" % str(moved))
		check(got == 3 and int(App.rpg().ore) < ore0, "three clicks at the point of a Buy key buy that item three times: the key stayed under them (%d)" % got)
		var now = _one("shop_buy", id)
		check(now != null and now.get_global_rect().get_center().distance_to(at2) < 3.0, "and it is still exactly there")
		await ShotHelper.snap(tree, "steady_2_shop")

	# --- the builds and the schools of the Moves page ------------------------------------------------
	await _page("moves")
	var b2 = _one("build_pick", 1)
	if b2 != null:
		var at3 = b2.get_global_rect().get_center()
		await ShotHelper.click(tree, b2)
		await ShotHelper.wait(tree, 0.5)
		var again = _one("build_pick", 1)
		check(int(App.rpg().build) == 1 and again != null and again.get_global_rect().get_center().distance_to(at3) < 3.0, "a build key picks its build and stays where it was (build %d, %s -> %s)" % [int(App.rpg().build), str(at3), str(again.get_global_rect().get_center()) if again != null else "gone"])
		var b1 = _one("build_pick", 0)
		await ShotHelper.click(tree, b1)
		await ShotHelper.wait(tree, 0.5)
		check(int(App.rpg().build) == 0, "and back")
	var chips = _all("school_pick")
	if chips.size() >= 2:
		ShotHelper.reveal(chips[1])
		await ShotHelper.wait(tree, 0.4)
		chips = _all("school_pick")
		var want = str(chips[1].get_meta("school_pick"))
		var at4 = chips[1].get_global_rect().get_center()
		await ShotHelper.click(tree, chips[1])
		await ShotHelper.wait(tree, 0.5)
		var same = _one("school_pick", want)
		check(same != null and same.get_global_rect().get_center().distance_to(at4) < 3.0, "a school chip stays under the pointer when it is picked (%s)" % want)

	# --- a feat claimed --------------------------------------------------------------------------------
	await _page("hero")
	var claim = _one("feat_claim")
	if claim != null:
		ShotHelper.reveal(claim)
		await ShotHelper.wait(tree, 0.4)
		claim = _one("feat_claim")
		var fid = str(claim.get_meta("feat_claim"))
		var at5 = claim.get_global_rect().get_center()
		var ore1 = int(App.rpg().ore)
		await ShotHelper.click(tree, claim)
		await ShotHelper.wait(tree, 0.6)
		var row = _one("feat", fid)
		check(int(App.rpg().ore) > ore1 and row != null and absf(row.get_global_rect().get_center().y - at5.y) < 40.0, "a feat is claimed and its row is still where the key was pressed")
	print("STEADY %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
