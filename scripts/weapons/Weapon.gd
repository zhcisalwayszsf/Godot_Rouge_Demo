# Weapon.gd - 武器组件（仅负责节点引用和数据加载）
extends Area2D
class_name WeaponComponent

# 武器数据
var weapon_data: WeaponData

# 子节点引用 - 供WeaponSystem使用
@onready var weapon_sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var muzzle_point: Node2D = $MuzzlePoint if has_node("MuzzlePoint") else null
@onready var aim_point: Node2D = $AimPoint if has_node("AimPoint") else null
@onready var shell_eject_point: Node2D = $ShellEjectPoint if has_node("ShellEjectPoint") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

@export var weapon_ID:int
@export var weapon_name:String
func _init() -> void:
	#print("开始实例化武器")
	return
	
func _ready():
	if weapon_data:
		return
	load_weapon_data()

func load_weapon_data():
	"""自动加载武器数据 - 优先使用weapon_name，失败后尝试weapon_ID"""
	var data_path: String = ""
	var weapon_info: Dictionary = {}
	
	# 第一步：尝试通过 weapon_name 查找
	if weapon_name and not weapon_name.is_empty():
		weapon_info = WeaponList.get_weapon_by_name(weapon_name)
		if weapon_info.has("data_path"):
			data_path = weapon_info["data_path"]
			print("通过武器名称找到数据路径: ", weapon_name, " -> ", data_path)
		else:
			print("警告: 通过名称 '", weapon_name, "' 未找到武器数据，尝试使用ID查找...")
	
	# 第二步：如果通过名称查找失败，尝试通过 weapon_ID 查找
	if data_path.is_empty() and weapon_ID > 0:
		weapon_info = WeaponList.get_weapon_by_id(weapon_ID)
		if weapon_info.has("data_path"):
			data_path = weapon_info["data_path"]
			print("通过武器ID找到数据路径: ", weapon_ID, " -> ", data_path)
			# 如果通过ID找到了，更新weapon_name
			if weapon_info.has("name"):
				weapon_name = weapon_info["name"]
				print("已自动更新武器名称为: ", weapon_name)
		else:
			print("警告: 通过ID '", weapon_ID, "' 也未找到武器数据")
	
	# 第三步：如果两种方式都失败，创建后备数据
	if data_path.is_empty():
		print("错误: 无法通过名称 '", weapon_name, "' 或ID '", weapon_ID, "' 找到武器数据，使用后备数据")
		create_fallback_weapon_data()
		return
	
	# 第四步：尝试加载找到的数据路径
	if ResourceLoader.exists(data_path):
		var loaded_data = load(data_path)
		if loaded_data and loaded_data is WeaponData:
			weapon_data = loaded_data
			print("✓ 成功加载武器数据: ", data_path)
			
			# 确保 weapon_data 有正确的名称和ID
			if weapon_data.weapon_name.is_empty():
				weapon_data.weapon_name = weapon_name if not weapon_name.is_empty() else data_path.get_file().get_basename()
			
			# 同步武器组件的属性
			if weapon_info.has("id"):
				weapon_ID = weapon_info["id"]
			if weapon_info.has("name"):
				weapon_name = weapon_info["name"]
		else:
			print("错误: 加载的资源不是有效的WeaponData: ", data_path)
			create_fallback_weapon_data()
	else:
		print("错误: 武器数据文件不存在: ", data_path)
		create_fallback_weapon_data()

func create_fallback_weapon_data():
	"""创建后备武器数据"""
	weapon_data = WeaponData.new()
	weapon_data.weapon_name = "未知武器"
	weapon_data.weapon_display_name = "未知武器"
	weapon_data.base_damage = 10
	weapon_data.fire_rate = 1.0
	weapon_data.magazine_size = 30
	weapon_data.current_magazine_ammo = 30
	print("创建后备武器数据: ", weapon_data.weapon_name)

# === 手动设置武器数据的方法 ===

func set_weapon_data(data: WeaponData):
	"""手动设置武器数据（用于从外部传入已加载的数据）"""
	if data and data is WeaponData:
		weapon_data = data
		print("手动设置武器数据: ", weapon_data.weapon_name)
	else:
		print("错误: 传入的不是有效的WeaponData")
		create_fallback_weapon_data()

func set_weapon_data_from_path(data_path: String):
	"""从指定路径加载武器数据"""
	if ResourceLoader.exists(data_path):
		var loaded_data = load(data_path)
		if loaded_data and loaded_data is WeaponData:
			weapon_data = loaded_data
			print("从路径加载武器数据: ", data_path)
		else:
			print("错误: 指定路径的资源不是有效的WeaponData: ", data_path)
			create_fallback_weapon_data()
	else:
		print("错误: 指定路径的武器数据不存在: ", data_path)
		create_fallback_weapon_data()

# === 获取器方法 - 供WeaponSystem调用 ===

func get_weapon_data() -> WeaponData:
	"""获取武器数据"""
	if not weapon_data:
		# 第一次尝试加载
		load_weapon_data()
		if not weapon_data:
			print("严重错误: 无法获取weapon_data，创建后备数据")
			create_fallback_weapon_data()
	return weapon_data

func has_weapon_data() -> bool:
	"""检查是否有有效的武器数据"""
	return weapon_data != null and weapon_data is WeaponData

func get_muzzle_position() -> Vector2:
	return muzzle_point.global_position if muzzle_point else global_position

func get_muzzle_direction() -> Vector2:
	return global_transform.x

func get_shell_eject_position() -> Vector2:
	return shell_eject_point.global_position if shell_eject_point else global_position

func get_weapon_sprite() -> Sprite2D:
	return weapon_sprite

# === 运行时参数修改接口 ===

func modify_damage(new_damage: int):
	"""动态修改伤害值"""
	if weapon_data:
		weapon_data.base_damage = new_damage
		print("修改武器伤害: ", weapon_data.weapon_name, " -> ", new_damage)

func modify_fire_rate(new_rate: float):
	"""动态修改射速"""
	if weapon_data:
		weapon_data.fire_rate = new_rate
		print("修改武器射速: ", weapon_data.weapon_name, " -> ", new_rate)

func add_special_effect(effect: String):
	"""动态添加特殊效果"""
	if weapon_data and effect not in weapon_data.special_effects:
		weapon_data.special_effects.append(effect)
		print("添加特殊效果: ", weapon_data.weapon_name, " -> ", effect)

func set_weapon_visibility(p_visible: bool):
	"""设置武器可见性"""
	self.visible = p_visible

# === 调试方法 ===

func debug_print_weapon_info():
	"""调试打印武器信息"""
	print("=== 武器组件调试信息 ===")
	print("节点名称: ", name)
	print("场景文件路径: ", scene_file_path)
	if weapon_data:
		print("武器名称: ", weapon_data.weapon_name)
		print("显示名称: ", weapon_data.weapon_display_name)
		print("基础伤害: ", weapon_data.base_damage)
		print("射速: ", weapon_data.fire_rate)
		print("弹夹容量: ", weapon_data.magazine_size)
		print("当前弹药: ", weapon_data.current_magazine_ammo)
	else:
		print("警告: weapon_data 为空!")
	print("=======================")

# === 拾取相关方法 ===

func disable_pickup_collision():
	"""禁用拾取碰撞（当被拾取时调用）"""
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func on_picked_up():
	"""被拾取时的回调方法"""
	print("武器被拾取: ", weapon_data.weapon_name if weapon_data else "未知武器")
