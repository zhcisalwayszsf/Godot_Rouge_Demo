#B类模板：积木拼接式内容生成 
extends Node2D

@export var DEBUG_MODE = true

# 主题枚举
enum Room_Theme {
	TEST,
	SPRING,   # 春原
	DESERT,   # 沙漠
	FOREST,   # 雨林
	DUNGEON,  # 地牢
	COAST     # 海岸
}

# 网格配置
const GRID_SIZE = 3  # 3x3 网格
# 新的房间尺寸：1526x896。CELL_SIZE = 1526/3 x 896/3
# 1526 / 3 ≈ 508.67
# 896 / 3 ≈ 298.67
const CELL_SIZE = Vector2(1480 / GRID_SIZE, 768/GRID_SIZE)  # 每个网格单元的尺寸 (适应 1526x896 房间)

# 导出参数
@export var current_theme: Room_Theme = Room_Theme.SPRING
@export var floor_level: int = 1
@export var room_type = null  # 从LevelManager传入的房间类型

# 运行时变量
var rng: RandomNumberGenerator
var entity_layer: Node2D
var block_config: Dictionary = {}
var decoration_config: Dictionary = {}
var selected_blocks: Array = []  # 当前生成中选中的块
var grid_positions: Array = []  # 3x3网格位置
# 新增 LevelManager 传入的生成参数
var max_blocks_limit: int = 9   # 最大块数限制
var spread_factor: float = 1.0  # 分散因子

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 初始化网格位置
	_initialize_grid_positions()
	
	 #如果在编辑器中测试，自动生成
	if DEBUG_MODE:
		populate(1, null)

func populate(level: int = 1, room_type_param = null, max_blocks: int = 9, spread: float = 1.0):
	"""主生成方法 - 被LevelManager调用"""
	floor_level = level
	room_type = room_type_param
	max_blocks_limit = max_blocks      # 接收最大块数
	spread_factor = clampf(spread, 0.0, 1.0) # 接收分散因子
	
	if DEBUG_MODE:
		print("[B类模板] 开始生成内容 - 主题: %s, 楼层: %d, MaxBlocks: %d, Spread: %.1f" % [
			_theme_to_string(), 
			floor_level,
			max_blocks_limit,
			spread_factor
		])
	
	# 获取EntityLayer
	entity_layer = get_node_or_null("EntityLayer")
	if not entity_layer:
		push_error("B类模板缺少EntityLayer节点")
		return
	
	# 加载配置
	if not _load_configurations():
		return
	
	# 清空现有内容
	_clear_entity_layer()
	
	# 选择块组合
	selected_blocks = _select_block_combination()
	
	if selected_blocks.is_empty():
		push_warning("未能选择任何块")
		return
	
	# 在网格中实例化块
	_instantiate_blocks_in_grid()
	
	if DEBUG_MODE:
		print("[B类模板] 内容生成完成 - 共 %d 个块" % selected_blocks.size())

func _initialize_grid_positions():
	"""初始化3x3网格的中心位置"""
	grid_positions.clear()
	
	# 计算起始偏移（使网格中心点为房间中心 (0, 0)）
	var start_offset = Vector2(
		-(GRID_SIZE - 1) * CELL_SIZE.x / 2,
		-(GRID_SIZE - 1) * CELL_SIZE.y / 2
	)
	
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var pos = start_offset + Vector2(
				x * CELL_SIZE.x,
				y * CELL_SIZE.y
			)
			grid_positions.append({
				"position": pos, # 网格单元的中心坐标
				"grid_x": x,
				"grid_y": y,
				"occupied": false
			})

func _load_configurations() -> bool:
	"""加载块配置和装饰物配置"""
	var block_path = _get_block_config_path()
	var decoration_path = _get_decoration_config_path()
	
	# 加载块配置
	var block_script = load(block_path)
	if not block_script:
		push_error("无法加载块配置: %s" % block_path)
		return false
	
	block_config = block_script.block_pools
	
	# 加载装饰物配置
	var decoration_script = load(decoration_path)
	if not decoration_script:
		push_error("无法加载装饰物配置: %s" % decoration_path)
		return false
	
	decoration_config = decoration_script.decoration_pools
	
	if DEBUG_MODE:
		print("  [配置加载] 块类型: %d, 装饰物类型: %d" % [
			block_config.keys().size(),
			decoration_config.keys().size()
		])
	
	return true

# ... (_get_block_config_path 和 _get_decoration_config_path 保持不变) ...

func _get_block_config_path() -> String:
	"""获取块配置文件路径"""
	match current_theme:
		Room_Theme.TEST:
			return "res://scripts/rooms/objectslist/B/Test_Block_List.gd"
		Room_Theme.SPRING:
			return "res://scripts/rooms/objectslist/B/Test_Block_List.gd"
		Room_Theme.DESERT:
			return "res://scripts/rooms/objectslist/B/Test_Block_List.gd"
		Room_Theme.FOREST:
			return "res://scripts/rooms/objectslist/B/Test_Block_List.gd"
		Room_Theme.DUNGEON:
			return "res://scripts/rooms/objectslist/B/Test_Block_List.gd"
		Room_Theme.COAST:
			return "res://scripts/rooms/objectslist/B/Test_Block_List.gd"
		_:
			return "res://scripts/rooms/objectslist/B/Test_Block_List.gd"

func _get_decoration_config_path() -> String:
	"""获取装饰物配置文件路径"""
	match current_theme:
		Room_Theme.TEST:
			return "res://scripts/rooms/objectslist/B/decoration/test_decoration.gd"
		Room_Theme.SPRING:
			return "res://scripts/rooms/objectslist/B/decoration/spring_decoration.gd"
		Room_Theme.DESERT:
			return "res://scripts/rooms/objectslist/B/decoration/desert_decoration.gd"
		Room_Theme.FOREST:
			return "res://scripts/rooms/objectslist/B/decoration/forest_decoration.gd"
		Room_Theme.DUNGEON:
			return "res://scripts/rooms/objectslist/B/decoration/dungeon_decoration.gd"
		Room_Theme.COAST:
			return "res://scripts/rooms/objectslist/B/decoration/coast_decoration.gd"
		_:
			return "res://scripts/rooms/objectslist/B/decoration/spring_decoration.gd"


func _select_block_combination() -> Array:
	"""选择块组合（考虑互斥和协同关系，并受最大块数限制）"""
	var selected = []
	var max_blocks_in_grid = GRID_SIZE * GRID_SIZE
	var final_max_blocks = min(max_blocks_in_grid, max_blocks_limit) # 取配置和网格尺寸的最小值
	
	var available_blocks = block_config.keys()
	
	# 第一步：处理互斥规则，过滤出候选块
	var candidates = _apply_exclusion_rules(available_blocks)
	
	if candidates.is_empty():
		push_warning("所有块都被互斥规则过滤，使用备用方案")
		candidates = available_blocks.duplicate()
	
	if DEBUG_MODE:
		print("  [块选择] 候选块: %s" % candidates)
	
	# 第二步：根据协同关系选择块
	selected = _select_blocks_with_synergy(candidates)
	
	# 第三步：应用最大块数限制
	if selected.size() > final_max_blocks:
		# 截断或重新选择，这里简单地截断前面权重/协同最高的
		selected.resize(final_max_blocks)
	elif selected.size() < final_max_blocks:
		# 如果协同选择的块不够，随机从剩余候选块中补足
		var needed = final_max_blocks - selected.size()
		var pool_to_fill = []
		for name in candidates:
			if name not in selected:
				pool_to_fill.append(name)
		
		var added = _random_select_blocks(pool_to_fill, needed)
		selected.append_array(added)
		
	return selected

func _apply_exclusion_rules(all_blocks: Array) -> Array:
	"""应用互斥规则，返回符合条件的候选块列表"""
	var candidates = []
	
	# 收集所有块的互斥规则
	var exclusion_map = {}  # block_name -> [excluded_block_names]
	
	for block_name in all_blocks:
		var block_data = block_config[block_name]
		var excludes = block_data.get("excludes", [])
		
		if not excludes.is_empty():
			exclusion_map[block_name] = excludes
	
	# 如果没有互斥规则，返回全部
	if exclusion_map.is_empty():
		return all_blocks.duplicate()
	
	# 按权重排序所有块
	var sorted_blocks = all_blocks.duplicate()
	# 引入 spread_factor：当 spread_factor 接近 1.0 时，降低高权重块被选中的优先级，
	# 间接增加分散度（避免所有最高权重的块都被选上，让位给其他块）
	sorted_blocks.sort_custom(func(a, b):
		var weight_a = block_config[a].get("spawn_weight", 1.0)
		var weight_b = block_config[b].get("spawn_weight", 1.0)
		# 调整后的权重，分散因子越高，对权重的削弱越大
		var adjusted_weight_a = weight_a * (1.0 - 0.5 * spread_factor) + (0.5 * spread_factor)
		var adjusted_weight_b = weight_b * (1.0 - 0.5 * spread_factor) + (0.5 * spread_factor)
		return adjusted_weight_a > adjusted_weight_b
	)
	
	# 贪心算法：按权重顺序尝试添加块
	for block_name in sorted_blocks:
		# 检查该块是否与已选块冲突
		var has_conflict = false
		
		for selected_block in candidates:
			# 检查双向互斥
			if _blocks_are_exclusive(block_name, selected_block, exclusion_map):
				has_conflict = true
				break
		
		if not has_conflict:
			candidates.append(block_name)
			
			if DEBUG_MODE:
				print("    [互斥检查] %s 加入候选" % block_name)
		else:
			if DEBUG_MODE:
				print("    [互斥检查] %s 被排除" % block_name)
	
	return candidates

# ... (_blocks_are_exclusive, _select_blocks_with_synergy, _select_next_synergy_block, _random_select_blocks 保持不变) ...

func _blocks_are_exclusive(block_a: String, block_b: String, exclusion_map: Dictionary) -> bool:
	"""检查两个块之间是否互斥"""
	# 检查 A 是否排除 B
	if block_a in exclusion_map:
		if block_b in exclusion_map[block_a]:
			return true
	
	# 检查 B 是否排除 A
	if block_b in exclusion_map:
		if block_a in exclusion_map[block_b]:
			return true
	
	return false

func _select_blocks_with_synergy(group_blocks: Array) -> Array:
	"""根据协同关系选择块"""
	var selected = []
	var max_blocks = min(GRID_SIZE * GRID_SIZE, group_blocks.size())
	
	# 第一步：选择核心块（权重最高的）
	var sorted_blocks = group_blocks.duplicate()
	sorted_blocks.sort_custom(func(a, b):
		return block_config[a].get("spawn_weight", 1.0) > block_config[b].get("spawn_weight", 1.0)
	)
	
	if sorted_blocks.is_empty():
		return selected

	var core_block = sorted_blocks[0]
	selected.append(core_block)
	
	if DEBUG_MODE:
		print("  [协同选择] 核心块: %s" % core_block)
	
	# 第二步：根据协同系数选择其他块
	var core_data = block_config[core_block]
	var synergy_map = core_data.get("synergy_with", {})
	
	for i in range(max_blocks - 1):
		var next_block = _select_next_synergy_block(sorted_blocks, selected, synergy_map)
		if next_block:
			selected.append(next_block)
	
	return selected

func _select_next_synergy_block(available: Array, selected: Array, synergy_map: Dictionary) -> String:
	"""选择下一个协同块"""
	var candidates = []
	
	for block_name in available:
		if block_name in selected:
			continue
		
		var base_weight = block_config[block_name].get("spawn_weight", 1.0)
		var synergy_bonus = synergy_map.get(block_name, 1.0)
		var final_weight = base_weight * synergy_bonus
		
		candidates.append({"name": block_name, "weight": final_weight})
	
	if candidates.is_empty():
		return ""
	
	# 加权随机选择
	var names = candidates.map(func(c): return c.name)
	var weights = candidates.map(func(c): return c.weight)
	
	return _weighted_random_choice(names, weights)

func _random_select_blocks(available: Array, count: int) -> Array:
	"""随机选择块（无协同关系）"""
	var selected = []
	var pool = available.duplicate()
	pool.shuffle()
	
	for i in range(min(count, pool.size())):
		selected.append(pool[i])
	
	return selected


func _instantiate_blocks_in_grid():
	"""在网格中实例化选中的块"""
	# 打乱网格位置
	var available_positions = grid_positions.duplicate()
	available_positions.shuffle()
	
	for i in range(min(selected_blocks.size(), available_positions.size())):
		var block_name = selected_blocks[i]
		var grid_cell = available_positions[i]
		
		# 决定块在网格单元内的左右区域
		var block_half_side = rng.randi_range(0, 1) # 0: 左侧, 1: 右侧
		
		_instantiate_single_block(block_name, grid_cell, block_half_side)

func _instantiate_single_block(block_name: String, grid_cell: Dictionary, half_side: int):
	"""实例化单个块及其装饰物"""
	if block_name not in block_config:
		return
	
	var block_data = block_config[block_name]
	var block_scenes = block_data.get("scenes", [])
	
	if block_scenes.is_empty():
		return
	
	# 根据概率选择场景
	var scene_path = _select_scene_by_probability(block_scenes)
	
	if scene_path.is_empty():
		return
	
	# 加载并实例化块
	var block_scene = load(scene_path)
	if not block_scene:
		push_warning("无法加载块场景: %s" % scene_path)
		return
	
	var block_instance = block_scene.instantiate()
	
	# 创建或获取块容器
	var container = _get_or_create_container(block_data.get("container", "Blocks"))
	
	# 在网格单元的指定半区内随机偏移
	var random_offset = _get_random_offset_in_cell(half_side)
	block_instance.position = grid_cell.position + random_offset
	
	container.add_child(block_instance)
	
	if DEBUG_MODE:
		print("  [实例化] 块: %s 位置: (%d,%d), 区域: %s" % [
			block_name,
			grid_cell.grid_x,
			grid_cell.grid_y,
			"左" if half_side == 0 else "右"
		])
	
	# 标记网格为已占用
	grid_cell.occupied = true
	
	# 添加装饰物（装饰物独立选择半区）
	_add_decorations_for_block(block_name, grid_cell, half_side)

func _select_scene_by_probability(scenes: Array) -> String:
	"""根据概率选择场景"""
	if scenes.is_empty():
		return ""
	
	# 如果场景数据包含概率信息
	var has_probability = scenes[0] is Dictionary and "probability" in scenes[0]
	
	if not has_probability:
		# 简单随机选择
		return scenes[rng.randi() % scenes.size()] if scenes[0] is String else scenes[rng.randi() % scenes.size()].path
	
	# 加权随机选择
	var paths = []
	var weights = []
	
	for scene_data in scenes:
		paths.append(scene_data.path)
		weights.append(scene_data.get("probability", 1.0))
	
	return _weighted_random_choice(paths, weights)

func _add_decorations_for_block(block_name: String, grid_cell: Dictionary, block_half_side: int):
#                                                                           ^^^^^^^^^^^^^^^^^^^ 新增参数
	"""为块添加装饰物"""
	if block_name not in decoration_config:
		return
	
	var decoration_data = decoration_config[block_name]
	var decoration_list = decoration_data.get("items", [])
	var max_decorations = decoration_data.get("max_count", 3)
	
	if decoration_list.is_empty():
		return
	
	# 装饰物强制反选 (1 - half_side)
	# 如果主体块在左侧 (0)，装饰物强制在右侧 (1)。
	# 如果主体块在右侧 (1)，装饰物强制在左侧 (0)。
	var deco_half_side = 1 - block_half_side # <--- 关键修改
	
	# 随机选择装饰物数量
	var decoration_count = rng.randi_range(0, max_decorations)
	
	for i in range(decoration_count):
		var decoration_scene_path = _select_scene_by_probability(decoration_list)
		
		if decoration_scene_path.is_empty():
			continue
		
		var decoration_scene = load(decoration_scene_path)
		if not decoration_scene:
			continue
		
		var decoration_instance = decoration_scene.instantiate()
		
		# 在网格单元的指定半区内随机位置
		var random_offset = _get_random_offset_in_cell(deco_half_side)
		decoration_instance.position = grid_cell.position + random_offset
		
		var container = _get_or_create_container("Decorations")
		container.add_child(decoration_instance)


func _get_random_offset_in_cell(half_side: int) -> Vector2:
	"""
	在网格单元的指定半区内获取随机偏移。
	half_side: 0 为左半区, 1 为右半区。
	"""
	var margin = 50  # 边缘留白
	var half_width = CELL_SIZE.x / 2
	var quarter_width = CELL_SIZE.x / 4
	
	var x_min: float
	var x_max: float
	
	if half_side == 0: # 左半区
		x_min = -half_width + margin
		x_max = -margin # 靠近中心线
	else: # 右半区
		x_min = margin # 靠近中心线
		x_max = half_width - margin
	
	return Vector2(
		rng.randf_range(x_min, x_max),
		rng.randf_range(-CELL_SIZE.y / 2 + margin, CELL_SIZE.y / 2 - margin)
	)

func _get_or_create_container(container_name: String) -> Node2D:
	"""获取或创建容器节点"""
	var container = entity_layer.get_node_or_null(container_name)
	
	if not container:
		container = Node2D.new()
		container.name = container_name
		entity_layer.add_child(container)
	
	return container

func _clear_entity_layer():
	"""清空EntityLayer的所有子节点"""
	for child in entity_layer.get_children():
		child.queue_free()

func _weighted_random_choice(items: Array, weights: Array):
	"""加权随机选择"""
	if items.is_empty() or weights.is_empty():
		return null
	
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	if total_weight <= 0:
		return items[rng.randi() % items.size()]
	
	var random_value = rng.randf() * total_weight
	var cumulative = 0.0
	
	for i in range(items.size()):
		cumulative += weights[i]
		if random_value <= cumulative:
			return items[i]
	
	return items[-1]

func _theme_to_string() -> String:
	match current_theme:
		Room_Theme.SPRING: return "春原"
		Room_Theme.DESERT: return "沙漠"
		Room_Theme.FOREST: return "雨林"
		Room_Theme.DUNGEON: return "地牢"
		Room_Theme.COAST: return "海岸"
		_: return "未知(测试)"
