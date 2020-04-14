extends CanvasLayer

const TWEEN_DURATION := 0.5
const TEST_CONTENTS := [
	{
		"name": "密儿",
		"portrait": "mier",
		"text": "不知道。（哼，才不告诉你）",
	},
	{
		"name": "小飞刀",
		"portrait": "dagger",
		"text": "好吧。\n算了。",
	},
	{
		"name": null,
		"portrait": null,
		"text": "远处忽然传来惨叫声！",
	},
]

var contents := []
var current_index := 0

onready var talkbar := $Talkbar
onready var text_label := $Talkbar/HBoxContainer/RichTextLabel
onready var talker_label := $Talkbar/HBoxContainer/VBoxContainer/NameLabel
onready var talker_portrait := $Talkbar/HBoxContainer/VBoxContainer/TextureRect
onready var tween := $Tween


func _ready() -> void:
	talkbar.hide()


func _input(event: InputEvent) -> void:
	if not talkbar.visible:
		return
	
	if event.is_action_pressed("interact"):
		if tween.is_active():
			tween.seek(TWEEN_DURATION)
		else:
			var next_index = (current_index + 1) % contents.size()
			if next_index == 0:
				talkbar.hide()
			else:
				_show_dialogue(next_index)
	
	get_tree().set_input_as_handled()


func _show_dialogue(index: int) -> void:
	var data: Dictionary = contents[index]
	
	text_label.text = data.text
	
	var talker_name = data.get("name")
	if talker_name:
		talker_label.text = talker_name
	else:
		talker_label.text = ""
	
	tween.interpolate_property(text_label, "percent_visible", 0, 1, TWEEN_DURATION)
	tween.start()
	
	current_index = index


func show_dialogue(input: Array) -> void:
	talkbar.show()
	contents = input
	_show_dialogue(0)
