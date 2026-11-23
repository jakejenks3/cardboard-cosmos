class_name Todos
extends RefCounted
## A plain to-do list: things to do that have nothing to do with training
## (the user, 2026-11-22: "A separate section for random things I need to do...
## doesn't need to connect. Goals or points or anything, just to keep a list
## and check boxes"). STORED, not derived: saved.todos = [{"id", "text", "done",
## "at" (when it was added, ms), "doneOn" (the day it was ticked, or "")}], in
## the order added. Nothing in the game reads it: no XP, no mission, no streak.
## App has the commands (add_todo, set_todo_done, remove_todo,
## clear_done_todos); the screen is ui/screens/todo_view.gd.

const MAX_TEXT = 200
## Rows on the Hero tab's card (the sheet has them all).
const CARD_ROWS = 3


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


static func open_count(list: Array) -> int:
	return list.filter(func(t): return not bool(t.done)).size()


static func done_count(list: Array) -> int:
	return list.filter(func(t): return bool(t.done)).size()


## What the Hero tab's card lists: the open items and the ones ticked today,
## in the list's order. One ticked today stays where it is until tomorrow, so
## ticking never moves the rows under the finger.
static func shown(list: Array, today: String) -> Array:
	return list.filter(func(t): return not bool(t.done) or str(t.get("doneOn", "")) == today)
