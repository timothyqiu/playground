extends Map

onready var bandit_tuyin = $Structures/BanditA
onready var bandit_daoba = $Structures/BanditB
onready var rouer = $Structures/Rouer


func _on_BanditA_interact(interactor) -> void:
	_on_Rouer_interact(interactor)


func _on_BanditB_interact(interactor) -> void:
	if Game.phase == Game.Phase.BEAT_TUYIN:
		_on_Rouer_interact(interactor)
	else:
		bandit_daoba.interact(interactor)


func _on_Rouer_interact(interactor) -> void:
	match Game.phase:
		Game.Phase.BEAT_TUYIN:
			rouer.pause_mode = Node.PAUSE_MODE_PROCESS
			bandit_daoba.pause_mode = Node.PAUSE_MODE_PROCESS
			bandit_tuyin.pause_mode = Node.PAUSE_MODE_PROCESS
			
			rouer.talk(interactor)
			yield(Events, "dialogue_finished")
			bandit_daoba.talk(interactor)
			yield(Events, "dialogue_finished")
			bandit_tuyin.interact(interactor)
			yield(Events, "dialogue_finished")
			
			rouer.pause_mode = Node.PAUSE_MODE_INHERIT
			bandit_daoba.pause_mode = Node.PAUSE_MODE_INHERIT
			bandit_tuyin.pause_mode = Node.PAUSE_MODE_INHERIT
		
		Game.Phase.BEAT_DAOBA:
			bandit_daoba.interact(interactor)
		
		_:
			rouer.interact(interactor)


func _on_BanditA_dead() -> void:
	Game.phase = Game.Phase.BEAT_DAOBA
	bandit_daoba.interact(player)


func _on_BanditB_dead() -> void:
	rouer.is_stationary = false
	rouer.interact(player)
	Game.phase = Game.Phase.GO_OUTSIDE
