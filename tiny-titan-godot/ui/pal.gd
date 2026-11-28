class_name Pal
extends RefCounted
## The colour palette. One place, so the whole game stays consistent.
##
## THE WORKSHOP LOOK (2026-11-27, the user's pick of four mock-ups made after looking at the menus of idle
## and pixel RPG games: "Let's go with #1"). A dark plank page; windows framed in wood round sand
## parchment; rows on cream paper slips; solid bevelled keys in green, gold, red, orange, blue and wood with
## cream words outlined in dark; icons in framed slots; dark wells for numbers being typed. Dark ink is the
## text on paper, cream the text on wood, keys and the page (ui/ink.gd keeps every word readable on what it
## sits on). It is the only theme: "theme" in the settings is ignored (the four old ones are gone).

const THEMES = {
	"workshop": {
		"name": "Workshop",
		"bg": "2b1a12", "bg2": "1f110a", "panel": "eccd94", "panel2": "fbf1d8", "border": "7a5230", "line": "c9a46a",
		"outline": "1f110a", "text": "3b2417", "muted": "76553a", "well": "2a170e",
		"accent": "f2b632", "accent_dark": "c4871a", "accent2": "e8692e",
		"second": "3f86d6", "second_dark": "2a5f9e",
	},
}
const THEME_ORDER = ["workshop"]

static var theme_id: String = "workshop"

## The page behind everything (dark planks: PixBox.planks), and a darker shade of it.
static var BG = Color("2b1a12")
static var BG2 = Color("1f110a")
## Sand parchment inside a wooden window, and the cream paper of a slip or card sitting on it.
static var PANEL = Color("eccd94")
static var PANEL2 = Color("fbf1d8")
## Brown edges of paper, quiet divider lines on paper, and the dark rim round everything.
static var BORDER = Color("7a5230")
static var LINE = Color("c9a46a")
static var OUTLINE = Color("1f110a")
## Dark ink: words on paper. MUTED is the quieter brown ink.
static var TEXT = Color("3b2417")
static var MUTED = Color("76553a")
## Gold (a reward, the one main action), its dark edge, and orange (a warning).
static var ACCENT = Color("f2b632")
static var ACCENT_DARK = Color("c4871a")
static var ACCENT2 = Color("e8692e")
## The face of "secondary" keys: blue.
static var SECOND = Color("3f86d6")
static var SECOND_DARK = Color("2a5f9e")
static var GOOD = Color("5bb34a")
static var GOOD_DARK = Color("3d8a33")
static var DANGER = Color("d2493b")
static var DANGER_DARK = Color("a12f25")
## The darkest ink: words on bright keys and tags, the rim of everything.
static var INK = Color("1f110a")
## Cream: words on wood, on keys, on the page and in dark wells. GOLD_TEXT: gold numbers there.
static var CREAM = Color("fff2cf")
static var GOLD_TEXT = Color("ffd25e")
## Sunken surfaces: text inputs, the track of a bar or a switch (dark; their words are CREAM).
static var WELL = Color("2a170e")
static var WELL_LINE = Color("1f110a")

# Discipline colours: bright, and distinct from each other (the mock-up's).
static var LIFT = Color("e8692e")
static var CLIMB = Color("2fa37a")
static var RUN = Color("3f86d6")
static var RIDE = Color("e0a030")
## Misc activities (vest walks...): pink, apart from the four disciplines.
static var MISC = Color("d65aa0")
## Reading: the brown of a book's spine, apart from everything that is training.
static var READ = Color("b07a3a")
static var READ_DARK = Color("7d5222")
## Physical therapy (game/pt.gd): a fresh green-yellow, apart from the training colours.
static var PT = Color("8cbf3f")
static var PT_DARK = Color("5e8a22")

static var HP = Color("d2493b")
## The weekly bounty: violet, so it never reads as the campaign boss.
static var BOUNTY = Color("9b4de0")

# The Realm (the RPG tab, RPG_PLAN.md): its own colour and one per school of
# moves that has none yet. The other schools borrow what their training
# already has (speed RUN, grip CLIMB, mind READ, flow PT: RpgUi.color). Picked
# 2026-11-25 far from each other and from the fixed colours above. As words on
# paper they are darkened by Ink to stay readable.
## Push moves (chest, shoulders, arms): a light coral.
static var PUSH = Color("ff8e7c")
## Pull moves (back, arms): periwinkle, between RUN's blue and BOUNTY's violet.
static var PULL = Color("939bff")
## Legs moves: lemon yellow.
static var LEGS = Color("f0e63c")
## Grit (showing up): magenta.
static var GRIT = Color("ff60f6")
## The Realm itself (its tab, its sections, ore): cyan. TAB_ACCENT.realm is the same value.
static var REALM = Color("36d6f2")

## What a colour means (2026-11-24, "things blend together"): gold (ACCENT) is a reward (XP, coins, the
## level, the chest, Claim) and the one main action, never a target or a frame for everything. A section's
## colour is what it is about (LIFT for today's lifting, PT, CLIMB, READ) or the tab it leads to (Pal.tab):
## it colours the section's icon slot and its sign. GOOD means done, ACCENT2 a warning, DANGER stuck or down.

## The materials of the Workshop look (PixBox.material): rings from the outside in, each a colour, a bevel
## [lit top and left, shaded bottom and right] or four sides [top, left, bottom, right]; the fill; the
## corner chamfer in art pixels. The same values as the approved mock-up.
const MATERIALS = {
	# A window: dark rim, a raised wood band, a dark inner line, then sand parchment.
	"wood": {"rings": ["3a2216", ["e09656", "7d4322"], "b5683a", "b5683a", ["8a4a26", "c97a44"], "4a2a18", ["c29a5e", "f6e2b4"]], "fill": "eccd94", "cut": 2},
	# The sign on a window's top edge, the tab bar's shelf and the top bar's board.
	"plate": {"rings": ["1f110a", ["c27a46", "4e2814"], ["8f4f2c", "69371d"]], "fill": "7a4224", "cut": 1},
	"board": {"rings": ["1f110a", ["d98a4e", "5a3018"], ["b5683a", "a85f34", "6b3a1c", "a85f34"]], "fill": "9c5630", "cut": 1},
	# Paper: a row's slip, a card, a note pinned on wood, a quiet chip.
	"slip": {"rings": ["7a5230", ["fffcf2", "d8bb84"]], "fill": "fbf1d8", "cut": 1},
	"card": {"rings": ["3a2216", ["fffdf6", "d6b77e"]], "fill": "fff8e8", "cut": 1},
	"note": {"rings": ["a8794a", ["b98d55", "f9e7bf"]], "fill": "e2bf82", "cut": 1},
	"chip": {"rings": ["7a5230", ["f6dfae", "b48a52"]], "fill": "e6c690", "cut": 1},
	# Sunken: a pick-one track, a well for numbers, a dark cap (the coins, a timer).
	"track": {"rings": ["24140c", ["2a170e", "6b442c"]], "fill": "4a2e1e", "cut": 1},
	"well": {"rings": ["1a0d07", ["120904", "5a3a26"]], "fill": "2a170e", "cut": 1},
	"cap": {"rings": ["120804", ["0b0502", "5a3a26"]], "fill": "24140c", "cut": 2},
	# An icon's framed slot (PixBox.slot puts a ring in the slot's colour after the rim).
	"slot": {"rings": ["24140c", ["2a170e", "6b442c"]], "fill": "4a2e1e", "cut": 1},
}
## The solid keys: [rim, lit edge, shaded edge, face].
const BLOCKS = {
	"green": ["1f3d18", "8fd46f", "3d8a33", "5bb34a"], "gold": ["4a2e08", "ffe08a", "c4871a", "f2b632"],
	"red": ["4a120c", "f28474", "a12f25", "d2493b"], "orange": ["4a1d08", "ffa46e", "b14a1a", "e8692e"],
	"wood": ["3a2216", "e09a5c", "7d4322", "b5683a"], "purple": ["2c1145", "c58cff", "6e2fae", "9b4de0"],
	"blue": ["0f2a4a", "86bdf2", "2a5f9e", "3f86d6"], "tan": ["6b4a2c", "fff8e2", "c9a46a", "efd9aa"],
}
## The shadow a window and a key cast on what is under them.
const SHADOW = Color(0.03, 0.016, 0.008, 0.7)

## Each tab has its own accent, used for its headings, sub-tabs and tab-bar label,
## so the six areas of the game do not all look the same ("realm" is Pal.REALM;
## a const cannot name a static var, so the value is written again).
const TAB_ACCENT = {
	"home": Color("ffd23f"),
	"adventure": Color("ff6b7a"),
	"log": Color("58e07a"),
	"journey": Color("5ab6ff"),
	"armory": Color("d59bff"),
	"realm": Color("36d6f2"),
}
## The tab being shown (set by the app shell).
static var current_tab: String = "home"


## The one theme (any id): kept so main.gd's start-up and an old save's "theme" still work.
static func apply(_id = "workshop") -> void:
	theme_id = "workshop"
	var t = THEMES[theme_id]
	BG = Color(t.bg)
	BG2 = Color(t.bg2)
	PANEL = Color(t.panel)
	PANEL2 = Color(t.panel2)
	BORDER = Color(t.border)
	LINE = Color(t.line)
	OUTLINE = Color(t.outline)
	TEXT = Color(t.text)
	MUTED = Color(t.muted)
	WELL = Color(t.well)
	WELL_LINE = Color(t.outline)
	ACCENT = Color(t.accent)
	ACCENT_DARK = Color(t.accent_dark)
	ACCENT2 = Color(t.accent2)
	SECOND = Color(t.second)
	SECOND_DARK = Color(t.second_dark)
	INK = Color(t.outline)


static func theme_name(_id = "") -> String:
	return THEMES["workshop"].name


static func tab(id) -> Color:
	return TAB_ACCENT.get(id, ACCENT)


## The accent of the tab being shown.
static func tab_accent() -> Color:
	return TAB_ACCENT.get(current_tab, ACCENT)


static func disc(d) -> Color:
	match d:
		"lift":
			return LIFT
		"climb":
			return CLIMB
		"run":
			return RUN
		"ride":
			return RIDE
		"misc":
			return MISC
	return ACCENT


static func rarity(r) -> Color:
	match r:
		"common":
			return Color("b8c0cc")
		"uncommon":
			return Color("6fd37a")
		"rare":
			return Color("5aa9ff")
		"epic":
			return Color("c77dff")
		"legendary":
			return Color("ffc83d")
	return MUTED


## "#rrggbb" (or "rrggbb") → Color. Unknown input gives the accent colour.
static func hex(s) -> Color:
	if s is Color:
		return s
	if s is String and Color.html_is_valid(s):
		return Color.html(s)
	return ACCENT


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## The header band of a section in colour `c` (Kit.section): a deep shade lit a
## little towards `c` (deep alone is too close to the panel for blues).
static func band(c: Color) -> Color:
	return deep(c).lerp(c, 0.22)


## The fill of a row inside a section (Kit.row): the cream paper of a slip.
static func slot() -> Color:
	return PANEL2


## A deep shade of `c`, for filling a box that is colour-coded by what it shows.
static func deep(c: Color) -> Color:
	# Darkened yellows turn olive; nudging them towards orange keeps gold looking like gold.
	var h = c.h
	if h > 0.08 and h < 0.2:
		h -= 0.04
	return Color.from_hsv(h, minf(1.0, c.s * 1.05), c.v * 0.42)
