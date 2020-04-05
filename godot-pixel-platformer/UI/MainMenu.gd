extends Control

signal game_start

func prepare():
	$Start.grab_focus()

func _on_Start_pressed():
	emit_signal("game_start")
