extends CharacterBody2D

@onready var weapon_pivot = $Visuals/WeaponPivot


@export var equipped_weapon_id:int
@export var equipped_weapon_name:String
@export var enemy_data:EnemyData

signal be_hurt()

var health:float
var armor:float

var using_weapon_data:WeaponData
var using_weapon:WeaponComponent
var move_direction:Vector2 = Vector2.ZERO
var last_move_direction:Vector2 = Vector2.ZERO
var move_speed:float
var in_move:bool=false
var damage_multiplier:float=1

var player_position:Vector2= Vector2.RIGHT
var is_aimming:bool = false
var aim_direction:Vector2 =Vector2.RIGHT
var attack_time:float
var attack_cooldown:float

var attack_timer:Timer = null
var fire_timer:Timer = null
var burst_fire_left = 1
# ================================
func _ready():
	equip_weapon()
	health = enemy_data.max_health if enemy_data.max_health>0 else 100
	armor = enemy_data.max_armor if enemy_data.max_armor>0 else 0
	be_hurt.connect(
		func():
			print(health)
			handle_die()
			)
	#print(enemy_data.enemy_name)
	self.add_to_group("enemies")
	pass

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	update_weapon_rotation()
	
	if in_move:
		handle_movement()

#========
func equip_weapon():
	match enemy_data.enemy_type:
		0,1,2:
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
			
		_:
			pass



func update_weapon_rotation():
	"""更新武器旋转（跟随鼠标）"""
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
	if velocity.length() >0.1:
		last_move_direction = velocity
	move_and_slide()



#====攻击模块====
func start_attack(time:float):
	if try_get_player():
		is_aimming = true
		attack_timer = TimerPool.create_one_shot_timer(
			attack_time,
			func():
				if fire_timer:
					fire_timer.stop()
				)
		attack_timer.start()
		try_attack()
	else: 
		print("未能开始攻击：未获取到玩家信息")
	

func try_get_player()->bool:
	if get_tree().get_nodes_in_group("player")[0]:
		player_position = get_tree().get_nodes_in_group("player")[0].global_position
		return true
	else: 
		return false

func try_attack()->bool:
	match enemy_data.enemy_type:
		0,1,2:
			if using_weapon_data:
				match using_weapon.fire_mode:
					0:
						fire_timer = TimerPool.create_loop_timer(1/using_weapon_data.click_rate,execute_fire)
						fire_timer.start()
						
					1:
						fire_timer = TimerPool.create_loop_timer(1/using_weapon_data.fire_rate,execute_fire)
						fire_timer.start()
					2:
						burst_fire_left = using_weapon_data.burst_count -1 
						execute_fire()
						fire_timer = TimerPool.create_loop_timer(
							1/using_weapon_data.fire_rate,
							func():execute_burst_fire()
							)
						fire_timer.start()
	return false

func execute_burst_fire():
	if burst_fire_left >0:
		burst_fire_left -= 1
		execute_fire()
	else:
		fire_timer.stop()

func execute_fire():
	var bullet_data = Bullet.BulletData.new()
	bullet_data.damage = enemy_data.attack_damage*damage_multiplier
	bullet_data.travel_range = enemy_data.attack_distance
	bullet_data.speed = using_weapon_data.bullet_speed
	bullet_data.size = using_weapon_data.bullet_size 
	#测试子弹功能#var shot_direction  = Vector2(1,1)
	var shot_direction = aim_direction if aim_direction.length()>0 else Vector2.RIGHT
	bullet_data.direction = WeaponSystem.get_weapon_precision(using_weapon_data,shot_direction)
	var muzzle_point = using_weapon.muzzle_point
	if not muzzle_point:
		print("错误: 武器组件缺少 MuzzlePoint 节点")
		return
	bullet_data.start_position = muzzle_point.global_position
	
	var bullet = BulletPool.get_bullet((bullet_data),1)
	if not bullet:
		print("警告：无法从对象池获取子弹实例")
		return
	
	pass

func finish_attack():
	is_aimming = false
	pass

#====受伤====
func take_damage(damage:float,special_info:Dictionary={}):
	if armor > 0:
		armor = armor-damage 
		if armor<=0:	
			health = health + armor
			be_hurt.emit()
			armor = 0
	else:
		health = health-damage
		be_hurt.emit()
	pass
	
#====死亡====
func handle_die():
	if health <= 0:
		if attack_timer:
			attack_timer.timeout.emit()
		if fire_timer:
			fire_timer.stop()
			TimerPool.return_timer(fire_timer)
		#AudioSystem.play_sound("enermy_die")
		#play_die_effect()
		self.queue_free()
