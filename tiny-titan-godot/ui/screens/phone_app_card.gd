class_name PhoneAppCard
extends VBoxContainer
## Settings -> PHONE APP: the save shared by the PC and the phone app through
## the note's script (app/cloud_sync.gd).
##
## On the PC: a switch (the note's script must be set up first), the sync's
## state, Sync now, and Send to phone (a push with the phone app's link, which
## carries the script's link and token: the phone connects by opening it).
## In the phone app: the same state, or, before it is connected, a box to paste
## the code into; and how to put the app on the Home Screen.
## The state line follows the sync as it happens (status_changed).

const ABOUT = [
	"Your log is kept in your phone note's script, in your own Google account, so the PC and the phone app share one log.",
	"A change on either goes there a few seconds later. Both keep their own copy and work without a connection; they catch up when they are back online.",
	"When both changed things at once, the two are put together: nothing you logged on either is lost. A copy of the save is kept before each merge.",
	"Progress photos go to a folder in your own Google Drive, Tiny Titan photos. Only you can open it.",
	"The link the PC sends your phone holds the script's link and its password. Keep it to yourself.",
]

var _panel = null
var _status: Label = null
var _icon: Control = null
## In the phone app, not connected: the connect box is shown only when asked for.
var _show_connect: bool = false


static func make(panel) -> Control:
	var card = panel._card("PHONE APP", panel._info_button("About the phone app", ABOUT))
	var me = PhoneAppCard.new()
	me._panel = panel
	me.add_theme_constant_override("separation", 8)
	me.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	me._fill()
	card.add(me)
	return card


func _ready() -> void:
	App.cloud.status_changed.connect(_on_status)


func _exit_tree() -> void:
	if App.cloud != null and App.cloud.status_changed.is_connected(_on_status):
		App.cloud.status_changed.disconnect(_on_status)


func _fill() -> void:
	var cloud = App.cloud
	var web = OS.has_feature("web")
	var ep = cloud._endpoint()
	if not web and ep.url == "":
		add_child(Kit.muted_para("First set up your phone note's script (Phone inbox: Clear the table, Set up). Then your log can go to the phone app.", 12))
		return
	if web and str(cloud._cfg.get("url", "")) == "":
		# The phone app by itself: its own switches first; sharing with a PC is an extra.
		_home_screen_hint_plain()
		_phone_rows()
		_version_row()
		if _show_connect:
			_connect_box()
		else:
			var share = Kit.button("Share my log with a PC…", "ghost", func():
				Sfx.tap()
				_show_connect = true
				_refill(), "sm")
			share.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			add_child(share)
		return
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(Icons.rect("repeat", 16)))
	var l = Kit.clip("Share my log with the phone app" if not web else "Share my log with my PC", 14, null, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(Kit.vcenter(l))
	row.add_child(Kit.switch(cloud.is_on(), _on_switch, "Keep your log in the note's script, shared with the other device"))
	add_child(row)
	var st = Kit.hbox(6)
	_icon = Icons.rect("clock", 16)
	st.add_child(Kit.vcenter(_icon))
	_status = Kit.clip(cloud.status_text(), 12, _color(cloud.status))
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(Kit.vcenter(_status))
	add_child(st)
	if cloud.status == "old":
		add_child(_old_script_help())
	if str(cloud.photo_note) != "":
		var pn = Kit.hbox(6)
		pn.add_child(Kit.vcenter(Icons.rect("camera", 16)))
		var pt = Kit.muted_para(str(cloud.photo_note), 12)
		pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pn.add_child(pt)
		add_child(pn)
	var keys = Kit.hbox(8)
	keys.add_child(Kit.expand(Kit.button("Sync now", "secondary", _sync_now, "md", "repeat")))
	if not web:
		var send = Kit.button("Send to phone", "primary", _send_to_phone, "md", "arrow_down")
		send.tooltip_text = "A push to your phone with the app's link (it connects by itself)"
		keys.add_child(Kit.expand(send))
	add_child(keys)
	if not web:
		var copy = Kit.button("Copy the phone's link", "ghost", _copy_link, "sm")
		copy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		add_child(copy)
	if web:
		_home_screen_hint()
		_phone_rows()
	_version_row()


## The phone app's own switches: how sharp it draws, and buzzes.
func _phone_rows() -> void:
	var app = JavaScriptBridge.get_interface("ttApp") if OS.has_feature("web") else null
	if app != null and float(app.dpr) > 2.0:
		var row = Kit.hbox(8)
		row.add_child(Kit.vcenter(Icons.rect("sparkle", 16)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.clip("Sharper picture", 14, null, true))
		v.add_child(Kit.clip("Off if scrolling feels slow. The app reloads", 11, Pal.MUTED))
		row.add_child(v)
		row.add_child(Kit.switch(bool(app.sharp), func(on): app.setSharp(bool(on)), "Draw every pixel of this screen"))
		add_child(row)
	var hz = Kit.hbox(8)
	hz.add_child(Kit.vcenter(Icons.rect("bolt", 16)))
	var hl = Kit.clip("Taps you can feel", 14, null, true)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hz.add_child(Kit.vcenter(hl))
	hz.add_child(Kit.switch(bool(App.settings().get("haptics", true)), func(on):
		App.update_settings({"haptics": bool(on)})
		Sfx.buzz(2), "A light tick with every tap, and a buzz when you finish a workout or set a record"))
	hz.set_meta("buzz_row", true)
	add_child(hz)


## Put it on the Home Screen (shown in the browser, not in the Home Screen app).
func _home_screen_hint_plain() -> void:
	if not OS.has_feature("web"):
		return
	var app = JavaScriptBridge.get_interface("ttApp")
	if app == null or bool(app.standalone):
		return
	var tip = Kit.hbox(8)
	tip.add_child(Kit.vcenter(Icons.rect("info", 16)))
	var t = Kit.muted_para("Put it on your Home Screen: tap Share, then Add to Home Screen. It then opens full screen, like an app." if bool(app.ios) else "Put it on your home screen: open the browser's menu, then Add to Home screen.", 12)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.add_child(t)
	add_child(tip)


## "New version ready": the build on screen has been replaced behind it
## (WebUpdate). One tap loads the app again, into the new one; a workout under
## way is kept (the draft) and so is everything saved. For the Hero tab.
static func update_card() -> Control:
	var c = Kit.card(6, Callable(), 10)
	c.accent(Pal.GOOD)
	c.set_meta("update_card", true)
	var row = Kit.hbox(10)
	row.add_child(Kit.vcenter(Icons.rect("sparkle", 26)))
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.clip("New version ready", 15, null, true))
	v.add_child(Kit.clip("Restart to use it. Your log is kept.", 12, Pal.MUTED))
	row.add_child(v)
	var b = Kit.button("Restart", "good", restart_now, "sm")
	b.set_meta("update_restart", true)
	row.add_child(Kit.vcenter(b))
	c.add(row)
	return c


static func restart_now() -> void:
	Sfx.tap()
	App.toast("Restarting into the new version...", "good", "sparkle")
	WebUpdate.restart()


static func check_now() -> void:
	Sfx.tick()
	WebUpdate.check()
	App.toast("Looking for a newer version. If there is one it is fetched, and a Restart key shows here.", "info", "sparkle")


## Updates, said in Settings: a Restart key once a newer build is in, else a
## key to look for one now (the app also looks when it starts and when it
## comes back to the front). Null where the app does not update this way.
static func update_row():
	if not WebUpdate.can():
		return null
	var row = Kit.hbox(8)
	row.set_meta("update_row", true)
	var ready = WebUpdate.ready()
	var l = Kit.clip("A new version is ready" if ready else "Updates come by themselves", 12, Pal.GOOD if ready else Pal.MUTED, ready)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(Kit.vcenter(l))
	var b = Kit.button("Restart", "good", restart_now, "sm") if ready else Kit.button("Check now", "ghost", check_now, "sm")
	b.set_meta("update_key", "restart" if ready else "check")
	row.add_child(Kit.vcenter(b))
	return row


## Which build this is, and a switch for the speed readout (frames a second in
## the corner): the two things to look at when the phone app misbehaves.
func _version_row() -> void:
	var main = get_tree().current_scene if is_inside_tree() else (Engine.get_main_loop() as SceneTree).current_scene
	if main == null or not main.has_method("show_speed"):
		return
	var row = Kit.hbox(8)
	var built = ""
	if OS.has_feature("web"):
		var app = JavaScriptBridge.get_interface("ttApp")
		if app != null:
			built = str(app.build)
	var l = Kit.clip(("Version %s" % built) if built != "" and not built.begins_with("%") else "", 12, Pal.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(Kit.vcenter(l))
	row.add_child(Kit.vcenter(Kit.clip("Show speed", 12, null, true)))
	row.add_child(Kit.switch(main.speed_shown(), func(on): main.show_speed(bool(on)), "Frames a second, in the corner of the screen"))
	add_child(row)
	var updates = update_row()
	if updates != null:
		add_child(updates)
	# The sizes the phone gives the page: what to read off a screenshot when the
	# app does not fit (an iPhone can hand a Home Screen app a page that is
	# shorter than its screen: web/tt.js, ttSafe).
	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval("window.ttSafe ? window.ttSafe() : ''", true)
		var d = JSON.parse_string(str(raw)) if raw != null and str(raw) != "" else null
		if d is Dictionary:
			var said = "Screen %d×%d · page %d×%d · bars %d / %d" % [int(d.get("sw", 0)), int(d.get("sh", 0)), int(d.get("w", 0)), int(d.get("h", 0)), int(d.get("top", 0)), int(d.get("bar", 0))]
			if float(d.get("short", 0)) > 0.0:
				said += " · %d short" % int(d.get("short", 0))
			add_child(Kit.clip(said, 11, Pal.with_alpha(Pal.MUTED, 0.8)))


## In the phone app, before it is connected: paste the code (or the link).
func _connect_box() -> void:
	add_child(Kit.para("Connect to your hero: on the PC, open Settings, Phone app, Send to phone, and open the link on this phone. Or copy the PC's link and paste it here:", 13, Pal.TEXT))
	var box = Kit.input("", "Paste the link or code")
	box.select_all_on_focus = false
	add_child(box)
	var go = Kit.button("Connect", "primary", func():
		if App.cloud.connect_with(box.text):
			Sfx.claim()
			App.toast("Connecting to your hero...", "good", "repeat")
			_refill(), "lg", "repeat")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(go)


func _home_screen_hint() -> void:
	if not OS.has_feature("web"):
		return
	var app = JavaScriptBridge.get_interface("ttApp")
	if app == null or bool(app.standalone):
		return
	var tip = Kit.hbox(8)
	tip.add_child(Kit.vcenter(Icons.rect("info", 16)))
	var t = Kit.muted_para("Put it on your Home Screen: tap Share, then Add to Home Screen. It then opens full screen, like an app." if bool(app.ios) else "Put it on your home screen: open the browser's menu, then Add to Home screen.", 12)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.add_child(t)
	add_child(tip)
	# If the Home Screen app opens without its connection, the link can be pasted
	# into it (it keeps its own storage, apart from the browser's).
	if App.cloud.connect_code() != "" and str(App.cloud._cfg.get("url", "")) != "":
		var cp = Kit.button("Copy my link", "ghost", func():
			Sfx.tap()
			WebFiles.copy(App.cloud.app_link() if App.cloud.app_link() != "" else App.cloud.connect_code(), "Copy my link"), "sm")
		cp.tooltip_text = "For the Home Screen app, if it asks to connect"
		cp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		add_child(cp)


func _old_script_help() -> Control:
	var p = Kit.muted_para("Your note's script is an older version. On the PC: Settings, Phone inbox, Options, Copy the script; paste it over the old one in the doc's Apps Script and Save. Choose authorize beside the Run button, press Run and allow it. Then Deploy, Manage deployments, edit (pencil), Version: New version, Deploy. The link stays the same.", 12)
	return p


func _color(st: String) -> Color:
	match st:
		"ok":
			return Pal.GOOD
		"error", "old":
			return Pal.DANGER
		"busy":
			return Pal.ACCENT
	return Pal.MUTED


func _on_status() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.text = App.cloud.status_text()
	_status.add_theme_color_override("font_color", _color(App.cloud.status))


func _on_switch(on) -> void:
	Sfx.tap()
	App.cloud.set_on(bool(on))
	_refill()


func _sync_now() -> void:
	Sfx.tap()
	App.cloud.sync_now("button")


func _refill() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_status = null
	_fill()


func _link_text() -> String:
	var link = App.cloud.app_link()
	return link if link != "" else App.cloud.connect_code()


func _copy_link() -> void:
	DisplayServer.clipboard_set(_link_text())
	App.toast("Copied. It holds your script's password: keep it to yourself", "good", "check")


## A push (ntfy, the morning goals' topic) with the phone app's link.
func _send_to_phone() -> void:
	Sfx.tap()
	var m = MorningAlert.settings(App.settings())
	var topic = _panel._ensure_topic() if _panel != null else str(m.topic)
	var link = App.cloud.app_link()
	var text = "Tap to open Tiny Titan on your phone, then Share, Add to Home Screen." if link != "" else "The phone app is not published yet. Its code: " + App.cloud.connect_code()
	var http = HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var headers = ["Title: Tiny Titan app", "Tags: iphone", "Content-Type: text/plain; charset=utf-8"]
	if link != "":
		headers.append("Click: %s" % link)
	var err = http.request("%s/%s" % [str(m.server).trim_suffix("/"), topic], PackedStringArray(headers), HTTPClient.METHOD_POST, text)
	if err != OK:
		http.queue_free()
		App.toast("Could not send it", "bad", "warning")
		return
	var res = await http.request_completed
	http.queue_free()
	var good = int(res[0]) == HTTPRequest.RESULT_SUCCESS and int(res[1]) >= 200 and int(res[1]) < 300
	App.toast(("Sent to %s: open it on your phone" % topic) if good else "Not sent: no connection", "good" if good else "bad", "check" if good else "warning")
