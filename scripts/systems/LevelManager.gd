# LevelManager.gd
extends Node

# 房间类型枚举
enum RoomType {
	NORMAL_COMBAT,    # 普通战斗房
	BOSS,             # Boss房
	TREASURE,         # 宝箱/奖励房
	SHOP,             # 商店房
	REST,             # 休息房
	CORRIDOR,         # 走廊/过渡房
	START             # 起始房
}

# 内容生成模式
enum ContentMode {
	A_STAR_PATTERN,   # A类：精心设计
	B_MIXED_BLOCKS    # B类：积木拼接
}

# 房间数据结构
class RoomData:
	var room_name: String
	var room_type: RoomType
	var content_mode: ContentMode
	var floor_level: int
	var grid_position: Vector2i
	var connections: Array
	var is_populated: bool = false
	
	func _init(name: String, type: RoomType, mode: ContentMode, level: int):
		room_name = name
		room_type = type
		content_mode = mode
		floor_level = level

# 存储当前关卡信息
var current_level_data: Dictionary = {}
var current_floor_level: int = 1
var rooms_data: Dictionary = {}  # key: room_name, value: RoomData

# A/B类模板资源池
var a_templates: Dictionary = {
	RoomType.BOSS: [
		"res://scenes/content_templates/a_patterns/boss_arena_1.tscn",
		"res://scenes/content_templates/a_patterns/boss_arena_2.tscn"
	],
	RoomType.TREASURE: [
		"res://scenes/content_templates/a_patterns/treasure_room_1.tscn"
	],
	RoomType.SHOP: [
		"res://scenes/content_templates/a_patterns/shop_room_1.tscn"
	],
	RoomType.CORRIDOR: [
		"res://scenes/content_templates/a_patterns/corridor_1.tscn",
		"res://scenes/content_templates/a_patterns/corridor_2.tscn"
	],
	RoomType.NORMAL_COMBAT: [
		"res://scenes/content_templates/a_patterns/combat_layout_1.tscn",
		"res://scenes/content_templates/a_patterns/combat_layout_2.tscn"
	]
}

var b_templates: Dictionary = {
	RoomType.NORMAL_COMBAT: [
		"res://scenes/content_templates/b_blocks/mixed_blocks_peaceful.tscn",
		"res://scenes/content_templates/b_blocks/mixed_blocks_ruins.tscn"
	],
	RoomType.REST: [
		"res://scenes/content_templates/b_blocks/mixed_blocks_garden.tscn"
	]
}

signal room_type_assigned(room_name: String, room_type: RoomType)
signal content_generated(room_name: String)
signal all_rooms_populated()

func _ready():
	pass

# ============== 主要接口 ==============

func initialize_from_level_data(level_data: Dictionary, floor_level: int = 1):
	"""从NormalLevelGenerator的输出初始化"""
	current_level_data = level_data
	current_floor_level = floor_level
	rooms_data.clear()
	
	print("=== Level Manager 初始化 ===")
	print("楼层: %d" % floor_level)
	print("房间数量: %d" % level_data.grid_info.room_count)
	
	# 分配房间类型
	_assign_room_types(level_data)
	
	# 选择内容生成模式
	_assign_content_modes()
	
	print("=== 房间类型分配完成 ===")
	_print_room_assignments()

func populate_all_rooms():
	"""为所有房间生成内容"""
	if current_level_data.is_empty():
		push_error("Level Manager未初始化")
		return
	
	var level_node = current_level_data.level_node
	if not level_node:
		push_error("Level节点不存在")
		return
	
	print("=== 开始生成房间内容 ===")
	
	for room_name in rooms_data.keys():
		var room_data = rooms_data[room_name] as RoomData
		var room_node = level_node.get_node_or_null(room_name)
		
		if room_node:
			_populate_single_room(room_node, room_data)
		else:
			push_warning("找不到房间节点: %s" % room_name)
	
	print("=== 房间内容生成完成 ===")
	all_rooms_populated.emit()

func populate_room(room_name: String):
	"""为单个房间生成内容（延迟加载用）"""
	if room_name not in rooms_data:
		push_error("房间数据不存在: %s" % room_name)
		return
	
	var room_data = rooms_data[room_name] as RoomData
	if room_data.is_populated:
		return
	
	var level_node = current_level_data.level_node
	var room_node = level_node.get_node_or_null(room_name)
	
	if room_node:
		_populate_single_room(room_node, room_data)

func get_room_type(room_name: String) -> RoomType:
	"""获取房间类型"""
	if room_name in rooms_data:
		return rooms_data[room_name].room_type
	return RoomType.NORMAL_COMBAT

# ============== 私有方法 ==============

func _assign_room_types(level_data: Dictionary):
	"""分配房间类型的算法"""
	var all_rooms_info = level_data.all_rooms_info
	var room_list = all_rooms_info.keys()
	
	if room_list.is_empty():
		return
	
	# 1. 起始房（room1永远是起始房）
	if "room1_info" in room_list:
		_create_room_data("room1", RoomType.START, all_rooms_info["room1_info"])
		room_list.erase("room1_info")
	
	# 2. 寻找末端房间（连接数最少的）作为特殊房间
	var end_rooms = _find_end_rooms(all_rooms_info, room_list)
	
	# 3. 分配Boss房（最远的末端）
	if not end_rooms.is_empty() and current_floor_level % 3 == 0:  # 每3层一个Boss
		var boss_room_key = end_rooms[0]
		var boss_room_name = boss_room_key.replace("_info", "")
		_create_room_data(boss_room_name, RoomType.BOSS, all_rooms_info[boss_room_key])
		room_list.erase(boss_room_key)
		end_rooms.erase(boss_room_key)
	
	# 4. 分配宝箱房和商店房（其他末端）
	var special_types = [RoomType.TREASURE, RoomType.SHOP, RoomType.REST]
	var special_index = 0
	
	for i in range(min(2, end_rooms.size())):
		var room_key = end_rooms[i]
		var room_name = room_key.replace("_info", "")
		var room_type = special_types[special_index % special_types.size()]
		_create_room_data(room_name, room_type, all_rooms_info[room_key])
		room_list.erase(room_key)
		special_index += 1
	
	# 5. 识别走廊房间（2个连接且为直线）
	for room_key in room_list.duplicate():
		var room_info = all_rooms_info[room_key]
		if _is_corridor_room(room_info):
			var room_name = room_key.replace("_info", "")
			_create_room_data(room_name, RoomType.CORRIDOR, room_info)
			room_list.erase(room_key)
	
	# 6. 剩余房间全部为普通战斗房
	for room_key in room_list:
		var room_name = room_key.replace("_info", "")
		_create_room_data(room_name, RoomType.NORMAL_COMBAT, all_rooms_info[room_key])

func _assign_content_modes():
	"""为每个房间分配A/B类内容生成模式"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for room_name in rooms_data.keys():
		var room_data = rooms_data[room_name] as RoomData
		var mode = ContentMode.A_STAR_PATTERN
		
		match room_data.room_type:
			RoomType.BOSS, RoomType.SHOP, RoomType.TREASURE:
				mode = ContentMode.A_STAR_PATTERN  # 特殊房间强制A类
			
			RoomType.CORRIDOR:
				mode = ContentMode.A_STAR_PATTERN  # 走廊使用A类
			
			RoomType.NORMAL_COMBAT:
				# 70% B类，30% A类
				mode = ContentMode.B_MIXED_BLOCKS if rng.randf() < 0.7 else ContentMode.A_STAR_PATTERN
			
			RoomType.REST:
				mode = ContentMode.B_MIXED_BLOCKS  # 休息房使用B类
			
			RoomType.START:
				mode = ContentMode.A_STAR_PATTERN  # 起始房使用A类
		
		room_data.content_mode = mode

func _populate_single_room(room_node: Node2D, room_data: RoomData):
	"""为单个房间生成内容"""
	if room_data.is_populated:
		return
	
	print("生成房间内容: %s (类型: %s, 模式: %s)" % [
		room_data.room_name,
		_room_type_to_string(room_data.room_type),
		"A类" if room_data.content_mode == ContentMode.A_STAR_PATTERN else "B类"
	])
	
	# 获取或创建TerrainContent容器
	var terrain_content = room_node.get_node_or_null("TerrainContent")
	if not terrain_content:
		terrain_content = Node2D.new()
		terrain_content.name = "TerrainContent"
		room_node.add_child(terrain_content)
	
	# 选择并加载模板
	var template_scene = _select_template(room_data)
	if not template_scene:
		push_warning("未找到模板: %s" % room_data.room_name)
		room_data.is_populated = true
		return
	
	# 实例化模板
	var content_instance = template_scene.instantiate()
	terrain_content.add_child(content_instance)
	
	# 调用模板的populate方法
	if content_instance.has_method("populate"):
		content_instance.populate(room_data.floor_level, room_data.room_type)
	
	room_data.is_populated = true
	content_generated.emit(room_data.room_name)

func _select_template(room_data: RoomData) -> PackedScene:
	"""选择合适的模板场景"""
	var templates_dict = a_templates if room_data.content_mode == ContentMode.A_STAR_PATTERN else b_templates
	
	if room_data.room_type not in templates_dict:
		return null
	
	var templates = templates_dict[room_data.room_type]
	if templates.is_empty():
		return null
	
	# 随机选择一个模板
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var template_path = templates[rng.randi() % templates.size()]
	
	return load(template_path)

func _create_room_data(room_name: String, room_type: RoomType, room_info: Dictionary):
	"""创建房间数据"""
	var mode = ContentMode.A_STAR_PATTERN  # 稍后会被_assign_content_modes修改
	var room_data = RoomData.new(room_name, room_type, mode, current_floor_level)
	room_data.grid_position = room_info.grid_position
	room_data.connections = room_info.connections
	
	rooms_data[room_name] = room_data
	room_type_assigned.emit(room_name, room_type)

func _find_end_rooms(all_rooms_info: Dictionary, room_list: Array) -> Array:
	"""查找末端房间（连接数<=2）并按距离排序"""
	var end_rooms = []
	var start_pos = Vector2i.ZERO
	
	if "room1_info" in all_rooms_info:
		start_pos = all_rooms_info["room1_info"].grid_position
	
	for room_key in room_list:
		var room_info = all_rooms_info[room_key]
		var connection_count = room_info.connections.size()
		
		if connection_count <= 2:
			var distance = start_pos.distance_to(room_info.grid_position)
			end_rooms.append({"key": room_key, "distance": distance})
	
	# 按距离降序排序（最远的在前）
	end_rooms.sort_custom(func(a, b): return a.distance > b.distance)
	
	return end_rooms.map(func(item): return item.key)

func _is_corridor_room(room_info: Dictionary) -> bool:
	"""判断是否为走廊房间"""
	var connections = room_info.connections
	if connections.size() != 2:
		return false
	
	# 检查是否为直线连接（左-右 或 上-下）
	var has_left = 0 in connections
	var has_right = 1 in connections
	var has_top = 2 in connections
	var has_bottom = 3 in connections
	
	return (has_left and has_right) or (has_top and has_bottom)

func _room_type_to_string(type: RoomType) -> String:
	match type:
		RoomType.NORMAL_COMBAT: return "普通战斗"
		RoomType.BOSS: return "Boss"
		RoomType.TREASURE: return "宝箱"
		RoomType.SHOP: return "商店"
		RoomType.REST: return "休息"
		RoomType.CORRIDOR: return "走廊"
		RoomType.START: return "起始"
		_: return "未知"

func _print_room_assignments():
	"""打印房间分配结果"""
	for room_name in rooms_data.keys():
		var room_data = rooms_data[room_name] as RoomData
		print("  %s: %s (%s)" % [
			room_name,
			_room_type_to_string(room_data.room_type),
			"A类" if room_data.content_mode == ContentMode.A_STAR_PATTERN else "B类"
		])
