extends PanelContainer

signal train_unit(building_index, unit_id)

var building_index := -1

onready var building_name = $H/Name
onready var buttons = $H/Buttons
onready var tween = $Tween


func _ready():
	hide()


func show_panel(index, building_id):
	building_index = index
	
	var building = Database.get_building(building_id)
	building_name.text = building.name
	
	for child in buttons.get_children():
		child.queue_free()
	
	for unit_id in building.unit_ids:
		var unit = Database.UNITS[unit_id]
		var button := SimpleButton.new()
		button.texture_normal = unit.texture
		buttons.add_child(button)
		var err = button.connect("pressed", self, "_on_UnitButton_pressed", [unit_id])
		assert(err == OK)
	
	if not visible:
		tween.interpolate_property(self, "margin_left", -300, 8, 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		tween.start()
	
	show()


func hide_panel():
	tween.interpolate_property(self, "margin_left", null, -300, 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	hide()


func _on_UnitButton_pressed(unit_id):
	emit_signal("train_unit", building_index, unit_id)
