class_name AssassinListUI
extends CanvasLayer

signal list_visibility_changed(is_open: bool)

const ENTRY_SCENE: PackedScene = preload("res://src/ui/assassin_list_entry.tscn")

@export var slide_open_duration: float = 0.35
@export var slide_close_duration: float = 0.25
@export var hidden_y_offset: float = 980.0

@onready var _phone_root: Control = %PhoneRoot
@onready var _entries_container: Container = %EntriesContainer
@onready var _count_label: Label = %CountLabel
@onready var _hint_label: Label = %HintLabel

var _entries_by_id: Dictionary = {}
var _assassins: Array[CharacterData] = []
var _input_locked: bool = false
var _is_open: bool = false
var _open_offset_top: float = 0.0
var _open_offset_bottom: float = 0.0
var _slide_tween: Tween = null


func _ready() -> void:
	_open_offset_top = _phone_root.offset_top
	_open_offset_bottom = _phone_root.offset_bottom
	_set_phone_y_shift(hidden_y_offset)
	_phone_root.visible = false
	_update_count()


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if _hint_label:
		_hint_label.visible = not locked
	if locked and _is_open:
		_set_open(false, true)


func _unhandled_input(event: InputEvent) -> void:
	if _input_locked:
		return
	if event.is_action_pressed(&"toggle_assassin_list"):
		toggle_list()
		get_viewport().set_input_as_handled()


func toggle_list() -> void:
	_set_open(not _is_open, false)


func _set_open(open: bool, instant: bool) -> void:
	if _is_open == open and not instant:
		return
	_is_open = open
	_hint_label.text = "[Tab] Zavřít portréty" if open else "[Tab] Portréty assassinů"
	list_visibility_changed.emit(open)

	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	if instant:
		_set_phone_y_shift(0.0 if open else hidden_y_offset)
		_phone_root.visible = open
		return

	var current_shift := _phone_root.offset_top - _open_offset_top
	var target_shift := 0.0 if open else hidden_y_offset

	if open:
		_phone_root.visible = true

	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	_slide_tween.tween_method(
		_set_phone_y_shift,
		current_shift,
		target_shift,
		slide_open_duration if open else slide_close_duration
	)
	if not open:
		_slide_tween.tween_callback(func() -> void: _phone_root.visible = false)


func _set_phone_y_shift(shift_y: float) -> void:
	_phone_root.offset_top = _open_offset_top + shift_y
	_phone_root.offset_bottom = _open_offset_bottom + shift_y


func set_assassins(assassins: Array[CharacterData]) -> void:
	_assassins = assassins
	_entries_by_id.clear()

	for child in _entries_container.get_children():
		child.queue_free()

	for data in assassins:
		var entry := ENTRY_SCENE.instantiate() as AssassinListEntry
		_entries_container.add_child(entry)
		entry.setup(data)
		_entries_by_id[data.id] = entry

	_update_count()


func mark_assassin_dead(character_id: StringName) -> void:
	for data in _assassins:
		if data.id == character_id:
			data.is_alive = false
			break

	var entry := _entries_by_id.get(character_id) as AssassinListEntry
	if entry:
		entry.set_alive(false)

	_update_count()


func _update_count() -> void:
	if not _count_label:
		return
	var alive_count := 0
	for data in _assassins:
		if data.is_alive:
			alive_count += 1
	_count_label.text = "%d naživu" % alive_count
