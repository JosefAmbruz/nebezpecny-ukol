class_name OffScreenDirector
extends Node

signal npc_died(npc: NpcBase, killer: Node3D)
signal quest_npc_interacted(npc: QuestNpc, actor: Node3D, role: QuestNpc.Role)
signal level_activated(zone: LevelZone)

const NPC_BASE_SCENE: PackedScene = preload("res://src/characters/npc_base.tscn")
const QUEST_NPC_SCENE: PackedScene = preload("res://src/characters/quest_npc.tscn")
const DEATH_MARK_SCENE: PackedScene = preload("res://src/world/death_mark.tscn")

@export var tick_interval: float = 5.0
@export var freeze_ramp_seconds: float = 25.0

@export_group("Unique Z-Lanes (proti prolínání 3D hlav)")
@export var z_lane_spacing: float = 1.25
@export var z_min: float = -4.5
@export var z_max: float = 4.5
@export var player_reserved_z: float = 2.4

var active_level_id: int = -1

var _levels: Array[LevelZone] = []
var _pool: AppearancePool = null
var _reserved_signatures: Dictionary = {}
var _spawn_parent: Node3D = null

## Pole slovníků: { "data": CharacterData, "level_id": int, "x_pos": float, "time_frozen": float, "node": NpcBase }
var _assassin_records: Array[Dictionary] = []
var _active_civilians: Array[NpcBase] = []
var _active_quest_npc: QuestNpc = null
var _quest_npc_x_by_level: Dictionary = {} # level_id -> float
var _death_mark_records: Array[Dictionary] = []
var _active_death_marks: Array[DeathMark] = []

var _available_z_lanes: Array[float] = []
var _overflow_lane_index: int = 0
var _tick_timer: Timer = null


func _ready() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = tick_interval
	_tick_timer.autostart = false
	_tick_timer.timeout.connect(_on_director_tick)
	add_child(_tick_timer)


func initialize(
	levels: Array[LevelZone],
	assassins: Array[CharacterData],
	pool: AppearancePool,
	reserved_signatures: Dictionary,
	spawn_parent: Node3D,
	player_z: float
) -> void:
	_levels = levels
	_levels.sort_custom(func(a: LevelZone, b: LevelZone) -> bool: return a.level_id < b.level_id)
	_pool = pool
	_reserved_signatures = reserved_signatures
	_spawn_parent = spawn_parent
	player_reserved_z = player_z

	_quest_npc_x_by_level.clear()
	for zone in _levels:
		_quest_npc_x_by_level[zone.level_id] = zone.quest_npc_start_x

	_assassin_records.clear()
	for data in assassins:
		var zone := _get_zone(data.current_level_id)
		var start_x: float
		if data.can_do_quest and zone:
			# K assassinů začíná na startu u Padrina Pacata
			start_x = clampf(zone.quest_npc_start_x + randf_range(1.5, 5.5), zone.min_x + 1.5, zone.max_x - 1.5)
		elif zone:
			start_x = zone.get_random_x()
		else:
			start_x = 0.0

		_assassin_records.append({
			"data": data,
			"level_id": data.current_level_id,
			"x_pos": start_x,
			"time_frozen": 0.0,
			"node": null,
		})

	_tick_timer.start()


func activate_level(new_level_id: int) -> void:
	if new_level_id == active_level_id:
		return

	var zone := _get_zone(new_level_id)
	if not zone or not _spawn_parent:
		return

	_despawn_active_level()
	active_level_id = new_level_id
	_reset_z_lanes()

	_spawn_quest_npc_for_zone(zone)
	_spawn_assassins_for_zone(zone)
	_spawn_civilians_for_zone(zone)
	_spawn_death_marks_for_zone(zone)

	level_activated.emit(zone)


func get_zone_for_x(x: float) -> LevelZone:
	for zone in _levels:
		if zone.contains_x(x):
			return zone
	if _levels.is_empty():
		return null
	return _levels[0] if x < _levels[0].min_x else _levels[-1]


func _despawn_active_level() -> void:
	# Uložíme pozice a stav aktivních assassinů zpět do zmraženého poolu
	for rec in _assassin_records:
		var npc := rec["node"] as NpcBase
		if is_instance_valid(npc):
			rec["x_pos"] = npc.global_position.x
			rec["time_frozen"] = 0.0
			npc.queue_free()
		rec["node"] = null

	for civ in _active_civilians:
		if is_instance_valid(civ):
			civ.queue_free()
	_active_civilians.clear()

	if is_instance_valid(_active_quest_npc):
		if _active_quest_npc.role != QuestNpc.Role.PADRINO_PACATO:
			_quest_npc_x_by_level[active_level_id] = _active_quest_npc.global_position.x
		_active_quest_npc.queue_free()
	_active_quest_npc = null

	for mark in _active_death_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_active_death_marks.clear()


func _spawn_quest_npc_for_zone(zone: LevelZone) -> void:
	var qnpc := QUEST_NPC_SCENE.instantiate() as QuestNpc
	qnpc.role = zone.quest_npc_role
	if zone.quest_npc_appearance:
		qnpc.appearance = zone.quest_npc_appearance
	if zone.quest_npc_voice:
		qnpc.voice_on_interact = zone.quest_npc_voice

	qnpc.level_min_x = zone.min_x + 1.0
	qnpc.level_max_x = zone.max_x - 1.0

	var spawn_x: float = _quest_npc_x_by_level.get(zone.level_id, zone.quest_npc_start_x)
	var lane_z := _allocate_z_lane()
	_spawn_parent.add_child(qnpc)
	qnpc.global_position = Vector3(spawn_x, zone.floor_y, lane_z)
	qnpc.quest_interacted.connect(_on_quest_npc_interacted)
	_active_quest_npc = qnpc


func _spawn_assassins_for_zone(zone: LevelZone) -> void:
	for rec in _assassin_records:
		var data := rec["data"] as CharacterData
		if not data or not data.is_alive:
			continue
		if rec["level_id"] != zone.level_id:
			continue

		var npc := NPC_BASE_SCENE.instantiate() as NpcBase
		npc.level_min_x = zone.min_x + 0.8
		npc.level_max_x = zone.max_x - 0.8
		npc.can_flee_left = zone.level_id > 0
		npc.can_flee_right = zone.level_id < _levels.size() - 1
		npc.apply_character_data(data)

		var lane_z := _allocate_z_lane()
		_spawn_parent.add_child(npc)
		npc.global_position = Vector3(rec["x_pos"], zone.floor_y, lane_z)
		npc.died.connect(_on_npc_died)
		npc.fled_level.connect(_on_assassin_fled)
		rec["node"] = npc


func _spawn_civilians_for_zone(zone: LevelZone) -> void:
	for i in range(zone.civilian_count):
		var civ := NPC_BASE_SCENE.instantiate() as NpcBase
		civ.is_assassin = false
		civ.display_name = "Civilista"
		civ.level_min_x = zone.min_x + 0.8
		civ.level_max_x = zone.max_x - 0.8
		civ.appearance = CharacterGenerator.generate_civilian_appearance(_pool, _reserved_signatures)

		var lane_z := _allocate_z_lane()
		_spawn_parent.add_child(civ)
		civ.global_position = Vector3(zone.get_random_x(), zone.floor_y, lane_z)
		civ.died.connect(_on_npc_died)
		_active_civilians.append(civ)


func _on_director_tick() -> void:
	if _levels.is_empty():
		return

	# Lehký off-screen pohyb Madriny a Morettiho
	for zone in _levels:
		if zone.level_id == 0 or zone.level_id == active_level_id:
			continue
		_quest_npc_x_by_level[zone.level_id] = zone.get_random_x(2.5)

	# Krokování zmražených assassinů mimo aktivní level
	for rec in _assassin_records:
		var data := rec["data"] as CharacterData
		if not data or not data.is_alive:
			continue
		if rec["level_id"] == active_level_id:
			continue

		rec["time_frozen"] = float(rec["time_frozen"]) + tick_interval
		var chance := clampf(float(rec["time_frozen"]) / maxf(1.0, freeze_ramp_seconds), 0.1, 0.85)
		if randf() >= chance:
			continue

		rec["time_frozen"] = 0.0
		_step_frozen_assassin(rec)


func _step_frozen_assassin(rec: Dictionary) -> void:
	var data := rec["data"] as CharacterData
	var current_lvl: int = rec["level_id"]

	# Assassini s povoleným questem se postupně snaží získat balónek (L2) -> baterku (L3) -> odevzdat (L1)
	if data.can_do_quest and data.quest_stage != CharacterData.QuestStage.COMPLETED:
		match data.quest_stage:
			CharacterData.QuestStage.NONE:
				if current_lvl == 1:
					data.quest_stage = CharacterData.QuestStage.HAS_BALLOON
					return
				_move_record_toward_level(rec, 1)
				return
			CharacterData.QuestStage.HAS_BALLOON:
				if current_lvl == 2:
					data.quest_stage = CharacterData.QuestStage.HAS_BATTERY
					return
				_move_record_toward_level(rec, 2)
				return
			CharacterData.QuestStage.HAS_BATTERY:
				if current_lvl == 0:
					data.quest_stage = CharacterData.QuestStage.COMPLETED
					return
				_move_record_toward_level(rec, 0)
				return

	# Jinak náhodný přesun do napojeného sousedního levelu
	var neighbors: Array[int] = []
	if current_lvl > 0:
		neighbors.append(current_lvl - 1)
	if current_lvl < _levels.size() - 1:
		neighbors.append(current_lvl + 1)

	if not neighbors.is_empty():
		var target_lvl: int = neighbors.pick_random()
		_assign_record_to_level(rec, target_lvl)


func _move_record_toward_level(rec: Dictionary, target_lvl: int) -> void:
	var current_lvl: int = rec["level_id"]
	var step := 1 if target_lvl > current_lvl else -1
	var next_lvl := clampi(current_lvl + step, 0, _levels.size() - 1)
	_assign_record_to_level(rec, next_lvl)


func _assign_record_to_level(rec: Dictionary, target_lvl: int) -> void:
	var zone := _get_zone(target_lvl)
	if not zone:
		return
	var data := rec["data"] as CharacterData
	rec["level_id"] = target_lvl
	data.current_level_id = target_lvl
	rec["x_pos"] = zone.get_random_x()


func _on_assassin_fled(npc: NpcBase, exit_side: int) -> void:
	if not npc.character_data:
		return
	for rec in _assassin_records:
		if rec["data"] == npc.character_data:
			rec["node"] = null
			rec["time_frozen"] = 0.0
			var target_lvl := clampi(active_level_id + exit_side, 0, _levels.size() - 1)
			if target_lvl == active_level_id and _levels.size() > 1:
				target_lvl = 1 if active_level_id == 0 else active_level_id - 1
			_assign_record_to_level(rec, target_lvl)
			break


func spawn_death_mark(world_pos: Vector3, victim_name: String, was_assassin: bool) -> void:
	if not _spawn_parent:
		return
	var zone := _get_zone(active_level_id)
	var floor_y := zone.floor_y if zone else world_pos.y
	var record := {
		"level_id": active_level_id,
		"x_pos": world_pos.x,
		"y_pos": floor_y,
		"z_pos": world_pos.z,
		"frame": randi_range(0, 5),
		"victim_name": victim_name,
		"was_assassin": was_assassin,
	}
	_death_mark_records.append(record)
	_instantiate_death_mark(record)


func _spawn_death_marks_for_zone(zone: LevelZone) -> void:
	for record in _death_mark_records:
		if record["level_id"] == zone.level_id:
			_instantiate_death_mark(record)


func _instantiate_death_mark(record: Dictionary) -> void:
	var mark := DEATH_MARK_SCENE.instantiate() as DeathMark
	mark.setup(record["victim_name"], record["was_assassin"], record["frame"])
	_spawn_parent.add_child(mark)
	mark.global_position = Vector3(record["x_pos"], record["y_pos"], record["z_pos"])
	_active_death_marks.append(mark)


func _on_npc_died(npc: NpcBase, killer: Node3D) -> void:
	if npc.character_data:
		npc.character_data.is_alive = false
		for rec in _assassin_records:
			if rec["data"] == npc.character_data:
				rec["node"] = null
				break

	var victim_name := npc.character_data.display_name if npc.character_data else npc.display_name
	spawn_death_mark(npc.global_position, victim_name, npc.is_assassin)
	npc_died.emit(npc, killer)


func _on_quest_npc_interacted(npc: QuestNpc, actor: Node3D, role: QuestNpc.Role) -> void:
	quest_npc_interacted.emit(npc, actor, role)


func _get_zone(level_id: int) -> LevelZone:
	for zone in _levels:
		if zone.level_id == level_id:
			return zone
	return null


func _reset_z_lanes() -> void:
	_available_z_lanes.clear()
	_overflow_lane_index = 0
	var z := z_min
	while z <= z_max + 0.001:
		if absf(z - player_reserved_z) >= z_lane_spacing * 0.85:
			_available_z_lanes.append(z)
		z += z_lane_spacing
	_available_z_lanes.shuffle()


func _allocate_z_lane() -> float:
	if not _available_z_lanes.is_empty():
		return _available_z_lanes.pop_back()
	_overflow_lane_index += 1
	return z_min - float(_overflow_lane_index) * z_lane_spacing
