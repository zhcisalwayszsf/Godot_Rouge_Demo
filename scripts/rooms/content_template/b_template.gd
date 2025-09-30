# b_template.gd
# B类模板：积木式拼接 + 智能选择算法
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

# 子分块配置
var block_types = {
	"empty": {
		"scene": null,
		"weight": 30,
		"size": "any",
		"conflicts": [],
		"synergy": {},
		"themes": ["peaceful", "ruins", "dark"]
	},
	"house": {
		"scene": "res://scenes/content_blocks/house_block.tscn",
		"weight": 15,
		"size": "large",
		"conflicts": ["barn", "altar"],
		"synergy": {"garden": 2.0, "well": 1.5},
		"themes": ["peaceful"]
	},
	"barn": {
		"scene": "res://scenes/content_blocks/barn_block.tscn",
		"weight": 12,
		"size": "large",
		"conflicts": ["house", "ruins"],
		"synergy": {"garden": 1.8, "fence": 2.0},
		"themes": ["peaceful"]
	},
	"garden": {
		"scene": "res://scenes/content_blocks/garden_block.tscn",
		"weight": 20,
		"size": "medium",
		"conflicts": ["ruins", "bones"],
		"synergy": {"house": 1.5, "well": 1.3},
		"themes": ["peaceful"]
	},
	"well": {
		"scene": "res://scenes/content_blocks/well_block.tscn",
		"weight": 10,
		"size": "small",
		"conflicts": [],
		"synergy": {"house": 1.5, "garden": 1.3},
		"themes": ["peaceful"]
	},
	"forest": {
		"scene": "res://scenes/content_blocks/forest_block.tscn",
		"weight": 20,
		"size": "medium",
		"conflicts": ["house", "barn"],
		"synergy": {"pond": 1.8, "ruins": 1.2},
		"themes": ["peaceful", "ruins"]
	},
	"pond": {
		"scene": "res://scenes/content_blocks/pond_block.tscn",
		"weight": 8,
		"size": "small",
		"conflicts": ["altar"],
		"synergy": {"forest": 1.8},
		"themes": ["peaceful"]
	},
	"ruins": {
		"scene": "res://scenes/content_blocks/ruins_block.tscn",
		"weight": 15,
		"size": "large",
		"conflicts": ["house", "barn", "garden"],
		"synergy": {"altar": 2.5, "bones": 1.8},
		"themes": ["ruins", "dark"]
	},
	"altar": {
		"scene": "res://scenes/content_blocks/altar_block.tscn",
		"weight": 10,
		"size": "medium",
		"conflicts": ["house", "pond", "garden"],
		"synergy": {"ruins": 2.5, "candles": 2.0},
		"themes": ["dark"]
	},
	"bones": {
		"scene": "res://scenes/content_blocks/bones_block.tscn",
		"weight": 12,
		"size": "small",
		"conflicts": ["garden", "well"],
		"synergy": {"ruins": 1.8, "altar": 1.5},
		"themes": ["dark"]
	}
}

# 网格规则：定义每个格子允许的类型
var grid_rules = {
	Vector2i(1, 1): ["empty", "pond", "altar", "well"],  # 中心：开阔
	Vector2i(0, 0): ["house", "forest", "ruins", "barn"],  # 左上角：大型
	Vector2i(2, 0): ["house", "forest", "ruins", "barn"],  # 右上角：大型
	Vector2i(0, 2): ["house", "forest", "ruins", "barn"],  # 左下角：大型
	Vector2i(2, 2): ["house", "forest", "ruins", "barn"]   # 右下角：大型
}

# 主题偏好（根据楼层选择）
var theme_preferences = {
	"peaceful": ["house", "barn", "garden", "well", "forest", "pond"],
	"ruins": ["ruins", "forest", "bones", "altar"],
	"dark": ["altar", "bones", "ruins"]
}

var rng: RandomNumberGenerator
var block_grid: Node2D
var entity_layer: Node2D
var used_types: Array = []  # 记录已使用的类型（软互斥用）
var grid_layout: Dictionary = {}  # 记录每个格子的类型
var current_theme: String = "peaceful"

func _ready():
	rng = RandomNumberGenerator.new()
	rng.randomize()

func populate(floor_level: int = 1, room_type = null):
	"""主生成方法"""
	print("  [B类] 开始生成内容 (3x3网格)")
	
	# 获取容器
	block_grid = get_node_or_null("BlockGrid")
	entity_layer = get_node_or_null("EntityLayer")
	
	if not block_grid or not entity_layer:
		push_error("B类模板缺少必要节点")
		return
	
	# 根据楼层选择主题
	_select_theme(floor_level)
	
	# 调整密度
	var density = _calculate_density(floor_level)
	
	# 生成3x3网格
	_generate_grid(density)
	
	# 收集所有子分块的SpawnMarkers并生成实体
	_populate_entities()
	
	# 清理Markers
	_cleanup_markers()
	
	print("  [B类] 内容生成完成")

func _select_theme(floor_level: int):
	"""根据楼层选择主题"""
	if floor_level <= 3:
		current_theme = "peaceful"
	elif floor_level <= 7:
		current_theme = "ruins"
	else:
		current_theme = "dark"
	
	print("    主题: %s (楼层 %d)" % [current_theme, floor_level])

func _calculate_density(floor_level: int) -> float:
	"""计算密度（空格子的概率）"""
	if floor_level <= 3:
		return 0.6  # 60%空格子
	elif floor_level <= 7:
		return 0.4  # 40%空格子
	else:
		return 0.2  # 20%空格子

func _generate_grid(density: float):
	"""生成3x3网格"""
	used_types.clear()
	grid_layout.clear()
	
	# 遍历3x3网格
	for x in range(3):
		for y in range(3):
			var grid_pos = Vector2i(x, y)
			var block_type = _select_block_for_position(grid_pos, density)
			
			grid_layout[grid_pos] = block_type
			
			# 实例化子分块
			if block_type != "empty":
				_instantiate_block(block_type, grid_pos)
				used_types.append(block_type)

func _select_block_for_position(grid_pos: Vector2i, density: float) -> String:
	"""智能选择算法"""
	# 1. 获取该位置允许的类型
	var allowed_types = grid_rules.get(grid_pos, block_types.keys())
	
	# 2. 过滤：只保留符合主题的类型
	var themed_types = []
	for type in allowed_types:
		if type == "empty" or current_theme in block_types[type].themes:
			themed_types.append(type)
	
	if themed_types.is_empty():
		return "empty"
	
	# 3. 计算权重
	var weighted_types = []
	
	for type in themed_types:
		var weight = block_types[type].weight
		
		# 硬互斥：冲突类型权重归零
		var conflicts = block_types[type].conflicts
		for conflict in conflicts:
			if conflict in used_types:
				weight = 0
				break
		
		if weight == 0:
			continue
		
		# 软互斥：已使用类型降权
		if type in used_types and type != "empty":
			weight *= 0.2
		
		# 增益系统：检查相邻格子
		var synergy = block_types[type].synergy
		for neighbor_pos in _get_neighbors(grid_pos):
			var neighbor_type = grid_layout.get(neighbor_pos, "")
			if neighbor_type in synergy:
				weight *= synergy[neighbor_type]
		
		# 密度控制：空格子基础权重提升
		if type == "empty":
			weight *= (1.0 + density * 2)
		
		weighted_types.append({"type": type, "weight": weight})
	
	# 4. 加权随机选择
	return _weighted_random_choice(weighted_types)

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
	
	# 计算位置（假设每个格子552x341像素）
	var block_size = Vector2(552, 341)
	var offset = Vector2(-block_size.x, -block_size.y)  # 左上角对齐
	block_instance.position = offset + Vector2(grid_pos.x * block_size.x, grid_pos.y * block_size.y)
	
	block_grid.add_child(block_instance)

func _populate_entities():
	"""从子分块的Markers生成实体"""
	# 递归收集所有SpawnMarkers
	var all_markers = []
	_collect_markers_recursive(block_grid, all_markers)
	
	print("    找到 %d 个Marker" % all_markers.size())
	
	# 遍历生成
	for marker in all_markers:
		_spawn_from_marker(marker)

func _collect_markers_recursive(node: Node, markers: Array):
	"""递归收集Markers"""
	if node.name == "SpawnMarkers":
		for child in node.get_children():
			if child is Marker2D:
				markers.append(child)
	
	for child in node.get_children():
		_collect_markers_recursive(child, markers)

func _spawn_from_marker(marker: Marker2D):
	"""从Marker生成实体"""
	var entity_type = marker.get_meta("type", "")
	var probability = marker.get_meta("prob", 1.0)
	
	if entity_type.is_empty() or rng.randf() > probability:
		return
	
	# 获取场景路径（简化：直接使用type对应路径）
	var scene_path = "res://scenes/entities/%s.tscn" % entity_type
	var entity_scene = load(scene_path)
	
	if not entity_scene:
		return
	
	var entity_instance = entity_scene.instantiate()
	
	# 转换到EntityLayer的局部坐标
	entity_instance.global_position = marker.global_position
	
	# 放入对应容器
	var container_name = _get_container_for_type(entity_type)
	var container = entity_layer.get_node_or_null(container_name)
	
	if not container:
		container = Node2D.new()
		container.name = container_name
		entity_layer.add_child(container)
	
	container.add_child(entity_instance)

func _cleanup_markers():
	"""清理所有SpawnMarkers"""
	_cleanup_markers_recursive(block_grid)

func _cleanup_markers_recursive(node: Node):
	"""递归清理Markers"""
	if node.name == "SpawnMarkers":
		node.queue_free()
		return
	
	for child in node.get_children():
		_cleanup_markers_recursive(child)

# ============== 辅助函数 ==============

func _get_neighbors(grid_pos: Vector2i) -> Array:
	"""获取已处理的相邻格子"""
	var neighbors = []
	var offsets = [Vector2i(-1, 0), Vector2i(0, -1)]  # 只检查左和上
	
	for offset in offsets:
		var neighbor_pos = grid_pos + offset
		if neighbor_pos in grid_layout:
			neighbors.append(neighbor_pos)
	
	return neighbors

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
	if entity_type in ["tree", "rock", "stump"]:
		return "Trees"
	elif entity_type in ["barrel", "crate"]:
		return "Destructibles"
	else:
		return "Props"
