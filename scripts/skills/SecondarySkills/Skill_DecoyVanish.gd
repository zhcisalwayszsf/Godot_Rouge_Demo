extends Node2D
@export var skill_name: String = "DecoyVanish"
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
	
	
func _physics_process(delta: float) -> void: 
	pass
	
func main_funtion(): ## 技能释放时运行一次
	create_fake_body()
	apply_invisible()
	pass


func create_fake_body(): ## 检查玩家移动距离,达到阈值时创建阴影
	
	var current_position = player.global_position
	create_shadows()
	last_shadow_position = current_position

func create_shadows():
	var sprite = creat_emtpy_sprite()
	get_tree().root.add_child(sprite)
	sprite.position = shadow_source.global_position
	
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "self_modulate", Color(sprite.self_modulate.r, sprite.self_modulate.g, sprite.self_modulate.b,1), 2)
	tween.bind_node(sprite)
	tween.finished.connect(func(): sprite.queue_free())

func creat_emtpy_sprite() -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite = shadow_source.duplicate()
	sprite.scale = Vector2(2,2)
	sprite.set_self_modulate(Color(1,1,1,1))
	return sprite

func apply_invisible():
	var row_sprite_modulate = shadow_source.self_modulate
	var effect_timer = TimerPool.create_one_shot_timer(skill_data.buff_time[2],
		func(): shadow_source.self_modulate = row_sprite_modulate
	)
	player.set_no_collision(skill_data.buff_time[2])
	shadow_source.self_modulate = Color(0.6,0.7,0.8,0.5)
	effect_timer.start()
	pass
