extends KinematicBody2D
class_name Player

signal player_dead

const MAX_SPEED = 85  # px/s
const ACCELERATION = 500  # speed approches MAX_SPEED
const FRICTION = 600  # speed approches ZERO
const AIR_RESISTANCE = 200  # speed approches ZERO

const GRAVITY = 420
const JUMP_FORCE = 170.0

enum {
	RUN,
	DEAD,
}

onready var sprite = $Sprite
onready var animationPlayer = $AnimationPlayer
onready var jumpSound = $Sounds/Jump
onready var hurtSound = $Sounds/Hurt
onready var jumpBufferingTimer = $JumpBufferingTimer
onready var coyoteTimer = $CoyoteTimer

var state = RUN
var velocity = Vector2.ZERO
var is_jumping = false

func _process(delta):
	match state:
		RUN:
			run_state(delta)
			
		DEAD:
			dead_state(delta)

func run_state(delta):
	var direction = Input.get_action_strength("right") - Input.get_action_strength("left")

	if direction == 0:
		animationPlayer.play("Idle")
		var factor = FRICTION if is_on_floor() else AIR_RESISTANCE
		velocity.x = move_toward(velocity.x, 0, factor * delta)
	else:
		animationPlayer.play("Run")
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
		sprite.flip_h = direction < 0

	velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("jump"):
		jumpBufferingTimer.start()

	if is_on_floor():
		is_jumping = false
		coyoteTimer.stop()
	else:
		animationPlayer.play("Jump")
		if Input.is_action_just_released("jump") and velocity.y < -JUMP_FORCE / 2:
			velocity.y = -JUMP_FORCE / 2
	
	if jumpBufferingTimer.time_left > 0 and (is_on_floor() or coyoteTimer.time_left > 0):
		jumpSound.play()
		velocity.y = -JUMP_FORCE
		jumpBufferingTimer.stop()
		coyoteTimer.stop()
		is_jumping = true

	var was_on_floor = is_on_floor()
	velocity = move_and_slide(velocity, Vector2.UP)
	if was_on_floor and not is_jumping and not is_on_floor():
		coyoteTimer.start()

func dead_state(delta):
	velocity.y += GRAVITY * delta
	velocity = move_and_slide(velocity, Vector2.UP)

func hurt():
	state = DEAD
	hurtSound.play()
	animationPlayer.play("Jump")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2(0, -JUMP_FORCE * 1.2)
	emit_signal("player_dead")
