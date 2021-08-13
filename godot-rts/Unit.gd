extends KinematicBody2D

var target_pos

onready var sprite := $Sprite as Sprite
onready var health := $Health as TextureProgress
onready var tween := $Tween as Tween


func _ready():
	health.hide()


func _process(delta):
	if target_pos:
		if not tween.is_active():
			tween.interpolate_property(sprite, "rotation_degrees", 0, +10, 0.1, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
			tween.interpolate_property(sprite, "rotation_degrees", +10, 0, 0.1, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 0.1)
			tween.interpolate_property(sprite, "rotation_degrees", 0, -10, 0.1, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 0.2)
			tween.interpolate_property(sprite, "rotation_degrees", -10, 0, 0.1, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 0.3)
			tween.start()


func _physics_process(delta):
	if target_pos:
		var direction = global_position.direction_to(target_pos)
		move_and_slide(direction * 50)
	
		if global_position.distance_to(target_pos) < 20:
			target_pos = null


func move_to(target: Vector2):
	target_pos = target


func deselect():
	remove_from_group("current_units")
	health.hide()


func _on_Unit_input_event(viewport, event, shape_idx):
	var mb = event as InputEventMouseButton
	if mb and mb.button_index == BUTTON_LEFT and mb.is_pressed():
		if is_in_group("current_units"):
			deselect()
		else:
			add_to_group("current_units")
			health.show()
			
			tween.interpolate_property(sprite, "position:y", 0, -6, 0.2, Tween.TRANS_SINE, Tween.EASE_IN)
			tween.interpolate_property(sprite, "position:y", -6, 0, 0.2, Tween.TRANS_ELASTIC, Tween.EASE_OUT, 0.2)
			tween.start()
		get_tree().set_input_as_handled()
