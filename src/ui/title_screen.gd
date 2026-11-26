extends Control


func _ready() -> void:
	$Center/Content/Start.grab_focus()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://src/world.tscn")


func _on_how_to_toggled(expanded: bool) -> void:
	%HowToContent.visible = expanded


func _on_quit_pressed() -> void:
	get_tree().quit()
