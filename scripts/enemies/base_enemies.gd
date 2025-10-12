extends CharacterBody2D

@onready var weapon_pivot = $Visuals/WeaponPivot
@onready var detect_area =$Area2D

@export var equipped_weapon_id:int
@export var equipped_weapon_name:String
@export var enemy_data:EnemyData
@export var has_armor:bool=true
signal be_hurt()

var player:CharacterBody2D

var health:float
var armor:float



enum stat{
		partol,#巡逻
		alart,#警戒
		target_player,#索敌
		path_find,#寻路
		flee,#逃跑
		controlled#被控
		}


@export var using_weapon_data:WeaponData
var using_weapon:WeaponComponent
var move_direction:Vector2 = Vector2.ZERO
var last_move_direction:Vector2 = Vector2.ZERO
var move_speed:float =150
var in_move:bool=false
var damage_multiplier:float=1

var player_position:Vector2= Vector2.RIGHT
var is_aimming:bool = false
var aim_direction:Vector2 =Vector2.RIGHT
var attack_time:float
var attack_cooldown:float

var attack_timer:Timer = null
var fire_timer:Timer = null
var burst_fire_timer:Timer = null
var burst_fire_left = 1

var last_shotgun_bullet_tick_numb :int = 0
# ================================
func _ready():
	"""初始化信息"""
	health = enemy_data.max_health if enemy_data.max_health>0 else 100
	armor = enemy_data.max_armor if enemy_data.max_armor>0 else 0
	move_speed = enemy_data.move_speed
	equip_weapon()
	#链接受伤信号节省资源
	be_hurt.connect(
		func():
			print(health)
			self.handle_die()
			)
	#print(enemy_data.enemy_name)
	#设置碰撞层，添加到敌人组
	set_collision_layer_value(2,true)
	set_collision_mask_value(2,true)
	self.add_to_group("enemies")
	
	#测试代码
	start_attack(10)
	in_move=true
	
	
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	update_weapon_rotation()
	
	if in_move:
		handle_movement()

#========
func equip_weapon():
	"""根据类型，选择是否装备武器，武器id和name二选一"""
	match enemy_data.enemy_type:
		0,1,2:
			if enemy_data.use_weapon:
				if not WeaponList.get_weapon_by_name(equipped_weapon_name)=={}:
					using_weapon_data = load(WeaponList.get_weapon_by_name(equipped_weapon_name).get("data_path")).duplicate()
					#using_weapon_data.base_damage = enemy_data.attack_damage
					#using_weapon_data.attack_distance = enemy_data.attack_range
				
					using_weapon = load(WeaponList.get_weapon_by_name(equipped_weapon_name).get("tscn_path")).instantiate()
					weapon_pivot.add_child(using_weapon)
				elif equipped_weapon_id > 0 and (not WeaponList.get_weapon_by_id(equipped_weapon_id)=={}):
					using_weapon_data = load(WeaponList.get_weapon_by_id(equipped_weapon_id).get("data_path")).duplicate()
					#using_weapon_data.base_damage = enemy_data.attack_damage
					#using_weapon_data.attack_distance = enemy_data.attack_range
				
					using_weapon = load(WeaponList.get_weapon_by_id(equipped_weapon_id).get("tscn_path")).instantiate()
					weapon_pivot.add_child(using_weapon)
				else:
					using_weapon_data = null
					print(name,"：未能加载或装备武器")
			else:
				if not using_weapon_data:
					print(name,"严重错误:不使用武器时，未指定武器数据")
		_:
			pass

func update_weapon_rotation():
	"""更新武器旋转"""
	#没有武器节点则返回
	if not weapon_pivot:
		return
	var angle 
		
	#未瞄准时根据移动方向设置武器方向
	if not is_aimming:
	# 根据最近移动的的X轴方向翻转整个武器锚点
		angle = move_direction.angle()
		weapon_pivot.rotation = angle
		
		if last_move_direction.x < 0:
		# 往左侧移动，将 WeaponPivot 在垂直方向上进行镜像缩放
			weapon_pivot.scale.y = -1
		else:
		# 往右侧移动，恢复正常缩放
			weapon_pivot.scale.y = 1
	else:
		angle = aim_direction.angle()
		weapon_pivot.rotation = angle
		if aim_direction.x<0:
			weapon_pivot.scale.y = -1
		else:
			weapon_pivot.scale.y = 1

func handle_movement():
	"""处理移动"""
	#确保获取了玩家节点
	if not try_get_player():
		return
		
	var direction = (get_player_position() - global_position).normalized()
	
	if direction.length() >0.1:
		last_move_direction = direction
	velocity = direction * move_speed
	move_and_slide()

#====攻击模块====
func start_attack(time:float =-1 ):
	"""开始攻击"""
	if try_get_player():
		is_aimming = true
		attack_timer = TimerPool.create_one_shot_timer(
			time if time>0 else attack_time,
			func():
				if fire_timer:
					fire_timer.stop()
					finish_attack()
				)
		attack_timer.start()
		try_attack()
	else: 
		print("未能开始攻击：未获取到玩家信息")

func try_get_player()->bool:
	"""获取玩家节点"""
	if get_tree().get_nodes_in_group("player")[0]:
		player  = get_tree().get_nodes_in_group("player")[0]
		return true
	else: 
		return false

func get_player_position()->Vector2:
	"""更新玩家全局位置"""
	player_position = player.get_node("Area2D").global_position
	#print(player_position)
	return player_position
	
#尝试开火
func try_attack()->bool:
	"""尝试开火攻击"""
	if not is_aimming:
		return false
	match enemy_data.enemy_type:
		#用枪的
		0,1,2:
			if using_weapon_data:
				match using_weapon_data.fire_mode:
					0:
						fire_timer = TimerPool.create_loop_timer(1/using_weapon_data.click_rate,execute_fire)
						fire_timer.start()
						return true
					1:
						fire_timer = TimerPool.create_loop_timer(1/using_weapon_data.fire_rate,execute_fire)
						fire_timer.start()
						return true
					2:
						burst_fire_left = using_weapon_data.burst_count -1 
						execute_fire()
						fire_timer = TimerPool.create_loop_timer(
							1/using_weapon_data.fire_rate,
							func():execute_burst_fire()
							)
						fire_timer.start()
						return true
	return false

#多连发方法
func execute_burst_fire():
	if burst_fire_left >0:
		burst_fire_left -= 1
		execute_fire()
	else:
		fire_timer.stop()
		burst_fire_timer =TimerPool.create_one_shot_timer(1/using_weapon_data.click_rate,try_attack)
		burst_fire_timer.start()

func execute_fire():
	"""开火发射子弹"""
	#获取子弹发射初始位置
	var muzzle_point
	#根据是否装备武器来设置子弹发射点
	if enemy_data.use_weapon:
		muzzle_point = using_weapon.muzzle_point
		if not muzzle_point:
			print("错误: 武器组件缺少 MuzzlePoint 节点")
			return
	else:
		muzzle_point = weapon_pivot
		
	#根据玩家坐标生成子弹飞行方向
	aim_direction = (get_player_position() - muzzle_point.global_position).normalized()
	#设置将要实例化的子弹携带的数据
	var bullet_data = Bullet.BulletData.new()
	bullet_data.damage = enemy_data.attack_damage*damage_multiplier
	bullet_data.travel_range = using_weapon_data.attack_distance
	bullet_data.speed = using_weapon_data.bullet_speed
	bullet_data.size = using_weapon_data.bullet_size 
	#测试子弹功能#	 var shot_direction  = Vector2(1,1)
	var shot_direction = aim_direction if aim_direction.length()>0 else Vector2.RIGHT
	bullet_data.direction = WeaponSystem.get_weapon_precision(using_weapon_data,shot_direction)
	bullet_data.start_position = muzzle_point.global_position
	
	#实例化子弹-=-发射子弹
	var bullet = BulletPool.get_bullet((bullet_data),1)
	if not bullet:
		print("警告：无法从对象池获取子弹实例")
		return

func finish_attack():
	is_aimming = false
	pass
#====随机状态机====

#====受伤====
func take_damage(damage:float,special_info:Dictionary={}):
	#有甲先扣甲
	if special_info.has("from_shotgun"):
		#print("I have been shoot by shotgun")
		if special_info.from_shotgun and not last_shotgun_bullet_tick_numb == special_info.bullet_tick_numb:
			#print("校验通过")
			special_info.function.call()
			last_shotgun_bullet_tick_numb = special_info.bullet_tick_numb
	else:
		special_info.function.call()
		
	if not has_armor:
		return
	if armor > 0:
		armor = armor-damage 
		#甲不足按余量扣血
		if armor<=0:	
			health = health + armor
			be_hurt.emit()
			armor = 0
	else:
		#没甲直接扣血
		health = health-damage
		be_hurt.emit()
	pass
	
#====死亡====
func handle_die():
#先返还射击计时器
	if health <=0:
		if attack_timer:
			attack_timer.timeout.emit()
		#TimerPool.return_timer(attack_timer)
		if fire_timer:
			fire_timer.stop()
			TimerPool.return_timer(fire_timer)
		#AudioSystem.play_sound("enermy_die")
		#play_die_effect()
		#detect_area.process_mode = Node.PROCESS_MODE_DISABLED ##启用这个会使在血量小于零时立即停止检测子弹，即喷子等的剩余子弹会穿透
		#print(name,":我要死了")
		self.queue_free()
