extends CanvasLayer

export(float, -1.0, 1.0, 0.01) var audio_volume: float = 0.0 setget set_audio_volume

var audio_player: AudioStreamPlayer = null
const normal_volume: float = 10.0
var current_scene: Node = null

onready var animation_player = $AnimationPlayer


func _ready():
	var root = get_tree().root
	root.pause_mode = Node.PAUSE_MODE_PROCESS

	current_scene = root.get_child(root.get_child_count() - 1)
	current_scene.pause_mode = Node.PAUSE_MODE_STOP

	audio_player = BackgroundMusic


func set_audio_volume(value):
	audio_volume = value
	if audio_player:
		audio_player.volume_db = normal_volume * (1 + audio_volume)


func transition_to(path):
	call_deferred("_transition_to", path)


func _transition_to(path):
	animation_player.play_backwards("fade_in")
	yield(animation_player, "animation_finished")
	
	Dialogue.hide_dialogue()
	current_scene.free()
	
	var s = ResourceLoader.load(path)
	current_scene = s.instance()
	current_scene.pause_mode = Node.PAUSE_MODE_STOP
	
	get_tree().get_root().add_child(current_scene)
	get_tree().set_current_scene(current_scene)
	
	animation_player.play("fade_in")
