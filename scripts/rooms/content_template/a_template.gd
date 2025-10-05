# a_star_pattern_v3.gd
# A类模板：适配Resource配置系统
extends TileMapLayer

static var DEBUG_MODE = true

const FALLBACK_SCENE = "res://scenes/rooms/normal_rooms/content_layer/spring/Natural_Objects/stone001.tscn"

@export var max_spawn: int = 10
@export var entity_pools: Dictionary
@export_enum("春原","沙漠","雨林","地牢","海岸") var theme: int = 0

var rng: RandomNumberGenerator
var entity_layer: Node2D
var spawn_counts: Dictionary = {}
var global_seed_offset: int = 0
var exclusive_group_counts: Dictionary = {}
var selected_subgroups: Dictionary = {}

func _ready():
	var theme_path: String
	match theme:
		0: theme_path = "res://scripts/rooms/objectslist/A/spring_list.gd" ##春原
		1: theme_path = "res://scripts/rooms/objectslist/A/spring_list.gd" ##沙漠
		2: theme_path = "res://scripts/rooms/objectslist/A/spring_list.gd" ##雨林
		3: theme_path = "res://scripts/rooms/objectslist/A/spring_list.gd" ##地牢
		4: theme_path = "res://scripts/rooms/objectslist/A/spring_list.gd" ##海岸
	
	entity_pools = load(theme_path).entity_pools
	rng = RandomNumberGenerator.new()
	rng.randomize()
	populate()

func populate(room_type = null): ##主生成方法
	"""主生成方法"""
	print("[A类-Resource版] 开始生成内容")
	
	entity_layer = get_node_or_null("EntityLayer")
	if not entity_layer:
		push_error("A类模板缺少EntityLayer节点")
		return
	
	spawn_counts.clear()
	exclusive_group_counts.clear()
	selected_subgroups.clear()
	
	global_seed_offset = rng.randi()
	
	# 收集所有SpawnMarker
	var all_markers = _collect_all_markers()
	
	if all_markers.is_empty():
		print("    [警告] 未找到任何SpawnMarker")
		return
	
	# 预处理互斥组
	_preprocess_exclusive_groups_v3(all_markers)
	
	# 按优先级排序
	all_markers.sort_custom(func(a, b): 
		var data_a = a.get_config()
		var data_b = b.get_config()
		return data_a.priority < data_b.priority
	)
	
	# 生成实体
	for marker in all_markers:
		_spawn_at_marker_v3(marker)
	
	print("  [A类-Resource版] 内容生成完成")

func _collect_all_markers() -> Array[SpawnMarker]:
	"""收集所有有效的SpawnMarker"""
	var markers: Array[SpawnMarker] = []
	
	for child in entity_layer.get_children():
		if child is Node2D:
			_collect_markers_recursive(child, markers)
	
	if DEBUG_MODE:
		print("    [收集] 找到 %d 个SpawnMarker" % markers.size())
	
	return markers

func _collect_markers_recursive(node: Node, markers: Array[SpawnMarker]):
	"""递归收集Marker"""
	for child in node.get_children():
		if child is SpawnMarker and child.is_valid():
			markers.append(child)
		elif child.get_child_count() > 0:
			_collect_markers_recursive(child, markers)



func _preprocess_exclusive_groups_v3(markers: Array[SpawnMarker]):
	"""预处理互斥组，随机选择子组"""
	var group_subgroups: Dictionary = {}
	
	for marker in markers:
		var data = marker.get_config()
		
		if not data.use_exclusive_group or data.exclusive_group.is_empty():
			continue
		
		if not data.subgroup.is_empty():
			var group_name = data.exclusive_group
			
			if group_name not in group_subgroups:
				group_subgroups[group_name] = []
			
			if data.subgroup not in group_subgroups[group_name]:
				group_subgroups[group_name].append(data.subgroup)
	
	# 为每个组随机选择子组
	for group_name in group_subgroups.keys():
		var subgroups = group_subgroups[group_name]
		if not subgroups.is_empty():
			var selected = subgroups[rng.randi() % subgroups.size()]
			selected_subgroups[group_name] = selected
			
			if DEBUG_MODE:
				print("    [子组选择] 组'%s'选中子组'%s' (可选: %s)" % [
					group_name, selected, subgroups
				])

func _spawn_at_marker_v3(marker: SpawnMarker):
	"""在Marker位置生成实体 (Resource版本)"""
	var data = marker.get_config()
	
	# 1. 子组过滤
	if data.use_exclusive_group and not data.subgroup.is_empty():
		var group_name = data.exclusive_group
		
		if group_name in selected_subgroups:
			var selected = selected_subgroups[group_name]
			
			if data.subgroup != selected:
				if DEBUG_MODE:
					print("    [子组过滤] %s 跳过: 子组'%s'未选中(选中'%s')" % [
						marker.name, data.subgroup, selected
					])
				return
	
	# 2. 互斥组限制检查
	if data.use_exclusive_group and not data.exclusive_group.is_empty():
		var current_count = exclusive_group_counts.get(data.exclusive_group, 0)
		
		if current_count >= data.group_limit:
			if DEBUG_MODE:
				print("    [互斥组] %s 跳过: 组'%s'已达限制(%d/%d)" % [
					marker.name, data.exclusive_group, current_count, data.group_limit
				])
			return
	
	# 3. 类型数量检查
	if not _can_spawn_type(data.entity_type):
		return
	
	# 4. 概率判定
	if rng.randf() > data.probability:
		return
	
	# 5. 场景选择
	var scene_path = _select_scene_for_marker_v3(marker, data)
	if scene_path.is_empty():
		return
	
	# 6. 实例化
	var entity_scene = load(scene_path)
	if not entity_scene:
		push_warning("无法加载场景: %s" % scene_path)
		return
	
	var entity_instance = entity_scene.instantiate()
	
	# 7. 放置到容器
	var container_name = _get_container_for_type(data.entity_type)
	var container = entity_layer.get_node_or_null(container_name)
	
	if not container:
		container = Node2D.new()
		container.name = container_name
		entity_layer.add_child(container)
	
	entity_instance.position = marker.position
	container.add_child(entity_instance)
	
	# 8. 更新计数
	spawn_counts[data.entity_type] = spawn_counts.get(data.entity_type, 0) + 1
	
	if data.use_exclusive_group and not data.exclusive_group.is_empty():
		exclusive_group_counts[data.exclusive_group] = \
			exclusive_group_counts.get(data.exclusive_group, 0) + 1
		
		if DEBUG_MODE:
			print("    [生成] %s: %s (组'%s': %d/%d)" % [
				marker.name, data.entity_type, data.exclusive_group,
				exclusive_group_counts[data.exclusive_group], data.group_limit
			])

func _select_scene_for_marker_v3(marker: SpawnMarker, data: MarkerData) -> String:
	"""为Marker选择场景 (Resource版本)"""
	if data.entity_type not in entity_pools:
		return ""
	
	var scenes = entity_pools[data.entity_type].scenes
	if scenes.is_empty():
		return ""
	
	# 尺寸过滤
	var filtered_scenes = _filter_scenes_by_size(scenes, data.size_limit)
	
	if filtered_scenes.is_empty():
		if DEBUG_MODE:
			print("    [尺寸不匹配] %s: 无匹配尺寸 %s，使用替代" % [
				marker.name, data.size_limit
			])
		return FALLBACK_SCENE
	
	# 优先级1: explicit_scene
	if data.should_use_explicit_scene():
		if data.size_limit.x > 0:
			var scene_size = _get_scene_size(data.explicit_scene, scenes)
			if scene_size.x > 0 and scene_size != data.size_limit:
				if DEBUG_MODE:
					print("    [尺寸检查] explicit_scene尺寸不匹配，使用替代")
				return FALLBACK_SCENE
		return data.explicit_scene
	
	# 优先级2: pair_seed
	if data.should_use_pair_seed():
		var final_seed = data.pair_seed + global_seed_offset
		var pair_rng = RandomNumberGenerator.new()
		pair_rng.seed = final_seed
		var index = pair_rng.randi() % filtered_scenes.size()
		
		if DEBUG_MODE:
			print("    [配对] %s: seed=%d → 索引%d" % [
				marker.name, data.pair_seed, index
			])
		
		return filtered_scenes[index].path
	
	# 优先级3: scene_index
	if data.should_use_scene_index():
		if data.scene_index < filtered_scenes.size():
			return filtered_scenes[data.scene_index].path
	
	# 默认：随机
	var selected = filtered_scenes[rng.randi() % filtered_scenes.size()]
	return selected.path

func _can_spawn_type(entity_type: String) -> bool:
	"""检查是否还能生成该类型"""
	if entity_type not in entity_pools:
		return false
	
	var current_count = spawn_counts.get(entity_type, 0)
	var max_count = entity_pools[entity_type].max_count
	
	return current_count < max_count

func _get_container_for_type(entity_type: String) -> String:
	"""根据类型获取容器名称"""
	if entity_type in entity_pools:
		return entity_pools[entity_type].get("container", "Objects")
	return "Objects"

func _filter_scenes_by_size(scenes: Array, size_limit: Vector2i) -> Array:
	"""根据尺寸限制过滤场景列表"""
	if size_limit.x <= 0 or size_limit.y <= 0:
		return scenes
	
	var exact_matches = []
	
	for scene_data in scenes:
		if scene_data.size == size_limit:
			exact_matches.append(scene_data)
	
	return exact_matches

func _get_scene_size(scene_path: String, scenes: Array) -> Vector2i:
	"""获取场景尺寸"""
	for scene_data in scenes:
		if scene_data.path == scene_path:
			return scene_data.size
	return Vector2i(-1, -1)
