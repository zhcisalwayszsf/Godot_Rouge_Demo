# Normal_Level_Generator.gd
# 单例模式的随机关卡生成器 - 返回详细数据结构版本
extends Node

# ============== 核心参数 ==============
var GRID_SIZE: int = 5
var TARGET_ROOMS: int = 8
var CONNECTION_RATE: float = 0.5
var ENABLE_PARTITIONS: bool = true
var COMPLEXITY_BIAS: float = 0.5
var RANDOM_SEED: int = -1
var DEBUG_MODE: bool = false

const ROOM_WIDTH = 1664
const ROOM_HEIGHT = 1024

enum Direction { LEFT = 0, RIGHT = 1, TOP = 2, BOTTOM = 3 }

# ============== 自定义数据结构 ==============
class LevelData:
	var level_node: Node2D = null
	var grid_info: Dictionary = {}
	var all_rooms_info: Dictionary = {}
	
	func _init():
		grid_info = {
			"grid_size": 0,
			"room_count": 0,
			"connection_count": 0
		}

class RoomInfo:
	var room_name: String = ""
	var global_position: Vector2 = Vector2.ZERO
	var grid_position: Vector2i = Vector2i.ZERO
	var connections: Array = []
	var connected_neighbors: Array = [false, false, false, false]
	var neighbors: Array = [null, null, null, null]
	var diagonal_neighbors: Array = [false, false, false, false]  # 新增：[左上, 右上, 左下, 右下]
	
	func to_dict() -> Dictionary:
		return {
			"room_name": room_name,
			"global_position": global_position,
			"grid_position": grid_position,
			"connections": connections,
			"connected_neighbors": connected_neighbors,
			"neighbors": neighbors,
			"diagonal_neighbors": diagonal_neighbors  # 新增
		}

class level_config:
	var config_dic:Dictionary = {
		"GRID_SIZE" : 5 as int,
		"TARGET_ROOMS": 8 as int,
		"CONNECTION_RATE": 0.5 as float,
		"ENABLE_PARTITIONS": true as bool,
		"COMPLEXITY_BIAS": 0.5 as float,
		"RANDOM_SEED": -1 as int,
		"DEBUG_MODE":false as bool 
	}
	
var room_templates = {
	"L": "res://scenes/rooms/normal_rooms/Room_L.tscn",
	"R": "res://scenes/rooms/normal_rooms/Room_R.tscn", 
	"T": "res://scenes/rooms/normal_rooms/Room_T.tscn",
	"B": "res://scenes/rooms/normal_rooms/Room_B.tscn",
	"LR": "res://scenes/rooms/normal_rooms/Room_LR.tscn",
	"LT": "res://scenes/rooms/normal_rooms/Room_LT.tscn",
	"LB": "res://scenes/rooms/normal_rooms/Room_LB.tscn",
	"RT": "res://scenes/rooms/normal_rooms/Room_RT.tscn",
	"RB": "res://scenes/rooms/normal_rooms/Room_RB.tscn",
	"TB": "res://scenes/rooms/normal_rooms/Room_TB.tscn",
	"LRB": "res://scenes/rooms/normal_rooms/Room_LRB.tscn",
	"LRT": "res://scenes/rooms/normal_rooms/Room_LRT.tscn",
	"RTB": "res://scenes/rooms/normal_rooms/Room_RTB.tscn",
	"LTB": "res://scenes/rooms/normal_rooms/Room_LTB.tscn",
	"LRTB": "res://scenes/rooms/normal_rooms/Room_LRTB.tscn"
}

# 数据结构
class RoomCell:
	var is_room: bool = false
	var connections: Array = []
	var scene_instance: Node2D = null
	var room_name: String = ""  # 新增：存储房间名称
	
	func has_connection(dir: Direction) -> bool:
		return dir in connections
	
	func add_connection(dir: Direction):
		if not has_connection(dir):
			connections.append(dir)
	
	func get_connection_count() -> int:
		return connections.size()

class PotentialConnection:
	var pos1: Vector2i
	var pos2: Vector2i  
	var direction: Direction
	var weight: float
	
	func _init(p1: Vector2i, p2: Vector2i, dir: Direction, w: float = 1.0):
		pos1 = p1
		pos2 = p2
		direction = dir
		weight = w

# 生成状态
var grid: Dictionary = {}
var rooms: Array = []
var potential_connections: Array = []
var active_connections: Array = []
var rng: RandomNumberGenerator
var initial_room_pos: Vector2i
var room_position_map: Dictionary = {}  # 新增：存储网格位置到房间名称的映射

var final_room_info:Dictionary
# ============== 公共接口 ==============

func generate(
	grid_size: int = 5,
	target_rooms: int = 8,
	connection_rate: float = 0.5,
	enable_partitions: bool = true,
	complexity_bias: float = 0.5,
	random_seed: int = -1,
	debug_mode: bool = false
) -> Dictionary:
	"""主方法 - 使用参数生成关卡，返回详细数据"""
	
	GRID_SIZE = grid_size
	TARGET_ROOMS = target_rooms
	CONNECTION_RATE = connection_rate
	ENABLE_PARTITIONS = enable_partitions
	COMPLEXITY_BIAS = complexity_bias
	RANDOM_SEED = random_seed
	DEBUG_MODE = debug_mode
	
	var level_data = _generate_level_internal()
	return _convert_level_data_to_dict(level_data)

func generate_with_config(config: Dictionary) -> Dictionary:
	"""副方法 - 使用完整配置生成关卡，返回详细数据"""
	
	GRID_SIZE = config.GRID_SIZE
	TARGET_ROOMS = config.TARGET_ROOMS
	CONNECTION_RATE = config.CONNECTION_RATE
	ENABLE_PARTITIONS = config.ENABLE_PARTITIONS 
	COMPLEXITY_BIAS = config.COMPLEXITY_BIAS
	RANDOM_SEED = config.RANDOM_SEED
	DEBUG_MODE = config.DEBUG_MODE 
	
	if config.has("room_templates"):
		room_templates = config.room_templates
	
	var level_data = _generate_level_internal()
	return _convert_level_data_to_dict(level_data)

# ============== 内部生成逻辑 ==============

func _generate_level_internal() -> LevelData:
	"""内部生成方法 - 返回LevelData对象"""
	
	var level_data = LevelData.new()
	var level_node = Node2D.new()
	level_node.name = "Level"
	level_data.level_node = level_node
	
	_clear_state()
	_initialize_generator()
	
	_log_debug("=== 开始关卡生成 ===")
	_log_debug("网格大小: %dx%d" % [GRID_SIZE, GRID_SIZE])
	_log_debug("目标房间数: %d" % TARGET_ROOMS)
	
	var max_attempts = 3
	var attempt = 0
	var generation_success = false
	var last_error = ""
	
	while attempt < max_attempts and not generation_success:
		attempt += 1
		_log_debug("=== 尝试 %d/%d ===" % [attempt, max_attempts])
		
		if attempt > 1:
			_clear_state()
			_initialize_generator()
		
		# 第一阶段：房间布局生成
		if not phase_one_room_placement():
			last_error = "房间布局生成失败"
			_log_debug("错误: " + last_error)
			continue
		
		if not rooms.is_empty():
			initial_room_pos = rooms[0]
		
		# 验证房间数量
		if rooms.size() > TARGET_ROOMS:
			_log_debug("房间数过多 (%d/%d)，调整中..." % [rooms.size(), TARGET_ROOMS])
			while rooms.size() > TARGET_ROOMS:
				var removed_pos = rooms.pop_back()
				var cell = grid[removed_pos] as RoomCell
				if cell:
					cell.is_room = false
		
		# 第二阶段：分析连接
		phase_two_analyze_connections()
		
		# 第三阶段：连接生长
		phase_three_connection_growth()
		
		# 第四阶段：连通性验证
		if not phase_four_connectivity_check():
			last_error = "连通性验证失败"
			_log_debug("错误: " + last_error)
			continue
		
		# 最终验证
		var validation = validate_final_generation()
		if not validation.is_valid:
			last_error = validation.error_message
			_log_debug("错误: " + last_error)
			continue
		
		generation_success = true
		_log_debug("生成成功！房间数: %d, 连接数: %d" % [rooms.size(), active_connections.size()])
	
	if not generation_success:
		push_warning("关卡生成失败: " + last_error + "，使用备用布局")
		_generate_fallback_level()
	
	_instantiate_rooms_to_level(level_node)
	
	# 填充LevelData
	level_data.grid_info = {
		"grid_size": GRID_SIZE,
		"room_count": rooms.size(),
		"connection_count": active_connections.size()
	}
	
	# 收集所有房间信息
	level_data.all_rooms_info = _collect_rooms_info()
	
	_log_debug("=== 关卡生成完成 ===")
	return level_data

func _collect_rooms_info() -> Dictionary:
	"""收集所有房间的详细信息"""
	var all_rooms_info = {}
	var center_offset = (GRID_SIZE + 1) / 2.0
	var initial_world_pos = Vector2(
		(initial_room_pos.x - center_offset) * ROOM_WIDTH,
		(initial_room_pos.y - center_offset) * ROOM_HEIGHT
	)
	
	for room_pos in rooms:
		var cell = grid.get(room_pos) as RoomCell
		if not cell:
			continue
			
		var room_info = RoomInfo.new()
		room_info.room_name = cell.room_name
		room_info.grid_position = room_pos
		
		# 计算全局坐标（房间中心点）
		var world_pos = Vector2(
			(room_pos.x - center_offset) * ROOM_WIDTH,
			(room_pos.y - center_offset) * ROOM_HEIGHT
		)
		var relative_pos = world_pos - initial_world_pos
		room_info.global_position = relative_pos + Vector2(ROOM_WIDTH/2, ROOM_HEIGHT/2)
		
		# 设置连接方向
		room_info.connections = cell.connections.duplicate()
		
		# 检查每个方向的邻居
		for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
			var neighbor_pos = room_pos + get_direction_vector(dir)
			
			# 检查是否有邻居房间
			if is_room_at(neighbor_pos):
				var neighbor_cell = grid.get(neighbor_pos) as RoomCell
				if neighbor_cell:
					room_info.neighbors[dir] = neighbor_cell.room_name
					
					# 检查是否连通
					if cell.has_connection(dir):
						room_info.connected_neighbors[dir] = true
			else:
				room_info.neighbors[dir] = null
				room_info.connected_neighbors[dir] = false
		
		# 添加到结果字典
		var info_key = cell.room_name + "_info"
		all_rooms_info[info_key] = room_info.to_dict()
		final_room_info = all_rooms_info
	return all_rooms_info

func _convert_level_data_to_dict(level_data: LevelData) -> Dictionary:
	"""将LevelData转换为字典格式"""
	return {
		"level_node": level_data.level_node,
		"grid_info": level_data.grid_info,
		"all_rooms_info": level_data.all_rooms_info
	}

func _instantiate_rooms_to_level(level_node: Node2D):
	"""将房间实例化到Level节点 - 仅加载预制场景"""
	
	if rooms.is_empty():
		push_error("无法实例化:没有房间")
		return
	
	var center_offset = (GRID_SIZE + 1) / 2.0
	var initial_world_pos = Vector2(
		(initial_room_pos.x - center_offset) * ROOM_WIDTH,
		(initial_room_pos.y - center_offset) * ROOM_HEIGHT
	)
	
	var room_index = 1
	room_position_map.clear()
	
	# 先实例化初始房间
	var initial_cell = grid.get(initial_room_pos) as RoomCell
	if initial_cell:
		var initial_room_type = get_room_type_from_connections(initial_cell.connections)
		var initial_instance = _create_room_instance(initial_room_pos, initial_room_type)
		
		if initial_instance:
			initial_instance.name = "room1"
			initial_cell.room_name = "room1"
			initial_instance.position = Vector2.ZERO
			level_node.add_child(initial_instance)
			
			# 等待节点准备好
			await get_tree().process_frame
			
			# 调用初始化方法
			if initial_instance.has_method("instantiate_tile"):
				var initial_room_info = _create_room_info_for_position(initial_room_pos, "room1")
				initial_instance.instantiate_tile(initial_room_info)
			else:
				push_warning("初始房间没有 instantiate_tile 方法")
	
	# 实例化其他房间
	for room_pos in rooms:
		if room_pos == initial_room_pos:
			continue
	
		var cell = grid.get(room_pos) as RoomCell
		if not cell:
			push_warning("房间 %s 没有有效的cell" % str(room_pos))
			continue
		
		var room_type = get_room_type_from_connections(cell.connections)
		var room_instance = _create_room_instance(room_pos, room_type)
	
		if room_instance:
			var room_name = "room%d" % room_index
			room_instance.name = room_name
			cell.room_name = room_name
			var world_pos = Vector2(
				(room_pos.x - center_offset) * ROOM_WIDTH,
				(room_pos.y - center_offset) * ROOM_HEIGHT
			)
			room_instance.position = world_pos - initial_world_pos
			level_node.add_child(room_instance)
			
			# 等待节点准备好
			await get_tree().process_frame
			
			# 调用初始化方法
			if room_instance.has_method("instantiate_tile"):
				var current_room_info = _create_room_info_for_position(room_pos, room_name)
				room_instance.instantiate_tile(current_room_info)
			else:
				push_warning("房间 %s 没有 instantiate_tile 方法" % room_name)
		
			room_position_map[room_pos] = room_name
			room_index += 1

func _create_room_info_for_position(room_pos: Vector2i, room_name: String) -> RoomInfo:
	"""为指定位置创建RoomInfo对象 - 用于实例化时调用"""
	var cell = grid.get(room_pos) as RoomCell
	if not cell:
		push_error("无法为位置 %s 创建RoomInfo：没有有效的cell" % str(room_pos))
		return null
	
	var room_info = RoomInfo.new()
	room_info.room_name = room_name
	room_info.grid_position = room_pos
	
	# 计算全局坐标（房间中心点）
	var center_offset = (GRID_SIZE + 1) / 2.0
	var initial_world_pos = Vector2(
		(initial_room_pos.x - center_offset) * ROOM_WIDTH,
		(initial_room_pos.y - center_offset) * ROOM_HEIGHT
	)
	var world_pos = Vector2(
		(room_pos.x - center_offset) * ROOM_WIDTH,
		(room_pos.y - center_offset) * ROOM_HEIGHT
	)
	var relative_pos = world_pos - initial_world_pos
	room_info.global_position = relative_pos + Vector2(ROOM_WIDTH/2, ROOM_HEIGHT/2)
	
	# 设置连接方向
	room_info.connections = cell.connections.duplicate()
	
	# 确保数组正确初始化为4个元素 [LEFT, RIGHT, TOP, BOTTOM]
	room_info.connected_neighbors = [false, false, false, false]
	room_info.neighbors = [null, null, null, null]
	
	# 检查每个方向的邻居
	for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
		var neighbor_pos = room_pos + get_direction_vector(dir)
		
		# 检查是否有邻居房间
		if is_room_at(neighbor_pos):
			var neighbor_cell = grid.get(neighbor_pos) as RoomCell
			if neighbor_cell and not neighbor_cell.room_name.is_empty():
				room_info.neighbors[dir] = neighbor_cell.room_name
			else:
				# 如果邻居房间名称还未分配，使用位置信息作为临时标识
				room_info.neighbors[dir] = "room_at_" + str(neighbor_pos)
			
			# 检查是否连通
			if cell.has_connection(dir):
				room_info.connected_neighbors[dir] = true
			else:
				room_info.connected_neighbors[dir] = false
		else:
			room_info.neighbors[dir] = null
			room_info.connected_neighbors[dir] = false
	
	# 检查对角线位置 [左上, 左下 , 右下,右上]
	var diagonal_offsets = [
		Vector2i(-1, -1),  # 左上
		Vector2i(-1, 1),   # 左下
		Vector2i(1, 1),     # 右下
		Vector2i(1, -1)   # 右上
	]
	
	room_info.diagonal_neighbors = [false, false, false, false]
	for i in range(4):
		var diagonal_pos = room_pos + diagonal_offsets[i]
		room_info.diagonal_neighbors[i] = is_room_at(diagonal_pos)
	
	return room_info

func _create_room_instance(grid_pos: Vector2i, room_type: String) -> Node2D:
	"""创建房间实例 - 仅加载预制场景，不添加任何生成逻辑"""
	if not room_templates.has(room_type):
		push_warning("未找到房间模板: %s，使用默认模板 R" % room_type)
		room_type = "R"
	
	var room_scene = load(room_templates[room_type])
	if not room_scene:
		push_error("加载房间场景失败: %s" % room_templates[room_type])
		return null
	
	var room_instance = room_scene.instantiate()
	var cell = grid.get(grid_pos) as RoomCell
	if cell:
		cell.scene_instance = room_instance
	
	return room_instance

func _clear_state():
	"""清理状态"""
	grid.clear()
	rooms.clear()
	potential_connections.clear()
	active_connections.clear()
	initial_room_pos = Vector2i.ZERO
	room_position_map.clear()

func _initialize_generator():
	"""初始化生成器"""
	rooms.clear()
	
	if RANDOM_SEED == -1:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = RANDOM_SEED
	
	grid.clear()
	for x in range(1, GRID_SIZE + 1):
		for y in range(1, GRID_SIZE + 1):
			grid[Vector2i(x, y)] = RoomCell.new()

func _generate_fallback_level():
	"""生成备用布局 - 保证成功"""
	_log_debug("生成备用布局...")
	_clear_state()
	_initialize_generator()
	
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	var simple_rooms = min(TARGET_ROOMS, 7)
	
	rooms.clear()
	
	# 放置中心房间
	if not place_room(center):
		push_error("备用布局失败：无法放置中心房间")
		# 尝试其他位置
		for x in range(1, GRID_SIZE + 1):
			for y in range(1, GRID_SIZE + 1):
				if place_room(Vector2i(x, y)):
					center = Vector2i(x, y)
					break
			if rooms.size() > 0:
				break
	
	if rooms.is_empty():
		push_error("严重错误：无法生成任何房间")
		return
	
	initial_room_pos = center
	var current_pos = center
	var placed_count = 1
	
	# 生成简单线性布局
	for i in range(simple_rooms - 1):
		if placed_count >= TARGET_ROOMS:
			break
		
		var directions = [Direction.RIGHT, Direction.BOTTOM, Direction.LEFT, Direction.TOP]
		directions.shuffle()
		
		for dir in directions:
			var next_pos = current_pos + get_direction_vector(dir)
			if is_valid_position(next_pos) and not is_room_at(next_pos):
				if place_room(next_pos):
					var conn = PotentialConnection.new(current_pos, next_pos, dir, 1.0)
					active_connections.append(conn)
					apply_single_connection(conn)
					current_pos = next_pos
					placed_count += 1
					break
		
		# 如果当前位置无法扩展，从其他房间尝试
		if placed_count < simple_rooms:
			for room_pos in rooms:
				if placed_count >= TARGET_ROOMS:
					break
				var dirs = get_empty_neighbors(room_pos)
				if not dirs.is_empty():
					var dir = dirs[0]
					var new_pos = room_pos + get_direction_vector(dir)
					if place_room(new_pos):
						var conn = PotentialConnection.new(room_pos, new_pos, dir, 1.0)
						active_connections.append(conn)
						apply_single_connection(conn)
						placed_count += 1
						break
	
	_log_debug("备用布局完成: %d 个房间" % rooms.size())

# ============== 第一阶段：房间布局生成 ==============
func phase_one_room_placement() -> bool:
	"""使用多种策略生成房间布局"""
	var strategy = choose_placement_strategy()
	var success = false
	
	_log_debug("使用策略: " + strategy)
	
	match strategy:
		"organic_growth":
			success = organic_growth_placement()
		"shape_template":
			success = shape_template_placement()
		"cluster_expansion":
			success = cluster_expansion_placement()
		"path_based":
			success = path_based_placement()
		_:
			success = organic_growth_placement()
	
	# 补充房间到目标数
	if success and rooms.size() < TARGET_ROOMS:
		supplement_to_target()
	
	# 验证房间数
	if rooms.size() > TARGET_ROOMS:
		while rooms.size() > TARGET_ROOMS:
			var removed_pos = rooms.pop_back()
			var cell = grid[removed_pos] as RoomCell
			if cell:
				cell.is_room = false
	
	# 确保有最少房间数
	if rooms.size() < min(3, TARGET_ROOMS):
		supplement_minimum_rooms()
	
	return rooms.size() >= min(3, TARGET_ROOMS)

func choose_placement_strategy() -> String:
	var strategies = []
	
	if COMPLEXITY_BIAS > 0.7:
		strategies.append_array(["shape_template", "path_based", "organic_growth"])
	elif COMPLEXITY_BIAS > 0.4:
		strategies.append_array(["organic_growth", "cluster_expansion", "shape_template"])
	else:
		strategies.append_array(["cluster_expansion", "organic_growth"])
	
	return strategies[rng.randi() % strategies.size()]

func organic_growth_placement() -> bool:
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	
	if not place_room(center):
		center = find_valid_start_position()
		if center == Vector2i(-1, -1):
			return false
		place_room(center)
	
	var growth_queue = [center]
	var attempts = 0
	var max_attempts = TARGET_ROOMS * 30
	
	while rooms.size() < TARGET_ROOMS and not growth_queue.is_empty() and attempts < max_attempts:
		attempts += 1
		
		var growth_pos = growth_queue[rng.randi() % growth_queue.size()]
		var available_dirs = get_empty_neighbors(growth_pos)
		
		if available_dirs.is_empty():
			growth_queue.erase(growth_pos)
			continue
		
		var chosen_dir = available_dirs[rng.randi() % available_dirs.size()]
		var new_pos = growth_pos + get_direction_vector(chosen_dir)
		
		if place_room(new_pos):
			growth_queue.append(new_pos)
	
	return rooms.size() >= 3

func shape_template_placement() -> bool:
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	place_room(center)
	
	var shape = ["cross", "ring", "line"][rng.randi() % 3]
	
	match shape:
		"cross":
			return generate_cross_shape()
		"ring":
			return generate_ring_shape()
		_:
			return generate_line_shape()

func cluster_expansion_placement() -> bool:
	var clusters = max(1, TARGET_ROOMS / 5)
	
	for i in range(clusters):
		var center = Vector2i(
			rng.randi_range(2, GRID_SIZE - 1),
			rng.randi_range(2, GRID_SIZE - 1)
		)
		expand_cluster(center, TARGET_ROOMS / clusters)
	
	return rooms.size() >= 3

func path_based_placement() -> bool:
	var start = Vector2i(rng.randi_range(2, GRID_SIZE-1), rng.randi_range(2, GRID_SIZE-1))
	place_room(start)
	
	var current = start
	for i in range(TARGET_ROOMS - 1):
		var dirs = get_empty_neighbors(current)
		if dirs.is_empty():
			break
		var dir = dirs[rng.randi() % dirs.size()]
		current = current + get_direction_vector(dir)
		place_room(current)
	
	return rooms.size() >= 3

# ============== 形状生成函数 ==============
func generate_cross_shape() -> bool:
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	place_room(center)
	
	var arm_length = min(2, (GRID_SIZE - 3) / 2)
	
	for i in range(1, arm_length + 1):
		if rooms.size() >= TARGET_ROOMS:
			break
		place_room(center + Vector2i(i, 0))
		place_room(center + Vector2i(-i, 0))
		place_room(center + Vector2i(0, i))
		place_room(center + Vector2i(0, -i))
	
	return rooms.size() >= 5

func generate_ring_shape() -> bool:
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	var radius = min(2, (GRID_SIZE - 3) / 2)
	
	var positions = [
		center + Vector2i(-radius, 0),
		center + Vector2i(radius, 0),
		center + Vector2i(0, -radius),
		center + Vector2i(0, radius),
		center + Vector2i(-radius, -radius),
		center + Vector2i(radius, -radius),
		center + Vector2i(radius, radius),
		center + Vector2i(-radius, radius)
	]
	
	for pos in positions:
		if rooms.size() >= TARGET_ROOMS:
			break
		if is_valid_position(pos):
			place_room(pos)
	
	return rooms.size() >= 6

func generate_line_shape() -> bool:
	var start_x = 2
	var y = GRID_SIZE / 2 + 1
	
	for x in range(start_x, min(start_x + TARGET_ROOMS, GRID_SIZE)):
		place_room(Vector2i(x, y))
	
	return rooms.size() >= 3

# ============== 第二阶段：潜在连接分析 ==============
func phase_two_analyze_connections():
	potential_connections.clear()
	
	for room_pos in rooms:
		for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
			var neighbor_pos = room_pos + get_direction_vector(dir)
			
			if is_room_at(neighbor_pos):
				var connection = PotentialConnection.new(
					room_pos, 
					neighbor_pos, 
					dir,
					calculate_connection_weight(room_pos, neighbor_pos, dir)
				)
				
				if not has_connection_pair(connection):
					potential_connections.append(connection)
	
	_log_debug("找到 %d 个潜在连接" % potential_connections.size())

func calculate_connection_weight(pos1: Vector2i, pos2: Vector2i, dir: Direction) -> float:
	var weight = 1.0
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	var avg_distance = (pos1.distance_to(center) + pos2.distance_to(center)) / 2
	weight += (GRID_SIZE - avg_distance) * 0.1
	
	if dir == Direction.LEFT or dir == Direction.RIGHT:
		weight += 0.1
	
	weight += COMPLEXITY_BIAS * 0.5
	
	return weight

func has_connection_pair(conn: PotentialConnection) -> bool:
	for existing in potential_connections:
		if (existing.pos1 == conn.pos1 and existing.pos2 == conn.pos2) or \
		   (existing.pos1 == conn.pos2 and existing.pos2 == conn.pos1):
			return true
	return false

# ============== 第三阶段：连接选择与生长 ==============
func phase_three_connection_growth():
	active_connections.clear()
	
	if not ENABLE_PARTITIONS:
		active_connections = potential_connections.duplicate()
		_log_debug("隔断禁用：开通全部 %d 个连接" % active_connections.size())
	else:
		active_connections = select_connections_intelligently()
		_log_debug("智能选择：开通 %d/%d 个连接" % [active_connections.size(), potential_connections.size()])
	
	apply_connections()

func select_connections_intelligently() -> Array:
	var selected = []
	
	# 确保基本连通性
	var mst_connections = build_minimum_spanning_tree()
	selected.append_array(mst_connections)
	
	var remaining_connections = []
	for conn in potential_connections:
		if conn not in selected:
			remaining_connections.append(conn)
	
	remaining_connections.sort_custom(func(a, b): return a.weight > b.weight)
	
	var extra_count = int((potential_connections.size() - mst_connections.size()) * CONNECTION_RATE)
	extra_count = min(extra_count, remaining_connections.size())
	
	for i in range(extra_count):
		if should_add_connection(remaining_connections[i], selected):
			selected.append(remaining_connections[i])
	
	return selected

func build_minimum_spanning_tree() -> Array:
	"""构建最小生成树确保连通性"""
	if rooms.size() <= 1:
		return []
	
	var mst = []
	var visited = {rooms[0]: true}
	var edges = []
	
	for conn in potential_connections:
		if conn.pos1 == rooms[0]:
			edges.append(conn)
	
	while visited.size() < rooms.size() and not edges.is_empty():
		edges.sort_custom(func(a, b): return a.weight > b.weight)
		
		var best_edge = null
		for edge in edges:
			if (edge.pos1 in visited) != (edge.pos2 in visited):
				best_edge = edge
				break
		
		if not best_edge:
			_log_debug("警告：MST算法无法找到更多边")
			break
		
		mst.append(best_edge)
		var new_node = best_edge.pos2 if best_edge.pos1 in visited else best_edge.pos1
		visited[new_node] = true
		
		for conn in potential_connections:
			if (conn.pos1 == new_node and conn.pos2 not in visited) or \
			   (conn.pos2 == new_node and conn.pos1 not in visited):
				if conn not in edges:
					edges.append(conn)
		
		edges.erase(best_edge)
	
	_log_debug("MST: %d 条边确保连通性" % mst.size())
	return mst

func should_add_connection(conn: PotentialConnection, existing: Array) -> bool:
	"""判断是否应该添加连接"""
	# 检查连接度限制
	var pos1_connections = 0
	var pos2_connections = 0
	
	for existing_conn in existing:
		if existing_conn.pos1 == conn.pos1 or existing_conn.pos2 == conn.pos1:
			pos1_connections += 1
		if existing_conn.pos1 == conn.pos2 or existing_conn.pos2 == conn.pos2:
			pos2_connections += 1
	
	var max_connections = 4
	if pos1_connections >= max_connections or pos2_connections >= max_connections:
		return false
	
	# 根据复杂度偏好决定
	if COMPLEXITY_BIAS > 0.6:
		return rng.randf() < 0.8
	else:
		return rng.randf() < 0.4

func apply_connections():
	for conn in active_connections:
		apply_single_connection(conn)

func apply_single_connection(conn: PotentialConnection):
	var cell1 = grid.get(conn.pos1) as RoomCell
	var cell2 = grid.get(conn.pos2) as RoomCell
	
	if cell1 and cell2:
		cell1.add_connection(conn.direction)
		cell2.add_connection(get_opposite_direction(conn.direction))

# ============== 第四阶段：连通性验证与修复 ==============
func phase_four_connectivity_check() -> bool:
	"""验证并修复连通性"""
	if rooms.size() <= 1:
		return true
	
	var reachable_rooms = get_all_reachable_rooms(rooms[0])
	
	if reachable_rooms.size() == rooms.size():
		_log_debug("所有房间已连通")
		return true
	
	_log_debug("发现 %d 个不连通房间，尝试修复" % (rooms.size() - reachable_rooms.size()))
	
	# 尝试标准修复
	var repair_success = repair_connectivity_enhanced(reachable_rooms)
	
	# 如果失败，尝试强制修复
	if not repair_success:
		_log_debug("标准修复失败，执行强制修复")
		repair_success = force_connectivity_repair()
	
	# 最终验证
	var final_reachable = get_all_reachable_rooms(rooms[0])
	_log_debug("修复后连通性: %d/%d" % [final_reachable.size(), rooms.size()])
	
	return final_reachable.size() == rooms.size()

func repair_connectivity_enhanced(reachable_rooms: Array) -> bool:
	"""增强的连通性修复"""
	var unreachable = []
	for room in rooms:
		if room not in reachable_rooms:
			unreachable.append(room)
	
	var repairs_made = 0
	
	# 策略1: 寻找直接相邻的桥接
	for unreachable_room in unreachable:
		var bridge = find_bridge_connection(unreachable_room, reachable_rooms)
		if bridge:
			active_connections.append(bridge)
			apply_single_connection(bridge)
			repairs_made += 1
			reachable_rooms = get_all_reachable_rooms(rooms[0])
	
	# 策略2: 如果还有不连通的，尝试创建路径连接
	if repairs_made == 0:
		for unreachable_room in unreachable:
			var closest = find_closest_reachable_room(unreachable_room, reachable_rooms)
			if closest != Vector2i(-1, -1):
				var path_conn = create_direct_connection(unreachable_room, closest)
				if path_conn:
					active_connections.append(path_conn)
					apply_single_connection(path_conn)
					repairs_made += 1
					reachable_rooms = get_all_reachable_rooms(rooms[0])
	
	return repairs_made > 0

func force_connectivity_repair() -> bool:
	"""强制连通性修复 - 最后手段"""
	_log_debug("执行强制连通性修复")
	
	var forced_connections = 0
	
	# 强制连接所有相邻房间
	for room_pos in rooms:
		for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
			var neighbor_pos = room_pos + get_direction_vector(dir)
			
			if is_room_at(neighbor_pos):
				var has_connection = false
				for conn in active_connections:
					if (conn.pos1 == room_pos and conn.pos2 == neighbor_pos) or \
					   (conn.pos1 == neighbor_pos and conn.pos2 == room_pos):
						has_connection = true
						break
				
				if not has_connection:
					var forced_conn = PotentialConnection.new(room_pos, neighbor_pos, dir, 999.0)
					active_connections.append(forced_conn)
					apply_single_connection(forced_conn)
					forced_connections += 1
	
	_log_debug("强制添加了 %d 个连接" % forced_connections)
	return forced_connections > 0

func find_closest_reachable_room(unreachable_pos: Vector2i, reachable_rooms: Array) -> Vector2i:
	"""找到最近的可达房间"""
	var closest = Vector2i(-1, -1)
	var min_distance = 999999
	
	for reachable_pos in reachable_rooms:
		var distance = abs(unreachable_pos.x - reachable_pos.x) + abs(unreachable_pos.y - reachable_pos.y)
		if distance < min_distance:
			min_distance = distance
			closest = reachable_pos
	
	return closest

func create_direct_connection(pos1: Vector2i, pos2: Vector2i) -> PotentialConnection:
	"""尝试创建直接连接"""
	# 检查是否直接相邻
	var diff = pos2 - pos1
	var direction = Direction.RIGHT
	
	if diff == Vector2i(1, 0):
		direction = Direction.RIGHT
	elif diff == Vector2i(-1, 0):
		direction = Direction.LEFT
	elif diff == Vector2i(0, 1):
		direction = Direction.BOTTOM
	elif diff == Vector2i(0, -1):
		direction = Direction.TOP
	else:
		return null  # 不直接相邻
	
	return PotentialConnection.new(pos1, pos2, direction, 999.0)

func get_all_reachable_rooms(start_room: Vector2i) -> Array:
	var visited = {}
	var queue = [start_room]
	var reachable = []
	
	while not queue.is_empty():
		var current = queue.pop_front()
		if current in visited:
			continue
		
		visited[current] = true
		reachable.append(current)
		
		var cell = grid.get(current) as RoomCell
		if cell:
			for dir in cell.connections:
				var neighbor = current + get_direction_vector(dir)
				if neighbor in rooms and neighbor not in visited and neighbor not in queue:
					queue.append(neighbor)
	
	return reachable

func find_bridge_connection(unreachable_room: Vector2i, reachable_rooms: Array) -> PotentialConnection:
	for conn in potential_connections:
		if (conn.pos1 == unreachable_room and conn.pos2 in reachable_rooms) or \
		   (conn.pos2 == unreachable_room and conn.pos1 in reachable_rooms):
			return conn
	return null

# ============== 验证和辅助函数 ==============
func validate_final_generation() -> Dictionary:
	"""最终生成验证"""
	var result = {
		"is_valid": true,
		"error_message": "",
		"warnings": []
	}
	
	# 检查房间数量
	if rooms.size() > TARGET_ROOMS:
		result.is_valid = false
		result.error_message = "房间数量 %d 超过目标 %d" % [rooms.size(), TARGET_ROOMS]
		return result
	
	if rooms.size() < max(3, TARGET_ROOMS / 3):
		result.is_valid = false
		result.error_message = "房间数量 %d 太少" % rooms.size()
		return result
	
	# 检查重复房间
	var unique_rooms = {}
	for room_pos in rooms:
		if room_pos in unique_rooms:
			result.is_valid = false
			result.error_message = "发现重复房间 %s" % str(room_pos)
			return result
		unique_rooms[room_pos] = true
	
	# 检查所有房间都在网格中
	for room_pos in rooms:
		if not is_room_at(room_pos):
			result.is_valid = false
			result.error_message = "房间 %s 未正确标记" % str(room_pos)
			return result
	
	# 检查连接有效性
	for conn in active_connections:
		if not is_room_at(conn.pos1) or not is_room_at(conn.pos2):
			result.warnings.append("存在无效连接")
	
	return result

func supplement_to_target():
	"""补充房间到目标数量"""
	var attempts = 0
	var max_attempts = 50
	
	while rooms.size() < TARGET_ROOMS and attempts < max_attempts:
		attempts += 1
		
		if not rooms.is_empty():
			var base_room = rooms[rng.randi() % rooms.size()]
			var dirs = [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]
			dirs.shuffle()
			
			for dir in dirs:
				var new_pos = base_room + get_direction_vector(dir)
				if is_valid_position(new_pos) and not is_room_at(new_pos):
					if place_room(new_pos):
						break
	
	_log_debug("补充后房间数: %d/%d" % [rooms.size(), TARGET_ROOMS])

func supplement_minimum_rooms():
	"""确保最少房间数"""
	var min_rooms = max(3, TARGET_ROOMS / 3)
	var attempts = 0
	
	while rooms.size() < min_rooms and attempts < 50:
		attempts += 1
		
		# 在现有房间附近放置
		if not rooms.is_empty():
			var base_room = rooms[rng.randi() % rooms.size()]
			for radius in range(1, 3):
				for dx in range(-radius, radius + 1):
					for dy in range(-radius, radius + 1):
						var new_pos = base_room + Vector2i(dx, dy)
						if is_valid_position(new_pos) and not is_room_at(new_pos):
							if place_room(new_pos):
								break
		else:
			# 随机放置
			var pos = Vector2i(rng.randi_range(1, GRID_SIZE), rng.randi_range(1, GRID_SIZE))
			place_room(pos)

func expand_cluster(center: Vector2i, size: int):
	place_room(center)
	var growth_queue = [center]
	var placed = 1
	
	while placed < size and not growth_queue.is_empty():
		var pos = growth_queue[rng.randi() % growth_queue.size()]
		var empty_neighbors = get_empty_neighbors(pos)
		
		if not empty_neighbors.is_empty():
			var new_dir = empty_neighbors[rng.randi() % empty_neighbors.size()]
			var new_pos = pos + get_direction_vector(new_dir)
			
			if place_room(new_pos):
				growth_queue.append(new_pos)
				placed += 1
		else:
			growth_queue.erase(pos)

func find_valid_start_position() -> Vector2i:
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	
	for radius in range(0, 3):
		for x in range(max(1, center.x - radius), min(GRID_SIZE + 1, center.x + radius + 1)):
			for y in range(max(1, center.y - radius), min(GRID_SIZE + 1, center.y + radius + 1)):
				var pos = Vector2i(x, y)
				if is_valid_position(pos):
					return pos
	
	return Vector2i(-1, -1)

func get_room_type_from_connections(connections: Array) -> String:
	var type_str = ""
	
	if Direction.LEFT in connections: type_str += "L"
	if Direction.RIGHT in connections: type_str += "R"
	if Direction.TOP in connections: type_str += "T"
	if Direction.BOTTOM in connections: type_str += "B"
	
	return type_str if not type_str.is_empty() else "R"

func place_room(pos: Vector2i) -> bool:
	if not is_valid_position(pos):
		return false
	
	var cell = grid.get(pos) as RoomCell
	if not cell or cell.is_room:
		return false
	
	cell.is_room = true
	rooms.append(pos)
	return true

func get_direction_vector(dir: Direction) -> Vector2i:
	match dir:
		Direction.LEFT: return Vector2i(-1, 0)
		Direction.RIGHT: return Vector2i(1, 0)
		Direction.TOP: return Vector2i(0, -1)
		Direction.BOTTOM: return Vector2i(0, 1)
		_: return Vector2i.ZERO

func get_opposite_direction(dir: Direction) -> Direction:
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.TOP: return Direction.BOTTOM
		Direction.BOTTOM: return Direction.TOP
		_: return Direction.LEFT

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 1 and pos.x <= GRID_SIZE and pos.y >= 1 and pos.y <= GRID_SIZE

func is_room_at(pos: Vector2i) -> bool:
	var cell = grid.get(pos) as RoomCell
	return cell and cell.is_room

func get_empty_neighbors(pos: Vector2i) -> Array:
	var empty_dirs = []
	
	for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
		var neighbor_pos = pos + get_direction_vector(dir)
		if is_valid_position(neighbor_pos) and not is_room_at(neighbor_pos):
			empty_dirs.append(dir)
	
	return empty_dirs

func _log_debug(message: String):
	"""条件调试输出"""
	if DEBUG_MODE:
		print("[LevelGen] " + message)


"""
# ============== 使用示例 ==============

# 示例1：使用默认参数快速生成
func generate_default_level():
	var result = NormalLevelGenerator.generate()
	
	# 获取生成的节点
	add_child(result.level_node)
	
	# 访问网格信息
	print("网格大小: ", result.grid_info.grid_size)
	print("房间数量: ", result.grid_info.room_count)
	
	# 遍历所有房间信息
	for key in result.all_rooms_info:
		var room_info = result.all_rooms_info[key]
		print("房间: ", room_info.room_name)
		print("  全局位置: ", room_info.global_position)
		print("  网格位置: ", room_info.grid_position)
		print("  开口方向: ", room_info.connections)
		print("  连通邻居: ", room_info.connected_neighbors)
		print("  所有邻居: ", room_info.neighbors)

# 示例2：自定义参数生成
func generate_custom_level():
	var result = NormalLevelGenerator.generate(
		7,      # grid_size
		12,     # target_rooms
		0.7,    # connection_rate
		true,   # enable_partitions
		0.8,    # complexity_bias
		12345   # random_seed
	)
	
	add_child(result.level_node)
	
	# 检查特定房间
	if result.all_rooms_info.has("room1_info"):
		var room1 = result.all_rooms_info["room1_info"]
		print("初始房间位置: ", room1.global_position)

# 示例3：使用完整配置字典
func generate_with_config():
	var config = {
		"grid_size": 6,
		"target_rooms": 10,
		"connection_rate": 0.6,
		"enable_partitions": false,
		"complexity_bias": 0.5,
		"random_seed": -1,
		"room_templates": {
			"L": "res://custom_rooms/Room_L.tscn",
			"R": "res://custom_rooms/Room_R.tscn"
		}
	}
	
	var result = NormalLevelGenerator.generate_with_config(config)
	
	# 根据房间信息做进一步处理
	for key in result.all_rooms_info:
		var room_info = result.all_rooms_info[key]
		# 例如：根据连通性生成敌人
		var enemy_count = room_info.connected_neighbors.count(true)
		spawn_enemies_in_room(room_info.room_name, enemy_count)

# 示例4：访问邻居关系
func check_room_connections(result: Dictionary):
	var room5_info = result.all_rooms_info.get("room5_info")
	if room5_info:
		# 检查左边是否有连通的房间
		if room5_info.connected_neighbors[0]:  # 0 = LEFT
			var left_neighbor = room5_info.neighbors[0]
			print("room5 左边连通: ", left_neighbor)
		
		# 检查所有方向
		for i in range(4):
			var dir_names = ["左", "右", "上", "下"]
			if room5_info.neighbors[i]:
				print("方向 %s: %s (连通: %s)" % [
					dir_names[i],
					room5_info.neighbors[i],
					room5_info.connected_neighbors[i]
				])
"""
