class_name Pal
extends RefCounted
## The colour palette. One place, so the whole game stays consistent.
## Surfaces are a neutral night blue; colour comes from the content (the
## disciplines, rarities, the art) and from each tab's accent.

const BG = Color("0d1117")
const BG2 = Color("131a24")
const PANEL = Color("1a2332")
const PANEL2 = Color("243044")
const LINE = Color("34435c")
const TEXT = Color("f2f5fa")
const MUTED = Color("9aa7bd")
const ACCENT = Color("ffc83d")
const ACCENT_DARK = Color("b88a1f")
const ACCENT2 = Color("ff8a5c")
const GOOD = Color("6fd37a")
const GOOD_DARK = Color("3e8a4a")
const DANGER = Color("ff6b6b")
## Dark ink: text on bright buttons, pixel-art outlines.
const INK = Color("10141b")
## Sunken surfaces: text inputs and the track of progress bars.
const WELL = Color("0a0e14")
const WELL_LINE = Color("06090d")

# Discipline colours, validated as a set on the dark panels.
const LIFT = Color("d95926")
const CLIMB = Color("199e70")
const RUN = Color("3987e5")
const RIDE = Color("c98500")

const HP = Color("ff5d6c")

## Each tab has its own accent, used for its headings, sub-tabs and tab-bar label,
## so the five areas of the game do not all look the same.
const TAB_ACCENT = {
	"home": Color("ffc83d"),
	"adventure": Color("ff6b7a"),
	"log": Color("6fd37a"),
	"journey": Color("5aa9ff"),
	"armory": Color("c58cff"),
}
## The tab being shown (set by the app shell).
static var current_tab: String = "home"


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
