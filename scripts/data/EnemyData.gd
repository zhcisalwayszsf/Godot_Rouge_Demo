extends Resource
class_name EnemyData

@export_group("基础信息")
@export var enemy_name: String = "小怪模板"
@export var description: String = "大部分小怪的通用模板"
@export_enum( "射手","重甲兵","法师", "辅助","近战兵") var enemy_type: int = 0

@export_group("基础属性") 
@export var max_health: float = 50
@export var max_armor: float = 50
@export var move_speed: float = 150.0
@export var attack_damage: float = 10
@export var attack_distance: float = 100.0
@export var detection_range: float = 300.0
@export var attack_cooldown: float = 1.5

@export_group("AI行为")
@export var patrol_radius: float = 100.0
@export_enum("被动", "主动", "狂暴") var ai_behavior: int = 0

@export_group("掉落")
@export var drop_chance: float = 0.1
@export var exp_value: int = 10

# ================================
