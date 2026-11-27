class_name RecapPush
extends RefCounted
## Last week's recap poster as a picture on the phone: when the game is opened
## in a new week (once a week), with Morning goals on and "Weekly recap" on
## (settings.morning.recap, on by default), if last week had workouts, the
## poster (RecapSheet.poster) is drawn off screen and sent to the ntfy topic as
## an attachment (MorningAlert.send_picture), WITHOUT progress photos (the
## relay is public and keeps attachments a while). settings.morning.recapSent keeps
## the week sent. Never from tests or scratch runs (TINY_TITAN_DATA set): the
## game itself only.


## Send last week's poster when it is due. Awaitable: true when sent.
static func send_if_due() -> bool:
	if OS.get_environment("TINY_TITAN_DATA") != "" and not OS.get_cmdline_user_args().has("--recap-push-test"):
		return false
	# The PC sends it (it has the morning goals); the phone app would send it twice.
	if OS.has_feature("web"):
		return false
	var key = MorningAlert.recap_due(App.settings(), App.sessions(), App.today)
	if key == "":
		return false
	var r = Recap.build("week", key, App.state, App.sessions(), App.body(), App.today)
	# No progress photos: ntfy.sh is a public relay that keeps attachments a while.
	r["photos"] = null
	# Its own file (a poster the player saved keeps its photos), gone once sent.
	var path = await RecapSheet.save_picture(r, "phone-week-%s.png" % key)
	if path == "":
		return false
	var m = MorningAlert.settings(App.settings())
	var words = "%s: %d workouts, %s XP. Tap to open your note." % [Recap.title_of("week", key), int(r.get("sessions", 0)), Xp.fmt_int(int(r.get("xp", 0)))]
	var res = await MorningAlert.send_picture(App, "Tiny Titan - your week", words, m.topic, m.server, path, MorningAlert.note_link(App.saved))
	DirAccess.remove_absolute(path)
	if res.ok:
		var mm = App.settings().get("morning", {}).duplicate()
		mm["recapSent"] = key
		App.update_settings({"morning": mm})
		App.toast("Last week's recap is on your phone", "good", "photo")
	return res.ok
