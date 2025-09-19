# res://scripts/ui/MainMenu.gd
extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	connect_buttons()
	GameManager.change_state(GameManager.GameState.MENU)

func connect_buttons():
	"""连接按钮信号"""
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	"""开始游戏"""
	print("开始新游戏")
	GameManager.start_game(GameManager.Difficulty.NORMAL)
	get_tree().change_scene_to_file("res://scenes/main/GameScene.tscn")

func _on_settings_pressed():
	"""打开设置"""
	print("打开设置界面")
	# 暂时只是打印，后面可以添加设置界面

func _on_quit_pressed():
	"""退出游戏"""
	print("退出游戏")
	get_tree().quit()
