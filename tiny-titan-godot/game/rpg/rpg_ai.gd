class_name RpgAi
extends RefCounted
## Who decides in a battle of the Realm (RPG_PLAN.md 4.5, 8.3, 13): the foes'
## next move, and the hero's when no player holds the keys (auto-battle, the
## simulator, the balance sweep). Pure and deterministic: every function reads
## the battle `B` (RpgBattle) and changes nothing in it.
##
##   choose(B, foe unit, ahead = 0) -> {"move": foe move id, "pi": the pattern index after it, "rule": the rule's index or -1}
##       The foe's next move: its rules first, in order (the first that holds and
##       can be used; a "once" rule only once), then its pattern, round and round.
##       A move that cannot be used now is passed over: a summon with no place
##       free (three living foes), a pure heal while no foe is hurt. Nothing
##       usable at all: "basic", a plain hit of power 1.
##   holds(B, foe unit, rule) -> bool      does a rule's condition hold now
##   usable(B, foe unit, move id) -> bool
##
##   hero_action(B, policy = "heuristic") -> an action for RpgBattle.act
##       "heuristic"       a sensible player: the companion's command when it is charged (it is free: ask again
##                         after it), finish a foe if it can, break a guard, Guard a telegraphed heavy hit (it reads
##                         the turn order: a wind-up of a foe that acts twice before the hero does is due) or a
##                         blow that would kill, heal when low, the ultimate on a broken or dangerous foe, a buff
##                         when the fight will last, otherwise the most damage for the time it takes.
##                         It knows only what the player may know (RpgBattle.preview without `truth`): a weakness
##                         not yet learned counts for nothing, so pass `known` in the setup to play a practised hand.
##       "random"          any legal action but Flee, on any target (its dice are its own: B.rng is not touched)
##       "loop:<move id>"  that move whenever it can be used (the ultimate's id: whenever the gauge is full), else Strike
##
## The rules of a foe (rpg_foes.gd): {"if", "v", "use", "once"}:
##   hp_below v    its own HP share is under v
##   ally_hurt v   some living foe (itself too) is under v
##   turn_mod v    v = N: every Nth of its turns; v = [N, r]: its turns where turn % N == r (its first turn is 1)
##   alone         no other foe lives
##   hero_has v    the hero has the status v
##   self_lacks v  it does not have the status v

## The hit a foe is reckoned to make after a wind-up or a countdown has landed, as a share of that one.
const AFTER_BIG = 0.4
## A hit this big (a share of the hero's max HP) is worth a Guard even when it is not a wind-up.
const HEAVY = 0.3
## Under this share of HP the hero heals if it can.
const LOW_HP = 0.4
## A support move is used when it is worth this much of an average turn.
const SUPPORT_MIN = 0.8
## What a self-buff / a debuff on the target is worth, in average turns.
const BUFF_WORTH = {"pumped": 0.9, "hasted": 0.9, "braced": 0.6, "regen": 0.5, "evade": 0.7, "focus": 0.5, "counter": 0.5,
	"steady": 0.1, "insight": 0.4}
const DEBUFF_WORTH = {"exposed": 0.8, "marked": 0.8, "weakened": 0.6, "slowed": 0.5, "burn": 0.5, "bleed": 0.5, "stun": 1.0}


# =============================================================================
# Foes
# =============================================================================

static func _share(u: Dictionary) -> float:
	return clampf(float(u.get("hp", 0)) / maxf(1.0, float(u.get("hp_max", 1))), 0.0, 1.0)


## Does a foe's rule hold as things stand?
## `ahead`: 0 = for its next turn, 1 = for the one after (RpgBattle.next_intent).
static func holds(B: Dictionary, f: Dictionary, rule: Dictionary, ahead: int = 0) -> bool:
	var v = rule.get("v")
	match str(rule.get("if", "")):
		"hp_below":
			return (v is int or v is float) and _share(f) < float(v)
		"ally_hurt":
			if not (v is int or v is float):
				return false
			for g in RpgBattle.foes(B):
				if _share(g) < float(v):
					return true
			return false
		"turn_mod":
			var n = 1
			var rem = 0
			if v is Array and v.size() >= 2:
				n = maxi(1, int(v[0]))
				rem = int(v[1])
			elif v is int or v is float:
				n = maxi(1, int(v))
			return (int(f.get("turns", 0)) + 1 + ahead) % n == rem % n
		"alone":
			return RpgBattle.foes(B).size() <= 1
		"hero_has":
			return RpgBattle.has_status(B.hero, str(v))
		"self_lacks":
			return not RpgBattle.has_status(f, str(v))
	return false


## Can the foe use this move now? A summon needs a free place (and a foe it
## knows); a move that only heals needs somebody hurt.
static func usable(B: Dictionary, _f: Dictionary, move_id: String) -> bool:
	var mv = RpgBattle.foe_move(B, move_id)
	if mv == null:
		return false
	var brings = mv.get("foes", [])
	if not brings.is_empty():
		if RpgBattle.foes(B).size() >= RpgDefs.FOES_MAX:
			return false
		var known = false
		for id in brings:
			if RpgBattle.foe_row(B, str(id)) != null:
				known = true
		if not known:
			return false
	if str(mv.get("kind", "")) == "heal" and float(mv.get("power", 0.0)) <= 0.0 and str(mv.get("target", "hero")) != "hero":
		var hurt = false
		for g in RpgBattle.foes(B):
			if int(g.hp) < int(g.hp_max):
				hurt = true
		if not hurt:
			return false
	return true


## The foe's next move (see the top). Reads only; RpgBattle writes what it returns.
static func choose(B: Dictionary, f: Dictionary, ahead: int = 0) -> Dictionary:
	var pi = int(f.get("pi", 0))
	var rules = f.get("rules", [])
	var spent = f.get("flags", {}).get("rules", {})
	for i in range(rules.size()):
		var r = rules[i]
		if not (r is Dictionary):
			continue
		if bool(r.get("once", false)) and spent.has("r" + str(i)):
			continue
		var id = str(r.get("use", ""))
		if holds(B, f, r, ahead) and usable(B, f, id):
			return {"move": id, "pi": pi, "rule": i}
	var pattern = f.get("pattern", [])
	var n = pattern.size()
	for step in range(n):
		var at = (pi + step) % n
		if usable(B, f, str(pattern[at])):
			return {"move": str(pattern[at]), "pi": (at + 1) % n, "rule": -1}
	for id in f.get("moves", []):
		if usable(B, f, str(id)):
			return {"move": str(id), "pi": pi, "rule": -1}
	return {"move": "basic", "pi": pi, "rule": -1}


# =============================================================================
# The hero without a player
# =============================================================================

## The action a policy takes now (see the top). Always a legal one while the
## battle waits for the hero; {"t": "guard"} when it does not.
static func hero_action(B: Dictionary, policy: String = "heuristic") -> Dictionary:
	var opt = RpgBattle.options(B)
	if RpgBattle.over(B) or opt.targets.is_empty() or not bool(opt.guard):
		return {"t": "guard"}
	if policy == "random":
		return _random(B, opt)
	if policy.begins_with("loop:"):
		return _loop(B, opt, policy.substr(5))
	return _heuristic(B, opt)


## Any legal action but Flee. The dice come from the battle's state without touching it.
static func _random(B: Dictionary, opt: Dictionary) -> Dictionary:
	var st = Rng.Stream.new((int(B.rng) ^ (int(B.get("n", 0)) * 40503 + 977)) & 0xFFFFFFFF)
	var list = []
	for m in opt.moves:
		if bool(m.ok):
			list.append({"t": "move", "id": str(m.id)})
	if bool(opt.strike):
		list.append({"t": "strike"})
	if bool(opt.guard):
		list.append({"t": "guard"})
	if bool(opt.ult.ok):
		list.append({"t": "ult"})
	for it in opt.items:
		if bool(it.ok):
			list.append({"t": "item", "id": str(it.id)})
	if bool(opt.pet.ok):
		list.append({"t": "pet"})
	var a = list[int(st.next_int(list.size())) % list.size()]
	a["target"] = str(opt.targets[int(st.next_int(opt.targets.size())) % opt.targets.size()])
	return a


## One move whenever it can be used, else Strike (the balance sweep's "no one-move loop" check).
static func _loop(B: Dictionary, opt: Dictionary, id: String) -> Dictionary:
	var target = _focus(RpgBattle.foes(B))
	if bool(opt.ult.ok) and str(opt.ult.id) == id:
		return {"t": "ult", "target": target}
	for m in opt.moves:
		if str(m.id) == id and bool(m.ok):
			return {"t": "move", "id": id, "target": target}
	return {"t": "strike", "target": target}


## The foe to hit when nothing says otherwise: a Broken one, else the one with
## the least HP left (the first on a tie).
static func _focus(living: Array) -> String:
	var best = null
	for f in living:
		if best == null:
			best = f
		elif bool(f.get("broken", false)) != bool(best.get("broken", false)):
			if bool(f.get("broken", false)):
				best = f
		elif int(f.hp) < int(best.hp):
			best = f
	return "" if best == null else str(best.id)


static func _shield(u: Dictionary) -> float:
	var sh = RpgBattle.status_of(u, "shield")
	return 0.0 if sh == null else float(sh.get("amount", 0))


## How many times a foe acts before the hero's next turn, if the hero now does
## something of that rank (the foe's own actions counted at rank 1, as the
## timeline on screen shows them).
static func _acts_before(B: Dictionary, f: Dictionary, rank: float = 1.0) -> int:
	var h = B.hero
	var next = float(h.get("at", 0.0)) + RpgDefs.delay(rank, RpgBattle.speed_of(h))
	var step = maxf(1.0, RpgDefs.delay(1.0, RpgBattle.speed_of(f)))
	var first = float(f.get("at", 0.0))
	if first >= next:
		return 0
	# a wind-up takes its move's own time to charge (a heavy one comes a little later than the turn order says)
	var it = f.get("intent", {})
	var second = step
	if bool(it.get("windup", false)):
		var mv = RpgBattle.foe_move(B, str(it.get("move", "")))
		if mv != null:
			second = maxf(1.0, RpgDefs.delay(float(mv.get("rank", 1.0)), RpgBattle.speed_of(f)))
	if first + second >= next:
		return 1
	return 2 + int(floor((next - first - second - 0.0001) / step))


## What a foe is about to do to the hero before the hero acts again, if the
## hero now does something of that rank. A hit that is ready lands on the
## foe's next action (when that comes first); a wind-up still to charge
## lands only when the foe gets two actions in before the hero's next turn (a
## quick foe, or a slow move of the hero's), a countdown when it gets as many
## as the count: the timeline shows it, so a player sees it coming too.
static func _due(B: Dictionary, f: Dictionary, rank: float = 1.0) -> float:
	var it = f.get("intent", {})
	var need = 1
	if bool(it.get("windup", false)):
		need = 2
	elif int(it.get("count", 0)) > 1:
		need = int(it.get("count", 0))
	var acts = _acts_before(B, f, rank)
	if acts < need:
		return 0.0
	# what it does after the hit that is shown cannot be known: reckon with a plain hit for each action more
	var dmg = float(it.get("dmg", 0))
	return dmg + float(acts - need) * dmg * (1.0 if need == 1 and not bool(it.get("charged", false)) else AFTER_BIG)


## Everything that lands on the hero before the next turn, if the hero now does something of that rank.
static func _lands(B: Dictionary, living: Array, rank: float) -> float:
	var sum = 0.0
	for f in living:
		sum += _due(B, f, rank)
	return sum


## When a Guard now would be over before the hit it is meant for (the foe has
## still to charge, or the hero is up again first): something quick enough that
## nothing lands during it either: the heal when hurt, else the best such
## attack. {} when there is nothing like that (then Guard, and Guard again).
static func _quiet(B: Dictionary, living: Array, attacks: Array, heal, share: float) -> Dictionary:
	if heal != null and share < 0.75:
		var hrow = RpgBattle.move_row(B, str(heal.get("id", "")))
		if _lands(B, living, float(hrow.get("rank", 1.0)) if hrow != null else 1.0) <= 0.0:
			return heal
	var quick = null
	for a in attacks:
		if bool(a.ult) or float(a.get("lands", 1.0)) > 0.0:
			continue
		if quick == null or float(a.score) > float(quick.score):
			quick = a
	return {} if quick == null else quick.action


## One attack on one target, weighed: {"action", "value" (damage that counts,
## plus what a kill or a break is worth), "raw" (the damage alone), "kills",
## "breaks", "stops" (the damage it takes out of this round), "cost", "rank", "ult"}.
static func _weigh(B: Dictionary, action: Dictionary, move: Dictionary, living: Array, cost: int) -> Dictionary:
	var mode = str(move.get("target", "foe"))
	var targets = []
	if mode == "all" or mode == "random":
		targets = living
	else:
		for f in living:
			if str(f.id) == str(action.get("target", "")):
				targets.append(f)
		var splash = float(move.get("splash", 0.0))
		if splash > 0.0:
			for f in living:
				if str(f.id) != str(action.get("target", "")):
					targets.append(f)
	var out = {"action": action, "value": 0.0, "raw": 0.0, "kills": 0, "sure": 0, "breaks": 0, "stops": 0.0, "cost": cost,
		"rank": float(move.get("rank", 1.0)), "ult": str(action.get("t", "")) == "ult"}
	for i in range(targets.size()):
		var f = targets[i]
		var a = action.duplicate()
		a["target"] = str(f.id)
		var pv = RpgBattle.preview(B, a)
		var avg = 0.5 * (float(pv.lo) + float(pv.hi))
		if mode == "random":
			avg /= float(maxi(1, living.size()))
		elif mode == "foe" and i > 0:
			avg *= float(move.get("splash", 0.0))
		var left = float(f.hp) + _shield(f)
		var counts = minf(avg, left)
		out.raw = float(out.raw) + counts
		out.value = float(out.value) + counts
		var sure = bool(pv.kills) and (mode == "foe" and i == 0 or mode == "all")
		if sure or avg >= left:
			out.kills = int(out.kills) + 1
			if sure:
				out.sure = int(out.sure) + 1
				out.stops = float(out.stops) + _due(B, f, float(move.get("rank", 1.0)))
			out.value = float(out.value) + float(f.get("intent", {}).get("dmg", 0)) + 0.1 * float(f.hp_max)
		elif int(pv.chip) > 0 and int(f.get("guard", 0)) > 0 and int(pv.chip) >= int(f.get("guard", 0)) and (i == 0 or mode == "all"):
			# a break: its next action is lost and the next hits land 40% harder
			out.breaks = int(out.breaks) + 1
			out.stops = float(out.stops) + _due(B, f, float(move.get("rank", 1.0)))
			out.value = float(out.value) + float(f.get("intent", {}).get("dmg", 0)) + 0.4 * avg
		elif int(pv.chip) > 0:
			out.value = float(out.value) + 0.08 * avg * float(pv.chip)
	# what else the move does to its target, roughly
	for e in move.get("fx", []):
		if str(e.get("k", "")) == "status" and str(e.get("to", "target")) == "target" and not targets.is_empty():
			var id = str(e.get("id", ""))
			if not RpgBattle.has_status(targets[0], id) and int(out.kills) == 0:
				out.value = float(out.value) + 0.25 * float(DEBUFF_WORTH.get(id, 0.0)) * float(out.raw) * float(e.get("chance", 1.0))
	return out


## Every attack the hero can make now, weighed.
static func _attacks(B: Dictionary, opt: Dictionary, living: Array) -> Array:
	var out = []
	var list = []
	for m in opt.moves:
		if bool(m.ok):
			list.append([{"t": "move", "id": str(m.id)}, RpgBattle.move_row(B, str(m.id)), int(m.cost)])
	if bool(opt.strike):
		list.append([{"t": "strike"}, RpgBattle.strike_row(), 0])
	if bool(opt.ult.ok):
		list.append([{"t": "ult"}, RpgBattle.move_row(B, str(opt.ult.id)), 0])
	for entry in list:
		var move = entry[1]
		if move == null or str(move.get("kind", "attack")) != "attack":
			continue
		var mode = str(move.get("target", "foe"))
		if mode == "all" or mode == "random":
			var a = entry[0].duplicate()
			a["target"] = _focus(living)
			out.append(_weigh(B, a, move, living, int(entry[2])))
		else:
			for f in living:
				var a = entry[0].duplicate()
				a["target"] = str(f.id)
				out.append(_weigh(B, a, move, living, int(entry[2])))
	return out


## What a list of effects used on the hero's side is worth now, in average
## turns (a support move, an item). `target` = the foe a debuff would land on.
static func _support_worth(B: Dictionary, fx: Array, target, incoming: float, attack: bool) -> float:
	var h = B.hero
	var share = _share(h)
	var worth = 0.0
	for e in fx:
		match str(e.get("k", "")):
			"status":
				var id = str(e.get("id", ""))
				var to = str(e.get("to", "target" if attack else "self"))
				if to == "self":
					if RpgBattle.has_status(h, id):
						continue
					if id == "insight":
						var hidden = false
						for f in RpgBattle.foes(B):
							if not bool(RpgBattle.known(B, str(f.id)).all):
								hidden = true
						worth += float(BUFF_WORTH[id]) if hidden else 0.0
					elif (id == "braced" or id == "evade" or id == "counter") and incoming <= 0.0:
						worth += 0.3 * float(BUFF_WORTH.get(id, 0.0))
					else:
						worth += float(BUFF_WORTH.get(id, 0.0))
				elif target != null and not RpgBattle.has_status(target, id):
					worth += float(DEBUFF_WORTH.get(id, 0.0)) * float(e.get("chance", 1.0))
			"heal":
				var got = minf(float(e.get("pct", 0.0)) * RpgDefs.heal_mult(float(h.s.get("flow", 1.0)), float(h.get("agg", {}).get("heal_pct", 0.0))), 1.0 - share)
				worth += got * (6.0 if share < LOW_HP else 3.0)
			"shield":
				if _shield(h) <= 0.0 and incoming > 0.0:
					worth += 0.7
			"energy":
				worth += 0.3 * float(clampi(int(e.get("n", 0)), -int(h.en), int(h.en_max) - int(h.en)))
			"gauge":
				worth += 0.02 * minf(float(e.get("n", 0.0)), RpgDefs.GAUGE_MAX - float(h.gauge))
			"cleanse":
				var bad = RpgBattle.debuffs(h)
				if e.get("ids") is Array:
					bad = 0
					for id in e.ids:
						if RpgBattle.has_status(h, str(id)):
							bad += 1
				elif int(e.get("n", 0)) > 0:
					bad = mini(bad, int(e.n))
				worth += 0.5 * float(bad)
			"hp_cost":
				worth -= float(e.get("pct", 0.0)) * (4.0 if share < 0.5 else 1.5)
			"cd_cut":
				if not h.get("cds", {}).is_empty():
					worth += 0.3
			"extra_turn":
				worth += 1.0
			"when":
				if share < float(e.get("hp_below", 0.0)) and e.get("do") is Dictionary:
					worth += _support_worth(B, [e.do], target, incoming, attack)
	return worth


static func _has_heal(fx: Array) -> bool:
	for e in fx:
		if str(e.get("k", "")) == "heal":
			return true
	return false


## The sensible player (see the top).
static func _heuristic(B: Dictionary, opt: Dictionary) -> Dictionary:
	var h = B.hero
	var living = RpgBattle.foes(B)
	var focus = _focus(living)
	if bool(opt.pet.ok):
		return {"t": "pet", "target": focus}

	var hp = float(h.hp) + _shield(h)
	var hp_max = maxf(1.0, float(h.hp_max))
	var share = _share(h)
	var incoming = 0.0
	var biggest = 0.0
	var telegraphed = false
	var left_total = 0.0
	var big_foe = false
	for f in living:
		var d = _due(B, f)
		incoming += d
		biggest = maxf(biggest, d)
		var it = f.get("intent", {})
		# a wind-up or a countdown that lands before the next turn: charged, at its last count, or the foe is quick enough
		if d > 0.0 and (bool(it.get("charged", false)) or bool(it.get("windup", false)) or int(it.get("count", 0)) >= 1):
			telegraphed = true
		left_total += float(f.hp)
		if bool(f.get("boss", false)) or bool(f.get("elite", false)):
			big_foe = true

	var attacks = _attacks(B, opt, living)
	var best = null            # the most that counts for the time it takes
	var finisher = null        # a sure kill, the cheapest way
	var stopper = null         # what takes the most out of this round
	var deadly = false         # some attack would let a killing blow in
	for a in attacks:
		var score = float(a.value) / maxf(0.5, float(a.rank))
		a["score"] = score
		# what lands before the next turn if this is done now (a slow move lets a quick foe act twice)
		a["lands"] = _lands(B, living, float(a.rank))
		var ends = living.size() == int(a.sure) and int(B.wave) >= B.waves.size() - 1
		a["deadly"] = float(a.lands) - float(a.stops) >= hp and not ends
		if bool(a.ult):
			continue
		if int(a.sure) > 0 and not bool(a.deadly) and (finisher == null or int(a.sure) > int(finisher.sure) or (int(a.sure) == int(finisher.sure) and int(a.cost) < int(finisher.cost))):
			finisher = a
		if float(a.stops) > 0.0 and (stopper == null or float(a.stops) > float(stopper.stops)):
			stopper = a
		if bool(a.deadly):
			deadly = true
			continue
		# clearly more, or about as much (within 5%) for less energy
		if best == null or score > float(best.score) * 1.05 or (score > float(best.score) * 0.95 and int(a.cost) < int(best.cost)):
			best = a

	# the supports at hand: moves, then the belt
	var heal = null
	var support = null
	var support_worth = 0.0
	var target_unit = RpgBattle.unit(B, focus)
	var heal_short = false     # a heal that is rested and only wants energy
	for m in opt.moves:
		if not bool(m.ok):
			if str(m.get("why", "")) == "energy":
				var short = RpgBattle.move_row(B, str(m.id))
				if short != null and str(short.get("kind", "attack")) == "support" and _has_heal(short.get("fx", [])):
					heal_short = true
			continue
		var row = RpgBattle.move_row(B, str(m.id))
		if row == null or str(row.get("kind", "attack")) != "support":
			continue
		var w = _support_worth(B, row.get("fx", []), target_unit, incoming, false)
		var act = {"t": "move", "id": str(m.id), "target": focus}
		if _has_heal(row.get("fx", [])) and heal == null:
			heal = act
		if w > support_worth:
			support_worth = w
			support = act
	var heal_item = null
	for it in opt.items:
		if not bool(it.ok):
			continue
		var row = RpgBattle.item_row(B, str(it.id))
		if row == null:
			continue
		var w = 0.8 * _support_worth(B, row.get("fx", []), target_unit, incoming, false)      # the belt is not endless
		if _has_heal(row.get("fx", [])) and heal_item == null:
			heal_item = {"t": "item", "id": str(it.id)}
		if w > support_worth and (big_foe or share < LOW_HP):
			support_worth = w
			support = {"t": "item", "id": str(it.id)}

	# 1. a blow that would kill: take it out of the round, or heal, or Guard
	if incoming >= hp:
		if stopper != null and incoming - float(stopper.stops) < hp:
			return stopper.action
		if finisher != null and living.size() == int(finisher.kills) and int(B.wave) >= B.waves.size() - 1:
			return finisher.action
		var in_guard = _lands(B, living, RpgDefs.GUARD_RANK)
		if in_guard <= 0.0:
			var q = _quiet(B, living, attacks, heal, share)
			if not q.is_empty():
				return q
		# a Guard is short: only what lands while it lasts counts against it
		var guarded = in_guard * RpgDefs.guard_mult(float(h.s.get("core", 1.0)), float(h.get("agg", {}).get("guard_pct", 0.0)))
		if guarded < hp:
			return {"t": "guard"}
		if heal != null:
			return heal
		if heal_item != null:
			return heal_item
		return {"t": "guard"}
	# 2. finish a foe
	if finisher != null:
		return finisher.action
	# 3. a telegraphed heavy hit: break it off, else Guard
	if telegraphed or biggest >= HEAVY * hp_max:
		if stopper != null and float(stopper.stops) >= biggest:
			return stopper.action
		if _lands(B, living, RpgDefs.GUARD_RANK) <= 0.0:
			var q = _quiet(B, living, attacks, heal, share)
			if not q.is_empty():
				return q
		return {"t": "guard"}
	# 4. heal when low (short of the energy for it: Guard, which brings 2, or Strike, which brings 1)
	if share < LOW_HP:
		if heal != null:
			return heal
		if heal_item != null and share < 0.3:
			return heal_item
		if heal_short:
			if incoming > 0.0:
				return {"t": "guard"}
			if bool(opt.strike):
				return {"t": "strike", "target": focus}
	# 5. the ultimate: on a broken or a dangerous foe, or whenever little of it would be wasted
	if bool(opt.ult.ok):
		var urow = RpgBattle.move_row(B, str(opt.ult.id))
		if urow != null and str(urow.get("kind", "attack")) == "attack":
			var top = null
			for a in attacks:
				if bool(a.ult) and (top == null or float(a.score) > float(top.score)):
					top = a
			if top != null:
				var tu = RpgBattle.unit(B, str(top.action.get("target", "")))
				var broken = tu != null and bool(tu.get("broken", false))
				if broken or big_foe or int(top.kills) > 0 or best == null or float(top.raw) >= 1.5 * float(best.raw):
					return top.action
		elif urow != null:
			if not _has_heal(urow.get("fx", [])) or share < 0.5:
				return {"t": "ult", "target": focus}
	# 6. a buff or a debuff when the fight will last
	if support != null and support_worth >= SUPPORT_MIN and (best == null or left_total > 2.0 * float(best.raw)):
		return support
	# 7. the most damage for the time it takes (never a move so slow that a killing blow gets in)
	if best != null:
		return best.action
	if deadly:
		return {"t": "guard"}
	return {"t": "strike", "target": focus}
