extends KinematicBody2D

const MAX_SPEED = 80  # max px/s
const ACCELERATION = 500  # approches MAX_SPEED by 500 px/s
const FRICTION = 500  # approches ZERO by 500 px/s

enum {
	MOVE,
	ROLL,
	ATTACK,
}

onready var animationTree = $AnimationTree
onready var animationState = $AnimationTree.get("parameters/playback")

var state = MOVE
var velocity = Vector2.ZERO

func _process(delta):
	match state:
		MOVE:
			move_state(delta)

		ROLL:
			pass

		ATTACK:
			attack_state(delta)

func move_state(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	input_vector.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	var direction = input_vector.normalized()

	if input_vector == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		animationState.travel("Idle")
	else:
		animationTree.set("parameters/Idle/blend_position", direction)
		animationTree.set("parameters/Run/blend_position", direction)
		animationTree.set("parameters/Attack/blend_position", direction)
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
		animationState.travel("Run")

	velocity = move_and_slide(velocity)

	if Input.is_action_just_pressed("attack"):
		state = ATTACK

func attack_state(delta):
	velocity = Vector2.ZERO
	animationState.travel("Attack")

func attack_animation_finished():
	state = MOVE
