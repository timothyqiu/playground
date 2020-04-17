extends Control

onready var avatar := $Sections/Avatar
onready var health_label := $Sections/Value/Health
onready var attack_label := $Sections/Value/Attack
onready var defend_label := $Sections/Value/Defend
onready var level_label := $Sections/Value/Level


func set_avatar(texture: Texture) -> void:
	avatar.texture = texture


func set_stats(stats: Stats) -> void:
	health_label.text = str(stats.health)
	attack_label.text = str(stats.attack)
	defend_label.text = str(stats.defend)
	level_label.text = str(stats.level)
