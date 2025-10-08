extends Node2D
@onready var node1 = $Node2D1
@onready var node2 = $Node2D2
@onready var node3 = $Node2D3

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	rotate(calculate_weapon_rotation(get_local_mouse_position()))
	pass

## 武器节点W的旋转角度计算，使B、C、m三点共线
## @param mouse_global_position 鼠标的全局坐标
func calculate_weapon_rotation(mouse_global_position: Vector2) -> float:
	# 1. 获取动态的子节点局部位置
	# 确保 $NodeB 和 $NodeC 存在，并获取它们的局部坐标

	var B_0: Vector2 = node3.position  # 局部坐标 (b_x, b_y)
	var C_0: Vector2 = node2.position  # 局部坐标 (c_x, c_y)
	
	var W: Vector2 = global_position  # 武器节点全局位置 (w_x, w_y)
	var M: Vector2 = mouse_global_position # 鼠标全局位置 (m_x, m_y)
	
	# 2. 定义常量（只计算一次）
	var A_x: float = M.x - W.x  # M_x - W_x
	var A_y: float = M.y - W.y  # M_y - W_y
	
	var dX: float = C_0.x - B_0.x # delta_x (c_x - b_x)
	var dY: float = C_0.y - B_0.y # delta_y (c_y - b_y)
	
	var Bx: float = B_0.x
	var By: float = B_0.y

	# 3. 牛顿迭代求解 f(θ) = 0
	
	# 初始猜测：直接指向 W 到 M 的向量角度
	var initial_guess: float = (M - W).angle()
	var theta: float = initial_guess
	
	for i in range(10): # 10次迭代通常足够精度
		var cos_t: float = cos(theta)
		var sin_t: float = sin(theta)
		
		# --- 通用函数 f(θ) (叉积) ---
		# B'C' 向量: (dX*cos_t - dY*sin_t, dX*sin_t + dY*cos_t)
		var BC_x = dX * cos_t - dY * sin_t
		var BC_y = dX * sin_t + dY * cos_t
		
		# B'M 向量: (A_x - (Bx*cos_t - By*sin_t), A_y - (Bx*sin_t + By*cos_t))
		var BM_x = A_x - (Bx * cos_t - By * sin_t)
		var BM_y = A_y - (Bx * sin_t + By * cos_t)
		
		# f(θ) = BC_x * BM_y - BC_y * BM_x (叉积)
		var f: float = BC_x * BM_y - BC_y * BM_x
		
		# --- 通用导函数 f'(θ) ---
		# 导函数 f'(θ) = d/dθ (BC_x * BM_y - BC_y * BM_x)
		
		# d/dθ(BC_x) = -dX*sin_t - dY*cos_t = -BC_y
		var dBC_x = -BC_y
		# d/dθ(BC_y) = dX*cos_t - dY*sin_t = BC_x
		var dBC_y = BC_x
		
		# d/dθ(BM_x) = d/dθ(-Bx*cos_t + By*sin_t) = Bx*sin_t + By*cos_t
		var dBM_x = Bx * sin_t + By * cos_t
		# d/dθ(BM_y) = d/dθ(-Bx*sin_t - By*cos_t) = -Bx*cos_t + By*sin_t
		var dBM_y = -Bx * cos_t + By * sin_t
		
		# 乘法导数法则: (uv)' = u'v + uv'
		var df: float = (dBC_x * BM_y + BC_x * dBM_y) - (dBC_y * BM_x + BC_y * dBM_x)
		
		# 避免除以零
		if abs(df) < 0.0001:
			break
		
		theta = theta - f / df
		
	return theta # 返回弧度

# --- 脚本使用示例 ---

# func _process(delta):
#     var mouse_pos: Vector2 = get_global_mouse_position()
#     var rotation_rad: float = calculate_weapon_rotation(mouse_pos)
#     
#     # 将计算出的弧度值赋给自身的 rotation 属性
#     rotation = rotation_rad
