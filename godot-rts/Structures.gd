extends TileMap

signal selection_changed(pos)

var selection = null

onready var selection_map = $Selection
onready var selection_id = tile_set.find_tile_by_name("SelectionBox")


func _unhandled_input(event):
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == BUTTON_LEFT and mb.is_pressed():
		var pos = world_to_map(mb.global_position)
		var tile_id = get_cellv(pos)
		if tile_id == -1:
			selection = null
		else:
			selection = pos
		
		selection_map.clear()
		if selection:
			selection_map.set_cellv(selection, selection_id)
		
		emit_signal("selection_changed", selection)
		
		if tile_id != -1:
			get_tree().set_input_as_handled()


func _update_selections():
	selection_map.clear()
	if selection:
		selection_map.set_cellv(selection, selection_id)
