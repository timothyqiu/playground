extends Area2D

export var turned_on := false
export var link: NodePath

var interactable = false

onready var sprite = $AnimatedSprite


func _ready():
	sprite.animation = "TurnOn"
	sprite.frame = 2 if turned_on else 0
	sprite.playing = false
	
	_notify_link()


func _unhandled_input(event):
	if interactable and event.is_action_pressed("interact"):
		if turned_on:
			sprite.play("TurnOff")
		else:
			sprite.play("TurnOn")
		turned_on = not turned_on
		
		_notify_link()


func _notify_link():
	if not link:
		return
	var node = get_node(link)
	node.on_lever(turned_on)


func _on_Lever_body_entered(_body):
	interactable = true


func _on_Lever_body_exited(_body):
	interactable = false
