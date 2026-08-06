class_name BenchmarkDemo
extends DemoBase

## Deterministic spawn benchmark. Every body is placed on a fixed lattice from a fixed seed,
## so a run is identical on any physics backend and the only variable is the backend itself.

enum State { IDLE, RUNNING, FINISHED }

const BATCH_SCENES: Array[String] = [
	"res://demos/bench_box.tscn",
	"res://demos/bench_sphere.tscn",
]
const BUDGET_MS: float = 16.66
const LATTICE_COLUMNS: int = 6
const LATTICE_ROWS: int = 6
const SPAWN_SPACING: float = 0.62
const SPAWN_HEIGHT: float = 9.0
const LAYER_HEIGHT: float = 0.62
const SETTLE_FRAMES: int = 12
const GRAPH_SAMPLES: int = 240
const RNG_SEED: int = 20260805

@export var spawn_root: Node3D
@export var graph: Control
@export var batch_size: SpinBox
@export var start_button: Button
@export var export_button: Button
@export var readout: Label

var _state: State = State.IDLE
var _layer: int = 0
var _frames_since_spawn: int = 0
var _budget_body_count: int = 0
var _peak_step_ms: float = 0.0
var _samples: PackedFloat32Array = PackedFloat32Array()
var _counts: PackedInt32Array = PackedInt32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	start_button.pressed.connect(_on_start_pressed)
	export_button.pressed.connect(_on_export_pressed)
	_reset()


func _physics_process(_delta: float) -> void:
	var step_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var body_count: int = spawn_root.get_child_count()

	if _state == State.RUNNING:
		_record(step_ms, body_count)
		if step_ms > BUDGET_MS and _budget_body_count == 0 and body_count > 0:
			_budget_body_count = body_count
			_state = State.FINISHED
			start_button.text = "Run again"
		else:
			_frames_since_spawn += 1
			if _frames_since_spawn >= SETTLE_FRAMES:
				_frames_since_spawn = 0
				_spawn_layer()

	_peak_step_ms = maxf(_peak_step_ms, step_ms)
	_update_readout(step_ms, body_count)
	graph.queue_redraw()


func _record(step_ms: float, body_count: int) -> void:
	_samples.append(step_ms)
	_counts.append(body_count)
	if _samples.size() > GRAPH_SAMPLES:
		_samples.remove_at(0)
		_counts.remove_at(0)


# Fixed lattice from a fixed seed: identical placement on every backend and every run.
func _spawn_layer() -> void:
	var count: int = int(batch_size.value)
	for i in count:
		var scene_path: String = BATCH_SCENES[i % BATCH_SCENES.size()]
		var body: RigidBody3D = load(scene_path).instantiate()
		spawn_root.add_child(body)
		var column: int = i % LATTICE_COLUMNS
		var row: int = (i / LATTICE_COLUMNS) % LATTICE_ROWS
		var stack: int = i / (LATTICE_COLUMNS * LATTICE_ROWS)
		body.global_position = Vector3(
			(column - (LATTICE_COLUMNS - 1) * 0.5) * SPAWN_SPACING,
			SPAWN_HEIGHT + (stack + _layer) * LAYER_HEIGHT,
			(row - (LATTICE_ROWS - 1) * 0.5) * SPAWN_SPACING,
		)
		# A tiny seeded jitter stops a perfect lattice resting in a degenerate stack.
		body.global_position += Vector3(
			_rng.randf_range(-0.01, 0.01),
			0.0,
			_rng.randf_range(-0.01, 0.01),
		)
	_layer += 1


func _update_readout(step_ms: float, body_count: int) -> void:
	var memory_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	readout.text = "\n".join([
		"Backend      %s" % ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT"),
		"Bodies       %d" % body_count,
		"FPS          %.1f" % Engine.get_frames_per_second(),
		"Physics      %.2f ms  (peak %.2f)" % [step_ms, _peak_step_ms],
		"Memory       %.1f MB" % memory_mb,
		"Budget       %s" % _budget_text(),
	])


func _budget_text() -> String:
	if _budget_body_count > 0:
		return "%d bodies exceeded %.2f ms" % [_budget_body_count, BUDGET_MS]
	if _state == State.RUNNING:
		return "under %.2f ms" % BUDGET_MS
	return "not started"


func _on_start_pressed() -> void:
	if _state == State.RUNNING:
		return
	_reset()
	_state = State.RUNNING
	start_button.text = "Running"


func _on_export_pressed() -> void:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var backend: String = str(
		ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT")
	).replace(" ", "_").replace("(", "").replace(")", "")
	var base: String = "user://benchmark_%s_%s" % [backend, stamp]

	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("%s.png" % base)

	var report: FileAccess = FileAccess.open("%s.csv" % base, FileAccess.WRITE)
	report.store_line("backend,%s" % backend)
	report.store_line("budget_ms,%.2f" % BUDGET_MS)
	report.store_line("bodies_over_budget,%d" % _budget_body_count)
	report.store_line("peak_step_ms,%.3f" % _peak_step_ms)
	report.store_line("bodies,step_ms")
	for i in _samples.size():
		report.store_line("%d,%.3f" % [_counts[i], _samples[i]])
	report.close()

	set_status("Exported to %s" % ProjectSettings.globalize_path("%s.png" % base))


func _reset() -> void:
	for child in spawn_root.get_children():
		child.queue_free()
	_state = State.IDLE
	_layer = 0
	_frames_since_spawn = 0
	_budget_body_count = 0
	_peak_step_ms = 0.0
	_samples.clear()
	_counts.clear()
	_rng.seed = RNG_SEED
	start_button.text = "Start benchmark"


func restart() -> void:
	_reset()
