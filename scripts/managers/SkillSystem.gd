# res://scripts/managers/SkillSystem.gd
extends Node


# 常用参数系数——技能组部分
var primary_speed_multiplier: float = 1.0
var primary_damage_multiplier: float = 1.0
var primary_armor_multiplier: float = 1.0
var primary_max_health_multiplier: float = 1.0

var secondary_speed_multiplier: float = 1.0
var secondary_damage_multiplier: float = 1.0
var secondary_armor_multiplier: float = 1.0
var secondary_max_health_multiplier: float = 1.0

# 技能生效状态
var primary_skill_is_active: bool = false
var secondary_skill_is_active: bool = false

var health_from_skill
var armor_from_skill
var speed_from_skill
var damage_from_skill

# 技能装备状态
var primary_skill_data: SkillData = null
var secondary_skill_data: SkillData = null

# 冷却计时器
var primary_cd_timer: Timer
var secondary_cd_timer: Timer
var primary_in_cd:bool=false
var secondary_in_cd:bool=false

var current_primary_cd:float=0
var current_secondary_cd:float=0

"""改动处"""

""""""
# 技能升级等级
var primary_skill_level: int = 1
var secondary_skill_level: int = 1

# 技能脚本路径
var skill_scenes_path: String = "res://scripts/skills/"

# 施法状态
var is_casting_primary: bool = false
var is_casting_secondary: bool = false

"""改动处"""
var primary_cast_timer: Timer
var secondary_cast_timer: Timer
""""""
var skill_pivot: Node2D = null

#施法位置缓存
var mouse_position:Vector2 = Vector2(0,0)

# 持续技能效果跟踪
var active_area_effects: Array[Dictionary] = []

# 信号
signal skill_cast(skill_data: SkillData, slot: int, position: Vector2, direction: Vector2)
signal skill_equipped(skill_data: SkillData, slot: int)
signal skill_upgraded(skill_data: SkillData, slot: int, new_level: int)
signal skill_cooldown_started(slot: int, duration: float)
signal skill_cooldown_finished(slot: int)
signal primary_skill_ready()
signal secondary_skill_ready()
signal skill_unequipped(skill_data: SkillData, slot: int)

signal cast_strat()
signal cast_finish()

func _ready():
	print("SkillSystem 初始化完成")
	setup_timer()

func _process(delta):
	return

# === 初始化 ===
func initialize_default_skills():
	"""初始化默认技能"""
	var default_secondary_skill = load("res://resources/skills/SecondarySkill/Skill_SimpleDash.tres") as SkillData
	if default_secondary_skill:
		equip_skill_with_script(default_secondary_skill, 1)

func set_skill_pivot(p_pivot: Node2D):
	"""设置技能锚点"""
	skill_pivot = p_pivot
	print("设置技能锚点: ", p_pivot.name)

func setup_timer():
	#主技能施法前摇
	primary_cast_timer = Timer.new()
	self.add_child(primary_cast_timer)
	primary_cast_timer.one_shot=true
	primary_cast_timer.autostart=false
	primary_cast_timer.timeout.connect(finish_casting_primary)
	#副技能施法前摇
	secondary_cast_timer = Timer.new()
	self.add_child(secondary_cast_timer)
	secondary_cast_timer.one_shot=true
	secondary_cast_timer.autostart=false
	secondary_cast_timer.timeout.connect(finish_casting_secondary)
	
	#主技能cd计时器
	primary_cd_timer = Timer.new()
	self.add_child(primary_cd_timer)
	primary_cd_timer.one_shot=true
	primary_cd_timer.autostart=false
	primary_cd_timer.timeout.connect(func():cooldown_finish(0))#labmda表达式
	#副技能cd计时器
	secondary_cd_timer = Timer.new()
	self.add_child(secondary_cd_timer)
	secondary_cd_timer.one_shot=true
	secondary_cd_timer.autostart=false
	secondary_cd_timer.timeout.connect(func():cooldown_finish(1))#labmda表达式

# === 技能装备系统 ===
func equip_skill_with_script(p_skill_data: SkillData, p_slot: int) -> bool:
	"""装备技能到指定槽位"""
	if not p_skill_data or p_slot < 0 or p_slot > 1:
		print("装备技能失败: 无效参数")
		return false
	
	if p_slot == 0:
		primary_skill_data = p_skill_data
		primary_skill_level = 1
		primary_cd_timer.wait_time = p_skill_data.cooldown_time
		PlayerDataManager.equip_primary_skill(p_skill_data)
	else:
		secondary_skill_data = p_skill_data
		secondary_skill_level = 1
		secondary_cd_timer.wait_time = p_skill_data.cooldown_time
		PlayerDataManager.equip_secondary_skill(p_skill_data)
		
	var is_equiped_script = equip_skill_script(p_skill_data.skill_name, p_slot)
	if not is_equiped_script:
		print("装备技能失败: 装备脚本失败")
		return false
	
	skill_equipped.emit(p_skill_data, p_slot)
	print("SkillSystem：装备技能: ", p_skill_data.skill_name, " 到槽位 ", p_slot)
	return true

func load_skill_script(skill_name: String, slot: int) -> Script:
	"""加载技能脚本文件"""
	var script_path = null
	if slot == 0:
		script_path = skill_scenes_path + "PrimarySkills/" + "Skill_" + skill_name + ".gd"
	if slot == 1:
		script_path = skill_scenes_path + "SecondarySkills/" + "Skill_"  + skill_name + ".gd"
		
	if FileAccess.file_exists(script_path):
		return load(script_path) as Script
	else:
		print("技能脚本不存在: ", script_path)
		return null

func equip_skill_script(p_skill_name: String, p_slot: int) -> bool:
	"""挂载技能脚本"""
	var skill_script = load_skill_script(p_skill_name, p_slot)
	if not skill_script:
		print("装备技能失败: 无法加载技能脚本 ", p_skill_name)
		return false
		
	if skill_pivot:
		var skill_node
		if p_slot == 0:
			skill_node = skill_pivot.get_node("PrimarySkill")
		elif p_slot == 1:
			skill_node = skill_pivot.get_node("SecondarySkill")
		else:
			print("加载技能脚本失败：无效的技能槽")
			return false
		# 设置脚本
		skill_node.set_script(skill_script)
		skill_node.skill_data = get_skill_data(p_slot)
		# ✅ 关键：手动调用初始化方法
		if skill_node.has_method("initialize_skill"):
			skill_node.initialize_skill()
		
		# ✅ 启用 process（如果需要）
		if skill_node.has_method("_process"):
			skill_node.set_process(true)
		if skill_node.has_method("_physics_process"):
			skill_node.set_physics_process(true)
	return true
	
func unequip_skill_scrtpt(p_slot: int) -> bool:
	"""卸载技能脚本"""
	if skill_pivot:
		if p_slot == 0:
			skill_pivot.get_node("PrimarySkill").set_script(null)
		elif p_slot == 1:
			skill_pivot.get_node("SecondarySkill").set_script(null)
		else:
			print("卸载技能脚本失败：无效的技能槽")
			return false
	return true

# === 技能释放系统 ===
func try_cast_primary_skill(caster_position: Vector2, target_direction: Vector2) -> bool:
	"""尝试释放主技能"""
	return try_cast_skill(0, caster_position, target_direction)

func try_cast_secondary_skill(caster_position: Vector2, target_direction: Vector2) -> bool:
	"""尝试释放副技能"""
	return try_cast_skill(1, caster_position, target_direction)

func try_cast_skill(slot: int, caster_position: Vector2, target_direction: Vector2) -> bool:
	"""尝试释放指定槽位的技能"""
	if not can_cast_skill(slot):
		return false
	
	var skill_data = get_skill_data(slot)
	if not skill_data:
		return false
	
	if not consume_skill_resources(skill_data, slot):
		return false
	
	if skill_data.cast_time > 0:
		start_casting(slot, skill_data, caster_position, target_direction)

	else:
		execute_skill(skill_data, slot, caster_position, target_direction)
	
	return true

func can_cast_skill(slot: int) -> bool:
	"""检查是否可以释放技能"""
	var skill_data = get_skill_data(slot)
	if not skill_data:
		return false
		
	if get_cooldown_timer(slot) > 0:
		return false
	
	if is_casting(slot):
		return false
	
	if slot == 0:
		return PlayerDataManager.get_energy() >= skill_data.energy_cost
	else:
		return true

func consume_skill_resources(skill_data: SkillData, slot: int) -> bool:
	"""消耗技能所需资源"""
	if slot == 0:
		return PlayerDataManager.consume_energy(skill_data.energy_cost)
	return true

"""改动处"""
func start_casting(slot: int, skill_data: SkillData, position: Vector2 = Vector2.ZERO, direction: Vector2 = Vector2.RIGHT):
	"""开始施法"""
	if slot == 0:
		is_casting_primary = true
		primary_cast_timer.start(skill_data.cast_time)
	else:
		is_casting_secondary = true
		secondary_cast_timer.start(skill_data.cast_time)
	
	#print("开始施法: ", skill_data.skill_name, " 施法时间: ", skill_data.cast_time)

"""修改处"""
func finish_casting_primary():
	"""完成施法1"""
	var skill_data = get_skill_data(0)
	if not skill_data:
		return
	
	var caster_position = Vector2.ZERO
	var target_direction = Vector2.RIGHT
	
	if PlayerDataManager.player_node:
		caster_position = PlayerDataManager.player_node.global_position
		target_direction = (PlayerDataManager.player_node.get_global_mouse_position() - caster_position).normalized()
	execute_skill(skill_data, 0, caster_position, target_direction)
	is_casting_primary = false
	
func finish_casting_secondary():
	"""完成施法2"""
	var skill_data = get_skill_data(1)
	if not skill_data:
		return
	
	var caster_position = Vector2.ZERO
	var target_direction = Vector2.RIGHT
	
	if PlayerDataManager.player_node:
		caster_position = PlayerDataManager.player_node.global_position
		target_direction = (PlayerDataManager.player_node.get_global_mouse_position() - caster_position).normalized()
	execute_skill(skill_data, 1, caster_position, target_direction)
	
	is_casting_secondary = false

func execute_skill(skill_data: SkillData, slot: int,  position: Vector2 = Vector2.ZERO, direction: Vector2 = Vector2.RIGHT,distance:float=-1):
	"""执行技能效果"""
	var final_skill_data = apply_skill_upgrades(skill_data, slot)
	
	skill_cast.emit(final_skill_data, slot, position, direction)
	
	var skill_node 
	
	match slot:
		0:
			skill_node = PlayerDataManager.player_node.get_node("SkillPivot/PrimarySkill")
			if not skill_node.get_script == null:
				if skill_node.has_method("main_funtion"):
					skill_node.main_funtion()
		1:
			skill_node = PlayerDataManager.player_node.get_node("SkillPivot/SecondarySkill")
			if not skill_node.get_script == null:
				if skill_node.has_method("main_funtion"):
					skill_node.main_funtion()
	# 根据技能类型执行不同效果
	#有伤害模块
	if final_skill_data.has_skill_type(0):
		execute_damage_skill(final_skill_data, position, direction)
	
	#有位移模块
	if final_skill_data.has_skill_type(1):
		distance = distance if distance>0 else skill_data.distance
		execute_movement_skill(final_skill_data,distance)
		
	#有控制模块
	if final_skill_data.has_skill_type(2):
		execute_control_skill(final_skill_data, position, direction)
		
	#有增益模块
	if final_skill_data.has_skill_type(3):
		execute_buff_skill(final_skill_data, position)
	
	if AudioSystem:
		AudioSystem.play_skill_sound(skill_data.skill_name)
		
	start_cooldown(slot, final_skill_data)
	#print("释放技能: ", final_skill_data.skill_name, " 位置: ", position,"类型：", final_skill_data.get_skill_type_names())

# === 技能效果执行 ===
###伤害类
func execute_damage_skill(skill_data: SkillData, position: Vector2, direction: Vector2)->Dictionary:
	"""执行伤害技能"""
	match skill_data.action_type:
		0: # 射线型
			var attack_area:Dictionary = execute_line_damage(skill_data, position, direction,skill_data.line_width)
			return {"line_type":attack_area}
		1: # 范围持续型
			var attack_area:Dictionary
			match skill_data.area_duration_acting_position:
				1: 
					mouse_position =  PlayerDataManager.player_node.get_global_mouse_position()
					#设定释放技能位置，超出技能最大释放距离则取最远端
					mouse_position = mouse_position if (
						(mouse_position-position).length()<skill_data.area_max_distance
						) else (mouse_position-position).normalized()*skill_data.area_max_distance
						
					attack_area = execute_area_damage(skill_data, mouse_position)
					return {"area_tpye":attack_area}
				_:
					attack_area = execute_area_damage(skill_data, position)
					return {"area_tpye":attack_area}
		2: # 中心瞬发型
			var attack_area:Dictionary = execute_area_damage(skill_data,position,9999999,true)
			return {"broadcast_tpye":attack_area}
		3: # 范围随机型
			var attack_area:Dictionary 
			match skill_data.area_duration_acting_position:
				1: 
					mouse_position =  PlayerDataManager.player_node.get_global_mouse_position()
					#设定释放技能位置，超出技能最大释放距离则取最远端
					mouse_position = mouse_position if (
						(mouse_position-position).length()<skill_data.area_max_distance
						) else (mouse_position-position).normalized()*skill_data.area_max_distance
						
					attack_area = execute_area_damage(skill_data, mouse_position,9999999,true,true)
					return {"area_random_tpye":attack_area}
				_:
					attack_area = execute_area_damage(skill_data,position,9999999,true,true)
					return {"area_random_tpye":attack_area}
		4:#子弹型
			return {}
	return {}

func execute_line_damage(skill_data: SkillData, position: Vector2, direction: Vector2,line_width:float)->Dictionary:
	"""执行直线伤害"""
	var enemies = get_enemies_in_line(position, direction, skill_data.damage_distance, skill_data.damage_target_numb,line_width)
	var a = calculate_ray_rect_corners(position, direction, skill_data.damage_distance,line_width)
	apply_damage_to_enemies(enemies, skill_data)
	#create_skill_effect("line_damage", position, skill_data)
	return a

func execute_area_damage(
	skill_data: SkillData, 
	position: Vector2,
	radius: float = 0,
	one_shot: bool = false,
	random_numb: int = 0
) -> Dictionary:
	if not radius > 0:
		radius = skill_data.area_radius if skill_data.area_radius > 0 else 0

	if skill_data.area_duration_time > 0 and (not one_shot):
		# 伤害触发计时器（循环）
		var tick_timer = TimerPool.instance.create_loop_timer(
			skill_data.area_duration_acting_tick,
			func():apply_duration_damage_tick(
					position,
					radius,
					calculate_final_damage(skill_data),
					skill_data.damage_type,
					skill_data.damage_target_numb))
		
		# 区域持续时间计时器（一次性）
		var area_timer = TimerPool.instance.create_one_shot_timer(
			skill_data.area_duration_time,
			func():
				tick_timer.stop()
				TimerPool.instance.return_timer(tick_timer))
			# area_timer会在超时后自动归还
		
		# 启动计时器
		tick_timer.start()
		area_timer.start()
		
	else:
		# 单次伤害逻辑不变
		var enemies = get_enemies_in_range(position, radius, random_numb) if random_numb > 0 else get_enemies_in_range(position, radius)
		apply_damage_to_enemies(enemies, skill_data, calculate_final_damage(skill_data))
		
	#create_skill_effect("area_damage", position, skill_data)
	return get_circle_area(position, radius)

func calculate_final_damage(skill_data: SkillData) -> float:
	"""计算最终伤害"""
	var final_damage =skill_data.damage* skill_data.damage_multiplier + skill_data.extra_damage
	
	# 应用玩家伤害倍率
	final_damage *= PlayerDataManager.get_final_damage_multiplier()
	
	return final_damage

func apply_damage_to_enemies(enemies: Array, skill_data: SkillData,damage:float=0):
	"""对敌人数组应用伤害"""
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var damage_amount = damage if damage>0 else calculate_final_damage(skill_data)
			enemy.take_damage(damage, skill_data.damage_type)
			# 应用持续伤害
			if skill_data.continue_damage > 0:
				if enemy.has_method("apply_dot"):
					enemy.apply_dot(skill_data.continue_damage, skill_data.continue_damage_time, skill_data.continue_damage_frequent)

###控制类
func execute_control_skill(skill_data: SkillData,position: Vector2, direction: Vector2,random_numb:int=-1):
	"""执行控制技能"""
	var dictionary :Dictionary = execute_control_skill_ways(
		skill_data,position,direction,random_numb if random_numb>=0 else skill_data.control_target_numb)
	var enemies:Array = dictionary["enemies"]
	var area:Dictionary = dictionary["area"]
	if dictionary["type"]  == "circle" or dictionary["type"]  == "rectangle":
		#draw_area()或者execute_control_skill.emit(area)
		print("执行控制技能，识别作用区域为：",dictionary["type"])
	else:
		return
	"""enemy.take_control_xxxx(skill_data)====>enemy.take_control_xxxx(skill_data,new_continue_time)；重载，时间用可自定义量"""
	if skill_data.has_control_effect_type(0):# 速度
		"""执行速度参数传递，例如设置速度为0，减少多少速度"""
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_control_speed"):
				enemy.take_control_speed(skill_data)

	if skill_data.has_control_effect_type(1):# 攻击力
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_control_speed"):
				enemy.take_control_attack(skill_data)
				
	if skill_data.has_control_effect_type(2):# 护甲
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_control_speed"):
				enemy.take_control_armor(skill_data)
		
	if skill_data.has_control_effect_type(3):# 易伤
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_control_speed"):
				enemy.take_control_vulnerable(skill_data)
				
	if skill_data.has_control_effect_type(4):# 击退
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_control_speed"):
				enemy.take_control_knockback(skill_data)
				
	if skill_data.has_control_effect_type(5): # 眩晕
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_control_speed"):
				enemy.take_control_stun(skill_data)
	return			

	#create_skill_effect("control", position, skill_data)

func modify_time_vlaue(skill_data:SkillData,value:float,continue_time:float=-1,is_control:bool=true)->float:
	var result_time
	if is_control:
		result_time = continue_time if continue_time>=0 else skill_data.control_continue_time
	else:
		result_time = continue_time	 if continue_time >= 0 else skill_data.continue_damage_time
		
	return result_time

func execute_control_skill_ways(
	skill_data:SkillData,
	position: Vector2=Vector2(0,0),
	direction: Vector2=Vector2(0,0),
	random_numb:int=0,
	action_type:int=-1,
	line_width:float=20
	)->Dictionary:
	"""根据类型返回敌人数组和area"""
	var p_type= action_type if action_type>=0 else skill_data.action_type
	match p_type:
		0: # 射线型
			var enemies:Array = get_enemies_in_line(
				position, direction, skill_data.damage_distance, skill_data.control_target_numb,line_width)
			var rectangle:Dictionary = calculate_ray_rect_corners(position, direction, skill_data.damage_distance, line_width)
			return {"enemies":enemies,"area":rectangle,"tpype":"rectangle"}
		1: # 范围持续型
			"""根据【skill_data.area_duration_acting_position】，来判断是玩家自身位置的范围，还是鼠标位置（小于距离）"""
			var enemies:Array 
			var circle:Dictionary 
			match skill_data.area_duration_acting_position:
				1: 
					mouse_position =  PlayerDataManager.player_node.get_global_mouse_position()
					#设定释放技能位置，超出技能最大释放距离则取最远端
					mouse_position = mouse_position if (
						(mouse_position-position).length()<skill_data.area_max_distance
						) else (mouse_position-position).normalized()*skill_data.area_max_distance
						
					enemies = get_enemies_in_range(mouse_position,skill_data.control_range)
					circle  = get_circle_area(position,skill_data.control_range)
				_:
					enemies = get_enemies_in_range(position,skill_data.control_range)
					circle = execute_area_damage(skill_data, position)
			return {"enemies":enemies,"area":circle,"tpype":"circle"}
		2: # 中心瞬发型
			var enemies:Array = get_enemies_in_range(position,skill_data.control_range,random_numb)
			var circle:Dictionary = get_circle_area(position,skill_data.control_range)
			return {"enemies":enemies,"area":circle,"tpype":"circle"}
		3: # 范围随机型
			var enemies:Array 
			var circle:Dictionary 
			match skill_data.area_duration_acting_position:
				1: 
					mouse_position =  PlayerDataManager.player_node.get_global_mouse_position()
					enemies = get_enemies_in_range(mouse_position,skill_data.control_range,random_numb)
					circle  = get_circle_area(position,skill_data.control_range)
				_:
					enemies = get_enemies_in_range(position,skill_data.control_range,random_numb)
					circle = execute_area_damage(skill_data, position)
			return {"enemies":enemies,"area":circle,"tpype":"circle"}
		4:#子弹型
			return {"tpype": null}
	return {"tpype": null}

###位移和增益
func execute_movement_skill(
	skill_data: SkillData,
	distance:float=-1,
	dash_time:float=-1,
	dash_extra_effect:int=0,
	dash_effect_continue_time:float=0,
	dash_type:int=-1,
	dash_with_dirction:bool=false,
	direction: Vector2=Vector2.ZERO):
	"""执行位移技能"""
	distance = distance if distance>=0 else skill_data.distance
	dash_time = dash_time if dash_time>= 0 else skill_data.dash_time
	dash_type = dash_type if dash_type>=0 else skill_data.dash_type
	var player:CharacterBody2D = PlayerDataManager.player_node
	var dash_vector2:Vector2 = Vector2.ZERO
	dash_type = dash_type if dash_type >=0 else skill_data.dash_type
	
	var a = (player.get_global_mouse_position()-player.global_position)
	dash_vector2 = a if a.length()<=distance else a.normalized()*distance
	var dash_direction = player.get_input_direction() if not player.get_input_direction() == Vector2.ZERO else dash_vector2
	if dash_type == 0:
		player.dash(dash_direction,distance,dash_time)
	elif dash_type == 1:
		player.blink_to(player.global_position + dash_direction)
	if skill_data.has_movement_method(0):
		apply_movement_effect(skill_data,0)
	if skill_data.has_movement_method(1):
		apply_movement_effect(skill_data,1)
	
	#create_skill_effect("movement", position, skill_data)

func execute_buff_skill(skill_data: SkillData, position: Vector2):
	"""执行增益技能"""
	if PlayerDataManager.player_node:
		apply_buff_effect(skill_data,PlayerDataManager.player_node)
	#create_skill_effect("buff", position, skill_data)

func apply_movement_effect(skill_data: SkillData,type:int=0,time:float=0):
	"""应用无敌或无碰撞效果"""
	
	if skill_data.has_movement_method(0): # 无敌
		#print("有无敌效果，按0来取",skill_data.has_movement_method(0))
		time = time if time>0 else skill_data.dash_effect_continue_time
		PlayerDataManager.player_node.set_invulnerable(time)
	if skill_data.has_movement_method(1): # 无碰撞
		#print("有无碰撞效果，按1来取",skill_data.has_movement_method(1))
		time = time if time>0 else skill_data.dash_effect_continue_time
		PlayerDataManager.player_node.set_no_collision(time)

func apply_buff_effect(skill_data: SkillData,target:CharacterBody2D,time:float=0):
	"""应用增益效果"""
	var player = PlayerDataManager.player_node
	
	if skill_data.has_buff_type(2):
		var row_speed = PlayerDataManager.player_stats.move_speed
		PlayerDataManager.player_stats.move_speed += skill_data.buff_value[2]
		var buff_timer= TimerPool.create_one_shot_timer(
			skill_data.buff_time[2],
			func():
				PlayerDataManager.player_stats.move_speed = row_speed)
		buff_timer.start()
	
	if skill_data.has_buff_type(0):
		var row_damage_multiplier = PlayerDataManager.player_stats.damage_multiplier
		PlayerDataManager.player_stats.damage_multiplier = skill_data.buff_value[0]
		var buff_timer= TimerPool.create_one_shot_timer(
			skill_data.buff_time[0] if time >0 else skill_data.buff_time[0],
			func():
				PlayerDataManager.player_stats.damage_multiplier = row_damage_multiplier)
		buff_timer.start()
		
		"""
	if skill_data.has_buff_type(1):
		var row_armor_value = PlayerDataManager.player_stats.armor_value
		PlayerDataManager.player_stats.vulneralbe_multiplier = skill_data.buff_value[1]
		var buff_timer = TimerPool.instance.create_one_shot_timer(
			skill_data.buff_time[1] if time >0 else skill_data.buff_time[1],
			func():
				PlayerDataManager.player_stats.armor_value = row_armor_value)
		buff_timer.start()
		"""
		"""
	if skill_data.has_buff_type(3):
		var row_attack_frequency = PlayerDataManager.player_stats.attack_frequency
		PlayerDataManager.player_stats.vulneralbe_multiplier = skill_data.buff_value[3]
		var buff_timer TimerPool.instance.create_one_shot_timer(
			skill_data.buff_time[3] if time >0 else skill_data.buff_time[3],
			func():
				PlayerDataManager.player_stats.attack_frequency = row_attack_frequency)
		buff_timer.start()
	"""
	"""
	if skill_data.has_buff_type(4):
		var row_damage_reduction = PlayerDataManager.player_stats.damage_reduction
		PlayerDataManager.player_stats.vulneralbe_multiplier = skill_data.buff_value[4]
		var = TimerPool.instance.create_one_shot_timer(
			skill_data.buff_time[4] if time >0 else skill_data.buff_time[4],
			func():
				PlayerDataManager.player_stats.damage_reduction = row_damage_reduction)
		buff_timer.start()
	"""
	"""
	if skill_data.has_buff_type(5):
		var row_dodge_chance = PlayerDataManager.player_stats.dodge_chance
		PlayerDataManager.player_stats.dodge_chance = skill_data.buff_value[5]
		var = TimerPool.instance.create_one_shot_timer(
			skill_data.buff_time[5] if time >0 else skill_data.buff_time[5],
			func():
				PlayerDataManager.player_stats.damage_reduction = row_dodge_chance)
		buff_timer.start()
	s"""	
	if skill_data.has_buff_type(6):
		PlayerDataManager.player_node.set_invulnerable(skill_data.buff_time[6] if time >0 else skill_data.buff_time[6])
		
	if skill_data.has_buff_type(7):
		PlayerDataManager.player_node.set_no_collision(skill_data.buff_time[7] if time >0 else skill_data.buff_time[7])
		
	if skill_data.has_buff_type(8):
		var row_unstoppable = PlayerDataManager.player_stats.unstoppable
		PlayerDataManager.player_stats.unstoppable = skill_data.buff_value[8]
		var buff_timer = TimerPool.instance.create_one_shot_timer(
			skill_data.buff_time[8] if time >0 else skill_data.buff_time[8],
			func():
				PlayerDataManager.player_stats.unstoppable = row_unstoppable)
		buff_timer.start()
		

# === 伤害和控制应用===
func apply_duration_damage_tick(position:Vector2,radius:float,tick_damage:float,damage_type:int=1,target_numb:int=0,):
	"""应用范围持续造成伤害效果的一次tick"""
	var enemies
	enemies = get_enemies_in_range(position, radius)
	if target_numb > 0:
		enemies = enemies.slice(0,target_numb)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(tick_damage,damage_type)

func apply_duration_control(position:Vector2,radius:float,target_numb:int=0)->Dictionary:
	"""应用控制持续效果"""
	var enemies
	enemies = get_enemies_in_range(position, radius)
	if target_numb > 0:
		enemies = enemies.slice(0,target_numb)
	#for enemy in enemies:
		#if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			#enemy.take_damage(tick_damage,damage_type)
	var circle = {"position":position,"radius":radius}
	return circle

# === 辅助方法 ===
func get_enemies_in_range(center: Vector2, range: float,random_numb:int=0) -> Array:
	"""获取圆形范围内的敌人"""
	var enemies = []
	var enemy_nodes = get_tree().get_nodes_in_group("enemies")
	if random_numb>0:
		var result_enemies=[]
		for i in range(random_numb):
			var ramdom_index = randi() % enemy_nodes.size()
			result_enemies.append(enemy_nodes[ramdom_index])
		return result_enemies
		
	for enemy in enemy_nodes:
		if is_instance_valid(enemy):
			var distance = center.distance_to(enemy.global_position)
			if distance <= range:
				enemies.append(enemy)	
	return enemies

func get_circle_area(position:Vector2,radius:float)->Dictionary:
	"""获取圆形范围圆心坐标和半径的字典"""
	return {"position":position,"radius":radius}

func get_enemies_in_line(start: Vector2,direction: Vector2,range: float,max_count: int,line_width: float = 50.0) -> Array:
	"""获取射线范围内的敌人"""
	var enemies = []
	var enemy_nodes = get_tree().get_nodes_in_group("enemies")
	for enemy in enemy_nodes:
		if is_instance_valid(enemy):
			var to_enemy = enemy.global_position - start
			var projected = to_enemy.project(direction)
			if projected.dot(direction) > 0 and projected.length() <= range:
				var perpendicular_distance = (to_enemy - projected).length()
				if perpendicular_distance <= line_width:
					enemies.append(enemy)
	if max_count > 0:
		enemies = enemies.slice(0, max_count)
	return enemies

func calculate_ray_rect_corners(start: Vector2,direction: Vector2,range: float,line_width: float) -> Dictionary:
	"""获取矩形四角坐标点"""
	# 步骤1：将方向向量归一化（确保长度为1，方便计算）
	var dir_unit = direction.normalized()
	# 步骤2：计算方向向量的垂直向量（用于生成矩形的“宽度方向”）
	# 垂直向量 = (-y, x)（顺时针旋转90°，也可写(x, -y)逆时针，不影响四角顺序）
	var perp_unit = Vector2(-dir_unit.y, dir_unit.x)
	# 步骤3：计算宽度的一半（矩形从中心线向两侧偏移的距离）
	var half_width = line_width / 2.0
	
	# 步骤4：计算矩形的两个端点（射线的起点和终点）
	var ray_start = start  # 射线起点（矩形的“近端”）
	var ray_end = start + dir_unit * range  # 射线终点（矩形的“远端”）
	
	# 步骤5：计算四个角的坐标（从近端/远端向垂直方向偏移half_width）
	var corner1 = ray_start + perp_unit * half_width  # 近端-上（相对方向）
	var corner2 = ray_start - perp_unit * half_width  # 近端-下（相对方向）
	var corner3 = ray_end - perp_unit * half_width    # 远端-下（相对方向）
	var corner4 = ray_end + perp_unit * half_width    # 远端-上（相对方向）
	
	# 返回四个角坐标（顺序：近端上→近端下→远端下→远端上，闭合矩形）
	return {"corner1":corner1, "corner2":corner2,"corner3": corner3, "corner4":corner4}

func get_all_enemies() -> Array:
	"""获取所有敌人"""
	return get_tree().get_nodes_in_group("enemies")

func create_skill_effect(effect_type: String, position: Vector2, skill_data: SkillData):
	"""创建技能视觉效果"""
	#print("创建技能效果: ", effect_type, " 位置: ", position, " 技能: ", skill_data.skill_name)

# === 冷却系统 ===
func start_cooldown(slot:int,skill_data:SkillData):
	"""技能进入冷却"""
	var cooldown_time = calculate_final_cooldown(skill_data, slot)
	match slot:
		0:
			primary_cd_timer.start(cooldown_time)
			primary_in_cd = true
		1:
			secondary_cd_timer.start(cooldown_time)
			secondary_in_cd = true
	skill_cooldown_started.emit(slot,cooldown_time)
	
func cooldown_finish(slot:int):
	"""技能冷却结束，信号发射器"""
	match slot:
		0:
			primary_in_cd = false
		1:
			secondary_in_cd = false
	skill_cooldown_finished.emit(slot)

func get_is_in_cd(slot:int)->bool:
	"""技能是否在cd"""
	match slot:
		0:
			return primary_in_cd
		1:
			return secondary_in_cd
	print("错误！不能获取是否在冷却状态,已返回false")
	return false

func erupt_or_add_cd(slot:int,new_cd:float=0):
	"""临时设置技能槽技能的cd，正数减cd，负数加cd,结果小于0直接结束cd"""
	if get_is_in_cd(slot):
		match slot:
			0:
				var result = primary_cd_timer.wait_time+new_cd
				if result>0:
					primary_cd_timer.stop()
					primary_cd_timer.start(result)
				else:
					primary_cd_timer.stop()
					primary_cd_timer.timeout.emit()
			1:
				var result = secondary_cd_timer.wait_time+new_cd
				if result>0:
					secondary_cd_timer.stop()
					secondary_cd_timer.start(result)
				else:
					secondary_cd_timer.stop()
					secondary_cd_timer.timeout.emit()
	else:
		print("警告！临时设置cd错误！")

func set_skill_cd(slot:int,new_cd:float=1):
	"""重设本地cd参数"""
	if (not new_cd>0):
		print("警告！cd设置失败：错误的参数")
		return
	match slot:
		0:
			current_primary_cd=new_cd
		1:
			current_secondary_cd=new_cd

func calculate_final_cooldown(skill_data: SkillData, slot: int) -> float:
	"""计算最终冷却时间"""
	var base_cooldown = skill_data.cooldown_time
	if slot==0:
		base_cooldown = current_primary_cd if current_primary_cd>0 else base_cooldown
	elif slot==1:
		base_cooldown =current_secondary_cd if current_primary_cd>0 else base_cooldown
	
	var level = get_skill_level(slot)
	
	if level > 1:
		var bonus_levels = level - 1
		base_cooldown -= bonus_levels * skill_data.cd_reduction_per_level
	
	base_cooldown *= get_player_cooldown_modifier()
	return max(0.1, base_cooldown)

func get_player_cooldown_modifier() -> float:
	"""获取玩家冷却修正"""
	var modifier = 1.0
	if PlayerDataManager.has_upgrade("cooldown_reduction"):
		var reduction_count = PlayerDataManager.get_upgrade_count("cooldown_reduction")
		modifier *= pow(0.9, reduction_count)
	return modifier

# === 施法系统 ===
func is_casting(slot: int) -> bool:
	"""检查是否正在施法"""
	if slot == 0:
		return is_casting_primary
	elif slot == 1:
		return is_casting_secondary
	return false

func cancel_casting(slot: int):
	"""取消施法"""
	if slot == 0 and is_casting_primary:
		is_casting_primary = false
		primary_cast_timer.stop()
	elif slot == 1 and is_casting_secondary:
		is_casting_secondary = false
		secondary_cast_timer.stop()

# === 技能升级系统 ===
func upgrade_skill(slot: int) -> bool:
	"""升级技能"""
	var skill_data = get_skill_data(slot)
	if not skill_data:
		return false
	
	var current_level = get_skill_level(slot)
	if current_level >= skill_data.max_level:
		return false
	
	if slot == 0:
		primary_skill_level += 1
	else:
		secondary_skill_level += 1
	
	var new_level = get_skill_level(slot)
	skill_upgraded.emit(skill_data, slot, new_level)
	return true

func apply_skill_upgrades(skill_data: SkillData, slot: int) -> SkillData:
	"""应用技能升级加成"""
	var upgraded_skill = skill_data.duplicate()
	var level = get_skill_level(slot)
	
	if level > 1:
		var bonus_levels = level - 1
		upgraded_skill.damage += bonus_levels * skill_data.damage_per_level
		upgraded_skill.damage *= pow(skill_data.upgrade_damage_multiplier, bonus_levels)
	
	return upgraded_skill

# === 获取器方法 ===

func get_skill_data(slot: int) -> SkillData:
	"""获取指定槽位技能数据"""
	if slot == 0:
		return primary_skill_data
	elif slot == 1:
		return secondary_skill_data
	return null

func get_skill_level(slot: int) -> int:
	"""获取技能等级"""
	if slot == 0:
		return primary_skill_level
	elif slot == 1:
		return secondary_skill_level
	return 1

func get_cooldown_timer(slot: int) -> float:
	"""获取冷却剩余时间"""
	if slot == 0:
		return primary_cd_timer.time_left
	elif slot == 1:
		return secondary_cd_timer.time_left
	return 0.0

func is_skill_ready(slot: int) -> bool:
	"""检查技能是否准备就绪"""
	return get_cooldown_timer(slot) <= 0 and not is_casting(slot)

func has_skill(slot: int) -> bool:
	"""检查指定槽位是否有技能"""
	return get_skill_data(slot) != null

func get_skill_info(slot: int) -> String:
	"""获取技能信息字符串"""
	var skill_data = get_skill_data(slot)
	if not skill_data:
		return "空槽位"
	
	var level = get_skill_level(slot)
	var info = "%s (Lv.%d)\n" % [skill_data.skill_name, level]
	info += "描述: %s\n" % skill_data.description
	info += "伤害: %d\n" % skill_data.damage
	info += "冷却: %.1f秒\n" % calculate_final_cooldown(skill_data, slot)
	info += "范围: %.0f\n" % skill_data.effect_range
	
	if skill_data.energy_cost > 0:
		info += "能量消耗: %d\n" % skill_data.energy_cost
	
	if skill_data.special_effects.size() > 0:
		info += "特殊效果: " + ", ".join(skill_data.special_effects)
	
	return info

# === 调试功能 ===

func debug_print_status():
	"""调试打印技能系统状态"""
	print("=== SkillSystem 状态 ===")
	print("主技能: ", primary_skill_data.skill_name if primary_skill_data else "无")
	print("副技能: ", secondary_skill_data.skill_name if secondary_skill_data else "无")
	print("主技能等级: ", primary_skill_level)
	print("副技能等级: ", secondary_skill_level)
	print("主技能冷却: ", primary_cd_timer)
	print("副技能冷却: ", secondary_cd_timer)
	print("主技能施法中: ", is_casting_primary)
	print("副技能施法中: ", is_casting_secondary)
	print("========================")
