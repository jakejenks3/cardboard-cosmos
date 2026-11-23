class_name Todos
extends RefCounted
## A plain to-do list: things to do that have nothing to do with training
## (the user, 2026-11-22: "A separate section for random things I need to do...
## doesn't need to connect. Goals or points or anything, just to keep a list
## and check boxes"). STORED, not derived: saved.todos = [{"id", "text", "done",
## "at" (when it was added, ms), "doneOn" (the day it was ticked, or "")}], in
## the order added. No mission, no streak and no plan reads it.
## App has the commands (add_todo, set_todo_done, remove_todo,
## clear_done_todos); the screen is ui/screens/todo_view.gd.
##
## A SMALL BONUS for ticking one off (the user, 2026-11-23: "Add some small
## bonuses for doing to do list tasks, changed my mind about that"; the list
## paid nothing at first, by their own wish). Ticking an item pays BONUS_XP
## hero XP (and so 2 coins), ONCE per item and for at most BONUS_A_DAY items a
## day, so the list cannot be milked: unticking takes nothing back, ticking
## again pays nothing more. It is paid as a claim (saved.claims, questId
## "todo:<item id>"), like a mission or a sent project: the XP and the coins
## come from the replay, and they stay earned when the item is taken off the
## list. Keep it small: it is a thank-you for a chore, not a way to level.

const MAX_TEXT = 200
## Rows on the Hero tab's card (the sheet has them all).
const CARD_ROWS = 3
## What a tick pays, and for how many items a day.
const BONUS_XP = 20
const BONUS_A_DAY = 5
## A bonus claim's questId is this and the item's id.
const CLAIM = "todo:"


## An item's words as stored: one line, trimmed, not endless.
static func clean(text: String) -> String:
	return text.replace("\n", " ").replace("\r", " ").strip_edges().left(MAX_TEXT)


static func new_item(text: String, now_ms: int) -> Dictionary:
	return {"id": Rng.uid("td"), "text": clean(text), "done": false, "at": now_ms, "doneOn": ""}


## The saved list, cleaned (anything that is not an item with words is left out).
static func parse(raw) -> Array:
	var out = []
	if not (raw is Array):
		return out
	for t in raw:
		if not (t is Dictionary) or not (t.get("id") is String) or clean(str(t.get("text", ""))) == "":
			continue
		var at = t.get("at", 0)
		out.append({"id": str(t.id), "text": clean(str(t.text)), "done": bool(t.get("done", false)),
			"at": int(at) if (at is int or at is float) else 0, "doneOn": str(t.get("doneOn", ""))})
	return out


static func claim_id(id: String) -> String:
	return CLAIM + id


## Was this item's bonus paid (ever)?
static func paid(claims: Array, id: String) -> bool:
	var q = claim_id(id)
	return claims.any(func(c): return str(c.get("questId", "")) == q)


## How many bonuses were paid on `day`.
static func paid_on(claims: Array, day: String) -> int:
	return claims.filter(func(c): return str(c.get("questId", "")).begins_with(CLAIM) and str(c.get("date", "")) == day).size()


## How many bonuses are still to be had on `day`.
static func left_on(claims: Array, day: String) -> int:
	return maxi(0, BONUS_A_DAY - paid_on(claims, day))


## What ticking this item off on `day` pays: BONUS_XP, or 0 when it was paid
## before or the day's bonuses are used up.
static func bonus_for(claims: Array, id: String, day: String) -> int:
	if paid(claims, id) or left_on(claims, day) <= 0:
		return 0
	return BONUS_XP


static func open_count(list: Array) -> int:
	return list.filter(func(t): return not bool(t.done)).size()


static func done_count(list: Array) -> int:
	return list.filter(func(t): return bool(t.done)).size()


## What the Hero tab's card lists: the open items and the ones ticked today,
## in the list's order. One ticked today stays where it is until tomorrow, so
## ticking never moves the rows under the finger.
static func shown(list: Array, today: String) -> Array:
	return list.filter(func(t): return not bool(t.done) or str(t.get("doneOn", "")) == today)
