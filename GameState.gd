extends Node

var health: int = 100
var lives: int = 3
var ammo: int = 8
var score: int = 0
var keys: int = 0  # Bitfield: 1=gold, 2=silver, 4=bronze, 8=key4

# Weapon system
enum Weapon { KNIFE, PISTOL, MACHINEGUN, CHAINGUN }
var weapon: Weapon = Weapon.PISTOL
var best_weapon: Weapon = Weapon.PISTOL
var chosen_weapon: Weapon = Weapon.PISTOL

# Level stats (reset each level)
var level_stats: LevelStats = null

var current_map: int = 0
var episode: int = 0
var selected_map_path: String = "user://assets/wolf3d/maps/json/00_Tunnels 1.json"
var selected_game: String = "wolf3d"

# Difficulty system
enum Difficulty { BABY, EASY, NORMAL, HARD }
var difficulty: Difficulty = Difficulty.NORMAL

var in_game: bool = false
var menu_from_game: bool = false

var saved_game_state: Dictionary = {}

# View size system (original Wolf3D behavior)
# viewsize ranges from 4 to 21 (in 16-pixel units)
# viewwidth = viewsize * 16, viewheight = viewwidth * 0.5
const VIEW_SIZE_MIN = 4
const VIEW_SIZE_MAX = 21
const VIEW_SIZE_DEFAULT = 15
const HEIGHT_RATIO = 0.5  # Original Wolf3D aspect ratio
const STATUSLINES = 40    # HUD height in original 320x200 resolution
const GAME_AREA_HEIGHT = 160  # 200 - STATUSLINES

var view_size: int = VIEW_SIZE_DEFAULT

signal view_size_changed(new_size: int)


# Difficulty modifiers
func get_damage_multiplier() -> float:
	match difficulty:
		Difficulty.BABY:
			return 0.25
		Difficulty.EASY:
			return 0.5
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 1.5
	return 1.0


func get_enemy_speed_multiplier() -> float:
	match difficulty:
		Difficulty.BABY:
			return 0.75
		Difficulty.EASY:
			return 0.9
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 1.25
	return 1.0


signal health_changed(new_health: int)
signal ammo_changed(new_ammo: int)
signal lives_changed(new_lives: int)
signal score_changed(new_score: int)
signal keys_changed(new_keys: int)
signal weapon_changed(new_weapon: Weapon)


func _ready():
	level_stats = LevelStats.new()
	add_child(level_stats)


# ===== HEALTH SYSTEM =====
signal player_died
signal damage_taken(amount: int)  # For screen flash

# Track who killed the player for death camera
var last_attacker: Node3D = null

func take_damage(amount: int, attacker: Node3D = null) -> void:
	if health <= 0:
		return

	# Apply difficulty multiplier
	var actual_damage = int(amount * get_damage_multiplier())
	actual_damage = max(actual_damage, 1)  # Always at least 1 damage

	var old_health = health
	health -= actual_damage
	health = max(health, 0)
	print("[DEBUG] take_damage: %d -> %d (damage: %d)" % [old_health, health, actual_damage])
	health_changed.emit(health)
	
	# Play pain sound and emit for screen flash
	SoundManager.play_sound(SoundManager.SoundID.NAZIHITPLAYERSND)
	damage_taken.emit(actual_damage)
	
	# Track attacker for death sequence
	if attacker:
		last_attacker = attacker

	if health <= 0:
		player_died.emit()
		die()


func heal(amount: int) -> void:
	if health <= 0:
		return

	var old_health = health
	health += amount
	health = min(health, 100)
	print("[DEBUG] heal: %d -> %d (healed: %d)" % [old_health, health, amount])
	health_changed.emit(health)


signal restart_level_requested

func die() -> void:
	lives -= 1
	lives_changed.emit(lives)

	if lives >= 0:
		# DON'T reset stats here - keep health at 0 so death face shows
		# Stats will be reset when level reloads via start_level()
		
		# Emit signal - DeathSequence handles the death animation and restart
		restart_level_requested.emit()
	else:
		game_over()


# Called when level restarts after death (or at start of any level)
func reset_for_respawn() -> void:
	health = 100
	weapon = best_weapon
	chosen_weapon = best_weapon
	ammo = 8
	keys = 0

	health_changed.emit(health)
	ammo_changed.emit(ammo)
	weapon_changed.emit(weapon)
	keys_changed.emit(keys)


func game_over() -> void:
	print("GAME OVER")
	# DeathSequence handles game over screen


# ===== AMMO SYSTEM =====
func give_ammo(amount: int) -> void:
	if ammo == 99:
		return

	# If had no ammo and wasn't attacking, switch to chosen weapon
	var had_no_ammo = ammo == 0

	ammo += amount
	ammo = min(ammo, 99)
	ammo_changed.emit(ammo)

	if had_no_ammo and weapon == Weapon.KNIFE:
		weapon = chosen_weapon
		weapon_changed.emit(weapon)


func use_ammo(amount: int = 1) -> bool:
	if ammo >= amount:
		ammo -= amount
		ammo_changed.emit(ammo)

		# Auto-switch to knife if out of ammo
		if ammo == 0:
			weapon = Weapon.KNIFE
			weapon_changed.emit(weapon)

		return true
	return false


# ===== WEAPON SYSTEM =====
func give_weapon(new_weapon: Weapon) -> void:
	give_ammo(6)

	if new_weapon > best_weapon:
		best_weapon = new_weapon
		weapon = new_weapon
		chosen_weapon = new_weapon
		weapon_changed.emit(weapon)


func change_weapon(new_weapon: Weapon) -> void:
	if ammo == 0 and new_weapon != Weapon.KNIFE:
		return  # Can't switch without ammo

	if new_weapon <= best_weapon:
		weapon = new_weapon
		chosen_weapon = new_weapon
		weapon_changed.emit(weapon)


# ===== KEYS SYSTEM =====
func give_key(key_index: int) -> void:
	# key_index: 0=gold, 1=silver, 2=bronze, 3=key4
	keys |= (1 << key_index)
	keys_changed.emit(keys)


func has_key(key_index: int) -> bool:
	return (keys & (1 << key_index)) != 0


# ===== SCORE SYSTEM =====
const EXTRA_LIFE_POINTS = 40000

var next_extra_life: int = EXTRA_LIFE_POINTS


func give_points(points: int) -> void:
	score += points
	score_changed.emit(score)

	# Check for extra life
	while score >= next_extra_life:
		next_extra_life += EXTRA_LIFE_POINTS
		give_extra_life()


func give_extra_life() -> void:
	if lives < 9:
		lives += 1
		lives_changed.emit(lives)
		# Play 1-up sound


# ===== PICKUP FUNCTIONS =====
func pickup_health_potion() -> bool:
	if health >= 100:
		return false
	heal(25)
	return true


func pickup_food() -> bool:
	if health >= 100:
		return false
	heal(10)
	return true


func pickup_clip() -> bool:
	if ammo >= 99:
		return false
	give_ammo(8)
	return true


func pickup_treasure(value: int) -> void:
	give_points(value)
	level_stats.treasure_count += 1


# ===== LEVEL MANAGEMENT =====
func start_new_game(starting_episode: int = 0, starting_level: int = 0) -> void:
	episode = starting_episode
	current_map = starting_level

	health = 100
	lives = 3
	ammo = 8
	score = 0
	keys = 0
	weapon = Weapon.PISTOL
	best_weapon = Weapon.PISTOL
	chosen_weapon = Weapon.PISTOL
	next_extra_life = EXTRA_LIFE_POINTS

	# Emit all signals
	health_changed.emit(health)
	lives_changed.emit(lives)
	ammo_changed.emit(ammo)
	score_changed.emit(score)
	keys_changed.emit(keys)
	weapon_changed.emit(weapon)


func start_level() -> void:
	level_stats.start_level()
	keys = 0  # Keys reset each level
	keys_changed.emit(keys)


func complete_level() -> void:
	# stats for end-of-level screen
	pass


# ===== VIEW SIZE SYSTEM =====
func set_view_size(new_size: int) -> void:
	new_size = clampi(new_size, VIEW_SIZE_MIN, VIEW_SIZE_MAX)
	if new_size != view_size:
		view_size = new_size
		view_size_changed.emit(view_size)
		print("View size changed to: %d" % view_size)


func increase_view_size() -> void:
	set_view_size(view_size + 1)


func decrease_view_size() -> void:
	set_view_size(view_size - 1)


# Get viewport dimensions in original 320x200 coordinates
func get_view_width() -> int:
	return view_size * 16


func get_view_height() -> int:
	return int(get_view_width() * HEIGHT_RATIO)


# Check if at full size (no borders needed)
func is_full_size() -> bool:
	return view_size >= VIEW_SIZE_MAX


func _process(_delta: float) -> void:
	# Handle view size input
	if Input.is_action_just_pressed("view_increase"):
		increase_view_size()
	elif Input.is_action_just_pressed("view_decrease"):
		decrease_view_size()


# ===== SAVE/LOAD GAME STATE =====
func save_game_state() -> void:
	# Save player state
	saved_game_state = {
		"health": health,
		"lives": lives,
		"ammo": ammo,
		"score": score,
		"keys": keys,
		"weapon": weapon,
		"best_weapon": best_weapon,
		"chosen_weapon": chosen_weapon,
		"current_map": current_map,
		"episode": episode,
		"selected_map_path": selected_map_path,
		"selected_game": selected_game,
		"difficulty": difficulty,
		"view_size": view_size,
		"next_extra_life": next_extra_life,
		"player_position": Vector3.ZERO,
		"player_rotation": 0.0,
		"enemies": [],
		"corpses": [],
		"pickups": [],
		"doors": []
	}
	
	# Save player position and rotation
	var player = _get_player()
	if player:
		var pos = player.global_position
		saved_game_state["player_position"] = {"x": pos.x, "y": pos.y, "z": pos.z}
		saved_game_state["player_rotation"] = player.rotation.y
	
	# Save enemies state
	var enemies = _get_tree_or_null().get_nodes_in_group("enemies") if _get_tree_or_null() else []
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			if enemy.is_dead:
				# Save corpses separately
				var pos = enemy.global_position
				saved_game_state["corpses"].append({
					"position": {"x": pos.x, "y": pos.y, "z": pos.z},
					"rotation": enemy.rotation.y,
					"enemy_type": enemy.enemy_type,
					"state": enemy.state
				})
			else:
				# Save living enemies
				var pos = enemy.global_position
				saved_game_state["enemies"].append({
					"position": {"x": pos.x, "y": pos.y, "z": pos.z},
					"rotation": enemy.rotation.y,
					"health": enemy.health,
					"state": enemy.state,
					"direction": enemy.direction,
					"enemy_type": enemy.enemy_type,
					"in_attack_mode": enemy.in_attack_mode,
					"tilex": enemy.tilex,
					"tiley": enemy.tiley
				})
	
	# Save pickups state (track which ones are collected)
	var pickups = _get_tree_or_null().get_nodes_in_group("pickups") if _get_tree_or_null() else []
	for pickup in pickups:
		if pickup and is_instance_valid(pickup):
			var pos = pickup.global_position
			saved_game_state["pickups"].append({
				"position": {"x": pos.x, "y": pos.y, "z": pos.z},
				"type": pickup.get_meta("pickup_type") if pickup.has_meta("pickup_type") else 0
			})
	
	# Save doors state
	var doors = _get_tree_or_null().get_nodes_in_group("doors") if _get_tree_or_null() else []
	for door in doors:
		if door and is_instance_valid(door):
			var door_data = {
				"grid_x": door.get_meta("grid_x") if door.has_meta("grid_x") else -1,
				"grid_y": door.get_meta("grid_y") if door.has_meta("grid_y") else -1,
				"current_state": door.current_state,
				"open_ratio": door.open_ratio,
				"auto_close_timer": door.auto_close_timer
			}
			saved_game_state["doors"].append(door_data)
	
	print("[GameState] Game state saved: Player at ", saved_game_state["player_position"])

func has_saved_state() -> bool:
	return not saved_game_state.is_empty()

func clear_saved_state() -> void:
	saved_game_state.clear()

func _get_player() -> Node:
	var tree = _get_tree_or_null()
	if tree:
		return tree.get_first_node_in_group("player")
	return null

func _get_tree_or_null():
	if is_inside_tree():
		return get_tree()
	return null
