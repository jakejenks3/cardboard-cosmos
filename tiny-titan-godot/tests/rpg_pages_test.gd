extends SceneTree
## Test of the Realm's four pages (RPG_PLAN.md 10.1): Hero, Moves, Skills, Gear
## (ui/rpg/realm_hero.gd, realm_moves.gd, realm_skills.gd, realm_gear.gd), built
## for real, headless, into a 412-wide column, and used by pressing the keys a
## player has.
##   - a save with no training and a fresh Realm, a year of training with a
##     fresh Realm, and a rich Realm made with RpgSave calls (skills learned,
##     gear upgraded, a rune socketed, relics, items, ore): every section is
##     there, nothing is wider than 412, sections do not overlap, and with
##     Kit.fingers every key is at least 40 high;
##   - a fresh save explains every empty part in a line;
##   - the keys do the real thing in App.rpg(): pick and rename a build, equip
##     a move through the pick sheet, empty a slot, equip from ALL MOVES, learn
##     a node from its tile and from its sheet, a blocked node says why, reset,
##     wear, upgrade (and not without ore), socket and scrap a rune, pick a
##     relic, a companion, a belt item, buy from the camp shop.
## The pages' classes name the App autoload, which is only there a frame after
## the start: they are loaded by path once App is up, never named here.
##   godot --headless --path . --script res://tests/rpg_pages_test.gd
## TINY_TITAN_DATA must point at a throwaway folder: the test replaces the save.
## Made-up data. Prints RPG PAGES: n/m passed and exits with 1 when anything fails.

const W = 412.0

var passed = 0
var total = 0
var app = null
var kit = null
var ui = null
var host: Control = null
var holder: Control = null
var box: VBoxContainer = null
var screen = null
var pages = {}
var current = ""
var dirty = false

const SECTIONS = {
	"hero": ["realm_body", "realm_traits", "realm_fight", "realm_boosts", "realm_journey"],
	"moves": ["moves_build", "moves_all"],
	"skills": ["skills_head", "skills_board"],
	"gear": ["gear_worn", "gear_relics", "gear_pet", "gear_belt", "gear_runes", "gear_shop"],
}


## What the pages are handed as their screen: `rebuild()` draws the page again
## (the real RealmScreen does that, also whenever the Realm's save changes).
class StubScreen extends Control:
	var on_rebuild: Callable = Callable()
	func rebuild() -> void:
		if on_rebuild.is_valid():
			on_rebuild.call()


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _all(n: Node, out: Array = []) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _is(n, class_id: String) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var sc = n.get_script()
	while sc != null:
		if str(sc.get_global_name()) == class_id:
			return true
		sc = sc.get_base_script()
	return false


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


## Every node under `root` with the meta `key` (equal to `value` when one is given).
func _metas(root: Node, key: String, value = null) -> Array:
	return _all(root).filter(func(c): return c.has_meta(key) and (value == null or (typeof(c.get_meta(key)) == typeof(value) and c.get_meta(key) == value)))


func _meta(root: Node, key: String, value = null):
	var found = _metas(root, key, value)
	return found[0] if not found.is_empty() else null


## Everything a player could read under `n`.
func _words(n: Node) -> String:
	var out = []
	for c in _all(n):
		if (c is Label or c is Button or c is LineEdit) and str(c.text) != "":
			out.append(str(c.text))
	return "\n".join(out)


func _mark_dirty() -> void:
	dirty = true


## Draw the page in view again.
func _refill() -> void:
	dirty = false
	if box != null and is_instance_valid(box):
		holder.remove_child(box)
		box.free()
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.position = Vector2.ZERO
	box.size = Vector2(W, 0)
	holder.add_child(box)
	pages[current].fill(box, screen)
	box.size = Vector2(W, 0)


func _show(page: String) -> void:
	current = page
	_refill()
	await _frames(3)
	box.size = Vector2(W, 0)
	await _frames(1)


## After a key: the screen draws itself again when the save changed.
func _settle() -> void:
	await _frames(1)
	if dirty:
		_refill()
	await _frames(3)
	box.size = Vector2(W, 0)
	await _frames(1)


func _press(b) -> void:
	if b != null and is_instance_valid(b):
		b.pressed.emit()
	await _settle()


## A tap on a card (its own callable).
func _tap(card) -> void:
	if card != null and is_instance_valid(card) and card._tap.is_valid():
		card._tap.call()
	await _settle()


## The sheets that are open, the newest last.
func _sheets() -> Array:
	return host.get_children().filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion() and _is(c, "Sheet") and not c._closing)


## A sheet that was closed (it frees itself once it has slid away).
func _gone(sh) -> bool:
	return sh == null or not is_instance_valid(sh) or sh._closing


func _sheet():
	var all = _sheets()
	return all[all.size() - 1] if not all.is_empty() else null


func _close_sheets() -> void:
	for c in host.get_children():
		if _is(c, "Sheet"):
			host.remove_child(c)
			c.free()
	await _frames(1)


## The controls under `root` that reach past the column (or start left of it).
func _wide(root: Control, left: float, right: float) -> Array:
	var out = []
	for c in _all(root):
		if not (c is Control) or not c.is_visible_in_tree():
			continue
		var r = c.get_global_rect()
		if r.size.x <= 0.0:
			continue
		if r.end.x > right + 0.5 or r.position.x < left - 0.5:
			out.append("%s %d..%d" % [c.get_class(), int(r.position.x), int(r.end.x)])
	return out


## The keys under `root` lower than `least`.
func _low_keys(root: Node, least: float) -> Array:
	var out = []
	for c in _all(root):
		if c is BaseButton and c.is_visible_in_tree() and c.size.y < least - 0.5:
			out.append("%s %d" % [str(c.text) if c is Button else c.get_class(), int(c.size.y)])
	return out


## The layout of the page in view: its sections, its width, no section over another.
func _check_page(tag: String) -> void:
	var want = SECTIONS[current]
	var have = _metas(box, "section").map(func(c): return str(c.get_meta("section")))
	ok(want.all(func(id): return have.has(id)), "%s: every section of the %s page is there" % [tag, current], [want, have])
	ok(box.get_combined_minimum_size().x <= W + 0.5 and box.size.x <= W + 0.5, "%s: the %s page needs no more than 412" % [tag, current], [box.get_combined_minimum_size().x, box.size.x])
	var wide = _wide(box, box.global_position.x, box.global_position.x + W)
	ok(wide.is_empty(), "%s: nothing on the %s page reaches past the column" % [tag, current], wide.slice(0, 6))
	var secs = _metas(box, "section")
	var over = []
	for i in range(1, secs.size()):
		if secs[i].get_global_rect().position.y < secs[i - 1].get_global_rect().end.y + 21.5:
			over.append(str(secs[i].get_meta("section")))
	ok(over.is_empty() and secs.all(func(s): return s.size.y > 40.0), "%s: the %s page's sections follow each other, none empty" % [tag, current], over)
	if kit.fingers:
		var low = _low_keys(box, 40.0)
		ok(low.is_empty(), "%s: with fingers every key of the %s page is 40 high or more" % [tag, current], low.slice(0, 8))
	_dump(tag)
	if current == "skills":
		var heights = _metas(box, "node").map(func(t): return int(round(t.size.y)))
		ok(not heights.is_empty() and heights.min() == heights.max(), "%s: every node tile is one size" % tag,
			_metas(box, "node").filter(func(t): return int(round(t.size.y)) != heights.min()).map(func(t): return [t.get_meta("node"), t.get_meta("node_state"), t.size.y, t.box.get_children().map(func(c): return c.size.y)]))


## An open sheet stays inside the column (and its keys are finger-high).
func _check_sheet(tag: String) -> void:
	var sh = _sheet()
	ok(sh != null, "%s: a sheet is open" % tag)
	if sh == null:
		return
	_dump(tag)
	var wide = _wide(sh.box, host.global_position.x, host.global_position.x + W)
	ok(wide.is_empty() and sh.box.get_child_count() > 0, "%s: the sheet fits the column and is not empty" % tag, wide.slice(0, 6))
	if kit.fingers:
		var low = _low_keys(sh.box, 40.0)
		ok(low.is_empty(), "%s: with fingers the sheet's keys are 40 high or more" % tag, low.slice(0, 6))


## With RPG_PAGES_DUMP set: what a reader of the log needs to picture the page
## in view (nobody sees a headless page): each section's height, and every
## one-line label that is cut off with "..." (its words, the room it has, the
## room it wants).
func _dump(tag: String) -> void:
	if OS.get_environment("RPG_PAGES_DUMP") == "":
		return
	print("--- %s / %s: %d high" % [tag, current, int(box.size.y)])
	for sec in _metas(box, "section"):
		print("   section %s: %d x %d" % [str(sec.get_meta("section")), int(sec.size.x), int(sec.size.y)])
	for key in ["hero_stat", "hero_figure", "fight_num", "move_slot", "node", "tier_band", "gear_doll", "gear_slot", "pet_pick", "shop_buy", "build_pick", "school_pick"]:
		var first = _meta(box, key)
		if first != null:
			print("   first %s: %d x %d at %d, %d" % [key, int(first.size.x), int(first.size.y), int(first.global_position.x), int(first.global_position.y)])
	var roots = [box]
	if _sheet() != null:
		roots = [_sheet().box]
	for r in roots:
		for c in _all(r):
			if c is Label and c.clip_text and c.is_visible_in_tree() and c.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var want = c.get_theme_font("font").get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x
				if want > c.size.x + 1.0:
					print("   cut: \"%s\" has %d of %d" % [c.text, int(c.size.x), int(want)])
			elif c is Button and c.clip_text and c.is_visible_in_tree() and c.text != "":
				var want_b = c.get_theme_font("font").get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x
				if want_b > c.size.x - 16.0:
					print("   cut key: \"%s\" has %d of %d" % [c.text, int(c.size.x), int(want_b)])


func _build() -> Dictionary:
	return RpgSave.build_of(app.rpg())


func _xp_for(level: int) -> int:
	var xp = 0
	for l in range(1, level):
		xp += RpgDefs.xp_to_next(l)
	return xp


## A Realm with things in it, made with the real transitions.
func _rich() -> Dictionary:
	var sheet = ui.sheet()
	var days = ui.days()
	var have = ui.owned()
	var r = RpgSave.empty()
	r.opened = true
	r.xp = _xp_for(12) + 5
	r.ore = 6000
	r = RpgSave.first_open(r, app.loadout(), app.active_pet())
	# One piece of gear in every slot the player owns something for.
	for id in have.items:
		var g = RpgGear.of(str(id))
		if g != null and not RpgSave.build_of(r).gear.has(str(g.slot)):
			r = RpgSave.equip_gear(r, str(g.slot), str(id), have.items).rpg
	for i in range(5):
		var can = RpgSkills.learnable(r, sheet, RpgSave.level_of(r), days)
		if can.is_empty():
			break
		r = RpgSave.learn(r, str(can[0]), sheet, days).rpg
	r.runes = [{"id": "rnA", "k": "atk_push", "v": 1.5, "rarity": "rare"}, {"id": "rnB", "k": "hp", "v": 12.0, "rarity": "common"},
		{"id": "rnC", "k": "crit", "v": 0.02, "rarity": "epic"}]
	var worn = RpgGear.worn(RpgSave.build_of(r).gear, have.items)
	if not worn.is_empty():
		r = RpgSave.upgrade(r, str(worn[0]), "", have.items).rpg
		r = RpgSave.upgrade(r, str(worn[0]), "", have.items).rpg
		r = RpgSave.socket(r, str(worn[0]), "rnA").rpg
	var relics = RpgRelics.all()
	r.relics = {str(relics[0].id): true, str(relics[1].id): true, str(relics[relics.size() - 1].id): true}
	r = RpgSave.equip_relic(r, 0, str(relics[0].id)).rpg
	r = RpgSave.buy_item(r, "protein_shake", 3).rpg
	r = RpgSave.buy_item(r, "chalk_ball", 1).rpg
	r = RpgSave.set_belt(r, 0, "protein_shake").rpg
	r = RpgSave.rename_build(r, 1, "Long build name of 24 ch").rpg
	return r


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	app = root.get_node_or_null("App")
	if app == null or OS.get_environment("TINY_TITAN_DATA") == "":
		print("RPG PAGES: needs the App autoload and TINY_TITAN_DATA")
		quit(1)
		return
	kit = load("res://ui/kit.gd")
	ui = load("res://ui/rpg/rpg_ui.gd")
	pages = {"hero": load("res://ui/rpg/realm_hero.gd"), "moves": load("res://ui/rpg/realm_moves.gd"),
		"skills": load("res://ui/rpg/realm_skills.gd"), "gear": load("res://ui/rpg/realm_gear.gd")}
	var shots = load("res://tests/shot_helper.gd")
	ok(pages.values().all(func(s): return s != null and s.can_instantiate()), "the four page scripts load")
	host = Control.new()
	host.size = Vector2(W, 900)
	root.add_child(host)
	holder = Control.new()
	holder.size = Vector2(W, 900)
	host.add_child(holder)
	kit.overlay_root = host
	kit.fingers = false
	screen = StubScreen.new()
	screen.on_rebuild = _mark_dirty
	host.add_child(screen)
	app.rpg_changed.connect(_mark_dirty)

	# =================================================================================================
	# A player with nothing: no training at all, a fresh Realm
	# =================================================================================================
	app.replace_all(app.empty_saved())
	ui.drop_cache()
	app.set_rpg(RpgSave.empty())
	pages.skills.board = ""
	for fingers in [false, true]:
		kit.fingers = fingers
		for page in ["hero", "moves", "skills", "gear"]:
			await _show(page)
			_check_page("nothing yet%s" % (", fingers" if fingers else ""))
	kit.fingers = false
	await _show("hero")
	ok(_metas(box, "hero_stat").size() == 12 and _metas(box, "fight_num").size() == 7, "nothing yet: twelve stats and seven fight numbers all the same", [_metas(box, "hero_stat").size(), _metas(box, "fight_num").size()])
	ok((ui.boosts().is_empty() and _meta(box, "realm_empty", "boosts_none") != null) or (not ui.boosts().is_empty() and _metas(box, "hero_boost").size() == ui.boosts().size()),
		"nothing yet: the boosts are listed, or a line says what earns one")
	await _show("moves")
	ok(_metas(box, "move_slot").size() == 5 and _metas(box, "move_slot").filter(func(c): return c.has_meta("realm_locked")).size() == 1, "nothing yet: four move slots and a locked fifth")
	ok(_metas(box, "move_slot").slice(0, 4).map(func(c): return str(c.get_meta("slot_holds"))) == ["shove", "yank", "stomp", "deep_breath"], "nothing yet: the four starters are in the build", _metas(box, "move_slot").map(func(c): return c.get_meta("slot_holds", "?")))
	ok(_words(_metas(box, "move_slot")[4]).contains("fighter level %d" % RpgDefs.MOVE_SLOT_5_AT), "the locked fifth slot says its level", _words(_metas(box, "move_slot")[4]))
	ok(_meta(box, "realm_empty", "ult_slot") != null and _words(_meta(box, "ult_slot")).contains("fifth tier"), "nothing yet: the empty ultimate slot says where one comes from", _words(_meta(box, "ult_slot")))
	ok(_metas(box, "passive_slot").size() == 3 and _metas(box, "passive_slot").all(func(c): return c.has_meta("realm_locked")) and _words(_metas(box, "passive_slot")[0]).contains("fighter level %d" % int(RpgDefs.PASSIVE_SLOTS_AT[0])),
		"nothing yet: three locked passive slots, each with its level", _words(_metas(box, "passive_slot")[0]))
	await _show("skills")
	var pts0 = ui.points()
	ok(int(_meta(box, "skills_left").get_meta("skills_left")) == int(pts0.left) and int(pts0.left) == 3 and _meta(box, "skills_left").text == "3", "nothing yet: 3 skill points, shown big", pts0)
	ok(_words(_meta(box, "section", "skills_head")).contains("3 to start") and _words(_meta(box, "section", "skills_head")).contains("Nothing learned yet"), "the points say where they came from, and that nothing is learned", _words(_meta(box, "section", "skills_head")))
	ok(_meta(box, "skills_reset").disabled, "nothing learned: Reset all is switched off")
	await _show("gear")
	var notes = _metas(box, "realm_empty").map(func(c): return str(c.get_meta("realm_empty")))
	var want_notes = ["gear_none", "sets_none", "relics_none", "pet_none", "belt_none", "runes_none", "shop_no_ore"]
	ok(want_notes.all(func(n): return notes.has(n)), "nothing yet: every empty part of the Gear page explains itself in a line", notes)
	ok(_metas(box, "realm_empty").all(func(c): return c is Label and str(c.text).length() > 20), "those lines are real sentences")
	ok(_metas(box, "gear_slot").size() == 10 and _metas(box, "gear_slot").all(func(c): return str(c.get_meta("gear_holds")) == ""), "nothing yet: the doll has its nine slots and the companion, all empty")
	ok(_metas(box, "shop_buy").size() == 8, "the camp shop sells its eight items", _metas(box, "shop_buy").size())
	var before_buy = JSON.stringify(app.rpg())
	await _press(_meta(box, "shop_buy", "protein_shake"))
	ok(JSON.stringify(app.rpg()) == before_buy, "without ore the shop sells nothing")
	await _tap(_meta(box, "gear_slot", "head"))
	ok(_sheet() != null and _meta(_sheet().box, "realm_empty", "slot_none") != null, "a slot with no gear owned says where gear comes from")
	await _close_sheets()

	# =================================================================================================
	# A year of training, a fresh Realm
	# =================================================================================================
	app.replace_all(shots.demo_saved("year"))
	ui.drop_cache()
	app.set_rpg(RpgSave.empty())
	pages.skills.board = ""
	pages.skills.fresh = ""
	for fingers in [false, true]:
		kit.fingers = fingers
		for page in ["hero", "moves", "skills", "gear"]:
			await _show(page)
			_check_page("a year, fresh Realm%s" % (", fingers" if fingers else ""))
	kit.fingers = false
	var sheet = ui.sheet()
	await _show("skills")
	ok(str(_meta(box, "section", "skills_board").get_meta("board")) == pages.skills.best_board(sheet), "the first board shown is the one of the hero's highest stat", [pages.skills.board, pages.skills.best_board(sheet)])
	ok(int(ui.points().left) > 3 and _words(_meta(box, "section", "skills_head")).contains("%d from training days" % int(ui.points().from.days)), "training days have earned skill points, and the page says how many", ui.points())
	await _show("gear")
	ok(_meta(box, "realm_empty", "pet_unpicked") != null or _meta(box, "realm_empty", "pet_none") != null, "a fresh Realm has no companion picked, and says so")

	# =================================================================================================
	# A rich Realm
	# =================================================================================================
	app.set_rpg(_rich())
	pages.skills.board = ""
	pages.moves.school = "push"
	for fingers in [false, true]:
		kit.fingers = fingers
		for page in ["hero", "moves", "skills", "gear"]:
			await _show(page)
			_check_page("rich%s" % (", fingers" if fingers else ""))
	kit.fingers = false

	# --- HERO ----------------------------------------------------------------------------------------
	await _show("hero")
	var body = _meta(box, "section", "realm_body")
	var tiles = _metas(body, "hero_stat")
	ok(tiles.size() == 6 and tiles.map(func(c): return str(c.get_meta("hero_stat"))) == RpgDefs.BODY, "BODY: the six body stats", tiles.map(func(c): return c.get_meta("hero_stat")))
	var fig = _meta(body, "hero_figure")
	var lefts = tiles.slice(0, 3)
	var rights = tiles.slice(3, 6)
	ok(fig != null and lefts.all(func(c): return c.get_global_rect().end.x <= fig.get_global_rect().position.x + 0.5) and rights.all(func(c): return c.get_global_rect().position.x >= fig.get_global_rect().end.x - 0.5),
		"three stats on each side of the hero, none over the figure")
	ok(tiles.all(func(c): return c.size.x >= 96.0) and absf(lefts[0].size.x - rights[0].size.x) <= 1.5 and fig.size.x >= 128.0, "the two columns are the same width and wide enough to read", [lefts[0].size.x, fig.size.x, rights[0].size.x])
	var over_y = []
	for col in [lefts, rights]:
		for i in range(1, col.size()):
			if col[i].get_global_rect().position.y < col[i - 1].get_global_rect().end.y - 0.5:
				over_y.append(i)
	ok(over_y.is_empty(), "the tiles of a column do not overlap")
	var st_legs = sheet.stats.legs
	var legs_tile = _meta(body, "hero_stat", "legs")
	ok(_words(legs_tile).contains("Legs") and _words(legs_tile).contains(pages.hero.one(float(st_legs.raw))), "a tile shows the stat's name and its value to one decimal", _words(legs_tile))
	var gains = RpgDefs.STATS.filter(func(id): return float(sheet.stats[id].raw) - float(sheet.stats[id].was) >= 0.05)
	ok(_metas(box, "hero_gain").size() == gains.size(), "\"+N this week\" on exactly the stats that grew", [_metas(box, "hero_gain").size(), gains])
	ok(_metas(_meta(box, "section", "realm_traits"), "hero_stat").map(func(c): return str(c.get_meta("hero_stat"))) == RpgDefs.TRAITS, "TRAITS: the six traits as rows")
	ok(_metas(box, "hero_next").size() == 12, "every stat has its bar to the next point")
	await _tap(legs_tile)
	_check_sheet("the stat's sheet")
	var ssh = _sheet()
	ok(ssh != null and str(ssh.box.get_meta("hero_stat_sheet", "")) == "legs" and _words(ssh.box).contains(str(RpgDefs.STAT_DOES.legs)), "a tap on a stat opens its sheet: what it does in a fight", _words(ssh.box) if ssh != null else "")
	ok(ssh != null and st_legs.lines.all(func(l): return _words(ssh.box).contains(str(l))) and (str(st_legs.next) == "" or _words(ssh.box).contains(str(st_legs.next))), "its lines and what raises it")
	var tier_rows = _metas(ssh.box, "stat_tier") if ssh != null else []
	ok(not tier_rows.is_empty() and tier_rows.all(func(r): return bool(r.get_meta("stat_tier_met")) == (int(st_legs.v) >= int(RpgDefs.REQ[int(r.get_meta("stat_tier"))])))
		and _words(ssh.box).contains("skills open at %d" % int(RpgDefs.REQ[int(tier_rows[0].get_meta("stat_tier"))])), "the skill tiers it has reached, against RpgDefs.REQ", tier_rows.size())
	await _close_sheets()
	var nums = _metas(box, "fight_num").map(func(c): return str(c.get_meta("fight_num")))
	ok(nums == ["power", "hp", "def", "spd", "crit", "dodge", "energy"], "IN A FIGHT: power, HP, defence, speed, crit, dodge, energy", nums)
	var numbers = RpgHero.numbers(ui.hero())
	ok(_words(_meta(box, "fight_num", "hp")).contains(Xp.fmt_int(int(numbers.hp))) and _metas(box, "fight_num").all(func(c): return _words(c).length() > 20), "each with its number and a line on where it comes from", _words(_meta(box, "fight_num", "hp")))
	var boosts = ui.boosts()
	ok((boosts.is_empty() and _meta(box, "realm_empty", "boosts_none") != null) or _metas(box, "hero_boost").size() == boosts.size(), "BOOSTS: every boost, or what earns one")
	for b in boosts:
		var row = _meta(box, "hero_boost", str(b.id))
		ok(row != null and _words(row).contains(str(b.name)) and _words(row).contains(str(b.text)) and _words(row).contains(str(b.why)) and (_words(row).contains("until tomorrow") or _words(row).contains("ends today")),
			"the boost %s in full: name, text, why, until" % str(b.id))

	# --- MOVES ---------------------------------------------------------------------------------------
	await _show("moves")
	ok(_metas(box, "build_pick").size() == 3 and _metas(box, "build_pick").filter(func(c): return bool(c.get_meta("build_on"))).size() == 1, "three builds, one picked")
	ok(_meta(box, "build_pick", 1).text == "Long build name of 24 ch" and _meta(box, "build_pick", 1).size.x < 160.0, "a long build name is cut off, not let widen the track", _meta(box, "build_pick", 1).size.x)
	await _press(_meta(box, "build_pick", 1))
	ok(int(app.rpg().build) == 1 and bool(_meta(box, "build_pick", 1).get_meta("build_on")), "picking a build: App.rpg().build is 1 and its key is the raised one")
	await _press(_meta(box, "build_pick", 0))
	ok(int(app.rpg().build) == 0, "and back to the first")
	await _press(_meta(box, "build_rename"))
	var rsh = _sheet()
	ok(rsh != null and _meta(rsh.box, "build_name_box") != null, "Rename opens a sheet with a box")
	if rsh != null:
		_meta(rsh.box, "build_name_box").text = "Heavy day"
		await _press(_meta(rsh.box, "build_rename_save"))
	ok(str(app.rpg().builds[0].name) == "Heavy day" and _meta(box, "build_pick", 0).text == "Heavy day", "the build is renamed, on the page too", app.rpg().builds[0].name)
	await _close_sheets()

	var known = RpgSkills.known_moves(app.rpg())
	var spare = known.filter(func(id): return not _build().moves.has(id))
	ok(not spare.is_empty(), "the rich save knows moves that are not in the build", known)
	await _tap(_meta(box, "move_slot", 1))
	_check_sheet("the pick sheet")
	var psh = _sheet()
	ok(psh != null and str(psh.box.get_meta("pick_sheet", "")) == "move:1", "a tap on a move slot opens its pick sheet")
	var picks = _metas(psh.box, "pick_move").map(func(c): return str(c.get_meta("pick_move")))
	ok(picks.size() == known.size() + 1 and known.all(func(id): return picks.has(id)) and picks[picks.size() - 1] == "", "it lists every known move and an Empty key", picks)
	var first_used = picks.find(str(_build().moves[0]))
	ok(spare.all(func(id): return picks.find(id) < first_used), "moves not yet in the build come first")
	ok(_words(_meta(psh.box, "pick_move", str(_build().moves[1]))).contains("HERE") and _words(_meta(psh.box, "pick_move", str(_build().moves[0]))).contains("SLOT 1"), "the equipped ones are marked: HERE, SLOT 1")
	var want_move = str(spare[0])
	await _tap(_meta(psh.box, "pick_move", want_move))
	ok(str(_build().moves[1]) == want_move and _gone(psh), "picking one puts it into the slot and closes the sheet", _build().moves)
	ok(str(_meta(box, "move_slot", 1).get_meta("slot_holds")) == want_move, "the page shows it in slot 2")
	await _close_sheets()
	await _tap(_meta(box, "move_slot", 3))
	await _press(_meta(_sheet().box, "pick_move", ""))
	ok(str(_build().moves[3]) == "" and _meta(_meta(box, "move_slot", 3), "realm_empty") != null, "Empty this slot clears it, and the empty slot says what goes there", _build().moves)
	await _close_sheets()

	ok(_metas(box, "school_pick").size() == 8 and _metas(box, "school_pick").map(func(c): return str(c.get_meta("school_pick"))) == RpgDefs.SCHOOLS, "ALL MOVES: a chip for each of the eight schools")
	await _press(_meta(box, "school_pick", "legs"))
	ok(pages.moves.school == "legs" and str(_meta(box, "section", "moves_all").get_meta("school")) == "legs" and bool(_meta(box, "school_pick", "legs").get_meta("school_on")), "a school chip shows that school's moves")
	var all_sec = _meta(box, "section", "moves_all")
	var shown = _metas(all_sec, "rpg_move").map(func(c): return str(c.get_meta("rpg_move")))
	ok(shown == RpgMoves.by_school("legs").map(func(m): return str(m.id)), "every Legs move in tier order", shown)
	var known_now = RpgSkills.known_moves(app.rpg())
	var known_ults = RpgSkills.known_ults(app.rpg())
	ok(_metas(all_sec, "rpg_move").all(func(c): return bool(c.get_meta("move_known")) == (known_now.has(str(c.get_meta("rpg_move"))) or known_ults.has(str(c.get_meta("rpg_move"))))), "known and unknown ones told apart")
	var unknown_cards = _metas(all_sec, "rpg_move").filter(func(c): return not bool(c.get_meta("move_known")))
	ok(not unknown_cards.is_empty() and unknown_cards.all(func(c): return _meta(c, "move_needs") != null and str(_meta(c, "move_needs").text).length() > 8 and c.modulate.a < 1.0), "an unknown move is dim and says what it needs", unknown_cards.size())
	var scroll_cards = unknown_cards.filter(func(c): return int(RpgMoves.by_id(str(c.get_meta("rpg_move"))).tier) >= RpgMoves.TIER_SCROLL)
	ok(not scroll_cards.is_empty() and scroll_cards.all(func(c): return str(_meta(c, "move_needs").text) == "A scroll: found in the Ironwild"), "a scroll move says it is found in the Ironwild")
	var stomp_card = _meta(all_sec, "rpg_move", "stomp")
	ok(stomp_card != null and _words(stomp_card).contains("Starter") and _words(stomp_card).contains(pages.moves.rank_word(RpgMoves.by_id("stomp"))) and _meta(stomp_card, "move_power") != null, "a known move's card: tier, power, rank as a word", _words(stomp_card))
	await _tap(stomp_card)
	_check_sheet("the equip sheet")
	var esh = _sheet()
	ok(esh != null and str(esh.box.get_meta("equip_sheet", "")) == "stomp" and _metas(esh.box, "equip_slot").size() == 4, "a tap on a known move offers its four slots", _metas(esh.box, "equip_slot").size() if esh != null else 0)
	await _press(_meta(esh.box, "equip_slot", 3))
	ok(str(_build().moves[3]) == "stomp" and _build().moves.count("stomp") == 1, "Equip puts it in that slot (and nowhere twice)", _build().moves)
	await _close_sheets()

	# --- SKILLS --------------------------------------------------------------------------------------
	await _show("skills")
	var pts = ui.points()
	ok(int(_meta(box, "skills_left").get_meta("skills_left")) == int(pts.left) and int(pts.spent) > 0 and not _meta(box, "skills_reset").disabled, "points left as RpgSkills.points has them; Reset all is on", pts)
	ok(_words(_meta(box, "section", "skills_head")).contains("Earned %d: %d to start, %d from fighter levels" % [int(pts.earned), int(pts.from.start), int(pts.from.level)]), "the line of where the points came from", _words(_meta(box, "section", "skills_head")))
	ok(_metas(box, "board_pick").map(func(c): return str(c.get_meta("board_pick"))) == RpgDefs.SCHOOLS and _metas(box, "board_pick").all(func(c): return c.icon != null), "eight board chips with their icons")
	var saw = {"learned": 0, "can": 0, "blocked": 0}
	var can_tile_board = ""
	var blocked_board = ""
	for b in RpgDefs.SCHOOLS:
		await _press(_meta(box, "board_pick", b))
		var bsec = _meta(box, "section", "skills_board")
		var node_tiles = _metas(bsec, "node")
		var want_nodes = RpgSkills.nodes_of(b)
		var state_ok = func(t):
			var id = str(t.get_meta("node"))
			var want = "learned" if RpgSkills.has_node(app.rpg(), id) else ("can" if bool(RpgSkills.can_learn(app.rpg(), id, sheet, ui.level(), ui.days()).ok) else "blocked")
			return str(t.get_meta("node_state")) == want
		var right_states = node_tiles.all(state_ok)
		var heights = node_tiles.map(func(t): return int(round(t.size.y)))
		var rows = {}
		for t in node_tiles:
			var y = int(round(t.get_global_rect().position.y))
			rows[y] = int(rows.get(y, 0)) + 1
		if not (str(bsec.get_meta("board")) == b and node_tiles.size() == want_nodes.size() and right_states and heights.min() == heights.max() and rows.size() == 5 and rows.values().max() <= 3
				and _metas(bsec, "tier_band").size() == 5 and _words(bsec).contains(str(RpgDefs.SCHOOL_FROM[b]).to_lower())):
			ok(false, "the %s board: its nodes in five tiers, each in its true state, all one size, what feeds it" % b, [node_tiles.size(), want_nodes.size(), right_states, heights.min(), heights.max(), rows])
		var wide = _wide(box, box.global_position.x, box.global_position.x + W)
		if not wide.is_empty():
			ok(false, "the %s board fits the column" % b, wide.slice(0, 4))
		for t in node_tiles:
			saw[str(t.get_meta("node_state"))] += 1
			if str(t.get_meta("node_state")) == "can" and can_tile_board == "":
				can_tile_board = b
			if str(t.get_meta("node_state")) == "blocked" and blocked_board == "":
				blocked_board = b
		for band in _metas(bsec, "tier_band"):
			var tier = int(band.get_meta("tier_band"))
			if not _words(band).contains("TIER %d" % tier) or not _words(band).contains("needs ") or not _words(band).contains(" %d · you have " % int(RpgDefs.REQ[tier])):
				ok(false, "the band of tier %d of %s says what it needs and what you have" % [tier, b], _words(band))
			if int(RpgDefs.NODE_LEVEL[tier]) > 1 and not _words(band).contains("fighter level %d" % int(RpgDefs.NODE_LEVEL[tier])):
				ok(false, "the band of tier %d of %s names its fighter level" % [tier, b], _words(band))
	ok(true, "all eight boards were built")
	ok(saw.learned > 0 and saw.can > 0 and saw.blocked > 0, "the rich save shows all three node states", saw)

	# Learn from a tile.
	await _press(_meta(box, "board_pick", can_tile_board))
	var can_tile = _metas(box, "node").filter(func(t): return str(t.get_meta("node_state")) == "can")[0]
	var learn_id = str(can_tile.get_meta("node"))
	var learn_node = RpgSkills.by_id(learn_id)
	var learn_key = _meta(can_tile, "node_learn", learn_id)
	ok(learn_key != null and learn_key.text == "Learn · %d" % int(learn_node.cost) and _metas(can_tile, "node_blocked").is_empty(), "a node that can be learned has a Learn key with its cost", learn_key.text if learn_key != null else "")
	var left_before = int(ui.points().left)
	await _press(learn_key)
	ok(RpgSkills.has_node(app.rpg(), learn_id) and int(ui.points().left) == left_before - int(learn_node.cost), "Learn: the node is learned and the points go down by its cost", [left_before, ui.points().left])
	var now_tile = _meta(box, "node", learn_id)
	ok(now_tile != null and str(now_tile.get_meta("node_state")) == "learned" and _words(now_tile).contains("Learned") and _meta(now_tile, "node_learn") == null and int(_meta(box, "skills_left").get_meta("skills_left")) == left_before - int(learn_node.cost),
		"its tile turns learned (a tick, no key) and the big number follows")
	var offer = _meta(box, "node_equip", learn_id)
	ok(offer != null and _words(_meta(box, "skills_fresh")).contains("Learned"), "a just-learned skill offers \"Equip it now\"")
	if str(learn_node.kind) == "move":
		ok(RpgSkills.known_moves(app.rpg()).has(str(learn_node.ref)), "the move is now one the hero may equip")
	await _press(offer)
	var osh = _sheet()
	ok(osh != null and str(osh.box.get_meta("equip_sheet", "")) == str(learn_node.ref), "\"Equip it now\" opens the equip sheet of what was learned")
	if osh != null and str(learn_node.kind) == "move":
		await _press(_meta(osh.box, "equip_slot", 0))
		ok(str(_build().moves[0]) == str(learn_node.ref), "and a slot key equips it", _build().moves)
	await _close_sheets()

	# A blocked node says why.
	await _press(_meta(box, "board_pick", blocked_board))
	var blocked = _metas(box, "node").filter(func(t): return str(t.get_meta("node_state")) == "blocked")
	var b_tile = blocked[blocked.size() - 1]
	var b_id = str(b_tile.get_meta("node"))
	var b_why = str(RpgSkills.can_learn(app.rpg(), b_id, sheet, ui.level(), ui.days()).why)
	var b_label = _meta(b_tile, "node_blocked")
	ok(b_label != null and str(b_label.get_meta("node_blocked")) == b_why and str(b_label.text).length() > 4 and _meta(b_tile, "node_learn") == null, "a blocked node says why in a few words, and has no Learn key", b_label.text if b_label != null else "")
	await _tap(b_tile)
	_check_sheet("the node's sheet")
	var nsh = _sheet()
	ok(nsh != null and str(nsh.box.get_meta("node_sheet", "")) == b_id and _meta(nsh.box, "node_why") != null and str(_meta(nsh.box, "node_why").get_meta("node_why")) == b_why and _meta(nsh.box, "node_learn") == null,
		"its sheet gives the reason in full and no Learn key", b_why)
	var req_rows = _metas(nsh.box, "node_req") if nsh != null else []
	ok(req_rows.size() >= 2 and req_rows.any(func(r): return not bool(r.get_meta("node_req"))) and (_meta(nsh.box, "rpg_move") != null or _meta(nsh.box, "rpg_passive") != null), "with the move or passive in full and each requirement ticked or crossed", req_rows.map(func(r): return r.get_meta("node_req")))
	var before_blocked = JSON.stringify(app.rpg().nodes)
	await _close_sheets()

	# Learn from the sheet.
	var again = RpgSkills.learnable(app.rpg(), sheet, ui.level(), ui.days())
	ok(not again.is_empty(), "there is still a skill to learn", ui.points())
	if not again.is_empty():
		var id2 = str(again[0])
		var n2 = RpgSkills.by_id(id2)
		await _press(_meta(box, "board_pick", str(n2.board)))
		await _tap(_meta(box, "node", id2))
		var lsh = _sheet()
		var big_key = _meta(lsh.box, "node_learn", id2) if lsh != null else null
		ok(big_key != null and str(big_key.text).begins_with("Learn for %d point" % int(n2.cost)) and _metas(lsh.box, "node_req").all(func(r): return bool(r.get_meta("node_req"))), "a learnable node's sheet: every requirement ticked, \"Learn for N points\"", big_key.text if big_key != null else "")
		var left2 = int(ui.points().left)
		await _press(big_key)
		ok(RpgSkills.has_node(app.rpg(), id2) and int(ui.points().left) == left2 - int(n2.cost) and JSON.stringify(app.rpg().nodes) != before_blocked, "learned from the sheet")
		ok(_sheet() == lsh and _meta(lsh.box, "node_equip", id2) != null and _meta(lsh.box, "node_learn") == null, "the sheet stays and now offers \"Equip it now\"")
		await _close_sheets()

	# Reset.
	var builds_before = JSON.stringify(app.rpg().builds)
	await _press(_meta(box, "skills_reset"))
	var csh = _sheet()
	ok(csh != null and int(ui.points().spent) > 0, "Reset all asks first")
	var yes = _all(csh).filter(func(c): return c is Button and c.text == "Reset all") if csh != null else []
	await _press(yes[0] if not yes.is_empty() else null)
	ok(app.rpg().nodes.is_empty() and int(ui.points().spent) == 0 and int(ui.points().left) == int(ui.points().earned) and JSON.stringify(app.rpg().builds) == builds_before, "Reset all: nothing learned, every point back, the builds untouched", ui.points())
	await _close_sheets()
	await _settle()
	ok(_metas(box, "node").all(func(t): return str(t.get_meta("node_state")) != "learned") and _meta(box, "skills_reset").disabled, "the board shows it")
	await _show("moves")
	var gone = _metas(box, "move_slot").filter(func(c): return not c.has_meta("realm_locked") and str(c.get_meta("slot_holds")) != "" and not RpgSkills.known_moves(app.rpg()).has(str(c.get_meta("slot_holds"))))
	ok(not gone.is_empty() and gone.all(func(c): return _words(c).contains("Not learned")), "a move the reset unlearned stays in its slot, marked as not learned", gone.size())

	# --- GEAR ----------------------------------------------------------------------------------------
	app.set_rpg(_rich())
	await _show("gear")
	var have = ui.owned()
	var doll = _metas(box, "gear_slot")
	ok(doll.size() == 10 and doll.map(func(c): return str(c.get_meta("gear_slot"))) == ["head", "face", "body", "hands", "legs", "aura", "back", "accessory", "feet", "pet"], "WORN: the nine slots and the companion around the hero")
	var well = _meta(box, "gear_doll")
	ok(well != null and doll.slice(0, 5).all(func(c): return c.get_global_rect().end.x <= well.get_global_rect().position.x + 0.5) and doll.slice(5, 10).all(func(c): return c.get_global_rect().position.x >= well.get_global_rect().end.x - 0.5) and well.size.x >= 200.0,
		"five tiles left of the hero and five right of it, the hero's stage 200 wide or more", well.size.x if well != null else 0)
	var worn = RpgGear.worn(_build().gear, have.items)
	ok(not worn.is_empty() and worn.all(func(id): return str(_meta(box, "gear_slot", str(RpgGear.of(id).slot)).get_meta("gear_holds")) == id), "each worn piece is in its tile", worn)
	var up_id = str(worn[0])
	ok(int(_meta(box, "gear_slot", str(RpgGear.of(up_id).slot)).get_meta("gear_plus")) == 2, "an upgraded piece shows its plus")
	var totals = RpgGear.totals(_build().gear, app.rpg().plus, app.rpg().runes, app.rpg().socket, have.items)
	ok(_metas(box, "gear_total").size() == totals.size() and totals.keys().all(func(k): return _words(_meta(box, "gear_total", str(k))) == RpgGear.line_words({"k": k, "v": totals[k]})), "the kit's totals as chips, in RpgGear's words", _metas(box, "gear_total").size())
	var sets = RpgGear.sets_in_force(_build().gear, have.items)
	ok(_metas(box, "gear_set").size() == sets.size() and (not sets.is_empty() or _meta(box, "realm_empty", "sets_none") != null), "the sets in force (or a line when none)", sets)
	for s in sets:
		ok(_words(_meta(box, "gear_set", str(s.id))).contains("%s set" % str(s.name)) and _words(_meta(box, "gear_set", str(s.id))).contains(str(RpgGear.SETS[s.id].two.text)), "the %s set with its bonus text" % str(s.id))

	# A slot's sheet: wear, upgrade, rune. The slot with the most owned pieces.
	var by_slot = {}
	for id in have.items:
		var g = RpgGear.of(str(id))
		if g != null:
			if not by_slot.has(str(g.slot)):
				by_slot[str(g.slot)] = []
			by_slot[str(g.slot)].append(str(id))
	var slot = ""
	for s in by_slot:
		if slot == "" or by_slot[s].size() > by_slot[slot].size():
			slot = str(s)
	ok(slot != "" and by_slot[slot].size() >= 2, "the demo player owns two pieces for one slot", by_slot)
	await _tap(_meta(box, "gear_slot", slot))
	_check_sheet("the slot's sheet")
	var gsh = _sheet()
	var cards = _metas(gsh.box, "gear_item") if gsh != null else []
	var listed = cards.map(func(c): return str(c.get_meta("gear_item")))
	var want_listed = by_slot[slot].duplicate()
	want_listed.sort()
	var got_listed = listed.duplicate()
	got_listed.sort()
	ok(str(gsh.box.get_meta("slot_sheet", "")) == slot and got_listed == want_listed, "a slot's sheet lists every owned piece of that slot and nothing else", [listed, by_slot[slot]])
	var worn_here = str(_build().gear.get(slot, ""))
	ok(cards.filter(func(c): return bool(c.get_meta("gear_worn"))).map(func(c): return str(c.get_meta("gear_item"))) == [worn_here] and _words(_meta(gsh.box, "gear_item", worn_here)).contains("WORN"), "\"WORN\" on the one in use")
	var a_card = _meta(gsh.box, "gear_item", worn_here)
	var a_gear = RpgGear.of(worn_here, int(app.rpg().plus.get(worn_here, 0)))
	ok(a_gear.lines.all(func(l): return _words(a_card).contains(RpgGear.line_words(l))) and _words(a_card).contains(Items.by_id(worn_here).name) and _words(a_card).contains(str(a_gear.rarity).to_upper()), "a piece's card: name, rarity, its lines in words", _words(a_card))
	var other = str(by_slot[slot].filter(func(id): return id != worn_here)[0])
	await _press(_meta(gsh.box, "gear_wear", other))
	ok(str(_build().gear.get(slot, "")) == other, "Wear: the build wears it", _build().gear)
	ok(_sheet() == gsh and bool(_meta(gsh.box, "gear_item", other).get_meta("gear_worn")) and not bool(_meta(gsh.box, "gear_item", worn_here).get_meta("gear_worn")), "the sheet stays open and marks the new one")
	ok(_metas(gsh.box, "gear_item").map(func(c): return str(c.get_meta("gear_item"))) == listed, "the cards keep their order (the key stays under the finger)")
	ok(str(_meta(box, "gear_slot", slot).get_meta("gear_holds")) == other, "the doll follows")

	var up_key = _meta(gsh.box, "gear_upgrade", other)
	var plus0 = int(app.rpg().plus.get(other, 0))
	var cost = RpgGear.plus_cost(other, plus0)
	var ore0 = int(app.rpg().ore)
	ok(up_key != null and not up_key.disabled and up_key.text == "Upgrade to +%d · %s ore" % [plus0 + 1, Xp.fmt_int(cost)] and int(up_key.get_meta("gear_cost")) == cost, "the Upgrade key says the next plus and its price in ore", up_key.text if up_key != null else "")
	var grow = _meta(_meta(gsh.box, "gear_item", other), "gear_next")
	ok(grow != null and RpgGear.of(other, plus0 + 1).lines.all(func(l): return str(grow.text).contains(RpgGear.line_words(l))), "and shows the lines as they will be", grow.text if grow != null else "")
	await _press(up_key)
	ok(int(app.rpg().plus.get(other, 0)) == plus0 + 1 and int(app.rpg().ore) == ore0 - cost, "Upgrade: the plus goes up and the ore goes down by the price", [app.rpg().plus.get(other, 0), app.rpg().ore, ore0, cost])
	ok(int(_meta(gsh.box, "gear_item", other).get_meta("gear_plus")) == plus0 + 1 and _meta(gsh.box, "gear_upgrade", other).text == "Upgrade to +%d · %s ore" % [plus0 + 2, Xp.fmt_int(RpgGear.plus_cost(other, plus0 + 1))], "the card and the key follow")
	# Without ore.
	var poor = RpgSave.copy(app.rpg())
	poor.ore = 3
	app.set_rpg(poor)
	await _close_sheets()
	await _settle()
	await _tap(_meta(box, "gear_slot", slot))
	gsh = _sheet()
	var poor_key = _meta(gsh.box, "gear_upgrade", other)
	var why_line = _meta(_meta(gsh.box, "gear_item", other), "gear_upgrade_why")
	ok(poor_key.disabled and why_line != null and str(why_line.text).contains("Needs %s ore, you have 3" % Xp.fmt_int(RpgGear.plus_cost(other, plus0 + 1))), "short of ore: the key is off and a line says what is missing", why_line.text if why_line != null else "")
	await _press(poor_key)
	ok(int(app.rpg().plus.get(other, 0)) == plus0 + 1 and int(app.rpg().ore) == 3, "and even pressed it upgrades nothing")
	var maxed = RpgSave.copy(app.rpg())
	maxed.ore = 6000
	maxed.plus[other] = RpgDefs.PLUS_MAX
	app.set_rpg(maxed)
	await _close_sheets()
	await _settle()
	await _tap(_meta(box, "gear_slot", slot))
	gsh = _sheet()
	ok(_meta(gsh.box, "gear_upgrade", other).disabled and _words(_meta(gsh.box, "gear_item", other)).contains("+%d is as far as it goes" % RpgDefs.PLUS_MAX), "at +10 the key is off and says that is the top")

	# The rune of a piece.
	await _press(_meta(gsh.box, "gear_rune", other))
	_check_sheet("the rune sheet")
	var runesh = _sheet()
	ok(runesh != gsh and str(runesh.box.get_meta("rune_sheet", "")) == other and _metas(runesh.box, "rune_socket").size() == 3, "Rune opens the rune list for that piece", _metas(runesh.box, "rune_socket").size())
	await _press(_meta(runesh.box, "rune_socket", "rnB"))
	ok(str(app.rpg().socket.get(other, "")) == "rnB" and _gone(runesh), "Socket: the rune sits in the piece")
	ok(_words(_meta(gsh.box, "gear_item", other)).contains("Rune: %s" % RpgGear.rune_words({"k": "hp", "v": 12.0})), "the piece's card names its rune", _words(_meta(gsh.box, "gear_item", other)))
	await _press(_meta(gsh.box, "gear_rune", other))
	runesh = _sheet()
	ok(_meta(runesh.box, "rune_socket", "rnB").disabled and _meta(runesh.box, "rune_remove") != null, "the rune list marks the one in it and offers to take it out")
	await _press(_meta(runesh.box, "rune_socket", "rnA"))
	ok(str(app.rpg().socket.get(other, "")) == "rnA" and not app.rpg().socket.values().has("rnB") and app.rpg().socket.size() == 1, "a rune moves freely: rnA leaves the piece it was in", app.rpg().socket)
	await _press(_meta(gsh.box, "gear_rune", other))
	await _press(_meta(_sheet().box, "rune_remove"))
	ok(not app.rpg().socket.has(other), "Take the rune out")
	await _close_sheets()
	await _settle()

	# RUNES: where each sits, scrap.
	var again_rune = RpgSave.socket(app.rpg(), other, "rnC").rpg
	app.set_rpg(again_rune)
	await _settle()
	ok(_metas(box, "rune_row").size() == 3 and str(_meta(_meta(box, "rune_row", "rnC"), "rune_in").get_meta("rune_in")) == other and _words(_meta(box, "rune_row", "rnC")).contains("In %s" % str(Items.by_id(other).name))
		and _words(_meta(box, "rune_row", "rnA")).contains("Not in any gear"), "RUNES: every rune in words, and where it sits", _words(_meta(box, "rune_row", "rnC")))
	var pay = RpgLoot.scrap_ore({"rarity": "epic"})
	var scrap_key = _meta(box, "rune_scrap", "rnC")
	ok(scrap_key != null and scrap_key.text == "Scrap for %d ore" % pay, "a rune's key says what scrapping pays", scrap_key.text if scrap_key != null else "")
	var ore_s = int(app.rpg().ore)
	await _press(scrap_key)
	ok(app.rpg().runes.size() == 3 and _sheet() != null, "Scrap asks first")
	var scrap_yes = _all(_sheet()).filter(func(c): return c is Button and c.text == "Scrap it")
	await _press(scrap_yes[0] if not scrap_yes.is_empty() else null)
	ok(app.rpg().runes.size() == 2 and int(app.rpg().ore) == ore_s + pay and not app.rpg().socket.has(other), "scrapped: the rune is gone, out of its piece, and the ore is paid", [app.rpg().runes.size(), app.rpg().ore])
	await _close_sheets()
	await _settle()
	ok(_meta(box, "rune_row", "rnC") == null and _metas(box, "rune_row").size() == 2, "the list follows")

	# RELICS.
	var relics = RpgRelics.all()
	var r_slots = _metas(box, "relic_slot")
	ok(r_slots.size() == 3 and str(r_slots[0].get_meta("slot_holds")) == str(relics[0].id) and _words(r_slots[0]).contains(str(relics[0].name)) and _words(r_slots[0]).contains(str(relics[0].text)), "RELICS: the first slot holds its relic, in full", _words(r_slots[0]))
	ok(str(r_slots[1].get_meta("slot_holds")) == "" and not r_slots[1].has_meta("realm_locked") and r_slots[2].has_meta("realm_locked") and _words(r_slots[2]).contains("fighter level %d" % int(RpgDefs.RELIC_SLOTS_AT[2])), "the second is open and empty at level 12, the third locked with its level")
	await _tap(r_slots[1])
	_check_sheet("the relic sheet")
	var relsh = _sheet()
	ok(_metas(relsh.box, "pick_relic").size() == 4, "the relic sheet lists the three found and an Empty key", _metas(relsh.box, "pick_relic").size())
	await _tap(_meta(relsh.box, "pick_relic", str(relics[1].id)))
	ok(str(_build().relics[1]) == str(relics[1].id) and _gone(relsh), "picking a relic puts it in the slot", _build().relics)
	await _close_sheets()

	# COMPANION.
	var my_pets = Pets.all().filter(func(p): return have.pets.has(p.id) and RpgPets.by_id(str(p.id)) != null).map(func(p): return str(p.id))
	var pet_keys = _metas(_meta(box, "section", "gear_pet"), "pet_pick")
	ok(my_pets.size() >= 2 and my_pets.all(func(id): return _meta(_meta(box, "section", "gear_pet"), "pet_pick", id) != null), "COMPANION: every owned companion to pick from", [my_pets, pet_keys.size()])
	var new_pet = str(my_pets.filter(func(id): return id != str(_build().pet))[0])
	await _tap(_meta(_meta(box, "section", "gear_pet"), "pet_pick", new_pet))
	ok(str(_build().pet) == new_pet and bool(_meta(_meta(box, "section", "gear_pet"), "pet_pick", new_pet).get_meta("pet_on")), "picking one makes it the build's companion")
	var pet_card = _meta(box, "pet_card", new_pet)
	var pet_words = RpgPets.words(new_pet)
	ok(pet_card != null and _words(pet_card).contains(str(Pets.by_id(new_pet).name)) and _words(pet_card).contains(str(pet_words.command)) and (str(pet_words.auto) == "" or _words(pet_card).contains(str(pet_words.auto))), "the companion in full: its name, what it does by itself, its command", _words(pet_card) if pet_card != null else "")
	ok(str(_meta(box, "gear_slot", "pet").get_meta("gear_holds")) == new_pet, "the doll's PET tile follows")
	await _press(_meta(_meta(box, "section", "gear_pet"), "pet_pick", ""))
	ok(str(_build().pet) == "" and _meta(box, "realm_empty", "pet_unpicked") != null, "\"No companion\" clears it, and the part says so")
	await _tap(_meta(box, "gear_slot", "pet"))
	_check_sheet("the companion sheet")
	await _tap(_meta(_sheet().box, "pet_pick", new_pet))
	ok(str(_build().pet) == new_pet, "the PET tile's sheet picks one too")
	await _close_sheets()

	# BELT.
	var belt_slots = _metas(box, "belt_slot")
	ok(belt_slots.size() == 3 and str(belt_slots[0].get_meta("slot_holds")) == "protein_shake" and _words(belt_slots[0]).contains("x3") and not belt_slots[2].has_meta("realm_locked"), "BELT: the shake with its stock; the third slot is open at level 12", _words(belt_slots[0]))
	await _tap(belt_slots[1])
	_check_sheet("the belt sheet")
	var beltsh = _sheet()
	var belt_picks = _metas(beltsh.box, "pick_item").map(func(c): return str(c.get_meta("pick_item")))
	ok(belt_picks.size() == RpgItems.all().size() + 1 and belt_picks.slice(0, 2).has("protein_shake") and belt_picks.slice(0, 2).has("chalk_ball"), "the belt sheet lists every item, the ones in stock first", belt_picks)
	await _tap(_meta(beltsh.box, "pick_item", "chalk_ball"))
	ok(str(_build().belt[1]) == "chalk_ball", "picking an item puts it on the belt", _build().belt)
	await _close_sheets()

	# CAMP SHOP.
	var price = RpgItems.price("energy_gel")
	var ore_b = int(app.rpg().ore)
	var buy = _meta(box, "shop_buy", "energy_gel")
	ok(buy != null and buy.text == "Buy · %d" % price and _metas(box, "shop_buy").map(func(c): return str(c.get_meta("shop_buy"))) == RpgItems.SHOP, "CAMP SHOP: the eight items, each key with its price", buy.text if buy != null else "")
	await _press(buy)
	ok(int(app.rpg().items.get("energy_gel", 0)) == 1 and int(app.rpg().ore) == ore_b - price, "Buy: one more in stock, the ore paid", [app.rpg().items, app.rpg().ore])
	ok(_meta(box, "shop_buy", "energy_gel") != null and _meta(box, "shop_buy", "energy_gel").text == "Buy · %d" % price and int(_meta(_meta(box, "shop_item", "energy_gel"), "item_stock").get_meta("item_stock")) == 1, "the key keeps its words; the row counts what you have")
	ok(int(_meta(_meta(box, "section", "gear_shop"), "rpg_ore").get_meta("rpg_ore")) == ore_b - price, "the ore on hand follows")

	# The rich page once more after all of that, at both sizes.
	for fingers in [false, true]:
		kit.fingers = fingers
		for page in ["moves", "skills", "gear"]:
			await _show(page)
			_check_page("after playing%s" % (", fingers" if fingers else ""))
	# The sheets with keys, at finger size.
	await _show("gear")
	await _tap(_meta(box, "gear_slot", slot))
	_check_sheet("the slot's sheet, fingers")
	await _close_sheets()
	await _show("moves")
	await _tap(_meta(box, "move_slot", 0))
	_check_sheet("the pick sheet, fingers")
	await _close_sheets()
	await _show("skills")
	await _tap(_metas(box, "node")[0])
	_check_sheet("the node's sheet, fingers")
	await _close_sheets()
	kit.fingers = false

	print("RPG PAGES: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
