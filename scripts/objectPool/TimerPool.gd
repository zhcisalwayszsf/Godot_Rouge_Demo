extends Node

# 对象池数组
var free_timers: Array[Timer] = []
# 使用中的 Timer 引用（防止重复归还）
var used_timers: Dictionary = {}
# 最大缓存数量
@export var max_pool_size: int = 30
# 预创建的 Timer 数量
@export var preload_count: int = 5

func _ready():
	# 预创建 Timer 到对象池
	for i in range(preload_count):
		var new_timer = create_new_timer()
		free_timers.append(new_timer)

# 创建新的 Timer 节点
func create_new_timer() -> Timer:
	var timer = Timer.new()
	timer.name = "PooledTimer_" + str(randi())
	timer.one_shot = false
	add_child(timer)
	return timer

# 获取空闲 Timer
func get_timer() -> Timer:
	var timer: Timer
	
	# 从空闲池中获取
	if free_timers.size() > 0:
		timer = free_timers.pop_back()
		# 双重检查确保 Timer 有效
		if not is_instance_valid(timer):
			return get_timer()  # 递归重试
	else:
		# 创建新的 Timer
		timer = create_new_timer()
	
	# 重置 Timer 状态
	reset_timer(timer)
	
	# 加入使用中的字典
	used_timers[timer.get_instance_id()] = timer
	
	return timer

# 重置 Timer 到初始状态
func reset_timer(timer: Timer):
	if not is_instance_valid(timer):
		return
		
	# 停止计时器
	timer.stop()
	
	# 断开所有信号连接
	var connections = timer.get_signal_connection_list("timeout")
	for connection in connections:
		if timer.is_connected("timeout", connection.callable):
			timer.disconnect("timeout", connection.callable)
	
	# 重置基本属性
	timer.one_shot = false
	timer.wait_time = 1.0
	timer.autostart = false
	
	# 清除自定义元数据
	if timer.has_meta("pool_callback"):
		timer.remove_meta("pool_callback")
	if timer.has_meta("pool_type"):
		timer.remove_meta("pool_type")

# 归还 Timer 到对象池
func return_timer(timer: Timer):
	if not is_instance_valid(timer):
		return
	
	var timer_id = timer.get_instance_id()
	
	# 检查是否已经归还过
	if not used_timers.has(timer_id):
		push_warning("Timer 已经归还或不属于此对象池")
		return
	
	# 从使用中移除
	used_timers.erase(timer_id)
	
	# 重置 Timer 状态
	reset_timer(timer)
	
	# 归还到空闲池或销毁
	if free_timers.size() < max_pool_size:
		free_timers.append(timer)
	else:
		timer.queue_free()

# 创建一次性计时器
func create_one_shot_timer(wait_time: float, callback: Callable) -> Timer:
	var timer = get_timer()
	timer.one_shot = true
	timer.wait_time = wait_time
	
	# 设置元数据标记
	timer.set_meta("pool_type", "one_shot")
	timer.set_meta("pool_callback", callback)
	
	# 连接超时信号，使用弱引用避免循环引用
	timer.connect("timeout", _on_one_shot_timeout.bind(timer), CONNECT_ONE_SHOT)
	
	return timer

# 一次性计时器超时处理
func _on_one_shot_timeout(timer: Timer):
	if not is_instance_valid(timer):
		return
	
	# 获取回调函数
	var callback = timer.get_meta("pool_callback", null)
	
	# 先归还 Timer，再执行回调（避免回调中的异常影响归还）
	return_timer(timer)
	
	# 执行回调
	if callback != null and callback.is_valid():
		callback.call()

# 创建循环计时器
func create_loop_timer(wait_time: float, callback: Callable) -> Timer:
	var timer = get_timer()
	timer.one_shot = false
	timer.wait_time = wait_time
	
	# 设置元数据标记
	timer.set_meta("pool_type", "loop")
	timer.set_meta("pool_callback", callback)
	
	# 连接超时信号
	timer.connect("timeout", callback)
	
	return timer

# 便捷方法：创建并立即启动一次性计时器
func start_one_shot_timer(wait_time: float, callback: Callable) -> Timer:
	var timer = create_one_shot_timer(wait_time, callback)
	timer.start()
	return timer

# 便捷方法：创建并立即启动循环计时器
func start_loop_timer(wait_time: float, callback: Callable) -> Timer:
	var timer = create_loop_timer(wait_time, callback)
	timer.start()
	return timer

# 强制归还所有使用中的 Timer
func return_all_used_timers():
	var timers_to_return = used_timers.values()
	for timer in timers_to_return:
		return_timer(timer)

# 清理所有 Timer
func clear_all_timers():
	# 归还所有使用中的
	return_all_used_timers()
	
	# 清理空闲的
	for timer in free_timers:
		if is_instance_valid(timer):
			timer.queue_free()
	free_timers.clear()

# 获取对象池状态信息
func get_pool_info() -> Dictionary:
	return {
		"free_count": free_timers.size(),
		"used_count": used_timers.size(),
		"total_count": free_timers.size() + used_timers.size(),
		"max_pool_size": max_pool_size,
		"preload_count": preload_count
	}

# 节点退出时清理
func _exit_tree():
	clear_all_timers()
