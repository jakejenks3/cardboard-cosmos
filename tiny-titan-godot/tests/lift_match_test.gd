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
	ok(LiftMatch.tokens("leg press on the home pulley") == ["leg", "press", "cable"], "small words go, a pulley is a cable", LiftMatch.tokens("leg press on the home pulley"))
	ok(LiftMatch.tokens("Presses") == ["press"] and LiftMatch.tokens("crunches") == ["crunch"] and LiftMatch.tokens("calves") == ["calf"] and LiftMatch.tokens("chest flyes") == ["chest", "fly"], "plurals", [LiftMatch.tokens("Presses"), LiftMatch.tokens("crunches")])
	ok(LiftMatch.key("Lat pull-down, 1UE") == "latpulldown1ue" and LiftMatch.key("  Neck 4 way ") == "neck4way", "a decision is filed under letters and digits only")

	# --- typos ----------------------------------------------------------------------------
	ok(LiftMatch.typo("extension", "extention") == 1 and LiftMatch.typo("raise", "riase") == 1 and LiftMatch.typo("squat", "squat") == 0, "one letter changed or two swapped is one typo")
	ok(LiftMatch.typo("pulldown", "pushdown") == 2 and LiftMatch.typo("incline", "decline") == 2 and LiftMatch.typo("pullup", "pushup") == 2, "pulldown / pushdown and incline / decline are two apart")
	ok(LiftMatch.same_word("extension", "extention") and not LiftMatch.same_word("pulldown", "pushdown") and not LiftMatch.same_word("dip", "hip") and not LiftMatch.same_word("curl", "curb"), "a typo counts only in a word of five letters or more")
	ok(absf(LiftMatch.alike(["cable", "fly"], ["fly", "cable"]) - 1.0) < 0.001 and absf(LiftMatch.alike(["cable", "row"], ["seated", "cable", "row"]) - 0.8) < 0.001 and LiftMatch.alike([], ["row"]) == 0.0, "alike: the same words in any order are 1")

	# --- the library ----------------------------------------------------------------------
	var lib = LiftLibrary.catalog()
	var odd = []
	for i in range(lib.size()):
		if LiftMatch.row_of(str(lib[i].name)) != i:
			odd.append(lib[i].name)
	ok(odd.is_empty(), "every library lift is itself, and no two are the same words", odd)
	var missing = []
	for d in Summary.DEFAULT_EXERCISES:
		if LiftMatch.library_name(str(d)) == "":
			missing.append(d)
	ok(missing.is_empty(), "every suggested lift is in the library", missing)
	ok(LiftMatch.library_name("db bench") == "Dumbbell Bench Press" and LiftMatch.library_name("cable crossover") == "Cable Fly" and LiftMatch.library_name("squats") == "Squat" and LiftMatch.library_name("pull ups") == "Pull-up", "the library's own name for another name of a lift", [LiftMatch.library_name("db bench"), LiftMatch.library_name("pull ups")])
	ok(LiftMatch.library_name("neck 4 way") == "" and LiftMatch.library_name("chest fly cable") == "", "only an exact name counts there")
	ok(LiftMatch.row_of("Chest Fly Cable") == LiftMatch.row_of("Cable Fly") and LiftMatch.row_of("Cable Fly") >= 0, "'Chest Fly Cable' is the library's Cable Fly (the body part says nothing new)")
	ok(LiftMatch.row_of("Lateral Raise Cable") == LiftMatch.row_of("Cable Lateral Raise") and LiftMatch.row_of("Lateral Raise Cable") != LiftMatch.row_of("Lateral Raise"), "'Lateral Raise Cable' is the cable one, not the dumbbell one")
	ok(LiftMatch.row_of("Neck 4 Way") == -1 and LiftMatch.row_of("Zercher Carry") == -1, "a lift of the player's own is no library lift")

	# --- the lifts a typed name could be ---------------------------------------------------
	var mine = ["seated row - cable, 1UE", "Chest Fly Cable", "Squat", "Heel Raise"]
	var b1 = best("seated row single arm, home pulley", mine)
	ok(b1.name == "seated row - cable, 1UE" and float(b1.score) >= LiftMatch.SAME and b1.own, "the same words in other words is the player's own lift", b1)
	var b2 = best("cable fly", mine)
	ok(b2.name == "Chest Fly Cable" and float(b2.score) >= LiftMatch.SAME and b2.own, "their lift stands for the library lift it is", b2)
	var b3 = best("cable fly")
	ok(b3.name == "Cable Fly" and not b3.own and float(b3.score) >= LiftMatch.SAME, "without it, the library lift", b3)
	var b4 = best("lateral raise - cable")
	var dumb = 0.0
	for c in LiftMatch.find("lateral raise - cable", [], 40):
		if c.name == "Lateral Raise":
			dumb = float(c.score)
	ok(b4.name == "Cable Lateral Raise" and float(b4.score) >= LiftMatch.SAME and dumb < LiftMatch.CLOSE, "other equipment than the lift uses counts against it", [b4, dumb])
	var b5 = best("tricep pulldown")
	ok(float(b5.score) < LiftMatch.SAME, "a pulldown is not a pushdown", b5)
	var b6 = best("incline dumbell curls")
	ok(b6.name == "Incline Dumbbell Curl" and float(b6.score) >= LiftMatch.SAME, "a misspelling and a plural are still the lift", b6)
	var b7 = best("incline dumbbell hammer curl")
	ok(float(b7.score) < LiftMatch.SAME and float(b7.score) >= LiftMatch.CLOSE, "one more word makes it another lift: offered as closest, not taken", b7)
	var b8 = best("neck 4 way", mine)
	ok(float(b8.score) < LiftMatch.CLOSE, "nothing is close to a lift nobody has", b8)
	var b9 = best("bench press dumbbell")
	ok(b9.name == "Dumbbell Bench Press" and float(b9.score) >= LiftMatch.SAME, "the words in another order", b9)
	ok(LiftMatch.find("", mine).is_empty() and LiftMatch.find("the with", mine).is_empty(), "no words, no lifts")
	var top = LiftMatch.find("row", mine, 4)
	ok(top.size() == 4 and float(top[0].score) >= float(top[1].score) and float(top[1].score) >= float(top[2].score), "best first, as many as asked for", top)

	# --- the player's own name for a library lift --------------------------------------------
	ok(LiftMatch.same_lift("Cable Fly", mine) == "Chest Fly Cable" and LiftMatch.same_lift("Calf Raise", mine) == "Heel Raise", "their name for a library lift", [LiftMatch.same_lift("Cable Fly", mine), LiftMatch.same_lift("Calf Raise", mine)])
	ok(LiftMatch.same_lift("Squat", mine) == "" and LiftMatch.same_lift("Bench Press", mine) == "" and LiftMatch.same_lift("Neck 4 Way", mine) == "", "none when they log it under its own name, or not at all")
	print("LIFTMATCH: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
