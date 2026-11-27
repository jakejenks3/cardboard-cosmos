class_name WebFiles
extends RefCounted
## Files in the web build, where there are no folders to pick from: a file goes
## to the browser (on an iPhone, the share sheet: Save to Files, Photos, ...)
## and comes from its file chooser. A phone only opens either inside a tap, so
## the page shows a real button for it (web/tt.js, ttFile).

## The JavaScriptBridge callback of the file chooser (it must stay referenced).
static var _picked = null
static var _on_pick: Callable
static var _saved = null
static var _on_saved: Callable
static var _copied = null
## Why the file picked last could not be used ("" when it could, or when the chooser was closed).
static var last_error: String = ""
static var _on_copied: Callable


static func available() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.get_interface("ttFile") != null


## Hand `bytes` to the browser as a file called `file_name`. `label` is the button's text.
## `done` (optional) is called once the player has tapped the button.
static func save(file_name: String, mime: String, bytes: PackedByteArray, label: String = "Save it", done: Callable = Callable()) -> void:
	var f = JavaScriptBridge.get_interface("ttFile")
	if f == null:
		return
	_on_saved = done
	_saved = JavaScriptBridge.create_callback(WebFiles._did_save)
	f.save(file_name, mime, Marshalls.raw_to_base64(bytes), label, _saved)


static func _did_save(_args: Array) -> void:
	if _on_saved.is_valid():
		_on_saved.call()


## Put `text` on the clipboard: at once inside a tap, else a real button shows
## for the player to tap. `done` (optional) is called once it really is there.
static func copy(text: String, label: String = "Copy", done: Callable = Callable()) -> void:
	var w = JavaScriptBridge.get_interface("window")
	if w == null:
		return
	_on_copied = done
	_copied = JavaScriptBridge.create_callback(WebFiles._did_copy)
	w.ttCopy(text, label, _copied)


static func _did_copy(_args: Array) -> void:
	if _on_copied.is_valid():
		_on_copied.call()


## Let the player choose a file; `done` gets (file name, bytes), or ("", empty) if none.
## With `max_side`, a picture arrives as a JPEG no longer than that on its longer
## side, the right way up (a phone's photo, from the camera or the library).
static func pick(accept: String, label: String, done: Callable, max_side: int = 0) -> void:
	var f = JavaScriptBridge.get_interface("ttFile")
	if f == null:
		return
	_on_pick = done
	_picked = JavaScriptBridge.create_callback(WebFiles._got)
	f.pick(accept, label, _picked, max_side)


## What became of the file picked last, as the page tells it (how it was read, its kind and size): for
## Settings -> Phone app, so a picture that would not load can be told apart from here.
static func last_pick() -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("(window.ttFile && window.ttFile.last) || ''", true)
	return str(v) if v != null else ""


## What kind of picture these bytes are, by how they begin: "jpeg", "png", "webp", "heic" or "".
static func kind_of(bytes: PackedByteArray) -> String:
	if bytes.size() < 12:
		return ""
	if bytes[0] == 0xFF and bytes[1] == 0xD8:
		return "jpeg"
	if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		return "png"
	if bytes.slice(0, 4).get_string_from_ascii() == "RIFF":
		return "webp"
	if bytes.slice(4, 8).get_string_from_ascii() == "ftyp":
		return "heic"
	return ""


static func _got(args: Array) -> void:
	var file_name = str(args[0]) if args.size() > 0 else ""
	var b64 = str(args[1]) if args.size() > 1 else ""
	last_error = str(args[2]) if args.size() > 2 and args[2] != null else ""
	var bytes = Marshalls.base64_to_raw(b64) if b64 != "" else PackedByteArray()
	if _on_pick.is_valid():
		_on_pick.call(file_name, bytes)
