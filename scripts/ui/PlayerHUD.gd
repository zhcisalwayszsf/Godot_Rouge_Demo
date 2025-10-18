# res://scripts/ui/PlayerHUD.gd - 带拾取提示版本
extends CanvasLayer
class_name PlayerHUD

# 血量和能量相关
@onready var health_bar = $BottomLeft/HealthBar
@onready var energy_bar = $BottomLeft/EnergyBar
@onready var health_label = $BottomLeft/HealthEnergyLabels/HealthLabel
@onready var energy_label = $BottomLeft/HealthEnergyLabels/EnergyLabel

# 武器相关
@onready var weapon_name = $BottomRight/VBoxContainer/WeaponInfo/WeaponName
@onready var ammo_label = $BottomRight/VBoxContainer/WeaponInfo/AmmoInfo/AmmoLabel
@onready var reload_progress = $BottomRight/VBoxContainer/WeaponInfo/AmmoInfo/box/ReloadProgress
@onready var weapon_icon = $BottomRight/VBoxContainer/WeaponInfo/WeaponIcon
@onready var primary_weapon_icon = $BottomRight/VBoxContainer/WeaponSlots/PrimaryWeapon/PrimaryIcon
@onready var secondary_weapon_icon = $BottomRight/VBoxContainer/WeaponSlots/SecondaryWeapon/SecondaryIcon

# 技能相关
@onready var primary_skill_icon = $BottomCenter/SkillBar/PrimarySkill/PrimarySkillIcon
@onready var primary_skill_cooldown = $BottomCenter/SkillBar/PrimarySkill/PrimarySkillCooldown
@onready var primary_skill_key = $BottomCenter/SkillBar/PrimarySkill/PrimarySkillKey
@onready var secondary_skill_icon = $BottomCenter/SkillBar/SecondarySkill/SecondarySkillIcon
@onready var secondary_skill_cooldown = $BottomCenter/SkillBar/SecondarySkill/SecondarySkillCooldown
@onready var secondary_skill_key = $BottomCenter/SkillBar/SecondarySkill/SecondarySkillKey

# 武器槽位Panel引用（用于高亮当前武器）
@onready var primary_weapon_panel = $BottomRight/VBoxContainer/WeaponSlots/PrimaryWeapon
@onready var secondary_weapon_panel = $BottomRight/VBoxContainer/WeaponSlots/SecondaryWeapon

# 拾取提示相关 - 新增
var pickup_prompt: Label
var pickup_prompt_container: Control

# 样式配置
var normal_weapon_color: Color = Color.WHITE
var active_weapon_color: Color = Color.YELLOW
var cooldown_color: Color = Color.RED
var ready_color: Color = Color.GREEN

# 缓存UI元素状态
var cached_health: int = -1
var cached_energy: int = -1
var cached_ammo: int = -1
var ui_update_timer: float = 0.0
const UI_UPDATE_INTERVAL = 0.1

func _ready():
	print("PlayerHUD initialized with pickup system")
	setup_hud()
	setup_pickup_prompt()
	connect_signals()
	setup_initial_display()

	
func setup_hud():
	"""设置HUD样式和布局"""
	# 设置进度条样式
	health_bar.theme = ResourceLoader.load("res://scenes/ui/healthbar.tres")
	energy_bar.theme = ResourceLoader.load("res://scenes/ui/energybar.tres")
	
	# 设置技能冷却进度条
	primary_skill_cooldown.show_percentage = false
	secondary_skill_cooldown.show_percentage = false
	
	# 设置技能按键标签
	primary_skill_key.text = "V"
	secondary_skill_key.text = "E"
	
	# 设置初始可见性
	reload_progress.visible = false

func setup_pickup_prompt():
	"""设置拾取提示UI"""
	# 创建拾取提示容器
	pickup_prompt_container = Control.new()
	pickup_prompt_container.name = "PickupPromptContainer"
	pickup_prompt_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pickup_prompt_container.position.y = -100  # 稍微向上偏移
	add_child(pickup_prompt_container)
	
	# 创建拾取提示标签
	pickup_prompt = Label.new()
	pickup_prompt.name = "PickupPrompt"
	pickup_prompt.text = ""
	pickup_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pickup_prompt.add_theme_font_size_override("font_size", 24)
	pickup_prompt.add_theme_color_override("font_color", Color.YELLOW)
	pickup_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	pickup_prompt.add_theme_constant_override("shadow_offset_x", 2)
	pickup_prompt.add_theme_constant_override("shadow_offset_y", 2)
	pickup_prompt_container.add_child(pickup_prompt)
	
	# 初始隐藏
	pickup_prompt_container.visible = false

func connect_signals():
	"""连接系统信号"""
	# 连接玩家控制器信号（需要从场景树获取）
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		player.energy_changed.connect(_on_energy_changed)
		player.ammo_updated.connect(_on_ammo_updated)
	
	# 连接武器系统信号
	if WeaponSystem:
		WeaponSystem.weapon_switched.connect(_on_weapon_switched)
		WeaponSystem.weapon_equipped.connect(_on_weapon_equipped)
	
	# 连接技能系统信号
	if SkillSystem:
		SkillSystem.skill_equipped.connect(_on_skill_equipped)
	


func setup_initial_display():
	"""设置初始显示"""
	# 初始化血量和能量显示
	var stats = PlayerDataManager.get_player_stats()
	if stats:
		update_health_display(stats.current_health, stats.max_health)
		update_energy_display(stats.current_energy, stats.max_energy)
	
	# 初始化武器显示
	update_weapon_display()
	
	# 初始化技能显示
	update_skill_display()

func _process(delta):
	"""更新需要实时刷新的元素"""
	ui_update_timer -= delta
	if ui_update_timer <= 0:
		ui_update_timer = UI_UPDATE_INTERVAL
		update_cached_ui_elements()
		update_skill_cooldowns()
		update_weapon_states()
		
func update_cached_ui_elements():
	var stats = PlayerDataManager.get_player_stats()
	if not stats:
		return
	
	# 只有当值发生变化时才更新UI
	if stats.current_health != cached_health:
		cached_health = stats.current_health
		health_bar.value = cached_health
		health_label.text = str(cached_health) + "/" + str(stats.max_health)
	
	if stats.current_energy != cached_energy:
		cached_energy = stats.current_energy
		energy_bar.value = cached_energy
		energy_label.text = str(cached_energy) + "/" + str(stats.max_energy)

func update_health_display(current_health: int, max_health: int):
	"""更新血量显示"""
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = str(current_health) + "/" + str(max_health)

func update_energy_display(current_energy: int, max_energy: int):
	"""更新能量显示"""
	energy_bar.max_value = max_energy
	energy_bar.value = current_energy
	energy_label.text = str(current_energy) + "/" + str(max_energy)

func update_weapon_display():
	"""更新武器显示"""
	var active_weapon_data = WeaponSystem.get_active_weapon_data()
	var primary_weapon_data = WeaponSystem.current_primary_weapon_data
	var secondary_weapon_data = WeaponSystem.current_secondary_weapon_data
	
	# 更新当前武器信息
	if active_weapon_data:
		weapon_name.text = active_weapon_data.weapon_display_name
	else:
		weapon_name.text = "无武器"
		weapon_icon.texture = null
	
	# 更新武器槽位图标
	# 这里可以根据武器数据设置图标
	
	# 高亮当前激活武器
	update_weapon_highlight()

func update_weapon_highlight():
	"""更新武器槽位高亮"""
	var active_slot = WeaponSystem.active_weapon_slot
	
	if active_slot == 0:
		primary_weapon_panel.modulate = active_weapon_color
		secondary_weapon_panel.modulate = normal_weapon_color
	else:
		primary_weapon_panel.modulate = normal_weapon_color
		secondary_weapon_panel.modulate = active_weapon_color

func update_weapon_states():
	"""更新武器状态（弹药、换弹进度等）"""
	var active_weapon_data = WeaponSystem.get_active_weapon_data()
	if not active_weapon_data:
		ammo_label.text = "无武器"
		reload_progress.visible = false
		return
	
	# 获取弹药信息
	var magazine_ammo = WeaponSystem.get_active_magazine_ammo()
	var stats = PlayerDataManager.get_player_stats()
	var total_ammo = 0
	
	if stats and active_weapon_data.ammo_type < 4:  # 非无消耗武器
		match active_weapon_data.ammo_type:
			0: total_ammo = stats.normal_ammo
			1: total_ammo = stats.special_ammo
			2: total_ammo = stats.arrows
			3: total_ammo = stats.mana_essence
		
		ammo_label.text = str(magazine_ammo) + "/" + str(total_ammo)
	else:
		ammo_label.text = "∞"  # 无消耗武器
	
	# 更新换弹进度
	var reload_progress_value = WeaponSystem.get_reload_progress()
	if reload_progress_value > 0:
		reload_progress.visible = true
		reload_progress.value = reload_progress_value
	else:
		reload_progress.visible = false

func update_skill_display():
	"""更新技能显示"""
	var primary_skill = SkillSystem.primary_skill_data
	var secondary_skill = SkillSystem.secondary_skill_data
	
	# 更新主技能
	# 这里可以根据技能数据设置图标
	
	# 更新副技能
	# 这里可以根据技能数据设置图标

func update_skill_cooldowns():
	"""更新技能冷却进度"""
	# 主技能冷却
	var primary_cooldown_progress = SkillSystem.get_cooldown_timer(0)
	if primary_cooldown_progress > 0:
		primary_skill_cooldown.visible = true
		primary_skill_cooldown.value = (1.0 - primary_cooldown_progress/SkillSystem.primary_skill_data.cooldown_time) * 100
	else:
		primary_skill_cooldown.visible = false
	
	# 副技能冷却
	var secondary_cooldown_progress = SkillSystem.get_cooldown_timer(1)
	if secondary_cooldown_progress > 0:
		secondary_skill_cooldown.visible = true
		secondary_skill_cooldown.value = (1.0 - secondary_cooldown_progress/SkillSystem.secondary_skill_data.cooldown_time) * 100
	else:
		secondary_skill_cooldown.visible = false

# === 拾取提示相关 - 新增功能 ===

func _on_pickup_prompt_changed(item_name: String, show: bool):
	"""拾取提示改变回调"""
	if show and not item_name.is_empty():
		show_pickup_prompt(item_name)
	else:
		hide_pickup_prompt()

func show_pickup_prompt(item_name: String):
	"""显示拾取提示"""
	pickup_prompt.text = "按 E 键拾取 " + item_name
	pickup_prompt_container.visible = true
	
	# 重新居中
	pickup_prompt.position.x = -pickup_prompt.size.x / 2
	
	# 添加淡入动画
	pickup_prompt_container.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(pickup_prompt_container, "modulate:a", 1.0, 0.2)

func hide_pickup_prompt():
	"""隐藏拾取提示"""
	if pickup_prompt_container.visible:
		# 添加淡出动画
		var tween = create_tween()
		tween.tween_property(pickup_prompt_container, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): pickup_prompt_container.visible = false)

func _on_item_picked_up(item_type: String, item_data):
	"""物品拾取回调"""
	show_pickup_feedback(item_type, item_data)

func show_pickup_feedback(item_type: String, item_data):
	"""显示拾取反馈"""
	var feedback_text = ""
	
	match item_type:
		"weapon":
			if item_data is WeaponData:
				feedback_text = "获得武器: " + item_data.weapon_name
			else:
				feedback_text = "获得武器"
		"loot":
			feedback_text = "获得物品"
		"skill":
			if item_data is SkillData:
				feedback_text = "学会技能: " + item_data.skill_name
			else:
				feedback_text = "学会技能"
		_:
			feedback_text = "获得物品"
	
	create_floating_text(feedback_text, Color.GREEN)

func create_floating_text(text: String, color: Color):
	"""创建浮动文字效果"""
	var floating_label = Label.new()
	floating_label.text = text
	floating_label.add_theme_font_size_override("font_size", 20)
	floating_label.add_theme_color_override("font_color", color)
	floating_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	floating_label.add_theme_constant_override("shadow_offset_x", 2)
	floating_label.add_theme_constant_override("shadow_offset_y", 2)
	floating_label.position = Vector2(get_viewport().size.x / 2 - 100, get_viewport().size.y / 2)
	floating_label.z_index = 100
	
	add_child(floating_label)
	
	# 浮动动画
	var tween = create_tween()
	tween.parallel().tween_property(floating_label, "position:y", floating_label.position.y - 50, 1.5)
	tween.parallel().tween_property(floating_label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(floating_label.queue_free)

# 信号回调函数
func _on_health_changed(current_health: int, max_health: int):
	"""血量改变回调"""
	update_health_display(current_health, max_health)

func _on_energy_changed(current_energy: int, max_energy: int):
	"""能量改变回调"""
	update_energy_display(current_energy, max_energy)

func _on_ammo_updated(weapon_slot: int, magazine_ammo: int, total_ammo: int):
	"""弹药更新回调"""
	# 只有当前激活武器的弹药变化才更新显示
	if weapon_slot == WeaponSystem.active_weapon_slot:
		ammo_label.text = str(magazine_ammo) + "/" + str(total_ammo)

func _on_weapon_switched(weapon: WeaponData, slot: int):
	"""武器切换回调"""
	update_weapon_display()

func _on_weapon_equipped(weapon: WeaponData, slot: int):
	"""武器装备回调"""
	update_weapon_display()

func _on_skill_equipped(skill: SkillData, slot: int):
	"""技能装备回调"""
	update_skill_display()

func show_damage_indicator(damage: int, position: Vector2):
	"""显示伤害指示器"""
	var damage_label = Label.new()
	damage_label.text = "-" + str(damage)
	damage_label.modulate = Color.RED
	damage_label.z_index = 100
	add_child(damage_label)
	
	# 设置位置
	damage_label.global_position = position
	
	# 创建动画
	var tween = create_tween()
	tween.parallel().tween_property(damage_label, "global_position", position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(damage_label.queue_free)

func show_heal_indicator(heal: int, position: Vector2):
	"""显示治疗指示器"""
	var heal_label = Label.new()
	heal_label.text = "+" + str(heal)
	heal_label.modulate = Color.GREEN
	heal_label.z_index = 100
	add_child(heal_label)
	
	heal_label.global_position = position
	
	var tween = create_tween()
	tween.parallel().tween_property(heal_label, "global_position", position + Vector2(0, -30), 0.8)
	tween.parallel().tween_property(heal_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(heal_label.queue_free)
