class_name Diff
extends RefCounted
## The "results reel" (port of diff.ts): the list of things that changed between
## two PlayerStates, in the order they are shown after logging something.
##
## Every event is a Dictionary with a "type":
##   xp          {discipline, amount, parts: [{label, xp}], prBonus, bonusPct,
##                hero: {before, after}, disc: {before, after}}   (before / after are LevelInfo)
##   import      {count, xp, byDiscipline: {lift, climb, run, ride}, hero: {before, after}}
##   bodyxp      {amount, hero: {before, after}}
##   levelup     {track: "hero" | discipline, from, to}
##   rank        {discipline, from, to}        (indexes into Xp.RANKS)
##   stage       {from, to}                    (indexes into Xp.STAGES)
##   boss        {index, damage, weak: bool, hpBefore, hpAfter, maxHp, defeated: bool}
##   pr          {icon, title, detail}
##   achievement {id}
##   item        {id, how: "drop" | "unlock" | "start"}
##   pet         {id}
##   streak      {current}


static func _level_events(before: Dictionary, after: Dictionary, tracks: Array) -> Array:
	var ev: Array = []
	for track in tracks:
		if after.levels[track].level > before.levels[track].level:
			ev.append({"type": "levelup", "track": track, "from": before.levels[track].level, "to": after.levels[track].level})
	for d in TT.DISCIPLINES:
		if after.ranks[d] > before.ranks[d]:
			ev.append({"type": "rank", "discipline": d, "from": before.ranks[d], "to": after.ranks[d]})
	if after.stage > before.stage:
		ev.append({"type": "stage", "from": before.stage, "to": after.stage})
	return ev


## One event per boss that took damage between the two states.
static func _boss_events(before: Dictionary, after: Dictionary, discipline, defeated_only: bool = false) -> Array:
	var ev: Array = []
	var first: int = int(before.campaign.index)
	var last: int = int(after.campaign.index)
	for i in range(first, last + 1):
		var boss: Dictionary = Campaign.boss_at(i)
		var hp_before = boss.hp - (before.campaign.damage if i == first else 0)
		var defeated: bool = i < last
		var hp_after = 0 if defeated else boss.hp - after.campaign.damage
		if hp_before == hp_after:
			continue
		if defeated_only and not defeated:
			continue
		ev.append({
			"type": "boss",
			"index": i,
			"damage": hp_before - hp_after,
			"weak": discipline != null and boss.get("weak") == discipline,
			"hpBefore": hp_before,
			"hpAfter": hp_after,
			"maxHp": boss.hp,
			"defeated": defeated,
		})
	return ev


static func _unlock_events(before: Dictionary, after: Dictionary) -> Array:
	var ev: Array = []
	for id in after.achievements:
		if not before.achievements.has(id):
			ev.append({"type": "achievement", "id": id})
	for id in after.items:
		if not before.items.has(id):
			ev.append({"type": "item", "id": id, "how": after.items[id].how})
	for id in after.pets:
		if not before.pets.has(id):
			ev.append({"type": "pet", "id": id})
	return ev


static func _streak_events(before: Dictionary, after: Dictionary) -> Array:
	if after.streak.current > before.streak.current and after.streak.current >= 2:
		return [{"type": "streak", "current": after.streak.current}]
	return []


static func _hero_pair(before: Dictionary, after: Dictionary) -> Dictionary:
	return {"before": before.levels.hero, "after": after.levels.hero}


## Everything that changed because `session` was added: the results reel.
static func diff_states(before: Dictionary, after: Dictionary, session: Dictionary) -> Array:
	var ev: Array = []
	var d: String = session.discipline
	var amount = TTUtil.get_or(after.sessionXp, session.id, 0)
	var base: Dictionary = Xp.base_session_xp(session)
	var bonus_pct = TTUtil.get_or(session, "bonusPct", 0)
	var with_perk: int = TTUtil.jsround(base.xp * (1 + bonus_pct))
	ev.append({
		"type": "xp",
		"discipline": d,
		"amount": amount,
		"parts": base.parts,
		"prBonus": max(0, amount - with_perk),
		"bonusPct": bonus_pct,
		"hero": _hero_pair(before, after),
		"disc": {"before": before.levels[d], "after": after.levels[d]},
	})
	ev.append_array(_boss_events(before, after, d))
	ev.append_array(_level_events(before, after, [d, "hero"]))

	# PRs
	var bp: Dictionary = before.prs
	var ap: Dictionary = after.prs
	for lift_name in ap.lifts:
		var pr: Dictionary = ap.lifts[lift_name]
		var prev = bp.lifts.get(lift_name)
		if prev == null:
			continue
		if pr.weightKg > prev.weightKg + 1e-9:
			ev.append({"type": "pr", "icon": "🏋️", "title": "%s PR" % _title_case(lift_name), "detail": "%s kg (was %s kg)" % [_trim(pr.weightKg), _trim(prev.weightKg)]})
		elif pr.e1rm > prev.e1rm + 1e-6:
			ev.append({"type": "pr", "icon": "📈", "title": "%s est. 1RM PR" % _title_case(lift_name), "detail": "%s kg (was %s kg)" % [_trim(pr.e1rm), _trim(prev.e1rm)]})
	if ap.climbMaxSend != null and (bp.climbMaxSend == null or ap.climbMaxSend > bp.climbMaxSend):
		ev.append({
			"type": "pr",
			"icon": "🧗",
			"title": "Max grade set" if bp.climbMaxSend == null else "New max grade!",
			"detail": Xp.grade_label(ap.climbMaxSend) if bp.climbMaxSend == null else "%s (was %s)" % [Xp.grade_label(ap.climbMaxSend), Xp.grade_label(bp.climbMaxSend)],
		})
	if ap.climbMaxFlash != null and (bp.climbMaxFlash == null or ap.climbMaxFlash > bp.climbMaxFlash):
		ev.append({
			"type": "pr",
			"icon": "⚡",
			"title": "Max flash set" if bp.climbMaxFlash == null else "New max flash!",
			"detail": Xp.grade_label(ap.climbMaxFlash) if bp.climbMaxFlash == null else "%s (was %s)" % [Xp.grade_label(ap.climbMaxFlash), Xp.grade_label(bp.climbMaxFlash)],
		})
	if bp.longestRunM > 0 and ap.longestRunM > bp.longestRunM:
		ev.append({"type": "pr", "icon": "👟", "title": "Longest run!", "detail": "%s km (was %s km)" % [Fmt.to_fixed(ap.longestRunM / 1000.0, 1), Fmt.to_fixed(bp.longestRunM / 1000.0, 1)]})
	if bp.longestRideM > 0 and ap.longestRideM > bp.longestRideM:
		ev.append({"type": "pr", "icon": "🚴", "title": "Longest ride!", "detail": "%s km (was %s km)" % [Fmt.to_fixed(ap.longestRideM / 1000.0, 1), Fmt.to_fixed(bp.longestRideM / 1000.0, 1)]})
	if bp.bestPaceSecPerKm != null and ap.bestPaceSecPerKm != null and ap.bestPaceSecPerKm < bp.bestPaceSecPerKm - 1e-6:
		ev.append({"type": "pr", "icon": "💨", "title": "Fastest pace (5 km+)!", "detail": "%s /km (was %s)" % [_pace(ap.bestPaceSecPerKm), _pace(bp.bestPaceSecPerKm)]})
	if bp.bestRideSpeedKmh != null and ap.bestRideSpeedKmh != null and ap.bestRideSpeedKmh > bp.bestRideSpeedKmh + 1e-6:
		ev.append({"type": "pr", "icon": "💨", "title": "Fastest ride (20 km+)!", "detail": "%s km/h (was %s)" % [Fmt.to_fixed(ap.bestRideSpeedKmh, 1), Fmt.to_fixed(bp.bestRideSpeedKmh, 1)]})

	ev.append_array(_unlock_events(before, after))
	ev.append_array(_streak_events(before, after))
	return ev


## Results reel for a batch of sessions (e.g. an import).
static func diff_bulk(before: Dictionary, after: Dictionary, sessions: Array) -> Array:
	var ev: Array = []
	var by_discipline: Dictionary = {"lift": 0, "climb": 0, "run": 0, "ride": 0}
	var xp = 0
	for s in sessions:
		var v = TTUtil.get_or(after.sessionXp, s.id, 0)
		by_discipline[s.discipline] += v
		xp += v
	ev.append({"type": "import", "count": sessions.size(), "xp": xp, "byDiscipline": by_discipline, "hero": _hero_pair(before, after)})
	ev.append_array(_boss_events(before, after, null, true))
	ev.append_array(_level_events(before, after, ["lift", "climb", "run", "ride", "hero"]))
	ev.append_array(_unlock_events(before, after))
	ev.append_array(_streak_events(before, after))
	return ev


## Results reel for a body check-in.
static func diff_body(before: Dictionary, after: Dictionary, entry: Dictionary) -> Array:
	var ev: Array = []
	ev.append({"type": "bodyxp", "amount": TTUtil.get_or(after.bodyXp, entry.id, 0), "hero": _hero_pair(before, after)})
	ev.append_array(_level_events(before, after, ["hero"]))
	ev.append_array(_unlock_events(before, after))
	return ev


static func total_discipline_xp(s: Dictionary):
	var total = 0
	for d in TT.DISCIPLINES:
		total += s.xp[d]
	return total


# JS `\w`: ASCII letters, digits and underscore only.
static func _is_word_char(code: int) -> bool:
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 95


## JS `s.replace(/\b\w/g, c => c.toUpperCase())`: upper-case every word
## character that starts a run of word characters ("pull-up" -> "Pull-Up").
static func _title_case(text: String) -> String:
	var out: String = ""
	var prev_word: bool = false
	for i in range(text.length()):
		var ch: String = text[i]
		var is_word: bool = _is_word_char(text.unicode_at(i))
		out += ch.to_upper() if (is_word and not prev_word) else ch
		prev_word = is_word
	return out


## Whole numbers as they are, anything else with one decimal.
static func _trim(n: float) -> String:
	if n == floor(n):
		return str(int(n))
	return Fmt.to_fixed(n, 1)


static func _pace(sec_per_km: float) -> String:
	var m: int = int(floor(sec_per_km / 60.0))
	var s: int = TTUtil.jsround(fmod(sec_per_km, 60.0))
	return "%s:%s" % [str(m), str(s).lpad(2, "0")]
