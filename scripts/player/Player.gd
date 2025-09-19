# res://scenes/player/Player.gd
extends CharacterBody2D

# 节点引用
@onready var body_sprite = $Visuals/Body
@onready var weapon_pivot = $Visuals/WeaponPivot
@onready var skill_pivot = $SkillPivot
@onready var collision_shape = $CollisionShape2D

# 移动相关
var move_direction: Vector2 = Vector2.ZERO

# 位移技能相关
var is_dashing: bool = false
var dash_duration: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_speed: float = 0.0
var dash_timer: float = 0.0

# 特殊状态
var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0
var has_no_collision: bool = false
var no_collision_timer: float = 0.0

# 原始碰撞层设置
var original_collision_layer: int
var original_collision_mask: int

# 信号
signal health_changed(current: int, max: int)
signal energy_changed(current: int, max: int)
signal ammo_updated(weapon_slot: int, magazine_ammo: int, total_ammo: int)

func _ready():
	print("玩家控制器初始化")
	setup_player()
	connect_system_signals()
	
	add_to_group("player")
	
	PlayerDataManager.set_player_node(self)
	WeaponSystem.set_weapon_pivot(weapon_pivot)
	SkillSystem.set_skill_pivot(skill_pivot)
	
	initialize_default_equipment()
	
	# 从test场景添加测试武器
	var test_node_link = get_parent()
	if test_node_link is Node2D:
		print("test:获取到父节点")
		if test_node_link.has_signal("test_weapon_component"):
			test_node_link.test_weapon_component.connect(WeaponSystem.equip_weapon_component)

func setup_player():
	"""设置玩家基础属性"""
	collision_layer = 1  # 玩家层
	collision_mask = 2 | 3 | 4 |5| 6 |7 
	 # 敌人层 | 墙壁层 | 空气墙 | 拾取物层 | 特殊敌人
	
	# 保存原始碰撞设置
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

func connect_system_signals():
	"""连接系统信号"""
	if WeaponSystem:
		WeaponSystem.magazine_ammo_changed.connect(_on_magazine_ammo_changed)
	
	if GameManager:
		GameManager.state_changed.connect(_on_game_state_changed)
	
	#if SkillSystem:
		#SkillSystem.skill_cast.connect()

func initialize_default_equipment():
	"""初始化默认装备"""
	WeaponSystem.initialize_default_weapons()
	SkillSystem.initialize_default_skills()

# === 输入处理 ===

func _input(event):
	if not GameManager.is_game_playing():
		return
	
	# 武器输入
	if event.is_action_pressed("lb"):
		WeaponSystem.try_fire()
	
	if event.is_action_pressed("r"):
		WeaponSystem.start_reload()
	
	if event.is_action_pressed("q"):
		var next_slot = WeaponSystem.get_next_weapon_slot()
		WeaponSystem.switch_weapon(next_slot)
	
	# 技能输入 - 适配新的技能系统
	if event.is_action_pressed("v"):
		var target_dir = (get_global_mouse_position() - global_position).normalized()
		var success = SkillSystem.try_cast_primary_skill(global_position, target_dir)
		if not success:
			print("主技能释放失败 - 可能在冷却中或能量不足")
	
	if event.is_action_pressed("e"):
		var target_dir = (get_global_mouse_position() - global_position).normalized()
		var success = SkillSystem.try_cast_secondary_skill(global_position, target_dir)
		if not success:
			print("副技能释放失败 - 可能在冷却中")
	
	# 游戏控制
	if event.is_action_pressed("pause"):
		GameManager.toggle_pause()
	
	if event.is_action_pressed("f"):
		try_pickup_nearby_items()

# === 移动系统 ===

func _physics_process(delta):
	if not GameManager.is_game_playing():
		return
	
	update_special_states(delta)
	if is_dashing:
		handle_dash_movement(delta)
	else:
		handle_movement_input()
		apply_movement()
	
	update_visual_direction()

func handle_movement_input():
	"""处理移动输入"""
	move_direction = Vector2.ZERO
	
	# 检查是否可以移动（施法时是否允许移动）
	var can_move = true
	if SkillSystem.is_casting(0):  # 主技能施法中
		var primary_skill = SkillSystem.get_skill_data(0)
		if primary_skill and not primary_skill.can_move_while_casting:
			can_move = false
	
	if SkillSystem.is_casting(1):  # 副技能施法中
		var secondary_skill = SkillSystem.get_skill_data(1)
		if secondary_skill and not secondary_skill.can_move_while_casting:
			can_move = false
	
	if not can_move:
		return
	
	
	
	move_direction = get_input_direction().normalized()

func get_input_direction()->Vector2:
	var direction = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	
	return direction

func apply_movement():
	"""应用移动"""
	velocity = move_direction * PlayerDataManager.get_final_move_speed()
	move_and_slide()

func update_visual_direction():
	"""更新视觉方向"""
	var mouse_pos = get_global_mouse_position()
	if mouse_pos.x < global_position.x:
		body_sprite.scale.x = -abs(body_sprite.scale.x)
	else:
		body_sprite.scale.x = abs(body_sprite.scale.x)

# === 位移技能系统 ===

func dash(direction: Vector2, distance: float, duration: float = 0.2):
	"""执行位移技能"""
	if is_dashing:
		return false
	
	is_dashing = true
	dash_direction = direction.normalized()
	dash_speed = distance / duration
	dash_duration = duration
	dash_timer = 0.0
	
	print("玩家开始位移: 方向=", dash_direction, " 速度=", dash_speed, " 持续时间=", duration)
	return true

func blink_to(target_global_pos: Vector2):
	# 直接设置到目标位置
	global_position = target_global_pos

func handle_dash_movement(delta: float):
	"""处理位移移动"""
	dash_timer += delta if dash_timer <99999 else 100
	
	if dash_timer >= dash_duration:
		# 位移结束
		is_dashing = false
		dash_timer = 0.0
		print("玩家位移结束")
	else:
		# 执行位移
		velocity = dash_direction * dash_speed
		move_and_slide()

# === 特殊状态系统 ===

func update_special_states(delta: float):
	"""更新特殊状态"""
	# 更新无敌状态
	if is_invulnerable:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			set_invulnerable(false)
	
	# 更新无碰撞状态
	if has_no_collision:
		no_collision_timer -= delta
		if no_collision_timer <= 0:
			set_no_collision(false)

func set_invulnerable(duration: float = 0.0,invulnerable: bool=true):
	"""设置无敌状态"""
	is_invulnerable = invulnerable
	if invulnerable and duration > 0:
		invulnerable_timer = duration
		print("玩家进入无敌状态，持续时间: ", duration)
		# 可以添加视觉效果
		create_invulnerable_effect()
	else:
		invulnerable_timer = 0.0
		print("玩家无敌状态结束")

func set_no_collision( duration: float = 0.0,no_collision: bool=true):
	"""设置无碰撞状态"""
	has_no_collision = no_collision
	if no_collision and duration > 0:
		no_collision_timer = duration
		# 修改碰撞层，让玩家可以穿过敌人和子弹
		#要屏蔽的层
		var no_need_layer = (1<<2) | (1<<3) | (1<<5) | (1<<7)
		collision_mask = collision_mask & ~  no_need_layer# 移除敌人层
		print("玩家进入无碰撞状态，持续时间: ", duration)
	else:
		no_collision_timer = 0.0
		# 恢复碰撞设置
		collision_mask = original_collision_mask
		print("玩家无碰撞状态结束")

func create_invulnerable_effect():
	"""创建无敌视觉效果"""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(body_sprite, "modulate:a", 0.5, 0.1)
	tween.tween_property(body_sprite, "modulate:a", 1.0, 0.1)
	
	# 在无敌时间结束时停止效果
	var effect_timer = Timer.new()
	effect_timer.wait_time = invulnerable_timer
	effect_timer.one_shot = true
	effect_timer.timeout.connect(func():
		tween.kill()
		body_sprite.modulate.a = 1.0
		effect_timer.queue_free()
	)
	add_child(effect_timer)
	effect_timer.start()

# === 伤害系统 ===

func take_damage(damage: int, damage_type: int = 0):
	"""承受伤害 - 适配新的伤害类型系统"""
	if is_invulnerable:
		print("玩家处于无敌状态，免疫伤害")
		return
	
	# 根据伤害类型计算实际伤害
	var actual_damage = calculate_damage_by_type(damage, damage_type)
	
	var was_killed = PlayerDataManager.damage_player(actual_damage)
	
	AudioSystem.play_damage_sound()
	create_damage_effect(damage_type)
	
	if was_killed:
		handle_death()

func calculate_damage_by_type(base_damage: int, damage_type: int) -> int:
	"""根据伤害类型计算实际伤害"""
	var actual_damage = base_damage
	
	match damage_type:
		0: # 普通伤害
			actual_damage = max(1, base_damage - PlayerDataManager.get_armor_value())
		1: # 穿甲伤害
			actual_damage = base_damage  # 无视护甲
		2: # 燃烧伤害
			actual_damage = base_damage  # 可以添加燃烧DOT效果
		3: # 中毒伤害
			actual_damage = base_damage  # 可以添加中毒DOT效果
		4: # 百分比伤害
			actual_damage = int(PlayerDataManager.get_max_health() * (base_damage / 100.0))
	
	return max(1, actual_damage)

func apply_dot(damage_per_tick: float, duration: float, frequency: float):
	"""应用持续伤害效果"""
	var dot_timer = Timer.new()
	var tick_interval = 1.0 / frequency
	var ticks_remaining = int(duration * frequency)
	
	dot_timer.wait_time = tick_interval
	dot_timer.timeout.connect(func():
		if ticks_remaining > 0:
			PlayerDataManager.damage_player(int(damage_per_tick))
			ticks_remaining -= 1
			print("持续伤害tick: ", damage_per_tick, " 剩余次数: ", ticks_remaining)
		else:
			dot_timer.queue_free()
	)
	
	add_child(dot_timer)
	dot_timer.start()
	print("应用持续伤害: ", damage_per_tick, "/tick, 持续时间: ", duration, "s, 频率: ", frequency, "/s")

func apply_control_effect(effect_type: int, duration: float):
	"""应用控制效果"""
	match effect_type:
		0: # 眩晕
			apply_stun(duration)
		1: # 减速
			apply_slow(duration, 0.5)  # 减速50%
		2: # 定身
			apply_root(duration)
		3: # 沉默
			apply_silence(duration)

func apply_stun(duration: float):
	"""应用眩晕效果"""
	set_physics_process(false)
	var stun_timer = Timer.new()
	stun_timer.wait_time = duration
	stun_timer.one_shot = true
	stun_timer.timeout.connect(func():
		set_physics_process(true)
		stun_timer.queue_free()
		print("眩晕效果结束")
	)
	add_child(stun_timer)
	stun_timer.start()
	print("玩家被眩晕，持续时间: ", duration)

func apply_slow(duration: float, slow_factor: float):
	"""应用减速效果"""
	var original_speed = PlayerDataManager.get_final_move_speed()
	PlayerDataManager.player_stats.move_speed *= slow_factor
	
	var slow_timer = Timer.new()
	slow_timer.wait_time = duration
	slow_timer.one_shot = true
	slow_timer.timeout.connect(func():
		PlayerDataManager.player_stats.move_speed = original_speed
		slow_timer.queue_free()
		print("减速效果结束")
	)
	add_child(slow_timer)
	slow_timer.start()
	print("玩家被减速，减速系数: ", slow_factor, " 持续时间: ", duration)

func apply_root(duration: float):
	"""应用定身效果"""
	var can_move_backup = true
	# 这里需要实现定身逻辑
	print("玩家被定身，持续时间: ", duration)

func apply_silence(duration: float):
	"""应用沉默效果"""
	# 这里需要实现沉默逻辑，禁用技能释放
	print("玩家被沉默，持续时间: ", duration)

func create_damage_effect(damage_type: int = 0):
	"""创建受伤视觉效果"""
	var effect_color = Color.RED
	
	# 根据伤害类型选择不同颜色
	match damage_type:
		1: effect_color = Color.YELLOW  # 穿甲
		2: effect_color = Color.ORANGE  # 燃烧
		3: effect_color = Color.GREEN   # 中毒
		4: effect_color = Color.PURPLE  # 百分比
	
	var tween = create_tween()
	tween.tween_property(body_sprite, "modulate", effect_color, 0.1)
	tween.tween_property(body_sprite, "modulate", Color.WHITE, 0.1)

func handle_death():
	"""处理玩家死亡"""
	set_process_input(false)
	set_physics_process(false)
	AudioSystem.play_sound("player_death")

# === 技能回调 ===



# === 拾取系统 ===

func try_pickup_nearby_items():
	"""拾取附近物品/武器"""
	var pickup_range = 80.0
	var bodies = get_tree().get_nodes_in_group("pickups")
	
	var closest_item = null
	var closest_distance = pickup_range + 1
	
	for body in bodies:
		if is_instance_valid(body):
			var distance = global_position.distance_to(body.global_position)
			if distance <= pickup_range and distance < closest_distance:
				closest_distance = distance
				closest_item = body
	
	if closest_item:
		pickup_item(closest_item)

func pickup_item(item):
	"""拾取物品"""
	if not item or not is_instance_valid(item):
		return
	
	if item.has_method("pickup"):
		item.pickup()
	
	AudioSystem.play_sound("item_pickup")

# === 信号回调 ===

func _on_magazine_ammo_changed(slot: int, current_ammo: int):
	"""弹夹弹药变化回调"""
	var weapon_data = WeaponSystem.get_weapon_data(slot)
	if weapon_data:
		var ammo_type = 0
		if weapon_data.has_method("get") and weapon_data.get("ammo_type") != null:
			ammo_type = weapon_data.ammo_type
		var total_ammo = PlayerDataManager.get_ammo(ammo_type)
		ammo_updated.emit(slot, current_ammo, total_ammo)

func _on_game_state_changed(new_state: GameManager.GameState, old_state: GameManager.GameState):
	"""游戏状态变化响应"""
	match new_state:
		GameManager.GameState.PAUSED:
			set_physics_process(false)
		GameManager.GameState.PLAYING:
			set_physics_process(true)
		GameManager.GameState.GAME_OVER:
			set_process_input(false)
			set_physics_process(false)

# === 数据同步 ===

func sync_health_energy():
	"""同步血量和能量到UI"""
	health_changed.emit(PlayerDataManager.get_health(), PlayerDataManager.get_max_health())
	energy_changed.emit(PlayerDataManager.get_energy(), PlayerDataManager.get_max_energy())

# === 调试功能 ===

func debug_print_player_info():
	"""调试输出玩家信息"""
	print("=== 玩家状态 ===")
	print("位置: ", global_position)
	print("血量: ", PlayerDataManager.get_health(), "/", PlayerDataManager.get_max_health())
	print("能量: ", PlayerDataManager.get_energy(), "/", PlayerDataManager.get_max_energy())
	print("正在位移: ", is_dashing)
	print("无敌状态: ", is_invulnerable)
	print("无碰撞状态: ", has_no_collision)
	
	# 技能状态
	print("主技能冷却: ", SkillSystem.get_cooldown_timer(0))
	print("副技能冷却: ", SkillSystem.get_cooldown_timer(1))
	print("主技能施法中: ", SkillSystem.is_casting(0))
	print("副技能施法中: ", SkillSystem.is_casting(1))
	print("=================")
