extends KinematicBody2D

const MAX_SPEED = 15  # px/s
const ACCELERATION = 100  # speed approches MAX_SPEED
const FRICTION = 100  # speed approches ZERO
const AIR_RESISTANCE = 100  # speed approches ZERO

const GRAVITY = 420

onready var animationPlayer = $AnimationPlayer
onready var sprite = $Sprite

var direction = -1.0
var velocity = Vector2.ZERO

func _process(delta):
	if direction == 0:
		animationPlayer.play("Idle")
		var factor = FRICTION if is_on_floor() else AIR_RESISTANCE
		velocity.x = move_toward(velocity.x, 0, factor * delta)
	else:
		animationPlayer.play("Run")
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
		sprite.flip_h = direction < 0

	velocity.y += GRAVITY * delta

	velocity = move_and_slide(velocity, Vector2.UP)

func _physics_process(delta):
	if $LeftWallChecker.is_colliding() or not $LeftCliffChecker.is_colliding():
		direction = 1.0
	if $RightWallChecker.is_colliding() or not $RightCliffChecker.is_colliding():
		direction = -1.0


func _on_Area2D_body_entered(body):
	var player: Player = body
	player.hurt()
