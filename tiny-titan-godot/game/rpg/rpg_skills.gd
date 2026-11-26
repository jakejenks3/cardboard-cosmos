class_name RpgSkills
extends RefCounted
## Skill boards (RPG_PLAN.md 6). Pure: nothing here touches a save or a screen;
## every function takes the saved Realm (`rpg`, RPG_PLAN.md 11.2) and reads it.
##
## Eight boards, one per school, in RpgDefs.SCHOOLS order. A board:
##   {"id" (its school), "name", "nodes": [node]}
## A node:
##   {"id": "<board>:<ref>", "board", "tier" (1..5), "kind": "move"|"passive"|"ult",
##    "ref" (the id of the move or the passive), "cost" (skill points, RpgDefs.NODE_COST
##    by tier), "stat" (the stat it asks for), "col" (0..2), "row" (= tier)}
##
## Nothing is typed in here: a board is every tier 1..5 move of its school
## (RpgMoves; the tier-5 one is the ultimate) and every passive of that board
## (RpgPassives), so a move added to the catalog with a tier is on its board.
## An attack board has 12 nodes, Flow and Grit 9; all of them cost 168 points.
##
## On screen a tier is a row of three places: the moves from the left, the
## passive on the right (col 2); a row of two moves has them at the two ends;
## the ultimate stands in the middle.
##
## To learn a node (can_learn): enough points, a learned node of the tier below
## on the same board, the fighter level of the tier (RpgDefs.NODE_LEVEL) and
## the stat (RpgDefs.REQ by tier, read from the sheet's own value, never a
## boosted one). A learned node stays learned whatever the stats do later.
##
## Skill points (points): 3 + (fighter level - 1) + 2 a region boss beaten +
## 1 per 12 stars + 1 per 8 active training days. Spent = the cost of the
## learned nodes. The save holds only `rpg.nodes` = {node id: true}.

static var _boards = null
static var _all = null
static var _by_id = null
static var _by_ref = null


## Where the nodes of one tier stand: `moves` and `passives` nodes of a tier get their "col".
static func _place(moves: Array, passives: Array) -> void:
	var cols = [1] if moves.size() == 1 and passives.is_empty() else ([0, 2] if moves.size() == 2 and passives.is_empty() else [0, 1, 2])
	for i in range(moves.size()):
		moves[i]["col"] = int(cols[mini(i, cols.size() - 1)])
	for i in range(passives.size()):
		passives[i]["col"] = maxi(0, 2 - i)


static func _node(board: String, tier: int, kind: String, ref: String, stat: String) -> Dictionary:
	return {"id": board + ":" + ref, "board": board, "tier": tier, "kind": kind, "ref": ref,
		"cost": int(RpgDefs.NODE_COST[clampi(tier, 0, RpgDefs.NODE_COST.size() - 1)]), "stat": stat, "col": 0, "row": tier}


## The eight boards, in RpgDefs.SCHOOLS order (the plan's BOARDS; a function
## because the nodes are made from the two catalogs).
static func boards() -> Array:
	if _boards == null:
		var list = []
		for school in RpgDefs.SCHOOLS:
			var nodes = []
			for tier in range(1, 6):
				var moves = []
				for m in RpgMoves.all():
					if str(m.school) == school and int(m.tier) == tier:
						moves.append(_node(school, tier, "ult" if bool(m.ult) else "move", str(m.id), RpgMoves.stat_of(m)))
				var passives = []
				for p in RpgPassives.all():
					if str(p.board) == school and int(p.tier) == tier:
						passives.append(_node(school, tier, "passive", str(p.id), str(RpgDefs.BOARD_STAT.get(school, ""))))
				_place(moves, passives)
				nodes.append_array(moves)
				nodes.append_array(passives)
			list.append({"id": school, "name": str(RpgDefs.SCHOOL_NAMES.get(school, school)), "nodes": nodes})
		_boards = list
	return _boards


## Every node of every board, board by board, tier by tier.
static func all() -> Array:
	if _all == null:
		var list = []
		for b in boards():
			list.append_array(b.nodes)
		_all = list
	return _all


## A node by its id ("push:haymaker"), or null.
static func by_id(node_id: String) -> Variant:
	if _by_id == null:
		var map = {}
		for n in all():
			map[n.id] = n
		_by_id = map
	return _by_id.get(node_id)


## The nodes of one board (its school id), tier by tier; [] for an unknown board.
static func nodes_of(board: String) -> Array:
	for b in boards():
		if str(b.id) == board:
			return b.nodes
	return []


## The node that teaches a move or a passive (by its id), or null: a starter
## and a scroll have none.
static func node_of_ref(ref: String) -> Variant:
	if _by_ref == null:
		var map = {}
		for n in all():
			map[n.ref] = n
		_by_ref = map
	return _by_ref.get(ref)


## Is this node learned in the saved Realm?
static func has_node(rpg: Dictionary, node_id: String) -> bool:
	return bool(rpg.get("nodes", {}).get(node_id, false))


## The fighter level of the saved Realm.
static func level_of(rpg: Dictionary) -> int:
	return int(RpgDefs.level_of(int(rpg.get("xp", 0))).lvl)


## Skill points: {"earned", "spent", "left", "from": {"start", "level",
## "bosses", "stars", "days"}}; "from" holds the POINTS each source gave.
## active_days = the player's training days (the game's own count).
static func points(rpg: Dictionary, active_days: int) -> Dictionary:
	var stages = rpg.get("stages", {})
	var bosses = 0
	for i in range(RpgDefs.REGIONS.size()):
		var st = stages.get("r%ds%d" % [i + 1, RpgDefs.STAGES_PER_REGION])
		if st is Dictionary and int(st.get("wins", 0)) > 0:
			bosses += 1
	var stars = 0
	for id in stages:
		var st = stages[id]
		if st is Dictionary and st.get("stars") is Array:
			for s in st.stars:
				if s is bool and s:
					stars += 1
	var by = {"start": RpgDefs.POINTS_START, "level": level_of(rpg) - 1, "bosses": RpgDefs.POINTS_PER_BOSS * bosses,
		"stars": int(floor(float(stars) / float(RpgDefs.STARS_PER_POINT))),
		"days": int(floor(float(maxi(0, active_days)) / float(RpgDefs.DAYS_PER_POINT)))}
	var earned = int(by.start) + int(by.level) + int(by.bosses) + int(by.stars) + int(by.days)
	var spent = 0
	for n in all():
		if has_node(rpg, str(n.id)):
			spent += int(n.cost)
	return {"earned": earned, "spent": spent, "left": earned - spent, "from": by}


## May this node be learned now? {"ok", "why"}: "why" is "" when it may, else
## the first thing in the way, in plain words with its numbers. `sheet` is the
## stat sheet (RpgStats.sheet: sheet.stats[stat].v), `level` the fighter level.
static func can_learn(rpg: Dictionary, node_id: String, sheet: Dictionary, level: int, active_days: int) -> Dictionary:
	var n = by_id(node_id)
	if n == null:
		return {"ok": false, "why": "No such skill"}
	if has_node(rpg, node_id):
		return {"ok": false, "why": "Already learned"}
	var tier = int(n.tier)
	var board_name = str(RpgDefs.SCHOOL_NAMES.get(str(n.board), str(n.board)))
	if tier > 1:
		var below = false
		for o in nodes_of(str(n.board)):
			if int(o.tier) == tier - 1 and has_node(rpg, str(o.id)):
				below = true
				break
		if not below:
			return {"ok": false, "why": "Learn a tier %d %s skill first" % [tier - 1, board_name]}
	var need_level = int(RpgDefs.NODE_LEVEL[tier])
	if level < need_level:
		return {"ok": false, "why": "Needs fighter level %d" % need_level}
	var need_stat = float(RpgDefs.REQ[tier])
	var st = sheet.get("stats", {}).get(str(n.stat))
	var have = float(st.get("v", 0.0)) if st is Dictionary else 0.0
	if have < need_stat:
		return {"ok": false, "why": "Needs %s %d (you have %d)" % [str(RpgDefs.STAT_NAMES.get(str(n.stat), str(n.stat))), int(need_stat), int(floor(have))]}
	var left = int(points(rpg, active_days).left)
	if left < int(n.cost):
		return {"ok": false, "why": "Not enough skill points (needs %d, you have %d)" % [int(n.cost), maxi(0, left)]}
	return {"ok": true, "why": ""}


## The node ids that could be learned right now (for "A skill can be learned").
static func learnable(rpg: Dictionary, sheet: Dictionary, level: int, active_days: int) -> Array:
	var out = []
	for n in all():
		if bool(can_learn(rpg, str(n.id), sheet, level, active_days).ok):
			out.append(str(n.id))
	return out


## The refs of the learned nodes of one kind, in board order.
static func _known(rpg: Dictionary, kind: String) -> Array:
	var out = []
	for n in all():
		if str(n.kind) == kind and has_node(rpg, str(n.id)):
			out.append(str(n.ref))
	return out


## The ids of the moves the hero may equip: the starters, the learned move
## nodes, the scrolls found (ultimates are known_ults).
static func known_moves(rpg: Dictionary) -> Array:
	var out = RpgMoves.STARTERS.duplicate()
	out.append_array(_known(rpg, "move"))
	var found = rpg.get("scrolls", {})
	for m in RpgMoves.scrolls():
		if bool(found.get(str(m.id), false)):
			out.append(str(m.id))
	return out


## The ids of the ultimates learned.
static func known_ults(rpg: Dictionary) -> Array:
	return _known(rpg, "ult")


## The ids of the board passives learned.
static func known_passives(rpg: Dictionary) -> Array:
	return _known(rpg, "passive")
