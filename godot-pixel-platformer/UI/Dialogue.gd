extends CanvasLayer

signal finished

const TWEEN_DURATION = 0.8

var dialogues = [
	"Hi there!",
]
var current_index = 0

onready var tween = $Tween
onready var label = $RichTextLabel


func _ready():
	label.hide()


func _input(event):
	if not label.visible:
		return

	if event.is_action_pressed("jump"):
		if tween.is_active():
			tween.seek(TWEEN_DURATION)
		elif current_index + 1 < dialogues.size():
			_show_dialogue(current_index + 1)
		else:
			_hide_dialogue()
		
		get_tree().set_input_as_handled()
	
	elif event.is_action_type() and not (event.is_action("exit") or event.is_action("fullscreen")):
		get_tree().set_input_as_handled()


func _show_dialogue(index):
	assert(0 <= index and index < dialogues.size())
	label.text = dialogues[index]
	current_index = index
	tween.interpolate_property(label, "percent_visible", 0, 1, TWEEN_DURATION)
	tween.start()


func show_dialogue(texts):
	get_tree().paused = true
	dialogues = texts
	label.show()
	_show_dialogue(0)


func _hide_dialogue():
	label.hide()
	get_tree().paused = false
	emit_signal("finished")
