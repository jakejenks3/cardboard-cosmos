class_name XpBarAnim
extends PanelContainer
## An XP bar that animates from `before` to `after` (LevelInfo dictionaries),
## filling to 100 % and wrapping around on every level gained
## (port of components/XpBarAnim.tsx, same timeline).
##
##   var bar = XpBarAnim.new()
##   bar.setup(ev.hero.before, ev.hero.after, Pal.ACCENT, "Hero", "star")
##   parent.add_child(bar)
##   var secs = bar.play()      # emits level_up(level) per level, done at the end
##   bar.finish_now()           # jump to the final state (skip)

signal level_up(level)
signal done

var _before: Dictionary = {}
var _after: Dictionary = {}
var _color: Color = Pal.ACCENT
var _level: int = 1
var _pct: float = 0.0
var _tween = null
var _bar: Bar
var _lv_label: Label
var _foot: Label
var _style: StyleBoxFlat


func setup(before: Dictionary, after: Dictionary, color: Color, label_text: String, icon: String = "") -> void:
	_before = before
	_after = after
	_color = color
	_level = int(before.level)
	_pct = float(before.progress)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style = Kit.sbox(Pal.PANEL, 12, Pal.LINE, 1, 12, 10)
	add_theme_stylebox_override("panel", _style)
	var v = Kit.vbox(6)
	add_child(v)
	var head = Kit.hbox(6)
	if icon != "":
		head.add_child(Icons.rect(icon, 18))
	head.add_child(Kit.clip(label_text, 15, null, true))
	_lv_label = Kit.label("", 15, null, true)
	head.add_child(_lv_label)
	v.add_child(head)
	_bar = Kit.bar(_pct, color, 14)
	v.add_child(_bar)
	_foot = Kit.label("", 11, Pal.MUTED)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_foot)
	_refresh_text()


## Start the animation. Returns how long it takes (seconds) until `done`.
func play() -> float:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var t = 0.15
	_tween.tween_interval(0.15)
	var gained = int(_after.level) - int(_before.level)
	var seg = maxf(0.35, 0.9 / float(gained + 1)) if gained > 0 else 0.9
	for i in range(gained):
		var lv = int(_before.level) + i
		_tween.tween_callback(_fill_to.bind(1.0, minf(0.75, seg)))
		_tween.tween_interval(seg)
		_tween.tween_callback(_flash.bind(lv + 1))
		_tween.tween_interval(0.22)
		_tween.tween_callback(_wrap.bind(lv + 1))
		_tween.tween_interval(0.04)
		t += seg + 0.26
	_tween.tween_callback(_final_fill)
	_tween.tween_interval(0.8)
	_tween.tween_callback(func(): done.emit())
	t += 0.8
	return t


## Show the end state at once (the reel was skipped). Emits nothing.
func finish_now() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_level = int(_after.level)
	_pct = float(_after.progress)
	_bar.set_value(_pct, false)
	_set_flash(false)
	_refresh_text()


func _fill_to(v: float, dur: float) -> void:
	_pct = v
	_bar.set_value(v, true, dur)
	_refresh_text()


func _flash(new_level: int) -> void:
	_set_flash(true)
	Sfx.level_up()
	Kit.pop(_lv_label, 1.35, 0.3)
	level_up.emit(new_level)


func _wrap(new_level: int) -> void:
	_set_flash(false)
	_level = new_level
	_pct = 0.0
	_bar.set_value(0.0, false)
	_refresh_text()


func _final_fill() -> void:
	_fill_to(float(_after.progress), 0.75)
	Sfx.xp()


func _set_flash(on: bool) -> void:
	if on:
		_style.border_color = Pal.ACCENT
		_style.set_border_width_all(2)
		_style.shadow_color = Pal.with_alpha(Pal.ACCENT, 0.55)
		_style.shadow_size = 14
	else:
		_style.border_color = Pal.LINE
		_style.set_border_width_all(1)
		_style.shadow_size = 0


func _refresh_text() -> void:
	var to_next = int(_after.toNext) if _level == int(_after.level) else int(_before.toNext)
	_lv_label.text = "Lv %d" % _level
	_foot.text = "%s / %s XP" % [Xp.fmt_int(TTUtil.jsround(_pct * to_next)), Xp.fmt_int(to_next)]
