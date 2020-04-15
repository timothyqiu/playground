extends CanvasLayer

onready var rect = $ColorRect
onready var animation_player = $AnimationPlayer
onready var current_scene = get_tree().current_scene


func _ready() -> void:
	var root = get_tree().root
	root.pause_mode = Node.PAUSE_MODE_PROCESS
	current_scene.pause_mode = Node.PAUSE_MODE_STOP


func change_scene(scene_path: String, destination: String = ""):
	call_deferred("_change_scene", scene_path, destination)


func _change_scene(scene_path: String, destination: String = ""):
	get_tree().paused = true
	
	animation_player.play_backwards("fade_in")
	yield(animation_player, "animation_finished")
	
	if current_scene is Map:
		Events.emit_signal("leaving_map", current_scene)
	
	var root = get_tree().root
	root.remove_child(current_scene)
	current_scene.free()
	
	current_scene = load(scene_path).instance()
	current_scene.pause_mode = Node.PAUSE_MODE_STOP
	current_scene.target_destination = destination
	root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	if current_scene is Map:
		Events.emit_signal("entering_map", current_scene)
	
	get_tree().paused = false
	animation_player.play("fade_in")
