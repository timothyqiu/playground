extends TileMap

signal placing_confirmed(index, pos)

export var structures_path: NodePath
export var good_tint: Color
export var bad_tint: Color

var building_id := -1
var tile_id := -1

onready var structures := get_node(structures_path) as TileMap


func _ready():
	hide()


func _unhandled_input(event):
	if not visible or building_id == -1:
		return
	
	var mm := event as InputEventMouseMotion
	if mm:
		clear()
		var pos = world_to_map(mm.global_position)
		set_cellv(pos, tile_id)
		modulate = good_tint if structures.get_cellv(pos) == -1 else bad_tint
		get_tree().set_input_as_handled()
	
	var mb := event as InputEventMouseButton
	if mb and mb.is_pressed():
		match mb.button_index:
			BUTTON_LEFT:
				var pos = world_to_map(mb.global_position)
				if structures.get_cellv(pos) == -1:
					emit_signal("placing_confirmed", building_id, pos)
					hide()
				get_tree().set_input_as_handled()
			BUTTON_RIGHT:
				hide()
				get_tree().set_input_as_handled()


func start_placing(id):
	building_id = id
	tile_id = Database.get_building_tile_id(id)
	clear()
	show()
