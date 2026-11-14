class_name Stepper
extends HBoxContainer
## A number field with − / + buttons. Tap to step, hold to repeat, or click the
## number and type. Emits `changed(text)` whenever the text changes.
##
## opts `compact: true` draws one joined pill (− | value | +) instead of three
## boxes: quiet muted glyphs, a prominent value, `height` (default 30) tall.
## The children stay − / text box / + in that order either way.

signal changed(text)

var text: String = ""
var step: float = 1.0
var min_value: float = 0.0
var max_value = null
## Snap to multiples of `step` (plate maths) instead of adding it.
var snap: bool = false
## Where + / − start from when the field is empty (e.g. last time's value).
var base = null
var compact: bool = false

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
	if _edit == null:
		compact = bool(opts.get("compact", false))
		var h = float(opts.get("height", 30 if compact else 42))
		add_theme_constant_override("separation", 0 if compact else 4)
		_minus = _make_btn("minus", h)
		add_child(_minus)
		_edit = Kit.input(text, str(opts.get("placeholder", "")), true)
		_edit.custom_minimum_size = Vector2(float(opts.get("width", 58)), h)
		_edit.text_changed.connect(_typed)
		if compact:
			_style_compact_edit(h)
		add_child(_edit)
		_plus = _make_btn("plus", h)
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


func _make_btn(icon: String, h: float = 42.0) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.text = "−" if icon == "minus" else "+"
	if compact:
		# Quiet glyphs inside the pill: no box of their own, a faint wash on hover.
		b.custom_minimum_size = Vector2(28, h)
		b.add_theme_font_size_override("font_size", 17)
		var empty = Kit.sbox(Pal.with_alpha(Pal.WELL, 0.0), 8, null, 0, 0, 0)
		b.add_theme_stylebox_override("normal", empty)
		b.add_theme_stylebox_override("hover", Kit.sbox(Pal.with_alpha(Pal.TEXT, 0.07), 8, null, 0, 0, 0))
		b.add_theme_stylebox_override("pressed", Kit.sbox(Pal.with_alpha(Pal.ACCENT, 0.22), 8, null, 0, 0, 0))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", Pal.MUTED)
		b.add_theme_color_override("font_hover_color", Pal.TEXT)
		b.add_theme_color_override("font_pressed_color", Pal.ACCENT)
		return b
	b.custom_minimum_size = Vector2(38, h)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", Kit.sbox(Pal.PANEL2, 10, Pal.LINE, 1, 4, 4))
	b.add_theme_stylebox_override("hover", Kit.sbox(Pal.PANEL2.lightened(0.08), 10, Pal.LINE, 1, 4, 4))
	b.add_theme_stylebox_override("pressed", Kit.sbox(Pal.ACCENT, 10, Pal.ACCENT, 1, 4, 4))
	b.add_theme_color_override("font_pressed_color", Pal.INK)
	return b


## The value box of a compact stepper: no box of its own (the pill is drawn
## behind it), bold 15 px number, tight padding so "102.5" fits.
func _style_compact_edit(h: float) -> void:
	var pv = int(maxf(0.0, (h - 20.0) / 2.0))
	var clear = Kit.sbox(Pal.with_alpha(Pal.WELL, 0.0), 6, null, 0, 1, pv)
	_edit.add_theme_stylebox_override("normal", clear)
	_edit.add_theme_stylebox_override("focus", clear.duplicate())
	_edit.add_theme_stylebox_override("read_only", clear.duplicate())
	_edit.add_theme_constant_override("minimum_character_width", 0)
	_edit.add_theme_font_size_override("font_size", 15)
	_edit.add_theme_font_override("font", Kit.font_bold())
	_edit.add_theme_color_override("font_color", Pal.TEXT)
	_edit.add_theme_color_override("font_placeholder_color", Pal.with_alpha(Pal.MUTED, 0.6))
	_edit.size_flags_horizontal = Control.SIZE_FILL
	_edit.focus_entered.connect(queue_redraw)
	_edit.focus_exited.connect(queue_redraw)


func _draw() -> void:
	if not compact:
		return
	var focused = _edit != null and _edit.has_focus()
	var box = Kit.sbox(Pal.WELL, 9, Pal.ACCENT if focused else Pal.LINE, 2 if focused else 1, 0, 0)
	draw_style_box(box, Rect2(Vector2.ZERO, size))


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
