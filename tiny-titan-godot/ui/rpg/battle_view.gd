class_name BattleView
extends Control
## The battle screen of the Realm (RPG_PLAN.md 10.2): a full-column overlay on
## Kit.overlay_root, opaque, nothing scrolls, no key moves between turns.
##
##   var v = BattleView.open(setup, opts)       # setup: what RpgBattle.start takes
##   v.finished.connect(func(B, summary): ...)  # the player left the result, or fled; v.choice says how
##   v.closed.connect(...)                      # it is gone (it frees itself)
##
## opts: "title" (the stage's name) · "scene" (a RealmScenes id) · "hero": {"state", "profile", "loadout", "pet"}
##   (what HeroView draws; the view never reads the log itself; left out: no hero is drawn) · "tutorial": bool (a
##   hint for each step, in a band at the foot of the arena) · "store": Callable(B), called after every hero action
##   (the caller keeps the draft) · "speed": 1 or 2 · "resume": a stored B (the battle goes on from it; `setup`
##   is not looked at) · "result": Callable(B, summary) -> the `info` BattleResult shows (the caller pays the
##   rewards there, once; left out: a plain result with what was learned) · "next": bool (for that plain result)
##   · "instant": bool (no waits between events).
##
## `choice` when `finished` is emitted: "next" | "again" | "back" (the result's keys) or "flee".
##
## THE SLOTS, top to bottom (y and height are worked out in _layout from the view's own size; keys are placed
## from the BOTTOM edge, so they never move): top bar (flee, title, wave, turn, speed) · the arena (the backdrop,
## the hero and companion at the left on its ground line, one to three foes each under its plate) · the timeline
## (the next 7) · the hero's plate · ONE line saying what just happened · the moves, two across · Strike, Guard,
## Item, Companion, Ultimate.
##
## INPUT: a tap on a foe picks the target (kept between turns, marked under the foe and on its plate); a tap on
## a move does it at once on that target; a plate opens that unit's sheet. A key that cannot be used is dim and
## says why in the line. While a playback runs every tap only skips it (skip()).
##
## PLAYBACK: RpgBattle.act returns events; _show() draws one and says how long to wait (x2 halves it). Every
## wait is a Tween bound to this node and every step checks `_gen` (as in ResultsOverlay), so a skip or a close
## never leaves a coroutine running on a freed node. What a playback draws is only ever a preview of the end:
## when it ends (or is skipped) _sync() sets every widget from B itself.
##
## Metas for tests and walkthroughs: bv_move (move id), bv_foe (unit id, the tap area of a foe), bv_plate (unit
## id or "hero"), bv_key (strike | guard | item | pet | ult | flee | speed), bv_line, bv_hp_hero, bv_energy,
## bv_gauge, bv_hp / bv_guard (on a foe's plate), bv_wave, bv_turn, bv_timeline, bv_hint, bv_item (a belt key in
## the item sheet), bv_sheet, bv_result (the result).

signal finished(B, summary)
signal closed
signal speed_changed(speed)

const ARENA_H = 240.0
## The arena grows by up to this much when the column is taller than the screen needs.
const ARENA_MORE = 80.0
const GAP = 4.0
const PAD = 8.0
const KEY_GAP = 6.0
const BOTTOM = 6.0
## With more room than that: a breath of this much may stay between the line and the keys, then the move keys
## grow (to MOVE_H_MAX each), the action keys (to ACT_H_MAX), the line gets a second line (LINE_H_TWO), and
## all the rest is the arena's again: sky above the backdrop, never a hole between the line and the keys.
const BREATH = 12.0
const MOVE_H_MAX = 72.0
const ACT_H_MAX = 56.0
const LINE_H_TWO = 42.0
const HERO_SCALE = 2
const HERO_X = -6.0
const PET_X = 94.0
const PET_PX = 40.0
## Where the foes' part of the arena begins.
const FOE_X0 = 124.0
const POSES = ["strike", "kick", "guard", "cast", "hurt", "pull", "flex"]
## How far the hero steps in to strike (never under a foe's plate).
const STEP_IN = 26.0
## Under this share of his HP the arena's edge beats red.
const LOW_HP = 0.3
## Hints given ONCE EVER, the first time a thing happens in a fight (the first fight teaches the basics by
## its own band; the rest of what a fight can do is met later, one thing at a time). The caller says which
## were given before (opts "hints": {id: true}) and is told when one is (opts "on_hint": Callable(id)).
const HINTS = {
	"charge": "It is winding up a big hit. Guard on your next turn, or break its guard to stop it.",
	"count": "A countdown: when it runs out the blow lands. Finish the foe first, or guard in time.",
	"danger": "An intent that beats red is a quarter of your HP or more. Guard cuts it by half.",
	"break": "Its guard is broken: it loses its next action and takes more. Hit hard now.",
	"resist": "It resists that school: the hit does less. Try a move of another school.",
	"summon": "It called for help. The new ones fall fast: clear them, or go for the caller.",
	"shield": "A shield soaks damage before HP does. Chip through it, or wait it out.",
	"dot": "Burn and Bleed take HP every turn until they wear off.",
	"stun": "Stunned: a turn is lost. Tap a plate to read what a fighter has on it.",
	"phase": "A boss changes when it is hurt: new moves, sometimes new weaknesses.",
	"gauge": "Your gauge is full: the Ultimate key is lit. It costs no energy.",
	"pet": "Your companion's command is charged: its key is lit, and using it costs no turn.",
}
## Seconds a hint stays up.
const HINT_SECS = 6.0
## The hour of a stage, by its place on its region's road: the light the picture is seen in (it is multiplied
## into the backdrop and its sky, never into the fighters). Ten fights in one region do not all look the same.
const HOURS = {"day": Color(1, 1, 1), "dusk": Color(1.0, 0.8, 0.66), "night": Color(0.5, 0.56, 0.86), "boss": Color(0.78, 0.6, 0.66)}
## Statuses that stay drawn on a fighter while it has them: [the effect, seconds a round].
const STATUS_LOOPS = {"burn": ["flame", 1.0], "bleed": ["drops", 1.3], "stun": ["stars", 1.2], "shield": ["shield", 1.9], "regen": ["heal", 1.7],
	"charge": ["gather", 0.9], "charged": ["rays", 1.3]}
## The air of each scene (BattleFx.Ambient): [what drifts, its colour, how many].
const AMBIENT = {
	"rustyard": ["dust", "#e0c296", 14], "greenmile": ["leaves", "#c9e88f", 10], "chalk": ["snow", "#f4f1e6", 12],
	"stacks": ["dust", "#f0dfa8", 12], "ironworks": ["embers", "#ff9a3c", 16], "marsh": ["fireflies", "#d8f57a", 12],
	"stormspine": ["rain", "#bcd3f2", 26], "titans_rest": ["stars", "#ffe9a6", 12], "spire": ["stars", "#d6e4ff", 16],
	"hunt": ["leaves", "#f2b46a", 8], "rival": ["embers", "#ff7ad9", 12],
}
## Statuses whose name says what a unit IS ("is Exposed"); the others it HAS ("has Bleed").
const STATES = ["pumped", "weakened", "braced", "exposed", "hasted", "slowed", "stun", "steady", "marked"]

## The battle (RpgBattle's B). The view is the only one that acts on it while it is open.
var B: Dictionary = {}
## How the player left: "next" | "again" | "back" | "flee" ("" until then).
var choice: String = ""
var speed: int = 1
## The picked target (a foe's unit id).
var target: String = ""
## True: a playback shows every event at once, with no waits (a caller's "no animations" setting).
var instant: bool = false

var _opts: Dictionary = {}
var _resumed: bool = false
var _built: bool = false
var _gen: int = 0
var _busy: bool = false
var _closed: bool = false
var _result: BattleResult = null
var _sheet = null
var _learned: Array = []

var _top_h: float = 36.0
var _tl_h: float = 26.0
var _plate_h: float = 48.0
var _line_h: float = 26.0
var _move_h: float = 54.0
var _act_h: float = 48.0
## Those three as they are at the least (what they are in a 720-high column).
var _line_h0: float = 26.0
var _move_h0: float = 54.0
var _act_h0: float = 48.0
var _slots: int = 4

var _top: HBoxContainer
## AUTO: the hero plays by himself (RpgAi's heuristic) until the key is tapped again. It is kept from one
## fight to the next while the game is open (a stage run again, the next hunt).
static var auto_kept: bool = false
## The speed picked last (x1 or x2): the next fight of the visit opens at it.
static var speed_kept: int = 1
var auto: bool = false
var _auto_key: Button = null
var _music_key: Button = null
var _auto_tw: Tween = null
var _wave_label: Label
var _turn_label: Label
var _speed_key: Button
var _arena: BattleWidgets.Arena
var _arena_home: Vector2 = Vector2.ZERO
var _arena_size: Vector2 = Vector2.ZERO
var _foe_layer: Control
var _fx_layer: Control
var _hero_view: HeroView = null
var _hero_home: Vector2 = Vector2.ZERO
## The hero's figure inside its canvas, in art pixels: its top row, its lowest row, its middle column.
var _hero_top: int = 7
var _hero_low: int = 68
var _hero_mid: float = 32.0
## An unseen mark over the hero's head: his numbers rise from there, not from his face.
var _hero_mark: Control = null
var _pet_view: PetView = null
var _hint: Label = null
## The once-only hints: their band, the ones given (before this fight or in it), the band's fade.
var _tip: Label = null
var _hints_given: Dictionary = {}
var _tip_tw: Tween = null
var _tip_at: int = -100000
var _timeline: BattleWidgets.Timeline
var _hero_plate: BattleWidgets.HeroPlate
var _line_box: PanelContainer
var _line: Label
var _moves: Control
var _move_keys: Dictionary = {}
var _move_order: Array = []
var _acts: HBoxContainer
var _act: Dictionary = {}

## The foes on screen: unit id -> {"view", "hit", "plate", "slot", "foe", "unit" (what is shown of it), "known", "home"}.
var _foes: Dictionary = {}
var _hero_statuses: Array = []
var _guard_shown: bool = false
var _end_pose: String = ""
var _act_head: String = ""
var _act_dmg: int = 0
var _pose_tw: Tween = null
var _shake_tw: Tween = null
var _moving: Array = []
## The effects' own bookkeeping: the hero's body tween, the event being shown, what the action is, how many
## numbers have risen from each unit in it, whether the gauge was already full.
var _hero_tw: Tween = null
var _ev_i: int = 0
var _act_kind: String = ""
var _act_who: String = ""
var _act_first: bool = true
var _act_heavy: bool = false
var _hit_counts: Dictionary = {}
var _word_counts: Dictionary = {}
## Foes whose fall was already shown with the blow that felled them.
var _ko_done: Dictionary = {}
## What the line has said in this fight (the last LOG_MAX entries): a tap on the line opens them.
var _log: Array = []
const LOG_MAX = 60
## The looping effects of lasting statuses: "unit|status" -> the effect.
var _status_nodes: Dictionary = {}
var _gauge_full: bool = false
var _ambient: BattleFx.Ambient = null
var _sky_fx: BattleFx.SkyBand = null
var _vignette: BattleFx.Vignette = null
## Where in the arena's children something "behind the fighters" goes.
var _back_index: int = 0
var _shadow_at: Vector2 = Vector2(-9999, -9999)
## True while this battle holds the Realm's music.
var _held: bool = false
var _pulse: float = 0.0
var _still: bool = false
var _events: Array = []


## Put a battle up on Kit.overlay_root and start it (or go on with opts.resume).
static func open(setup: Dictionary, opts: Dictionary = {}) -> BattleView:
	var v = BattleView.new()
	v._opts = opts
	v.speed = 2 if int(opts.get("speed", speed_kept)) >= 2 else 1
	v.instant = bool(opts.get("instant", false))
	var stored = opts.get("resume")
	v._resumed = stored is Dictionary and not stored.is_empty()
	v.B = stored if v._resumed else RpgBattle.start(setup)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	if Kit.overlay_root != null:
		Kit.overlay_root.add_child(v)
	return v


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	target = str(B.get("target", ""))
	_build()
	_built = true
	resized.connect(_layout)
	_layout()
	_sync()
	if RpgBattle.over(B):
		_battle_over()
		return
	_say("Your move." if _resumed else "The fight begins.")
	BattleFx.speed = float(speed)
	_set_auto(auto_kept and not instant)
	if not instant:
		_held = true
		RpgSfx.hold(1, true)
		RpgSfx.tune("boss" if _has_boss() else "battle", RpgSfx.region_of_scene(str(_opts.get("scene", ""))))
	if not _resumed:
		var first = RpgBattle.opening(B)
		if not first.is_empty():
			var h = B.hero
			_hero_plate.set_hp(_hp_before(first, "hero", int(h.hp)), int(h.hp_max), false)
		if instant:
			if not first.is_empty():
				_play(first)
		else:
			_intro(first)
	if _hero_view != null:
		_warm()


func busy() -> bool:
	return _busy


## The line that says what just happened.
func line_text() -> String:
	return _line.text if _line != null else ""


## The result on screen, or null while the battle runs.
func result() -> BattleResult:
	return _result


# =============================================================================
# Building (once; after this only what the pieces SHOW changes)
# =============================================================================

func _build() -> void:
	if Kit.fingers:
		_top_h = 44.0
		_plate_h = 52.0
		_move_h = 58.0
		_act_h = 52.0
	_move_h0 = _move_h
	_act_h0 = _act_h
	_line_h0 = _line_h
	var base = ColorRect.new()
	base.color = Pal.BG
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_top()
	_build_arena()
	_timeline = BattleWidgets.Timeline.new()
	add_child(_timeline)
	var h = B.hero
	_hero_plate = BattleWidgets.HeroPlate.new(int(_plate_h), int(h.get("en_max", RpgDefs.EN_BASE)))
	_hero_plate.pressed.connect(_open_unit.bind("hero"))
	add_child(_hero_plate)
	_line_box = PanelContainer.new()
	_line_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# A tap on the line opens everything that was said in this fight (the log).
	_line_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_line_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_line_box.gui_input.connect(_on_line_input)
	_line_box.set_meta("bv_log_key", true)
	_line_box.add_theme_stylebox_override("panel", PixBox.well(8, 2))
	_line = Kit.clip("", 12, Pal.TEXT, true)
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# It fills its box. (Left to shrink, a label that wraps and clips asks for one pixel of height and showed
	# NOTHING: in every column tall enough for the two-line box, a phone's among them, the line was blank.)
	_line.size_flags_vertical = Control.SIZE_FILL
	_line.set_meta("bv_line", true)
	_line_box.add_child(_line)
	add_child(_line_box)
	_build_moves()
	_build_acts()


func _build_top() -> void:
	_top = Kit.hbox(6)
	add_child(_top)
	var flee = Kit.button("Flee", "ghost", _on_flee, "sm", "flee" if Icons.has_icon("flee") else "")
	flee.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flee.set_meta("bv_key", "flee")
	flee.set_meta("anchor_id", "bv_key:flee")
	if Kit.fingers:
		flee.custom_minimum_size.y = 40
	_top.add_child(flee)
	var title = Kit.clip(str(_opts.get("title", "")), 14, null, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top.add_child(title)
	_wave_label = Kit.label("", 11, Pal.MUTED, true)
	# (A fight of one wave does not say "WAVE 1/1": its place goes to the stage's name.)
	_wave_label.custom_minimum_size = Vector2(64 if B.get("waves", []).size() > 1 else 0, 0)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_label.clip_text = true
	_wave_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wave_label.set_meta("bv_wave", "")
	_top.add_child(_wave_label)
	_turn_label = Kit.label("", 11, Pal.MUTED, true)
	_turn_label.custom_minimum_size = Vector2(58, 0)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_turn_label.clip_text = true
	_turn_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_turn_label.set_meta("bv_turn", 0)
	_top.add_child(_turn_label)
	_auto_key = Kit.button("AUTO", "ghost", _on_auto, "sm")
	_auto_key.custom_minimum_size = Vector2(58, 40 if Kit.fingers else 0)
	_auto_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_auto_key.set_meta("bv_key", "auto")
	_auto_key.set_meta("anchor_id", "bv_key:auto")
	_top.add_child(_auto_key)
	_speed_key = Kit.button("x%d" % speed, "ghost", _on_speed, "sm")
	_speed_key.custom_minimum_size = Vector2(46, 40 if Kit.fingers else 0)
	_speed_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed_key.set_meta("bv_key", "speed")
	_speed_key.set_meta("anchor_id", "bv_key:speed")
	_top.add_child(_speed_key)
	# The music's own switch (the same one as on the Realm's banner).
	_music_key = Kit.icon_button("music" if RpgSfx.music_on() else "music_off", _on_music, "Music", 40 if Kit.fingers else 32)
	_music_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_music_key.set_meta("bv_key", "music")
	_music_key.set_meta("anchor_id", "bv_key:music")
	_top.add_child(_music_key)


func _build_arena() -> void:
	_arena = BattleWidgets.Arena.new(str(_opts.get("scene", "")))
	add_child(_arena)
	var light = HOURS.get(hour(), Color(1, 1, 1))
	_arena.self_modulate = light
	_arena.set_meta("bv_hour", hour())
	if not instant:
		_sky_fx = BattleFx.SkyBand.new()
		_sky_fx.sky = _arena._sky * light
		_arena.add_child(_sky_fx)
		_back_index = 1
	var amb = AMBIENT.get(RealmScenes.scene_of(str(_opts.get("scene", ""))))
	if amb != null and not instant:
		_ambient = BattleFx.Ambient.new()
		_ambient.mode = str(amb[0])
		_ambient.color = Color(str(amb[1]))
		_ambient.count = int(amb[2])
		_ambient.set_meta("bv_ambient", str(amb[0]))
		_arena.add_child(_ambient)
		_back_index += 1
	var hero = _opts.get("hero")
	if hero is Dictionary and hero.get("state") is Dictionary and hero.get("profile") is Dictionary:
		_hero_view = HeroView.new()
		_hero_view.min_scale = HERO_SCALE
		_hero_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hero_view.setup(hero.state, hero.profile, hero.get("loadout", {}), null, false)
		_arena.add_child(_hero_view)
		_measure_hero(hero)
		_hero_mark = Control.new()
		_hero_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arena.add_child(_hero_mark)
	if B.get("pet") is Dictionary and str(B.pet.get("pet", "")) != "":
		_pet_view = PetView.new()
		_pet_view.setup(str(B.pet.pet), PET_PX, true)
		_arena.add_child(_pet_view)
	_foe_layer = Control.new()
	_foe_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_foe_layer)
	_foe_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer = Control.new()
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_fx_layer)
	_vignette = BattleFx.Vignette.new()
	_vignette.color = Pal.DANGER
	_vignette.set_process(false)
	_arena.add_child(_vignette)
	if bool(_opts.get("tutorial", false)):
		_hint = Kit.clip("", 12, Pal.TEXT, true)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hint.add_theme_stylebox_override("normal", Kit.sbox(Pal.with_alpha(Pal.OUTLINE, 0.86), 3, Pal.ACCENT, 1, 6, 0))
		_hint.set_meta("bv_hint", true)
		_arena.add_child(_hint)
	elif not instant:
		# The band of the once-only hints (two lines of small words, at the foot of the arena; unseen until one is given).
		_tip = Kit.para("", 12, Pal.TEXT, true)
		_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tip.max_lines_visible = 2
		_tip.add_theme_stylebox_override("normal", Kit.sbox(Pal.with_alpha(Pal.OUTLINE, 0.9), 3, Pal.ACCENT, 1, 6, 2))
		_tip.set_meta("bv_tip", "")
		_tip.modulate.a = 0.0
		_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arena.add_child(_tip)
	var given = _opts.get("hints")
	if given is Dictionary:
		for k in given:
			_hints_given[str(k)] = true


## Where the hero's figure is on its canvas (the rows and columns that are not empty, standing idle).
func _measure_hero(hero: Dictionary) -> void:
	var tex = Art.hero_texture(hero.state, hero.profile, hero.get("loadout", {}), "idle", 0, false)
	var img = tex.get_image() if tex != null else null
	if img == null or img.get_width() <= 0:
		_hero_low = HeroBody.height() - 2
		return
	var top = -1
	var low = -1
	var left = img.get_width()
	var right = -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.05:
				if top < 0:
					top = y
				low = y
				left = mini(left, x)
				right = maxi(right, x)
	if low < 0:
		return
	_hero_top = top
	_hero_low = low
	_hero_mid = float(left + right + 1) / 2.0


func _build_moves() -> void:
	_moves = Control.new()
	_moves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_moves)
	var ids = B.hero.get("moves", [])
	_slots = maxi(RpgDefs.MOVE_SLOTS, ids.size())
	if _slots % 2 == 1:
		_slots += 1
	for i in range(_slots):
		var row = RpgBattle.move_row(B, str(ids[i])) if i < ids.size() else null
		if row == null:
			var empty = Panel.new()
			empty.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty.add_theme_stylebox_override("panel", PixBox.well(0, 0))
			empty.modulate.a = 0.5
			_moves.add_child(empty)
			_move_order.append(empty)
			continue
		var key = BattleWidgets.MoveKey.new(row, int(_move_h))
		key.pressed.connect(_on_move.bind(key.move_id))
		_moves.add_child(key)
		_move_keys[key.move_id] = key
		_move_order.append(key)


func _build_acts() -> void:
	_acts = Kit.hbox(int(KEY_GAP))
	add_child(_acts)
	var rows = [
		["strike", "Strike", "strike", Pal.PANEL2],
		["guard", "Guard", "guard", Pal.SECOND],
		["item", "Item", "belt", Pal.ACCENT2],
		["pet", "Companion", "paw", Pal.GOOD],
		["ult", "Ultimate", "gauge", RpgUi.color("grit")],
	]
	for r in rows:
		var key = BattleWidgets.ActKey.new(str(r[0]), str(r[1]), str(r[2]), r[3], int(_act_h))
		key.pressed.connect(_on_act.bind(str(r[0])))
		_acts.add_child(key)
		_act[str(r[0])] = key


# =============================================================================
# Layout (everything by hand: sizes are known, nothing depends on what is shown)
# =============================================================================

## The height the view needs with the arena at its least.
func needed_height() -> float:
	return _top_h + _tl_h + _plate_h + _line_h0 + _moves_height(_move_h0) + _act_h0 + GAP * 6.0 + BOTTOM + ARENA_H


func _move_rows() -> int:
	return int(ceil(float(_slots) / 2.0))


func _moves_height(key_h: float) -> float:
	return float(_move_rows()) * key_h + float(_move_rows() - 1) * KEY_GAP


func _rect(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


func _layout() -> void:
	if not _built:
		return
	var w = size.x
	var h = size.y
	var inner = w - 2.0 * PAD
	# The room over what the view needs, handed out in this order (see BREATH).
	var spare = maxf(0.0, floor(h - needed_height()))
	var arena_h = ARENA_H + minf(spare, ARENA_MORE)
	spare -= arena_h - ARENA_H
	spare -= minf(spare, BREATH)
	var rows = float(_move_rows())
	_move_h = _move_h0 + floor(minf(spare, rows * maxf(0.0, MOVE_H_MAX - _move_h0)) / rows)
	spare -= rows * (_move_h - _move_h0)
	_act_h = _act_h0 + minf(spare, maxf(0.0, ACT_H_MAX - _act_h0))
	spare -= _act_h - _act_h0
	_line_h = LINE_H_TWO if spare >= LINE_H_TWO - _line_h0 else _line_h0
	spare -= _line_h - _line_h0
	arena_h += spare
	var two = _line_h >= LINE_H_TWO
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if two else TextServer.AUTOWRAP_OFF
	_line.max_lines_visible = 2 if two else 1
	var y = 0.0
	_rect(_top, PAD, y, inner, _top_h)
	y += _top_h + GAP
	_kill(_shake_tw)
	_rect(_arena, 0, y, w, arena_h)
	_arena_home = _arena.position
	_arena_size = _arena.size
	y += arena_h + GAP
	_rect(_timeline, PAD, y, inner, _tl_h)
	y += _tl_h + GAP
	_rect(_hero_plate, PAD, y, inner, _plate_h)
	y += _plate_h + GAP
	_rect(_line_box, PAD, y, inner, _line_h)
	# The keys hang from the bottom edge.
	var by = h - BOTTOM - _act_h
	_rect(_acts, PAD, by, inner, _act_h)
	var mh = _moves_height(_move_h)
	by -= GAP + mh
	_rect(_moves, PAD, by, inner, mh)
	var kw = floor((inner - KEY_GAP) / 2.0)
	for i in range(_move_order.size()):
		_rect(_move_order[i], float(i % 2) * (kw + KEY_GAP), float(int(i / 2.0)) * (_move_h + KEY_GAP), kw, _move_h)
	if _hint != null:
		_rect(_hint, 6, arena_h - 22.0, w - 12.0, 20)
	if _tip != null:
		_rect(_tip, 6, arena_h - 40.0, w - 12.0, 38)
	# Banners stay over the fighters, however much sky is above them.
	_rect(_fx_layer, 0, arena_h - ARENA_H, w, ARENA_H)
	if _ambient != null:
		_rect(_ambient, 0, 0, w, arena_h)
	if _sky_fx != null:
		# The band of plain sky over the picture (none when the arena is as low as the picture).
		var band = arena_h - float(RealmScenes.H * _arena.k())
		_sky_fx.visible = band >= 24.0
		_rect(_sky_fx, 0, 0, w, maxf(0.0, band))
	_rect(_vignette, 0, 0, w, arena_h)
	_place_hero()
	_place_foes()


func _place_hero() -> void:
	var ground = _arena.ground()
	if _hero_view != null:
		_kill_moving()
		var k = float(HERO_SCALE)
		_hero_view.size = _hero_view.custom_minimum_size
		# As the foes stand (FoeView): the figure's lowest row, its outline, lies ON the ground line.
		_hero_home = Vector2(HERO_X, floor(ground - float(_hero_low) * k))
		_hero_view.position = _hero_home
		var cx = HERO_X + _hero_mid * k
		_hero_shadow()
		_rect(_hero_mark, cx - 20.0, _hero_home.y + float(_hero_top) * k - 8.0, 40, 8)
	if _pet_view != null:
		_pet_view.size = Vector2(PET_PX, PET_PX)
		# The companion's own outline row on the ground line too (it is drawn in the middle of its square).
		var art = PetSprites.sprite_size(str(B.pet.get("pet", "")), 0)
		var pk = float(_pet_view.art_scale())
		var tall = (float(art.get("h", 0)) + 2.0) * pk
		var feet = floor((PET_PX - tall) / 2.0) + tall - pk
		_pet_view.position = Vector2(PET_X if _hero_view != null else 30.0, floor(ground - feet))


## The hero's shadow lies under him wherever he is (he steps in to strike), smaller while he is in the air.
func _hero_shadow() -> void:
	if _hero_view == null:
		return
	_shadow_at = _hero_view.position
	var k = float(HERO_SCALE)
	var ground = _arena.ground()
	var cx = _hero_view.position.x + _hero_mid * k
	var up = clampf((_hero_home.y - _hero_view.position.y) / 24.0, 0.0, 1.0)
	var half = floor(14.0 - 5.0 * up)
	_arena.shadows = [Rect2(cx - half, ground - k, half * 2.0, k), Rect2(cx - half - 2.0, ground, half * 2.0 + 4.0, k)]
	_arena.queue_redraw()


## Every foe on its column (its place, 0 to 2), standing on the ground line,
## its plate over it and its tap area under the plate. One foe alone is drawn
## bigger and gets a wide plate.
func _place_foes() -> void:
	if _foes.is_empty():
		return
	var cols = 1
	for id in _foes:
		cols = maxi(cols, int(_foes[id].slot) + 1)
	var x0 = FOE_X0
	var cw = (_arena.size.x - 4.0 - x0) / float(cols)
	var pw = floor(minf(cw - 4.0, 196.0))
	var k = 4 if cols == 1 else 3
	var ground = _arena.ground()
	var top = ground
	for id in _foes:
		var nd = _foes[id]
		var cx = x0 + cw * (float(int(nd.slot)) + 0.5)
		nd.view.set_art_scale(k)
		var need = FoeView.needed(str(nd.foe), k)
		nd.view.size = need
		nd.home = Vector2(floor(cx - need.x / 2.0), floor(ground + float(FoeView.FOOT * k) - need.y))
		nd.view.position = nd.home
		top = minf(top, nd.home.y)
		nd["cx"] = cx
	var ph = BattleWidgets.PLATE_H_WIDE if pw >= BattleWidgets.PLATE_WIDE_AT else BattleWidgets.PLATE_H_NARROW
	var py = maxf(4.0, floor(top - ph - 6.0))
	for id in _foes:
		var nd = _foes[id]
		var cx = float(nd.cx)
		if nd.plate == null or absf(nd.plate.custom_minimum_size.x - pw) > 0.5:
			if nd.plate != null:
				_foe_layer.remove_child(nd.plate)
				nd.plate.queue_free()
			var plate = BattleWidgets.FoePlate.new(str(id), pw, int(nd.slot))
			plate.pressed.connect(_open_unit.bind(str(id)))
			_foe_layer.add_child(plate)
			nd.plate = plate
			plate.set_unit(nd.unit, nd.known)
		nd.plate.position = Vector2(floor(cx - pw / 2.0), py)
		nd.plate.size = Vector2(pw, ph)
		var hy = py + ph + 2.0
		_rect(nd.hit, floor(cx - cw / 2.0), hy, floor(cw), maxf(8.0, _arena.size.y - hy))
	_mark()


func _add_foe(u: Dictionary) -> void:
	var id = str(u.get("id", ""))
	if id == "" or _foes.has(id):
		return
	var view = FoeView.new()
	view.marker_color = Pal.ACCENT
	_foe_layer.add_child(view)
	view.setup(str(u.get("foe", "")), 64.0, true)
	var hit = Button.new()
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		hit.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	hit.set_meta("bv_foe", id)
	hit.set_meta("anchor_id", "bv_foe:" + id)
	hit.pressed.connect(_on_foe.bind(id))
	_foe_layer.add_child(hit)
	_foes[id] = {"view": view, "hit": hit, "plate": null, "slot": int(u.get("slot", 0)), "foe": str(u.get("foe", "")),
		"unit": u.duplicate(true), "known": RpgBattle.known(B, id), "home": Vector2.ZERO, "cx": 0.0}


func _drop_foe(id: String) -> void:
	var nd = _foes.get(id)
	if nd == null:
		return
	for part in [nd.view, nd.hit, nd.plate]:
		if part != null and is_instance_valid(part):
			if part.get_parent() != null:
				part.get_parent().remove_child(part)
			part.queue_free()
	_foes.erase(id)


## A foe that is down leaves its place to one that comes after it.
func _clear_place(slot: int, but: String) -> void:
	for id in _foes.keys():
		if str(id) != but and int(_foes[id].slot) == slot and not bool(_foes[id].unit.get("alive", true)):
			_drop_foe(str(id))


func _mark() -> void:
	for id in _foes:
		var nd = _foes[id]
		var on = str(id) == target and bool(nd.unit.get("alive", true))
		nd.view.set_marked(on)
		if nd.plate != null:
			nd.plate.set_picked(on)


# =============================================================================
# The state as it IS (after every playback, a skip, a resume)
# =============================================================================

func _sync() -> void:
	var now = {}
	for f in B.foes:
		now[str(f.id)] = f
	for id in _foes.keys():
		if not now.has(str(id)):
			_drop_foe(str(id))
	for i in range(B.foes.size()):
		var f = B.foes[i]
		var id = str(f.id)
		if not bool(f.alive) and _place_taken(i):
			_drop_foe(id)
			continue
		if not _foes.has(id):
			_add_foe(f)
		var nd = _foes[id]
		nd.unit = f.duplicate(true)
		nd.slot = int(f.get("slot", 0))
		nd.known = RpgBattle.known(B, id)
	_fix_target()
	_place_foes()
	for id in _foes:
		var nd = _foes[id]
		var alive = bool(nd.unit.get("alive", true))
		nd.plate.set_unit(nd.unit, nd.known)
		nd.view.visible = alive
		nd.hit.mouse_filter = Control.MOUSE_FILTER_STOP if alive else Control.MOUSE_FILTER_IGNORE
	var h = B.hero
	_hero_statuses = h.get("statuses", []).duplicate(true)
	_hero_plate.set_hp(int(h.hp), int(h.hp_max), false)
	_hero_plate.set_energy(int(h.en), int(h.en_max))
	_hero_plate.set_gauge(float(h.get("gauge", 0.0)), false)
	_gauge_full = float(h.get("gauge", 0.0)) >= RpgDefs.GAUGE_MAX
	_low_hp(int(h.hp))
	_hero_plate.set_statuses(_hero_statuses)
	_show_wave(int(B.get("wave", 0)) + 1, B.get("waves", []).size())
	_show_turn(int(h.get("turns", 0)))
	_guard_shown = bool(h.get("guarding", false)) and not RpgBattle.over(B)
	_end_pose = ""
	if RpgBattle.over(B):
		_end_pose = "flex" if RpgBattle.won(B) else "hurt"
	_kill(_pose_tw)
	_pose_rest()
	if _hero_view != null:
		_hero_view.position = _hero_home
	_refresh_keys()
	_refresh_timeline()
	_refresh_hint()
	_mark_danger()
	_status_fx(true)
	if not _busy and B.get("pet") is Dictionary and not RpgBattle.over(B) and bool(RpgBattle.options(B).pet.ok):
		_teach("pet")


## What lasts is seen: flames on a burning fighter, drops on a bleeding one, stars round a stunned or broken
## head, a faint bubble for a shield, green motes for regeneration. `fresh`: everything is drawn anew (the
## fighters may stand somewhere else); otherwise only what changed is added or taken away.
func _status_fx(fresh: bool = false) -> void:
	if instant or _fx_layer == null:
		return
	var want = {}
	if not RpgBattle.over(B):
		for st in _hero_statuses:
			if STATUS_LOOPS.has(str(st.get("id", ""))):
				want["hero|" + str(st.id)] = true
		for id in _foes:
			var nd = _foes[id]
			if not bool(nd.unit.get("alive", true)):
				continue
			for st in nd.unit.get("statuses", []):
				if STATUS_LOOPS.has(str(st.get("id", ""))):
					want[str(id) + "|" + str(st.id)] = true
			if bool(nd.unit.get("broken", false)):
				want[str(id) + "|stun"] = true
			# A foe winding up a blow gathers it for all to see; once it is charged, it blazes.
			var it = nd.unit.get("intent", {})
			if it is Dictionary and bool(it.get("windup", false)) and not bool(nd.unit.get("broken", false)):
				want[str(id) + ("|charged" if bool(it.get("charged", false)) else "|charge")] = true
	for key in _status_nodes.keys():
		var node = _status_nodes[key]
		if fresh or not want.has(key) or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_status_nodes.erase(key)
	for key in want:
		if _status_nodes.has(key):
			continue
		var parts = str(key).split("|")
		var id2 = str(parts[0])
		var sid = str(parts[1])
		var row = STATUS_LOOPS[sid]
		var hero = id2 == "hero"
		var at = _mid(id2)
		var col = Pal.ACCENT
		var opts = {"loop": true}
		match sid:
			"burn":
				at = _feet(id2) + Vector2(0, -22)
				col = Pal.ACCENT2
			"bleed":
				col = Pal.DANGER
			"stun":
				at = _head(id2) + Vector2(0, 8)
				opts["half"] = 12.0
			"shield":
				col = RpgUi.color("grit") if hero else Pal.MUTED
			"regen":
				col = Pal.GOOD
				opts["n"] = 4
			"charge":
				col = Pal.DANGER
				opts["n"] = 8
			"charged":
				col = Pal.DANGER
				opts["n"] = 10
				opts["half"] = 22.0
		var node2 = BattleFx.at(_fx_layer, str(row[0]), at, col, float(row[1]) * float(speed), opts)
		if node2 != null:
			node2.modulate.a = 0.45 if sid == "shield" else (0.55 if sid == "charged" else 0.8)
			node2.set_meta("bv_status_fx", key)
			_status_nodes[key] = node2


## A foe about to hit hard says so: its intent beats red (a quarter of the hero's HP or more in one action,
## or a blow it has finished charging).
func _mark_danger() -> void:
	var most = float(B.hero.hp_max)
	for id in _foes:
		var nd = _foes[id]
		if nd.plate == null:
			continue
		var it = nd.unit.get("intent", {})
		var hard = false
		if it is Dictionary and not it.is_empty() and bool(nd.unit.get("alive", true)):
			var total = float(it.get("dmg", 0)) * float(maxi(1, int(it.get("hits", 1))))
			hard = total >= 0.25 * most or (bool(it.get("windup", false)) and bool(it.get("charged", false)))
		nd.plate.set_danger(hard and not instant)
		if hard and not _busy:
			_teach("danger")


## A foe that is down keeps its place (its plate fades) until another one
## stands there: one that lives, or one that came after it.
func _place_taken(index: int) -> bool:
	var f = B.foes[index]
	for j in range(B.foes.size()):
		var g = B.foes[j]
		if j != index and int(g.get("slot", 0)) == int(f.get("slot", 0)) and (bool(g.alive) or j > index):
			return true
	return false


func _fix_target() -> void:
	var live = []
	for f in B.foes:
		if bool(f.alive):
			live.append(str(f.id))
	if not live.has(target):
		var kept = str(B.get("target", ""))
		target = kept if live.has(kept) else (str(live[0]) if not live.is_empty() else "")


func _show_wave(n: int, of: int) -> void:
	_wave_label.text = ("WAVE %d/%d" % [maxi(1, n), maxi(1, of)]) if of > 1 else ""
	_wave_label.set_meta("bv_wave", "%d/%d" % [maxi(1, n), maxi(1, of)])


func _show_turn(n: int) -> void:
	_turn_label.text = "TURN %d" % maxi(1, n)
	_turn_label.set_meta("bv_turn", maxi(1, n))


func _refresh_keys() -> void:
	var o = RpgBattle.options(B)
	for m in o.moves:
		var key = _move_keys.get(str(m.id))
		if key != null:
			key.set_state(m, RpgBattle.preview(B, {"t": "move", "id": str(m.id), "target": target}))
	var sp = RpgBattle.preview(B, {"t": "strike", "target": target})
	_act["strike"].set_state(bool(o.strike), _range(sp))
	_act["guard"].set_state(bool(o.guard), "+%d" % RpgDefs.EN_GUARD)
	var left = 0
	var usable = false
	for it in o.items:
		left += int(it.n)
		usable = usable or bool(it.ok)
	_act["item"].set_state(usable, ("x%d" % left) if not o.items.is_empty() else "")
	if B.get("pet") is Dictionary:
		_act["pet"].set_state(bool(o.pet.ok), "%d/%d" % [mini(int(o.pet.charge), int(o.pet.max)), int(o.pet.max)], bool(o.pet.ok))
	else:
		_act["pet"].set_state(false, "")
	if str(o.ult.id) == "":
		_act["ult"].set_state(false, "")
	else:
		_act["ult"].set_state(bool(o.ult.ok), "%d%%" % int(floor(float(o.ult.gauge) + 0.0001)), bool(o.ult.ok))
	_act["ult"].modulate = Color.WHITE


func _range(pv: Dictionary) -> String:
	var lo = int(pv.get("lo", 0))
	var hi = int(pv.get("hi", 0))
	if hi <= 0:
		return ""
	return str(lo) if lo == hi else "%d-%d" % [lo, hi]


func _refresh_timeline() -> void:
	var tiles = []
	for id in RpgBattle.timeline(B, 7):
		var kind = "hero" if str(id) == "hero" else ("pet" if str(id) == "pet" else "foe")
		var slot = 0
		if kind == "foe":
			var f = RpgBattle.unit(B, str(id))
			slot = int(f.get("slot", 0)) if f != null else 0
		tiles.append({"id": str(id), "kind": kind, "slot": slot})
	_timeline.set_tiles(tiles)


## The first fight's hint for the step the player is at.
func _refresh_hint() -> void:
	if _hint == null:
		return
	var f = RpgBattle.unit(B, target) if target != "" else null
	var text = ""
	if RpgBattle.over(B) or f == null:
		text = ""
	elif bool(f.get("broken", false)):
		text = "BROKEN! It loses its turn and takes more: hit hard now."
	else:
		var kn = RpgBattle.known(B, target)
		if kn.weak.is_empty():
			text = "Try each school: a weak hit chips its guard pips."
		elif int(f.get("guard", 0)) > 0:
			text = "Weak to %s: hit it there to chip its guard." % _schools(kn.weak)
		else:
			text = "Watch its intent. Guard halves a hit and gives 2 energy."
	_hint.text = text
	_hint.modulate.a = 0.0 if text == "" else 1.0


# =============================================================================
# Input
# =============================================================================

## True when the tap was used up (a playback was skipped, or nothing may be done).
func _tap_guard() -> bool:
	if _closed or _result != null:
		return true
	if _busy:
		skip()
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _busy:
			skip()


func _on_foe(id: String) -> void:
	if _tap_guard():
		return
	var nd = _foes.get(id)
	if nd == null or not bool(nd.unit.get("alive", true)):
		return
	target = id
	Sfx.tap()
	_mark()
	if nd.plate != null and not instant:
		Kit.pop(nd.plate, 1.06, 0.16)
	_refresh_keys()
	_refresh_hint()


func _on_move(id: String) -> void:
	if _tap_guard():
		return
	var key = _move_keys.get(id)
	if key == null:
		return
	if not key.usable:
		_refuse(_why(key.why, {"t": "move", "id": id}))
		if str(key.why) == "energy":
			_hero_plate.deny_energy()
		return
	if not instant:
		# (A blink, not a pop: a key never changes its size or its place, not even for a moment.)
		Sfx.click()
		BattleFx.tint(key, Color(1.6, 1.6, 1.6), 0.22)
		Kit.burst(key, RpgUi.color(str(key.school)), 8)
	_do({"t": "move", "id": id, "target": target})


func _on_act(what: String) -> void:
	if _tap_guard():
		return
	if not instant and _act.has(what):
		Sfx.click()
		if what != "ult":
			BattleFx.tint(_act[what], Color(1.6, 1.6, 1.6), 0.22)
	match what:
		"strike":
			_do({"t": "strike", "target": target})
		"guard":
			_do({"t": "guard"})
		"item":
			_open_items()
		"pet":
			if not (B.get("pet") is Dictionary):
				_refuse("No companion in this build.")
			elif not _act["pet"].usable:
				_refuse(_why("pet", {"t": "pet"}))
			else:
				_do({"t": "pet", "target": target})
		"ult":
			if str(B.hero.get("ult", "")) == "":
				_refuse("No ultimate in this build.")
			elif not _act["ult"].usable:
				_refuse(_why("gauge", {"t": "ult"}))
			else:
				_do({"t": "ult", "target": target})


## The music on or off (it does not skip what is playing either).
func _on_music() -> void:
	if _closed:
		return
	RpgSfx.set_music(not RpgSfx.music_on())
	var on = RpgSfx.music_on()
	_music_key.icon = Icons.tex("music" if on else "music_off", null, 2 if _music_key.custom_minimum_size.x >= 40 else 1)
	if on and _held:
		RpgSfx.tune("result" if _result != null else ("boss" if _has_boss() else "battle"), RpgSfx.region_of_scene(str(_opts.get("scene", ""))))
	_say("Music on." if on else "Music off.")


## AUTO on or off. It does not skip what is playing: the hero's next move is simply his own, or the player's.
func _on_auto() -> void:
	if _closed or _result != null:
		return
	_set_auto(not auto)
	auto_kept = auto
	Sfx.tap()
	_say("Auto: the hero fights by himself. Tap AUTO again to take over." if auto else "Your move.")
	if auto and not _busy:
		_auto_soon()


func _set_auto(on: bool) -> void:
	auto = on and not bool(_opts.get("tutorial", false))
	_kill(_auto_tw)
	if _auto_key != null:
		_auto_key.set_meta("bv_auto", auto)
		# (Its word never changes: lit gold while it is on.)
		_auto_key.modulate = Color(1.5, 1.3, 0.45) if auto else Color.WHITE


## The hero's own move, a breath after the last thing was shown.
func _auto_soon() -> void:
	_kill(_auto_tw)
	if not auto or _closed or RpgBattle.over(B) or instant:
		return
	_auto_tw = create_tween()
	_auto_tw.tween_interval(0.32 / float(speed))
	_auto_tw.tween_callback(_auto_step)


func _auto_step() -> void:
	if not auto or _busy or _closed or _result != null or RpgBattle.over(B) or not bool(B.get("wait", false)):
		return
	if _sheet != null and is_instance_valid(_sheet):
		# Something is open (a fighter's sheet, the belt): the hero waits for it to be put away.
		_auto_soon()
		return
	var a = RpgAi.hero_action(B, "heuristic")
	var aim = str(a.get("target", ""))
	if aim != "" and aim != target and _foes.has(aim):
		target = aim
		_mark()
	_do(a)


func _on_speed() -> void:
	speed = 1 if speed >= 2 else 2
	speed_kept = speed
	BattleFx.speed = float(speed)
	_speed_key.text = "x%d" % speed
	speed_changed.emit(speed)


func _on_flee() -> void:
	if _tap_guard():
		return
	_set_auto(false)
	Kit.confirm("Flee the battle?", "Nothing is lost. You can try again any time.", "Flee", func():
		if not _closed and _result == null and not RpgBattle.over(B):
			_do({"t": "flee"}))


func _refuse(text: String) -> void:
	_say(text)
	Sfx.error()
	if not instant and _line_box != null:
		BattleFx.knock(_line_box, _line_box.position, 5.0, 0.18)


## Why an action cannot be done, in words.
func _why(why: String, action: Dictionary) -> String:
	var h = B.hero
	match why:
		"cooldown":
			var row = RpgBattle.move_row(B, str(action.get("id", "")))
			var cd = int(h.cds.get(str(action.get("id", "")), 0))
			return "%s rests %d more turn%s." % [str(row.name) if row != null else "It", cd, "" if cd == 1 else "s"]
		"energy":
			var row2 = RpgBattle.move_row(B, str(action.get("id", "")))
			return "Not enough energy: %s costs %d, you have %d." % [str(row2.name) if row2 != null else "it", RpgBattle.cost_of(B, row2) if row2 != null else 0, int(h.en)]
		"gauge":
			return "The gauge is at %d%%: it fills as you fight." % int(floor(float(h.get("gauge", 0.0))))
		"pet":
			var p = B.pet
			var more = int(p.get("charge_max", 3)) - int(p.get("charge", 0))
			return "%s needs %d more turn%s." % [str(p.get("name", "Your companion")), more, "" if more == 1 else "s"]
		"item":
			return "None of that left for this battle."
		"rule":
			return "No items in this fight."
		"over":
			return "The battle is over."
	return "Not now."


## One hero action: the engine runs it, the caller keeps the draft, the events play.
func _do(action: Dictionary) -> void:
	if _busy or _closed or _result != null:
		return
	var ev = RpgBattle.act(B, action)
	if ev.size() == 1 and str(ev[0].get("t", "")) == "no":
		_refuse(_why(str(ev[0].get("why", "")), action))
		return
	var store = _opts.get("store")
	if store is Callable and store.is_valid():
		store.call(B)
	_play(ev)


# =============================================================================
# Playback
# =============================================================================

## Pause for `secs`. Bound to this node: if the view is freed, it never returns.
func _wait(secs: float) -> void:
	var tw = create_tween()
	tw.tween_interval(maxf(0.01, secs))
	await tw.finished


func _alive(gen: int) -> bool:
	return is_instance_valid(self) and is_inside_tree() and gen == _gen and not _closed


func _play(events: Array) -> void:
	_gen += 1
	var gen = _gen
	_busy = true
	_events = events
	_act_head = ""
	_act_dmg = 0
	_ko_done = {}
	_dim_keys(true)
	for i in range(events.size()):
		var e = events[i]
		_ev_i = i
		if not (e is Dictionary):
			continue
		var secs = _show(e)
		if secs > 0.0 and not instant:
			await _wait(secs / float(speed))
			if not _alive(gen):
				return
	_end_playback()


## Jump to the end of the playback that is running.
func skip() -> void:
	if not _busy or _closed:
		return
	_gen += 1
	var said = _digest(_events)
	_end_playback()
	if said != "":
		_say(said)


## A playback in one line, for when it was skipped: what the hero did and dealt, who fell, what it cost.
func _digest(events: Array) -> String:
	var head = ""
	var dealt = 0
	var taken = 0
	var down = 0
	for e in events:
		if not (e is Dictionary):
			continue
		match str(e.get("t", "")):
			"act":
				if str(e.get("who", "")) == "hero" and head == "":
					var kind = str(e.get("kind", ""))
					head = "You lose your turn" if kind == "lost" else ("You get away" if kind == "flee" else str(e.get("name", "")))
			"dmg":
				if str(e.get("dst", "")) == "hero":
					taken += int(e.get("amount", 0))
				elif str(e.get("src", "")) == "hero" or str(e.get("src", "")) == "pet":
					dealt += int(e.get("amount", 0))
			"tick":
				if str(e.get("dst", "")) == "hero":
					taken += int(e.get("amount", 0))
			"ko":
				if str(e.get("dst", "")) != "hero":
					down += 1
	var parts = []
	if head != "" and dealt > 0:
		parts.append("%s: %d damage" % [head, dealt])
	elif head != "":
		parts.append(head)
	elif dealt > 0:
		parts.append("%d damage" % dealt)
	if down > 0:
		parts.append("%d down" % down)
	if taken > 0:
		parts.append("You take %d" % taken)
	return (". ".join(parts) + ".") if not parts.is_empty() else ""


func _end_playback() -> void:
	_busy = false
	_kill_moving()
	_kill(_shake_tw)
	_arena.position = _arena_home
	if _arena_size.x > 0.0:
		_arena.size = _arena_size
	_foe_layer.modulate.a = 1.0
	_dim_keys(false)
	_sync()
	if RpgBattle.over(B):
		_battle_over()
	elif bool(B.get("wait", false)):
		if auto:
			_auto_soon()
		else:
			_snd("turn")


func _battle_over() -> void:
	if bool(B.get("fled", false)):
		_leave("flee")
	else:
		_show_result()


func _kill(tw) -> void:
	if tw != null and tw is Tween and tw.is_valid():
		tw.kill()


func _kill_moving() -> void:
	for tw in _moving:
		_kill(tw)
	_moving = []
	if _hero_view != null:
		_hero_view.position = _hero_home
		_hero_view.modulate = Color.WHITE
	for id in _foes:
		_foes[id].view.position = _foes[id].home
		_foes[id].view.modulate = Color.WHITE


func _say(text: String) -> void:
	if _line != null:
		_line.text = text
	if text != "" and (_log.is_empty() or str(_log[_log.size() - 1]) != text):
		# (A line that grows as its hits land, "Stomp: 12 damage." then "Stomp: 24 damage.", is one entry.)
		var head = text.split(":")[0]
		if not _log.is_empty() and text.contains(":") and str(_log[_log.size() - 1]).begins_with(head + ":"):
			_log[_log.size() - 1] = text
		else:
			_log.append(text)
		if _log.size() > LOG_MAX:
			_log.remove_at(0)


func _on_line_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_line_box.accept_event()
		if _tap_guard():
			return
		_open_log()


## Everything that was said in this fight, the newest first.
func _open_log() -> void:
	Sfx.tap()
	var s = Kit.sheet("What happened")
	s.set_meta("bv_sheet", "log")
	if _log.is_empty():
		s.box.add_child(Kit.muted_para("Nothing yet.", 13))
	for i in range(_log.size() - 1, -1, -1):
		var l = Kit.para(str(_log[i]), 13, Pal.TEXT if i == _log.size() - 1 else Pal.MUTED, i == _log.size() - 1)
		l.set_meta("bv_log_line", i)
		s.box.add_child(l)
	var help = Kit.button("How fights work", "secondary", RealmHelp.open, "lg", "book" if Icons.has_icon("book") else "")
	help.set_meta("bv_help", true)
	s.box.add_child(help)
	s.box.add_child(Kit.button("Close", "ghost", s.close, "lg"))
	_sheet_up(s)


func _name(id: String) -> String:
	if id == "hero":
		return "You"
	if id == "pet":
		return str(B.pet.get("name", "Your companion")) if B.get("pet") is Dictionary else "Your companion"
	var nd = _foes.get(id)
	if nd != null:
		return str(nd.unit.get("name", "The foe"))
	var u = RpgBattle.unit(B, id)
	return str(u.get("name", "The foe")) if u != null else "The foe"


func _schools(list: Array) -> String:
	var out = []
	for sc in list:
		out.append(str(RpgDefs.SCHOOL_NAMES.get(str(sc), str(sc).capitalize())))
	return " and ".join(out)


## Where a number rises from for that unit.
func _anchor(id: String) -> Control:
	if id == "hero":
		return _hero_mark if _hero_mark != null else _hero_plate
	if id == "pet":
		return _pet_view if _pet_view != null else _hero_plate
	var nd = _foes.get(id)
	return nd.view if nd != null else null


func _float(at: Control, text: String, color: Color, px: int = 2, delay: float = 0.0) -> void:
	if at != null and is_instance_valid(at):
		Kit.floater(at, text, color, delay, px)


## A short step towards the other side and back.
func _lunge(c: Control, home: Vector2, dx: float) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.position = home
	# The tween is the mover's own: it goes when a new wave takes the foe away.
	var tw = c.create_tween()
	tw.tween_property(c, "position", home + Vector2(dx, 0), 0.08 / float(speed)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", home, 0.16 / float(speed)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_moving.append(tw)


## Show a pose (at frame 0) for a moment, then what the hero rests in.
func _pose(pose: String, secs: float) -> void:
	if _hero_view == null:
		return
	_kill(_pose_tw)
	_hero_view.animate = false
	_hero_view.forced_pose = pose
	_pose_tw = create_tween()
	_pose_tw.tween_interval(secs / float(speed))
	_pose_tw.tween_callback(_pose_rest)


func _pose_rest() -> void:
	if _hero_view == null:
		return
	var pose = _end_pose
	if pose == "" and _guard_shown:
		pose = "guard"
	_hero_view.forced_pose = pose
	_hero_view.animate = pose == ""


func _shake(power: float = 1.0) -> void:
	_kill(_shake_tw)
	_arena.position = _arena_home
	if instant:
		return
	_shake_tw = create_tween()
	for off in [Vector2(-6, 2), Vector2(5, -3), Vector2(-4, 3), Vector2(3, -2), Vector2(-2, 1)]:
		_shake_tw.tween_property(_arena, "position", _arena_home + (off * power).round(), 0.035)
	_shake_tw.tween_property(_arena, "position", _arena_home, 0.05)


# -----------------------------------------------------------------------------
# Effects and sounds (BattleFx, RpgSfx). Nothing of this in an `instant` playback.
# -----------------------------------------------------------------------------

func _snd(name: String, pitch: float = 1.0, drift: float = 0.0) -> void:
	if not instant:
		RpgSfx.play(name, pitch, drift)


## Where a unit's middle is, in the effect layer's own pixels (a fighter stands at its home there).
func _mid(id: String) -> Vector2:
	var off = _fx_layer.position
	if id == "pet" and _pet_view != null:
		return _pet_view.position + _pet_view.size / 2.0 - off
	if id == "hero" or id == "pet":
		if _hero_view == null:
			return Vector2(58.0, _arena.ground() - 56.0) - off
		var k = float(HERO_SCALE)
		return Vector2(_hero_home.x + _hero_mid * k, _hero_home.y + float(_hero_top + _hero_low) * 0.5 * k) - off
	var nd = _foes.get(id)
	if nd == null:
		return _fx_layer.size / 2.0
	var lay = nd.view.layout()
	return nd.home + lay.sprite.get_center() - off


## The ground under a unit.
func _feet(id: String) -> Vector2:
	return Vector2(_mid(id).x, _arena.ground() - _fx_layer.position.y)


## Just over a unit's head: its numbers start there.
func _head(id: String) -> Vector2:
	var off = _fx_layer.position
	if id == "hero" or id == "pet":
		if id == "pet" and _pet_view != null:
			return _pet_view.position + Vector2(_pet_view.size.x / 2.0, -6.0) - off
		if _hero_view == null:
			return _mid(id) + Vector2(0, -50)
		return Vector2(_hero_home.x + _hero_mid * float(HERO_SCALE), _hero_home.y + float(_hero_top) * float(HERO_SCALE) - 12.0) - off
	var nd = _foes.get(id)
	if nd == null:
		return _fx_layer.size / 2.0
	var lay = nd.view.layout()
	return nd.home + Vector2(lay.sprite.get_center().x, lay.sprite.position.y + 6.0) - off


func _fx(kind: String, pos: Vector2, color: Color, dur: float = 0.36, opts: Dictionary = {}):
	if instant:
		return null
	return BattleFx.at(_fx_layer, kind, pos, color, dur, opts)


func _num(id: String, text: String, color: Color, px: int = 2, big: bool = false) -> void:
	if instant:
		return
	var n = int(_hit_counts.get(id, 0))
	_hit_counts[id] = n + 1
	# The hero's rise over his head (sky is there); a foe stands right under its plate, so its numbers start on
	# its body and hop to the side.
	var at = _head(id) if id == "hero" or id == "pet" else _mid(id) + Vector2(0, -12.0)
	BattleFx.number(_fx_layer, at, text, color, px, n, big)


## A word at a unit ("WEAK", a status): over the hero's head, across a foe's feet. Words of one action stack.
func _word(id: String, text: String, color: Color, px: int = 1, delay: float = 0.0, _up: float = 0.0) -> void:
	if instant:
		return
	var n = int(_word_counts.get(id, 0))
	_word_counts[id] = n + 1
	if id == "hero" or id == "pet":
		BattleFx.word(_fx_layer, _head(id) + Vector2(0, -14.0 - 12.0 * float(n)), text, color, px, delay)
	else:
		BattleFx.word(_fx_layer, _mid(id) + Vector2(0, 20.0 - 12.0 * float(n)), text, color, px, delay, 12.0)


## Something behind the fighters (over the backdrop and its motes): an ultimate's rays, the dark of a wind-up.
func _behind(node) -> void:
	if node != null and is_instance_valid(node) and node.get_parent() == _arena:
		_arena.move_child(node, _back_index)


func _dim_back(alpha: float, hold: float) -> void:
	if not instant:
		_behind(BattleFx.dim(_arena, alpha, hold))


## A foe (or the hero, dx < 0) knocked back and returning.
func _knock(id: String, dx: float) -> void:
	if instant:
		return
	if id == "hero":
		if _hero_view != null:
			_kill(_hero_tw)
			_hero_tw = BattleFx.knock(_hero_view, _hero_home, dx, 0.24)
			if _hero_tw != null:
				_moving.append(_hero_tw)
		return
	var nd = _foes.get(id)
	if nd != null:
		var tw = BattleFx.knock(nd.view, nd.home, dx, 0.22)
		if tw != null:
			_moving.append(tw)


## True when the events still to come in this action have `dst` going down.
func _ko_ahead(dst: String) -> bool:
	for i in range(_ev_i + 1, _events.size()):
		var e = _events[i]
		if not (e is Dictionary):
			continue
		var t = str(e.get("t", ""))
		if t == "act" or t == "turn":
			return false
		if t == "ko" and str(e.get("dst", "")) == dst:
			return true
	return false


## How many hits of the action being shown are still to come on screen.
func _hits_ahead(src: String) -> int:
	var n = 0
	for i in range(_ev_i + 1, _events.size()):
		var e = _events[i]
		if not (e is Dictionary):
			continue
		var t = str(e.get("t", ""))
		if t == "act" or t == "turn":
			break
		if t == "dmg" and str(e.get("src", "")) == src and not bool(e.get("counter", false)):
			n += 1
	return n


## The hero's body in an attack: a step in (a hop for a stomp, a blur for speed), a hold while the hits land,
## and back. A thrown attack stays where it is.
func _hero_attack(school: String, hits: int, thrown: bool) -> void:
	if _hero_view == null or instant:
		return
	_kill(_hero_tw)
	var k = float(speed)
	var hold = minf(1.1, 0.26 + 0.3 * float(maxi(0, hits - 1))) / k
	var home = _hero_home
	_hero_view.position = home
	var tw = _hero_view.create_tween()
	if thrown:
		tw.tween_property(_hero_view, "position", home + Vector2(-5, 0), 0.07 / k)
		tw.tween_property(_hero_view, "position", home + Vector2(6, 0), 0.06 / k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(hold)
	elif school == "legs":
		tw.tween_property(_hero_view, "position", home + Vector2(STEP_IN * 0.55, -22.0), 0.1 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_hero_view, "position", home + Vector2(STEP_IN, 0), 0.07 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_hero_dust.bind(STEP_IN))
		tw.tween_interval(hold)
	elif school == "speed":
		tw.tween_callback(_hero_blur)
		tw.tween_property(_hero_view, "position", home + Vector2(STEP_IN + 8.0, 0), 0.05 / k)
		tw.tween_interval(hold * 0.8)
	else:
		tw.tween_property(_hero_view, "position", home + Vector2(-6, 0), 0.05 / k)
		tw.tween_property(_hero_view, "position", home + Vector2(STEP_IN, 0), 0.08 / k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(hold)
	tw.tween_property(_hero_view, "position", home, 0.16 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_hero_tw = tw
	_moving.append(tw)


func _hero_dust(dx: float = 0.0) -> void:
	_fx("dust", _feet("hero") + Vector2(dx, -2.0), Pal.MUTED, 0.3)


func _hero_blur() -> void:
	var at = _mid("hero")
	_fx("streaks", at + Vector2(10, 0), RpgUi.color("speed"), 0.22, {"flip": true})


## The HP `id` had before the first of these events touched it.
func _hp_before(events: Array, id: String, hp_now: int) -> int:
	for e in events:
		if not (e is Dictionary) or str(e.get("dst", "")) != id:
			continue
		match str(e.get("t", "")):
			"dmg", "tick":
				return int(e.get("hp", hp_now)) + int(e.get("amount", 0))
			"heal":
				return int(e.get("hp", hp_now)) - int(e.get("amount", 0))
	return hp_now


## Draw one event. Returns how long to let it be seen (seconds at x1; 0 = go on at once).
func _show(e: Dictionary) -> float:
	match str(e.get("t", "")):
		"turn":
			if str(e.get("who", "")) == "hero":
				_guard_shown = false
				_show_turn(int(e.get("n", 1)))
				_pose_rest()
			return 0.0
		"act":
			return _show_act(e)
		"dmg":
			return _show_dmg(e)
		"miss":
			var md = str(e.get("dst", ""))
			_word(md, "MISS", Pal.MUTED, 2)
			_knock(md, -10.0 if md == "hero" else 10.0)
			_snd("miss", 1.0, 0.05)
			_say("%s: a miss." % _act_head if _act_head != "" else "A miss.")
			return 0.3
		"heal":
			var dst = str(e.get("dst", ""))
			_set_hp(dst, int(e.get("hp", 0)))
			if int(e.get("amount", 0)) > 0:
				_num(dst, "+%d" % int(e.amount), Pal.GOOD, 2)
				_fx("heal", _mid(dst), Pal.GOOD, 0.6)
				_tint(dst, Color(0.6, 1.5, 0.7))
				_snd("heal")
				_say("%s heal%s %d." % [_name(dst), "" if dst == "hero" else "s", int(e.amount)])
				return 0.34
			return 0.0
		"status":
			return _show_status(e)
		"tick":
			var dst2 = str(e.get("dst", ""))
			_set_hp(dst2, int(e.get("hp", 0)))
			var burn = str(e.get("id", "")) == "burn"
			var bleed = str(e.get("id", "")) == "bleed"
			_num(dst2, str(int(e.get("amount", 0))), Pal.ACCENT2 if burn else Pal.DANGER, 2)
			if burn:
				_fx("flame", _mid(dst2) + Vector2(0, 6), Pal.ACCENT2, 0.5)
				_snd("burn", 1.0, 0.06)
			else:
				_fx("drops", _mid(dst2), Pal.DANGER, 0.45)
				_snd("bleed", 1.0, 0.06)
			if dst2 != "hero":
				var tnd = _foes.get(dst2)
				if tnd != null:
					tnd.view.hit()
			var word = "burn" if burn else ("bleed" if bleed else "pay")
			_say("%s %s%s: %d." % [_name(dst2), word, "" if dst2 == "hero" else "s", int(e.get("amount", 0))])
			return 0.3
		"break":
			return _show_break(str(e.get("dst", "")))
		"recover":
			var nd = _foes.get(str(e.get("dst", "")))
			if nd != null:
				nd.unit["broken"] = false
				nd.unit["guard"] = int(e.get("guard", 0))
				nd.plate.set_guard(int(e.get("guard", 0)), int(nd.unit.get("guard_max", 0)))
				nd.plate.set_statuses(nd.unit.get("statuses", []), false)
				_fx("up", _mid(str(e.get("dst", ""))), Pal.MUTED, 0.4)
				_snd("recover")
				_status_fx()
			return 0.0
		"chip":
			var nd2 = _foes.get(str(e.get("dst", "")))
			if nd2 != null:
				nd2.unit["guard"] = int(e.get("guard", 0))
				nd2.plate.set_guard(int(e.get("guard", 0)), int(nd2.unit.get("guard_max", 0)))
				_snd("chip", 1.0, 0.05)
			return 0.12
		"ko":
			if _ko_done.has(str(e.get("dst", ""))):
				_ko_done.erase(str(e.get("dst", "")))
				return 0.0
			return _show_ko(str(e.get("dst", "")))
		"energy":
			_hero_plate.set_energy(int(e.get("v", 0)), int(B.hero.en_max))
			return 0.0
		"gauge":
			var gv = float(e.get("v", 0.0))
			_hero_plate.set_gauge(gv, true)
			var full = gv >= RpgDefs.GAUGE_MAX
			if full and not _gauge_full and str(B.hero.get("ult", "")) != "":
				_word("hero", "ULTIMATE READY", Pal.ACCENT, 1, 0.1, 10.0)
				_teach("gauge")
				_fx("sparkle", _mid("hero"), Pal.ACCENT, 0.6, {"n": 8})
				_snd("gauge_full")
				if _act.has("ult") and not instant:
					Kit.pop(_act["ult"], 1.12, 0.3)
			_gauge_full = full
			return 0.0
		"intent":
			var nd3 = _foes.get(str(e.get("who", "")))
			if nd3 != null and e.get("intent") is Dictionary:
				nd3.unit["intent"] = e.intent
				nd3.plate.set_intent(e.intent)
				_status_fx()
			return 0.0
		"learn":
			return _show_learn(e)
		"phase":
			var who = str(e.get("who", ""))
			var nd4 = _foes.get(who)
			if nd4 != null:
				nd4.unit["phase"] = int(e.get("phase", 0))
				nd4.known = RpgBattle.known(B, who)
				var now = RpgBattle.unit(B, who)
				nd4.plate.set_known(now.get("weak", []).size() if now != null else 2, nd4.known)
				nd4.view.hit()
				_fx("ring", _mid(who), Pal.DANGER, 0.5)
				_fx("gather", _mid(who), Pal.DANGER, 0.7)
			var say = str(e.get("say", ""))
			if not instant:
				BattleWidgets.banner(_fx_layer, "IT CHANGES", Pal.DANGER, 0.6 / float(speed))
				BattleFx.flash(_arena, Pal.DANGER, 0.3, 0.3)
			_dim_back(0.5, 0.6)
			_shake(1.2)
			_teach("phase")
			_say(say if say != "" else "%s changes." % _name(who))
			_snd("phase")
			return 0.9
		"summon":
			var fresh = []
			for u in e.get("units", []):
				if u is Dictionary:
					_clear_place(int(u.get("slot", 0)), str(u.get("id", "")))
					_add_foe(u)
					fresh.append(str(u.get("id", "")))
			_place_foes()
			_enter_foes(fresh)
			_snd("summon")
			_teach("summon")
			_say("%s calls for help." % _name(str(e.get("by", ""))) if str(e.get("by", "")) != "" else "More foes arrive.")
			return 0.45
		"wave":
			return _show_new_wave(e)
		"say":
			_say(str(e.get("text", "")))
			return 0.5
		"survive":
			var sd = str(e.get("dst", ""))
			_set_hp(sd, int(e.get("hp", 1)))
			_word(sd, "HANGS ON!", Pal.ACCENT, 2)
			_fx("ring", _mid(sd), Pal.ACCENT, 0.5)
			if not instant:
				BattleFx.flash(_arena, Pal.ACCENT, 0.3, 0.3)
			_snd("survive")
			_say("%s hang%s on!" % [_name(sd), "" if sd == "hero" else "s"])
			return 0.5
		"interrupt":
			var idst = str(e.get("dst", ""))
			_word(idst, "INTERRUPTED", Pal.ACCENT2, 1)
			_fx("spark", _mid(idst), Pal.ACCENT2, 0.3)
			_snd("interrupt")
			_say("%s is interrupted." % _name(idst))
			return 0.3
		"adapt":
			var adst = str(e.get("dst", ""))
			_fx("shield", _mid(adst), RpgUi.color(str(e.get("school", ""))), 0.5)
			_snd("adapt")
			_say("%s adapts: it now resists %s." % [_name(adst), _schools([str(e.get("school", ""))])])
			return 0.35
		"end":
			return _show_end(bool(e.get("win", false)))
	return 0.0


func _tint(id: String, color: Color) -> void:
	if instant:
		return
	if id == "hero":
		if _hero_view != null:
			BattleFx.tint(_hero_view, color, 0.3)
		return
	var nd = _foes.get(id)
	if nd != null:
		BattleFx.tint(nd.view, color, 0.3)


func _set_hp(id: String, hp: int) -> void:
	if id == "hero":
		_hero_plate.set_hp(hp, int(B.hero.hp_max), true)
		_low_hp(hp)
		return
	var nd = _foes.get(id)
	if nd != null:
		nd.unit["hp"] = hp
		nd.plate.set_hp(hp, int(nd.unit.get("hp_max", 1)), true)


## The red edge that beats while the hero is nearly down.
func _low_hp(hp: int) -> void:
	if _vignette != null:
		_vignette.set_on(hp > 0 and float(hp) < LOW_HP * float(B.hero.hp_max) and not RpgBattle.over(B))


func _show_act(e: Dictionary) -> float:
	var who = str(e.get("who", ""))
	var kind = str(e.get("kind", ""))
	var move = str(e.get("name", ""))
	var on = str(e.get("target", ""))
	_act_dmg = 0
	_act_kind = kind
	_act_who = who
	_act_first = true
	_act_heavy = false
	_hit_counts = {}
	_word_counts = {}
	if who == "hero":
		match kind:
			"guard":
				_guard_shown = true
				_pose_rest()
				_act_head = "You guard"
				_fx("shield", _mid("hero") + Vector2(10, 0), RpgUi.color("grit"), 0.5)
				_snd("guard")
				_say("You guard: the next hits are cut down.")
				return 0.34
			"item":
				_pose("cast", 0.4)
				_act_head = "You use %s" % move
				_fx("sparkle", _mid("hero"), Pal.ACCENT2, 0.5)
				_snd("item")
				_say(_act_head + ".")
				return 0.34
			"flee":
				_snd("flee")
				if _hero_view != null and not instant:
					_kill(_hero_tw)
					_hero_tw = _hero_view.create_tween()
					_hero_tw.tween_property(_hero_view, "position", _hero_home + Vector2(-170, 0), 0.3 / float(speed)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					_hero_dust()
				_say("You get away.")
				return 0.3
			"lost":
				_act_head = "You lose your turn"
				_fx("stars", _head("hero") + Vector2(0, 6), Pal.ACCENT, 0.7, {"half": 12.0})
				_snd("stun")
				_say("You are %s and lose your turn." % move.to_lower() if move != "" else "You lose your turn.")
				return 0.5
		var school = str(e.get("school", "plain"))
		var row = RpgBattle.move_row(B, str(e.get("id", ""))) if kind != "strike" else null
		# A move that costs three energy or more, or is slow and heavy by its rank, lands like one.
		_act_heavy = row != null and (int(row.get("cost", 0)) >= 3 or float(row.get("rank", 1.0)) >= 1.35)
		var aim = "foe" if row == null else str(row.get("target", "foe"))
		var aimed = aim == "foe"
		var to = (" on %s" % _name(on)) if (aimed and on != "" and on != "hero" and _foes.has(on)) else ""
		var hits = _hits_ahead("hero")
		var thrown = BattleFx.THROWN.has(school)
		var color = RpgUi.color(school)
		var wait = 0.28
		if aim == "self" or hits <= 0:
			# Nothing is struck: a call, a breath, a stance.
			_pose(str(RpgDefs.SCHOOL_POSE.get(school, "cast")), 0.5)
			_fx("gather", _mid("hero"), color, 0.45)
			_fx("aura", _feet("hero"), color, 0.6, {"half": 30.0})
			_snd("foe_cast", 1.4, 0.04)
		else:
			_pose(str(RpgDefs.SCHOOL_POSE.get(school, "strike")), 0.5 + 0.3 * float(maxi(0, hits - 1)))
			_hero_attack(school, hits, thrown)
			_snd("swing", 1.0, 0.07)
			if thrown and not instant:
				var from = _mid("hero") + Vector2(22, -12)
				for id in _foes:
					if bool(_foes[id].unit.get("alive", true)) and (not aimed or str(id) == on):
						BattleFx.bolt(_fx_layer, from, _mid(str(id)), color, 0.2)
		if kind == "strike":
			_act_head = "You strike%s" % ((" " + _name(on)) if to != "" else "")
		elif kind == "ult":
			_act_head = "%s%s" % [move, to]
			if not instant:
				BattleFx.cutin(_fx_layer, move.to_upper(), Pal.ACCENT, 0.55, "ULTIMATE")
				_behind(BattleFx.at(_arena, "rays", _mid("hero") + _fx_layer.position, Pal.ACCENT, 0.9, {"n": 12, "half": 24.0}))
			_dim_back(0.62, 0.9)
			_snd("ult_start")
			RpgSfx.buzz(2)
			wait = 0.8
		else:
			_act_head = "You use %s%s" % [move, to]
		_say(_act_head + ".")
		return wait
	if who == "pet":
		_act_head = "%s uses %s" % [_name("pet"), move]
		_say(_act_head + ".")
		_snd("pet")
		if _pet_view != null:
			_pet_view.hop()
			_fx("sparkle", _mid("pet"), Pal.GOOD, 0.4, {"n": 4, "half": 10.0})
		return 0.26
	var nd = _foes.get(who)
	var nm = _name(who)
	match kind:
		"lost":
			_act_head = "%s loses its turn" % nm
			_fx("stars", _head(who) + Vector2(0, 8), Pal.ACCENT, 0.7, {"half": 12.0})
			_snd("stun", 0.9)
			_say("%s is %s and loses its turn." % [nm, move.to_lower()] if move != "" else _act_head + ".")
			return 0.45
		"charge":
			_act_head = "%s is charging %s" % [nm, move]
			_say(_act_head + "!")
			_fx("gather", _mid(who), Pal.DANGER, 0.6, {"n": 14})
			_word(who, "CHARGING", Pal.DANGER, 1)
			_teach("charge")
			_snd("charge")
			if nd != null and not instant:
				Kit.pop(nd.view, 1.08, 0.2)
			return 0.5
		"count":
			_act_head = "%s counts down" % nm
			_fx("ring", _mid(who), Pal.ACCENT2, 0.4)
			_snd("count")
			_teach("count")
			_say("%s: %s is coming." % [nm, move])
			return 0.38
	_act_head = "%s uses %s" % [nm, move]
	_say(_act_head + ".")
	if nd != null and not instant:
		if ["debuff", "buff", "heal", "shield", "summon"].has(kind):
			Kit.pop(nd.view, 1.1, 0.26)
			_fx("gather", _mid(who), Pal.DANGER if kind == "debuff" or kind == "summon" else Pal.GOOD, 0.4, {"n": 8})
			_snd("foe_cast", 1.0, 0.06)
			if kind == "debuff" and on == "hero":
				# What it does to the hero is seen crossing the arena.
				BattleFx.bolt(_fx_layer, _mid(who) + Vector2(-14, -6), _mid("hero"), Pal.ACCENT2, 0.24)
		else:
			var far = -38.0 if kind == "heavy" or kind == "bomb" else -26.0
			var tw = nd.view.create_tween()
			nd.view.position = nd.home
			tw.tween_property(nd.view, "position", nd.home + Vector2(8, 0), 0.07 / float(speed))
			tw.tween_property(nd.view, "position", nd.home + Vector2(far, 0), 0.08 / float(speed)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.14 / float(speed))
			tw.tween_property(nd.view, "position", nd.home, 0.16 / float(speed)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			_moving.append(tw)
			_snd("foe_act", 0.8 if kind == "heavy" else 1.0, 0.08)
	return 0.3


func _show_dmg(e: Dictionary) -> float:
	var dst = str(e.get("dst", ""))
	var src = str(e.get("src", ""))
	var amount = int(e.get("amount", 0))
	var school = str(e.get("school", ""))
	var crit = bool(e.get("crit", false))
	var weak = bool(e.get("weak", false))
	var resist = bool(e.get("resist", false))
	var soaked = amount == 0 and int(e.get("absorbed", 0)) > 0
	_act_dmg += amount
	var tail = ""
	if crit:
		tail = " Crit!"
	elif weak:
		tail = " Weak!"
	elif resist:
		tail = " Resisted."
	elif soaked:
		tail = " The shield holds."
	if bool(e.get("counter", false)):
		_say("%s strike%s back: %d damage." % [_name(src), "" if src == "hero" else "s", amount])
	else:
		_say("%s: %d damage.%s" % [_act_head if _act_head != "" else "A hit", _act_dmg, tail])
	var first = _act_first
	_act_first = false
	if dst == "hero":
		var most = int(B.hero.hp_max)
		_hero_plate.set_hp(int(e.get("hp", 0)), most, true)
		_low_hp(int(e.get("hp", 0)))
		var big = float(amount) >= 0.15 * float(most)
		var at = _mid("hero")
		var col = RpgUi.color(school) if school != "" and school != "plain" else Pal.DANGER
		if soaked:
			_fx("shield", at, RpgUi.color("grit"), 0.45)
			_word("hero", "SHIELD", RpgUi.color("grit"), 1)
			_snd("absorb")
			return 0.3
		_num("hero", str(amount) + ("!" if crit else ""), Pal.DANGER, 3 if crit or big else 2, crit)
		match _act_kind:
			"multi":
				_fx("bite", at, col, 0.3)
			"heavy", "bomb":
				_fx("impact", at, col, 0.34, {"n": 12})
				_fx("dust", _feet("hero"), Pal.MUTED, 0.34)
			"drain":
				_fx("drops", at, col, 0.4)
				_fx("ring", at, col, 0.4)
			_:
				_fx("slash", at, col, 0.28, {"flip": true})
		if _guard_shown:
			_fx("block", at + Vector2(14, 0), RpgUi.color("grit"), 0.3)
			_word("hero", "BLOCK", RpgUi.color("grit"), 1, 0.05, 8.0)
			_snd("block", 1.0, 0.05)
			_knock("hero", -3.0)
		else:
			_pose("hurt", 0.36)
			_knock("hero", -12.0 if big else -7.0)
			_tint("hero", Color(1.45, 0.72, 0.72))
			_snd("hurt_big" if big else "hurt", 1.0, 0.05)
		if not instant:
			Kit.pop(_hero_plate, 1.03, 0.18)
		if big:
			_shake(1.3 if crit else 1.0)
			RpgSfx.buzz(2)
			if not instant:
				BattleFx.flash(_arena, Pal.DANGER, 0.22, 0.2)
		else:
			_shake(0.4)
		return 0.36
	var nd = _foes.get(dst)
	if nd == null:
		return 0.0
	nd.unit["hp"] = int(e.get("hp", 0))
	nd.unit["guard"] = int(e.get("guard", 0))
	nd.plate.set_hp(int(e.get("hp", 0)), int(nd.unit.get("hp_max", 1)), true)
	nd.plate.set_guard(int(e.get("guard", 0)), int(nd.unit.get("guard_max", 0)))
	if soaked:
		_fx("shield", _mid(dst), Pal.MUTED, 0.45)
		_word(dst, "SHIELD", Pal.MUTED, 1)
		_snd("absorb", 0.9)
		return 0.3
	nd.view.hit()
	var ult = _act_kind == "ult" and _act_who == "hero"
	var col2 = Pal.TEXT
	var px = 2
	if crit:
		col2 = Pal.ACCENT
		px = 3
	elif weak:
		col2 = RpgUi.color(school)
	elif resist:
		col2 = Pal.MUTED
	_num(dst, str(amount) + ("!" if crit else ""), col2, px, crit or ult)
	if crit:
		_word(dst, "CRIT!", Pal.ACCENT, 1, 0.04, 12.0)
	if weak:
		_word(dst, "WEAK", RpgUi.color(school), 2 if not crit else 1, 0.08, 0.0 if not crit else 24.0)
	elif resist:
		_word(dst, "RESIST", Pal.MUTED, 1, 0.06)
		_teach("resist")
		if not nd.known.resist.has(school):
			nd.known.resist.append(school)
			nd.plate.set_known(nd.unit.get("weak", []).size(), nd.known)
	var fx_school = school if school != "" else "plain"
	if not instant:
		BattleFx.strike(_fx_layer, fx_school, _mid(dst), _feet(dst), RpgUi.color(fx_school), crit or ult or _act_heavy)
		Kit.burst(nd.view, RpgUi.color(fx_school), 14 if crit else 6)
	_knock(dst, 5.0 if resist else (12.0 if crit or ult else 8.0))
	var wait = 0.34
	if ult and first:
		_snd("ult_hit")
		_shake(1.6)
		RpgSfx.buzz(3)
		if not instant:
			BattleFx.flash(_arena, Color(1, 1, 1), 0.6, 0.3)
			# An ultimate lands as a storm, not as one blow: bursts all round the foe, a wide ring in gold.
			var at2 = _mid(dst)
			var spots = [Vector2(-26, -18), Vector2(24, -10), Vector2(-14, 16), Vector2(20, 20), Vector2(0, -28)]
			for i in range(spots.size()):
				_fx("impact", at2 + spots[i], Pal.ACCENT if i % 2 == 0 else RpgUi.color(fx_school), 0.3, {"delay": 0.05 + 0.06 * float(i), "n": 10})
			_fx("ring", at2, Pal.ACCENT, 0.5, {"u": 5.0, "half": 14.0})
			_fx("sparkle", at2, Color(1, 1, 1), 0.8, {"n": 14, "half": 26.0, "delay": 0.1})
		wait = 0.62
	else:
		if not instant:
			RpgSfx.hit(fx_school, crit, weak, resist)
		if crit:
			_shake(0.9)
			RpgSfx.buzz(1)
			if not instant:
				BattleFx.flash(_arena, Color(1, 1, 1), 0.3, 0.14)
			wait = 0.44
		elif _act_heavy and _act_who == "hero":
			_shake(0.8)
			RpgSfx.buzz(1)
			wait = 0.4
		elif weak:
			_shake(0.45)
	# The blow that fells a foe fells it NOW, not a beat later after whatever else the blow set off.
	if int(e.get("hp", 1)) <= 0 and _ko_ahead(dst):
		_ko_done[dst] = true
		var line = _line.text if _line != null else ""
		wait = maxf(wait, _show_ko(dst))
		_say("%s %s is down." % [line, _name(dst)])
	return wait


func _show_status(e: Dictionary) -> float:
	var dst = str(e.get("dst", ""))
	var id = str(e.get("id", ""))
	var row = RpgDefs.STATUS.get(id, {})
	var nm = str(row.get("name", id.capitalize()))
	if bool(e.get("resisted", false)) or bool(e.get("bounced", false)):
		_word(dst, "NO EFFECT", Pal.MUTED, 1)
		_snd("resist", 1.2)
		_say("%s shrug%s off %s." % [_name(dst), "" if dst == "hero" else "s", nm])
		return 0.24
	var on = bool(e.get("on", true))
	var list = _hero_statuses
	var nd = _foes.get(dst)
	if dst != "hero":
		if nd == null:
			return 0.0
		list = nd.unit.get("statuses", [])
	for i in range(list.size() - 1, -1, -1):
		if str(list[i].get("id", "")) == id:
			list.remove_at(i)
	if on:
		list.append({"id": id, "turns": int(e.get("turns", 0)), "stacks": int(e.get("stacks", 1)), "amount": float(e.get("amount", 0.0))})
	if dst == "hero":
		_hero_plate.set_statuses(list)
	else:
		nd.unit["statuses"] = list
		nd.plate.set_statuses(list, bool(nd.unit.get("broken", false)))
	_status_fx()
	if not on:
		return 0.0
	var good = str(row.get("kind", "debuff")) == "buff"
	# Good for the one who has it; a foe's gain is the hero's worry, so it is not drawn green.
	var col = (Pal.GOOD if dst == "hero" else Pal.ACCENT2) if good else (Pal.ACCENT2 if dst == "hero" else RpgUi.color("mind"))
	_word(dst, nm.to_upper(), col, 1, 0.1)
	var at = _mid(dst)
	match id:
		"shield":
			_fx("shield", at, RpgUi.color("grit") if dst == "hero" else Pal.MUTED, 0.5)
			_snd("shield")
			if dst != "hero":
				_teach("shield")
		"stun":
			_snd("stun")
			if dst == "hero":
				_teach("stun")
		"burn":
			_fx("flame", at + Vector2(0, 6), Pal.ACCENT2, 0.5)
			_snd("burn")
			if dst == "hero":
				_teach("dot")
		"bleed":
			_fx("drops", at, Pal.DANGER, 0.45)
			_snd("bleed")
			if dst == "hero":
				_teach("dot")
		_:
			_fx("up" if good else "down", at, col, 0.5)
			_snd("buff" if good else "debuff", 1.0, 0.04)
	if STATES.has(id):
		_say("%s %s %s." % [_name(dst), "are" if dst == "hero" else "is", nm])
	else:
		_say("%s %s %s." % [_name(dst), "have" if dst == "hero" else "has", "a Shield" if id == "shield" else nm])
	return 0.26


func _show_break(dst: String) -> float:
	var nd = _foes.get(dst)
	if nd == null:
		return 0.0
	nd.unit["broken"] = true
	nd.unit["guard"] = 0
	nd.plate.set_guard(0, int(nd.unit.get("guard_max", 0)))
	nd.plate.set_statuses(nd.unit.get("statuses", []), true)
	var at = _mid(dst)
	_word(dst, "BREAK!", Pal.ACCENT, 3, 0.05, 10.0)
	_fx("shards", at, Pal.ACCENT, 0.6, {"n": 16})
	_fx("ring", at, Color(1, 1, 1), 0.4)
	_knock(dst, 14.0)
	_shake(1.1)
	if not instant:
		BattleFx.flash(_arena, Color(1, 1, 1), 0.4, 0.2)
		Kit.burst(nd.view, Pal.ACCENT, 20)
		Kit.pop(nd.plate, 1.1, 0.24)
	_snd("break")
	RpgSfx.buzz(2)
	_status_fx()
	_teach("break")
	_say("%s's guard breaks: it loses its next action." % _name(dst))
	return 0.6


func _show_ko(dst: String) -> float:
	if dst == "hero":
		_end_pose = "hurt"
		_kill(_pose_tw)
		_pose_rest()
		_low_hp(0)
		_snd("down")
		_shake(1.2)
		_dim_back(0.5, 1.0)
		_say("You are knocked down.")
		return 0.6
	var nd = _foes.get(dst)
	if nd == null:
		return 0.0
	nd.unit["alive"] = false
	nd.unit["hp"] = 0
	nd.unit["intent"] = {}
	nd.plate.set_hp(0, int(nd.unit.get("hp_max", 1)), true)
	nd.plate.set_intent({})
	nd.plate.set_down(true)
	nd.view.set_marked(false)
	nd.view.faint()
	nd.hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_fx()
	var big = bool(nd.unit.get("boss", false)) or bool(nd.unit.get("elite", false))
	_fx("poof", _mid(dst), Pal.MUTED, 0.6, {"delay": 0.18})
	_fx("sparkle", _mid(dst), Pal.ACCENT, 0.7, {"delay": 0.25, "n": 8 if big else 5})
	_snd("ko", 0.8 if big else 1.0, 0.05)
	if big:
		_shake(1.4)
		RpgSfx.buzz(3)
		if not instant:
			BattleFx.flash(_arena, Color(1, 1, 1), 0.55, 0.4)
			Kit.burst(nd.view, Pal.ACCENT, 30)
	_say("%s is down." % _name(dst))
	return 0.7 if big else 0.45


func _show_learn(e: Dictionary) -> float:
	var key = str(e.get("key", ""))
	var school = str(e.get("school", ""))
	var who = ""
	var who_id = ""
	for id in _foes:
		var nd = _foes[id]
		if RpgBattle.seen_key(nd.unit) != key:
			continue
		who = str(nd.unit.get("name", ""))
		if who_id == "" and bool(nd.unit.get("alive", true)):
			who_id = str(id)
		if not nd.known.weak.has(school):
			nd.known.weak.append(school)
			nd.plate.set_known(nd.unit.get("weak", []).size(), nd.known)
	if who == "":
		return 0.0
	var line = "%s is weak to %s" % [who, _schools([school])]
	if not _learned.has(line):
		_learned.append(line)
		if who_id != "":
			_word(who_id, "WEAKNESS FOUND", RpgUi.color(school), 1, 0.2, 30.0)
		_snd("learn_weak")
	_say("Learned: %s." % line)
	return 0.3


## Foes that have just come step in from the right, one after the other.
func _enter_foes(ids: Array) -> void:
	if instant:
		return
	var i = 0
	for id in ids:
		var nd = _foes.get(str(id))
		if nd == null:
			continue
		nd.view.position = nd.home + Vector2(110.0, 0)
		nd.view.modulate.a = 0.0
		var tw = nd.view.create_tween()
		tw.tween_interval(0.08 * float(i) / float(speed))
		tw.tween_property(nd.view, "position", nd.home, 0.22 / float(speed)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(nd.view, "modulate:a", 1.0, 0.1 / float(speed))
		tw.tween_callback(_foe_dust.bind(str(id)))
		_moving.append(tw)
		i += 1


func _foe_dust(id: String) -> void:
	if _foes.has(id):
		_fx("dust", _feet(id) + Vector2(0, -2.0), Pal.MUTED, 0.3)


## The hour this fight is fought at: "day" | "dusk" | "night" | "boss". A stage of a road goes by its number
## (1 to 3 by day, 4 to 6 at dusk, 7 to 9 at night, the boss at its own dark hour); everything else by day,
## but a fight with a boss in it is always the boss's hour.
func hour() -> String:
	if _has_boss():
		return "boss"
	var what = B.get("what", {})
	var id = str(what.get("id", "")) if what is Dictionary else ""
	var at = id.rfind("s")
	if (str(what.get("kind", "")) == "stage" or str(what.get("kind", "")) == "echo") and at > 0 and id.substr(at + 1).is_valid_int():
		var n = int(id.substr(at + 1))
		if n >= 7:
			return "night"
		if n >= 4:
			return "dusk"
	return "day"


## Does a boss wait in any wave of this battle (its music is the boss's from the start)?
func _has_boss() -> bool:
	for f in B.get("foes", []):
		if f is Dictionary and bool(f.get("boss", false)):
			return true
	for wave in B.get("waves", []):
		if not (wave is Array):
			continue
		for en in wave:
			if not (en is Dictionary):
				continue
			var row = en.get("row") if en.get("row") is Dictionary else RpgBattle.foe_row(B, str(en.get("foe", "")))
			if row != null and bool(row.get("boss", false)):
				return true
	return false


func _exit_tree() -> void:
	if _held:
		_held = false
		RpgSfx.hold(-1, true)


## The boss of the wave on screen ("" when it has none).
func _boss_here() -> String:
	for id in _foes:
		if bool(_foes[id].unit.get("boss", false)):
			return str(id)
	return ""


func _show_new_wave(e: Dictionary) -> float:
	var n = int(e.get("n", 1))
	var of = int(e.get("of", 1))
	for id in _foes.keys():
		_drop_foe(str(id))
	for u in e.get("units", []):
		if u is Dictionary:
			_add_foe(u)
	_fix_target()
	_place_foes()
	_foe_layer.modulate.a = 1.0
	for id in _foes:
		_foes[id].hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_enter_foes(_foes.keys())
	_show_wave(n, of)
	if n > 1:
		_hero_statuses = []
		_hero_plate.set_statuses(_hero_statuses)
	var boss = _boss_here()
	if boss != "" and not instant:
		# The boss steps out: the arena goes dark, its name crosses it.
		_dim_back(0.6, 1.1)
		BattleFx.cutin(_fx_layer, _name(boss).to_upper(), Pal.DANGER, 0.8, "BOSS")
		_snd("boss")
		RpgSfx.buzz(2)
		_say("%s stands in your way." % _name(boss))
		return 1.35
	_snd("wave" if n > 1 else "enter")
	if not instant:
		BattleWidgets.banner(_fx_layer, "FIGHT!" if of <= 1 else "WAVE %d/%d" % [n, of], Pal.TEXT, 0.4 / float(speed))
	_say("Wave %d of %d." % [n, of] if of > 1 else "The fight begins.")
	return 0.65 if n > 1 else 0.45


func _show_end(win: bool) -> float:
	if bool(B.get("fled", false)):
		return 0.15
	_kill(_pose_tw)
	_guard_shown = false
	_end_pose = "flex" if win else "hurt"
	_pose_rest()
	_low_hp(0)
	if win:
		if not instant:
			BattleWidgets.banner(_fx_layer, "VICTORY", Pal.ACCENT, 0.7 / float(speed))
			BattleFx.flash(_arena, Pal.ACCENT, 0.3, 0.4)
			for i in range(3):
				_fx("sparkle", Vector2(_fx_layer.size.x * (0.25 + 0.25 * float(i)), _fx_layer.size.y * 0.35), Pal.ACCENT, 0.9, {"n": 8, "delay": 0.1 * float(i), "half": 26.0})
			if _hero_view != null:
				Kit.burst(_hero_view, Pal.ACCENT, 22)
		_say("You win!")
		_snd("victory")
		RpgSfx.buzz(3)
		return 1.0
	if not instant:
		BattleWidgets.banner(_fx_layer, "KNOCKED DOWN", Pal.MUTED, 0.7 / float(speed), 2)
	_say("You are knocked down. Nothing is lost.")
	_snd("defeat")
	return 0.9


## The fight opens: the screen comes up out of the dark and the hero runs in. The opening's own events (the
## first wave among them) are played after it.
func _intro(first: Array) -> void:
	_gen += 1
	var gen = _gen
	_busy = true
	_events = []
	_dim_keys(true)
	_foe_layer.modulate.a = 0.0
	var cover = ColorRect.new()
	cover.color = Color(0.02, 0.02, 0.05, 1.0)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ctw = cover.create_tween()
	ctw.tween_property(cover, "color:a", 0.0, 0.3)
	ctw.tween_callback(cover.queue_free)
	if _hero_view != null:
		_hero_view.position = _hero_home + Vector2(-120, 0)
		_hero_tw = _hero_view.create_tween()
		_hero_tw.tween_interval(0.08)
		_hero_tw.tween_property(_hero_view, "position", _hero_home, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hero_tw.tween_callback(_hero_dust)
		_moving.append(_hero_tw)
	await _wait(0.4)
	if not _alive(gen):
		return
	if first.is_empty():
		_end_playback()
	else:
		_play(first)


## Give a hint of HINTS, if it was never given: its band comes up for a few seconds, and the caller is told.
func _teach(id: String) -> void:
	if _tip == null or instant or _hints_given.has(id) or not HINTS.has(id) or _closed:
		return
	# One at a time: while a hint is still being read, the next one waits for its next occasion.
	if Time.get_ticks_msec() - _tip_at < 3500:
		return
	_tip_at = Time.get_ticks_msec()
	_hints_given[id] = true
	_tip.text = str(HINTS[id])
	_tip.set_meta("bv_tip", id)
	# Over the foes' plates when there is sky for it (it covers no fighter there), else at the arena's foot.
	var top = _arena.size.y
	for fid in _foes:
		if _foes[fid].plate != null:
			top = minf(top, _foes[fid].plate.position.y)
	if top - 44.0 >= 4.0:
		_rect(_tip, 6, floor(top - 44.0), _arena.size.x - 12.0, 38)
	else:
		_rect(_tip, 6, _arena.size.y - 40.0, _arena.size.x - 12.0, 38)
	_kill(_tip_tw)
	_tip_tw = create_tween()
	_tip_tw.tween_property(_tip, "modulate:a", 1.0, 0.2)
	_tip_tw.tween_interval(HINT_SECS)
	_tip_tw.tween_property(_tip, "modulate:a", 0.0, 0.4)
	var cb = _opts.get("on_hint")
	if cb is Callable and cb.is_valid():
		cb.call(id)


## The keys go quiet while something plays (they still hear a tap: it skips).
func _dim_keys(on: bool) -> void:
	var c = Color(1, 1, 1, 0.62) if on and not instant else Color.WHITE
	if _moves != null:
		_moves.modulate = c
	if _acts != null:
		_acts.modulate = c


## The poses' textures are made once at the start, so the first strike does not stutter.
func _warm() -> void:
	var hero = _opts.get("hero")
	for p in POSES:
		await _wait(0.03)
		if not is_inside_tree() or _closed:
			return
		Art.hero_texture(hero.state, hero.profile, hero.get("loadout", {}), p, 0, false)


func _process(delta: float) -> void:
	if not _built or _closed:
		return
	# While a finger scrolls a page (a sheet over the fight) the hero and the companion stand still too.
	if TouchScroll.scrolling != _still:
		_still = TouchScroll.scrolling
		if _hero_view != null:
			_hero_view.set_process(not _still)
		if _pet_view != null:
			_pet_view.set_process(not _still)
	if _hero_view != null and _hero_view.position != _shadow_at:
		_hero_shadow()
	# The only looping decoration of the view itself: the ultimate's key glows when it is ready.
	if _still or not is_visible_in_tree() or _result != null:
		return
	var key = _act.get("ult")
	if key == null or not bool(key.get_meta("bv_lit", false)):
		return
	_pulse += delta
	var v = 1.0 + 0.16 * (0.5 + 0.5 * sin(_pulse * 5.0))
	key.modulate = Color(v, v, v, 1.0)


# =============================================================================
# Sheets
# =============================================================================

func _sheet_up(s) -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = s
	s.open()


## A unit in words: its numbers, its statuses, and for a foe what is known of its schools and its ways.
func _open_unit(id: String) -> void:
	if _tap_guard():
		return
	var u = RpgBattle.unit(B, id)
	if u == null:
		return
	Sfx.tap()
	var s = Kit.sheet("You" if id == "hero" else str(u.get("name", "")))
	s.set_meta("bv_sheet", id)
	var facts = Kit.flow(6)
	facts.add_child(Kit.pill("heart", "%d / %d" % [int(u.hp), int(u.hp_max)], BattleWidgets.hp_color(float(u.hp) / maxf(1.0, float(u.hp_max)))))
	if id == "hero":
		facts.add_child(Kit.pill("energy", "Energy %d / %d" % [int(u.en), int(u.en_max)], Pal.ACCENT))
		facts.add_child(Kit.pill("gauge", "Gauge %d%%" % int(floor(float(u.get("gauge", 0.0)))), RpgUi.color("grit")))
	else:
		facts.add_child(Kit.pill("guard_pip", "Guard %d / %d" % [int(u.get("guard", 0)), int(u.get("guard_max", 0))], Pal.SECOND, "", Pal.TEXT))
	s.box.add_child(facts)
	if id != "hero":
		var kn = RpgBattle.known(B, id)
		var weak = Kit.flow(6)
		weak.add_child(Kit.label("Weak to", 13, Pal.MUTED, true))
		for sc in kn.weak:
			weak.add_child(Kit.icon_chip(RpgUi.school_icon(str(sc)), str(RpgDefs.SCHOOL_NAMES.get(str(sc), sc)), RpgUi.color(str(sc))))
		for i in range(maxi(0, u.get("weak", []).size() - kn.weak.size())):
			weak.add_child(Kit.tag("?", Pal.MUTED))
		s.box.add_child(weak)
		if not kn.resist.is_empty():
			var res = Kit.flow(6)
			res.add_child(Kit.label("Resists", 13, Pal.MUTED, true))
			for sc in kn.resist:
				res.add_child(Kit.icon_chip(RpgUi.school_icon(str(sc)), str(RpgDefs.SCHOOL_NAMES.get(str(sc), sc)), Pal.PANEL2))
			s.box.add_child(res)
		var it = u.get("intent", {})
		if it is Dictionary and not it.is_empty():
			var words = BattleWidgets.IntentTag.words(it, true)
			var dmg = int(round(float(it.get("dmg", 0))))
			var next = "Next: %s" % str(it.get("name", ""))
			if dmg > 0:
				next += " · %d damage" % dmg
			elif words != "" and words != str(it.get("name", "")):
				next += " · %s" % words
			s.box.add_child(Kit.para(next, 14, null, true))
	s.box.add_child(Kit.sub_head("Statuses", Pal.ACCENT2))
	var any = false
	if bool(u.get("broken", false)):
		any = true
		s.box.add_child(_status_line({"id": "broken"}, "Broken: loses its next action and takes 40% more damage."))
	for st in u.get("statuses", []):
		any = true
		s.box.add_child(_status_line(st, RpgUi.status_words(st)))
	if not any:
		s.box.add_child(Kit.muted("None right now.", 13))
	if id == "hero":
		s.box.add_child(Kit.sub_head("Your moves", RpgUi.color("realm")))
		for mid in u.get("moves", []):
			var row = RpgBattle.move_row(B, str(mid))
			if row != null:
				s.box.add_child(RpgUi.move_card(row))
		var ult = RpgBattle.move_row(B, str(u.get("ult", ""))) if str(u.get("ult", "")) != "" else null
		if ult != null:
			s.box.add_child(RpgUi.move_card(ult))
	else:
		var foe_row = RpgFoes.by_id(str(u.get("foe", "")))
		if foe_row == null and B.get("custom") is Dictionary:
			foe_row = B.custom.get("foes", {}).get(str(u.get("foe", "")))
		if foe_row is Dictionary:
			s.box.add_child(Kit.sub_head("What it does", Pal.DANGER))
			for w in RpgFoes.words(RpgFoes.full(foe_row) if not foe_row.has("moves") else foe_row):
				s.box.add_child(Kit.para("· " + str(w), 13))
			if str(foe_row.get("text", "")) != "":
				s.box.add_child(Kit.muted_para(str(foe_row.text), 12))
	_sheet_up(s)


func _status_line(st: Dictionary, words: String) -> Control:
	var row = Kit.hbox(8)
	row.add_child(RpgUi.status_icon(st, 32))
	var l = Kit.para(words, 13)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


## The belt: a row per item, a key to use it.
func _open_items() -> void:
	var o = RpgBattle.options(B)
	if o.items.is_empty():
		_refuse("Your belt is empty.")
		return
	if B.rules.has("no_items"):
		_refuse(_why("rule", {}))
		return
	Sfx.tap()
	var s = Kit.sheet("Belt")
	s.set_meta("bv_sheet", "items")
	for it in o.items:
		var row = RpgBattle.item_row(B, str(it.id))
		if row == null:
			continue
		var card = Kit.row(Callable(), Pal.ACCENT2, Pal.ACCENT2, 8, 4)
		var line = Kit.hbox(8)
		line.add_child(Icons.rect(str(row.get("icon", "belt")) if Icons.has_icon(str(row.get("icon", ""))) else "belt", 32))
		var v = Kit.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(Kit.clip("%s x%d" % [str(row.get("name", "")), int(it.n)], 15, null, true))
		var why = ""
		if not bool(it.ok):
			why = "None left." if int(it.n) <= 0 else "Used %d times: no more this battle." % int(it.used)
		v.add_child(Kit.para(RpgItems.words(row) if why == "" else why, 12, Pal.MUTED))
		line.add_child(v)
		var use = Kit.button("Use", "primary", _use_item.bind(str(it.id), s), "md")
		use.custom_minimum_size = Vector2(64, 42)
		use.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		use.disabled = not bool(it.ok)
		use.set_meta("bv_item", str(it.id))
		use.set_meta("anchor_id", "bv_item:" + str(it.id))
		line.add_child(use)
		card.add(line)
		s.box.add_child(card)
	_sheet_up(s)


func _use_item(id: String, s) -> void:
	if s != null and is_instance_valid(s):
		s.close()
	_do({"t": "item", "id": id})


# =============================================================================
# The end
# =============================================================================

func _show_result() -> void:
	if _result != null or _closed:
		return
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null
	var s = RpgBattle.summary(B)
	var info = null
	var cb = _opts.get("result")
	if cb is Callable and cb.is_valid():
		info = cb.call(B, s)
	if not (info is Dictionary):
		info = _plain_info(s)
	if _held:
		RpgSfx.tune("result")
	# The result's own picture: the hero where the fight was (BattleResult's tableau).
	if not info.has("scene"):
		info["scene"] = str(_opts.get("scene", ""))
	# (the hour the fight was fought at: the result's picture is seen in the same light)
	info["light"] = HOURS.get(hour(), Color(1, 1, 1))
	if not info.has("hero") and _hero_view != null:
		info["hero"] = _opts.get("hero")
		info["hero_fit"] = {"top": _hero_top, "low": _hero_low, "mid": _hero_mid}
	# What is under the result stands still (nothing in a hidden arena loops).
	_arena.visible = false
	_result = BattleResult.new()
	add_child(_result)
	_result.setup(s, info)
	_result.chosen.connect(_leave)


## The result when the caller gave none: who won, and what was learned.
func _plain_info(s: Dictionary) -> Dictionary:
	var lines = _learned.duplicate()
	var found = s.get("learned", {})
	if found is Dictionary:
		for key in found:
			var row = RpgFoes.by_id(str(key).split("#")[0])
			var nm = str(row.name) if row != null else str(key).capitalize()
			for sc in found[key]:
				var line = "%s is weak to %s" % [nm, _schools([str(sc)])]
				if not lines.has(line):
					lines.append(line)
	return {"win": bool(s.get("win", false)), "title": str(_opts.get("title", "")), "stars": null, "objectives": null,
		"rewards": null, "learned": lines, "next": bool(_opts.get("next", false)) and bool(s.get("win", false))}


func _leave(what: String) -> void:
	if _closed:
		return
	_closed = true
	_gen += 1
	choice = what
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	finished.emit(B, RpgBattle.summary(B))
	closed.emit()
	queue_free()


## Take the view down without a result (the caller's own reasons). `finished` is not emitted.
func close() -> void:
	if _closed:
		return
	_closed = true
	_gen += 1
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	closed.emit()
	queue_free()
