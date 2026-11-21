extends SceneTree
## Unit test for game/lift_match.gd: which lift a typed name means.
##   godot --headless --path . --script res://tests/lift_match_test.gd
## Prints LIFTMATCH: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func best(typed: String, known: Array = []) -> Dictionary:
	var f = LiftMatch.find(typed, known)
	return f[0] if not f.is_empty() else {"name": "", "score": 0.0, "own": false}


func _init() -> void:
	# --- the words of a name --------------------------------------------------------------
	ok(LiftMatch.tokens("Triceps push-downs w/ rope") == ["tricep", "pushdown", "rope"], "plural, 'push-downs' as one word, 'w/' dropped", LiftMatch.tokens("Triceps push-downs w/ rope"))
	ok(LiftMatch.tokens("Pull-ups") == ["pullup"] and LiftMatch.tokens("sit ups") == ["situp"] and LiftMatch.tokens("Bent-Over Row") == ["bentover", "row"], "'pull ups', 'sit ups', 'bent over' are one word each")
	ok(LiftMatch.tokens("DB bench press") == ["dumbbell", "bench", "press"] and LiftMatch.tokens("KB swings") == ["kettlebell", "swing"], "short forms for equipment")
	ok(LiftMatch.tokens("row - cable, 1UE") == ["row", "cable", "single", "arm"] and LiftMatch.tokens("one arm cable row") == ["single", "arm", "cable", "row"] and LiftMatch.tokens("1-arm row") == ["single", "arm", "row"], "'1UE', 'one arm' and '1-arm' all say single arm", [LiftMatch.tokens("row - cable, 1UE"), LiftMatch.tokens("1-arm row")])
	ok(LiftMatch.tokens("EZ-Bar Curl") == ["ez", "curl"] and LiftMatch.tokens("over head press") == ["overhead", "press"] and LiftMatch.tokens("dead lifts") == ["deadlift"], "words written apart")
	ok(LiftMatch.tokens("leg press on the home pulley") == ["leg", "press", "home", "cable"] and LiftMatch.tokens("leg press, home gym pulley") == ["leg", "press", "home", "cable"], "small words go, a pulley is a cable, where it was done stays ('home gym' is 'home')", LiftMatch.tokens("leg press on the home pulley"))
	ok(LiftMatch.tokens("Presses") == ["press"] and LiftMatch.tokens("crunches") == ["crunch"] and LiftMatch.tokens("calves") == ["calf"] and LiftMatch.tokens("chest flyes") == ["chest", "fly"], "plurals", [LiftMatch.tokens("Presses"), LiftMatch.tokens("crunches")])
	ok(LiftMatch.key("Lat pull-down, 1UE") == "latpulldown1ue" and LiftMatch.key("  Neck 4 way ") == "neck4way", "a decision is filed under letters and digits only")

	# --- typos ----------------------------------------------------------------------------
	ok(LiftMatch.typo("extension", "extention") == 1 and LiftMatch.typo("raise", "riase") == 1 and LiftMatch.typo("squat", "squat") == 0, "one letter changed or two swapped is one typo")
	ok(LiftMatch.typo("pulldown", "pushdown") == 2 and LiftMatch.typo("incline", "decline") == 2 and LiftMatch.typo("pullup", "pushup") == 2, "pulldown / pushdown and incline / decline are two apart")
	ok(LiftMatch.same_word("extension", "extention") and not LiftMatch.same_word("pulldown", "pushdown") and not LiftMatch.same_word("dip", "hip") and not LiftMatch.same_word("curl", "curb"), "a typo counts only in a word of five letters or more")
	ok(absf(LiftMatch.alike(["cable", "fly"], ["fly", "cable"]) - 1.0) < 0.001 and absf(LiftMatch.alike(["cable", "row"], ["seated", "cable", "row"]) - 0.8) < 0.001 and LiftMatch.alike([], ["row"]) == 0.0, "alike: the same words in any order are 1")

	# --- the names a typed name could be (the review's "pick another lift") -------------------
	var mine = ["Seated Row - Single arm", "Chest Fly - Cable", "Squat - Barbell", "Calf Raise", "Bicep Curl - Incline dumbbell"]
	var b1 = LiftMatch.find("seated row single arm, home pulley", mine)
	ok(not b1.is_empty() and b1[0].name == "Seated Row - Single arm" and float(b1[0].score) >= LiftMatch.CLOSE, "the same words in other words come first", b1)
	var b2 = LiftMatch.find("cable fly chest", mine)
	ok(not b2.is_empty() and b2[0].name == "Chest Fly - Cable", "order does not matter", b2)
	var b6 = LiftMatch.find("incline dumbell curls", mine)
	ok(not b6.is_empty() and b6[0].name == "Bicep Curl - Incline dumbbell", "a misspelling and a plural still find it", b6)
	ok(LiftMatch.find("", mine).is_empty() and LiftMatch.find("the with", mine).is_empty(), "no words, no names")
	var top = LiftMatch.find("row", mine + ["Bent Over Row - Barbell", "Upright Row - Barbell"], 3)
	ok(top.size() == 3 and float(top[0].score) >= float(top[1].score) and float(top[1].score) >= float(top[2].score), "best first, as many as asked for", top)
	print("LIFTMATCH: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
