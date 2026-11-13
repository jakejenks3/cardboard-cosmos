class_name UiScreen
extends VBoxContainer
## Base class for every screen. Override `build()` and add children to `self`.
##
## A screen is rebuilt from scratch whenever the saved data changes
## (App.changed) or the sub-navigation changes (App.nav_changed). Screens that
## hold a half-filled form set `auto_rebuild = false` and update themselves.

var auto_rebuild: bool = true
var _queued: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	App.changed.connect(_on_app_changed)
	App.nav_changed.connect(_on_app_nav)
	rebuild_now()


func _on_app_changed() -> void:
	if auto_rebuild:
		rebuild()


func _on_app_nav() -> void:
	on_nav()


## Called when the tab / sub-tab / edit target changes. Default: rebuild.
func on_nav() -> void:
	rebuild()


## Rebuild at the end of this frame (several requests in one frame become one).
func rebuild() -> void:
	if _queued:
		return
	_queued = true
	call_deferred("rebuild_now")


func rebuild_now() -> void:
	_queued = false
	if not is_inside_tree():
		return
	Kit.clear(self)
	build()


## Override: create the screen's controls and add them to `self`.
func build() -> void:
	pass
