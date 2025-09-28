# level_manager_example.gd
# 展示如何使用增强版关卡生成器的示例
extends Node

# ============== 基础使用示例 ==============

func example_basic_usage():
	"""基础使用 - 生成关卡并获取数据"""
	
	# 生成关卡
	var level_data = NormalLevelGenerator.generate(
		5,      # grid_size
		8,      # target_rooms
		0.5,    # connection_rate
		true,   # enable_partitions
		0.5,    # complexity_bias
		-1,     # random_seed (-1为随机)
		true    # debug_mode
	)
	
	# 添加关卡节点到场景
	add_child(level_data.level_node)
	
	# 获取基础信息
	print("生成了 %d 个房间" % level_data.room_count)
	print("初始房间位置: ", level_data.initial_room_pos)
	
	# 获取统计信息
	var stats = level_data.get_statistics()
	print("关卡统计:")
	print("  - 总房间数: ", stats.total_rooms)
	print("  - 总连接数: ", stats.total_connections)
	print("  - 死胡同数: ", stats.dead_ends)
	print("  - 中枢房间数: ", stats.hub_rooms)
	print("  - 最大距离: ", stats.max_distance)
	print("  - 布局类型: ", stats.layout_type)

# ============== 寻找特殊房间 ==============

func example_find_special_rooms():
	"""寻找特殊房间的示例"""
	
	var level_data = NormalLevelGenerator.generate()
	add_child(level_data.level_node)
	
	# 1. 找到最远的房间（适合放置Boss）
	var farthest_room = level_data.get_farthest_room()
	if farthest_room:
		print("最远房间位置: ", farthest_room.grid_pos)
		print("距离起点: ", farthest_room.distance_from_start)
		
		# 在最远房间放置Boss
		spawn_boss(farthest_room.node_instance)
	
	# 2. 找到所有死胡同（适合放置宝藏）
	var dead_ends = level_data.get_dead_ends()
	print("找到 %d 个死胡同房间" % dead_ends.size())
	for room in dead_ends:
		# 在死胡同放置宝藏
		spawn_treasure(room.node_instance)
	
	# 3. 找到中枢房间（适合放置商店或休息点）
	var hubs = level_data.get_hub_rooms()
	print("找到 %d 个中枢房间" % hubs.size())
	for room in hubs:
		if room.grid_pos != level_data.initial_room_pos:  # 不在起始房间
			spawn_shop(room.node_instance)
			break  # 只放置一个商店

# ============== 路径查找示例 ==============

func example_pathfinding():
	"""路径查找功能示例"""
	
	var level_data = NormalLevelGenerator.generate()
	add_child(level_data.level_node)
	
	# 查找从起始房间到最远房间的路径
	var start = level_data.initial_room_pos
	var farthest = level_data.get_farthest_room()
	
	if farthest:
		var path = level_data.find_path(start, farthest.grid_pos)
		print("从起点到最远房间的路径:")
		for i in range(path.size()):
			var room_pos = path[i]
			var room_info = level_data.room_grid[room_pos]
			print("  步骤 %d: %s (类型: %s)" % [i, room_pos, room_info.room_type])
		
		# 在路径上放置引导元素
		for pos in path:
			var room = level_data.room_grid[pos]
			if room and room.node_instance:
				add_breadcrumb(room.node_instance)

# ============== 渐进式解锁示例 ==============

func example_progressive_unlock():
	"""基于距离的渐进式解锁"""
	
	var level_data = NormalLevelGenerator.generate()
	add_child(level_data.level_node)
	
	# 按距离分组房间
	var max_distance = level_data.get_farthest_room().distance_from_start
	
	for distance in range(max_distance + 1):
		var rooms_at_distance = level_data.get_rooms_at_distance(distance)
		print("距离 %d 的房间数: %d" % [distance, rooms_at_distance.size()])
		
		# 为不同距离的房间设置不同难度
		for room in rooms_at_distance:
			set_room_difficulty(room.node_instance, distance)
			
			# 设置房间锁定状态
			if distance > 0:
				lock_room(room.node_instance)

# ============== 可视化布局示例 ==============

func example_visualize_layout():
	"""可视化关卡布局"""
	
	var level_data = NormalLevelGenerator.generate()
	add_child(level_data.level_node)
	
	# 导出布局网格
	var layout_grid = level_data.export_layout_grid()
	
	print("\n关卡布局可视化:")
	for row in layout_grid:
		var line = ""
		for cell in row:
			if cell.exists:
				if cell.is_start:
					line += "[S]"  # 起始房间
				elif cell.distance == level_data.get_farthest_room().distance_from_start:
					line += "[E]"  # 最远房间（终点）
				else:
					line += "[%d]" % cell.distance  # 显示距离
			else:
				line += "   "  # 空白
		print(line)
	
	# 创建小地图
	create_minimap(layout_grid, level_data)

# ============== 动态事件系统示例 ==============

func example_dynamic_events():
	"""根据房间特性触发动态事件"""
	
	var level_data = NormalLevelGenerator.generate()
	add_child(level_data.level_node)
	
	# 遍历所有房间设置事件
	for pos in level_data.room_grid:
		var room = level_data.room_grid[pos]
		
		# 根据房间特性决定事件类型
		if room.is_dead_end and room.distance_from_start > 2:
			# 死胡同且距离较远 - 隐藏房间
			setup_secret_room(room)
			
		elif room.is_hub:
			# 中枢房间 - 战斗挑战
			setup_arena_room(room)
			
		elif room.connections.size() == 2:
			# 通道房间 - 陷阱或谜题
			if randf() > 0.5:
				setup_trap_room(room)
			else:
				setup_puzzle_room(room)

# ============== 保存和加载示例 ==============

func example_save_load_level():
	"""保存和加载关卡数据"""
	
	# 生成关卡
	var level_data = NormalLevelGenerator.generate(5, 8, 0.5, true, 0.5, 12345)
	
	# 保存关卡数据
	var save_data = {
		"seed": 12345,
		"room_count": level_data.room_count,
		"initial_room": var_to_str(level_data.initial_room_pos),
		"rooms": [],
		"connections": []
	}
	
	# 保存房间信息
	for pos in level_data.room_grid:
		var room = level_data.room_grid[pos]
		save_data.rooms.append({
			"pos": var_to_str(pos),
			"type": room.room_type,
			"distance": room.distance_from_start
		})
	
	# 保存连接信息
	for conn in level_data.connections:
		save_data.connections.append({
			"from": var_to_str(conn.room1_pos),
			"to": var_to_str(conn.room2_pos),
			"direction": conn.direction
		})
	
	# 写入文件
	var file = FileAccess.open("user://level_save.dat", FileAccess.WRITE)
	file.store_var(save_data)
	file.close()
	
	print("关卡已保存")

# ============== 关卡分析工具 ==============

func example_level_analysis():
	"""分析生成的关卡质量"""
	
	var level_data = NormalLevelGenerator.generate()
	
	# 计算关卡复杂度评分
	var complexity_score = calculate_complexity_score(level_data)
	print("关卡复杂度评分: %.2f" % complexity_score)
	
	# 检查关卡平衡性
	var balance = check_level_balance(level_data)
	print("关卡平衡性:")
	print("  - 线性度: %.2f" % balance.linearity)
	print("  - 分支度: %.2f" % balance.branching)
	print("  - 回路数: %d" % balance.loops)
	
	# 推荐游戏时长
	var estimated_time = estimate_play_time(level_data)
	print("预计游戏时长: %d 分钟" % estimated_time)

func calculate_complexity_score(level_data: NormalLevelGenerator.LevelData) -> float:
	"""计算关卡复杂度"""
	var score = 0.0
	
	# 基于房间数量
	score += level_data.room_count * 0.5
	
	# 基于连接数量
	var stats = level_data.get_statistics()
	score += stats.total_connections * 0.3
	
	# 基于最大距离
	score += stats.max_distance * 0.8
	
	# 基于中枢房间
	score += stats.hub_rooms * 1.2
	
	# 基于布局类型
	match stats.layout_type:
		"linear":
			score *= 0.7
		"interconnected":
			score *= 1.3
		"hub_based":
			score *= 1.1
	
	return score

func check_level_balance(level_data: NormalLevelGenerator.LevelData) -> Dictionary:
	"""检查关卡平衡性"""
	var result = {
		"linearity": 0.0,
		"branching": 0.0,
		"loops": 0
	}
	
	var stats = level_data.get_statistics()
	
	# 计算线性度（死胡同比例）
	result.linearity = float(stats.dead_ends) / max(1, stats.total_rooms)
	
	# 计算分支度（平均连接数）
	result.branching = stats.average_connections / 4.0
	
	# 计算回路数（额外连接数）
	var min_connections = stats.total_rooms - 1  # 最小生成树
	result.loops = stats.total_connections - min_connections
	
	return result

func estimate_play_time(level_data: NormalLevelGenerator.LevelData) -> int:
	"""估算游戏时长（分钟）"""
	var base_time = 2  # 每个房间基础时间
	var total_time = level_data.room_count * base_time
	
	# 根据复杂度调整
	var stats = level_data.get_statistics()
	if stats.layout_type == "interconnected":
		total_time *= 1.2  # 高互联性增加探索时间
	elif stats.layout_type == "linear":
		total_time *= 0.9  # 线性布局减少时间
	
	# 死胡同增加时间（需要回头）
	total_time += stats.dead_ends * 0.5
	
	return int(total_time)

# ============== 辅助函数（需要根据实际项目实现）==============

func spawn_boss(room_node: Node2D):
	pass

func spawn_treasure(room_node: Node2D):
	pass

func spawn_shop(room_node: Node2D):
	pass

func add_breadcrumb(room_node: Node2D):
	pass

func set_room_difficulty(room_node: Node2D, difficulty: int):
	pass

func lock_room(room_node: Node2D):
	pass

func create_minimap(layout_grid: Array, level_data: NormalLevelGenerator.LevelData):
	pass

func setup_secret_room(room_info):
	pass

func setup_arena_room(room_info):
	pass

func setup_trap_room(room_info):
	pass

func setup_puzzle_room(room_info):
	pass
