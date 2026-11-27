extends Control


func _ready() -> void:
	for difficulty_name in Difficulty.NAMES:
		%Difficulty.add_item(difficulty_name)
	%Difficulty.select(Difficulty.current)
	$Center/Content/Start.grab_focus()


func _on_difficulty_selected(index: int) -> void:
	Difficulty.current = index as Difficulty.Level


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://src/world.tscn")


func _on_how_to_toggled(expanded: bool) -> void:
	%HowToContent.visible = expanded


func _on_quit_pressed() -> void:
	get_tree().quit()
