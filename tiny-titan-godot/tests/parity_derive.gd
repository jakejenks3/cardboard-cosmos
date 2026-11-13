extends SceneTree
## Parity test for the engine core: replays the fixtures written by
## tests/parity/gen_derive.ts (the real TypeScript engine) against the
## GDScript port and compares every value.
##
##   godot --headless --path <project> --script res://tests/parity_derive.gd
##
## The project's script classes must be registered first (open it once in
## the editor, or run `godot --headless --path <project> --import`).
##
## Prints up to 15 mismatch paths per failing case, then
##   PARITY derive: X/Y passed
##   PARITY core: X/Y passed
## and exits with 1 on any failure, 0 otherwise.

const EPS = 1e-6
const MAX_SHOWN = 15
const TWO_32 = 4294967296.0

var _core_total: int = 0
var _core_passed: int = 0


func _init() -> void:
	var ok: bool = _run()
	quit(0 if ok else 1)


func _run() -> bool:
	var cases = _load("res://tests/parity/derive_cases.json")
	var core = _load("res://tests/parity/core_vectors.json")
	if not (cases is Array) or not (core is Dictionary):
		print("PARITY derive: 0/0 passed (fixtures missing or unreadable)")
		print("PARITY core: 0/0 passed (fixtures missing or unreadable)")
		return false

	var derive_passed: int = 0
	var started: int = Time.get_ticks_msec()
	for c in cases:
		if _run_derive_case(c):
			derive_passed += 1
	var derive_ms: int = Time.get_ticks_msec() - started

	_run_core(core, cases)

	print("derive replay time: %d ms for %d cases" % [derive_ms, cases.size()])
	print("PARITY derive: %d/%d passed" % [derive_passed, cases.size()])
	print("PARITY core: %d/%d passed" % [_core_passed, _core_total])
	return derive_passed == cases.size() and _core_passed == _core_total and cases.size() > 0 and _core_total > 0


func _load(path: String):
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		printerr("cannot read " + path)
		return null
	var data = JSON.parse_string(text)
	if data == null:
		printerr("cannot parse " + path)
		return null
	return TTUtil.normalize_json(data)


# --- comparison ------------------------------------------------------------------

func _show(v) -> String:
	if v == null:
		return "null"
	var text: String = JSON.stringify(v) if (v is Dictionary or v is Array or v is String) else str(v)
	if text.length() > 120:
		text = text.substr(0, 117) + "..."
	return text


func _is_num(v) -> bool:
	return v is int or v is float


## Appends "path: expected X got Y" lines to `out` for every difference.
## Numbers match within EPS (relative or absolute) whatever their type, two
## ints must be identical, Dictionaries are compared by key set, Arrays by
## index. A missing key and a null value are the same thing (JSON has no
## `undefined`).
func _diff(expected, actual, path: String, out: Array) -> void:
	if out.size() >= 500:
		return
	if expected == null or actual == null:
		if not (expected == null and actual == null):
			out.append("%s: expected %s got %s" % [path, _show(expected), _show(actual)])
		return
	if expected is Dictionary:
		if not (actual is Dictionary):
			out.append("%s: expected %s got %s" % [path, _show(expected), _show(actual)])
			return
		var keys = {}
		for k in expected:
			keys[k] = true
		for k in actual:
			keys[k] = true
		for k in keys:
			_diff(expected.get(k), actual.get(k), path + "." + str(k), out)
		return
	if expected is Array:
		if not (actual is Array):
			out.append("%s: expected %s got %s" % [path, _show(expected), _show(actual)])
			return
		if expected.size() != actual.size():
			out.append("%s.length: expected %d got %d" % [path, expected.size(), actual.size()])
		for i in range(mini(expected.size(), actual.size())):
			_diff(expected[i], actual[i], "%s[%d]" % [path, i], out)
		return
	if _is_num(expected):
		var same: bool = false
		if _is_num(actual):
			if expected is int and actual is int:
				same = expected == actual
			else:
				var e: float = float(expected)
				var a: float = float(actual)
				same = absf(e - a) <= EPS * maxf(1.0, maxf(absf(e), absf(a)))
		if not same:
			out.append("%s: expected %s got %s" % [path, _show(expected), _show(actual)])
		return
	if expected is bool:
		if not (actual is bool) or expected != actual:
			out.append("%s: expected %s got %s" % [path, _show(expected), _show(actual)])
		return
	if expected is String:
		if not (actual is String or actual is StringName) or String(actual) != expected:
			out.append("%s: expected %s got %s" % [path, _show(expected), _show(actual)])
		return
	out.append("%s: unsupported expected value %s" % [path, _show(expected)])


func _report(out: Array) -> void:
	for i in range(mini(out.size(), MAX_SHOWN)):
		print(out[i])
	if out.size() > MAX_SHOWN:
		print("  ... and %d more" % (out.size() - MAX_SHOWN))


# One core vector: counts it and prints its mismatches.
func _check(label: String, expected, actual) -> void:
	_core_total += 1
	var out: Array = []
	_diff(expected, actual, label, out)
	if out.is_empty():
		_core_passed += 1
	else:
		_report(out)


# --- derive ----------------------------------------------------------------------

func _run_derive_case(c: Dictionary) -> bool:
	var label: String = "case[%s]" % c.name
	var input = TTUtil.deep_copy(c.input)
	var actual = Derive.derive(input)
	var out: Array = []
	_diff(c.expected, actual, label, out)
	# The replay must not touch its input.
	_diff(c.input, input, label + ".input", out)
	# ... and must give the same answer when asked again.
	var again = Derive.derive(TTUtil.deep_copy(c.input))
	var repeat: Array = []
	_diff(actual, again, label + ".repeat", repeat)
	if not repeat.is_empty():
		out.append(label + ": a second replay of the same input gave a different state (" + repeat[0] + ")")
	if out.is_empty():
		return true
	_report(out)
	return false


# --- core ------------------------------------------------------------------------

func _run_core(core: Dictionary, cases: Array) -> void:
	_core_hash(core.hashString)
	_core_rng(core.rng)
	_core_dates(core.dates)
	_core_relative_day(core.relativeDay)
	_core_levels(core.levels, core.levelTables)
	_core_small(core)
	_core_sessions(core.sessions)
	_core_catalog(core.catalog)
	_core_states(core.states, cases)


func _core_hash(vectors: Array) -> void:
	for v in vectors:
		_check("hashString[%s]" % _show(v["in"]), v.out, Rng.hash_string(v["in"]))


func _core_rng(vectors: Array) -> void:
	for v in vectors:
		var label: String = "rng[%s]" % _show(v.seed)
		var r = Rng.make_rng(v.seed)
		var floats: Array = []
		var u32: Array = []
		for i in range(8):
			var f: float = r.next()
			floats.append(f)
			u32.append(int(f * TWO_32))
		var ints: Array = []
		for e in v.ints:
			ints.append({"max": e["max"], "out": r.int(e["max"])})
		var picks: Array = []
		for i in range(v.picks.size()):
			picks.append(r.pick(v.pickFrom))
		var weights: Array = v.weights
		var idxs: Array = range(weights.size())
		var weighted: Array = []
		for i in range(v.weighted.size()):
			weighted.append(r.weighted(idxs, func(i2): return weights[i2]))
		var none = r.weighted([0, 1, 2], func(_i): return 0)
		var negative = r.weighted([0, 1, 2], func(i3): return 5 if i3 == 1 else -3)
		var after: int = int(r.next() * TWO_32)
		_check(label, v, {
			"seed": v.seed,
			"floats": floats,
			"u32": u32,
			"ints": ints,
			"pickFrom": v.pickFrom,
			"picks": picks,
			"weights": v.weights,
			"weighted": weighted,
			"weightedNone": none,
			"weightedNegative": negative,
			"after": after,
		})


func _core_dates(vectors: Array) -> void:
	for v in vectors:
		var key: String = v.key
		var p: Dictionary = Dates.parse_date_key(key)
		var add_days: Array = []
		for e in v.addDays:
			add_days.append({"n": e.n, "out": Dates.add_days(key, e.n)})
		var add_weeks: Array = []
		for e in v.addWeeks:
			add_weeks.append({"n": e.n, "out": Dates.add_weeks(key, e.n)})
		var between: Array = []
		for e in v.daysBetween:
			between.append({"other": e.other, "out": Dates.days_between(key, e.other)})
		var formats: Array = []
		for e in v.formats:
			formats.append({"opts": e.opts, "out": Dates.format_date(key, e.opts)})
		_check("dates[%s]" % key, v, {
			"key": key,
			"parts": {"year": p.year, "month": p.month, "day": p.day, "weekday": p.weekday},
			"weekKey": Dates.week_key(key),
			"weekdayIndex": Dates.weekday_index(key),
			"addDays": add_days,
			"addWeeks": add_weeks,
			"daysBetween": between,
			"formatDate": Dates.format_date(key),
			"formatDateLong": Dates.format_date_long(key),
			"formats": formats,
		})
		# Round trips through the other date helpers.
		_check("dates[%s].to_date_key" % key, key, Dates.to_date_key(p))
		_check("dates[%s].today_key" % key, key, Dates.today_key({"year": p.year, "month": p.month, "day": p.day}))


func _core_relative_day(vectors: Array) -> void:
	for v in vectors:
		_check("relativeDay[%s @ %s]" % [v.key, v.today], v.out, Dates.relative_day(v.key, v.today))


func _core_levels(levels: Array, tables: Array) -> void:
	for v in levels:
		_check("levels[%s]" % _show(v.xp), v, {
			"xp": v.xp,
			"hero": Xp.hero_level(v.xp),
			"disc": Xp.disc_level(v.xp),
			"custom": Xp.level_from_xp(v.xp, func(l): return 100 * l),
		})
		# The generic curve walker must agree with the cached tables.
		_check("levels[%s].hero_via_curve" % _show(v.xp), v.hero, Xp.level_from_xp(v.xp, func(l): return Xp.hero_xp_for_level(l)))
		_check("levels[%s].disc_via_curve" % _show(v.xp), v.disc, Xp.level_from_xp(v.xp, func(l): return Xp.disc_xp_for_level(l)))
	for v in tables:
		var level = v.level
		_check("levelTables[%s]" % _show(level), v, {
			"level": level,
			"heroXpForLevel": Xp.hero_xp_for_level(level),
			"discXpForLevel": Xp.disc_xp_for_level(level),
			"heroXpToReach": Xp.hero_xp_to_reach(level),
			"discXpToReach": Xp.disc_xp_to_reach(level),
			"stageForLevel": Xp.stage_for_level(level),
			"rankForLevel": Xp.rank_for_level(level),
		})


func _core_small(core: Dictionary) -> void:
	for v in core.e1rm:
		_check("e1rm[%s x %s]" % [_show(v.weightKg), _show(v.reps)], v.out, Xp.e1rm(v.weightKg, v.reps))
	for v in core.grades:
		_check("grades[%s]" % _show(v.grade), v, {
			"grade": v.grade,
			"clampGrade": Xp.clamp_grade(v.grade),
			"climbGradeXp": Xp.climb_grade_xp(v.grade),
			"gradeLabel": Xp.grade_label(v.grade),
		})
	for v in core.fmtInt:
		_check("fmtInt[%s]" % _show(v.n), v.out, Xp.fmt_int(v.n))
	for v in core.normalizeExercise:
		_check("normalizeExercise[%s]" % _show(v.name), v.out, Xp.normalize_exercise(v.name))
	for v in core.isDiscipline:
		_check("isDiscipline[%s]" % _show(v.x), v.out, Xp.is_discipline(v.x))
	for i in range(core.computeStreak.size()):
		var v = core.computeStreak[i]
		_check("computeStreak[%d]" % i, v.out, Derive.compute_streak(TTUtil.deep_copy(v.weekCounts), v.goal, v.nowWeek))
	for i in range(core.bodyEntryReward.size()):
		var v = core.bodyEntryReward[i]
		_check("bodyEntryReward[%d]" % i, v.out, Derive.body_entry_reward(v.flags, v.entry))
	for i in range(core.progressRatio.size()):
		var v = core.progressRatio[i]
		_check("progressRatio[%d]" % i, v.out, Goals.progress_ratio(v.p))
	for i in range(core.weightStepOf.size()):
		var v = core.weightStepOf[i]
		_check("weightStepOf[%s]" % _show(v.settings), v.out, TT.weight_step_of(v.settings))


func _core_sessions(vectors: Array) -> void:
	for v in vectors:
		var label: String = "sessions[%s]" % v.session.id
		var session = TTUtil.deep_copy(v.session)
		_check(label + ".baseSessionXp", v.baseSessionXp, Xp.base_session_xp(session))
		_check(label + ".sessionStats", v.sessionStats, Xp.session_stats(session))
		_check(label + ".untouched", v.session, session)


func _core_catalog(cat: Dictionary) -> void:
	_check("catalog.constants", cat.constants, {
		"WEAK_MULT": Campaign.WEAK_MULT,
		"RARITY_WEIGHT": Items.RARITY_WEIGHT,
		"TIER_COLOR": Achievements.TIER_COLOR,
		"ACH_GROUPS": Achievements.ACH_GROUPS,
		"DEFAULT_SETTINGS": TT.DEFAULT_SETTINGS,
	})
	_check("catalog.zones", cat.zones, Campaign.zones())
	_check("catalog.bosses", cat.bosses, Campaign.bosses())
	for v in cat.bosses:
		_check("catalog.boss_by_id[%s]" % v.id, v, Campaign.boss_by_id(v.id))
	_check("catalog.boss_by_id[unknown]", null, Campaign.boss_by_id("no_such_boss"))
	for v in cat.bossAt:
		_check("catalog.bossAt[%d]" % v.index, v, {"index": v.index, "isEcho": Campaign.is_echo(v.index), "out": Campaign.boss_at(v.index)})
	for v in cat.bossesInZone:
		var listed: Array = []
		for x in Campaign.bosses_in_zone(v.zone):
			listed.append({"id": x.boss.id, "index": x.index})
		_check("catalog.bossesInZone[%d]" % v.zone, v.out, listed)

	var achs: Array = Achievements.all()
	_check("catalog.achievements.length", cat.achievements.size(), achs.size())
	for i in range(mini(cat.achievements.size(), achs.size())):
		var a: Dictionary = achs[i]
		_check("catalog.achievements[%d:%s]" % [i, cat.achievements[i].id], cat.achievements[i], {
			"id": a.id,
			"name": a.name,
			"desc": a.desc,
			"icon": a.icon,
			"xp": a.xp,
			"group": a.group,
			"secret": a.secret,
			"hasProgress": a.has("progress"),
			"tier": Achievements.tier_of(a),
		})
		_check("catalog.achievements.by_id[%s]" % a.id, true, is_same(Achievements.by_id(a.id), a))
	_check("catalog.achievements.by_id[unknown]", null, Achievements.by_id("no_such_trophy"))

	var items: Array = Items.all()
	_check("catalog.items.length", cat.items.size(), items.size())
	for i in range(mini(cat.items.size(), items.size())):
		var it: Dictionary = items[i]
		_check("catalog.items[%d:%s]" % [i, cat.items[i].id], cat.items[i], {
			"id": it.id,
			"name": it.name,
			"slot": it.slot,
			"rarity": it.rarity,
			"discipline": it.get("discipline"),
			"flavor": it.flavor,
			"perk": it.get("perk"),
			"visual": it.visual,
			"unlockKind": it.unlock.kind,
			"minHeroLevel": it.unlock.get("minHeroLevel"),
			"hint": it.unlock.get("hint"),
			"hasProgress": it.unlock.kind == "unlock" and it.unlock.has("progress"),
			"unlockHint": Items.unlock_hint(it),
			"perkSummary": Items.perk_summary(it.get("perk")),
		})
		_check("catalog.items.by_id[%s]" % it.id, true, is_same(Items.by_id(it.id), it))
	_check("catalog.items.by_id[unknown]", null, Items.by_id("no_such_item"))

	var pets: Array = Pets.all()
	_check("catalog.pets.length", cat.pets.size(), pets.size())
	for i in range(mini(cat.pets.size(), pets.size())):
		var pet: Dictionary = pets[i]
		_check("catalog.pets[%d:%s]" % [i, cat.pets[i].id], cat.pets[i], {
			"id": pet.id,
			"name": pet.name,
			"species": pet.species,
			"rarity": pet.rarity,
			"discipline": pet.get("discipline"),
			"flavor": pet.flavor,
			"perk": pet.perk,
			"hint": pet.hint,
			"perkSummary": Items.perk_summary(pet.perk),
		})
		_check("catalog.pets.by_id[%s]" % pet.id, true, is_same(Pets.by_id(pet.id), pet))
	_check("catalog.pets.by_id[unknown]", null, Pets.by_id("no_such_pet"))


func _progress(p) -> Variant:
	if not (p is Dictionary):
		return null
	return {"cur": p.cur, "target": p.target, "unit": p.unit, "ratio": Goals.progress_ratio(p)}


# Every goal in the three catalogs, evaluated on the TS engine's final state
# of each derive case (so this does not depend on Derive.derive being right).
func _core_states(vectors: Array, cases: Array) -> void:
	var by_name = {}
	for c in cases:
		by_name[c.name] = c
	for v in vectors:
		var label: String = "states[%s]" % v["case"]
		if not by_name.has(v["case"]):
			_check(label, "a derive case with this name", null)
			continue
		var s: Dictionary = TTUtil.deep_copy(by_name[v["case"]].expected)

		var achs: Array = []
		for a in Achievements.all():
			achs.append({"id": a.id, "check": a.check.call(s), "progress": _progress(a.progress.call(s)) if a.has("progress") else null})
		_check(label + ".achievements", v.achievements, achs)

		var items: Array = []
		for it in Items.all():
			if it.unlock.kind != "unlock":
				continue
			items.append({"id": it.id, "check": it.unlock.check.call(s), "progress": _progress(Items.unlock_progress(it, s))})
		_check(label + ".items", v.items, items)

		var pets: Array = []
		for pet in Pets.all():
			pets.append({"id": pet.id, "check": pet.check.call(s), "progress": _progress(pet.progress.call(s))})
		_check(label + ".pets", v.pets, pets)

		_check(label + ".computeTitle", v.computeTitle, Derive.compute_title(s))
		_check(label + ".trophyPoints", v.trophyPoints, Achievements.trophy_points(s))
		_check(label + ".counts", v.counts, {
			"items": PlayerState.owned_item_count(s),
			"pets": PlayerState.owned_pet_count(s),
			"defeated": PlayerState.defeated_count(s),
			"hasFirstSession": PlayerState.has_ach(s, "first_session"),
			"hasZone6": PlayerState.has_ach(s, "zone_6"),
		})

		var perks: Array = []
		for e in v.perks:
			perks.append({
				"loadout": e.loadout,
				"activePet": e.activePet,
				"perks": Perks.compute_perks(s, e.loadout, e.activePet),
				"sanitized": Perks.sanitize_loadout(s, e.loadout, e.activePet),
			})
		_check(label + ".perks", v.perks, perks)
		# Nothing above may have modified the state.
		_check(label + ".untouched", by_name[v["case"]].expected, s)
