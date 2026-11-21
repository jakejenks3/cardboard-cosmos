class_name ResultsOverlay
extends Control
## The results reel shown after logging (port of screens/Results.tsx).
##
## The shell creates it with `.new()`, anchors it over the app column, adds it
## to the tree and calls `setup(result)` with result = {"key", "title", "events"}
## (events from Diff.diff_states / diff_bulk / diff_body). Timeline, as on the
## web: the XP number counts up (1 s) → the discipline bar fills → the hero bar
## fills (wrapping on each level-up) → the other events pop in one by one →
## "Continue". A click anywhere, Space or Enter skips to the end; `finished`
## is emitted once when the player closes it.
##
## Every pause is a Tween bound to this node, so when the overlay is freed
## mid-sequence the paused coroutine is simply dropped (a SceneTree timer would
## try to resume it on a freed instance). Each step also checks `_gen`, which
## a skip or close bumps, so a skipped reel never runs another step.

signal finished

const HEADER_TYPES = ["xp", "import", "bodyxp", "levelup"]

var _title: String = ""
var _events: Array = []
var _cards: Array = []
var _xp_ev = null
var _import_ev = null
var _body_ev = null
var _hero_pair = null
var _leveled: bool = false
var _amount: int = 0
var _phase: String = "xp"  # xp | disc | hero | cards | done
var _shown: int = 0
var _gen: int = 0
var _closed: bool = false
var _press_pos = null

var _scroll: ScrollContainer
var _bars: VBoxContainer
var _cards_box: VBoxContainer
var _hero: HeroView
var _xp_rect: TextureRect
var _xp_color: Color = Pal.ACCENT
var _xp_scale: int = 4
var _footer_btn: Button
var _confetti: Confetti
var _shake_tw: Tween = null
var _shake_rest = Vector2.ZERO
var _disc_bar = null
var _hero_bar = null
var _count_tween = null
var _equip_buttons: Array = []  # [{"button", "item"}]
var _pet_buttons: Array = []  # [{"button", "pet"}]


func setup(result: Dictionary) -> void:
	_title = Icons.strip_emoji(str(result.get("title", "")))
	_events = result.get("events", [])
	for e in _events:
		match e.type:
			"xp":
				if _xp_ev == null:
					_xp_ev = e
			"import":
				if _import_ev == null:
					_import_ev = e
			"bodyxp":
				if _body_ev == null:
					_body_ev = e
			"levelup":
				_leveled = true
		if not HEADER_TYPES.has(e.type):
			_cards.append(e)
	if _xp_ev != null:
		_amount = int(_xp_ev.amount)
		_hero_pair = _xp_ev.hero
		_xp_color = Pal.disc(_xp_ev.discipline)
	elif _import_ev != null:
		_amount = int(_import_ev.xp)
		_hero_pair = _import_ev.hero
	elif _body_ev != null:
		_amount = int(_body_ev.amount)
		_hero_pair = _body_ev.hero
	_build()
	_run()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var base = ColorRect.new()
	base.color = Pal.BG
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	# A soft glow behind the hero, in the theme's own world colours.
	var bg = TextureRect.new()
	var grad = Gradient.new()
	grad.set_color(0, Pal.BG2.lightened(0.12))
	grad.set_color(1, Pal.BG)
	var gt = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.2)
	gt.fill_to = Vector2(0.5, 0.62)
	gt.width = 128
	gt.height = 128
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root = Kit.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	var content = Kit.vbox(0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(Kit.pad(content, 16, 24, 16, 16))
	_scroll.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	content.add_child(_build_head())
	_bars = Kit.vbox(14)
	content.add_child(Kit.pad(_bars, 0, 18, 0, 18))
	_cards_box = Kit.vbox(10)
	content.add_child(_cards_box)

	_footer_btn = Kit.button("Tap to skip", "ghost", _on_footer, "lg")
	_footer_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_btn.custom_minimum_size = Vector2(0, 58)
	root.add_child(Kit.pad(_footer_btn, 16, 12, 16, 16))

	_confetti = Confetti.new()
	_confetti.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confetti)


func _build_head() -> Control:
	var head = Kit.vbox(8)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	var scale_px = 2
	if PixelFont.measure(_title).x * 2 > 380:
		scale_px = 1
	var title = PixelFont.rect(_title.to_upper(), scale_px, Pal.ACCENT)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	Kit.pop(title, 1.15, 0.4)

	_hero = HeroView.new()
	_hero.happy = true
	_hero.forced_pose = "flex" if _leveled else "idle"
	_hero.min_scale = 3
	_hero.setup(App.state, App.profile(), App.loadout(), App.active_pet(), false)
	_hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(_hero)

	# The XP as big as it fits: the number the whole reel is about.
	var widest = PixelFont.measure("+%s XP" % Xp.fmt_int(_amount)).x
	_xp_scale = 5
	while _xp_scale > 2 and widest * _xp_scale > 390:
		_xp_scale -= 1
	_xp_rect = PixelFont.rect("+0 XP", _xp_scale, _xp_color)
	_xp_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_xp_rect.tooltip_text = _breakdown()
	_xp_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(_xp_rect)
	_set_count(0.0)
	_count_tween = create_tween()
	_count_tween.tween_method(_set_count, 0.0, float(_amount), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var summary = _summary()
	if summary != null:
		head.add_child(summary)
	return head


## Where the XP came from, line by line (the XP number's tooltip).
func _breakdown() -> String:
	if _xp_ev == null:
		return ""
	var bits = PackedStringArray()
	for p in _xp_ev.parts:
		bits.append("%s +%s" % [Icons.strip_emoji(p.label), Xp.fmt_int(p.xp)])
	if int(_xp_ev.prBonus) > 0:
		bits.append("PR bonus +%s" % Xp.fmt_int(_xp_ev.prBonus))
	if float(_xp_ev.get("bonusPct", 0)) > 0.0:
		bits.append("includes +%d%% gear bonus" % TTUtil.jsround(float(_xp_ev.bonusPct) * 100.0))
	return "\n".join(bits)


## Under the XP: a few chips instead of a sentence (the full breakdown is the tooltip).
func _summary():
	var f = Kit.flow(6)
	f.alignment = FlowContainer.ALIGNMENT_CENTER
	if _import_ev != null:
		f.add_child(Kit.pill("calendar", "%d sessions" % int(_import_ev.count), Pal.PANEL2, "", Pal.TEXT))
		for d in TT.SESSION_KINDS:
			var v = int(_import_ev.byDiscipline.get(d, 0))
			if v > 0:
				f.add_child(Kit.pill(d, "+" + Xp.fmt_int(v), Pal.disc(d), "", Color.WHITE))
		return f
	if _body_ev != null:
		if int(_body_ev.amount) > 0:
			f.add_child(Kit.pill("scale", "Weekly check-in", Pal.GOOD))
		else:
			f.add_child(Kit.pill("check", "Logged", Pal.PANEL2, "", Pal.TEXT))
		return f
	if _xp_ev != null:
		if int(_xp_ev.prBonus) > 0:
			f.add_child(Kit.pill("trophy", "PR +%s" % Xp.fmt_int(_xp_ev.prBonus), Pal.ACCENT))
		if float(_xp_ev.get("bonusPct", 0)) > 0.0:
			f.add_child(Kit.pill("chest", "+%d%% gear" % TTUtil.jsround(float(_xp_ev.bonusPct) * 100.0), Pal.GOOD))
	if f.get_child_count() == 0:
		f.queue_free()
		return null
	return f


func _set_count(v: float) -> void:
	if not is_instance_valid(_xp_rect):
		return
	var t = PixelFont.tex("+%s XP" % Xp.fmt_int(TTUtil.jsround(v)), _xp_color)
	_xp_rect.texture = t
	_xp_rect.custom_minimum_size = Vector2(t.get_width() * _xp_scale, t.get_height() * _xp_scale)


# ---------------------------------------------------------------------------
# Timeline
# ---------------------------------------------------------------------------

## Pause for `secs`. Bound to this node: if the overlay is freed, it never returns.
func _wait(secs: float) -> void:
	var tw = create_tween()
	tw.tween_interval(secs)
	await tw.finished


func _alive(gen: int) -> bool:
	return is_instance_valid(self) and is_inside_tree() and gen == _gen and not _closed


func _run() -> void:
	var gen = _gen
	await _wait(1.0)
	if not _alive(gen):
		return
	if _xp_ev != null and _xp_ev.get("disc") != null:
		_phase = "disc"
		var secs = _ensure_disc_bar().play()
		await _wait(secs)
		if not _alive(gen):
			return
	if _hero_pair != null:
		_phase = "hero"
		var secs2 = _ensure_hero_bar().play()
		await _wait(secs2)
		if not _alive(gen):
			return
	_phase = "cards"
	for i in range(_cards.size()):
		var delay = 0.3
		if i > 0:
			delay = 1.1 if ["boss", "bounty"].has(_cards[i - 1].type) else 0.65
		# A long reel (a big import) speeds up a little after the first ten.
		if i >= 10:
			delay *= 0.6
		await _wait(delay)
		if not _alive(gen):
			return
		_reveal(i, true)
	_set_done()


func _ensure_disc_bar() -> XpBarAnim:
	if _disc_bar == null:
		var d = _xp_ev.discipline
		_disc_bar = XpBarAnim.new()
		_disc_bar.setup(_xp_ev.disc.before, _xp_ev.disc.after, Pal.disc(d), TT.DISCIPLINE_META[d].name, d)
		_disc_bar.level_up.connect(_on_bar_level_up)
		_bars.add_child(_disc_bar)
		_pop_in(_disc_bar, 0.35)
	return _disc_bar


func _ensure_hero_bar() -> XpBarAnim:
	if _hero_bar == null:
		_hero_bar = XpBarAnim.new()
		_hero_bar.setup(_hero_pair.before, _hero_pair.after, Pal.ACCENT, "Hero", "star")
		_hero_bar.level_up.connect(_on_bar_level_up)
		_bars.add_child(_hero_bar)
		_pop_in(_hero_bar, 0.35)
	return _hero_bar


func _on_bar_level_up(_level) -> void:
	_confetti.burst(1.2)


func _reveal(i: int, animate: bool) -> void:
	var ev = _cards[i]
	_shown = i + 1
	if animate:
		match ev.type:
			"item":
				var it = Items.by_id(ev.id)
				Sfx.drop(it.rarity if it != null else "common")
			"achievement":
				Sfx.achievement()
			"pet":
				Sfx.pet()
			"pr":
				# A record is the big moment: a fanfare, confetti and a shake.
				Sfx.pr()
				Sfx.level_up()
				_confetti.burst(1.0)
				_shake()
			"boss":
				if ev.defeated:
					Sfx.boss_down()
					_confetti.burst(1.2)
				else:
					Sfx.hit()
			"bounty":
				if ev.defeated or ev.crushed:
					Sfx.boss_down()
					_confetti.burst(1.0)
				else:
					Sfx.hit()
			"coins":
				Sfx.claim()
			"rank":
				Sfx.rank()
				_confetti.burst(1.2)
			"stage":
				Sfx.stage()
				_confetti.burst(1.2)
			_:
				Sfx.tap()
	var card = _build_card(ev, animate)
	if card == null:
		return
	_cards_box.add_child(card)
	if animate:
		_pop_in(card, 0.45)
		_scroll_to_end()
		var col = _burst_color(ev)
		if col != null:
			var tw = card.create_tween()
			tw.tween_interval(0.3)
			tw.tween_callback(func(): Kit.burst(card, col, 20))
		if ev.type == "pr":
			_fireworks(card)


## A record's fireworks: bursts of gold, green and blue over its card, then a
## gold sweep and twinkles that stay on it.
func _fireworks(card: Control) -> void:
	var tw = card.create_tween()
	for k in range(3):
		var col = [Pal.ACCENT, Pal.GOOD, Pal.SECOND][k]
		tw.tween_interval(0.25)
		tw.tween_callback(func(): Kit.burst(card, col, 26))
	Fx.shine(card, 2.2, 0.6, 0.55)
	Fx.twinkle(card, Pal.ACCENT, 4)


## A short shake of the whole reel (a record). A shake still running is
## stopped first, so records in a row never leave the reel off its place.
func _shake() -> void:
	if _shake_tw != null and _shake_tw.is_valid():
		_shake_tw.kill()
		position = _shake_rest
	_shake_rest = position
	_shake_tw = create_tween()
	for off in [Vector2(-6, 2), Vector2(5, -3), Vector2(-4, 3), Vector2(3, -2), Vector2(-2, 1)]:
		_shake_tw.tween_property(self, "position", _shake_rest + off, 0.035)
	_shake_tw.tween_property(self, "position", _shake_rest, 0.05)


func _skip() -> void:
	if _phase == "done" or _closed:
		return
	_gen += 1
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_set_count(float(_amount))
	if _xp_ev != null and _xp_ev.get("disc") != null:
		_ensure_disc_bar().finish_now()
	if _hero_pair != null:
		_ensure_hero_bar().finish_now()
	for i in range(_shown, _cards.size()):
		_reveal(i, false)
	_set_done()


func _set_done() -> void:
	_phase = "done"
	_footer_btn.text = "Continue"
	Kit.style_button(_footer_btn, "primary", "lg")
	_footer_btn.add_theme_font_size_override("font_size", 20)
	Kit.pop(_footer_btn, 1.06, 0.3)
	_hero.forced_pose = "flex"


func _close() -> void:
	if _closed:
		return
	_closed = true
	_gen += 1
	finished.emit()


func _on_footer() -> void:
	if _phase == "done":
		_close()
	else:
		_skip()


func _scroll_to_end() -> void:
	# Let the containers lay the new card out first.
	await _wait(0.05)
	if not is_instance_valid(self) or not is_inside_tree() or _closed:
		return
	var target = int(_scroll.get_v_scroll_bar().max_value - _scroll.size.y)
	if target <= _scroll.scroll_vertical:
		return
	var tw = create_tween()
	tw.tween_property(_scroll, "scroll_vertical", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The web's `pop` keyframes: scale 0.6 → 1 with an overshoot, fading in.
func _pop_in(c: Control, dur: float) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.6, 0.6)
	c.resized.connect(func(): c.pivot_offset = c.size / 2.0)
	var tw = c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.6)


# ---------------------------------------------------------------------------
# Input: a click anywhere (not on a button), Space or Enter skips; once the reel
# is done, Space / Enter also close it (the Continue button).
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _closed or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_on_footer()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not get_global_rect().has_point(event.position):
			return
		if event.pressed:
			_press_pos = event.position
		elif _press_pos != null:
			var moved = event.position.distance_to(_press_pos)
			_press_pos = null
			if moved < 12.0 and _phase != "done" and not _over_button(self, event.position):
				_skip()


func _over_button(node: Node, pos: Vector2) -> bool:
	for c in node.get_children():
		if c is CanvasItem and not c.visible:
			continue
		if c is BaseButton and c.get_global_rect().has_point(pos):
			return true
		if _over_button(c, pos):
			return true
	return false


# ---------------------------------------------------------------------------
# Event cards
# ---------------------------------------------------------------------------

## The colour of the sparks when a card is revealed, or null for no burst.
## Trophies, loot, companions, ranks and evolutions are rewards and get one;
## a boss gets its burst when it goes down.
func _burst_color(ev: Dictionary):
	match ev.type:
		"achievement":
			var a = Achievements.by_id(ev.id)
			if a != null:
				return Pal.hex(Achievements.TIER_COLOR[Achievements.tier_of(a)])
		"item":
			var it = Items.by_id(ev.id)
			if it != null:
				return Pal.rarity(it.rarity)
		"pet":
			var pet = Pets.by_id(ev.id)
			if pet != null:
				return Pal.rarity(pet.rarity)
		"rank":
			return Pal.hex(Xp.RANKS[int(ev.to)].color)
		"stage", "pr", "coins":
			return Pal.ACCENT
	return null


## A reel card: a pixel panel colour-coded by what it shows.
## {panel (Card), row (HBox), main (VBox)}.
func _rcard(color: Color, fill: bool = false) -> Dictionary:
	var card = Kit.card(4, Callable(), 12)
	card.accent(color, fill)
	var row = Kit.hbox(12)
	card.add(row)
	var main = Kit.vbox(3)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return {"panel": card, "row": row, "main": main}


## The picture of a card on a raised plate in its colour.
func _plate(content: Control, color: Color, px: int = 52) -> Control:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.deep(color), {"ring": color, "lip": 1, "lip_color": Pal.OUTLINE, "pad_h": 2, "pad_v": 2}))
	p.add_child(Kit.center(content))
	return p


func _icon_cell(icon: String, color: Color) -> Control:
	return _plate(Icons.rect(icon, 32), color)


## The small coloured tag above a card's title ("GOLD TROPHY", "LOOT DROP").
func _kicker(text: String, color: Color) -> Control:
	return Kit.tag(text, color, true, 10)


func _title_l(text: String) -> Label:
	return Kit.para(text, 16, null, true)


func _sub(text: String) -> Label:
	return Kit.clip(text, 13, Pal.MUTED)


func _perk_l(text: String) -> Label:
	return Kit.para(text, 13, Pal.GOOD, true)


func _finish(c: Dictionary, left: Control) -> Control:
	if left != null:
		c.row.add_child(left)
	c.row.add_child(c.main)
	return c.panel


func _build_card(ev: Dictionary, animate: bool):
	match ev.type:
		"boss":
			return _boss_card(ev, animate)
		"bounty":
			return _bounty_card(ev, animate)
		"coins":
			var c = _rcard(Pal.ACCENT)
			c.main.add_child(_kicker("COINS", Pal.ACCENT))
			var h = Kit.hbox(8)
			h.add_child(PixelFont.rect("+" + Xp.fmt_int(ev.amount), 3, Pal.ACCENT))
			h.add_child(Kit.vcenter(Kit.label("for the shop", 14, null, true)))
			c.main.add_child(h)
			c.main.add_child(_sub("%s in your purse" % Xp.fmt_int(ev.balance)))
			c.panel.tooltip_text = "1 coin per 10 XP, plus bounties, bosses, trophies and missions. Spend them in Armory, Shop."
			return _finish(c, _icon_cell("coin", Pal.ACCENT))
		"rank":
			var rank = Xp.RANKS[int(ev.to)]
			var rc = Pal.hex(rank.color)
			var m = TT.DISCIPLINE_META[ev.discipline]
			var c = _rcard(rc)
			var kick = Kit.hbox(6)
			kick.add_child(_kicker("RANK UP", rc))
			kick.add_child(Icons.rect(ev.discipline, 16))
			c.main.add_child(kick)
			c.main.add_child(Kit.rich("[color=%s]%s →[/color] [color=%s]%s[/color]" % [Kit.hex_of(Pal.MUTED), Kit.esc(Xp.RANKS[int(ev.from)].name), Kit.hex_of(rc), Kit.esc(rank.name)], 17, null))
			c.panel.tooltip_text = "%s level %d reached." % [m.statName, int(rank.minLevel)]
			return _finish(c, _icon_cell("medal", rc))
		"stage":
			return _stage_card(ev)
		"pr":
			var c = _rcard(Pal.ACCENT)
			c.main.add_child(_kicker("NEW RECORD", Pal.ACCENT))
			c.main.add_child(_title_l(Icons.strip_emoji(ev.title)))
			c.main.add_child(_sub(Icons.strip_emoji(ev.detail)))
			return _finish(c, _icon_cell(Icons.for_emoji(ev.icon), Pal.ACCENT))
		"achievement":
			var a = Achievements.by_id(ev.id)
			if a == null:
				return null
			var tier = Achievements.tier_of(a)
			var tc = Pal.hex(Achievements.TIER_COLOR[tier])
			var c = _rcard(tc)
			var kick = Kit.hbox(6)
			kick.add_child(_kicker("%s TROPHY" % tier.to_upper(), tc))
			kick.add_child(Parts.xp_chip(a.xp, 10))
			c.main.add_child(kick)
			c.main.add_child(_title_l(Icons.strip_emoji(a.name)))
			c.main.add_child(_sub(Icons.strip_emoji(a.desc)))
			c.panel.tooltip_text = Icons.strip_emoji(a.desc)
			return _finish(c, _icon_cell(Icons.for_emoji(a.icon), tc))
		"item":
			return _item_card(ev)
		"pet":
			return _pet_card(ev)
		"streak":
			var c = _rcard(Pal.ACCENT2)
			c.main.add_child(_kicker("STREAK", Pal.ACCENT2))
			var h = Kit.hbox(8)
			h.add_child(PixelFont.rect(str(int(ev.current)), 3, Pal.ACCENT2))
			h.add_child(Kit.vcenter(Kit.label("weeks in a row", 15, null, true)))
			c.main.add_child(h)
			c.panel.tooltip_text = "Consistency is the real superpower."
			return _finish(c, _icon_cell("flame", Pal.ACCENT2))
	return null


func _boss_card(ev: Dictionary, animate: bool) -> Control:
	var boss = Campaign.boss_at(int(ev.index))
	var c = _rcard(Pal.HP, true)
	var bv = BossView.new()
	bv.setup(boss.id, 72.0, false)
	bv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kick_row = Kit.hbox(6)
	kick_row.add_child(_kicker("BOSS FIGHT", Pal.HP))
	if ev.weak:
		kick_row.add_child(Kit.tag("×%s" % TTUtil.num_str(Campaign.WEAK_MULT), Pal.ACCENT, true, 10))
	c.main.add_child(kick_row)
	c.main.add_child(_title_l(boss.name))
	var max_hp = maxf(1.0, float(ev.maxHp))
	var hp = Kit.bar(float(ev.hpBefore) / max_hp, Pal.HP, 12)
	c.main.add_child(Kit.pad(hp, 0, 2, 0, 2))
	var foot = Kit.rich("", 13, Pal.with_alpha(Pal.TEXT, 0.75))
	c.main.add_child(foot)
	if ev.weak:
		c.panel.tooltip_text = "Super effective: its weakness hits for ×%s." % TTUtil.num_str(Campaign.WEAK_MULT)
	var parts = {"boss": boss, "ev": ev, "bv": bv, "kick_row": kick_row, "hp": hp, "foot": foot, "panel": c.panel}
	var card = _finish(c, bv)
	if animate:
		_boss_foot(parts, float(ev.hpBefore), false)
		var tw = card.create_tween()
		tw.tween_interval(0.2)
		tw.tween_callback(func():
			hp.set_value(float(ev.hpAfter) / max_hp, true, 0.7)
			bv.hit()
			_boss_foot(parts, float(ev.hpAfter), false))
		if ev.defeated:
			tw.tween_interval(0.7)
			tw.tween_callback(func(): _boss_down(parts, true))
	else:
		hp.set_value(float(ev.hpAfter) / max_hp, false)
		if ev.defeated:
			_boss_down(parts, false)
		else:
			_boss_foot(parts, float(ev.hpAfter), false)
	return card


## The weekly bounty taking a hit (and going down), like the boss card but violet.
func _bounty_card(ev: Dictionary, animate: bool) -> Control:
	var mon = Bounty.monster(ev.monster)
	var won = ev.defeated or ev.crushed
	var c = _rcard(Pal.BOUNTY, true)
	var bv = BossView.new()
	bv.setup(ev.monster, 72.0, false)
	bv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kick_row = Kit.hbox(6)
	kick_row.add_child(Kit.tag("WEEKLY BOUNTY", Pal.BOUNTY, false, 10))
	if ev.weak:
		kick_row.add_child(Kit.tag("×%s" % TTUtil.num_str(Bounty.WEAK_MULT), Pal.ACCENT, true, 10))
	c.main.add_child(kick_row)
	c.main.add_child(_title_l(mon.name))
	var max_hp = maxf(1.0, float(ev.maxHp))
	var hp = Kit.bar(float(ev.hpBefore) / max_hp, Pal.BOUNTY, 12)
	c.main.add_child(Kit.pad(hp, 0, 2, 0, 2))
	var foot = Kit.rich("", 13, Pal.with_alpha(Pal.TEXT, 0.75))
	c.main.add_child(foot)
	if ev.weak:
		c.panel.tooltip_text = "Super effective: its weakness hits for ×%s." % TTUtil.num_str(Bounty.WEAK_MULT)
	var hit_text = "[b]−%s[/b] · %s / %s HP" % [Xp.fmt_int(ev.damage), Xp.fmt_int(ev.hpAfter), Xp.fmt_int(ev.maxHp)]
	var parts = {"ev": ev, "bv": bv, "kick_row": kick_row, "foot": foot, "panel": c.panel}
	var card = _finish(c, bv)
	if animate:
		foot.text = "[b]−%s[/b] · %s / %s HP" % [Xp.fmt_int(ev.damage), Xp.fmt_int(ev.hpBefore), Xp.fmt_int(ev.maxHp)]
		var tw = card.create_tween()
		tw.tween_interval(0.2)
		tw.tween_callback(func():
			hp.set_value(float(ev.hpAfter) / max_hp, true, 0.7)
			bv.hit()
			foot.text = hit_text)
		if won:
			tw.tween_interval(0.7)
			tw.tween_callback(func(): _bounty_down(parts, true))
	else:
		hp.set_value(float(ev.hpAfter) / max_hp, false)
		if won:
			_bounty_down(parts, false)
		else:
			foot.text = hit_text
	return card


func _bounty_down(parts: Dictionary, animate: bool) -> void:
	if not is_instance_valid(parts.panel):
		return
	var ev = parts.ev
	Kit.clear(parts.kick_row)
	parts.kick_row.add_child(_kicker("BOUNTY CRUSHED" if ev.crushed else "BOUNTY CLAIMED", Pal.ACCENT))
	parts.kick_row.add_child(Icons.rect("coin", 16))
	parts.bv.set_dim(true)
	parts.panel.accent(Pal.ACCENT, true)
	var text = "[b][color=%s]+%s coins[/color][/b]" % [Kit.hex_of(Pal.ACCENT), Xp.fmt_int(ev.coins)]
	if int(ev.streak) >= 2:
		text += " · %d in a row" % int(ev.streak)
	parts.foot.text = text
	if animate:
		Kit.pop(parts.panel, 1.04, 0.3)
		Kit.burst(parts.panel, Pal.ACCENT, 28)


func _boss_foot(parts: Dictionary, hp: float, down: bool) -> void:
	var ev = parts.ev
	var boss = parts.boss
	var text = "[b]−%s[/b] · " % Xp.fmt_int(ev.damage)
	if down:
		var reward = ""
		if boss.get("rewardItem") != null:
			var it = Items.by_id(boss.rewardItem)
			if it != null:
				reward = " + %s" % Kit.esc(it.name)
		text = "[b][color=%s]+%s XP%s[/color][/b]" % [Kit.hex_of(Pal.ACCENT), Xp.fmt_int(boss.xp), reward]
	else:
		text += "%s / %s HP" % [Xp.fmt_int(hp), Xp.fmt_int(ev.maxHp)]
	parts.foot.text = text


func _boss_down(parts: Dictionary, animate: bool) -> void:
	if not is_instance_valid(parts.panel):
		return
	Kit.clear(parts.kick_row)
	parts.kick_row.add_child(_kicker("BOSS DEFEATED", Pal.ACCENT))
	parts.kick_row.add_child(Icons.rect("skull", 16))
	parts.bv.set_dim(true)
	parts.panel.accent(Pal.ACCENT, true)
	_boss_foot(parts, 0.0, true)
	if animate:
		Kit.pop(parts.panel, 1.04, 0.3)
		Kit.burst(parts.panel, Pal.ACCENT, 28)


func _stage_card(ev: Dictionary) -> Control:
	var to = Xp.STAGES[int(ev.to)]
	var card = Kit.card(8, Callable(), 18)
	card.accent(Pal.ACCENT, true)
	card.tooltip_text = to.blurb
	var k = _kicker("BODY EVOLVED", Pal.ACCENT)
	k.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add(k)
	var names = Kit.hbox(8)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_child(PixelFont.rect(str(Xp.STAGES[int(ev.from)].name).to_upper(), 2, Pal.MUTED))
	names.add_child(PixelFont.rect("→", 2, Pal.ACCENT))
	names.add_child(PixelFont.rect(str(to.name).to_upper(), 2, Pal.ACCENT))
	card.add(names)
	var hero = HeroView.new()
	hero.happy = true
	hero.forced_pose = "flex"
	hero.setup(App.state, App.profile(), App.loadout(), App.active_pet(), false)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add(hero)
	return card


func _item_card(ev: Dictionary):
	var it = Items.by_id(ev.id)
	if it == null:
		return null
	var rc = Pal.rarity(it.rarity)
	var legendary = it.rarity == "legendary"
	var c = _rcard(rc, legendary)
	if legendary:
		_glow_loop(c.panel)
	c.panel.tooltip_text = it.flavor
	var kick = Kit.hbox(6)
	kick.add_child(_kicker("LOOT" if ev.how == "drop" else "UNLOCKED", rc))
	kick.add_child(Kit.label(str(it.rarity).to_upper(), 10, rc, true))
	c.main.add_child(kick)
	c.main.add_child(_title_l(it.name))
	var perks = Items.perk_summary(it.get("perk"))
	if not perks.is_empty():
		c.main.add_child(_perk_l(" · ".join(PackedStringArray(perks))))
	# The piece of gear by itself, as big as fits the plate in whole pixels.
	var art = PixFit.make(Art.item_icon_texture(it.id), Vector2(48, 48), 3)
	var card = _finish(c, _plate(art, rc, 56))
	var b = Kit.button("Equip", "secondary", Callable(), "sm")
	b.pressed.connect(_on_equip.bind(it, b))
	b.custom_minimum_size = Vector2(0, 36)
	c.row.add_child(Kit.vcenter(b))
	_equip_buttons.append({"button": b, "item": it})
	_refresh_buttons()
	return card


func _pet_card(ev: Dictionary):
	var pet = Pets.by_id(ev.id)
	if pet == null:
		return null
	var rc = Pal.rarity(pet.rarity)
	var legendary = pet.rarity == "legendary"
	var c = _rcard(rc, legendary)
	if legendary:
		_glow_loop(c.panel)
	c.panel.tooltip_text = pet.flavor
	var kick = Kit.hbox(6)
	kick.add_child(_kicker("NEW COMPANION", rc))
	c.main.add_child(kick)
	c.main.add_child(_title_l("%s the %s" % [pet.name, pet.species]))
	var perks = Items.perk_summary(pet.get("perk"))
	if not perks.is_empty():
		c.main.add_child(_perk_l(" · ".join(PackedStringArray(perks))))
	var pv = PetView.new()
	pv.setup(pet.id, 44.0, true)
	var card = _finish(c, _plate(pv, rc, 56))
	var b = Kit.button("Follow me", "secondary", Callable(), "sm")
	b.pressed.connect(_on_pet.bind(pet, b))
	b.custom_minimum_size = Vector2(0, 36)
	c.row.add_child(Kit.vcenter(b))
	_pet_buttons.append({"button": b, "pet": pet})
	_refresh_buttons()
	return card


## A legendary card breathes: its panel brightens and dims.
func _glow_loop(panel: Control) -> void:
	var tw = panel.create_tween()
	tw.set_loops()
	tw.tween_property(panel, "self_modulate", Color(1.35, 1.3, 1.1), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "self_modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)


func _on_equip(it: Dictionary, from: Control) -> void:
	App.equip(it.slot, it.id)
	Sfx.tap()
	Kit.burst(from, Pal.rarity(it.rarity), 18)
	App.toast("Equipped %s" % it.name, "good", "armory")
	_refresh_buttons()


func _on_pet(pet: Dictionary, from: Control) -> void:
	App.set_active_pet(pet.id)
	Sfx.pet()
	Kit.burst(from, Pal.rarity(pet.rarity), 18)
	App.toast("%s is now following you" % pet.name, "good", "paw")
	_refresh_buttons()


func _refresh_buttons() -> void:
	var lo = App.loadout()
	for e in _equip_buttons:
		if not is_instance_valid(e.button):
			continue
		var on = lo.get(e.item.slot) == e.item.id
		e.button.disabled = on
		e.button.text = "Equipped" if on else "Equip"
		Kit.style_button(e.button, "ghost" if on else "secondary", "sm")
	for e in _pet_buttons:
		if not is_instance_valid(e.button):
			continue
		var on = App.active_pet() == e.pet.id
		e.button.disabled = on
		e.button.text = "Active" if on else "Follow me"
		Kit.style_button(e.button, "ghost" if on else "secondary", "sm")
	if is_instance_valid(_hero):
		_hero.setup(App.state, App.profile(), App.loadout(), App.active_pet(), false)
