# 改进版关卡管理器 - 优化资源管理和模板选择
extends Node

# A类模板池 - 精心设计的固定布局
var a_templates
# B类模板池 - 程序化生成的积木拼接
var b_templates
# 房间类型枚举
enum RoomType {
	NORMAL_COMBAT,    # 普通战斗房
	SPECIAL_COMBAT,   # 特殊战斗房（精英房间/挑战房）
	BOSS,             # Boss房
	TREASURE,         # 宝箱/奖励房
	SHOP,             # 商店房
	REST,             # 休息房
	CORRIDOR,         # 走廊/过渡房
	START,            # 起始房
	SECRET            # 秘密房
}

# 内容生成模式
enum ContentMode {
	A_PREFAB,   # A类：精心设计
	B_MIXED_BLOCKS,   # B类：积木拼接
	HYBRID            # 混合模式
}

# ============== 新增：关卡内容配置类 ==============
class LevelContent:
	var floor_level: int = 1
	var rest_room_count: int = 0           # 休息房数量
	var special_combat_room_count: int = 0 # 特殊战斗房数量
	var shop_room: bool = true             # 是否生成商店房（最多一个）
	var max_corridor_room_count: int = 1   # 最大走廊房数量
	var treasure_room_count: int = 0       # 宝藏房数量
	var secret_room: bool = false          # 是否生成秘密房
	
	func _init(level: int = 1):
		floor_level = level
		
	
	func validate_and_adjust(available_rooms: int):
		"""验证并调整配置以确保可行性"""
		# 必需房间：起始房(1) + Boss房(1) = 2
		var required_rooms = 2
		
		# 确保至少有1个普通战斗房
		var min_normal_combat = 1
		
		# 计算可用于特殊房间的空间
		var available_for_special = max(0, available_rooms - required_rooms - min_normal_combat)
		
		# 按优先级调整特殊房间数量
		var total_special_requested = 0
		total_special_requested += special_combat_room_count
		total_special_requested += (1 if shop_room else 0)
		total_special_requested += treasure_room_count
		total_special_requested += (1 if secret_room else 0)
		total_special_requested += rest_room_count
		total_special_requested += max_corridor_room_count
		
		if total_special_requested > available_for_special:
			_log_warning("特殊房间需求(%d)超出可用空间(%d)，将按优先级调整" % [total_special_requested, available_for_special])
			
			# 按优先级削减（从低到高）
			var remaining = available_for_special
			
			# 优先级1: 特殊战斗房
			special_combat_room_count = min(special_combat_room_count, remaining)
			remaining -= special_combat_room_count
			
			# 优先级2: 商店
			if remaining <= 0:
				shop_room = false
			else:
				remaining -= (1 if shop_room else 0)
			
			# 优先级3: 宝藏房
			treasure_room_count = min(treasure_room_count, remaining)
			remaining -= treasure_room_count
			
			# 优先级4: 秘密房
			if remaining <= 0:
				secret_room = false
			else:
				remaining -= (1 if secret_room else 0)
			
			# 优先级5: 休息房
			rest_room_count = min(rest_room_count, remaining)
			remaining -= rest_room_count
			
			# 优先级6: 走廊房
			max_corridor_room_count = min(max_corridor_room_count, remaining)
	
	func _log_warning(msg: String):
		push_warning("[LevelContent] " + msg)

# 房间数据结构（扩展版）
class RoomData:
	var room_name: String
	var room_type: RoomType
	var content_mode: ContentMode
	var floor_level: int
	var grid_position: Vector2i
	var connections: Array
	var is_populated: bool = false
	var template_path: String = ""  # 具体模板路径
	var theme: String = ""  # 主题
	var difficulty_modifier: float = 1.0  # 难度系数
	# 新增：块生成参数 (主要用于 B 类模板)
	var max_blocks: int = 9         # 最大生成的块数量 (默认3x3网格的最大值)
	var spread_factor: float = 1.0  # 块分散因子 (0-1)，1.0表示尽量分散，减少扎堆
	
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
var current_level_content: LevelContent = null  # 新增：当前关卡内容配置
var rooms_data: Dictionary = {}  # key: room_name, value: RoomData
var loaded_templates: Dictionary = {}  # 缓存已加载的模板

# ============== 模板配置（改进版） ==============


# 信号
signal room_type_assigned(room_name: String, room_type: RoomType)
signal content_generated(room_name: String)
signal all_rooms_populated()
signal room_entered(room_name: String)  # 玩家进入房间信号

func _init():
	var templates_list = load("res://scripts/rooms/content_template/template_list.gd")
	a_templates = templates_list.a_templates
	b_templates = templates_list.b_templates

func _ready():
	_log_debug("LevelManager 初始化完成")

# ============== 主要接口 ==============

func initialize_from_level_data(level_data: Dictionary, level_content: LevelContent = null):
	"""从NormalLevelGenerator的输出初始化（新版本支持LevelContent配置）"""
	current_level_data = level_data
	
	# 使用传入的LevelContent或创建默认配置
	if level_content:
		current_level_content = level_content
	else:
		# 使用默认配置
		var grid_info = level_data.get("grid_info", {})
		var floor_level = grid_info.get("floor_level", 1)
		current_level_content = LevelContent.new(floor_level)
	
	current_floor_level = current_level_content.floor_level
	rooms_data.clear()
	loaded_templates.clear()
	
	_log_debug("=== Level Manager 初始化 ===")
	_log_debug("楼层: %d" % current_floor_level)
	_log_debug("房间数量: %d" % level_data.grid_info.room_count)
	
	# 验证配置可行性
	current_level_content.validate_and_adjust(level_data.grid_info.room_count)
	
	# 分配房间类型（使用新的配置驱动方式）
	_assign_room_types_by_content(level_data)
	
	# 选择内容生成模式
	_assign_content_modes()
	
	# 选择具体模板
	_assign_templates()
	
	_log_debug("=== 房间配置完成 ===")
	_print_room_assignments()

func set_room_generation_params(room_name: String, max_blocks: int, spread_factor: float):
	"""设置指定房间的块生成参数"""
	if room_name in rooms_data:
		var room_data = rooms_data[room_name] as RoomData
		room_data.max_blocks = max_blocks
		room_data.spread_factor = clampf(spread_factor, 0.0, 1.0)
		_log_debug("房间 %s 生成参数更新: max_blocks=%d, spread_factor=%.1f" % [room_name, max_blocks, spread_factor])
	else:
		push_warning("尝试设置不存在的房间 %s 的生成参数" % room_name)

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

# ============== 私有方法 - 新版房间分配（基于LevelContent） ==============

func _assign_room_types_by_content(level_data: Dictionary):
	"""基于LevelContent配置分配房间类型"""
	var all_rooms_info = level_data.all_rooms_info
	var room_list = all_rooms_info.keys()
	
	if room_list.is_empty():
		push_error("没有可用房间")
		return
	
	var config = current_level_content
	var assigned_count = 0
	
	_log_debug("=== 开始按配置分配房间 ===")
	_log_debug("总房间数: %d" % room_list.size())
	
	# 优先级1: 起始房（必需）
	if "room1_info" in room_list:
		_create_room_data("room1", RoomType.START, all_rooms_info["room1_info"])
		room_list.erase("room1_info")
		assigned_count += 1
		_log_debug("✓ 起始房已分配")
	
	# 寻找末端房间（用于特殊房间分配）
	var end_rooms = _find_end_rooms(all_rooms_info, room_list)
	
	# 优先级2: Boss房（必需）
	if not end_rooms.is_empty():
		var boss_room_key = end_rooms[0]
		var boss_room_name = boss_room_key.replace("_info", "")
		var boss_data = _create_room_data(boss_room_name, RoomType.BOSS, all_rooms_info[boss_room_key])
		
		# 根据楼层调整Boss难度
		if current_floor_level % 5 == 0:
			boss_data.difficulty_modifier = 1.5  # 大Boss
		elif current_floor_level % 3 == 0:
			boss_data.difficulty_modifier = 1.2  # 中Boss
		else:
			boss_data.difficulty_modifier = 1.0  # 普通Boss
		
		room_list.erase(boss_room_key)
		end_rooms.remove_at(0)
		assigned_count += 1
		_log_debug("✓ Boss房已分配")
	
	# 优先级3: 普通战斗房（至少保留1个）
	var normal_combat_reserved = 1
	
	# 优先级4-8: 按配置分配特殊房间
	var special_assignments = []
	
	# 特殊战斗房
	for i in range(config.special_combat_room_count):
		special_assignments.append(RoomType.SPECIAL_COMBAT)
	
	# 商店
	if config.shop_room:
		special_assignments.append(RoomType.SHOP)
	
	# 宝藏房
	for i in range(config.treasure_room_count):
		special_assignments.append(RoomType.TREASURE)
	
	# 秘密房
	if config.secret_room:
		special_assignments.append(RoomType.SECRET)
	
	# 休息房
	for i in range(config.rest_room_count):
		special_assignments.append(RoomType.REST)
	
	# 走廊房（从非末端房间中识别）
	var corridor_count = 0
	var max_corridors = config.max_corridor_room_count
	
	# 分配特殊房间到末端
	var special_index = 0
	for room_key in end_rooms.duplicate():
		if special_index >= special_assignments.size():
			break
		
		var room_name = room_key.replace("_info", "")
		var room_type = special_assignments[special_index]
		_create_room_data(room_name, room_type, all_rooms_info[room_key])
		room_list.erase(room_key)
		assigned_count += 1
		special_index += 1
		_log_debug("✓ %s 已分配" % _room_type_to_string(room_type))
	
	# 识别走廊房
	for room_key in room_list.duplicate():
		if corridor_count >= max_corridors:
			break
		
		var room_info = all_rooms_info[room_key]
		if _is_corridor_room(room_info):
			var room_name = room_key.replace("_info", "")
			_create_room_data(room_name, RoomType.CORRIDOR, room_info)
			room_list.erase(room_key)
			assigned_count += 1
			corridor_count += 1
			_log_debug("✓ 走廊房已分配")
	
	# 剩余房间全部为普通战斗房
	for room_key in room_list:
		var room_name = room_key.replace("_info", "")
		_create_room_data(room_name, RoomType.NORMAL_COMBAT, all_rooms_info[room_key])
		assigned_count += 1
	
	_log_debug("✓ %d个普通战斗房已分配" % room_list.size())
	_log_debug("=== 房间分配完成，总计: %d ===\n" % assigned_count)

# ============== 私有方法 - 房间分配（保留旧版本作为参考） ==============

func _assign_room_types(level_data: Dictionary):
	"""智能分配房间类型（旧版本，已废弃）"""
	# 此方法保留用于兼容性，实际使用 _assign_room_types_by_content
	pass

func _calculate_special_rooms(available_slots: int) -> Array:
	"""根据楼层计算特殊房间类型（旧版本）"""
	var special_types = []
	
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
		var mode = ContentMode.A_PREFAB
		
		# 根据房间类型和楼层决定生成模式
		match room_data.room_type:
			RoomType.BOSS, RoomType.SHOP, RoomType.TREASURE, RoomType.START:
				mode = ContentMode.A_PREFAB  # 特殊房间强制A类
			
			RoomType.CORRIDOR:
				mode = ContentMode.A_PREFAB  # 走廊使用A类
			
			RoomType.SECRET:
				# 秘密房间50/50
				mode = ContentMode.A_PREFAB if rng.randf() < 0.5 else ContentMode.B_MIXED_BLOCKS
			
			RoomType.NORMAL_COMBAT, RoomType.SPECIAL_COMBAT:
				# 根据楼层调整比例
				if current_floor_level <= 3:
					# 低楼层：60% B类（更随机）
					mode = ContentMode.B_MIXED_BLOCKS if rng.randf() < 0.6 else ContentMode.A_PREFAB
				elif current_floor_level <= 7:
					# 中楼层：70% B类
					mode = ContentMode.B_MIXED_BLOCKS if rng.randf() < 0.7 else ContentMode.A_PREFAB
				else:
					# 高楼层：80% B类（更复杂）
					mode = ContentMode.B_MIXED_BLOCKS if rng.randf() < 0.8 else ContentMode.A_PREFAB
			
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
	"""为每个房间分配具体模板并设置默认生成参数"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for room_name in rooms_data.keys():
		var room_data = rooms_data[room_name] as RoomData
		
		# 设置默认的块生成参数
		room_data.max_blocks = 9
		room_data.spread_factor = 1.0
		
		# 选择模板池
		var templates_dict = a_templates if room_data.content_mode == ContentMode.A_PREFAB else b_templates
		
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
	
	_log_debug("生成房间内容: %s (类型: %s, 模式: %s, 主题: %s, MaxBlocks: %d, Spread: %.1f)" % [
		room_data.room_name,
		_room_type_to_string(room_data.room_type),
		"A类" if room_data.content_mode == ContentMode.A_PREFAB else "B类",
		room_data.theme,
		room_data.max_blocks,
		room_data.spread_factor
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
	
	# 调用模板的populate方法
	if content_instance.has_method("populate"):
		if room_data.content_mode == ContentMode.B_MIXED_BLOCKS:
			content_instance.populate(room_data.floor_level, room_data.room_type, room_data.max_blocks, room_data.spread_factor)
		else:
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
	var templates_dict = a_templates if room_data.content_mode == ContentMode.A_PREFAB else b_templates
	
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
	var room_data = RoomData.new(room_name, room_type, ContentMode.A_PREFAB, current_floor_level) 
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
		RoomType.SPECIAL_COMBAT: return "特殊战斗"
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
		
	print("\n=== 房间分配结果 ===")
	
	# 统计各类型房间数量
	var type_counts = {}
	for room_name in rooms_data.keys():
		var room_data = rooms_data[room_name] as RoomData
		var type_str = _room_type_to_string(room_data.room_type)
		if type_str not in type_counts:
			type_counts[type_str] = 0
		type_counts[type_str] += 1
		
		print("  %s: %s (%s) [%s] (MaxBlocks: %d, Spread: %.1f)" % [
			room_name,
			type_str,
			"A类" if room_data.content_mode == ContentMode.A_PREFAB else "B类",
			room_data.theme,
			room_data.max_blocks,
			room_data.spread_factor
		])
	
	print("\n--- 房间类型统计 ---")
	for type_str in type_counts.keys():
		print("  %s: %d个" % [type_str, type_counts[type_str]])
	print("  总计: %d个房间" % rooms_data.size())
	print("===================\n")
