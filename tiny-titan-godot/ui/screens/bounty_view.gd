class_name BountyView
extends RefCounted
## The weekly bounty on screen (rules in game/bounty.gd): the card shown on the
## Hero and Adventure tabs, and the sheet with the details, the next rewards
## and the past weeks.


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


## A small pill for the monster's weakness.
static func weak_pill(d: String) -> Control:
	var tip = "Weak to %s: those sessions hit for ×%s" % [str(TT.DISCIPLINE_META[d].name).to_lower(), TTUtil.num_str(Bounty.WEAK_MULT)]
	return Kit.pill(d, "×%s" % TTUtil.num_str(Bounty.WEAK_MULT), Pal.disc(d), tip, Color.WHITE, 12)


## A small pill for the muscle group the monster is weak to.
static func part_pill(g: String) -> Control:
	var tip = "Weak to %s: a session with %d sets or more of it hits for ×%s" % [str(Bounty.MUSCLE_NAMES.get(g, g)).to_lower(), Bounty.WEAK_SETS, TTUtil.num_str(Bounty.WEAK_MULT)]
	return Kit.pill("muscle", "%s ×%s" % [str(Bounty.MUSCLE_NAMES.get(g, g)), TTUtil.num_str(Bounty.WEAK_MULT)], Pal.LIFT, tip, Color.WHITE, 12)


## This week's bounty as a tappable card. `big` (Adventure) shows a larger
## monster and the reward chips; the small one (Hero tab) is a single row.
static func card(big: bool = false) -> Control:
	var w = Bounty.of(App.state)
	if w == null:
		return Kit.gap(0)
	var cur = w.current
	var mon = Bounty.monster(cur.monster)
	var hp_left = maxf(0.0, float(cur.hp) - float(cur.damage))
	var c = Kit.card(6, BountyView.open, 10 if not big else 12)
	c.accent(Pal.ACCENT if cur.defeated else Pal.BOUNTY, true)
	c.tooltip_text = "A new monster every Monday, sized from your last four weeks.\nBeat it by Sunday night for coins."
	var row = Kit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bv = BossView.new()
	bv.setup(cur.monster, 90.0 if big else 54.0, not cur.defeated)
	bv.set_dim(cur.defeated)
	row.add_child(Kit.vcenter(bv))
	var main = Kit.vbox(5)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kick = Kit.hbox(6)
	if cur.defeated:
		kick.add_child(Kit.tag("CRUSHED" if cur.crushed else "BOUNTY CLAIMED", Pal.ACCENT, true, 10))
		kick.add_child(Kit.vcenter(Icons.rect("check", 14)))
	else:
		kick.add_child(Kit.tag("WEEKLY BOUNTY", Pal.BOUNTY, false, 10))
		kick.add_child(Kit.vcenter(Kit.label(_left_text(), 11, Pal.with_alpha(Pal.TEXT, 0.75), true)))
	main.add_child(kick)
	var top = Kit.hbox(8)
	top.add_child(Kit.clip(mon.name, 16 if not big else 18, null, true))
	if cur.weak != null and not cur.defeated:
		top.add_child(weak_pill(cur.weak))
	if cur.get("weakPart") != null and not cur.defeated:
		top.add_child(part_pill(str(cur.weakPart)))
	main.add_child(top)
	if cur.defeated:
		var done = Kit.hbox(6)
		done.add_child(Kit.coin_pill(cur.coins, "Coins this bounty paid"))
		if not cur.crushed:
			var more = int(ceil(float(cur.hp) * Bounty.CRUSH_MULT)) - int(cur.damage)
			done.add_child(Kit.vcenter(Kit.muted("%s more damage crushes it: +%d" % [Xp.fmt_int(more), Bounty.COINS_CRUSH], 11)))
		elif int(w.streak) >= 2:
			done.add_child(Kit.icon_chip("flame", "%d in a row" % int(w.streak), Pal.ACCENT2, "Bounties won in a row", Color.WHITE))
		main.add_child(done)
	else:
		main.add_child(Kit.hp_bar(hp_left, float(cur.hp), 18 if big else 14))
		var foot = Kit.hbox(6)
		foot.add_child(Kit.coin_pill(coins_now(w), "Coins for beating it this week", 11))
		if int(w.streak) >= 1:
			foot.add_child(Kit.icon_chip("flame", "%d in a row" % int(w.streak), Pal.ACCENT2, "Bounties won in a row: each adds %d coins, up to %d" % [Bounty.COINS_STREAK_STEP, Bounty.COINS_STREAK_MAX], Color.WHITE))
		if big:
			# Clipped, so a long line can never make the card wider than the screen.
			foot.add_child(Kit.vcenter(Kit.clip(mon.epithet, 11, Pal.MUTED)))
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
		chips.add_child(Kit.pill("clock", _left_text(), Pal.PANEL2, "", Pal.TEXT))
		if cur.weak != null:
			chips.add_child(weak_pill(cur.weak))
		if cur.get("weakPart") != null:
			chips.add_child(part_pill(str(cur.weakPart)))
		chips.add_child(Kit.coin_pill(coins_now(w), "Coins for beating it this week"))
		chips.add_child(Kit.pill("bolt", "+%d crush" % Bounty.COINS_CRUSH, Pal.ACCENT2, "Deal %d%% of its HP for a bonus" % TTUtil.jsround(Bounty.CRUSH_MULT * 100.0), Color.WHITE))
	sh.box.add_child(chips)
	sh.box.add_child(Kit.hp_bar(maxf(0.0, float(cur.hp) - float(cur.damage)), float(cur.hp), 22, "Every XP you earn from a session this week deals 1 damage."))
	var how = Kit.muted_para("Its HP is 90%% of your average week over the last four. Train its weak discipline, or its weak muscles (%d sets or more), for ×%s. A new monster arrives every Monday." % [Bounty.WEAK_SETS, TTUtil.num_str(Bounty.WEAK_MULT)], 12)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh.box.add_child(how)

	# --- your record ---------------------------------------------------------------
	var tiles = Kit.grid(3, 8)
	tiles.add_child(_stat(str(int(w.wins)), "WINS", Pal.TEXT, "skull"))
	tiles.add_child(_stat(str(int(w.streak)), "IN A ROW", Pal.ACCENT2, "flame"))
	tiles.add_child(_stat(Xp.fmt_int(w.coins), "COINS", Pal.ACCENT, "coin"))
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
			rmain.add_child(Kit.muted(Items.unlock_hint(it), 11))
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
