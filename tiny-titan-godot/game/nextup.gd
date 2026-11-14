class_name NextUp
extends RefCounted
## "What am I closest to?" (port of nextup.ts): surfaces the nearest unfinished
## goals across achievements, gear, pets, body stages and mastery ranks.
##
## NextGoal: {
##   key: String ("a:<achievement id>" | "i:<item id>" | "p:<pet id>" | "stage" | "r:<discipline>"),
##   kind: "achievement" | "item" | "pet" | "stage" | "rank",
##   icon: String, title: String,
##   sub: String (what you get, or how to get it),
##   progress: {cur, target, unit} (see Goals; format with Fmt.fmt_progress),
##   ratio: float 0..1,
##   discipline: "lift" | "climb" | "run" | "ride" | null }


## Every goal that is not finished yet (ratio < 1), in catalog order:
## achievements, items, pets, the next body stage, then the next rank of each
## discipline the player has used. Secret achievements are left out.
static func all_open_goals(s: Dictionary) -> Array:
	var out: Array = []

	for a in Achievements.all():
		if s.achievements.has(a.id) or a.get("progress") == null or TTUtil.truthy(a.get("secret")):
			continue
		var p: Dictionary = a.progress.call(s)
		out.append({
			"key": "a:%s" % a.id,
			"kind": "achievement",
			"icon": a.icon,
			"title": a.name,
			"sub": "%s · +%s XP" % [a.desc, TTUtil.num_str(a.xp)],
			"progress": p,
			"ratio": Goals.progress_ratio(p),
			"discipline": a.group if _is_disc(a.group) else null,
		})
	for it in Items.all():
		if s.items.has(it.id) or it.unlock.kind != "unlock" or it.unlock.get("progress") == null:
			continue
		var p: Dictionary = it.unlock.progress.call(s)
		out.append({
			"key": "i:%s" % it.id,
			"kind": "item",
			"icon": "🎁",
			"title": it.name,
			"sub": it.unlock.hint,
			"progress": p,
			"ratio": Goals.progress_ratio(p),
			"discipline": it.get("discipline"),
		})
	for pet in Pets.all():
		if s.pets.has(pet.id) or pet.get("progress") == null:
			continue
		var p: Dictionary = pet.progress.call(s)
		out.append({
			"key": "p:%s" % pet.id,
			"kind": "pet",
			"icon": "🐾",
			"title": "%s the %s" % [pet.name, pet.species],
			"sub": pet.hint,
			"progress": p,
			"ratio": Goals.progress_ratio(p),
			"discipline": pet.get("discipline"),
		})

	var next_stage_index: int = int(s.stage) + 1
	if next_stage_index < Xp.STAGES.size():
		var next_stage: Dictionary = Xp.STAGES[next_stage_index]
		out.append({
			"key": "stage",
			"kind": "stage",
			"icon": "🧬",
			"title": "Evolve: %s" % next_stage.name,
			"sub": "New body stage at hero level %s" % TTUtil.num_str(next_stage.minLevel),
			"progress": {"cur": s.levels.hero.level, "target": next_stage.minLevel, "unit": "level"},
			"ratio": minf(1.0, float(s.xp.hero) / Xp.hero_xp_to_reach(next_stage.minLevel)),
			"discipline": null,
		})
	for d in TT.DISCIPLINES:
		if s.totals.byDiscipline[d] == 0:
			continue
		var next_rank_index: int = int(s.ranks[d]) + 1
		if next_rank_index >= Xp.RANKS.size():
			continue
		var next_rank: Dictionary = Xp.RANKS[next_rank_index]
		var meta: Dictionary = TT.DISCIPLINE_META[d]
		out.append({
			"key": "r:%s" % d,
			"kind": "rank",
			"icon": meta.icon,
			"title": "%s %s" % [meta.name, next_rank.name],
			"sub": "Rank up at %s level %s" % [meta.name.to_lower(), TTUtil.num_str(next_rank.minLevel)],
			"progress": {"cur": s.levels[d].level, "target": next_rank.minLevel, "unit": "level"},
			"ratio": minf(1.0, float(s.xp[d]) / Xp.disc_xp_to_reach(next_rank.minLevel)),
			"discipline": d,
		})

	var open: Array = []
	for g in out:
		if g.ratio < 1:
			open.append(g)
	return open


## The nearest goals, with at most two of any one kind so the list stays varied.
static func next_goals(s: Dictionary, limit: int = 4) -> Array:
	var sorted: Array = all_open_goals(s)
	# Closest first; goals that are equally close keep their catalog order.
	TTUtil.stable_sort(sorted, func(a, b): return a.ratio > b.ratio)
	var per_kind: Dictionary = {}
	var picked: Array = []
	for g in sorted:
		if picked.size() >= limit:
			break
		if g.ratio <= 0:
			continue
		if per_kind.get(g.kind, 0) >= 2:
			continue
		per_kind[g.kind] = per_kind.get(g.kind, 0) + 1
		picked.append(g)
	return picked


static func _is_disc(x) -> bool:
	return x == "lift" or x == "climb" or x == "run" or x == "ride"
