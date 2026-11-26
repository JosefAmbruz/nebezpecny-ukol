@tool
class_name LevelZone
extends Node3D

@export var level_id: int = 0
@export var level_name: String = "Level 1"
@export var civilian_count: int = 4
@export var floor_y: float = 0.6

@export_group("Editor Bounds (Marker3D)")
@export var left_bound: Marker3D
@export var right_bound: Marker3D
@export var quest_npc_spawn: Marker3D

@export_group("Quest NPC")
@export var quest_npc_role: QuestNpc.Role = QuestNpc.Role.PADRINO_PACATO
@export var quest_npc_appearance: CharacterAppearance
@export var quest_npc_voice: AudioStream

@export_group("Audio (Brno Ambient & Hudba)")
@export var ambient_stream: AudioStream
@export var ambient_oneshots: AudioStream
@export var music_override: AudioStream

@export_group("Editor Preview")
@export var preview_color: Color = Color(0.25, 0.85, 0.55, 1.0)
@export var preview_height: float = 4.5
@export var preview_depth: float = 10.0

## Automaticky počítané hranice z Marker3D (nebo fallback -15..15, pokud chybí).
var min_x: float:
	get:
		var lb := _resolve_left_bound()
		var rb := _resolve_right_bound()
		if lb and rb:
			return minf(lb.global_position.x, rb.global_position.x)
		if lb:
			return lb.global_position.x
		return global_position.x - 15.0

var max_x: float:
	get:
		var lb := _resolve_left_bound()
		var rb := _resolve_right_bound()
		if lb and rb:
			return maxf(lb.global_position.x, rb.global_position.x)
		if rb:
			return rb.global_position.x
		return global_position.x + 15.0

var quest_npc_start_x: float:
	get:
		var qs := _resolve_quest_spawn()
		if qs:
			return qs.global_position.x
		return (min_x + max_x) * 0.5

var _preview_mesh_instance: MeshInstance3D = null
var _preview_mesh: ImmediateMesh = null
var _preview_material: StandardMaterial3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_preview()
		_redraw_editor_preview()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_redraw_editor_preview()


func contains_x(x: float) -> bool:
	return x >= min_x and x < max_x


func get_random_x(margin: float = 2.0) -> float:
	var lo := minf(min_x + margin, max_x - margin)
	var hi := maxf(min_x + margin, max_x - margin)
	return randf_range(lo, hi)


func _resolve_left_bound() -> Marker3D:
	if is_instance_valid(left_bound):
		return left_bound
	return get_node_or_null("LeftBound") as Marker3D


func _resolve_right_bound() -> Marker3D:
	if is_instance_valid(right_bound):
		return right_bound
	return get_node_or_null("RightBound") as Marker3D


func _resolve_quest_spawn() -> Marker3D:
	if is_instance_valid(quest_npc_spawn):
		return quest_npc_spawn
	return get_node_or_null("QuestNpcSpawn") as Marker3D


func _setup_editor_preview() -> void:
	if is_instance_valid(_preview_mesh_instance):
		return
	_preview_mesh = ImmediateMesh.new()
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.albedo_color = preview_color

	_preview_mesh_instance = MeshInstance3D.new()
	_preview_mesh_instance.name = "_EditorBoundsPreview"
	_preview_mesh_instance.mesh = _preview_mesh
	_preview_mesh_instance.material_override = _preview_material
	_preview_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview_mesh_instance)


func _redraw_editor_preview() -> void:
	if not is_instance_valid(_preview_mesh_instance) or not _preview_mesh:
		_setup_editor_preview()
	if _preview_material:
		_preview_material.albedo_color = preview_color

	var local_min_x := to_local(Vector3(min_x, floor_y, 0.0)).x
	var local_max_x := to_local(Vector3(max_x, floor_y, 0.0)).x
	var y0 := floor_y - global_position.y
	var y1 := y0 + preview_height
	var z0 := -preview_depth * 0.5
	var z1 := preview_depth * 0.5

	_preview_mesh.clear_surfaces()
	_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var corners := [
		Vector3(local_min_x, y0, z0),
		Vector3(local_max_x, y0, z0),
		Vector3(local_max_x, y0, z1),
		Vector3(local_min_x, y0, z1),
		Vector3(local_min_x, y1, z0),
		Vector3(local_max_x, y1, z0),
		Vector3(local_max_x, y1, z1),
		Vector3(local_min_x, y1, z1),
	]
	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]
	for e in edges:
		_preview_mesh.surface_add_vertex(corners[e[0]])
		_preview_mesh.surface_add_vertex(corners[e[1]])

	_preview_mesh.surface_end()
