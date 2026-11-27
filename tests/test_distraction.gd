extends Node3D

# Run with godot --headless --path . res://tests/test_distraction.tscn.
func _ready() -> void:
	var player := Player.new()
	add_child(player)
	player.distractions_left = 1
	var near := _spawn_npc(2.0)
	var far := _spawn_npc(9.0)
	var stalker := _spawn_npc(1.0, true)
	near._looking_right = false
	stalker._stalk_target = player
	stalker.state = NpcBase.State.STALK
	assert(near.is_looking_at(player))

	assert(player.throw_distraction(Vector3(4.0, 0.0, 0.0)))
	assert(player.distractions_left == 0 and not player.throw_distraction(Vector3.ZERO))
	assert(near._distract_time_left > 0.0 and far._distract_time_left == 0.0)
	assert(stalker._distract_time_left > 0.0)
	near._physics_process(0.1)
	stalker._physics_process(0.1)
	assert(near._looking_right and not near.is_looking_at(player) and near.velocity.x == 0.0)
	assert(stalker.state == NpcBase.State.STALK and stalker.velocity.x == 0.0)

	near._physics_process(player.distraction_duration)
	near._physics_process(0.1)
	assert(near._distract_time_left <= 0.0 and near.state == NpcBase.State.WANDER)

	var dead := _spawn_npc(3.0)
	dead.state = NpcBase.State.DEAD
	dead.distract(3.0, 1.0)
	assert(dead._distract_time_left == 0.0)
	print("Coin distraction passed.")
	get_tree().quit()


func _spawn_npc(x: float, assassin: bool = false) -> NpcBase:
	var npc := preload("res://src/characters/npc_base.tscn").instantiate() as NpcBase
	npc.position.x = x
	npc.is_assassin = assassin
	add_child(npc)
	npc.set_physics_process(false)
	return npc
