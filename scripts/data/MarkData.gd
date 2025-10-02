# marker_data.gd
# Marker配置数据资源类
extends Resource
class_name MarkerData

## === 基础配置 ===
@export_group("基础配置")
@export var entity_type: String = "tree"  ## 实体类型(对应entity_pools的键)

@export_group("空间控制")
@export var size_limit: Vector2i = Vector2i(-1, -1)  ## 尺寸限制(-1,-1表示不限制)

## === 生成控制 ===
@export_group("生成控制")
@export_range(1, 999) var priority: int = 1  ## 生成优先级(数字越小越先处理)
@export_range(0.0, 1.0) var probability: float = 1.0  ## 生成概率

## === 场景选择 ===
@export_group("场景选择")
@export_enum("随机", "指定场景", "配对种子", "场景索引") var selection_mode: int = 0

@export_file("*.tscn") var explicit_scene: String = ""  ## 指定场景路径(selection_mode=1时使用)
@export var pair_seed: int = -1  ## 配对种子(selection_mode=2时使用, >0有效)
@export var scene_index: int = -1  ## 场景索引(selection_mode=3时使用, >=0有效)

## === 互斥组 ===
@export_group("互斥组配置")
@export var use_exclusive_group: bool = false  ## 是否使用互斥组
@export var exclusive_group: String = ""  ## 互斥组名称
@export var subgroup: String = ""  ## 子组名称(用于随机分组)
@export_range(1, 999) var group_limit: int = 10  ## 组内最大生成数量


## === 辅助方法 ===
func is_valid() -> bool:
	"""检查配置是否有效"""
	return not entity_type.is_empty()

func get_debug_info() -> String:
	"""获取调试信息"""
	var info = "[%s] " % entity_type
	
	if size_limit.x > 0:
		info += "size=%s " % size_limit
	
	if priority != 999:
		info += "priority=%d " % priority
	
	if probability < 1.0:
		info += "prob=%.2f " % probability
	
	match selection_mode:
		1: info += "explicit "
		2: info += "pair_seed=%d " % pair_seed
		3: info += "scene_index=%d " % scene_index
	
	if use_exclusive_group and not exclusive_group.is_empty():
		info += "group=%s" % exclusive_group
		if not subgroup.is_empty():
			info += "(%s)" % subgroup
		info += " limit=%d " % group_limit
	
	return info

func should_use_pair_seed() -> bool:
	"""是否应该使用配对种子"""
	return selection_mode == 2 and pair_seed > 0

func should_use_explicit_scene() -> bool:
	"""是否应该使用指定场景"""
	return selection_mode == 1 and not explicit_scene.is_empty()

func should_use_scene_index() -> bool:
	"""是否应该使用场景索引"""
	return selection_mode == 3 and scene_index >= 0
