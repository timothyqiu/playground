extends CharacterBody3D

const MAX_SPEED := 3.0
const ACCELERATION := MAX_SPEED / 0.2
const MOUSE_SENSITIVITY := 0.01

var gravity := ProjectSettings.get("physics/3d/default_gravity") as float

@onready var camera_base: Node3D = $CameraBase


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		rotation.y -= mm.relative.x * MOUSE_SENSITIVITY
		camera_base.rotation.x -= mm.relative.y * MOUSE_SENSITIVITY


func _physics_process(delta: float) -> void:
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var target_velocity := (
		Vector2(velocity.x, velocity.z)
		.move_toward(movement.rotated(-rotation.y) * MAX_SPEED, ACCELERATION * delta)
	)
	
	velocity = Vector3(
		target_velocity.x,
		velocity.y - gravity * delta,
		target_velocity.y
	)
	
	move_and_slide()
