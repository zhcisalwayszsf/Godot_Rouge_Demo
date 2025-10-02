#@tool
extends TileMapLayer
var tile_set_pack:TileMapLayer
# 季节枚举 - 对应 TileSet 源的 ID

enum LevelTheme {
	Spring_Filed = 0,
	Desert = 1,
	Dung= 2,
	Beach = 3
}

# 导出变量 - 可在编辑器中调整
@export var level_theme: LevelTheme = LevelTheme.Spring_Filed
@export_range(0.1, 5.0, 0.1) var density: float = 1.0  # 密度调整

# 常量定义
const RECT_WIDTH = 800 # 矩形宽度(像素)
const RECT_HEIGHT = 480  # 矩形高度(像素)
const TILE_SIZE = 16  # 单个瓦片大小(像素)

# 泊松采样参数
const MAX_ATTEMPTS = 30  # 每个点的最大尝试次数

func _init() -> void:
	tile_set_pack = preload("res://scenes/rooms/normal_rooms/floor_layers/tile_scene.tscn").instantiate()
	add_child(tile_set_pack)
func _ready():
	if Engine.is_editor_hint():
		return
	generate_tiles()

# 主生成函数
func generate_tiles():
	tile_set_pack.clear()  # 清除现有瓦片
	
	# 计算网格尺寸
	var grid_width = RECT_WIDTH / TILE_SIZE  # 54 格
	var grid_height = RECT_HEIGHT / TILE_SIZE  # 34 格
	
	# 获取选定源的所有可用瓦片
	var available_tiles = get_available_tiles_from_source(level_theme)
	if available_tiles.is_empty():
		push_warning("没有找到可用的瓦片!")
		return
	
	# 计算最小距离(根据密度调整)
	var min_distance = 2.0 / density
	
	# 执行泊松采样
	var sample_points = poisson_disk_sampling(grid_width, grid_height, min_distance)
	
	# 在采样点放置瓦片
	for point in sample_points:
		# 转换为以中心为原点的坐标
		var tile_x = int(point.x - grid_width / 2.0)
		var tile_y = int(point.y - grid_height / 2.0)
		
		# 随机选择一个瓦片
		var random_tile = available_tiles[randi() % available_tiles.size()]
		
		# 放置瓦片
		tile_set_pack.set_cell(Vector2i(tile_x, tile_y), level_theme, random_tile)

# 获取指定源的所有可用瓦片坐标
func get_available_tiles_from_source(source_id: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var p_tile_set = tile_set_pack.tile_set
	
	if p_tile_set == null:
		push_warning("TileSet 未设置!")
		return tiles
	
	# 检查源是否存在
	if p_tile_set.get_source_count() <= source_id:
		push_warning("源 ID %d 不存在!" % source_id)
		return tiles
	
	# 获取 TileSetSource
	var source = p_tile_set.get_source(source_id)
	if source == null:
		push_warning("无法获取源 ID %d!" % source_id)
		return tiles
	
	# 如果是 TileSetAtlasSource
	if source is TileSetAtlasSource:
		var atlas_source = source as TileSetAtlasSource
		var texture_region_size = atlas_source.texture_region_size
		var atlas_size = atlas_source.get_atlas_grid_size()
		
		# 遍历图集中的所有格子
		for y in range(atlas_size.y):
			for x in range(atlas_size.x):
				var coord = Vector2i(x, y)
				# 检查该坐标是否有瓦片
				if atlas_source.has_tile(coord):
					tiles.append(coord)
	
	return tiles

# 泊松圆盘采样算法
func poisson_disk_sampling(width: float, height: float, min_dist: float) -> Array:
	var cell_size = min_dist / sqrt(2.0)
	var grid_width = ceil(width / cell_size)
	var grid_height = ceil(height / cell_size)
	
	# 初始化网格
	var grid = []
	for i in range(grid_width * grid_height):
		grid.append(-1)
	
	var active_list = []
	var points = []
	
	# 添加初始点
	var first_point = Vector2(randf() * width, randf() * height)
	var first_index = points.size()
	points.append(first_point)
	active_list.append(first_index)
	
	var grid_x = int(first_point.x / cell_size)
	var grid_y = int(first_point.y / cell_size)
	grid[grid_x + grid_y * grid_width] = first_index
	
	# 主循环
	while not active_list.is_empty():
		var random_index = randi() % active_list.size()
		var point_index = active_list[random_index]
		var point = points[point_index]
		var found = false
		
		# 尝试生成新点
		for i in range(MAX_ATTEMPTS):
			var angle = randf() * TAU
			var radius = min_dist + randf() * min_dist
			var new_point = point + Vector2(cos(angle), sin(angle)) * radius
			
			# 检查是否在范围内
			if new_point.x < 0 or new_point.x >= width or new_point.y < 0 or new_point.y >= height:
				continue
			
			# 检查是否与其他点太近
			if is_valid_point(new_point, width, height, cell_size, min_dist, points, grid, grid_width):
				found = true
				var new_index = points.size()
				points.append(new_point)
				active_list.append(new_index)
				
				var new_grid_x = int(new_point.x / cell_size)
				var new_grid_y = int(new_point.y / cell_size)
				grid[new_grid_x + new_grid_y * grid_width] = new_index
				break
		
		if not found:
			active_list.remove_at(random_index)
	
	return points

# 检查点是否有效
func is_valid_point(point: Vector2, width: float, height: float, cell_size: float, 
					min_dist: float, points: Array, grid: Array, grid_width: int) -> bool:
	var grid_x = int(point.x / cell_size)
	var grid_y = int(point.y / cell_size)
	
	# 检查周围的格子
	var search_start_x = max(0, grid_x - 2)
	var search_end_x = min(grid_width - 1, grid_x + 2)
	var search_start_y = max(0, grid_y - 2)
	var grid_height = grid.size() / grid_width
	var search_end_y = min(grid_height - 1, grid_y + 2)
	
	for y in range(search_start_y, search_end_y + 1):
		for x in range(search_start_x, search_end_x + 1):
			var index = grid[x + y * grid_width]
			if index != -1:
				var other_point = points[index]
				if point.distance_to(other_point) < min_dist:
					return false
	
	return true

# 在编辑器中可以手动触发重新生成
func regenerate():
	generate_tiles()
