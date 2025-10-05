# spring_decoration.gd
# 春原主题的装饰物配置

static var decoration_pools = {
	# 房屋装饰
	"house": {
		"max_count": 5,  # 该块最多生成的装饰物数量
		"items": [
			{
				"path": "res://scenes/decorations/spring/fence_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/fence_02.tscn",
				"probability": 0.9
			},
			{
				"path": "res://scenes/decorations/spring/flower_pot.tscn",
				"probability": 0.8
			},
			{
				"path": "res://scenes/decorations/spring/stone_path.tscn",
				"probability": 0.7
			},
			{
				"path": "res://scenes/decorations/spring/mailbox.tscn",
				"probability": 0.6
			},
			{
				"path": "res://scenes/decorations/spring/lantern.tscn",
				"probability": 0.5
			}
		]
	},
	
	# 水井装饰
	"well": {
		"max_count": 3,
		"items": [
			{
				"path": "res://scenes/decorations/spring/bucket.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/water_barrel.tscn",
				"probability": 0.8
			},
			{
				"path": "res://scenes/decorations/spring/stone_small.tscn",
				"probability": 0.6
			}
		]
	},
	
	# 花园装饰
	"garden": {
		"max_count": 6,
		"items": [
			{
				"path": "res://scenes/decorations/spring/flower_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/flower_02.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/flower_03.tscn",
				"probability": 0.9
			},
			{
				"path": "res://scenes/decorations/spring/butterfly.tscn",
				"probability": 0.5
			},
			{
				"path": "res://scenes/decorations/spring/garden_tool.tscn",
				"probability": 0.7
			}
		]
	},
	
	# 畜牧栏装饰
	"livestock": {
		"max_count": 4,
		"items": [
			{
				"path": "res://scenes/decorations/spring/feeding_trough.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/hay_bale.tscn",
				"probability": 0.9
			},
			{
				"path": "res://scenes/decorations/spring/fence_broken.tscn",
				"probability": 0.6
			}
		]
	},
	
	# 菜地装饰
	"vegetable_field": {
		"max_count": 5,
		"items": [
			{
				"path": "res://scenes/decorations/spring/scarecrow.tscn",
				"probability": 0.8
			},
			{
				"path": "res://scenes/decorations/spring/farming_tool.tscn",
				"probability": 0.7
			},
			{
				"path": "res://scenes/decorations/spring/crop_small.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/watering_can.tscn",
				"probability": 0.6
			}
		]
	},
	
	# 小干草堆装饰
	"haystack_small": {
		"max_count": 2,
		"items": [
			{
				"path": "res://scenes/decorations/spring/pitchfork.tscn",
				"probability": 0.7
			},
			{
				"path": "res://scenes/decorations/spring/straw_scattered.tscn",
				"probability": 0.9
			}
		]
	},
	
	# 废墟装饰
	"ruins": {
		"max_count": 4,
		"items": [
			{
				"path": "res://scenes/decorations/spring/rubble_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/rubble_02.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/broken_pillar.tscn",
				"probability": 0.8
			},
			{
				"path": "res://scenes/decorations/spring/moss_stone.tscn",
				"probability": 0.7
			},
			{
				"path": "res://scenes/decorations/spring/vine_overgrowth.tscn",
				"probability": 0.6
			}
		]
	},
	
	# 火灾后的小屋装饰
	"burnt_house": {
		"max_count": 3,
		"items": [
			{
				"path": "res://scenes/decorations/spring/charred_wood.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/ash_pile.tscn",
				"probability": 0.9
			},
			{
				"path": "res://scenes/decorations/spring/burnt_debris.tscn",
				"probability": 0.8
			}
		]
	},
	
	# 破损小屋装饰
	"damaged_house": {
		"max_count": 3,
		"items": [
			{
				"path": "res://scenes/decorations/spring/broken_window.tscn",
				"probability": 0.9
			},
			{
				"path": "res://scenes/decorations/spring/collapsed_wall.tscn",
				"probability": 0.8
			},
			{
				"path": "res://scenes/decorations/spring/broken_furniture.tscn",
				"probability": 0.7
			}
		]
	},
	
	# 巨石装饰
	"boulder": {
		"max_count": 2,
		"items": [
			{
				"path": "res://scenes/decorations/spring/moss_patch.tscn",
				"probability": 0.8
			},
			{
				"path": "res://scenes/decorations/spring/rock_small.tscn",
				"probability": 1.0
			}
		]
	},
	
	# 灌木林装饰
	"shrub_forest": {
		"max_count": 5,
		"items": [
			{
				"path": "res://scenes/decorations/spring/bush_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/bush_02.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/mushroom.tscn",
				"probability": 0.6
			},
			{
				"path": "res://scenes/decorations/spring/fallen_branch.tscn",
				"probability": 0.7
			}
		]
	},
	
	# 树丛装饰
	"tree_cluster": {
		"max_count": 4,
		"items": [
			{
				"path": "res://scenes/decorations/spring/stump.tscn",
				"probability": 0.7
			},
			{
				"path": "res://scenes/decorations/spring/fallen_log.tscn",
				"probability": 0.8
			},
			{
				"path": "res://scenes/decorations/spring/bird_nest.tscn",
				"probability": 0.4
			},
			{
				"path": "res://scenes/decorations/spring/wildflower.tscn",
				"probability": 0.9
			}
		]
	},
	
	# 小湖装饰
	"small_pond": {
		"max_count": 4,
		"items": [
			{
				"path": "res://scenes/decorations/spring/lily_pad.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/decorations/spring/cattail.tscn",
				"probability": 0.9
			},
			{
				"path": "res://scenes/decorations/spring/water_grass.tscn",
				"probability": 0.8
			},
			{
				"path": "res://scenes/decorations/spring/dragonfly.tscn",
				"probability": 0.5
			}
		]
	}
}
