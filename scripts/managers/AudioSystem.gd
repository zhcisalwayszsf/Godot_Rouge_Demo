# res://scripts/managers/AudioSystem.gd
extends Node

# 音频播放器节点
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer

# 音频池系统（用于同时播放多个音效）
var sfx_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 10
var current_pool_index: int = 0

# 音量设置
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var ui_volume: float = 0.6
var voice_volume: float = 0.9

# 音频资源路径
var music_path: String = "res://assets/audio/music/"
var sfx_path: String = "res://assets/audio/sfx/"
var ui_path: String = "res://assets/audio/ui/"
var voice_path: String = "res://assets/audio/voice/"

# 当前播放状态
var current_music: String = ""
var is_music_playing: bool = false
var music_fade_tween: Tween

# 音效缓存
var audio_cache: Dictionary = {}
var max_cache_size: int = 50

# 信号
signal music_started(track_name: String)
signal music_stopped()
signal sound_played(sound_name: String)
signal volume_changed(category: String, volume: float)

func _ready():
	print("AudioSystem 初始化中...")
	setup_audio_players()
	setup_audio_buses()
	load_default_sounds()
	print("AudioSystem 初始化完成")

# === 初始化设置 ===

func setup_audio_players():
	"""设置音频播放器"""
	# 主音乐播放器
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	
	# 主音效播放器
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "SFX"
	add_child(sfx_player)
	
	# UI音效播放器
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIPlayer"
	ui_player.bus = "UI"
	add_child(ui_player)
	
	# 语音播放器
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "VoicePlayer"
	voice_player.bus = "Voice"
	add_child(voice_player)
	
	# 创建音效池
	create_sfx_pool()

func create_sfx_pool():
	"""创建音效播放器池"""
	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPool_" + str(i)
		player.bus = "SFX"
		add_child(player)
		sfx_pool.append(player)

func setup_audio_buses():
	"""设置音频总线"""
	# 确保所需的音频总线存在
	var bus_names = ["Master", "Music", "SFX", "UI", "Voice"]
	
	for i in range(bus_names.size()):
		if AudioServer.get_bus_index(bus_names[i]) == -1:
			AudioServer.add_bus(i + 1)
			AudioServer.set_bus_name(i + 1, bus_names[i])
			if i > 0:  # 将所有总线连接到Master
				AudioServer.set_bus_send(i + 1, "Master")
	
	# 设置初始音量
	apply_volume_settings()

func load_default_sounds():
	"""预加载常用音效"""
	var default_sounds = [
		"button_click",
		"button_hover",
		"weapon_pickup",
		"item_pickup",
		"player_hurt",
		"enemy_hurt",
		"level_up"
	]
	
	for sound_name in default_sounds:
		preload_sound(sound_name, "ui" if sound_name.begins_with("button") else "sfx")

# === 音乐播放系统 ===

func play_music(track_name: String, fade_in: bool = true) -> bool:
	"""播放背景音乐"""
	if current_music == track_name and is_music_playing:
		return true
	
	var music_resource = load_audio_resource(track_name, "music")
	if not music_resource:
		print("音乐文件未找到: ", track_name)
		return false
	
	# 停止当前音乐
	if is_music_playing:
		stop_music(true)
	
	music_player.stream = music_resource
	music_player.play()
	
	current_music = track_name
	is_music_playing = true
	
	# 淡入效果
	if fade_in:
		music_player.volume_db = linear_to_db(0.0)
		fade_music_to(music_volume, 1.0)
	else:
		music_player.volume_db = linear_to_db(music_volume * master_volume)
	
	music_started.emit(track_name)
	print("播放音乐: ", track_name)
	return true

func stop_music(fade_out: bool = true):
	"""停止背景音乐"""
	if not is_music_playing:
		return
	
	if fade_out:
		fade_music_to(0.0, 0.5, true)
	else:
		music_player.stop()
		is_music_playing = false
		current_music = ""
		music_stopped.emit()

func fade_music_to(target_volume: float, duration: float, stop_after: bool = false):
	"""音乐淡入淡出"""
	if music_fade_tween:
		music_fade_tween.kill()
	
	music_fade_tween = create_tween()
	var target_db = linear_to_db(target_volume * master_volume)
	
	music_fade_tween.tween_property(music_player, "volume_db", target_db, duration)
	
	if stop_after:
		music_fade_tween.tween_callback(_on_music_fade_complete)

func _on_music_fade_complete():
	"""音乐淡出完成回调"""
	music_player.stop()
	is_music_playing = false
	current_music = ""
	music_stopped.emit()

func set_music_position(position: float):
	"""设置音乐播放位置"""
	if music_player and music_player.stream:
		music_player.seek(position)

func get_music_position() -> float:
	"""获取当前音乐播放位置"""
	if music_player and is_music_playing:
		return music_player.get_playback_position()
	return 0.0

# === 音效播放系统 ===

func play_sound(sound_name: String, category: String = "sfx", volume_modifier: float = 1.0) -> bool:
	"""播放音效"""
	var audio_resource = load_audio_resource(sound_name, category)
	if not audio_resource:
		#print("音效文件未找到: ", sound_name)
		return false
	
	var player = get_available_sfx_player()
	if not player:
		print("没有可用的音效播放器")
		return false
	
	player.stream = audio_resource
	
	# 计算最终音量
	var final_volume = get_category_volume(category) * volume_modifier * master_volume
	player.volume_db = linear_to_db(final_volume)
	
	player.play()
	
	sound_played.emit(sound_name)
	return true

func play_sound_2d(sound_name: String, position: Vector2, category: String = "sfx", volume_modifier: float = 1.0) -> bool:
	"""在指定位置播放2D音效"""
	var audio_resource = load_audio_resource(sound_name, category)
	if not audio_resource:
		return false
	
	# 创建临时的2D音效播放器
	var player = AudioStreamPlayer2D.new()
	get_tree().current_scene.add_child(player)
	
	player.stream = audio_resource
	player.global_position = position
	player.bus = category.to_upper()
	
	var final_volume = get_category_volume(category) * volume_modifier * master_volume
	player.volume_db = linear_to_db(final_volume)
	
	player.play()
	
	# 播放完成后自动删除
	player.finished.connect(player.queue_free)
	
	return true

func get_available_sfx_player() -> AudioStreamPlayer:
	"""获取可用的音效播放器"""
	# 优先使用未播放的播放器
	for player in sfx_pool:
		if not player.playing:
			return player
	
	# 如果都在播放，使用轮询方式
	var player = sfx_pool[current_pool_index]
	current_pool_index = (current_pool_index + 1) % pool_size
	return player

# === 特定游戏音效 ===

func play_weapon_sound(weapon_sound_name: String, volume_modifier: float = 1.0):
	"""播放武器音效"""
	play_sound(weapon_sound_name, "sfx", volume_modifier)

func play_skill_sound(skill_name: String, volume_modifier: float = 1.0):
	"""播放技能音效"""
	play_sound(skill_name + "_cast", "sfx", volume_modifier)

func play_ui_sound(ui_sound_name: String, volume_modifier: float = 1.0):
	"""播放UI音效"""
	play_sound(ui_sound_name, "ui", volume_modifier)

func play_damage_sound(damage_type: String = "normal", volume_modifier: float = 1.0):
	"""播放伤害音效"""
	var sound_name = "damage_" + damage_type
	play_sound(sound_name, "sfx", volume_modifier)

func play_pickup_sound(item_type: String, volume_modifier: float = 1.0):
	"""播放拾取音效"""
	var sound_name = item_type + "_pickup"
	play_sound(sound_name, "sfx", volume_modifier)

# === 游戏状态音乐 ===

func play_menu_music():
	"""播放菜单音乐"""
	play_music("menu_theme")

func play_game_music():
	"""播放游戏音乐"""
	play_music("game_theme")

func play_boss_music():
	"""播放Boss音乐"""
	play_music("boss_theme")

func play_victory_music():
	"""播放胜利音乐"""
	play_music("victory_theme", false)

func play_game_over_sound():
	"""播放游戏结束音效"""
	stop_music()
	play_sound("game_over", "sfx", 1.2)

# === 音频资源管理 ===

func load_audio_resource(resource_name: String, category: String) -> AudioStream:
	"""加载音频资源"""
	var cache_key = category + ":" + resource_name
	
	# 检查缓存
	if cache_key in audio_cache:
		return audio_cache[cache_key]
	
	# 尝试加载不同格式的音频文件
	var extensions = [".ogg", ".wav", ".mp3"]
	var base_path = get_audio_path(category) + resource_name
	
	for ext in extensions:
		var full_path = base_path + ext
		if ResourceLoader.exists(full_path):
			var resource = load(full_path) as AudioStream
			if resource:
				cache_audio_resource(cache_key, resource)
				return resource
	
	return null

func get_audio_path(category: String) -> String:
	"""获取音频文件路径"""
	match category:
		"music":
			return music_path
		"sfx":
			return sfx_path
		"ui":
			return ui_path
		"voice":
			return voice_path
		_:
			return sfx_path

func cache_audio_resource(key: String, resource: AudioStream):
	"""缓存音频资源"""
	# 如果缓存满了，移除最旧的资源
	if audio_cache.size() >= max_cache_size:
		var keys = audio_cache.keys()
		audio_cache.erase(keys[0])
	
	audio_cache[key] = resource

func preload_sound(sound_name: String, category: String = "sfx"):
	"""预加载音效"""
	load_audio_resource(sound_name, category)

func clear_audio_cache():
	"""清空音频缓存"""
	audio_cache.clear()
	print("音频缓存已清空")

# === 音量控制 ===

func set_master_volume(volume: float):
	"""设置主音量"""
	master_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()
	volume_changed.emit("master", master_volume)

func set_music_volume(volume: float):
	"""设置音乐音量"""
	music_volume = clamp(volume, 0.0, 1.0)
	if music_player:
		music_player.volume_db = linear_to_db(music_volume * master_volume)
	volume_changed.emit("music", music_volume)

func set_sfx_volume(volume: float):
	"""设置音效音量"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()
	volume_changed.emit("sfx", sfx_volume)

func set_ui_volume(volume: float):
	"""设置UI音量"""
	ui_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()
	volume_changed.emit("ui", ui_volume)

func set_voice_volume(volume: float):
	"""设置语音音量"""
	voice_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()
	volume_changed.emit("voice", voice_volume)

func apply_volume_settings():
	"""应用音量设置到音频总线"""
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), linear_to_db(ui_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(voice_volume))

func get_category_volume(category: String) -> float:
	"""获取分类音量"""
	match category:
		"music":
			return music_volume
		"sfx":
			return sfx_volume
		"ui":
			return ui_volume
		"voice":
			return voice_volume
		_:
			return sfx_volume

# === 获取器方法 ===

func is_playing_music() -> bool:
	"""检查是否正在播放音乐"""
	return is_music_playing

func get_current_music() -> String:
	"""获取当前播放的音乐"""
	return current_music

func get_master_volume() -> float:
	return master_volume

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

func get_ui_volume() -> float:
	return ui_volume

func get_voice_volume() -> float:
	return voice_volume

# === 静音控制 ===

func mute_master(muted: bool):
	"""静音/取消静音主音频"""
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

func mute_music(muted: bool):
	"""静音/取消静音音乐"""
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), muted)

func mute_sfx(muted: bool):
	"""静音/取消静音音效"""
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), muted)

func mute_ui(muted: bool):
	"""静音/取消静音UI音效"""
	AudioServer.set_bus_mute(AudioServer.get_bus_index("UI"), muted)

func mute_all(muted: bool):
	"""静音/取消静音所有音频"""
	mute_master(muted)

# === 音频设置保存/加载 ===

func save_audio_settings() -> Dictionary:
	"""保存音频设置"""
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume,
		"voice_volume": voice_volume
	}

func load_audio_settings(settings: Dictionary):
	"""加载音频设置"""
	master_volume = settings.get("master_volume", 1.0)
	music_volume = settings.get("music_volume", 0.7)
	sfx_volume = settings.get("sfx_volume", 0.8)
	ui_volume = settings.get("ui_volume", 0.6)
	voice_volume = settings.get("voice_volume", 0.9)
	
	apply_volume_settings()
	print("音频设置已加载")

# === 特殊效果 ===

func play_random_sound(sound_prefix: String, count: int, category: String = "sfx"):
	"""播放随机音效（用于多个变体音效）"""
	var random_index = randi() % count + 1
	var sound_name = sound_prefix + str(random_index)
	play_sound(sound_name, category)

func play_sound_with_pitch(sound_name: String, pitch: float, category: String = "sfx"):
	"""以指定音调播放音效"""
	var player = get_available_sfx_player()
	if not player:
		return
	
	var audio_resource = load_audio_resource(sound_name, category)
	if not audio_resource:
		return
	
	player.stream = audio_resource
	player.pitch_scale = pitch
	
	var final_volume = get_category_volume(category) * master_volume
	player.volume_db = linear_to_db(final_volume)
	
	player.play()
	
	# 播放完成后重置音调
	player.finished.connect(func(): player.pitch_scale = 1.0)

func crossfade_music(new_track: String, duration: float = 2.0):
	"""交叉淡化音乐"""
	if not is_music_playing:
		play_music(new_track)
		return
	
	# 开始新音乐的淡入
	var old_player = music_player
	
	# 创建临时播放器用于新音乐
	var new_player = AudioStreamPlayer.new()
	new_player.bus = "Music"
	add_child(new_player)
	
	var new_resource = load_audio_resource(new_track, "music")
	if new_resource:
		new_player.stream = new_resource
		new_player.volume_db = linear_to_db(0.0)
		new_player.play()
		
		# 淡出旧音乐，淡入新音乐
		var fade_tween = create_tween()
		fade_tween.parallel().tween_property(old_player, "volume_db", linear_to_db(0.0), duration)
		fade_tween.parallel().tween_property(new_player, "volume_db", linear_to_db(music_volume * master_volume), duration)
		
		fade_tween.tween_callback(func():
			old_player.stop()
			music_player = new_player
			current_music = new_track
		)

# === 环境音效系统 ===

var ambient_players: Array[AudioStreamPlayer] = []

func play_ambient_sound(sound_name: String, loop: bool = true, volume: float = 0.3) -> AudioStreamPlayer:
	"""播放环境音效"""
	var audio_resource = load_audio_resource(sound_name, "sfx")
	if not audio_resource:
		return null
	
	var ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "Ambient_" + sound_name
	ambient_player.bus = "SFX"
	ambient_player.stream = audio_resource
	ambient_player.volume_db = linear_to_db(volume * sfx_volume * master_volume)
	
	add_child(ambient_player)
	ambient_players.append(ambient_player)
	
	ambient_player.play()
	
	if not loop:
		ambient_player.finished.connect(func():
			ambient_players.erase(ambient_player)
			ambient_player.queue_free()
		)
	
	return ambient_player

func stop_ambient_sound(sound_name: String):
	"""停止特定环境音效"""
	for player in ambient_players:
		if player.name == "Ambient_" + sound_name:
			player.stop()
			ambient_players.erase(player)
			player.queue_free()
			break

func stop_all_ambient_sounds():
	"""停止所有环境音效"""
	for player in ambient_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	ambient_players.clear()

# === 音频分析 ===

func get_music_spectrum() -> PackedFloat32Array:
	"""获取当前音乐的频谱数据"""
	if music_player and is_music_playing:
		var spectrum = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Music"), 0)
		if spectrum:
			return spectrum.get_magnitude_for_frequency_range(20, 20000)
	return PackedFloat32Array()

# === 调试功能 ===

func debug_print_status():
	"""调试打印音频系统状态"""
	print("=== AudioSystem 状态 ===")
	print("当前音乐: ", current_music)
	print("音乐播放中: ", is_music_playing)
	print("主音量: ", master_volume)
	print("音乐音量: ", music_volume)
	print("音效音量: ", sfx_volume)
	print("UI音量: ", ui_volume)
	print("语音音量: ", voice_volume)
	print("音效池使用: ", current_pool_index, "/", pool_size)
	print("环境音效数量: ", ambient_players.size())
	print("音频缓存大小: ", audio_cache.size(), "/", max_cache_size)
	print("=========================")
