class_name AssassinListUI
extends CanvasLayer

signal list_visibility_changed(is_open: bool)

const ENTRY_SCENE: PackedScene = preload("res://src/ui/assassin_list_entry.tscn")

@onready var _list_panel: Control = %ListPanel
@onready var _entries_container: Container = %EntriesContainer
@onready var _count_label: Label = %CountLabel
@onready var _hint_label: Label = %HintLabel

var _entries_by_id: Dictionary = {}
var _assassins: Array[CharacterData] = []


func _ready() -> void:
	_list_panel.visible = false
	_update_count()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_assassin_list"):
		toggle_list()
		get_viewport().set_input_as_handled()


func toggle_list() -> void:
	_list_panel.visible = not _list_panel.visible
	_hint_label.text = "[Tab] Zavřít portréty" if _list_panel.visible else "[Tab] Portréty assassinů"
	list_visibility_changed.emit(_list_panel.visible)


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
