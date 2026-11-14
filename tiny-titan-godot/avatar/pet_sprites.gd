class_name PetSprites
extends RefCounted
## Hand-pixelled companions (port of avatar/petSprites.ts). Sprites are
## bottom-anchored; '.' is transparent.
##
## PetSprite: {palette: {char: "#rrggbb"}, frames: [rows, rows], fly?: true}.
## Hovering pets (`fly`) float above the ground and bob.

const EYE = "#1a1026" # = Pix.OUTLINE

const PET_SPRITES = {
	"slime": {
		"palette": {"g": "#6fe36f", "d": "#2f7a3a", "e": EYE, "h": "#d4ffd4", "m": "#2f7a3a"},
		"frames": [
			[
				"...gggg...",
				".ghgggggg.",
				"gggegggegg",
				"gggggggggg",
				"ggggmmgggg",
				".gggggggg.",
				"gggggggggg",
			],
			[
				"..........",
				"..ghgggg..",
				".gggegggeg",
				"gggggggggg",
				"ggggmmmggg",
				"gggggggggg",
				"gggggggggg",
			],
		],
	},
	"bulldog": {
		"palette": {"b": "#c9a07a", "d": "#8f6a4a", "e": EYE, "n": "#3a2a22", "w": "#f1e3d3", "t": "#8f6a4a"},
		"frames": [
			[
				".dd....dd...",
				".bbbbbbbb...",
				"bbebbbbebb..",
				"bbbbbnnbbb..",
				"bwwbbbbbbbb.",
				"bwwbbbbbbbbt",
				"bbbbbbbbbbb.",
				".bb..bb.bb..",
				".bb..bb.bb..",
			],
			[
				".dd....dd...",
				".bbbbbbbb...",
				"bbebbbbebb..",
				"bbbbbnnbbb.t",
				"bwwbbbbbbbb.",
				"bwwbbbbbbbb.",
				"bbbbbbbbbbb.",
				".bb..bb.bb..",
				".bb..bb.bb..",
			],
		],
	},
	"gecko": {
		"palette": {"g": "#7cd957", "d": "#4e9a36", "e": EYE, "s": "#ffe082"},
		"frames": [
			[
				"....gggg.......",
				"...gegggg......",
				"..ggggggggggg..",
				"...gsggsggggggg",
				"..g.gg..gg.g.gg",
			],
			[
				"....gggg.......",
				"...gegggg......",
				"..gggggggggggg.",
				"...gsggsgggggg.",
				"..g.gg..gg.g..g",
			],
		],
	},
	"pigeon": {
		"palette": {"p": "#8e9bb0", "d": "#5f6a7d", "e": EYE, "o": "#ff9800", "w": "#b9c3d3", "i": "#6cc09b"},
		"frames": [
			[
				"..pp....",
				".pepp...",
				".pppo...",
				"..iip...",
				".pppppp.",
				"pwwpppppp",
				"pwwppppp.",
				".pppppp..",
				"..o..o...",
			],
			[
				"..pp....",
				".pepp...",
				".pppo...",
				"..iip...",
				".pppppp.",
				"pwwpppppp",
				"pwwppppp.",
				".pppppp..",
				".o....o..",
			],
		],
	},
	"hamster": {
		"palette": {"h": "#f2b56b", "d": "#c98a44", "e": EYE, "n": "#ff8a80", "c": "#ffcdd2", "w": "#fff3e0"},
		"frames": [
			[
				".d.....d.",
				".hhhhhhh.",
				"hhehhhehh",
				"hhhhnhhhh",
				"hcchhhcch",
				"hhwwwwwhh",
				"hhhwwwhhh",
				".hh...hh.",
			],
			[
				".d.....d.",
				".hhhhhhh.",
				"hhehhhehh",
				"hhhhnhhhh",
				"hcchhhcch",
				"hhwwwwwhh",
				"hhhwwwhhh",
				".hh...hh.",
			],
		],
	},
	"sprout": {
		"palette": {"g": "#66bb6a", "d": "#388e3c", "p": "#b5651d", "r": "#d2843b", "e": EYE, "c": "#ffab91"},
		"frames": [
			[
				"..gg...gg.",
				".ggg.gggg.",
				"..ggdgdg..",
				"....ggg...",
				".....d....",
				".rrrrrrrrr",
				"..pepppep.",
				"..pppcppp.",
				"...ppppp..",
			],
			[
				".gg.....gg",
				".ggg.gggg.",
				"..ggdgdg..",
				"....ggg...",
				".....d....",
				".rrrrrrrrr",
				"..pepppep.",
				"..pppcppp.",
				"...ppppp..",
			],
		],
	},
	"golemling": {
		"palette": {"g": "#90a4ae", "d": "#546e7a", "e": "#ff5252", "l": "#cfd8dc"},
		"frames": [
			[
				"..gggggg..",
				".gglggggg.",
				".geeggeeg.",
				".gggggggg.",
				"ggggddgggg",
				"gg.gggg.gg",
				"gg.gggg.gg",
				"...gg.gg..",
				"..ggg.ggg.",
			],
			[
				"..gggggg..",
				".gglggggg.",
				".geeggeeg.",
				"gggggggggg",
				"gg.gddg.gg",
				"...gggg...",
				"...gggg...",
				"...gg.gg..",
				"..ggg.ggg.",
			],
		],
	},
	"ox": {
		"palette": {"b": "#7a4b2a", "d": "#56331b", "e": EYE, "n": "#e8a3a3", "w": "#f3e9d2", "r": "#d9b04c"},
		"frames": [
			[
				"w....bbbb....w",
				"ww..bbbbbb..ww",
				".wbbbbbbbbbbw.",
				"..bbebbbbebb..",
				"..bbbbbbbbbb..",
				"..bbnnnnnnbb..",
				"...bnrrrrnb...",
				"bbbbbbbbbbbbbb",
				"bbbbbbbbbbbbbb",
				"bbbddbbbbddbbb",
				".bb..bb..bb.bb",
			],
			[
				"w....bbbb....w",
				"ww..bbbbbb..ww",
				".wbbbbbbbbbbw.",
				"..bbebbbbebb..",
				"..bbbbbbbbbb..",
				"..bbnnnnnnbb..",
				"...bnrrrrnb...",
				"bbbbbbbbbbbbbb",
				"bbbbbbbbbbbbbb",
				"bbbddbbbbddbbb",
				".bb..bb..bb.bb",
			],
		],
	},
	"goat": {
		"palette": {"g": "#e9e4d8", "d": "#b9b2a3", "h": "#6d6256", "e": EYE, "n": "#8d8378", "b": "#cfc8b8"},
		"frames": [
			[
				".h........h.",
				".hh..gg..hh.",
				"..gggggggg..",
				"..ggeggeggg.",
				"..gggggggggn",
				"...ggggggg..",
				"....bb......",
				"gggggggggggg",
				"gggggggggggg",
				"dgg.ggg.gg.d",
				".gg..gg.gg..",
			],
			[
				".h........h.",
				".hh..gg..hh.",
				"..gggggggg..",
				"..ggeggeggg.",
				"..gggggggggn",
				"...ggggggg..",
				"....bb......",
				"gggggggggggg",
				"gggggggggggg",
				"dgg.ggg.gg.d",
				".gg.gg...gg.",
			],
		],
	},
	"greyhound": {
		"palette": {"g": "#9aa5b5", "d": "#6c7788", "e": EYE, "w": "#e6ebf2", "n": "#2b2b2b", "c": "#d9534f"},
		"frames": [
			[
				"............gg.",
				"...........gegn",
				"...........ggg.",
				"..ggggggggggg..",
				".gggggggggggg..",
				"ggwwgggggggg...",
				"d.gg.gg..gg.g..",
				"d.gg.gg..gg.gg.",
			],
			[
				"............gg.",
				"...........gegn",
				"...........ggg.",
				"..ggggggggggg..",
				".gggggggggggg..",
				"ggwwgggggggg...",
				".dgg..gg.gg.g..",
				".dgg.gg...gg.g.",
			],
		],
	},
	"falcon": {
		"fly": true,
		"palette": {"f": "#8d6e63", "d": "#5d4037", "e": EYE, "w": "#ffe0b2", "y": "#ffb300"},
		"frames": [
			[
				"d..........d",
				"dd...ff...dd",
				".ddd.fef.ddd",
				"..ddffffydd.",
				"...dfwwfd...",
				"....fwwf....",
				"....ffff....",
				".....yy.....",
			],
			[
				"............",
				".....ff.....",
				".....fef....",
				"..ddffffydd.",
				"ddddfwwfdddd",
				"d...fwwf...d",
				"....ffff....",
				".....yy.....",
			],
		],
	},
	"tortoise": {
		"palette": {"s": "#4e8d3a", "d": "#2f6a27", "g": "#8bc34a", "e": EYE, "b": "#c5e1a5", "h": "#7cb342"},
		"frames": [
			[
				"...ssssss....",
				"..sdssdssds..",
				".sssdssdsss..",
				".sdssdssdssh.",
				"ssssssssssshe",
				".bbbbbbbbbbh.",
				".gg..gg..gg..",
			],
			[
				"...ssssss....",
				"..sdssdssds..",
				".sssdssdsss..",
				".sdssdssdss..",
				"ssssssssssshh",
				".bbbbbbbbbbhe",
				".gg..gg..gg..",
			],
		],
	},
	"cat": {
		"palette": {"c": "#f3a24f", "d": "#c97a2a", "e": "#3fbf5f", "w": "#fff3e0", "n": "#ff8a80", "k": EYE},
		"frames": [
			[
				".c....c....",
				".cc..cc....",
				".ccccccc...",
				".cecccec...",
				".cccnccc...",
				"..ccccc..d.",
				".cccccccd..",
				".cwwcccc...",
				".cwwccccc..",
				".cc..cc....",
			],
			[
				".c....c....",
				".cc..cc....",
				".ccccccc...",
				".cecccec...",
				".cccnccc...",
				"..ccccc....",
				".ccccccccd.",
				".cwwcccc.d.",
				".cwwccccc..",
				".cc..cc....",
			],
		],
	},
	"phoenix": {
		"fly": true,
		"palette": {"r": "#ff5722", "o": "#ff9800", "y": "#ffeb3b", "e": EYE, "w": "#fff3e0", "d": "#d84315"},
		"frames": [
			[
				"o...........o",
				"oo...rrr...oo",
				".ooo.rer.ooo.",
				"..oorrrryoo..",
				"...orwwro....",
				"....rwwr.....",
				"....rrrr.....",
				"...yoooy.....",
				"..y.ooo.y....",
				".y..o.o..y...",
			],
			[
				".............",
				".....rrr.....",
				".....rer.....",
				"..oorrrryoo..",
				"ooooorwwrooooo",
				"o...rwwr....o",
				"....rrrr.....",
				"...yoooy.....",
				"..y.o.o.y....",
				".y.......y...",
			],
		],
	},
	"dragon": {
		"fly": true,
		"palette": {"p": "#7e57c2", "d": "#4527a0", "g": "#69f0ae", "e": "#ffeb3b", "k": EYE, "w": "#b39ddb", "f": "#ff7043"},
		"frames": [
			[
				"d.....pp.....d",
				"dd...pppp...dd",
				".ddd.pepp.ddd.",
				"..ddppppppdd..",
				"...dpgggpd....",
				"....pgggpp....",
				"....pggggpp...",
				"....pppppppp..",
				"...ppp..ppp.pp",
				"...pp...pp...p",
			],
			[
				"..............",
				".....pppp.....",
				".....pepp.....",
				"..ddppppppdd..",
				"dddddpgggpddddd",
				"d...pgggpp...d",
				"....pggggpp...",
				"....pppppppp..",
				"...ppp..ppp.pp",
				"...pp...pp..p.",
			],
		],
	},
}


## Size {w, h} of one frame of a pet sprite, without the outline ({0, 0} for an
## unknown id).
static func sprite_size(id: String, frame: int = 0) -> Dictionary:
	var sp = PET_SPRITES.get(id)
	if sp == null:
		return {"w": 0, "h": 0}
	var rows: Array = sp.frames[frame % sp.frames.size()]
	var pw: int = 0
	for r in rows:
		pw = maxi(pw, r.length())
	return {"w": pw, "h": rows.size()}


## One frame of a pet in a tight buffer with a 1px margin, outlined by default:
## the buffer draw_pet() blits, and what the web PetPortrait shows for frame 0.
## Returns null for an unknown id.
static func pet_buffer(id: String, frame: int = 0, outline: bool = true):
	var sp = PET_SPRITES.get(id)
	if sp == null:
		return null
	var rows: Array = sp.frames[frame % sp.frames.size()]
	var ph: int = rows.size()
	var pw: int = 0
	for r in rows:
		pw = maxi(pw, r.length())
	var buf: Pix = Pix.new(pw + 2, ph + 2)
	buf.sprite(1, 1, rows, sp.palette)
	if outline:
		buf.outline(Pix.OUTLINE)
	return buf


## Draw a pet with its feet at `y_bottom` (hovering pets float above it).
## Returns the sprite size {w, h} ({0, 0} for an unknown id).
static func draw_pet(p: Pix, id: String, x: int, y_bottom: int, frame: int, outline: bool = true) -> Dictionary:
	var sp = PET_SPRITES.get(id)
	if sp == null:
		return {"w": 0, "h": 0}
	var buf: Pix = pet_buffer(id, frame, outline)
	var pw: int = buf.w - 2
	var ph: int = buf.h - 2
	var hover: int = 0
	if sp.get("fly", false):
		hover = 12 + (0 if frame % 4 < 2 else 1)
	p.blit(buf, x - 1, y_bottom - ph - 1 - hover)
	return {"w": pw, "h": ph}
