class_name WebUpdate
extends RefCounted
## The phone app (web build): a newer build is ready to use.
##
## The app's files are kept on the phone by its service worker (sw.js, written
## by tools/build_web.py), so it opens without a connection. A new build comes
## with a new sw.js: the browser fetches it when the app starts (and when the
## app comes back to the front, web/tt.js), keeps the new files and hands the
## page over to them. The page on screen is still the OLD build until it is
## loaded again, and nothing said so: the user, 2026-11-23, after a publish
## they could not see: "its up there now, i must not have updated it correctly
## before".
##
## So the page says when that has happened (web/tt.js, `ttUpdate.ready()`),
## main.gd asks every few seconds, and the game offers a restart: a card on
## the Hero tab and a row in Settings -> Phone app (PhoneAppCard.update_card,
## `update_row`). Nothing restarts by itself: a workout may be under way.

## The game has said so already (main.gd says it once).
static var announced: bool = false
## For a walkthrough on the PC: "idle" = as if this were the phone app with
## nothing newer, "ready" = as if a newer build had taken over.
static var pretend: String = ""


## Can this app be updated like that (the web build, where the browser keeps
## its files)?
static func can() -> bool:
	if pretend != "":
		return true
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("!!(window.ttUpdate && window.ttUpdate.can)", true))


## Has a newer build taken over from the one on screen?
static func ready() -> bool:
	if pretend != "":
		return pretend == "ready"
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("!!(window.ttUpdate && window.ttUpdate.ready())", true))


## Ask the site now whether there is a newer build (it is fetched if so, and
## `ready` turns true once it is in).
static func check() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ttUpdate && window.ttUpdate.check()", true)


## Load the app again, into the newer build. The save is written as it changes;
## the page waits a moment for the last write to reach the phone's storage.
static func restart() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ttUpdate && window.ttUpdate.restart()", true)
