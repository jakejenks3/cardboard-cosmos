class_name FoeView
extends Control
## A foe of the Realm on screen (RPG_PLAN.md 12): a FoeSprites sprite at a
## WHOLE-number scale, alive.
##
##   var foe = FoeView.new()
##   foe.setup("dust_bunny", 64.0)      # fitted into a 64 x 64 square, animated
##   foe.hit()                          # flash and shake when it takes a hit
##   foe.faint()                        # sinks and fades, then stays hidden
##
## The sprite stands on the BOTTOM of the control (feet_y() is its ground
## line), centred across it, so foes of different heights in a row stand on
## one line and a battle can put that line on a backdrop's ground
## (RealmScenes.ground_y). Under it are FOOT art rows for its shadow and the
## target marker; a foe that hovers also has PAD rows of headroom to float in.
##
## Animated, a foe plays its two frames (frame_at()): one that hovers gives
## each frame half the time (wings up, wings down) and also floats up and down
## over a shadow that shrinks as it rises; one on the ground stands in its
## first frame and only dips into the second for a beat, so a breath is a
## breath and eyes that close are a blink, not a flicker. All foes run off one
## clock, each with its own offset, so a pack does not move as one. The
## looping idle stops while a page is being scrolled by a finger and while the
## view is not visible; hit() and faint() are short and always play out.
##
## By default the scale is the largest whole number that fits `px`; a battle
## that wants every foe in the same size of pixel calls set_art_scale(k), and
## the view then asks for the room that takes (FoeView.needed).
##
## No autoload, no Kit and no TouchScroll by name in here: it can be built in
## a headless test (page_scrolling() says how the scrolling is read).

## Art rows of headroom above a hovering foe (it floats into them).
const PAD = 3
## Art rows under the feet: the shadow, then the target marker.
const FOOT = 3
## One round of the two frames, and how long a foe on the ground is in the second.
const CYCLE_MS = 920.0
const BEAT_MS = 280.0
## A frame of a foe that hovers (half a round).
const FRAME_MS = 460.0
const HIT_MS = 450.0
const FAINT_MS = 620.0
## How far a fainting foe sinks, in art pixels.
const FAINT_SINK = 5.0
## A hovering foe's float: this many steps a second, over these heights (art pixels).
const FLOAT_STEP_MS = 150.0
const FLOAT_PATH = [0, 1, 2, 2, 2, 1, 0, 0]
## Art pixels a hovering foe keeps between itself and the ground.
const HOVER_GAP = 1
## The weekly rival is a bounty monster of the main game, which has one frame
## only: on the ground it hops this many art pixels on the beat instead.
const HOP = 1
## The script whose static `scrolling` is true while a finger scrolls a page.
const SCROLL_SCRIPT = "res://ui/touch_scroll.gd"

## That script, once the game has loaded it (see page_scrolling()).
static var _scroll = null

## The colour of the target marker (a battle sets it from Pal).
var marker_color: Color = Color(1.0, 0.96, 0.92)

var _foe_id: String = ""
var _px: float = 64.0
var _animate: bool = true
var _silhouette: bool = false
var _dim: bool = false
var _marked: bool = false
var _hover: bool = false
var _fixed_scale: int = 0
var _offset_ms: int = 0
var _frame: int = 0
var _lift: int = 0
var _beat: int = 0
var _hit_ms: float = -1.0 # time into the hit animation, < 0 = not playing
var _faint_ms: float = -1.0 # time into the faint, < 0 = not playing
var _gone: bool = false # fainted: nothing is drawn until revive()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_px, _px)


func _ready() -> void:
	# A node with _process() starts processing when it becomes ready: only
	# keep it on while something is moving.
	_sync_processing()


func _notification(what: int) -> void:
	# Shown, hidden (itself or a parent), or put back into the tree.
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_sync_processing()


## Something moves only while the view can be seen.
func _sync_processing() -> void:
	var moving = (_animate and not _gone) or _hit_ms >= 0.0 or _faint_ms >= 0.0
	set_process(moving and _foe_id != "" and is_visible_in_tree())


## `px` is the on-screen square the foe is fitted into (the control's minimum
## size). `animate` turns the idle motion on. A foe that had fainted is back.
func setup(foe_id: String, px: float = 64.0, animate: bool = true) -> void:
	_foe_id = foe_id
	_px = px
	_animate = animate
	_hover = FoeSprites.hovers(foe_id)
	# Foes in one pack do not all move on the same beat, two of a kind neither.
	_offset_ms = int(Rng.hash_string("foe:%s:%d" % [foe_id, get_instance_id()]) % int(CYCLE_MS))
	_gone = false
	_hit_ms = -1.0
	_faint_ms = -1.0
	_read_clock()
	_resize()
	_sync_processing()
	queue_redraw()


## The foe shown ("" before setup).
func foe_id() -> String:
	return _foe_id


## Draw at exactly `k` screen pixels per art pixel (0 = fit `px` again). The
## view then asks for the room that needs: FoeView.needed(foe_id, k).
func set_art_scale(k: int) -> void:
	_fixed_scale = maxi(0, k)
	_resize()
	queue_redraw()


## The art rows a foe takes from the top of its float (or hop) to the foot of its marker.
static func rows_needed(id: String) -> int:
	var above = PAD if FoeSprites.hovers(id) else (HOP if FoeSprites.is_rival(id) else 0)
	return FoeSprites.size(id).y + above + FOOT


## The room a foe needs at `k` screen pixels per art pixel.
static func needed(id: String, k: int) -> Vector2:
	return Vector2(float(FoeSprites.size(id).x * k), float(rows_needed(id) * k))


func _resize() -> void:
	if _fixed_scale > 0 and _foe_id != "":
		custom_minimum_size = FoeView.needed(_foe_id, _fixed_scale)
	else:
		custom_minimum_size = Vector2(_px, _px)


## The whole-number scale the foe is drawn at.
func art_scale() -> int:
	if _fixed_scale > 0:
		return _fixed_scale
	if _foe_id == "":
		return 1
	var across = float(FoeSprites.size(_foe_id).x)
	return maxi(1, int(floor(_px / maxf(1.0, maxf(across, float(FoeView.rows_needed(_foe_id)))))))


## The y of the ground line the foe stands on (or floats over), in this control.
func feet_y() -> float:
	return floor(size.y) - float(FOOT * art_scale())


## The short white flash and shake of a foe taking a hit.
func hit() -> void:
	if _gone:
		return
	_hit_ms = 0.0
	_sync_processing()
	queue_redraw()


## The foe goes down: it sinks and fades, then nothing is drawn (the view
## keeps its room, so nothing beside it moves) until revive() or setup().
func faint() -> void:
	if _gone or _faint_ms >= 0.0:
		return
	_faint_ms = 0.0
	_sync_processing()
	queue_redraw()


## True once the foe has gone down (or is going).
func fainted() -> bool:
	return _gone or _faint_ms >= 0.0


## Back on its feet, at once.
func revive() -> void:
	_gone = false
	_faint_ms = -1.0
	_sync_processing()
	queue_redraw()


## Grey the foe out.
func set_dim(dim: bool) -> void:
	if _dim != dim:
		_dim = dim
		queue_redraw()


## Draw a foe that has not been met yet as a dark shape.
func set_silhouette(on: bool) -> void:
	if _silhouette != on:
		_silhouette = on
		queue_redraw()


## A small marker under the foe: it is the picked target.
func set_marked(on: bool) -> void:
	if _marked != on:
		_marked = on
		queue_redraw()


## True while a finger is scrolling a page (TouchScroll.scrolling): looping
## decoration stands still then. It is read through the script the game has
## already loaded, never by its name: naming TouchScroll here would pull Sheet,
## Kit and with them the Sfx autoload into every script that names FoeView, and
## a headless test could not compile it. Where the game is not running (a
## test) nothing has loaded that script and this is simply false.
static func page_scrolling() -> bool:
	if _scroll == null:
		if not ResourceLoader.has_cached(SCROLL_SCRIPT):
			return false
		_scroll = load(SCROLL_SCRIPT)
	return _scroll != null and _scroll.get("scrolling") == true


## The frame (0 or 1) at `now_ms` on the clock: a foe that hovers changes
## every FRAME_MS; one on the ground is in frame 1 for the last BEAT_MS of
## every CYCLE_MS.
static func frame_at(now_ms: int, hover: bool) -> int:
	var into = fmod(float(maxi(0, now_ms)), CYCLE_MS)
	if hover:
		return 1 if into >= FRAME_MS else 0
	return 1 if into >= CYCLE_MS - BEAT_MS else 0


## Which frame and how high, from the shared clock.
func _read_clock() -> bool:
	var frame = 0
	var lift = 0
	var beat = 0
	if _animate:
		var now = Time.get_ticks_msec() + _offset_ms
		frame = FoeView.frame_at(now, _hover)
		beat = int(floor(float(now) / (FRAME_MS / 2.0))) % 2
		if _hover:
			lift = int(FLOAT_PATH[int(floor(float(now) / FLOAT_STEP_MS)) % FLOAT_PATH.size()])
		elif FoeSprites.is_rival(_foe_id):
			lift = HOP * frame
	var changed = frame != _frame or lift != _lift or (beat != _beat and _marked)
	_frame = frame
	_lift = lift
	_beat = beat
	return changed


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var redraw = false
	if _animate and not _gone and not FoeView.page_scrolling():
		redraw = _read_clock()
	if _hit_ms >= 0.0:
		_hit_ms += delta * 1000.0
		if _hit_ms >= HIT_MS:
			_hit_ms = -1.0
		redraw = true
	if _faint_ms >= 0.0:
		_faint_ms += delta * 1000.0
		if _faint_ms >= FAINT_MS:
			_faint_ms = -1.0
			_hit_ms = -1.0
			_gone = true
		redraw = true
	if redraw:
		queue_redraw()
	if _hit_ms < 0.0 and _faint_ms < 0.0 and (_gone or not _animate):
		_sync_processing()


## Where the parts are drawn, in this control's own pixels, with the foe
## floating `lift` art pixels up (-1: as it is now): {k, up, ground, sprite:
## Rect2 of the whole texture (no shake), shadow: [Rect2, Rect2], marker:
## Vector2 (its tip)}. _draw() goes by it, and the art test checks with it
## that nothing leaves the control.
func layout(lift: int = -1) -> Dictionary:
	var sz = FoeSprites.size(_foe_id)
	var bw = float(sz.x)
	var bh = float(sz.y)
	var k = float(art_scale())
	var left = floor((size.x - bw * k) / 2.0)
	var ground = feet_y()
	var up = float((_lift if lift < 0 else lift) + (HOVER_GAP if _hover else 0))
	# Its shadow on the ground: narrower the higher it floats.
	var sw = maxf(4.0, bw - 4.0 - up * 2.0)
	var sx = left + floor((bw - sw) / 2.0) * k
	return {
		"k": k, "up": up, "ground": ground,
		# The sprite's own outline row sits on the ground line.
		"sprite": Rect2(left, ground - (bh - 1.0 + up) * k, bw * k, bh * k),
		"shadow": [Rect2(sx + k, ground - k, (sw - 2.0) * k, k), Rect2(sx, ground, sw * k, k)],
		"marker": Vector2(left + floor(bw / 2.0) * k, ground + k),
	}


func _draw() -> void:
	if _foe_id == "" or _gone:
		return
	var tex: ImageTexture = FoeSprites.texture(_foe_id, _frame, _silhouette, _dim)
	var at = layout()
	var k = float(at.k)
	var shake = 0.0
	var glow = 1.0
	if _hit_ms >= 0.0:
		var t = clampf(_hit_ms / HIT_MS, 0.0, 1.0)
		shake = _hit_shake(t)
		glow = _hit_brightness(t)
	var fade = 1.0
	var sink = 0.0
	var drop = 0.0
	if _faint_ms >= 0.0:
		var f = clampf(_faint_ms / FAINT_MS, 0.0, 1.0)
		fade = 1.0 - f
		sink = floor(f * FAINT_SINK)
		# One that floats comes down to the ground as it goes.
		drop = floor(float(at.up) * f + 0.5)
	if not _silhouette:
		var shade = Color(0, 0, 0, 0.26 * fade)
		for r in at.shadow:
			draw_rect(r, shade)
	if _marked:
		_draw_marker(at.marker.x, at.marker.y, k, _animate and _beat == 1)
	# Going down it sinks INTO the ground: the rows that have gone under are
	# not drawn, so nothing is ever painted below the ground line.
	var box: Rect2 = at.sprite
	var rows = maxf(0.0, box.size.y / k - sink)
	var dest = Rect2(box.position.x + shake, box.position.y + (drop + sink) * k, box.size.x, rows * k)
	draw_texture_rect_region(tex, dest, Rect2(0.0, 0.0, box.size.x / k, rows), Color(glow, glow, glow, fade))


## A little arrow head pointing up at the foe, `k` screen pixels per pixel,
## its tip at (x, y); it blinks a shade darker on every other beat.
func _draw_marker(x: float, y: float, k: float, low: bool) -> void:
	var edge = Color(0.04, 0.03, 0.1, 0.9)
	var c = marker_color.darkened(0.25) if low else marker_color
	draw_rect(Rect2(x - k, y, 3.0 * k, k), edge)
	draw_rect(Rect2(x - 2.0 * k, y + k, 5.0 * k, k), edge)
	draw_rect(Rect2(x, y, k, k), c)
	draw_rect(Rect2(x - k, y + k, 3.0 * k, k), c)


## The shake of a hit, in screen pixels: 0 -> -4 -> 4 -> -2 -> 0 (as BossView).
static func _hit_shake(t: float) -> float:
	var keys = [0.0, -4.0, 4.0, -2.0, 0.0]
	var f = clampf(t, 0.0, 1.0) * 4.0
	var i = mini(3, int(floor(f)))
	return lerpf(float(keys[i]), float(keys[i + 1]), f - float(i))


## ... and its brightness: 4 -> 2 at the halfway point -> 1.
static func _hit_brightness(t: float) -> float:
	if t < 0.5:
		return lerpf(4.0, 2.0, t / 0.5)
	return lerpf(2.0, 1.0, (t - 0.5) / 0.5)
