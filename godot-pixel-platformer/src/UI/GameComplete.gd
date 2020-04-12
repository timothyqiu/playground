extends Control


onready var stats = $StatsValue


func _ready():
	var total_seconds = Game.game_completed_at - Game.game_started_at
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	stats.text = "%02d:%02d\n%d / %d\n%d\n" % [
		minutes, seconds,
		Game.coins_collected, Game.coins_total,
		Game.total_deaths,
	]


func _unhandled_input(event):
	# essentially "press any key"
	if event.is_pressed() and not event.is_echo():
		Game.go_main_menu()
