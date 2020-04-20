extends CanvasLayer

const TWEEN_DURATION := 0.5

var contents := []
var current_index := 0

onready var talkbar := $Talkbar
onready var text_label := $Talkbar/HBoxContainer/RichTextLabel
onready var talker_label := $Talkbar/HBoxContainer/VBoxContainer/NameLabel
onready var talker_portrait := $Talkbar/HBoxContainer/VBoxContainer/TextureRect
onready var tween := $Tween


func _input(event: InputEvent) -> void:
	if not talkbar.visible:
		return
	
	if event.is_action_pressed("ui_select"):
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
	
	var talker_avatar = data.get("avatar")
	if talker_avatar:
		talker_portrait.texture = talker_avatar
	else:
		talker_portrait.texture = null
	
	tween.interpolate_property(text_label, "percent_visible", 0, 1, TWEEN_DURATION)
	tween.start()
	
	current_index = index


func show_dialogue(input: Array) -> void:
	if input.empty():
		Events.emit_signal("dialogue_started")
		Events.call_deferred("emit_signal", "dialogue_finished")
	else:
		contents = input
		talkbar.popup()


func _on_Talkbar_about_to_show() -> void:
	Events.emit_signal("dialogue_started")
	get_tree().paused = true
	Events.emit_signal("game_paused")
	_show_dialogue(0)


func _on_Talkbar_popup_hide() -> void:
	get_tree().paused = false
	Events.emit_signal("game_unpaused")
	Events.emit_signal("dialogue_finished")
