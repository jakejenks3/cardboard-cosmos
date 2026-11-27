extends SceneTree
## Unit test for the icons the Realm adds (RpgDefs.ICONS, drawn in ui/icons.gd):
## every name is there and well formed, none is empty or a filled square, no two
## icons of the whole set are the same picture, and the 86 icons the game had
## before are untouched (a fingerprint of each, taken before the Realm's were
## added).
##   godot --headless --path . --script res://tests/rpg_icons_test.gd
## Prints RPG ICONS: X/Y passed and exits with 1 when anything fails.
##
## It also saves contact sheets (every icon at x4, x2 and x1 on a dark and on a
## light panel, group by group) as PNG, for a person to look at: into the
## folder TINY_TITAN_SHOTS names, else the one TINY_TITAN_DATA names. With
## neither set nothing is saved (never into the project or the real save).

var passed = 0
var total = 0

## The game's icons before the Realm: name -> fingerprint (see `_print_of`).
const OLD = {
	"lift": "237f1635b9c3", "climb": "05255f416d87", "run": "039c5f2af83c", "ride": "620109cdb8f3", "home": "afc210e1722f",
	"adventure": "5cf09e68a28a", "log": "82792437215f", "journey": "d448faee8d6f", "armory": "0e07cbe4359d", "settings": "56e327aa8f29",
	"close": "a1b7ccdab36d", "check": "8881983d14a9", "plus": "a6545c87c6b0", "minus": "7bc05f6dcd76", "chevron_right": "77adba2f549c",
	"chevron_left": "c1057d951a2a", "chevron_down": "0cb5426729b1", "chevron_up": "22ab0928cf86", "arrow_up": "7d231e8576e3",
	"arrow_down": "7b32eea39a41", "arrow_left": "cf7240198251", "arrow_right": "9593561b842d", "edit": "d2aa9e2ebe2a", "trash": "bd3b611ab5c0",
	"repeat": "4823c2c9b75e", "info": "e3808c29815b", "warning": "c68b731761a8", "question": "d33883cca097", "lock": "51db981830ec",
	"unlock": "5634c3dba556", "sound_on": "1225c656a7e4", "sound_off": "bf9c78686764", "camera": "639eb0ac4830", "calendar": "efb69bf0a662",
	"clock": "66a24777d553", "search": "6c55a792d053", "speech": "06331c154605", "flame": "dac8c133f9a5", "ember": "dc76444fc5df",
	"heart": "a5b3bfb2b2eb", "pt": "3a474470bdee", "star": "19e7c13831a6", "sparkle": "c7cb91e8f2ff", "bolt": "e6ec51778a30",
	"trophy": "f0febe18d68f", "medal": "0d66b3771f14", "crown": "58e886994058", "quest": "1fc6c197244f", "chest": "77698d1cb9b2",
	"gift": "2d3f298373f4", "skull": "94c57384f592", "sword": "b763fd6a61f8", "shield": "7ea3d3111c88", "paw": "64f6ee5d81f1",
	"gem": "90c0c373f32a", "target": "64952d8c174b", "muscle": "e2abddacb530", "potion": "2d47e16b1258", "book": "831d0df9aee2",
	"map": "0df53aca6541", "scale": "4566a5dc0397", "ruler": "7b52c6794521", "body": "e0e515e2d50c", "photo": "f3b3be01ebe8",
	"mountain": "e608ad4ee0f1", "road": "3eb7bd73eaf1", "globe": "b1e58542cff3", "rocket": "11c693358e0a", "sun": "de7be32f30b6",
	"moon": "d3c2c12e03b9", "wave": "5e1dcb71c5b9", "tree": "0e0887bdee40", "elephant": "011121aa1494", "wheel": "243e0851b3f1",
	"stopwatch": "d1be0f2507d5", "dice": "d8c71977f939", "robot": "0b815aa49a87", "couch": "d6c916e0fa78", "plate": "7bc441a2d3ac",
	"rock": "f654a4a480a0", "abacus": "6f17f347336e", "wind": "f52f83383f43", "coin": "7991c46a22ed", "bag": "8ff84df9265b",
	"misc": "4ce6e94984f5", "vest": "ee82392ca6cd",
}

## The contact sheets: [file name, [icon names]].
const SHEETS = [
	["icons_schools_stats", ["sch_push", "sch_pull", "sch_legs", "sch_speed", "sch_grip", "sch_mind", "sch_flow", "sch_grit",
		"st_chest", "st_shoulders", "st_arms", "st_back", "st_core", "st_legs", "st_endurance"]],
	["icons_statuses", ["fx_pumped", "fx_weakened", "fx_braced", "fx_exposed", "fx_hasted", "fx_slowed", "fx_burn", "fx_bleed", "fx_stun",
		"fx_regen", "fx_shield", "fx_focus", "fx_evade", "fx_counter", "fx_steady", "fx_marked", "fx_insight", "fx_broken"]],
	["icons_intents", ["in_attack", "in_heavy", "in_multi", "in_debuff", "in_buff", "in_heal", "in_shield", "in_summon", "in_bomb",
		"in_stunned", "in_drain", "in_charge"]],
	["icons_keys", ["realm", "ore", "energy", "gauge", "guard_pip", "power", "sp", "strike", "guard", "flee", "belt", "relic", "rune",
		"scroll", "hunt", "spire", "rival", "chest_wood", "chest_iron", "chest_gold", "star_on", "star_off", "music", "music_off"]],
	["icons_items_relics", ["it_shake", "it_mega", "it_electro", "it_salts", "it_chalk", "it_gel", "it_ice", "it_pre",
		"rl_ring", "rl_bookmark", "rl_chain", "rl_tooth", "rl_band", "rl_whistle", "rl_tape", "rl_feather", "rl_bell", "rl_hourglass",
		"rl_horn", "rl_anvil"]],
]

## The two panels a sheet shows the icons on (a test picture, not a screen).
const DARK = Color("27386f")
const LIGHT = Color("e9e4f5")
const PER_ROW = 8


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## What an icon is, in a few characters: its rows and its palette.
func _print_of(d: Dictionary) -> String:
	var keys = d.pal.keys()
	keys.sort()
	var s = "\n".join(d.rows) + "|"
	for k in keys:
		s += "%s=%s," % [k, str(d.pal[k]).to_lower()]
	return s.md5_text().left(12)


## Where an icon has anything at all, as one string: its silhouette.
func _outline_of(d: Dictionary) -> String:
	var sil = ""
	for row in d.rows:
		for ch in str(row):
			sil += "." if ch == "." else "#"
	return sil


## The icon as pixels, straight from its rows (the way Icons.tex paints it).
func _image(name: String) -> Image:
	var d = Icons.DATA[name]
	var img = Image.create_empty(Icons.SIZE, Icons.SIZE, false, Image.FORMAT_RGBA8)
	for y in range(Icons.SIZE):
		var row: String = d.rows[y]
		for x in range(Icons.SIZE):
			var ch = row[x]
			if ch == ".":
				continue
			img.set_pixel(x, y, Icons.OUTLINE if ch == "o" else Color.html(d.pal[ch]))
	return img


func _init() -> void:
	var names: Array = RpgDefs.ICONS
	ok(names.size() == 89, "the Realm names 89 icons", names.size())

	# --- every name is there, 16 rows of 16, only letters of its palette ------
	var missing = []
	var shape = []
	var letters = []
	var unused = []
	var blank = []
	var full = []
	var colours = []
	var good = []
	for n in names:
		if not Icons.has_icon(n):
			missing.append(n)
			continue
		var d = Icons.DATA[n]
		if not (d.get("rows") is Array) or not (d.get("pal") is Dictionary) or d.rows.size() != Icons.SIZE:
			shape.append(n)
			continue
		var fine = true
		var used = {}
		var filled = 0
		for row in d.rows:
			if not (row is String) or row.length() != Icons.SIZE:
				fine = false
				break
			for ch in row:
				if ch == ".":
					continue
				filled += 1
				if ch != "o":
					used[ch] = true
					if not d.pal.has(ch):
						letters.append("%s:%s" % [n, ch])
		if not fine:
			shape.append(n)
			continue
		for k in d.pal:
			if not used.has(k):
				unused.append("%s:%s" % [n, k])
			if not (d.pal[k] is String) or not Color.html_is_valid(d.pal[k]):
				colours.append("%s:%s" % [n, k])
		# nothing at all, nothing but an outline, or a square with no shape
		if filled < 24 or used.is_empty():
			blank.append(n)
		if filled > Icons.SIZE * Icons.SIZE - 16:
			full.append(n)
		good.append(n)
	ok(missing.is_empty(), "every icon of RpgDefs.ICONS is drawn", missing)
	ok(shape.is_empty(), "every icon is 16 rows of 16 characters", shape)
	ok(letters.is_empty(), "every letter of an icon is in its palette", letters)
	ok(unused.is_empty(), "no palette holds a colour its icon never uses", unused)
	ok(colours.is_empty(), "every palette colour is a colour", colours)
	ok(blank.is_empty(), "no icon is empty", blank)
	ok(full.is_empty(), "no icon fills the whole square", full)

	# --- an outline all round: no colour on the canvas edge without one -------
	var bare = []
	for n in good:
		var rows: Array = Icons.DATA[n].rows
		var open_px = 0
		for y in range(Icons.SIZE):
			for x in range(Icons.SIZE):
				var ch = rows[y][x]
				if ch == "." or ch == "o":
					continue
				for dd in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = x + dd[0]
					var ny: int = y + dd[1]
					if nx < 0 or ny < 0 or nx >= Icons.SIZE or ny >= Icons.SIZE or rows[ny][nx] == ".":
						open_px += 1
						break
		if open_px > 0:
			bare.append("%s:%d" % [n, open_px])
	ok(bare.is_empty(), "every coloured pixel sits inside the dark outline", bare)

	# --- more than one shade, so a tinted icon keeps its form ------------------
	var flat = []
	for n in good:
		if Icons.DATA[n].pal.size() < 2:
			flat.append(n)
	ok(flat.is_empty(), "every icon has light and shade (two colours or more)", flat)

	# --- no two icons of the whole set are the same picture --------------------
	var seen = {}
	var twins = []
	var same_shape = {}
	var shape_twins = []
	for n in Icons.names():
		var d = Icons.DATA[n]
		if not (d.get("rows") is Array) or d.rows.size() != Icons.SIZE:
			continue
		var key = _print_of(d)
		if seen.has(key):
			twins.append("%s = %s" % [n, seen[key]])
		seen[key] = n
		# the silhouette alone (what is left when an icon is tinted flat); the
		# game's older round icons share theirs with each other, so only a pair
		# with one of the Realm's in it counts
		var sil = _outline_of(d)
		if same_shape.has(sil) and (names.has(n) or names.has(same_shape[sil])):
			shape_twins.append("%s ~ %s" % [n, same_shape[sil]])
		same_shape[sil] = n
	ok(twins.is_empty(), "no two icons are identical", twins)
	# The two stars are a pair on purpose (lit and unlit); everything else the
	# Realm adds has an outline of its own.
	var odd = shape_twins.filter(func(t): return not str(t).begins_with("star_o"))
	ok(odd.is_empty(), "no icon of the Realm shares its silhouette with another icon (the two stars aside)", odd)
	var schools = {}
	for n in RpgDefs.SCHOOL_ICONS.values():
		if Icons.has_icon(n):
			schools[_outline_of(Icons.DATA[n])] = n
	ok(schools.size() == RpgDefs.SCHOOL_ICONS.size(), "the eight schools and Strike differ in shape, not only in colour", schools.values())

	# --- the names the catalogs point at exist ---------------------------------
	var pointed = []
	for n in RpgDefs.STAT_ICONS.values() + RpgDefs.SCHOOL_ICONS.values():
		if not Icons.has_icon(n):
			pointed.append(n)
	for id in RpgDefs.STATUS:
		if not Icons.has_icon(RpgDefs.STATUS[id].icon):
			pointed.append(RpgDefs.STATUS[id].icon)
	ok(pointed.is_empty(), "every stat, school and status has its icon", pointed)

	# --- a row of statuses reads at once: buffs green, blue or gold; debuffs red or purple ---
	var wrong_lean = []
	var leans = {"fx_broken": "debuff"}
	for id in RpgDefs.STATUS:
		leans[str(RpgDefs.STATUS[id].icon)] = str(RpgDefs.STATUS[id].kind)
	for n in leans:
		if not good.has(n):
			continue
		var d = Icons.DATA[n]
		var kind_px = 0
		var harsh_px = 0
		for row in d.rows:
			for ch in str(row):
				if ch == "." or ch == "o":
					continue
				var c = Color.html(d.pal[ch])
				if c.s < 0.25:
					continue
				# yellow through green to blue is kind; orange, red and purple are harsh
				var hue: float = c.h * 360.0
				if hue >= 36.0 and hue < 250.0:
					kind_px += 1
				else:
					harsh_px += 1
		if (kind_px > harsh_px) != (leans[n] == "buff"):
			wrong_lean.append("%s (%s): %d kind, %d harsh" % [n, leans[n], kind_px, harsh_px])
	ok(leans.size() == RpgDefs.STATUS.size() + 1 and wrong_lean.is_empty(), "a buff's icon is green, blue or gold; a debuff's red or purple", wrong_lean)

	# --- the game's own icons are as they were ---------------------------------
	var gone = []
	var changed = []
	for n in OLD:
		if not Icons.has_icon(n):
			gone.append(n)
		elif _print_of(Icons.DATA[n]) != OLD[n]:
			changed.append(n)
	ok(OLD.size() == 86 and gone.is_empty(), "the 86 icons the game had are all still there", gone)
	ok(changed.is_empty(), "none of them changed", changed)
	var extra = Icons.names().filter(func(n): return not OLD.has(n) and not names.has(n))
	ok(extra.is_empty() and Icons.names().size() == OLD.size() + names.size(), "the set is the old icons and the Realm's, nothing else", [Icons.names().size(), extra])
	var clash = names.filter(func(n): return OLD.has(n))
	ok(clash.is_empty(), "no new icon took an old name", clash)

	# --- Icons draws each one: a texture, tinted too, and at twice the size ----
	var undrawn = []
	for n in good:
		var t = Icons.tex(n)
		if t == null or t.get_width() != Icons.SIZE or t.get_height() != Icons.SIZE:
			undrawn.append(n)
			continue
		# (compared before the doubled one is asked for: without a screen a
		# texture hands out its own picture, and doubling would resize it)
		var got = t.get_image()
		if got != null and not got.is_empty() and got.get_data() != _image(n).get_data():
			undrawn.append(n + " (pixels)")
		var tinted = Icons.tex(n, Color(0.3, 0.8, 0.5))
		var big = Icons.tex(n, null, 2)
		if tinted == null or big == null or tinted.get_width() != Icons.SIZE or big.get_width() != Icons.SIZE * 2 or big.get_height() != Icons.SIZE * 2:
			undrawn.append(n + " (tinted, doubled)")
	ok(undrawn.is_empty(), "Icons.tex draws every one of them, plain, tinted and doubled", undrawn)
	var stand_in = Icons.tex("no_such_icon")
	ok(stand_in != null and stand_in.get_width() == Icons.SIZE, "an unknown name still gives a picture (the star)")

	# --- contact sheets, to look at ---------------------------------------------
	var dir = OS.get_environment("TINY_TITAN_SHOTS")
	if dir == "":
		dir = OS.get_environment("TINY_TITAN_DATA")
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
		var saved = []
		for sheet in SHEETS:
			var list: Array = sheet[1].filter(func(n): return good.has(n))
			if list.is_empty():
				continue
			var path = dir.path_join(str(sheet[0]) + ".png")
			if _sheet(list).save_png(path) == OK:
				saved.append(path)
		var listed = {}
		for sheet in SHEETS:
			for n in sheet[1]:
				listed[n] = true
		ok(saved.size() == SHEETS.size() and listed.size() == names.size() and names.all(func(n): return listed.has(n)), "every icon is on a contact sheet", saved.size())
		for path in saved:
			print("sheet  " + path)

	print("RPG ICONS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


## One sheet: the icons at x4 in rows, then all of them at x2 and at x1, on the
## dark panel (top half) and again on the light one.
func _sheet(list: Array) -> Image:
	var cell = Icons.SIZE * 4 + 12
	var rows = int(ceil(list.size() / float(PER_ROW)))
	var strip = Icons.SIZE * 2 + 10 + Icons.SIZE + 14
	var half_h = rows * cell + strip + 8
	var w = maxi(PER_ROW * cell + 8, list.size() * (Icons.SIZE * 2 + 6) + 14)
	var img = Image.create_empty(w, half_h * 2, false, Image.FORMAT_RGBA8)
	for half in range(2):
		var top = half * half_h
		img.fill_rect(Rect2i(0, top, w, half_h), DARK if half == 0 else LIGHT)
		for k in range(list.size()):
			var src = _image(list[k])
			var big = src.duplicate()
			big.resize(Icons.SIZE * 4, Icons.SIZE * 4, Image.INTERPOLATE_NEAREST)
			var bx = 8 + (k % PER_ROW) * cell
			var by = top + 8 + int(k / float(PER_ROW)) * cell
			img.blend_rect(big, Rect2i(0, 0, Icons.SIZE * 4, Icons.SIZE * 4), Vector2i(bx, by))
			var mid = src.duplicate()
			mid.resize(Icons.SIZE * 2, Icons.SIZE * 2, Image.INTERPOLATE_NEAREST)
			var sy = top + 8 + rows * cell
			img.blend_rect(mid, Rect2i(0, 0, Icons.SIZE * 2, Icons.SIZE * 2), Vector2i(8 + k * (Icons.SIZE * 2 + 6), sy))
			img.blend_rect(src, Rect2i(0, 0, Icons.SIZE, Icons.SIZE), Vector2i(8 + k * (Icons.SIZE * 2 + 6), sy + Icons.SIZE * 2 + 10))
	return img
