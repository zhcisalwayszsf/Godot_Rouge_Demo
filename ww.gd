extends Node2D

var config

func _ready() -> void:
	#self.add_child(NormalLevelGenerator.generate_level(NormalLevelGenerator.GenerationParams.new()).level_node)
	var level_node = NormalLevelGenerator.generate().level_node
	add_child(level_node)
	
	config = NormalLevelGenerator.level_config.new().config_dic
	config.GRID_SIZE= 6
	config.TARGET_ROOMS=5
	config.CONNECTION_RATE= 0.25
	config.ENABLE_PARTITIONS= true
	config.COMPLEXITY_BIAS = 0.6
	config.RANDOM_SEED = -1
	config.DEBUG_MODE= false  # 调试模式开关
	
	pass

func _input(event):
	if event.is_action_pressed("space"):
		self.remove_child(get_child(0))
		var level_node = NormalLevelGenerator.generate_with_full_config(config).level_node
		add_child(level_node)
