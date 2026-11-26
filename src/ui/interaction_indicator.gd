class_name InteractionIndicator
extends CanvasLayer

@export var player: Player
@export var ring_radius: float = 22.0
@export var ring_width: float = 5.0
@export var assassinate_color: Color = Color(0.92, 0.22, 0.22, 0.95)
@export var quest_color: Color = Color(0.25, 0.72, 0.95, 0.95)

@onready var _cursor_ring: Control = $CursorRing
@onready var _status_label: Label = $StatusLabel

var _active: bool = false
var _progress: float = 0.0
var _kind: InteractableNpc.InteractionKind = InteractableNpc.InteractionKind.ASSASSINATE


func _ready() -> void:
	_cursor_ring.draw.connect(_on_cursor_ring_draw)
	_cursor_ring.visible = false
	_status_label.text = ""

	if player:
		player.interaction_started.connect(_on_interaction_started)
		player.interaction_progress_changed.connect(_on_interaction_progress_changed)
		player.interaction_cancelled.connect(_on_interaction_ended)
		player.interaction_completed.connect(_on_interaction_completed)
		player.safe_state_changed.connect(_on_safe_state_changed)


func _process(_delta: float) -> void:
	if not _active:
		return
	_cursor_ring.position = get_viewport().get_mouse_position()
	_cursor_ring.queue_redraw()


func _on_interaction_started(_target: InteractableNpc, kind: InteractableNpc.InteractionKind) -> void:
	_active = true
	_progress = 0.0
	_kind = kind
	_cursor_ring.visible = true
	_cursor_ring.position = get_viewport().get_mouse_position()
	_cursor_ring.queue_redraw()


func _on_interaction_progress_changed(progress: float, kind: InteractableNpc.InteractionKind) -> void:
	_progress = progress
	_kind = kind
	_cursor_ring.queue_redraw()


func _on_interaction_ended() -> void:
	_active = false
	_progress = 0.0
	_cursor_ring.visible = false


func _on_interaction_completed(_target: InteractableNpc, _kind: InteractableNpc.InteractionKind) -> void:
	_on_interaction_ended()


func _on_safe_state_changed(is_safe: bool, can_lean: bool) -> void:
	if is_safe:
		_status_label.text = "V bezpečí (opřený / imunita)"
	elif can_lean:
		_status_label.text = "[E] Opřít se"
	else:
		_status_label.text = ""


func _on_cursor_ring_draw() -> void:
	var bg_color := Color(0.0, 0.0, 0.0, 0.45)
	var fg_color := assassinate_color if _kind == InteractableNpc.InteractionKind.ASSASSINATE else quest_color

	_cursor_ring.draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 36, bg_color, ring_width + 2.0, true)
	if _progress > 0.0:
		var start_angle := -PI * 0.5
		var end_angle := start_angle + TAU * _progress
		_cursor_ring.draw_arc(Vector2.ZERO, ring_radius, start_angle, end_angle, 36, fg_color, ring_width, true)
