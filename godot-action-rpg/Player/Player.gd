extends KinematicBody2D

const MAX_SPEED = 80  # max px/s
const ACCELERATION = 500  # approches MAX_SPEED by 500 px/s
const FRICTION = 500  # approches ZERO by 500 px/s
const ROLL_SPEED = MAX_SPEED * 1.4

enum {
	MOVE,
	ROLL,
	ATTACK,
}

onready var animationTree = $AnimationTree
onready var animationState = $AnimationTree.get("parameters/playback")
onready var swordHitbox = $HitboxPivit/SwordHitbox

var state = MOVE
var velocity = Vector2.ZERO
var roll_direction = Vector2.DOWN

func _process(delta):
	match state:
		MOVE:
			move_state(delta)

		ROLL:
			roll_state(delta)

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
		roll_direction = direction
		swordHitbox.knockback_vector = direction
		animationTree.set("parameters/Idle/blend_position", direction)
		animationTree.set("parameters/Run/blend_position", direction)
		animationTree.set("parameters/Attack/blend_position", direction)
		animationTree.set("parameters/Roll/blend_position", direction)
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)
		animationState.travel("Run")

	velocity = move_and_slide(velocity)

	if Input.is_action_just_pressed("roll"):
		state = ROLL

	if Input.is_action_just_pressed("attack"):
		state = ATTACK

func attack_state(_delta):
	velocity = Vector2.ZERO
	animationState.travel("Attack")

func attack_animation_finished():
	state = MOVE

func roll_state(_delta):
	animationState.travel("Roll")
	velocity = roll_direction * ROLL_SPEED
	velocity = move_and_slide(velocity)

func roll_animation_finished():
	velocity *= 0.8
	state = MOVE
