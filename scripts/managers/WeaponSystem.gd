# res://scripts/managers/WeaponSystem.gd
extends Node

# 武器装备状态
var current_primary_weapon: WeaponComponent = null
var current_secondary_weapon: WeaponComponent = null
var current_primary_weapon_data: WeaponData = null
var current_secondary_weapon_data: WeaponData = null

var primary_weapon:Node2D #PrimaryWeapon节点
var secondary_weapon:Node2D  #SecondWeapon节点

# 武器节点管理
var weapon_pivot: Node2D = null  # 武器旋转锚点

# 武器状态
var active_weapon_slot: int = 0  # 0=主武器, 1=副武器
var is_reloading: bool = false

# 弹药状态 (弹夹中的子弹)
var primary_magazine_ammo: int = 0
var secondary_magazine_ammo: int = 0

# 武器场景路径配置
var weapon_scenes_path: String = "res://scenes/weapons/"

# 计时器对象池引用
var reload_timer: Timer = null
var fire_cooldown_timer: Timer = null
var burst_cooldown_timer: Timer = null

# 在类变量部分添加以下变量
var is_firing: bool = false  # 是否正在连发
var burst_shots_fired: int = 0  # 三连发已发射的子弹数
var burst_shots_remaining: int = 0  # 三连发剩余的子弹数

# 信号
signal weapon_fired(weapon_data: WeaponData, position: Vector2, direction: Vector2)
signal weapon_switched(weapon_data: WeaponData, slot: int)
signal weapon_equipped(weapon_data: WeaponData, slot: int)
signal weapon_reload_started(weapon_data: WeaponData)
signal weapon_reload_finished(weapon_data: WeaponData)
signal magazine_ammo_changed(slot: int, current_ammo: int)
signal weapon_upgrade_applied(weapon_data: WeaponData, upgrade: String)
signal weapon_unequipped(weapon_data: WeaponData, slot: int)

func _ready():
	print("WeaponSystem 初始化完成")

func _process(delta):
	# 不再需要手动更新计时器
	update_weapon_rotation()
	#处理连发模式
	handle_continuous_fire()
# === 初始化和设置 ===

func set_weapon_pivot(pivot: Node2D):
	"""设置武器旋转锚点"""
	weapon_pivot = pivot
	link_weapon_node(pivot)
	print("设置武器锚点: ", pivot.name)

func initialize_default_weapons():
	"""初始化默认武器"""
	# 装备默认手枪
	var default_pistol = preload("res://scenes/weapons/pistol_m1911.tscn").instantiate() as WeaponComponent
	
	if default_pistol:
		equip_weapon_component(default_pistol, 0)
		switch_weapon(0)
		
# === 武器装备系统 ===
func link_weapon_node(p_weapon_povit:Node2D):
	primary_weapon = p_weapon_povit.get_node("PrimaryWeapon")
	secondary_weapon = p_weapon_povit.get_node("SecondaryWeapon")
	print("连接节点:"+primary_weapon.name+secondary_weapon.name)

func equip_weapon_component(weapon_node: WeaponComponent, slot: int) -> bool:
	"""装备武器实例到指定槽位（保留运行时修改）"""
	if not weapon_node or not is_instance_valid(weapon_node) or slot < 0 or slot > 1:
		print("装备武器失败: 无效参数")
		return false
	
	var weapon_data = weapon_node.get_weapon_data()
	if not weapon_data:
		print("装备武器失败: 武器组件缺少武器数据")
		return false
	
	# 卸载当前武器
	unequip_weapon(slot)
	
	# 确保武器节点没有父节点（从之前的位置移除）
	if weapon_node.get_parent():
		weapon_node.get_parent().remove_child(weapon_node)
	
	# 设置武器数据到对应槽位
	if slot == 0:
		current_primary_weapon_data = weapon_data
		current_primary_weapon = weapon_node
		# 保持当前弹夹弹药数（如果武器有的话）
		if weapon_data.current_magazine_ammo > 0:
			primary_magazine_ammo = weapon_data.current_magazine_ammo
		else:
			primary_magazine_ammo = weapon_data.magazine_size
		PlayerDataManager.equip_primary_weapon(weapon_data)
	else:
		current_secondary_weapon_data = weapon_data
		current_secondary_weapon = weapon_node
		# 保持当前弹夹弹药数（如果武器有的话）
		if weapon_data.current_magazine_ammo > 0:
			secondary_magazine_ammo = weapon_data.current_magazine_ammo
		else:
			secondary_magazine_ammo = weapon_data.magazine_size
		PlayerDataManager.equip_secondary_weapon(weapon_data)
	
	# 添加武器到场景
	if weapon_pivot:
		if slot==0:
			remove_all_children(primary_weapon)
			primary_weapon.add_child(weapon_node)
		else:
			remove_all_children(secondary_weapon)
			secondary_weapon.add_child(weapon_node)
		print("武器节点名称保持为: ", weapon_node.name)
	
	# 初始时隐藏非激活武器
	if slot != active_weapon_slot:
		set_weapon_father_node_visibility(slot,false)
	
	# 发出装备信号
	weapon_equipped.emit(weapon_data, slot)
	magazine_ammo_changed.emit(slot, get_magazine_ammo(slot))
	
	print("WeaponSystem：完成装备现有武器组件: ", weapon_data.weapon_name, " 到槽位 ", slot, " (保留运行时修改)")
	return true

func pickup_and_equip_weapon(pickup_weapon: WeaponComponent, slot: int) -> bool:
	"""从地面拾取武器并装备，保留其修改状态"""
	if not pickup_weapon or not is_instance_valid(pickup_weapon):
		print("拾取武器失败: 无效武器组件")
		return false
	
	# 处理拾取状态 - 从拾取物品组中移除
	if pickup_weapon.is_in_group("pickups"):
		pickup_weapon.remove_from_group("pickups")
		print("从拾取组移除武器: ", pickup_weapon.name)
	
	# 禁用拾取碰撞检测
	if pickup_weapon.has_method("disable_pickup_collision"):
		pickup_weapon.disable_pickup_collision()
	elif pickup_weapon.collision_shape:
		pickup_weapon.collision_shape.set_deferred("disabled", true)
		print("禁用武器拾取碰撞")
	
	# 如果武器有特殊的拾取处理方法，调用它
	if pickup_weapon.has_method("on_picked_up"):
		pickup_weapon.on_picked_up()
	
	# 使用装备组件方法来保留所有修改
	var success = equip_weapon_component(pickup_weapon, slot)
	
	if success:
		print("成功拾取并装备武器: ", pickup_weapon.get_weapon_data().weapon_name)
		
		# 播放拾取音效
		if AudioSystem:
			AudioSystem.play_sound("weapon_pickup")
	else:
		print("拾取武器失败")
	
	return success

func unequip_weapon(slot: int):
	"""卸载指定槽位的武器"""
	var weapon_to_remove: WeaponComponent = null
	var weapon_data_to_remove: WeaponData = null
	if slot == 0 and current_primary_weapon:
		remove_all_children(primary_weapon)
		weapon_to_remove = current_primary_weapon
		weapon_data_to_remove = current_primary_weapon_data
		current_primary_weapon = null
		current_primary_weapon_data = null
		primary_magazine_ammo = 0
		PlayerDataManager.equip_primary_weapon(null)
	elif slot == 1 and current_secondary_weapon:
		remove_all_children(secondary_weapon)
		weapon_to_remove = current_secondary_weapon
		weapon_data_to_remove = current_secondary_weapon_data
		current_secondary_weapon = null
		current_secondary_weapon_data = null
		secondary_magazine_ammo = 0
		PlayerDataManager.equip_secondary_weapon(null)
	weapon_unequipped.emit(weapon_data_to_remove,slot)
	if weapon_to_remove and is_instance_valid(weapon_to_remove):
		weapon_to_remove.queue_free()
		print("卸载武器: 槽位 ", slot)

func load_weapon_scene(weapon_name: String) -> PackedScene:
	"""加载武器场景文件"""
	var scene_path = weapon_scenes_path + weapon_name + ".tscn"
	
	if ResourceLoader.exists(scene_path):
		return load(scene_path) as PackedScene
	else:
		print("武器场景不存在: ", scene_path)
		return null
		
func remove_all_children(m: Node):
	# 倒序遍历所有子节点（避免索引变化导致漏删）
	for i in range(m.get_child_count() - 1, -1, -1):
		var child = m.get_child(i)
		m.remove_child(child)

# === 武器切换系统 ===

func switch_weapon(slot: int):
	"""切换到指定武器槽位"""
	if slot < 0 or slot > 1 or slot == active_weapon_slot:
		return
	
	var old_slot = active_weapon_slot
	active_weapon_slot = slot
	
	# 更新武器显示状态
	update_weapon_visibility()
	
	# 中断当前重装
	if is_reloading:
		cancel_reload()
	
	var active_weapon_data = get_active_weapon_data()
	if active_weapon_data:
		weapon_switched.emit(active_weapon_data, slot)
		print("切换武器: 槽位 ", old_slot, " -> ", slot, " (", active_weapon_data.weapon_name, ")")
	else:
		print("切换到空槽位: ", slot)

func update_weapon_visibility():
	"""更新武器可见性"""
	if primary_weapon:
		set_weapon_father_node_visibility(0,active_weapon_slot == 0)
	
	if secondary_weapon:
		set_weapon_father_node_visibility(1,active_weapon_slot == 1)

func set_weapon_father_node_visibility(slot:int,boolvalue:bool):
	if slot==0:
		primary_weapon.visible=boolvalue
		print("设置主武器父节点可见性")
		return
	elif slot==1:
		secondary_weapon.visible=boolvalue
		print("设置副武器父节点可见性")
		return
	else:
		print("警告：设置武器父节点可见性失败")
		return

func get_next_weapon_slot() -> int:
	"""获取下一个可用武器槽位"""
	for i in range(2):
		var next_slot = (active_weapon_slot + 1 + i) % 2
		if get_weapon_data(next_slot) != null:
			return next_slot
	return active_weapon_slot

# === 射击系统 ===
func start_firing():
	"""开始射击（按下鼠标左键）"""
	var weapon_data = get_active_weapon_data()
	if not weapon_data or is_reloading:
		return
	
	is_firing = true
	
	# 根据射击模式处理
	match weapon_data.fire_mode:
		0:  # 单发
			try_fire()
		1:  # 连发
			# 连发模式会在_process中处理
			pass
		2:  # 三连发
			if burst_shots_remaining <= 0:
				burst_shots_remaining = 3
				burst_shots_fired = 0

func stop_firing():
	"""停止射击（释放鼠标左键）"""
	is_firing = false
	
	# 重置三连发状态（如果正在三连发）
	if burst_shots_remaining > 0:
		burst_shots_remaining = 0
		burst_shots_fired = 0

func handle_continuous_fire():
	"""处理连发射击"""
	if not is_firing or is_reloading:
		return
	
	var weapon_data = get_active_weapon_data()
	if not weapon_data:
		return
	
	# 根据射击模式处理
	match weapon_data.fire_mode:
		1:  # 连发
			try_fire()
		2:  # 三连发
			if burst_shots_remaining > 0 and burst_shots_fired < 3:
				# 检查是否在连发冷却中
				if not fire_cooldown_timer or not is_instance_valid(fire_cooldown_timer) or fire_cooldown_timer.time_left <= 0:
					if try_fire():
						burst_shots_fired += 1
						burst_shots_remaining -= 1
			elif burst_shots_remaining <= 0:
				# 三连发结束，重置状态
				burst_shots_remaining = 0
				burst_shots_fired = 0

func try_fire() -> bool:
	"""尝试开火"""
	if not can_fire():
		return false
	
	var weapon_data = get_active_weapon_data()
	var weapon_component = get_active_weapon_component()
	
	if not weapon_data or not weapon_component:
		return false
	
	# 单发模式需要检查click_rate
	if weapon_data.fire_mode == 0:
		# 检查是否在点击冷却中
		if fire_cooldown_timer and is_instance_valid(fire_cooldown_timer) and fire_cooldown_timer.time_left > 0:
			return false
	
	# 消耗弹药
	if not consume_magazine_ammo():
		# 弹夹空了，尝试自动重装
		if can_reload():
			start_reload()
		return false
	
	# 执行射击
	execute_fire(weapon_data, weapon_component)
	
	# 设置射击冷却 - 使用TimerPool
	var cooldown_time = 1.0 / weapon_data.fire_rate
	start_fire_cooldown(cooldown_time)
	
	return true

func can_fire() -> bool:
	"""检查是否可以开火"""
	if is_reloading:
		return false
		
	# 检查射击冷却（连发和三连发模式）
	var weapon_data = get_active_weapon_data()
	if weapon_data and weapon_data.fire_mode != 0:  # 非单发模式
		if fire_cooldown_timer and is_instance_valid(fire_cooldown_timer) and fire_cooldown_timer.time_left > 0:
			return false
	
	if not weapon_data:
		return false
	
	# 检查弹夹是否有子弹
	return get_active_magazine_ammo() > 0

func start_fire_cooldown(cooldown_time: float):
	"""开始射击冷却"""
	# 从对象池获取计时器，one_shot会自动归还
	fire_cooldown_timer = TimerPool.create_one_shot_timer(
		cooldown_time,
		func(): fire_cooldown_timer = null  # 只需清空引用
	)
	fire_cooldown_timer.start()

func execute_fire(weapon_data: WeaponData, weapon_component: WeaponComponent):
	"""执行开火"""
	
	var muzzle_point = weapon_component.muzzle_point
	if not muzzle_point:
		print("错误: 武器组件缺少 MuzzlePoint 节点")
		return

	# Step 1: 创建子弹数据对象
	var bullet_data = Bullet.BulletData.new()
	bullet_data.damage = WeaponDamageSystem.calculate_weapon_damage(active_weapon_slot)
	bullet_data.travel_range = weapon_data.attack_distance
	bullet_data.speed = 1000 # 可以根据武器类型调整
	var direction = (PlayerDataManager.player_node.get_global_mouse_position() - muzzle_point.global_position).normalized()
	bullet_data.direction = get_weapon_precision(weapon_data,direction)
	bullet_data.start_position = muzzle_point.global_position

	# bullet_data.special_info = {} # 在这里添加特殊效果信息
	
	
	# Step 2: 从对象池获取子弹，并将数据传递给它
	var bullet = BulletPool.get_bullet(bullet_data)
	if not bullet:
		print("警告：无法从对象池获取子弹实例")
		return
	
	# 发射信号
	weapon_fired.emit(weapon_data, muzzle_point.global_position, bullet_data.direction)
	
	# 播放音效
	if AudioSystem:
		AudioSystem.play_weapon_sound(weapon_data.weapon_name + "_fire")
	
	print("武器开火: ", weapon_data.weapon_name, " 剩余弹夹: ", get_active_magazine_ammo())

# === 弹药管理 ===

func consume_magazine_ammo() -> bool:
	"""消耗弹夹子弹"""
	if active_weapon_slot == 0:
		if primary_magazine_ammo > 0:
			primary_magazine_ammo -= 1
			magazine_ammo_changed.emit(0, primary_magazine_ammo)
			return true
	else:
		if secondary_magazine_ammo > 0:
			secondary_magazine_ammo -= 1
			magazine_ammo_changed.emit(1, secondary_magazine_ammo)
			return true
	return false

func get_magazine_ammo(slot: int) -> int:
	"""获取指定槽位弹夹弹药数"""
	return primary_magazine_ammo if slot == 0 else secondary_magazine_ammo

func get_active_magazine_ammo() -> int:
	"""获取当前武器弹夹弹药数"""
	return get_magazine_ammo(active_weapon_slot)

func set_magazine_ammo(slot: int, ammo: int):
	"""设置弹夹弹药数"""
	if slot == 0:
		primary_magazine_ammo = ammo
	else:
		secondary_magazine_ammo = ammo
	magazine_ammo_changed.emit(slot, ammo)

# === 重装系统 ===

func can_reload() -> bool:
	"""检查是否可以重装"""
	if is_reloading:
		return false
	
	var weapon_data = get_active_weapon_data()
	if not weapon_data:
		return false
	
	# 检查是否需要重装
	var current_ammo = get_active_magazine_ammo()
	if current_ammo >= weapon_data.magazine_size:
		return false
	
	# 检查是否有备用弹药
	var available_ammo = PlayerDataManager.get_ammo(weapon_data.ammo_type)
	return available_ammo > 0

func start_reload():
	"""开始重装"""
	if not can_reload():
		return
	
	var weapon_data = get_active_weapon_data()
	var weapon_component = get_active_weapon_component()
	
	if not weapon_data or not weapon_component:
		return
	
	is_reloading = true
	
	# 使用TimerPool创建重装计时器，one_shot会自动归还
	reload_timer = TimerPool.create_one_shot_timer(
		weapon_data.reload_time,
		func(): _on_reload_finished()
	)
	reload_timer.start()
	
	weapon_reload_started.emit(weapon_data)
	
	if AudioSystem:
		AudioSystem.play_weapon_sound(weapon_data.weapon_name + "_reload")
	
	print("开始重装: ", weapon_data.weapon_name, " 时间: ", weapon_data.reload_time, "秒")

func _on_reload_finished():
	"""重装完成回调"""
	finish_reload()
	reload_timer = null  # 计时器已自动归还，只需清空引用

func finish_reload():
	"""完成重装"""
	var weapon_data = get_active_weapon_data()
	if not weapon_data:
		return
	
	# 计算需要的弹药数
	var current_ammo = get_active_magazine_ammo()
	var ammo_needed = weapon_data.magazine_size - current_ammo
	var available_ammo = PlayerDataManager.get_ammo(weapon_data.ammo_type)
	
	var ammo_to_reload = min(ammo_needed, available_ammo)
	
	# 消耗备用弹药
	PlayerDataManager.consume_ammo(weapon_data.ammo_type, ammo_to_reload)
	
	# 填充弹夹
	set_magazine_ammo(active_weapon_slot, current_ammo + ammo_to_reload)
	
	is_reloading = false
	
	weapon_reload_finished.emit(weapon_data)
	
	print("重装完成: ", weapon_data.weapon_name, " 弹夹: ", get_active_magazine_ammo())

func cancel_reload():
	"""取消重装"""
	if not is_reloading:
		return
	
	is_reloading = false
	
	# 对于one_shot计时器，只需停止即可，会自动归还
	if reload_timer and is_instance_valid(reload_timer):
		reload_timer.stop()
		reload_timer = null
	
	print("重装被取消")

func get_reload_progress() -> float:
	"""获取重装进度 (0.0 - 1.0)"""
	if not is_reloading or not reload_timer or not is_instance_valid(reload_timer):
		return 0.0
	
	var weapon_data = get_active_weapon_data()
	if not weapon_data or weapon_data.reload_time <= 0:
		return 1.0
	
	var elapsed_time = weapon_data.reload_time - reload_timer.time_left
	return elapsed_time / weapon_data.reload_time

# === 武器旋转和瞄准 ===
func update_weapon_rotation():
	"""更新武器旋转（跟随鼠标）"""
	if not weapon_pivot:
		return
	
	var mouse_pos = weapon_pivot.get_global_mouse_position()
	var direction = (mouse_pos - weapon_pivot.global_position).normalized()
	
	# 计算角度
	var angle = direction.angle()
	weapon_pivot.rotation = angle
	
	# 根据鼠标的X轴方向翻转整个武器锚点
	if direction.x < 0:
		# 鼠标在左侧，将 WeaponPivot 在垂直方向上进行镜像缩放
		weapon_pivot.scale.y = -1
	else:
		# 鼠标在右侧，恢复正常缩放
		weapon_pivot.scale.y = 1

# === 武器精准度系统 ===
func get_weapon_precision(weaponData:WeaponData,offset_vector:Vector2)->Vector2:
	var weapon_precision
	if weaponData.weapon_precision > 1:
		weapon_precision=1
	elif weaponData.weapon_precision <0 :
		weapon_precision=0
	else:
		weapon_precision = weaponData.weapon_precision
		
	var weapon_precision_angle
	if weaponData.weapon_precision_angle >0 and weaponData.weapon_precision_angle<=180 :
		weapon_precision_angle = weaponData.weapon_precision_angle / 2
	else: weapon_precision_angle=15
	
	var random_value = randf()
	
	if random_value >= weapon_precision:
		var random_angle_deg : float =randf_range(-weapon_precision_angle,weapon_precision_angle)
		offset_vector = offset_vector.rotated(deg_to_rad(random_angle_deg))
		
	return offset_vector

func set_weapon_precision(weaponData:WeaponData,precision:float,set_angle:bool=false,angle:float=30):
	precision = precision if precision < 1 else 1
	precision = precision if precision > 0 else 0
	if set_angle:
		weaponData.weapon_precision_angle = angle if angle >= 0 and angle <= 30 else 30
	weaponData.weapon_precision = precision
	


# === 武器升级系统 ===
func apply_weapon_upgrade(weapon_data: WeaponData, upgrade_type: String, value: float):
	"""应用武器升级"""
	if not weapon_data:
		return
	
	var upgrade_data = {}
	
	match upgrade_type:
		"damage":
			upgrade_data["damage"] = int(value)
		"fire_rate":
			upgrade_data["fire_rate"] = value
		"range":
			upgrade_data["range"] = value
		"magazine_size":
			upgrade_data["magazine_size"] = int(value)
		"piercing":
			upgrade_data["special_effects"] = ["穿透"]
		"explosive":
			upgrade_data["special_effects"] = ["爆炸"]
		"poison":
			upgrade_data["special_effects"] = ["毒伤"]
		"freeze":
			upgrade_data["special_effects"] = ["冰冻"]
	
	# 应用升级到武器组件
	var weapon_component = get_weapon_component_by_data(weapon_data)
	if weapon_component:
		weapon_component.upgrade_weapon(upgrade_data)
	
	weapon_upgrade_applied.emit(weapon_data, upgrade_type)
	print("武器升级: ", weapon_data.weapon_name, " 升级类型: ", upgrade_type)

func get_weapon_component_by_data(weapon_data: WeaponData) -> WeaponComponent:
	"""通过武器数据获取武器组件"""
	if current_primary_weapon_data == weapon_data:
		return current_primary_weapon
	elif current_secondary_weapon_data == weapon_data:
		return current_secondary_weapon
	return null

# === 获取器方法 ===

func get_active_weapon_data() -> WeaponData:
	"""获取当前激活武器数据"""
	return get_weapon_data(active_weapon_slot)

func get_active_weapon_component() -> WeaponComponent:
	"""获取当前激活武器组件"""
	return get_weapon_component(active_weapon_slot)

func get_weapon_data(slot: int) -> WeaponData:
	"""获取指定槽位武器数据"""
	if slot == 0:
		return current_primary_weapon_data
	elif slot == 1:
		return current_secondary_weapon_data
	return null

func get_weapon_component(slot: int) -> WeaponComponent:
	"""获取指定槽位武器组件"""
	if slot == 0:
		return current_primary_weapon
	elif slot == 1:
		return current_secondary_weapon
	return null

func has_weapon(slot: int) -> bool:
	"""检查指定槽位是否有武器"""
	return get_weapon_data(slot) != null

func is_weapon_ready() -> bool:
	"""检查当前武器是否准备就绪"""
	return get_active_weapon_data() != null and not is_reloading and can_fire()

# === 武器信息 ===

func get_weapon_info(slot: int) -> String:
	"""获取武器信息字符串"""
	var weapon_component = get_weapon_component(slot)
	if weapon_component:
		return weapon_component.get_weapon_info_string()
	return "空槽位"

func get_all_weapons_info() -> Array[String]:
	"""获取所有武器信息"""
	var info_array: Array[String] = []
	for i in range(2):
		info_array.append(get_weapon_info(i))
	return info_array

# === 清理资源 ===

func _exit_tree():
	"""节点退出场景树时清理计时器引用"""
	# one_shot计时器会自动归还，只需清空引用
	reload_timer = null
	fire_cooldown_timer = null

# === 调试功能 ===

func debug_print_status():
	"""调试打印武器系统状态"""
	print("=== WeaponSystem 状态 ===")
	print("当前武器槽: ", active_weapon_slot)
	print("主武器: ", current_primary_weapon_data.weapon_name if current_primary_weapon_data else "无")
	print("副武器: ", current_secondary_weapon_data.weapon_name if current_secondary_weapon_data else "无")
	print("主武器弹夹: ", primary_magazine_ammo)
	print("副武器弹夹: ", secondary_magazine_ammo)
	print("是否重装中: ", is_reloading)
	print("重装进度: ", get_reload_progress() * 100, "%")
	print("射击冷却剩余时间: ", fire_cooldown_timer.time_left if fire_cooldown_timer and is_instance_valid(fire_cooldown_timer) else 0)
	print("=========================")
