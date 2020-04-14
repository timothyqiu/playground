extends StaticBody2D

export var opened := false

var interactable := false

onready var sprite := $AnimatedSprite


func _ready() -> void:
	set_opened(opened)


func _unhandled_input(event: InputEvent) -> void:
	if not opened and interactable and event.is_action_pressed("interact"):
		set_opened(true)
		
		var data = [{
			"text": "你打开了一个宝箱，看看里面有什么？"
		}]
		Dialogue.show_dialogue(data)
		
		# open one chest at a time
		get_tree().set_input_as_handled()


func set_opened(value: bool) -> void:
	opened = value
	sprite.frame = 1 if opened else 0


func _on_Interactable_area_entered(_area: Area2D) -> void:
	interactable = true


func _on_Interactable_area_exited(_area: Area2D) -> void:
	interactable = false
