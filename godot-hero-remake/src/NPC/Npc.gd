extends KinematicBody2D

enum NpcState {
	WALK,
	IDLE,
}

export var max_speed := 30.0
export var acceleration := 256.0
export var friction := 256.0

var state = NpcState.IDLE
var direction := Vector2.ZERO
var velocity := Vector2.ZERO

onready var sprite := $Sprite
onready var animation_tree := $AnimationTree
onready var animation_state:AnimationNodeStateMachine = $AnimationTree.get("parameters/playback")
onready var walk_timer := $WalkTimer
onready var idle_timer := $IdleTimer


func _ready() -> void:
	if randi() % 2:
		_enter_idle()
	else:
		_enter_walk()


func _physics_process(_delta: float) -> void:
	velocity = move_and_slide(velocity)
	
	if state == NpcState.WALK and velocity.is_equal_approx(Vector2.ZERO):
		direction = Vector2.RIGHT.rotated(randi() % 4 * PI / 2)


func _process(delta: float) -> void:
	match state:
		NpcState.IDLE:
			if idle_timer.is_stopped():
				_enter_walk()
		
		NpcState.WALK:
			if walk_timer.is_stopped():
				_enter_idle()
	
	if direction == Vector2.ZERO:
		animation_state.travel("idle")
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		set_direction(direction)
		animation_state.travel("walk")
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)


func set_direction(value: Vector2) -> void:
	animation_tree.set("parameters/idle/blend_position", value)
	animation_tree.set("parameters/walk/blend_position", value)


func _enter_walk():
	state = NpcState.WALK
	direction = Vector2.RIGHT.rotated(randi() % 4 * PI / 2)
	walk_timer.start(5 + randi() % 5)
	print("enter walk", walk_timer.time_left)


func _enter_idle():
	state = NpcState.IDLE
	direction = Vector2.ZERO
	idle_timer.start(1 + randi() % 5)
	print("enter idle", idle_timer.time_left)
