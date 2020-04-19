class_name Battle
extends CanvasLayer

const HitEffect = preload("res://src/Battle/HitEffect.tscn")
const DamageText = preload("res://src/Battle/DamageText.tscn")

enum BattleResult {
	PLAYER_WIN,
	PLAYER_LOSE,
	RETREAT
}

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
var enemy_items = []

var player_hurt: int
var enemy_hurt: int

var enemy_texture: Texture

onready var player_stats_display := $Root/Bar/Sections/PlayerStats
onready var enemy_stats_display := $Root/Bar/Sections/EnemyStats
onready var actions := $Root/Bar/Sections/Actions
onready var stats_dialog := $Root/StatsDialog
onready var items_dialog := $Root/ItemsDialog
onready var message_label := $Root/MessageLabel
onready var animation_player := $AnimationPlayer
onready var player_sprite := $Root/PlayerSprite
onready var enemy_sprite := $Root/EnemySprite
onready var player_hurt_sound := $PlayerHurtSound
onready var enemy_hurt_sound := $EnemyHurtSound
onready var attack_sound := $AttackSound
onready var player_death_sound := $PlayerDeathSound
onready var enemy_death_sound := $EnemyDeathSound


func _ready() -> void:
	randomize()
	
	player_stats = PlayerStats
	
	if not enemy_stats:
		enemy_stats = Stats.new()
	
	player_stats_display.set_stats(player_stats)
	enemy_stats_display.set_stats(enemy_stats)
	
	if enemy_texture:
		enemy_sprite.texture = enemy_texture
	
	var avatar = AtlasTexture.new()
	avatar.atlas = enemy_sprite.texture
	avatar.region = Rect2(0, 0, 32, 32)
	enemy_stats_display.set_avatar(avatar)
	
	message_label.hide()
	
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
	Game.use_item(index)
	items_dialog.set_items(Game.items)
	items_dialog.show_stats()
	player_stats_display.set_stats(player_stats)
	item_used = true
	
	items_dialog.hide()


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
			message_label.visible = false
			item_used = false
		
		BattlePhase.PLAYER_ATTACK:
			enemy_hurt = _calculate_damage(player_stats.attack, enemy_stats.defend)
			animation_player.play("enemy_hurt")
			yield(animation_player, "animation_finished")
			enemy_stats_display.set_stats(enemy_stats)
			set_phase(BattlePhase.PLAYER_CHECK)
		
		BattlePhase.PLAYER_RETREAT:
			if randi() % 100 < 20:
				set_phase(BattlePhase.BATTLE_END)
			else:
				_show_message("逃跑失败")
				set_phase(BattlePhase.ENEMY_ATTACK)
		
		BattlePhase.ENEMY_ATTACK:
			player_hurt = _calculate_damage(enemy_stats.attack, player_stats.defend)
			animation_player.play("player_hurt")
			yield(animation_player, "animation_finished")
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
				_show_message("你死了")
				player_death_sound.play()
				player_sprite.hide()
			elif enemy_stats.health == 0:
				var gains = []
				
				if enemy_stats.current_exp > 0:
					var exp_get = "获得了%d经验" % enemy_stats.current_exp
					var current_level = PlayerStats.level
					PlayerStats.current_exp += enemy_stats.current_exp
					if current_level != PlayerStats.level:
						exp_get += "，升到了%d级" % PlayerStats.level
					gains.append(exp_get)
				
				if enemy_stats.money > 0:
					gains.append("获得了%d金币" % enemy_stats.money)
				
				var items_get = ""
				for item_id in enemy_items:
					var item = ItemDB.ITEMS[item_id]
					items_get += "%s、" % item.name
					Game.put_item(item_id)  # FIXME: item overflow?
				if not items_get.empty():
					items_get.erase(items_get.length() - 1, 1)
					gains.append("获得了%s" % items_get)
				
				var text = ""
				if not gains.empty():
					for gain in gains:
						text += "\n" + gain
				
				_show_message("胜利！" + text)
				enemy_death_sound.play()
				enemy_sprite.hide()
			else:
				_show_message("逃跑成功")


func _unhandled_input(event: InputEvent) -> void:
	if phase != BattlePhase.BATTLE_END:
		return
	
	if event.is_pressed() and not event.is_echo():
		Transition.pop_scene()
		get_tree().set_input_as_handled()
		
		if player_stats.health == 0:
			Events.emit_signal("battle_finished", BattleResult.PLAYER_LOSE)
		elif enemy_stats.health == 0:
			Events.emit_signal("battle_finished", BattleResult.PLAYER_WIN)
		else:
			Events.emit_signal("battle_finished", BattleResult.RETREAT)


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true


func _enable_actions(value: bool) -> void:
	for button in actions.get_children():
		button.disabled = not value


# ugly
func _show_hit_effect(enemy: bool) -> void:
	var effect := HitEffect.instance()
	var text := DamageText.instance()
	add_child(effect)
	add_child(text)
	
	var damage: int
	if enemy:
		damage = enemy_hurt
		effect.global_position = enemy_sprite.global_position
		text.global_position = enemy_sprite.global_position
		enemy_stats.health -= enemy_hurt
	else:
		damage = player_hurt
		effect.global_position = player_sprite.global_position
		text.global_position = player_sprite.global_position
		player_stats.health -= player_hurt
	
	if damage == 0:
		text.set_text("Miss")
	else:
		text.set_text("%d" % -damage)
	
	attack_sound.play()


func _play_hurt_sound(enemy: bool) -> void:
	if enemy:
		enemy_hurt_sound.play()
	else:
		player_hurt_sound.play()
