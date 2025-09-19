# 完善RoomTemplate.gd（你的文件目前只有extends Resource）
extends Resource
class_name RoomTemplate

@export_group("房间信息")
@export var template_name: String = ""
@export_enum("小", "中", "大") var room_size: int = 1
@export var dimensions: Vector2 = Vector2(1200, 900)

@export_group("生成点位")
@export var enemy_spawn_points: Array[Vector2] = []
@export var item_spawn_points: Array[Vector2] = []
@export var cover_positions: Array[Vector2] = []
@export var player_spawn_point: Vector2 = Vector2(600, 450)

@export_group("房间限制")
@export var max_enemies: int = 12
@export var max_items: int = 50
