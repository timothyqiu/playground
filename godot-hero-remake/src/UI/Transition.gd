extends CanvasLayer

enum ChangeMode {
	REPLACE,
	PUSH,
	POP,
}

var scene_stack = []

onready var rect = $ColorRect
onready var animation_player = $AnimationPlayer
onready var current_scene = get_tree().current_scene


func _ready() -> void:
	var root = get_tree().root
	root.pause_mode = Node.PAUSE_MODE_PROCESS
	current_scene.pause_mode = Node.PAUSE_MODE_STOP


func replace_scene(scene_path: String, args={}):
	call_deferred("_change_scene", ChangeMode.REPLACE, scene_path, args)


func push_scene(scene_path: String, args={}):
	call_deferred("_change_scene", ChangeMode.PUSH, scene_path, args)


func pop_scene():
	call_deferred("_change_scene", ChangeMode.POP, "", {})


func _change_scene(mode: int, scene_path: String, args: Dictionary):
	get_tree().paused = true
	
	animation_player.play_backwards("fade_in")
	yield(animation_player, "animation_finished")
	
	var root = get_tree().root
	
	match mode:
		ChangeMode.REPLACE, ChangeMode.POP:
			if not args.get("skip_persist", false) and current_scene is Map:
				Events.emit_signal("leaving_map", current_scene)
			root.remove_child(current_scene)
			current_scene.free()
		
		ChangeMode.PUSH:
			root.remove_child(current_scene)
			scene_stack.push_front(current_scene)
	
	match mode:
		ChangeMode.REPLACE, ChangeMode.PUSH:
			current_scene = load(scene_path).instance()
			current_scene.pause_mode = Node.PAUSE_MODE_STOP
			
			for arg in args:
				current_scene.set(arg, args[arg])
		
		ChangeMode.POP:
			current_scene = scene_stack.front()
			scene_stack.pop_front()
	
	root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	match mode:
		ChangeMode.REPLACE, ChangeMode.PUSH:
			if current_scene is Map:
				Events.emit_signal("entering_map", current_scene)
	
	get_tree().paused = false
	animation_player.play("fade_in")
