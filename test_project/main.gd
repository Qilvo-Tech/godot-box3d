class_name DemoHub
extends Control

const DEMOS: Array[Dictionary] = [
	{"name": "Shapes", "path": "res://demos/shapes.tscn"},
	{"name": "Joints", "path": "res://demos/joints.tscn"},
	{"name": "Areas", "path": "res://demos/areas.tscn"},
	{"name": "Contacts", "path": "res://demos/contacts.tscn"},
	{"name": "Collision exceptions", "path": "res://demos/exceptions.tscn"},
	{"name": "Trimesh", "path": "res://demos/trimesh.tscn"},
	{"name": "Benchmark", "path": "res://demos/benchmark.tscn"},
]

@onready var _buttons: VBoxContainer = %Buttons
@onready var _backend_label: Label = %BackendLabel


func _ready() -> void:
	var engine_name: String = str(
		ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT")
	)
	var loaded: bool = ClassDB.class_exists(&"Box3DPhysicsServer3D")
	_backend_label.text = "Physics backend: %s    Extension loaded: %s" % [
		engine_name,
		"yes" if loaded else "no",
	]

	for demo in DEMOS:
		var button: Button = Button.new()
		button.text = demo["name"]
		button.pressed.connect(_on_demo_pressed.bind(demo["path"]))
		_buttons.add_child(button)

	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()


func _on_demo_pressed(path: String) -> void:
	get_tree().change_scene_to_file(path)
