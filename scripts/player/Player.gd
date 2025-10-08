# res://scenes/player/Player.gd
extends CharacterBody2D

# 节点引用
@onready var body_sprite = $Visuals/Body
@onready var weapon_pivot = $Visuals/WeaponPivot
@onready var skill_pivot = $SkillPivot
@onready var collision_shape = $CollisionShape2D
@onready var area:Area2D = $Area2D

# 移动相关
var move_direction: Vector2 = Vector2.ZERO
var base_move_speed: float = 300.0

#动画相关
@onready var animatorPlayer = $Visuals/AnimationPlayer
@onready var animationrTree = $Visuals/AnimationTree
var last_move_direction:Vector2 = Vector2.DOWN

# 位移技能相关
var movement_state: MovementState = MovementState.NORMAL
var dash_data: DashData = DashData.new()

# 特殊状态
var status_effects: StatusEffects = StatusEffects.new()

# 原始碰撞层设置
var original_collision_layer: int
var original_collision_mask: int

# 原始碰撞层设置
var original_area_collision_layer: int
var original_area_collision_mask: int

# 信号
signal health_changed(current: int, max: int)
signal energy_changed(current: int, max: int)
signal ammo_updated(weapon_slot: int, magazine_ammo: int, total_ammo: int)

# 枚举定义
enum MovementState {
	NORMAL,      # 正常移动
	DASHING,     # 冲刺中
	STUNNED,     # 眩晕
	ROOTED       # 定身
}

# 内部类定义
class DashData:
	var is_active: bool = false
	var direction: Vector2 = Vector2.ZERO
	var speed: float = 0.0
	var type: int = 0  # 0=dash, 1=blink
	
	func reset():
		is_active = false
		direction = Vector2.ZERO
		speed = 0.0
		type = 0

class StatusEffects:
	var is_invulnerable: bool = false
	var has_no_collision: bool = false
	
	func reset_all():
		is_invulnerable = false
		has_no_collision = false


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
		#print("test:获取到父节点")
		if test_node_link.has_signal("test_weapon_component"):
			test_node_link.test_weapon_component.connect(WeaponSystem.equip_weapon_component)



func _process(delta: float) -> void:

	pass

func setup_player():
	"""设置玩家基础属性"""
	collision_layer = 1  # 玩家层
	collision_mask = 334
	#collision_mask = 2 | 3 | 4 | 7 | 9 
	# 敌人层 | 墙壁层 | 实体墙 | 空气墙 | 特殊敌人 |
	
	area.collision_layer = 1
	area.collision_mask = 128
	
	# 保存原始碰撞设置
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	
	original_area_collision_layer = area.collision_layer
	original_area_collision_mask = area.collision_mask

func connect_system_signals():
	"""连接系统信号"""
	if WeaponSystem:
		WeaponSystem.magazine_ammo_changed.connect(_on_magazine_ammo_changed)
	
	if GameManager:
		GameManager.state_changed.connect(_on_game_state_changed)

func initialize_default_equipment():
	"""初始化默认装备"""
	WeaponSystem.initialize_default_weapons()
	SkillSystem.initialize_default_skills()

# === 输入处理 ===

func _input(event):
	if not GameManager.is_game_playing():
		return
	
	# 武器输入
	# 武器输入 - 改为使用连发系统
	if event.is_action_pressed("lb"):
		WeaponSystem.start_firing()
	
	if event.is_action_released("lb"):
		WeaponSystem.stop_firing()
	
	if event.is_action_pressed("r"):
		WeaponSystem.start_reload()
	
	if event.is_action_pressed("q"):
		var next_slot = WeaponSystem.get_next_weapon_slot()
		WeaponSystem.switch_weapon(next_slot)
	
	# 技能输入
	if event.is_action_pressed("v"):
		var target_dir = (get_global_mouse_position() - global_position).normalized()
		var success = SkillSystem.try_cast_primary_skill(global_position, target_dir)
		if not success:
			#print("主技能释放失败 - 可能在冷却中或能量不足")
			pass
	
	if event.is_action_pressed("e"):
		var target_dir = (get_global_mouse_position() - global_position).normalized()
		var success = SkillSystem.try_cast_secondary_skill(global_position, target_dir)
		if not success:
			#print("副技能释放失败 - 可能在冷却中")
			pass
	
	# 游戏控制
	if event.is_action_pressed("pause"):
		GameManager.toggle_pause()
	
	if event.is_action_pressed("f"):
		try_pickup_nearby_items()

# === 移动系统 - 重构后 ===

func _physics_process(delta):
	if not GameManager.is_game_playing():
		return

	process_movement(delta)
	#update_visual_direction()
	animationrTree.set("parameters/move/blend_position",velocity)
	animationrTree.set("parameters/move/4/blend_position",last_move_direction)

func process_movement(delta: float):
	"""处理所有移动逻辑"""
	match movement_state:
		MovementState.NORMAL:
			handle_normal_movement()
		MovementState.DASHING:
			handle_dash_movement(delta)
		MovementState.STUNNED:
			velocity = Vector2.ZERO
		MovementState.ROOTED:
			velocity = Vector2.ZERO
		_:
			handle_normal_movement()
	if velocity.length() >=0.1:
		last_move_direction = velocity
	move_and_slide()

func handle_normal_movement():
	"""处理正常移动"""
	move_direction = Vector2.ZERO
	
	# 检查是否可以移动（施法时是否允许移动）
	if not can_move_while_casting():
		velocity = Vector2.ZERO
		return
	
	move_direction = get_input_direction().normalized()
	velocity = move_direction * get_effective_move_speed()

func can_move_while_casting() -> bool:
	"""检查施法时是否可以移动"""
	if SkillSystem.is_casting(0):  # 主技能施法中
		var primary_skill = SkillSystem.get_skill_data(0)
		if primary_skill and not primary_skill.can_move_while_casting:
			return false
	
	if SkillSystem.is_casting(1):  # 副技能施法中
		var secondary_skill = SkillSystem.get_skill_data(1)
		if secondary_skill and not secondary_skill.can_move_while_casting:
			return false
	
	return true

func get_input_direction() -> Vector2:
	"""获取输入方向"""
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

func get_effective_move_speed() -> float:
	"""获取有效移动速度（考虑状态效果）"""
	return PlayerDataManager.get_final_move_speed()

# === 位移技能系统===

func dash(direction: Vector2, distance: float, duration: float = 0.2) -> bool:
	"""执行冲刺位移"""
	if movement_state == MovementState.DASHING:
		return false
	
	return start_dash_movement(direction.normalized(), distance / duration, duration, 0)

func blink_to(target_global_pos: Vector2) -> bool:
	"""执行闪现位移"""
	if movement_state == MovementState.DASHING:
		return false
	
	global_position = target_global_pos
	#print("玩家闪现到位置: ", target_global_pos)
	return true

func start_dash_movement(direction: Vector2, speed: float, duration: float, dash_type: int) -> bool:
	"""开始位移移动 - 使用TimerPool的便捷方法"""
	# 如果已经在dash中，先结束之前的dash
	if movement_state == MovementState.DASHING:
		_on_dash_finished()
	
	# 设置位移数据
	dash_data.is_active = true
	dash_data.direction = direction
	dash_data.speed = speed
	dash_data.type = dash_type
	
	# 使用TimerPool的便捷方法创建一次性计时器
	var dash_timer = TimerPool.create_one_shot_timer(duration, _on_dash_finished)
	dash_timer.start()
	# 切换状态
	movement_state = MovementState.DASHING
	
	#print("开始位移: 方向=", direction, " 速度=", speed, " 持续时间=", duration)
	return true

func handle_dash_movement(delta: float):
	if not dash_data.is_active:
		movement_state = MovementState.NORMAL
		return
	# 只负责应用速度，时间控制交给Timer
	velocity = dash_data.direction * dash_data.speed

func _on_dash_finished():
	"""位移结束回调"""
	if movement_state == MovementState.DASHING:
		#print("玩家位移结束")
		movement_state = MovementState.NORMAL
		dash_data.reset()


# === 特殊状态系统 - 重构后 ===
func set_invulnerable(duration: float = 0.0, invulnerable: bool = true):
	"""设置无敌状态 - 使用便捷方法"""
	status_effects.is_invulnerable = invulnerable
	
	if invulnerable and duration > 0:
		#print("玩家进入无敌状态，持续时间: ", duration)
		create_invulnerable_effect(duration)
		
		# 使用TimerPool的便捷方法
		var invulnerable_timer  = TimerPool.create_one_shot_timer(duration, func():
			status_effects.is_invulnerable = false
			#print("玩家无敌状态结束")
		)
		invulnerable_timer.start()
	#else:
		#print("玩家无敌状态结束")

# 修复无碰撞状态
func set_no_collision(duration: float = 0.0, no_collision: bool = true):
	"""设置无碰撞状态 - 使用便捷方法"""
	status_effects.has_no_collision = no_collision
	
	if no_collision and duration > 0:
		#print("玩家进入无碰撞状态，持续时间: ", duration)
		
		# 修改碰撞层
		
		collision_mask = 0
		area.collision_layer = 0
		# 使用TimerPool的便捷方法
		var no_collision_timer  =TimerPool.create_one_shot_timer(duration, func():
			status_effects.has_no_collision = false
			collision_mask = original_collision_mask
			area.collision_layer = original_area_collision_layer
			#print("玩家无碰撞状态结束")
		)
		no_collision_timer.start()
	else:
		collision_mask = original_collision_mask
		#print("玩家无碰撞状态结束")

func create_invulnerable_effect(duration: float):
	"""创建无敌视觉效果"""
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(body_sprite, "modulate:a", 0.5, 0.1)
	tween.tween_property(body_sprite, "modulate:a", 1.0, 0.1)
	
	# 使用TimerPool管理效果结束
	var effect_timer =TimerPool.create_one_shot_timer(duration, func():
		tween.kill()
		body_sprite.modulate.a = 1.0
	)
	effect_timer.start()

# === 控制效果系统 - 重构后 ===
func apply_stun(duration: float):
	"""应用眩晕效果"""
	movement_state = MovementState.STUNNED
	
	var stun_timer = TimerPool.create_one_shot_timer(duration, func():
		if movement_state == MovementState.STUNNED:
			movement_state = MovementState.NORMAL
		#print("眩晕效果结束")
	)
	stun_timer.start()
	#print("玩家被眩晕，持续时间: ", duration)

func apply_root(duration: float):
	"""应用定身效果"""
	var old_state = movement_state
	movement_state = MovementState.ROOTED
	
	var root_timer = TimerPool.create_one_shot_timer(duration, func():
		if movement_state == MovementState.ROOTED:
			movement_state = MovementState.NORMAL if old_state == MovementState.ROOTED else old_state
		#print("定身效果结束")
	)
	root_timer.start()
	#print("玩家被定身，持续时间: ", duration)

func apply_slow(duration: float, slow_factor: float):
	"""应用减速效果"""
	var original_speed = PlayerDataManager.get_final_move_speed()
	PlayerDataManager.player_stats.move_speed *= slow_factor
	
	var slow_timer = TimerPool.create_one_shot_timer(duration, func():
		PlayerDataManager.player_stats.move_speed = original_speed
		##print("减速效果结束")
	)
	slow_timer.start()
	#print("玩家被减速，减速系数: ", slow_factor, " 持续时间: ", duration)

# === 伤害系统 ===
'''
func take_damage(damage: int, damage_type: int = 0):
	#承受伤害 - 适配新的伤害类型系统
	if status_effects.is_invulnerable:
		#print("玩家处于无敌状态，免疫伤害")
		return
	
	# 根据伤害类型计算实际伤害
	var actual_damage = calculate_damage_by_type(damage, damage_type)
	
	var was_killed = PlayerDataManager.damage_player(actual_damage)
	
	AudioSystem.play_damage_sound()
	create_damage_effect(damage_type)
	
	if was_killed:
		handle_death()
'''
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
	var tick_interval = 1.0 / frequency
	var ticks_remaining = int(duration * frequency)
	
	# 创建循环Timer来处理DOT
	var dot_timer = TimerPool.create_loop_timer(tick_interval, func():
		if ticks_remaining > 0:
			PlayerDataManager.damage_player(int(damage_per_tick))
			ticks_remaining -= 1
			#print("持续伤害tick: ", damage_per_tick, " 剩余次数: ", ticks_remaining)
		else:
			# DOT结束，归还Timer（这由TimerPool内部处理）
			pass
	)
	
	# 设置总持续时间，到时间后自动停止
	var dat_timer = TimerPool.create_one_shot_timer(duration, func():
		if is_instance_valid(dot_timer):
			dot_timer.stop()
			TimerPool.return_timer(dot_timer)
	)
	dat_timer.start()
	
	#print("应用持续伤害: ", damage_per_tick, "/tick, 持续时间: ", duration, "s, 频率: ", frequency, "/s")

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
	status_effects.reset_all()
	dash_data.reset()
	AudioSystem.play_sound("player_death")

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

# === 公共接口方法 ===

func is_dashing() -> bool:
	"""检查是否在位移中"""
	return movement_state == MovementState.DASHING

func is_invulnerable() -> bool:
	"""检查是否无敌"""
	return status_effects.is_invulnerable

func has_no_collision() -> bool:
	"""检查是否无碰撞"""
	return status_effects.has_no_collision

func is_stunned() -> bool:
	"""检查是否眩晕"""
	return movement_state == MovementState.STUNNED

func is_rooted() -> bool:
	"""检查是否定身"""
	return movement_state == MovementState.ROOTED

# === 调试功能 ===

func debug_print_player_info():
	"""调试输出玩家信息"""
	print("=== 玩家状态 ===")
	print("位置: ", global_position)
	print("血量: ", PlayerDataManager.get_health(), "/", PlayerDataManager.get_max_health())
	print("能量: ", PlayerDataManager.get_energy(), "/", PlayerDataManager.get_max_energy())
	print("移动状态: ", MovementState.keys()[movement_state])
	print("位移中: ", is_dashing())
	print("无敌状态: ", is_invulnerable())
	print("无碰撞状态: ", has_no_collision())
	print("主技能冷却: ", SkillSystem.get_cooldown_timer(0))
	print("副技能冷却: ", SkillSystem.get_cooldown_timer(1))
	print("=================")

func _exit_tree():
	"""节点退出场景时清理资源"""
	status_effects.reset_all()
	dash_data.reset()
