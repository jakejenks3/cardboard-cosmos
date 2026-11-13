class_name Pets
extends RefCounted
## The companion catalog (port of pets.ts).
##
## Pet: {id, name, species, rarity, flavor, perk, hint, discipline?,
##       check: Callable(state) -> bool,
##       progress: Callable(state) -> {cur, target, unit}}
## `perk` has the same shape as an item perk (see Items). `discipline` is
## optional: read it with `pet.get("discipline")`.

static var _all = null
static var _by_id = null


static func _p(id: String, pet_name: String, species: String, rarity: String, flavor: String, perk: Dictionary, hint: String, getter: Callable, target, unit: String = "count", discipline = null) -> Dictionary:
	var pet = {"id": id, "name": pet_name, "species": species, "rarity": rarity, "flavor": flavor, "perk": perk, "hint": hint}
	if discipline != null:
		pet["discipline"] = discipline
	pet.merge(Goals.at_least(getter, target, unit))
	return pet


## Every pet, in catalog order (do not mutate).
static func all() -> Array:
	if _all == null:
		_all = _build()
	return _all


## Pet by id, or null.
static func by_id(id):
	if _by_id == null:
		var map = {}
		for pet in all():
			map[pet.id] = pet
		_by_id = map
	return _by_id.get(id)


static func _build() -> Array:
	return [
			_p("slime", "Gloop", "Gym Slime", "common", "Found under the squat rack. Very supportive.", {"xp": {"all": 0.01}}, "Log your first session", func(s): return s.totals.sessions, 1),
			_p("bulldog", "Rep", "Bulldog", "common", "Counts your reps. Loudly.", {"xp": {"lift": 0.03}}, "Log a lifting session", func(s): return s.totals.byDiscipline.lift, 1, "count", "lift"),
			_p("gecko", "Crimpy", "Gecko", "common", "Sticks to anything. Shows off about it.", {"xp": {"climb": 0.03}}, "Log a climbing session", func(s): return s.totals.byDiscipline.climb, 1, "count", "climb"),
			_p("pigeon", "Coach", "Pigeon", "common", "Keeps pace. Judges your form.", {"xp": {"run": 0.03}}, "Log a run", func(s): return s.totals.byDiscipline.run, 1, "count", "run"),
			_p("hamster", "Pedals", "Hamster", "common", "Born for the wheel.", {"xp": {"ride": 0.03}}, "Log a ride", func(s): return s.totals.byDiscipline.ride, 1, "count", "ride"),
			_p("sprout", "Sprout", "Potted Plant", "uncommon", "Grows a leaf every time you check in.", {"xp": {"all": 0.02}}, "Check in (weight or photos) 4 weeks in a row", func(s): return s.body.bestStreak, 4, "weeks"),
			_p("ox", "Tonnage", "Ox", "rare", "Strong as, well, you know.", {"xp": {"lift": 0.05}}, "Reach lifting level 10", func(s): return s.levels.lift.level, 10, "level", "lift"),
			_p("goat", "Cliff", "Mountain Goat", "rare", "Has never fallen. Ever. Allegedly.", {"xp": {"climb": 0.05}}, "Reach climbing level 10", func(s): return s.levels.climb.level, 10, "level", "climb"),
			_p("greyhound", "Zoom", "Greyhound", "rare", "Fast. Elegant. Naps 20 hours a day.", {"xp": {"run": 0.05}}, "Reach running level 10", func(s): return s.levels.run.level, 10, "level", "run"),
			_p("falcon", "Draft", "Falcon", "rare", "Rides your slipstream. Takes the KOM.", {"xp": {"ride": 0.05}}, "Reach cycling level 10", func(s): return s.levels.ride.level, 10, "level", "ride"),
			_p("golemling", "Pebble", "Golemling", "rare", "A chip off the old Iron Golem. Followed you home.", {"xp": {"all": 0.03}}, "Clear the Iron Foothills (defeat 8 bosses)", func(s): return s.campaign.defeated.size(), 8),
			_p("tortoise", "Steady", "Tortoise", "rare", "Slow is smooth. Smooth is eight weeks straight.", {"xp": {"all": 0.04}}, "Keep an 8-week streak", func(s): return s.streak.best, 8, "weeks"),
			_p("cat", "Deload", "Cat", "rare", "Knocks loot off the shelf. Into your bag.", {"luck": 0.08}, "Log 50 sessions", func(s): return s.totals.sessions, 50),
			_p("phoenix", "Ember", "Phoenix", "epic", "Half a year of fire, reborn weekly.", {"xp": {"all": 0.06}}, "Keep a 26-week streak", func(s): return s.streak.best, 26, "weeks"),
			_p("dragon", "Titan Jr.", "Baby Dragon", "legendary", "Tiny now. Give it a few hundred sessions.", {"xp": {"all": 0.08}}, "Reach hero level 30", func(s): return s.levels.hero.level, 30, "level"),
	]
