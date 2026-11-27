class_name SettingsSheet
extends RefCounted
## The Settings sheet (Home → cog). Port of tiny-titan/src/screens/Settings.tsx,
## without Strava, the server / sync section and anything about installing the app.
## The contents live in SettingsPanel (settings_panel.gd), a Node so its
## callbacks stay valid while the sheet is open.


static func open() -> void:
	var sheet = Kit.sheet("Settings")
	var panel = SettingsPanel.new()
	panel.sheet = sheet
	sheet.box.add_child(panel)
	panel.fill()
	sheet.open()
