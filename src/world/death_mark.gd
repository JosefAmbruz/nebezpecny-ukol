class_name DeathMark
extends Node3D

signal inspected(mark: DeathMark)

@export var sprite: Sprite3D
@export var interactable: InteractableNpc
@export var info_label: Label3D
@export var info_visible_duration: float = 4.0

var victim_name: String = "Neznámý"
var was_assassin: bool = false
var frame_index: int = -1
var is_inspected: bool = false

var _hide_label_timer: float = 0.0


func _ready() -> void:
	if sprite:
		if frame_index < 0:
			frame_index = randi_range(0, maxi(0, sprite.hframes - 1))
		sprite.frame = clampi(frame_index, 0, maxi(0, sprite.hframes - 1))

	if interactable:
		interactable.interaction_kind = InteractableNpc.InteractionKind.QUEST

	if info_label:
		info_label.visible = false
		_update_label_text()


func _process(delta: float) -> void:
	if _hide_label_timer > 0.0:
		_hide_label_timer -= delta
		if _hide_label_timer <= 0.0 and info_label:
			info_label.visible = false


func setup(p_victim_name: String, p_was_assassin: bool, p_frame_index: int = -1, p_inspected: bool = false) -> void:
	victim_name = p_victim_name
	was_assassin = p_was_assassin
	frame_index = p_frame_index
	is_inspected = p_inspected
	if is_node_ready():
		if sprite and frame_index >= 0:
			sprite.frame = clampi(frame_index, 0, maxi(0, sprite.hframes - 1))
		_update_label_text()


func can_be_interacted_by(actor: Node3D) -> bool:
	return actor is Player


func on_interaction_completed(_actor: Node3D, _kind: InteractableNpc.InteractionKind) -> void:
	is_inspected = true
	_update_label_text()
	if info_label:
		info_label.visible = true
		_hide_label_timer = info_visible_duration
	inspected.emit(self)


func _update_label_text() -> void:
	if not info_label:
		return
	if was_assassin:
		info_label.text = "Zde zemřel:\n%s" % victim_name
	else:
		info_label.text = "Zde zemřel:\nCivilista"
