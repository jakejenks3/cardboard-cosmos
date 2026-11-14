class_name Art
extends RefCounted
## The static facade the UI uses to get pixel art as textures.
##
## Every `*_texture()` function returns a cached ImageTexture (draw it with
## nearest-neighbour filtering: PixelRect / HeroView / BossView / PetView do
## that). The `*_pix()` functions return the raw Pix buffer, uncached.
##
## Inputs: `state` is a PlayerState Dictionary (shape of initialState() in
## state.ts), `profile` is {name, skin, hairStyle, hairColor, createdAt},
## `loadout` is {slot: item id or null}.
##
## Animation (see HeroView): `frame` is a counter that goes up by one every
## FRAME_MS. Everything that moves is derived from it exactly as on the web:
## the idle bob, cape wave, sandal wings, medal sparkle, auras, string lights,
## treadmill and pets; the hero blinks on every BLINK_EVERY-th frame.

## Size of the hero buffer / of the home-gym scene, in art pixels.
const HERO_W = HeroBody.HERO_W # 48
const HERO_H = HeroBody.HERO_H # 60
const SCENE_W = GymScene.SCENE_W # 96
const SCENE_H = GymScene.SCENE_H # 72

## One animation frame lasts this long (HeroScene.tsx FRAME_MS).
const FRAME_MS = 170
## A tap makes the hero flex for this long.
const FLEX_MS = 1600
## The hero blinks for one frame whenever frame % BLINK_EVERY == 0 (frame > 0).
const BLINK_EVERY = 18
## Where the active pet stands in the scene (left edge; feet on the floor).
const PET_X = 70

# The mannequin of the web's avatar preview page ("items by slot"): a Lv25
# balanced body in the starter kit. item_texture() draws every item on it.
const PREVIEW_PROFILE = {"name": "Preview", "skin": 1, "hairStyle": 0, "hairColor": 1, "createdAt": 0}
const STARTER_LOADOUT = {"body": "tee_grey", "legs": "shorts_navy", "feet": "trainers_worn"}
const MANNEQUIN_LEVELS = {"hero": 25, "lift": 15, "climb": 15, "run": 15, "ride": 15}

## CSS brightness of the greyed-out looks (`grayscale(1) brightness(x)`).
const LOCKED_BRIGHTNESS = 0.4
const BOSS_DIM_BRIGHTNESS = 0.55

const _TEX_CACHE_MAX = 384
const _SCENE_CACHE_MAX = 160

static var _tex_cache = {} # signature -> ImageTexture (everything but scenes)
static var _scene_cache = {} # signature -> ImageTexture (animated scenes churn)


# --- textures (cached) --------------------------------------------------------

## The hero alone on a transparent background (HERO_W x HERO_H), wearing the
## loadout items the state owns. `pose` is "idle" or "flex". `happy` forces the
## smile (a flexing hero always smiles).
static func hero_texture(state: Dictionary, profile: Dictionary, loadout: Dictionary, pose: String = "idle", frame: int = 0, happy: bool = false) -> ImageTexture:
	var key: String = "hero|" + _hero_sig(state, profile, loadout, pose, frame, happy)
	var tex = _tex_cache.get(key)
	if tex == null:
		tex = hero_pix(state, profile, loadout, pose, frame, happy).to_texture()
		_cache_put(_tex_cache, key, tex, _TEX_CACHE_MAX)
	return tex


## The home gym (SCENE_W x SCENE_H) with the hero and the active pet
## (`active_pet` is a pet id or null; it is only drawn when the state owns it).
## `hour` is the local hour (0-23) shown in the window, -1 = now.
static func scene_texture(state: Dictionary, profile: Dictionary, loadout: Dictionary, active_pet, pose: String = "idle", frame: int = 0, happy: bool = false, hour: int = -1) -> ImageTexture:
	if hour < 0:
		hour = current_hour()
	var key: String = "scene|" + _hero_sig(state, profile, loadout, pose, frame, happy) + "|" + _scene_sig(state, active_pet, frame, hour)
	var tex = _scene_cache.get(key)
	if tex == null:
		tex = scene_pix(state, profile, loadout, active_pet, pose, frame, happy, hour).to_texture()
		_cache_put(_scene_cache, key, tex, _SCENE_CACHE_MAX)
	return tex


## One frame of a pet in a tight outlined buffer (the web PetPortrait shows
## frame 0). The size depends on the pet: see pet_size(). `locked` gives the
## greyed-out look of a pet that is not unlocked yet. An unknown id gives a
## 1x1 transparent texture.
static func pet_texture(pet_id: String, frame: int = 0, locked: bool = false) -> ImageTexture:
	var frames: int = pet_frame_count(pet_id)
	var key: String = "pet|" + pet_id + "|" + str(frame % frames) + "|" + str(locked)
	var tex = _tex_cache.get(key)
	if tex == null:
		var p: Pix = pet_pix(pet_id, frame)
		if locked:
			p = p.dimmed(LOCKED_BRIGHTNESS)
		tex = p.to_texture()
		_cache_put(_tex_cache, key, tex, _TEX_CACHE_MAX)
	return tex


## A boss in a tight outlined buffer (16 wide, 14-17 tall depending on the
## boss). `silhouette` draws an unknown boss as a dark shape, `dim` gives the
## greyed-out look of a defeated boss.
static func boss_texture(boss_id: String, silhouette: bool = false, dim: bool = false) -> ImageTexture:
	var key: String = "boss|" + boss_id + "|" + str(silhouette) + "|" + str(dim)
	var tex = _tex_cache.get(key)
	if tex == null:
		var p: Pix = boss_pix(boss_id, silhouette)
		if dim:
			p = p.dimmed(BOSS_DIM_BRIGHTNESS)
		tex = p.to_texture()
		_cache_put(_tex_cache, key, tex, _TEX_CACHE_MAX)
	return tex


## Thumbnail of an item (HERO_W x HERO_H): the item worn by the preview
## mannequin. `locked` gives the greyed-out look of an item not owned yet.
## To show the item on the player's own hero (what the web Armory grid does)
## use item_preview_texture().
static func item_texture(item_id: String, locked: bool = false) -> ImageTexture:
	var key: String = "item|" + item_id + "|" + str(locked)
	var tex = _tex_cache.get(key)
	if tex == null:
		var p: Pix = item_pix(item_id)
		if locked:
			p = p.dimmed(LOCKED_BRIGHTNESS)
		tex = p.to_texture()
		_cache_put(_tex_cache, key, tex, _TEX_CACHE_MAX)
	return tex


## The web Armory tile: the player's own hero (static, frame 0) wearing their
## loadout with `item_id` put in its slot. As on the web, an item the state
## does not own is not drawn (its slot shows empty); pass `locked` to grey the
## tile out.
static func item_preview_texture(item_id: String, state: Dictionary, profile: Dictionary, loadout: Dictionary, locked: bool = false) -> ImageTexture:
	var worn: Dictionary = loadout.duplicate()
	var item = Items.by_id(item_id)
	if item != null:
		worn[item.slot] = item_id
	if not locked:
		return hero_texture(state, profile, worn, "idle", 0, false)
	var key: String = "locked|" + _hero_sig(state, profile, worn, "idle", 0, false)
	var tex = _tex_cache.get(key)
	if tex == null:
		tex = hero_pix(state, profile, worn, "idle", 0, false).dimmed(LOCKED_BRIGHTNESS).to_texture()
		_cache_put(_tex_cache, key, tex, _TEX_CACHE_MAX)
	return tex


## Drop every cached texture (they are rebuilt on demand).
static func clear_cache() -> void:
	_tex_cache.clear()
	_scene_cache.clear()


# --- buffers (uncached) ---------------------------------------------------------

## TS `visualsFromLoadout`: {slot: item visual} for the loadout entries that
## are set, owned by the state and known to the item catalog.
static func visuals_from_loadout(loadout: Dictionary, state: Dictionary) -> Dictionary:
	var v: Dictionary = {}
	for slot in loadout:
		var id = loadout[slot]
		if not _is_worn(id, state):
			continue
		var item = Items.by_id(id)
		if item != null:
			v[slot] = item.visual
	return v


## The BodyInput Dictionary HeroBody.draw_hero() takes, built the way
## HeroScene.tsx does (blink and smile are derived from frame and pose).
static func body_input(state: Dictionary, profile: Dictionary, pose: String = "idle", frame: int = 0, happy: bool = false) -> Dictionary:
	var lv: Dictionary = state.levels
	return {
		"heroLevel": int(lv.hero.level),
		"liftLevel": int(lv.lift.level),
		"climbLevel": int(lv.climb.level),
		"runLevel": int(lv.run.level),
		"rideLevel": int(lv.ride.level),
		"skin": int(profile.skin),
		"hairStyle": int(profile.hairStyle),
		"hairColor": int(profile.hairColor),
		"pose": pose,
		"frame": frame,
		# The web blinks when its frame counter hits a multiple of 18; the
		# very first render (frame 0) has the eyes open.
		"blink": frame > 0 and frame % BLINK_EVERY == 0,
		"happy": happy or pose == "flex",
	}


static func hero_pix(state: Dictionary, profile: Dictionary, loadout: Dictionary, pose: String = "idle", frame: int = 0, happy: bool = false) -> Pix:
	var hero: Pix = Pix.new(HERO_W, HERO_H)
	HeroBody.draw_hero(hero, body_input(state, profile, pose, frame, happy), {"visuals": visuals_from_loadout(loadout, state)})
	return hero


static func scene_pix(state: Dictionary, profile: Dictionary, loadout: Dictionary, active_pet, pose: String = "idle", frame: int = 0, happy: bool = false, hour: int = -1) -> Pix:
	if hour < 0:
		hour = current_hour()
	var hero: Pix = hero_pix(state, profile, loadout, pose, frame, happy)
	var lv: Dictionary = state.levels
	var buf: Pix = Pix.new(SCENE_W, SCENE_H)
	GymScene.draw_scene(buf, {
		"stage": int(state.stage),
		"liftLevel": int(lv.lift.level),
		"climbLevel": int(lv.climb.level),
		"runLevel": int(lv.run.level),
		"rideLevel": int(lv.ride.level),
		"achievements": state.achievements.size(),
		"sessions": int(state.totals.sessions),
		"hour": hour,
		"frame": frame,
	})
	buf.blit(hero, GymScene.HERO_X, GymScene.HERO_Y)
	if _pet_shown(active_pet, state):
		PetSprites.draw_pet(buf, active_pet, PET_X, GymScene.FLOOR_Y, frame)
	return buf


static func pet_pix(pet_id: String, frame: int = 0) -> Pix:
	var buf = PetSprites.pet_buffer(pet_id, frame)
	if buf == null:
		return Pix.new(1, 1)
	return buf


static func boss_pix(boss_id: String, silhouette: bool = false) -> Pix:
	return BossSprites.boss_buffer(boss_id, {"silhouette": silhouette})


static func item_pix(item_id: String) -> Pix:
	var loadout: Dictionary = STARTER_LOADOUT.duplicate()
	var item = Items.by_id(item_id)
	if item != null:
		loadout[item.slot] = item_id
	var owned: Dictionary = {}
	for slot in loadout:
		owned[loadout[slot]] = {"at": "", "how": "unlock"}
	var levels: Dictionary = {}
	for track in MANNEQUIN_LEVELS:
		levels[track] = {"level": MANNEQUIN_LEVELS[track]}
	return hero_pix({"levels": levels, "items": owned}, PREVIEW_PROFILE, loadout, "idle", 0, false)


## A copy of `state` whose levels are replaced by `levels`
## ({hero, lift, climb, run, ride}, missing tracks keep their level): the web's
## `levelsOverride` prop, e.g. to draw the hero as they were at level 1. Only
## the levels change (the gym's `stage` stays the state's).
static func state_with_levels(state: Dictionary, levels: Dictionary) -> Dictionary:
	var s: Dictionary = state.duplicate()
	var lv: Dictionary = {}
	for track in state.levels:
		var info: Dictionary = state.levels[track].duplicate()
		if levels.has(track):
			info["level"] = int(levels[track])
		lv[track] = info
	s["levels"] = lv
	return s


# --- facts the views need -------------------------------------------------------

## Local hour of day, 0-23 (what the gym window shows).
static func current_hour() -> int:
	return int(Time.get_time_dict_from_system().hour)


## Number of animation frames of a pet sprite (1 for an unknown id).
static func pet_frame_count(pet_id: String) -> int:
	var sp = PetSprites.PET_SPRITES.get(pet_id)
	if sp == null:
		return 1
	return sp.frames.size()


## Largest pet_texture() size over all frames of a pet (a few frames are one
## column wider than the others).
static func pet_size(pet_id: String) -> Vector2i:
	var best: Vector2i = Vector2i(1, 1)
	for f in range(pet_frame_count(pet_id)):
		var sz: Dictionary = PetSprites.sprite_size(pet_id, f)
		best.x = maxi(best.x, sz.w + 2)
		best.y = maxi(best.y, sz.h + 2)
	return best


## Size of boss_texture() for a boss.
static func boss_size(boss_id: String) -> Vector2i:
	var rows: Array = BossSprites.BASE[BossSprites.boss_look(boss_id).sprite]
	var bw: int = 0
	for r in rows:
		bw = maxi(bw, r.length())
	return Vector2i(bw + 2, rows.size() + 2)


## True for bosses that float (they bob faster in BossView).
static func boss_hovers(boss_id: String) -> bool:
	return BossSprites.boss_look(boss_id).get("hover", false)


# --- private --------------------------------------------------------------------

static func _is_worn(id, state: Dictionary) -> bool:
	if id == null or not (id is String) or id == "":
		return false
	return state.items.has(id)


static func _pet_shown(active_pet, state: Dictionary) -> bool:
	if active_pet == null or not (active_pet is String) or active_pet == "":
		return false
	return state.pets.has(active_pet)


## Cache key of a hero render: everything draw_hero() reads.
static func _hero_sig(state: Dictionary, profile: Dictionary, loadout: Dictionary, pose: String, frame: int, happy: bool) -> String:
	var lv: Dictionary = state.levels
	var slots: Array = loadout.keys()
	slots.sort()
	var gear: String = ""
	var has_aura: bool = false
	for slot in slots:
		var id = loadout[slot]
		if not _is_worn(id, state) or Items.by_id(id) == null:
			continue
		gear += str(slot) + "=" + id + ","
		if slot == "aura":
			has_aura = true
	# Without an aura the hero only depends on frame % 8 (bob and cape use
	# frame % 4, wings frame % 2, the medal sparkle frame % 8); auras drift
	# with the raw frame number.
	var frame_key: int = frame if has_aura else frame % 8
	var blink: bool = frame > 0 and frame % BLINK_EVERY == 0
	return "%d.%d.%d.%d.%d|%d.%d.%d|%s|%d|%s|%s|%s" % [
		int(lv.hero.level), int(lv.lift.level), int(lv.climb.level), int(lv.run.level), int(lv.ride.level),
		int(profile.skin), int(profile.hairStyle), int(profile.hairColor),
		pose, frame_key, str(blink), str(happy or pose == "flex"), gear,
	]


## Cache key of everything the scene adds around the hero.
static func _scene_sig(state: Dictionary, active_pet, frame: int, hour: int) -> String:
	var stage: int = int(state.stage)
	# String lights (stage 3+) repeat every 10 frames, the treadmill (running
	# level 5+) every 54, a pet every 4.
	var lights: int = frame % 10 if stage >= 3 else 0
	var treadmill: int = frame % 54 if int(state.levels.run.level) >= 5 else 0
	var pet: String = ""
	if _pet_shown(active_pet, state):
		pet = active_pet + ":" + str(frame % 4)
	var sky: Dictionary = GymScene.sky_colors(hour)
	return "%d|%d|%s|%s|%d|%d|%s" % [stage, state.achievements.size(), str(int(state.totals.sessions) >= 5), sky.sky, lights, treadmill, pet]


static func _cache_put(cache: Dictionary, key: String, tex: ImageTexture, cap: int) -> void:
	if cache.size() >= cap:
		# Dictionaries keep insertion order: drop the oldest quarter.
		var old: Array = cache.keys()
		for i in range(maxi(1, cap >> 2)):
			cache.erase(old[i])
	cache[key] = tex
