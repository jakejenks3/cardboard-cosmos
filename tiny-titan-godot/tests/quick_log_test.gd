extends SceneTree
## Unit tests for game/quick_log.gd (the phone-inbox parser) and the share-link rewriting.
##   godot --headless --path . --script res://tests/quick_log_test.gd
## Prints QUICKLOG: X/Y passed and exits with 1 when anything fails.

const TODAY = "2026-11-15"  # a Sunday

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func opts(extra: Dictionary = {}) -> Dictionary:
	var o = {"today": TODAY, "weightUnit": "kg", "distanceUnit": "km", "exercises": Summary.DEFAULT_EXERCISES}
	o.merge(extra, true)
	return o


func p(text: String, extra: Dictionary = {}) -> Dictionary:
	return QuickLog.parse(text, opts(extra))


## The single entry of `text` (or {} when there is not exactly one).
func one(text: String, extra: Dictionary = {}) -> Dictionary:
	var r = p(text, extra)
	if r.entries.size() != 1:
		print("  (%d entries, problems %s for %s)" % [r.entries.size(), str(r.problems), text])
		return {}
	return r.entries[0]


## [[reps, kg], ...] of the first exercise of a lift entry.
func sets_of(e: Dictionary, idx: int = 0) -> Array:
	if e.is_empty() or e.data.get("exercises") == null or e.data.exercises.size() <= idx:
		return []
	var out = []
	for s in e.data.exercises[idx].sets:
		out.append([int(s.reps), snappedf(float(s.weightKg), 0.01)])
	return out


func ex_name(text: String) -> String:
	var e = one(text)
	return "" if e.is_empty() else str(e.data.exercises[0].name)


func date_of(text: String) -> String:
	var r = p(text + "\nbench 3x5 @ 80")
	return "" if r.entries.is_empty() else str(r.entries[0].date)


## The climbs of a one-entry text as "V3s1 V3a3" (grade, first letter of the
## result, how many); "" when the text is not exactly one entry.
func tally(text: String) -> String:
	var e = one(text)
	if e.is_empty():
		return ""
	var out = []
	for c in e.data.get("climbs", []):
		out.append("%s%s%d" % [Xp.climb_label(c), str(c.result).substr(0, 1), int(c.count)])
	return " ".join(PackedStringArray(out))


func _init() -> void:
	# --- normalising -------------------------------------------------------------
	ok(sets_of(one("﻿Bench 3×5 @ 80\r\n")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "BOM, CRLF, times sign", sets_of(one("﻿Bench 3×5 @ 80\r\n")))
	ok(sets_of(one("BENCH 3X5 @ 80")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "upper case, X, nbsp")
	ok(sets_of(one("bench 3*5 @ 80")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "* as x")
	ok(sets_of(one("- bench 3x5 @ 80")).size() == 3, "list bullet")
	ok(p("# warmup\n// comment\n\n").entries.is_empty() and p("# warmup\n// c").problems.is_empty(), "comments are ignored")

	# --- lifting -------------------------------------------------------------------
	ok(sets_of(one("squat 5,5,4 @ 100")) == [[5, 100.0], [5, 100.0], [4, 100.0]], "reps list @ weight")
	ok(sets_of(one("ohp 5 @ 50, 5 @ 52.5, 3 @ 55")) == [[5, 50.0], [5, 52.5], [3, 55.0]], "per-set weights", sets_of(one("ohp 5 @ 50, 5 @ 52.5, 3 @ 55")))
	ok(sets_of(one("dl 1x3 @ 140kg")) == [[3, 140.0]], "dl 1x3 @ 140kg")
	ok(sets_of(one("pull-up 3x8")) == [[8, 0.0], [8, 0.0], [8, 0.0]], "bodyweight AxB")
	ok(sets_of(one("pull-up 8,8,6")) == [[8, 0.0], [8, 0.0], [6, 0.0]], "bodyweight list")
	ok(sets_of(one("dip 3x8 @ +10")) == [[8, 10.0], [8, 10.0], [8, 10.0]], "added weight +10")
	ok(sets_of(one("squat 80kg x 5")) == [[5, 80.0]], "weight first x reps")
	ok(sets_of(one("squat 80kg x5 x3")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "weight first x reps x sets")
	var rf = sets_of(one("backsquat x5 135", {"weightUnit": "lb"}))
	ok(rf.size() == 1 and rf[0][0] == 5 and absf(rf[0][1] - 61.23) < 0.01, "reps-first per-set line: x5 135", rf)
	ok(ex_name("backsquat x5 135") == "Squat", "backsquat alias on a reps-first line")
	ok(sets_of(one("heel raise x10 135
backsquat x5 195
heel raise x10 195")) == [[10, 135.0], [10, 195.0]], "same exercise on two lines merges its sets", sets_of(one("heel raise x10 135
heel raise x10 195")))
	ok(sets_of(one("bench x5 x5 x4 80")) == [[5, 80.0], [5, 80.0], [4, 80.0]], "x5 x5 x4 then the weight")
	ok(sets_of(one("pull-up x8")) == [[8, 0.0]], "x8 alone is one bodyweight set", sets_of(one("pull-up x8")))
	ok(not p("bench x5 135 7").problems.is_empty(), "x5 135 7 is a problem, not a guess")
	ok(sets_of(one("bench 3x5 @ 82,5")) == [[5, 82.5], [5, 82.5], [5, 82.5]], "decimal comma after @")
	ok(sets_of(one("bench 3x5 at 80")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "'at' instead of @")
	ok(sets_of(one("bench 3 x 5 @ 80 kg")).size() == 3, "spaces around x and unit")
	ok(sets_of(one("squat 3x5 100kg")) == [[5, 100.0], [5, 100.0], [5, 100.0]], "unit on a trailing weight")
	ok(sets_of(one("bench 3x5 @ 80", {"weightUnit": "lb"})) == [[5, 36.29], [5, 36.29], [5, 36.29]], "player unit lb")
	ok(sets_of(one("bench 3x5 @ 80kg", {"weightUnit": "lb"}))[0] == [5, 80.0], "explicit kg for lb player")
	ok(sets_of(one("bench 3x5 @ 185lbs"))[0] == [5, 83.91], "explicit lbs for kg player", sets_of(one("bench 3x5 @ 185lbs")))
	var heur = one("squat 5x80")
	ok(sets_of(heur) == [[5, 80.0]] and str(heur.warnings).contains("read as 5 reps at 80"), "bare AxB, B > 30 on a loaded lift", heur)
	var bw = one("squat 3x5")
	ok(sets_of(bw) == [[5, 0.0], [5, 0.0], [5, 0.0]] and str(bw.warnings).contains("no weight given"), "bare AxB, small B on a loaded lift")
	ok(one("pull-up 3x50").warnings.is_empty(), "bare AxB on a bodyweight exercise: no warning")
	ok(str(one("hammer curl 3x10", {"loaded": []}).warnings).contains("no weight given"), "built-in loaded word (curl)")
	ok(str(one("ring row 3x10").warnings).contains("no weight given") and str(one("muscle up 3x5", {"loaded": ["muscle up"]}).warnings).contains("no weight given"), "history makes an exercise loaded")
	var two = one("bench 3x5 @ 80\nsquat 5,5,4 @ 100\npull-up 3x8")
	ok(two.get("data", {}).get("exercises", []).size() == 3, "all lifting lines of a day = one session")
	ok(p("bench 3x5 @ 80\n---\nsquat 3x5 @ 100").entries.size() == 2 and p("bench 3x5 @ 80\nlift\nsquat 3x5 @ 100").entries.size() == 2, "--- or 'lift' starts a second session")
	ok(sets_of(one("bench 3x5 @ 80\nbench 1x3 @ 85")).size() == 4, "same exercise twice merges sets")
	ok(p("bench 3x5 @").problems.size() == 1 and p("bench @ 80").problems.size() == 1, "broken lifting lines are problems")

	# --- exercise names -------------------------------------------------------------
	ok(ex_name("bench 3x5 @ 80") == "Bench Press", "alias bench")
	ok(ex_name("ohp 3x5 @ 40") == "Overhead Press", "alias ohp")
	ok(ex_name("deads 1x5 @ 140") == "Deadlift" and ex_name("dl 1x5 @ 140") == "Deadlift", "alias dl / deads")
	ok(ex_name("squats 3x5 @ 100") == "Squat", "plural squats")
	ok(ex_name("pull ups 3x8") == "Pull-up" and ex_name("pullups 3x8") == "Pull-up", "pull ups / pullups")
	ok(ex_name("chins 3x8") == "Chin-up" and ex_name("rows 3x8 @ 60") == "Barbell Row" and ex_name("rdl 3x8 @ 80") == "Romanian Deadlift", "chins, rows, rdl")
	ok(ex_name("dips 3x8") == "Dip" and ex_name("pushups 3x20") == "Push-up" and ex_name("curls 3x10 @ 30") == "Bicep Curl", "dips, pushups, curls")
	ok(ex_name("Romanian deadlift 3x8 @ 80") == "Romanian Deadlift", "exact match, any case")
	ok(ex_name("incline 3x8 @ 60") == "Incline Bench Press", "unique prefix")
	ok(ex_name("zercher squat 3x5 @ 60") == "Zercher Squat", "new exercise in Title Case")
	ok(ex_name("bench: 3x5 @ 80") == "Bench Press", "colon after the name")
	ok(ex_name("my move 3x5 @ 60") == "My Move" and QuickLog.parse("my move 3x5 @ 60", {"today": TODAY, "exercises": ["My Move"]}).entries[0].data.exercises[0].name == "My Move", "custom known exercise")
	# A number that belongs to the name: taken when the name is cut off by a dash
	# or a colon, is a shape names have ("4 way", "1 arm"), or is one already logged.
	ok(ex_name("neck 4 way - 3x20@10") == "Neck 4 Way" and sets_of(one("neck 4 way - 3x20@10")) == [[20, 10.0], [20, 10.0], [20, 10.0]], "a number inside the name, a dash before the sets", one("neck 4 way - 3x20@10"))
	ok(ex_name("Neck 4 way 3x20 @ 10") == "Neck 4 Way" and ex_name("hip 3-way 2x15") == "Hip 3-way", "'4 way' / '3-way' with no dash", [ex_name("Neck 4 way 3x20 @ 10"), ex_name("hip 3-way 2x15")])
	ok(ex_name("1 arm rope climb 3x2") == "1 Arm Rope Climb" and ex_name("45 degree back extension 3x12") == "45 Degree Back Extension", "a name that starts with a number", [ex_name("1 arm rope climb 3x2"), ex_name("45 degree back extension 3x12")])
	ok(ex_name("1 arm row 3x10 @ 40") == "Dumbbell Row", "and '1 arm row' is the library's one arm row", ex_name("1 arm row 3x10 @ 40"))
	ok(ex_name("face pull - cable, 1UE 3x15 @ 30") == "Face Pull Cable, 1UE" and ex_name("ghd back raise - 2x12") == "GHD Back Raise" and ex_name("db shrug 3x10 @ 60") == "Dumbbell Shrug", "a short form in a name ('1UE') is part of it, and short forms keep their capitals", [ex_name("face pull - cable, 1UE 3x15 @ 30"), ex_name("ghd back raise - 2x12"), ex_name("db shrug 3x10 @ 60")])
	ok(ex_name("21s - 3x21 @ 20") == "21s" and ex_name("90/90 hip switch: 3x10") == "90/90 Hip Switch" and ex_name("4 way hip - 2x15") == "4 Way Hip", "after a dash or a colon any name goes")
	var nn_big5 = QuickLog.parse("big 5 complex 3x5 @ 40", {"today": TODAY, "exercises": ["Big 5 Complex"]})
	ok(nn_big5.problems.is_empty() and nn_big5.entries.size() == 1 and nn_big5.entries[0].data.exercises[0].name == "Big 5 Complex" and p("big 5 complex 3x5 @ 40").entries.is_empty(), "an exercise already logged keeps its number; an unknown one like it is not guessed", nn_big5)
	var nn_day3 = one("11/14\nneck 4 way - 3x20@10\nbench 3x5 @ 80")
	ok(not nn_day3.is_empty() and nn_day3.data.exercises.size() == 2 and nn_day3.data.exercises[0].name == "Neck 4 Way" and nn_day3.data.exercises[1].name == "Bench Press", "it joins the day's lift like any other line", nn_day3)
	for nn_line in ["bench 3 sets of 5 at 80", "bench 3 sets of 5 - 5 @ 80", "deadlift 1 rep max 180", "squat 100 for 5", "bench 5 heavy 3x5 @ 80", "bench 80 - 3x5", "row 1 arm 40 3x10", "3 sets bench 5 @ 80", "curl 3 x 10 each arm 25"]:
		var nn_al = p(nn_line)
		ok(nn_al.entries.is_empty() and nn_al.problems.size() == 1, "an amount is never taken for a name: " + nn_line, nn_al)
	ok(str(p("bench 3 sets of 5 at 80").problems[0].why).contains("3 sets of 5"), "and the problem still quotes the line from its first number", p("bench 3 sets of 5 at 80").problems)
	# Which lift a typed name is (game/lift_match.gd): exact, the same words, or new.
	var lm = {"own": ["seated row - cable, 1UE", "Chest Fly Cable"], "exercises": ["seated row - cable, 1UE", "Chest Fly Cable"] + Summary.DEFAULT_EXERCISES}
	var lm_same = one("seated row single arm, home pulley 3x10 @ 40", lm)
	ok(not lm_same.is_empty() and lm_same.data.exercises[0].name == "seated row - cable, 1UE" and lm_same.get("names", []).size() == 1 and lm_same.names[0].kind == "match" and lm_same.names[0].typed == "seated row single arm, home pulley", "the same words in other words: taken as the player's lift, and the review is told", lm_same)
	ok(not one("seated row - cable, 1ue 3x10 @ 40", lm).has("names") and not one("bench 3x5 @ 80", lm).has("names") and not one("cable crossover 3x12 @ 20").has("names"), "their own lift, a short name and a library lift are exact: nothing to ask")
	ok(ex_name("cable crossover 3x12 @ 20") == "Cable Fly" and ex_name("db bench 3x8 @ 30") == "Dumbbell Bench Press", "another name of a library lift gets the library's name", [ex_name("cable crossover 3x12 @ 20"), ex_name("db bench 3x8 @ 30")])
	var lm_lib = one("cable fly 3x12 @ 20", lm)
	ok(not lm_lib.is_empty() and lm_lib.data.exercises[0].name == "Chest Fly Cable" and lm_lib.names[0].kind == "match", "a library lift they log under other words joins their own", lm_lib)
	var lm_new = one("neck 4 way - 3x20@10", lm)
	ok(not lm_new.is_empty() and lm_new.data.exercises[0].name == "Neck 4 Way" and lm_new.names[0].kind == "new" and lm_new.names[0].closest == "", "nothing like it: a new lift, said so", lm_new)
	var lm_near = one("incline dumbbell hammer curl 3x10 @ 20", lm)
	ok(not lm_near.is_empty() and lm_near.data.exercises[0].name == "Incline Dumbbell Hammer Curl" and lm_near.names[0].kind == "new" and lm_near.names[0].closest == "Incline Dumbbell Curl", "one word more: a new lift, with the closest one to ask about", lm_near)
	var lm_start = one("romanian 3x8 @ 60", lm)
	ok(not lm_start.is_empty() and lm_start.data.exercises[0].name == "Romanian Deadlift" and lm_start.get("names", [{}])[0].get("kind") == "match", "the start of exactly one lift is taken, and asked about", lm_start)
	var lm_vague = one("pause row 3x8 @ 60", lm)
	ok(not lm_vague.is_empty() and lm_vague.data.exercises[0].name == "Pause Row" and lm_vague.names[0].kind == "new" and lm_vague.names[0].closest == "", "several lifts equally near: none is called the closest", lm_vague)
	var lm_key = LiftMatch.key("seated row single arm, home pulley")
	var lm_no = one("seated row single arm, home pulley 3x10 @ 40", lm.merged({"names": {lm_key: ""}}))
	ok(not lm_no.is_empty() and lm_no.data.exercises[0].name == "Seated Row Single Arm, Home Pulley" and lm_no.names[0].kind == "exact" and lm_no.names[0].get("decided") == true, "decided 'no': it stays a lift of its own", lm_no)
	var lm_lib_no = one("cable fly 3x12 @ 20", lm.merged({"names": {LiftMatch.key("cable fly"): ""}}))
	ok(not lm_lib_no.is_empty() and lm_lib_no.data.exercises[0].name == "Cable Fly" and QuickLog.plain_name("db bench") == "Dumbbell Bench Press" and QuickLog.plain_name("neck 4 way") == "Neck 4 Way", "'no' to their own lift for a library lift: the library's lift, apart from theirs", lm_lib_no)
	var lm_other = one("seated row single arm, home pulley 3x10 @ 40", lm.merged({"names": {lm_key: "Seated Cable Row"}}))
	ok(not lm_other.is_empty() and lm_other.data.exercises[0].name == "Seated Cable Row" and lm_other.key == lm_same.key and lm_no.key == lm_same.key, "decided 'another one': that lift, and the entry keeps its key whatever is decided", lm_other)
	var lm_two = one("seated row single arm, home pulley 3x10 @ 40\nseated row - cable, 1ue 2x8 @ 45", lm)
	ok(not lm_two.is_empty() and lm_two.data.exercises.size() == 1 and lm_two.data.exercises[0].sets.size() == 5 and lm_two.names.size() == 1, "two spellings of one lift on a day are one exercise", lm_two)
	ok(str(one("muscle up 3x5", {"loaded": ["muscle up"]}).data.exercises[0].name) == "Muscle-up", "the library's spelling does not lose what the log knows about the lift")
	# "(PT)" in front of an exercise: a physical therapy lift (game/pt.gd).
	var pt_new = one("(PT) neck 4 way - 3x20@10")
	ok(not pt_new.is_empty() and pt_new.data.exercises[0].name == "Neck 4 Way" and pt_new.data.exercises[0].get("pt") == true and pt_new.names[0].typed == "(PT) neck 4 way" and pt_new.names[0].kind == "new" and pt_new.names[0].pt, "the tag comes off the name and the exercise is marked", pt_new)
	var pt_ctx = {"own": ["Squat"], "exercises": Summary.DEFAULT_EXERCISES}
	var pt_own = one("(PT) squat 3x10", pt_ctx)
	ok(not pt_own.is_empty() and pt_own.data.exercises[0].name == "Squat" and pt_own.data.exercises[0].get("pt") == true and pt_own.names[0].kind == "match" and pt_own.names[0].key == "ptsquat", "a lift they already do, tagged for the first time: that lift, and the review asks", pt_own)
	var pt_known = one("(PT) squat 3x10", pt_ctx.merged({"pt": {"squat": {"name": "Squat", "perWeek": 3}}}))
	ok(not pt_known.is_empty() and pt_known.data.exercises[0].name == "Squat" and not pt_known.has("names"), "once it is a PT lift there is nothing to ask", pt_known)
	var pt_apart = one("(PT) squat 3x10", pt_ctx.merged({"names": {"ptsquat": ""}}))
	ok(not pt_apart.is_empty() and pt_apart.data.exercises[0].name == "PT Squat" and pt_apart.data.exercises[0].get("pt") == true, "'no': the PT one is kept apart under its own name", pt_apart)
	var pt_plain = one("squat 3x5 @ 100", pt_ctx.merged({"names": {"ptsquat": ""}}))
	ok(not pt_plain.is_empty() and pt_plain.data.exercises[0].name == "Squat" and not pt_plain.data.exercises[0].has("pt") and not pt_plain.has("names"), "and the untagged line is still the plain lift", pt_plain)
	var pt_forms = p("11/14
calf raise (PT) 3x15
pt: clamshells 2x20
[pt] glute bridge 3x12
3 pt row 3x8 @ 40")
	var pt_flags = []
	for ex in pt_forms.entries[0].data.exercises if pt_forms.entries.size() == 1 else []:
		pt_flags.append("%s=%s" % [str(ex.name), str(ex.get("pt", false))])
	ok(pt_forms.problems.is_empty() and pt_flags == ["Calf Raise=true", "Clamshells=true", "Glute Bridge=true", "3 Pt Row=false"], "the tag after the name, 'pt:' and '[pt]' count; the bare letters do not", [pt_flags, pt_forms.problems])
	var pt_two = one("(PT) neck 4 way - 3x20@10
neck 4 way 2x20@10")
	ok(not pt_two.is_empty() and pt_two.data.exercises.size() == 1 and pt_two.data.exercises[0].sets.size() == 5 and pt_two.data.exercises[0].get("pt") == true, "tagged and untagged lines of one lift on a day are one exercise, marked", pt_two)
	ok(pt_new.key != one("neck 4 way - 3x20@10").key and one("(PT) neck 4 way - 3x20@10").key == pt_new.key, "the tag is part of the typed line, so adding it later reads as an edit of that day")
	# A hold (a stretch): seconds, written 30" where a weight would be.
	var hd = one("(PT) calf stretch - 3x1@30\"")
	var hd_sets = hd.data.exercises[0].sets if not hd.is_empty() else []
	ok(hd_sets.size() == 3 and int(hd_sets[0].reps) == 1 and int(hd_sets[0].get("holdSec", 0)) == 30 and float(hd_sets[0].weightKg) == 0.0 and hd.data.exercises[0].get("pt") == true and hd.warnings.is_empty(), "3x1@30\": three holds of 30 seconds, no weight, and no 'no weight' warning", hd)
	ok(not hd.is_empty() and str(hd.summary) == "Calf Stretch 3 × 30 s hold", "its line in the review says seconds", hd.get("summary"))
	var hd2 = one("hamstring stretch 3@30\"")
	ok(not hd2.is_empty() and hd2.data.exercises[0].sets.size() == 1 and int(hd2.data.exercises[0].sets[0].reps) == 3 and int(hd2.data.exercises[0].sets[0].holdSec) == 30, "3@30\": one set of three holds", hd2)
	var hd_forms = {"pec stretch 2x45\"": [2, 45], "couch stretch 60\"": [1, 60], "quad stretch 2x30”": [2, 30], "pigeon stretch 2x30''": [2, 30], "plank 3x30s": [3, 30], "plank 3 x 30 sec": [3, 30], "side plank 45 sec x2": [2, 45], "wall sit 2 60 seconds": [2, 60]}
	for hd_line in hd_forms:
		var hd_e = one(hd_line)
		var hd_n = 0
		var hd_s = 0
		for hd_one in (hd_e.data.exercises[0].sets if not hd_e.is_empty() else []):
			hd_n += int(hd_one.reps)
			hd_s = int(hd_one.get("holdSec", 0))
		ok(hd_n == hd_forms[hd_line][0] and hd_s == hd_forms[hd_line][1], "a hold: " + hd_line, hd_e)
	var hd_mix = one("calf stretch 30\", 45\"")
	ok(not hd_mix.is_empty() and hd_mix.data.exercises[0].sets.size() == 2 and int(hd_mix.data.exercises[0].sets[1].holdSec) == 45 and str(hd_mix.summary).ends_with("30 s, 45 s hold"), "two holds of different lengths", hd_mix)
	ok(not one("bench 3x5 @ 80").data.exercises[0].sets[0].has("holdSec") and not one("pull-up 3x8").data.exercises[0].sets[0].has("holdSec"), "a plain set has no hold")
	ok(p("calf stretch 3x4000\"").entries.is_empty() and p("calf stretch 3x4000\"").problems.size() == 1, "an hour-long hold is a mistake, not an entry")
	ok(not one("hang 20mm 10s x6").is_empty() and one("hang 20mm 10s x6").data.get("discipline") == "climb", "a hangboard hang is still a hang")

	# A table (what the inbox makes of a Google Doc's table): one "| a | b |" line per row.
	var lb = {"weightUnit": "lb", "distanceUnit": "mi"}
	var tb = p("| Date | Exercise | Variation | Weight | Reps |\n| 11/14 | Seated row | cable, 1 arm | 70 | 12, 10, 9 |\n| | Bench press | | 80 | 3x5 |\n| | (PT) Neck 4 way | | 10 | 3x20 |\n| | Calf stretch | wall | 30\" | 3 |\n| | | | | |", lb)
	var tb_ex = tb.entries[0].data.exercises if tb.entries.size() == 1 else []
	var tb_names = []
	for tb_one in tb_ex:
		tb_names.append(str(tb_one.name))
	ok(tb.problems.is_empty() and tb.entries.size() == 1 and tb.entries[0].date == "2026-11-14" and tb_names == ["Seated Row Cable, 1 Arm", "Bench Press", "Neck 4 Way", "Calf Stretch Wall"], "a table: its date, and a row per exercise (the variation joins the name)", [tb_names, tb.problems])
	ok(tb_ex.size() == 4 and tb_ex[0].sets.size() == 3 and int(tb_ex[0].sets[1].reps) == 10 and absf(float(tb_ex[0].sets[0].weightKg) - 70.0 * 0.45359237) < 0.01 and tb_ex[1].sets.size() == 3 and int(tb_ex[1].sets[0].reps) == 5, "the weight column and the reps column", tb_ex)
	ok(tb_ex.size() == 4 and tb_ex[2].get("pt") == true and tb_ex[2].sets.size() == 3 and int(tb_ex[3].sets[0].reps) == 3 and int(tb_ex[3].sets[0].get("holdSec", 0)) == 30 and float(tb_ex[3].sets[0].weightKg) == 0.0, "(PT) in the exercise cell, and 30\" in the weight column is a hold", tb_ex)
	var tb2 = p("11/14\n| Exercise | Type | Sets | Reps | Weight (lb) | Notes |\n|---|---|---|---|---|---|\n| Squat | barbell | 3 | 5 | 185 | felt good |", lb)
	var tb2_ex = tb2.entries[0].data.exercises if tb2.entries.size() == 1 else []
	ok(tb2.problems.is_empty() and tb2_ex.size() == 1 and tb2_ex[0].name == "Squat" and tb2_ex[0].sets.size() == 3 and int(tb2_ex[0].sets[2].reps) == 5 and absf(float(tb2_ex[0].sets[0].weightKg) - 185.0 * 0.45359237) < 0.01 and tb2.entries[0].data.get("notes") == "felt good", "Sets and Reps as two columns, other words in the header, a note, a ruler row", tb2)
	var tb3 = p("| Exercise | PT | Weight | Set 1 | Set 2 | Set 3 |\n| Deadlift | | 135 | 5 | 5 | 3 |\n| Clamshell | x | | 15 | 15 | |\n| Romanian deadlift | | | 5@135 | 5@185 | |", lb)
	var tb3_ex = tb3.entries[0].data.exercises if tb3.entries.size() == 1 else []
	ok(tb3.problems.is_empty() and tb3_ex.size() == 3 and tb3_ex[0].sets.size() == 3 and int(tb3_ex[0].sets[2].reps) == 3 and tb3_ex[1].get("pt") == true and tb3_ex[1].sets.size() == 2 and float(tb3_ex[1].sets[0].weightKg) == 0.0 and tb3_ex[2].sets.size() == 2 and absf(float(tb3_ex[2].sets[1].weightKg) - 185.0 * 0.45359237) < 0.01, "a column per set, a PT column, and a weight inside a set's cell", tb3)
	var tb4 = p("| Exercise | Hold | Reps |\n| Pigeon stretch | 45 | 2 |\n| Couch stretch | 60 | |", lb)
	var tb4_ex = tb4.entries[0].data.exercises if tb4.entries.size() == 1 else []
	ok(tb4.problems.is_empty() and tb4_ex.size() == 2 and int(tb4_ex[0].sets[0].reps) == 2 and int(tb4_ex[0].sets[0].holdSec) == 45 and tb4_ex[1].sets.size() == 1 and int(tb4_ex[1].sets[0].holdSec) == 60, "a Hold column is seconds; with no reps it is one hold", tb4)
	var tb5 = p("| Exercise | Variation | Weight | Reps |
| | | 80 | 3x5 |
| Curl | cable | | |
| Bench press | | 80 | 3x5 |", lb)
	ok(tb5.entries.size() == 1 and tb5.problems.size() == 2 and str(tb5.problems[0].why).contains("no exercise") and str(tb5.problems[1].why).contains("no sets or reps") and str(tb5.problems[1].line) == "Curl | cable", "a row that cannot be read is a problem with its reason; the rest still counts", tb5.problems)
	var tb8 = p("| Exercise | Variation | Weight | Set 1 | Set 2 | Set 3 |
| 11/13 | | | | | |
| Push-up | | | 20 | 20 | 18 |
| 11/14 | | | | | |
| Push-up | | | 22 | 20 | |
| read 12 pages | | | | | |", lb)
	ok(tb8.problems.is_empty() and tb8.entries.size() == 3 and tb8.entries[0].date == "2026-11-13" and tb8.entries[0].data.exercises[0].sets.size() == 3 and tb8.entries[1].date == "2026-11-14" and tb8.entries[1].data.exercises[0].sets.size() == 2 and tb8.entries[2].kind == "reading", "a row with one thing in it is that line: a date that starts a day, pages read", tb8)
	var tb6 = p("| bench | 3x5 | @ 80 |\n| run | 5.2km | 27:30 |")
	ok(tb6.problems.is_empty() and tb6.entries.size() == 2 and tb6.entries[1].data.get("discipline") == "run", "a table without a header: each row is read as a line", tb6)
	var tb7 = p("| Date | Exercise | Reps |\n| 11/13 | Push-up | 3x20 |\n| 11/14 | Push-up | 3x22 |")
	ok(tb7.entries.size() == 2 and tb7.entries[0].date == "2026-11-13" and tb7.entries[1].date == "2026-11-14" and tb7.entries[0].key != tb7.entries[1].key and tb7.entries[0].key == p("| Date | Exercise | Reps |\n| 11/13 | Push-up | 3x20 |").entries[0].key, "a date in a row starts a new day; a row keeps its key", tb7)
	ok(QuickLog.table_role("Weight (lb)") == "weight" and QuickLog.table_role("Reps (each set)") == "reps" and QuickLog.table_role("Set 2") == "set" and QuickLog.table_role("PT?") == "pt" and QuickLog.table_role("Weight or hold") == "weight" and QuickLog.table_role("Felt") == "", "what a column holds, from its header")
	var doc = "<html><head><style>td{x}</style></head><body><p><span>11/14</span></p><table><tbody><tr><td colspan=\"1\"><p><span>Exercise</span></p></td><td><p><span>Variation</span></p></td><td><p><span>Weight</span></p></td><td><p><span>Reps</span></p></td></tr><tr><td><p><span>Seated row</span></p></td><td><p><span>cable</span></p></td><td><p><span>70</span></p></td><td><p><span>12, </span><span>10, 9</span></p></td></tr><tr><td><p><span></span></p></td><td><p><span></span></p></td><td><p></p></td><td><p></p></td></tr></tbody></table><p><span>read 20&nbsp;pages</span></p></body></html>"
	var doc_lines = []
	for doc_ln in PhoneInbox.html_to_text(doc).split("\n"):
		if doc_ln.strip_edges() != "":
			doc_lines.append(doc_ln.strip_edges())
	ok(doc_lines == ["11/14", "| Exercise | Variation | Weight | Reps |", "| Seated row | cable | 70 | 12, 10, 9 |", "|  |  |  |  |", "read 20 pages"], "a Google Doc's table comes through as one line per row", doc_lines)
	var doc_parsed = p(PhoneInbox.html_to_text(doc), lb)
	ok(doc_parsed.problems.is_empty() and doc_parsed.entries.size() == 2 and doc_parsed.entries[0].data.exercises[0].sets.size() == 3, "and reads as a lift and the pages under it", doc_parsed)
	# Table rows the way they get filled in mid-workout.
	var tw = p("| Exercise | Variation | Weight | Set 1 | Set 2 | Set 3 |\n| 11/14 | | | | | |\n| Goblet squat | kettlebell | 35 | 12 | | |\n| | | 53 | 8 | 8 | |\n| Face pull | | blue band | 15 | 12 | |\n| | | black band | 10 | | |\n| Lat pulldown | 1 arm, cable | 60 | 10 | 8 | |\n| Rope pushdown | | 50 | 12 | 10 | |\n| Pull-up | | bw | 8 | 6 | |\n| Clamshell | | | | | |", lb)
	var tw_ex = tw.entries[0].data.exercises if tw.entries.size() == 1 else []
	var tw_by = {}
	for tw_one in tw_ex:
		tw_by[str(tw_one.name)] = tw_one
	ok(tw.entries.size() == 1 and tw.entries[0].date == "2026-11-14" and tw_ex.size() == 6, "one lift for the day, six exercises", tw_by.keys())
	var tw_row = {"sets": []}
	for tw_name in tw_by:
		if str(tw_name).begins_with("Goblet Squat"):
			tw_row = tw_by[tw_name]
	ok(tw_row.sets.size() == 3 and int(tw_row.sets[0].reps) == 12 and absf(float(tw_row.sets[0].weightKg) - 35.0 * 0.45359237) < 0.01 and int(tw_row.sets[2].reps) == 8 and absf(float(tw_row.sets[2].weightKg) - 53.0 * 0.45359237) < 0.01, "a row with no exercise goes on with the one above: a second weight of it", tw_by.keys())
	var tw_blue = tw_by.get("Face Pull Blue Band", {"sets": []})
	var tw_black = tw_by.get("Face Pull Black Band", {"sets": []})
	ok(tw_blue.sets.size() == 2 and float(tw_blue.sets[0].weightKg) == 0.0 and tw_black.sets.size() == 1 and int(tw_black.sets[0].reps) == 10, "a band in the Weight column is the resistance: part of the name, no weight", tw_by.keys())
	var tw_warned = false
	for tw_w in tw.entries[0].warnings if tw.entries.size() == 1 else []:
		if str(tw_w).contains("no weight given"):
			tw_warned = true
	ok(not tw_warned, "and no 'no weight given' warning, since the band was given", tw.entries[0].warnings if tw.entries.size() == 1 else [])
	var tw_lat = tw_by.get("Lat Pulldown 1 Arm, Cable", {"sets": []})
	ok(tw_lat.sets.size() == 2 and int(tw_lat.sets[0].reps) == 10, "a number in the variation ('1 arm') is part of the name, not a set", tw_by.keys())
	var tw_rope = tw_by.get("Rope Pushdown", {"sets": []})
	ok(tw_rope.sets.size() == 2 and int(tw_rope.sets[1].reps) == 10, "'rope pushdown' in the Exercise column is a lift, not a climb", tw_by.keys())
	var tw_pull = tw_by.get("Pull-up", {"sets": []})
	ok(tw_pull.sets.size() == 2 and float(tw_pull.sets[0].weightKg) == 0.0, "'bw' in the Weight column is bodyweight", tw_pull)
	ok(tw.problems.size() == 1 and str(tw.problems[0].line) == "Clamshell" and str(tw.problems[0].why).contains("no sets or reps"), "an exercise with nothing beside it yet says it has no sets", tw.problems)
	var tw2 = p("| Exercise | Weight | Set 1 |\n| 11/13 | | |\n| Squat | 100 | 5 |\n| 11/14 | | |\n| | 120 | 5 |")
	ok(tw2.entries.size() == 1 and tw2.problems.size() == 1 and str(tw2.problems[0].why).contains("no exercise"), "a date row ends the exercise a nameless row would go on with", tw2)
	var tw3 = p("| Exercise | PT | Weight | Set 1 | Set 2 |\n| Calf raise | x | | 15 | 15 |\n| | | 10 | 12 | |", lb)
	var tw3_ex = tw3.entries[0].data.exercises if tw3.entries.size() == 1 else []
	ok(tw3.problems.is_empty() and tw3_ex.size() == 1 and tw3_ex[0].get("pt") == true and tw3_ex[0].sets.size() == 3, "the row under a PT exercise stays PT", tw3)

	# Another workout under a date already imported is a second session, not an edit of the first.
	var sw_old = {"exercises": [{"name": "Bench Press"}, {"name": "Deadlift"}, {"name": "Neck 4 Way"}, {"name": "Dip"}]}
	ok(not PhoneInbox.same_workout(sw_old, {"exercises": [{"name": "Pull-up"}, {"name": "Neck 4 Way"}, {"name": "Hip Thrust"}]}), "another workout that shares one exercise is not an edit")
	ok(PhoneInbox.same_workout(sw_old, {"exercises": [{"name": "Bench Press"}, {"name": "Deadlift"}, {"name": "Neck 4 Way"}, {"name": "Dip"}, {"name": "Plank"}]}), "one exercise added is an edit")
	ok(PhoneInbox.same_workout(sw_old, {"exercises": [{"name": "Bench Press"}, {"name": "Deadlift"}]}), "two dropped is an edit")
	ok(PhoneInbox.same_workout({"exercises": [{"name": "Lunge"}]}, {"exercises": [{"name": "Lunge"}, {"name": "Dip"}, {"name": "Plank"}]}), "the old lines kept and more added is an edit")
	ok(PhoneInbox.same_workout(sw_old, {"exercises": [{"name": "Bench Press"}, {"name": "Deadlift"}, {"name": "Neck 4 Way"}, {"name": "Dipp"}]}), "a typo fixed in one of four is an edit")
	ok(PhoneInbox.same_workout({"exercises": [{"name": "Neck 4 Way"}, {"name": "Clamshell"}]}, {"exercises": [{"name": "Pull-up"}, {"name": "Neck 4 Way"}, {"name": "Lunge"}, {"name": "Hip Thrust"}, {"name": "Plank"}]}) == false, "a short PT session and a later workout sharing one exercise are two sessions")
	ok(LiftMatch.tokens("hip abduction, home gym machine") == LiftMatch.tokens("hip abduction, machine"), "'home gym' says where, not which lift", LiftMatch.tokens("hip abduction, home gym machine"))

	# Google's export writes some characters as codes: the curly quote of 30” comes as &rdquo;.
	var ent_in = "3x30&rdquo; &ldquo;a&rdquo; b&amp;c &#8221; &#x201d; 5&nbsp;lb &lt;3 x&rsquo;s &amp;quot;"
	ok(PhoneInbox.decode_entities(ent_in) == "3x30” “a” b&c ” ” 5 lb <3 x’s &quot;", "the codes of an exported doc become their characters", PhoneInbox.decode_entities(ent_in))
	var ent = p(PhoneInbox.html_to_text("<html><body><p><span>11/14</span></p><p><span>(PT) hip flexor stretch - 3x30&rdquo;</span></p><p><span>(PT) toe stretch - 2x45&quot;</span></p><p><span>goblet squat 3x8 @ 40</span></p></body></html>"))
	var ent_ex = ent.entries[0].data.exercises if ent.entries.size() == 1 else []
	ok(ent.problems.is_empty() and ent_ex.size() == 3 and ent_ex[0].sets.size() == 3 and int(ent_ex[0].sets[0].get("holdSec", 0)) == 30 and int(ent_ex[1].sets[1].get("holdSec", 0)) == 45 and not ent_ex[2].sets[0].has("holdSec"), "a stretch typed with a curly quote in a Google Doc is a hold", [ent.problems, ent_ex])
	# A decimal typed without its zero.
	ok(sets_of(one("bench 3x5 @ .5")) == [[5, 0.5], [5, 0.5], [5, 0.5]] and sets_of(one("curl 2x10 @.5kg")) == [[10, 0.5], [10, 0.5]], "'@ .5' is 0.5", [one("bench 3x5 @ .5"), one("curl 2x10 @.5kg")])
	var nz_half = one("run .5km 3:00")
	ok(not nz_half.is_empty() and int(nz_half.data.distanceM) == 500 and nz_half.data.get("durationSec") == 180 and nz_half.summary == "Run 0.5 km · 3:00", "'run .5km' is half a kilometre", nz_half)
	ok(QuickLog.lead_zeros(".5 mi, x .25 @.5 (.75)") == "0.5 mi, x 0.25 @0.5 (0.75)" and QuickLog.lead_zeros("5.10a v4.5 a.5 ...5 1.5") == "5.10a v4.5 a.5 ...5 1.5", "only a dot that opens a number gets a zero", QuickLog.lead_zeros(".5 mi, x .25 @.5 (.75)"))
	ok(one("tr 5.10a flash").data.get("discipline") == "climb" and one("tr 5.10a flash").data.climbs[0].get("yds") == "5.10a", "a route grade is not touched", one("tr 5.10a flash"))
	var nz_noted = one("bench 3x5 @ 80\nnote: walked .5 km to warm up")
	ok(not nz_noted.is_empty() and nz_noted.data.get("notes") == "walked .5 km to warm up" and nz_noted.key == QuickLog.entry_key("lift", "", ["bench 3x5 @ 80", "note: walked .5 km to warm up"]), "a note keeps its words, and its entry the key it had", nz_noted)

	# --- climbing ---------------------------------------------------------------------
	var cl = one("v4 flash x2, v5 send, v6 attempt x3")
	ok(not cl.is_empty() and cl.data.climbs == [{"grade": 4, "result": "flash", "count": 2}, {"grade": 5, "result": "send", "count": 1}, {"grade": 6, "result": "attempt", "count": 3}], "climb list", cl.get("data"))
	ok(one("climb vb x3").data.climbs == [{"grade": -1, "result": "send", "count": 3}], "climb vb x3")
	ok(one("v3").data.climbs == [{"grade": 3, "result": "send", "count": 1}], "bare v3 = one send")
	ok(one("2x v4f").data.climbs == [{"grade": 4, "result": "flash", "count": 2}], "2x v4f")
	ok(one("boulder v5 att, v6 project, v2 fail").data.climbs.all(func(c): return c.result == "attempt"), "attempt words")
	ok(one("v4 flash x2\nv5 s\nv4 f 2x").data.climbs.size() == 2, "climb lines of a day = one session, same grade+result merge")
	var badc = p("v4 flash x2, v4 crimpy")
	ok(badc.entries.size() == 1 and badc.problems.size() == 1, "a bad climb item is a problem, the rest kept")
	ok(p("v18").problems.size() == 1, "V18 is out of range")

	# One climb can hold a send and attempts: every result word is its own tally.
	var sa = one("v1 flash, v2 flash, v3 send 3 attempts, v4 5 attempts")
	ok(not sa.is_empty() and sa.data.climbs == [{"grade": 1, "result": "flash", "count": 1}, {"grade": 2, "result": "flash", "count": 1}, {"grade": 3, "result": "send", "count": 1}, {"grade": 3, "result": "attempt", "count": 3}, {"grade": 4, "result": "attempt", "count": 5}], "send + attempts on one climb", sa.get("data"))
	ok(sa.get("summary") == "V1 flash · V2 flash · V3 send · V3 attempt ×3 · V4 attempt ×5", "send + attempts: summary", sa.get("summary"))
	if not sa.is_empty():
		var sst = Xp.session_stats(sa.data)
		ok(int(sst.sends) == 3 and int(sst.flashes) == 2 and int(sst.attempts) == 8 and int(sst.maxGradeSent) == 3, "send + attempts: 3 tops (2 flashed), 8 tries, best send V3 not V4", [sst.sends, sst.flashes, sst.attempts, sst.maxGradeSent])
	for same in ["v3 send 3 attempts", "v3 send, 3 attempts", "v3 send and 3 attempts", "v3 send + 3 attempts", "v3 send (3 attempts)", "v3 send 3 tries", "v3 s 3 a", "v3 send after 3 attempts", "v3 send after 3", "v3 sent with 3 fails"]:
		ok(tally(same) == "V3s1 V3a3", "one send and three tries: " + same, tally(same))
	ok(tally("v4 5 attempts") == "V4a5", "tries with no send word are only tries", tally("v4 5 attempts"))
	ok(tally("v3 3 attempts then send") == "V3a3 V3s1", "tries first, then the send", tally("v3 3 attempts then send"))
	ok(tally("v3 2 sends 3 attempts") == "V3s2 V3a3" and tally("2x v3 send 3 tries") == "V3s2 V3a3", "each word takes the number before it")
	ok(tally("v3 flash x2 attempt x3") == "V3f2 V3a3", "x2 goes with the word before it", tally("v3 flash x2 attempt x3"))
	ok(tally("v4 2 flash") == "V4f2" and tally("v4 x2 flash") == "V4f2" and tally("v5 3") == "V5s3", "one number and one word: as before")
	ok(tally("v4 project 5 attempts") == "V4a5", "two words for the same result are one tally", tally("v4 project 5 attempts"))
	ok(tally("v3 send flash") == "V3f1", "send + flash with no numbers is one flashed climb", tally("v3 send flash"))
	ok(tally("v3 send 0 attempts") == "V3s1", "0 attempts adds nothing", tally("v3 send 0 attempts"))
	ok(tally("v3 send 3 attempts\nv3 2 attempts") == "V3s1 V3a5", "tries on a later line add up")
	var rs = one("5.10a send 2 attempts")
	ok(tally("5.10a send 2 attempts") == "5.10as1 5.10aa2" and rs.data.climbs.all(func(c): return c.get("style") == "rope"), "a route takes a send and tries too", rs.get("data"))
	# "3rd go" says which go it went on.
	for third in ["v3 3rd go", "v3 sent 3rd go", "v3 sent on the 3rd go", "v3 send in 3", "v3 send in 3 goes", "v3 third try"]:
		ok(tally(third) == "V3s1 V3a2", "third go = a send and two tries: " + third, tally(third))
	ok(tally("v3 first go") == "V3f1" and tally("v3 send 1st go") == "V3f1", "first go is a flash")
	# "no send": everything on it was a try.
	ok(tally("v4 5 attempts no send") == "V4a5" and tally("v4 5 attempts, no send") == "V4a5", "no send after tries adds nothing")
	ok(tally("v4 no send") == "V4a1" and tally("v4 x3 no send") == "V4a3" and tally("v5 unsent") == "V5a1", "no send alone is a try")
	# What cannot be told apart stays a problem, never a guess.
	for no in ["v3 flash 2nd go", "v4 flash x2 3", "v4 send no send", "v3 v4", "v4 x0", "v4 x150"]:
		ok(p(no).entries.is_empty() and p(no).problems.size() == 1, "not guessed: " + no, p(no))
	var half = p("v4 flash, 5 send")
	ok(half.problems.size() == 1 and half.entries.size() == 1 and half.entries[0].data.climbs == [{"grade": 4, "result": "flash", "count": 1}], "a send with no grade is not given the grade before it", half)
	ok(p("v4 crimpy, 3 attempts").problems.size() == 2 and p("v4 crimpy, 3 attempts").entries.is_empty(), "tries after an unreadable climb are attached to nothing")
	ok(p("v4, no send").problems.size() == 1, "no send after a send is a problem")

	# --- running / cycling ------------------------------------------------------------
	var run = one("run 5.2km 27:30 +80m")
	ok(not run.is_empty() and run.data.discipline == "run" and int(run.data.distanceM) == 5200 and int(run.data.durationSec) == 1650 and int(run.data.elevationM) == 80, "run 5.2km 27:30 +80m", run.get("data"))
	var ride = one("ride 40km 1h35")
	ok(ride.data.discipline == "ride" and int(ride.data.distanceM) == 40000 and int(ride.data.durationSec) == 5700, "ride 40km 1h35")
	ok(int(one("ran 5.2 km in 45 min").data.durationSec) == 2700 and int(one("jog 10k 1:02:30").data.durationSec) == 3750, "5.2 km, 45 min, 10k, 1:02:30")
	ok(int(one("run 3mi 30min").data.distanceM) == 4828 and int(one("run 3", {"distanceUnit": "mi"}).data.distanceM) == 4828, "miles, bare number in the player's unit")
	ok(int(one("bike 30 1h 30m").data.durationSec) == 5400 and int(one("cycle 30km 1.5h").data.durationSec) == 5400 and int(one("ride 20km 1h").data.durationSec) == 3600, "1h 30m, 1.5h, 1h")
	var track = one("run 400m 1:30")
	ok(not track.is_empty() and int(track.data.distanceM) == 400 and int(track.data.durationSec) == 90, "run 400m 1:30 is 400 metres, not 400 minutes", track.get("data"))
	ok(int(one("ride 5000m").data.distanceM) == 5000, "ride 5000m is a distance")
	var mm = one("run 8km 45m 120m")
	ok(int(mm.data.durationSec) == 2700 and int(mm.data.elevationM) == 120, "bare NNm: minutes first, then metres")
	ok(int(one("run 8km 40:00 80m elev").data.elevationM) == 80 and int(one("run 8km elev 80").data.elevationM) == 80, "80m elev / elev 80")
	ok(int(one("ride 40km 300 ft gain").data.elevationM) == 91 and int(one("run 5km +100", {"distanceUnit": "mi"}).data.elevationM) == 30, "feet of climbing")
	ok(int(one("run 5,2km 27:30").data.distanceM) == 5200, "decimal comma in a distance")
	ok(p("run 5km\nrun 3km").entries.size() == 2, "each run is its own session")
	ok(p("run fast").problems.size() == 1 and p("run fast").entries.is_empty(), "run without distance is a problem")

	# --- body ---------------------------------------------------------------------------
	var body = one("weight 82.4  bf 18")
	ok(body.kind == "body" and float(body.data.weightKg) == 82.4 and float(body.data.bodyFatPct) == 18.0, "weight + bf on one line")
	ok(is_equal_approx(float(one("weighed 181 lb").data.weightKg), 82.1), "weighed 181 lb", one("weighed 181 lb").get("data"))
	ok(float(one("bw 82,4").data.weightKg) == 82.4 and float(one("body fat 18.5%").data.bodyFatPct) == 18.5, "bw with decimal comma, body fat %")
	var b2 = one("weight 82.4\nbf 18.5")
	ok(b2.data.has("weightKg") and b2.data.has("bodyFatPct"), "one body entry per date from two lines")
	ok(is_equal_approx(float(one("weight 181", {"weightUnit": "lb"}).data.weightKg), 82.1), "weight in the player's lb")
	ok(p("weight banana").problems.size() == 1 and p("weight 900").problems.size() == 1, "bad weights are problems")

	# --- extras --------------------------------------------------------------------------
	var ex = one("title: Push day\nbench 3x5 @ 80\nnote: felt strong\nduration 70min")
	ok(ex.data.get("title") == "Push day" and ex.data.get("notes") == "felt strong" and int(ex.data.get("durationSec", 0)) == 4200, "title above, note and duration below", ex.get("data"))
	var r2 = p("bench 3x5 @ 80\nrun 5km\ntime 1h10")
	ok(int(r2.entries[1].data.get("durationSec", 0)) == 4200 and r2.entries[0].data.get("durationSec") == null, "duration attaches to the last session (the run)")
	ok(p("note: nothing here").problems.size() == 1, "an extra with no session is a problem")

	# --- dates ---------------------------------------------------------------------------
	ok(date_of("2026-11-14") == "2026-11-14" and date_of("nov 14") == "2026-11-14" and date_of("November 14:") == "2026-11-14", "iso, nov 14, November 14:")
	ok(date_of("14 nov") == "2026-11-14" and date_of("11/14") == "2026-11-14" and date_of("11/14/2026") == "2026-11-14", "14 nov, 11/14, 11/14/2026")
	ok(date_of("dec 20") == "2025-12-20" and date_of("12/20") == "2025-12-20", "future month/day = last year")
	ok(date_of("today") == TODAY and date_of("yesterday") == "2026-11-14", "today, yesterday")
	ok(date_of("sat") == "2026-11-14" and date_of("saturday") == "2026-11-14" and date_of("sun") == TODAY and date_of("mon") == "2026-11-09", "weekday names (on or before today)")
	ok(date_of("sat nov 7") == "2026-11-07", "weekday before an explicit date is decoration")
	var nd = p("bench 3x5 @ 80")
	ok(nd.entries[0].date == TODAY and nd.entries[0].date_note == QuickLog.NO_DATE_NOTE, "no date line = today with a note")
	ok(p("yesterday\nbench 3x5 @ 80").entries[0].date_note != "" and p("nov 14\nbench 3x5 @ 80").entries[0].date_note == "", "relative dates carry a note, explicit ones do not")
	var days = p("nov 13\nbench 3x5 @ 80\nnov 14\nbench 3x5 @ 82.5\nrun 5km")
	ok(days.entries.size() == 3 and days.entries[0].date == "2026-11-13" and days.entries[2].date == "2026-11-14", "entries take the date above them")
	ok(p("nov 14: v4 flash x2").entries[0].date == "2026-11-14", "date: entry on one line")
	ok(date_of("feb 30") == TODAY and p("feb 30").problems.size() == 1, "an impossible date is a problem")

	# --- problems ---------------------------------------------------------------------------
	var junk = p("hello there\nbench 3x5 @ 80\nfelt great today!!")
	ok(junk.entries.size() == 1 and junk.problems.size() == 2 and junk.problems[0].line == "hello there", "junk lines are kept as problems with their text", junk.problems)
	ok(junk.problems[0].why != "", "problems say why")

	# --- summaries ----------------------------------------------------------------------------
	ok(one("bench 3x5 @ 80").summary == "Bench Press 3×5 @ 80 kg", "lift summary", one("bench 3x5 @ 80").summary)
	ok(one("run 5.2km 27:30 +80m").summary == "Run 5.2 km · 27:30 · 80 m up", "run summary", one("run 5.2km 27:30 +80m").summary)
	ok(one("v4 flash x2, v5 send").summary == "V4 flash ×2 · V5 send", "climb summary")

	# --- the cheat sheet the app shows parses cleanly ---------------------------------------------
	var cs = p(QuickLog.CHEAT_SHEET)
	ok(cs.problems.is_empty() and cs.entries.size() == 7, "cheat sheet: 7 entries, no problems", [cs.entries.size(), cs.problems])

	# --- pages read (game/reading.gd) -----------------------------------------------------------
	var rd_one = one("nov 14\nread 20 pages")
	ok(not rd_one.is_empty() and rd_one.kind == "reading" and int(rd_one.data.pages) == 20 and rd_one.date == "2026-11-14" and rd_one.summary == "Read 20 pages", "read 20 pages", rd_one)
	for rd_line in ["reading 20", "read: 20", "20 pages", "20 pages read", "20p", "read 20p", "pages 20", "read 20 pgs", "Read 20 Pages of the big book", "read chapter 3, 20 pages", "reading - 20 pages before bed"]:
		var rd_e = one(rd_line)
		ok(not rd_e.is_empty() and rd_e.kind == "reading" and int(rd_e.data.pages) == 20, "'%s' is 20 pages" % rd_line, rd_e)
	ok(one("read 1 page").summary == "Read 1 page", "one page is singular", one("read 1 page").get("summary"))
	var rd_two = one("read 12 pages\nbench 3x5 @ 80\nread 8 pages\nrun 5km").is_empty()
	var rd_day = p("11/14\nread 12 pages\nbench 3x5 @ 80\nread 8 pages")
	ok(rd_two and rd_day.entries.size() == 2 and rd_day.problems.is_empty(), "reading and a lift on one day are two entries", rd_day)
	var rd_pages = null
	for rd_e in rd_day.entries:
		if rd_e.kind == "reading":
			rd_pages = rd_e
	ok(rd_pages != null and int(rd_pages.data.pages) == 20 and rd_pages.raw.size() == 2, "two reading lines on a day add up", rd_pages)
	var rd_inline = one("11/14: read 25 pages")
	ok(not rd_inline.is_empty() and rd_inline.kind == "reading" and rd_inline.date == "2026-11-14" and int(rd_inline.data.pages) == 25, "a date, a colon, then the pages", rd_inline)
	for rd_bad in ["read 30 min", "reading 1h", "read", "read a lot", "read 0 pages", "read 99999 pages"]:
		var rd_r = p(rd_bad)
		ok(rd_r.entries.is_empty() and rd_r.problems.size() == 1 and str(rd_r.problems[0].why).contains("read 20 pages"), "'%s' is a problem line with a hint" % rd_bad, rd_r)
	ok(one("reverse fly 3x12 @ 10").kind == "session" and one("pull-up 3x8").kind == "session", "lifts are still lifts")
	var rd_ka = one("nov 14\nread 20 pages")
	var rd_kb = one("nov 14\nread 35 pages")
	ok(rd_ka.key != rd_kb.key and QuickLog.key_prefix(rd_ka.key) == QuickLog.key_prefix(rd_kb.key) and str(rd_ka.key).begins_with("read-"), "an edited reading line keeps the key prefix of its day", [rd_ka.key, rd_kb.key])

	# --- keys ---------------------------------------------------------------------------------
	var k1 = p("yesterday\nbench 3x5 @ 80\nrun 5km")
	var k2 = QuickLog.parse("yesterday\nbench 3x5 @ 80\nrun 5km", opts({"today": "2026-12-03"}))
	ok(k1.entries[0].key == k2.entries[0].key and k1.entries[1].key == k2.entries[1].key, "same text, different today: same keys")
	ok(k1.entries[0].key != k1.entries[1].key, "different entries: different keys")
	ok(p("Bench 3X5 @ 80").entries[0].key == p("bench 3x5 @ 80").entries[0].key, "keys ignore case and spacing")
	ok(p("nov 14\nrun 5km").entries[0].key != p("nov 15\nrun 5km").entries[0].key, "the date header is part of the key")
	ok(QuickLog.key_prefix(p("nov 14\nbench 3x5 @ 80").entries[0].key) == QuickLog.key_prefix(p("nov 14\nbench 3x5 @ 80\nsquat 3x5 @ 100").entries[0].key), "key prefix names kind + day")

	# --- CSV (Google Form responses) ---------------------------------------------------------------
	var csv = "Timestamp,What did you do?\n\"11/14/2026 18:32:10\",\"bench 3x5 @ 80\nsquat 5,5,4 @ 100\"\n2026-11-13 07:05,run 5km 25:00\n11/12/2026 20:00:00,\"v4 flash x2, v5 send\"\n"
	ok(QuickLog.looks_like_csv(csv) and not QuickLog.looks_like_csv("nov 14\nbench 3x5 @ 80"), "CSV detection")
	var cr = QuickLog.parse_any(csv, opts())
	ok(cr.entries.size() == 3 and cr.problems.is_empty(), "CSV rows -> entries", [cr.entries.size(), cr.problems])
	ok(cr.entries[0].date == "2026-11-14" and cr.entries[0].date_note == "" and cr.entries[0].data.exercises.size() == 2, "quoted multi-line cell with commas, dated by the timestamp")
	ok(cr.entries[1].date == "2026-11-13" and cr.entries[2].data.climbs.size() == 2, "ISO timestamp, quoted commas in a climb cell")
	var csv2 = csv + "\"11/15/2026 09:00:00\",bench 3x5 @ 80\n"
	var cr2 = QuickLog.parse_csv(csv2, opts())
	ok(cr2.entries[3].key != cr2.entries[0].key and cr2.entries[0].key == cr.entries[0].key, "CSV keys include the timestamp and are stable")
	ok(QuickLog.csv_rows("a,\"b \"\"q\"\" c\",d\r\ne,f") == [["a", "b \"q\" c", "d"], ["e", "f"]], "CSV quote escaping and CRLF")
	ok(QuickLog.timestamp_date("14.11.2026 18:32:10") == "2026-11-14" and QuickLog.timestamp_date("hello") == "", "dotted day-first timestamps")

	# --- share links -> raw text (app/inbox.gd, static) ---------------------------------------------
	ok(PhoneInbox.fetch_url("https://docs.google.com/document/d/AbC_123-x/edit?usp=sharing") == "https://docs.google.com/document/d/AbC_123-x/export?format=zip", "Google Doc link (zip: text and pictures)")
	ok(PhoneInbox.fetch_url("https://docs.google.com/spreadsheets/d/XyZ9/edit#gid=12345") == "https://docs.google.com/spreadsheets/d/XyZ9/export?format=csv&gid=12345", "Google Sheet link keeps gid")
	ok(PhoneInbox.fetch_url("https://docs.google.com/spreadsheets/d/XyZ9/edit?usp=sharing") == "https://docs.google.com/spreadsheets/d/XyZ9/export?format=csv", "Google Sheet link")
	ok(PhoneInbox.fetch_url("https://www.dropbox.com/s/abc/log.txt?dl=0") == "https://www.dropbox.com/s/abc/log.txt?dl=1", "Dropbox dl=0 -> dl=1")
	ok(PhoneInbox.fetch_url("https://gist.github.com/someone/0123abcd") == "https://gist.github.com/someone/0123abcd/raw", "gist page -> raw")
	ok(PhoneInbox.fetch_url(" https://example.com/notes.txt ") == "https://example.com/notes.txt", "other links unchanged")

	# --- routes (5.xx) and hangboard --------------------------------------------
	var tr = one("5.10a flash, 5.11b send x2, tr 5.9")
	ok(not tr.is_empty() and tr.data.climbs.size() == 3, "three routes on one line", tr)
	if not tr.is_empty() and tr.data.climbs.size() == 3:
		var r0 = tr.data.climbs[0]
		ok(r0.get("style") == "rope" and r0.yds == "5.10a" and r0.result == "flash" and int(r0.grade) == 1, "5.10a flash is a route worth V1", r0)
		ok(tr.data.climbs[1].yds == "5.11b" and int(tr.data.climbs[1].count) == 2, "5.11b send x2", tr.data.climbs[1])
		ok(tr.data.climbs[2].yds == "5.9" and tr.data.climbs[2].result == "send", "tr 5.9", tr.data.climbs[2])
	ok(str(one("top rope 5.10 x2").summary).contains("5.10a TR"), "bare 5.10 reads as 5.10a and the summary says TR", one("top rope 5.10 x2"))
	var mix = one("v3 x2, 5.10c")
	ok(not mix.is_empty() and mix.data.climbs.size() == 2 and not mix.data.climbs[0].has("style") and mix.data.climbs[1].get("style") == "rope", "boulder and route on one line stay apart", mix)
	var hg = one("hang 20mm 10s x6")
	ok(not hg.is_empty() and hg.data.get("hangs", []).size() == 1 and int(hg.data.hangs[0].count) == 6 and int(hg.data.hangs[0].sec) == 10 and int(hg.data.hangs[0].edgeMm) == 20 and int(hg.data.hangs[0].arms) == 2, "hang 20mm 10s x6", hg)
	var oa = one("one arm hang 15mm 7s x3 +10")
	ok(not oa.is_empty() and int(oa.data.hangs[0].arms) == 1 and int(oa.data.hangs[0].edgeMm) == 15 and absf(float(oa.data.hangs[0].addKg) - 10.0) < 0.01, "one arm hang with added weight", oa)
	var asst = one("hangboard 10mm 10s x4 -20lb")
	ok(not asst.is_empty() and float(asst.data.hangs[0].addKg) < -9.0 and float(asst.data.hangs[0].addKg) > -9.1, "assisted hang in lb", asst)
	var both = one("v4 send\nhang 20mm 10s x5\nhang 20mm 10s x5")
	ok(not both.is_empty() and both.data.climbs.size() == 1 and both.data.hangs.size() == 1 and int(both.data.hangs[0].count) == 10, "hangs join the day's climb session and merge", both)
	var two_h = one("hang 20mm 10s x6, 15mm 7s x3")
	ok(not two_h.is_empty() and two_h.data.hangs.size() == 2 and int(two_h.data.hangs[1].edgeMm) == 15, "two hangs on one line", two_h)
	ok(not p("hang 20mm").problems.is_empty(), "a hang without seconds is a problem")
	ok(str(one("hang jug 20s x3").summary).contains("jug"), "jug hang summary", one("hang jug 20s x3"))
	var hs = Xp.session_stats({"discipline": "climb", "date": TODAY, "climbs": [{"grade": 3, "result": "send", "count": 1, "style": "rope", "yds": "5.11a"}], "hangs": [{"edgeMm": 20, "sec": 10, "arms": 2, "addKg": 10.0, "count": 6}]})
	ok(hs.maxGradeSent == null and int(hs.maxRouteSent) == Xp.yds_index("5.11a") and int(hs.hangs) == 6 and int(hs.hangSec) == 60 and absf(float(hs.bestHangKg) - 10.0) < 0.01, "session_stats keeps routes out of the V-grade PR and sums hangs", hs)
	var hx = Xp.base_session_xp({"discipline": "climb", "date": TODAY, "climbs": [], "hangs": [{"edgeMm": 20, "sec": 10, "arms": 2, "addKg": 0.0, "count": 6}]})
	ok(int(hx.xp) == 60, "6 × 10 s on 20 mm = 60 XP", hx)
	ok(absf(Xp.hang_xp({"edgeMm": 10, "sec": 10, "arms": 1, "addKg": 0.0}) - 50.0) < 0.01, "10 mm one arm 10 s = 50 XP", Xp.hang_xp({"edgeMm": 10, "sec": 10, "arms": 1, "addKg": 0.0}))
	ok(absf(Xp.route_xp(Xp.yds_index("5.10a")) - 45.0) < 0.01, "5.10a = V1 × 1.5 = 45 XP", Xp.route_xp(Xp.yds_index("5.10a")))
	# Pictures in the note (a Google Doc's images arrive as "photo images/imageN.jpg" lines).
	var pics = p("progress pics 11/15\nphoto images/image1.jpg\nphoto images/image2.jpg\nphoto images/image3.jpg")
	ok(pics.entries.size() == 1 and pics.problems.is_empty() and pics.entries[0].kind == "body" and pics.entries[0].date == "2026-11-15" and pics.entries[0].data.get("photoRefs", []).size() == 3, "progress pics 11/15 + three pictures = one check-in with three photos", pics)
	ok(not pics.entries.is_empty() and str(pics.entries[0].summary) == "3 progress photos", "summary says 3 progress photos", pics)
	var four = p("nov 14\nweight 82\nphoto images/a.jpg\nphoto images/b.jpg\nphoto images/c.jpg\nphoto images/d.jpg")
	ok(four.entries.size() == 1 and four.entries[0].data.photoRefs.size() == 3 and not four.entries[0].warnings.is_empty() and four.entries[0].data.has("weightKg"), "a fourth picture is left out with a warning; the weight joins the same check-in", four)
	ok(p("pics\nphotos\nprogress pics").entries.is_empty() and p("pics\nphotos\nprogress pics").problems.is_empty(), "bare picture labels are skipped")
	ok(p("photos nov 14\nbench 3x5 @ 80").entries.size() == 1 and p("photos nov 14\nbench 3x5 @ 80").entries[0].date == "2026-11-14", "'photos nov 14' dates the block", p("photos nov 14\nbench 3x5 @ 80"))
	var html = "<html><head><style>p{x}</style><title>W</title></head><body><p class=\"c1\"><span>11/14</span></p><p><span>Backsquat x5&nbsp;135</span></p><p><span></span></p><p><span>Progress pics 11/15</span></p><p><span><img alt=\"\" src=\"images/image1.jpg\" style=\"w\"></span><span><img src=\"images/image2.jpg\"></span></p></body></html>"
	var lines = []
	for ln in PhoneInbox.html_to_text(html).split("\n"):
		if ln.strip_edges() != "":
			lines.append(ln.strip_edges())
	ok("|".join(PackedStringArray(lines)) == "11/14|Backsquat x5 135|Progress pics 11/15|photo images/image1.jpg|photo images/image2.jpg", "Google Doc HTML -> lines with photo markers", lines)
	print("QUICKLOG: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
