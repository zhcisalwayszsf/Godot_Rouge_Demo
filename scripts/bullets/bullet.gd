# res://scenes/bullets/Bullet.gd
extends Area2D
class_name Bullet

signal returned_to_pool(bullet)

# 内部类：用于封装子弹的运行时数据
class BulletData:
	var damage: float = 0
	var damage_type:int= 0
	var damage_method:int =0
	var travel_range: float = 0
	var size:float=1
	var speed: float = 0
	var direction: Vector2 = Vector2.ZERO
	var special_info: Dictionary = {}
	var start_position: Vector2   #子弹的起始位置

var bullet_data: BulletData = BulletData.new()


func _process(delta):
	# 使用内部类的数据进行移动和检查
	position += bullet_data.direction * bullet_data.speed * delta
	
	# 检查是否超出射程，现在直接使用内部数据
	if (position - bullet_data.start_position).length() > bullet_data.travel_range:
		return_to_pool()
	
func initialize(p_data: BulletData,source:int=0):
	"""使用传入的 BulletData 初始化子弹"""
	self.bullet_data = p_data
	
	# 设置子弹的初始位置和旋转
	position = p_data.start_position
	rotation = p_data.direction.angle()
	scale = Vector2(bullet_data.size,bullet_data.size)
	# 激活子弹
	self.visible = true
	set_process(true)
	match source:
		0:
			collision_layer = 16 #第5层
			collision_mask = 78 #检测2\3\4\7
		1:
			collision_layer = 128 #第8层
			collision_mask = 77 #检测1\3\4\7
		2:
			collision_layer = 128 #第8层
			collision_mask = 15 #检测1\2\3\4
			
func return_to_pool():
	"""归还子弹到对象池"""
	self.visible = false
	set_process(false)
	self.collision_layer = 0
	self.collision_mask = 0
	returned_to_pool.emit(self)
	
func _on_body_entered(body):
	# 处理碰撞逻辑
	if body.collision_layer & 4 == 4 or body.collision_layer & 8 == 8 :
		if body.get_parent().has_method("take_damage"):
		#print("成功命中")
			self.visible = false
			body.get_parent().take_damage(bullet_data.damage, bullet_data.special_info)
		return_to_pool()
	
func _on_area_entered(area):
	# 处理碰撞逻辑
	if area.get_parent().has_method("take_damage"):
		#print("成功命中")
		self.visible = false
		area.get_parent().take_damage(bullet_data.damage, bullet_data.special_info)
		
	return_to_pool()
