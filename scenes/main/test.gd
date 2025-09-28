extends Node2D

var test_weapon
var test_weapon2
var weapon_instance
var test_skill
var config
var level_node

signal test_weapon_weapon_data(weapon_data: WeaponData, slot: int)
signal test_weapon_component(weapon_component: WeaponComponent, slot: int)

func _ready():
	GameManager.change_state(GameManager.GameState.PLAYING)
	test_weapon =preload("res://scenes/weapons/uzi.tscn")
	test_weapon2 =preload("res://scenes/weapons/pistol_ice.tscn")
	test_skill =load("res://resources/skills/SecondarySkill/TestDash.tres") as SkillData
	level_generator()

func _input(event):
	if event.is_action_pressed("test"):
		#test_weapon_weapon_data.emit(test_weapon2, 1)
		weapon_instance =test_weapon.instantiate()
		test_weapon_component.emit(weapon_instance, 1)
	if event.is_action_pressed("space"):
		SkillSystem.equip_skill_with_script(test_skill,1)
		#SkillSystem.execute_movement_skill(test_skill,300,0.25)
	
	if event.is_action_pressed("space"):
		remove_child(level_node)
		level_node = NormalLevelGenerator.generate_with_config(config)
		add_child(level_node)
	

func level_generator():
	level_node = NormalLevelGenerator.generate()
	level_node.get_node("room1").add_child(load("res://scenes/buildings/Blacksmith.tscn").instantiate())
	add_child(level_node)
	
	config = NormalLevelGenerator.level_config.new().config_dic
	config.GRID_SIZE= 6
	config.TARGET_ROOMS=5
	config.CONNECTION_RATE= 0.25
	config.ENABLE_PARTITIONS= true
	config.COMPLEXITY_BIAS = 0.6
	config.RANDOM_SEED = -1
	config.DEBUG_MODE= false  # 调试模式开关
