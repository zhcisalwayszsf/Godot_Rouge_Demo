# res://scripts/rooms/objectslist/B/block/Test_Block_List.gd

static var block_pools = {
	"test_block_a": {
		"exclusive_group": "test_group",
		"spawn_weight": 1.0,
		"synergy_with": {},
		"scenes": [
			{
				# 使用现有的简单场景，或创建一个简单的Sprite2D场景
				"path": "res://scenes/rooms/normal_rooms/content_layer/A_template/临时/tree002.tscn",
				"probability": 1.0
			}
		],
		"container": "TestBlocks"
	}
}


static var decoration_pools = {
	"test_block_a": {
		"max_count": 2,
		"items": [
			{
				"path": "res://scenes/rooms/normal_rooms/content_layer/A_template/spring/Natural_Objects/stone001.tscn",
				"probability": 1.0
			}
		]
	}
}
