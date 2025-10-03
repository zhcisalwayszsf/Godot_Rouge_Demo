# b_template.gd
# B类模板：积木式拼接 + 智能选择算法（改进版）
extends Node2D

"""
场景结构:
BMixedBlocks (Node2D) [此脚本]
  ├─ BlockGrid (Node2D)          # 3x3网格容器（空，运行时填充）
  └─ EntityLayer (Node2D)        # 实体容器（运行时填充）
		├─ Trees (Node2D)
		├─ Destructibles (Node2D)
		└─ Props (Node2D)
"""

# ============== 配置参数 ==============
@export var DEBUG_MODE: bool = false
@export var grid_size: Vector2i = Vector2i(3, 3)  # 可配置的网格大小
@export var block_size: Vector2i = Vector2i(552, 341)  # 每个格子的尺寸

# 子分块配置（扩展版）
var block_types = {
	"empty": {
		"scene": null,
		"weight": 30,
		"size": "any",
		"conflicts": [],
		"synergy": {},
		"themes": ["peaceful", "ruins", "dark", "mystical"],
		"min_floor": 1,
		"max_floor": 99
	},
	"house": {
		"scene": "res://scenes/content_blocks/house_block.tscn",
		"weight": 15,
		"size": "large",
		"conflicts": ["barn", "altar", "portal"],
		"synergy": {"garden": 2.0, "well": 1.5, "fence": 1.3},
		"themes": ["peaceful"],
		"min_floor": 1,
		"max_floor": 5
	},
	"barn": {
		"scene": "res://scenes/content_blocks/barn_block.tscn",
		"weight": 12,
		"size": "large",
		"conflicts": ["house", "ruins"],
		"synergy": {"garden": 1.8, "fence": 2.0, "scarecrow": 1.5},
		"themes": ["peaceful"],
		"min_floor": 1,
		"max_floor": 5
	},
	"garden": {
		"scene": "res://scenes/content_blocks/garden_block.tscn",
		"weight": 20,
		"size": "medium",
		"conflicts": ["ruins", "bones", "corruption"],
		"synergy": {"house": 1.5, "well": 1.3, "fountain": 1.8},
		"themes": ["peaceful"],
		"min_floor": 1,
		"max_floor": 6
	},
	"well": {
		"scene": "res://scenes/content_blocks/well_block.tscn",
		"weight": 10,
		"size": "small",
		"conflicts": ["void"],
		"synergy": {"house": 1.5, "garden": 1.3},
		"themes": ["peaceful"],
		"min_floor": 1,
		"max_floor": 99
	},
	"forest": {
		"scene": "res://scenes/content_blocks/forest_block.tscn",
		"weight": 20,
		"size": "medium",
		"conflicts": ["house", "barn"],
		"synergy": {"pond": 1.8, "ruins": 1.2, "mushrooms": 2.0},
		"themes": ["peaceful", "ruins", "mystical"],
		"min_floor": 1,
		"max_floor": 99
	},
	"pond": {
		"scene": "res://scenes/content_blocks/pond_block.tscn",
		"weight": 8,
		"size": "small",
		"conflicts": ["altar", "lava"],
		"synergy": {"forest": 1.8, "lilypads": 1.5},
		"themes": ["peaceful"],
		"min_floor": 1,
		"max_floor": 99
	},
	"ruins": {
		"scene": "res://scenes/content_blocks/ruins_block.tscn",
		"weight": 15,
		"size": "large",
		"conflicts": ["house", "barn", "garden"],
		"synergy": {"altar": 2.5, "bones": 1.8, "ancient_tree": 2.0},
		"themes": ["ruins", "dark"],
		"min_floor": 3,
		"max_floor": 99
	},
	"altar": {
		"scene": "res://scenes/content_blocks/altar_block.tscn",
		"weight": 10,
		"size": "medium",
		"conflicts": ["house", "pond", "garden"],
		"synergy": {"ruins": 2.5, "candles": 2.0, "ritual_circle": 3.0},
		"themes": ["dark", "mystical"],
		"min_floor": 5,
		"max_floor": 99
	},
	"bones": {
		"scene": "res://scenes/content_blocks/bones_block.tscn",
		"weight": 12,
		"size": "small",
		"conflicts": ["garden", "well"],
		"synergy": {"ruins": 1.8, "altar": 1.5, "graveyard": 2.5},
		"themes": ["dark"],
		"min_floor": 4,
		"max_floor": 99
	},
	"mushrooms": {
		"scene": "res://scenes/content_blocks/mushrooms_block.tscn",
		"weight": 15,
		"size": "small",
		"conflicts": [],
		"synergy": {"forest": 2.0, "cave": 1.5},
		"themes": ["mystical"],
		"min_floor": 2,
		"max_floor": 99
	},
	"crystal": {
		"scene": "res://scenes/content_blocks/crystal_block.tscn",
		"weight": 8,
		"size": "medium",
		"conflicts": [],
		"synergy": {"cave": 2.0, "portal": 2.5},
		"themes": ["mystical"],
		"min_floor": 7,
		"max_floor": 99
	},
	"portal": {
		"scene": "res://scenes/content_blocks/portal_block.tscn",
		"weight": 5,
		"size": "large",
		"conflicts": ["house", "barn"],
		"synergy": {"crystal": 2.5, "altar": 2.0},
		"themes": ["mystical", "dark"],
		"min_floor": 10,
		"max_floor": 99
	}
}

# 网格规则：定义每个格子允许的类型（可根据grid_size动态调整）
var grid_rules = {}

# 主题配置（扩展版）
var theme_configs = {
	"peaceful": {
		"preferred_types": ["house", "barn", "garden", "well", "forest", "pond"],
		"density": 0.6,  # 60%填充率
		"description": "宁静祥和的田园风光"
	},
	"ruins": {
		"preferred_types": ["ruins", "forest", "bones", "altar"],
		"density": 0.5,
		"description": "古老遗迹与自然融合"
	},
	"dark": {
		"preferred_types": ["altar", "bones", "ruins", "portal"],
		"density": 0.4,
		"description": "黑暗邪恶的氛围"
	},
	"mystical": {
		"preferred_types": ["crystal", "mushrooms", "portal", "altar", "forest"],
		"density": 0.45,
		"description": "神秘魔法的环境"
	}
}

# ============== 状态变量 ==============
var rng: RandomNumberGenerator
var block_grid: Node2D
var entity_layer: Node2D
var used_types: Array = []
var grid_layout: Dictionary = {}
var current_theme: String = "peaceful"
var current_floor_level: int = 1
var current_room_type = null

# 实体池配置（兼容A类模板格式）
var entity_pools: Dictionary = {}

func _ready():
	rng = RandomNumberGenerator.new()
	rng.randomize()
	_initialize_grid_rules()

func populate(floor_level: int = 1, room_type = null):
	"""主生成方法"""
	_log_debug("=== B类模板开始生成 ===")
	_log_debug("楼层: %d, 房间类型: %s" % [floor_level, room_type])
	
	current_floor_level = floor_level
	current_room_type = room_type
	
	# 获取容器
	block_grid = get_node_or_null("BlockGrid")
	entity_layer = get_node_or_null("EntityLayer")
	
	if not block_grid:
		block_grid = Node2D.new()
		block_grid.name = "BlockGrid"
		add_child(block_grid)
	
	if not entity_layer:
		entity_layer = Node2D.new()
		entity_layer.name = "EntityLayer"
		add_child(entity_layer)
	
	# 加载实体池配置
	_load_entity_pools()
	
	# 选择主题
	_select_theme(floor_level, room_type)
	
	# 计算密度
	var density = _calculate_density(floor_level)
	
	# 生成网格布局
	_generate_grid(density)
	
	# 从子分块收集SpawnMarkers并生成实体
	_populate_entities_from_blocks()
	
	# 直接在空格子生成装饰
	_populate_empty_cells()
	
	# 清理Markers
	_cleanup_markers()
	
	_log_debug("=== B类模板生成完成 ===")
	_print_generation_summary()

func _initialize_grid_rules():
	"""初始化网格规则（支持动态网格大小）"""
	grid_rules.clear()
	
	# 中心位置优先小型元素
	var center = Vector2i(grid_size.x / 2, grid_size.y / 2)
	grid_rules[center] = ["empty", "pond", "altar", "well", "crystal"]
	
	# 四角优先大型元素
	grid_rules[Vector2i(0, 0)] = ["house", "forest", "ruins", "barn", "portal"]
	grid_rules[Vector2i(grid_size.x - 1, 0)] = ["house", "forest", "ruins", "barn", "portal"]
	grid_rules[Vector2i(0, grid_size.y - 1)] = ["house", "forest", "ruins", "barn", "portal"]
	grid_rules[Vector2i(grid_size.x - 1, grid_size.y - 1)] = ["house", "forest", "ruins", "barn", "portal"]

func _load_entity_pools():
	"""加载实体池配置（根据主题）"""
	# 这里可以根据主题加载不同的配置
	# 暂时使用硬编码的示例
	entity_pools = {
		"tree": {
			"scenes": [
				{"path": "res://scenes/entities/nature/oak_tree.tscn", "size": Vector2i(2, 2)},
				{"path": "res://scenes/entities/nature/pine_tree.tscn", "size": Vector2i(2, 2)}
			],
			"max_count": 8,
			"container": "Trees"
		},
		"rock": {
			"scenes": [
				{"path": "res://scenes/entities/nature/rock_small.tscn", "size": Vector2i(1, 1)},
				{"path": "res://scenes/entities/nature/rock_large.tscn", "size": Vector2i(2, 2)}
			],
			"max_count": 5,
			"container": "Trees"
		},
		"barrel": {
			"scenes": [
				{"path": "res://scenes/entities/props/barrel.tscn", "size": Vector2i(1, 1)}
			],
			"max_count": 3,
			"container": "Destructibles"
		},
		"flower": {
			"scenes": [
				{"path": "res://scenes/entities/nature/flower_red.tscn", "size": Vector2i(1, 1)},
				{"path": "res://scenes/entities/nature/flower_blue.tscn", "size": Vector2i(1, 1)}
			],
			"max_count": 10,
			"container": "Props"
		}
	}

func _select_theme(floor_level: int, room_type):
	"""智能主题选择"""
	# 根据楼层和房间类型选择主题
	if room_type == LevelManager.RoomType.REST:
		current_theme = "peaceful"
	elif room_type == LevelManager.RoomType.BOSS and floor_level >= 10:
		current_theme = "dark"
	elif floor_level <= 3:
		current_theme = "peaceful"
	elif floor_level <= 6:
		current_theme = "ruins"
	elif floor_level <= 9:
		current_theme = "mystical"
	else:
		current_theme = "dark"
	
	_log_debug("选择主题: %s (%s)" % [current_theme, theme_configs[current_theme].description])

func _calculate_density(floor_level: int) -> float:
	"""计算密度（基于主题和楼层）"""
	var base_density = theme_configs[current_theme].density
	
	# 楼层越高，密度略微降低（增加挑战空间）
	var floor_modifier = 1.0 - (floor_level * 0.02)
	floor_modifier = max(0.3, floor_modifier)
	
	return base_density * floor_modifier

func _generate_grid(density: float):
	"""生成网格布局（改进版）"""
	used_types.clear()
	grid_layout.clear()
	
	# 收集可用的块类型
	var available_types = _get_available_block_types()
	
	_log_debug("可用块类型: %s" % str(available_types))
	
	# 遍历网格
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var grid_pos = Vector2i(x, y)
			var block_type = _select_block_for_position(grid_pos, density, available_types)
			
			grid_layout[grid_pos] = block_type
			
			if block_type != "empty":
				_instantiate_block(block_type, grid_pos)
				used_types.append(block_type)

func _get_available_block_types() -> Array:
	"""获取当前楼层和主题可用的块类型"""
	var available = []
	var theme_preferred = theme_configs[current_theme].preferred_types
	
	for type_name in block_types.keys():
		var type_data = block_types[type_name]
		
		# 检查楼层范围
		if current_floor_level < type_data.min_floor or current_floor_level > type_data.max_floor:
			continue
		
		# 检查主题匹配
		if current_theme in type_data.themes or type_name in theme_preferred:
			available.append(type_name)
	
	return available

func _select_block_for_position(grid_pos: Vector2i, density: float, available_types: Array) -> String:
	"""智能块选择算法（改进版）"""
	# 1. 获取位置允许的类型
	var allowed_types = grid_rules.get(grid_pos, available_types)
	
	# 2. 过滤可用类型
	var valid_types = []
	for type in allowed_types:
		if type in available_types:
			valid_types.append(type)
	
	if valid_types.is_empty():
		return "empty"
	
	# 3. 计算权重
	var weighted_types = []
	
	for type in valid_types:
		var weight = block_types[type].weight
		
		# 硬互斥检查
		var conflicts = block_types[type].conflicts
		var has_conflict = false
		for conflict in conflicts:
			if conflict in used_types:
				has_conflict = true
				break
		
		if has_conflict:
			continue
		
		# 软互斥：已使用类型降权
		if type in used_types and type != "empty":
			weight *= 0.3
		
		# 增益系统：检查相邻格子
		var synergy_bonus = _calculate_synergy_bonus(type, grid_pos)
		weight *= synergy_bonus
		
		# 主题偏好加权
		if type in theme_configs[current_theme].preferred_types:
			weight *= 1.5
		
		# 密度控制
		if type == "empty":
			weight *= (1.0 + (1.0 - density) * 3)
		
		weighted_types.append({"type": type, "weight": weight})
	
	# 4. 加权随机选择
	return _weighted_random_choice(weighted_types)

func _calculate_synergy_bonus(type: String, grid_pos: Vector2i) -> float:
	"""计算协同加成"""
	var bonus = 1.0
	var synergy = block_types[type].synergy
	
	# 检查所有相邻位置
	var offsets = [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1),
		Vector2i(-1, 1), Vector2i(1, 1)
	]
	
	for offset in offsets:
		var neighbor_pos = grid_pos + offset
		if neighbor_pos in grid_layout:
			var neighbor_type = grid_layout[neighbor_pos]
			if neighbor_type in synergy:
				bonus *= synergy[neighbor_type]
	
	return bonus

func _instantiate_block(block_type: String, grid_pos: Vector2i):
	"""实例化子分块到网格"""
	var scene_path = block_types[block_type].scene
	if not scene_path:
		return
	
	var block_scene = load(scene_path)
	if not block_scene:
		push_warning("无法加载分块: %s" % scene_path)
		return
	
	var block_instance = block_scene.instantiate()
	
	# 计算位置
	var offset = Vector2(-block_size.x, -block_size.y)
	block_instance.position = offset + Vector2(grid_pos.x * block_size.x, grid_pos.y * block_size.y)
	
	block_grid.add_child(block_instance)
	
	_log_debug("生成块 [%d,%d]: %s" % [grid_pos.x, grid_pos.y, block_type])

func _populate_entities_from_blocks():
	"""从子分块的Markers生成实体"""
	var all_markers = []
	_collect_markers_recursive(block_grid, all_markers)
	
	_log_debug("从块中找到 %d 个Marker" % all_markers.size())
	
	# 按优先级排序（如果Marker有priority元数据）
	all_markers.sort_custom(func(a, b):
		var priority_a = a.get_meta("priority", 999)
		var priority_b = b.get_meta("priority", 999)
		return priority_a < priority_b
	)
	
	# 生成实体
	var spawn_counts = {}
	for marker in all_markers:
		_spawn_from_marker(marker, spawn_counts)

func _populate_empty_cells():
	"""在空格子直接生成装饰"""
	for grid_pos in grid_layout:
		if grid_layout[grid_pos] == "empty":
			_populate_empty_cell(grid_pos)

func _populate_empty_cell(grid_pos: Vector2i):
	"""为空格子生成随机装饰"""
	# 根据主题选择装饰类型
	var decoration_types = []
	
	match current_theme:
		"peaceful":
			decoration_types = ["flower", "tree", "rock"]
		"ruins":
			decoration_types = ["rock", "tree"]
		"dark":
			decoration_types = ["rock"]
		"mystical":
			decoration_types = ["flower", "rock"]
	
	# 随机决定是否生成（30%概率）
	if rng.randf() > 0.3:
		return
	
	# 选择类型并生成
	if not decoration_types.is_empty():
		var chosen_type = decoration_types[rng.randi() % decoration_types.size()]
		
		if chosen_type in entity_pools:
			var scenes = entity_pools[chosen_type].scenes
			if not scenes.is_empty():
				var scene_data = scenes[rng.randi() % scenes.size()]
				var entity_scene = load(scene_data.path)
				
				if entity_scene:
					var entity_instance = entity_scene.instantiate()
					
					# 计算世界坐标
					var world_pos = Vector2(grid_pos.x * block_size.x, grid_pos.y * block_size.y)
					# 添加随机偏移
					world_pos += Vector2(
						rng.randf_range(-block_size.x * 0.3, block_size.x * 0.3),
						rng.randf_range(-block_size.y * 0.3, block_size.y * 0.3)
					)
					
					entity_instance.position = world_pos
					
					# 添加到容器
					var container_name = entity_pools[chosen_type].get("container", "Props")
					var container = entity_layer.get_node_or_null(container_name)
					
					if not container:
						container = Node2D.new()
						container.name = container_name
						entity_layer.add_child(container)
					
					container.add_child(entity_instance)

func _collect_markers_recursive(node: Node, markers: Array):
	"""递归收集Markers"""
	if node.name == "SpawnMarkers":
		for child in node.get_children():
			if child is Marker2D:
				markers.append(child)
	
	for child in node.get_children():
		_collect_markers_recursive(child, markers)

func _spawn_from_marker(marker: Marker2D, spawn_counts: Dictionary):
	"""从Marker生成实体（兼容metadata和MarkerData）"""
	var entity_type = ""
	var probability = 1.0
	
	# 尝试获取type（兼容旧版metadata）
	if marker.has_meta("type"):
		entity_type = marker.get_meta("type", "")
	
	# 尝试获取MarkerData（新版Resource系统）
	if marker.has_method("get_config"):
		var config = marker.get_config()
		if config:
			entity_type = config.entity_type
			probability = config.probability
	
	if entity_type.is_empty() or rng.randf() > probability:
		return
	
	# 检查类型限制
	var current_count = spawn_counts.get(entity_type, 0)
	if entity_type in entity_pools:
		var max_count = entity_pools[entity_type].get("max_count", 999)
		if current_count >= max_count:
			return
	
	# 获取场景
	var scene_path = _get_scene_for_type(entity_type)
	if scene_path.is_empty():
		return
	
	var entity_scene = load(scene_path)
	if not entity_scene:
		return
	
	var entity_instance = entity_scene.instantiate()
	entity_instance.global_position = marker.global_position
	
	# 放入容器
	var container_name = _get_container_for_type(entity_type)
	var container = entity_layer.get_node_or_null(container_name)
	
	if not container:
		container = Node2D.new()
		container.name = container_name
		entity_layer.add_child(container)
	
	container.add_child(entity_instance)
	
	# 更新计数
	spawn_counts[entity_type] = current_count + 1

func _get_scene_for_type(entity_type: String) -> String:
	"""获取类型对应的场景路径"""
	if entity_type not in entity_pools:
		return ""
	
	var scenes = entity_pools[entity_type].scenes
	if scenes.is_empty():
		return ""
	
	# 随机选择
	var scene_data = scenes[rng.randi() % scenes.size()]
	return scene_data.path

func _cleanup_markers():
	"""清理所有SpawnMarkers节点"""
	_cleanup_markers_recursive(block_grid)

func _cleanup_markers_recursive(node: Node):
	"""递归清理Markers"""
	if node.name == "SpawnMarkers":
		node.queue_free()
		return
	
	for child in node.get_children():
		_cleanup_markers_recursive(child)

# ============== 辅助函数 ==============

func _weighted_random_choice(weighted_types: Array) -> String:
	"""加权随机选择"""
	if weighted_types.is_empty():
		return "empty"
	
	var total_weight = 0.0
	for item in weighted_types:
		total_weight += item.weight
	
	if total_weight == 0:
		return "empty"
	
	var random_value = rng.randf() * total_weight
	var cumulative = 0.0
	
	for item in weighted_types:
		cumulative += item.weight
		if random_value <= cumulative:
			return item.type
	
	return weighted_types[0].type

func _get_container_for_type(entity_type: String) -> String:
	"""根据类型获取容器名称"""
	if entity_type in entity_pools:
		return entity_pools[entity_type].get("container", "Props")
	
	# 默认分类
	if entity_type in ["tree", "rock", "stump"]:
		return "Trees"
	elif entity_type in ["barrel", "crate"]:
		return "Destructibles"
	else:
		return "Props"

func _log_debug(message: String):
	"""条件调试输出"""
	if DEBUG_MODE:
		print("[B类] " + message)

func _print_generation_summary():
	"""打印生成摘要"""
	if not DEBUG_MODE:
		return
	
	print("=== B类生成摘要 ===")
	print("主题: %s" % current_theme)
	print("网格大小: %dx%d" % [grid_size.x, grid_size.y])
	print("生成的块类型:")
	
	var type_counts = {}
	for pos in grid_layout:
		var type = grid_layout[pos]
		type_counts[type] = type_counts.get(type, 0) + 1
	
	for type in type_counts:
		print("  %s: %d" % [type, type_counts[type]])
	
	print("===================")
