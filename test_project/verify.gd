extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	print("has demo_orbit: %s" % InputMap.has_action("demo_orbit"))
	for a in ["demo_orbit","demo_zoom_in","demo_zoom_out"]:
		if InputMap.has_action(a):
			for e in InputMap.action_get_events(a):
				print("%s -> %s" % [a, e.as_text()])
	# Simulate: does a right-press match the action?
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	print("right-press is_action_pressed(demo_orbit): %s" % ev.is_action_pressed("demo_orbit"))
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	print("wheel-up is_action_pressed(demo_zoom_in): %s" % wheel.is_action_pressed("demo_zoom_in"))
	quit(0)
