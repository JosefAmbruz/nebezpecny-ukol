extends SceneTree

# Run with godot --headless --path . --script res://tests/test_npc_behavior.gd.


func _initialize() -> void:
	create_timer(3.0).timeout.connect(quit.bind(1))
	_run_test.call_deferred()


func _run_test() -> void:
	var player := Player.new()
	root.add_child(player)
	var victim := _spawn_npc(0.5)
	var witness := _spawn_npc(2.0)
	var distant_civilian := _spawn_npc(12.0)
	var assassin := _spawn_npc(-1.0, true)
	var distant_assassin := _spawn_npc(11.0, true)

	victim.on_interaction_completed(player, InteractableNpc.InteractionKind.ASSASSINATE)
	assert(witness.state == NpcBase.State.EVADE and witness._evade_target_x > witness.position.x)
	assert(distant_civilian.state == NpcBase.State.WANDER)
	assert(assassin.state == NpcBase.State.STALK and assassin._stalk_target == player)
	assert(distant_assassin.state == NpcBase.State.WANDER)

	witness._process_evade(0.1)
	assert(witness.velocity.x > witness.walk_speed)
	witness._process_evade(3.0)
	assert(witness.state == NpcBase.State.WANDER and witness.velocity.x == 0.0)
	witness.on_caught_assassination_attempt(player)
	assert(witness.state == NpcBase.State.EVADE)

	player._looking_right = false
	assassin._process_stalk(0.1)
	assert(assassin.state == NpcBase.State.STALK and assassin.velocity.x < 0.0)
	player._looking_right = true
	assassin._process_stalk(0.1)
	assert(assassin.state == NpcBase.State.ATTACK)
	player.position.x = 12.0
	assassin._process_attack(0.1)
	assassin._process_stalk(0.1)
	assert(assassin.state == NpcBase.State.WANDER and assassin._stalk_target == null)
	assert(not assassin.alert_to_stalk(player))

	player.position.x = 0.0
	distant_assassin.position.x = -5.0
	distant_assassin.has_balloon = true
	assassin._attack_cooldown = 0.0
	assassin.stalk_trigger_chance_per_sec = 1000.0
	assassin._try_acquire_stalk_target(0.1)
	assert(assassin._stalk_target == distant_assassin)
	distant_assassin._is_leaning = true
	assassin._process_stalk(0.1)
	assert(assassin.state == NpcBase.State.WANDER)

	distant_civilian.position.x = distant_civilian.level_max_x
	distant_civilian._pick_new_wander_target()
	assert(distant_civilian._wander_target_x < distant_civilian.position.x)
	print("Civilian reactions, local alerts, target selection, stalking, and boundary wandering passed.")
	quit()


func _spawn_npc(x: float, assassin: bool = false) -> NpcBase:
	var npc := NpcBase.new()
	npc.position.x = x
	npc.is_assassin = assassin
	root.add_child(npc)
	return npc
