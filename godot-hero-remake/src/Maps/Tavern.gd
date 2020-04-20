extends Map

onready var bandit_a = $Structures/BanditA
onready var bandit_b = $Structures/BanditB
onready var rouer = $Structures/Rouer


func _on_BanditA_dead() -> void:
	if bandit_b.is_alive():
		bandit_b._on_Interactable_interact(player)
	else:
		rouer._on_Interactable_interact(player)


func _on_BanditB_dead() -> void:
	if bandit_a.is_alive():
		bandit_a._on_Interactable_interact(player)
	else:
		rouer._on_Interactable_interact(player)


func _on_Rouer_interaction_finished() -> void:
	rouer.state = Npc.NpcState.IDLE
	Game.phase = Game.Phase.FIND_SWORD
