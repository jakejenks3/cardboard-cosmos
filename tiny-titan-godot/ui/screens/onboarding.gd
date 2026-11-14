class_name OnboardingScreen
extends Control
## First launch: name your hero, pick a look, choose units and a weekly goal.

var _name = ""
var _skin = 1
var _hair_style = 0
var _hair_color = 0
var _step = 0

var _box: VBoxContainer
var _blank: Dictionary
var _hero: HeroView = null
var _next: Button = null


func _ready() -> void:
	_blank = Derive.derive({"sessions": [], "claims": [], "body": [], "weeklyGoal": 3, "today": App.today})
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	_box = Kit.vbox(14)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var holder = Kit.pad(_box, 18, 28, 18, 28)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	_build()


func _profile() -> Dictionary:
	return {"name": _name if _name != "" else "Hero", "skin": _skin, "hairStyle": _hair_style, "hairColor": _hair_color, "createdAt": 0}


func _build() -> void:
	Kit.clear(_box)
	var brand = PixelFont.rect("TINY TITAN", 4, Pal.ACCENT)
	brand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(brand)

	_hero = HeroView.new()
	_hero.setup(_blank, _profile(), App.DEFAULT_LOADOUT, null, false)
	_hero.custom_minimum_size = Vector2(Art.HERO_W * 4, Art.HERO_H * 4)
	_hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_hero)

	var card = Kit.card(12, Callable(), 18)
	_box.add_child(card)
	match _step:
		0:
			card.add(Kit.h1("Every titan starts tiny."))
			card.add(Kit.muted_para("Log your lifts, climbs, runs and rides and watch this scrawny little hero turn into an absolute unit. Gear, pets, bosses and quests along the way.", 14))
			var input = Kit.input(_name, "e.g. Jake")
			input.max_length = 20
			input.text_changed.connect(_name_typed)
			input.text_submitted.connect(_name_submitted)
			card.add(Kit.field("What should we call your hero?", input))
			_next = Kit.button("Next →", "primary", _go.bind(1), "lg")
			_next.disabled = _name.strip_edges() == ""
			card.add(_next)
			input.call_deferred("grab_focus")
		1:
			card.add(Kit.h1("Make it yours."))
			card.add(Parts.appearance_editor(_skin, _hair_style, _hair_color, _look_changed))
			var row = Kit.hbox(12)
			row.add_child(Kit.button("← Back", "ghost", _go.bind(0)))
			row.add_child(Kit.expand(Kit.button("Next →", "primary", _go.bind(2), "lg")))
			card.add(row)
		_:
			var settings = App.settings()
			card.add(Kit.h1("Units & goals."))
			card.add(Kit.field("Weight", Kit.segmented([{"value": "kg", "label": "kg"}, {"value": "lb", "label": "lb"}], settings.weightUnit, _set_weight_unit)))
			card.add(Kit.field("Distance", Kit.segmented([{"value": "km", "label": "km"}, {"value": "mi", "label": "miles"}], settings.distanceUnit, _set_distance_unit)))
			var goals = []
			for n in [2, 3, 4, 5, 6]:
				goals.append({"value": n, "label": str(n)})
			card.add(Kit.field("Weekly goal (sessions per week to keep your streak alive)", Kit.segmented(goals, int(settings.weeklyGoal), _set_goal)))
			var row2 = Kit.hbox(12)
			row2.add_child(Kit.button("← Back", "ghost", _go.bind(1)))
			row2.add_child(Kit.expand(Kit.button("Start my journey", "good", _finish, "lg", "rocket")))
			card.add(row2)


func _name_typed(t: String) -> void:
	_name = t
	if is_instance_valid(_next):
		_next.disabled = t.strip_edges() == ""
	if is_instance_valid(_hero):
		_hero.setup(_blank, _profile(), App.DEFAULT_LOADOUT, null, false)


func _name_submitted(_t: String) -> void:
	if _name.strip_edges() != "":
		_go(1)


func _go(step: int) -> void:
	Sfx.tap()
	_step = step
	_build()


func _look_changed(patch: Dictionary) -> void:
	Sfx.tick()
	if patch.has("skin"):
		_skin = patch.skin
	if patch.has("hairStyle"):
		_hair_style = patch.hairStyle
	if patch.has("hairColor"):
		_hair_color = patch.hairColor
	_build()


func _set_weight_unit(v) -> void:
	App.update_settings({"weightUnit": v})


func _set_distance_unit(v) -> void:
	App.update_settings({"distanceUnit": v})


func _set_goal(v) -> void:
	App.update_settings({"weeklyGoal": int(v)})


func _finish() -> void:
	Sfx.level_up()
	App.set_profile({"name": _name.strip_edges(), "skin": _skin, "hairStyle": _hair_style, "hairColor": _hair_color, "createdAt": App.now_ms()})
