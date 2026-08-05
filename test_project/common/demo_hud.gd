class_name DemoHud
extends CanvasLayer

## Shared demo chrome: title, description, live status, backend switcher, and a control bar
## whose buttons are built from whatever actions the demo declares.

signal action_pressed(action: String)
signal back_pressed
signal restart_pressed

const BACKEND_SETTING: String = "physics/3d/physics_engine"

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var status_label: Label = %StatusLabel
@onready var backend_picker: OptionButton = %BackendPicker
@onready var controls: HBoxContainer = %Controls

var _backends: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_populate_backends()
	backend_picker.item_selected.connect(_on_backend_selected)
	%BackButton.pressed.connect(back_pressed.emit)
	%RestartButton.pressed.connect(restart_pressed.emit)
	%BackButton.text = "Back (%s)" % _key_hint("demo_back")
	%RestartButton.text = "Restart (%s)" % _key_hint("demo_restart")


## Adds one button per extra action; the demo owns what each action means.
func add_action(action: String, label: String) -> void:
	var button: Button = Button.new()
	button.text = "%s (%s)" % [label, _key_hint(action)]
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action_pressed.emit.bind(action))
	controls.add_child(button)


func _populate_backends() -> void:
	var current: String = str(ProjectSettings.get_setting(BACKEND_SETTING, "DEFAULT"))
	for property in ProjectSettings.get_property_list():
		if property["name"] != BACKEND_SETTING:
			continue
		_backends = String(property["hint_string"]).split(",")
		break

	for i in _backends.size():
		backend_picker.add_item(_backends[i], i)
		if _backends[i] == current:
			backend_picker.select(i)


# The physics server is built once at startup, so switching means relaunching.
func _on_backend_selected(index: int) -> void:
	var chosen: String = _backends[index]
	if chosen == str(ProjectSettings.get_setting(BACKEND_SETTING, "DEFAULT")):
		return
	ProjectSettings.set_setting(BACKEND_SETTING, chosen)
	ProjectSettings.save()
	var scene_path: String = get_tree().current_scene.scene_file_path
	OS.set_restart_on_exit(true, ["--path", ProjectSettings.globalize_path("res://"), scene_path])
	get_tree().quit()


func _key_hint(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).physical_keycode)
	return "?"
