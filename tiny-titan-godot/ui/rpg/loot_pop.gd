class_name LootPop
extends Control
## Something is opened (a training chest, a star chest, a cache, a hunt's
## prize): the moment gets the whole screen. The chest drops in, rattles and
## bursts open in light, and what was in it appears a line at a time; a tap
## shows everything at once, the next tap closes it.
##
##   LootPop.open("TRAINING CHEST", "chest_wood", ["80 ore", "Protein Shake x1"])
##
## It is drawn over everything on Kit.overlay_root and takes every tap while
## it is up. What was won is in the save BEFORE this opens: it only shows it.
## Metas: loot_pop (the title) on the root, loot_line on each line.
## `LootPop.close_all()` takes every one off the screen (a walkthrough).

const ICON_PX = 96.0
## How dark the page goes under the moment (0.86 let the page's own words compete with the pop's).
const DIM = 0.92

var done: bool = false
var _gen: int = 0
var _icon: TextureRect
var _holder: Control
var _lines: Array = []
var _hint: Control
var _dim: ColorRect
var _rays = null
var _color: Color = Color(1, 1, 1)
var _closing: bool = false
var _sound: String = "chest"


static func open(title: String, icon: String, lines: Array, color = null, sound: String = "chest") -> LootPop:
	if Kit.overlay_root == null:
		return null
	var p = LootPop.new()
	p._color = Pal.ACCENT if color == null else color
	p._sound = sound
	Kit.overlay_root.add_child(p)
	p._build(title, icon, lines)
	p._run()
	return p


## Every pop on screen goes, at once.
static func close_all() -> void:
	if Kit.overlay_root == null:
		return
	for c in Kit.overlay_root.get_children():
		if c is LootPop:
			c.queue_free()


func _build(title: String, icon: String, lines: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("loot_pop", title)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.06, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# (2026-11-27 review: the title, the chest and the lines floated with no panel over the dimmed page, whose
	# own words still showed beside them.) The moment is a wooden window: the title on its sign in the moment's
	# colour, the chest and what was in it on the parchment, "tap to go on" under the window.
	var outer = Kit.vbox(12)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(outer)
	var win = Kit.section("loot_window", title.to_upper(), "", _color, null, Callable(), 10, 14)
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(win)
	var col = Kit.vbox(10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.custom_minimum_size = Vector2(300, 0)
	win.add(col)
	var holder = Control.new()
	holder.custom_minimum_size = Vector2(ICON_PX + 40.0, ICON_PX + 40.0)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder = holder
	col.add_child(holder)
	_icon = TextureRect.new()
	_icon.texture = Icons.tex(icon if Icons.has_icon(icon) else "chest", null, 2)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size = Vector2(ICON_PX, ICON_PX)
	_icon.position = Vector2(20, 20)
	_icon.pivot_offset = Vector2(ICON_PX / 2.0, ICON_PX * 0.8)
	_icon.set_meta("loot_icon", icon)
	holder.add_child(_icon)
	# The first line in the moment's colour, darkened in its own hue until it reads on the parchment.
	var first = RpgUi.ink_on(_color, Pal.PANEL)
	for i in range(mini(lines.size(), 6)):
		var l = Kit.label(str(lines[i]), 16, Pal.TEXT if i > 0 else first, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		l.modulate.a = 0.0
		l.set_meta("loot_line", str(lines[i]))
		col.add_child(l)
		_lines.append(l)
	if lines.size() > 6:
		var more = Kit.label("+%d more" % (lines.size() - 6), 13, Pal.MUTED, true)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		more.modulate.a = 0.0
		col.add_child(more)
		_lines.append(more)
	_hint = PixelFont.rect("TAP TO GO ON", 2, Pal.CREAM)
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hint.modulate.a = 0.0
	outer.add_child(_hint)
	# Every tap reaches the pop itself (a tap shows all, the next closes it).
	Kit.passthrough(outer)


func _wait(secs: float) -> void:
	var tw = create_tween()
	tw.tween_interval(maxf(0.01, secs))
	await tw.finished


func _alive(gen: int) -> bool:
	return is_instance_valid(self) and is_inside_tree() and gen == _gen and not _closing


func _run() -> void:
	_gen += 1
	var gen = _gen
	var tw = create_tween()
	tw.tween_property(_dim, "color:a", DIM, 0.18)
	# It drops in, rattles, and opens in light.
	_icon.scale = Vector2(0.3, 0.3)
	_icon.modulate.a = 0.0
	var it = _icon.create_tween()
	it.tween_property(_icon, "modulate:a", 1.0, 0.08)
	it.parallel().tween_property(_icon, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(4):
		it.tween_property(_icon, "rotation", 0.14 * (1.0 if i % 2 == 0 else -1.0), 0.07)
	it.tween_property(_icon, "rotation", 0.0, 0.05)
	RpgSfx.play(_sound)
	await _wait(0.62)
	if not _alive(gen):
		return
	_open_fx()
	await _wait(0.2)
	if not _alive(gen):
		return
	for i in range(_lines.size()):
		var l = _lines[i]
		Kit.fade_in(l, 0.14)
		Kit.pop(l, 1.12, 0.2)
		RpgSfx.play("loot", 1.0 + 0.07 * float(i))
		await _wait(0.24)
		if not _alive(gen):
			return
	_end()


## The lid is off: light, sparks, a punch of the icon.
func _open_fx() -> void:
	var at = _icon.get_global_rect().get_center() - global_position
	BattleFx.speed = 1.0
	BattleFx.flash(self, _color, 0.35, 0.3)
	if _rays == null:
		# (behind the chest, over the window's parchment: behind the window they would not be seen)
		_rays = BattleFx.at(_holder, "rays", _icon.position + _icon.size / 2.0, _color, 5.0, {"loop": true, "n": 14, "half": 34.0})
		if _rays != null:
			_holder.move_child(_rays, 0)
			_rays.modulate.a = 0.6
	BattleFx.at(self, "sparkle", at, Color(1, 1, 1), 0.9, {"n": 12, "half": 30.0})
	Kit.burst(_icon, _color, 28)
	Kit.pop(_icon, 1.25, 0.3)
	RpgSfx.buzz(3)


func _end() -> void:
	done = true
	for l in _lines:
		l.modulate.a = 1.0
	_icon.scale = Vector2.ONE
	_icon.rotation = 0.0
	_icon.modulate.a = 1.0
	_dim.color.a = DIM
	if _rays == null and is_inside_tree():
		_open_fx()
	_hint.modulate.a = 1.0


func _close() -> void:
	if _closing:
		return
	_closing = true
	_gen += 1
	Sfx.tap()
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if done:
			_close()
		else:
			_gen += 1
			_end()
