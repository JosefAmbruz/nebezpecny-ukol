extends Node

const BUS_MUSIC: StringName = &"Music"
const BUS_AMBIENT: StringName = &"Ambient"
const BUS_SFX: StringName = &"SFX"
const BUS_VOICE: StringName = &"Voice"

const SILENT_DB: float = -80.0
const SFX_POOL_SIZE: int = 8

var _music_players: Array[AudioStreamPlayer] = []
var _music_index: int = 0
var _music_tween: Tween = null

var _ambient_players: Array[AudioStreamPlayer] = []
var _ambient_index: int = 0
var _ambient_tween: Tween = null

var _oneshot_player: AudioStreamPlayer = null
var _oneshot_timer: Timer = null
var _oneshot_stream: AudioStream = null
var _oneshot_interval_range: Vector2 = Vector2(7.0, 16.0)

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _crowd_voice_cooldown: float = 0.0
var _duck_tween: Tween = null
var _base_music_bus_db: float = -4.0
var _base_ambient_bus_db: float = -6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in range(2):
		var mp := AudioStreamPlayer.new()
		mp.bus = BUS_MUSIC
		mp.volume_db = SILENT_DB
		add_child(mp)
		_music_players.append(mp)

		var ap := AudioStreamPlayer.new()
		ap.bus = BUS_AMBIENT
		ap.volume_db = SILENT_DB
		add_child(ap)
		_ambient_players.append(ap)

	_oneshot_player = AudioStreamPlayer.new()
	_oneshot_player.bus = BUS_AMBIENT
	add_child(_oneshot_player)

	_oneshot_timer = Timer.new()
	_oneshot_timer.one_shot = true
	_oneshot_timer.timeout.connect(_on_ambient_oneshot_timeout)
	add_child(_oneshot_timer)

	for i in range(SFX_POOL_SIZE):
		var sp := AudioStreamPlayer.new()
		sp.bus = BUS_SFX
		add_child(sp)
		_sfx_pool.append(sp)

	var music_idx := AudioServer.get_bus_index(BUS_MUSIC)
	if music_idx >= 0:
		_base_music_bus_db = AudioServer.get_bus_volume_db(music_idx)
	var amb_idx := AudioServer.get_bus_index(BUS_AMBIENT)
	if amb_idx >= 0:
		_base_ambient_bus_db = AudioServer.get_bus_volume_db(amb_idx)


func _process(delta: float) -> void:
	if _crowd_voice_cooldown > 0.0:
		_crowd_voice_cooldown = maxf(0.0, _crowd_voice_cooldown - delta)


#region Hudba (Music)

func play_music(stream: AudioStream, fade_time: float = 1.5, target_db: float = 0.0) -> void:
	if not stream:
		return
	var current := _music_players[_music_index]
	if current.playing and current.stream == stream:
		return

	var next_idx := 1 - _music_index
	var next_player := _music_players[next_idx]
	next_player.stream = stream
	next_player.volume_db = SILENT_DB
	next_player.play()

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(next_player, "volume_db", target_db, fade_time)
	if current.playing:
		_music_tween.tween_property(current, "volume_db", SILENT_DB, fade_time)
		_music_tween.chain().tween_callback(current.stop)

	_music_index = next_idx


func stop_music(fade_time: float = 1.0) -> void:
	var current := _music_players[_music_index]
	if not current.playing:
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(current, "volume_db", SILENT_DB, fade_time)
	_music_tween.tween_callback(current.stop)

#endregion


#region Ambient Brna

func play_ambient(stream: AudioStream, fade_time: float = 1.8, target_db: float = 0.0) -> void:
	if not stream:
		stop_ambient(fade_time)
		return
	var current := _ambient_players[_ambient_index]
	if current.playing and current.stream == stream:
		return

	var next_idx := 1 - _ambient_index
	var next_player := _ambient_players[next_idx]
	next_player.stream = stream
	next_player.volume_db = SILENT_DB
	next_player.play()

	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()

	_ambient_tween = create_tween()
	_ambient_tween.set_parallel(true)
	_ambient_tween.tween_property(next_player, "volume_db", target_db, fade_time)
	if current.playing:
		_ambient_tween.tween_property(current, "volume_db", SILENT_DB, fade_time)
		_ambient_tween.chain().tween_callback(current.stop)

	_ambient_index = next_idx


func stop_ambient(fade_time: float = 1.2) -> void:
	var current := _ambient_players[_ambient_index]
	if not current.playing:
		return
	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(current, "volume_db", SILENT_DB, fade_time)
	_ambient_tween.tween_callback(current.stop)


## Nastaví náhodné jednorázové zvuky Brna (šalina, holubi...) přes AudioStreamRandomizer.
func set_ambient_oneshots(stream: AudioStream, interval_range: Vector2 = Vector2(7.0, 16.0)) -> void:
	_oneshot_stream = stream
	_oneshot_interval_range = interval_range
	_oneshot_timer.stop()
	if _oneshot_stream:
		_schedule_next_oneshot()


func _schedule_next_oneshot() -> void:
	if not _oneshot_stream:
		return
	_oneshot_timer.start(randf_range(_oneshot_interval_range.x, _oneshot_interval_range.y))


func _on_ambient_oneshot_timeout() -> void:
	if _oneshot_stream and not _oneshot_player.playing:
		_oneshot_player.stream = _oneshot_stream
		_oneshot_player.play()
	_schedule_next_oneshot()

#endregion


#region SFX & Dabing (Voice)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if not stream:
		return
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter) if pitch_jitter > 0.0 else 1.0
	player.play()


## Přehraje důležitou dabingovou hlášku (např. Padrino / Madrina) a jemně ztlumí hudbu/ambient.
func play_voice_3d(player_3d: AudioStreamPlayer3D, stream: AudioStream, duck_db: float = -6.0) -> void:
	if not is_instance_valid(player_3d) or not stream:
		return
	player_3d.bus = BUS_VOICE
	player_3d.stream = stream
	player_3d.play()
	_duck_background(duck_db, 0.25)
	if not player_3d.finished.is_connected(_on_important_voice_finished):
		player_3d.finished.connect(_on_important_voice_finished, CONNECT_ONE_SHOT)


## Přehraje hlášku davu/NPC s globálním cooldownem, aby se postavy nepřekřikovaly.
func try_play_crowd_voice_3d(player_3d: AudioStreamPlayer3D, stream: AudioStream, cooldown: float = 3.0) -> bool:
	if _crowd_voice_cooldown > 0.0 or not is_instance_valid(player_3d) or not stream:
		return false
	if player_3d.playing:
		return false
	player_3d.bus = BUS_VOICE
	player_3d.stream = stream
	player_3d.play()
	_crowd_voice_cooldown = cooldown
	return true


func _on_important_voice_finished() -> void:
	_duck_background(0.0, 0.6)


func _duck_background(offset_db: float, duration: float) -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.set_parallel(true)

	var music_idx := AudioServer.get_bus_index(BUS_MUSIC)
	if music_idx >= 0:
		var start_m := AudioServer.get_bus_volume_db(music_idx)
		var end_m := _base_music_bus_db + offset_db
		_duck_tween.tween_method(
			func(v: float) -> void: AudioServer.set_bus_volume_db(music_idx, v),
			start_m,
			end_m,
			duration
		)

	var amb_idx := AudioServer.get_bus_index(BUS_AMBIENT)
	if amb_idx >= 0:
		var start_a := AudioServer.get_bus_volume_db(amb_idx)
		var end_a := _base_ambient_bus_db + offset_db * 0.7
		_duck_tween.tween_method(
			func(v: float) -> void: AudioServer.set_bus_volume_db(amb_idx, v),
			start_a,
			end_a,
			duration
		)

#endregion
