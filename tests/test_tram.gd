extends Node

# Run with godot --headless --path . res://tests/test_tram.tscn.
func _ready() -> void:
	var world := preload("res://src/world.tscn").instantiate()
	world.total_assassins = 3
	world.quest_assassins = 0
	world.background_music = null
	add_child(world)
	while world._director.active_level_id < 0:
		await get_tree().process_frame
	var director: OffScreenDirector = world._director
	var zone := director._get_zone(director.active_level_id)
	var player_x: float = world._player.global_position.x
	var far_x := zone.max_x - 1.0 if zone.max_x - player_x > player_x - zone.min_x else zone.min_x + 1.0
	assert(absf(far_x - player_x) > director.tram_offscreen_distance)

	for rec in director._assassin_records:
		if is_instance_valid(rec["node"]):
			rec["node"].free()
		rec["node"] = null
	var arriving: Dictionary = director._assassin_records[0]
	var distant: Dictionary = director._assassin_records[1]
	var leaving: Dictionary = director._assassin_records[2]
	director._assign_record_to_level(arriving, director.active_level_id + 1)
	director._assign_record_to_level(distant, director.active_level_id + 2)
	director._assign_record_to_level(leaving, director.active_level_id)
	leaving["x_pos"] = far_x
	director._spawn_assassin(leaving, zone)
	var leaving_node: NpcBase = leaving["node"]

	var civilians: Array[NpcBase] = director._active_civilians.duplicate()
	for civ in civilians:
		civ.global_position.x = player_x + 1.0
	civilians[0].global_position.x = far_x
	var crowd_before := civilians.size()

	director.trigger_tram()
	assert(director._active_civilians.size() == crowd_before - 1 + director.tram_passengers_in)
	assert(civilians[0].is_queued_for_deletion() and not civilians[1].is_queued_for_deletion())
	assert(leaving_node.is_queued_for_deletion() and leaving["node"] == null and leaving["level_id"] != director.active_level_id)
	assert(arriving["level_id"] == director.active_level_id and is_instance_valid(arriving["node"]))
	assert(absf(arriving["node"].global_position.x - player_x) > director.tram_offscreen_distance)
	assert(distant["level_id"] == director.active_level_id + 2 and distant["node"] == null)
	assert(world._game_hud.get_node("%EventLabel").visible)

	var victim: NpcBase = civilians[1]
	victim.on_interaction_completed(world._player, InteractableNpc.InteractionKind.ASSASSINATE)
	assert(victim.witness_count == 0 and world._player.heat_time_left == 0.0)

	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	assert(NpcBase.noise_cover_until_msec == 0)
	print("Tram event passed.")
	get_tree().quit()
