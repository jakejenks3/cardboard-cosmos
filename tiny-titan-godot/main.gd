extends Control
## The app shell: a phone-shaped column with the current screen, the tab bar,
## and layers for modal sheets, the results reel and toasts.

const NAV_H = 64.0
const MAX_W = 520.0
const TABS = [
	{"id": "home", "label": "Hero", "icon": "home"},
	{"id": "adventure", "label": "Adventure", "icon": "adventure"},
	{"id": "log", "label": "Log", "icon": "plus"},
	{"id": "journey", "label": "Journey", "icon": "journey"},
	{"id": "armory", "label": "Armory", "icon": "armory"},
]
const SCREENS = {
	"home": "res://ui/screens/home.gd",
	"adventure": "res://ui/screens/adventure.gd",
	"log": "res://ui/screens/log.gd",
	"journey": "res://ui/screens/journey.gd",
	"armory": "res://ui/screens/armory.gd",
}
const ONBOARDING = "res://ui/screens/onboarding.gd"
const RESULTS = "res://ui/screens/results.gd"

var _column: Control
var _frame: Panel
var _scroll: ScrollContainer
var _holder: MarginContainer
var _nav: PanelContainer
var _nav_row: HBoxContainer
var _overlay: Control
var _toasts: VBoxContainer
var _screen = null
var _shown_tab = ""
var _onboarding = null
var _results = null
var _result_queue = []


func _ready() -> void:
	theme = Kit.theme()

	var bg = TextureRect.new()
	var grad = Gradient.new()
	grad.set_color(0, Color("2a2056"))
	grad.set_color(1, Pal.BG)
	var gt = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.2, 0.0)
	gt.fill_to = Vector2(0.95, 0.75)
	gt.width = 128
	gt.height = 128
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_column = Control.new()
	add_child(_column)

	# On a wide window the column gets a faint frame so it reads as "the device".
	_frame = Panel.new()
	var fs = StyleBoxFlat.new()
	fs.bg_color = Pal.with_alpha(Pal.BG, 0.55)
	fs.border_color = Pal.LINE
	fs.border_width_left = 1
	fs.border_width_right = 1
	_frame.add_theme_stylebox_override("panel", fs)
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_frame)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_bottom = -NAV_H
	_column.add_child(_scroll)
	_holder = MarginContainer.new()
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_holder.add_theme_constant_override("margin_left", 14)
	_holder.add_theme_constant_override("margin_right", 14)
	_holder.add_theme_constant_override("margin_top", 10)
	_holder.add_theme_constant_override("margin_bottom", 28)
	_scroll.add_child(_holder)

	_nav = PanelContainer.new()
	var ns = StyleBoxFlat.new()
	ns.bg_color = Color(0.078, 0.063, 0.165, 0.97)
	ns.border_color = Pal.LINE
	ns.border_width_top = 1
	_nav.add_theme_stylebox_override("panel", ns)
	_nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_nav.offset_top = -NAV_H
	_nav.offset_bottom = 0
	_column.add_child(_nav)
	_nav_row = HBoxContainer.new()
	_nav_row.add_theme_constant_override("separation", 0)
	_nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav.add_child(_nav_row)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_overlay)
	Kit.overlay_root = _overlay

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_left = 14
	_toasts.offset_right = -14
	_toasts.offset_top = 10
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	_column.add_child(_toasts)

	resized.connect(_layout)
	_layout()
	App.nav_changed.connect(_refresh)
	App.changed.connect(_on_changed)
	App.result_ready.connect(_on_result)
	App.toast_requested.connect(_on_toast)
	_refresh()


func _layout() -> void:
	var w = minf(size.x, MAX_W)
	_column.position = Vector2(floor((size.x - w) / 2.0), 0)
	_column.size = Vector2(w, size.y)
	_frame.visible = size.x > MAX_W + 2.0


func _on_changed() -> void:
	# Profile created or wiped: swap between onboarding and the game.
	if (_onboarding != null) == App.has_profile():
		_refresh()
	else:
		_build_nav()


func _refresh() -> void:
	if not App.has_profile():
		_show_onboarding()
		return
	if _onboarding != null:
		_onboarding.queue_free()
		_onboarding = null
	_scroll.visible = true
	_nav.visible = _results == null
	if App.tab != _shown_tab or _screen == null:
		_shown_tab = App.tab
		Kit.clear(_holder)
		_screen = _make(SCREENS.get(App.tab, ""), App.tab)
		_holder.add_child(_screen)
		_scroll.scroll_vertical = 0
		Kit.fade_in(_screen, 0.18)
	_build_nav()


func _show_onboarding() -> void:
	_scroll.visible = false
	_nav.visible = false
	Kit.clear(_holder)
	_screen = null
	_shown_tab = ""
	if _onboarding == null:
		_onboarding = _make(ONBOARDING, "onboarding")
		_onboarding.set_anchors_preset(Control.PRESET_FULL_RECT)
		_column.add_child(_onboarding)
		_column.move_child(_onboarding, _scroll.get_index())


## Instantiate a screen script; a friendly placeholder if it is missing.
func _make(path: String, what: String) -> Control:
	if path != "" and ResourceLoader.exists(path):
		var script = load(path)
		if script != null:
			return script.new()
	var v = VBoxContainer.new()
	v.add_child(Kit.h1(what.capitalize()))
	v.add_child(Kit.muted_para("This screen is missing (%s)." % path))
	return v


# --- tab bar ----------------------------------------------------------------

func _build_nav() -> void:
	Kit.clear(_nav_row)
	var claimable = App.claimable_quests() if App.has_profile() else 0
	for t in TABS:
		_nav_row.add_child(_nav_button(t, t.id == App.tab, claimable if t.id == "adventure" else 0))


func _nav_button(t: Dictionary, active: bool, badge: int) -> Button:
	var b = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(56, NAV_H)
	b.tooltip_text = t.label
	var empty = StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	b.pressed.connect(_nav_pressed.bind(t.id))

	var col = Pal.ACCENT if active else Pal.MUTED
	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	if t.id == "log":
		# The big gold "+" that sticks up out of the bar.
		var key = Panel.new()
		var ks = Kit.sbox(Pal.ACCENT, 14, Pal.ACCENT_DARK, 0, 0, 0)
		ks.border_width_bottom = 3
		ks.shadow_color = Color(1.0, 0.78, 0.24, 0.28)
		ks.shadow_size = 8
		key.add_theme_stylebox_override("panel", ks)
		key.custom_minimum_size = Vector2(46, 46)
		key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plus = Icons.rect("plus", 26, Pal.INK)
		plus.set_anchors_preset(Control.PRESET_CENTER)
		plus.position -= Vector2(13, 14)
		key.add_child(plus)
		var lift = Control.new()
		lift.custom_minimum_size = Vector2(46, 30)
		lift.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.position = Vector2(0, -18)
		lift.add_child(key)
		v.add_child(lift)
	else:
		var holder = Control.new()
		holder.custom_minimum_size = Vector2(26, 24)
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic = Icons.rect(t.icon, 24, null if active else Pal.MUTED)
		ic.position = Vector2(1, 0)
		ic.size = Vector2(24, 24)
		holder.add_child(ic)
		if badge > 0:
			var dot = Kit.tag(str(badge), Pal.DANGER, false, 10)
			dot.position = Vector2(15, -5)
			holder.add_child(dot)
		v.add_child(holder)
	var l = Kit.label(t.label, 11, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return b


func _nav_pressed(id: String) -> void:
	Sfx.tap()
	if id == "log":
		App.open_log(null)
	else:
		App.go(id)
	_scroll.scroll_vertical = 0


# --- results reel -----------------------------------------------------------

func _on_result(result: Dictionary) -> void:
	_result_queue.append(result)
	_next_result()


func _next_result() -> void:
	if _results != null or _result_queue.is_empty():
		return
	if not ResourceLoader.exists(RESULTS):
		_result_queue.clear()
		return
	var result = _result_queue.pop_front()
	_results = load(RESULTS).new()
	_results.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_results)
	_results.setup(result)
	_results.finished.connect(_result_done)
	_nav.visible = false


func _result_done() -> void:
	if _results != null:
		_results.queue_free()
		_results = null
	_nav.visible = App.has_profile()
	_next_result()


# --- toasts -----------------------------------------------------------------

func _on_toast(text: String, kind: String, icon: String) -> void:
	var col = Pal.LINE
	var ic = icon
	match kind:
		"good":
			col = Pal.GOOD
			if ic == "":
				ic = "check"
		"bad":
			col = Pal.DANGER
			if ic == "":
				ic = "warning"
		_:
			if ic == "":
				ic = "info"
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.sbox(Pal.PANEL2, 12, col, 1, 12, 9))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = Kit.hbox(8)
	h.add_child(Icons.rect(ic, 20))
	h.add_child(Kit.para(text, 14, null, true))
	p.add_child(h)
	_toasts.add_child(p)
	p.modulate.a = 0.0
	var tw = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
