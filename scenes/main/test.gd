extends Node2D

var test_weapon
var test_weapon2
var weapon_instance
var test_skill

signal test_weapon_weapon_data(weapon_data: WeaponData, slot: int)
signal test_weapon_component(weapon_component: WeaponComponent, slot: int)

func _ready():
	GameManager.change_state(GameManager.GameState.PLAYING)
	test_weapon =preload("res://scenes/weapons/uzi.tscn")
	test_weapon2 =preload("res://scenes/weapons/pistol_ice.tscn")
	test_skill =load("res://resources/skills/SecondarySkill/TestDash.tres") as SkillData
	

func _input(event):
	if event.is_action_pressed("test"):
		#test_weapon_weapon_data.emit(test_weapon2, 1)
		weapon_instance =test_weapon.instantiate()
		test_weapon_component.emit(weapon_instance, 1)
	if event.is_action_pressed("space"):
		SkillSystem.equip_skill_with_script(test_skill,1)
		#SkillSystem.execute_movement_skill(test_skill,300,0.25)
