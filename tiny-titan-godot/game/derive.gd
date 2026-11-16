class_name Derive
extends RefCounted
## The replay engine (port of derive.ts). Everything the player owns is
## computed by replaying the log in `createdAt` order:
##
##   var state = Derive.derive({
##       "sessions": [...], "claims": [...], "body": [...],   # body is optional
##       "purchases": [...],                                  # optional, see Wallet
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
		if st.get("maxRouteSent") != null:
			if prs.get("climbMaxRoute") != null and st.maxRouteSent > prs.climbMaxRoute:
				pr_bonus += Xp.PR_BONUS.climbMaxRoute
				pr_total += 1
				_chron(s, {"date": date, "kind": "pr", "icon": "🧗", "title": "New max route: " + Xp.yds_label(st.maxRouteSent), "discipline": "climb"})
			prs.climbMaxRoute = max(prs.climbMaxRoute if prs.get("climbMaxRoute") != null else -99, st.maxRouteSent)
		if st.get("maxRouteFlashed") != null:
			if prs.get("climbMaxRouteFlash") != null and st.maxRouteFlashed > prs.climbMaxRouteFlash:
				pr_bonus += Xp.PR_BONUS.climbMaxRouteFlash
				pr_total += 1
			prs.climbMaxRouteFlash = max(prs.climbMaxRouteFlash if prs.get("climbMaxRouteFlash") != null else -99, st.maxRouteFlashed)
		if st.get("bestHangKg") != null:
			if prs.get("bestHangKg") != null and float(st.bestHangKg) > 0.0 and float(st.bestHangKg) > float(prs.bestHangKg):
				pr_bonus += Xp.PR_BONUS.bestHang
				pr_total += 1
				_chron(s, {"date": date, "kind": "pr", "icon": "🧗", "title": "Heaviest hang", "val": {"n": st.bestHangKg, "unit": "kg"}, "discipline": "climb"})
			prs.bestHangKg = maxf(float(prs.bestHangKg) if prs.get("bestHangKg") != null else -9999.0, float(st.bestHangKg))
		# Hangboard records per edge: the heaviest 5 s+ hang on each edge size,
		# two-arm and one-arm apart; assisted hangs set no record.
		for h in session.get("hangs", []):
			var h_sec: int = int(h.get("sec", 0))
			var h_add: float = float(h.get("addKg", 0.0))
			if h_sec <= 0 or int(h.get("count", 0)) <= 0:
				continue
			if prs.get("longestHangSec") == null or h_sec > int(prs.longestHangSec):
				prs.longestHangSec = h_sec
			if h_sec < 5 or h_add < 0.0:
				continue
			var table: String = "hangOneArm" if int(h.get("arms", 2)) == 1 else "hangEdge"
			if prs.get(table) == null:
				prs[table] = {}
			var ek: String = str(int(h.get("edgeMm", 0)))
			var prev_kg = prs[table].get(ek)
			if prev_kg == null or h_add > float(prev_kg) + 1e-9:
				if prev_kg != null:
					pr_total += 1
					_chron(s, {"date": date, "kind": "pr", "icon": "🧗", "title": "%s %s hang PR" % [Xp.edge_label(int(ek)), "one-arm" if table == "hangOneArm" else "two-arm"], "val": {"n": h_add, "unit": "kg"}, "discipline": "climb"})
				prs[table][ek] = h_add
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
	elif disc == "ride":
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
	elif disc == TT.MISC:
		# An activity outside the four disciplines (game/misc.gd): its own totals and records.
		var mr: Dictionary = Misc.record(s, session, st)
		pr_bonus += int(mr.bonus)
		pr_total += int(mr.prs)

	# --- XP -------------------------------------------------------------------
	var xp: int = TTUtil.jsround(base * (1 + TTUtil.get_or(session, "bonusPct", 0))) + pr_bonus
	if s.xp.has(disc):
		s.xp[disc] += xp
	else:
		Misc.add_xp(s, session, xp)
	s.sessionXp[session.id] = xp
	_add_hero_xp(s, date, xp)

	# --- totals ---------------------------------------------------------------
	var t: Dictionary = s.totals
	var b: Dictionary = s.bests
	t.sessions += 1
	if t.byDiscipline.has(disc):
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
		if int(TTUtil.get_or(st, "routes", 0)) > 0:
			t.climbRoutes = int(TTUtil.get_or(t, "climbRoutes", 0)) + int(st.routes)
		if int(TTUtil.get_or(st, "hangs", 0)) > 0:
			t.hangs = int(TTUtil.get_or(t, "hangs", 0)) + int(st.hangs)
			t.hangSec = int(TTUtil.get_or(t, "hangSec", 0)) + int(TTUtil.get_or(st, "hangSec", 0))
		b.sessionSends = max(b.sessionSends, st.sends)
		b.sessionFlashes = max(b.sessionFlashes, st.flashes)
		b.sessionAttempts = max(b.sessionAttempts, st.attempts)
		var v_points = 0
		for c in session.get("climbs", []):
			if c.result != "attempt":
				v_points += max(0, c.grade) * max(0, c["count"])
		b.sessionVPoints = max(b.sessionVPoints, v_points)
		# Card hands: what this session's boulder sends look like as a poker hand.
		var hc = {}
		var hf = {}
		for c in session.get("climbs", []):
			if c.result == "attempt" or Xp.is_route(c):
				continue
			var g: int = int(c.grade)
			var n: int = max(0, int(c["count"]))
			if n <= 0:
				continue
			hc[g] = int(hc.get(g, 0)) + n
			if c.result == "flash":
				hf[g] = int(hf.get(g, 0)) + n
		if not s.has("hands"):
			s["hands"] = PlayerState.initial_state(3).hands
		_deal_hands(s.hands, hc, hf, int(st.sends))
	elif disc == "run":
		t.runDistanceM += st.distanceM
		t.runElevationM += st.elevationM
	elif disc == "ride":
		t.rideDistanceM += st.distanceM
		t.rideElevationM += st.elevationM

	if not s.has("quirks"):
		s["quirks"] = PlayerState.initial_state(3).quirks
	if TT.DISCIPLINES.has(disc):
		_deal_quirks(s.quirks, session, st, date, disc)

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
		# Photo milestones: how long the album spans and how many months it covers.
		if b.get("firstPhotoDate") == null or e.date < str(b.firstPhotoDate):
			b.firstPhotoDate = e.date
		b.photoSpanDays = max(int(TTUtil.get_or(b, "photoSpanDays", 0)), absi(Dates.days_between(str(b.firstPhotoDate), e.date)))
		if b.get("photoMonthKeys") == null:
			b.photoMonthKeys = {}
		b.photoMonthKeys[e.date.substr(0, 7)] = true
		b.photoMonths = b.photoMonthKeys.size()
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


# Something bought in the shop (see Wallet): the item joins the collection.
static func _apply_purchase(s: Dictionary, buy: Dictionary) -> void:
	var item = Items.by_id(buy.get("itemId"))
	if item == null or s.items.has(item.id):
		return
	var date: String = str(buy.get("date", ""))
	s.items[item.id] = _unlock(date, buy.get("id"), {"how": "shop"})
	_chron(s, {"date": date, "kind": "item", "icon": "🪙", "title": "Bought " + item.name, "detail": item.flavor, "ref": item.id})
	_settle(s, date, buy.get("id"))


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
	for buy in TTUtil.get_or(input, "purchases", []):
		steps.append({"t": buy.at, "buy": buy})
	# Stable: steps logged at the same instant replay in input order.
	TTUtil.stable_sort(steps, func(a, b): return a.t < b.t)
	for step in steps:
		if step.has("session"):
			_apply_session(s, step.session)
		elif step.has("claim"):
			_apply_claim(s, step.claim)
		elif step.has("body"):
			_apply_body(s, step.body)
		elif step.has("buy"):
			_apply_purchase(s, step.buy)
	var now_week: String = Dates.week_key(input.today)
	s.streak = compute_streak(s.weekCounts, input.weeklyGoal, now_week)
	s.body.streak = _body_streak(s, now_week).current
	if steps.is_empty():
		var t: Dictionary = compute_title(s)
		s.title = t.title
		s.stage = t.stage
	# Added after the port (the parity tests drop both keys): the weekly
	# bounties, worked out from the replayed log, then the coin count.
	Bounty.settle(s, TTUtil.get_or(input, "sessions", []), input.today)
	Wallet.tally(s, input)
	return s


# ---------------------------------------------------------------------------
# Card hands (trophies "hand_*"): the sends of one boulder session read like a
# poker hand. `counts` / `flashes` map grade -> sends / flashes in the session.
# Each hand keeps its best grade across sessions, so the trophies can ask for
# "a pair of V5s" or "a straight up to V8".
# ---------------------------------------------------------------------------

static func _hand_max(h: Dictionary, key: String, v: int) -> void:
	if h.get(key) == null or v > int(h[key]):
		h[key] = v


static func _deal_hands(h: Dictionary, counts: Dictionary, flashes: Dictionary, total_sends: int) -> void:
	var grades: Array = counts.keys()
	grades.sort()
	for g in grades:
		var n: int = int(counts[g])
		if n >= 2:
			_hand_max(h, "pair", int(g))
		if n >= 3:
			_hand_max(h, "three", int(g))
		if n >= 4:
			_hand_max(h, "four", int(g))
		if int(g) == 7 and n >= 7:
			h.luckySevens = true
		for g2 in grades:
			if g2 == g:
				continue
			var n2: int = int(counts[g2])
			if n >= 2 and n2 >= 2:
				_hand_max(h, "twoPair", mini(int(g), int(g2)))
			if n >= 3 and n2 >= 2:
				_hand_max(h, "fullHouse", mini(int(g), int(g2)))
	for top in grades:
		var run_ok: bool = true
		var flash_ok: bool = true
		for k in range(5):
			if int(counts.get(int(top) - k, 0)) < 1:
				run_ok = false
			if int(flashes.get(int(top) - k, 0)) < 1:
				flash_ok = false
		if run_ok:
			_hand_max(h, "straight", int(top))
		if flash_ok:
			_hand_max(h, "straightFlush", int(top))
	var fl: int = 0
	for g in flashes:
		if int(g) >= 3:
			fl += int(flashes[g])
	if fl > 0:
		_hand_max(h, "flush", fl)
	if total_sends == 21:
		h.blackjack = true
	if grades.size() == 1 and int(grades[0]) == 1 and int(counts[grades[0]]) == 2:
		h.snakeEyes = true


# ---------------------------------------------------------------------------
# Chase feats (trophies "quirk_*"): odd shapes of a session that are fun to go
# out of your way for. Flags stay true once earned; bests keep their maximum.
# ---------------------------------------------------------------------------

static func _quirk_max(q: Dictionary, key: String, v) -> void:
	if q.get(key) == null or v > q[key]:
		q[key] = v


static func _deal_quirks(q: Dictionary, session: Dictionary, st: Dictionary, date: String, disc: String) -> void:
	# --- calendar oddities (any discipline) ----------------------------------------
	var month: String = date.substr(5, 2)
	var day: String = date.substr(8, 2)
	if Dates.weekday_index(date) == 4 and day == "13":
		q.friday13 = true
	if month == "02" and day == "29":
		q.leapDay = true
	if month == "01" and day == "01":
		q.newYear = true
	var disc_bit: int = 1 << maxi(0, TT.DISCIPLINES.find(disc))
	var day_bits: int = int(q.dateDisc.get(date, 0)) | disc_bit
	q.dateDisc[date] = day_bits
	if day_bits != disc_bit and (day_bits & (day_bits - 1)) != 0:
		q.doubleHeader = true

	if disc == "lift":
		var names: Dictionary = {}
		for ex in session.get("exercises", []):
			var ws: Array = []
			var same_reps: int = 0
			var same_w: bool = true
			var n_sets: int = 0
			for one_set in ex.sets:
				var reps: int = maxi(0, int(one_set.reps))
				var w: float = maxf(0.0, float(one_set.weightKg))
				n_sets += 1
				ws.append(w)
				if reps == 13:
					q.bakersDozen = true
				if w > 0.0:
					_quirk_max(q, "maxSetVolumeKg", reps * w)
				else:
					_quirk_max(q, "maxSetReps", reps)
				if reps == 5:
					same_reps += 1
				if absf(w - float(ws[0])) > 0.01:
					same_w = false
			if n_sets > 0:
				names[Xp.normalize_exercise(ex.name)] = true
			if n_sets == 5 and same_reps == 5 and same_w and float(ws[0]) > 0.0:
				q.fiveByFive = true
			var sevens: int = 0
			for one_set in ex.sets:
				if int(one_set.reps) == 7:
					sevens += 1
			if sevens >= 7:
				q.sevenBySeven = true
			# Ladder: longest run of strictly heavier sets. Pyramid: up 3+, then down 2+.
			var run_len: int = 1
			var best_run: int = 1 if n_sets > 0 else 0
			var up: int = 0
			var down: int = 0
			var pyramid: bool = false
			for i in range(1, ws.size()):
				if float(ws[i]) > float(ws[i - 1]) + 0.01:
					run_len += 1
					if down > 0:
						up = 0
						down = 0
					up += 1
				else:
					run_len = 1
					if float(ws[i]) < float(ws[i - 1]) - 0.01 and up >= 2:
						down += 1
						if down >= 2:
							pyramid = true
					elif float(ws[i]) < float(ws[i - 1]) - 0.01:
						up = 0
						down = 0
					else:
						up = 0
						down = 0
				best_run = maxi(best_run, run_len)
			if best_run > 0:
				_quirk_max(q, "ladderSets", best_run)
			if pyramid:
				q.pyramid = true
		var has_squat: bool = false
		var has_bench: bool = false
		var has_dead: bool = false
		for n in names:
			if str(n).contains("squat"):
				has_squat = true
			if str(n).contains("bench"):
				has_bench = true
			if str(n).contains("deadlift"):
				has_dead = true
		if has_squat and has_bench and has_dead:
			q.bigThree = true
	elif disc == "run":
		var dist: float = float(st.distanceM)
		if absf(dist - 5000.0) <= 10.0:
			q.runExact5 = true
		if dist >= 3000.0 and st.paceSecPerKm != null and absf(float(st.paceSecPerKm) - 300.0) <= 1.0:
			q.metronome = true
		if q.runLastDate == null or date != str(q.runLastDate):
			if q.runLastDate != null and Dates.days_between(str(q.runLastDate), date) == 1:
				q.runDayStreak = int(q.runDayStreak) + 1
			else:
				q.runDayStreak = 1
			q.runLastDate = date
		_quirk_max(q, "runDayStreakBest", int(q.runDayStreak))
		var mk: String = date.substr(0, 7)
		q.monthRunM[mk] = float(q.monthRunM.get(mk, 0.0)) + dist
		_quirk_max(q, "bestMonthRunM", float(q.monthRunM[mk]))
	elif disc == "ride":
		var dist: float = float(st.distanceM)
		if absf(dist - 50000.0) <= 50.0:
			q.rideExact50 = true
		var wk: String = Dates.week_key(date)
		var bits: int = int(q.weekRideDays.get(wk, 0)) | (1 << Dates.weekday_index(date))
		q.weekRideDays[wk] = bits
		var n_days: int = 0
		while bits > 0:
			n_days += bits & 1
			bits >>= 1
		_quirk_max(q, "bestRideWeekDays", n_days)
		var mk: String = date.substr(0, 7)
		q.monthRideM[mk] = float(q.monthRideM.get(mk, 0.0)) + dist
		_quirk_max(q, "bestMonthRideM", float(q.monthRideM[mk]))
