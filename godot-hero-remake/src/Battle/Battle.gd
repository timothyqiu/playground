extends CanvasLayer

signal player_retreat()
signal player_win()
signal player_lose()

enum BattlePhase {
	PLAYER_CHOOSE_ACTION,
	PLAYER_ATTACK,
	PLAYER_RETREAT,
	PLAYER_CHECK,
	ENEMY_ATTACK,
	ENEMY_CHECK,
	BATTLE_END,
}

var phase setget set_phase
var item_used := false

var player_stats: Stats
var enemy_stats: Stats

onready var player_stats_display := $Root/Bar/Sections/PlayerStats
onready var enemy_stats_display := $Root/Bar/Sections/EnemyStats
onready var actions := $Root/Bar/Sections/Actions
onready var stats_dialog := $Root/StatsDialog
onready var items_dialog := $Root/ItemsDialog


func _ready() -> void:
	randomize()
	
	player_stats = Game.stats
	enemy_stats = Stats.new()
	enemy_stats.attack = randi() % 10
	enemy_stats.defend = randi() % 10
	
	player_stats_display.set_stats(player_stats)
	enemy_stats_display.set_stats(enemy_stats)
	
	actions.get_child(0).grab_focus()
	set_phase(BattlePhase.PLAYER_CHOOSE_ACTION)


func _on_Stats_pressed() -> void:
	stats_dialog.popup_centered()


func _on_Items_pressed() -> void:
	items_dialog.set_items(Game.items)
	items_dialog.popup_centered()


func _on_Retreat_pressed() -> void:
	set_phase(BattlePhase.PLAYER_RETREAT)


func _on_Attack_pressed() -> void:
	set_phase(BattlePhase.PLAYER_ATTACK)


func _on_ItemsDialog_item_selected(_items, index) -> void:
	Game.stats = player_stats
	Game.use_item(index)
	items_dialog.set_items(Game.items)
	items_dialog.show_stats()
	player_stats = Game.stats
	player_stats_display.set_stats(player_stats)
	item_used = true


func _on_ItemsDialog_finished() -> void:
	if item_used:
		set_phase(BattlePhase.PLAYER_CHECK)


func _calculate_damage(src_attack: int, dst_defend: int) -> int:
	var base = src_attack * 2 - dst_defend
	if base < 10:
		return randi() % 10
	return base + randi() % base


func set_phase(value):
	phase = value
	
	_enable_actions(phase == BattlePhase.PLAYER_CHOOSE_ACTION)
	
	match phase:
		BattlePhase.PLAYER_CHOOSE_ACTION:
			print("Player choose action ...")
			item_used = false
		
		BattlePhase.PLAYER_ATTACK:
			var damage = _calculate_damage(player_stats.attack, enemy_stats.defend)
			enemy_stats.health -= damage
			print("Player attack: damage ", damage)
			yield(get_tree().create_timer(1), "timeout")  # TODO: wait for animation
			enemy_stats_display.set_stats(enemy_stats)
			set_phase(BattlePhase.PLAYER_CHECK)
		
		BattlePhase.PLAYER_RETREAT:
			if randi() % 100 < 20:
				set_phase(BattlePhase.BATTLE_END)
			else:
				print("Retreat failed")
				set_phase(BattlePhase.ENEMY_ATTACK)
		
		BattlePhase.ENEMY_ATTACK:
			var damage = _calculate_damage(enemy_stats.attack, player_stats.defend)
			player_stats.health -= damage
			print("Enemy attack: damage ", damage)
			yield(get_tree().create_timer(1), "timeout")  # TODO: wait for animation
			player_stats_display.set_stats(player_stats)
			set_phase(BattlePhase.ENEMY_CHECK)
		
		BattlePhase.PLAYER_CHECK:
			if player_stats.health == 0 or enemy_stats.health == 0:
				set_phase(BattlePhase.BATTLE_END)
			else:
				set_phase(BattlePhase.ENEMY_ATTACK)
			
		BattlePhase.ENEMY_CHECK:
			if player_stats.health == 0 or enemy_stats.health == 0:
				set_phase(BattlePhase.BATTLE_END)
			else:
				set_phase(BattlePhase.PLAYER_CHOOSE_ACTION)
		
		BattlePhase.BATTLE_END:
			if player_stats.health == 0:
				print("You Lose")
			elif enemy_stats.health == 0:
				print("You Win")
			else:
				print("Retreat")


func _enable_actions(value: bool) -> void:
	for button in actions.get_children():
		button.disabled = not value


