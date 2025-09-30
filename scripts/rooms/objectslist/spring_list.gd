
static var entity_pools = {
	"tree": {
		"scenes": [
			{
				"path": "res://scenes/rooms/normal_rooms/content_layer/spring/Natural_Objects/tree001.tscn",
				"size": Vector2i(1, 1)
			},
			{
				"path": "res://scenes/rooms/normal_rooms/content_layer/spring/Natural_Objects/tree001.tscn",
				"size": Vector2i(2, 2)
			},
			{
				"path": "res://scenes/rooms/normal_rooms/content_layer/spring/Natural_Objects/tree001.tscn",
				"size": Vector2i(3, 3)
			},
			{
				"path": "res://scenes/rooms/normal_rooms/content_layer/spring/Natural_Objects/tree001.tscn",
				"size": Vector2i(4, 4)
			}
		],
		"max_count": 4,
		"container": "NaturalThings"  # 指定容器
	},
	"rock": {
		"scenes": [
			{
				"path": "res://scenes/rooms/normal_rooms/content_layer/spring/Natural_Objects/stone001.tscn",
				"size": Vector2i(1, 1)
			}
		],
		"max_count": 6,
		"container": "NaturalThings"
	},
	"stump": {#树桩
		"scenes": [
			{
				"path": "res://scenes/entities/nature/stump_1.tscn",
				"size": Vector2i(1, 1)
			}
		],
		"max_count": 3,
		"container": "NaturalThings"
	},
	"flower": {
		"scenes": [
			{
				"path": "res://scenes/entities/decoration/flower_1.tscn",
				"size": Vector2i(1, 1)
			},
			{
				"path": "res://scenes/entities/decoration/flower_2.tscn",
				"size": Vector2i(1, 1)
			}
		],
		"max_count": 10,
		"container": "Objects"
	},
	"barrel": {
		"scenes": [
			{
				"path": "res://scenes/entities/destructibles/barrel_1.tscn",
				"size": Vector2i(1, 1)
			}
		],
		"max_count": 4,
		"container": "Objects"
	},
	"crate": {
		"scenes": [
			{
				"path": "res://scenes/entities/destructibles/crate_1.tscn",
				"size": Vector2i(1, 1)
			}
		],
		"max_count": 4,
		"container": "Objects"
	},
	"grass": {
		"scenes": [
			{
				"path": "res://scenes/entities/decoration/grass_1.tscn",
				"size": Vector2i(1, 1)
			}
		],
		"max_count": 15,
		"container": "Objects"
	}
}
