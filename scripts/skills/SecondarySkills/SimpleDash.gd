extends Node2D
@export var skill_name: String = "SimpleDash"
@export var skill_data: SkillData
@export var player: CharacterBody2D
var shadow_source: Sprite2D


var last_shadow_position: Vector2  ## 记录上一个阴影的位置
var shadow_distance: float ## 每隔30像素创建一个阴影
var effecting:bool = false

func initialize_skill(): ## Skill System 装备技能到槽位后运行一次
	if not player:
		player = get_tree().get_nodes_in_group("player")[0]
		shadow_source = player.get_node("Visuals/Body")
	shadow_distance = skill_data.distance / 10
	
func _physics_process(delta: float) -> void: 
	match player.movement_state:
		player.MovementState.DASHING:
			check_and_create_shadow()
	
func main_funtion(): ## 技能释放时运行一次
	pass


func check_and_create_shadow(): ## 检查玩家移动距离,达到阈值时创建阴影
	
	var current_position = player.global_position
	var distance = current_position.distance_to(last_shadow_position)
	
	# 如果移动距离超过阈值,创建阴影
	if distance >= shadow_distance:
		create_shadows()
		last_shadow_position = current_position

func create_shadows():
	var sprite = creat_emtpy_sprite()
	get_tree().root.add_child(sprite)
	sprite.position = shadow_source.global_position
	
	var tween = create_tween()
	tween.tween_property(sprite, "self_modulate", Color(sprite.self_modulate.r, sprite.self_modulate.g, sprite.self_modulate.b, 0), 0.25)
	tween.bind_node(sprite)
	tween.finished.connect(func(): sprite.queue_free())

func creat_emtpy_sprite() -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite = shadow_source.duplicate()
	sprite.scale = Vector2(2,2)
	sprite.set_self_modulate(Color(1,0,1,1))
	return sprite



"""
extends Node2D
@export var skill_name: String = "SimpleDash"
@export var skill_data: SkillData
@export var player: CharacterBody2D
var shadow_source: Sprite2D

# 新增变量
var last_shadow_position: Vector2  ## 记录上一个阴影的位置
var shadow_distance: float ## 每隔30像素创建一个阴影
var effecting:bool = false

func initialize_skill():
	if not player:
		player = get_tree().get_nodes_in_group("player")[0]
		shadow_source = player.get_node("Visuals/Body")
	shadow_distance = skill_data.distance / 10
	
func _physics_process(delta: float) -> void:
	if effecting:
		check_and_create_shadow()
	
func main_funtion():
	print("成功运行了技能附带脚本!!!")
	# 初始化位置
	last_shadow_position = player.global_position
	effecting = true
	# 改用每帧检查距离	
	var effect_timer = TimerPool.create_one_shot_timer(
		skill_data.dash_time if skill_data else 0.5,
		func():
			effecting = false
	)
	
	effect_timer.start()

func check_and_create_shadow():#检查玩家移动距离,达到阈值时创建阴影
	var current_position = player.global_position
	var distance = current_position.distance_to(last_shadow_position)
	
	# 如果移动距离超过阈值,创建阴影
	if distance >= shadow_distance:
		create_shadows()
		last_shadow_position = current_position

func create_shadows():
	var sprite = creat_emtpy_sprite()
	get_tree().root.add_child(sprite)
	sprite.position = shadow_source.global_position
	
	var tween = create_tween()
	tween.tween_property(sprite, "self_modulate", Color(sprite.self_modulate.r, sprite.self_modulate.g, sprite.self_modulate.b, 0), 0.25)
	tween.bind_node(sprite)
	tween.finished.connect(func(): sprite.queue_free())

func creat_emtpy_sprite() -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite = shadow_source.duplicate()
	sprite.scale = Vector2(2,2)
	sprite.set_self_modulate(Color(1,0,1,1))
	return sprite
"""
