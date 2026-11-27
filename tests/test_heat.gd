extends Node3D

# Run with godot --headless --path . res://tests/test_heat.tscn.
func _ready() -> void:
	var player := Player.new()
	add_child(player)
	var witness := _spawn_npc(2.0)
	var assassin := _spawn_npc(-9.0, true)
	var base_range := assassin._detect_range_for(player)

	var isolated := _spawn_npc(-20.0)
	isolated.on_interaction_completed(player, InteractableNpc.InteractionKind.ASSASSINATE)
	assert(player.heat_time_left == 0.0)

	var victim := _spawn_npc(0.5)
	victim.on_interaction_completed(player, InteractableNpc.InteractionKind.ASSASSINATE)
	assert(witness.state == NpcBase.State.EVADE and player.heat_time_left == player.heat_duration)
	assert(is_equal_approx(assassin._detect_range_for(player), base_range * assassin.heat_detect_range_multiplier))
	# Assassin 9 m daleko je mimo běžný dosah, ale během rozruchu hráče najde.
	assassin.stalk_trigger_chance_per_sec = 1000.0
	assassin._try_acquire_stalk_target(0.1)
	assert(assassin.state == NpcBase.State.STALK and assassin._stalk_target == player)

	player._physics_process(1.0)
	assert(is_equal_approx(player.heat_time_left, player.heat_duration - 1.0))
	player._is_leaning = true
	player._physics_process(1.0)
	assert(is_equal_approx(player.heat_time_left, player.heat_duration - 1.0 - player.heat_hidden_decay_multiplier))
	player.clear_heat()
	assert(is_equal_approx(assassin._detect_range_for(player), base_range))
	print("Heat after witnessed kills passed.")
	get_tree().quit()


func _spawn_npc(x: float, assassin: bool = false) -> NpcBase:
	var npc := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	npc.position.x = x
	npc.is_assassin = assassin
	add_child(npc)
	npc.set_physics_process(false)
	return npc
