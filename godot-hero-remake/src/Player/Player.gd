extends KinematicBody2D

export var max_speed := 128.0
export var acceleration := 1024.0
export var friction := 1024.0

var input_strength := Vector2.ZERO
var velocity := Vector2.ZERO

onready var animation_tree := $AnimationTree
onready var animation_state:AnimationNodeStateMachine = $AnimationTree.get("parameters/playback")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("down") or event.is_action("up"):
		input_strength.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	if event.is_action("right") or event.is_action("left"):
		input_strength.x = Input.get_action_strength("right") - Input.get_action_strength("left")


func _process(delta: float) -> void:
	var direction = input_strength.normalized()
	
	if direction == Vector2.ZERO:
		animation_state.travel("idle")
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		_update_blend_position(direction)
		animation_state.travel("walk")
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)


func _physics_process(_delta: float) -> void:
	velocity = move_and_slide(velocity)


func _update_blend_position(value: Vector2) -> void:
	animation_tree.set("parameters/idle/blend_position", value)
	animation_tree.set("parameters/walk/blend_position", value)
