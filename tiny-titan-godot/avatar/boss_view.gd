class_name BossView
extends Control
## A boss portrait (port of BossPortrait.tsx).
##
##   var boss = BossView.new()
##   boss.setup("iron_golem", 58.0, true)   # animated idle bob
##   boss.hit()                             # flash + shake when it takes damage
##
## The boss is fitted into a `px` x `px` square (the web's `size` prop),
## centred in the control, with two art pixels of headroom for the bob:
## animated bosses hop up one art pixel every 420 ms, hovering ones every
## 260 ms (off one shared clock, so all portraits on screen bob in step, as
## on the web). hit() replays the web's 0.45 s "bosshit" animation: a white
## flash that fades while the sprite shakes sideways.

## Rows of headroom above the sprite (the bob moves into it).
const PAD = 2
const BOB_MS = 420.0
const HOVER_BOB_MS = 260.0
const HIT_MS = 450.0

var _boss_id: String = ""
var _px: float = 58.0
var _animate: bool = false
var _silhouette: bool = false
var _dim: bool = false
var _hover: bool = false
var _phase: int = 0
var _hit_ms: float = -1.0 # time into the hit animation, < 0 = not playing


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_px, _px)


func _ready() -> void:
	# A node with _process() starts processing when it becomes ready: only
	# keep it on while something is moving.
	_sync_processing()


func _sync_processing() -> void:
	set_process(_animate or _hit_ms >= 0.0)


## `px` is the on-screen square the portrait is fitted into. `animate` turns
## the idle bob on, `silhouette` draws an undiscovered boss as a dark shape.
func setup(boss_id: String, px: float = 58.0, animate: bool = false, silhouette: bool = false) -> void:
	_boss_id = boss_id
	_px = px
	_animate = animate
	_silhouette = silhouette
	_hover = Art.boss_hovers(boss_id)
	_phase = _bob_phase()
	custom_minimum_size = Vector2(px, px)
	_sync_processing()
	queue_redraw()


## The short white flash / shake of a boss taking a hit.
func hit() -> void:
	_hit_ms = 0.0
	_sync_processing()
	queue_redraw()


## Grey a defeated boss out (the web's `boss-dim` class).
func set_dim(dim: bool) -> void:
	_dim = dim
	queue_redraw()


## 0 or 1: the web's `floor(t / period) % 2` on the page clock.
func _bob_phase() -> int:
	if not _animate:
		return 0
	return int(floor(Time.get_ticks_msec() / (HOVER_BOB_MS if _hover else BOB_MS))) % 2


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var phase: int = _bob_phase()
	if phase != _phase:
		_phase = phase
		queue_redraw()
	if _hit_ms >= 0.0:
		_hit_ms += delta * 1000.0
		if _hit_ms >= HIT_MS:
			_hit_ms = -1.0
			_sync_processing()
		queue_redraw()


func _draw() -> void:
	if _boss_id == "":
		return
	var tex: ImageTexture = Art.boss_texture(_boss_id, _silhouette, _dim)
	var bw: float = tex.get_width()
	var bh: float = tex.get_height()
	# The web canvas is bw x (bh + PAD) art pixels, shown with
	# `object-fit: contain` in a px x px box.
	var k: float = _px / maxf(bw, bh + PAD)
	var box: Vector2 = Vector2(bw, bh + PAD) * k
	var origin: Vector2 = (size - box) / 2.0
	var shake: float = 0.0
	var glow: float = 1.0
	if _hit_ms >= 0.0:
		var t: float = clampf(_hit_ms / HIT_MS, 0.0, 1.0)
		shake = _hit_shake(t)
		glow = _hit_brightness(t)
	var pos: Vector2 = origin + Vector2(shake, (PAD - _phase) * k)
	draw_texture_rect(tex, Rect2(pos, Vector2(bw, bh) * k), false, Color(glow, glow, glow, 1.0))


## Keyframes of the web's `bosshit` animation: translateX 0 -> -4 -> 4 -> -2 -> 0 px.
static func _hit_shake(t: float) -> float:
	var keys: Array = [0.0, -4.0, 4.0, -2.0, 0.0]
	var f: float = clampf(t, 0.0, 1.0) * 4.0
	var i: int = mini(3, int(floor(f)))
	return lerpf(keys[i], keys[i + 1], f - i)


## ... and its brightness: 4 -> 2 at the halfway point -> 1.
static func _hit_brightness(t: float) -> float:
	if t < 0.5:
		return lerpf(4.0, 2.0, t / 0.5)
	return lerpf(2.0, 1.0, (t - 0.5) / 0.5)
