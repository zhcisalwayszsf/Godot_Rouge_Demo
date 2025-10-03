extends Node2D

func _ready() -> void:
	GameManager.change_state(GameManager.GameState.PLAYING)
# 当玩家进入房间时自动生成
