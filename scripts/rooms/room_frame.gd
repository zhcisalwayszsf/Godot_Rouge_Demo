# room_frame.gd
extends Node2D
@onready var detection_area :Area2D = $Area2D

var tiles_floor : TileMapLayer
var tiles_wall : TileMapLayer

var spring_floor
var spring_wall
var desert_floor
var desert_wall
var forest_floor
var forest_wall
var dungeon_floor
var dungeon_wall
var coast_floor
var coast_wall
#var test_floor
#var test_wall

# TileMap的拐角定位点
var cornor_lt : Vector2i = Vector2i(-27,-17)
var cornor_lb : Vector2i = Vector2i(-27,15)
var cornor_rb : Vector2i = Vector2i(25,15)
var cornor_rt : Vector2i = Vector2i(25,-17)

var room_info: LevelFrameGenerator.RoomInfo
var wall_body: StaticBody2D  ## 墙体碰撞节点
var room_name

signal player_entered(room_name: String)

func _init():
	spring_floor= preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_floor.tscn")
	spring_wall = preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_rect_wall.tscn")
	desert_floor= preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_floor.tscn")
	desert_wall = preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_rect_wall.tscn")
	forest_floor= preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_floor.tscn")
	forest_wall = preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_rect_wall.tscn")
	dungeon_floor= preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_floor.tscn")
	dungeon_wall = preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_rect_wall.tscn")
	coast_floor= preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_floor.tscn")
	coast_wall = preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_rect_wall.tscn")



func _ready():
	# 连接区域检测信号
	if detection_area:
		detection_area.body_entered.connect(_on_player_entered)
	



func load_tiles(room_theme):
	match room_theme:
		0:
			tiles_floor = spring_floor.instantiate()
			tiles_wall = spring_wall.instantiate()
		1:
			tiles_floor = desert_floor.instantiate()
			tiles_wall = desert_wall.instantiate()
		2:
			tiles_floor = forest_floor.instantiate()
			tiles_wall = forest_wall.instantiate()
		3:
			tiles_floor = dungeon_floor.instantiate()
			tiles_wall = desert_wall.instantiate()
		4:
			tiles_floor = coast_floor.instantiate()
			tiles_wall = coast_wall.instantiate()
		_:
			tiles_floor = spring_floor.instantiate()
			tiles_wall = spring_wall.instantiate()

func instantiate_tile(p_room_info: LevelFrameGenerator.RoomInfo):
	room_info = p_room_info
	room_name = p_room_info.room_name  ## 保存房间名称
	load_tiles(room_info.level_theme_in_room)
	set_cornor_tile()
	cancel_door()
	add_door_walls()  # 新增：添加门洞墙体
	tiles_floor.add_child(tiles_wall)
	tiles_floor.scale = Vector2(2, 2)
	add_child(tiles_floor)

func set_cornor_tile():
	## 获取房间邻居信息
	var lt_info = get_neighbor("lt")
	var lb_info = get_neighbor("lb")
	var rb_info = get_neighbor("rb")
	var rt_info = get_neighbor("rt")
	
	# 左上角
	match lt_info.get("result"):
		1:
			tiles_wall.set_pattern(cornor_lt, tiles_wall.tile_set.get_pattern(8))
		2:
			match lt_info.get("neighbor"):
				"l":
					tiles_wall.set_pattern(cornor_lt, tiles_wall.tile_set.get_pattern(4))
				_:
					tiles_wall.set_pattern(cornor_lt, tiles_wall.tile_set.get_pattern(6))
		3:
			tiles_wall.set_pattern(cornor_lt, tiles_wall.tile_set.get_pattern(0))
	
	# 左下角
	match lb_info.get("result"):
		1:
			tiles_wall.set_pattern(cornor_lb, tiles_wall.tile_set.get_pattern(8))
		2:
			match lb_info.get("neighbor"):
				"l":
					tiles_wall.set_pattern(cornor_lb, tiles_wall.tile_set.get_pattern(5))
				_:
					tiles_wall.set_pattern(cornor_lb, tiles_wall.tile_set.get_pattern(6))
		3:
			tiles_wall.set_pattern(cornor_lb, tiles_wall.tile_set.get_pattern(1))
	
	# 右下角
	match rb_info.get("result"):
		1:
			tiles_wall.set_pattern(cornor_rb, tiles_wall.tile_set.get_pattern(8))
		2:
			match rb_info.get("neighbor"):
				"r":
					tiles_wall.set_pattern(cornor_rb, tiles_wall.tile_set.get_pattern(5))
				_:
					tiles_wall.set_pattern(cornor_rb, tiles_wall.tile_set.get_pattern(7))
		3:
			tiles_wall.set_pattern(cornor_rb, tiles_wall.tile_set.get_pattern(2))
	
	# 右上角
	match rt_info.get("result"):
		1:
			tiles_wall.set_pattern(cornor_rt, tiles_wall.tile_set.get_pattern(8))
		2:
			match rt_info.get("neighbor"):
				"r":
					tiles_wall.set_pattern(cornor_rt, tiles_wall.tile_set.get_pattern(4))
				_:
					tiles_wall.set_pattern(cornor_rt, tiles_wall.tile_set.get_pattern(7))
		3:
			tiles_wall.set_pattern(cornor_rt, tiles_wall.tile_set.get_pattern(3))

func get_neighbor(cornor: String) -> Dictionary:
	var result: int = 3
	match cornor:
		"lt":
			var l = room_info.neighbors[0] != null
			var t = room_info.neighbors[2] != null
			var diagonal = room_info.diagonal_neighbors[0]
			var neighbor = "l" if l else "t"
			if l:
				result -= 1
			if t:
				result -= 1
			if diagonal:
				result = 1
			return {"result": result, "neighbor": neighbor, "diagonal": diagonal}
		"lb":
			var l = room_info.neighbors[0] != null
			var b = room_info.neighbors[3] != null
			var diagonal = room_info.diagonal_neighbors[1]
			var neighbor = "l" if l else "b"
			if l:
				result -= 1
			if b:
				result -= 1
			if diagonal:
				result = 1
			return {"result": result, "neighbor": neighbor, "diagonal": diagonal}
		"rb":
			var r = room_info.neighbors[1] != null
			var b = room_info.neighbors[3] != null
			var diagonal = room_info.diagonal_neighbors[2]
			var neighbor = "r" if r else "b"
			if r:
				result -= 1
			if b:
				result -= 1
			if diagonal:
				result = 1
			return {"result": result, "neighbor": neighbor, "diagonal": diagonal}
		"rt":
			var r = room_info.neighbors[1] != null
			var t = room_info.neighbors[2] != null
			var diagonal = room_info.diagonal_neighbors[3]
			var neighbor = "r" if r else "t"
			if r:
				result -= 1
			if t:
				result -= 1
			if diagonal:
				result = 1
			return {"result": result, "neighbor": neighbor, "diagonal": diagonal}
	return {"result": result}

func cancel_door():
	"""填充瓷砖层的门洞"""
	# 检查LEFT方向
	if not (0 in room_info.connections):
		tiles_wall.set_pattern(Vector2i(cornor_lt.x, -3), tiles_wall.tile_set.get_pattern(10))
	
	# 检查RIGHT方向
	if not (1 in room_info.connections):
		tiles_wall.set_pattern(Vector2i(cornor_rt.x, -3), tiles_wall.tile_set.get_pattern(10))
	
	# 检查TOP方向
	if not (2 in room_info.connections):
		tiles_wall.set_pattern(Vector2i(-3, cornor_lt.y), tiles_wall.tile_set.get_pattern(9))
	
	# 检查BOTTOM方向
	if not (3 in room_info.connections):
		tiles_wall.set_pattern(Vector2i(-3, cornor_lb.y), tiles_wall.tile_set.get_pattern(9))

func add_door_walls():
	"""为未开口的门添加碰撞墙体"""
	# 获取或创建 Wall 节点
	wall_body = get_node_or_null("Wall")
	if not wall_body:
		push_warning("未找到 Wall 节点，无法添加门洞墙体")
		return
	
	# LEFT门 (位置: -832, 0, 尺寸: 64x128 纵向)
	if not (0 in room_info.connections):
		var shape = RectangleShape2D.new()
		shape.size = Vector2(64, 128)
		var collision = CollisionShape2D.new()
		collision.shape = shape
		collision.position = Vector2(-832, 0)
		collision.name = "DoorWall_Left"
		wall_body.add_child(collision)
	
	# RIGHT门 (位置: 832, 0, 尺寸: 64x128 纵向)
	if not (1 in room_info.connections):
		var shape = RectangleShape2D.new()
		shape.size = Vector2(64, 128)
		var collision = CollisionShape2D.new()
		collision.shape = shape
		collision.position = Vector2(832, 0)
		collision.name = "DoorWall_Right"
		wall_body.add_child(collision)
	
	# TOP门 (位置: 0, -512, 尺寸: 128x64 横向)
	if not (2 in room_info.connections):
		var shape = RectangleShape2D.new()
		shape.size = Vector2(128, 64)
		var collision = CollisionShape2D.new()
		collision.shape = shape
		collision.position = Vector2(0, -512)
		collision.name = "DoorWall_Top"
		wall_body.add_child(collision)
	
	# BOTTOM门 (位置: 0, 512, 尺寸: 128x64 横向)
	if not (3 in room_info.connections):
		var shape = RectangleShape2D.new()
		shape.size = Vector2(128, 64)
		var collision = CollisionShape2D.new()
		collision.shape = shape
		collision.position = Vector2(0, 512)
		collision.name = "DoorWall_Bottom"
		wall_body.add_child(collision)

func _on_player_entered(body: Node2D):
	if body.is_in_group("player") and not room_name.is_empty():
		# 发送到GameManager中转
		GameManager.on_player_entered_room(room_name)

		
		
		
