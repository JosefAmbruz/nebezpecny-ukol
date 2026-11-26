class_name GameHud
extends CanvasLayer

signal restart_requested
signal menu_requested

const TOOTHBRUSH_SHEET: Texture2D = preload("res://assets/misc/toothbrush-ui.png")

@export var toothbrush_icon_size: Vector2 = Vector2(64, 52)

@onready var _clock_label: Label = %ClockLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _level_label: Label = %LevelLabel
@onready var _quest_label: Label = %QuestLabel
@onready var _toothbrush_container: HBoxContainer = %ToothbrushContainer
@onready var _end_game_panel: Control = %EndGamePanel
@onready var _end_title_label: Label = %EndTitleLabel
@onready var _end_summary_label: Label = %EndSummaryLabel
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton

var _whole_brush_tex: AtlasTexture = null
var _broken_brush_tex: AtlasTexture = null
var _brush_icons: Array[TextureRect] = []


func _ready() -> void:
	_build_brush_textures()
	_end_game_panel.visible = false
	set_clock_progress(0.0)
	set_score(0)
	set_quest_state(false, false, false)
	set_toothbrushes(3, 0)

	if _restart_button:
		_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	if _menu_button:
		_menu_button.pressed.connect(func() -> void: menu_requested.emit())


func _build_brush_textures() -> void:
	if not TOOTHBRUSH_SHEET:
		return
	var half_w := TOOTHBRUSH_SHEET.get_width() * 0.5
	var h := float(TOOTHBRUSH_SHEET.get_height())

	_whole_brush_tex = AtlasTexture.new()
	_whole_brush_tex.atlas = TOOTHBRUSH_SHEET
	_whole_brush_tex.region = Rect2(0.0, 0.0, half_w, h)

	_broken_brush_tex = AtlasTexture.new()
	_broken_brush_tex.atlas = TOOTHBRUSH_SHEET
	_broken_brush_tex.region = Rect2(half_w, 0.0, half_w, h)


func set_toothbrushes(total: int, broken: int) -> void:
	if not _toothbrush_container:
		return

	if _brush_icons.size() != total:
		for child in _toothbrush_container.get_children():
			child.queue_free()
		_brush_icons.clear()
		for i in range(total):
			var icon := TextureRect.new()
			icon.custom_minimum_size = toothbrush_icon_size
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_toothbrush_container.add_child(icon)
			_brush_icons.append(icon)

	# Zlomené kartáčky se zobrazují zprava doleva (ubývající životy)
	var intact_count := maxi(0, total - broken)
	for i in range(total):
		var is_intact := i < intact_count
		_brush_icons[i].texture = _whole_brush_tex if is_intact else _broken_brush_tex
		_brush_icons[i].modulate = Color.WHITE if is_intact else Color(0.85, 0.75, 0.75, 0.85)


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


func set_quest_state(has_balloon: bool, has_battery: bool, completed: bool) -> void:
	if completed:
		_quest_label.text = "Úkol: Odevzdáno Padrinovi (+bonus)"
	elif has_balloon and has_battery:
		_quest_label.text = "Úkol: Balónek + AAA baterka → vrať se k Padrinovi (L1)"
	elif has_balloon:
		_quest_label.text = "Úkol: Máš balónek → najdi Padrina Morettiho (L3)"
	else:
		_quest_label.text = "Úkol: Najdi Madrinu Metticulosu s balónky (L2)"


func show_end_screen(title: String, summary: String) -> void:
	_end_title_label.text = title
	_end_summary_label.text = summary
	_end_game_panel.visible = true
