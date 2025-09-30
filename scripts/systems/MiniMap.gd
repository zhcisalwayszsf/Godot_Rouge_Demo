# MiniMap.gd
extends CanvasLayer

@onready var minimap_tiles: TileMapLayer = $MiniMapTiles
@onready var player_marker: Sprite2D = $PlayerMarker

# 小地图配置 - 可以随意修改这些值
const ROOM_WIDTH_TILES: int = 12   # 房间宽度
const ROOM_HEIGHT_TILES: int = 10  # 房间高度
const ROOM_SPACING: int = -1       # 房间间距

var level_data: Dictionary = {}
var room_positions: Dictionary = {}
var current_room: String = ""
var grid_offset: Vector2i = Vector2i.ZERO

func _ready():
	if GameManager.has_signal("player_entered_room"):
		GameManager.player_entered_room.connect(_on_player_entered_room)
	else:
		push_warning("GameManager缺少player_entered_room信号")
	
	if minimap_tiles:
		minimap_tiles.clear()
	
	if player_marker:
		#player_marker.modulate = Color.RED
		player_marker.z_index = 10

func setup_minimap(p_level_data: Dictionary):
	"""初始化小地图"""
	level_data = p_level_data
	room_positions.clear()
	
	if not minimap_tiles:
		push_error("minimap_tiles节点不存在")
		return
	
	minimap_tiles.clear()
	
	if not level_data.has("all_rooms_info"):
		push_error("level_data缺少all_rooms_info")
		return
	
	var all_rooms = level_data.get("all_rooms_info", {})
	if all_rooms.is_empty():
		push_warning("没有房间信息")
		return
	
	# 收集房间数据
	var min_x = 999
	var min_y = 999
	var room_data_list = []
	
	for room_key in all_rooms:
		var room_info = all_rooms[room_key]
		var grid_pos = room_info.get("grid_position")
		var room_name = room_info.get("room_name", "")
		
		if room_name.is_empty() or grid_pos == null:
			continue
		
		if grid_pos is Vector2i:
			min_x = mini(min_x, grid_pos.x)
			min_y = mini(min_y, grid_pos.y)
			
			room_data_list.append({
				"room_name": room_name,
				"grid_pos": grid_pos,
				"connections": room_info.get("connections", [])
			})
	
	if room_data_list.is_empty():
		push_error("没有找到有效的房间数据")
		return
	
	grid_offset = Vector2i(min_x, min_y)
	
	#print("=== 小地图设置 ===")
	#print("房间尺寸: %dx%d, 间距: %d" % [ROOM_WIDTH_TILES, ROOM_HEIGHT_TILES, ROOM_SPACING])
	#print("房间总数: ", room_data_list.size())
	
	
	# 绘制所有房间
	for room_data in room_data_list:
		var room_name = room_data["room_name"]
		var grid_pos = room_data["grid_pos"]
		var connections = room_data["connections"]  # 获取连接信息
		
		# 计算瓦片基准位置
		var normalized_pos = grid_pos - grid_offset
		var tile_base_pos = Vector2i(
			normalized_pos.x * (ROOM_WIDTH_TILES + ROOM_SPACING),
			normalized_pos.y * (ROOM_HEIGHT_TILES + ROOM_SPACING)
		)
		
		# 绘制房间（传入连接信息）
		_draw_room_rectangle(tile_base_pos, connections)
		
		# 计算并保存房间中心
		var room_center = Vector2i(
			tile_base_pos.x + ROOM_WIDTH_TILES / 2 ,
			tile_base_pos.y + ROOM_HEIGHT_TILES / 2 
		)
		room_positions[room_name] = room_center
	
	# 初始化玩家标记
	if room_positions.has("room1"):
		update_player_position("room1")

func _draw_room_rectangle(base_pos: Vector2i, connections: Array):
	"""绘制带开口的中空矩形
	connections: Direction枚举数组 [LEFT=0, RIGHT=1, TOP=2, BOTTOM=3]
	"""
	
	# 如果尺寸太小，绘制实心矩形
	if ROOM_WIDTH_TILES < 2 or ROOM_HEIGHT_TILES < 2:
		for x in range(ROOM_WIDTH_TILES):
			for y in range(ROOM_HEIGHT_TILES):
				minimap_tiles.set_cell(base_pos + Vector2i(x, y), 0, Vector2i(0, 0))
		return
	
	# 计算开口大小（边长的1/3，最小1）
	var opening_width = maxi(1, ROOM_WIDTH_TILES / 3-1)   # 上下开口宽度
	var opening_height = maxi(1, ROOM_HEIGHT_TILES / 3-1)  # 左右开口高度
	
	# 计算开口中心位置
	var top_opening_start = (ROOM_WIDTH_TILES - opening_width) / 2
	var bottom_opening_start = (ROOM_WIDTH_TILES - opening_width) / 2
	var left_opening_start = (ROOM_HEIGHT_TILES - opening_height) / 2
	var right_opening_start = (ROOM_HEIGHT_TILES - opening_height) / 2
	
	# 检查各方向是否有开口
	var has_left = 0 in connections    # Direction.LEFT = 0
	var has_right = 1 in connections   # Direction.RIGHT = 1
	var has_top = 2 in connections     # Direction.TOP = 2
	var has_bottom = 3 in connections  # Direction.BOTTOM = 3
	
	# 绘制矩形
	for x in range(ROOM_WIDTH_TILES):
		for y in range(ROOM_HEIGHT_TILES):
			var is_border = (y == 0 or y == ROOM_HEIGHT_TILES - 1 or 
							x == 0 or x == ROOM_WIDTH_TILES - 1)
			
			if not is_border:
				continue
			
			var should_draw = true
			
			# 检查是否在开口位置
			# 左边开口（x=0）
			if x == 0 and has_left:
				if y >= left_opening_start and y < left_opening_start + opening_height:
					should_draw = false
			
			# 右边开口（x=最右）
			if x == ROOM_WIDTH_TILES - 1 and has_right:
				if y >= right_opening_start and y < right_opening_start + opening_height:
					should_draw = false
			
			# 顶边开口（y=0）
			if y == 0 and has_top:
				if x >= top_opening_start and x < top_opening_start + opening_width:
					should_draw = false
			
			# 底边开口（y=最下）
			if y == ROOM_HEIGHT_TILES - 1 and has_bottom:
				if x >= bottom_opening_start and x < bottom_opening_start + opening_width:
					should_draw = false
			
			# 绘制瓦片
			if should_draw:
				minimap_tiles.set_cell(base_pos + Vector2i(x, y), 0, Vector2i(0, 0))

func update_player_position(room_name: String):
	"""更新玩家标记位置"""
	if not player_marker:
		return
		
	if not room_positions.has(room_name):
		push_warning("未找到房间: " + room_name)
		return
	
	current_room = room_name
	var room_center = room_positions[room_name]
	
	if minimap_tiles:
		var world_pos = minimap_tiles.map_to_local(room_center) + Vector2(-10,0)
		player_marker.position = world_pos
		print("玩家位置: %s -> 瓦片(%d,%d) 世界(%.1f,%.1f)" % 
			[room_name, room_center.x, room_center.y, world_pos.x, world_pos.y])

func _on_player_entered_room(room_name: String):
	"""响应玩家进入房间"""
	update_player_position(room_name)
