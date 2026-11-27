class_name RpgUi
extends RefCounted
## The Realm's shared look, and (later) its facade to App (RPG_PLAN.md 11.5).
##
## THE LOOK (this half is done; nothing in it reads App, the log or the save):
##   color(school_or_name) -> Color      the colour of a school ("push"... "grit"), of "realm", of "plain"
##   school_icon(id) -> String           the Icons name of a school
##   status_icon(entry, px) -> Control   a status of a unit ({"id", "turns", "stacks", "amount"}) as an icon with
##                                       its stacks; meta "rpg_status" = its id
##   rarity_color(rarity) -> Color
##   ore_pill(amount) -> PanelContainer  "[ore] 120"
##   stat_chip(stat_id, value)           "[icon] Chest 31" in the colour of the stat's school
##   cost_pips(cost, color) -> Control   a move's energy cost as pips ("Free" for none)
##   move_card(move, opts) -> Control    a move as a card: school colour and icon, name, cost pips, cooldown, what
##                                       it does in words (RpgMoves.words). opts: "tap": Callable, "compact": bool
##                                       (no words), "tag": String (a word at its right end, "EQUIPPED"), "dim":
##                                       bool (not learned yet). Meta "rpg_move" = its id.
##
## THE FACADE (input, sheet, boosts, hero, level, save, commit, fight, finish) is another builder's: it goes
## at the marked place at the end of this file.


# =============================================================================
# The look
# =============================================================================

## The colour of a school, of the Realm itself ("realm") or of a plain Strike.
static func color(id: String) -> Color:
	match id:
		"push":
			return Pal.PUSH
		"pull":
			return Pal.PULL
		"legs":
			return Pal.LEGS
		"speed":
			return Pal.RUN
		"grip":
			return Pal.CLIMB
		"mind":
			return Pal.READ
		"flow":
			return Pal.PT
		"grit":
			return Pal.GRIT
		"realm":
			return Pal.REALM
		"plain":
			return Pal.MUTED
	return Pal.MUTED


## The Icons name of a school ("strike" for plain and for one nobody knows).
static func school_icon(id: String) -> String:
	return str(RpgDefs.SCHOOL_ICONS.get(id, "strike"))


## A status of a unit as an icon `px` big (16, 32 or 48: Icons' whole-number
## sizes); more than one stack is written in its corner. `entry` is the unit's
## own entry ({"id", "turns", "stacks", "amount"}) or just the id.
static func status_icon(entry, px: int = 16) -> Control:
	var id = str(entry.get("id", "")) if entry is Dictionary else str(entry)
	var row = RpgDefs.STATUS.get(id, {})
	var icon_name = str(row.get("icon", ""))
	if id == "broken":
		icon_name = "fx_broken"
	if not Icons.has_icon(icon_name):
		icon_name = "fx_marked"
	var k = Icons.scale_for(float(px))
	var side = float(Icons.SIZE * k)
	var box = Control.new()
	box.custom_minimum_size = Vector2(side, side)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.set_meta("rpg_status", id)
	var ic = Icons.rect(icon_name, float(px))
	ic.position = Vector2.ZERO
	ic.size = Vector2(side, side)
	box.add_child(ic)
	var stacks = int(entry.get("stacks", 1)) if entry is Dictionary else 1
	if stacks > 1:
		var n = PixelFont.rect(str(stacks), k, Pal.TEXT)
		n.position = Vector2(side - n.custom_minimum_size.x, side - n.custom_minimum_size.y)
		n.size = n.custom_minimum_size
		box.add_child(n)
	return box


## A status in words: "Exposed (2 turns): Takes 25% more damage."
static func status_words(entry: Dictionary) -> String:
	var id = str(entry.get("id", ""))
	var row = RpgDefs.STATUS.get(id, {})
	var head = str(row.get("name", id.capitalize()))
	var bits = []
	var stacks = int(entry.get("stacks", 1))
	if stacks > 1:
		bits.append("x%d" % stacks)
	var turns = int(entry.get("turns", 0))
	if turns > 0:
		bits.append("%d turn%s" % [turns, "" if turns == 1 else "s"])
	if id == "shield" and int(round(float(entry.get("amount", 0.0)))) > 0:
		bits.append("%d left" % int(round(float(entry.get("amount", 0.0)))))
	if not bits.is_empty():
		head += " (%s)" % ", ".join(bits)
	return "%s: %s" % [head, str(row.get("text", ""))]


static func rarity_color(rarity: String) -> Color:
	return Pal.rarity(rarity)


## An amount of ore as a pill in the Realm's colour.
static func ore_pill(amount) -> PanelContainer:
	var p = Kit.pill("ore", Xp.fmt_int(int(round(float(amount)))), color("realm"))
	p.set_meta("rpg_ore", int(round(float(amount))))
	return p


## A stat and its value as a chip in the colour of the school it feeds.
static func stat_chip(stat_id: String, value) -> PanelContainer:
	var school = str(RpgDefs.STAT_SCHOOL.get(stat_id, "plain"))
	var words = "%s %d" % [str(RpgDefs.STAT_NAMES.get(stat_id, stat_id.capitalize())), int(floor(float(value)))]
	var p = Kit.icon_chip(str(RpgDefs.STAT_ICONS.get(stat_id, "star")), words, color(school))
	p.set_meta("rpg_stat", stat_id)
	return p


## A move's energy cost: an energy icon and a pip for each ("Free" for none).
static func cost_pips(cost: int, pip_color = null) -> Control:
	var h = Kit.hbox(3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if cost <= 0:
		h.add_child(Kit.label("Free", 11, Pal.MUTED, true))
		return h
	h.add_child(Kit.vcenter(Icons.rect("energy", 16)))
	h.add_child(Kit.pips(cost, cost, Pal.ACCENT if pip_color == null else pip_color, 8))
	return h


## A move as a card (see the top). Its height depends only on `compact` and on
## how many lines its words take.
static func move_card(move: Dictionary, opts: Dictionary = {}) -> Control:
	var school = str(move.get("school", "plain"))
	var col = color(school)
	var dim = bool(opts.get("dim", false))
	var card = Kit.row(opts.get("tap", Callable()), col, col, 8, 4)
	card.set_meta("rpg_move", str(move.get("id", "")))
	card.set_meta("anchor_id", "rpg_move:" + str(move.get("id", "")))
	var head = Kit.hbox(8)
	var badge = PanelContainer.new()
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", PixBox.make(col, {"lip": 1, "lip_color": col.darkened(0.45), "pad_h": 4, "pad_v": 4}))
	badge.add_child(Icons.rect(school_icon(school), 32))
	head.add_child(badge)
	var mid = Kit.vbox(3)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(Kit.clip(str(move.get("name", "")), 15, Pal.MUTED if dim else null, true))
	var facts = Kit.hbox(6)
	facts.add_child(Kit.tag(str(RpgDefs.SCHOOL_NAMES.get(school, "Strike")), col))
	if bool(move.get("ult", false)):
		facts.add_child(Kit.tag("ULTIMATE", Pal.ACCENT))
	else:
		facts.add_child(cost_pips(int(move.get("cost", 0))))
	var cd = int(move.get("cd", 0))
	if cd > 0:
		facts.add_child(Kit.vcenter(Icons.rect("clock", 16)))
		facts.add_child(Kit.vcenter(Kit.label(str(cd), 12, Pal.MUTED, true)))
	mid.add_child(facts)
	head.add_child(mid)
	if str(opts.get("tag", "")) != "":
		head.add_child(Kit.tag(str(opts.tag), Pal.GOOD))
	card.add(head)
	if not bool(opts.get("compact", false)):
		var words = RpgMoves.words(move)
		var said = " · ".join(words) if not words.is_empty() else ("A plain hit" if str(move.get("kind", "attack")) == "attack" else str(move.get("text", "")))
		if said != "":
			card.add(Kit.muted_para(said, 12))
	if dim:
		card.modulate = Color(1, 1, 1, 0.6)
	return card


# =============================================================================
# THE FACADE (RPG_PLAN.md 11.5): input(), sheet(), boosts(), hero(), level(),
# save(), commit(rpg), fight(what), finish(B, what), foe_tile(...).
# Its builder writes it below this line; nothing above reads App.
# =============================================================================

## The Realm's sub-page in view: map | hero | moves | skills | gear (kept while the app runs).
static var page = "map"
static var _cache = {}
static var _hooked = false


## The cache (sheet, boosts) is dropped whenever the LOG changes (App.changed);
## a change of the Realm's own save (App.rpg_changed) keeps it.
static func _hook() -> void:
	if _hooked:
		return
	_hooked = true
	App.changed.connect(func(): RpgUi._cache = {})


static func drop_cache() -> void:
	_cache = {}


## What the stat engine reads (plain data from App; nothing is changed).
static func input() -> Dictionary:
	return {"sessions": App.sessions(), "state": App.state, "reading": App.reading(), "books": App.books(),
		"body": App.body(), "claims": App.claims(), "settings": App.settings(), "marks": App.pt(), "today": App.today}


static func sheet() -> Dictionary:
	_hook()
	if not _cache.has("sheet") or str(_cache.get("day", "")) != App.today:
		_cache = {"day": App.today, "sheet": RpgStats.sheet(input())}
	return _cache.sheet


## What a day's training added to the stats: today's, or when today added nothing yet, yesterday's.
## {"day": "today" | "yesterday" | "", "gains": [{"id", "name", "add", "raw"}] the biggest first}. A gain under
## GAIN_MIN is not worth a line.
const GAIN_MIN = 0.1

static func gains() -> Dictionary:
	sheet()
	if not _cache.has("gains"):
		var inp = input()
		var today = str(App.today)
		var y = Dates.add_days(today, -1)
		var pair = RpgStats.scan_pair(inp, y, today)
		var before = RpgStats.raws_of(pair[0])
		var list = gains_between(before, RpgStats.raws_of(pair[1]))
		var day = "today"
		if list.is_empty():
			var older = RpgStats.raws_of(RpgStats.scan(inp, Dates.add_days(today, -2)))
			list = gains_between(older, before)
			day = "yesterday"
		_cache["gains"] = {"day": day if not list.is_empty() else "", "gains": list}
	return _cache.gains


static func gains_between(a: Dictionary, b: Dictionary) -> Array:
	var out = []
	for id in RpgDefs.STATS:
		var add = float(b.get(id, 0.0)) - float(a.get(id, 0.0))
		if add >= GAIN_MIN:
			out.append({"id": str(id), "name": str(RpgDefs.STAT_NAMES[id]), "add": add, "raw": float(b.get(id, 0.0))})
	out.sort_custom(func(p, q): return float(p.add) > float(q.add))
	return out


static func boosts() -> Array:
	sheet()
	if not _cache.has("boosts"):
		_cache["boosts"] = RpgBoosts.active(input())
	return _cache.boosts


## Days with any training (skill points come from them).
static func days() -> int:
	return int(App.state.get("totals", {}).get("activeDays", 0))


static func save() -> Dictionary:
	return App.rpg()


static func commit(rpg: Dictionary) -> void:
	App.set_rpg(rpg)


## Store a note of the Realm's own that changes no screen (nothing is redrawn).
static func commit_quiet(rpg: Dictionary) -> void:
	App.set_rpg(rpg, true)


## Take the result of an RpgSave change ({"ok", "why", "rpg"}): store it when it
## went through, else say why. `good` is toasted on success ("" = nothing).
static func apply(result: Dictionary, good: String = "") -> bool:
	if bool(result.get("ok", false)):
		commit(result.rpg)
		if good != "":
			App.toast(good, "good")
		return true
	var why = str(result.get("why", ""))
	if why != "":
		App.toast(why, "bad")
	return false


static func level() -> int:
	return RpgSave.level_of(save())


static func level_info() -> Dictionary:
	return RpgDefs.level_of(int(save().get("xp", 0)))


## What the player owns in the main game (gear and pets can only be worn when owned).
static func owned() -> Dictionary:
	return {"items": App.state.get("items", {}), "pets": App.state.get("pets", {})}


## The hero as a battle unit, from the sheet, the boosts and the build in use.
static func hero() -> Dictionary:
	return RpgHero.build(sheet(), boosts(), save(), owned())


static func pet():
	return RpgHero.pet_unit(save(), owned(), level())


static func points() -> Dictionary:
	return RpgSkills.points(save(), days())


## What HeroView needs to draw the hero in the Realm gear: the gear of the
## build in use (owned pieces only) and its companion.
static func hero_look() -> Dictionary:
	var b = RpgSave.build_of(save())
	var have = owned()
	var loadout = {}
	for slot in TT.SLOTS:
		var id = b.gear.get(slot)
		if id is String and id != "" and have.items.has(id):
			loadout[slot] = id
	var pet_id = str(b.get("pet", ""))
	return {"state": App.state, "profile": App.saved.get("profile"), "loadout": loadout,
		"pet": pet_id if (pet_id != "" and have.pets.has(pet_id)) else null}


## `what` with what RpgWorld needs to make a hunt or a rival (never stored).
static func _full(what: Dictionary) -> Dictionary:
	var w = {"kind": str(what.get("kind", "")), "id": str(what.get("id", ""))}
	w["boosts"] = boosts()
	w["state"] = App.state
	return w


static func stage_of(what: Dictionary):
	return RpgWorld.stage_of(_full(what), save())


## The battle of today that was left half way (the app was closed in one), or null.
static func kept_battle():
	var d = App.draft_load("battle")
	if d is Dictionary and int(d.get("v", 0)) == RpgDefs.VERSION and d.get("B") is Dictionary and d.get("what") is Dictionary:
		return d
	return null


static func _store(what: Dictionary, B: Dictionary, info = null) -> void:
	var d = {"day": App.today, "v": RpgDefs.VERSION, "what": {"kind": str(what.get("kind", "")), "id": str(what.get("id", ""))}, "B": B}
	if info is Dictionary:
		d["info"] = info
		d["paid_rng"] = int(B.get("rng", 0))
	App.draft_store("battle", d)


## The one place a battle starts. `what` = {"kind": "stage"|"echo"|"hunt"|"rival"|"spire", "id"}.
## Returns the BattleView, or null when there is nothing to fight.
static func fight(what: Dictionary, resume_b = null):
	var st = stage_of(what)
	if not (st is Dictionary):
		App.toast("Nothing to fight there", "bad")
		return null
	var setup = {}
	if not (resume_b is Dictionary):
		var battle_seed = int(Time.get_ticks_usec() % 2000000000) + 1
		setup = RpgWorld.setup(_full(what), save(), hero(), pet(), battle_seed, App.today)
		if setup.is_empty():
			App.toast("Nothing to fight there", "bad")
			return null
	var id = str(st.get("id", ""))
	var first_time = int(save().stages.get(id, {}).get("wins", 0)) == 0
	var nxt = RpgWorld.next_stage(id) if ["battle", "elite", "boss"].has(str(st.get("kind", ""))) else ""
	var opts = {"title": str(st.get("name", "")), "scene": str(st.get("scene", "rustyard")), "tutorial": id == "r1s1" and first_time,
		"hero": hero_look(), "next": nxt != "",
		"store": func(B): RpgUi._store(what, B),
		"result": func(B, summary): return RpgUi.finish(B, what, summary)}
	if resume_b is Dictionary:
		opts["resume"] = resume_b
	var bv = BattleView.open(setup, opts)
	bv.finished.connect(func(_b, _summary): RpgUi._after(bv, what, nxt))
	return bv


## Continue the kept battle (kept_battle() says whether there is one).
static func resume():
	var d = kept_battle()
	if d == null:
		return null
	return fight(d.what, d.B)


## The one place a battle is paid out and stored: called by BattleView when
## the fight is over (also again when a kept battle that was already over is
## opened: then what was shown before is shown again and nothing is paid twice).
## Returns the info BattleResult shows.
static func finish(B: Dictionary, what: Dictionary, summary: Dictionary) -> Dictionary:
	var kept = App.draft_load("battle")
	if kept is Dictionary and kept.get("info") is Dictionary and int(kept.get("paid_rng", -1)) == int(B.get("rng", 0)):
		return kept.info
	var rpg = save()
	var st = stage_of(what)
	var win = RpgBattle.won(B)
	var before = RpgDefs.level_of(int(rpg.get("xp", 0)))
	var rewards = {}
	var stars = null
	var objectives = null
	if st is Dictionary:
		if win:
			rewards = RpgLoot.rewards(st, summary, rpg, int(before.lvl), boosts(), int(B.get("rng", 1)))
			if not st.get("stars", []).is_empty():
				stars = RpgWorld.stars(st, summary)
				objectives = st.stars.map(func(o): return RpgWorld.objective_words(o))
		var res = RpgSave.finish(rpg, {"kind": str(what.get("kind", "")), "id": str(what.get("id", ""))}, st, rewards, summary, App.today)
		if bool(res.get("ok", false)):
			commit(res.rpg)
	var learned = []
	var got = summary.get("learned", {})
	for key in got:
		var foe = RpgFoes.by_id(str(key).split("#")[0])
		for school in got[key]:
			learned.append("%s is weak to %s" % [str(foe.name) if foe != null else "It", str(RpgDefs.SCHOOL_NAMES.get(school, school))])
	var id = str(st.get("id", "")) if st is Dictionary else ""
	var nxt = RpgWorld.next_stage(id) if (st is Dictionary and ["battle", "elite", "boss"].has(str(st.get("kind", "")))) else ""
	var info = {"win": win, "title": str(st.get("name", "")) if st is Dictionary else "", "stars": stars, "objectives": objectives,
		"rewards": rewards if win else null, "level_before": before, "level_after": RpgDefs.level_of(int(save().get("xp", 0))),
		"learned": learned, "next": win and nxt != "" and RpgWorld.is_open(save(), nxt)}
	if not win:
		info["tips"] = tips(B, st, summary)
	_store(what, B, info)
	return info


## What a body stat is to a fighter, in a few words (for a tip after a lost fight).
const STAT_GIVES = {"chest": "your Push moves hit with it", "shoulders": "your Push moves hit with it", "arms": "your Push moves hit with it",
	"back": "your Pull moves hit with it", "legs": "your Legs moves hit with it", "core": "it is your armour and your guard"}
const TIPS_MAX = 4


## After a lost fight: what would help, the most telling first (at most TIPS_MAX lines). It looks at the
## fight (which weaknesses were found and whether the build can hit them, whether a guard or an item was
## used), at the save (skill points left, power against the stage's) and at the log (a boost, the lowest stat).
static func tips(B: Dictionary, st, summary: Dictionary) -> Array:
	var out = []
	var mine = {}
	for id in B.hero.get("moves", []):
		var row = RpgBattle.move_row(B, str(id))
		if row != null:
			mine[str(row.get("school", ""))] = true
	var named = {}
	for f in B.get("foes", []):
		if not (f is Dictionary) or named.has(str(f.get("name", ""))):
			continue
		named[str(f.get("name", ""))] = true
		var kn = RpgBattle.known(B, str(f.get("id", "")))
		var weak = kn.get("weak", []) if kn is Dictionary else []
		var total = f.get("weak", []).size() if f.get("weak") is Array else 0
		if not weak.is_empty():
			var can = false
			for sc in weak:
				if mine.has(str(sc)):
					can = true
			if not can:
				var words = []
				for sc in weak:
					words.append(str(RpgDefs.SCHOOL_NAMES.get(str(sc), str(sc))))
				out.append("%s is weak to %s, and your build has no such move: put one in (Moves)." % [str(f.name), " and ".join(words)])
		elif total > 0 and (bool(f.get("boss", false)) or bool(f.get("elite", false)) or out.is_empty()):
			out.append("You have not found what %s is weak to: a weak hit does more and chips its guard. Try a move of each school." % str(f.name))
	var left = int(points().left)
	if left > 0:
		out.append("You have %d skill point%s to spend: new moves and passives (Skills)." % [left, "" if left == 1 else "s"])
	var rec = float(st.get("rec", 0.0)) if st is Dictionary else 0.0
	var power = RpgHero.power(hero())
	if rec > 0.0 and power < rec * 0.95:
		out.append("Recommended power %s, yours %s: upgrade your gear with ore, learn skills, train." % [Xp.fmt_int(int(round(rec))), Xp.fmt_int(int(round(power)))])
	if int(summary.get("guards", 0)) == 0:
		out.append("You never guarded. When a foe's intent beats red, Guard cuts the hit by half or more and gives %d energy." % RpgDefs.EN_GUARD)
	var belt_left = 0
	for it in B.hero.get("belt", []):
		if it is Dictionary and str(it.get("id", "")) != "":
			belt_left += 1
	if int(summary.get("items", 0)) == 0 and belt_left > 0:
		out.append("Your belt was not touched: an item can turn a fight (Item).")
	if boosts().is_empty():
		out.append("No boost today. A workout gives one for that day and the next.")
	var sh = sheet()
	var low = ""
	for id in RpgDefs.BODY:
		if low == "" or float(sh.stats[id].raw) < float(sh.stats[low].raw):
			low = str(id)
	if low != "" and float(sh.stats[low].raw) < 0.6 * float(sh.get("might", 0.0)):
		out.append("%s is your lowest stat (%d): %s. Train it and it rises; a stat never falls." % [str(sh.stats[low].name), int(sh.stats[low].v), str(STAT_GIVES.get(low, "it carries its moves"))])
	return out.slice(0, TIPS_MAX)


static func _after(bv, what: Dictionary, nxt: String) -> void:
	var choice = str(bv.choice) if is_instance_valid(bv) else "back"
	App.draft_store("battle", null)
	# The hub was drawn again when the fight was paid, while the kept battle was still there: it would go on
	# offering "Continue the battle" for a fight that is over. Now that the draft is gone, it is drawn once more.
	App.rpg_changed.emit()
	match choice:
		"again":
			fight.call_deferred(what)
		"next":
			if nxt != "":
				fight.call_deferred({"kind": str(what.get("kind", "stage")), "id": nxt})


## Today's date as the game has it ("YYYY-MM-DD"): the hunt's day, the chests' days.
static func today() -> String:
	return str(App.today)


# =============================================================================
# Small helpers the four pages share (realm_hero / realm_moves / realm_skills /
# realm_gear), so the pages themselves never touch App.
# =============================================================================

## A toast ("info" | "good" | "bad").
static func say(text: String, kind: String = "info") -> void:
	App.toast(text, kind)


## At least a finger high on a phone (40 px). Returns the control.
static func finger(c: Control) -> Control:
	if Kit.fingers:
		c.custom_minimum_size.y = maxf(c.custom_minimum_size.y, 40.0)
	return c


## A key of a page. `anchor` names it across rebuilds whatever its text says by
## then (UiScreen keeps the tapped key under the finger).
static func page_key(text: String, variant: String, on_press: Callable, anchor: String = "", size: String = "sm", icon: String = "") -> Button:
	var b = Kit.button(text, variant, on_press, size, icon)
	if anchor != "":
		b.set_meta("anchor_id", anchor)
	finger(b)
	return b


## The one line an empty part of a page explains itself with (meta "realm_empty" = id).
static func page_note(id: String, text: String) -> Label:
	var l = Kit.muted_para(text, 13)
	l.set_meta("realm_empty", id)
	return l


## A slot that is not open yet: a dim row with a lock and when it opens (meta "realm_locked").
static func lock_row(text: String) -> Card:
	var r = Kit.row(Callable(), Pal.LINE, null, 8, 4)
	var h = Kit.hbox(8)
	h.add_child(Kit.vcenter(Icons.rect("lock", 16)))
	h.add_child(Kit.vcenter(Kit.clip(text, 13, Pal.MUTED)))
	r.add(h)
	r.modulate = Color(1, 1, 1, 0.75)
	r.set_meta("realm_locked", true)
	return r
