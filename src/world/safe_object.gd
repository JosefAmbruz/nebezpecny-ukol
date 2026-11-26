class_name SafeObject
extends Area3D

## Pokud je true (např. zóna kolem Padrina Pacata), postava je v bezpečí automaticky bez nutnosti mačkat opření.
@export var is_passive_immunity: bool = false
## Jak dlouho se může hráč o objekt opírat (v sekundách). 0 = bez omezení.
@export var max_lean_duration: float = 4.0
## Kolik postav se může o objekt opírat najednou (využijí i NPC).
@export var max_occupants: int = 2

var _occupants: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"safe_objects")
	collision_layer = 1 << 2 # Layer 3: SafeObjects
	collision_mask = 0
	monitoring = false
	monitorable = true


func can_lean(actor: Node3D) -> bool:
	if is_passive_immunity:
		return false
	if actor in _occupants:
		return true
	return _occupants.size() < max_occupants


func register_occupant(actor: Node3D) -> void:
	if actor not in _occupants:
		_occupants.append(actor)


func unregister_occupant(actor: Node3D) -> void:
	_occupants.erase(actor)
