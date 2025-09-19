# 修复3: 完善EnemyData.gd（你的文件目前只有extends Resource）
extends Resource
class_name EnemyData

@export_group("基础信息")
@export var enemy_name: String = ""
@export var description: String = ""
@export_enum("小怪", "射手", "近战兵", "重甲兵", "法师") var enemy_type: int = 0

@export_group("基础属性") 
@export var max_health: int = 50
@export var move_speed: float = 150.0
@export var attack_damage: int = 10
@export var attack_range: float = 100.0
@export var detection_range: float = 300.0
@export var attack_cooldown: float = 1.5

@export_group("AI行为")
@export var patrol_radius: float = 100.0
@export_enum("被动", "主动", "狂暴") var ai_behavior: int = 0

@export_group("掉落")
@export var drop_chance: float = 0.1
@export var exp_value: int = 10

# ================================
