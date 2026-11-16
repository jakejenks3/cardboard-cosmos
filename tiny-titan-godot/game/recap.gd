class_name Recap
extends RefCounted
## A week or a month in review (added after the port): pure numbers for the
## recap poster, read from the derived state and the log. Nothing is stored.
##
##   Recap.build("week", "2026-11-09", state, sessions, body, today)
##   Recap.build("month", "2026-10", state, sessions, body, today)
##
## Recap: {
##   kind: "week" | "month", key, from, to (date keys), title, range (text),
##   running: bool (the period is not over yet), empty: bool (nothing logged),
##   sessions, activeDays, durationSec, by: {discipline: sessions},
##   xp (session XP), heroXp (all hero XP earned in the period),
##   levelFrom, levelTo (hero level before and after),
##   liftKg, liftSets, sends, topGrade (null or V index), routes, runM, rideM, elevM,
##   prs: [chronicle entries], trophies: [ids], items: [ids], pets: [ids],
##   bosses: [boss ids], bounties: {won, crushed, weeks: [records]},
##   coins (earned in the period), best: {id, discipline, xp, date} or null,
##   prev: {key, xp, sessions} (the period before), headline: String,
##   weight: {from, to} or null (first and last weigh-in of the period),
##   photos: {then: {id, date}, now: {id, date}} or null (a before / after pair) }

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]


static func _in(date, from: String, to: String) -> bool:
	if date == null:
		return false
	var d: String = str(date)
	return d >= from and d <= to


## [from, to] date keys of a period.
static func bounds(kind: String, key: String) -> Array:
	if kind == "week":
		return [key, Dates.add_days(key, 6)]
	var first: String = key + "-01"
	# The day before the first of the next month.
	var next_first: String = Dates.add_days(first, 32).substr(0, 7) + "-01"
	return [first, Dates.add_days(next_first, -1)]


## The key of the period that contains `date`.
static func key_of(kind: String, date: String) -> String:
	return Dates.week_key(date) if kind == "week" else date.substr(0, 7)


## The key of the period `n` steps away (negative = earlier).
static func shift(kind: String, key: String, n: int) -> String:
	if kind == "week":
		return Dates.add_weeks(key, n)
	var y: int = int(key.substr(0, 4))
	var m: int = int(key.substr(5, 2)) - 1 + n
	y += int(floor(m / 12.0))
	m = ((m % 12) + 12) % 12
	return "%04d-%02d" % [y, m + 1]


static func title_of(kind: String, key: String) -> String:
	if kind == "week":
		return "Week of " + Dates.format_date(key, {"month": "long", "day": "numeric"})
	return "%s %s" % [MONTHS[int(key.substr(5, 2)) - 1], key.substr(0, 4)]


static func range_text(from: String, to: String) -> String:
	if from.substr(0, 7) == to.substr(0, 7):
		return "%s to %d" % [Dates.format_date(from), int(to.substr(8, 2))]
	return "%s to %s" % [Dates.format_date(from), Dates.format_date(to)]


## The first period with anything in it (a session or a check-in), or the
## current one when the log is empty.
static func first_key(kind: String, sessions: Array, body: Array, today: String) -> String:
	var first: String = today
	for x in sessions:
		if str(x.date) < first:
			first = str(x.date)
	for e in body:
		if str(e.date) < first:
			first = str(e.date)
	return key_of(kind, first)


static func _numbers(from: String, to: String, state: Dictionary, sessions: Array) -> Dictionary:
	var out = {
		"sessions": 0, "activeDays": 0, "durationSec": 0, "by": {}, "xp": 0,
		"liftKg": 0.0, "liftSets": 0, "sends": 0, "topGrade": null, "routes": 0,
		"runM": 0.0, "rideM": 0.0, "elevM": 0.0, "best": null,
	}
	var days: Dictionary = {}
	for x in sessions:
		if not _in(x.date, from, to):
			continue
		var st: Dictionary = Xp.session_stats(x)
		var xp: int = int(state.sessionXp.get(x.id, 0))
		out.sessions += 1
		days[x.date] = true
		out.durationSec += int(st.durationSec)
		out.by[x.discipline] = int(out.by.get(x.discipline, 0)) + 1
		out.xp += xp
		if out.best == null or xp > int(out.best.xp):
			out.best = {"id": x.id, "discipline": x.discipline, "xp": xp, "date": str(x.date)}
		match x.discipline:
			"lift":
				out.liftKg += float(st.volumeKg)
				out.liftSets += int(st.sets)
			"climb":
				out.sends += int(st.sends)
				out.routes += int(TTUtil.get_or(st, "routes", 0))
				if st.maxGradeSent != null and (out.topGrade == null or int(st.maxGradeSent) > int(out.topGrade)):
					out.topGrade = int(st.maxGradeSent)
			"run":
				out.runM += float(st.distanceM)
				out.elevM += float(st.elevationM)
			"ride":
				out.rideM += float(st.distanceM)
				out.elevM += float(st.elevationM)
	out.activeDays = days.size()
	return out


static func _hero_xp_before(state: Dictionary, date: String) -> int:
	var n: int = 0
	for d in state.xpByDate:
		if str(d) < date:
			n += int(state.xpByDate[d])
	return n


static func _photo_of(e: Dictionary):
	var ph = e.get("photos")
	if not (ph is Dictionary):
		return null
	for angle in TT.PHOTO_ANGLES:
		if TTUtil.truthy(ph.get(angle)):
			return {"id": str(ph[angle]), "date": str(e.date), "angle": angle}
	return null


static func _headline(r: Dictionary) -> String:
	var week: bool = r.kind == "week"
	if r.sessions == 0:
		return "A rest week" if week else "A quiet month"
	if not r.bosses.is_empty():
		return "Boss slayer"
	if r.prs.size() >= 3:
		return "Record breaker"
	if int(r.levelTo) > int(r.levelFrom):
		return "Levelled up"
	if int(r.prev.xp) > 0 and float(r.xp) >= float(r.prev.xp) * 1.25:
		return "A big step up"
	if int(r.bounties.won) > 0 and week:
		return "Bounty claimed"
	if r.by.size() >= 3:
		return "All-rounder"
	if int(r.prev.xp) > 0 and float(r.xp) < float(r.prev.xp) * 0.6 and not r.running:
		return "A lighter one" if week else "A lighter month"
	return "Solid work"


static func build(kind: String, key: String, state: Dictionary, sessions: Array, body: Array, today: String) -> Dictionary:
	var b: Array = bounds(kind, key)
	var from: String = b[0]
	var to: String = b[1]
	var r: Dictionary = _numbers(from, to, state, sessions)
	r["kind"] = kind
	r["key"] = key
	r["from"] = from
	r["to"] = to
	r["title"] = title_of(kind, key)
	r["range"] = range_text(from, to)
	r["running"] = today >= from and today <= to

	var hero_xp: int = 0
	for d in state.xpByDate:
		if _in(d, from, to):
			hero_xp += int(state.xpByDate[d])
	r["heroXp"] = hero_xp
	var before_xp: int = _hero_xp_before(state, from)
	r["levelFrom"] = int(Xp.hero_level(before_xp).level)
	r["levelTo"] = int(Xp.hero_level(before_xp + hero_xp).level)

	var prs: Array = []
	for c in state.chronicle:
		if c.kind == "pr" and _in(c.date, from, to):
			prs.append(c)
	r["prs"] = prs
	var trophies: Array = []
	for id in state.achievements:
		if _in(state.achievements[id].get("at"), from, to):
			trophies.append(id)
	r["trophies"] = trophies
	var items: Array = []
	for id in state.items:
		var o = state.items[id]
		if o.get("how") != "start" and _in(o.get("at"), from, to):
			items.append(id)
	r["items"] = items
	var pets: Array = []
	for id in state.pets:
		if _in(state.pets[id].get("at"), from, to):
			pets.append(id)
	r["pets"] = pets
	var bosses: Array = []
	for id in state.campaign.defeated:
		if _in(state.campaign.defeated[id].get("at"), from, to):
			bosses.append(id)
	r["bosses"] = bosses

	var bounties = {"won": 0, "crushed": 0, "weeks": []}
	var coins: int = 0
	var w = state.get("weekly")
	if w is Dictionary:
		for rec in w.history:
			# A week belongs to the period its Monday falls in.
			if not _in(rec.week, from, to):
				continue
			bounties.weeks.append(rec)
			if rec.defeated:
				bounties.won += 1
				coins += int(rec.coins)
			if rec.crushed:
				bounties.crushed += 1
	r["bounties"] = bounties
	for x in sessions:
		if _in(x.date, from, to):
			coins += Wallet.xp_coins(state.sessionXp.get(x.id, 0))
	for id in trophies:
		var a = Achievements.by_id(id)
		if a != null:
			coins += Wallet.trophy_coins(a)
	for id in bosses:
		coins += Wallet.boss_coins(str(id))
	r["coins"] = coins

	var prev_key: String = shift(kind, key, -1)
	var pb: Array = bounds(kind, prev_key)
	var pn: Dictionary = _numbers(pb[0], pb[1], state, sessions)
	r["prev"] = {"key": prev_key, "xp": pn.xp, "sessions": pn.sessions}

	# Body: the first and last weigh-in, and a before / after photo pair.
	var entries: Array = body.duplicate()
	TTUtil.stable_sort(entries, func(a, c): return str(a.date) < str(c.date))
	var w_from = null
	var w_to = null
	var now_photo = null
	var first_photo_in = null
	var before_photo = null
	for e in entries:
		var d: String = str(e.date)
		var ph = _photo_of(e)
		if d < from:
			if ph != null:
				before_photo = ph
			continue
		if d > to:
			break
		var kg = e.get("weightKg")
		if (kg is int or kg is float) and kg > 0:
			if w_from == null:
				w_from = float(kg)
			w_to = float(kg)
		if ph != null:
			if first_photo_in == null:
				first_photo_in = ph
			now_photo = ph
	r["weight"] = null if w_from == null else {"from": w_from, "to": w_to}
	var then_photo = before_photo if before_photo != null else first_photo_in
	if now_photo != null and then_photo != null and then_photo.id != now_photo.id:
		r["photos"] = {"then": then_photo, "now": now_photo}
	elif now_photo != null:
		r["photos"] = {"then": null, "now": now_photo}
	else:
		r["photos"] = null

	r["empty"] = r.sessions == 0 and trophies.is_empty() and r.photos == null and r.weight == null
	r["headline"] = _headline(r)
	return r
