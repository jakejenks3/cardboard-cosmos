class_name Derive
extends RefCounted
## The replay engine (port of derive.ts). Everything the player owns is
## computed by replaying the log in `createdAt` order:
##
##   var state = Derive.derive({
##       "sessions": [...], "claims": [...], "body": [...],   # body is optional
##       "weeklyGoal": 3,
##       "today": Dates.today_key(),   # date key used for the "current" streaks
##   })
##
## The result is a fresh PlayerState Dictionary (see player_state.gd). The
## input is never modified.

const DROP_BASE_CHANCE = 0.22
const DROP_XP_DIVISOR = 6000
const DROP_MAX_CHANCE = 0.6
const DROP_PITY = 3
const MAX_PR_BONUSES_PER_SESSION = 3

## Weekly check-in rewards: each component pays out once per Monday-week.
const BODY_BITS = {"weight": 1, "bodyFat": 2, "front": 4, "side": 8, "back": 16}
const BODY_XP = {"weight": 60, "bodyFat": 20, "photo": 15}

const NOUNS = {
	"lift": ["Lifter", "Ironhand", "Powerhouse"],
	"climb": ["Climber", "Crusher", "Stoneborn"],
	"run": ["Runner", "Pacer", "Windstrider"],
	"ride": ["Rider", "Rouleur", "Wheelborn"],
	"all": ["All-Rounder", "Polymath", "Paragon"],
}

# Exercise names that count for the bodyweight-relative strength goals.
const REL_LIFTS = {
	"benchRatio": ["bench press", "bench", "barbell bench press", "flat bench press"],
	"squatRatio": ["squat", "back squat", "barbell squat", "low bar squat", "high bar squat"],
	"deadliftRatio": ["deadlift", "conventional deadlift", "sumo deadlift", "barbell deadlift"],
}

# week key -> the Monday before it. The streak is recomputed after every
# replayed session, so the same few hundred weeks get asked for over and over.
static var _prev_week_cache = {}


static func _is_pos(v) -> bool:
	return (v is int or v is float) and v > 0


## XP and new flags for a check-in, given the components already rewarded
## this week (`flags`, a bitmask of BODY_BITS). `e` needs only the optional
## `weightKg`, `bodyFatPct` and `photos` fields. Returns {"xp": int, "flags": int}.
static func body_entry_reward(flags, e: Dictionary) -> Dictionary:
	var f: int = int(flags) if (flags is int or flags is float) else 0
	var xp: int = 0
	var grants: Array = []
	if _is_pos(e.get("weightKg")):
		grants.append([BODY_BITS.weight, BODY_XP.weight])
	if _is_pos(e.get("bodyFatPct")):
		grants.append([BODY_BITS.bodyFat, BODY_XP.bodyFat])
	var photos = e.get("photos")
	if photos is Dictionary:
		if TTUtil.truthy(photos.get("front")):
			grants.append([BODY_BITS.front, BODY_XP.photo])
		if TTUtil.truthy(photos.get("side")):
			grants.append([BODY_BITS.side, BODY_XP.photo])
		if TTUtil.truthy(photos.get("back")):
			grants.append([BODY_BITS.back, BODY_XP.photo])
	for g in grants:
		if (f & g[0]) == 0:
			f |= g[0]
			xp += g[1]
	return {"xp": xp, "flags": f}


static func _prev_week(wk: String) -> String:
	var hit = _prev_week_cache.get(wk)
	if hit != null:
		return hit
	var prev: String = Dates.add_weeks(wk, -1)
	if _prev_week_cache.size() > 8192:
		_prev_week_cache.clear()
	_prev_week_cache[wk] = prev
	return prev


## Weekly streak from sessions-per-week counts. `week_counts` is
## {monday key: count}, `goal` the count a week needs, `now_week` the Monday
## of the current week (a week still in progress does not break the streak).
## Returns {"current", "best", "thisWeek", "goal"}.
static func compute_streak(week_counts: Dictionary, goal, now_week: String) -> Dictionary:
	var current: int = 0
	var wk: String = now_week
	if week_counts.get(wk, 0) >= goal:
		current += 1
	wk = _prev_week(wk)
	# With a positive goal this can only walk over existing keys, so the bound
	# never triggers; it only stops a goal of 0 from looping forever.
	var limit: int = week_counts.size() + 1
	while week_counts.get(wk, 0) >= goal and limit > 0:
		current += 1
		wk = _prev_week(wk)
		limit -= 1
	var best: int = 0
	var run: int = 0
	var keys: Array = week_counts.keys()
	keys.sort()
	for k in keys:
		if week_counts.get(k, 0) >= goal:
			run = run + 1 if week_counts.get(_prev_week(k), 0) >= goal else 1
			best = maxi(best, run)
	return {"current": current, "best": maxi(best, current), "thisWeek": week_counts.get(now_week, 0), "goal": goal}


static func _recompute_levels(s: Dictionary) -> void:
	s.levels.hero = Xp.hero_level(s.xp.hero)
	for d in TT.DISCIPLINES:
		s.levels[d] = Xp.disc_level(s.xp[d])


## Title, dominant discipline and body stage for a state.
## Returns {"title": String, "dominant": discipline or null, "stage": int}.
static func compute_title(s: Dictionary) -> Dictionary:
	var stage: int = Xp.stage_for_level(s.levels.hero.level)
	var adj: String = Xp.STAGES[stage].name
	if s.totals.sessions == 0:
		return {"title": adj + " Newcomer", "dominant": null, "stage": stage}
	var total = 0
	for d in TT.DISCIPLINES:
		total += s.xp[d]
	var dominant = null
	var top = 0
	for d in TT.DISCIPLINES:
		if s.xp[d] > top:
			top = s.xp[d]
			dominant = d
	var used: int = 0
	for d in TT.DISCIPLINES:
		if s.totals.byDiscipline[d] > 0:
			used += 1
	var share: float = float(top) / total if total > 0 else 0.0
	var key: String = "all" if (used >= 2 and share < 0.55) else (dominant if dominant != null else "all")
	var tier: int = 0 if stage <= 1 else (1 if stage <= 3 else 2)
	return {"title": adj + " " + NOUNS[key][tier], "dominant": null if key == "all" else dominant, "stage": stage}


static func _is_word_char(c: int) -> bool:
	return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95


# JS `str.replace(/\b\w/g, c => c.toUpperCase())`: upper-case every ASCII
# word character that starts a word.
static func _title_case(text: String) -> String:
	var out: String = ""
	var prev_word: bool = false
	for i in range(text.length()):
		var is_word: bool = _is_word_char(text.unicode_at(i))
		if is_word and not prev_word:
			out += text[i].to_upper()
		else:
			out += text[i]
		prev_word = is_word
	return out


static func _chron(s: Dictionary, e: Dictionary) -> void:
	s.chronicle.append(e)


static func _ensure_start(s: Dictionary, date) -> void:
	if s.seen.started:
		return
	s.seen.started = true
	_chron(s, {"date": date, "kind": "start", "icon": "🌱", "title": "The journey begins", "detail": "Scrawny. Determined. Level 1."})


static func _add_hero_xp(s: Dictionary, date, amount) -> void:
	if amount == null or amount == 0:
		return
	s.xp.hero += amount
	s.xpByDate[date] = s.xpByDate.get(date, 0) + amount
	s.bests.dayXp = max(s.bests.dayXp, s.xpByDate[date])


static func _update_ranks(s: Dictionary, date) -> void:
	for d in TT.DISCIPLINES:
		var r: int = Xp.rank_for_level(s.levels[d].level)
		if r > s.ranks[d]:
			s.ranks[d] = r
			s.bests.maxRank = max(s.bests.maxRank, r)
			var disc_name: String = TT.DISCIPLINE_META[d].name
			_chron(s, {
				"date": date,
				"kind": "rank",
				"icon": "🎖️",
				"title": disc_name + " rank: " + Xp.RANKS[r].name,
				"detail": "Reached " + disc_name.to_lower() + " level " + str(Xp.RANKS[r].minLevel) + ".",
				"discipline": d,
			})


static func _update_ratios(s: Dictionary) -> void:
	var bw = s.body.latestWeightKg
	if not _is_pos(bw):
		return
	for key in REL_LIFTS:
		var best = 0
		for lift_name in REL_LIFTS[key]:
			var pr = s.prs.lifts.get(lift_name)
			if pr != null:
				best = max(best, pr.weightKg)
		if best > 0:
			s.bests[key] = max(s.bests[key], float(best) / bw)


# An unlock record: {at, sessionId?} (+ extra fields).
static func _unlock(date, ref_id, extra = null) -> Dictionary:
	var u = {"at": date}
	if ref_id != null:
		u["sessionId"] = ref_id
	if extra is Dictionary:
		u.merge(extra)
	return u


# Resolve everything that can unlock from the current state: achievements
# (whose XP can trigger more), ranks, condition-based gear and pets, and the
# level / stage chronicle entries.
static func _settle(s: Dictionary, date, ref_id = null) -> void:
	for outer in range(4):
		var changed: bool = false
		for pass_i in range(4):
			_recompute_levels(s)
			_update_ranks(s, date)
			var found_any: bool = false
			for ach in Achievements.all():
				if s.achievements.has(ach.id):
					continue
				if ach.check.call(s):
					s.achievements[ach.id] = _unlock(date, ref_id)
					_add_hero_xp(s, date, ach.xp)
					_chron(s, {"date": date, "kind": "achievement", "icon": ach.icon, "title": ach.name, "detail": ach.desc, "ref": ach.id})
					found_any = true
					changed = true
			if not found_any:
				break
		_recompute_levels(s)
		_update_ranks(s, date)
		for item in Items.all():
			if s.items.has(item.id):
				continue
			if item.unlock.kind == "unlock" and item.unlock.check.call(s):
				s.items[item.id] = _unlock(date, ref_id, {"how": "unlock"})
				_chron(s, {"date": date, "kind": "item", "icon": "🔓", "title": "Unlocked " + item.name, "detail": item.unlock.hint, "ref": item.id})
				changed = true
		for pet in Pets.all():
			if s.pets.has(pet.id):
				continue
			if pet.check.call(s):
				s.pets[pet.id] = _unlock(date, ref_id)
				_chron(s, {"date": date, "kind": "pet", "icon": "🐾", "title": pet.name + " the " + pet.species + " joined you", "detail": pet.hint, "ref": pet.id})
				changed = true
		if not changed:
			break

	var lv: int = s.levels.hero.level
	if lv > s.seen.heroLevel:
		for l in range(s.seen.heroLevel + 1, lv + 1):
			if l % 5 == 0:
				_chron(s, {"date": date, "kind": "level", "icon": "⭐", "title": "Hero level " + str(l)})
		s.seen.heroLevel = lv
	var t: Dictionary = compute_title(s)
	if t.stage > s.seen.stage:
		for st in range(s.seen.stage + 1, t.stage + 1):
			_chron(s, {"date": date, "kind": "stage", "icon": "🧬", "title": "Body evolved: " + Xp.STAGES[st].name, "detail": Xp.STAGES[st].blurb})
		s.seen.stage = t.stage
	s.title = t.title
	s.dominant = t.dominant
	s.stage = t.stage


# Every point of session XP is a point of damage (x WEAK_MULT against a boss
# weak to the session's discipline); overkill carries over to the next boss.
static func _deal_damage(s: Dictionary, session: Dictionary, xp: int) -> void:
	var pool: int = xp
	var dealt: int = 0
	var guard: int = 0
	while guard < 30 and pool > 0:
		guard += 1
		var boss: Dictionary = Campaign.boss_at(s.campaign.index)
		var weak_hit: bool = boss.get("weak") == session.discipline
		var mult: float = Campaign.WEAK_MULT if weak_hit else 1.0
		var remaining: int = boss.hp - s.campaign.damage
		var potential: int = TTUtil.jsround(pool * mult)
		if potential >= remaining:
			dealt += remaining
			pool -= int(ceil(remaining / mult))
			s.campaign.defeated[boss.id] = {"at": session.date, "sessionId": session.id}
			s.campaign.index += 1
			s.campaign.damage = 0
			_add_hero_xp(s, session.date, boss.xp)
			_chron(s, {"date": session.date, "kind": "boss", "icon": "👑" if boss.zoneBoss else "⚔️", "title": "Defeated " + boss.name, "detail": boss.epithet, "ref": boss.id})
		else:
			s.campaign.damage += potential
			dealt += potential
			pool = 0
	s.campaign.totalDamage += dealt
	s.sessionDamage[session.id] = dealt


static func _apply_session(s: Dictionary, session: Dictionary) -> void:
	_ensure_start(s, session.date)
	var st: Dictionary = Xp.session_stats(session)
	var base: int = Xp.base_session_xp(session).xp
	var pr_bonus: int = 0
	var pr_bonus_count: int = 0
	var pr_total: int = 0
	var prs: Dictionary = s.prs
	var date: String = session.date
	var disc: String = session.discipline

	# --- PR detection ---------------------------------------------------------
	if disc == "lift":
		for ex in session.exercises:
			var lift_name: String = Xp.normalize_exercise(ex.name)
			if lift_name == "":
				continue
			var best_w = 0
			var best_e = 0
			var best_reps = 0
			for one_set in ex.sets:
				if one_set.weightKg <= 0 or one_set.reps <= 0:
					continue
				best_w = max(best_w, one_set.weightKg)
				var e = Xp.e1rm(one_set.weightKg, one_set.reps)
				if e > best_e:
					best_e = e
					best_reps = one_set.reps
			if best_w <= 0:
				continue
			var prev = prs.lifts.get(lift_name)
			if prev != null:
				var weight_up: bool = best_w > prev.weightKg + 1e-9
				var improved: bool = weight_up or best_e > prev.e1rm + 1e-6
				if improved:
					pr_total += 1
					if pr_bonus_count < MAX_PR_BONUSES_PER_SESSION:
						pr_bonus += Xp.PR_BONUS.liftExercise
						pr_bonus_count += 1
					prs.lifts[lift_name] = {
						"weightKg": max(prev.weightKg, best_w),
						"e1rm": max(prev.e1rm, best_e),
						"reps": best_reps if best_e > prev.e1rm else prev.reps,
						"date": date,
					}
					if weight_up:
						_chron(s, {"date": date, "kind": "pr", "icon": "🏋️", "title": _title_case(lift_name) + " PR", "val": {"n": best_w, "unit": "kg"}, "discipline": "lift"})
			else:
				prs.lifts[lift_name] = {"weightKg": best_w, "e1rm": best_e, "reps": best_reps, "date": date}
	elif disc == "climb":
		if st.maxGradeSent != null:
			if prs.climbMaxSend != null and st.maxGradeSent > prs.climbMaxSend:
				pr_bonus += Xp.PR_BONUS.climbMaxSend
				pr_total += 1
				_chron(s, {"date": date, "kind": "pr", "icon": "🧗", "title": "New max grade: " + Xp.grade_label(st.maxGradeSent), "discipline": "climb"})
			prs.climbMaxSend = max(prs.climbMaxSend if prs.climbMaxSend != null else -99, st.maxGradeSent)
		if st.maxGradeFlashed != null:
			if prs.climbMaxFlash != null and st.maxGradeFlashed > prs.climbMaxFlash:
				pr_bonus += Xp.PR_BONUS.climbMaxFlash
				pr_total += 1
			prs.climbMaxFlash = max(prs.climbMaxFlash if prs.climbMaxFlash != null else -99, st.maxGradeFlashed)
	elif disc == "run":
		if prs.longestRunM > 0 and st.distanceM > prs.longestRunM:
			pr_bonus += Xp.PR_BONUS.longestRun
			pr_total += 1
			_chron(s, {"date": date, "kind": "pr", "icon": "👟", "title": "Longest run", "val": {"n": st.distanceM, "unit": "m"}, "discipline": "run"})
		prs.longestRunM = max(prs.longestRunM, st.distanceM)
		prs.bestRunElevM = max(prs.bestRunElevM, st.elevationM)
		if st.distanceM >= 5000 and st.paceSecPerKm != null:
			if prs.bestPaceSecPerKm == null or st.paceSecPerKm < prs.bestPaceSecPerKm:
				if prs.bestPaceSecPerKm != null:
					pr_total += 1
				prs.bestPaceSecPerKm = st.paceSecPerKm
	else:
		if prs.longestRideM > 0 and st.distanceM > prs.longestRideM:
			pr_bonus += Xp.PR_BONUS.longestRide
			pr_total += 1
			_chron(s, {"date": date, "kind": "pr", "icon": "🚴", "title": "Longest ride", "val": {"n": st.distanceM, "unit": "m"}, "discipline": "ride"})
		prs.longestRideM = max(prs.longestRideM, st.distanceM)
		prs.bestRideElevM = max(prs.bestRideElevM, st.elevationM)
		if st.distanceM >= 20000 and st.speedKmh != null:
			if prs.bestRideSpeedKmh == null or st.speedKmh > prs.bestRideSpeedKmh:
				if prs.bestRideSpeedKmh != null:
					pr_total += 1
				prs.bestRideSpeedKmh = st.speedKmh

	# --- XP -------------------------------------------------------------------
	var xp: int = TTUtil.jsround(base * (1 + TTUtil.get_or(session, "bonusPct", 0))) + pr_bonus
	s.xp[disc] += xp
	s.sessionXp[session.id] = xp
	_add_hero_xp(s, date, xp)

	# --- totals ---------------------------------------------------------------
	var t: Dictionary = s.totals
	var b: Dictionary = s.bests
	t.sessions += 1
	t.byDiscipline[disc] += 1
	t.durationSec += st.durationSec
	s.dateCounts[date] = s.dateCounts.get(date, 0) + 1
	if s.dateCounts[date] == 1:
		t.activeDays += 1
	b.daySessions = max(b.daySessions, s.dateCounts[date])
	b.sessionDurationSec = max(b.sessionDurationSec, st.durationSec)
	b.sessionPrs = max(b.sessionPrs, pr_total)
	if disc == "lift":
		t.liftVolumeKg += st.volumeKg
		t.liftReps += st.reps
		t.liftSets += st.sets
		for n in st.exerciseNames:
			t.liftExercises[n] = true
		b.maxSetKg = max(b.maxSetKg, st.maxSetKg)
		b.sessionVolumeKg = max(b.sessionVolumeKg, st.volumeKg)
		b.sessionBwReps = max(b.sessionBwReps, st.bwReps)
		_update_ratios(s)
	elif disc == "climb":
		t.climbSends += st.sends
		t.climbFlashes += st.flashes
		t.climbAttempts += st.attempts
		b.sessionSends = max(b.sessionSends, st.sends)
		b.sessionFlashes = max(b.sessionFlashes, st.flashes)
		b.sessionAttempts = max(b.sessionAttempts, st.attempts)
		var v_points = 0
		for c in session.climbs:
			if c.result != "attempt":
				v_points += max(0, c.grade) * max(0, c["count"])
		b.sessionVPoints = max(b.sessionVPoints, v_points)
	elif disc == "run":
		t.runDistanceM += st.distanceM
		t.runElevationM += st.elevationM
	else:
		t.rideDistanceM += st.distanceM
		t.rideElevationM += st.elevationM

	# --- weeks / months / streak ---------------------------------------------
	var wk: String = Dates.week_key(date)
	s.weekCounts[wk] = s.weekCounts.get(wk, 0) + 1
	s.weekDays[wk] = s.weekDays.get(wk, 0) | (1 << Dates.weekday_index(date))
	# bits 5 and 6 = Saturday and Sunday
	if (s.weekDays[wk] & 0b1100000) == 0b1100000:
		b.weekendWarrior = 1
	var disc_idx: int = TT.DISCIPLINES.find(disc)
	s.weekDisc[wk] = s.weekDisc.get(wk, 0) | ((1 << disc_idx) if disc_idx >= 0 else 0)
	var bits: int = s.weekDisc[wk]
	var n_disc: int = 0
	while bits > 0:
		n_disc += bits & 1
		bits >>= 1
	b.weekDisciplines = max(b.weekDisciplines, n_disc)
	var month: String = date.substr(0, 7)
	s.monthCounts[month] = s.monthCounts.get(month, 0) + 1
	b.monthSessions = max(b.monthSessions, s.monthCounts[month])
	if TTUtil.truthy(s.lastSessionDate):
		if date > s.lastSessionDate:
			b.gapDays = max(b.gapDays, Dates.days_between(s.lastSessionDate, date))
			s.lastSessionDate = date
	else:
		s.lastSessionDate = date
	s.streak = compute_streak(s.weekCounts, s.streak.goal, wk)

	# --- campaign -------------------------------------------------------------
	_deal_damage(s, session, xp)

	_settle(s, date, session.id)

	# --- loot roll ------------------------------------------------------------
	var rng = Rng.make_rng("drop:" + TTUtil.num_str(session.id))
	var luck = 1 + TTUtil.get_or(session, "luckPct", 0)
	var chance = min(DROP_MAX_CHANCE, DROP_BASE_CHANCE + xp / float(DROP_XP_DIVISOR)) * luck
	if s.sessionsSinceDrop >= DROP_PITY:
		chance = 1
	var roll: float = rng.next()
	var hero_lv: int = s.levels.hero.level
	var pool: Array = []
	for item in Items.all():
		if item.unlock.kind == "drop" and not s.items.has(item.id) and TTUtil.get_or(item.unlock, "minHeroLevel", 0) <= hero_lv:
			pool.append(item)
	if not pool.is_empty() and roll < chance:
		var picked = rng.weighted(pool, func(i): return Derive._drop_weight(i, disc))
		if picked != null:
			s.items[picked.id] = {"at": date, "sessionId": session.id, "how": "drop"}
			s.sessionsSinceDrop = 0
			_chron(s, {"date": date, "kind": "item", "icon": "🎁", "title": "Found " + picked.name, "detail": picked.flavor, "ref": picked.id})
			_settle(s, date, session.id)
	elif not pool.is_empty():
		s.sessionsSinceDrop += 1


# Loot weight of an item for a session of `disc`: rarity weight, x3 for gear
# of the session's own discipline, x1.5 for general gear, x0.4 for the rest.
static func _drop_weight(item: Dictionary, disc: String) -> float:
	var r = Items.RARITY_WEIGHT[item.rarity]
	var item_disc = item.get("discipline")
	var dm = 1.5 if not TTUtil.truthy(item_disc) else (3 if item_disc == disc else 0.4)
	return r * dm


static func _body_streak(s: Dictionary, now_week: String) -> Dictionary:
	var counts = {}
	for wk in s.body.weekFlags:
		if TTUtil.truthy(s.body.weekFlags[wk]):
			counts[wk] = 1
	return compute_streak(counts, 1, now_week)


static func _apply_body(s: Dictionary, e: Dictionary) -> void:
	_ensure_start(s, e.date)
	var b: Dictionary = s.body
	b.entries += 1
	var wk: String = Dates.week_key(e.date)
	var r: Dictionary = body_entry_reward(b.weekFlags.get(wk, 0), e)
	if r.flags != 0:
		b.weekFlags[wk] = r.flags

	var weight = e.get("weightKg")
	if _is_pos(weight):
		b.weightEntries += 1
		if b.firstWeightDate == null:
			_chron(s, {"date": e.date, "kind": "body", "icon": "⚖️", "title": "First weigh-in", "val": {"n": weight, "unit": "kg"}})
		if b.firstWeightDate == null or e.date < b.firstWeightDate:
			b.firstWeightDate = e.date
			b.firstWeightKg = weight
		if b.latestWeightDate == null or e.date >= b.latestWeightDate:
			b.latestWeightDate = e.date
			b.latestWeightKg = weight
	var body_fat = e.get("bodyFatPct")
	if _is_pos(body_fat):
		b.bfEntries += 1
		if b.latestBodyFatDate == null or e.date >= b.latestBodyFatDate:
			b.latestBodyFatDate = e.date
			b.latestBodyFat = body_fat
	var n_photos: int = 0
	var photos = e.get("photos")
	if photos is Dictionary:
		for angle in TT.PHOTO_ANGLES:
			if TTUtil.truthy(photos.get(angle)):
				n_photos += 1
	if n_photos > 0:
		b.photoEntries += 1
	if n_photos == 3:
		b.fullSets += 1
		_chron(s, {"date": e.date, "kind": "body", "icon": "📸", "title": "Progress photos taken", "detail": "Front, side and back.", "ref": e.id})
	var st: Dictionary = _body_streak(s, wk)
	b.streak = st.current
	b.bestStreak = max(b.bestStreak, st.best)

	s.bodyXp[e.id] = r.xp
	_add_hero_xp(s, e.date, r.xp)
	_update_ratios(s)
	_settle(s, e.date, e.id)


static func _apply_claim(s: Dictionary, claim: Dictionary) -> void:
	_add_hero_xp(s, claim.date, claim.xp)
	_settle(s, claim.date, claim.id)


## Replay the whole log into a PlayerState. `input`:
##   {"sessions": [Session], "claims": [QuestClaim], "body": [BodyEntry] (optional),
##    "weeklyGoal": int, "today": date key}
static func derive(input: Dictionary) -> Dictionary:
	var s: Dictionary = PlayerState.initial_state(input.weeklyGoal)
	for item in Items.all():
		if item.unlock.kind == "start":
			s.items[item.id] = {"at": "", "how": "start"}
	var steps: Array = []
	for session in TTUtil.get_or(input, "sessions", []):
		steps.append({"t": session.createdAt, "session": session})
	for claim in TTUtil.get_or(input, "claims", []):
		steps.append({"t": claim.claimedAt, "claim": claim})
	for entry in TTUtil.get_or(input, "body", []):
		steps.append({"t": entry.createdAt, "body": entry})
	# Stable: steps logged at the same instant replay in input order.
	TTUtil.stable_sort(steps, func(a, b): return a.t < b.t)
	for step in steps:
		if step.has("session"):
			_apply_session(s, step.session)
		elif step.has("claim"):
			_apply_claim(s, step.claim)
		elif step.has("body"):
			_apply_body(s, step.body)
	var now_week: String = Dates.week_key(input.today)
	s.streak = compute_streak(s.weekCounts, input.weeklyGoal, now_week)
	s.body.streak = _body_streak(s, now_week).current
	if steps.is_empty():
		var t: Dictionary = compute_title(s)
		s.title = t.title
		s.stage = t.stage
	return s
