class_name DemoBase
extends Node3D

## Base for every demo scene. Owns the shared HUD and the return-to-hub shortcut so each
## demo scene only has to describe its own physics setup.

signal hub_requested

const HUB_SCENE: String = "res://main.tscn"

@export_multiline var description: String = ""
## Assigned in each demo scene; unique names do not cross an instanced scene boundary.
@export var hud: Node

var _title_label: Label
var _description_label: Label
var _status_label: Label


func _ready() -> void:
	if hud == null:
		return
	_title_label = hud.get_node("%TitleLabel")
	_description_label = hud.get_node("%DescriptionLabel")
	_status_label = hud.get_node("%StatusLabel")
	_title_label.text = name.capitalize()
	_description_label.text = description
	_status_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return_to_hub()


func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func return_to_hub() -> void:
	hub_requested.emit()
	# Running a demo standalone with F6 has no hub to go back to.
	if ResourceLoader.exists(HUB_SCENE):
		get_tree().change_scene_to_file(HUB_SCENE)
