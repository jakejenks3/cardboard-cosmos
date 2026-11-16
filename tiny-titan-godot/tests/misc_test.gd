extends SceneTree
## Unit test for misc activities (game/misc.gd): the weighted vest walk, what it
## is worth, where it counts (hero XP, bosses, bounty, coins, streak) and where
## it must not (the four disciplines' XP, totals, records and quests), and how
## the phone note reads one.
##   godot --headless --path . --script res://tests/misc_test.gd
## Prints MISC: X/Y passed and exits with 1 when anything fails.

const LB = 0.45359237
const MI = 1609.344

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func near(a, b, eps: float = 0.011) -> bool:
	return a != null and absf(float(a) - float(b)) <= eps


func _at() -> int:
	_n += 1
	return 1700000000000 + _n * 3600000


func walk(date: String, km: float, minutes: float, kg: float, elev_m: float = 0.0) -> Dictionary:
	var at = _at()
	return {"id": "w%d" % _n, "discipline": "misc", "kind": "vest_walk", "date": date, "createdAt": at, "source": "manual",
		"distanceM": km * 1000.0, "elevationM": elev_m, "durationSec": int(minutes * 60.0), "loadKg": kg}


func run(date: String, km: float) -> Dictionary:
	var at = _at()
	return {"id": "r%d" % _n, "discipline": "run", "date": date, "createdAt": at, "source": "manual", "distanceM": km * 1000.0, "elevationM": 0, "durationSec": int(km * 330.0)}


func ride(date: String, km: float) -> Dictionary:
	var at = _at()
	return {"id": "c%d" % _n, "discipline": "ride", "date": date, "createdAt": at, "source": "manual", "distanceM": km * 1000.0, "elevationM": 0, "durationSec": int(km * 150.0)}


func derive(sessions: Array, today: String) -> Dictionary:
	return Derive.derive({"sessions": sessions, "claims": [], "body": [], "purchases": [], "weeklyGoal": 3, "today": today})


func opts(extra: Dictionary = {}) -> Dictionary:
	var o = {"today": "2026-11-15", "weightUnit": "kg", "distanceUnit": "km", "exercises": Summary.DEFAULT_EXERCISES}
	o.merge(extra, true)
	return o


func p(text: String, extra: Dictionary = {}) -> Dictionary:
	return QuickLog.parse(text, opts(extra))


func _init() -> void:
	var mi_lb = {"weightUnit": "lb", "distanceUnit": "mi"}

	# --- the catalog ------------------------------------------------------------------
	ok(Misc.ORDER == ["vest_walk"] and Misc.KINDS.has("vest_walk"), "one kind for now: the weighted vest walk")
	for k in Misc.ORDER:
		var m = Misc.meta(k)
		ok(Icons.has_icon(str(m.icon)) and str(m.name) != "" and str(m.short) != "", "%s has a name and an icon" % k, m)
	ok(Icons.has_icon("misc") and TT.DISCIPLINE_META.has("misc") and not TT.DISCIPLINES.has("misc"), "misc has an icon and a name, and is not one of the four disciplines")
	ok(TT.SESSION_KINDS == ["lift", "climb", "run", "ride", "misc"], "the session kinds, in order")
	ok(Misc.meta("yoga-on-a-boat").name == "Activity" and Misc.meta("yoga-on-a-boat").fields.is_empty(), "an unknown kind is a plain activity")

	# --- what the vest is worth ---------------------------------------------------------
	ok(near(Misc.load_mult("vest_walk", 0.0), 1.0) and near(Misc.load_mult("vest_walk", 10.0), 1.25) and near(Misc.load_mult("vest_walk", 20.0), 1.5), "no vest x1, 10 kg x1.25, 20 kg x1.5")
	ok(near(Misc.load_mult("vest_walk", 80.0), 2.0) and near(Misc.load_mult("vest_walk", -5.0), 1.0), "capped at x2, never below x1")
	var hour = walk("2026-11-03", 5.0, 60.0, 20.0 * LB)
	var base = Xp.base_session_xp(hour)
	ok(int(base.xp) == 488, "an hour, 5 km, 20 lb vest: 488 XP", base)
	ok(base.parts.size() == 2 and str(base.parts[0].label) == "5.0 km carrying 9.1 kg" and int(base.parts[0].xp) == 368 and int(base.parts[1].xp) == 120, "the parts: the walk with its load, and the time", base.parts)
	ok(int(Xp.base_session_xp(walk("2026-11-03", 5.0, 60.0, 0.0)).xp) == 420, "the same walk without a vest: 420 XP")
	ok(int(Xp.base_session_xp(walk("2026-11-03", 5.0, 60.0, 9.0, 100.0)).xp) == 586, "100 m of climbing counts too, heavier with the vest", Xp.base_session_xp(walk("2026-11-03", 5.0, 60.0, 9.0, 100.0)))
	var st = Xp.session_stats(hour)
	ok(near(st.distanceM, 5000.0) and near(st.paceSecPerKm, 720.0) and near(st.loadKg, 9.0718, 0.001) and int(st.sets) == 0 and int(st.sends) == 0, "its numbers: distance, pace, load", st)
	var odd = {"id": "o1", "discipline": "misc", "kind": "yoga-on-a-boat", "date": "2026-11-03", "createdAt": 5, "durationSec": 1800}
	ok(int(Xp.base_session_xp(odd).xp) == 60 and Misc.is_valid(odd) and not Misc.is_valid({"discipline": "misc", "kind": "vest_walk", "durationSec": 600}), "an unknown kind earns its time; a vest walk needs a distance")

	# --- how it reads ----------------------------------------------------------------------
	ok(Summary.summarize_session(hour, mi_lb) == "3.1 mi · 1:00:00 · 19:19 /mi · 20 lb vest", "one line in miles and pounds", Summary.summarize_session(hour, mi_lb))
	ok(Summary.summarize_session(walk("2026-11-03", 4.0, 50.0, 10.0, 80.0), {"weightUnit": "kg", "distanceUnit": "km"}) == "4 km · 50:00 · 12:30 /km · 10 kg vest · 80 m ↑", "one line in km and kg", Summary.summarize_session(walk("2026-11-03", 4.0, 50.0, 10.0, 80.0), {"weightUnit": "kg", "distanceUnit": "km"}))
	ok(Misc.title(hour) == "Weighted vest walk" and Misc.title({"discipline": "misc", "kind": "vest_walk", "title": "Dog loop"}) == "Dog loop", "its name, or its own title")

	# --- a log without misc is exactly as before ----------------------------------------------
	var r1 = run("2026-11-02", 6.0)
	var c1 = ride("2026-11-02", 30.0)
	var plain = derive([r1, c1], "2026-11-04")
	ok(not plain.has("misc") and Misc.sessions(plain) == 0 and Misc.totals(plain, "vest_walk") == null, "no misc activity: the state has no misc key")

	# --- where a vest walk counts, and where it does not -------------------------------------------
	var w1 = walk("2026-11-03", 5.0, 60.0, 9.0)
	var both = derive([r1, c1, w1], "2026-11-04")
	var xp_w = int(both.sessionXp[w1.id])
	ok(xp_w == int(Xp.base_session_xp(w1).xp) and xp_w > 0, "it has its XP", xp_w)
	ok(int(both.xp.hero) == int(plain.xp.hero) + xp_w, "the hero gets it")
	ok(both.xp.keys() == plain.xp.keys() and int(both.xp.run) == int(plain.xp.run) and int(both.xp.ride) == int(plain.xp.ride) and int(both.xp.lift) == 0, "the four disciplines' XP is untouched")
	ok(both.totals.byDiscipline == plain.totals.byDiscipline and int(both.totals.sessions) == int(plain.totals.sessions) + 1, "one more session, none of the four's counts")
	ok(near(both.totals.runDistanceM, plain.totals.runDistanceM) and near(both.totals.rideDistanceM, plain.totals.rideDistanceM), "run and ride distance untouched")
	ok(both.prs == plain.prs, "run, ride, lift and climb records untouched", both.prs)
	ok(int(both.totals.durationSec) == int(plain.totals.durationSec) + 3600 and int(both.totals.activeDays) == 2, "its time and its day count")
	ok(int(both.weekCounts["2026-11-02"]) == 3 and int(both.streak.thisWeek) == 3, "it counts for the weekly goal", both.streak)
	ok(int(both.campaign.totalDamage) == int(plain.campaign.totalDamage) + xp_w and int(both.sessionDamage[w1.id]) == xp_w, "it hits the boss for its XP")
	ok(int(both.coins.by.sessions) == int(plain.coins.by.sessions) + Wallet.xp_coins(xp_w), "it pays coins")
	ok(int(both.weekly.current.damage) > int(plain.weekly.current.damage) and both.weekly.current.weak != "misc", "it hits the weekly bounty, which is never weak to misc", both.weekly.current)
	var mt = Misc.totals(both, "vest_walk")
	ok(Misc.sessions(both) == 1 and mt != null and int(mt.sessions) == 1 and near(mt.distanceM, 5000.0) and near(mt.heaviestKg, 9.0) and near(mt.longestM, 5000.0) and int(mt.xp) == xp_w and near(mt.loadKm, 45.0), "its own totals", both.misc)
	ok(both.quirks == plain.quirks and both.weekDisc == plain.weekDisc, "it is not a discipline for double-headers or cross-training")
	var only = derive([walk("2026-11-03", 3.0, 40.0, 9.0)], "2026-11-04")
	ok(only.weekly.current.weak == null and int(only.xp.hero) > 0 and int(only.levels.hero.level) >= 1 and only.title != "", "a log of only vest walks works, and its bounty has no weakness", only.weekly.current)

	# --- records --------------------------------------------------------------------------------
	var w2 = walk("2026-11-05", 6.0, 70.0, 9.0)
	var w3 = walk("2026-11-06", 4.0, 50.0, 14.0)
	var rec = derive([w1, w2, w3], "2026-11-07")
	ok(int(rec.sessionXp[w2.id]) == int(Xp.base_session_xp(w2).xp) + 75, "a longer walk than ever pays the record bonus", rec.sessionXp)
	ok(int(rec.sessionXp[w3.id]) == int(Xp.base_session_xp(w3).xp) and int(rec.sessionXp[w1.id]) == int(Xp.base_session_xp(w1).xp), "the first walk sets the mark; a heavier vest is a record without a bonus")
	var titles = []
	for c in rec.chronicle:
		if str(c.get("kind", "")) == "pr":
			titles.append(str(c.title))
	ok(titles == ["Longest vest walk", "Heaviest vest"], "both records are in the Story", titles)
	ok(near(Misc.totals(rec, "vest_walk").longestM, 6000.0) and near(Misc.totals(rec, "vest_walk").heaviestKg, 14.0) and int(rec.bests.sessionPrs) == 1, "the marks moved")

	# --- the results reel ---------------------------------------------------------------------------
	var before = derive([r1, w1], "2026-11-07")
	var after = derive([r1, w1, w2], "2026-11-07")
	var ev = Diff.diff_states(before, after, w2)
	ok(ev.size() >= 1 and ev[0].type == "xp" and ev[0].discipline == "misc" and ev[0].disc == null and int(ev[0].amount) == int(after.sessionXp[w2.id]) and int(ev[0].prBonus) == 75, "the reel: XP for the hero, no discipline bar, the record bonus", ev[0] if not ev.is_empty() else null)
	var tracks = []
	for e in ev:
		if e.type == "levelup":
			tracks.append(e.track)
	ok(tracks.is_empty() or tracks == ["hero"], "only the hero can level up from it", tracks)
	var extra = Diff.diff_extras(before, after, "misc", mi_lb)
	var prs = extra.filter(func(e): return e.type == "pr")
	ok(prs.size() == 1 and prs[0].title == "Longest vest walk!" and prs[0].detail == "3.73 mi (was 3.11 mi)", "the record card, in the player's units", prs)
	ok(Diff.diff_extras(plain, plain).filter(func(e): return e.type == "pr").is_empty(), "no misc, no record cards")
	var bulk = Diff.diff_bulk(derive([r1], "2026-11-07"), after, [w1, w2])
	ok(bulk[0].type == "import" and int(bulk[0].byDiscipline.get("misc", 0)) == int(after.sessionXp[w1.id]) + int(after.sessionXp[w2.id]) and int(bulk[0].byDiscipline.run) == 0, "an import of vest walks adds them up under misc", bulk[0])

	# --- quests, recap -------------------------------------------------------------------------------------
	var settings = {"weeklyGoal": 3, "weightUnit": "lb", "distanceUnit": "mi"}
	var wq = Quests.weekly_quests("2026-11-02", after, [r1, w1, w2], [], settings)
	var dq = Quests.daily_quests("2026-11-05", after, [r1, w1, w2], [])
	ok(wq.size() >= 3 and dq.size() >= 1, "quests still build with vest walks in the log", [wq.size(), dq.size()])
	for q in wq:
		if str(q.title) == "Consistency":
			ok(int(q.progress) == 3, "a vest walk day is a training day for the weekly quest", q)
		if str(q.title) == "Cross-training":
			ok(int(q.progress) == 1, "but not a second discipline", q)
	var rc = Recap.build("week", "2026-11-02", after, [r1, w1, w2], [], "2026-11-07")
	ok(int(rc.sessions) == 3 and int(rc.by.get("misc", 0)) == 2 and near(rc.miscM, 11000.0) and near(rc.runM, 6000.0), "the recap counts them on their own", rc.by)

	# --- the phone note ---------------------------------------------------------------------------------------
	var a = p("nov 14\nvest walk 3km 40:00 10kg")
	var ae = a.entries[0] if a.entries.size() == 1 else {"data": {}}
	ok(a.entries.size() == 1 and a.problems.is_empty() and ae.kind == "session" and ae.data.get("discipline") == "misc" and ae.data.get("kind") == "vest_walk", "'vest walk 3km 40:00 10kg' is a vest walk", a)
	ok(near(ae.data.get("distanceM"), 3000.0) and ae.data.get("durationSec") == 2400 and near(ae.data.get("loadKg"), 10.0) and ae.get("date") == "2026-11-14", "with its distance, time and vest", ae.get("data"))
	ok(ae.get("summary") == "Vest walk 3 km · 40:00 · 10 kg vest", "and its summary", ae.get("summary"))
	var b = p("vest walk 2 mi 38:30 20 lb +120ft", mi_lb).entries
	ok(b.size() == 1 and near(b[0].data.distanceM, 2.0 * MI, 0.6) and b[0].data.durationSec == 2310 and near(b[0].data.loadKg, 20.0 * LB) and near(b[0].data.elevationM, 36.6, 0.6), "miles, pounds and feet", b)
	ok(b.size() == 1 and b[0].summary == "Vest walk 2 mi · 38:30 · 20 lb vest · 120 ft up", "summary in miles and pounds", b[0].summary if b.size() == 1 else "")
	for line in ["weighted vest walk 3km 40min 10kg", "weighted walk 3km 40min 10kg", "vestwalk 3km 40min 10kg", "Vest Walk: 3 km in 40 min with 10 kg", "vest walk 3km 40min @10kg"]:
		var x = p(line).entries
		ok(x.size() == 1 and x[0].data.get("kind") == "vest_walk" and near(x[0].data.distanceM, 3000.0) and x[0].data.durationSec == 2400 and near(x[0].data.loadKg, 10.0), "also: " + line, p(line))
	var bare = p("vest walk 2 40:00 20", mi_lb).entries
	ok(bare.size() == 1 and near(bare[0].data.distanceM, 2.0 * MI, 0.6) and near(bare[0].data.loadKg, 20.0 * LB), "bare numbers: distance in the player's unit, then the vest", bare)
	var usual = p("vest walk 3km 40:00", {"lastLoadKg": {"vest_walk": 12.0}}).entries
	ok(usual.size() == 1 and near(usual[0].data.loadKg, 12.0) and usual[0].warnings.size() == 1 and str(usual[0].warnings[0]).contains("12 kg"), "no vest written: the last one used, and it says so", usual)
	var none = p("vest walk 3km 40:00").entries
	ok(none.size() == 1 and near(none[0].data.get("loadKg", 0.0), 0.0) and none[0].warnings.size() == 1, "no vest written and none known: no load, with a warning", none)
	var after_line = p("vest walk 3km 40:00\nvest 15kg").entries
	ok(after_line.size() == 1 and near(after_line[0].data.loadKg, 15.0) and after_line[0].warnings.is_empty(), "a 'vest 15kg' line under it sets the vest", after_line)
	ok(p("vest walk 40:00").entries.is_empty() and p("vest walk 40:00").problems.size() == 1, "no distance is a problem, not an entry", p("vest walk 40:00"))
	ok(p("vest 15kg").entries.is_empty() and p("vest 15kg").problems.size() == 1, "a vest line with no walk above it is a problem", p("vest 15kg"))
	# Said as a sentence, the way it gets typed on a phone: the words anywhere in a line that has a distance.
	var said = p("11/16: 2.5 mile walk with 30 lb vest", mi_lb.merged({"today": "2026-11-16"}))
	var said_e = said.entries[0] if said.entries.size() == 1 else {"data": {}}
	ok(said.problems.is_empty() and said.entries.size() == 1 and said_e.data.get("kind") == "vest_walk" and said_e.get("date") == "2026-11-16", "'2.5 mile walk with 30 lb vest' is a vest walk on its date", said)
	ok(near(said_e.data.get("distanceM", 0.0), 2.5 * MI, 0.6) and near(said_e.data.get("loadKg", 0.0), 30.0 * LB) and not said_e.data.has("durationSec") and said_e.get("warnings", [""]).is_empty(), "2.5 miles, a 30 lb vest, no time and no warning", said_e.get("data"))
	ok(said_e.get("summary") == "Vest walk 2.5 mi · 30 lb vest", "its line in the review", said_e.get("summary"))
	var said2 = p("walked 2 miles in 38:30 with the vest", mi_lb.merged({"lastLoadKg": {"vest_walk": 20.0 * LB}})).entries
	ok(said2.size() == 1 and said2[0].data.get("kind") == "vest_walk" and near(said2[0].data.distanceM, 2.0 * MI, 0.6) and said2[0].data.get("durationSec") == 2310 and near(said2[0].data.loadKg, 20.0 * LB), "'walked 2 miles in 38:30 with the vest': the last vest weight is used", said2)
	for lift_line in ["weighted vest walking lunges 3x10 @ 20", "walking lunge 3x10"]:
		var ll = p(lift_line, mi_lb)
		ok(ll.entries.size() == 1 and ll.entries[0].data.get("discipline") == "lift", "a lift with those words stays a lift: " + lift_line, ll)
	ok(p("2.5 mile walk", mi_lb).entries.all(func(e): return e.data.get("discipline") != "misc"), "a walk with no vest word is not taken as a vest walk")
	var mixed = p("nov 14\nbench 3x5 @ 80\nvest walk 3km 40:00 10kg\nsquat 3x5 @ 100\nrun 5km 25:00")
	ok(mixed.entries.size() == 3 and mixed.problems.is_empty() and mixed.entries[0].data.discipline == "lift" and mixed.entries[0].data.exercises.size() == 2, "between lifts it is its own session and does not split the lifting", mixed)
	ok(p("vest walk 3km 40:00 10kg").entries[0].key == QuickLog.parse("vest walk 3km 40:00 10kg", opts({"today": "2026-11-20"})).entries[0].key, "the key is the same on any day")
	var cheat = QuickLog.parse(QuickLog.CHEAT_SHEET, opts())
	var has_walk = false
	for e in cheat.entries:
		if e.kind == "session" and e.data.get("discipline") == "misc":
			has_walk = true
	ok(cheat.problems.is_empty() and has_walk, "the cheat sheet shows a vest walk, and every line of it parses", cheat.problems)

	# --- a walk screenshot ------------------------------------------------------------------------------------
	var shot = {"kind": "walk", "dist": 1.2, "distUnit": "mi", "sec": 1450, "elev": 12.0, "elevUnit": "ft", "title": "Lunch Walk", "rel": "today", "month": 0, "day": 0, "year": 0, "extras": ["Steps 2,950"], "seen": "2026-11-15", "id": "abc"}
	var s1 = p("photo images/walk.png", {"shots": {"images/walk.png": shot}, "lastLoadKg": {"vest_walk": 9.0}})
	var se = s1.entries[0] if s1.entries.size() == 1 else {"data": {}}
	ok(s1.entries.size() == 1 and s1.problems.is_empty() and se.data.get("discipline") == "misc" and se.data.get("kind") == "vest_walk", "a walk screenshot comes in as a vest walk", s1)
	ok(near(se.data.get("distanceM"), 1.2 * MI, 0.6) and se.data.get("durationSec") == 1450 and near(se.data.get("loadKg"), 9.0) and se.data.get("title") == "Lunch Walk" and se.data.get("notes") == "Steps 2,950", "with what the picture says and the usual vest", se.get("data"))
	ok(se.get("shots") == ["images/walk.png"] and se.get("warnings", []).size() == 1 and str(se.warnings[0]).contains("vest"), "it remembers its picture and says where the vest came from", se)
	var s2 = p("photo images/walk.png\nvest 20 lb", {"shots": {"images/walk.png": shot}, "lastLoadKg": {"vest_walk": 9.0}}).entries
	ok(s2.size() == 1 and near(s2[0].data.loadKg, 20.0 * LB) and s2[0].warnings.is_empty(), "'vest 20 lb' under the picture sets the vest", s2)
	var s3 = p("photo images/walk.png", {"shots": {"images/walk.png": shot}}).entries
	ok(s3.size() == 1 and near(s3[0].data.get("loadKg", 0.0), 0.0) and s3[0].warnings.size() == 1, "no vest known: imported without one, and it says how to add it", s3)

	print("MISC: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
