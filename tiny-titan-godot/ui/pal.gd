class_name Pal
extends RefCounted
## The colour palette. One place, so the whole game stays consistent.
##
## The colours come from a theme (Settings → Theme). Every theme is a vivid
## world colour with pixel-art panels on top; boxes are colour-coded by what
## they show (gold for level, red for the boss, a bright tile per discipline)
## and each tab has its own accent.

const THEMES = {
	"arcade": {
		"name": "Arcade",
		"bg": "18244a", "bg2": "1f2e5e", "panel": "27386f", "panel2": "33488c", "border": "5f80dc", "line": "465da3",
		"outline": "0b1126", "text": "fff6ea", "muted": "b6c2ea", "well": "111a3a",
		"accent": "ffd23f", "accent_dark": "c98a12", "accent2": "ff9f1c",
		"second": "3d8bff", "second_dark": "2459c4",
	},
	"ember": {
		"name": "Ember",
		"bg": "251a1c", "bg2": "302226", "panel": "3d2b2e", "panel2": "4f383a", "border": "c0794a", "line": "6e4c46",
		"outline": "120b0c", "text": "fff3e6", "muted": "d6bcab", "well": "1a1214",
		"accent": "ffb43a", "accent_dark": "c2741a", "accent2": "ff7a3c",
		"second": "2fb7a3", "second_dark": "1c7d70",
	},
	"forest": {
		"name": "Forest",
		"bg": "10261f", "bg2": "163329", "panel": "1f4636", "panel2": "2a5c47", "border": "62c48e", "line": "3d7a5f",
		"outline": "07140f", "text": "f4ffe9", "muted": "b5d6c0", "well": "0b1c16",
		"accent": "ffd95a", "accent_dark": "b8962a", "accent2": "ff9f43",
		"second": "39a0ed", "second_dark": "1f6fb0",
	},
	"slate": {
		"name": "Slate",
		"bg": "12161f", "bg2": "191f2b", "panel": "232c3d", "panel2": "2f3b52", "border": "6f83a8", "line": "43516d",
		"outline": "07090d", "text": "f2f5fa", "muted": "a3afc4", "well": "0c1017",
		"accent": "ffc83d", "accent_dark": "b88a1f", "accent2": "ff8a5c",
		"second": "4f8dff", "second_dark": "2f5fc0",
	},
}
const THEME_ORDER = ["arcade", "ember", "forest", "slate"]

static var theme_id: String = "arcade"

## The world behind everything, and a slightly lighter version of it.
static var BG = Color("18244a")
static var BG2 = Color("1f2e5e")
## Panels (cards) and a lighter panel for things sitting on a panel.
static var PANEL = Color("27386f")
static var PANEL2 = Color("33488c")
## The bright inner edge of a panel, quiet divider lines, and the dark pixel outline.
static var BORDER = Color("5f80dc")
static var LINE = Color("465da3")
static var OUTLINE = Color("0b1126")
static var TEXT = Color("fff6ea")
static var MUTED = Color("b6c2ea")
static var ACCENT = Color("ffd23f")
static var ACCENT_DARK = Color("c98a12")
static var ACCENT2 = Color("ff9f1c")
## The face of "secondary" buttons.
static var SECOND = Color("3d8bff")
static var SECOND_DARK = Color("2459c4")
static var GOOD = Color("3ddc6d")
static var GOOD_DARK = Color("1f9c48")
static var DANGER = Color("ff4d6d")
static var DANGER_DARK = Color("b82645")
## Dark ink: text on bright buttons.
static var INK = Color("151a30")
## Sunken surfaces: text inputs and the track of progress bars.
static var WELL = Color("111a3a")
static var WELL_LINE = Color("0b1126")

# Discipline colours: bright, and distinct from each other.
static var LIFT = Color("ff6b35")
static var CLIMB = Color("23c29b")
static var RUN = Color("3d9bff")
static var RIDE = Color("ffb21f")

static var HP = Color("ff4d6d")

## Each tab has its own accent, used for its headings, sub-tabs and tab-bar label,
## so the five areas of the game do not all look the same.
const TAB_ACCENT = {
	"home": Color("ffd23f"),
	"adventure": Color("ff6b7a"),
	"log": Color("58e07a"),
	"journey": Color("5ab6ff"),
	"armory": Color("d59bff"),
}
## The tab being shown (set by the app shell).
static var current_tab: String = "home"


## Switch theme. The caller rebuilds the UI afterwards (see main.gd).
static func apply(id) -> void:
	theme_id = str(id) if THEMES.has(str(id)) else "arcade"
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
	INK = Color(t.outline).lightened(0.06)


static func theme_name(id) -> String:
	return THEMES.get(id, THEMES["arcade"]).name


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


## A deep shade of `c`, for filling a box that is colour-coded by what it shows.
static func deep(c: Color) -> Color:
	# Darkened yellows turn olive; nudging them towards orange keeps gold looking like gold.
	var h = c.h
	if h > 0.08 and h < 0.2:
		h -= 0.04
	return Color.from_hsv(h, minf(1.0, c.s * 1.05), c.v * 0.42)
