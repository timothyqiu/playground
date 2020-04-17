class_name Map
extends Node2D

const music = 1

export var identifier := ""
export var camera_inset := Vector2.ZERO

var target_destination: String

onready var floor_tiles = $Floor
onready var player := $Structures/Player

func _ready() -> void:
	randomize()
	
	Game.music = music
	
	if target_destination:
		for child in get_children():
			if child is Destination and child.identifier == target_destination:
				player.set_direction(child.direction)
				player.position = child.position
				break
	
	var rect = floor_tiles.get_used_rect()
	rect.position += camera_inset
	rect.size -= camera_inset * 2
	rect.position *= floor_tiles.cell_size
	rect.size *= floor_tiles.cell_size
	
	var viewport_size = get_viewport_rect().size
	if viewport_size.x >= rect.size.x:
		rect.position.x += (rect.size.x - viewport_size.x) / 2
		rect.size.x = viewport_size.x
	if viewport_size.y >= rect.size.y:
		rect.position.y += (rect.size.y - viewport_size.y) / 2
		rect.size.y = viewport_size.y

	player.set_camera_bounds(rect)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameMenu.show_menu()
