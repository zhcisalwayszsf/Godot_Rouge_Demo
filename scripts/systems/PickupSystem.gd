# res://scripts/systems/PickupSystem.gd
extends Node

# 信号
signal pickup_prompt_changed(item_name: String, show: bool)
signal item_picked_up(item_type: String, item_data)
signal pickup_area_entered(pickup_item: Node)
signal pickup_area_exited(pickup_item: Node)

# 拾取范围检测
var pickup_range: float = 100.0
var player_node: Node

# 当前可拾取的物品
var nearby_pickups: Array[Node] = []
var current_highlighted_pickup: Node

# 拾取物品类型
enum PickupType {
	WEAPON,
	SKILL,
	LOOT,
	AMMO,
	HEALTH,
	ENERGY
}

# 自动拾取设置
var auto_pickup_enabled: Dictionary = {
	PickupType.LOOT: true,
	PickupType.AMMO: true,
	PickupType.HEALTH: false,
	PickupType.ENERGY: false,
	PickupType.WEAPON: false,
	PickupType.SKILL: false
}

# 拾取特效预制体
var pickup_effect_scene: PackedScene

func _ready():
	print("PickupSystem initialized")
	load_pickup_effects()

func _process(delta):
	update_pickup_detection()
	update_pickup_prompt()

func load_pickup_effects():
	"""加载拾取特效"""
	var effect_path = "res://scenes/effects/pickup_effect.tscn"
	if ResourceLoader.exists(effect_path):
		pickup_effect_scene = load(effect_path)

func set_player_reference(player: Node):
	"""设置玩家引用"""
	player_node = player

# === 拾取检测系统 ===
func update_pickup_detection():
	"""更新拾取物品检测"""
	if not player_node:
		return
	
	# 获取玩家位置
	var player_position = player_node.global_position
	
	# 检查所有拾取物品的距离
	var items_to_remove = []
	
	for pickup_item in nearby_pickups:
		if not is_instance_valid(pickup_item):
			items_to_remove.append(pickup_item)
			continue
		
		var distance = player_position.distance_to(pickup_item.global_position)
		
		# 如果超出范围，移除
		if distance > pickup_range:
			items_to_remove.append(pickup_item)
			pickup_area_exited.emit(pickup_item)
	
	# 清理无效物品
	for item in items_to_remove:
		nearby_pickups.erase(item)

func add_pickup_item(pickup_item: Node):
	"""添加拾取物品到检测列表"""
	if not pickup_item in nearby_pickups:
		nearby_pickups.append(pickup_item)
		pickup_area_entered.emit(pickup_item)
		
		# 检查是否需要自动拾取
		check_auto_pickup(pickup_item)

func remove_pickup_item(pickup_item: Node):
	"""从检测列表中移除拾取物品"""
	if pickup_item in nearby_pickups:
		nearby_pickups.erase(pickup_item)
		pickup_area_exited.emit(pickup_item)
		
		# 如果这是当前高亮的物品，清除高亮
		if current_highlighted_pickup == pickup_item:
			current_highlighted_pickup = null
			pickup_prompt_changed.emit("", false)

func update_pickup_prompt():
	"""更新拾取提示"""
	var best_pickup = get_best_pickup_target()
	
	if best_pickup != current_highlighted_pickup:
		current_highlighted_pickup = best_pickup
		
		if best_pickup:
			var item_name = get_pickup_name(best_pickup)
			pickup_prompt_changed.emit(item_name, true)
		else:
			pickup_prompt_changed.emit("", false)

func get_best_pickup_target() -> Node:
	"""获取最佳拾取目标（距离最近的非自动拾取物品）"""
	if not player_node or nearby_pickups.is_empty():
		return null
	
	var player_position = player_node.global_position
	var closest_pickup: Node = null
	var closest_distance: float = pickup_range + 1
	
	for pickup_item in nearby_pickups:
		if not is_instance_valid(pickup_item):
			continue
		
		# 跳过自动拾取的物品
		var pickup_type = get_pickup_type(pickup_item)
		if auto_pickup_enabled.get(pickup_type, false):
			continue
		
		var distance = player_position.distance_to(pickup_item.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_pickup = pickup_item
	
	return closest_pickup

# === 拾取执行系统 ===
func attempt_pickup():
	"""尝试拾取当前高亮的物品"""
	if current_highlighted_pickup and is_instance_valid(current_highlighted_pickup):
		pickup_item(current_highlighted_pickup)

func pickup_item(pickup_item: Node) -> bool:
	"""拾取物品"""
	if not pickup_item or not is_instance_valid(pickup_item):
		return false
	
	var pickup_type = get_pickup_type(pickup_item)
	var pickup_data = get_pickup_data(pickup_item)
	
	print("Attempting to pickup: ", get_pickup_name(pickup_item), " (Type: ", pickup_type, ")")
	
	var success = false
	
	match pickup_type:
		PickupType.WEAPON:
			success = pickup_weapon(pickup_data)
		PickupType.SKILL:
			success = pickup_skill(pickup_data)
		PickupType.LOOT:
			success = pickup_loot(pickup_data)
		PickupType.AMMO:
			success = pickup_ammo(pickup_data)
		PickupType.HEALTH:
			success = pickup_health(pickup_data)
		PickupType.ENERGY:
			success = pickup_energy(pickup_data)
	
	if success:
		# 播放拾取特效
		play_pickup_effect(pickup_item.global_position)
		
		# 播放拾取音效
		if AudioManager:
			AudioManager.play_pickup_sound()
		
		# 发送拾取信号
		var item_type_name = PickupType.keys()[pickup_type].to_lower()
		item_picked_up.emit(item_type_name, pickup_data)
		
		# 从检测列表中移除
		remove_pickup_item(pickup_item)
		
		# 销毁物品
		pickup_item.queue_free()
		
		print("Successfully picked up: ", get_pickup_name(pickup_item))
	
	return success

func pickup_weapon(weapon_data: WeaponData) -> bool:
	"""拾取武器"""
	if not weapon_data:
		return false
	
	# 检查玩家是否有空槽位，或者替换当前武器
	var primary_weapon = WeaponSystem.current_primary_weapon_data
	var secondary_weapon = WeaponSystem.current_secondary_weapon_data
	
	if not primary_weapon:
		return WeaponSystem.equip_weapon(weapon_data, WeaponSystem.WeaponSlot.PRIMARY)
	elif not secondary_weapon:
		return WeaponSystem.equip_weapon(weapon_data, WeaponSystem.WeaponSlot.SECONDARY)
	else:
		# 替换当前激活的武器
		return WeaponSystem.equip_weapon(weapon_data, WeaponSystem.active_weapon_slot)

func pickup_skill(skill_data: SkillData) -> bool:
	"""拾取技能"""
	if not skill_data:
		return false
	
	# 根据技能类型装备到对应槽位
	var target_slot = skill_data.skill_type  # 0=主技能, 1=副技能
	return SkillSystem.equip_skill(skill_data, target_slot)

func pickup_loot(loot_data: LootData) -> bool:
	"""拾取战利品"""
	if not loot_data:
		return false
	
	var amount = randi_range(loot_data.min_amount, loot_data.max_amount)
	
	match loot_data.loot_type:
		0: # 普通子弹
			PlayerDataManager.add_ammo(0, amount)
		1: # 特殊子弹
			PlayerDataManager.add_ammo(1, amount)
		2: # 箭矢
			PlayerDataManager.add_ammo(2, amount)
		3: # 魔力精华
			PlayerDataManager.add_ammo(3, amount)
		4: # 血包
			PlayerDataManager.heal(amount)
			return true
	
	return true

func pickup_ammo(ammo_data: Dictionary) -> bool:
	"""拾取弹药"""
	var ammo_type = ammo_data.get("type", 0)
	var amount = ammo_data.get("amount", 10)
	
	PlayerDataManager.add_ammo(ammo_type, amount)
	return true

func pickup_health(health_data: Dictionary) -> bool:
	"""拾取血包"""
	var heal_amount = health_data.get("amount", 25)
	
	# 检查是否满血
	var stats = PlayerDataManager.get_player_stats()
	if stats.current_health >= stats.max_health:
		return false
	
	PlayerDataManager.heal(heal_amount)
	return true

func pickup_energy(energy_data: Dictionary) -> bool:
	"""拾取能量"""
	var energy_amount = energy_data.get("amount", 25)
	
	# 检查是否满能量
	var stats = PlayerDataManager.get_player_stats()
	if stats.current_energy >= stats.max_energy:
		return false
	
	# 直接恢复能量（绕过正常的能量回复系统）
	stats.current_energy = min(stats.max_energy, stats.current_energy + energy_amount)
	PlayerDataManager.energy_changed.emit(stats.current_energy, stats.max_energy)
	return true

# === 自动拾取系统 ===
func check_auto_pickup(pickup_item: Node):
	"""检查是否需要自动拾取"""
	var pickup_type = get_pickup_type(pickup_item)
	
	if auto_pickup_enabled.get(pickup_type, false):
		# 延迟一帧后自动拾取，确保物品完全初始化
		await get_tree().process_frame
		if is_instance_valid(pickup_item):
			pickup_item(pickup_item)

func set_auto_pickup(pickup_type: PickupType, enabled: bool):
	"""设置自动拾取"""
	auto_pickup_enabled[pickup_type] = enabled
	print("Auto pickup for ", PickupType.keys()[pickup_type], " set to: ", enabled)

# === 特效系统 ===
func play_pickup_effect(position: Vector2):
	"""播放拾取特效"""
	if pickup_effect_scene and player_node:
		var effect_instance = pickup_effect_scene.instantiate()
		player_node.get_parent().add_child(effect_instance)
		effect_instance.global_position = position
		
		# 如果特效有播放方法，调用它
		if effect_instance.has_method("play"):
			effect_instance.play()

# === 拾取物品创建系统 ===
func spawn_weapon_pickup(weapon_data: WeaponData, position: Vector2):
	"""生成武器拾取物"""
	var pickup_scene = load("res://scenes/items/weapon_pickup.tscn")
	if pickup_scene:
		var pickup_instance = pickup_scene.instantiate()
		pickup_instance.set_weapon_data(weapon_data)
		pickup_instance.global_position = position
		
		# 添加到当前场景
		if player_node:
			player_node.get_parent().add_child(pickup_instance)
		
		print("Spawned weapon pickup: ", weapon_data.weapon_name)
		return pickup_instance
	
	return null

func spawn_loot_pickup(loot_data: LootData, position: Vector2):
	"""生成战利品拾取物"""
	var pickup_scene = load("res://scenes/items/loot_pickup.tscn")
	if pickup_scene:
		var pickup_instance = pickup_scene.instantiate()
		pickup_instance.set_loot_data(loot_data)
		pickup_instance.global_position = position
		
		if player_node:
			player_node.get_parent().add_child(pickup_instance)
		
		print("Spawned loot pickup: ", loot_data.loot_name)
		return pickup_instance
	
	return null

func spawn_skill_pickup(skill_data: SkillData, position: Vector2):
	"""生成技能拾取物"""
	var pickup_scene = load("res://scenes/items/skill_pickup.tscn")
	if pickup_scene:
		var pickup_instance = pickup_scene.instantiate()
		pickup_instance.set_skill_data(skill_data)
		pickup_instance.global_position = position
		
		if player_node:
			player_node.get_parent().add_child(pickup_instance)
		
		print("Spawned skill pickup: ", skill_data.skill_name)
		return pickup_instance
	
	return null

# === 工具函数 ===
func get_pickup_type(pickup_item: Node) -> PickupType:
	"""获取拾取物类型"""
	if pickup_item.has_method("get_pickup_type"):
		return pickup_item.get_pickup_type()
	elif pickup_item.has_meta("pickup_type"):
		return pickup_item.get_meta("pickup_type")
	else:
		# 根据节点名称或类型推断
		var item_name = pickup_item.name.to_lower()
		if "weapon" in item_name:
			return PickupType.WEAPON
		elif "skill" in item_name:
			return PickupType.SKILL
		elif "ammo" in item_name:
			return PickupType.AMMO
		elif "health" in item_name:
			return PickupType.HEALTH
		elif "energy" in item_name:
			return PickupType.ENERGY
		else:
			return PickupType.LOOT

func get_pickup_data(pickup_item: Node):
	"""获取拾取物数据"""
	if pickup_item.has_method("get_pickup_data"):
		return pickup_item.get_pickup_data()
	elif pickup_item.has_method("get_weapon_data"):
		return pickup_item.get_weapon_data()
	elif pickup_item.has_method("get_skill_data"):
		return pickup_item.get_skill_data()
	elif pickup_item.has_method("get_loot_data"):
		return pickup_item.get_loot_data()
	else:
		return null

func get_pickup_name(pickup_item: Node) -> String:
	"""获取拾取物名称"""
	var pickup_data = get_pickup_data(pickup_item)
	
	if pickup_data and pickup_data.has_method("get"):
		if pickup_data.get("weapon_name"):
			return pickup_data.weapon_name
		elif pickup_data.get("skill_name"):
			return pickup_data.skill_name
		elif pickup_data.get("loot_name"):
			return pickup_data.loot_name
	
	# 备用方案：使用节点名称
	return pickup_item.name.replace("_", " ").capitalize()

func get_nearby_pickups() -> Array[Node]:
	"""获取附近的拾取物列表"""
	return nearby_pickups.duplicate()

func get_pickup_count() -> int:
	"""获取附近拾取物数量"""
	return nearby_pickups.size()

func clear_all_pickups():
	"""清除所有拾取物（用于场景切换）"""
	for pickup_item in nearby_pickups:
		if is_instance_valid(pickup_item):
			pickup_item.queue_free()
	
	nearby_pickups.clear()
	current_highlighted_pickup = null
	pickup_prompt_changed.emit("", false)

# === 输入处理 ===
func _input(event):
	"""处理拾取输入"""
	if event.is_action_pressed("interact"):  # E键
		attempt_pickup()

# === 设置函数 ===
func set_pickup_range(new_range: float):
	"""设置拾取范围"""
	pickup_range = new_range

func get_pickup_range() -> float:
	"""获取拾取范围"""
	return pickup_range

# === 调试函数 ===
func debug_print_nearby_pickups():
	"""调试：打印附近的拾取物"""
	print("=== Nearby Pickups ===")
	for i in range(nearby_pickups.size()):
		var pickup_item = nearby_pickups[i]
		if is_instance_valid(pickup_item):
			print(i, ": ", get_pickup_name(pickup_item), " at ", pickup_item.global_position)
		else:
			print(i, ": Invalid pickup item")
	print("======================")
