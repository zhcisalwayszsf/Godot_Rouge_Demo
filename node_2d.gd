extends Node2D
var level_node:Node2D
var level_data



func _ready() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)
	#
# 当玩家进入房间时自动生成
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("test"):
		clear_level_map()
		spawn()


func spawn():
	level_data = NormalLevelGenerator.generate( 5,
	8,
	 0.5,
	true,
	 0.5,
	-1,
	false,
	 0.3 ,
	 1 ,
	0)
	level_node = level_data.level_node
	LevelManager.initialize_from_level_data(level_data)
	LevelManager.populate_all_rooms()
	level_node.get_node("room1").add_child(load("res://scenes/buildings/Blacksmith.tscn").instantiate())
	add_child(level_node)

	
func clear_level_map():
	if level_node:
		level_node.queue_free()
