extends Control
## The app shell: a phone-shaped column with the current screen, the tab bar,
## and layers for modal sheets, the results reel and toasts.

const NAV_H = 64.0
const MAX_W = 520.0
## How far down the sky shows through the top of the column.
const SKY_H = 260.0
## The tabs, left to right. The sixth, Realm (the turn-based RPG, RPG_PLAN.md),
## came 2026-11-25 and is LAST, so the first five are where they always were.
const TABS = [
	{"id": "home", "label": "Hero", "icon": "home"},
	{"id": "adventure", "label": "Adventure", "icon": "adventure"},
	{"id": "log", "label": "Log", "icon": "plus"},
	{"id": "journey", "label": "Journey", "icon": "journey"},
	{"id": "armory", "label": "Armory", "icon": "armory"},
	{"id": "realm", "label": "Realm", "icon": "realm"},
]
const SCREENS = {
	"home": "res://ui/screens/home.gd",
	"adventure": "res://ui/screens/adventure.gd",
	"log": "res://ui/screens/log.gd",
	"journey": "res://ui/screens/journey.gd",
	"armory": "res://ui/screens/armory.gd",
	"realm": "res://ui/rpg/realm.gd",
}
## How the tab bar's width is shared out (size_flags_stretch_ratio). With five
## equal tabs each had a fifth; with six, the first three keep exactly that
## fifth (3 of 15) and the last three share the rest (2 of 15 each), so the Log
## key, the one tapped most, did not move by a pixel when the Realm tab came:
## 86.4, 86.4, 86.4, 57.6, 57.6, 57.6 of the bar's 432 on a phone.
const TAB_STRETCH = {"home": 3, "adventure": 3, "log": 3, "journey": 2, "armory": 2, "realm": 2}
## A tab's least width: the wide ones, and the narrow ones on the right.
const TAB_MIN_W = 56.0
const TAB_MIN_W_NARROW = 48.0
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
## Whether the Realm tab shows its dot (a training chest waits): what the bar
## was last built with, so a change of the Realm's save rebuilds the bar only
## when the dot turns on or off.
var _realm_dot = false
## On a phone, the room the status bar (top) and the home bar (bottom) take, in
## screen units (web build: web/tt.js ttSafe). The column fits between them.
var _inset_top = 0.0
var _inset_bottom = 0.0
## The tab bar's colour under the home bar.
var _floor: ColorRect
## Web build with ?debug=1 in the link: window.ttEval("expression") (see _debug_bridge).
var _debug_cb = null
## The speed readout (Settings -> Phone app -> Show speed): frames a second now,
## and the slowest half second of the last few, in a corner of the screen.
var _speed: Label = null
var _speed_n = 0
var _speed_t = 0.0
var _speed_lows = []


func _ready() -> void:
	Pal.apply(App.settings().get("theme", "arcade"))
	_apply_look()
	if OS.has_feature("web"):
		# A phone's browser has no fonts to fall back on for arrows and triangles.
		SymbolFont.install(ThemeDB.fallback_font, Kit.font_bold())
	_fit_window()
	_build()
	resized.connect(_layout)
	if OS.has_feature("web"):
		_read_insets()
		get_viewport().size_changed.connect(func(): call_deferred("_read_insets"))
		_debug_bridge()
	App.nav_changed.connect(_refresh)
	App.changed.connect(_on_changed)
	App.rpg_changed.connect(_on_rpg_changed)
	App.result_ready.connect(_on_result)
	App.toast_requested.connect(_on_toast)
	_refresh()
	# Last week's recap to the phone, once a week (app/recap_push.gd), a moment after start.
	get_tree().create_timer(6.0).timeout.connect(RecapPush.send_if_due)
	# The phone app: a newer build fetched behind this one (app/web_update.gd).
	if OS.has_feature("web"):
		var ask = Timer.new()
		ask.wait_time = 4.0
		ask.autostart = true
		ask.timeout.connect(_ask_update)
		add_child(ask)


## A newer build has taken over from the one on screen: say so once, and let
## the Hero tab and Settings show their restart key.
func _ask_update() -> void:
	if WebUpdate.announced or not WebUpdate.ready():
		return
	WebUpdate.announced = true
	App.toast("A new version is ready: restart from the Hero tab", "good", "sparkle")
	App.changed.emit()


## Build the shell: scene, column, screen holder, tab bar, overlay and toast layers.
## Called again after a theme change, so everything picks up the new colours.
func _build() -> void:
	theme = Kit.theme()

	# The pixel-art sky and mountains behind everything.
	add_child(Backdrop.new())
	_floor = ColorRect.new()
	_floor.color = Pal.BG2
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor.visible = false
	add_child(_floor)

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
	_add_touch_helpers()
	_layout()


## On a touch screen: drag to scroll over anything (ui/touch_scroll.gd); in a
## phone's browser, a real text field for typing (app/web_keys.gd).
func _add_touch_helpers() -> void:
	# A phone or tablet: keys sized for fingers (Kit.fingers; "--fingers" tries it on a PC).
	if ((OS.has_feature("web") or OS.has_feature("mobile")) and DisplayServer.is_touchscreen_available()) or OS.get_cmdline_user_args().has("--fingers"):
		Kit.fingers = true
	if DisplayServer.is_touchscreen_available():
		var ts = TouchScroll.new()
		if OS.has_feature("web"):
			# A phone (its pointer cannot hover): no mouse at all, only the taps made for fingers.
			var app = JavaScriptBridge.get_interface("ttApp")
			ts.only_fingers = app != null and bool(app.noHover)
		add_child(ts)
	if WebKeys.wanted():
		add_child(WebKeys.new())


## For testing the web build in a browser: with ?debug=1 in the page's link,
## window.ttEval("main._scroll.scroll_vertical") evaluates a GDScript expression
## (names: main, App) and leaves the answer in window.ttOut.
func _debug_bridge() -> void:
	var app = JavaScriptBridge.get_interface("ttApp")
	if app == null or not str(app.href()).contains("debug=1"):
		return
	_debug_cb = JavaScriptBridge.create_callback(_debug_eval)
	JavaScriptBridge.get_interface("window").ttEval = _debug_cb


## For ttEval: where the `nth` visible button whose text holds `text` (or else a
## label showing it) is, "x,y,w,h" in screen units, or "".
func debug_rect(text: String, nth: int = 0) -> String:
	var want = text.to_lower()
	var hits = []
	for n in find_children("*", "Button", true, false):
		if n.is_visible_in_tree() and str(n.text).to_lower().contains(want):
			hits.append(n)
	if hits.is_empty():
		for n in find_children("*", "Label", true, false):
			if n.is_visible_in_tree() and str(n.text).to_lower() == want:
				hits.append(n)
	if nth >= hits.size():
		return ""
	var r = hits[nth].get_global_rect()
	return "%d,%d,%d,%d" % [r.position.x, r.position.y, r.size.x, r.size.y]


## For ttEval: how the last frames went: frames a second, the milliseconds the
## scripts took, draw calls and objects drawn.
func debug_perf() -> String:
	return "tooltip delay %s  fps %d  script %.1f ms  draws %d  objects %d  nodes %d" % [str(ProjectSettings.get_setting_with_override("gui/timers/tooltip_delay_sec")), Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]


## For ttEval (an Expression cannot name a class or a singleton): the backup keys
## and a photo from base64.
func debug_do(what: String, arg: String = "") -> String:
	match what:
		"export":
			SettingsPanel.pick_export()
		"import":
			SettingsPanel.pick_import(null)
		"photo":
			return App.import_photo_bytes(Marshalls.base64_to_raw(arg), "x.jpg")
		"load":
			# A save as JSON text left in window.ttIn (demo data for a browser test).
			var parsed = App.parse_saved(JSON.parse_string(str(JavaScriptBridge.eval("window.ttIn || ''"))))
			if parsed == null:
				return "not a save"
			App.apply_backup({"data": parsed, "photos": {}})
		"key":
			# Press the first visible key that carries this meta (keys without their own text).
			for n in find_children("*", "Button", true, false):
				if n.is_visible_in_tree() and n.has_meta(arg):
					n.pressed.emit()
					return "ok"
			return "no such key"
		"confirm":
			var b = null
			for n in find_children("*", "Button", true, false):
				if n.is_visible_in_tree() and str(n.text) == arg:
					b = n
			if b == null:
				return "no such key"
			b.pressed.emit()
	return "ok"


## For ttEval: where the `nth` visible control of a kind is, "x,y,w,h" in screen
## units, or "". Kinds: "plus" / "minus" (a Stepper's keys), "edit" (a text box),
## "tip:<words>" (a control whose tooltip holds the words).
func debug_where(what: String, nth: int = 0) -> String:
	var hits = []
	for n in find_children("*", "Control", true, false):
		if not n.is_visible_in_tree():
			continue
		if what == "plus" and n is Stepper:
			hits.append(n._plus)
		elif what == "minus" and n is Stepper:
			hits.append(n._minus)
		elif what == "edit" and (n is LineEdit or n is TextEdit):
			hits.append(n)
		elif what.begins_with("tip:") and str(n.tooltip_text).to_lower().contains(what.substr(4).to_lower()):
			hits.append(n)
	if nth >= hits.size():
		return ""
	var r = hits[nth].get_global_rect()
	return "%d,%d,%d,%d" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]


## For ttEval: what the fingers and the keyboard are up to, as one line.
func debug_touch() -> String:
	var f = get_viewport().gui_get_focus_owner()
	var first = ""
	for n in find_children("*", "Stepper", true, false):
		if n.is_visible_in_tree():
			first = str(n.text)
			break
	return "focus=%s typing=%s holding=%s stepper=%s size=%s" % [f.get_class() if f != null else "none", str(WebKeys.typing()), str(TouchScroll.holding), first, str(get_viewport_rect().size)]


func _debug_eval(args: Array) -> void:
	var w = JavaScriptBridge.get_interface("window")
	var e = Expression.new()
	if e.parse(str(args[0]) if not args.is_empty() else "", ["main", "App"]) != OK:
		w.ttOut = "parse error: " + e.get_error_text()
		return
	var r = e.execute([self, App], self)
	w.ttOut = "error: " + e.get_error_text() if e.has_execute_failed() else str(r)


## The web build on a phone: how much of the screen the status bar and the home
## bar cover (CSS pixels from the page, turned into screen units).
func _read_insets() -> void:
	if not OS.has_feature("web") or size.x <= 0.0:
		return
	var raw = JavaScriptBridge.eval("window.ttSafe ? window.ttSafe() : ''", true)
	var d = JSON.parse_string(str(raw)) if raw != null and str(raw) != "" else null
	if not (d is Dictionary) or float(d.get("w", 0)) <= 0.0:
		return
	var k = size.x / float(d.w)
	var top = roundf(float(d.get("top", 0)) * k)
	var bottom = roundf(float(d.get("bottom", 0)) * k)
	if top != _inset_top or bottom != _inset_bottom:
		_inset_top = top
		_inset_bottom = bottom
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
	_column.position = Vector2(floor((size.x - w) / 2.0), _inset_top)
	_column.size = Vector2(w, size.y - _inset_top - _inset_bottom)
	_frame.visible = size.x > MAX_W + 2.0
	if _floor != null:
		_floor.position = Vector2(_column.position.x, size.y - _inset_bottom)
		_floor.size = Vector2(w, _inset_bottom)
		_floor.visible = _inset_bottom > 0.0


## The look of sections and rows picked in Settings (Kit.look; the mock-ups of 2026-11-27).
func _apply_look() -> void:
	var lk = str(App.settings().get("look", "stripe"))
	Kit.look = lk if Kit.LOOKS.has(lk) else "stripe"


func _on_changed() -> void:
	var want_look = str(App.settings().get("look", "stripe"))
	if Kit.LOOKS.has(want_look) and want_look != Kit.look:
		_apply_look()
		call_deferred("_retheme")
		return
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
		# A new tab starts at the top. Before the screen is added: its first build
		# keeps the scroll position it finds (UiScreen), which was the old tab's.
		_scroll.scroll_vertical = 0
		# The new screen's cards rise in and its bars fill.
		Kit.intro_begin()
		_screen = _make(SCREENS.get(App.tab, ""), App.tab)
		_holder.add_child(_screen)
		_scroll.scroll_vertical = 0
		# No hard cut between tabs: the new one fades in while its cards rise.
		_screen.modulate.a = 0.0
		_screen.create_tween().tween_property(_screen, "modulate:a", 1.0, 0.16)
	_build_nav()
	_keep_awake()


## The phone app: the screen stays on while the Log tab is open (a workout being
## logged), where the browser allows it (web/tt.js ttApp.wake).
func _keep_awake() -> void:
	if not OS.has_feature("web"):
		return
	var app = JavaScriptBridge.get_interface("ttApp")
	if app != null:
		app.wake(App.tab == "log")


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
	_realm_dot = _chest_waiting()
	for t in TABS:
		_nav_row.add_child(_nav_button(t, t.id == App.tab, claimable if t.id == "adventure" else 0, _realm_dot and t.id == "realm"))


## Is a training chest of the Realm waiting to be opened (today's or
## yesterday's)? A cheap check (RpgBoosts.chest_waiting): it runs every time
## the bar is built.
func _chest_waiting() -> bool:
	# (Not before the Realm's hub can open one: RealmScreen.hub_ready.)
	return RealmScreen.hub_ready and App.has_profile() and RpgBoosts.chest_waiting(App.state, App.reading(), App.rpg(), App.today)


## The Realm's own save changed (App.set_rpg: a chest opened, a fight won).
## Nothing of the main game depends on it but the Realm tab's dot.
func _on_rpg_changed() -> void:
	if _nav_row != null and _chest_waiting() != _realm_dot:
		_build_nav()


## A small round pixel dot (5 x 5 art pixels, dark edge): "something waits in
## this tab", without a number.
func _tab_dot(color: Color) -> Control:
	var dot = Control.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size = Vector2(10, 10)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in [[Rect2(2, 0, 6, 10), Pal.OUTLINE], [Rect2(0, 2, 10, 6), Pal.OUTLINE], [Rect2(2, 2, 6, 6), color], [Rect2(2, 2, 4, 2), color.lightened(0.35)]]:
		var px = ColorRect.new()
		px.color = r[1]
		px.position = r[0].position
		px.size = r[0].size
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_child(px)
	return dot


## One key of the tab bar. `badge` is a count shown on the icon (0 = none);
## `dot` a small gold dot without a number (the Realm: a chest waits).
func _nav_button(t: Dictionary, active: bool, badge: int, dot: bool = false) -> Button:
	var b = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The bar's width by shares (TAB_STRETCH): the Log key stays where it was.
	var share = int(TAB_STRETCH.get(t.id, 3))
	b.size_flags_stretch_ratio = float(share)
	b.custom_minimum_size = Vector2(TAB_MIN_W if share >= 3 else TAB_MIN_W_NARROW, NAV_H)
	b.set_meta("tab", str(t.id))
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
			var count = Kit.tag(str(badge), Pal.DANGER, false, 10)
			count.position = Vector2(20, -6)
			holder.add_child(count)
		elif dot:
			# Gold: what waits is a reward (the Realm's training chest).
			var pip = _tab_dot(Pal.ACCENT)
			pip.position = Vector2(24, -4)
			pip.set_meta("tab_dot", str(t.id))
			holder.add_child(pip)
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


# --- speed readout ----------------------------------------------------------

func speed_shown() -> bool:
	return _speed != null and is_instance_valid(_speed)


## Show or hide the frames-a-second readout (kept across a theme change).
func show_speed(on: bool) -> void:
	if not on:
		if speed_shown():
			_speed.queue_free()
		_speed = null
		set_process(false)
		return
	if speed_shown():
		return
	_speed = Label.new()
	_speed.add_theme_font_override("font", Kit.font_bold())
	_speed.add_theme_font_size_override("font_size", 13)
	_speed.add_theme_color_override("font_color", Pal.ACCENT)
	_speed.add_theme_color_override("font_outline_color", Pal.INK)
	_speed.add_theme_constant_override("outline_size", 6)
	_speed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed.position = Vector2(8, _inset_top + 2)
	_speed.z_index = 100
	_speed.text = "speed: measuring"
	add_child(_speed)
	_speed_n = 0
	_speed_t = 0.0
	_speed_lows = []
	set_process(true)


func _process(delta: float) -> void:
	if not speed_shown():
		set_process(false)
		return
	_speed_n += 1
	_speed_t += delta
	if _speed_t < 0.5:
		return
	var fps = int(round(float(_speed_n) / _speed_t))
	_speed_n = 0
	_speed_t = 0.0
	_speed_lows.append(fps)
	while _speed_lows.size() > 10:
		_speed_lows.pop_front()
	_speed.text = "%d fps (low %d)" % [fps, int(_speed_lows.min())]


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
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Kit.passthrough(h)
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
