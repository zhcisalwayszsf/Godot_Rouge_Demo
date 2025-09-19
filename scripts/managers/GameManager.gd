# res://scripts/managers/GameManager.gd
extends Node

# 游戏状态枚举
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
	LOADING,
	INVENTORY,
	LEVEL_UP
}

# 游戏难度枚举
enum Difficulty {
	EASY,
	NORMAL,
	HARD,
	NIGHTMARE
}

# 游戏状态管理
var current_state: GameState = GameState.MENU
var previous_state: GameState = GameState.MENU
var current_difficulty: Difficulty = Difficulty.NORMAL

# 游戏数据
var current_level: int = 1
var total_enemies_killed: int = 0
var total_items_collected: int = 0
var game_time: float = 0.0
var is_paused: bool = false

# 关卡相关
var current_room_template: RoomTemplate
var enemies_in_current_room: int = 0
var max_enemies_per_room: int = 15

# 游戏设置
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var auto_pickup_enabled: bool = true

# 信号
signal state_changed(new_state: GameState, old_state: GameState)
signal level_completed(level: int)
signal game_over()
signal enemy_killed(enemy_data: EnemyData)
signal item_collected(item_name: String)
signal difficulty_changed(new_difficulty: Difficulty)

func _ready():
	print("GameManager 初始化完成")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 连接其他系统信号
	connect_system_signals()

func _process(delta):
	if current_state == GameState.PLAYING:
		game_time += delta
		
		# 检查是否需要生成新敌人
		check_enemy_spawning()

func connect_system_signals():
	"""连接各系统信号"""
	# 这些信号会在其他系统初始化后连接
	pass

# === 游戏状态管理 ===

func change_state(new_state: GameState):
	"""改变游戏状态"""
	if new_state == current_state:
		return
	
	var old_state = current_state
	previous_state = current_state
	current_state = new_state
	
	handle_state_transition(old_state, new_state)
	state_changed.emit(new_state, old_state)
	
	print("游戏状态改变: ", GameState.keys()[old_state], " -> ", GameState.keys()[new_state])

@warning_ignore("unused_parameter")
func handle_state_transition(old_state: GameState, new_state: GameState):
	"""处理状态转换"""
	match new_state:
		GameState.MENU:
			handle_enter_menu()
		GameState.PLAYING:
			handle_enter_playing()
		GameState.PAUSED:
			handle_enter_paused()
		GameState.GAME_OVER:
			handle_enter_game_over()
		GameState.LOADING:
			handle_enter_loading()
		GameState.INVENTORY:
			handle_enter_inventory()
		GameState.LEVEL_UP:
			handle_enter_level_up()

func handle_enter_menu():
	"""进入菜单状态"""
	get_tree().paused = false
	AudioSystem.play_menu_music()

func handle_enter_playing():
	"""进入游戏状态"""
	get_tree().paused = false
	is_paused = false
	AudioSystem.play_game_music()

func handle_enter_paused():
	"""进入暂停状态"""
	get_tree().paused = true
	is_paused = true

func handle_enter_game_over():
	"""进入游戏结束状态"""
	get_tree().paused = false
	game_over.emit()
	AudioSystem.play_game_over_sound()

func handle_enter_loading():
	"""进入加载状态"""
	pass

func handle_enter_inventory():
	"""进入背包状态"""
	get_tree().paused = true

func handle_enter_level_up():
	"""进入升级状态"""
	get_tree().paused = true

# === 游戏流程控制 ===

func start_game(difficulty: Difficulty = Difficulty.NORMAL):
	"""开始新游戏"""
	print("开始新游戏, 难度: ", Difficulty.keys()[difficulty])
	
	current_difficulty = difficulty
	apply_difficulty_settings()
	
	# 重置游戏数据
	reset_game_data()
	
	# 初始化玩家数据
	PlayerDataManager.initialize_new_game()
	
	# 切换状态
	change_state(GameState.PLAYING)
	
	difficulty_changed.emit(difficulty)

func apply_difficulty_settings():
	"""应用难度设置"""
	match current_difficulty:
		Difficulty.EASY:
			max_enemies_per_room = 8
		Difficulty.NORMAL:
			max_enemies_per_room = 12
		Difficulty.HARD:
			max_enemies_per_room = 18
		Difficulty.NIGHTMARE:
			max_enemies_per_room = 25

func reset_game_data():
	"""重置游戏数据"""
	current_level = 1
	total_enemies_killed = 0
	total_items_collected = 0
	game_time = 0.0
	enemies_in_current_room = 0

func pause_game():
	"""暂停游戏"""
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)

func resume_game():
	"""恢复游戏"""
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)

func toggle_pause():
	"""切换暂停状态"""
	if current_state == GameState.PLAYING:
		pause_game()
	elif current_state == GameState.PAUSED:
		resume_game()

func end_game():
	"""结束游戏"""
	change_state(GameState.GAME_OVER)

# === 关卡管理 ===

func complete_level():
	"""完成关卡"""
	print("关卡 ", current_level, " 完成!")
	current_level += 1
	level_completed.emit(current_level - 1)
	
	# 可以在这里添加关卡奖励逻辑
	give_level_rewards()

func give_level_rewards():
	"""给予关卡奖励"""
	# 根据难度给予不同奖励
	var bonus_health = 0
	var bonus_ammo = 0
	
	match current_difficulty:
		Difficulty.EASY:
			bonus_health = 20
			bonus_ammo = 50
		Difficulty.NORMAL:
			bonus_health = 15
			bonus_ammo = 30
		Difficulty.HARD:
			bonus_health = 10
			bonus_ammo = 20
		Difficulty.NIGHTMARE:
			bonus_health = 5
			bonus_ammo = 10
	
	PlayerDataManager.heal_player(bonus_health)
	PlayerDataManager.add_ammo(0, bonus_ammo)  # 普通子弹
	
	print("关卡奖励: +", bonus_health, " 血量, +", bonus_ammo, " 子弹")

func set_room_template(template: RoomTemplate):
	"""设置当前房间模板"""
	current_room_template = template
	if template:
		max_enemies_per_room = min(template.max_enemies, max_enemies_per_room)
		print("设置房间模板: ", template.template_name)

# === 敌人管理 ===

func register_enemy_killed(enemy_data: EnemyData):
	"""注册敌人死亡"""
	total_enemies_killed += 1
	enemies_in_current_room = max(0, enemies_in_current_room - 1)
	
	# 给予经验值
	PlayerDataManager.add_experience(enemy_data.exp_value)
	
	enemy_killed.emit(enemy_data)
	print("敌人被击败: ", enemy_data.enemy_name, " (总击败: ", total_enemies_killed, ")")

func register_enemy_spawned():
	"""注册敌人生成"""
	enemies_in_current_room += 1

func check_enemy_spawning():
	"""检查是否需要生成敌人"""
	# 这里可以添加敌人生成逻辑
	# 比如基于时间、玩家位置等因素
	pass

func can_spawn_enemy() -> bool:
	"""检查是否可以生成敌人"""
	return enemies_in_current_room < max_enemies_per_room

# === 物品管理 ===

func register_item_collected(item_name: String):
	"""注册物品收集"""
	total_items_collected += 1
	item_collected.emit(item_name)
	print("收集物品: ", item_name, " (总收集: ", total_items_collected, ")")

# === 设置管理 ===

func set_master_volume(volume: float):
	"""设置主音量"""
	master_volume = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

func set_sfx_volume(volume: float):
	"""设置音效音量"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	if AudioSystem:
		AudioSystem.set_sfx_volume(sfx_volume)

func set_music_volume(volume: float):
	"""设置音乐音量"""
	music_volume = clamp(volume, 0.0, 1.0)
	if AudioSystem:
		AudioSystem.set_music_volume(music_volume)

func toggle_auto_pickup():
	"""切换自动拾取"""
	auto_pickup_enabled = !auto_pickup_enabled
	print("自动拾取: ", "开启" if auto_pickup_enabled else "关闭")

# === 工具方法 ===

func get_current_state() -> GameState:
	"""获取当前游戏状态"""
	return current_state

func is_game_playing() -> bool:
	"""检查游戏是否在进行中"""
	return current_state == GameState.PLAYING

func is_game_paused() -> bool:
	"""检查游戏是否暂停"""
	return current_state == GameState.PAUSED

func get_game_time_string() -> String:
	"""获取格式化的游戏时间"""
	@warning_ignore("integer_division")
	var hours = int(game_time) / 3600
	@warning_ignore("integer_division")
	var minutes = int(game_time) / 60 % 60
	var seconds = int(game_time) % 60
	
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	else:
		return "%02d:%02d" % [minutes, seconds]

func get_stats_summary() -> Dictionary:
	"""获取游戏统计摘要"""
	return {
		"level": current_level,
		"enemies_killed": total_enemies_killed,
		"items_collected": total_items_collected,
		"time_played": get_game_time_string(),
		"difficulty": Difficulty.keys()[current_difficulty]
	}

# === 调试功能 ===

func debug_print_state():
	"""调试打印当前状态"""
	print("=== GameManager 状态 ===")
	print("当前状态: ", GameState.keys()[current_state])
	print("当前关卡: ", current_level)
	print("游戏时间: ", get_game_time_string())
	print("击败敌人: ", total_enemies_killed)
	print("收集物品: ", total_items_collected)
	print("当前房间敌人: ", enemies_in_current_room, "/", max_enemies_per_room)
	print("=========================")
