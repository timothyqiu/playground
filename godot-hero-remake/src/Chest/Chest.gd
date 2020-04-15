extends StaticBody2D

export var opened := false

var interactable := false

onready var sprite := $AnimatedSprite


func _ready() -> void:
	add_to_group("persist")
	set_opened(opened)


func set_opened(value: bool) -> void:
	opened = value
	sprite.frame = 1 if opened else 0


func _on_Interactable_interact(_interacter) -> void:
	if opened:
		return
	
	set_opened(true)
	
	var data = [{
		"text": "你打开了一个宝箱，看看里面有什么？"
	}]
	Dialogue.show_dialogue(data)


func to_dict():
	return {
		"opened": opened,
	}


func from_dict(data: Dictionary):
	set_opened(data.opened)

