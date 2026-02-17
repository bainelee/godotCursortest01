extends CharacterBody3D

## 第一人称相机控制器（无模型）
## 可复用：将场景实例化到任意关卡中即可

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var gravity_multiplier: float = 1.0

var _camera: Camera3D
var _pitch: float = 0.0  # 上下视角（俯仰角）


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera = get_node_or_null("Camera3D")
	if not _camera:
		push_error("FPSController: 未找到 Camera3D 子节点")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# 左右旋转身体
		rotate_y(-event.relative.x * mouse_sensitivity)
		# 上下旋转相机（限制俯仰角）
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, -deg_to_rad(89), deg_to_rad(89))
		if _camera:
			_camera.rotation.x = _pitch
	
	if event.is_action_pressed("ui_cancel"):  # ESC 切换鼠标
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# 重力（get_gravity().y 为负值，加上后 velocity.y 递减）
	if not is_on_floor():
		velocity.y += get_gravity().y * gravity_multiplier * delta
	
	# 跳跃
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	# 移动输入（WASD：W前 S后 A左 D右）
	var input_dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, 10.0)
		velocity.z = move_toward(velocity.z, 0, 10.0)
	
	move_and_slide()
