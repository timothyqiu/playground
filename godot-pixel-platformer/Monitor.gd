extends Node2D

onready var animationPlayer = $CanvasLayer/AnimationPlayer
onready var mainMenu = $MainMenu

var worlds = [
	load("res://World.tscn"),
	load("res://World2.tscn"),
	load("res://YouWin.tscn"),
]
var current_world_index = 0
var current_world

func _process(delta):
	if Input.is_action_just_pressed("exit"):
		_show_main_menu()

func _ready():
	mainMenu.prepare()

func _show_main_menu():
	animationPlayer.play("TransitionOut")
	yield(animationPlayer,"animation_finished")
	
	get_tree().current_scene.remove_child(current_world)
	
	mainMenu.show()
	mainMenu.prepare()
	
	animationPlayer.play("TransitionIn")

func on_game_start():
	animationPlayer.play("TransitionOut")
	yield(animationPlayer,"animation_finished")
	
	mainMenu.hide()
	load_world(0)
	animationPlayer.play("TransitionIn")

func on_game_finished():
	animationPlayer.play("TransitionOut")
	yield(animationPlayer,"animation_finished")
	
	get_tree().current_scene.remove_child(current_world)
	
	var next_world_index = current_world_index + 1
	if next_world_index == worlds.size():
		mainMenu.show()
		mainMenu.prepare()
	else:
		load_world(current_world_index + 1)
	animationPlayer.play("TransitionIn")

func on_game_over():
	animationPlayer.play("TransitionOut")
	yield(animationPlayer,"animation_finished")
	
	get_tree().current_scene.remove_child(current_world)
	load_world(current_world_index)
	animationPlayer.play("TransitionIn")

func load_world(index):
	current_world_index = index
	var world = worlds[current_world_index].instance()
	world.connect("game_over", self, "on_game_over", [], CONNECT_DEFERRED)
	world.connect("game_finished", self, "on_game_finished", [], CONNECT_DEFERRED)
	current_world = world
	get_tree().current_scene.add_child(current_world)
