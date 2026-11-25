class_name Bands
extends RefCounted
## Resistance bands in place of a weight (the user, 2026-11-25: "can we add a
## way to add bands to exs, instead of weight for resistances for similar
## activities"). A set done with a band is stored as
##   {"reps": n, "weightKg": 0.0, "band": "<id>"}
## The rules do not know bands: a band set earns as a bodyweight set (weight 0),
## so XP, parity and the records the rules keep by weight are untouched. What
## knows them: LiftHistory (the words, "3×15 · green band"), LiftTrend (a day's
## band, compare, records, the aim), the Log tab's band picker (BandPicker) and
## the lift's page.
##
## The ladder, light to heavy, is the order most therapy bands use. A band is
## a lower case id; its colour is the colour of the band itself (a real-world
## colour, not a theme colour), so it is kept here.
##
##   level(id)          1..9 up the ladder, 0 = no band or one not on it
##   name_of(id)        "Green"
##   words(id)          "green band"
##   color_of(id)       the swatch
##   text_color(id)     dark ink on a light swatch, light text on a dark one
##   step(id, d)        one band lighter (-1) or heavier (+1), kept on the ladder
##   is_band(set)       a set done with a band
##   top(sets)          the heaviest band of some sets ("" none)
##   of_name(lift)      a ladder colour named in a lift's variation ("" none)
##   says_band(lift)    is this lift done with a band (its variation, or its
##                      library movement's usual equipment)
##
## Pure logic: tests/bands_test.gd.

const LADDER = ["yellow", "orange", "red", "green", "blue", "black", "purple", "silver", "gold"]
const NAMES = {"yellow": "Yellow", "orange": "Orange", "red": "Red", "green": "Green", "blue": "Blue",
	"black": "Black", "purple": "Purple", "silver": "Silver", "gold": "Gold"}
const COLORS = {
	"yellow": Color("ffd92e"),
	"orange": Color("ff8a1f"),
	"red": Color("e8333a"),
	"green": Color("2fbf4a"),
	"blue": Color("2f6fe0"),
	"black": Color("2a2a30"),
	"purple": Color("8a3fd1"),
	"silver": Color("c3c9d1"),
	"gold": Color("d9a521"),
}
## The band a set gets when nothing else says which.
const DEFAULT = "red"
## Words that say a lift is done with a band.
const BAND_WORDS = ["band", "bands", "banded"]


static func _id(id) -> String:
	return str(id).strip_edges().to_lower()


static func level(id) -> int:
	return LADDER.find(_id(id)) + 1


static func name_of(id) -> String:
	var k = _id(id)
	if NAMES.has(k):
		return str(NAMES[k])
	return k.substr(0, 1).to_upper() + k.substr(1) if k != "" else ""


## "green band".
static func words(id) -> String:
	var n = name_of(id)
	return "band" if n == "" else "%s band" % n.to_lower()


static func color_of(id) -> Color:
	return COLORS.get(_id(id), Color(0.55, 0.55, 0.6))


## Text on the band's swatch: dark ink on a light band, light text on a dark one.
static func text_color(id) -> Color:
	return Pal.INK if color_of(id).get_luminance() > 0.5 else Pal.TEXT


## One band lighter (d < 0) or heavier (d > 0), never off the ladder. A band
## not on the ladder steps from DEFAULT.
static func step(id, d: int) -> String:
	var lv = level(id)
	if lv == 0:
		lv = level(DEFAULT)
	return str(LADDER[clampi(lv + d, 1, LADDER.size()) - 1])


static func is_band(one) -> bool:
	return one is Dictionary and _id(one.get("band", "")) != ""


## The heaviest band of the sets with reps ("" when none has a band).
static func top(sets: Array) -> String:
	var best = ""
	var best_lv = -1
	for one in sets:
		if is_band(one) and int(one.get("reps", 0)) > 0 and level(one.band) > best_lv:
			best_lv = level(one.band)
			best = _id(one.band)
	return best


static func _words_of(text: String) -> Array:
	var clean = ""
	for ch in text.to_lower():
		clean += ch if (ch >= "a" and ch <= "z") else " "
	return Array(clean.split(" ", false))


## A colour of the ladder named in a lift's variation: "Face Pull - Green band"
## is "green". "" when it names none.
static func of_name(lift_name: String) -> String:
	for w in _words_of(str(LiftNames.split(lift_name).variation)):
		if LADDER.has(w):
			return str(w)
	return ""


## Is this lift done with a band: "band" in its name or variation, a band
## colour in its variation, or (no variation) a library movement whose usual
## equipment is a band (Pull-Apart, Lateral Walk).
static func says_band(lift_name: String) -> bool:
	for w in _words_of(lift_name):
		if BAND_WORDS.has(w):
			return true
	if of_name(lift_name) != "":
		return true
	var sp = LiftNames.split(lift_name)
	if str(sp.variation) != "":
		return LiftNames.gear_of(str(sp.variation)).has("band")
	var m = LiftNames.movement(str(sp.move))
	if m is Dictionary:
		if LiftNames.gear_of(str(m.get("usual", ""))).has("band"):
			return true
		for o in m.get("only", []):
			if LiftNames.gear_of(str(o)).has("band"):
				return true
	return false
