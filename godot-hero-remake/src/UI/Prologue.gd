extends ColorRect

onready var label = $Label
onready var tween = $Tween


func _ready():
	tween.interpolate_property(label, "percent_visible", 0, 1, label.text.length() * 0.1)
	tween.start()


func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		if tween.is_active():
			tween.remove_all()
			label.percent_visible = 1
		else:
			Transition.replace_scene("res://src/Maps/Home.tscn")
