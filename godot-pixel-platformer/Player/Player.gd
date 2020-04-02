extends KinematicBody2D

const MAX_SPEED = 85  # px/s
const ACCELERATION = 500  # speed approches MAX_SPEED
const FRICTION = 600  # speed approches ZERO
const AIR_RESISTANCE = 200  # speed approches ZERO

const GRAVITY = 420
const JUMP_FORCE = 170.0

onready var sprite = $Sprite
onready var animationPlayer = $AnimationPlayer
onready var jumpSound = $JumpSound

var velocity = Vector2.ZERO

func _process(delta):
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

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			jumpSound.play()
			velocity.y = -JUMP_FORCE
	else:
		animationPlayer.play("Jump")
		if Input.is_action_just_released("jump") and velocity.y < -JUMP_FORCE / 2:
			velocity.y = -JUMP_FORCE / 2

	velocity = move_and_slide(velocity, Vector2.UP)
