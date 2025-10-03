# LevelManager.gd
# 改进版关卡管理器 - 优化资源管理和模板选择
extends Node

# 房间类型枚举
enum RoomType {
	NORMAL_COMBAT,    # 普通战斗房
	BOSS,             # Boss房
	TREASURE,         # 宝箱/奖励房
	SHOP,             # 商店房
	REST,             # 休息房
	CORRIDOR,         # 走廊/过渡房
	START,            # 起始房
	SECRET            # 秘密房（新增）
}

# 内容生成模式
enum ContentMode {
	A_STAR_PATTERN,   # A类：精心设计
	B_MIXED_BLOCKS,   # B类：积木拼接
	HYBRID            # 混合模式（新增）
}

# 房间数据结构（扩展版）
class RoomData:
	var room_name: String
	var room_type: RoomType
	var content_mode: ContentMode
	var floor_level: int
	var grid_position: Vector2i
	var connections: Array
	var is_populated: bool = false
	var template_path: String = ""  # 新增：具体模板路径
	var theme: String = ""  # 新增：主题
	var difficulty_modifier: float = 1.0  # 新增：难度系数
	
	func _init(name: String, type: RoomType, mode: ContentMode, level: int):
		room_name = name
		room_type = type
		content_mode = mode
		floor_level = level

# ============== 配置参数 ==============
@export var DEBUG_MODE: bool = false
@export var use_lazy_loading: bool = true  # 是否使用延迟加载
@export var preload_adjacent_rooms: bool = true  # 是否预加载相邻房间

# ============== 状态变量 ==============
var current_level_data: Dictionary = {}
var current_floor_level: int = 1
var rooms_data: Dictionary = {}  # key: room_name, value: RoomData
var loaded_templates: Dictionary = {}  # 缓存已加载的模板

# ============== 模板配置（改进版） ==============
# A类模板池 - 精心设计的固定布局
var a_templates: Dictionary = {
	RoomType.BOSS: {
		"templates": [
			"res://scenes/content_templates/a_patterns/boss_arena_1.tscn",
			"res://scenes/content_templates/a_patterns/boss_arena_2.tscn",
			"res://scenes/content_templates/a_patterns/boss_throne_room.tscn"
		],
		"weights": [1.0, 1.0, 0.5],  # 权重系统
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.TREASURE: {
		"templates": [
			"res://scenes/content_templates/a_patterns/treasure_room_1.tscn",
			"res://scenes/content_templates/a_patterns/treasure_vault.tscn"
		],
		"weights": [1.0, 0.3],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.SHOP: {
		"templates": [
			"res://scenes/content_templates/a_patterns/shop_room_1.tscn",
			"res://scenes/content_templates/a_patterns/shop_market.tscn"
		],
		"weights": [1.0, 0.5],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.CORRIDOR: {
		"templates": [
			"res://scenes/content_templates/a_patterns/corridor_1.tscn",
			"res://scenes/content_templates/a_patterns/corridor_2.tscn",
			"res://scenes/content_templates/a_patterns/corridor_trap.tscn"
		],
		"weights": [1.0, 1.0, 0.3],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.NORMAL_COMBAT: {
		"templates": [
			"res://scenes/content_templates/a_patterns/combat_layout_1.tscn",
			"res://scenes/content_templates/a_patterns/combat_layout_2.tscn",
			"res://scenes/content_templates/a_patterns/combat_arena.tscn"
		],
		"weights": [1.0, 1.0, 0.7],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.SECRET: {
		"templates": [
			"res://scenes/content_templates/a_patterns/secret_chamber.tscn"
		],
		"weights": [1.0],
		"min_floor": 3,
		"max_floor": 99
	},
	RoomType.START: {
		"templates": [
			"res://scenes/content_templates/a_patterns/start_room.tscn"
		],
		"weights": [1.0],
		"min_floor": 1,
		"max_floor": 99
	}
}

# B类模板池 - 程序化生成的积木拼接
var b_templates: Dictionary = {
	RoomType.NORMAL_COMBAT: {
		"templates": [
			"res://scenes/content_templates/b_blocks/mixed_blocks_peaceful.tscn",
			"res://scenes/content_templates/b_blocks/mixed_blocks_ruins.tscn",
			"res://scenes/content_templates/b_blocks/mixed_blocks_mystical.tscn"
		],
		"weights": [1.0, 0.7, 0.5],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.REST: {
		"templates": [
			"res://scenes/content_templates/b_blocks/mixed_blocks_garden.tscn",
			"res://scenes/content_templates/b_blocks/mixed_blocks_campsite.tscn"
		],
		"weights": [1.0, 0.8],
		"min_floor": 1,
		"max_floor": 99
	}
}

# 信号
signal room_type_assigned(room_name: String, room_type: RoomType)
signal content_generated(room_name: String)
signal all_rooms_populated()
signal room_entered(room_name: String)  # 新增

func _ready():
	_log_debug("LevelManager 初始化完成")

# ============== 主要接口 ==============

func initialize_from_level_data(level_data: Dictionary, floor_level: int = 1):
	"""从NormalLevelGenerator的输出初始化"""
	current_level_data = level_data
	current_floor_level = floor_level
	rooms_data.clear()
	loaded_templates.clear()
	
	_log_debug("=== Level Manager 初始化 ===")
	_log_debug("楼层: %d" % floor_level)
	_log_debug("房间数量: %d" % level_data.grid_info.room_count)
	
	# 分配房间类型
	_assign_room_types(level_data)
	
	# 选择内容生成模式
	_assign_content_modes()
	
	# 选择具体模板
	_assign_templates()
	
	_log_debug("=== 房间配置完成 ===")
	_print_room_assignments()

func populate_all_rooms():
	"""为所有房间生成内容（立即模式）"""
	if current_level_data.is_empty():
		push_error("Level Manager未初始化")
		return
	
	var level_node = current_level_data.level_node
	if not level_node:
		push_error("Level节点不存在")
		return
	
	_log_debug("=== 开始生成所有房间内容 ===")
	
	for room_name in rooms_data.keys():
		var room_data = rooms_data[room_name] as RoomData
		var room_node = level_node.get_node_or_null(room_name)
		
		if room_node:
			_populate_single_room(room_node, room_data)
		else:
			push_warning("找不到房间节点: %s" % room_name)
	
	_log_debug("=== 所有房间内容生成完成 ===")
	all_rooms_populated.emit()

func populate_room(room_name: String):
	"""为单个房间生成内容（延迟加载）"""
	if room_name not in rooms_data:
		push_error("房间数据不存在: %s" % room_name)
		return
	
	var room_data = rooms_data[room_name] as RoomData
	if room_data.is_populated:
		_log_debug("房间 %s 已生成，跳过" % room_name)
		return
	
	var level_node = current_level_data.level_node
	var room_node = level_node.get_node_or_null(room_name)
	
	if room_node:
		_populate_single_room(room_node, room_data)
		
		# 预加载相邻房间
		if preload_adjacent_rooms:
			_preload_adjacent_rooms(room_name)

func on_player_entered_room(room_name: String):
	"""玩家进入房间时调用"""
	_log_debug("玩家进入房间: %s" % room_name)
	
	# 延迟加载模式下，生成房间内容
	if use_lazy_loading:
		populate_room(room_name)
	
	room_entered.emit(room_name)

func get_room_type(room_name: String) -> RoomType:
	"""获取房间类型"""
	if room_name in rooms_data:
		return rooms_data[room_name].room_type
	return RoomType.NORMAL_COMBAT

func get_room_data(room_name: String) -> RoomData:
	"""获取房间完整数据"""
	return rooms_data.get(room_name, null)

# ============== 私有方法 - 房间分配 ==============

func _assign_room_types(level_data: Dictionary):
	"""智能分配房间类型"""
	var all_rooms_info = level_data.all_rooms_info
	var room_list = all_rooms_info.keys()
	
	if room_list.is_empty():
		return
	
	# 1. 起始房
	if "room1_info" in room_list:
		_create_room_data("room1", RoomType.START, all_rooms_info["room1_info"])
		room_list.erase("room1_info")
	
	# 2. 寻找末端房间
	var end_rooms = _find_end_rooms(all_rooms_info, room_list)
	
	# 3. Boss房（根据楼层决定）
	if not end_rooms.is_empty():
		if current_floor_level % 5 == 0:  # 每5层一个大Boss
			var boss_room_key = end_rooms[0]
			var boss_room_name = boss_room_key.replace("_info", "")
			_create_room_data(boss_room_name, RoomType.BOSS, all_rooms_info[boss_room_key])
			room_list.erase(boss_room_key)
			end_rooms.erase(boss_room_key)
		elif current_floor_level % 3 == 0:  # 每3层一个小Boss
			var boss_room_key = end_rooms[0]
			var boss_room_name = boss_room_key.replace("_info", "")
			var room_data = _create_room_data(boss_room_name, RoomType.BOSS, all_rooms_info[boss_room_key])
			room_data.difficulty_modifier = 0.7  # 小Boss难度降低
			room_list.erase(boss_room_key)
			end_rooms.erase(boss_room_key)
	
	# 4. 特殊房间分配
	var special_rooms = _calculate_special_rooms(end_rooms.size())
	var special_index = 0
	
	for i in range(min(special_rooms.size(), end_rooms.size())):
		var room_key = end_rooms[i]
		var room_name = room_key.replace("_info", "")
		var room_type = special_rooms[special_index]
		_create_room_data(room_name, room_type, all_rooms_info[room_key])
		room_list.erase(room_key)
		special_index += 1
	
	# 5. 走廊识别
	for room_key in room_list.duplicate():
		var room_info = all_rooms_info[room_key]
		if _is_corridor_room(room_info):
			var room_name = room_key.replace("_info", "")
			_create_room_data(room_name, RoomType.CORRIDOR, room_info)
			room_list.erase(room_key)
	
	# 6. 秘密房间（10%概率）
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	if current_floor_level >= 3 and not room_list.is_empty() and rng.randf() < 0.1:
		var secret_index = rng.randi() % room_list.size()
		var secret_key = room_list[secret_index]
		var secret_name = secret_key.replace("_info", "")
		_create_room_data(secret_name, RoomType.SECRET, all_rooms_info[secret_key])
		room_list.erase(secret_key)
	
	# 7. 剩余全部为普通战斗房
	for room_key in room_list:
		var room_name = room_key.replace("_info", "")
		_create_room_data(room_name, RoomType.NORMAL_COMBAT, all_rooms_info[room_key])

func _calculate_special_rooms(available_slots: int) -> Array:
	"""根据楼层计算特殊房间类型"""
	var special_types = []
	
	# 基础配置
	if available_slots >= 1:
		special_types.append(RoomType.TREASURE)
	
	if available_slots >= 2 and current_floor_level >= 2:
		if current_floor_level % 2 == 0:
			special_types.append(RoomType.SHOP)
		else:
			special_types.append(RoomType.REST)
	
	if available_slots >= 3:
		special_types.append(RoomType.REST)
	
	return special_types

func _assign_content_modes():
	"""智能分配内容生成模式"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for room_name in rooms_data.keys():
		var room_data = rooms_data[room_name] as RoomData
		var mode = ContentMode.A_STAR_PATTERN
		
		# 根据房间类型和楼层决定生成模式
		match room_data.room_type:
			RoomType.BOSS, RoomType.SHOP, RoomType.TREASURE, RoomType.START:
				mode = ContentMode.A_STAR_PATTERN  # 特殊房间强制A类
			
			RoomType.CORRIDOR:
				mode = ContentMode.A_STAR_PATTERN  # 走廊使用A类
			
			RoomType.SECRET:
				# 秘密房间50/50
				mode = ContentMode.A_STAR_PATTERN if rng.randf() < 0.5 else ContentMode.B_MIXED_BLOCKS
			
			RoomType.NORMAL_COMBAT:
				# 根据楼层调整比例
				if current_floor_level <= 3:
					# 低楼层：60% B类（更随机）
					mode = ContentMode.B_MIXED_BLOCKS if rng.randf() < 0.6 else ContentMode.A_STAR_PATTERN
				elif current_floor_level <= 7:
					# 中楼层：70% B类
					mode = ContentMode.B_MIXED_BLOCKS if rng.randf() < 0.7 else ContentMode.A_STAR_PATTERN
				else:
					# 高楼层：80% B类（更复杂）
					mode = ContentMode.B_MIXED_BLOCKS if rng.randf() < 0.8 else ContentMode.A_STAR_PATTERN
			
			RoomType.REST:
				mode = ContentMode.B_MIXED_BLOCKS  # 休息房使用B类
		
		room_data.content_mode = mode
		
		# 设置主题
		_assign_room_theme(room_data)

func _assign_room_theme(room_data: RoomData):
	"""为房间分配主题"""
	# 根据楼层和房间类型选择主题
	if room_data.room_type == RoomType.REST:
		room_data.theme = "peaceful"
	elif room_data.room_type == RoomType.BOSS:
		if current_floor_level >= 10:
			room_data.theme = "dark"
		elif current_floor_level >= 7:
			room_data.theme = "mystical"
		else:
			room_data.theme = "ruins"
	else:
		# 根据楼层选择默认主题
		if current_floor_level <= 3:
			room_data.theme = "peaceful"
		elif current_floor_level <= 6:
			room_data.theme = "ruins"
		elif current_floor_level <= 9:
			room_data.theme = "mystical"
		else:
			room_data.theme = "dark"

func _assign_templates():
	"""为每个房间分配具体模板"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for room_name in rooms_data.keys():
		var room_data = rooms_data[room_name] as RoomData
		
		# 选择模板池
		var templates_dict = a_templates if room_data.content_mode == ContentMode.A_STAR_PATTERN else b_templates
		
		if room_data.room_type not in templates_dict:
			continue
		
		var template_config = templates_dict[room_data.room_type]
		
		# 检查楼层限制
		if current_floor_level < template_config.get("min_floor", 1) or \
		   current_floor_level > template_config.get("max_floor", 99):
			continue
		
		# 根据权重选择模板
		var templates = template_config.templates
		var weights = template_config.get("weights", [])
		
		if templates.is_empty():
			continue
		
		# 如果没有权重或权重数量不匹配，使用均等权重
		if weights.is_empty() or weights.size() != templates.size():
			room_data.template_path = templates[rng.randi() % templates.size()]
		else:
			room_data.template_path = _weighted_random_choice(templates, weights, rng)

func _weighted_random_choice(items: Array, weights: Array, rng: RandomNumberGenerator) -> String:
	"""加权随机选择"""
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	var random_value = rng.randf() * total_weight
	var cumulative = 0.0
	
	for i in range(items.size()):
		cumulative += weights[i]
		if random_value <= cumulative:
			return items[i]
	
	return items[0]

# ============== 私有方法 - 内容生成 ==============

func _populate_single_room(room_node: Node2D, room_data: RoomData):
	"""为单个房间生成内容"""
	if room_data.is_populated:
		return
	
	_log_debug("生成房间内容: %s (类型: %s, 模式: %s, 主题: %s)" % [
		room_data.room_name,
		_room_type_to_string(room_data.room_type),
		"A类" if room_data.content_mode == ContentMode.A_STAR_PATTERN else "B类",
		room_data.theme
	])
	
	# 获取或创建TerrainContent容器
	var terrain_content = room_node.get_node_or_null("TerrainContent")
	if not terrain_content:
		terrain_content = Node2D.new()
		terrain_content.name = "TerrainContent"
		room_node.add_child(terrain_content)
	
	# 加载模板
	var template_scene = _load_template(room_data)
	if not template_scene:
		push_warning("未找到模板: %s" % room_data.room_name)
		room_data.is_populated = true
		return
	
	# 实例化模板
	var content_instance = template_scene.instantiate()
	terrain_content.add_child(content_instance)
	
	# 调用模板的populate方法，传递完整参数
	if content_instance.has_method("populate"):
		content_instance.populate(room_data.floor_level, room_data.room_type)
	
	# 如果是B类模板，设置主题
	if room_data.content_mode == ContentMode.B_MIXED_BLOCKS:
		if content_instance.has_method("set_theme"):
			content_instance.set("current_theme", room_data.theme)
	
	room_data.is_populated = true
	content_generated.emit(room_data.room_name)

func _load_template(room_data: RoomData) -> PackedScene:
	"""加载模板场景（带缓存）"""
	var template_path = room_data.template_path
	
	if template_path.is_empty():
		# 如果没有预分配模板，动态选择
		template_path = _select_template_fallback(room_data)
	
	if template_path.is_empty():
		return null
	
	# 检查缓存
	if template_path in loaded_templates:
		return loaded_templates[template_path]
	
	# 加载新模板
	var template = load(template_path)
	if template:
		loaded_templates[template_path] = template
	
	return template

func _select_template_fallback(room_data: RoomData) -> String:
	"""备用模板选择"""
	var templates_dict = a_templates if room_data.content_mode == ContentMode.A_STAR_PATTERN else b_templates
	
	if room_data.room_type not in templates_dict:
		return ""
	
	var templates = templates_dict[room_data.room_type].templates
	if templates.is_empty():
		return ""
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return templates[rng.randi() % templates.size()]

func _preload_adjacent_rooms(room_name: String):
	"""预加载相邻房间"""
	if room_name not in rooms_data:
		return
	
	var room_data = rooms_data[room_name]
	var all_rooms_info = current_level_data.all_rooms_info
	var room_info_key = room_name + "_info"
	
	if room_info_key not in all_rooms_info:
		return
	
	var room_info = all_rooms_info[room_info_key]
	
	# 找到所有连通的邻居
	for i in range(4):
		if room_info.connected_neighbors[i]:
			var neighbor_name = room_info.neighbors[i]
			if neighbor_name and neighbor_name in rooms_data:
				# 异步加载
				call_deferred("populate_room", neighbor_name)

# ============== 辅助方法 ==============

func _create_room_data(room_name: String, room_type: RoomType, room_info: Dictionary) -> RoomData:
	"""创建房间数据"""
	var room_data = RoomData.new(room_name, room_type, ContentMode.A_STAR_PATTERN, current_floor_level)
	room_data.grid_position = room_info.grid_position
	room_data.connections = room_info.connections
	
	rooms_data[room_name] = room_data
	room_type_assigned.emit(room_name, room_type)
	
	return room_data

func _find_end_rooms(all_rooms_info: Dictionary, room_list: Array) -> Array:
	"""查找末端房间并按距离排序"""
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
	
	# 按距离降序排序
	end_rooms.sort_custom(func(a, b): return a.distance > b.distance)
	
	return end_rooms.map(func(item): return item.key)

func _is_corridor_room(room_info: Dictionary) -> bool:
	"""判断是否为走廊房间"""
	var connections = room_info.connections
	if connections.size() != 2:
		return false
	
	# 检查是否为直线连接
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
		RoomType.SECRET: return "秘密"
		_: return "未知"

func _log_debug(message: String):
	"""条件调试输出"""
	if DEBUG_MODE:
		print("[LevelManager] " + message)

func _print_room_assignments():
	"""打印房间分配结果"""
	if not DEBUG_MODE:
		return
		
	print("=== 房间分配结果 ===")
	for room_name in rooms_data.keys():
		var room_data = rooms_data[room_name] as RoomData
		print("  %s: %s (%s) [%s]" % [
			room_name,
			_room_type_to_string(room_data.room_type),
			"A类" if room_data.content_mode == ContentMode.A_STAR_PATTERN else "B类",
			room_data.theme
		])
	print("===================")
