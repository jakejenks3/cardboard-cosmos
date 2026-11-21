extends Control
## The app shell: a phone-shaped column with the current screen, the tab bar,
## and layers for modal sheets, the results reel and toasts.

const NAV_H = 64.0
const MAX_W = 520.0
## How far down the sky shows through the top of the column.
const SKY_H = 260.0
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
## The tab whose icon bounces the next time the bar is built (the one just tapped).
var _bounce_tab = ""


func _ready() -> void:
	Pal.apply(App.settings().get("theme", "arcade"))
	_fit_window()
	_build()
	resized.connect(_layout)
	App.nav_changed.connect(_refresh)
	App.changed.connect(_on_changed)
	App.result_ready.connect(_on_result)
	App.toast_requested.connect(_on_toast)
	_refresh()
	# Last week's recap to the phone, once a week (app/recap_push.gd), a moment after start.
	get_tree().create_timer(6.0).timeout.connect(RecapPush.send_if_due)


## Build the shell: scene, column, screen holder, tab bar, overlay and toast layers.
## Called again after a theme change, so everything picks up the new colours.
func _build() -> void:
	theme = Kit.theme()

	# The pixel-art sky and mountains behind everything.
	add_child(Backdrop.new())

	_column = Control.new()
	add_child(_column)

	# The app column sits on the scene like a pane of dark glass: the sky shows
	# through at the top and fades to the solid background further down.
	var fade = Gradient.new()
	fade.set_color(0, Pal.with_alpha(Pal.BG, 0.0))
	fade.set_color(1, Pal.BG)
	var fade_tex = GradientTexture2D.new()
	fade_tex.gradient = fade
	fade_tex.fill_from = Vector2(0, 0)
	fade_tex.fill_to = Vector2(0, 1)
	fade_tex.width = 4
	fade_tex.height = 64
	var shade_top = TextureRect.new()
	shade_top.texture = fade_tex
	shade_top.stretch_mode = TextureRect.STRETCH_SCALE
	shade_top.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade_top.offset_bottom = SKY_H
	shade_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(shade_top)
	var shade_rest = ColorRect.new()
	shade_rest.color = Pal.BG
	shade_rest.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade_rest.offset_top = SKY_H
	shade_rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(shade_rest)

	# On a wide window the column gets thin side lines so it reads as "the device".
	_frame = Panel.new()
	var fs = StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
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
	_nav.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_nav.add_theme_stylebox_override("panel", PixBox.make(Pal.BG2, {"ring": Pal.BORDER, "lip": 0, "pad_h": 4, "pad_v": 0}))
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
	_layout()


## The theme changed in Settings: rebuild everything in the new colours and put
## the Settings sheet back if it was open.
func _retheme() -> void:
	var settings_open = false
	for c in _overlay.get_children():
		if c is Sheet:
			settings_open = true
	Pal.apply(App.settings().get("theme", "arcade"))
	Kit.reset_style()
	Kit.clear(self)
	_screen = null
	_shown_tab = ""
	_onboarding = null
	_results = null
	_build()
	_refresh()
	if settings_open and ResourceLoader.exists("res://ui/screens/settings.gd"):
		load("res://ui/screens/settings.gd").open()


## Open at a comfortable size on any screen: bigger on high-DPI displays, and
## never taller than the screen (the layout scrolls, so a short window is fine).
func _fit_window() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	if Engine.has_method("is_embedded_in_editor") and Engine.call("is_embedded_in_editor"):
		return
	var win = get_window()
	if win == null or win.mode != Window.MODE_WINDOWED:
		return
	# Only adjust the default window; a size chosen on the command line is left alone.
	if win.size != Vector2i(440, 900):
		return
	var screen = win.current_screen
	var usable = DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x < 200 or usable.size.y < 200:
		return
	var k = 1.0
	if OS.get_name() == "macOS":
		k = DisplayServer.screen_get_scale(screen)
	else:
		k = float(DisplayServer.screen_get_dpi(screen)) / 96.0
	# Whole and quarter steps only, and nothing extreme.
	k = clampf(snappedf(k, 0.25), 1.0, 3.0)
	var want = Vector2(440.0, 900.0) * k
	var max_h = float(usable.size.y) - 70.0
	var max_w = float(usable.size.x) - 20.0
	if want.y > max_h:
		want.y = max_h
	if want.x > max_w:
		want.x = max_w
	var new_size = Vector2i(int(want.x), int(want.y))
	if new_size == win.size:
		return
	win.size = new_size
	win.position = usable.position + (usable.size - new_size) / 2


func _layout() -> void:
	var w = minf(size.x, MAX_W)
	_column.position = Vector2(floor((size.x - w) / 2.0), 0)
	_column.size = Vector2(w, size.y)
	_frame.visible = size.x > MAX_W + 2.0


func _on_changed() -> void:
	if str(App.settings().get("theme", "arcade")) != Pal.theme_id and Pal.THEMES.has(str(App.settings().get("theme", "arcade"))):
		# Deferred: this runs inside the button press that asked for the change.
		call_deferred("_retheme")
		return
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
		Pal.current_tab = App.tab
		Kit.clear(_holder)
		# The new screen's cards rise in and its bars fill.
		Kit.intro_begin()
		_screen = _make(SCREENS.get(App.tab, ""), App.tab)
		_holder.add_child(_screen)
		_scroll.scroll_vertical = 0
		# No hard cut between tabs: the new one fades in while its cards rise.
		_screen.modulate.a = 0.0
		_screen.create_tween().tween_property(_screen, "modulate:a", 1.0, 0.16)
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

	var col = Pal.tab(t.id) if active else Pal.MUTED
	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	if t.id == "log":
		# The big gold "+" that sticks up out of the bar.
		var key = Panel.new()
		key.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		key.add_theme_stylebox_override("panel", PixBox.button_set(Pal.ACCENT, Pal.ACCENT_DARK, 0, 0, 2)["normal"])
		key.custom_minimum_size = Vector2(48, 50)
		key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Fx.shine(key, 7.0, 2.5, 0.35)
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
		holder.custom_minimum_size = Vector2(32, 32)
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic = Icons.rect(t.icon, 32, null if active else Pal.MUTED)
		ic.position = Vector2(0, 0)
		ic.size = Vector2(32, 32)
		holder.add_child(ic)
		if active and _bounce_tab == str(t.id):
			# The tab that was just chosen: its icon drops in with a bounce.
			_bounce_tab = ""
			ic.position.y = -8.0
			var tw = ic.create_tween()
			tw.tween_property(ic, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		if badge > 0:
			var dot = Kit.tag(str(badge), Pal.DANGER, false, 10)
			dot.position = Vector2(20, -6)
			holder.add_child(dot)
		v.add_child(holder)
	var l = Kit.label(t.label, 11, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if active and t.id != "log":
		# A marker in the tab's colour along the top edge of the bar.
		var mark = ColorRect.new()
		mark.color = Pal.tab(t.id)
		mark.set_anchors_preset(Control.PRESET_TOP_WIDE)
		mark.offset_left = 14
		mark.offset_right = -14
		mark.offset_top = 2
		mark.offset_bottom = 6
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(mark)
	Kit.juice(b)
	return b


func _nav_pressed(id: String) -> void:
	Sfx.tap()
	if id != App.tab:
		_bounce_tab = id
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
	var col = Pal.BORDER
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
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.PANEL2, {"ring": col, "lip": 1, "pad_h": 12, "pad_v": 8}))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = Kit.hbox(8)
	h.add_child(Icons.rect(ic, 20))
	h.add_child(Kit.para(text, 14, null, true))
	p.add_child(h)
	while _toasts.get_child_count() >= 4:
		var oldest = _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	_toasts.add_child(p)
	p.modulate.a = 0.0
	p.scale = Vector2(0.92, 0.92)
	p.ready.connect(func(): p.pivot_offset = p.size / 2.0, CONNECT_DEFERRED)
	var tw = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
