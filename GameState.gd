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

# Current level
var current_map: int = 0
var episode: int = 0
var selected_map_path: String = "user://assets/wolf3d/maps/json/00_Tunnels 1.json"  # Default map
var selected_game: String = "wolf3d"  # "wolf3d" or "sod"

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
func take_damage(amount: int) -> void:
	if health <= 0:
		return

	# if difficulty == BABY: amount = amount / 4
	
	health -= amount
	health = max(health, 0)
	health_changed.emit(health)
	
	if health <= 0:
		die()

func heal(amount: int) -> void:
	if health <= 0:
		return
	
	health += amount
	health = min(health, 100)
	health_changed.emit(health)

func die() -> void:
	lives -= 1
	lives_changed.emit(lives)
	
	if lives >= 0:
		health = 100
		weapon = best_weapon
		chosen_weapon = best_weapon
		ammo = 8
		keys = 0
		
		health_changed.emit(health)
		ammo_changed.emit(ammo)
		weapon_changed.emit(weapon)
		keys_changed.emit(keys)
	else:
		game_over()

func game_over() -> void:
	print("GAME OVER")
	# Handle game over logic

# ===== AMMO SYSTEM =====
func give_ammo(amount: int) -> void:
	if ammo == 99:
		return
	
	# If had no ammo and wasn't attacking, switch to chosen weapon
	var had_no_ammo = (ammo == 0)
	
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
