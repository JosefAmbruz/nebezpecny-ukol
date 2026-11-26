class_name InteractionIndicator
extends CanvasLayer

@export var player: Player
@export var ring_radius: float = 22.0
@export var ring_width: float = 5.0
@export var assassinate_color: Color = Color(0.92, 0.22, 0.22, 0.95)
@export var quest_color: Color = Color(0.25, 0.72, 0.95, 0.95)

@onready var _cursor_ring: Control = $CursorRing
@onready var _status_label: Label = $StatusLabel
@onready var _prompt: PanelContainer = $CursorPrompt
@onready var _prompt_label: Label = $CursorPrompt/Text

var _active: bool = false
var _progress: float = 0.0
var _kind: InteractableNpc.InteractionKind = InteractableNpc.InteractionKind.ASSASSINATE


func _ready() -> void:
	_cursor_ring.draw.connect(_on_cursor_ring_draw)
	_cursor_ring.visible = false
	_status_label.text = ""

	if player:
		player.interaction_started.connect(_on_interaction_started)
		player.interaction_hint_changed.connect(_on_interaction_hint_changed)
		player.interaction_progress_changed.connect(_on_interaction_progress_changed)
		player.interaction_cancelled.connect(_on_interaction_ended)
		player.interaction_completed.connect(_on_interaction_completed)
		player.safe_state_changed.connect(_on_safe_state_changed)


func _process(_delta: float) -> void:
	var cursor := get_viewport().get_mouse_position()
	if _active:
		_cursor_ring.position = cursor
		_cursor_ring.queue_redraw()
	if _prompt.visible:
		var limit := get_viewport().get_visible_rect().size - _prompt.size - Vector2(8, 8)
		_prompt.position = (cursor + Vector2(20, 26)).clamp(Vector2(8, 8), limit.max(Vector2(8, 8)))


func _on_interaction_hint_changed(hint: Player.InteractionHint) -> void:
	match hint:
		Player.InteractionHint.APPROACH:
			_prompt_label.text = "Přijdi blíž"
		Player.InteractionHint.TALK:
			_prompt_label.text = "Drž levé tlačítko | Promluvit"
		Player.InteractionHint.QUEST_UNAVAILABLE:
			_prompt_label.text = "Řiď se aktuálním úkolem"
		Player.InteractionHint.PROTECTED:
			_prompt_label.text = "Cíl je v bezpečí"
		Player.InteractionHint.ATTACK:
			_prompt_label.text = "Drž levé tlačítko | Zaútočit"
		Player.InteractionHint.WAIT:
			_prompt_label.text = "Cíl tě vidí | Počkej, až se otočí"
		Player.InteractionHint.RELEASE:
			_prompt_label.text = "Cíl tě vidí | Pusť tlačítko"
	_prompt.visible = hint != Player.InteractionHint.NONE
	_prompt.set_deferred("size", Vector2.ZERO)


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
		_status_label.text = "V bezpečí před útokem"
	elif can_lean:
		_status_label.text = "[E] Opřít se a chránit se"
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
