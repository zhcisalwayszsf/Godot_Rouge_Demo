# Spring_Block_List.gd
# 春原主题的块配置 - 使用灵活的互斥规则

static var block_pools = {
	# ========== 和平村落组 ==========
	"house": {
		"spawn_weight": 1.5, 
		"excludes": ["ruins", "burnt_house", "damaged_house"],  ## 房子与废墟类互斥
		"synergy_with": {  ## 协同权重
			"well": 1.8,
			"garden": 1.5,
			"livestock": 1.3,
			"vegetable_field": 1.4,
			"haystack_small": 1.2
		},
		"scenes": [  # 可用的场景及其出现概率
			{
				"path": "res://scenes/blocks/spring/house_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/house_02.tscn",
				"probability": 0.8
			},
			{
				"path": "res://scenes/blocks/spring/house_03.tscn",
				"probability": 0.6
			}
		],
		"container": "Buildings"  # 实例化到的容器名称
	},
	
	"well": {
		"exclusive_group": "peaceful",
		"spawn_weight": 1.2,
		"synergy_with": {
			"house": 1.8,
			"garden": 1.4,
			"vegetable_field": 1.3
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/well_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/well_02.tscn",
				"probability": 0.7
			}
		],
		"container": "Structures"
	},
	
	"garden": {
		"exclusive_group": "peaceful",
		"spawn_weight": 1.3,
		"synergy_with": {
			"house": 1.5,
			"well": 1.4,
			"haystack_small": 1.2
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/garden_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/garden_flower.tscn",
				"probability": 0.9
			},
			{
				"path": "res://scenes/blocks/spring/garden_vegetable.tscn",
				"probability": 0.8
			}
		],
		"container": "Nature"
	},
	
	"livestock": {
		"exclusive_group": "peaceful",
		"spawn_weight": 1.0,
		"synergy_with": {
			"house": 1.3,
			"haystack_small": 1.6,
			"vegetable_field": 1.2
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/livestock_pen_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/livestock_pen_02.tscn",
				"probability": 0.8
			}
		],
		"container": "Structures"
	},
	
	"vegetable_field": {
		"exclusive_group": "peaceful",
		"spawn_weight": 1.1,
		"synergy_with": {
			"house": 1.4,
			"well": 1.3,
			"haystack_small": 1.2
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/veggie_field_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/veggie_field_02.tscn",
				"probability": 0.9
			}
		],
		"container": "Nature"
	},
	
	"haystack_small": {
		"exclusive_group": "peaceful",
		"spawn_weight": 0.9,
		"synergy_with": {
			"house": 1.2,
			"livestock": 1.6,
			"vegetable_field": 1.2
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/haystack_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/haystack_02.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/haystack_03.tscn",
				"probability": 0.8
			}
		],
		"container": "Objects"
	},
	
	# ========== 废墟/破坏组 ==========
	"ruins": {
		"exclusive_group": "destroyed",  # 互斥组：废墟破坏
		"spawn_weight": 1.2,
		"synergy_with": {
			"burnt_house": 1.5,
			"damaged_house": 1.4,
			"boulder": 1.3
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/ruins_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/ruins_02.tscn",
				"probability": 0.9
			},
			{
				"path": "res://scenes/blocks/spring/ruins_ancient.tscn",
				"probability": 0.6
			}
		],
		"container": "Ruins"
	},
	
	"burnt_house": {
		"exclusive_group": "destroyed",
		"spawn_weight": 1.0,
		"synergy_with": {
			"ruins": 1.5,
			"damaged_house": 1.3,
			"boulder": 1.2
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/house_burnt_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/house_burnt_02.tscn",
				"probability": 0.8
			}
		],
		"container": "Ruins"
	},
	
	"damaged_house": {
		"exclusive_group": "destroyed",
		"spawn_weight": 1.1,
		"synergy_with": {
			"ruins": 1.4,
			"burnt_house": 1.3,
			"boulder": 1.2
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/house_damaged_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/house_damaged_02.tscn",
				"probability": 0.9
			}
		],
		"container": "Ruins"
	},
	
	"boulder": {
		"exclusive_group": "destroyed",
		"spawn_weight": 0.8,
		"synergy_with": {
			"ruins": 1.3,
			"burnt_house": 1.2,
			"damaged_house": 1.2
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/boulder_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/boulder_02.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/boulder_03.tscn",
				"probability": 0.9
			}
		],
		"container": "Nature"
	},
	
	# ========== 自然景观组 ==========
	"shrub_forest": {
		"exclusive_group": "nature",  # 互斥组：自然景观
		"spawn_weight": 1.0,
		"synergy_with": {
			"tree_cluster": 1.4,
			"small_pond": 1.3
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/shrub_forest_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/shrub_forest_02.tscn",
				"probability": 0.9
			}
		],
		"container": "Nature"
	},
	
	"tree_cluster": {
		"exclusive_group": "nature",
		"spawn_weight": 1.1,
		"synergy_with": {
			"shrub_forest": 1.4,
			"small_pond": 1.2
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/tree_cluster_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/tree_cluster_02.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/tree_cluster_03.tscn",
				"probability": 0.8
			}
		],
		"container": "Nature"
	},
	
	"small_pond": {
		"exclusive_group": "nature",
		"spawn_weight": 0.9,
		"synergy_with": {
			"shrub_forest": 1.3,
			"tree_cluster": 1.2
		},
		"scenes": [
			{
				"path": "res://scenes/blocks/spring/pond_01.tscn",
				"probability": 1.0
			},
			{
				"path": "res://scenes/blocks/spring/pond_02.tscn",
				"probability": 0.9
			},
			{
				"path": "res://scenes/blocks/spring/pond_lotus.tscn",
				"probability": 0.7
			}
		],
		"container": "Nature"
	}
}

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
