class_name RoadMap
extends Control
## A region's road as a ROAD (the user, 2026-11-26: "feels like stuff is
## missing"; the stages used to be a list of tiles): its stages are places on
## a path that winds down the page, three to a row, the boss alone at the end.
## A place won is a green medal with its stars, the one to fight next is gold
## and beats, with a marker hopping over it and the path leading to it
## marching; what lies beyond is grey and locked. The ground takes its colour
## from the region's own picture.
##
##   var road = RoadMap.new()
##   road.setup(stages, rpg, Callable(tap_stage), "rustyard")   # tap_stage(stage_id, name_of_the_stage_before)
##
## Every place is a Button (metas map_stage, map_state "done" | "open" |
## "locked", map_stage_stars, anchor_id), so tests and walkthroughs press it as
## they pressed the old tiles. Its size and place never change with its state.

const PER_ROW = 3
const ROW_H = 94.0
const TOP = 10.0
const MEDAL = 44.0
const BOSS_MEDAL = 56.0
const BOSS_ROW_H = 108.0
const ICONS = {"battle": "", "elite": "skull", "cache": "chest_wood", "boss": "crown"}
## Redraws a second while something on the road moves.
const FPS = 12.0

var _places: Array = []
var _scene: String = ""
var _age: float = 0.0
var _since: float = 0.0
var _ground: Color = Color(0.2, 0.2, 0.25)
var _current: int = -1
## What every place was the last time a road was drawn, and the ones that have changed since (for a moment):
## coming back from a win, its medal lights up and the next place answers.
static var _seen: Dictionary = {}
static var _fresh: Dictionary = {}
const FRESH_MS = 1500


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func setup(stages: Array, rpg: Dictionary, tap: Callable, scene_id: String) -> void:
	_scene = scene_id
	var tex = RealmScenes.texture(scene_id)
	var img = tex.get_image() if tex != null else null
	if img != null and img.get_width() > 0:
		_ground = img.get_pixel(int(img.get_width() / 2.0), img.get_height() - 3)
	_places = []
	_current = -1
	for i in range(stages.size()):
		var st = stages[i]
		var id = str(st.id)
		var state = "done" if RpgWorld.done(rpg, id) else ("open" if RpgWorld.is_open(rpg, id) else "locked")
		var kind = str(st.get("kind", "battle"))
		var stars = 0
		var got = rpg.get("stages", {}).get(id, {}).get("stars", [])
		if got is Array:
			for s in got:
				if bool(s):
					stars += 1
		var b = Place.new()
		b.stage = st
		b.state = state
		b.kind = kind
		b.stars = stars
		b.boss = kind == "boss"
		b.set_meta("map_stage", id)
		b.set_meta("map_state", state)
		b.set_meta("anchor_id", "map_stage:" + id)
		if kind != "cache":
			b.set_meta("map_stage_stars", stars)
		var before = str(stages[i - 1].name) if i > 0 else ""
		b.pressed.connect(_pressed.bind(b, tap, id, before))
		add_child(b)
		_places.append(b)
		if state == "open" and _current < 0:
			_current = i
	custom_minimum_size = Vector2(0, _height())
	resized.connect(_place)
	_place()
	set_process(_current >= 0)
	var now = Time.get_ticks_msec()
	for b in _places:
		var id = str(b.get_meta("map_stage"))
		var was = _seen.get(id)
		if was != null and str(was) != b.state:
			_fresh[id] = {"to": b.state, "at": now}
		_seen[id] = b.state
		var f = _fresh.get(id)
		if f != null and now - int(f.at) < FRESH_MS and str(f.to) == b.state:
			var tw = b.create_tween()
			tw.tween_interval(maxf(0.05, 0.35 - float(now - int(f.at)) / 1000.0) + (0.25 if b.state == "open" else 0.0))
			tw.tween_callback(_light_up.bind(b, id))


func _pressed(b: Place, tap: Callable, id: String, before: String) -> void:
	if b.state != "locked":
		RpgSfx.play("select")
		Kit.pop(b, 1.06, 0.16)
	if tap.is_valid():
		tap.call(id, before)


func _light_up(b: Place, id: String) -> void:
	if not _fresh.has(id) or not is_instance_valid(b) or not b.is_inside_tree():
		return
	_fresh.erase(id)
	if b.state == "done":
		Kit.burst(b, Pal.GOOD, 22)
		Kit.pop(b, 1.2, 0.3)
		RpgSfx.star(clampi(b.stars - 1, 0, 2))
	else:
		Kit.burst(b, Pal.ACCENT, 14)
		Kit.pop(b, 1.14, 0.26)
		RpgSfx.play("select", 1.3)


## Rows of three; a boss at the end stands alone on a row of its own.
func _rows() -> Array:
	var rows = []
	var n = _places.size()
	var last_alone = n > 1 and _places[n - 1].boss
	var body = n - 1 if last_alone else n
	var i = 0
	while i < body:
		var row = []
		for j in range(PER_ROW):
			if i + j < body:
				row.append(i + j)
		rows.append(row)
		i += PER_ROW
	if last_alone:
		rows.append([n - 1])
	return rows


func _height() -> float:
	var rows = _rows()
	var h = TOP
	for r in rows:
		h += BOSS_ROW_H if (r.size() == 1 and _places[r[0]].boss) else ROW_H
	return h + 6.0


func _place() -> void:
	var w = size.x
	if w <= 0.0:
		return
	var col_w = floor(w / float(PER_ROW))
	var y = TOP
	var rows = _rows()
	for ri in range(rows.size()):
		var row = rows[ri]
		var alone = row.size() == 1 and _places[row[0]].boss
		var rh = BOSS_ROW_H if alone else ROW_H
		for k in range(row.size()):
			var b = _places[row[k]]
			# The road winds: every other row runs right to left.
			var col = k if ri % 2 == 0 else PER_ROW - 1 - k
			var cx = floor(w / 2.0) if alone else floor(col_w * (float(col) + 0.5))
			b.size = Vector2(col_w - 6.0, rh - 6.0)
			b.position = Vector2(floor(cx - b.size.x / 2.0), y)
			b.center = Vector2(cx, y + (BOSS_MEDAL if alone else MEDAL) / 2.0 + 4.0)
		y += rh
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or TouchScroll.scrolling:
		return
	_age += delta
	_since += delta
	if _since >= 1.0 / FPS:
		_since = 0.0
		queue_redraw()
		if _current >= 0 and _current < _places.size():
			_places[_current].beat = 0.5 + 0.5 * sin(_age * 4.0)
			_places[_current].queue_redraw()


func _draw() -> void:
	var w = size.x
	var h = size.y
	# The ground: the region's own colour, darker, with a scatter of lighter and darker specks.
	var base = _ground.darkened(0.55).lerp(Pal.WELL, 0.35)
	draw_rect(Rect2(0, 0, w, h), base)
	var s = 4.0
	for i in range(70):
		var rx = _rand(i, 3)
		var ry = _rand(i, 7)
		var c = base.lightened(0.12) if i % 3 == 0 else base.darkened(0.18)
		draw_rect(Rect2(floor(rx * w / s) * s, floor(ry * h / s) * s, s * (2.0 if i % 5 == 0 else 1.0), s), c)
	draw_rect(Rect2(0, 0, w, 2), Pal.OUTLINE)
	draw_rect(Rect2(0, h - 2, w, 2), Pal.OUTLINE)
	# The path, place to place. Along a row it runs straight; down to the next row it swings out round the
	# names to the edge of the road and back in.
	var col_w = floor(w / float(PER_ROW))
	for i in range(_places.size() - 1):
		var a = _places[i]
		var b = _places[i + 1]
		var pts = [a.center]
		if absf(a.center.y - b.center.y) > 1.0:
			var side = 1.0 if a.center.x > w / 2.0 else -1.0
			var ex = clampf(a.center.x + side * (col_w / 2.0 - 8.0), 8.0, w - 8.0)
			pts.append(Vector2(ex, a.center.y))
			pts.append(Vector2(ex, b.center.y))
		pts.append(b.center)
		_stones(pts, a.state == "done" and b.state == "done", a.state == "done" and b.state == "open",
			(BOSS_MEDAL if a.boss else MEDAL) / 2.0 + 6.0, (BOSS_MEDAL if b.boss else MEDAL) / 2.0 + 6.0)
	# The marker over the place to fight next.
	if _current >= 0 and _current < _places.size():
		var p = _places[_current]
		var top = p.center.y - (BOSS_MEDAL if p.boss else MEDAL) / 2.0
		var hop = floor(absf(sin(_age * 3.4)) * 5.0)
		var x = p.center.x
		var y = top - 4.0 - hop
		for r in range(4):
			var half = float(3 - r) * 2.0 + 1.0
			draw_rect(Rect2(x - half - 1.0, y - float(3 - r) * 2.0 - 3.0, half * 2.0 + 2.0, 2), Pal.OUTLINE)
			draw_rect(Rect2(x - half, y - float(3 - r) * 2.0 - 2.0, half * 2.0, 2), Pal.ACCENT)


## A path of square stones along `pts`, leaving `lead` and `tail` free at its ends (the medals): bright
## where it was walked, marching towards the place that is next, faint beyond.
func _stones(pts: Array, walked: bool, next: bool, lead: float, tail: float) -> void:
	var total = 0.0
	for k in range(pts.size() - 1):
		total += (pts[k + 1] - pts[k]).length()
	var step = 12.0
	var t = lead + (fmod(_age * 18.0, step) if next else 0.0)
	var c = Pal.GOOD if walked else (Pal.ACCENT if next else Pal.with_alpha(Pal.MUTED, 0.45))
	while t < total - tail:
		var left = t
		var p = pts[0]
		for k in range(pts.size() - 1):
			var seg = (pts[k + 1] - pts[k]).length()
			if left <= seg or k == pts.size() - 2:
				p = pts[k] + (pts[k + 1] - pts[k]) * (left / maxf(1.0, seg))
				break
			left -= seg
		p = p.floor()
		draw_rect(Rect2(p.x - 4.0, p.y - 4.0, 8, 8), Pal.OUTLINE)
		draw_rect(Rect2(p.x - 3.0, p.y - 3.0, 6, 6) if (walked or next) else Rect2(p.x - 2.0, p.y - 2.0, 4, 4), c)
		t += step


static func _rand(i: int, salt: int) -> float:
	var v = sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floor(v)


# =============================================================================

## One place on the road: a medal, its stars, its name.
class Place extends Button:
	var stage: Dictionary = {}
	var state: String = "locked"
	var kind: String = "battle"
	var stars: int = 0
	var boss: bool = false
	## Where its medal's middle is, in the road's own pixels.
	var center: Vector2 = Vector2.ZERO
	## 0..1: the place to fight next beats.
	var beat: float = 0.0
	var _name: Label = null

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(k, StyleBoxEmpty.new())

	func _ready() -> void:
		_name = Kit.clip(str(stage.get("name", "")), 11, Pal.TEXT if state != "locked" else Pal.MUTED, state == "open")
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.add_theme_color_override("font_outline_color", Pal.OUTLINE)
		_name.add_theme_constant_override("outline_size", 3)
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_name)
		resized.connect(_fit)
		_fit()

	func _fit() -> void:
		if _name != null:
			_name.size = Vector2(size.x, 16)
			_name.position = Vector2(0, size.y - 18.0)

	func _color() -> Color:
		if state == "locked":
			return Pal.PANEL2
		if state == "done":
			return Pal.GOOD
		if kind == "boss":
			return Pal.DANGER
		if kind == "elite":
			return Pal.BOUNTY
		return Pal.ACCENT

	func _draw() -> void:
		var m = RoadMap.BOSS_MEDAL if boss else RoadMap.MEDAL
		var cx = floor(size.x / 2.0)
		var top = 4.0
		var col = _color()
		var u = 4.0
		var cells = int(m / u)
		# The beat of the place that is next: a ring that swells.
		if state == "open" and beat > 0.0:
			var grow = floor(beat * 6.0)
			_octagon(cx, top - grow, m + grow * 2.0, u, Pal.with_alpha(col, 0.28 + 0.2 * beat))
		_octagon(cx, top, m, u, Pal.OUTLINE)
		_octagon(cx, top + u, m - 2.0 * u, u, col.darkened(0.35))
		_octagon(cx, top + u, m - 2.0 * u, u, col, true)
		# A glint along its upper left edge.
		draw_rect(Rect2(cx - m / 2.0 + 3.0 * u, top + 2.0 * u, float(cells - 7) * u, u), col.lightened(0.45) if state != "locked" else col.lightened(0.12))
		var icon = "lock" if state == "locked" else str(RoadMap.ICONS.get(kind, ""))
		if icon != "" and Icons.has_icon(icon):
			var tex = Icons.tex(icon, null, 2)
			draw_texture(tex, Vector2(cx - 16.0, top + m / 2.0 - 16.0), Color(1, 1, 1, 0.6 if state == "locked" else 1.0))
		else:
			var t = PixelFont.tex(str(int(stage.get("s", 0))), Pal.INK, false)
			var k = 3.0
			var tw = float(t.get_width()) * k
			var th = float(t.get_height()) * k
			draw_texture_rect(t, Rect2(floor(cx - tw / 2.0), floor(top + m / 2.0 - th / 2.0), tw, th), false)
		# Its stars (a cache has none).
		if kind != "cache" and state != "locked":
			var on = Icons.tex("star_on", null, 1)
			var off = Icons.tex("star_off", null, 1)
			for i in range(3):
				draw_texture(on if i < stars else off, Vector2(cx - 26.0 + float(i) * 18.0, top + m + 2.0), Color(1, 1, 1, 1.0 if i < stars else 0.55))
		elif kind == "cache" and state == "done":
			var ck = Icons.tex("check", null, 1) if Icons.has_icon("check") else null
			if ck != null:
				draw_texture(ck, Vector2(cx - 8.0, top + m + 2.0))

	## A square with its corners cut, `m` across, its top at `y`; `inner` leaves the lower rim darker.
	func _octagon(cx: float, y: float, m: float, u: float, c: Color, inner: bool = false) -> void:
		var x0 = cx - m / 2.0
		var cut = 2.0 * u
		var h = m - (u if inner else 0.0)
		draw_rect(Rect2(x0 + cut, y, m - 2.0 * cut, h), c)
		draw_rect(Rect2(x0 + u, y + u, m - 2.0 * u, h - 2.0 * u), c)
		draw_rect(Rect2(x0, y + cut, m, h - 2.0 * cut), c)
