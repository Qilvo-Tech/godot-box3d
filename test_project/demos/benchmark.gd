class_name BenchmarkDemo
extends DemoBase

enum SpawnKind { BOXES, SPHERES, MIXED }

const BOX_SCENE: PackedScene = preload("res://demos/bench_box.tscn")
const SPHERE_SCENE: PackedScene = preload("res://demos/bench_sphere.tscn")
const WAVE_SIZE: int = 64
const WAVE_COLUMNS: int = 8
const SPAWN_SPACING: float = 0.75
const SPAWN_HEIGHT: float = 14.0
const BODY_CAP: int = 4096

@export var spawn_root: Node3D

var _kind: SpawnKind = SpawnKind.MIXED
var _smoothed_step_ms: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_spawn_wave()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		match key_event.keycode:
			KEY_R:
				_clear()
				return
			KEY_1:
				_kind = SpawnKind.BOXES
				return
			KEY_2:
				_kind = SpawnKind.SPHERES
				return
			KEY_3:
				_kind = SpawnKind.MIXED
				return
	super._unhandled_input(event)


func _process(_delta: float) -> void:
	var step_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_smoothed_step_ms = lerpf(_smoothed_step_ms, step_ms, 0.1)
	set_status(
		"Bodies: %d    FPS: %.1f    Physics: %.2f ms    Mode: %s\n"
		% [
			spawn_root.get_child_count(),
			Engine.get_frames_per_second(),
			_smoothed_step_ms,
			SpawnKind.keys()[_kind],
		]
		+ "[Space] spawn %d    [R] reset    [1] boxes [2] spheres [3] mixed" % WAVE_SIZE
	)


func _spawn_wave() -> void:
	if spawn_root.get_child_count() + WAVE_SIZE > BODY_CAP:
		return
	for i in WAVE_SIZE:
		var scene: PackedScene = _scene_for(i)
		var body: RigidBody3D = scene.instantiate()
		spawn_root.add_child(body)
		var column: int = i % WAVE_COLUMNS
		var row: int = i / WAVE_COLUMNS
		body.global_position = Vector3(
			(column - WAVE_COLUMNS * 0.5) * SPAWN_SPACING,
			SPAWN_HEIGHT + row * SPAWN_SPACING,
			(row - WAVE_COLUMNS * 0.5) * SPAWN_SPACING,
		)


func _scene_for(index: int) -> PackedScene:
	match _kind:
		SpawnKind.BOXES:
			return BOX_SCENE
		SpawnKind.SPHERES:
			return SPHERE_SCENE
		_:
			return BOX_SCENE if index % 2 == 0 else SPHERE_SCENE


func _clear() -> void:
	for child in spawn_root.get_children():
		child.queue_free()
