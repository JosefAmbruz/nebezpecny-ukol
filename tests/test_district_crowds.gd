extends Node

# Run with godot --headless --path . res://tests/test_district_crowds.tscn.
func _ready() -> void:
	var world := preload("res://src/world.tscn").instantiate()
	world.total_assassins = 0
	world.background_music = null
	add_child(world)
	while world._director.active_level_id < 0:
		await get_tree().process_frame
	world._levels[1].ambient_stream = null
	assert(world._director._active_civilians.size() == 8)
	world._director.activate_level(1)
	assert(world._director._active_civilians.size() == 10)
	world._director.activate_level(2)
	assert(world._director._active_civilians.size() == 7)
	world._director.activate_level(1)
	assert(world._director._active_civilians.size() == 10)
	world.queue_free()
	await get_tree().process_frame
	print("Districts spawn their crowds correctly on entry and return.")
	get_tree().quit()
