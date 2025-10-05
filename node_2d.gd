extends Node2D
var level_node
var level_data



func _ready() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)
	#
# 当玩家进入房间时自动生成
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("test"):
		level_data = NormalLevelGenerator.generate()
		level_node = level_data.level_node 
		add_child(level_node)
