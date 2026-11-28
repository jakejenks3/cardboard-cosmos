class_name Stepper
extends HBoxContainer
## A number field with − / + keys. Tap to step, hold to repeat, or click the
## number and type. Emits `changed(text)` whenever the text changes.
##
## Pixel style: the value sits in a sunken well, flanked by two small raised
## keys that sink when pressed. opts `compact: true` makes it slim (`height`,
## default 30) for rows of sets; `font` sets the value's size (big weigh-in).
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

## On a phone a finger that lands on a key may be starting a scroll
## (ui/touch_scroll.gd), so the first step waits for the lift (a tap) or for
## the hold to begin; a scroll calls the press off and nothing changes.
var _touch: bool = false
## Steps made by holding during this press.
var _repeats: int = 0


func setup(value: String, step_size: float = 1.0, opts: Dictionary = {}) -> void:
	text = value
	step = step_size
	min_value = float(opts.get("min", 0.0))
	max_value = opts.get("max", null)
	snap = bool(opts.get("snap", false))
	base = opts.get("base", null)
	if _edit == null:
		# The phone app (web) or a phone build; a PC keeps stepping on the press.
		_touch = (OS.has_feature("web") or OS.has_feature("mobile")) and DisplayServer.is_touchscreen_available()
		compact = bool(opts.get("compact", false))
		var h = float(opts.get("height", 30 if compact else 42))
		if _touch or Kit.fingers:
			# Room for a finger: slim rows of sets get taller keys on a phone.
			h = maxf(h, 40.0)
		add_theme_constant_override("separation", 2 if compact else 4)
		_minus = _make_btn("minus", h)
		add_child(_minus)
		_edit = Kit.input(text, str(opts.get("placeholder", "")), true)
		_edit.custom_minimum_size = Vector2(float(opts.get("width", 58)), h)
		_edit.text_changed.connect(_typed)
		_style_edit(h, int(opts.get("font", 15 if compact else 17)))
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


## A small raised pixel key with a − or + glyph; it sinks while held.
func _make_btn(icon: String, h: float = 42.0) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.text = "−" if icon == "minus" else "+"
	b.tooltip_text = "Hold to repeat"
	var big = _touch or Kit.fingers
	b.custom_minimum_size = Vector2((40 if big else 26) if compact else (46 if big else 36), h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A tan key with a dark sign on it (the Workshop's steppers).
	var looks = PixBox.block_set("tan", 0, 0, 1)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", Kit.font_bold())
	b.add_theme_font_size_override("font_size", 17 if compact else 20)
	b.add_theme_color_override("font_color", Pal.INK)
	b.add_theme_color_override("font_hover_color", Pal.INK)
	b.add_theme_color_override("font_pressed_color", Pal.ACCENT2.darkened(0.3))
	b.add_theme_color_override("font_hover_pressed_color", Pal.ACCENT2.darkened(0.3))
	return b


## The value: a sunken pixel well, bold number, tight padding so "102.5" fits.
func _style_edit(h: float, font_px: int) -> void:
	var pv = int(maxf(0.0, (h - float(font_px) - 12.0) / 2.0))
	_edit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_edit.add_theme_stylebox_override("normal", PixBox.well(2, pv, null))
	_edit.add_theme_stylebox_override("focus", PixBox.well(2, pv, Pal.ACCENT))
	_edit.add_theme_stylebox_override("read_only", PixBox.well(2, pv, null))
	_edit.add_theme_constant_override("minimum_character_width", 0)
	_edit.add_theme_font_size_override("font_size", font_px)
	_edit.add_theme_font_override("font", Kit.font_bold())
	_edit.add_theme_color_override("font_color", Pal.CREAM)
	_edit.add_theme_color_override("font_placeholder_color", Pal.with_alpha(Pal.CREAM, 0.42))
	_edit.size_flags_horizontal = Control.SIZE_FILL


func _typed(t: String) -> void:
	text = t
	changed.emit(text)


func _down(dir: int) -> void:
	_dir = dir
	_held = false
	_hold_time = 0.0
	_repeat_time = 0.0
	_repeats = 0
	if not _touch and _bump(dir):
		Kit.pop(_edit, 1.08, 0.14)
	set_process(true)


func _up() -> void:
	var dir = _dir
	_dir = 0
	set_process(false)
	# A tap on a touch screen: one step, made on the lift, and only when the
	# finger lifts on the key (a scroll's called-off press lifts far away).
	if _touch and dir != 0 and _repeats == 0 and Time.get_ticks_msec() - TouchScroll.last_cancel_msec > 400:
		var key = _minus if dir < 0 else _plus
		if key != null and key.get_global_rect().grow(6.0).has_point(TouchScroll.last_release_pos):
			if _bump(dir):
				Kit.pop(_edit, 1.08, 0.14)


func _process(delta: float) -> void:
	if _dir == 0:
		set_process(false)
		return
	# Fingers: a key only repeats while a finger really holds it. A press whose
	# release went missing ends here, before the first repeat, instead of
	# stepping on and on until something else is touched.
	if TouchScroll.active and TouchScroll.no_mouse and not TouchScroll.holding:
		_dir = 0
		set_process(false)
		return
	_hold_time += delta
	if _hold_time < HOLD_DELAY:
		return
	_repeat_time += delta
	while _repeat_time >= REPEAT_EVERY:
		_repeat_time -= REPEAT_EVERY
		_repeats += 1
		_bump(_dir)


func _bump(dir: int) -> bool:
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
		return false
	text = t
	_edit.text = t
	Sfx.step(dir)
	changed.emit(text)
	return true
