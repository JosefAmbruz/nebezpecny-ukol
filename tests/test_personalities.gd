extends Node3D

# Run with godot --headless --path . res://tests/test_personalities.tscn.
func _ready() -> void:
	var pool := preload("res://src/characters/default_appearance_pool.tres")
	var generated := CharacterGenerator.generate_assassins(pool, 6, 2, 3)
	var counts := {}
	for data in generated:
		counts[data.personality] = counts.get(data.personality, 0) + 1
	assert(counts.size() == 3 and not counts.has(CharacterData.Personality.NONE))
	assert(counts.values().all(func(n: int) -> bool: return n == 2))

	var plain := _spawn_assassin(CharacterData.Personality.NONE, 0.0)
	var aggressive := _spawn_assassin(CharacterData.Personality.AGGRESSIVE, 0.0)
	var patient := _spawn_assassin(CharacterData.Personality.PATIENT, 0.0)
	assert(aggressive.attack_duration < plain.attack_duration and aggressive._stalk_speed_factor > plain._stalk_speed_factor)
	assert(patient.detect_range > plain.detect_range and patient._stalk_time_limit > plain._stalk_time_limit)

	var player := Player.new()
	add_child(player)
	player._looking_right = true
	var skittish := _spawn_assassin(CharacterData.Personality.SKITTISH, 3.0)
	skittish.skittish_flee_chance_per_sec = 1000.0
	assert(skittish.alert_to_stalk(player))
	skittish._stalk_pause_timer = 0.0
	skittish._process_stalk(0.1)
	assert(skittish.state == NpcBase.State.FLEE)

	plain.position.x = 3.0
	assert(plain.alert_to_stalk(player))
	plain._stalk_pause_timer = 0.0
	plain._process_stalk(0.1)
	assert(plain.state == NpcBase.State.STALK)
	print("Assassin personalities passed.")
	get_tree().quit()


func _spawn_assassin(personality: CharacterData.Personality, x: float) -> NpcBase:
	var data := CharacterData.new()
	data.is_assassin = true
	data.personality = personality
	var npc := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	npc.apply_character_data(data)
	npc.position.x = x
	add_child(npc)
	npc.set_physics_process(false)
	return npc
