extends Node2D

var _buildings := []
var _building_map: Dictionary

onready var environment := $Environment
onready var structures := $Structures
onready var placing := $Placing
onready var construction_buttons := $CanvasLayer/Construction/V/Buttons
onready var building_panel := $CanvasLayer/Building


func _ready():
	for child in construction_buttons.get_children():
		child.queue_free()
	for i in Database.BUILDINGS.size():
		var building = Database.BUILDINGS[i]
		var button := preload("res://SimpleButton.gd").new() as TextureButton
		button.texture_normal = building.texture
		construction_buttons.add_child(button)
		var err := button.connect("pressed", self, "_on_BuildingButton_pressed", [i])
		assert(err == OK)
	
	building_panel.hide()


func _unhandled_input(event):
	var mb := event as InputEventMouseButton
	if mb and mb.is_pressed():
		if mb.button_index == BUTTON_RIGHT:
			get_tree().call_group("current_units", "move_to", mb.global_position)
			get_tree().set_input_as_handled()
		else:
			get_tree().call_group("current_units", "deselect")


func _on_BuildingButton_pressed(id):
	placing.start_placing(id)


func _on_Placing_placing_confirmed(building_id, pos):
	var tile_id = Database.get_building_tile_id(building_id)
	structures.set_cellv(pos, tile_id)
	
	var index = _buildings.size()
	_buildings.append({ id=building_id, pos=pos })
	_building_map[pos] = index


func _on_Structures_selection_changed(pos):
	if pos:
		var index = _building_map[pos]
		var building = _buildings[index]
		building_panel.show_panel(index, building.id)
	else:
		building_panel.hide_panel()


func _on_Building_train_unit(building_index, unit_id):
	var unit_info = Database.UNITS[unit_id]
	var unit = preload("res://Unit.tscn").instance()
	add_child(unit)
	unit.sprite.texture = unit_info.texture
	
	var building = _buildings[building_index]
	var radius = structures.cell_size.length()
	var building_pos = structures.map_to_world(building.pos) + structures.cell_size / 2
	var rand_angle = randf() * 2 * PI
	unit.global_position = Vector2(
		building_pos.x + sin(rand_angle) * radius,
		building_pos.y + cos(rand_angle) * radius
	)
	unit.move_and_slide(Vector2.DOWN)
