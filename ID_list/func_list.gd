extends Node
class_name FuncsList
static var funcs_by_id={
	-1:{
		"id":-1,
		"name":"error",
		"function": (func():
			pass
			)
	},
	0:{
		"id":0,
		"name":"test",
		"function": (func():
			print("来自函数库func_list：这是测试函数")
			)
		},
	}

static func get_func_by_id(id:int)->Callable:
	var p_func
	if funcs_by_id.get(id,{}).has("function"):
		p_func = funcs_by_id.get(id,{}).function
	else:
		p_func = func(): pass
	return p_func
	
static func get_func_dict_by_id(id:int)->Dictionary:
	return funcs_by_id.get(id,funcs_by_id.get(-1))
