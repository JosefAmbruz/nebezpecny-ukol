class_name GameHud
extends CanvasLayer

@onready var _clock_label: Label = %ClockLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _level_label: Label = %LevelLabel
@onready var _quest_label: Label = %QuestLabel
@onready var _end_game_panel: Control = %EndGamePanel
@onready var _end_title_label: Label = %EndTitleLabel
@onready var _end_summary_label: Label = %EndSummaryLabel


func _ready() -> void:
	_end_game_panel.visible = false
	set_clock_progress(0.0)
	set_score(0)
	set_quest_state(false, false, false)


## progress = 0.0 -> 18:00, progress = 1.0 -> 19:00
func set_clock_progress(progress: float) -> void:
	var clamped := clampf(progress, 0.0, 1.0)
	var total_minutes := int(floor(clamped * 60.0))
	var hours := 18 + int(total_minutes / 60)
	var minutes := total_minutes % 60
	_clock_label.text = "%02d:%02d" % [hours, minutes]


func set_score(score: int) -> void:
	_score_label.text = "Skóre: %d" % score


func set_level_name(level_name: String) -> void:
	_level_label.text = level_name


func enable_restart() -> void:
	%Restart.disabled = false


func set_quest_state(has_balloon: bool, has_battery: bool, completed: bool) -> void:
	if completed:
		_quest_label.text = "Úkol: Odevzdáno Padrinovi (+bonus)"
	elif has_balloon and has_battery:
		_quest_label.text = "Úkol: Balónek + AAA baterka → vrať se k Padrinovi (L1)"
	elif has_balloon:
		_quest_label.text = "Úkol: Máš balónek → najdi Padrina Morettiho (L3)"
	else:
		_quest_label.text = "Úkol: Najdi Madrinu Metticulosu s balónky (L2)"


func show_end_screen(title: String, summary: String, leaderboard: String) -> void:
	_end_title_label.text = title
	_end_summary_label.text = summary
	%LeaderboardRows.text = leaderboard
	$TopLeftPanel.hide()
	_end_game_panel.show()
	%PlayAgain.grab_focus()


func _on_restart_pressed() -> void:
	var tree := get_tree()
	if tree.reload_current_scene() == OK:
		tree.paused = false
