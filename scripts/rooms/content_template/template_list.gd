enum RoomType {
	NORMAL_COMBAT,    # 普通战斗房
	SPECIAL_COMBAT,   # 特殊战斗房（精英房间/挑战房）
	BOSS,             # Boss房
	TREASURE,         # 宝箱/奖励房
	SHOP,             # 商店房
	REST,             # 休息房
	CORRIDOR,         # 走廊/过渡房
	START,            # 起始房
	SECRET            # 秘密房
}

static var a_templates: Dictionary = {
	RoomType.BOSS: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Rect_Room.tscn",
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Rect_Room.tscn",
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Rect_Room.tscn"
		],
		"weights": [1.0, 1.0, 0.5],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.TREASURE: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn",
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn"
		],
		"weights": [1.0, 0.3],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.SHOP: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn",
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn"
		],
		"weights": [1.0, 0.5],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.CORRIDOR: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn",
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn",
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn"
		],
		"weights": [1.0, 1.0, 0.3],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.NORMAL_COMBAT: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn",
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn",
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn"
		],
		"weights": [1.0, 1.0, 0.7],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.SECRET: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn"
		],
		"weights": [1.0],
		"min_floor": 3,
		"max_floor": 99
	},
	RoomType.START: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn"
		],
		"weights": [1.0],
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.REST: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn",
			"res://scenes/rooms/normal_rooms/content_layer/A_template/spring/A_Circle_Room.tscn"
		],
		"weights": [1.0, 0.8],
		"min_floor": 1,
		"max_floor": 99
	}
}

# B类模板池 - 程序化生成的积木拼接
static var b_templates: Dictionary = {
	RoomType.NORMAL_COMBAT: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/B_template/B_Room_Content.tscn",
		],
		"weights": [1.0], 
		"min_floor": 1,
		"max_floor": 99
	},
	RoomType.SPECIAL_COMBAT: {
		"templates": [
			"res://scenes/rooms/normal_rooms/content_layer/B_template/B_Room_Content.tscn"
		],
		"weights": [1.0], 
		"min_floor": 1,
		"max_floor": 99
	}
}
