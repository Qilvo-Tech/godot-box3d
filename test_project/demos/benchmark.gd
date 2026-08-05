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


func _process(_delta: float) -> void:
	var step_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_smoothed_step_ms = lerpf(_smoothed_step_ms, step_ms, 0.1)
	set_status("Bodies: %d    FPS: %.1f    Physics: %.2f ms    Mode: %s" % [
		spawn_root.get_child_count(),
		Engine.get_frames_per_second(),
		_smoothed_step_ms,
		SpawnKind.keys()[_kind],
	])


func restart() -> void:
	_clear()


func _action_buttons() -> Array[Array]:
	return [
		["demo_action", "Spawn %d" % WAVE_SIZE],
		["demo_mode_1", "Boxes"],
		["demo_mode_2", "Spheres"],
		["demo_mode_3", "Mixed"],
	]


func _on_action(action: String) -> void:
	match action:
		"demo_action":
			_spawn_wave()
		"demo_mode_1":
			_kind = SpawnKind.BOXES
		"demo_mode_2":
			_kind = SpawnKind.SPHERES
		"demo_mode_3":
			_kind = SpawnKind.MIXED


func _spawn_wave() -> void:
	if spawn_root.get_child_count() + WAVE_SIZE > BODY_CAP:
		return
	for i in WAVE_SIZE:
		var body: RigidBody3D = _scene_for(i).instantiate()
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
