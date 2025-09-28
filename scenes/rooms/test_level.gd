# 激进随机关卡生成器 - 潜在连接生长模式
extends Node2D

# ============== 核心参数 ==============
@export var GRID_SIZE: int = 7  # 支持自定义网格大小
@export var TARGET_ROOMS: int = 6  # 目标房间数
@export var CONNECTION_RATE: float = 0.5  # 连接开通率 (0.5-1.0)
@export var ENABLE_PARTITIONS: bool = true  # 是否启用隔断
@export var COMPLEXITY_BIAS: float = 0.5  # 复杂形状偏好 (0.0-1.0)
@export var RANDOM_SEED: int = -1  # 随机种子 (-1为随机)

const ROOM_WIDTH = 1664
const ROOM_HEIGHT = 1024

# 方向枚举
enum Direction { LEFT = 0, RIGHT = 1, TOP = 2, BOTTOM = 3 }

# 房间模板映射
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
	var connections: Array = []  # 改为普通数组
	var scene_instance: Node2D = null
	
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

# 全局状态
var grid: Dictionary = {}
var rooms: Array = []  # 改为普通数组
var potential_connections: Array = []  # 改为普通数组
var active_connections: Array = []  # 改为普通数组
var rng: RandomNumberGenerator

func _ready():
	generate_level()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		generate_level()

# ============== 主生成流程 ==============
func generate_level():
	"""全新的激进随机关卡生成 - 增强容错性"""
	clear_previous_level()
	initialize_generator()
	
	print("=== 开始激进随机关卡生成 ===")
	print("网格大小: %dx%d" % [GRID_SIZE, GRID_SIZE])
	print("目标房间数: %d" % TARGET_ROOMS)
	print("随机种子: %d" % rng.seed)
	
	# 多次尝试生成，增加成功率
	var max_attempts = 3
	var attempt = 0
	
	while attempt < max_attempts:
		attempt += 1
		print("=== 尝试 %d/%d ===" % [attempt, max_attempts])
		
		# 重置状态
		if attempt > 1:
			clear_previous_level()
			initialize_generator()
		
		# 第一阶段：房间布局生成
		if not phase_one_room_placement():
			print("❌ 房间布局生成失败，重试...")
			continue
		
		# 验证房间数量
		if rooms.size() > TARGET_ROOMS:
			print("❌ 生成了过多房间 (%d > %d)，重试..." % [rooms.size(), TARGET_ROOMS])
			continue
		
		print("✅ 房间布局: %d 个房间" % rooms.size())
		
		# 第二阶段：潜在连接分析 
		phase_two_analyze_connections()
		
		# 第三阶段：连接选择与生长
		phase_three_connection_growth()
		
		# 第四阶段：连通性验证与修复
		if not phase_four_connectivity_check():
			print("❌ 连通性验证失败，重试...")
			continue
		
		# 最终验证
		if not validate_final_generation():
			print("❌ 最终验证失败，重试...")
			continue
		
		# 成功生成
		phase_five_instantiation()
		
		print("=== 关卡生成完成 ===")
		print("✅ 最终房间数: %d" % rooms.size())
		print("✅ 连接数: %d" % active_connections.size())
		print("✅ 平均连接度: %.2f" % get_average_connectivity())
		analyze_level_topology()
		return
	
	# 所有尝试都失败，生成备用简单布局
	print("⚠️ 多次尝试失败，生成备用布局")
	generate_fallback_level()

func validate_final_generation() -> bool:
	"""最终生成验证"""
	# 检查房间数量
	if rooms.size() > TARGET_ROOMS:
		print("验证失败：房间数量 %d 超过目标 %d" % [rooms.size(), TARGET_ROOMS])
		return false
	
	if rooms.size() < max(3, TARGET_ROOMS / 3):
		print("验证失败：房间数量 %d 太少" % rooms.size())
		return false
	
	# 检查是否有重复房间
	var unique_rooms = {}
	for room_pos in rooms:
		if room_pos in unique_rooms:
			print("验证失败：发现重复房间 %s" % str(room_pos))
			return false
		unique_rooms[room_pos] = true
	
	# 检查所有房间都在网格中且标记为is_room
	for room_pos in rooms:
		if not is_room_at(room_pos):
			print("验证失败：房间 %s 未正确标记" % str(room_pos))
			return false
	
	return true

func generate_fallback_level():
	"""生成备用简单布局 - 保证成功"""
	print("生成备用布局...")
	clear_previous_level()
	initialize_generator()
	
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	var simple_rooms = min(TARGET_ROOMS, 7)  # 限制房间数，确保不超过目标
	
	# 清空rooms数组，确保没有残留
	rooms.clear()
	
	# 生成简单线性布局
	if not place_room(center):
		print("错误：无法放置中心房间")
		return
		
	var current_pos = center
	var placed_count = 1
	
	for i in range(simple_rooms - 1):
		if placed_count >= TARGET_ROOMS:
			break
			
		var directions = [Direction.RIGHT, Direction.BOTTOM, Direction.LEFT, Direction.TOP]
		directions.shuffle()
		var placed = false
		
		for dir in directions:
			var next_pos = current_pos + get_direction_vector(dir)
			if is_valid_position(next_pos) and not is_room_at(next_pos):
				if place_room(next_pos):
					# 创建连接
					var conn = PotentialConnection.new(current_pos, next_pos, dir, 1.0)
					active_connections.append(conn)
					apply_single_connection(conn)
					
					current_pos = next_pos
					placed_count += 1
					placed = true
					break
		
		if not placed:
			# 如果当前位置无法扩展，尝试从其他已有房间扩展
			var found_new_pos = false
			for room_pos in rooms:
				var dirs = [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]
				dirs.shuffle()
				for d in dirs:
					var new_pos = room_pos + get_direction_vector(d)
					if is_valid_position(new_pos) and not is_room_at(new_pos):
						if place_room(new_pos):
							var conn = PotentialConnection.new(room_pos, new_pos, d, 1.0)
							active_connections.append(conn)
							apply_single_connection(conn)
							current_pos = new_pos
							placed_count += 1
							found_new_pos = true
							break
				if found_new_pos:
					break
			
			if not found_new_pos:
				break
	
	print("备用布局生成完成: %d 个房间 (目标: %d)" % [rooms.size(), TARGET_ROOMS])
	
	# 验证房间数量
	if rooms.size() > TARGET_ROOMS:
		print("错误：生成了过多房间！")
		# 只保留TARGET_ROOMS个房间
		while rooms.size() > TARGET_ROOMS:
			rooms.pop_back()
	
	phase_five_instantiation()

func clear_previous_level():
	"""清理之前的关卡"""
	for child in get_children():
		if child is Node2D and child != self:
			child.queue_free()
	
	grid.clear()
	rooms.clear()
	potential_connections.clear()
	active_connections.clear()

func initialize_generator():
	"""初始化生成器"""
	# 清空rooms数组，防止残留数据
	rooms.clear()
	
	# 随机种子处理
	if RANDOM_SEED == -1:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	else:
		rng = RandomNumberGenerator.new()
		rng.seed = RANDOM_SEED
	
	# 初始化网格 - 确保每个格子都是新的
	grid.clear()
	for x in range(1, GRID_SIZE + 1):
		for y in range(1, GRID_SIZE + 1):
			grid[Vector2i(x, y)] = RoomCell.new()

# ============== 第一阶段：房间布局生成 ==============
func phase_one_room_placement() -> bool:
	"""使用多种策略生成房间布局"""
	print("第一阶段：房间布局生成")
	
	# 根据复杂度偏好选择生成策略
	var strategy = choose_placement_strategy()
	print("选择策略: %s" % strategy)
	
	var success = false
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
	
	# 如果房间数不足，尝试补充
	if success and rooms.size() < TARGET_ROOMS:
		print("房间数不足 (%d/%d)，尝试补充..." % [rooms.size(), TARGET_ROOMS])
		supplement_to_target()
	
	# 检查最终结果
	if rooms.size() < min(3, TARGET_ROOMS):
		return false
	
	if rooms.size() > TARGET_ROOMS:
		# 如果超过了，移除多余的房间
		print("房间数过多 (%d/%d)，移除多余房间..." % [rooms.size(), TARGET_ROOMS])
		while rooms.size() > TARGET_ROOMS:
			var removed_pos = rooms.pop_back()
			var cell = grid[removed_pos] as RoomCell
			if cell:
				cell.is_room = false
	
	return true

func supplement_to_target():
	"""补充房间到目标数量"""
	var attempts = 0
	var max_attempts = 50
	
	while rooms.size() < TARGET_ROOMS and attempts < max_attempts:
		attempts += 1
		
		# 策略1：在现有房间附近放置
		var placed = false
		if not rooms.is_empty():
			# 随机选择一个现有房间
			var base_room = rooms[rng.randi() % rooms.size()]
			var dirs = [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]
			dirs.shuffle()
			
			for dir in dirs:
				var new_pos = base_room + get_direction_vector(dir)
				if is_valid_position(new_pos) and not is_room_at(new_pos):
					if place_room(new_pos):
						placed = true
						break
		
		# 策略2：如果上面失败，尝试在任意空位放置
		if not placed:
			var candidates = []
			for room_pos in rooms:
				for radius in range(1, 3):  # 扩大搜索半径
					for dx in range(-radius, radius + 1):
						for dy in range(-radius, radius + 1):
							if abs(dx) == radius or abs(dy) == radius:  # 只检查边界
								var check_pos = room_pos + Vector2i(dx, dy)
								if is_valid_position(check_pos) and not is_room_at(check_pos):
									# 确保至少有一个相邻房间
									var has_neighbor = false
									for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
										var neighbor = check_pos + get_direction_vector(dir)
										if is_room_at(neighbor):
											has_neighbor = true
											break
									if has_neighbor and check_pos not in candidates:
										candidates.append(check_pos)
			
			if not candidates.is_empty():
				candidates.shuffle()
				place_room(candidates[0])
	
	print("补充后房间数: %d/%d" % [rooms.size(), TARGET_ROOMS])

func choose_placement_strategy() -> String:
	"""根据参数选择房间放置策略"""
	var strategies = []
	
	# 根据复杂度偏好权重不同策略
	if COMPLEXITY_BIAS > 0.7:
		strategies.append_array(["shape_template", "path_based", "organic_growth"])
	elif COMPLEXITY_BIAS > 0.4:
		strategies.append_array(["organic_growth", "cluster_expansion", "shape_template"])
	else:
		strategies.append_array(["cluster_expansion", "organic_growth"])
	
	return strategies[rng.randi() % strategies.size()]

func organic_growth_placement() -> bool:
	"""有机生长房间布局 - 增强版"""
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	
	# 起始房间
	if not place_room(center):
		# 如果中心不可用，找一个可用位置
		center = find_valid_start_position()
		if center == Vector2i(-1, -1):
			return false
		place_room(center)
	
	var growth_queue = [center]
	var attempts = 0
	var max_attempts = TARGET_ROOMS * 30  # 增加最大尝试次数
	var stagnant_count = 0  # 停滞计数器
	
	while rooms.size() < TARGET_ROOMS and not growth_queue.is_empty() and attempts < max_attempts:
		attempts += 1
		
		# 如果停滞太久，随机重新激活
		if stagnant_count > 10:
			add_random_seed_rooms()
			stagnant_count = 0
		
		# 选择生长点
		var growth_pos = select_growth_position(growth_queue)
		if growth_pos == Vector2i(-1, -1):
			break
		
		# 获取可扩展方向
		var available_dirs = get_empty_neighbors(growth_pos)
		if available_dirs.is_empty():
			growth_queue.erase(growth_pos)
			stagnant_count += 1
			continue
		
		# 根据复杂度偏好选择扩展数量
		var expand_count = calculate_expansion_count(growth_pos, available_dirs)
		
		# 执行扩展
		var expanded = false
		for i in range(expand_count):
			if available_dirs.is_empty():
				break
				
			var chosen_dir = select_expansion_direction(growth_pos, available_dirs)
			var new_pos = growth_pos + get_direction_vector(chosen_dir)
			
			if place_room(new_pos):
				growth_queue.append(new_pos)
				available_dirs.erase(chosen_dir)
				expanded = true
		
		if expanded:
			stagnant_count = 0
		else:
			stagnant_count += 1
		
		# 更新生长队列 - 移除扩展潜力低的房间
		if get_expansion_potential(growth_pos) < 1:
			growth_queue.erase(growth_pos)
	
	print("有机生长完成: %d 个房间, %d 次尝试" % [rooms.size(), attempts])
	
	# 如果房间数太少，尝试补充
	if rooms.size() < max(3, TARGET_ROOMS / 3):
		supplement_rooms()
	
	return rooms.size() >= 3

func shape_template_placement() -> bool:
	"""基于形状模板的房间布局"""
	var templates = [
		"u_shape", "l_shape", "s_shape", "ring_shape", 
		"cross_shape", "spiral_shape", "branch_shape"
	]
	
	var chosen_template = templates[rng.randi() % templates.size()]
	print("使用形状模板: %s" % chosen_template)
	
	match chosen_template:
		"u_shape":
			return generate_u_shape()
		"l_shape":
			return generate_l_shape()
		"s_shape":
			return generate_s_shape()
		"ring_shape":
			return generate_ring_shape()
		"cross_shape":
			return generate_cross_shape()
		"spiral_shape":
			return generate_spiral_shape()
		"branch_shape":
			return generate_branch_shape()
		_:
			return organic_growth_placement()

func cluster_expansion_placement() -> bool:
	"""集群扩展房间布局"""
	var cluster_centers = generate_cluster_centers()
	
	for center in cluster_centers:
		var cluster_size = max(2, TARGET_ROOMS / cluster_centers.size())
		expand_cluster(center, cluster_size)
	
	return rooms.size() >= max(3, TARGET_ROOMS / 2)

func path_based_placement() -> bool:
	"""基于路径的房间布局"""
	var start_pos = Vector2i(rng.randi_range(2, GRID_SIZE-1), rng.randi_range(2, GRID_SIZE-1))
	place_room(start_pos)
	
	# 生成主路径
	var main_path = generate_random_path(start_pos, TARGET_ROOMS / 2)
	for pos in main_path:
		place_room(pos)
	
	# 生成分支路径
	for pos in main_path:
		if rng.randf() < COMPLEXITY_BIAS:
			var branch_length = rng.randi_range(1, 4)
			var branch = generate_random_path(pos, branch_length)
			for branch_pos in branch:
				if rooms.size() < TARGET_ROOMS:
					place_room(branch_pos)
	
	return rooms.size() >= max(3, TARGET_ROOMS / 2)

# ============== 形状模板实现 ==============
func generate_u_shape() -> bool:
	"""生成U形布局"""
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	var width = min(5, GRID_SIZE - 2)
	var height = min(4, GRID_SIZE - 2)
	
	# U形的三条边
	for i in range(height):
		place_room(center + Vector2i(-width/2, i))  # 左边
		place_room(center + Vector2i(width/2, i))   # 右边
	
	for i in range(width + 1):
		place_room(center + Vector2i(-width/2 + i, 0))  # 底边
	
	# 随机添加一些额外房间
	add_random_rooms_nearby(rooms, TARGET_ROOMS - rooms.size())
	
	return rooms.size() >= 5

func generate_l_shape() -> bool:
	"""生成L形布局"""
	var corner = Vector2i(rng.randi_range(2, GRID_SIZE-3), rng.randi_range(2, GRID_SIZE-3))
	var arm1_len = rng.randi_range(3, min(5, GRID_SIZE - corner.x))
	var arm2_len = rng.randi_range(3, min(5, GRID_SIZE - corner.y))
	
	# L的两条臂
	for i in range(arm1_len):
		place_room(corner + Vector2i(i, 0))
	for i in range(1, arm2_len):
		place_room(corner + Vector2i(0, i))
	
	add_random_rooms_nearby(rooms, TARGET_ROOMS - rooms.size())
	return rooms.size() >= 4

func generate_s_shape() -> bool:
	"""生成S形布局"""
	var start_y = rng.randi_range(2, GRID_SIZE - 4)
	var mid_x = GRID_SIZE / 2 + 1
	
	# S形的三段
	for x in range(2, mid_x + 1):
		place_room(Vector2i(x, start_y))
	for y in range(start_y, start_y + 3):
		place_room(Vector2i(mid_x, y))
	for x in range(mid_x, GRID_SIZE):
		place_room(Vector2i(x, start_y + 2))
	
	add_random_rooms_nearby(rooms, TARGET_ROOMS - rooms.size())
	return rooms.size() >= 6

func generate_ring_shape() -> bool:
	"""生成环形布局"""
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	var radius = min(2, (GRID_SIZE - 3) / 2)
	
	# 生成环形的8个方向位置
	var ring_positions = [
		center + Vector2i(-radius, -radius),
		center + Vector2i(0, -radius),
		center + Vector2i(radius, -radius),
		center + Vector2i(radius, 0),
		center + Vector2i(radius, radius),
		center + Vector2i(0, radius),
		center + Vector2i(-radius, radius),
		center + Vector2i(-radius, 0)
	]
	
	for pos in ring_positions:
		if is_valid_position(pos):
			place_room(pos)
	
	add_random_rooms_nearby(rooms, TARGET_ROOMS - rooms.size())
	return rooms.size() >= 6

func generate_cross_shape() -> bool:
	"""生成十字形布局"""
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	
	# 根据目标房间数动态调整臂长
	var max_rooms_in_cross = 1 + 4 * 3  # 中心 + 4个方向各最多3格
	var desired_cross_rooms = min(TARGET_ROOMS, max_rooms_in_cross)
	var arm_length = min((desired_cross_rooms - 1) / 4, (GRID_SIZE - 3) / 2)
	arm_length = max(1, int(arm_length))
	
	# 十字的四条臂
	place_room(center)
	for i in range(1, arm_length + 1):
		if rooms.size() >= TARGET_ROOMS:
			break
		place_room(center + Vector2i(i, 0))   # 右
		if rooms.size() >= TARGET_ROOMS:
			break
		place_room(center + Vector2i(-i, 0))  # 左
		if rooms.size() >= TARGET_ROOMS:
			break
		place_room(center + Vector2i(0, i))   # 下
		if rooms.size() >= TARGET_ROOMS:
			break
		place_room(center + Vector2i(0, -i))  # 上
	
	# 只有在房间数不足时才补充
	if rooms.size() < TARGET_ROOMS:
		add_random_rooms_nearby(rooms.duplicate(), TARGET_ROOMS - rooms.size())
	
	return rooms.size() >= min(5, TARGET_ROOMS)

func generate_spiral_shape() -> bool:
	"""生成螺旋形布局"""
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	var current_pos = center
	place_room(current_pos)
	
	var directions = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var dir_index = 0
	var steps_in_direction = 1
	var step_count = 0
	var total_steps = 0
	
	while rooms.size() < TARGET_ROOMS and total_steps < 20:
		var next_pos = current_pos + directions[dir_index]
		
		if is_valid_position(next_pos):
			place_room(next_pos)
			current_pos = next_pos
			step_count += 1
			total_steps += 1
			
			if step_count >= steps_in_direction:
				dir_index = (dir_index + 1) % 4
				if dir_index % 2 == 0:
					steps_in_direction += 1
				step_count = 0
		else:
			break
	
	return rooms.size() >= 4

func generate_branch_shape() -> bool:
	"""生成分支形布局"""
	var root = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	place_room(root)
	
	# 生成主干
	var trunk_length = min(rng.randi_range(2, 3), TARGET_ROOMS - 1)
	var trunk_dir = rng.randi() % 4
	var current_pos = root
	
	for i in range(trunk_length):
		if rooms.size() >= TARGET_ROOMS:
			break
		current_pos += get_direction_vector(trunk_dir as Direction)
		if is_valid_position(current_pos):
			place_room(current_pos)
	
	# 在主干上生成分支，确保不超过目标房间数
	var trunk_rooms = rooms.duplicate()
	for pos in trunk_rooms:
		if rooms.size() >= TARGET_ROOMS:
			break
		if rng.randf() < 0.6:  # 60%概率生成分支
			var branch_dirs = get_empty_neighbors(pos)
			if not branch_dirs.is_empty():
				var branch_dir = branch_dirs[rng.randi() % branch_dirs.size()]
				var branch_pos = pos + get_direction_vector(branch_dir)
				place_room(branch_pos)
	
	# 如果房间数还不够，补充到目标数量
	if rooms.size() < TARGET_ROOMS:
		add_random_rooms_nearby(rooms.duplicate(), TARGET_ROOMS - rooms.size())
	
	return rooms.size() >= min(4, TARGET_ROOMS)

# ============== 第二阶段：潜在连接分析 ==============
func phase_two_analyze_connections():
	"""分析所有可能的房间连接"""
	print("第二阶段：分析潜在连接")
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
				
				# 避免重复连接
				if not has_connection_pair(connection):
					potential_connections.append(connection)
	
	print("发现 %d 个潜在连接" % potential_connections.size())

func calculate_connection_weight(pos1: Vector2i, pos2: Vector2i, dir: Direction) -> float:
	"""计算连接的权重"""
	var weight = 1.0
	
	# 基于位置的权重调整
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	var avg_distance = (pos1.distance_to(center) + pos2.distance_to(center)) / 2
	weight += (GRID_SIZE - avg_distance) * 0.1
	
	# 基于连接方向的权重
	if dir == Direction.LEFT or dir == Direction.RIGHT:
		weight += 0.1  # 水平连接稍微优先
	
	# 基于形状复杂度的权重调整
	weight += COMPLEXITY_BIAS * 0.5
	
	return weight

func has_connection_pair(conn: PotentialConnection) -> bool:
	"""检查是否已存在相同的连接对"""
	for existing in potential_connections:
		if (existing.pos1 == conn.pos1 and existing.pos2 == conn.pos2) or \
		   (existing.pos1 == conn.pos2 and existing.pos2 == conn.pos1):
			return true
	return false

# ============== 第三阶段：连接选择与生长 ==============
func phase_three_connection_growth():
	"""基于权重和策略选择连接"""
	print("第三阶段：连接生长")
	active_connections.clear()
	
	if not ENABLE_PARTITIONS:
		# 不启用隔断：开通所有连接
		active_connections = potential_connections.duplicate()
		print("隔断禁用：开通全部 %d 个连接" % active_connections.size())
	else:
		# 启用隔断：智能选择连接
		active_connections = select_connections_intelligently()
		print("智能选择：开通 %d/%d 个连接" % [active_connections.size(), potential_connections.size()])
	
	# 应用选定的连接
	apply_connections()

func select_connections_intelligently() -> Array:
	"""智能选择连接 - 确保连通性的前提下控制连接密度"""
	var selected = []
	
	# 首先确保基本连通性：使用最小生成树算法
	var mst_connections = build_minimum_spanning_tree()
	selected.append_array(mst_connections)
	
	# 根据CONNECTION_RATE添加额外连接
	var remaining_connections = []
	for conn in potential_connections:
		if conn not in selected:
			remaining_connections.append(conn)
	
	# 按权重排序剩余连接
	remaining_connections.sort_custom(func(a, b): return a.weight > b.weight)
	
	# 计算要添加的额外连接数
	var extra_count = int((potential_connections.size() - mst_connections.size()) * CONNECTION_RATE)
	extra_count = min(extra_count, remaining_connections.size())
	
	# 添加高权重连接，但要避免过度连接
	for i in range(extra_count):
		var conn = remaining_connections[i]
		if should_add_connection(conn, selected):
			selected.append(conn)
	
	return selected

func build_minimum_spanning_tree() -> Array:
	"""构建最小生成树确保连通性"""
	if rooms.size() <= 1:
		return []
	
	var mst = []
	var visited = {rooms[0]: true}
	var edges = []
	
	# 初始化边集合
	for conn in potential_connections:
		if conn.pos1 == rooms[0]:
			edges.append(conn)
	
	while visited.size() < rooms.size() and not edges.is_empty():
		# 找到最小权重的边，连接已访问和未访问的节点
		edges.sort_custom(func(a, b): return a.weight > b.weight)
		
		var best_edge = null
		for edge in edges:
			if (edge.pos1 in visited) != (edge.pos2 in visited):
				best_edge = edge
				break
		
		if not best_edge:
			break
		
		# 添加这条边到MST
		mst.append(best_edge)
		var new_node = best_edge.pos2 if best_edge.pos1 in visited else best_edge.pos1
		visited[new_node] = true
		
		# 添加新节点的所有边
		for conn in potential_connections:
			if (conn.pos1 == new_node and conn.pos2 not in visited) or \
			   (conn.pos2 == new_node and conn.pos1 not in visited):
				if conn not in edges:
					edges.append(conn)
		
		# 移除已处理的边
		edges.erase(best_edge)
	
	print("MST: %d 条边确保连通性" % mst.size())
	return mst

func should_add_connection(conn: PotentialConnection, existing: Array) -> bool:
	"""判断是否应该添加这个连接"""
	# 检查连接度 - 避免某个房间连接过多
	var pos1_connections = count_connections_for_room(conn.pos1, existing)
	var pos2_connections = count_connections_for_room(conn.pos2, existing)
	
	var max_connections = 4  # 最多4个连接
	if pos1_connections >= max_connections or pos2_connections >= max_connections:
		return false
	
	# 根据复杂度偏好决定
	if COMPLEXITY_BIAS > 0.6:
		return rng.randf() < 0.8  # 高复杂度：更多连接
	else:
		return rng.randf() < 0.4  # 低复杂度：较少连接

func count_connections_for_room(room_pos: Vector2i, connections: Array) -> int:
	"""计算房间的连接数"""
	var count = 0
	for conn in connections:
		if conn.pos1 == room_pos or conn.pos2 == room_pos:
			count += 1
	return count

func apply_connections():
	"""应用选定的连接到房间"""
	for conn in active_connections:
		apply_single_connection(conn)

func apply_single_connection(conn: PotentialConnection):
	"""应用单个连接"""
	var cell1 = grid[conn.pos1] as RoomCell
	var cell2 = grid[conn.pos2] as RoomCell
	
	cell1.add_connection(conn.direction)
	cell2.add_connection(get_opposite_direction(conn.direction))

# ============== 第四阶段：连通性验证与修复 ==============
func phase_four_connectivity_check() -> bool:
	"""验证并修复连通性 - 增强版"""
	print("第四阶段：连通性验证")
	
	if rooms.size() <= 1:
		print("✅ 单房间或空关卡，无需验证连通性")
		return true
	
	var reachable_rooms = get_all_reachable_rooms(rooms[0])
	
	if reachable_rooms.size() == rooms.size():
		print("✅ 所有房间连通")
		return true
	
	print("⚠️ 发现 %d 个不连通房间，尝试修复" % (rooms.size() - reachable_rooms.size()))
	
	# 修复连通性 - 多重策略
	var repair_success = repair_connectivity_enhanced(reachable_rooms)
	
	if not repair_success:
		print("⚠️ 标准修复失败，尝试强制连接")
		repair_success = force_connectivity_repair()
	
	# 最终验证
	var final_reachable = get_all_reachable_rooms(rooms[0])
	print("修复后连通性: %d/%d" % [final_reachable.size(), rooms.size()])
	
	if final_reachable.size() == rooms.size():
		print("✅ 连通性修复成功")
		return true
	else:
		print("❌ 连通性修复失败")
		return false

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
			
			# 更新可达房间列表
			reachable_rooms = get_all_reachable_rooms(rooms[0])
	
	# 策略2: 如果还有不连通的，尝试创建新的连接
	if repairs_made > 0:
		unreachable.clear()
		for room in rooms:
			if room not in reachable_rooms:
				unreachable.append(room)
	
	# 策略3: 对剩余不连通房间，寻找最短路径连接
	for unreachable_room in unreachable:
		var closest_reachable = find_closest_reachable_room(unreachable_room, reachable_rooms)
		if closest_reachable != Vector2i(-1, -1):
			var path_connections = create_path_connections(unreachable_room, closest_reachable)
			for conn in path_connections:
				active_connections.append(conn)
				apply_single_connection(conn)
				repairs_made += 1
			
			reachable_rooms = get_all_reachable_rooms(rooms[0])
	
	print("连通性修复: 应用了 %d 个修复连接" % repairs_made)
	return repairs_made > 0

func force_connectivity_repair() -> bool:
	"""强制连通性修复 - 最后手段"""
	print("执行强制连通性修复")
	
	# 强制连接所有相邻房间
	var forced_connections = 0
	
	for room_pos in rooms:
		for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
			var neighbor_pos = room_pos + get_direction_vector(dir)
			
			if is_room_at(neighbor_pos):
				# 检查是否已有连接
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
	
	print("强制添加了 %d 个连接" % forced_connections)
	return forced_connections > 0

func find_closest_reachable_room(unreachable_pos: Vector2i, reachable_rooms: Array) -> Vector2i:
	"""找到最近的可达房间"""
	var closest = Vector2i(-1, -1)
	var min_distance = float('inf')
	
	for reachable_pos in reachable_rooms:
		var distance = abs(unreachable_pos.x - reachable_pos.x) + abs(unreachable_pos.y - reachable_pos.y)
		if distance < min_distance:
			min_distance = distance
			closest = reachable_pos
	
	return closest

func create_path_connections(start: Vector2i, end: Vector2i) -> Array:
	"""创建从start到end的路径连接"""
	var connections = []
	var current = start
	
	# 简单的曼哈顿路径
	while current != end:
		var next_pos = current
		
		# 优先水平移动
		if current.x != end.x:
			if current.x < end.x:
				next_pos = current + Vector2i(1, 0)
			else:
				next_pos = current + Vector2i(-1, 0)
		# 然后垂直移动
		elif current.y != end.y:
			if current.y < end.y:
				next_pos = current + Vector2i(0, 1)
			else:
				next_pos = current + Vector2i(0, -1)
		
		# 确保路径上的位置都有房间
		if not is_room_at(next_pos):
			place_room(next_pos)
		
		# 创建连接
		var direction = get_direction_from_offset(next_pos - current)
		var conn = PotentialConnection.new(current, next_pos, direction, 999.0)
		connections.append(conn)
		
		current = next_pos
	
	return connections

func get_direction_from_offset(offset: Vector2i) -> Direction:
	"""从偏移向量获取方向"""
	if offset == Vector2i(1, 0):
		return Direction.RIGHT
	elif offset == Vector2i(-1, 0):
		return Direction.LEFT
	elif offset == Vector2i(0, 1):
		return Direction.BOTTOM
	elif offset == Vector2i(0, -1):
		return Direction.TOP
	else:
		return Direction.RIGHT  # 默认值

func get_all_reachable_rooms(start_room: Vector2i) -> Array:
	"""获取从起始房间可达的所有房间"""
	var visited = {}
	var queue = [start_room]
	var reachable = []
	
	while not queue.is_empty():
		var current = queue.pop_front()
		if current in visited:
			continue
		
		visited[current] = true
		reachable.append(current)
		
		var cell = grid[current] as RoomCell
		for dir in cell.connections:
			var neighbor = current + get_direction_vector(dir)
			if neighbor in rooms and neighbor not in visited and neighbor not in queue:
				queue.append(neighbor)
	
	return reachable

func find_bridge_connection(unreachable_room: Vector2i, reachable_rooms: Array) -> PotentialConnection:
	"""找到桥接不连通房间的连接"""
	for conn in potential_connections:
		if (conn.pos1 == unreachable_room and conn.pos2 in reachable_rooms) or \
		   (conn.pos2 == unreachable_room and conn.pos1 in reachable_rooms):
			return conn
	return null

# ============== 第五阶段：实例化房间 ==============
func phase_five_instantiation():
	"""实例化房间场景"""
	print("第五阶段：房间实例化")
	
	var instantiated = 0
	# 确保只实例化实际存在的房间
	for room_pos in rooms:
		if not is_room_at(room_pos):
			print("警告：rooms数组中包含无效房间位置 %s" % str(room_pos))
			continue
			
		var cell = grid[room_pos] as RoomCell
		var room_type = get_room_type_from_connections(cell.connections)
		
		if instantiate_room_scene(room_pos, room_type):
			instantiated += 1
	
	print("成功实例化 %d/%d 个房间" % [instantiated, rooms.size()])

func get_room_type_from_connections(connections: Array) -> String:
	"""根据连接生成房间类型字符串"""
	var type_str = ""
	
	if Direction.LEFT in connections: type_str += "L"
	if Direction.RIGHT in connections: type_str += "R"
	if Direction.TOP in connections: type_str += "T"
	if Direction.BOTTOM in connections: type_str += "B"
	
	return type_str if not type_str.is_empty() else "R"

func instantiate_room_scene(grid_pos: Vector2i, room_type: String) -> bool:
	"""实例化房间场景"""
	if not room_templates.has(room_type):
		print("⚠️ 未找到房间模板: %s，使用默认模板 R" % room_type)
		room_type = "R"
	
	var room_scene = load(room_templates[room_type])
	if not room_scene:
		print("❌ 加载房间场景失败: %s" % room_type)
		return false
	
	var room_instance = room_scene.instantiate()
	var center_offset = (GRID_SIZE + 1) / 2.0
	
	var world_pos = Vector2(
		(grid_pos.x - center_offset) * ROOM_WIDTH,
		(grid_pos.y - center_offset) * ROOM_HEIGHT
	)
	
	room_instance.position = world_pos
	add_child(room_instance)
	
	var cell = grid[grid_pos] as RoomCell
	cell.scene_instance = room_instance
	
	return true

# ============== 分析与调试函数 ==============
func analyze_level_topology():
	"""分析关卡拓扑结构"""
	var analysis = {
		"dead_ends": 0,
		"corridors": 0,
		"junctions": 0,
		"crosses": 0,
		"loops": 0
	}
	
	for room_pos in rooms:
		var cell = grid[room_pos] as RoomCell
		var conn_count = cell.get_connection_count()
		
		match conn_count:
			1:
				analysis.dead_ends += 1
			2:
				if is_corridor(cell):
					analysis.corridors += 1
				else:
					analysis.junctions += 1  # 转角
			3:
				analysis.junctions += 1
			4:
				analysis.crosses += 1
	
	# 检测环路
	analysis.loops = count_loops()
	
	print("=== 拓扑分析 ===")
	print("死胡同: %d" % analysis.dead_ends)
	print("走廊: %d" % analysis.corridors)
	print("转角/三岔路: %d" % analysis.junctions)
	print("十字路口: %d" % analysis.crosses)
	print("环路数量: %d" % analysis.loops)

func is_corridor(cell: RoomCell) -> bool:
	"""判断是否为直线走廊"""
	if cell.connections.size() != 2:
		return false
	
	var dirs = cell.connections
	# 检查是否为对向连接
	return (Direction.LEFT in dirs and Direction.RIGHT in dirs) or \
		   (Direction.TOP in dirs and Direction.BOTTOM in dirs)

func count_loops() -> int:
	"""简单的环路计数"""
	var loop_count = 0
	var total_connections = active_connections.size()
	var min_tree_edges = rooms.size() - 1
	
	# 基本的环路数估算：额外边数
	loop_count = max(0, total_connections - min_tree_edges)
	
	return loop_count

func get_average_connectivity() -> float:
	"""计算平均连接度"""
	if rooms.is_empty():
		return 0.0
	
	var total_connections = 0
	for room_pos in rooms:
		var cell = grid[room_pos] as RoomCell
		total_connections += cell.get_connection_count()
	
	return float(total_connections) / float(rooms.size())

# ============== 辅助工具函数 ==============
func place_room(pos: Vector2i) -> bool:
	"""在指定位置放置房间"""
	if not is_valid_position(pos):
		return false
	
	var cell = grid.get(pos) as RoomCell
	if not cell:
		print("错误：网格位置 %s 没有有效的cell" % str(pos))
		return false
		
	if cell.is_room:
		# 房间已存在
		return false
	
	cell.is_room = true
	rooms.append(pos)
	
	# 调试：打印当前房间数
	if rooms.size() > TARGET_ROOMS:
		print("警告：房间数 (%d) 超过目标 (%d)！" % [rooms.size(), TARGET_ROOMS])
	
	return true

func select_growth_position(queue: Array) -> Vector2i:
	"""选择最佳生长位置"""
	if queue.is_empty():
		return Vector2i(-1, -1)
	
	var best_pos = queue[0]
	var best_score = get_expansion_potential(best_pos)
	
	for pos in queue:
		var score = get_expansion_potential(pos)
		# 加入随机因子
		score += rng.randf() * 2
		
		if score > best_score:
			best_score = score
			best_pos = pos
	
	return best_pos

func get_expansion_potential(pos: Vector2i) -> float:
	"""获取位置的扩展潜力"""
	var empty_neighbors = get_empty_neighbors(pos).size()
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	var distance_to_center = pos.distance_to(center)
	
	# 综合考虑空邻居数量和到中心的距离
	return empty_neighbors * 2.0 + (GRID_SIZE - distance_to_center) * 0.5

func calculate_expansion_count(pos: Vector2i, available_dirs: Array) -> int:
	"""计算应该扩展的房间数量"""
	var max_expand = min(available_dirs.size(), TARGET_ROOMS - rooms.size())
	
	if max_expand <= 0:
		return 0
	
	# 根据复杂度偏好决定扩展数量
	var expand_weights = []
	for i in range(1, max_expand + 1):
		if i == 1:
			expand_weights.append(1.0 - COMPLEXITY_BIAS * 0.5)  # 单扩展
		elif i == 2:
			expand_weights.append(COMPLEXITY_BIAS)  # 双扩展
		else:
			expand_weights.append(COMPLEXITY_BIAS * 1.5)  # 多扩展
	
	return weighted_random_choice(expand_weights) + 1

func select_expansion_direction(pos: Vector2i, available_dirs: Array) -> Direction:
	"""智能选择扩展方向"""
	var direction_scores = []
	
	for dir in available_dirs:
		var target_pos = pos + get_direction_vector(dir)
		var score = 0.0
		
		# 评估这个方向的扩展价值
		score += count_empty_neighbors(target_pos) * 2  # 周围空间
		score += get_shape_bonus(pos, dir) * 3  # 形状奖励
		score += rng.randf() * 2  # 随机因子
		
		direction_scores.append([dir, score])
	
	direction_scores.sort_custom(func(a, b): return a[1] > b[1])
	return direction_scores[0][0]

func get_shape_bonus(pos: Vector2i, dir: Direction) -> float:
	"""获取形状奖励分数"""
	var target_pos = pos + get_direction_vector(dir)
	var bonus = 0.0
	
	# 检查是否能形成有趣的形状
	if can_form_corner(pos, dir):
		bonus += 2.0
	if can_extend_line(pos, dir):
		bonus += 1.0
	if can_close_loop(pos, dir):
		bonus += 3.0
	
	return bonus

func can_form_corner(pos: Vector2i, dir: Direction) -> bool:
	"""检查是否能形成角落"""
	var target_pos = pos + get_direction_vector(dir)
	var perpendicular_dirs = get_perpendicular_directions(dir)
	
	for perp_dir in perpendicular_dirs:
		var check_pos = target_pos + get_direction_vector(perp_dir)
		if is_valid_position(check_pos) and not is_room_at(check_pos):
			return true
	
	return false

func can_extend_line(pos: Vector2i, dir: Direction) -> bool:
	"""检查是否能延伸直线"""
	var opposite_dir = get_opposite_direction(dir)
	var check_pos = pos + get_direction_vector(opposite_dir)
	return is_valid_position(check_pos) and is_room_at(check_pos)

func can_close_loop(pos: Vector2i, dir: Direction) -> bool:
	"""检查是否能形成环路"""
	var target_pos = pos + get_direction_vector(dir)
	
	# 简单检查：看目标位置周围是否有其他房间
	var room_neighbors = 0
	for check_dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
		var check_pos = target_pos + get_direction_vector(check_dir)
		if is_room_at(check_pos) and check_pos != pos:
			room_neighbors += 1
	
	return room_neighbors >= 2

func add_random_rooms_nearby(existing_rooms: Array, count: int):
	"""在现有房间附近随机添加房间"""
	if count <= 0:
		return
		
	var candidates = []
	
	# 收集所有可能的位置
	for room_pos in existing_rooms:
		for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
			var candidate_pos = room_pos + get_direction_vector(dir)
			if is_valid_position(candidate_pos) and not is_room_at(candidate_pos):
				if candidate_pos not in candidates:
					candidates.append(candidate_pos)
	
	candidates.shuffle()
	
	var added = 0
	for pos in candidates:
		if added >= count or rooms.size() >= TARGET_ROOMS:
			break
		if place_room(pos):
			added += 1
			
	# 如果还是不够，尝试更激进的扩展
	if rooms.size() < TARGET_ROOMS:
		var remaining = TARGET_ROOMS - rooms.size()
		var attempts = 0
		while remaining > 0 and attempts < 20:
			attempts += 1
			# 从现有房间中随机选择一个
			if rooms.is_empty():
				break
			var base = rooms[rng.randi() % rooms.size()]
			# 尝试在其周围找空位
			for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
				var new_pos = base + get_direction_vector(dir)
				if is_valid_position(new_pos) and not is_room_at(new_pos):
					if place_room(new_pos):
						remaining -= 1
						if remaining <= 0:
							break

func generate_cluster_centers() -> Array:
	"""生成集群中心点"""
	var centers = []
	var cluster_count = max(1, TARGET_ROOMS / 8)
	
	for i in range(cluster_count):
		var center = Vector2i(
			rng.randi_range(2, GRID_SIZE - 1),
			rng.randi_range(2, GRID_SIZE - 1)
		)
		centers.append(center)
	
	return centers

func expand_cluster(center: Vector2i, size: int):
	"""扩展集群"""
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

func generate_random_path(start: Vector2i, length: int) -> Array:
	"""生成随机路径"""
	var path = []
	var current = start
	var directions = [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]
	
	for i in range(length):
		directions.shuffle()
		var moved = false
		
		for dir in directions:
			var next_pos = current + get_direction_vector(dir)
			if is_valid_position(next_pos) and next_pos not in path and not is_room_at(next_pos):
				path.append(next_pos)
				current = next_pos
				moved = true
				break
		
		if not moved:
			break
	
	return path

func find_valid_start_position() -> Vector2i:
	"""寻找有效的起始位置"""
	var candidates = []
	var center = Vector2i(GRID_SIZE / 2 + 1, GRID_SIZE / 2 + 1)
	
	# 优先尝试中心附近的位置
	for radius in range(0, 3):
		for x in range(max(1, center.x - radius), min(GRID_SIZE + 1, center.x + radius + 1)):
			for y in range(max(1, center.y - radius), min(GRID_SIZE + 1, center.y + radius + 1)):
				var pos = Vector2i(x, y)
				if is_valid_position(pos):
					candidates.append(pos)
		
		if not candidates.is_empty():
			break
	
	if candidates.is_empty():
		return Vector2i(-1, -1)
	
	candidates.shuffle()
	return candidates[0]

func add_random_seed_rooms():
	"""添加随机种子房间来打破停滞"""
	var attempts = 5
	while attempts > 0 and rooms.size() < TARGET_ROOMS:
		attempts -= 1
		var pos = Vector2i(rng.randi_range(1, GRID_SIZE), rng.randi_range(1, GRID_SIZE))
		if place_room(pos):
			print("添加种子房间: %s" % str(pos))

func supplement_rooms():
	"""补充房间到最小数量"""
	var min_rooms = max(3, TARGET_ROOMS / 3)
	var attempts = 0
	var max_attempts = 50
	
	while rooms.size() < min_rooms and attempts < max_attempts:
		attempts += 1
		
		# 尝试在现有房间附近放置
		if not rooms.is_empty():
			var base_room = rooms[rng.randi() % rooms.size()]
			var dirs = [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]
			dirs.shuffle()
			
			for dir in dirs:
				var new_pos = base_room + get_direction_vector(dir)
				if place_room(new_pos):
					break
		else:
			# 如果没有房间，随机放置
			var pos = Vector2i(rng.randi_range(1, GRID_SIZE), rng.randi_range(1, GRID_SIZE))
			place_room(pos)

func get_direction_vector(dir: Direction) -> Vector2i:
	"""获取方向向量"""
	match dir:
		Direction.LEFT: return Vector2i(-1, 0)
		Direction.RIGHT: return Vector2i(1, 0)
		Direction.TOP: return Vector2i(0, -1)
		Direction.BOTTOM: return Vector2i(0, 1)
		_: return Vector2i.ZERO

func get_opposite_direction(dir: Direction) -> Direction:
	"""获取相反方向"""
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.TOP: return Direction.BOTTOM
		Direction.BOTTOM: return Direction.TOP
		_: return Direction.LEFT

func get_perpendicular_directions(dir: Direction) -> Array:
	"""获取垂直方向"""
	match dir:
		Direction.LEFT, Direction.RIGHT:
			return [Direction.TOP, Direction.BOTTOM]
		Direction.TOP, Direction.BOTTOM:
			return [Direction.LEFT, Direction.RIGHT]
		_:
			return []

func is_valid_position(pos: Vector2i) -> bool:
	"""检查位置是否有效"""
	return pos.x >= 1 and pos.x <= GRID_SIZE and pos.y >= 1 and pos.y <= GRID_SIZE

func is_room_at(pos: Vector2i) -> bool:
	"""检查指定位置是否有房间"""
	var cell = grid.get(pos) as RoomCell
	return cell and cell.is_room

func get_empty_neighbors(pos: Vector2i) -> Array:
	"""获取空邻居方向"""
	var empty_dirs = []
	
	for dir in [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]:
		var neighbor_pos = pos + get_direction_vector(dir)
		if is_valid_position(neighbor_pos) and not is_room_at(neighbor_pos):
			empty_dirs.append(dir)
	
	return empty_dirs

func count_empty_neighbors(pos: Vector2i) -> int:
	"""计算空邻居数量"""
	return get_empty_neighbors(pos).size()

func weighted_random_choice(weights: Array) -> int:
	"""根据权重进行随机选择"""
	if weights.is_empty():
		return 0
	
	var total_weight = 0.0
	for w in weights:
		total_weight += w
	
	if total_weight <= 0:
		return rng.randi() % weights.size()
	
	var rand_value = rng.randf() * total_weight
	var current_sum = 0.0
	
	for i in range(weights.size()):
		current_sum += weights[i]
		if rand_value <= current_sum:
			return i
	
	return weights.size() - 1

# ============== 调试和测试函数 ==============
func print_grid_debug():
	"""打印网格调试信息"""
	print("=== 网格状态 ===")
	for y in range(1, GRID_SIZE + 1):
		var row = ""
		for x in range(1, GRID_SIZE + 1):
			var pos = Vector2i(x, y)
			var cell = grid[pos] as RoomCell
			if cell.is_room:
				row += "R "
			else:
				row += ". "
		print(row)

func validate_generation() -> bool:
	"""验证生成结果的正确性"""
	var errors = []
	
	# 检查基本约束
	if rooms.is_empty():
		errors.append("没有生成任何房间")
	
	# 检查连通性
	if rooms.size() > 1:
		var reachable = get_all_reachable_rooms(rooms[0])
		if reachable.size() != rooms.size():
			errors.append("存在不连通房间")
	
	# 检查房间连接的有效性
	for room_pos in rooms:
		var cell = grid[room_pos] as RoomCell
		for dir in cell.connections:
			var neighbor_pos = room_pos + get_direction_vector(dir)
			if not is_room_at(neighbor_pos):
				errors.append("房间 %s 有连接到虚空的开口" % str(room_pos))
	
	if not errors.is_empty():
		print("❌ 验证失败:")
		for error in errors:
			print("  - %s" % error)
		return false
	
	print("✅ 验证通过")
	return true
