extends CharacterBody3D

## 第一人称相机控制器（无模型）
## 可复用：将场景实例化到任意关卡中即可

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var gravity_multiplier: float = 1.0

var _camera: Camera3D
var _bullet_spawn: Node3D  # 子弹发射点（可编辑器中调整 BulletSpawnPoint）
var _pitch: float = 0.0  # 上下视角（俯仰角）

const BULLET_SCENE := preload("res://scenes/projectiles/bullet.tscn")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera = get_node_or_null("Camera3D")
	_bullet_spawn = get_node_or_null("Camera3D/WeaponViewmodel/BulletSpawnPoint")
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
	
	# 鼠标左键发射子弹
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_shoot()


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


const RAY_MAX_LENGTH := 5000.0


func _shoot() -> void:
	if not _camera:
		return
	# 从屏幕中心（准星）发射射线，最远 5000
	var viewport := _camera.get_viewport()
	var center := viewport.get_visible_rect().get_center()
	var origin := _camera.project_ray_origin(center)
	var direction := _camera.project_ray_normal(center).normalized()
	var ray_end := origin + direction * RAY_MAX_LENGTH
	
	# 射线检测受击碰撞体（Area、Body）
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [self.get_rid()]
	
	var result := space_state.intersect_ray(query)
	var hit_position: Vector3
	var hit_collider: Node = null
	
	if result:
		hit_position = result.position
		hit_collider = result.collider
		if hit_collider is CharacterBody3D and hit_collider.is_in_group("player"):
			hit_collider = null
	else:
		hit_position = ray_end
	
	# 通知击中目标（命中位置为准星射线与受击体的交点）
	if hit_collider:
		_notify_hit(hit_collider, hit_position)
	
	# 生成子弹飞向命中点（纯视觉）
	var spawn_pos := _bullet_spawn.global_position if _bullet_spawn else origin
	var bullet := BULLET_SCENE.instantiate() as Area3D
	get_parent().add_child(bullet)
	if bullet.has_method("setup"):
		bullet.setup(direction, spawn_pos, hit_position)


func _notify_hit(collider: Node, hit_position: Vector3) -> void:
	var node: Node = collider
	while node:
		if node.is_in_group("enemy") and node.has_method("_on_bullet_hit"):
			node._on_bullet_hit(hit_position)
			break
		node = node.get_parent()
