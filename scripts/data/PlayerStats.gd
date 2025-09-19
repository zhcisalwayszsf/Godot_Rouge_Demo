#res://scripts/data/PlayerStats.gd
extends Resource
class_name PlayerStats

# 基础属性
@export_group("基础属性")
@export var max_health: int = 100
@export var current_health: int = 100
@export var max_energy: int = 100
@export var current_energy: int = 100
@export var energy_regen_rate: float = 10.0  # 每秒回复
@export var move_speed: float = 300.0

# 装备槽位
@export_group("装备")
@export var primary_weapon: WeaponData
@export var secondary_weapon: WeaponData

#SkillData
@export_group("技能")
@export var primary_skill: SkillData
@export var secondary_skill: SkillData
# 弹药系统
@export_group("弹药")
@export var normal_ammo: int = 100
@export var special_ammo: int = 20
@export var arrows: int = 30
@export var mana_essence: int = 50

# 升级增益
@export_group("升级增益")
@export var damage_multiplier: float = 1.0
@export var health_bonus: int = 0
@export var armor_value: int = 0
@export var special_effects: Array[String] = []
