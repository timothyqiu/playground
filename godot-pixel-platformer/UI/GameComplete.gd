extends Control


onready var stats = $StatsValue


func _ready():
	var total_seconds = Game.game_completed_at - Game.game_started_at
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	stats.text = "%02d:%02d\n%d" % [minutes, seconds, Game.total_deaths]


func _unhandled_input(event):
	if event.is_pressed():
		SceneTransition.transition_to("res://UI/MainMenu.tscn")
