# marker_component.gd
# 附加到Marker2D节点上的通用脚本
extends Marker2D
class_name SpawnMarker

@export var marker_data: MarkerData  ## Marker配置数据

func _ready():
	# 可选:在编辑器中显示标签
	if Engine.is_editor_hint() and marker_data:
		name = "%s_Marker" % marker_data.entity_type

func get_config() -> MarkerData:
	"""获取配置数据"""
	return marker_data

func is_valid() -> bool:
	"""检查配置是否有效"""
	return marker_data != null and marker_data.is_valid()

# 编辑器调试辅助
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	
	if marker_data == null:
		warnings.append("未设置marker_data资源")
	elif not marker_data.is_valid():
		warnings.append("marker_data配置无效: entity_type为空")
	
	return warnings
