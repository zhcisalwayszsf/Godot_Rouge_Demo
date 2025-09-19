# res://scripts/data/LootData.gd
extends Resource
class_name LootData

# 基础信息
@export_group("基础信息")
@export var loot_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export_enum("普通子弹", "特殊子弹", "箭矢", "魔力精华", "血包") var loot_type: int = 0
@export_enum("普通", "稀有", "史诗", "传说") var rarity: int = 0

# 数量配置
@export_group("数量配置")
@export var min_amount: int = 1
@export var max_amount: int = 100

# 拾取配置
@export_group("拾取配置")
@export var auto_pickup: bool = true
@export var pickup_scene_path: String = ""

# 特殊效果
@export_group("特殊效果")
@export var special_effects: Array[String] = []
