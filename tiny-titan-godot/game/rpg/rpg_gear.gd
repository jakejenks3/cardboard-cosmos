class_name RpgGear
extends RefCounted
## Battle stats of the game's items (RPG_PLAN.md 7.1). A stub: its builder fills
## it in. The two functions below are what RpgHero.build calls; until the real
## table is here they say "no gear".


## The battle stats of one item at +plus: {"id", "lines": [{"k", "v"}], "unique", "set"},
## or null for an id nobody knows.
static func of(_id: String, _plus: int = 0):
	return null


## The passive effects of a worn kit: `gear` = {slot: item id} (owned items
## only; an id nobody knows is skipped), `plus` = {item id: n}, `runes` = the
## saved runes, `socket` = {item id: rune id}.
static func fx(_gear: Dictionary, _plus: Dictionary = {}, _runes: Array = [], _socket: Dictionary = {}) -> Array:
	return []
