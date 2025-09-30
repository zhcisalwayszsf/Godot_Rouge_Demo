# a_star_pattern.gd
# A类模板：精心设计的布局 + 半随机生成
extends TileMapLayer


static var DEBUG_MODE = true

"""
场景结构:
AStarPattern (TileMapLayer) [此脚本]
  └─ EntityLayer (Node2D)
		├─ NaturalSpawns (Node2D)      # 自然物生成点容器
		│     ├─ Spawn1 (Marker2D)
		│     └─ Spawn2 (Marker2D)
		├─ DecoSpawns (Node2D)         # 装饰物生成点容器
		│     └─ Spawn1 (Marker2D)
		├─ NaturalThings (Node2D)      # 自然物容器（运行时填充）
		└─ Objects (Node2D)            # 可破坏物/装饰物容器（运行时填充）
"""

# 尺寸不匹配时的替代场景（1x1小物体，兼容性高）
const FALLBACK_SCENE = "res://scenes/rooms/normal_rooms/content_layer/spring/Natural_Objects/stone001.tscn"

# 实体资源池（新结构：包含尺寸信息）

@export var max_spawn: int = 10
@export var entity_pools:Dictionary
@export_enum("春原","沙漠","雨林","地牢","海岸") var theme:int=0

var rng: RandomNumberGenerator
var entity_layer: Node2D
var spawn_counts: Dictionary = {}
var global_seed_offset: int = 0
var exclusive_group_counts: Dictionary = {}
var selected_subgroups: Dictionary = {}

func _ready():
	var theme_path:String
	match  theme:
		0:
			theme_path = "res://scripts/rooms/objectslist/spring_list.gd"
		1:
			theme_path = "res://scripts/rooms/objectslist/spring_list.gd"
		2:
			theme_path = "res://scripts/rooms/objectslist/spring_list.gd"
		3:
			theme_path = "res://scripts/rooms/objectslist/spring_list.gd"
	entity_pools = load(theme_path).entity_pools
	rng = RandomNumberGenerator.new()
	rng.randomize()
	populate()
func populate(floor_level: int = 1, room_type = null):
	"""主生成方法 - 由Level_Manager调用"""
	print("  [A类] 开始生成内容")
	
	entity_layer = get_node_or_null("EntityLayer")
	if not entity_layer:
		push_error("A类模板缺少EntityLayer节点")
		return
	
	spawn_counts.clear()
	exclusive_group_counts.clear()
	selected_subgroups.clear()
	
	global_seed_offset = rng.randi()
	
	_adjust_for_floor_level(floor_level)
	
	# 处理自然物生成点
	_process_spawn_group("NaturalSpawns")
	
	# 处理装饰物生成点
	_process_spawn_group("DecoSpawns")
	
	# 清理Marker容器
	_cleanup_markers()
	
	print("  [A类] 内容生成完成")

func _adjust_for_floor_level(floor_level: int):
	"""根据楼层调整生成密度"""
	var density_multiplier = 1.0 + (floor_level * 0.1)
	
	for type in entity_pools.keys():
		var base_max = entity_pools[type].max_count
		entity_pools[type].max_count = int(base_max * density_multiplier)

func _process_spawn_group(group_name: String):
	"""处理指定生成点组"""
	var spawn_group = entity_layer.get_node_or_null(group_name)
	if not spawn_group:
		return
	
	var markers = []
	for child in spawn_group.get_children():
		if child is Marker2D:
			var priority = child.get_meta("priority", 999)
			markers.append({"marker": child, "priority": priority})
	
	_preprocess_exclusive_groups(markers)
	markers.sort_custom(func(a, b): return a.priority < b.priority)
	
	for item in markers:
		var marker = item.marker as Marker2D
		_spawn_at_marker(marker)

func _preprocess_exclusive_groups(markers: Array):
	"""预处理互斥组，随机选择子组"""
	var group_subgroups: Dictionary = {}
	
	for item in markers:
		var marker = item.marker as Marker2D
		if marker.has_meta("exclusive_group"):
			var group_name = marker.get_meta("exclusive_group", "")
			if group_name.is_empty():
				continue
			
			if marker.has_meta("subgroup"):
				var subgroup = marker.get_meta("subgroup", "")
				if not subgroup.is_empty():
					if group_name not in group_subgroups:
						group_subgroups[group_name] = []
					
					if subgroup not in group_subgroups[group_name]:
						group_subgroups[group_name].append(subgroup)
	
	for group_name in group_subgroups.keys():
		var subgroups = group_subgroups[group_name]
		if not subgroups.is_empty():
			var selected = subgroups[rng.randi() % subgroups.size()]
			selected_subgroups[group_name] = selected
			
			if DEBUG_MODE:
				print("    [子组选择] 互斥组'%s'随机选中子组'%s' (可选: %s)" % [
					group_name, selected, subgroups
				])

func _spawn_at_marker(marker: Marker2D):
	"""在Marker位置生成实体"""
	
	# 检查子组过滤
	if marker.has_meta("exclusive_group") and marker.has_meta("subgroup"):
		var group_name = marker.get_meta("exclusive_group", "")
		var subgroup = marker.get_meta("subgroup", "")
		
		if not group_name.is_empty() and not subgroup.is_empty():
			if group_name in selected_subgroups:
				var selected = selected_subgroups[group_name]
				
				if subgroup != selected:
					if DEBUG_MODE:
						print("    [子组过滤] %s 跳过: 子组'%s'未被选中(选中的是'%s')" % [
							marker.name, subgroup, selected
						])
					return
	
	# 检查互斥组限制
	if marker.has_meta("exclusive_group"):
		var group_name = marker.get_meta("exclusive_group", "")
		var group_limit = marker.get_meta("group_limit", 999)
		
		if not group_name.is_empty():
			var current_count = exclusive_group_counts.get(group_name, 0)
			
			if current_count >= group_limit:
				if DEBUG_MODE:
					print("    [互斥组] %s 跳过: 组'%s'已达到限制(%d/%d)" % [
						marker.name, group_name, current_count, group_limit
					])
				return
	
	var entity_type = marker.get_meta("type", "tree")
	
	if not _can_spawn_type(entity_type):
		return
	
	var spawn_probability = marker.get_meta("probability", 1.0)
	if rng.randf() > spawn_probability:
		return
	
	var scene_path = _select_scene_for_marker(marker, entity_type)
	if scene_path.is_empty():
		return
	
	var entity_scene = load(scene_path)
	if not entity_scene:
		push_warning("无法加载场景: %s" % scene_path)
		return
	
	var entity_instance = entity_scene.instantiate()
	
	# 根据类型获取容器名称
	var container_name = _get_container_for_type(entity_type)
	var container = entity_layer.get_node_or_null(container_name)
	
	if not container:
		container = Node2D.new()
		container.name = container_name
		entity_layer.add_child(container)
	
	entity_instance.position = marker.position
	container.add_child(entity_instance)
	
	spawn_counts[entity_type] = spawn_counts.get(entity_type, 0) + 1
	
	if marker.has_meta("exclusive_group"):
		var group_name = marker.get_meta("exclusive_group", "")
		if not group_name.is_empty():
			exclusive_group_counts[group_name] = exclusive_group_counts.get(group_name, 0) + 1
			
			if DEBUG_MODE:
				print("    [互斥组] %s 已生成: 组'%s'计数 %d/%d" % [
					marker.name, 
					group_name,
					exclusive_group_counts[group_name],
					marker.get_meta("group_limit", 999)
				])

func _get_container_for_type(entity_type: String) -> String:
	"""根据类型获取容器名称"""
	if entity_type in entity_pools:
		return entity_pools[entity_type].get("container", "Objects")
	return "Objects"

func _can_spawn_type(entity_type: String) -> bool:
	"""检查是否还能生成该类型"""
	if entity_type not in entity_pools:
		return false
	
	var current_count = spawn_counts.get(entity_type, 0)
	var max_count = entity_pools[entity_type].max_count
	
	return current_count < max_count

func _select_scene_for_marker(marker: Marker2D, entity_type: String) -> String:
	"""为Marker选择场景（支持配对种子，自动降级，尺寸过滤）"""
	if entity_type not in entity_pools:
		return ""
	
	var scenes = entity_pools[entity_type].scenes
	if scenes.is_empty():
		return ""
	
	var size_limit = Vector2i(-1, -1)
	if marker.has_meta("size"):
		var meta_size = marker.get_meta("size")
		if meta_size is Vector2i:
			size_limit = meta_size
		elif meta_size is Vector2:
			size_limit = Vector2i(int(meta_size.x), int(meta_size.y))
		elif meta_size is String:
			var parts = meta_size.split(",")
			if parts.size() == 2:
				size_limit = Vector2i(int(parts[0]), int(parts[1]))
	
	var filtered_scenes = _filter_scenes_by_size(scenes, size_limit)
	
	if filtered_scenes.is_empty():
		if DEBUG_MODE:
			print("    [尺寸不匹配] %s: 无匹配尺寸 %s 的场景，使用替代场景" % [marker.name, size_limit])
		return FALLBACK_SCENE
	
	# 优先级1: explicit_scene
	if marker.has_meta("explicit_scene"):
		var explicit_path = marker.get_meta("explicit_scene", "")
		if not explicit_path.is_empty():
			if size_limit.x > 0:
				var scene_size = _get_scene_size(explicit_path, scenes)
				if scene_size.x > 0 and scene_size != size_limit:
					if DEBUG_MODE:
						print("    [尺寸检查] explicit_scene尺寸不匹配: %s != %s，使用替代" % [scene_size, size_limit])
					return FALLBACK_SCENE
			return explicit_path
	
	# 优先级2: pair_seed
	if marker.has_meta("pair_seed"):
		var pair_seed = marker.get_meta("pair_seed", -1)
		if pair_seed > 0:
			var final_seed = pair_seed + global_seed_offset
			var pair_rng = RandomNumberGenerator.new()
			pair_rng.seed = final_seed
			var index = pair_rng.randi() % filtered_scenes.size()
			
			if DEBUG_MODE:
				print("    [配对+尺寸] %s: seed=%d → 索引%d, 尺寸%s" % [
					marker.name, pair_seed, index, filtered_scenes[index].size
				])
			
			return filtered_scenes[index].path
	
	# 优先级3: scene_index
	if marker.has_meta("scene_index"):
		var index = marker.get_meta("scene_index", -1)
		if index >= 0 and index < filtered_scenes.size():
			return filtered_scenes[index].path
	
	# 默认：随机选择
	var selected = filtered_scenes[rng.randi() % filtered_scenes.size()]
	return selected.path

func _filter_scenes_by_size(scenes: Array, size_limit: Vector2i) -> Array:
	"""根据尺寸限制过滤场景列表（只保留完全匹配的）"""
	
	if size_limit.x <= 0 or size_limit.y <= 0:
		return scenes
	
	var exact_matches = []
	
	for scene_data in scenes:
		var scene_size = scene_data.size
		
		if scene_size == size_limit:
			exact_matches.append(scene_data)
	
	if DEBUG_MODE and not exact_matches.is_empty():
		print("      [尺寸匹配] 找到 %d 个完全匹配 %s 的场景" % [exact_matches.size(), size_limit])
	
	return exact_matches

func _get_scene_size(scene_path: String, scenes: Array) -> Vector2i:
	"""从场景列表中获取指定路径的尺寸"""
	for scene_data in scenes:
		if scene_data.path == scene_path:
			return scene_data.size
	return Vector2i(-1, -1)

func _cleanup_markers():
	"""清理所有Marker容器"""
	if not entity_layer:
		return
	
	var natural_spawns = entity_layer.get_node_or_null("NaturalSpawns")
	if natural_spawns:
		natural_spawns.queue_free()
	
	var deco_spawns = entity_layer.get_node_or_null("DecoSpawns")
	if deco_spawns:
		deco_spawns.queue_free()
	
	print("    清理完成 - 已删除Marker容器")
