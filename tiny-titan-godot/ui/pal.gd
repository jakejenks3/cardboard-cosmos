class_name Pal
extends RefCounted
## The colour palette. One place, so the whole game stays consistent.

const BG = Color("14102a")
const BG2 = Color("1c1738")
const PANEL = Color("231d45")
const PANEL2 = Color("2b2454")
const LINE = Color("3a3166")
const TEXT = Color("f3efff")
const MUTED = Color("a99ecf")
const ACCENT = Color("ffc83d")
const ACCENT_DARK = Color("b88a1f")
const ACCENT2 = Color("ff8a5c")
const GOOD = Color("6fd37a")
const GOOD_DARK = Color("3e8a4a")
const DANGER = Color("ff6b6b")
## Dark ink: text on bright buttons, pixel-art outlines.
const INK = Color("1a1026")
## Sunken surfaces: text inputs and the track of progress bars.
const WELL = Color("110d22")
const WELL_LINE = Color("0c0917")

# Discipline colours, validated as a set on the dark panels.
const LIFT = Color("d95926")
const CLIMB = Color("199e70")
const RUN = Color("3987e5")
const RIDE = Color("c98500")

const HP = Color("ff5d6c")


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
