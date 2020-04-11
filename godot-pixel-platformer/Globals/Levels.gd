extends Node

const levels = [
	"res://World.tscn",
	"res://World2.tscn",
	"res://YouWin.tscn",
]

var current_level: int = 2


func reload():
	_go_level(current_level)


func go_first_level():
	_go_level(0)


func go_next_level():
	var next_level = current_level + 1
	if next_level == levels.size():
		SceneTransition.transition_to("res://UI/MainMenu.tscn")
	else:
		_go_level(next_level)


func _go_level(level: int):
	assert(0 <= level and level < levels.size())
	SceneTransition.transition_to(levels[level])
	current_level = level
