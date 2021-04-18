extends Area2D

signal decide_can_teleport(switcher)

export(String, FILE, "*.tscn") var target_scene: String
export var destination := ""

var can_teleport := true


func _on_MapSwitcher_body_entered(_body: Node) -> void:
	emit_signal("decide_can_teleport", self)
	
	if not can_teleport:
		return
	
	if not target_scene:
		print("Target scene not defined")
		return
	
	Transition.replace_scene(target_scene, {"target_destination": destination})
