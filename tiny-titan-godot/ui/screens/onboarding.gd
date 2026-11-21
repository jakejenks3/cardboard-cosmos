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
	_box = Kit.vbox(16)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var holder = Kit.pad(_box, 18, 28, 18, 28)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	_build()


func _profile() -> Dictionary:
	return {"name": _name if _name != "" else "Hero", "skin": _skin, "hairStyle": _hair_style, "hairColor": _hair_color, "createdAt": 0}


const STEP_TITLES = ["NAME YOUR HERO", "MAKE IT YOURS", "SET YOUR GOAL"]


func _build() -> void:
	Kit.clear(_box)
	var brand = PixelFont.rect("TINY TITAN", 4, Pal.ACCENT)
	brand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(brand)

	# The hero stands on a little sunken stage.
	var stage = PanelContainer.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_theme_stylebox_override("panel", PixBox.make(Pal.PANEL, {"ring": Pal.ACCENT, "lip": 2, "lip_color": Pal.OUTLINE.lightened(0.08), "pad_h": 10, "pad_v": 10}))
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hero = HeroView.new()
	_hero.setup(_blank, _profile(), App.DEFAULT_LOADOUT, null, false)
	_hero.custom_minimum_size = Vector2(HeroBody.width() * 5, HeroBody.height() * 5)
	_hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.add_child(_hero)
	_box.add_child(stage)

	_box.add_child(_pips())

	var card = Kit.card(14, Callable(), 18)
	_box.add_child(card)
	var title = PixelFont.rect(STEP_TITLES[mini(_step, 2)], 3, Pal.TEXT)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add(title)
	match _step:
		0:
			var input = Kit.input(_name, "Hero name")
			input.max_length = 20
			input.alignment = HORIZONTAL_ALIGNMENT_CENTER
			input.custom_minimum_size = Vector2(48, 50)
			input.add_theme_font_size_override("font_size", 20)
			input.text_changed.connect(_name_typed)
			input.text_submitted.connect(_name_submitted)
			card.add(input)
			_next = Kit.button("Next →", "primary", _go.bind(1), "lg")
			_next.disabled = _name.strip_edges() == ""
			_next.custom_minimum_size = Vector2(0, 56)
			card.add(_next)
			input.call_deferred("grab_focus")
		1:
			card.add(Parts.appearance_editor(_skin, _hair_style, _hair_color, _look_changed))
			card.add(_nav(0, Kit.button("Next →", "primary", _go.bind(2), "lg")))
		_:
			var settings = App.settings()
			card.add(_choice("scale", Kit.segmented([{"value": "kg", "label": "kg"}, {"value": "lb", "label": "lb"}], settings.weightUnit, _set_weight_unit)))
			card.add(_choice("road", Kit.segmented([{"value": "km", "label": "km"}, {"value": "mi", "label": "miles"}], settings.distanceUnit, _set_distance_unit)))
			var goals = []
			for n in [2, 3, 4, 5, 6]:
				goals.append({"value": n, "label": str(n)})
			var goal = _choice("flame", Kit.segmented(goals, int(settings.weeklyGoal), _set_goal))
			goal.tooltip_text = "Sessions per week that keep your streak alive"
			card.add(goal)
			card.add(JourneyScreen.caption("sessions a week", 12))
			card.add(_nav(1, Kit.button("Start my journey", "good", _finish, "lg", "rocket")))


## Three pixel pips: done and current ones lit gold, the rest sunken.
func _pips() -> Control:
	var row = Kit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(3):
		var pip = PanelContainer.new()
		pip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var lit = i <= _step
		if lit:
			pip.add_theme_stylebox_override("panel", PixBox.make(Pal.ACCENT, {"lip": 1, "lip_color": Pal.ACCENT_DARK, "pad_h": 0, "pad_v": 0}))
		else:
			pip.add_theme_stylebox_override("panel", PixBox.well(0, 0))
		pip.custom_minimum_size = Vector2(56 if i == _step else 34, 26)
		var c = CenterContainer.new()
		c.add_child(PixelFont.rect(str(i + 1), 2, Pal.INK if lit else Pal.MUTED, false))
		pip.add_child(c)
		row.add_child(pip)
	return row


## A Back button and the step's big forward button.
func _nav(back_to: int, forward: Button) -> Control:
	var row = Kit.hbox(10)
	row.add_child(Kit.button("← Back", "ghost", _go.bind(back_to), "lg"))
	forward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forward.custom_minimum_size.y = 56
	row.add_child(forward)
	return row


## icon + a full-width switch.
func _choice(icon: String, control: Control) -> Control:
	var row = Kit.hbox(10)
	row.add_child(Kit.vcenter(Icons.rect(icon, 26)))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


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
