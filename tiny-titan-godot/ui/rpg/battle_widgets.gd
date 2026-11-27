class_name BattleWidgets
extends RefCounted
## The pieces of the battle screen (RPG_PLAN.md 10.2): BattleView puts them in
## fixed slots and only ever changes what they SHOW. Nothing here reads the
## battle by itself, the log or the save; colours are Pal's (a school's through
## RpgUi.color).
##
##   Pips        a row of pips (energy, guard, a cost): set_values(now, most)
##   StatusRow   up to three status icons, then "+N": set_statuses(list)
##   WeakRow     a foe's weak schools ("?" until learned) and the resisted one (struck through)
##   IntentTag   a foe's intent: its icon and a number or a word
##   FoePlate    a foe's name plate (a key: a tap opens its sheet). Narrow (three foes) it has five rows,
##               wide (one or two) four; metas bv_plate, bv_hp, bv_guard
##   HeroPlate   HP with numbers, energy pips, the gauge, statuses; metas bv_hp_hero, bv_energy, bv_gauge
##   Timeline    who acts next, as tiles: "YOU", "PET", a foe's number in its colour
##   MoveKey     an equipped move as a key in its school's colour; meta bv_move
##   ActKey      Strike, Guard, Item, Companion, Ultimate; meta bv_key
##   Arena       the backdrop at a whole-number scale, its ground line
##   banner()    big pixel words over the arena for a moment ("WAVE 2/3", "BREAK!")
##
## A key never changes its size, its place or its meta with its state; a key
## that cannot be used is drawn dim but still hears the tap (the view then
## says why).

const PLATE_WIDE_AT = 140.0
const PLATE_H_WIDE = 68.0
const PLATE_H_NARROW = 86.0
const STATUS_W = 70.0
const WEAK_W = 52.0
## A raised key's lip, in screen pixels (PixBox: two rows and the outline).
const DROP = 6


## The colour of a foe's place (0, 1, 2): its number on the plate and its tiles in the timeline.
static func slot_color(slot: int) -> Color:
	match slot:
		0:
			return Pal.DANGER
		1:
			return Pal.ACCENT2
	return Pal.MISC


## The colour of an HP bar at that share.
static func hp_color(share: float) -> Color:
	if share > 0.5:
		return Pal.GOOD
	if share > 0.25:
		return Pal.ACCENT2
	return Pal.DANGER


## Dark ink on a bright face, light text on a dark one.
static func ink_on(face: Color) -> Color:
	return Pal.INK if face.get_luminance() > 0.45 else Pal.TEXT


static func _styles(b: Button, looks: Dictionary) -> void:
	b.add_theme_stylebox_override("normal", looks["normal"])
	b.add_theme_stylebox_override("hover", looks["hover"])
	b.add_theme_stylebox_override("pressed", looks["pressed"])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("disabled", looks["disabled"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Big pixel words in the middle of `over` for a moment. They free themselves.
static func banner(over: Control, text: String, color: Color, hold: float = 0.7, px_scale: int = 3) -> void:
	if not is_instance_valid(over) or not over.is_inside_tree():
		return
	var r = PixelFont.rect(text, px_scale, color)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(r)
	r.size = r.custom_minimum_size
	r.position = ((over.size - r.custom_minimum_size) / 2.0).floor()
	r.pivot_offset = r.custom_minimum_size / 2.0
	r.scale = Vector2(0.6, 0.6)
	r.set_meta("bv_banner", text)
	var tw = r.create_tween()
	tw.tween_property(r, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.05, hold))
	tw.tween_property(r, "modulate:a", 0.0, 0.2)
	tw.tween_callback(r.queue_free)


# =============================================================================

## A row of pips: `n` of `of` lit. As many as fit the width it is given, each
## at most `pip` wide.
class Pips extends Control:
	var n: int = 0
	var of: int = 0
	var on_color: Color = Color.WHITE
	var pip: int = 8
	var tall: int = 8
	var gap: int = 2

	func _init(c: Color, pip_px: int = 8, tall_px: int = 8) -> void:
		on_color = c
		pip = pip_px
		tall = tall_px
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		custom_minimum_size = Vector2(pip_px, tall_px)

	func set_values(now: int, most: int) -> void:
		if now == n and most == of:
			return
		n = now
		of = most
		queue_redraw()

	func set_color(c: Color) -> void:
		if c != on_color:
			on_color = c
			queue_redraw()

	## A short flare when the count changes (nothing moves: a row of pips sits against the edge of its plate).
	func flash() -> void:
		if not is_inside_tree():
			return
		modulate = Color(1.7, 1.7, 1.7, 1.0)
		var tw = create_tween()
		tw.tween_property(self, "modulate", Color.WHITE, 0.25)

	func _draw() -> void:
		if of <= 0:
			return
		var w = clampf(floor((size.x + float(gap)) / float(of)) - float(gap), 3.0, float(pip))
		var y = floor((size.y - float(tall)) / 2.0)
		for i in range(of):
			var r = Rect2(float(i) * (w + float(gap)), y, w, float(tall))
			draw_rect(r, Pal.OUTLINE)
			draw_rect(r.grow(-1.0), on_color if i < n else Pal.WELL)


## Up to three statuses as icons, then "+N". One width whatever it shows.
class StatusRow extends HBoxContainer:
	var _sig: String = "-"

	func _init() -> void:
		add_theme_constant_override("separation", 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		custom_minimum_size = Vector2(BattleWidgets.STATUS_W, 16)
		set_meta("bv_status", "")

	## `list`: a unit's statuses ({"id", "turns", "stacks"}); `broken` puts the Broken mark first.
	func set_statuses(list: Array, broken: bool = false) -> void:
		var all = []
		if broken:
			all.append({"id": "broken", "stacks": 1})
		for st in list:
			if st is Dictionary:
				all.append(st)
		var ids = []
		for st in all:
			ids.append("%s%d" % [str(st.get("id", "")), int(st.get("stacks", 1))])
		var sig = ",".join(ids)
		if sig == _sig:
			return
		_sig = sig
		Kit.clear(self)
		for i in range(mini(3, all.size())):
			add_child(RpgUi.status_icon(all[i], 16))
		if all.size() > 3:
			add_child(Kit.vcenter(Kit.label("+%d" % (all.size() - 3), 11, Pal.TEXT, true)))
		var plain = []
		for st in all:
			plain.append(str(st.get("id", "")))
		set_meta("bv_status", ",".join(plain))


## A foe's schools as far as they are known: the weak ones as their icons, a
## "?" for each not found yet, the resisted one struck through.
class WeakRow extends Control:
	var marks: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = Vector2(BattleWidgets.WEAK_W, 16)
		set_meta("bv_weak", "")

	## `weak_total`: how many weak schools the foe has; `known`: RpgBattle.known's answer.
	func set_known(weak_total: int, known: Dictionary) -> void:
		var list = []
		var said = []
		for sc in known.get("weak", []):
			list.append({"school": str(sc), "kind": "weak"})
			said.append(str(sc))
		for i in range(maxi(0, weak_total - known.get("weak", []).size())):
			list.append({"school": "", "kind": "unknown"})
			said.append("?")
		for sc in known.get("resist", []):
			list.append({"school": str(sc), "kind": "resist"})
			said.append("-" + str(sc))
		marks = list
		set_meta("bv_weak", ",".join(said))
		queue_redraw()

	func _draw() -> void:
		var x = 0.0
		for i in range(mini(3, marks.size())):
			var m = marks[i]
			if str(m.kind) == "unknown":
				draw_rect(Rect2(x, 0, 16, 16), Pal.OUTLINE)
				draw_rect(Rect2(x + 1.0, 1, 14, 14), Pal.WELL)
				var q = PixelFont.tex("?", Pal.MUTED, false)
				draw_texture(q, Vector2(x + floor((16.0 - float(q.get_width())) / 2.0), floor((16.0 - float(q.get_height())) / 2.0)))
			else:
				draw_texture(Icons.tex(RpgUi.school_icon(str(m.school))), Vector2(x, 0))
				if str(m.kind) == "resist":
					draw_line(Vector2(x + 1.0, 15), Vector2(x + 15.0, 1), Pal.DANGER, 2.0, false)
				else:
					draw_rect(Rect2(x + 2.0, 15, 12, 1), RpgUi.color(str(m.school)))
			x += 18.0


## What a foe will do next: an icon, and the damage (as things stand), the
## turns of a countdown, or a word.
class IntentTag extends HBoxContainer:
	var wide: bool = false
	var _icon: TextureRect
	var _label: Label

	func _init(is_wide: bool) -> void:
		wide = is_wide
		add_theme_constant_override("separation", 2)
		alignment = BoxContainer.ALIGNMENT_END
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon = Icons.rect("in_attack", 16)
		add_child(_icon)
		_label = Kit.label("", 12, Pal.TEXT, true)
		_label.clip_text = true
		_label.custom_minimum_size = Vector2(22, 0)
		if wide:
			_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(_label)
		set_meta("bv_intent", "")

	## The words of an intent (the same on the plate and in the sheet).
	static func words(intent: Dictionary, long: bool) -> String:
		if intent.is_empty():
			return ""
		var kind = str(intent.get("kind", ""))
		var dmg = int(round(float(intent.get("dmg", 0))))
		var count = int(intent.get("count", 0))
		if kind == "stunned":
			return "stunned" if long else ""
		if count > 0:
			return ("in %d" % count) if long else str(count)
		if bool(intent.get("windup", false)) and not bool(intent.get("charged", false)):
			return "charging" if long else ""
		if dmg > 0:
			return str(dmg)
		return str(intent.get("name", "")) if long else ""

	func set_intent(intent: Dictionary) -> void:
		var icon_name = str(intent.get("icon", ""))
		if intent.is_empty():
			_icon.modulate.a = 0.0
		else:
			_icon.modulate.a = 1.0
			if bool(intent.get("windup", false)) and not bool(intent.get("charged", false)) and Icons.has_icon("in_charge"):
				icon_name = "in_charge"
			if not Icons.has_icon(icon_name):
				icon_name = "in_attack"
			_icon.texture = Icons.tex(icon_name)
		var text = IntentTag.words(intent, wide)
		_label.text = text
		var count = int(intent.get("count", 0))
		_label.add_theme_color_override("font_color", Pal.ACCENT2 if count > 0 else Pal.TEXT)
		set_meta("bv_intent", "%s:%s" % [str(intent.get("kind", "")), text])


## A foe's name plate. A key: a tap opens the foe's sheet. Its width is set
## when it is made (a wave with another number of foes gets new plates).
class FoePlate extends Button:
	var uid: String = ""
	var wide: bool = false
	var hp: int = 0
	var hp_max: int = 1
	var guard: int = 0
	var guard_max: int = 0
	var _bar: Bar
	var _hp_label: Label = null
	var _name: Label
	var _pips: Pips
	var _weak: WeakRow
	var _statuses: StatusRow
	var _intent: IntentTag
	var _picked: bool = false
	var _rects: Array = []

	func _init(unit_id: String, w: float, slot: int) -> void:
		uid = unit_id
		wide = w >= BattleWidgets.PLATE_WIDE_AT
		var h = BattleWidgets.PLATE_H_WIDE if wide else BattleWidgets.PLATE_H_NARROW
		focus_mode = Control.FOCUS_NONE
		clip_contents = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(w, h)
		size = Vector2(w, h)
		set_meta("bv_plate", uid)
		set_meta("anchor_id", "bv_plate:" + uid)
		set_meta("bv_hp", 0)
		set_meta("bv_guard", 0)
		_restyle()
		var inner = w - 8.0
		var badge = Kit.label(str(slot + 1), 10, Pal.INK, true)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.clip_text = true
		badge.add_theme_stylebox_override("normal", Kit.sbox(BattleWidgets.slot_color(slot), 3, null, 0, 0, 0))
		_put(badge, 4, 3, 14, 14)
		var num_w = 38.0 if wide else 0.0
		_name = Kit.clip("", 11, Pal.TEXT, true)
		_put(_name, 21, 2, inner - 17.0 - num_w, 15)
		if wide:
			_hp_label = Kit.label("", 11, Pal.MUTED, true)
			_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_hp_label.clip_text = true
			_put(_hp_label, w - 4.0 - num_w, 2, num_w, 15)
		_bar = Bar.new(1.0, Pal.GOOD, 7)
		_bar.ghost = true
		_bar.size_flags_vertical = Control.SIZE_FILL
		_put(_bar, 4, 19, inner, 10)
		_pips = Pips.new(Pal.SECOND, 7, 9)
		_weak = WeakRow.new()
		_statuses = StatusRow.new()
		_intent = IntentTag.new(wide)
		if wide:
			_put(_pips, 4, 34, inner - BattleWidgets.WEAK_W - 4.0, 10)
			_put(_weak, w - 4.0 - BattleWidgets.WEAK_W, 31, BattleWidgets.WEAK_W, 16)
			_put(_statuses, 4, 49, BattleWidgets.STATUS_W, 16)
			_put(_intent, 4.0 + BattleWidgets.STATUS_W + 4.0, 49, inner - BattleWidgets.STATUS_W - 4.0, 16)
		else:
			_put(_pips, 4, 34, inner - 44.0, 10)
			_put(_intent, w - 4.0 - 42.0, 31, 42, 16)
			_put(_weak, 4, 49, BattleWidgets.WEAK_W, 16)
			_put(_statuses, 4, 67, BattleWidgets.STATUS_W, 16)

	func _put(c: Control, x: float, y: float, w: float, h: float) -> void:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		c.position = Vector2(x, y)
		c.size = Vector2(w, h)
		_rects.append([c, Rect2(x, y, w, h)])

	## A label only knows how high its own font is once it is in the tree
	## (before that it answers with the default font's height), so every part
	## is put in its place again then.
	func _ready() -> void:
		for r in _rects:
			r[0].position = r[1].position
			r[0].size = r[1].size

	func _restyle() -> void:
		var sb = Kit.sbox(Pal.with_alpha(Pal.OUTLINE, 0.84), 4, Pal.ACCENT if _picked else Pal.LINE, 2 if _picked else 1, 0, 0)
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(k, sb)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	## Everything a plate shows, at once, as the unit is now.
	func set_unit(f: Dictionary, known: Dictionary) -> void:
		_name.text = str(f.get("name", ""))
		set_hp(int(f.get("hp", 0)), int(f.get("hp_max", 1)), false)
		set_guard(int(f.get("guard", 0)), int(f.get("guard_max", 0)))
		set_statuses(f.get("statuses", []), bool(f.get("broken", false)))
		set_known(f.get("weak", []).size(), known)
		set_intent(f.get("intent", {}) if bool(f.get("alive", true)) else {})
		set_down(not bool(f.get("alive", true)))

	func set_hp(now: int, most: int, animate: bool = true) -> void:
		hp = maxi(0, now)
		hp_max = maxi(1, most)
		var share = float(hp) / float(hp_max)
		_bar.set_color(BattleWidgets.hp_color(share))
		_bar.set_value(share, animate, 0.3)
		if _hp_label != null:
			_hp_label.text = str(hp)
		set_meta("bv_hp", hp)

	func set_guard(now: int, most: int) -> void:
		var popped = now != guard
		guard = now
		guard_max = most
		_pips.set_values(now, most)
		set_meta("bv_guard", now)
		if popped:
			_pips.flash()

	func set_statuses(list: Array, broken: bool = false) -> void:
		_statuses.set_statuses(list, broken)

	func set_known(weak_total: int, known: Dictionary) -> void:
		_weak.set_known(weak_total, known)

	func set_intent(intent: Dictionary) -> void:
		_intent.set_intent(intent)

	func set_picked(on: bool) -> void:
		if on != _picked:
			_picked = on
			_restyle()

	## A foe that is down: its plate fades (it stays in its place).
	func set_down(on: bool) -> void:
		modulate.a = 0.4 if on else 1.0

	func weak_shown() -> String:
		return str(_weak.get_meta("bv_weak", ""))

	func statuses_shown() -> String:
		return str(_statuses.get_meta("bv_status", ""))

	func intent_shown() -> String:
		return str(_intent.get_meta("bv_intent", ""))


## The hero's plate: HP with its numbers, energy pips, the gauge, statuses.
## A key: a tap opens the hero's sheet.
class HeroPlate extends Button:
	var hp: int = 0
	var hp_max: int = 1
	var energy: int = 0
	var gauge: int = 0
	var _hp_bar: Bar
	var _hp_label: Label
	var _pips: Pips
	var _gauge_bar: Bar
	var _statuses: StatusRow

	func _init(h: int, en_max: int) -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		clip_contents = true
		custom_minimum_size = Vector2(0, h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		set_meta("bv_plate", "hero")
		set_meta("anchor_id", "bv_plate:hero")
		var sb = PixBox.make(Pal.PANEL, {"ring": Pal.BORDER, "lip": 0, "pad_h": 0, "pad_v": 0})
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(k, sb)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var col = Kit.vbox(4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(col)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 8
		col.offset_right = -8
		col.offset_top = 4
		col.offset_bottom = -4
		var top = Kit.hbox(6)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(Icons.rect("heart", 16))
		_hp_bar = Bar.new(1.0, Pal.GOOD, 12)
		_hp_bar.ghost = true
		top.add_child(_hp_bar)
		_hp_label = Kit.label("", 13, Pal.TEXT, true)
		_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_hp_label.clip_text = true
		_hp_label.custom_minimum_size = Vector2(78, 0)
		_hp_label.set_meta("bv_hp_hero", 0)
		top.add_child(_hp_label)
		col.add_child(top)
		var low = Kit.hbox(6)
		low.mouse_filter = Control.MOUSE_FILTER_IGNORE
		low.add_child(Icons.rect("energy", 16))
		_pips = Pips.new(Pal.ACCENT, 9, 10)
		_pips.custom_minimum_size = Vector2(float(clampi(en_max, 1, 12)) * 11.0, 10)
		_pips.set_meta("bv_energy", 0)
		low.add_child(_pips)
		low.add_child(Icons.rect("gauge", 16))
		_gauge_bar = Bar.new(0.0, RpgUi.color("grit"), 8)
		_gauge_bar.set_meta("bv_gauge", 0)
		low.add_child(_gauge_bar)
		_statuses = StatusRow.new()
		low.add_child(_statuses)
		col.add_child(low)

	func set_hp(now: int, most: int, animate: bool = true) -> void:
		hp = maxi(0, now)
		hp_max = maxi(1, most)
		var share = float(hp) / float(hp_max)
		_hp_bar.set_color(BattleWidgets.hp_color(share))
		_hp_bar.set_value(share, animate, 0.3)
		_hp_label.text = "%d / %d" % [hp, hp_max]
		_hp_label.set_meta("bv_hp_hero", hp)

	func set_energy(now: int, most: int) -> void:
		var popped = now != energy
		energy = now
		_pips.set_values(now, most)
		_pips.set_meta("bv_energy", now)
		if popped:
			_pips.flash()

	## `v`: 0..100.
	func set_gauge(v: float, animate: bool = true) -> void:
		gauge = int(floor(v + 0.0001))
		var full = v >= RpgDefs.GAUGE_MAX
		_gauge_bar.set_color(Pal.ACCENT if full else RpgUi.color("grit"))
		_gauge_bar.set_value(v / RpgDefs.GAUGE_MAX, animate, 0.3)
		_gauge_bar.set_meta("bv_gauge", gauge)

	func set_statuses(list: Array) -> void:
		_statuses.set_statuses(list)

	func statuses_shown() -> String:
		return str(_statuses.get_meta("bv_status", ""))


## Who acts next, as tiles: "YOU" in gold, "PET" in green, a foe's number in
## the colour of its place. The first tile (whose turn is next) is framed.
class Timeline extends Control:
	const HEAD_W = 52.0
	const TILE_H = 22.0
	var tiles: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = Vector2(0, TILE_H + 4.0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		set_meta("bv_timeline", "")

	## `list`: [{"id", "kind": "hero"|"pet"|"foe", "slot"}], the next first.
	func set_tiles(list: Array) -> void:
		tiles = list
		var ids = []
		for t in list:
			ids.append(str(t.get("id", "")))
		set_meta("bv_timeline", ",".join(ids))
		queue_redraw()

	func _draw() -> void:
		var head = PixelFont.tex("NEXT", Pal.MUTED, false)
		draw_texture_rect(head, Rect2(0, floor((size.y - float(head.get_height()) * 2.0) / 2.0), float(head.get_width()) * 2.0, float(head.get_height()) * 2.0), false)
		var count = 7
		var w = minf(44.0, floor((size.x - HEAD_W - 4.0 * float(count - 1)) / float(count)))
		var y = floor((size.y - TILE_H) / 2.0)
		for i in range(mini(count, tiles.size())):
			var t = tiles[i]
			var kind = str(t.get("kind", "foe"))
			var col = Pal.ACCENT if kind == "hero" else (Pal.GOOD if kind == "pet" else BattleWidgets.slot_color(int(t.get("slot", 0))))
			var text = "YOU" if kind == "hero" else ("PET" if kind == "pet" else str(int(t.get("slot", 0)) + 1))
			var r = Rect2(HEAD_W + float(i) * (w + 4.0), y, w, TILE_H)
			draw_rect(r, Pal.TEXT if i == 0 else Pal.OUTLINE)
			draw_rect(r.grow(-2.0), col if i == 0 else col.darkened(0.3))
			var g = PixelFont.tex(text, Pal.INK, false)
			var gs = Vector2(float(g.get_width()) * 2.0, float(g.get_height()) * 2.0)
			draw_texture_rect(g, Rect2((r.position + (r.size - gs) / 2.0).floor(), gs), false)


## An equipped move as a key in its school's colour: icon, name, cost pips, the
## rest it still needs, the damage it would do to the picked target, WEAK /
## RESIST / KO. Dim when it cannot be used (it still hears the tap).
class MoveKey extends Button:
	var move_id: String = ""
	var school: String = "plain"
	var usable: bool = true
	var why: String = ""
	var attack: bool = true
	var _col: Color
	var _support: String = "BUFF"
	var _on: Dictionary
	var _off: Dictionary
	var _row: HBoxContainer
	var _name: Label
	var _cost: Pips
	var _cd: Label
	var _dmg: Label
	var _tag: Label
	var _icon: TextureRect

	func _init(move: Dictionary, h: int) -> void:
		move_id = str(move.get("id", ""))
		school = str(move.get("school", "plain"))
		attack = str(move.get("kind", "attack")) == "attack"
		_support = MoveKey.support_word(move)
		_col = RpgUi.color(school)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		clip_contents = true
		custom_minimum_size = Vector2(0, h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		set_meta("bv_move", move_id)
		set_meta("anchor_id", "bv_move:" + move_id)
		set_meta("bv_ok", true)
		_on = PixBox.button_set(_col, _col.darkened(0.45), 6, 4, 2)
		var faded = _col.lerp(Pal.PANEL, 0.72)
		_off = PixBox.button_set(faded, _col.darkened(0.45).lerp(Pal.OUTLINE, 0.6), 6, 4, 2)
		BattleWidgets._styles(self, _on)
		_row = Kit.hbox(6)
		_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_row)
		_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_row.offset_left = 7
		_row.offset_right = -7
		_row.offset_top = 3
		_row.offset_bottom = -(3 + BattleWidgets.DROP)
		# The icon on a dark tile: a school's icon is drawn in the school's own colour, like the key.
		var tile = PanelContainer.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.add_theme_stylebox_override("panel", Kit.sbox(Pal.with_alpha(Pal.OUTLINE, 0.82), 4, null, 0, 2, 2))
		_icon = Icons.rect(RpgUi.school_icon(school), 32)
		tile.add_child(_icon)
		_row.add_child(tile)
		var mid = Kit.vbox(2)
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		_name = Kit.clip(str(move.get("name", "")), 14, Pal.INK, true)
		mid.add_child(_name)
		var facts = Kit.hbox(5)
		facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cost = Pips.new(Pal.INK, 7, 9)
		facts.add_child(_cost)
		_cd = Kit.clip("", 11, Pal.INK, true)
		facts.add_child(_cd)
		mid.add_child(facts)
		_row.add_child(mid)
		var right = Kit.vbox(1)
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		right.custom_minimum_size = Vector2(60, 0)
		_dmg = Kit.label("", 15, Pal.INK, true)
		_dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_dmg.clip_text = true
		right.add_child(_dmg)
		_tag = Kit.label("", 10, Pal.TEXT, true)
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tag.size_flags_horizontal = Control.SIZE_SHRINK_END
		_tag.custom_minimum_size = Vector2(46, 0)
		_tag.clip_text = true
		right.add_child(_tag)
		_row.add_child(right)
		button_down.connect(_sink.bind(true))
		button_up.connect(_sink.bind(false))
		Kit.juice(self)

	## What a support move does, in one word for its key: a heal before a
	## shield before a cleanse before a status, whatever order they are written in.
	static func support_word(move: Dictionary) -> String:
		var seen = {}
		for e in move.get("fx", []):
			if not (e is Dictionary):
				continue
			var fx = e.get("do") if (str(e.get("k", "")) == "when" and e.get("do") is Dictionary) else e
			var k = str(fx.get("k", ""))
			if k == "status":
				var row = RpgDefs.STATUS.get(str(fx.get("id", "")), {})
				var hex = str(row.get("kind", "buff")) == "debuff" and str(fx.get("to", "")) != "self" and str(move.get("target", "self")) == "foe"
				k = "debuff" if hex else "buff"
			seen[k] = true
		for pair in [["heal", "HEAL"], ["shield", "SHIELD"], ["cleanse", "CLEANSE"], ["buff", "BUFF"], ["debuff", "DEBUFF"], ["dispel", "DISPEL"],
				["energy", "ENERGY"], ["gauge", "GAUGE"], ["cd_cut", "REFRESH"], ["extra_turn", "AGAIN"], ["delay", "DELAY"], ["interrupt", "STOP"]]:
			if seen.has(pair[0]):
				return str(pair[1])
		return "BUFF"

	## The face and what is on it sink together.
	func _sink(down: bool) -> void:
		_row.offset_top = 3 + (BattleWidgets.DROP if down else 0)
		_row.offset_bottom = -3 if down else -(3 + BattleWidgets.DROP)

	## `o`: its row of RpgBattle.options ({"ok", "why", "cost", "cd"}); `pv`: RpgBattle.preview on the picked target.
	func set_state(o: Dictionary, pv: Dictionary) -> void:
		usable = bool(o.get("ok", false))
		why = str(o.get("why", ""))
		BattleWidgets._styles(self, _on if usable else _off)
		var fg = Pal.INK if usable else Pal.MUTED
		_name.add_theme_color_override("font_color", fg)
		_cd.add_theme_color_override("font_color", fg)
		_dmg.add_theme_color_override("font_color", fg)
		_icon.modulate.a = 1.0 if usable else 0.5
		var cost = int(o.get("cost", 0))
		_cost.custom_minimum_size = Vector2(float(maxi(1, cost)) * 9.0, 9)
		_cost.set_values(cost, cost)
		_cost.set_color(Pal.DANGER if why == "energy" else fg)
		var cd = int(o.get("cd", 0))
		_cd.text = ("rest %d" % cd) if cd > 0 else ("free" if cost <= 0 else "")
		var dmg = ""
		var tag = ""
		if attack:
			var lo = int(pv.get("lo", 0))
			var hi = int(pv.get("hi", 0))
			if hi > 0:
				dmg = str(lo) if lo == hi else "%d-%d" % [lo, hi]
			if bool(pv.get("kills", false)):
				tag = "KO"
			elif bool(pv.get("weak", false)):
				tag = "WEAK"
			elif bool(pv.get("resist", false)):
				tag = "RESIST"
		else:
			tag = _support
		_dmg.text = dmg
		_tag.text = tag
		var bg = Pal.ACCENT if tag == "KO" else (Pal.MUTED if tag == "RESIST" else Pal.INK)
		_tag.add_theme_stylebox_override("normal", Kit.sbox(bg, 3, null, 0, 4, 0))
		_tag.add_theme_color_override("font_color", BattleWidgets.ink_on(bg))
		_tag.modulate.a = 0.0 if tag == "" else (1.0 if usable else 0.6)
		set_meta("bv_ok", usable)
		set_meta("bv_dmg", dmg)
		set_meta("bv_tag", tag)


## One of the five keys under the moves: an icon over a word, a small count in
## its corner. Its word never changes.
class ActKey extends Button:
	var key_id: String = ""
	var usable: bool = true
	var _face: Color
	var _on: Dictionary
	var _lit: Dictionary
	var _off: Dictionary
	var _col: VBoxContainer
	var _label: Label
	var _badge: Label
	var _icon: TextureRect

	func _init(id: String, word: String, icon_name: String, face: Color, h: int) -> void:
		key_id = id
		_face = face
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		clip_contents = true
		custom_minimum_size = Vector2(0, h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		set_meta("bv_key", id)
		set_meta("anchor_id", "bv_key:" + id)
		set_meta("bv_ok", true)
		_on = PixBox.button_set(face, face.darkened(0.45), 4, 4, 2)
		_lit = PixBox.button_set(Pal.ACCENT, Pal.ACCENT_DARK, 4, 4, 2)
		_off = PixBox.button_set(face.lerp(Pal.PANEL, 0.72), face.darkened(0.45).lerp(Pal.OUTLINE, 0.6), 4, 4, 2)
		BattleWidgets._styles(self, _on)
		_col = Kit.vbox(0)
		_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(_col)
		_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_col.offset_left = 2
		_col.offset_right = -2
		_col.offset_top = 3
		_col.offset_bottom = -(2 + BattleWidgets.DROP)
		_icon = Icons.rect(icon_name if Icons.has_icon(icon_name) else "star", 16)
		_col.add_child(_icon)
		_label = Kit.clip(word, 11, BattleWidgets.ink_on(face), true)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_col.add_child(_label)
		_badge = Kit.label("", 10, BattleWidgets.ink_on(face), true)
		_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_badge.clip_text = true
		add_child(_badge)
		_badge.anchor_left = 1.0
		_badge.anchor_right = 1.0
		_badge.offset_left = -40
		_badge.offset_right = -5
		_badge.offset_top = 1
		_badge.offset_bottom = 15
		button_down.connect(_sink.bind(true))
		button_up.connect(_sink.bind(false))
		Kit.juice(self)

	func _sink(down: bool) -> void:
		_col.offset_top = 3 + (BattleWidgets.DROP if down else 0)
		_col.offset_bottom = -2 if down else -(2 + BattleWidgets.DROP)

	## `on`: it can be used now; `badge`: the count in its corner; `lit`: gold (the ultimate, ready).
	func set_state(on: bool, badge: String = "", lit: bool = false) -> void:
		usable = on
		BattleWidgets._styles(self, _off if not on else (_lit if lit else _on))
		var fg = Pal.MUTED if not on else BattleWidgets.ink_on(Pal.ACCENT if lit else _face)
		_label.add_theme_color_override("font_color", fg)
		_badge.add_theme_color_override("font_color", fg)
		_badge.text = badge
		_icon.modulate.a = 1.0 if on else 0.5
		set_meta("bv_ok", on)
		set_meta("bv_badge", badge)
		set_meta("bv_lit", lit and on)


## The backdrop of a fight at a whole-number scale: as wide as the arena or a
## little wider (its sides are cut off), standing on the arena's bottom edge;
## the sky's own colour above it when the arena is taller.
class Arena extends Control:
	var scene_id: String = ""
	## Shadows on the ground (Rect2), under what stands in the arena without one of its own: the hero.
	var shadows: Array = []
	var _tex: Texture2D = null
	var _sky: Color = Color.BLACK

	func _init(id: String) -> void:
		scene_id = id
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_PASS
		_tex = RealmScenes.texture(id)
		_sky = Pal.BG
		if _tex != null:
			var img = _tex.get_image()
			if img != null and img.get_width() > 0:
				_sky = img.get_pixel(int(img.get_width() / 2.0), 0)

	## Screen pixels per art pixel.
	func k() -> int:
		return maxi(1, int(ceil((size.x - 0.5) / float(RealmScenes.W))))

	## The y of the ground line the fighters stand on.
	## (round(): a shake moves the arena by parts of a pixel, and Godot then keeps its height a hair off whole.)
	func ground() -> float:
		return round(size.y) - float((RealmScenes.H - RealmScenes.ground_y(scene_id)) * k())

	func _draw() -> void:
		var kk = float(k())
		var w = float(RealmScenes.W) * kk
		var h = float(RealmScenes.H) * kk
		var y = size.y - h
		if y > 0.0:
			draw_rect(Rect2(0, 0, size.x, y), _sky)
		if _tex != null:
			draw_texture_rect(_tex, Rect2(floor((size.x - w) / 2.0), y, w, h), false)
		for r in shadows:
			draw_rect(r, Pal.with_alpha(Pal.OUTLINE, 0.3))
