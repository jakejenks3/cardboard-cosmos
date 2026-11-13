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
const BOSS_RED = Color("d7263d")
const STREAK = Color("ff8a5c")

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
var _footer_btn: Button
var _confetti: Confetti
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
	# radial-gradient(circle at 50% 20%, #2d2460 0, #14102a 60%)
	var bg = TextureRect.new()
	var grad = Gradient.new()
	grad.set_color(0, Color("2d2460"))
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

	_xp_rect = PixelFont.rect("+0 XP", 3, _xp_color)
	_xp_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.add_child(_xp_rect)
	_set_count(0.0)
	_count_tween = create_tween()
	_count_tween.tween_method(_set_count, 0.0, float(_amount), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var summary = _summary()
	if summary != null:
		head.add_child(summary)
	if _xp_ev != null and float(_xp_ev.get("bonusPct", 0)) > 0.0:
		var bonus = Kit.muted("includes +%d%% gear bonus" % TTUtil.jsround(float(_xp_ev.bonusPct) * 100.0), 11)
		bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(bonus)
	return head


func _summary():
	if _import_ev != null:
		var f = Kit.flow(6)
		f.alignment = FlowContainer.ALIGNMENT_CENTER
		f.add_child(Kit.muted("%d sessions ·" % int(_import_ev.count), 13))
		for d in TT.DISCIPLINES:
			var v = int(_import_ev.byDiscipline.get(d, 0))
			if v > 0:
				var h = Kit.hbox(3)
				h.add_child(Icons.rect(d, 16))
				h.add_child(Kit.muted(Xp.fmt_int(v), 13))
				f.add_child(h)
		return f
	var text = ""
	if _body_ev != null:
		text = "Weekly check-in bonus. See you next week." if int(_body_ev.amount) > 0 else "Logged. This week’s bonus was already earned."
	elif _xp_ev != null:
		var bits = PackedStringArray()
		for p in _xp_ev.parts:
			bits.append("%s +%s" % [Icons.strip_emoji(p.label), Xp.fmt_int(p.xp)])
		text = " · ".join(bits)
		if int(_xp_ev.prBonus) > 0:
			text += " · PR bonus +%s" % Xp.fmt_int(_xp_ev.prBonus)
	if text == "":
		return null
	var l = Kit.muted_para(text, 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return Kit.pad(l, 24, 0, 24, 0)


func _set_count(v: float) -> void:
	if not is_instance_valid(_xp_rect):
		return
	var t = PixelFont.tex("+%s XP" % Xp.fmt_int(TTUtil.jsround(v)), _xp_color)
	_xp_rect.texture = t
	_xp_rect.custom_minimum_size = Vector2(t.get_width() * 3, t.get_height() * 3)


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
	if _xp_ev != null:
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
			delay = 1.1 if _cards[i - 1].type == "boss" else 0.65
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
				Sfx.pr()
			"boss":
				if ev.defeated:
					Sfx.boss_down()
					_confetti.burst(1.2)
				else:
					Sfx.hit()
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


func _skip() -> void:
	if _phase == "done" or _closed:
		return
	_gen += 1
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_set_count(float(_amount))
	if _xp_ev != null:
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

## A reel card: {panel, style, row (HBox), main (VBox)}.
func _rcard(border: Color, bg: Color = Pal.PANEL, glow: bool = false) -> Dictionary:
	var p = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var st = Kit.sbox(bg, 14, border, 1, 14, 12)
	if glow:
		st.set_border_width_all(2)
		st.shadow_color = Pal.with_alpha(border, 0.4)
		st.shadow_size = 12
	p.add_theme_stylebox_override("panel", st)
	var row = Kit.hbox(12)
	p.add_child(row)
	var main = Kit.vbox(2)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return {"panel": p, "style": st, "row": row, "main": main}


func _icon_cell(icon: String) -> Control:
	var c = CenterContainer.new()
	c.custom_minimum_size = Vector2(44, 44)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(Icons.rect(icon, 32))
	return c


func _kicker(text: String) -> Label:
	return Kit.label(text, 11, Pal.MUTED, true)


func _title_l(text: String) -> Label:
	return Kit.para(text, 16, null, true)


func _sub(text: String) -> Label:
	return Kit.muted_para(text, 13)


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
		"rank":
			var rank = Xp.RANKS[int(ev.to)]
			var rc = Pal.hex(rank.color)
			var m = TT.DISCIPLINE_META[ev.discipline]
			var c = _rcard(rc, Pal.PANEL, true)
			c.main.add_child(_kicker("RANK UP · %s" % m.name.to_upper()))
			c.main.add_child(Kit.rich("[b][color=%s]%s →[/color] [color=%s]%s[/color][/b]" % [Kit.hex_of(Pal.MUTED), Kit.esc(Xp.RANKS[int(ev.from)].name), Kit.hex_of(rc), Kit.esc(rank.name)], 16))
			var sub = Kit.hbox(5)
			sub.add_child(Icons.rect(ev.discipline, 14))
			sub.add_child(_sub("%s level %d reached." % [m.statName, int(rank.minLevel)]))
			c.main.add_child(sub)
			return _finish(c, _icon_cell("medal"))
		"stage":
			return _stage_card(ev)
		"pr":
			var c = _rcard(Pal.ACCENT)
			c.main.add_child(_kicker("NEW RECORD"))
			c.main.add_child(_title_l(Icons.strip_emoji(ev.title)))
			c.main.add_child(_sub(Icons.strip_emoji(ev.detail)))
			return _finish(c, _icon_cell(Icons.for_emoji(ev.icon)))
		"achievement":
			var a = Achievements.by_id(ev.id)
			if a == null:
				return null
			var tier = Achievements.tier_of(a)
			var tc = Pal.hex(Achievements.TIER_COLOR[tier])
			var c = _rcard(tc)
			c.main.add_child(_kicker("%s TROPHY · +%s XP" % [tier.to_upper(), Xp.fmt_int(a.xp)]))
			c.main.add_child(_title_l(Icons.strip_emoji(a.name)))
			c.main.add_child(_sub(Icons.strip_emoji(a.desc)))
			return _finish(c, _icon_cell(Icons.for_emoji(a.icon)))
		"item":
			return _item_card(ev)
		"pet":
			return _pet_card(ev)
		"streak":
			var c = _rcard(STREAK)
			c.main.add_child(_kicker("STREAK"))
			c.main.add_child(_title_l("%d weeks in a row" % int(ev.current)))
			c.main.add_child(_sub("Consistency is the real superpower."))
			return _finish(c, _icon_cell("flame"))
	return null


func _boss_card(ev: Dictionary, animate: bool) -> Control:
	var boss = Campaign.boss_at(int(ev.index))
	var c = _rcard(BOSS_RED, Color("2a1c42"))
	var bv = BossView.new()
	bv.setup(boss.id, 64.0, false)
	var kick_row = Kit.hbox(6)
	var kicker = _kicker("BOSS FIGHT")
	kick_row.add_child(kicker)
	if ev.weak:
		kick_row.add_child(Kit.tag("SUPER EFFECTIVE ×%s" % TTUtil.num_str(Campaign.WEAK_MULT), BOSS_RED, false, 10))
	c.main.add_child(kick_row)
	c.main.add_child(_title_l(boss.name))
	var max_hp = maxf(1.0, float(ev.maxHp))
	var hp = Kit.bar(float(ev.hpBefore) / max_hp, Color("e8394f"), 10)
	c.main.add_child(Kit.pad(hp, 0, 4, 0, 2))
	var foot = Kit.rich("", 13, Pal.MUTED)
	c.main.add_child(foot)
	var parts = {"boss": boss, "ev": ev, "bv": bv, "kicker": kicker, "hp": hp, "foot": foot, "style": c.style, "panel": c.panel}
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
			tw.tween_callback(func(): _boss_down(parts))
	else:
		hp.set_value(float(ev.hpAfter) / max_hp, false)
		if ev.defeated:
			_boss_down(parts)
		else:
			_boss_foot(parts, float(ev.hpAfter), false)
	return card


func _boss_foot(parts: Dictionary, hp: float, down: bool) -> void:
	var ev = parts.ev
	var boss = parts.boss
	var text = "−%s damage · " % Xp.fmt_int(ev.damage)
	if down:
		var reward = ""
		if boss.get("rewardItem") != null:
			var it = Items.by_id(boss.rewardItem)
			if it != null:
				reward = " · Reward: %s" % Kit.esc(it.name)
		text += "[b][color=%s]+%s XP%s[/color][/b]" % [Kit.hex_of(Pal.GOOD), Xp.fmt_int(boss.xp), reward]
	else:
		text += "%s / %s HP left" % [Xp.fmt_int(hp), Xp.fmt_int(ev.maxHp)]
	parts.foot.text = text


func _boss_down(parts: Dictionary) -> void:
	if not is_instance_valid(parts.panel):
		return
	parts.kicker.text = "BOSS DEFEATED"
	parts.kicker.add_theme_color_override("font_color", Pal.ACCENT)
	parts.bv.set_dim(true)
	var st: StyleBoxFlat = parts.style
	st.border_color = Pal.ACCENT
	st.set_border_width_all(2)
	st.shadow_color = Pal.with_alpha(Pal.ACCENT, 0.35)
	st.shadow_size = 14
	_boss_foot(parts, 0.0, true)


func _stage_card(ev: Dictionary) -> Control:
	var to = Xp.STAGES[int(ev.to)]
	var p = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var st = Kit.sbox(Color("33275f"), 14, Pal.ACCENT, 2, 20, 20)
	st.shadow_color = Pal.with_alpha(Pal.ACCENT, 0.3)
	st.shadow_size = 12
	p.add_theme_stylebox_override("panel", st)
	var v = Kit.vbox(8)
	p.add_child(v)
	var k = _kicker("BODY EVOLVED")
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	var names = Kit.hbox(8)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_child(PixelFont.rect(str(Xp.STAGES[int(ev.from)].name).to_upper(), 2, Pal.MUTED))
	names.add_child(PixelFont.rect("→", 2, Pal.ACCENT))
	names.add_child(PixelFont.rect(str(to.name).to_upper(), 2, Pal.ACCENT))
	v.add_child(names)
	var hero = HeroView.new()
	hero.happy = true
	hero.forced_pose = "flex"
	hero.setup(App.state, App.profile(), App.loadout(), App.active_pet(), false)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(hero)
	var blurb = _sub(to.blurb)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(blurb)
	return p


func _item_card(ev: Dictionary):
	var it = Items.by_id(ev.id)
	if it == null:
		return null
	var rc = Pal.rarity(it.rarity)
	var legendary = it.rarity == "legendary"
	var c = _rcard(rc, Color("3a2f10") if legendary else Pal.PANEL, true)
	if legendary:
		_glow_loop(c.panel, c.style)
	var kick = Kit.hbox(6)
	kick.add_child(_kicker("LOOT DROP" if ev.how == "drop" else "UNLOCKED"))
	kick.add_child(Kit.rarity_badge(it.rarity))
	c.main.add_child(kick)
	c.main.add_child(_title_l(it.name))
	c.main.add_child(_sub(it.flavor))
	var perks = Items.perk_summary(it.get("perk"))
	if not perks.is_empty():
		c.main.add_child(_perk_l(" · ".join(PackedStringArray(perks))))
	var art = PixelRect.make(Art.item_texture(it.id), 1.0)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var card = _finish(c, art)
	var b = Kit.button("Equip", "secondary", _on_equip.bind(it), "sm")
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
	var c = _rcard(rc, Color("3a2f10") if legendary else Pal.PANEL, true)
	if legendary:
		_glow_loop(c.panel, c.style)
	c.main.add_child(_kicker("NEW COMPANION"))
	c.main.add_child(_title_l("%s the %s" % [pet.name, pet.species]))
	c.main.add_child(_sub(pet.flavor))
	var perks = Items.perk_summary(pet.get("perk"))
	if not perks.is_empty():
		c.main.add_child(_perk_l(" · ".join(PackedStringArray(perks))))
	var pv = PetView.new()
	pv.setup(pet.id, 56.0, true)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var card = _finish(c, pv)
	var b = Kit.button("Follow me", "secondary", _on_pet.bind(pet), "sm")
	b.custom_minimum_size = Vector2(0, 36)
	c.row.add_child(Kit.vcenter(b))
	_pet_buttons.append({"button": b, "pet": pet})
	_refresh_buttons()
	return card


## The legendary card's breathing glow (web `glow` keyframes).
func _glow_loop(panel: Control, st: StyleBoxFlat) -> void:
	var tw = panel.create_tween()
	tw.set_loops()
	tw.tween_property(st, "shadow_size", 26, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(st, "shadow_size", 10, 0.8).set_trans(Tween.TRANS_SINE)


func _on_equip(it: Dictionary) -> void:
	App.equip(it.slot, it.id)
	Sfx.tap()
	App.toast("Equipped %s" % it.name, "good", "armory")
	_refresh_buttons()


func _on_pet(pet: Dictionary) -> void:
	App.set_active_pet(pet.id)
	Sfx.tap()
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
