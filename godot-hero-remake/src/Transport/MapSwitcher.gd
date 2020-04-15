extends Area2D


export(String, FILE, "*.tscn") var target_scene: String
export var destination := ""


func _on_MapSwitcher_area_entered(_area: Area2D) -> void:
	if not target_scene:
		print("Target scene not defined")
		return
	
	Transition.change_scene(target_scene, destination)
