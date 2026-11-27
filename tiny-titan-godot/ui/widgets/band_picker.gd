class_name BandPicker
extends HBoxContainer
## A resistance band in place of a weight, in a set row of the Log tab's lift
## form (LogLiftEditor): a key for a lighter band, the band as a pill in its own
## colour with its name, a key for a heavier band (Bands' ladder).
##
## Sized like the compact weight Stepper it stands in for: keys 40 x 40 on a
## phone (Kit.fingers, or a touch screen on the web), else 26 x 30. The pill
## keeps one width whatever the band (the longest name fits), so a tap never
## moves anything: it changes the pill IN PLACE and emits `changed(id)`. At
## either end of the ladder the key says no (Sfx.error) and stays put; it is
## drawn faint there.
##
## Metas for walkthroughs: the keys have "band_key" = "lighter" / "heavier";
## the owner puts "band_of" on the picker. Also, for lists: `swatch(id, px)`
## (a square of the band's colour) and `pill(id, size)` (its name on its colour).

signal changed(id)

var band: String = Bands.DEFAULT
var _minus: Button = null
var _plus: Button = null
var _pill: PanelContainer = null
var _name: Label = null

## (12 px: "Orange", the longest name, fits the 54 px a weight's box takes)
const PILL_FONT = 12


## `what`: the lift and set the keys' tooltips name ("Face Pull set 2").
func setup(id: String, what: String = "") -> void:
	var b = str(id).strip_edges().to_lower()
	band = b if b != "" else Bands.DEFAULT
	var touch = (OS.has_feature("web") or OS.has_feature("mobile")) and DisplayServer.is_touchscreen_available()
	var big = touch or Kit.fingers
	var h = 40.0 if big else 30.0
	add_theme_constant_override("separation", 2)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	var head = (what + ": ") if what != "" else ""
	_minus = _key("−", -1, Vector2(40.0 if big else 26.0, h), head + "lighter band")
	_minus.set_meta("band_key", "lighter")
	add_child(_minus)
	_pill = PanelContainer.new()
	_pill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pill.custom_minimum_size = Vector2(pill_width(), h)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_name.add_theme_font_override("font", Kit.font_bold())
	_name.add_theme_font_size_override("font_size", PILL_FONT)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(_name)
	add_child(_pill)
	_plus = _key("+", 1, Vector2(40.0 if big else 26.0, h), head + "heavier band")
	_plus.set_meta("band_key", "heavier")
	add_child(_plus)
	_paint()


## As wide as the longest band name needs, so the pill never changes width.
static func pill_width() -> float:
	var w = 0.0
	for id in Bands.LADDER:
		w = maxf(w, Kit.font_bold().get_string_size(Bands.name_of(id), HORIZONTAL_ALIGNMENT_LEFT, -1, PILL_FONT).x)
	return maxf(54.0, ceilf(w) + 10.0)


## Change the band without emitting `changed`.
func set_band(id: String) -> void:
	var b = str(id).strip_edges().to_lower()
	band = b if b != "" else Bands.DEFAULT
	_paint()


func _key(glyph: String, d: int, at: Vector2, tip: String) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.text = glyph
	b.tooltip_text = tip
	b.custom_minimum_size = at
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var looks = PixBox.button_set(Pal.PANEL2, Pal.OUTLINE.lightened(0.1), 0, 0, 1, Pal.BORDER)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", Kit.font_bold())
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Pal.TEXT)
	b.add_theme_color_override("font_hover_color", Pal.TEXT)
	b.add_theme_color_override("font_pressed_color", Pal.ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", Pal.ACCENT)
	b.pressed.connect(_press.bind(d))
	return b


func _press(d: int) -> void:
	var next = Bands.step(band, d)
	if next == band:
		# The lightest or the heaviest band already: nothing moves.
		Sfx.error()
		return
	band = next
	_paint()
	Sfx.step(d)
	Kit.pop(_pill, 1.08, 0.14)
	changed.emit(band)


func _paint() -> void:
	if _pill == null:
		return
	var col = Bands.color_of(band)
	_pill.add_theme_stylebox_override("panel", PixBox.make(col, {"ring": col.lightened(0.3), "lip": 1, "pad_h": 4, "pad_v": 2}))
	_name.text = Bands.name_of(band)
	_name.add_theme_color_override("font_color", Bands.text_color(band))
	_pill.tooltip_text = Bands.words(band)
	var lv = Bands.level(band)
	_minus.modulate.a = 0.45 if lv == 1 else 1.0
	_plus.modulate.a = 0.45 if lv == Bands.LADDER.size() else 1.0


## A small square of a band's colour, with a dark outline (lists of sets).
static func swatch(id, px: int = 12) -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.sbox(Bands.color_of(id), 0, Pal.OUTLINE, 1, 0, 0))
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.tooltip_text = Bands.words(id)
	return p


## A band's name on its own colour, like Kit.tag.
static func pill(id, size: int = 11) -> PanelContainer:
	return Kit.tag(Bands.name_of(id), Bands.color_of(id), Bands.text_color(id) == Pal.INK, size)
