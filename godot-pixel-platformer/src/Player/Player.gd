extends KinematicBody2D
class_name Player

signal player_dead

const MAX_SPEED = 85  # px/s
const ACCELERATION = 500  # speed approches MAX_SPEED
const FRICTION = 600  # speed approches ZERO
const AIR_RESISTANCE = 200  # speed approches ZERO

const GRAVITY = 440
const JUMP_FORCE = 170.0

enum {
	RUN,
	DEAD,
	GO_RIGHT,  # after reaching level exit
}

onready var sprite = $Sprite
onready var animationPlayer = $AnimationPlayer
onready var jumpSound = $Sounds/Jump
onready var hurtSound = $Sounds/Hurt
onready var jumpBufferingTimer = $JumpBufferingTimer
onready var coyoteTimer = $CoyoteTimer

var state = RUN
var strength_left = 0.0
var strength_right = 0.0
var velocity = Vector2.ZERO
var is_jumping = false


func _process(delta):
	match state:
		RUN:
			run_state(delta)
			
		DEAD:
			dead_state(delta)
			
		GO_RIGHT:
			go_right_state(delta)


func _physics_process(_delta):
	var was_on_floor = is_on_floor()

	var snap = Vector2.ZERO if is_jumping else Vector2.DOWN
	velocity = move_and_slide_with_snap(velocity, snap, Vector2.UP)

	if is_on_floor():
		is_jumping = false
		coyoteTimer.stop()
	elif was_on_floor and not is_jumping:
		coyoteTimer.start()


func _unhandled_input(event):
	if event.is_action("left"):
		strength_left = event.get_action_strength("left")
	if event.is_action("right"):
		strength_right = event.get_action_strength("right")

	if state != RUN:
		return

	if event.is_action_pressed("jump"): 
		jumpBufferingTimer.start()
	if is_jumping and event.is_action_released("jump") and velocity.y < -JUMP_FORCE / 2:
		velocity.y = -JUMP_FORCE / 2


func _move(delta, direction):
	if direction == 0:
		animationPlayer.play("Idle")
		var factor = FRICTION if is_on_floor() else AIR_RESISTANCE
		velocity.x = move_toward(velocity.x, 0, factor * delta)
	else:
		animationPlayer.play("Run")
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
		sprite.flip_h = direction < 0

	velocity.y += GRAVITY * delta

	if is_jumping:
		animationPlayer.play("Jump")


func run_state(delta):
	var direction = strength_right - strength_left
	_move(delta, direction)
	
	var can_jump = is_on_floor() or coyoteTimer.time_left > 0
	if jumpBufferingTimer.time_left > 0 and can_jump:
		jump()


func dead_state(delta):
	velocity.y += GRAVITY * delta
	velocity = move_and_slide(velocity, Vector2.UP)


func go_right_state(delta):
	_move(delta, 0.5)


func go_right():
	state = GO_RIGHT


func jump():
	velocity.y = -JUMP_FORCE
	is_jumping = true
	jumpBufferingTimer.stop()
	coyoteTimer.stop()
	jumpSound.play()


func hurt():
	state = DEAD
	hurtSound.play()
	animationPlayer.play("Jump")
	collision_layer = 0
	collision_mask = 0
	$Hurtbox.collision_mask = 0
	velocity = Vector2(0, -JUMP_FORCE * 1.2)
	emit_signal("player_dead")


func _on_Hurtbox_area_entered(_area):
	hurt()
