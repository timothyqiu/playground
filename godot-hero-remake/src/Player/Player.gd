extends KinematicBody2D

const character_name = "小飞刀"

export var max_speed := 150.0
export var acceleration := 1024.0
export var friction := 1024.0

var input_strength := Vector2.ZERO
var velocity := Vector2.ZERO
var talker_texture := AtlasTexture.new()

onready var stats := PlayerStats
onready var animation_tree := $AnimationTree
onready var animation_state = $AnimationTree.get("parameters/playback")
onready var camera := $Camera2D


func _ready() -> void:
	var err := OK
	
	err = Events.connect("game_paused", self, "_on_game_paused")
	assert(err == OK)
	err = Events.connect("dialogue_started", self, "_on_game_paused")
	assert(err == OK)
	
	talker_texture.atlas = $Sprite.texture
	talker_texture.region = Rect2(0, 0, 32, 32)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("ui_down") or event.is_action("ui_up"):
		input_strength.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if event.is_action("ui_right") or event.is_action("ui_left"):
		input_strength.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")


func _process(delta: float) -> void:
	var direction = input_strength.normalized()
	
	if direction == Vector2.ZERO:
		animation_state.travel("idle")
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		set_direction(direction)
		animation_state.travel("walk")
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)


func _physics_process(_delta: float) -> void:
	velocity = move_and_slide(velocity)


func _on_game_paused() -> void:
	input_strength = Vector2.ZERO
	velocity = Vector2.ZERO


func set_direction(value: Vector2) -> void:
	animation_tree.set("parameters/idle/blend_position", value)
	animation_tree.set("parameters/walk/blend_position", value)


func set_camera_bounds(rect: Rect2) -> void:
	camera.limit_left = rect.position.x
	camera.limit_top = rect.position.y
	camera.limit_right = rect.end.x
	camera.limit_bottom = rect.end.y
	
	camera.force_update_scroll()


func to_dict():
	var direction = animation_tree.get("parameters/idle/blend_position")
	return {
		"x": position.x,
		"y": position.y,
		"direction_x": direction.x,
		"direction_y": direction.y,
	}


func from_dict(data):
	position = Vector2(data.x, data.y)
	set_direction(Vector2(data.direction_x, data.direction_y))
