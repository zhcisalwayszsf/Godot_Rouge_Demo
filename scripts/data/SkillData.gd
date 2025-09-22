#res://scripts/data/SkillData.gd
extends Resource
class_name SkillData

# 基础信息
@export_group("基础信息")
@export var skill_name: String = ""
@export var skill_display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""  # 技能图标路径
@export_enum("主技能", "副技能") var skill_type: int = 0

# 技能类型系统改进 - 支持多类型
@export_group("技能类型")
# 方案1：使用数组存储多个类型
#@export var skill_categories: Array[int] = []  # 0=伤害, 1=位移, 2=控制, 3=增益
# 方案2：使用位掩码
@export_flags("伤害", "位移", "控制", "增益") var skill_type_flags: int = 1

#基础参数
@export_group("基础参数")
@export var extra_damage: float = 0
@export var damage_multiplier: float = 1.0

# 消耗和冷却
@export_group("消耗和冷却")
@export var energy_cost: int = 0  # 主技能消耗能量
@export var cooldown_time: float = 1.0  # 副技能冷却时间(秒)
@export var cast_time: float = 0.0  # 施法时间
@export var skill_continue_time:float=0  #技能持续时间
@export var cast_anime: Animation

###技能效果###
###伤害和控制
"""作用敌人和玩家，共用部分参数"""
@export_group("伤害技能效果")
@export var damage: float = 0 #单次伤害量
@export_flags("一次性", "持续") var damage_method_flags: int = 1
@export var continue_damage: float = 0 # 持续伤害量
@export var continue_damage_time: float = 0 # 持续伤害持续时间
@export var continue_damage_frequent: float = 1 # 持续伤害频率-每秒伤害次数

@export var damage_target_numb: int = 0  #目标数量

@export var damage_distance: float = 0.0
@export_enum("直线型", "范围持续型", "中心瞬发型","范围随机型","子弹型") var action_type: int = 0
@export var line_width:float=50  #直线宽度
@export var area_duration_time:float=0  #持续型持续时间
@export var area_radius:float=0  #持续型半径
@export var area_duration_acting_tick:float=1 #持续型（范围或中心）的范围内作用频率，秒/次
@export_enum("中心持续","鼠标位置持续") var area_duration_acting_position:int = 0
@export var area_max_distance:float=400 #释放技能离玩家的最远距离
@export_enum("普通", "穿甲", "燃烧", "中毒", "百分百") var damage_type: int = 0

@export_group("控制技能效果")
@export var control_range: float = 0 # 技能作用范围
@export var control_target_numb: float = 0  #目标数量
@export_flags("速度", "攻击力", "护甲","受伤倍率", "击退(位移的长度)","眩晕") var control_effect_flags: int = 0
@export var control_continue_time: Array[float] = [0,0,0,0,0,0]  #持续时间
@export var control_value: Array[float] = [0,0,0,0,0,0] #数值



####位移和增益
"""仅作用玩家自身，共用部分参数"""
@export_group("位移技能效果")
@export var distance: float = 0
@export var dash_time: float = 0.0  # 位移需要的时间
@export var dash_effect_continue_time: float = 0.0  # 效果时间
@export_flags("无敌","无碰撞")var dash_effect_flags:int=0
@export_enum("位移","闪现") var dash_type:int =0

#增益类
@export_group("增益技能效果")
@export var can_multiplier: bool = false
@export_flags("攻击力", "护甲", "移速", "攻速","减伤","闪避","无敌","无碰撞","免控") var buff_flags: int = 0
@export var buff_value: Array[float] = [0,0,0,0,0,0,-1,-1,-1]
@export var buff_time: Array[float] = [0,0,0,0,0,0,0,0,0] # 持续时间
 # 0=攻击力, 1=防御力, 2=移速, 3=攻速, 4=特殊


# 特殊属性
@export_group("特殊属性")
@export var can_move_while_casting: bool = true
@export var piercing: bool = false  # 是否穿透
@export var special_effects: Array[String] = []  # 特殊效果列表

# 升级属性
@export_group("升级属性") 
@export var upgrade_damage_multiplier: float = 1 #伤害量系数
@export var upgrade_cd_mutiplier: float = 1 #cd减少系数
@export var max_level: int = 5 # 最大升级等级
@export var damage_per_level: int = 5 # 每级提升伤害量
@export var cd_reduction_per_level: float = 0.1 # 每级冷却减少量

# 伤害方法判断函数
func has_damage_method(type: int) -> bool:
	"""检查伤害方法是否包含指定方式（位掩码方式）"""
	return (damage_method_flags & (1 << type)) != 0
func add_damage_method(type: int):
	"""添加伤害方法"""
	damage_method_flags |= (1 << type)
func remove_damage_method(type: int):
	"""移除伤害方法"""
	damage_method_flags &= ~(1 << type)
func get_damage_methods() -> Array[int]:
	"""获取所有伤害方法"""
	var types: Array[int] = []
	var names: Array[String] = ["一次性", "持续"]
	for i in range(1):  # 0-1对应2种类型
		if has_damage_method(i):
			types.append(names[i])
	return types

# 位移方法判断函数
func has_movement_method(type: int) -> bool:
	"""检查伤害方法是否包含指定方式（位掩码方式）"""
	return (dash_effect_flags & (1 << type)) != 0
func add_movement_method(type: int):
	"""添加伤害方法"""
	dash_effect_flags |= (1 << type)
func remove_movement_method(type: int):
	"""移除伤害方法"""
	dash_effect_flags &= ~(1 << type)
func get_movement_methods() -> Array[int]:
	"""获取所有伤害方法"""
	var types: Array[int] = []
	var names: Array[String] = ["一次性", "持续"]
	for i in range(1):  # 0-1对应2种类型
		if has_movement_method(i):
			types.append(names[i])
	return types


# 控制方法判断函数
func has_control_effect_type(type: int) -> bool:
	"""检查是否包含指定控制类型（位掩码方式）"""
	return (control_effect_flags & (1 << type)) != 0
func add_control_effect_type(type: int):
	"""添加控制类型"""
	control_effect_flags |= (1 << type)
func remove_control_effect_type(type: int):
	"""移除控制类型"""
	control_effect_flags &= ~(1 << type)
func get_control_effect_type() -> Array[int]:
	"""获取所有控制类型"""
	var types: Array[int] = []
	var names: Array[String] = ["速度", "攻击力", "护甲","受伤倍率", "击退(位移的长度)","眩晕"]
	for i in range(5):  # 0-5对应6种类型
		if has_control_effect_type(i):
			types.append(names[i])
	return types
#设置各控制持续时间
func set_control_continue_time(control:int,value:float):
	if control<=5 and control>=0:
		control_continue_time[control]=value
	else:
		print("控制持续时间赋值失败：没有此控制")

#Buff判断函数
func has_buff_type(type: int) -> bool:
	"""检查是否包含指定buff类型（位掩码方式）"""
	return (buff_flags & (1 << type)) != 0
func add_buff_type(type: int):
	"""添加buff类型"""
	buff_flags |= (1 << type)
func remove_buff_type(type: int):
	"""移除buff类型"""
	buff_flags &= ~(1 << type)
func get_buff_type() -> Array[int]:
	"""获取所有控制类型"""
	var types: Array[int] = []
	var names: Array[String] = ["攻击力", "护甲", "移速", "攻速","减伤","闪避","无敌","无碰撞","免控"]
	for i in range(8):  # 0-8对应9型
		if has_buff_type(i):
			types.append(names[i])
	return types
#设置各buff伤害值
func set_buff_value(buff:int,value:float):
	if buff<=3 and buff>=0:
		buff_value[buff]=value
	else:
		print("buff赋值失败：没有此buff")
#设置各buff持续时间
func set_buff_time(buff:int,value:float):
	if buff<=4 and buff>=0:
		buff_time[buff]=value
	else:
		print("buff赋值失败：没有此buff")

# 技能类型判断函数
func has_skill_type(type: int) -> bool:
	"""检查技能是否包含指定类型（位掩码方式）"""
	return (skill_type_flags & (1 << type)) != 0

func add_skill_type(type: int):
	"""添加技能类型"""
	skill_type_flags |= (1 << type)

func remove_skill_type(type: int):
	"""移除技能类型"""
	skill_type_flags &= ~(1 << type)

func get_skill_types() -> Array[int]:
	"""获取所有技能类型"""
	var types: Array[int] = []
	for i in range(4):  # 0-3对应4种类型
		if has_skill_type(i):
			types.append(i)
	return types

func get_skill_type_names() -> Array[String]:
	"""获取技能类型名称"""
	var names: Array[String] = []
	var type_names = ["伤害", "位移", "控制", "增益"]
	for i in range(4):
		if has_skill_type(i):
			names.append(type_names[i])
	return names

# 技能类型常量
enum SkillCategory {
	DAMAGE = 0,    # 伤害
	MOVEMENT = 1,  # 位移
	CONTROL = 2,   # 控制
	BUFF = 3       # 增益
}
