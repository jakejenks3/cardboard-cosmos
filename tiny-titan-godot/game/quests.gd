class_name Quests
extends RefCounted
## Daily and weekly quests (port of quests.ts). Which quests are offered is
## seeded by the date / week key, so a given day always shows the same quests;
## targets scale with the player's levels and progress is counted from the log.
##
## Quest: {
##   id: String ("d:2026-01-01:1" / "w:2026-01-05:2", the id a QuestClaim refers to),
##   kind: "daily" | "weekly", periodKey: String (date key / Monday key),
##   title, desc, icon: String,
##   discipline: "lift" | "climb" | "run" | "ride" | null (set on discipline quests only),
##   target: number, progress: number (not clamped to target),
##   unit: "sessions" | "days" | "kg" | "sends" | "m" | "xp" | "min" | "disciplines"
##         (unit-aware formatting of progress / target is done by the caller),
##   xp: int (reward), done: bool, claimed: bool }


static func _round_to(n: float, step_size: int) -> int:
	return maxi(step_size, TTUtil.jsround(n / step_size) * step_size)


## {target, unit, title, icon} of the "do some volume" quest for a discipline.
static func _daily_target(d: String, s: Dictionary) -> Dictionary:
	var lv = s.levels[d].level
	match d:
		"lift":
			return {"target": _round_to(1500 + 350 * lv, 500), "unit": "kg", "title": "Move some iron", "icon": "🏋️"}
		"climb":
			return {"target": 4 + int(floor(lv * 0.6)), "unit": "sends", "title": "Send it", "icon": "🧗"}
		"run":
			return {"target": _round_to((2 + lv * 0.35) * 1000, 500), "unit": "m", "title": "Get the miles in", "icon": "👟"}
	return {"target": _round_to((8 + lv * 1.5) * 1000, 1000), "unit": "m", "title": "Spin the wheels", "icon": "🚴"}


static func _discipline_progress(d: String, sessions: Array):
	var p = 0
	for x in sessions:
		if x.discipline != d:
			continue
		var st: Dictionary = Xp.session_stats(x)
		if d == "lift":
			p += st.volumeKg
		elif d == "climb":
			p += st.sends
		else:
			p += st.distanceM
	return p


static func _used_disciplines(s: Dictionary) -> Array:
	var used: Array = []
	for d in TT.DISCIPLINES:
		if s.totals.byDiscipline[d] > 0:
			used.append(d)
	return used


## A discipline the player has logged before, or null for a brand-new player.
## Draws one number from the stream, but only when there is something to pick.
static func _pick_discipline(rng, s: Dictionary):
	var used: Array = _used_disciplines(s)
	if used.is_empty():
		return null
	# Weighted by how much the player actually does each discipline.
	var total = 0
	for d in used:
		total += s.totals.byDiscipline[d]
	var r: float = rng.next() * total
	for d in used:
		r -= s.totals.byDiscipline[d]
		if r < 0:
			return d
	return used[used.size() - 1]


static func _total_minutes(sessions: Array) -> int:
	var sec = 0
	for x in sessions:
		sec += TTUtil.get_or(x, "durationSec", 0)
	return TTUtil.jsround(sec / 60.0)


static func _session_xp_sum(s: Dictionary, sessions: Array):
	var total = 0
	for x in sessions:
		total += TTUtil.get_or(s.sessionXp, x.id, 0)
	return total


static func _quest(id: String, kind: String, period_key: String, title: String, desc: String, icon: String, discipline, target, progress, unit: String, xp: int, claims: Array) -> Dictionary:
	var claimed: bool = false
	for c in claims:
		if c.questId == id:
			claimed = true
			break
	return {
		"id": id,
		"kind": kind,
		"periodKey": period_key,
		"title": title,
		"desc": desc,
		"icon": icon,
		"discipline": discipline,
		"target": target,
		"progress": progress,
		"unit": unit,
		"xp": xp,
		"done": progress >= target,
		"claimed": claimed,
	}


## The three quests of a day. `s` is the current PlayerState, `all_sessions` the
## whole log (only the ones dated `date_key` count), `claims` every QuestClaim.
static func daily_quests(date_key: String, s: Dictionary, all_sessions: Array, claims: Array) -> Array:
	var rng = Rng.make_rng("daily:" + date_key)
	var sessions: Array = []
	for x in all_sessions:
		if x.date == date_key:
			sessions.append(x)
	var out: Array = []
	var hero_lv = s.levels.hero.level

	out.append(_quest("d:%s:0" % date_key, "daily", date_key, "Show up", "Log any session today.", "🙌", null, 1, sessions.size(), "sessions", 150, claims))

	var d = _pick_discipline(rng, s)
	if d != null:
		var t: Dictionary = _daily_target(d, s)
		out.append(_quest("d:%s:1" % date_key, "daily", date_key, t.title, "%s volume today." % TT.DISCIPLINE_META[d].name, t.icon, d, t.target, _discipline_progress(d, sessions), t.unit, 200, claims))
	else:
		out.append(_quest("d:%s:1" % date_key, "daily", date_key, "Break a sweat", "Train for 30 minutes today.", "⏱️", null, 30, _total_minutes(sessions), "min", 200, claims))

	if rng.next() < 0.6:
		var target: int = _round_to(300 + 60 * hero_lv, 50)
		out.append(_quest("d:%s:2" % date_key, "daily", date_key, "XP hunter", "Earn %s XP from sessions today." % Fmt.fmt_num(target, 3), "✨", null, target, _session_xp_sum(s, sessions), "xp", 150, claims))
	else:
		out.append(_quest("d:%s:2" % date_key, "daily", date_key, "Put in the time", "Train for 45 minutes today.", "⏱️", null, 45, _total_minutes(sessions), "min", 150, claims))
	return out


## The quests of a Monday-week (`wk` is the week key): three, plus a body
## check-in quest once the player has opted into body tracking.
static func weekly_quests(wk: String, s: Dictionary, all_sessions: Array, claims: Array, settings: Dictionary) -> Array:
	var rng = Rng.make_rng("weekly:" + wk)
	var sessions: Array = []
	for x in all_sessions:
		if Dates.week_key(x.date) == wk:
			sessions.append(x)
	var out: Array = []
	var hero_lv = s.levels.hero.level
	var goal = max(1, settings.weeklyGoal)

	var days: Dictionary = {}
	var discs: Dictionary = {}
	for x in sessions:
		days[x.date] = true
		discs[x.discipline] = true

	out.append(_quest("w:%s:0" % wk, "weekly", wk, "Consistency", "Train on %s different days this week." % TTUtil.num_str(goal), "📆", null, goal, days.size(), "days", 400, claims))

	var target: int = _round_to(2000 + 300 * hero_lv, 100)
	out.append(_quest("w:%s:1" % wk, "weekly", wk, "Grind", "Earn %s XP from sessions this week." % Fmt.fmt_num(target, 3), "⚔️", null, target, _session_xp_sum(s, sessions), "xp", 500, claims))

	var used: Array = _used_disciplines(s)
	var d = _pick_discipline(rng, s)
	# The second number is only drawn when cross-training is possible at all.
	if used.size() >= 2 and rng.next() < 0.4:
		out.append(_quest("w:%s:2" % wk, "weekly", wk, "Cross-training", "Log sessions in two different disciplines this week.", "🔀", null, 2, discs.size(), "disciplines", 300, claims))
	elif d != null:
		var t: Dictionary = _daily_target(d, s)
		var disc_name: String = TT.DISCIPLINE_META[d].name
		out.append(_quest("w:%s:2" % wk, "weekly", wk, "%s focus" % disc_name, "%s volume this week." % disc_name, t.icon, d, t.target * 3, _discipline_progress(d, sessions), t.unit, 400, claims))
	else:
		out.append(_quest("w:%s:2" % wk, "weekly", wk, "Hours in", "Train for 3 hours this week.", "⏳", null, 180, _total_minutes(sessions), "min", 400, claims))

	# Only offered once the player has opted into body tracking.
	if s.body.entries > 0:
		var checked_in: int = 1 if TTUtil.get_or(s.body.weekFlags, wk, 0) > 0 else 0
		out.append(_quest("w:%s:3" % wk, "weekly", wk, "Check in", "Log your weight or progress photos this week.", "📸", null, 1, checked_in, "sessions", 150, claims))
	return out
