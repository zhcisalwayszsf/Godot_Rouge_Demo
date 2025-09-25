#res://scripts/data/WeaponData.gd
extends Resource
class_name WeaponData

# 基础信息
@export_group("基础信息")
@export var weapon_name: String = ""
@export var weapon_display_name: String = ""
@export var description: String = ""
@export_enum("枪械", "近战", "魔法", "投掷") var weapon_type: int = 0
#@export_enum("无（普通）", "一次性", "诅咒", "多格占位型") var special_type: int = 0
@export_enum("普通", "稀有", "史诗", "传说") var rarity: int = 0
@export var magazine_size: int = 30  # 弹匣容量，-1表示无限制
@export var current_magazine_ammo: int = 30  # 当前弹夹子弹数（运行时数据）
@export_enum("单发","连发","三连发") var fire_mode:int = 0
@export var burst_count: int = 3 # 如果是三连发，每次发射的子弹数

# 战斗属性
@export_group("战斗属性")
@export var base_damage: float = 10
@export var extra_damage: float = 0
@export var fire_rate: float = 4.0  # 射速 发/秒
@export var click_rate: float = 1 # 鼠标松开后再次按下的最小间隔 次/秒
@export var weapon_precision:float = 0.8 #射击精准度
@export var weapon_precision_angle:float=10 #射击扩散角度
@export var bullet_size: float = 1 # 子弹大小
@export var attack_distance: float = 800.0 # 射程
@export var bullet_speed:float = 1000
@export_enum("普通子弹", "特殊子弹", "箭矢", "魔力精华", "无消耗") var ammo_type: int = 0
@export_enum("普通", "穿甲", "燃烧", "中毒", "百分比") var damage_type: int = 0
@export var reload_time: float = 2.0  # 换弹时间（秒）


# 特殊机制
@export_group("特殊机制")
@export var needs_aiming: bool = false
@export_enum("直线", "抛物线", "追踪","穿透") var projectile_type: int = 0
@export var special_effects: Array[String] = []
