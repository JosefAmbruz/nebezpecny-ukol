extends Node

func _ready() -> void:
	var world = load("res://src/world.tscn").instantiate()
	add_child(world)
	while world._director.active_level_id < 0:
		await get_tree().process_frame
	assert(world._game_hud._brush_icons.size() == 3)
	assert(world._player.visuals.get_balloon_anchor() != null)
	var civilian = world._director._active_civilians[0]
	civilian.interactable.complete_interaction(world._player)
	assert(world._broken_toothbrushes == 1)
	assert(world._director._death_mark_records.size() == 1)
	for i in range(2):
		world._director._active_civilians[0].interactable.complete_interaction(world._player)
	assert(world._match_ended and get_tree().paused)
	assert(world._game_hud.get_node("%Leaderboard").is_visible_in_tree())
	print("Merged match, visuals, death marks and toothbrush lives passed.")
	get_tree().quit()
