extends Node2D

onready var animationPlayer = $CanvasLayer/AnimationPlayer

var worlds = [
	load("res://World.tscn"),
	load("res://World2.tscn"),
	load("res://YouWin.tscn"),
]
var current_world_index = 0
var current_world

func _ready():
	reload_world()

func on_game_finished():
	current_world_index = (current_world_index + 1) % worlds.size()
	reload_world()

func on_game_over():
	reload_world()

func reload_world():
	if current_world:
		animationPlayer.play("TransitionOut")
		yield(animationPlayer,"animation_finished")
	var world = worlds[current_world_index].instance()
	world.connect("game_over", self, "on_game_over")
	world.connect("game_finished", self, "on_game_finished")
	var scene = get_tree().current_scene
	scene.remove_child(current_world)
	current_world = world
	scene.add_child(world)
	animationPlayer.play("TransitionIn")
