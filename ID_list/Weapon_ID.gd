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
		"name":"pistol_ice",
		"data_path":"res://resources/weapons/pistol_ice.tres",
		"tscn_path":"res://scenes/weapons/pistol_ice.tscn"
	},
	4:{
		"id":4,
		"name":"smg_pistol",
		"data_path":"res://resources/weapons/smg_pistol.tres",
		"tscn_path":"res://scenes/weapons/smg_pistol.tscn"
	},
	5:{
		"id":5,
		"name":"s1897",
		"data_path":"res://resources/weapons/s1897.tres",
		"tscn_path":"res://scenes/weapons/s1897.tscn"
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
	
