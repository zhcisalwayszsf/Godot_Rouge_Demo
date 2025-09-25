extends Node
class_name WeaponList

static var weapons_by_id={
	1:{
		"id":1,
		"name":"pistol_m1911",
		"data_path":"res://resources/weapons/pistol_m1911.tres",
		"tscn_path":"res://scenes/weapons/pistol_m1911.tscn"
	},
	2:{
		"id":2,
		"name":"uzi",
		"data_path":"res://resources/weapons/uzi.tres",
		"tscn_path":"res://scenes/weapons/uzi.tscn"
	},
	3:{
		"id":3,
		"name":"null",
		"data_path":"res://resources/weapons/.tres",
		"tscn_path":"res://scenes/weapons/.tscn"
	}
}
static func _int_name_dict()->Dictionary:
	var weapons_by_name={}
	
	for weapon in weapons_by_id.values():
		weapons_by_name[weapon.name] = weapon
	return weapons_by_name
	
static var weapons_by_name= _int_name_dict()


static func get_weapon_by_id(id:int)->Dictionary:
	return weapons_by_id.get(id,{})

static func get_weapon_by_name(name:String)->Dictionary:
	return weapons_by_name.get(name,{})
	
