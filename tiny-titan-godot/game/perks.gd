class_name Perks
extends RefCounted
## Bonuses from equipped gear and the active pet (port of perks.ts).


static func _add_perk(t: Dictionary, p) -> void:
	if not (p is Dictionary):
		return
	var xp = p.get("xp")
	if xp is Dictionary:
		for d in TT.DISCIPLINES:
			t.xp[d] += TTUtil.get_or(xp, d, 0) + TTUtil.get_or(xp, "all", 0)
	var luck = p.get("luck")
	if TTUtil.truthy(luck):
		t.luck += luck


## Bonuses from the gear and pet currently equipped (ignores anything not owned).
## `loadout` is {slot: item id or null}; `active_pet` is a pet id or null.
## Returns {"xp": {lift, climb, run, ride}, "luck": float}, as fractions
## (0.08 = +8%). The UI snapshots `xp[discipline]` / `luck` into a new
## session's `bonusPct` / `luckPct`.
static func compute_perks(state: Dictionary, loadout: Dictionary, active_pet) -> Dictionary:
	var t = {"xp": {"lift": 0.0, "climb": 0.0, "run": 0.0, "ride": 0.0}, "luck": 0.0}
	for slot in loadout:
		var id = loadout[slot]
		if not TTUtil.truthy(id) or not state.items.has(id):
			continue
		var item = Items.by_id(id)
		if item != null:
			_add_perk(t, item.get("perk"))
	if TTUtil.truthy(active_pet) and state.pets.has(active_pet):
		var pet = Pets.by_id(active_pet)
		if pet != null:
			_add_perk(t, pet.get("perk"))
	return t


## Drop everything from the loadout that isn't actually owned any more.
## Returns {"loadout": {slot: item id}, "activePet": pet id or null}.
static func sanitize_loadout(state: Dictionary, loadout: Dictionary, active_pet) -> Dictionary:
	var out = {}
	for slot in loadout:
		var id = loadout[slot]
		if not TTUtil.truthy(id) or not state.items.has(id):
			continue
		var item = Items.by_id(id)
		if item != null and item.slot == slot:
			out[slot] = id
	var pet = active_pet if (TTUtil.truthy(active_pet) and state.pets.has(active_pet)) else null
	return {"loadout": out, "activePet": pet}
