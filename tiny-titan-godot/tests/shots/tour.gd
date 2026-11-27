extends RefCounted
## A tour of the hard fights (run with the "year" data): the elite and the boss
## of every region, each played on AUTO at double speed for a while with every
## effect on and a hero who cannot fall, so the rarer things a fight can do
## (a call for help, a boss changing, a drain, a countdown, a wind-up, a shield)
## are all drawn and sounded at least once. It asserts little: the log must
## show no script error and every picture passes the layout checks. It prints
## which kinds of event each fight showed.

const SECS = 16.0

var main: Node
var tree: SceneTree
var fails = 0
var seen_all = {}


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _open(stage_id: String, seed: int):
	var rpg = App.rpg()
	var st = RpgWorld.stage(stage_id)
	var setup = RpgWorld.setup({"kind": "stage", "id": stage_id}, rpg, RpgUi.hero(), RpgUi.pet(), seed, App.today)
	return BattleView.open(setup, {"title": str(st.name), "scene": str(RpgWorld.region_of(stage_id)), "hero": RpgUi.hero_look(), "speed": 2})


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.set_rpg(RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true))
	App.go("realm")
	await ShotHelper.wait(tree, 0.6)
	LootPop.close_all()
	var stages = []
	for r in range(1, RpgDefs.REGIONS.size() + 1):
		stages.append("r%ds5" % r)
		stages.append("r%ds10" % r)
	for sid in stages:
		if not (RpgWorld.stage(sid) is Dictionary):
			continue
		var bv = _open(sid, 11)
		await ShotHelper.wait(tree, 1.0)
		# He cannot fall and hits like himself: the foes get their turns, which is what is to be seen.
		bv.B.hero["hp_max"] = 999999
		bv.B.hero["hp"] = 999999
		bv._sync()
		bv._set_auto(true)
		bv._auto_soon()
		var kinds = {}
		var t0 = Time.get_ticks_msec()
		var snapped = false
		var last_n = 0
		while is_instance_valid(bv) and bv.result() == null and Time.get_ticks_msec() - t0 < int(SECS * 1000.0):
			await ShotHelper.wait(tree, 0.1)
			if bv._events.size() != last_n or true:
				for e in bv._events:
					if e is Dictionary:
						var t = str(e.get("t", ""))
						if t == "act" and str(e.get("who", "")) != "hero" and str(e.get("who", "")) != "pet":
							t = "foe:" + str(e.get("kind", ""))
						kinds[t] = true
						seen_all[t] = true
			if not snapped and Time.get_ticks_msec() - t0 > int(SECS * 500.0):
				snapped = true
				await ShotHelper.snap(tree, "tour_%s" % sid)
		var names = kinds.keys()
		names.sort()
		print("TOUR %s (%s): %s" % [sid, "over" if (is_instance_valid(bv) and RpgBattle.over(bv.B)) else "still going", ", ".join(names)])
		check(is_instance_valid(bv), "%s: the fight's screen stands" % sid)
		if is_instance_valid(bv):
			bv._set_auto(false)
			bv.close()
		await ShotHelper.wait(tree, 0.5)
	BattleView.auto_kept = false
	BattleView.speed_kept = 1
	var all = seen_all.keys()
	all.sort()
	print("TOUR every kind of event shown: %s" % ", ".join(all))
	print("TOUR %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
