class_name Stepper
extends HBoxContainer
## A number field with − / + buttons. Tap to step, hold to repeat, or click the
## number and type. Emits `changed(text)` whenever the text changes.

signal changed(text)

var text: String = ""
var step: float = 1.0
var min_value: float = 0.0
var max_value = null
## Snap to multiples of `step` (plate maths) instead of adding it.
var snap: bool = false
## Where + / − start from when the field is empty (e.g. last time's value).
var base = null

var _edit: LineEdit
var _minus: Button
var _plus: Button
var _dir: int = 0
var _held: bool = false
var _hold_time: float = 0.0
var _repeat_time: float = 0.0

const HOLD_DELAY = 0.38
const REPEAT_EVERY = 0.09


func setup(value: String, step_size: float = 1.0, opts: Dictionary = {}) -> void:
	text = value
	step = step_size
	min_value = float(opts.get("min", 0.0))
	max_value = opts.get("max", null)
	snap = bool(opts.get("snap", false))
	base = opts.get("base", null)
	add_theme_constant_override("separation", 4)
	if _edit == null:
		_minus = _make_btn("minus")
		add_child(_minus)
		_edit = Kit.input(text, str(opts.get("placeholder", "")), true)
		_edit.custom_minimum_size = Vector2(float(opts.get("width", 58)), 42)
		_edit.text_changed.connect(_typed)
		add_child(_edit)
		_plus = _make_btn("plus")
		add_child(_plus)
		_minus.button_down.connect(_down.bind(-1))
		_plus.button_down.connect(_down.bind(1))
		_minus.button_up.connect(_up)
		_plus.button_up.connect(_up)
	else:
		_edit.text = text
		_edit.placeholder_text = str(opts.get("placeholder", ""))
	set_process(false)


## The current value as a number, or null when empty / not a number.
func number():
	var t = text.strip_edges().replace(",", ".")
	if t == "" or not t.is_valid_float():
		return null
	return t.to_float()


## Set the text without emitting `changed`.
func set_text(value: String) -> void:
	text = value
	if _edit != null and _edit.text != value:
		_edit.text = value


func set_placeholder(p: String) -> void:
	if _edit != null:
		_edit.placeholder_text = p


func _make_btn(icon: String) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(38, 42)
	b.text = "−" if icon == "minus" else "+"
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", Kit.sbox(Pal.PANEL2, 10, Pal.LINE, 1, 4, 4))
	b.add_theme_stylebox_override("hover", Kit.sbox(Pal.PANEL2.lightened(0.08), 10, Pal.LINE, 1, 4, 4))
	b.add_theme_stylebox_override("pressed", Kit.sbox(Pal.ACCENT, 10, Pal.ACCENT, 1, 4, 4))
	b.add_theme_color_override("font_pressed_color", Pal.INK)
	return b


func _typed(t: String) -> void:
	text = t
	changed.emit(text)


func _down(dir: int) -> void:
	_dir = dir
	_held = false
	_hold_time = 0.0
	_repeat_time = 0.0
	_bump(dir)
	set_process(true)


func _up() -> void:
	_dir = 0
	set_process(false)


func _process(delta: float) -> void:
	if _dir == 0:
		set_process(false)
		return
	_hold_time += delta
	if _hold_time < HOLD_DELAY:
		return
	_repeat_time += delta
	while _repeat_time >= REPEAT_EVERY:
		_repeat_time -= REPEAT_EVERY
		_bump(_dir)


func _bump(dir: int) -> void:
	var cur = number()
	var next: float
	if cur == null:
		if base != null:
			next = float(base) if dir > 0 else float(base) - step
		else:
			next = maxf(min_value, step) if dir > 0 else min_value
	elif snap:
		next = LiftHistory.step_value(cur, step, dir, min_value)
	else:
		next = cur + dir * step
	next = maxf(min_value, next)
	if max_value != null:
		next = minf(float(max_value), next)
	var t = TTUtil.num_str(snappedf(next, 0.01))
	if t == text:
		return
	text = t
	_edit.text = t
	Sfx.tick()
	changed.emit(text)
