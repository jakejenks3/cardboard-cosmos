extends SceneTree
## Unit test for game/plates.gd: warm-ups and plates on the bar.
##   godot --headless --path . --script res://tests/plates_test.gd
## Prints PLATES: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	ok(Plates.per_side(185.0, "lb") == [45.0, 25.0] and Plates.per_side(225.0, "lb") == [45.0, 45.0] and Plates.per_side(140.0, "lb") == [45.0, 2.5], "plates each side in pounds", [Plates.per_side(185.0, "lb"), Plates.per_side(140.0, "lb")])
	ok(Plates.per_side(100.0, "kg") == [25.0, 15.0] and Plates.per_side(62.5, "kg") == [20.0, 1.25], "and in kilograms", Plates.per_side(62.5, "kg"))
	ok(Plates.text(185.0, "lb") == "185 = 45 + 25 each side" and Plates.text(45.0, "lb") == "45 = the bar" and Plates.text(0.0, "lb") == "", "in words", Plates.text(185.0, "lb"))
	ok(Plates.warmups(225.0, "lb") == [[45.0, 10], [90.0, 5], [135.0, 3], [180.0, 2]], "warm-ups: the bar, then 40, 60, 80 percent", Plates.warmups(225.0, "lb"))
	ok(Plates.warmups(80.0, "lb").is_empty() and Plates.warmup_text(100.0, "kg") == "20×10, 40×5, 60×3, 80×2", "none for a light lift; kilograms", Plates.warmup_text(100.0, "kg"))
	ok(Plates.is_barbell("Squat - Barbell") and Plates.is_barbell("Bench Press") and Plates.is_barbell("Squat - Front") and not Plates.is_barbell("Chest Fly - Gym cable")
		and not Plates.is_barbell("Bench Press - Dumbbell") and not Plates.is_barbell("Bench Press - Smith machine"), "which lifts use a barbell")
	print("PLATES: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
