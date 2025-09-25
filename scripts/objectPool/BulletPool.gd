# res://scripts/managers/BulletPool.gd
extends Node


var bullet_scene: PackedScene = preload("res://scenes/ammo/Bullet.tscn")
var bullet_pool: Array[Bullet] = []

@export var max_pool_size: int = 500
@export var preload_count: int = 40

func _ready():
	for i in range(preload_count):
		var bullet = create_new_bullet()
		return_bullet(bullet)

func create_new_bullet() -> Bullet:
	var new_bullet = bullet_scene.instantiate() as Bullet
	get_tree().get_root().call_deferred("add_child", new_bullet)
	new_bullet.returned_to_pool.connect(return_bullet)
	new_bullet.visible = false
	new_bullet.set_process(false)
	new_bullet.set_collision_mask_value(2, false)
	new_bullet.set_collision_mask_value(3, false)
	new_bullet.set_collision_mask_value(7, false)
	return new_bullet

func get_bullet(p_data: Bullet.BulletData,source:int=0) -> Bullet:
	"""从对象池获取一个子弹实例并进行初始化"""
	var bullet: Bullet
	
	if bullet_pool.size() > 0:
		bullet = bullet_pool.pop_back()
		if not is_instance_valid(bullet):
			bullet = create_new_bullet()
	else:
		bullet = create_new_bullet()
	
	# 使用传入的数据初始化子弹
	bullet.initialize(p_data,source)
	
	return bullet

func return_bullet(bullet: Bullet):
	if not is_instance_valid(bullet):
		return
	
	if bullet_pool.size() < max_pool_size:
		if not bullet in bullet_pool:
			bullet_pool.append(bullet)
	else:
		bullet.queue_free()
