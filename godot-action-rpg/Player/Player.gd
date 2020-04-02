extends KinematicBody2D

const MAX_SPEED = 80  # max px/s
const ACCELERATION = 500  # approches MAX_SPEED by 500 px/s
const FRICTION = 500  # approches ZERO by 500 px/s

var velocity = Vector2.ZERO

func _process(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	var direction = input_vector.normalized()
	
	if input_vector == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	else:
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
	
	velocity = move_and_slide(velocity)
