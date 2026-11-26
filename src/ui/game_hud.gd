class_name GameHud
extends CanvasLayer

const DISTRICTS := ["Start", "Náměstí", "Park"]

@onready var _clock_label: Label = %ClockLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _level_label: Label = %LevelLabel
@onready var _quest_label: Label = %QuestLabel
@onready var _quest_route: Label = %QuestRoute
@onready var _end_game_panel: Control = %EndGamePanel
@onready var _end_title_label: Label = %EndTitleLabel
@onready var _end_summary_label: Label = %EndSummaryLabel

var _current_level_id: int = -1
var _quest_level_id: int = 1
var _defense_feedback: Tween


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
	_clock_label.text = "%02d:%02d / 19:00" % [hours, minutes]


func set_score(score: int) -> void:
	_score_label.text = "Skóre: %d" % score


func set_level(level_name: String, level_id: int) -> void:
	_level_label.text = level_name
	_current_level_id = level_id
	_update_quest_route()


func enable_restart() -> void:
	%Restart.disabled = false


func set_quest_state(has_balloon: bool, has_battery: bool, completed: bool) -> void:
	if completed:
		_quest_label.text = "Úkol splněn | Bonus připsán"
		_quest_level_id = -1
	elif has_balloon and has_battery:
		_quest_label.text = "Odnes balónek a baterii Padrinu Pacatovi"
		_quest_level_id = 0
	elif has_balloon:
		_quest_label.text = "Vyzvedni baterii u Padrina Morettiho"
		_quest_level_id = 2
	else:
		_quest_label.text = "Vyzvedni balónek u Madriny Metticulosy"
		_quest_level_id = 1
	_update_quest_route()


func _update_quest_route() -> void:
	_quest_route.visible = _quest_level_id >= 0
	if not _quest_route.visible:
		return
	var destination: String = DISTRICTS[_quest_level_id]
	if _current_level_id < 0:
		_quest_route.text = destination
	elif _quest_level_id == _current_level_id:
		_quest_route.text = "%s | Jsi na místě" % destination
	else:
		var direction := "doprava" if _quest_level_id > _current_level_id else "doleva"
		_quest_route.text = "%s | Jdi %s" % [destination, direction]


func show_defense_prompt() -> void:
	if _defense_feedback:
		_defense_feedback.kill()
	%DefenseLabel.text = "[F] Odraz útok"
	set_defense_progress(1.0)
	$TopLeftPanel.hide()
	%DefenseTime.show()
	%DefensePanel.show()


func set_defense_progress(progress: float) -> void:
	%DefenseTime.value = progress


func finish_defense_prompt(defended: bool) -> void:
	if not defended:
		%DefensePanel.hide()
		return
	%DefenseTime.hide()
	%DefenseLabel.text = "Útok odražen"
	$TopLeftPanel.show()
	_defense_feedback = create_tween()
	_defense_feedback.tween_interval(0.75)
	_defense_feedback.tween_callback(%DefensePanel.hide)


func show_end_screen(title: String, summary: String, leaderboard: String) -> void:
	_end_title_label.text = title
	_end_summary_label.text = summary
	%LeaderboardRows.text = leaderboard
	%DefensePanel.hide()
	$TopLeftPanel.hide()
	_end_game_panel.show()
	%PlayAgain.grab_focus()


func _on_restart_pressed() -> void:
	var tree := get_tree()
	if tree.reload_current_scene() == OK:
		tree.paused = false
