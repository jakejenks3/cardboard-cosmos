class_name BountyView
extends RefCounted
## The weekly bounty on screen (rules in game/bounty.gd): the card shown on the
## Hero and Adventure tabs, and the sheet with the details, the next rewards
## and the past weeks.
##
## On the Hero tab (`card(false)`) it is a slip (Kit.row) inside the ADVENTURE
## section; on the Adventure tab (`card(true)`) the same slip in a window of its
## own. Since the Workshop review (2026-11-27) the slip is plain cream paper like
## every other row: the violet is the monster's framed slot and the WEEKLY BOUNTY
## tag, the weaknesses are flat tags, a claimed bounty has a green tag.


## The coins a win this week would pay (streak included), before any crush bonus.
static func coins_now(w: Dictionary) -> int:
	var cur = w.current
	if cur.defeated:
		return int(cur.coins)
	return Bounty.coins_for(int(w.streak) + 1, false)


static func _left_text() -> String:
	var left = Bounty.days_left(App.today)
	if left <= 1:
		return "ends tonight"
	return "%d days left" % left


## A colour for big numbers on cream paper: darkened in its own hue until it reads, as ui/ink.gd does (gold
## becomes a deep gold; 2026-11-27 Workshop review: gold on paper looked faded).
static func _paper_ink(c: Color) -> Color:
	return Ink.adjust(c, Pal.PANEL, Ink.MIN_PIXEL)


## A small flat tag for the monster's weakness (a tag only says something: it is no key).
static func weak_pill(d: String) -> Control:
	var tip = "Weak to %s: those sessions hit for ×%s" % [str(TT.DISCIPLINE_META[d].name).to_lower(), TTUtil.num_str(Bounty.WEAK_MULT)]
	return Kit.icon_chip(d, "×%s" % TTUtil.num_str(Bounty.WEAK_MULT), Pal.disc(d), tip)


## A small flat tag for the muscle group the monster is weak to.
static func part_pill(g: String) -> Control:
	var tip = "Weak to %s: a session with %d sets or more of it hits for ×%s" % [str(Bounty.MUSCLE_NAMES.get(g, g)).to_lower(), Bounty.WEAK_SETS, TTUtil.num_str(Bounty.WEAK_MULT)]
	return Kit.icon_chip("muscle", "%s ×%s" % [str(Bounty.MUSCLE_NAMES.get(g, g)), TTUtil.num_str(Bounty.WEAK_MULT)], Pal.LIFT, tip)


## This week's bounty as a tappable slip. `big` (Adventure): a window of its own with the sign "WEEKLY
## BOUNTY" and the days left on its note, a larger monster and its flavour line; the small one (Hero tab, in
## its ADVENTURE section) is the slip alone. (2026-11-27 Workshop review: the two had two looks, a dark
## violet panel and a lilac slip, the only tinted row on the Hero tab. Both are now the same cream slip, the
## violet only in the monster's slot and the tag.)
static func card(big: bool = false) -> Control:
	var w = Bounty.of(App.state)
	if w == null:
		return Kit.gap(0)
	if not big:
		return _row(w, false)
	var cur = w.current
	var note = Kit.hbox(4)
	note.add_child(Kit.vcenter(Icons.rect("check" if cur.defeated else "clock", 16)))
	note.add_child(Kit.vcenter(Kit.label(("Crushed" if cur.crushed else "Beaten") if cur.defeated else _left_text(), 12, Pal.TEXT, true)))
	var sec = Kit.section("bounty_now", "WEEKLY BOUNTY", "skull", Pal.BOUNTY, note, Callable(), 8, 10)
	sec.add(_row(w, true))
	return sec


## The bounty as a slip (Kit.row, plain cream paper): the monster in a violet-framed slot, its name (a Label
## holding exactly the name), its weaknesses as flat tags on a line of their own (beside the name they cut it
## short), the HP bar or what it paid, the coins. `big`: a larger monster, its flavour line under the name,
## and no WEEKLY BOUNTY tag (the window's sign says it).
static func _row(w: Dictionary, big: bool = false) -> Control:
	var cur = w.current
	var mon = Bounty.monster(cur.monster)
	var hp_left = maxf(0.0, float(cur.hp) - float(cur.damage))
	var c = Kit.row(BountyView.open, Pal.BOUNTY, null, 8, 6)
	c.tooltip_text = "A new monster every Monday, sized from your last four weeks.\nBeat it by Sunday night for coins."
	var row = Kit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot = PanelContainer.new()
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", PixBox.slot(Pal.BOUNTY, false, 4))
	var bv = BossView.new()
	bv.setup(cur.monster, 72.0 if big else 48.0, not cur.defeated)
	bv.set_dim(cur.defeated)
	slot.add_child(bv)
	row.add_child(slot)
	var main = Kit.vbox(4)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if cur.defeated:
		var kick = Kit.hbox(6)
		kick.add_child(Kit.tag("CRUSHED" if cur.crushed else "BOUNTY CLAIMED", Pal.GOOD, true, 11))
		kick.add_child(Kit.vcenter(Icons.rect("check", 16)))
		main.add_child(kick)
	elif not big:
		var kick2 = Kit.hbox(6)
		kick2.add_child(Kit.tag("WEEKLY BOUNTY", Pal.BOUNTY, false, 11))
		kick2.add_child(Kit.vcenter(Kit.clip(_left_text(), 11, Pal.MUTED, true)))
		main.add_child(kick2)
	main.add_child(Kit.clip(mon.name, 17 if big else 15, null, true))
	if big:
		main.add_child(Kit.clip(mon.epithet, 12, Pal.MUTED))
	if not cur.defeated:
		var tags = Kit.flow(6)
		if cur.weak != null:
			tags.add_child(weak_pill(cur.weak))
		if cur.get("weakPart") != null:
			tags.add_child(part_pill(str(cur.weakPart)))
		if tags.get_child_count() > 0:
			main.add_child(tags)
		else:
			tags.free()
	if cur.defeated:
		var done = Kit.hbox(6)
		done.add_child(Kit.coin_pill(cur.coins, "Coins this bounty paid"))
		if not cur.crushed:
			var more = int(ceil(float(cur.hp) * Bounty.CRUSH_MULT)) - int(cur.damage)
			done.add_child(Kit.vcenter(Kit.clip("%s more damage crushes it: +%d" % [Xp.fmt_int(more), Bounty.COINS_CRUSH], 11, Pal.MUTED)))
		elif int(w.streak) >= 2:
			done.add_child(Kit.icon_chip("flame", "%d in a row" % int(w.streak), Pal.ACCENT2, "Bounties won in a row"))
		main.add_child(done)
	else:
		main.add_child(Kit.hp_bar(hp_left, float(cur.hp), 18 if big else 14))
		var foot = Kit.hbox(6)
		foot.add_child(Kit.coin_pill(coins_now(w), "Coins for beating it this week", 11))
		if int(w.streak) >= 1:
			foot.add_child(Kit.icon_chip("flame", "%d in a row" % int(w.streak), Pal.ACCENT2, "Bounties won in a row: each adds %d coins, up to %d" % [Bounty.COINS_STREAK_STEP, Bounty.COINS_STREAK_MAX]))
		main.add_child(foot)
	row.add_child(main)
	row.add_child(Kit.vcenter(Icons.rect("chevron_right", 18)))
	c.add(row)
	return c


static func _stat(value: String, caption: String, color: Color, icon: String) -> Control:
	var t = Kit.card(4, Callable(), 8)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top = Kit.hbox(4)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(Kit.vcenter(Icons.rect(icon, 14)))
	top.add_child(Kit.vcenter(Kit.label(caption, 11, Pal.MUTED, true)))
	t.add(top)
	t.add(Kit.big_number(value, color, 96, 3))
	return t


## The bounty gear not earned yet, nearest first: [{item, progress}].
static func next_rewards(s: Dictionary) -> Array:
	var out = []
	for it in Items.all():
		if s.items.has(it.id) or not str(it.id).begins_with("bounty_"):
			continue
		var p = Items.unlock_progress(it, s)
		if p != null:
			out.append({"item": it, "progress": p, "ratio": Goals.progress_ratio(p)})
	TTUtil.stable_sort(out, func(a, b): return a.ratio > b.ratio)
	return out


## The detail sheet: the monster, how it works, your record, what is next.
static func open() -> void:
	var s = App.state
	var w = Bounty.of(s)
	if w == null:
		return
	var cur = w.current
	var mon = Bounty.monster(cur.monster)
	var sh = Kit.sheet("Weekly bounty")

	var bv = BossView.new()
	bv.setup(cur.monster, 120.0, not cur.defeated)
	bv.set_dim(cur.defeated)
	bv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sh.box.add_child(bv)
	var name_l = Kit.para(mon.name, 20, null, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh.box.add_child(name_l)
	var ep = Kit.muted_para(mon.epithet, 13)
	ep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh.box.add_child(ep)

	var chips = Kit.flow(8)
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	if cur.defeated:
		chips.add_child(Kit.pill("check", "Crushed" if cur.crushed else "Beaten", Pal.GOOD))
		chips.add_child(Kit.coin_pill(cur.coins, "Coins this bounty paid"))
	else:
		# (flat tags: they only say something; a raised pill read as a key)
		chips.add_child(Kit.icon_chip("clock", _left_text(), Pal.PANEL2))
		if cur.weak != null:
			chips.add_child(weak_pill(cur.weak))
		if cur.get("weakPart") != null:
			chips.add_child(part_pill(str(cur.weakPart)))
		chips.add_child(Kit.coin_pill(coins_now(w), "Coins for beating it this week"))
		chips.add_child(Kit.icon_chip("bolt", "+%d crush" % Bounty.COINS_CRUSH, Pal.ACCENT2, "Deal %d%% of its HP for a bonus" % TTUtil.jsround(Bounty.CRUSH_MULT * 100.0)))
	sh.box.add_child(chips)
	sh.box.add_child(Kit.hp_bar(maxf(0.0, float(cur.hp) - float(cur.damage)), float(cur.hp), 22, "Every XP you earn from a session this week deals 1 damage."))
	var how = Kit.muted_para("Its HP is 90%% of your average week over the last four. Train its weak discipline, or its weak muscles (%d sets or more), for ×%s. A new monster arrives every Monday." % [Bounty.WEAK_SETS, TTUtil.num_str(Bounty.WEAK_MULT)], 12)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh.box.add_child(how)

	# --- your record ---------------------------------------------------------------
	var tiles = Kit.grid(3, 8)
	# (gold and orange numbers on paper in their deep shades: _paper_ink)
	tiles.add_child(_stat(str(int(w.wins)), "WINS", Pal.TEXT, "skull"))
	tiles.add_child(_stat(str(int(w.streak)), "IN A ROW", _paper_ink(Pal.ACCENT2), "flame"))
	tiles.add_child(_stat(Xp.fmt_int(w.coins), "COINS", _paper_ink(Pal.ACCENT), "coin"))
	sh.box.add_child(tiles)

	# --- the next piece of bounty gear ------------------------------------------------
	var nxt = next_rewards(s)
	if not nxt.is_empty():
		sh.box.add_child(Kit.section_title("Bounty gear"))
		for i in range(mini(2, nxt.size())):
			var it = nxt[i].item
			var rc = Pal.rarity(it.rarity)
			var rcard = Kit.card(4, ArmoryDetail.open_item.bind(it), 8)
			rcard.accent(rc)
			var rrow = Kit.hbox(10)
			rrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pic = PixelRect.make(Art.item_tryon_texture(it.id, s, App.profile(), App.loadout()), 1.0)
			rrow.add_child(Kit.vcenter(pic))
			var rmain = Kit.vbox(3)
			rmain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rmain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var rhead = Kit.hbox(6)
			rhead.add_child(Kit.clip(it.name, 14, null, true))
			rhead.add_child(Kit.rarity_badge(it.rarity))
			rmain.add_child(rhead)
			rmain.add_child(Kit.muted(Units.text(Items.unlock_hint(it), App.settings()), 11))
			rmain.add_child(Parts.progress_line(nxt[i].progress, rc))
			rrow.add_child(rmain)
			rcard.add(rrow)
			Kit.passthrough(rcard.box)
			sh.box.add_child(rcard)

	# --- the weeks so far, newest first ---------------------------------------------
	var past = []
	for r in w.history:
		if r.week != cur.week:
			past.append(r)
	if not past.is_empty():
		sh.box.add_child(Kit.section_title("Past weeks"))
		var g = Kit.grid(4, 6)
		var shown = 0
		for i in range(past.size() - 1, -1, -1):
			if shown >= 12:
				break
			shown += 1
			g.add_child(_past_tile(past[i]))
		sh.box.add_child(g)
	sh.open()


static func _past_tile(r: Dictionary) -> Control:
	var mon = Bounty.monster(r.monster)
	var t = Kit.card(2, Callable(), 6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if r.crushed:
		t.accent(Pal.ACCENT, true)
	elif r.defeated:
		t.accent(Pal.GOOD)
	var bv = BossView.new()
	bv.setup(r.monster, 54.0, false)
	bv.set_dim(not r.defeated)
	bv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.add(bv)
	var cap = Kit.clip(Dates.format_date(r.week), 10, Pal.TEXT if r.defeated else Pal.MUTED, true)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add(cap)
	var res = "CRUSHED" if r.crushed else ("WON" if r.defeated else "%d%%" % mini(99, int(floor(float(r.damage) / maxf(1.0, float(r.hp)) * 100.0))))
	var rl = Kit.clip(res, 10, Pal.ACCENT if r.crushed else (Pal.GOOD if r.defeated else Pal.MUTED), true)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add(rl)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.tooltip_text = "%s, week of %s: %s / %s damage" % [mon.name, Dates.format_date(r.week), Xp.fmt_int(r.damage), Xp.fmt_int(r.hp)]
	return t
