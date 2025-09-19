# res://scripts/managers/EffectManager.gd
extends Node

func _ready():
	print("EffectManager initialized")

func create_hit_effect(position: Vector2):
	"""创建命中效果"""
	var effect = create_simple_particle_effect(position, Color.ORANGE, 0.3)
	print("创建命中效果于位置: ", position)

func create_muzzle_flash(position: Vector2, direction: Vector2):
	"""创建枪口闪光"""
	var effect = create_simple_particle_effect(position, Color.YELLOW, 0.1)
	print("创建枪口闪光于位置: ", position)

func create_death_effect(position: Vector2):
	"""创建死亡效果"""
	var effect = create_simple_particle_effect(position, Color.RED, 0.5)
	print("创建死亡效果于位置: ", position)

func create_simple_particle_effect(position: Vector2, color: Color, duration: float) -> Node2D:
	"""创建简单的粒子效果"""
	var effect_node = Node2D.new()
	effect_node.name = "SimpleEffect"
	effect_node.global_position = position
	
	# 创建多个小圆点模拟粒子
	for i in range(8):
		var particle = create_particle_sprite(color)
		effect_node.add_child(particle)
		
		# 随机方向和速度
		var angle = randf() * TAU
		var speed = randf_range(50, 150)
		var direction = Vector2(cos(angle), sin(angle))
		
		# 粒子动画
		var tween = create_tween()
		var end_pos = particle.position + direction * speed * duration
		tween.parallel().tween_property(particle, "position", end_pos, duration)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, duration)
	
	# 添加到当前场景
	get_tree().current_scene.add_child(effect_node)
	
	# 延迟删除
	var cleanup_timer = get_tree().create_timer(duration)
	cleanup_timer.timeout.connect(effect_node.queue_free)
	
	return effect_node

func create_particle_sprite(color: Color) -> Sprite2D:
	"""创建粒子精灵"""
	var sprite = Sprite2D.new()
	
	# 创建小圆点纹理
	var image = Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	sprite.texture = texture
	
	return sprite

func screen_shake(intensity: float = 10.0, duration: float = 0.2):
	"""屏幕震动效果"""
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_offset = camera.offset
	var shake_tween = create_tween()
	
	# 震动循环
	var shake_count = int(duration * 60)  # 假设60FPS
	for i in range(shake_count):
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(camera, "offset", original_offset + shake_offset, duration / shake_count)
	
	# 恢复原始位置
	shake_tween.tween_property(camera, "offset", original_offset, 0.1)
