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
	if event.is_action_pressed("space"):
		print_scene_tree_to_file()

func spawn():
	level_data = LevelFrameGenerator.generate( 5,
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
	LevelContentGenerator.initialize_from_level_data(level_data)
	LevelContentGenerator.populate_all_rooms()
	level_node.get_node("room1").add_child(load("res://scenes/buildings/Blacksmith.tscn").instantiate())
	add_child(level_node)

	
func clear_level_map():
	if level_node:
		level_node.name = "deleting_node"
		level_node.queue_free()
		GameManager.level_node_changed.emit()
		
func print_scene_tree_to_file(filepath: String = "res://debug/scene_tree.txt"):
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		write_scene_tree(get_tree().root, "", file)
		file.close()
		print("场景树已保存到: " + filepath)
	else:
		print("无法创建文件: " + filepath)

func write_scene_tree(node: Node, indent: String, file: FileAccess):
	file.store_line(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		write_scene_tree(child, indent + "  ", file)
