extends Node
# TEMPORAIRE : capture une image du combat pour validation visuelle headless.
func _ready() -> void:
	GameData.difficulty = "normal"
	GameData.player_team = ["tank", "archer", "soigneur"]
	GameData.ai_team = ["berserker", "mage", "assassin"]
	var main := load("res://Main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.2).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shot.png")
	get_tree().quit()
