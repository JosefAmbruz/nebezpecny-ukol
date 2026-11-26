class_name InteractableNpc
extends Area3D

enum InteractionKind {
	ASSASSINATE,
	QUEST,
}

signal interaction_completed(actor: Node3D)
signal caught_attempt(attacker: Node3D)

@export var interaction_kind: InteractionKind = InteractionKind.ASSASSINATE
@export var interaction_duration: float = 1.6
@export var character_root: Node3D


func _ready() -> void:
	collision_layer = 1 << 1 # Layer 2: InteractableNPC
	collision_mask = 0
	monitoring = false
	monitorable = true
	if not character_root:
		character_root = get_parent() as Node3D


func get_character_root() -> Node3D:
	return character_root if character_root else self


func can_be_interacted_by(actor: Node3D) -> bool:
	var root := get_character_root()
	if root.has_method(&"can_be_interacted_by"):
		return root.call(&"can_be_interacted_by", actor)
	if interaction_kind == InteractionKind.ASSASSINATE and root.has_method(&"is_safe_from_attack"):
		return not root.call(&"is_safe_from_attack")
	return true


func is_looking_at(actor: Node3D) -> bool:
	if interaction_kind != InteractionKind.ASSASSINATE:
		return false
	var root := get_character_root()
	if root.has_method(&"is_looking_at"):
		return root.call(&"is_looking_at", actor)
	return false


func notify_caught_attempt(attacker: Node3D) -> void:
	caught_attempt.emit(attacker)
	var root := get_character_root()
	if root.has_method(&"on_caught_assassination_attempt"):
		root.call(&"on_caught_assassination_attempt", attacker)


func complete_interaction(actor: Node3D) -> void:
	interaction_completed.emit(actor)
	var root := get_character_root()
	if root.has_method(&"on_interaction_completed"):
		root.call(&"on_interaction_completed", actor, interaction_kind)
