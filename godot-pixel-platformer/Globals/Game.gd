extends Node

const levels = [
	"res://World/World.tscn",
	"res://World/World2.tscn",
	"res://World/YouWin.tscn",
]

var game_started_at: int
var game_completed_at: int
var total_deaths: int = 0

var current_level: int = 2


func _input(event):
	if event.is_action_pressed("fullscreen"):
		var will_fullscreen = not OS.window_fullscreen
		OS.window_fullscreen = will_fullscreen
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if will_fullscreen else Input.MOUSE_MODE_VISIBLE)
		get_tree().set_input_as_handled()


# maybe a better name
func reload():
	total_deaths += 1
	_go_level(current_level)


func go_first_level():
	game_started_at = OS.get_unix_time()
	game_completed_at = -1
	total_deaths = 0
	_go_level(0)


func go_next_level():
	var next_level = current_level + 1
	if next_level == levels.size():
		game_completed_at = OS.get_unix_time()
		SceneTransition.transition_to("res://UI/GameComplete.tscn")
	else:
		_go_level(next_level)


func _go_level(level: int):
	assert(0 <= level and level < levels.size())
	SceneTransition.transition_to(levels[level])
	current_level = level
