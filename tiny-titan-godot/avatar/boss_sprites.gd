class_name BossSprites
extends RefCounted
## Campaign bosses (port of avatar/bossSprites.ts): nine hand-pixelled base
## sprites, re-coloured per boss.
##
## Look: {sprite: key of BASE, palette: {char: "#rrggbb"}, hover?: true}
## (hover = floats above the ground).

const K = "#1a1026" # = Pix.OUTLINE

const BASE = {
	"clock": [
		"..rr......rr..",
		".rrrr....rrrr.",
		"..rrwwwwwwrr..",
		"..rwwwwwwwwr..",
		".rwwkwwwwkwwr.",
		".rwwkwwwwkwwr.",
		".rwwwwyywwwwr.",
		".rwwwwywwwwwr.",
		".rwwkkkkkkwwr.",
		"..rwwwwwwwwr..",
		"..rrwwwwwwrr..",
		"...rrrrrrrr...",
		"..rr......rr..",
		".rr........rr.",
	],
	"blob": [
		"....bbbbbb....",
		"..bbbbbbbbbb..",
		".bbbdbbbbbbbb.",
		".bbbbbbbbbdbb.",
		"bbkkkbbbbkkkbb",
		"bbbbbbbbbbbbbb",
		"bbbbbbmmbbbbbb",
		"bbdbbbbbbbbbbb",
		".bbbbbbbbbbdb.",
		".bbbbbbbbbbbb.",
		"ssssssssssssss",
		"ssssssssssssss",
	],
	"imp": [
		".h..........h.",
		".hh........hh.",
		"..iiiiiiiiii..",
		".iiiiiiiiiiii.",
		".iiweiiiiweii.",
		".iiweiiiiweii.",
		".iiiiiiiiiiii.",
		".iikiiiiiikii.",
		"..iikkkkkkii..",
		"...iiiiiiii...",
		"..iiiiiiiiii..",
		".ii.iiiiii.ii.",
		".i..ii..ii..i.",
		"....ii..ii....",
	],
	"golem": [
		"....gggggg....",
		"...gggggggg...",
		"...geeggeeg...",
		"...gggggggg...",
		".gggggggggggg.",
		"gggdggggggdggg",
		"ggg.gggggg.ggg",
		"ggg.gdggdg.ggg",
		"ggg.gggggg.ggg",
		"gg..gggggg..gg",
		"gg..ggg.ggg.gg",
		"....ggg.ggg...",
		"....ggg.ggg...",
		"...gggg.gggg..",
	],
	"wraith": [
		"....wwwwww....",
		"..wwwwwwwwww..",
		".wwwwwwwwwwww.",
		".wwkkwwwwkkww.",
		".wwkkwwwwkkww.",
		".wwwwwwwwwwww.",
		".wwwwkkkkwwww.",
		".wwwwwwwwwwww.",
		".wwwwwwwwwwww.",
		".wwwwwwwwwww..",
		".ww.www.www...",
		".w...ww..ww...",
		"......w...w...",
	],
	"wyvern": [
		"d............d",
		"dd....vv....dd",
		"ddd..vvvv..ddd",
		".dddvevvevddd.",
		"..ddvvvvvvdd..",
		"...vvvkkvvv...",
		"...vvvvvvvv...",
		"..vvvbbbbvvv..",
		"..vvbbbbbbvv..",
		"..vvbbbbbbvv..",
		"...vvbbbbvv.vv",
		"...vv....vv..v",
		"..vvv....vvv..",
	],
	"mountain": [
		"......ss......",
		".....ssss.....",
		"....ssssss....",
		"...mmssssmm...",
		"...mmmmmmmm...",
		"..mmkmmmmkmm..",
		"..mmkmmmmkmm..",
		".mmmmmmmmmmmm.",
		".mmmmkkkkmmmm.",
		"mmmmmmmmmmmmmm",
		"mmrmmmmmmmmrmm",
		"mmmrrmmmmrrmmm",
		"mmmmmrrrrmmmmm",
	],
	"shadow": [
		".....kkkk.....",
		"....kkkkkk....",
		"....kekkek....",
		"....kkkkkk....",
		".....kkkk.....",
		"......kk......",
		"....kkkkkk....",
		"...kkkkkkkk...",
		"...k.kkkk.k...",
		"...k.kkkk.k...",
		"...k.kkkk.k...",
		".....kkkk.....",
		".....k..k.....",
		".....k..k.....",
		"....kk..kk....",
	],
	"wheel": [
		"....tttttt....",
		"..tttttttttt..",
		".tttggggggttt.",
		".ttggggggggtt.",
		"ttggkkggkkggtt",
		"ttggkkggkkggtt",
		"ttggggggggggtt",
		"ttggkggggkggtt",
		"ttgggkkkkgggtt",
		".ttggggggggtt.",
		".tttggggggttt.",
		"..tttttttttt..",
		"....tttttt....",
	],
}

const ECHO_LOOK = {"sprite": "shadow", "palette": {"k": "#3a3a52", "e": "#7fe7ff"}}

static var _looks = null


static func _imp(horn: String, body: String) -> Dictionary:
	return {"sprite": "imp", "palette": {"h": horn, "i": body, "w": "#ffffff", "e": K, "k": K}}


static func _wraith(body: String, dark: String) -> Dictionary:
	return {"sprite": "wraith", "palette": {"w": body, "k": dark}, "hover": true}


static func _golem(body: String, seam: String, eye: String) -> Dictionary:
	return {"sprite": "golem", "palette": {"g": body, "d": seam, "e": eye}}


static func _blob(body: String, spot: String, mouth: String, base: String) -> Dictionary:
	return {"sprite": "blob", "palette": {"b": body, "d": spot, "k": K, "m": mouth, "s": base}}


## TS `BOSS_LOOK`: boss id -> Look, built once.
static func boss_looks() -> Dictionary:
	if _looks == null:
		_looks = {
			"snooze_button": {"sprite": "clock", "palette": {"r": "#e53935", "w": "#fff8e1", "k": K, "y": "#37474f"}},
			"couch_potato": _blob("#c9a36a", "#a07d48", "#5d4037", "#7e57c2"),
			"elevator_imp": _imp("#cfd8dc", "#5c9ded"),
			"sunday_scaries": _wraith("#5c6bc0", "#0d0a1a"),
			"rust_mite": _imp("#8d6e63", "#bf5b17"),
			"ego_imp": _imp("#ffd54f", "#e53935"),
			"doms_demon": _wraith("#d84343", "#1a0505"),
			"iron_golem": _golem("#90a4ae", "#546e7a", "#ff5252"),
			"greasy_sloper": _blob("#78909c", "#546e7a", "#263238", "#546e7a"),
			"pump_wraith": _wraith("#26a69a", "#04201d"),
			"gravity_gremlin": _imp("#ce93d8", "#8e24aa"),
			"crux_wyvern": {"sprite": "wyvern", "palette": {"d": "#2e7d32", "v": "#43a047", "e": "#ffeb3b", "k": K, "b": "#c5e1a5"}, "hover": true},
			"side_stitch": _imp("#ffab91", "#ec407a"),
			"blister_blob": _blob("#ef9a9a", "#e57373", "#b71c1c", "#e57373"),
			"headwind_wraith": _wraith("#b3e5fc", "#0d2a3a"),
			"the_wall": _golem("#a1543a", "#6d3524", "#ffeb3b"),
			"pothole_pixie": _imp("#bdbdbd", "#757575"),
			"flat_tire_fiend": {"sprite": "wheel", "palette": {"t": "#263238", "g": "#9e9e9e", "k": K}},
			"bonk_beast": _blob("#fff3e0", "#ffe0b2", "#8d6e63", "#ffe0b2"),
			"col_du_doom": {"sprite": "mountain", "palette": {"s": "#ffffff", "m": "#6d4c41", "k": K, "r": "#ffca28"}},
			"plateau_giant": _golem("#d4a017", "#9a7410", "#ffffff"),
			"excuse_hydra": {"sprite": "wyvern", "palette": {"d": "#00695c", "v": "#00897b", "e": "#ff5252", "k": K, "b": "#b2dfdb"}, "hover": true},
			"comparison_specter": _wraith("#ba68c8", "#1f0a29"),
			"old_you": {"sprite": "shadow", "palette": {"k": "#2a1f4a", "e": "#ff5252"}},
		}
	return _looks


## The look of a boss; unknown ids (the endless "echo_N" bosses) get the echo look.
static func boss_look(id: String) -> Dictionary:
	var look = boss_looks().get(id)
	if look == null:
		return ECHO_LOOK
	return look


## Render a boss into a tight, outlined buffer. `opts` is {silhouette?: bool}:
## an unknown boss is drawn as a dark silhouette.
static func boss_buffer(id: String, opts: Dictionary = {}) -> Pix:
	var look: Dictionary = boss_look(id)
	var rows: Array = BASE[look.sprite]
	var bw: int = 0
	for r in rows:
		bw = maxi(bw, r.length())
	var buf: Pix = Pix.new(bw + 2, rows.size() + 2)
	var silhouette: bool = opts.get("silhouette", false)
	var palette: Dictionary = look.palette
	if silhouette:
		palette = {}
		for k in look.palette:
			palette[k] = "#0d0a1a"
	buf.sprite(1, 1, rows, palette)
	buf.outline("#241c40" if silhouette else Pix.OUTLINE)
	return buf
