# Room_Generator.gd
# 房间生成器单例 - 基于TileMapLayer的生成系统
extends Node

# ============== 常量定义 ==============
const TILE_SIZE = 32
const ROOM_WIDTH = 1600
const ROOM_HEIGHT = 960
const GRID_WIDTH = ROOM_WIDTH / TILE_SIZE  # 50
const GRID_HEIGHT = ROOM_HEIGHT / TILE_SIZE # 30

const DOOR_CLEARANCE_SIZE = 64  # 门口预留空间大小
const DOOR_CLEARANCE_TILES = DOOR_CLEARANCE_SIZE / TILE_SIZE  # 2个tile

# 区域划分模式
enum AreaDivisionMode {
	GRID_UNIFORM,      # 均匀网格（如256x256）
	GRID_STAGGERED,    # 错列三角排布
	DIAGONAL_QUAD,     # 对角线四分
	VORONOI,          # Voronoi图
	ROOMS_IN_ROOM,    # 房中房
	SPIRAL,           # 螺旋分区
	RANDOM_RECTS      # 随机矩形
}

# 环境主题
enum EnvironmentTheme {
	DUNGEON,
	GRASSLAND,
	DESERT,
	SNOW,
	CAVE,
	CASTLE,
	FOREST,
	RUINS
}

# ============== 预制件路径 ==============
var floor_tilemap_scenes = {
	EnvironmentTheme.DUNGEON: "res://scenes/rooms/floor_layers/spring_room_floor.tscn",
	EnvironmentTheme.GRASSLAND: "res://scenes/rooms/floor_layers/spring_room_floor.tscn",
	EnvironmentTheme.DESERT: "res://scenes/rooms/floor_layers/spring_room_floor.tscn",
	EnvironmentTheme.SNOW: "res://scenes/rooms/floor_layers/spring_room_floor.tscn",
	EnvironmentTheme.CAVE: "res://scenes/rooms/floor_layers/spring_room_floor.tscn",
	EnvironmentTheme.CASTLE: "res://scenes/rooms/floor_layers/spring_room_floor.tscn",
	EnvironmentTheme.FOREST: "res://scenes/rooms/floor_layers/spring_room_floor.tscn",
	EnvironmentTheme.RUINS: "res://scenes/rooms/floor_layers/spring_room_floor.tscn"
}

# 建筑物TileSet资源路径
var building_tileset_resources = {
	EnvironmentTheme.DUNGEON: "res://scenes/rooms/building_layers/buildings_spring.tres",
	EnvironmentTheme.GRASSLAND: "res://scenes/rooms/building_layers/buildings_spring.tres",
	EnvironmentTheme.DESERT: "res://scenes/rooms/building_layers/buildings_spring.tres",
	EnvironmentTheme.SNOW: "res://scenes/rooms/building_layers/buildings_spring.tres"
}

# ============== 房间配置 ==============
class RoomGenerationConfig:
	var theme: EnvironmentTheme = EnvironmentTheme.DUNGEON
	var connections: Array = []  # Direction枚举数组
	var difficulty: float = 0.5
	var density: float = 0.5
	var room_seed: int = -1
	var division_mode: AreaDivisionMode = AreaDivisionMode.GRID_UNIFORM
	var allow_water: bool = true
	var allow_walls: bool = true
	var special_features: Dictionary = {}

# ============== 区域定义 ==============
class AreaRegion:
	var bounds: Rect2i  # 区域边界（tile坐标）
	var type: String = ""  # 区域类型
	var density: float = 0.5  # 区域密度
	var features: Array = []  # 特殊特征
	var is_entrance: bool = false  # 是否是入口区域
	
	func _init(rect: Rect2i):
		bounds = rect

# ============== 主生成函数 ==============
var rng: RandomNumberGenerator
var current_room_node: Node2D
var current_config: RoomGenerationConfig
var floor_layer: TileMapLayer
var building_layer: TileMapLayer
var areas: Array[AreaRegion] = []

func generate_room(room_node: Node2D, config: RoomGenerationConfig) -> void:
	"""生成房间的主函数"""
	
	current_room_node = room_node
	current_config = config
	
	# 初始化随机数生成器
	_init_rng(config.room_seed)
	
	# 清理旧的TileMapLayer（如果有）
	_clear_old_tilemaps()
	
	# 1. 添加地板层
	_add_floor_layer(config.theme)
	
	# 2. 创建建筑物层
	_create_building_layer(config.theme)
	
	# 3. 划分区域
	areas = _divide_areas(config.division_mode, config.connections)
	
	# 4. 为建筑物层设置脚本和生成内容
	_setup_building_layer()
	
	# 5. 生成建筑物和地形
	_generate_buildings_and_terrain()

# ============== 层级管理 ==============
func _clear_old_tilemaps():
	"""清理旧的TileMapLayer节点"""
	
	# 查找并删除现有的TileMapLayer节点
	for child in current_room_node.get_children():
		if child is TileMapLayer:
			child.queue_free()

func _add_floor_layer(theme: EnvironmentTheme) -> void:
	"""添加地板和墙壁层"""
	
	if not floor_tilemap_scenes.has(theme):
		push_warning("Floor theme not found: " + str(theme) + ", using dungeon")
		theme = EnvironmentTheme.DUNGEON
	
	var floor_scene = load(floor_tilemap_scenes[theme])
	if floor_scene:
		floor_layer = floor_scene.instantiate()
		floor_layer.name = "FloorLayer"
		floor_layer.scale = Vector2(2,2)
		floor_layer.z_index = -1  # 确保在底层
		current_room_node.add_child(floor_layer)
		floor_layer.position+=Vector2(0,544)
		# 如果需要，可以在这里修改地板的某些tiles
		_customize_floor_tiles()

func _create_building_layer(theme: EnvironmentTheme) -> void:
	"""创建建筑物层"""
	
	building_layer = TileMapLayer.new()
	building_layer.name = "BuildingLayer"
	building_layer.z_index = 0
	
	# 设置TileSet资源
	if building_tileset_resources.has(theme):
		var tileset = load(building_tileset_resources[theme])
		if tileset:
			building_layer.tile_set = tileset
			building_layer.scale = Vector2(2,2)
			building_layer.position+=Vector2(0,544)
	current_room_node.add_child(building_layer)

func _setup_building_layer():
	"""为建筑物层设置脚本"""
	
	# 动态附加building_tile脚本
	#var script = load("res://scripts/building_tile.gd")
	var script = null
	if script:
		building_layer.set_script(script)
		
		# 传递必要的配置给building_tile脚本
		if building_layer.has_method("initialize"):
			building_layer.initialize({
				"areas": areas,
				"config": current_config,
				"rng_seed": rng.seed if rng else -1
			})

# ============== 区域划分 ==============
func _divide_areas(mode: AreaDivisionMode, connections: Array) -> Array[AreaRegion]:
	"""划分房间区域"""
	
	var regions: Array[AreaRegion] = []
	
	# 首先标记入口区域（不生成建筑物）
	regions.append_array(_mark_entrance_areas(connections))
	
	# 根据模式划分剩余区域
	match mode:
		AreaDivisionMode.GRID_UNIFORM:
			regions.append_array(_divide_uniform_grid())
		AreaDivisionMode.GRID_STAGGERED:
			regions.append_array(_divide_staggered_grid())
		AreaDivisionMode.DIAGONAL_QUAD:
			regions.append_array(_divide_diagonal_quad())
		AreaDivisionMode.VORONOI:
			regions.append_array(_divide_voronoi())
		AreaDivisionMode.ROOMS_IN_ROOM:
			regions.append_array(_divide_rooms_in_room())
		AreaDivisionMode.SPIRAL:
			regions.append_array(_divide_spiral())
		AreaDivisionMode.RANDOM_RECTS:
			regions.append_array(_divide_random_rects())
		_:
			regions.append_array(_divide_uniform_grid())
	
	return regions

func _mark_entrance_areas(connections: Array) -> Array[AreaRegion]:
	"""标记门口入口区域"""
	
	var entrance_regions: Array[AreaRegion] = []
	
	for dir in connections:
		var entrance_area: AreaRegion
		
		match dir:
			0:  # LEFT
				entrance_area = AreaRegion.new(Rect2i(
					0, 
					GRID_HEIGHT / 2 - 3,
					4,  # 4个tile宽度的入口区域
					6   # 6个tile高度
				))
			1:  # RIGHT
				entrance_area = AreaRegion.new(Rect2i(
					GRID_WIDTH - 4,
					GRID_HEIGHT / 2 - 3,
					4,
					6
				))
			2:  # TOP
				entrance_area = AreaRegion.new(Rect2i(
					GRID_WIDTH / 2 - 3,
					0,
					6,
					4
				))
			3:  # BOTTOM
				entrance_area = AreaRegion.new(Rect2i(
					GRID_WIDTH / 2 - 3,
					GRID_HEIGHT - 4,
					6,
					4
				))
		
		if entrance_area:
			entrance_area.is_entrance = true
			entrance_area.type = "entrance"
			entrance_regions.append(entrance_area)
	
	return entrance_regions

func _divide_uniform_grid() -> Array[AreaRegion]:
	"""均匀网格划分（256x256像素 = 8x8 tiles）"""
	
	var regions: Array[AreaRegion] = []
	var grid_size = 8  # 256 / 32 = 8 tiles
	
	for x in range(0, GRID_WIDTH, grid_size):
		for y in range(0, GRID_HEIGHT, grid_size):
			var width = min(grid_size, GRID_WIDTH - x)
			var height = min(grid_size, GRID_HEIGHT - y)
			
			var region = AreaRegion.new(Rect2i(x, y, width, height))
			region.type = "grid_cell"
			region.density = current_config.density + rng.randf_range(-0.2, 0.2)
			
			# 随机决定这个格子的特征
			if rng.randf() < 0.3:
				region.features.append("walls")
			if rng.randf() < 0.2:
				region.features.append("water")
			if rng.randf() < 0.1:
				region.features.append("special")
			
			regions.append(region)
	
	return regions

func _divide_staggered_grid() -> Array[AreaRegion]:
	"""错列三角形/六边形排布"""
	
	var regions: Array[AreaRegion] = []
	var hex_size = 6  # 六边形半径（tiles）
	var row_height = hex_size * 1.5
	var col_width = hex_size * 2
	
	var row = 0
	var y = 0
	while y < GRID_HEIGHT:
		var x_offset = (row % 2) * hex_size  # 错列
		var x = x_offset
		
		while x < GRID_WIDTH:
			var region = AreaRegion.new(Rect2i(
				x,
				y,
				min(col_width, GRID_WIDTH - x),
				min(row_height, GRID_HEIGHT - y)
			))
			region.type = "hex_cell"
			region.density = current_config.density + rng.randf_range(-0.15, 0.15)
			regions.append(region)
			
			x += col_width
		
		y += row_height
		row += 1
	
	return regions

func _divide_diagonal_quad() -> Array[AreaRegion]:
	"""对角线四分区域"""
	
	var regions: Array[AreaRegion] = []
	var center_x = GRID_WIDTH / 2
	var center_y = GRID_HEIGHT / 2
	
	# 左上
	var tl = AreaRegion.new(Rect2i(0, 0, center_x, center_y))
	tl.type = "quad_tl"
	tl.density = current_config.density + rng.randf_range(-0.1, 0.1)
	regions.append(tl)
	
	# 右上
	var tr = AreaRegion.new(Rect2i(center_x, 0, GRID_WIDTH - center_x, center_y))
	tr.type = "quad_tr"
	tr.density = current_config.density + rng.randf_range(-0.1, 0.1)
	regions.append(tr)
	
	# 左下
	var bl = AreaRegion.new(Rect2i(0, center_y, center_x, GRID_HEIGHT - center_y))
	bl.type = "quad_bl"
	bl.density = current_config.density + rng.randf_range(-0.1, 0.1)
	regions.append(bl)
	
	# 右下
	var br = AreaRegion.new(Rect2i(center_x, center_y, GRID_WIDTH - center_x, GRID_HEIGHT - center_y))
	br.type = "quad_br"
	br.density = current_config.density + rng.randf_range(-0.1, 0.1)
	regions.append(br)
	
	# 可能添加中心特殊区域
	if rng.randf() < 0.5:
		var center = AreaRegion.new(Rect2i(
			center_x - 4, center_y - 4, 8, 8
		))
		center.type = "center_special"
		center.features.append("special")
		regions.append(center)
	
	return regions

func _divide_voronoi() -> Array[AreaRegion]:
	"""Voronoi图划分（简化版）"""
	
	var regions: Array[AreaRegion] = []
	var num_cells = rng.randi_range(6, 10)
	var seeds = []
	
	# 生成种子点
	for i in range(num_cells):
		seeds.append(Vector2i(
			rng.randi_range(2, GRID_WIDTH - 2),
			rng.randi_range(2, GRID_HEIGHT - 2)
		))
	
	# 为每个种子创建一个区域（简化：使用矩形近似）
	for i in range(seeds.size()):
		var seed = seeds[i]
		var min_x = seed.x
		var max_x = seed.x
		var min_y = seed.y
		var max_y = seed.y
		
		# 扩展到邻近种子的中点
		for j in range(seeds.size()):
			if i != j:
				var other = seeds[j]
				if abs(other.x - seed.x) < 15:
					if other.x < seed.x:
						min_x = min(min_x, (seed.x + other.x) / 2)
					else:
						max_x = max(max_x, (seed.x + other.x) / 2)
				if abs(other.y - seed.y) < 15:
					if other.y < seed.y:
						min_y = min(min_y, (seed.y + other.y) / 2)
					else:
						max_y = max(max_y, (seed.y + other.y) / 2)
		
		# 限制在房间范围内
		min_x = max(0, min_x - 3)
		max_x = min(GRID_WIDTH - 1, max_x + 3)
		min_y = max(0, min_y - 3)
		max_y = min(GRID_HEIGHT - 1, max_y + 3)
		
		var region = AreaRegion.new(Rect2i(
			min_x, min_y,
			max_x - min_x + 1,
			max_y - min_y + 1
		))
		region.type = "voronoi_cell"
		region.density = current_config.density + rng.randf_range(-0.2, 0.2)
		regions.append(region)
	
	return regions

func _divide_rooms_in_room() -> Array[AreaRegion]:
	"""房中房划分"""
	
	var regions: Array[AreaRegion] = []
	var num_rooms = rng.randi_range(3, 6)
	
	for i in range(num_rooms):
		var room_width = rng.randi_range(6, 12)
		var room_height = rng.randi_range(6, 12)
		var x = rng.randi_range(2, GRID_WIDTH - room_width - 2)
		var y = rng.randi_range(2, GRID_HEIGHT - room_height - 2)
		
		var region = AreaRegion.new(Rect2i(x, y, room_width, room_height))
		region.type = "inner_room"
		region.density = current_config.density + 0.2  # 内部房间密度更高
		region.features.append("room_walls")
		regions.append(region)
	
	# 添加走廊区域
	var corridor = AreaRegion.new(Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT))
	corridor.type = "corridor"
	corridor.density = 0.2  # 走廊密度低
	regions.append(corridor)
	
	return regions

func _divide_spiral() -> Array[AreaRegion]:
	"""螺旋分区"""
	
	var regions: Array[AreaRegion] = []
	var center = Vector2i(GRID_WIDTH / 2, GRID_HEIGHT / 2)
	var num_rings = 4
	
	for ring in range(num_rings):
		var inner_radius = ring * 5
		var outer_radius = (ring + 1) * 5
		
		# 简化：用方形环代替圆形环
		var ring_region = AreaRegion.new(Rect2i(
			center.x - outer_radius,
			center.y - outer_radius,
			outer_radius * 2,
			outer_radius * 2
		))
		ring_region.type = "spiral_ring_" + str(ring)
		ring_region.density = current_config.density * (1.0 - ring * 0.2)
		regions.append(ring_region)
	
	return regions

func _divide_random_rects() -> Array[AreaRegion]:
	"""随机矩形划分"""
	
	var regions: Array[AreaRegion] = []
	var num_rects = rng.randi_range(8, 15)
	
	for i in range(num_rects):
		var width = rng.randi_range(4, 10)
		var height = rng.randi_range(4, 10)
		var x = rng.randi_range(0, max(1, GRID_WIDTH - width))
		var y = rng.randi_range(0, max(1, GRID_HEIGHT - height))
		
		var region = AreaRegion.new(Rect2i(x, y, width, height))
		region.type = "random_rect"
		region.density = rng.randf_range(0.2, 0.8)
		regions.append(region)
	
	return regions

# ============== 建筑物生成 ==============
func _generate_buildings_and_terrain():
	"""生成建筑物和地形"""
	
	if not building_layer:
		return
	
	# 如果building_layer有generate方法，调用它
	if building_layer.has_method("generate_content"):
		building_layer.generate_content()
	else:
		# 否则直接在这里生成
		_direct_generate_buildings()

func _direct_generate_buildings():
	"""直接生成建筑物（备用方法）"""
	
	for area in areas:
		if area.is_entrance:
			continue  # 跳过入口区域
		
		_generate_area_content(area)

func _generate_area_content(area: AreaRegion):
	"""为特定区域生成内容"""
	
	var bounds = area.bounds
	
	# 根据区域特征生成不同内容
	if "walls" in area.features:
		_generate_walls_in_area(bounds)
	elif "water" in area.features:
		_generate_water_in_area(bounds)
	elif "special" in area.features:
		_generate_special_feature(bounds)
	else:
		_generate_obstacles_in_area(bounds, area.density)

func _generate_walls_in_area(bounds: Rect2i):
	"""在区域内生成墙壁"""
	
	# 这里使用tile索引，需要根据你的tileset调整
	var wall_tile_id = 0  # 墙壁的tile ID
	var wall_atlas_coords = Vector2i(0, 0)  # 墙壁在图集中的位置
	
	# 生成区域边缘墙壁
	for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
		building_layer.set_cell(Vector2i(x, bounds.position.y), 0, wall_atlas_coords)
		building_layer.set_cell(Vector2i(x, bounds.position.y + bounds.size.y - 1), 0, wall_atlas_coords)
	
	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		building_layer.set_cell(Vector2i(bounds.position.x, y), 0, wall_atlas_coords)
		building_layer.set_cell(Vector2i(bounds.position.x + bounds.size.x - 1, y), 0, wall_atlas_coords)

func _generate_water_in_area(bounds: Rect2i):
	"""在区域内生成水域"""
	
	var water_atlas_coords = Vector2i(1, 0)  # 水的图集坐标
	
	# 生成不规则水域
	var center = Vector2(bounds.get_center())
	var radius = min(bounds.size.x, bounds.size.y) / 2
	
	for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
		for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			
			# 添加一些噪声使边缘不规则
			var noise = rng.randf_range(-2, 2)
			if distance + noise < radius:
				building_layer.set_cell(Vector2i(x, y), 0, water_atlas_coords)

func _generate_special_feature(bounds: Rect2i):
	"""生成特殊地形特征"""
	
	# 可以是祭坛、雕像、特殊装饰等
	var special_atlas_coords = Vector2i(2, 0)  # 特殊物体的图集坐标
	
	var center = bounds.get_center()
	building_layer.set_cell(center, 0, special_atlas_coords)

func _generate_obstacles_in_area(bounds: Rect2i, density: float):
	"""在区域内生成障碍物"""
	
	var obstacle_types = [
		Vector2i(3, 0),  # 石头
		Vector2i(4, 0),  # 树木
		Vector2i(5, 0),  # 箱子
	]
	
	var num_obstacles = int(bounds.get_area() * density * 0.1)
	
	for i in range(num_obstacles):
		var x = rng.randi_range(bounds.position.x, bounds.position.x + bounds.size.x - 1)
		var y = rng.randi_range(bounds.position.y, bounds.position.y + bounds.size.y - 1)
		var obstacle_type = obstacle_types[rng.randi() % obstacle_types.size()]
		
		building_layer.set_cell(Vector2i(x, y), 0, obstacle_type)

# ============== 工具函数 ==============
func _init_rng(seed_value: int):
	"""初始化随机数生成器"""
	
	rng = RandomNumberGenerator.new()
	if seed_value == -1:
		rng.randomize()
	else:
		rng.seed = seed_value

func _customize_floor_tiles():
	"""自定义地板tiles（可选）"""
	
	# 可以在这里添加一些随机的地板变化
	# 比如添加裂缝、血迹、装饰等
	pass

# ============== 获取信息 ==============
func get_walkable_tiles() -> Array[Vector2i]:
	"""获取所有可行走的tile位置"""
	
	var walkable = []
	
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			
			# 检查是否有建筑物阻挡
			if building_layer and building_layer.get_cell_source_id(pos) == -1:
				# 检查是否在入口区域
				var in_entrance = false
				for area in areas:
					if area.is_entrance and area.bounds.has_point(pos):
						in_entrance = true
						break
				
				if not in_entrance:
					walkable.append(pos)
	
	return walkable

func get_area_at_position(tile_pos: Vector2i) -> AreaRegion:
	"""获取指定位置所在的区域"""
	
	for area in areas:
		if area.bounds.has_point(tile_pos):
			return area
	
	return null
