# SimpleHUD.gd
# Attach this to a CanvasLayer node
extends CanvasLayer

var labels: VBoxContainer

func _ready() -> void:
	print("HUD: Starting up...")
	
	# Create container
	labels = VBoxContainer.new()
	labels.position = Vector2(20, 20)
	add_child(labels)
	
	# Create 5 labels
	for i in range(5):
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		labels.add_child(lbl)
	
	print("HUD: Created labels")
	
	# Connect signals
	GameState.health_changed.connect(_update_ui)
	GameState.ammo_changed.connect(_update_ui)
	GameState.lives_changed.connect(_update_ui)
	GameState.score_changed.connect(_update_ui)
	GameState.keys_changed.connect(_update_ui)
	
	print("HUD: Connected signals")
	_update_ui(0)

func _update_ui(_unused = null) -> void:
	var children = labels.get_children()
	children[0].text = "HEALTH: %d" % GameState.health
	children[1].text = "AMMO: %d" % GameState.ammo
	children[2].text = "LIVES: %d" % GameState.lives
	children[3].text = "SCORE: %d" % GameState.score
	
	var key_str = "KEYS: "
	if GameState.keys & 1: key_str += "GOLD "
	if GameState.keys & 2: key_str += "SILVER "
	children[4].text = key_str

func _process(_delta: float) -> void:
	# Force update every frame (debug)
	_update_ui(0)












#extends CanvasLayer
#
## UI Elements - assign these in the editor or create them programmatically
#@onready var health_label: Label = $StatusBar/Health
#@onready var ammo_label: Label = $StatusBar/Ammo
#@onready var lives_label: Label = $StatusBar/Lives
#@onready var score_label: Label = $StatusBar/Score
#@onready var floor_label: Label = $StatusBar/Floor
#@onready var weapon_texture: TextureRect = $StatusBar/WeaponIcon
#
## Key indicators
#@onready var gold_key: TextureRect = $StatusBar/GoldKey
#@onready var silver_key: TextureRect = $StatusBar/SilverKey
#
## Face/health indicator
#@onready var face_texture: TextureRect = $StatusBar/Face
#
#func _ready() -> void:
	## Connect to GameState signals
	#GameState.health_changed.connect(_on_health_changed)
	#GameState.ammo_changed.connect(_on_ammo_changed)
	#GameState.lives_changed.connect(_on_lives_changed)
	#GameState.score_changed.connect(_on_score_changed)
	#GameState.keys_changed.connect(_on_keys_changed)
	#GameState.weapon_changed.connect(_on_weapon_changed)
	#
	## Initial update
	#_update_all()
#
#func _update_all() -> void:
	#_on_health_changed(GameState.health)
	#_on_ammo_changed(GameState.ammo)
	#_on_lives_changed(GameState.lives)
	#_on_score_changed(GameState.score)
	#_on_keys_changed(GameState.keys)
	#_on_weapon_changed(GameState.weapon)
	#_update_floor()
#
## ===== SIGNAL HANDLERS =====
#func _on_health_changed(new_health: int) -> void:
	#if health_label:
		#health_label.text = "%d%%" % new_health
	#_update_face(new_health)
#
#func _on_ammo_changed(new_ammo: int) -> void:
	#if ammo_label:
		#ammo_label.text = "%02d" % new_ammo
#
#func _on_lives_changed(new_lives: int) -> void:
	#if lives_label:
		#lives_label.text = str(new_lives)
#
#func _on_score_changed(new_score: int) -> void:
	#if score_label:
		#score_label.text = "%06d" % new_score
#
#func _on_keys_changed(new_keys: int) -> void:
	#if gold_key:
		#gold_key.visible = (new_keys & 1) != 0
	#if silver_key:
		#silver_key.visible = (new_keys & 2) != 0
#
#func _on_weapon_changed(new_weapon: GameState.Weapon) -> void:
	#if weapon_texture:
		## Load appropriate weapon icon
		#match new_weapon:
			#GameState.Weapon.KNIFE:
				#weapon_texture.texture = load("res://assets/ui/knife_icon.png")
			#GameState.Weapon.PISTOL:
				#weapon_texture.texture = load("res://assets/ui/pistol_icon.png")
			#GameState.Weapon.MACHINEGUN:
				#weapon_texture.texture = load("res://assets/ui/machinegun_icon.png")
			#GameState.Weapon.CHAINGUN:
				#weapon_texture.texture = load("res://assets/ui/chaingun_icon.png")
#
#func _update_floor() -> void:
	#if floor_label:
		#floor_label.text = "Floor %d" % (GameState.current_map + 1)
#
## ===== FACE SYSTEM (like Wolf3D) =====
#func _update_face(health: int) -> void:
	#if not face_texture:
		#return
	#
	## Wolf3D has different faces based on health ranges
	## 100-81: Happy face
	## 80-61: Slight concern
	## 60-41: Concerned
	## 40-21: Worried
	## 20-1: Very worried
	## 0: Dead
	#
	#var face_index = 0
	#if health <= 0:
		#face_index = 8  # Dead face
	#elif health <= 20:
		#face_index = 7
	#elif health <= 40:
		#face_index = 6
	#elif health <= 60:
		#face_index = 5
	#elif health <= 80:
		#face_index = 4
	#else:
		#face_index = 0  # Happy
	#
	## Load appropriate face texture
	## face_texture.texture = load("res://assets/ui/face_%d.png" % face_index)
#
## ===== LEVEL STATS DISPLAY =====
#func show_level_stats() -> void:
	## Display end-of-level statistics
	#var stats = GameState.level_stats
	#var time = stats.get_time_seconds()
	#
	#print("=== LEVEL COMPLETE ===")
	#print("Kill Ratio: %d/%d (%d%%)" % [
		#stats.kill_count, 
		#stats.kill_total, 
		#_calculate_percentage(stats.kill_count, stats.kill_total)
	#])
	#print("Secret Ratio: %d/%d (%d%%)" % [
		#stats.secret_count, 
		#stats.secret_total, 
		#_calculate_percentage(stats.secret_count, stats.secret_total)
	#])
	#print("Treasure Ratio: %d/%d (%d%%)" % [
		#stats.treasure_count, 
		#stats.treasure_total, 
		#_calculate_percentage(stats.treasure_count, stats.treasure_total)
	#])
	#print("Time: %02d:%02d" % [time / 60, time % 60])
	#
	## Create and show stats screen UI
#
#func _calculate_percentage(count: int, total: int) -> int:
	#if total == 0:
		#return 0
	#return int((float(count) / float(total)) * 100.0)
