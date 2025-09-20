extends Node

# 最终伤害
var final_damage: float = 0

# 武器伤害
var primary_weapon_extra_damage: float = 0
var primary_weapon_default_damage: float = 0

var secondary_weapon_extra_damage: float = 0
var secondary_weapon_default_damage: float = 0

# 技能伤害
var primary_skill_extra_damage: float = 0
var primary_skill_default_damage: float = 0

var secondary_skill_extra_damage: float = 0
var secondary_skill_default_damage: float = 0

# 人物等级伤害
var levelup_damage: float = 0
var levelup_extra_damage: float = 0

# 各种伤害倍数器
var primary_weapon_damage_multiplier: float = 1
var secondary_weapon_damage_multiplier: float = 1
var primary_skill_damage_multiplier: float = 1
var secondary_skill_damage_multiplier: float = 1
var levelup_damage_multiplier: float = 1

# Buff伤害增益
var buff_damage_multiplier: float = 1
var buff_damage_extra_damage: float = 0

## 本地信号组
signal update_weapon(actived_weapon_slot: int)
signal update_skill(actived_skill_slot: int)

func _ready():
	print("DamageHandleSystem 初始化完成")
	connect_needed_signals()

func _process(delta):
	return

### 获取参数

# 获取武器数据到本地
func update_weapon_damage(p_weapon_data: WeaponData, p_slot: int):
	if WeaponSystem.current_primary_weapon_data:
		primary_weapon_default_damage = WeaponSystem.current_primary_weapon_data.base_damage
		primary_weapon_extra_damage = WeaponSystem.current_primary_weapon_data.extra_damage
		print("DamageSystem:获取了武器槽1数据。" 
		+ WeaponSystem.current_primary_weapon_data.weapon_display_name
		+ "：baseDamage=" + str(primary_weapon_default_damage)
		+ "；extraDamage=" + str(primary_weapon_extra_damage))
	else: 
		primary_weapon_default_damage = 0
		primary_weapon_extra_damage = 0
		print("DamageSystem，警告:未获取武器槽1数据。")
		
	if WeaponSystem.current_secondary_weapon_data:
		secondary_weapon_default_damage = WeaponSystem.current_secondary_weapon_data.base_damage
		secondary_weapon_extra_damage = WeaponSystem.current_secondary_weapon_data.extra_damage
		print("DamageSystem:获取了武器槽2数据。" 
		+ WeaponSystem.current_secondary_weapon_data.weapon_display_name 
		+ "：baseDamage=" + str(secondary_weapon_default_damage)
		+ "；extraDamage=" + str(secondary_weapon_extra_damage))
	else: 
		secondary_weapon_default_damage = 0
		secondary_weapon_extra_damage = 0
		print("DamageSystem，警告:未获取武器槽2数据。")
	
	update_weapon.emit(WeaponSystem.active_weapon_slot)

# 获取技能数据到本地 - 适配新的SkillData结构
func update_skill_damage(p_skill_data: SkillData, slot: int):
	if SkillSystem.primary_skill_data:
		primary_skill_default_damage = SkillSystem.primary_skill_data.damage
		primary_skill_extra_damage = SkillSystem.primary_skill_data.extra_damage
		primary_skill_damage_multiplier = SkillSystem.primary_skill_data.damage_multiplier
		
		print("DamageSystem:获取了技能槽1数据。" 
		+ SkillSystem.primary_skill_data.skill_display_name
		+ "：baseDamage=" + str(primary_skill_default_damage)
		+ "：extraDamage=" + str(primary_skill_extra_damage)
		+ "：multiplier=" + str(primary_skill_damage_multiplier))
	else: 
		primary_skill_default_damage = 0
		primary_skill_extra_damage = 0
		primary_skill_damage_multiplier = 1.0
		print("DamageSystem，警告:未获取技能槽1数据。")
		
	if SkillSystem.secondary_skill_data:
		secondary_skill_default_damage = SkillSystem.secondary_skill_data.damage
		secondary_skill_extra_damage = SkillSystem.secondary_skill_data.extra_damage
		secondary_skill_damage_multiplier = SkillSystem.secondary_skill_data.damage_multiplier
		
		print("DamageSystem:获取了技能槽2数据。" 
		+ SkillSystem.secondary_skill_data.skill_display_name
		+ "：baseDamage=" + str(secondary_skill_default_damage)
		+ "：extraDamage=" + str(secondary_skill_extra_damage)
		+ "：multiplier=" + str(secondary_skill_damage_multiplier))
	else: 
		secondary_skill_default_damage = 0
		secondary_skill_extra_damage = 0
		secondary_skill_damage_multiplier = 1.0
		print("DamageSystem，警告:未获取技能槽2数据。")
	update_weapon.emit(WeaponSystem.active_weapon_slot)
	update_skill.emit(slot)

# 获取等级数据
func get_level_damage(t):
	return

### 信号连接器
func connect_needed_signals():
	WeaponSystem.weapon_equipped.connect(update_weapon_damage)
	WeaponSystem.weapon_unequipped.connect(update_weapon_damage)
	
	SkillSystem.skill_equipped.connect(update_skill_damage)
	SkillSystem.skill_unequipped.connect(update_skill_damage)
	
	update_weapon.connect(calculate_weapon_damage)
	update_skill.connect(calculate_weapon_damage)

### 伤害合成 - 装备或技能改变时触发

func calculate_weapon_damage(p_active_weapon: int)->float:
	"""计算武器伤害"""
	var p_multiplier: float = 1.0
	
	# 检查技能是否提供武器伤害增益
	if SkillSystem.primary_skill_is_active and SkillSystem.primary_skill_data:
		if SkillSystem.primary_skill_data.can_multiplier:
			p_multiplier *= primary_skill_damage_multiplier
	
	if SkillSystem.secondary_skill_is_active and SkillSystem.secondary_skill_data:
		if SkillSystem.secondary_skill_data.can_multiplier:
			p_multiplier *= secondary_skill_damage_multiplier
	
	match p_active_weapon:
		0:
			final_damage = (primary_weapon_default_damage * p_multiplier) + primary_weapon_extra_damage
		1:
			final_damage = (secondary_weapon_default_damage * p_multiplier) + secondary_weapon_extra_damage
	return final_damage
	print("DamageSystem: 计算武器伤害，最终伤害=", final_damage)

func get_weapon_damage() -> float:
	"""获取当前武器伤害"""
	return final_damage

### Debug功能

func debug_print_damage_info():
	"""调试输出伤害信息"""
	print("=== DamageSystem 状态 ===")
	print("最终武器伤害: ", final_damage)
	print("主武器基础伤害: ", primary_weapon_default_damage)
	print("主武器额外伤害: ", primary_weapon_extra_damage)
	print("副武器基础伤害: ", secondary_weapon_default_damage)
	print("副武器额外伤害: ", secondary_weapon_extra_damage)
	print("主技能基础伤害: ", primary_skill_default_damage)
	print("主技能额外伤害: ", primary_skill_extra_damage)
	print("副技能基础伤害: ", secondary_skill_default_damage)
	print("副技能额外伤害: ", secondary_skill_extra_damage)
	print("Buff伤害倍率: ", buff_damage_multiplier)
	print("Buff额外伤害: ", buff_damage_extra_damage)
	print("==========================")
