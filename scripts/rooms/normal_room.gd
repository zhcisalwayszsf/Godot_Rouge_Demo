# normal_room.gd
# 通用房间脚本 - 挂载到每个房间场景的根节点上
extends Node2D


var tiles_floor : TileMapLayer
var tiles_wall : TileMapLayer

var cornor_lt : Vector2i = Vector2i(-27,-17)
var cornor_lb : Vector2i = Vector2i(-27,15)
var cornor_rb : Vector2i = Vector2i(25,15)
var cornor_rt : Vector2i = Vector2i(25,-17)



var room_info:NormalLevelGenerator.RoomInfo

var cornor:Array = [
	"lt","lb","rt","rb"
]

func _init() -> void:
	tiles_floor = preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_floor.tscn").instantiate()
	tiles_wall = preload("res://scenes/rooms/normal_rooms/floor_layers//Spring/spring_room_rect_wall.tscn").instantiate()

func instantiate_tile(p_room_info:NormalLevelGenerator.RoomInfo):
	room_info = p_room_info
	set_cornor_tile()
	cancel_door()
	tiles_floor.add_child(tiles_wall)
	tiles_floor.scale=Vector2(2,2)
	add_child(tiles_floor)
	pass



func set_cornor_tile():
	#获取房间邻居信息
	var lt_info =get_neighbor("lt")
	var lb_info =get_neighbor("lb")
	var rb_info =get_neighbor("rb")
	var rt_info =get_neighbor("rt")
	
	#左上角需要补几块
	match lt_info.get("result"):
		1:
			tiles_wall.set_pattern(cornor_lt,tiles_wall.tile_set.get_pattern(8))
		2:
			match lt_info.get("neighbor"):
				"l":
					tiles_wall.set_pattern(cornor_lt,tiles_wall.tile_set.get_pattern(4))
				_:
					tiles_wall.set_pattern(cornor_lt,tiles_wall.tile_set.get_pattern(6))
		3:
			tiles_wall.set_pattern(cornor_lt,tiles_wall.tile_set.get_pattern(0))
	#左下角需要补几块
	match lb_info.get("result"):
		1:
			tiles_wall.set_pattern(cornor_lb,tiles_wall.tile_set.get_pattern(8))
		2:
			match lb_info.get("neighbor"):
				"l":
					tiles_wall.set_pattern(cornor_lb,tiles_wall.tile_set.get_pattern(5))
				_:
					tiles_wall.set_pattern(cornor_lb,tiles_wall.tile_set.get_pattern(6))
		3:
			tiles_wall.set_pattern(cornor_lb,tiles_wall.tile_set.get_pattern(1))
	#右下角需要补几块
	match rb_info.get("result"):
		1:
			tiles_wall.set_pattern(cornor_rb,tiles_wall.tile_set.get_pattern(8))
		2:
			match rb_info.get("neighbor"):
				"r":
					tiles_wall.set_pattern(cornor_rb,tiles_wall.tile_set.get_pattern(5))
				_:
					tiles_wall.set_pattern(cornor_rb,tiles_wall.tile_set.get_pattern(7))
		3:
			tiles_wall.set_pattern(cornor_rb,tiles_wall.tile_set.get_pattern(2))
	#右上角需要补几块
	match rt_info.get("result"):
		1:
			tiles_wall.set_pattern(cornor_rt,tiles_wall.tile_set.get_pattern(8))
		2:
			match rt_info.get("neighbor"):
				"r":
					tiles_wall.set_pattern(cornor_rt,tiles_wall.tile_set.get_pattern(4))
				_:
					tiles_wall.set_pattern(cornor_rt,tiles_wall.tile_set.get_pattern(7))
		3:
			tiles_wall.set_pattern(cornor_rt,tiles_wall.tile_set.get_pattern(3))



func get_neighbor(cornor: String) -> Dictionary:
	var result: int = 3
	match cornor:
		"lt":
			var l = room_info.neighbors[0] != null  # LEFT = 0
			var t = room_info.neighbors[2] != null  # TOP = 2
			var diagonal = room_info.diagonal_neighbors[0]  # 左上对角线
			var neighbor = "l" if l else "t"
			if l:
				result -= 1
			if t:
				result -= 1
			if diagonal:
				result = 1
			return {
				"result": result,
				"neighbor": neighbor,
				"diagonal": diagonal
				}
		"lb":
			var l = room_info.neighbors[0] != null  # LEFT = 0
			var b = room_info.neighbors[3] != null  # BOTTOM = 3
			var diagonal = room_info.diagonal_neighbors[1]  # 左上对角线
			var neighbor = "l" if l else "b"
			if l:
				result -= 1
			if b:
				result -= 1
			if diagonal:
				result = 1
			return {
				"result": result,
				"neighbor": neighbor,
				"diagonal": diagonal
				}
		"rb":
			var r = room_info.neighbors[1] != null  # RIGHT = 1
			var b = room_info.neighbors[3] != null  # BOTTOM = 3
			var diagonal = room_info.diagonal_neighbors[2]  # 左上对角线
			var neighbor = "r" if r else "b"
			if r:
				result -= 1
			if b:
				result -= 1
			if diagonal:
				result = 1
			return {
				"result": result,
				"neighbor": neighbor,
				"diagonal": diagonal
				}
		"rt":
			var r = room_info.neighbors[1] != null  # RIGHT = 1
			var t = room_info.neighbors[2] != null  # TOP = 2
			var diagonal = room_info.diagonal_neighbors[3]  # 左上对角线
			var neighbor = "r" if r else "t"
			if r:
				result -= 1
			if t:
				result -= 1
			if diagonal:
				result = 1
			return {
				"result": result,
				"neighbor": neighbor,
				"diagonal": diagonal
				}
	return {"result": result}


func cancel_door():
	# 检查LEFT方向是否有连接
	if not (0 in room_info.connections):  # 0 = Direction.LEFT
		tiles_wall.set_pattern(Vector2i(cornor_lt.x,-3),tiles_wall.tile_set.get_pattern(10))
	
	# 检查RIGHT方向是否有连接
	if not (1 in room_info.connections):  # 1 = Direction.RIGHT
		tiles_wall.set_pattern(Vector2i(cornor_rt.x,-3),tiles_wall.tile_set.get_pattern(10))

	# 检查TOP方向是否有连接
	if not (2 in room_info.connections):  # 2 = Direction.TOP
		tiles_wall.set_pattern(Vector2i(-3,cornor_lt.y),tiles_wall.tile_set.get_pattern(9))
	
	# 检查BOTTOM方向是否有连接
	if not (3 in room_info.connections):  # 3 = Direction.BOTTOM
		tiles_wall.set_pattern(Vector2i(-3,cornor_lb.y),tiles_wall.tile_set.get_pattern(9))
