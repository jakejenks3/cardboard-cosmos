class_name LiftNotes
extends RefCounted
## A note per lift that comes back the next time it is done (2026-11-27, "home cable pin 7, seat 4").
## STORED in `settings.liftNotes` = {normalized lift name: {name, text, at}}; one note per lift (movement
## and variation together). Nothing in the rules reads it. Pure (tests/log_extras_test.gd).

const KEY = "liftNotes"
## The longest note kept (a phone types one line).
const MAX_LEN = 140


static func key(lift_name: String) -> String:
	return Xp.normalize_exercise(lift_name)


static func of(settings: Dictionary, lift_name: String) -> String:
	var all = settings.get(KEY, {})
	if not (all is Dictionary):
		return ""
	var one = all.get(key(lift_name))
	return str(one.get("text", "")) if one is Dictionary else ""


## The notes with this lift's note set to `text` ("" takes it off). A copy.
static func with_note(settings: Dictionary, lift_name: String, text: String, day: String = "") -> Dictionary:
	var all = settings.get(KEY, {})
	var out = all.duplicate(true) if all is Dictionary else {}
	var k = key(lift_name)
	if k == "":
		return out
	var t = text.strip_edges().replace("\n", " ")
	if t.length() > MAX_LEN:
		t = t.substr(0, MAX_LEN)
	if t == "":
		out.erase(k)
	else:
		out[k] = {"name": lift_name.strip_edges(), "text": t, "at": day}
	return out


## The notes after a lift was renamed: its note goes with it (a note already on the new name stays).
static func renamed(settings: Dictionary, old_name: String, new_name: String) -> Dictionary:
	var all = settings.get(KEY, {})
	var out = all.duplicate(true) if all is Dictionary else {}
	var ok = key(old_name)
	var nk = key(new_name)
	if not out.has(ok) or ok == nk:
		return out
	if not out.has(nk):
		var one = out[ok].duplicate()
		one["name"] = new_name
		out[nk] = one
	out.erase(ok)
	return out
