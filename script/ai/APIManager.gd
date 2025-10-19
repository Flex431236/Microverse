extends Node

# 单例实例
static var instance = null

# API URLs现在通过APIConfig统一管理

# 当前设置（从SettingsManager获取）
var current_settings = {}

# 获取单例实例
static func get_instance() -> APIManager:
	if instance == null:
		instance = Engine.get_singleton("APIManager")
		if instance == null:
			print("[APIManager] 创建新的APIManager实例")
			instance = APIManager.new()
	return instance

func _enter_tree():
	# 设置单例实例
	if instance == null:
		instance = self
	
	add_to_group("api_manager")

# 在_ready中连接设置管理器
func _ready():
	# 连接设置变化信号
	SettingsManager.settings_changed.connect(_on_settings_changed)
	# 获取当前设置
	current_settings = SettingsManager.get_settings()
	print("[APIManager] 已连接设置管理器，当前设置 - API类型：", current_settings.api_type, "，模型：", current_settings.model)

# 设置变化回调
func _on_settings_changed(new_settings: Dictionary):
	current_settings = new_settings.duplicate()
	print("[APIManager] 设置已更新 - API类型：", current_settings.api_type, "，模型：", current_settings.model)

# 生成对话（支持角色独立AI设置）
func generate_dialog(prompt: String, character_name: String = "") -> HTTPRequest:
	# 确保节点已经初始化
	if not is_inside_tree():
		push_error("APIManager is not properly initialized!")
		return null
	
	# 等待三帧以确保完全初始化
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 创建新的HTTPRequest节点，不清理之前的节点
	var http_request = HTTPRequest.new()
	# 为每个请求设置唯一名称
	http_request.name = "HTTPRequest_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
	add_child(http_request)
	
	# 设置请求完成后自动清理
	http_request.request_completed.connect(func(result, response_code, headers, body):
		# 延迟清理，确保回调函数执行完毕
		get_tree().create_timer(1.0).timeout.connect(func():
			if http_request and is_instance_valid(http_request):
				remove_child(http_request)
				http_request.queue_free()
		)
	)
	# 获取角色对应的AI设置
	var ai_settings = current_settings
	if character_name != "":
		ai_settings = SettingsManager.get_character_ai_settings(character_name)
		print("[APIManager] 为角色 ", character_name, " 使用AI设置 - API类型：", ai_settings.api_type, "，模型：", ai_settings.model)
	else:
		print("[APIManager] 使用默认AI设置 - API类型：", ai_settings.api_type, "，模型：", ai_settings.model)
	
	# 使用APIConfig构建请求
	var headers = APIConfig.build_headers(ai_settings.api_type, ai_settings.api_key)
	var request_data = APIConfig.build_request_data(ai_settings.api_type, ai_settings.model, prompt)
	var data = JSON.stringify(request_data)
	var url = APIConfig.get_url(ai_settings.api_type, ai_settings.model)
	
	print("[APIManager] 发送请求到 ", ai_settings.api_type, " API，模型：", ai_settings.model)
	print("[APIManager] 请求URL：", url)
	
	# 🔍 调试：打印请求详情
	print("[APIManager] 请求头：")
	for header in headers:
		# 隐藏API Key的完整内容
		if header.begins_with("Authorization"):
			print("  ", header.substr(0, header.find(":") + 10), "... (已隐藏)")
		else:
			print("  ", header)
	print("[APIManager] 请求体：")
	print(JSON.stringify(request_data, "  "))
	
	print("[APIManager] 创建HTTPRequest节点：", http_request.name)
	http_request.request(url, headers, HTTPClient.METHOD_POST, data)
	return http_request

# 生成AI决策
func generate_decision(prompt: String, character_name: String = "") -> HTTPRequest:
	return await generate_dialog(prompt, character_name)
