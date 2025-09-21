# res://scripts/managers/PlayerDataManager.gd
extends Node

# 玩家数据
var player_stats: PlayerStats
var player_node: CharacterBody2D  # 玩家节点引用

# 经验值系统
var current_experience: int = 0
var current_level: int = 1
var experience_to_next_level: int = 100

# 升级增益跟踪
var selected_upgrades: Array[String] = []

var unstoppable:bool=false


# 信号
signal health_changed(current: int, max: int)
signal energy_changed(current: int, max: int)
signal ammo_changed(ammo_type: int, current: int)
signal player_died()
signal level_up(new_level: int)
signal experience_gained(amount: int)
signal stats_updated()

func _ready():
	print("PlayerDataManager 初始化完成")
	initialize_default_stats()

func _process(delta):
	if player_stats:
		regenerate_energy(delta)

# === 初始化 ===

func initialize_default_stats():
	"""初始化默认玩家数据"""
	player_stats = PlayerStats.new()
	
	# 设置默认值
	player_stats.max_health = 100
	player_stats.current_health = 100
	player_stats.max_energy = 100
	player_stats.current_energy = 100
	player_stats.energy_regen_rate = 10.0
	player_stats.move_speed = 300.0
	
	# 默认弹药
	player_stats.normal_ammo = 320
	player_stats.special_ammo = 30
	player_stats.arrows = 50
	player_stats.mana_essence = 80
	
	# 升级属性
	player_stats.damage_multiplier = 1.0
	player_stats.health_bonus = 0
	player_stats.armor_value = 0
	
	print("玩家数据初始化完成")

func initialize_new_game():
	"""初始化新游戏"""
	initialize_default_stats()
	current_experience = 0
	current_level = 1
	selected_upgrades.clear()
	
	# 发送初始信号
	emit_all_stat_signals()
	
	print("新游戏初始化完成")

func set_player_node(node: Node2D):
	"""设置玩家节点引用"""
	player_node = node
	print("设置玩家节点引用: ", node.name)

# === 生命值管理 ===

func damage_player(damage: int) -> bool:
	"""对玩家造成伤害"""
	if not player_stats:
		return false
	
	# 应用护甲减免
	var actual_damage = max(1, damage - player_stats.armor_value)
	
	player_stats.current_health = max(0, player_stats.current_health - actual_damage)
	health_changed.emit(player_stats.current_health, get_max_health())
	
	print("玩家受到伤害: ", actual_damage, " (剩余血量: ", player_stats.current_health, ")")
	
	# 检查死亡
	if player_stats.current_health <= 0:
		handle_player_death()
		return true
	
	return false

func heal_player(heal_amount: int):
	"""治疗玩家"""
	if not player_stats:
		return
	
	var old_health = player_stats.current_health
	player_stats.current_health = min(get_max_health(), player_stats.current_health + heal_amount)
	
	if player_stats.current_health > old_health:
		health_changed.emit(player_stats.current_health, get_max_health())
		print("玩家回复血量: ", heal_amount, " (当前血量: ", player_stats.current_health, ")")

func set_health(health: int):
	"""直接设置血量"""
	if not player_stats:
		return
	
	player_stats.current_health = clamp(health, 0, get_max_health())
	health_changed.emit(player_stats.current_health, get_max_health())

func get_health() -> int:
	"""获取当前血量"""
	return player_stats.current_health if player_stats else 0

func get_max_health() -> int:
	"""获取最大血量"""
	if not player_stats:
		return 100
	return player_stats.max_health + player_stats.health_bonus

func is_player_alive() -> bool:
	"""检查玩家是否存活"""
	return player_stats and player_stats.current_health > 0

func handle_player_death():
	"""处理玩家死亡"""
	print("玩家死亡")
	player_died.emit()
	if GameManager:
		GameManager.end_game()

# === 能量管理 ===

func consume_energy(amount: int) -> bool:
	"""消耗能量"""
	if not player_stats or player_stats.current_energy < amount:
		return false
	
	player_stats.current_energy -= amount
	energy_changed.emit(player_stats.current_energy, player_stats.max_energy)
	return true

func regenerate_energy(delta: float):
	"""能量自动恢复"""
	if not player_stats:
		return
	
	if player_stats.current_energy < player_stats.max_energy:
		var regen = player_stats.energy_regen_rate * delta
		var old_energy = player_stats.current_energy
		
		player_stats.current_energy = min(player_stats.max_energy, player_stats.current_energy + regen)
		
		if int(player_stats.current_energy) != int(old_energy):
			energy_changed.emit(player_stats.current_energy, player_stats.max_energy)

func set_energy(energy: int):
	"""设置能量值"""
	if not player_stats:
		return
	
	player_stats.current_energy = clamp(energy, 0, player_stats.max_energy)
	energy_changed.emit(player_stats.current_energy, player_stats.max_energy)

func get_energy() -> int:
	"""获取当前能量"""
	return player_stats.current_energy if player_stats else 0

func get_max_energy() -> int:
	"""获取最大能量"""
	return player_stats.max_energy if player_stats else 100

# === 弹药管理 ===

func get_ammo(ammo_type: int) -> int:
	"""获取指定类型弹药数量"""
	if not player_stats:
		return 0
	
	match ammo_type:
		0: return player_stats.normal_ammo
		1: return player_stats.special_ammo
		2: return player_stats.arrows
		3: return player_stats.mana_essence
		_: return 0

func consume_ammo(ammo_type: int, amount: int) -> bool:
	"""消耗弹药"""
	if not player_stats:
		return false
	
	var current_ammo = get_ammo(ammo_type)
	if current_ammo < amount:
		return false
	
	match ammo_type:
		0: player_stats.normal_ammo -= amount
		1: player_stats.special_ammo -= amount
		2: player_stats.arrows -= amount
		3: player_stats.mana_essence -= amount
		_: return false
	
	ammo_changed.emit(ammo_type, get_ammo(ammo_type))
	return true

func add_ammo(ammo_type: int, amount: int):
	"""增加弹药"""
	if not player_stats:
		return
	
	match ammo_type:
		0: player_stats.normal_ammo += amount
		1: player_stats.special_ammo += amount
		2: player_stats.arrows += amount
		3: player_stats.mana_essence += amount
		_: return
	
	ammo_changed.emit(ammo_type, get_ammo(ammo_type))
	print("获得弹药: 类型", ammo_type, " 数量+", amount)

func set_ammo(ammo_type: int, amount: int):
	"""设置弹药数量"""
	if not player_stats:
		return
	
	match ammo_type:
		0: player_stats.normal_ammo = max(0, amount)
		1: player_stats.special_ammo = max(0, amount)
		2: player_stats.arrows = max(0, amount)
		3: player_stats.mana_essence = max(0, amount)
		_: return
	
	ammo_changed.emit(ammo_type, get_ammo(ammo_type))

# === 经验值和升级系统 ===

func add_experience(p_exp: int):
	"""增加经验值"""
	current_experience += p_exp
	experience_gained.emit(p_exp)
	
	print("获得经验值: ", p_exp, " (总经验: ", current_experience, ")")
	
	# 检查升级
	check_level_up()

func check_level_up():
	"""检查是否升级"""
	while current_experience >= experience_to_next_level:
		current_experience -= experience_to_next_level
		current_level += 1
		experience_to_next_level = calculate_next_level_exp(current_level)
		
		print("玩家升级! 新等级: ", current_level)
		level_up.emit(current_level)
		
		# 升级时可以触发升级选择界面
		if GameManager:
			GameManager.change_state(GameManager.GameState.LEVEL_UP)

func calculate_next_level_exp(level: int) -> int:
	"""计算下一级所需经验值"""
	return 100 + (level - 1) * 50  # 基础100，每级增加50

func get_experience_progress() -> float:
	"""获取当前级别经验进度 (0.0 - 1.0)"""
	if experience_to_next_level <= 0:
		return 1.0
	return float(current_experience) / float(experience_to_next_level)

# === 升级增益管理 ===

func apply_upgrade(upgrade_type: String, value: float = 1.0):
	"""应用升级增益"""
	if not player_stats:
		return
	
	selected_upgrades.append(upgrade_type)
	
	match upgrade_type:
		"max_health":
			player_stats.health_bonus += int(value)
			# 如果是增加最大血量，同时回复对应血量
			heal_player(int(value))
		"armor":
			player_stats.armor_value += int(value)
		"damage":
			player_stats.damage_multiplier += value
		"move_speed":
			player_stats.move_speed += value
		"energy_regen":
			player_stats.energy_regen_rate += value
		"max_energy":
			player_stats.max_energy += int(value)
		_:
			player_stats.special_effects.append(upgrade_type)
	
	stats_updated.emit()
	print("应用升级: ", upgrade_type, " 值: ", value)

func has_upgrade(upgrade_type: String) -> bool:
	"""检查是否拥有某个升级"""
	return upgrade_type in selected_upgrades

func get_upgrade_count(upgrade_type: String) -> int:
	"""获取某个升级的次数"""
	return selected_upgrades.count(upgrade_type)

# === 装备管理 ===

func equip_primary_weapon(weapon_data: WeaponData):
	"""装备主武器"""
	player_stats.primary_weapon = weapon_data
	print("PlayerDataManager：装备了主武器（数据）: ", weapon_data.weapon_name if weapon_data else "无")

func equip_secondary_weapon(weapon_data: WeaponData):
	"""装备副武器"""
	player_stats.secondary_weapon = weapon_data
	print("PlayerDataManager：装备了副武器（数据）: ", weapon_data.weapon_name if weapon_data else "无")

func equip_primary_skill(skill_data: SkillData):
	"""装备主技能"""
	player_stats.primary_skill = skill_data
	if skill_data:
		print("PlayerDataManager：装备了主技能（数据）: ", skill_data.skill_display_name, 
			  " 类型:", skill_data.get_skill_type_names())
	else:
		print("PlayerDataManager：卸载了主技能")

func equip_secondary_skill(skill_data: SkillData):
	"""装备副技能"""
	player_stats.secondary_skill = skill_data
	if skill_data:
		print("PlayerDataManager：装备了副技能（数据）: ", skill_data.skill_display_name,
			  " 类型:", skill_data.get_skill_type_names())
	else:
		print("PlayerDataManager：卸载了副技能")

func get_primary_weapon() -> WeaponData:
	"""获取主武器数据"""
	return player_stats.primary_weapon if player_stats else null

func get_secondary_weapon() -> WeaponData:
	"""获取副武器数据"""
	return player_stats.secondary_weapon if player_stats else null

func get_primary_skill() -> SkillData:
	"""获取主技能数据"""
	return player_stats.primary_skill if player_stats else null

func get_secondary_skill() -> SkillData:
	"""获取副技能数据"""
	return player_stats.secondary_skill if player_stats else null

# === 技能相关的新方法 ===

func get_skill_info_by_slot(slot: int) -> Dictionary:
	"""根据槽位获取技能详细信息"""
	var skill_data = get_primary_skill() if slot == 0 else get_secondary_skill()
	if not skill_data:
		return {}
	
	var info = {
		"name": skill_data.skill_display_name,
		"description": skill_data.description,
		"skill_types": skill_data.get_skill_type_names(),
		"energy_cost": skill_data.energy_cost if slot == 0 else 0,
		"cooldown_time": skill_data.cooldown_time,
		"cast_time": skill_data.cast_time,
		"can_move_while_casting": skill_data.can_move_while_casting,
		"max_level": skill_data.max_level
	}
	
	# 根据技能类型添加具体信息
	if skill_data.has_skill_type(SkillData.SkillCategory.DAMAGE):
		info[		"damage_info"] = {
			"damage": skill_data.damage,
			"extra_damage": skill_data.extra_damage,
			"damage_multiplier": skill_data.damage_multiplier,
			"continue_damage": skill_data.continue_damage,
			"continue_damage_time": skill_data.continue_damage_time,
			"continue_damage_frequent": skill_data.continue_damage_frequent,
			"damage_target_numb": skill_data.damage_target_numb,
			"damage_duration": skill_data.damage_duration,
			"damage_range": skill_data.damage_range,
			"circle_position": skill_data.circle_position,
			"action_type": skill_data.action_type,
			"damage_type": skill_data.damage_type
		}
	
	if skill_data.has_skill_type(SkillData.SkillCategory.CONTROL):
		info["control_info"] = {
			"control_range": skill_data.control_range,
			"control_target_numb": skill_data.control_target_numb,
			"control_continue_time": skill_data.control_continue_time,
			"control_effect_type": skill_data.control_effect_type
		}
	
	if skill_data.has_skill_type(SkillData.SkillCategory.MOVEMENT):
		info["movement_info"] = {
			"distance": skill_data.distance,
			"dash_time": skill_data.dash_time,
			"dash_effect_continue_time": skill_data.dash_effect_continue_time,
			"dash_type": skill_data.dash_type
		}
	
	if skill_data.has_skill_type(SkillData.SkillCategory.BUFF):
		info["buff_info"] = {
			"can_multiplier": skill_data.can_multiplier,
			"buff_continue_time": skill_data.buff_continue_time,
			"buff_type": skill_data.buff_type,
			"buff_value": skill_data.buff_value
		}
	
	return info

func is_skill_damage_type(slot: int) -> bool:
	"""检查技能是否为伤害类型"""
	var skill_data = get_primary_skill() if slot == 0 else get_secondary_skill()
	return skill_data and skill_data.has_skill_type(SkillData.SkillCategory.DAMAGE)

func is_skill_movement_type(slot: int) -> bool:
	"""检查技能是否为位移类型"""
	var skill_data = get_primary_skill() if slot == 0 else get_secondary_skill()
	return skill_data and skill_data.has_skill_type(SkillData.SkillCategory.MOVEMENT)

func is_skill_control_type(slot: int) -> bool:
	"""检查技能是否为控制类型"""
	var skill_data = get_primary_skill() if slot == 0 else get_secondary_skill()
	return skill_data and skill_data.has_skill_type(SkillData.SkillCategory.CONTROL)

func is_skill_buff_type(slot: int) -> bool:
	"""检查技能是否为增益类型"""
	var skill_data = get_primary_skill() if slot == 0 else get_secondary_skill()
	return skill_data and skill_data.has_skill_type(SkillData.SkillCategory.BUFF)

# === 属性计算 ===

func get_final_damage_multiplier() -> float:
	"""获取最终伤害倍率"""
	return player_stats.damage_multiplier if player_stats else 1.0

func get_final_move_speed() -> float:
	"""获取最终移动速度"""
	return player_stats.move_speed if player_stats else 300.0

func get_armor_value() -> int:
	"""获取护甲值"""
	return player_stats.armor_value if player_stats else 0

# === 获取玩家统计数据 ===

func get_player_stats() -> PlayerStats:
	"""获取玩家数据"""
	return player_stats

func emit_all_stat_signals():
	"""发送所有状态信号"""
	if not player_stats:
		return
	
	health_changed.emit(player_stats.current_health, get_max_health())
	energy_changed.emit(player_stats.current_energy, player_stats.max_energy)
	
	for i in range(4):  # 4种弹药类型
		ammo_changed.emit(i, get_ammo(i))

# === 存档相关 ===

func save_player_data() -> Dictionary:
	"""保存玩家数据到字典"""
	if not player_stats:
		return {}
	
	return {
		"current_health": player_stats.current_health,
		"current_energy": player_stats.current_energy,
		"normal_ammo": player_stats.normal_ammo,
		"special_ammo": player_stats.special_ammo,
		"arrows": player_stats.arrows,
		"mana_essence": player_stats.mana_essence,
		"current_level": current_level,
		"current_experience": current_experience,
		"selected_upgrades": selected_upgrades,
		"damage_multiplier": player_stats.damage_multiplier,
		"health_bonus": player_stats.health_bonus,
		"armor_value": player_stats.armor_value
	}

func load_player_data(data: Dictionary):
	"""从字典加载玩家数据"""
	if not player_stats:
		initialize_default_stats()
	
	player_stats.current_health = data.get("current_health", 100)
	player_stats.current_energy = data.get("current_energy", 100)
	player_stats.normal_ammo = data.get("normal_ammo", 120)
	player_stats.special_ammo = data.get("special_ammo", 30)
	player_stats.arrows = data.get("arrows", 50)
	player_stats.mana_essence = data.get("mana_essence", 80)
	
	current_level = data.get("current_level", 1)
	current_experience = data.get("current_experience", 0)
	selected_upgrades = data.get("selected_upgrades", [])
	
	player_stats.damage_multiplier = data.get("damage_multiplier", 1.0)
	player_stats.health_bonus = data.get("health_bonus", 0)
	player_stats.armor_value = data.get("armor_value", 0)
	
	emit_all_stat_signals()
	print("玩家数据加载完成")

# === 调试功能 ===

func debug_print_stats():
	"""调试打印玩家状态"""
	if not player_stats:
		print("玩家数据未初始化")
		return
	
	print("=== 玩家数据 ===")
	print("血量: ", player_stats.current_health, "/", get_max_health())
	print("能量: ", player_stats.current_energy, "/", player_stats.max_energy)
	print("等级: ", current_level, " (经验: ", current_experience, "/", experience_to_next_level, ")")
	print("普通子弹: ", player_stats.normal_ammo)
	print("特殊子弹: ", player_stats.special_ammo)
	print("箭矢: ", player_stats.arrows)
	print("魔力精华: ", player_stats.mana_essence)
	print("伤害倍率: ", player_stats.damage_multiplier)
	print("护甲值: ", player_stats.armor_value)
	print("移动速度: ", player_stats.move_speed)
	print("升级次数: ", selected_upgrades.size())
	
	# 技能信息
	if player_stats.primary_skill:
		print("主技能: ", player_stats.primary_skill.skill_display_name, 
			  " 类型:", player_stats.primary_skill.get_skill_type_names())
	else:
		print("主技能: 无")
		
	if player_stats.secondary_skill:
		print("副技能: ", player_stats.secondary_skill.skill_display_name,
			  " 类型:", player_stats.secondary_skill.get_skill_type_names())
	else:
		print("副技能: 无")
	
	print("====================")
