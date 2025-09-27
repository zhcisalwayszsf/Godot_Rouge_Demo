# 2D Roguelike 完整关卡生成器（含边界限定与单口控制）
extends Node2D

# ============== 阶段零：参数与网格定义 ==============
const GRID_SIZE = 5
const ROOM_WIDTH = 1728
const ROOM_HEIGHT = 1088

# 生成参数
@export var MaxRooms: int = 10           # 目标房间总数
@export var MaxDeadEnds: int = 6         # 允许的单开口房间最大数量（增加）
@export var PBlock: float = 0.22         # 随机隔断率（降低到15%）
@export var UsePartition: bool = true    # 是否启用隔断
@export var MinConnections: int = 1      # 每个房间最少连接数

# 方向定义
enum Direction { LEFT = 0, RIGHT = 1, TOP = 2, BOTTOM = 3 }

# 房间模板
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

# 网格数据结构
class GridCell:
	var used: bool = false
	var required_ports: Array = []
	var blocked_connections: Array = []  # 封锁连接标记
	var scene_instance: Node2D = null
	var is_dead_end: bool = false

# 全局状态
var Grid = {}  # {Vector2i(x,y): GridCell}
var RoomsCount = 0
var DeadEndsCount = 0
var PendingQueue = []  # BFS队列
var initial_room_pos: Vector2i

func _ready():
	generate_complete_level()

func _input(event):
	if event.is_action_pressed("ui_accept"):  # 空格键重新生成
		generate_complete_level()

# ============== 主生成函数 ==============
func generate_complete_level():
	"""完整关卡生成流程"""
	print("=== 开始生成关卡 ===")
	
	# 阶段零：初始化
	stage_zero_initialize()
	
	# 阶段一：路径探索与结构锁定
	if not stage_one_skeleton_generation():
		print("阶段一失败：无法生成足够的房间骨架")
		return
	
	# 阶段二：拓扑确定与隔断修剪
	stage_two_topology_and_partition()
	
	# 阶段三：连通性复检与最终裁剪
	stage_three_connectivity_check()
	
	# 阶段四：几何落实与实例化
	stage_four_instantiation()
	
	print("=== 关卡生成完成 ===")
	print("最终房间数：", get_used_rooms_count())
	print("死胡同数：", DeadEndsCount)

# ============== 阶段零：初始化 ==============
func stage_zero_initialize():
	"""初始化网格和参数"""
	clear_level()
	Grid.clear()
	RoomsCount = 0
	DeadEndsCount = 0
	PendingQueue.clear()
	
	# 初始化5x5网格
	for x in range(1, GRID_SIZE + 1):
		for y in range(1, GRID_SIZE + 1):
			Grid[Vector2i(x, y)] = GridCell.new()

# ============== 阶段一：路径探索与结构锁定 ==============
func stage_one_skeleton_generation() -> bool:
	"""生成关卡骨架"""
	print("阶段一：开始骨架生成")
	
	# 1. 初始房间
	initial_room_pos = Vector2i(randi_range(2, 4), randi_range(2, 4))  # 避开边界
	Grid[initial_room_pos].used = true
	RoomsCount = 1
	
	# 将初始房间的合法邻居加入队列
	add_legal_neighbors_to_queue(initial_room_pos)
	
	# 2. 循环扩展 - 改进的扩展策略
	var max_attempts = MaxRooms * 10  # 增加尝试次数
	var attempts = 0
	var failed_expansions = 0
	var max_failed = MaxRooms * 2  # 允许的失败次数
	
	while PendingQueue.size() > 0 and RoomsCount < MaxRooms and attempts < max_attempts and failed_expansions < max_failed:
		attempts += 1
		
		# 优先选择队列前部的候选位置（BFS特性）
		var current_pos = PendingQueue.pop_front()
		
		if not Grid[current_pos].used and RoomsCount < MaxRooms:
			if try_expand_room(current_pos):
				failed_expansions = 0  # 重置失败计数
				print("成功扩展房间 ", current_pos, "，当前总数：", RoomsCount)
				
				# 如果接近目标，加速处理
				if MaxRooms - RoomsCount <= 3:
					# 优先处理最有潜力的位置
					PendingQueue.sort_custom(func(a, b): 
						return get_expansion_potential(a) > get_expansion_potential(b)
					)
			else:
				failed_expansions += 1
				print("扩展失败：", current_pos, "，失败次数：", failed_expansions)
				
				# 如果连续失败太多，尝试重新添加一些位置
				if failed_expansions > 5 and PendingQueue.size() < 3:
					add_more_candidates()
	
	print("骨架生成结束 - 尝试次数：", attempts, "，最终房间数：", RoomsCount, "，死胡同数：", DeadEndsCount)
	
	# 如果房间数不足，尝试补救措施
	if RoomsCount < min(MaxRooms, 3):
		print("房间数不足，尝试补救...")
		return attempt_rescue_generation()
	
	return true

func try_expand_room(pos: Vector2i) -> bool:
	"""尝试在指定位置扩展房间"""
	# a. 分支需求判断
	var available_directions = get_legal_neighbors(pos)
	
	if available_directions.is_empty():
		return false
	
	# 计算剩余房间数和死胡同配额
	var remaining_rooms = MaxRooms - RoomsCount
	var remaining_deadends = MaxDeadEnds - DeadEndsCount
	
	# b. 出口数量选择 - 改进的策略
	var min_ports = 1
	var max_ports = min(available_directions.size(), 4)
	
	# 动态调整最小出口数
	if remaining_rooms > remaining_deadends:
		# 如果剩余房间多于死胡同配额，优先多分支
		if remaining_rooms > (remaining_deadends + 2):
			min_ports = 2  # 强制分支
		else:
			min_ports = 1  # 允许但不强制死胡同
	
	# 智能出口数选择
	var num_ports = 0
	if remaining_rooms <= 2:
		# 接近目标时，倾向于少分支
		num_ports = min(max_ports, 2)
	elif RoomsCount < MaxRooms / 2:
		# 前半段，倾向于多分支扩展
		var weights = []
		for i in range(min_ports, max_ports + 1):
			if i == 1:
				weights.append(1)  # 死胡同权重
			elif i == 2:
				weights.append(4)  # 双分支权重高
			else:
				weights.append(2)  # 多分支适中权重
		num_ports = weighted_random_choice(weights) + min_ports
	else:
		# 后半段，平衡选择
		num_ports = randi_range(min_ports, max_ports)
	
	# 死胡同检查和处理
	if num_ports == 1:
		if DeadEndsCount >= MaxDeadEnds:
			# 死胡同已满，强制增加出口
			if available_directions.size() >= 2:
				num_ports = 2
				print("死胡同配额已满，强制扩展为双出口")
			else:
				print("无法满足死胡同限制，跳过房间：", pos)
				return false
		else:
			Grid[pos].is_dead_end = true
			DeadEndsCount += 1
	
	# 确保不超过可用方向数
	num_ports = min(num_ports, available_directions.size())
	
	# 智能选择出口方向
	var selected_ports = select_optimal_directions(pos, available_directions, num_ports)
	
	if selected_ports.is_empty():
		return false
	
	# c. 执行生成
	Grid[pos].used = true
	RoomsCount += 1
	
	# 将选中的新出口对应的邻居加入队列（去重并优先级排序）
	var new_neighbors = []
	for direction in selected_ports:
		var neighbor_pos = pos + get_direction_offset(direction)
		if is_valid_position(neighbor_pos) and not Grid[neighbor_pos].used:
			if neighbor_pos not in PendingQueue and neighbor_pos not in new_neighbors:
				new_neighbors.append(neighbor_pos)
	
	# 按距离中心的远近排序（中心扩散策略）
	new_neighbors.sort_custom(func(a, b): return get_distance_to_center(a) < get_distance_to_center(b))
	
	for neighbor in new_neighbors:
		PendingQueue.append(neighbor)
	
	print("在位置 ", pos, " 生成房间，出口数：", num_ports, "，剩余目标：", MaxRooms - RoomsCount)
	return true

func get_legal_neighbors(pos: Vector2i) -> Array:
	"""获取合法的邻居方向（满足边界规则）"""
	var legal = []
	
	# 检查每个方向
	if pos.x > 1:  # 不在左边界
		var left_pos = pos + Vector2i(-1, 0)
		if not Grid[left_pos].used:
			legal.append(Direction.LEFT)
	
	if pos.x < GRID_SIZE:  # 不在右边界
		var right_pos = pos + Vector2i(1, 0)
		if not Grid[right_pos].used:
			legal.append(Direction.RIGHT)
	
	if pos.y > 1:  # 不在上边界
		var top_pos = pos + Vector2i(0, -1)
		if not Grid[top_pos].used:
			legal.append(Direction.TOP)
	
	if pos.y < GRID_SIZE:  # 不在下边界
		var bottom_pos = pos + Vector2i(0, 1)
		if not Grid[bottom_pos].used:
			legal.append(Direction.BOTTOM)
	
	return legal

func add_legal_neighbors_to_queue(pos: Vector2i):
	"""将合法邻居加入待处理队列"""
	var legal_neighbors = get_legal_neighbors(pos)
	for direction in legal_neighbors:
		var neighbor_pos = pos + get_direction_offset(direction)
		if neighbor_pos not in PendingQueue:
			PendingQueue.append(neighbor_pos)

# ============== 阶段二：拓扑确定与隔断修剪 ==============
func stage_two_topology_and_partition():
	"""确定拓扑结构并应用隔断"""
	print("阶段二：拓扑确定与隔断修剪")
	
	# 第一遍：建立基础连通性
	establish_base_connectivity()
	
	# 第二遍：选择性应用隔断
	apply_selective_partitions()

func establish_base_connectivity():
	"""建立基础连通性（确保核心连通）"""
	for pos in Grid.keys():
		if not Grid[pos].used:
			continue
		
		var cell = Grid[pos]
		
		# 只检查右方（R）和下方（B）的邻居，避免重复处理
		var check_directions = [
			[Direction.RIGHT, Vector2i(1, 0)],
			[Direction.BOTTOM, Vector2i(0, 1)]
		]
		
		for dir_data in check_directions:
			var direction = dir_data[0]
			var offset = dir_data[1]
			var neighbor_pos = pos + offset
			
			if is_valid_position(neighbor_pos) and Grid[neighbor_pos].used:
				var neighbor_cell = Grid[neighbor_pos]
				
				# 建立基础连接（暂不考虑隔断）
				if direction not in cell.required_ports:
					cell.required_ports.append(direction)
				
				var opposite_dir = get_opposite_direction(direction)
				if opposite_dir not in neighbor_cell.required_ports:
					neighbor_cell.required_ports.append(opposite_dir)

func apply_selective_partitions():
	"""选择性应用隔断（避免创建孤立区域）"""
	if not UsePartition:
		return
	
	var partition_candidates = []
	
	# 收集可能的隔断候选
	for pos in Grid.keys():
		if not Grid[pos].used:
			continue
		
		var cell = Grid[pos]
		
		# 检查右方和下方连接
		var check_directions = [
			[Direction.RIGHT, Vector2i(1, 0)],
			[Direction.BOTTOM, Vector2i(0, 1)]
		]
		
		for dir_data in check_directions:
			var direction = dir_data[0]
			var offset = dir_data[1]
			var neighbor_pos = pos + offset
			
			if is_valid_position(neighbor_pos) and Grid[neighbor_pos].used:
				# 评估隔断的安全性
				if is_partition_safe(pos, neighbor_pos, direction):
					partition_candidates.append([pos, neighbor_pos, direction])
	
	print("找到 ", partition_candidates.size(), " 个安全隔断候选")
	
	# 逐个应用隔断，每次都重新验证安全性
	partition_candidates.shuffle()
	var applied_partitions = 0
	var max_partitions = max(1, int(get_used_rooms_count() * PBlock * 0.5))  # 更保守的隔断数量
	
	for candidate in partition_candidates:
		if applied_partitions >= max_partitions:
			break
		
		var pos1 = candidate[0]
		var pos2 = candidate[1]
		var direction = candidate[2]
		
		# 再次检查安全性（因为之前的隔断可能影响了连通性）
		if is_partition_safe(pos1, pos2, direction):
			apply_partition(pos1, pos2, direction)
			applied_partitions += 1
			print("应用隔断 ", applied_partitions, "/", max_partitions)
		else:
			print("跳过不安全的隔断：", pos1, " - ", pos2)
	
	print("总共应用了 ", applied_partitions, " 个隔断")

func is_partition_safe(pos1: Vector2i, pos2: Vector2i, direction: Direction) -> bool:
	"""检查隔断是否安全（不会创建孤立区域）"""
	# 1. 基本检查：确保两个房间都有其他连接
	var cell1 = Grid[pos1]
	var cell2 = Grid[pos2]
	
	var cell1_other_connections = count_other_connections(pos1, direction)
	var cell2_other_connections = count_other_connections(pos2, get_opposite_direction(direction))
	
	# 如果任一房间隔断后会变成孤立，则不安全
	if cell1_other_connections < 1 or cell2_other_connections < 1:
		return false
	
	# 2. 死胡同保护：如果是死胡同房间，不应该被隔断
	if cell1.is_dead_end or cell2.is_dead_end:
		return false
	
	# 3. 关键检查：模拟隔断，测试全局连通性
	return test_connectivity_after_partition(pos1, pos2, direction)

func test_connectivity_after_partition(pos1: Vector2i, pos2: Vector2i, direction: Direction) -> bool:
	"""模拟隔断后测试全局连通性"""
	# 临时移除这条连接
	var cell1 = Grid[pos1]
	var cell2 = Grid[pos2]
	var opposite_dir = get_opposite_direction(direction)
	
	# 创建临时连接状态（模拟移除连接）
	var temp_connections = {}
	for pos in Grid.keys():
		if Grid[pos].used:
			temp_connections[pos] = []
			var cell = Grid[pos]
			
			# 添加所有当前连接，除了要被隔断的那条
			var all_directions = [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]
			for dir in all_directions:
				var neighbor_pos = pos + get_direction_offset(dir)
				if is_valid_position(neighbor_pos) and Grid[neighbor_pos].used:
					# 跳过要被隔断的连接
					if (pos == pos1 and neighbor_pos == pos2 and dir == direction) or \
					   (pos == pos2 and neighbor_pos == pos1 and dir == opposite_dir):
						continue
					temp_connections[pos].append(dir)
	
	# 使用BFS检查连通性
	var all_used_rooms = []
	for pos in Grid.keys():
		if Grid[pos].used:
			all_used_rooms.append(pos)
	
	if all_used_rooms.is_empty():
		return true
	
	# 从第一个房间开始BFS
	var start_pos = all_used_rooms[0]
	var visited = {}
	var queue = [start_pos]
	var reachable_count = 0
	
	while queue.size() > 0:
		var current_pos = queue.pop_front()
		if current_pos in visited:
			continue
		
		visited[current_pos] = true
		reachable_count += 1
		
		# 遍历当前房间的所有连接
		if current_pos in temp_connections:
			for dir in temp_connections[current_pos]:
				var neighbor_pos = current_pos + get_direction_offset(dir)
				if neighbor_pos not in visited and neighbor_pos not in queue:
					queue.append(neighbor_pos)
	
	# 如果所有房间都能到达，则隔断安全
	var is_safe = reachable_count == all_used_rooms.size()
	
	if not is_safe:
		print("隔断 ", pos1, "-", pos2, " 不安全：会导致连通性问题 (", reachable_count, "/", all_used_rooms.size(), ")")
	
	return is_safe

func count_other_connections(pos: Vector2i, exclude_direction: Direction) -> int:
	"""计算除指定方向外的其他连接数"""
	var count = 0
	var all_directions = [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]
	
	for dir in all_directions:
		if dir == exclude_direction:
			continue
		
		var neighbor_pos = pos + get_direction_offset(dir)
		if is_valid_position(neighbor_pos) and Grid[neighbor_pos].used:
			count += 1
	
	return count

func apply_partition(pos1: Vector2i, pos2: Vector2i, direction: Direction):
	"""应用隔断"""
	var cell1 = Grid[pos1]
	var cell2 = Grid[pos2]
	var opposite_dir = get_opposite_direction(direction)
	
	# 移除正常连接
	cell1.required_ports.erase(direction)
	cell2.required_ports.erase(opposite_dir)
	
	# 添加封锁连接标记
	cell1.blocked_connections.append(direction)
	cell2.blocked_connections.append(opposite_dir)
	
	print("在 ", pos1, " 和 ", pos2, " 之间创建安全隔断")

# ============== 阶段三：连通性复检与最终裁剪 ==============
func stage_three_connectivity_check():
	"""检查连通性并裁剪孤立房间"""
	print("阶段三：连通性检查")
	
	# 1. 从初始房间开始进行连通性检查
	var reachable_rooms = get_reachable_rooms(initial_room_pos)
	var total_used_rooms = get_used_rooms_count()
	
	print("连通性检查：", reachable_rooms.size(), "/", total_used_rooms, " 个房间可达")
	
	# 2. 如果有房间不可达，尝试修复连通性
	if reachable_rooms.size() < total_used_rooms:
		print("发现不可达房间，尝试修复连通性...")
		repair_connectivity(reachable_rooms)
		
		# 重新检查连通性
		reachable_rooms = get_reachable_rooms(initial_room_pos)
		print("修复后连通性：", reachable_rooms.size(), "/", get_used_rooms_count(), " 个房间可达")
	
	# 3. 裁剪仍然孤立的房间
	var isolated_count = 0
	for pos in Grid.keys():
		if Grid[pos].used and pos not in reachable_rooms:
			Grid[pos].used = false
			Grid[pos].required_ports.clear()
			Grid[pos].blocked_connections.clear()
			isolated_count += 1
			print("裁剪孤立房间：", pos)
	
	if isolated_count > 0:
		print("裁剪了 ", isolated_count, " 个孤立房间")
	else:
		print("所有房间保持连通")

func repair_connectivity(reachable_rooms: Array):
	"""修复连通性，连接孤立的房间"""
	var isolated_rooms = []
	
	# 找出所有孤立的房间
	for pos in Grid.keys():
		if Grid[pos].used and pos not in reachable_rooms:
			isolated_rooms.append(pos)
	
	# 为每个孤立房间寻找最近的可达房间并建立连接
	for isolated_pos in isolated_rooms:
		var nearest_reachable = find_nearest_reachable_room(isolated_pos, reachable_rooms)
		if nearest_reachable != Vector2i(-1, -1):
			create_emergency_bridge(isolated_pos, nearest_reachable)
			print("为孤立房间 ", isolated_pos, " 建立紧急连接到 ", nearest_reachable)

func find_nearest_reachable_room(isolated_pos: Vector2i, reachable_rooms: Array) -> Vector2i:
	"""寻找最近的可达房间"""
	var min_distance = 999
	var nearest_pos = Vector2i(-1, -1)
	
	for reachable_pos in reachable_rooms:
		# 检查是否相邻
		var distance = abs(isolated_pos.x - reachable_pos.x) + abs(isolated_pos.y - reachable_pos.y)
		if distance == 1:  # 直接相邻
			return reachable_pos
		elif distance < min_distance:
			min_distance = distance
			nearest_pos = reachable_pos
	
	return nearest_pos

func create_emergency_bridge(pos1: Vector2i, pos2: Vector2i):
	"""在两个房间之间创建紧急连接"""
	# 计算连接方向
	var offset = pos2 - pos1
	var direction1: Direction
	var direction2: Direction
	
	if abs(offset.x) == 1 and offset.y == 0:
		# 水平相邻
		if offset.x > 0:
			direction1 = Direction.RIGHT
			direction2 = Direction.LEFT
		else:
			direction1 = Direction.LEFT
			direction2 = Direction.RIGHT
	elif abs(offset.y) == 1 and offset.x == 0:
		# 垂直相邻
		if offset.y > 0:
			direction1 = Direction.BOTTOM
			direction2 = Direction.TOP
		else:
			direction1 = Direction.TOP
			direction2 = Direction.BOTTOM
	else:
		# 不直接相邻，无法简单连接
		return
	
	# 建立双向连接
	var cell1 = Grid[pos1]
	var cell2 = Grid[pos2]
	
	# 移除可能的封锁连接
	cell1.blocked_connections.erase(direction1)
	cell2.blocked_connections.erase(direction2)
	
	# 添加正常连接
	if direction1 not in cell1.required_ports:
		cell1.required_ports.append(direction1)
	if direction2 not in cell2.required_ports:
		cell2.required_ports.append(direction2)

func get_reachable_rooms(start_pos: Vector2i) -> Array:
	"""获取从起始位置可达的所有房间"""
	var visited = {}
	var queue = [start_pos]
	var reachable = []
	
	while queue.size() > 0:
		var current_pos = queue.pop_front()
		if current_pos in visited:
			continue
		
		visited[current_pos] = true
		reachable.append(current_pos)
		
		var cell = Grid[current_pos]
		
		# 沿着所有开放通道搜索
		for direction in cell.required_ports:
			var neighbor_pos = current_pos + get_direction_offset(direction)
			if is_valid_position(neighbor_pos) and Grid[neighbor_pos].used:
				if neighbor_pos not in visited and neighbor_pos not in queue:
					queue.append(neighbor_pos)
	
	return reachable

func is_completely_isolated(pos: Vector2i) -> bool:
	"""检查房间是否完全孤立（所有连接都是封锁连接）"""
	var cell = Grid[pos]
	
	# 如果有正常的开口，就不是完全孤立
	if cell.required_ports.size() > 0:
		return false
	
	# 如果有封锁连接，说明原本应该连通但被隔断
	return cell.blocked_connections.size() > 0

# ============== 阶段四：几何落实与实例化 ==============
func stage_four_instantiation():
	"""实例化房间到场景中"""
	print("阶段四：几何落实与实例化")
	
	clear_scene_instances()
	
	for pos in Grid.keys():
		var cell = Grid[pos]
		if not cell.used:
			continue
		
		# 确保每个房间至少有一个出口
		if cell.required_ports.is_empty() and not cell.is_dead_end:
			# 为孤立房间添加一个出口（连向最近的邻居）
			add_emergency_connection(pos)
		
		# 选择预制件
		var room_type = get_room_type_from_ports(cell.required_ports)
		if room_type.is_empty():
			print("警告：位置 ", pos, " 无法确定房间类型，使用默认")
			room_type = "R"  # 默认房间类型
		
		# 实例化房间
		if instantiate_room_at_position(pos, room_type):
			print("在 ", pos, " 实例化房间类型：", room_type, " 出口：", cell.required_ports.size())
		
		# 处理封锁连接（添加特殊标记）
		if cell.blocked_connections.size() > 0:
			print("位置 ", pos, " 有 ", cell.blocked_connections.size(), " 个封锁连接")
			# TODO: 在这里可以放置上锁的门或可破坏的墙
			handle_blocked_connections(pos, cell.blocked_connections)

func add_emergency_connection(pos: Vector2i):
	"""为孤立房间添加紧急连接"""
	var cell = Grid[pos]
	var directions = [Direction.LEFT, Direction.RIGHT, Direction.TOP, Direction.BOTTOM]
	
	# 寻找最近的已使用邻居
	for direction in directions:
		var neighbor_pos = pos + get_direction_offset(direction)
		if is_valid_position(neighbor_pos) and Grid[neighbor_pos].used:
			# 建立双向连接
			cell.required_ports.append(direction)
			var opposite_dir = get_opposite_direction(direction)
			var neighbor_cell = Grid[neighbor_pos]
			if opposite_dir not in neighbor_cell.required_ports:
				neighbor_cell.required_ports.append(opposite_dir)
			print("为孤立房间 ", pos, " 添加紧急连接到 ", neighbor_pos)
			break

func handle_blocked_connections(pos: Vector2i, blocked_dirs: Array):
	"""处理封锁连接（可扩展为特殊门/墙）"""
	# 当前只是记录，后续可以在这里：
	# 1. 放置上锁的门 (locked doors)
	# 2. 放置可破坏的墙 (breakable walls)  
	# 3. 放置需要钥匙的通道 (key-required passages)
	pass

func get_room_type_from_ports(ports: Array) -> String:
	"""根据开口数组生成房间类型字符串"""
	var type_str = ""
	if Direction.LEFT in ports: type_str += "L"
	if Direction.RIGHT in ports: type_str += "R"
	if Direction.TOP in ports: type_str += "T"
	if Direction.BOTTOM in ports: type_str += "B"
	
	# 如果没有开口，创建一个单开口房间（不应该发生）
	if type_str.is_empty():
		type_str = "R"  # 默认右出口
	
	return type_str

func instantiate_room_at_position(grid_pos: Vector2i, room_type: String) -> bool:
	"""在指定网格位置实例化房间"""
	if not room_templates.has(room_type):
		print("错误：未找到房间模板 ", room_type)
		return false
	
	var room_scene = load(room_templates[room_type])
	if not room_scene:
		print("错误：无法加载房间场景 ", room_templates[room_type])
		return false
	
	var room_instance = room_scene.instantiate()
	
	# 计算世界坐标（网格中心为(3,3)）
	var world_pos = Vector2(
		(grid_pos.x - 3) * ROOM_WIDTH,
		(grid_pos.y - 3) * ROOM_HEIGHT
	)
	
	room_instance.position = world_pos
	add_child(room_instance)
	
	Grid[grid_pos].scene_instance = room_instance
	return true

# ============== 新增辅助函数 ==============
func weighted_random_choice(weights: Array) -> int:
	"""根据权重数组进行随机选择"""
	var total = 0
	for weight in weights:
		total += weight
	
	var rand_val = randi() % total
	var current_sum = 0
	
	for i in range(weights.size()):
		current_sum += weights[i]
		if rand_val < current_sum:
			return i
	
	return weights.size() - 1

func select_optimal_directions(pos: Vector2i, available: Array, count: int) -> Array:
	"""智能选择最优的扩展方向"""
	if count >= available.size():
		return available
	
	# 计算每个方向的优先级
	var direction_scores = []
	for direction in available:
		var neighbor_pos = pos + get_direction_offset(direction)
		var score = 0
		
		# 1. 距离中心的分数（越靠近中心越好）
		var center_distance = get_distance_to_center(neighbor_pos)
		score += (5 - center_distance) * 10
		
		# 2. 周围空间的分数（周围空地越多越好）
		var surrounding_space = count_surrounding_empty_cells(neighbor_pos)
		score += surrounding_space * 5
		
		# 3. 避免聚集（如果附近已有房间，降低分数）
		var nearby_rooms = count_nearby_used_cells(neighbor_pos)
		score -= nearby_rooms * 3
		
		direction_scores.append([direction, score])
	
	# 按分数排序
	direction_scores.sort_custom(func(a, b): return a[1] > b[1])
	
	# 选择前count个
	var result = []
	for i in range(min(count, direction_scores.size())):
		result.append(direction_scores[i][0])
	
	return result

func get_distance_to_center(pos: Vector2i) -> int:
	"""计算到网格中心的距离"""
	var center = Vector2i(3, 3)  # 5x5网格的中心
	return abs(pos.x - center.x) + abs(pos.y - center.y)

func count_surrounding_empty_cells(pos: Vector2i) -> int:
	"""计算周围空白格子数量"""
	var count = 0
	var offsets = [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1),
				   Vector2i(-1,0),                    Vector2i(1,0),
				   Vector2i(-1,1),  Vector2i(0,1),   Vector2i(1,1)]
	
	for offset in offsets:
		var check_pos = pos + offset
		if is_valid_position(check_pos) and not Grid[check_pos].used:
			count += 1
	
	return count

func count_nearby_used_cells(pos: Vector2i) -> int:
	"""计算附近已使用格子数量"""
	var count = 0
	var offsets = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	
	for offset in offsets:
		var check_pos = pos + offset
		if is_valid_position(check_pos) and Grid[check_pos].used:
			count += 1
	
	return count

func get_expansion_potential(pos: Vector2i) -> int:
	"""计算位置的扩展潜力"""
	var legal_neighbors = get_legal_neighbors(pos)
	var surrounding_space = count_surrounding_empty_cells(pos)
	var center_bonus = 5 - get_distance_to_center(pos)
	
	return legal_neighbors.size() * 10 + surrounding_space * 2 + center_bonus

func add_more_candidates():
	"""当候选位置不足时，添加更多候选"""
	print("添加更多候选位置...")
	
	# 寻找所有已使用房间的邻居
	for pos in Grid.keys():
		if Grid[pos].used:
			var neighbors = get_legal_neighbors(pos)
			for direction in neighbors:
				var neighbor_pos = pos + get_direction_offset(direction)
				if neighbor_pos not in PendingQueue:
					PendingQueue.append(neighbor_pos)

func attempt_rescue_generation() -> bool:
	"""房间数不足时的补救措施"""
	print("执行补救生成...")
	
	# 暂时放宽死胡同限制
	var original_max_deadends = MaxDeadEnds
	MaxDeadEnds = min(MaxDeadEnds + 2, MaxRooms / 2)  # 增加死胡同配额
	
	# 重新填充队列
	PendingQueue.clear()
	for pos in Grid.keys():
		if Grid[pos].used:
			add_legal_neighbors_to_queue(pos)
	
	# 再次尝试扩展
	var rescue_attempts = 50
	while PendingQueue.size() > 0 and RoomsCount < MaxRooms and rescue_attempts > 0:
		rescue_attempts -= 1
		var current_pos = PendingQueue.pop_front()
		
		if not Grid[current_pos].used:
			if try_expand_room(current_pos):
				print("补救成功，新增房间：", current_pos)
	
	# 恢复原始设置
	MaxDeadEnds = original_max_deadends
	
	print("补救完成，最终房间数：", RoomsCount)
	return RoomsCount >= 3
func get_direction_offset(dir: Direction) -> Vector2i:
	"""获取方向对应的偏移量"""
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

func is_valid_position(pos: Vector2i) -> bool:
	"""检查位置是否在有效网格范围内"""
	return pos.x >= 1 and pos.x <= GRID_SIZE and pos.y >= 1 and pos.y <= GRID_SIZE

func get_used_rooms_count() -> int:
	"""获取已使用的房间数量"""
	var count = 0
	for cell in Grid.values():
		if cell.used:
			count += 1
	return count

func clear_level():
	"""清理关卡"""
	clear_scene_instances()

func clear_scene_instances():
	"""清理场景实例"""
	for cell in Grid.values():
		if cell.scene_instance:
			cell.scene_instance.queue_free()
			cell.scene_instance = null
