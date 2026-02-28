class_name Enemy
extends Area3D

# Enemy types (matching L2Utils.EnemyType)
enum EnemyType { NONE, GUARD, OFFICER, SS, DOG, MUTANT, BOSS }

# AI States (matching original Wolf3D state machine)
enum State { STAND, PATH, CHASE, SHOOT, PAIN, DIE, DEAD }

# Directions (matching original Wolf3D - WL_DEF.H)
enum Dir { NORTH = 0, NORTHEAST = 1, EAST = 2, SOUTHEAST = 3, SOUTH = 4, SOUTHWEST = 5, WEST = 6, NORTHWEST = 7, NODIR = 8 }

const OPPOSITE = [Dir.SOUTH, Dir.SOUTHWEST, Dir.WEST, Dir.NORTHWEST, Dir.NORTH, Dir.NORTHEAST, Dir.EAST, Dir.SOUTHEAST, Dir.NODIR]

# Direction vectors (for movement) - pre-calculated normalized values
const DIAG = 0.7071067811865476  # 1/sqrt(2) for diagonal movement
const DIR_VECTORS = {
	Dir.NORTH: Vector3(0, 0, -1),
	Dir.NORTHEAST: Vector3(DIAG, 0, -DIAG),
	Dir.EAST: Vector3(1, 0, 0),
	Dir.SOUTHEAST: Vector3(DIAG, 0, DIAG),
	Dir.SOUTH: Vector3(0, 0, 1),
	Dir.SOUTHWEST: Vector3(-DIAG, 0, DIAG),
	Dir.WEST: Vector3(-1, 0, 0),
	Dir.NORTHWEST: Vector3(-DIAG, 0, -DIAG),
	Dir.NODIR: Vector3.ZERO,
}

# Health values by enemy type (matching original Wolf3D starthitpoints)
const HEALTH_VALUES = {
	EnemyType.GUARD: 25,
	EnemyType.OFFICER: 50,
	EnemyType.SS: 100,
	EnemyType.DOG: 1,
	EnemyType.MUTANT: 45,
	EnemyType.BOSS: 850,
}

# Speed values (tiles per second, scaled from original)
const SPEED_VALUES = {
	EnemyType.GUARD: 1.5,
	EnemyType.OFFICER: 2.5,
	EnemyType.SS: 2.0,
	EnemyType.DOG: 4.0,
	EnemyType.MUTANT: 1.5,
	EnemyType.BOSS: 1.0,
}

# Reaction time ranges (in seconds, converted from tics)
const REACTION_TIMES = {
	EnemyType.GUARD: [0.1, 0.5],
	EnemyType.OFFICER: [0.05, 0.05],
	EnemyType.SS: [0.05, 0.25],
	EnemyType.DOG: [0.02, 0.15],
	EnemyType.MUTANT: [0.05, 0.25],
	EnemyType.BOSS: [0.02, 0.02],
}

# Point values for killing enemies (authentic Wolf3D values)
const POINT_VALUES = {
	EnemyType.GUARD: 100,
	EnemyType.OFFICER: 400,
	EnemyType.SS: 500,
	EnemyType.DOG: 200,
	EnemyType.MUTANT: 700,
	EnemyType.BOSS: 5000,
}

# Sprite base indices for each enemy type (correct ranges from extracted sprites)
# Guard: 48-96, Dog: 97-135, SS: 136-184, Mutant: 185-235, Officer: 236-285
const SPRITE_BASES = {
	EnemyType.GUARD: 48,     # Guard sprites: 48-96
	EnemyType.DOG: 97,       # Dog sprites: 97-135
	EnemyType.SS: 136,       # SS (blue) sprites: 136-184
	EnemyType.MUTANT: 185,   # Mutant sprites: 185-235
	EnemyType.OFFICER: 236,  # Officer sprites: 236-285
	EnemyType.BOSS: 294,     # Hans Grosse: 294-304
}

@export var enemy_type: EnemyType = EnemyType.GUARD
@export var sprite_texture_folder: String:
	get: return GameState.get_sprites_path()

# Core state
var state: State = State.STAND
var health: int = 25
var is_dead: bool = false
var speed: float = 1.5

# Movement
var direction: int = Dir.NODIR
var distance: float = 0.0  # Distance remaining to next tile center
var tilex: int = 0
var tiley: int = 0

# AI flags (matching original FL_ flags)
var is_ambush: bool = false
var in_attack_mode: bool = false
var first_attack: bool = false

# Detection
var reaction_time: float = 0.0
var reaction_countdown: float = 0.0

# Animation
var anim_timer: float = 0.0
var anim_frame: int = 0
var standing_sprite_idx: int = 0

# Shooting
var shoot_timer: float = 0.0
const SHOOT_DELAY: float = 0.5

# References
var map_loader: Node = null
var grid = null
var player: Node3D = null

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

signal died(enemy: Enemy)

func _ready() -> void:
	add_to_group("enemies")
	
	# Set health and speed based on type
	health = HEALTH_VALUES.get(enemy_type, 25)
	speed = SPEED_VALUES.get(enemy_type, 1.5)
	
	# Get metadata from MapLoader
	if has_meta("sprite_idx"):
		standing_sprite_idx = get_meta("sprite_idx")
	if has_meta("direction"):
		direction = get_meta("direction")
	if has_meta("is_patrol"):
		var is_patrol = get_meta("is_patrol")
		state = State.PATH if is_patrol else State.STAND
		if is_patrol:
			in_attack_mode = false
		else:
			is_ambush = true  # Standing enemies require sight
	
	# Calculate tile position
	tilex = int(floor(position.x))
	tiley = int(floor(position.z))
	
	# Find MapLoader and player
	_find_references()
	
	# Calculate reaction time range for this enemy type
	var rt = REACTION_TIMES.get(enemy_type, [0.1, 0.3])
	reaction_time = randf_range(rt[0], rt[1])

func _find_references() -> void:
	# Find MapLoader
	var p = get_parent()
	while p:
		if p is MapLoader:
			map_loader = p
			grid = p.grid
			break
		p = p.get_parent()
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		# Try to find by class
		for node in get_tree().get_nodes_in_group("default"):
			if node is CharacterBody3D:
				player = node
				break

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Make sure we have player reference
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	
	# Update animation
	_update_animation(delta)
	
	# State machine
	match state:
		State.STAND:
			_t_stand(delta)
		State.PATH:
			_t_path(delta)
		State.CHASE:
			if enemy_type == EnemyType.DOG:
				_t_dog_chase(delta)
			else:
				_t_chase(delta)
		State.SHOOT:
			_t_shoot_state(delta)
		State.PAIN:
			_t_pain(delta)
		State.DIE:
			pass  # Handled by animation
		State.DEAD:
			pass

# ============================================================================
# AI BEHAVIORS (Based on WL_ACT2.C)
# ============================================================================

func _t_stand(_delta: float) -> void:
	if _sight_player():
		_first_sighting()

func _t_path(delta: float) -> void:
	if _sight_player():
		_first_sighting()
		return
	
	if direction == Dir.NODIR:
		_select_path_dir()
		if direction == Dir.NODIR:
			return
	
	var move = speed * delta
	
	while move > 0:
		if move < distance:
			_move_obj(move)
			break
		
		position.x = tilex + 0.5
		position.z = tiley + 0.5
		move -= distance
		
		_select_path_dir()
		if direction == Dir.NODIR:
			return

func _t_chase(delta: float) -> void:
	var dodge = false
	
	if _check_line():
		var dx = abs(tilex - int(floor(player.position.x)))
		var dy = abs(tiley - int(floor(player.position.z)))
		var dist = max(dx, dy)
		
		var chance: float
		if dist == 0 or (dist == 1 and distance < 0.25):
			chance = 0.9
		else:
			chance = 0.05 / dist
		
		if randf() < chance:
			state = State.SHOOT
			shoot_timer = 0.0
			return
		
		dodge = true
	
	if direction == Dir.NODIR:
		if dodge:
			_select_dodge_dir()
		else:
			_select_chase_dir()
		if direction == Dir.NODIR:
			return
	
	var move = speed * delta
	
	while move > 0:
		if move < distance:
			_move_obj(move)
			break
		
		position.x = tilex + 0.5
		position.z = tiley + 0.5
		move -= distance
		
		if dodge:
			_select_dodge_dir()
		else:
			_select_chase_dir()
		
		if direction == Dir.NODIR:
			return

func _t_dog_chase(delta: float) -> void:
	if direction == Dir.NODIR:
		_select_dodge_dir()
		if direction == Dir.NODIR:
			return
	
	var move = speed * delta
	
	while move > 0:
		var dx = abs(position.x - player.position.x)
		var dz = abs(position.z - player.position.z)
		
		if dx <= 0.8 and dz <= 0.8:
			_t_bite()
			state = State.CHASE
			return
		
		if move < distance:
			_move_obj(move)
			break
		
		position.x = tilex + 0.5
		position.z = tiley + 0.5
		move -= distance
		
		_select_dodge_dir()
		if direction == Dir.NODIR:
			return

func _t_shoot_state(delta: float) -> void:
	shoot_timer += delta
	
	if shoot_timer >= SHOOT_DELAY:
		_t_shoot()
		state = State.CHASE
		direction = Dir.NODIR

func _t_pain(_delta: float) -> void:
	await get_tree().create_timer(0.15).timeout
	state = State.CHASE
	direction = Dir.NODIR

# ============================================================================
# COMBAT (Based on WL_ACT2.C T_Shoot and T_Bite)
# ============================================================================

func _t_shoot() -> void:
	if not _check_line():
		return
	
	var dx = abs(tilex - int(floor(player.position.x)))
	var dy = abs(tiley - int(floor(player.position.z)))
	var dist = max(dx, dy)
	if dist > 20:
		return
	
	if enemy_type == EnemyType.SS or enemy_type == EnemyType.BOSS:
		dist = int(dist * 2.0 / 3.0)

	var hitchance: int
	var player_moving = false
	if player.has_method("get_velocity"):
		var vel = player.get_velocity()
		player_moving = vel.length() > 2.0
	elif player.get("velocity") != null:
		player_moving = player.velocity.length() > 2.0
	
	if player_moving:
		hitchance = 160 - dist * 16
	else:
		hitchance = 256 - dist * 8
	
	hitchance = clamp(hitchance, 0, 256)
	
	if randi() % 256 < hitchance:
		# Calculate damage based on distance
		var damage: int
		if dist < 2:
			damage = randi() % 64 
		elif dist < 4:
			damage = randi() % 32  
		else:
			damage = randi() % 16
		
		damage = max(1, damage)
		
		
		if player.has_method("take_damage"):
			player.take_damage(damage, self)
	
	SoundManager.play_sfx("NAZIFIRESND")



func _t_bite() -> void:
	SoundManager.play_sfx("DOGATTACKSND")
	
	var dx = abs(position.x - player.position.x)
	var dz = abs(position.z - player.position.z)
	
	if dx <= 1.0 and dz <= 1.0:
		if randi() % 256 < 180:
			var damage = randi() % 16
			damage = max(1, damage)
			if player.has_method("take_damage"):
				player.take_damage(damage, self)

# ============================================================================
# DETECTION (Based on WL_STATE.C)
# ============================================================================

func _sight_player() -> bool:
	if in_attack_mode:
		return false
	
	if reaction_countdown > 0:
		reaction_countdown -= get_physics_process_delta_time()
		if reaction_countdown > 0:
			return false
		return true
	
	if is_ambush:
		if not _check_sight():
			return false
		is_ambush = false
	else:
		if not _check_sight():
			return false
	
	var rt = REACTION_TIMES.get(enemy_type, [0.1, 0.3])
	reaction_countdown = randf_range(rt[0], rt[1])
	return false

func _check_sight() -> bool:
	if player == null:
		return false
	
	var delta_vec = player.position - position
	delta_vec.y = 0
	
	if delta_vec.length() < 1.5:
		return _check_line()
	
	if direction != Dir.NODIR and direction < 8:
		match direction:
			Dir.NORTH:
				if delta_vec.z > 0:
					return false
			Dir.EAST:
				if delta_vec.x < 0:
					return false
			Dir.SOUTH:
				if delta_vec.z < 0:
					return false
			Dir.WEST:
				if delta_vec.x > 0:
					return false
	
	return _check_line()

func _check_line() -> bool:
	if player == null or grid == null:
		return false
	
	var x0 = tilex
	var y0 = tiley
	var x1 = int(floor(player.position.x))
	var y1 = int(floor(player.position.z))
	
	if x0 == x1 and y0 == y1:
		return true
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	var x = x0
	var y = y0
	
	while true:
		# Calculate next position FIRST
		var e2 = 2 * err
		var next_x = x
		var next_y = y
		
		if e2 > -dy:
			err -= dy
			next_x += sx
		if e2 < dx:
			err += dx
			next_y += sy
		
		# Move to next tile
		x = next_x
		y = next_y
		
		if x == x1 and y == y1:
			return true
		
		if not grid.is_within_grid(x, y):
			return false
		
		var tile_id = grid.tile_at(x, y)
		
		if tile_id >= 1 and tile_id <= 53:
			return false
		
		if tile_id >= 90 and tile_id <= 101:
			var door = _find_door_at(x, y)
			if door:
				var open_ratio = door.get("open_ratio")
				if open_ratio != null and open_ratio < 0.3:
					return false
			elif door == null:
				return false
		
		if abs(x - x0) > 64 or abs(y - y0) > 64:
			return false
	
	return true



func _find_door_at(tx: int, ty: int) -> Node:
	var doors = get_tree().get_nodes_in_group("doors")
	for door in doors:
		var d_pos = door.get("start_pos")
		if d_pos == null:
			d_pos = door.position
		if int(floor(d_pos.x)) == tx and int(floor(d_pos.z)) == ty:
			return door
	return null

# ============================================================================
# MOVEMENT (Based on WL_STATE.C)
# ============================================================================

func _select_chase_dir() -> void:
	if player == null:
		direction = Dir.NODIR
		return
	
	var deltax = int(floor(player.position.x)) - tilex
	var deltay = int(floor(player.position.z)) - tiley
	
	var d = [Dir.NODIR, Dir.NODIR]
	
	if deltax > 0:
		d[0] = Dir.EAST
	elif deltax < 0:
		d[0] = Dir.WEST
	
	if deltay > 0:
		d[1] = Dir.SOUTH
	elif deltay < 0:
		d[1] = Dir.NORTH
	
	if abs(deltay) > abs(deltax):
		var temp = d[0]
		d[0] = d[1]
		d[1] = temp
	
	var turnaround = OPPOSITE[direction] if direction != Dir.NODIR else Dir.NODIR
	
	if d[0] == turnaround:
		d[0] = Dir.NODIR
	if d[1] == turnaround:
		d[1] = Dir.NODIR
	
	if d[0] != Dir.NODIR:
		direction = d[0]
		if _try_walk():
			return
	
	if d[1] != Dir.NODIR:
		direction = d[1]
		if _try_walk():
			return
	
	var dirs = [Dir.NORTH, Dir.EAST, Dir.SOUTH, Dir.WEST]
	dirs.shuffle()
	for dir in dirs:
		if dir != turnaround:
			direction = dir
			if _try_walk():
				return
	
	if turnaround != Dir.NODIR:
		direction = turnaround
		if _try_walk():
			return
	
	direction = Dir.NODIR

func _select_dodge_dir() -> void:
	if player == null:
		_select_chase_dir()
		return
	
	var deltax = int(floor(player.position.x)) - tilex
	var deltay = int(floor(player.position.z)) - tiley
	
	var dirtry = [Dir.NODIR, Dir.NODIR, Dir.NODIR, Dir.NODIR, Dir.NODIR]
	
	if deltax > 0:
		dirtry[1] = Dir.EAST
		dirtry[3] = Dir.WEST
	else:
		dirtry[1] = Dir.WEST
		dirtry[3] = Dir.EAST
	
	if deltay > 0:
		dirtry[2] = Dir.SOUTH
		dirtry[4] = Dir.NORTH
	else:
		dirtry[2] = Dir.NORTH
		dirtry[4] = Dir.SOUTH
	
	# Randomize for dodging
	if abs(deltax) > abs(deltay):
		var temp = dirtry[1]
		dirtry[1] = dirtry[2]
		dirtry[2] = temp
		temp = dirtry[3]
		dirtry[3] = dirtry[4]
		dirtry[4] = temp
	
	if randf() < 0.5:
		var temp = dirtry[1]
		dirtry[1] = dirtry[2]
		dirtry[2] = temp
		temp = dirtry[3]
		dirtry[3] = dirtry[4]
		dirtry[4] = temp
	
	if dirtry[1] == Dir.EAST and dirtry[2] == Dir.NORTH:
		dirtry[0] = Dir.NORTHEAST
	elif dirtry[1] == Dir.EAST and dirtry[2] == Dir.SOUTH:
		dirtry[0] = Dir.SOUTHEAST
	elif dirtry[1] == Dir.WEST and dirtry[2] == Dir.NORTH:
		dirtry[0] = Dir.NORTHWEST
	elif dirtry[1] == Dir.WEST and dirtry[2] == Dir.SOUTH:
		dirtry[0] = Dir.SOUTHWEST
	
	var turnaround = OPPOSITE[direction] if direction != Dir.NODIR else Dir.NODIR
	if first_attack:
		turnaround = Dir.NODIR
		first_attack = false
	
	for i in range(5):
		if dirtry[i] == Dir.NODIR or dirtry[i] == turnaround:
			continue
		direction = dirtry[i]
		if _try_walk():
			return
	
	if turnaround != Dir.NODIR:
		direction = turnaround
		if _try_walk():
			return
	
	direction = Dir.NODIR

func _select_path_dir() -> void:
	_select_chase_dir()
	distance = 1.0

func _is_position_blocked(pos: Vector3) -> bool:
	"""Check if a position is blocked by walls or closed doors"""
	if grid == null:
		return false
	
	var enemy_radius = 0.3
	
	var corners = [
		Vector2(pos.x - enemy_radius, pos.z - enemy_radius),
		Vector2(pos.x + enemy_radius, pos.z - enemy_radius),
		Vector2(pos.x - enemy_radius, pos.z + enemy_radius),
		Vector2(pos.x + enemy_radius, pos.z + enemy_radius)
	]
	
	for corner in corners:
		var check_x = int(floor(corner.x))
		var check_z = int(floor(corner.y))
		
		if not grid.is_within_grid(check_x, check_z):
			return true
		
		var tile_id = grid.tile_at(check_x, check_z)
		
		# Walls block movement
		if tile_id >= 1 and tile_id <= 53:
			return true
		
		# Closed doors block movement
		if tile_id >= 90 and tile_id <= 101:
			var door = _find_door_at(check_x, check_z)
			if door and not door.is_open():
				return true
	
	return false

func _try_walk() -> bool:
	if direction == Dir.NODIR:
		return false
	
	var new_tilex = tilex
	var new_tiley = tiley
	
	match direction:
		Dir.NORTH:
			new_tiley -= 1
		Dir.NORTHEAST:
			new_tilex += 1
			new_tiley -= 1
		Dir.EAST:
			new_tilex += 1
		Dir.SOUTHEAST:
			new_tilex += 1
			new_tiley += 1
		Dir.SOUTH:
			new_tiley += 1
		Dir.SOUTHWEST:
			new_tilex -= 1
			new_tiley += 1
		Dir.WEST:
			new_tilex -= 1
		Dir.NORTHWEST:
			new_tilex -= 1
			new_tiley -= 1
	
	# Check if walkable
	if grid == null:
		tilex = new_tilex
		tiley = new_tiley
		distance = 1.0
		return true
	
	if not grid.is_within_grid(new_tilex, new_tiley):
		return false
	
	var tile_id = grid.tile_at(new_tilex, new_tiley)
	
	# Check for walls
	if tile_id >= 1 and tile_id <= 53:
		return false
	
	# Check for closed doors
	if tile_id >= 90 and tile_id <= 101:
		var door = _find_door_at(new_tilex, new_tiley)
		if door and not door.is_open():
			return false
	
	tilex = new_tilex
	tiley = new_tiley
	distance = 1.0
	return true

func _move_obj(move: float) -> void:
	if direction == Dir.NODIR:
		return
	
	var move_vec = DIR_VECTORS.get(direction, Vector3.ZERO) * move
	var new_pos = position + move_vec
	
	if _is_position_blocked(new_pos):
		direction = Dir.NODIR
		distance = 0.0
		return
	
	if player:
		var delta_vec = new_pos - player.position
		delta_vec.y = 0
		if delta_vec.length() < 0.5:
			return
	
	position = new_pos
	distance -= move

# ============================================================================
# FIRST SIGHTING (Based on WL_STATE.C)
# ============================================================================

func _first_sighting() -> void:
	# Switch to chase mode
	in_attack_mode = true
	first_attack = true
	direction = Dir.NODIR
	
	if player:
		var dx = player.position.x - position.x
		var dz = player.position.z - position.z
		
		if abs(dx) > abs(dz):
			direction = Dir.EAST if dx > 0 else Dir.WEST
		else:
			direction = Dir.SOUTH if dz > 0 else Dir.NORTH
	
	state = State.CHASE
	
	match enemy_type:
		EnemyType.GUARD:
			SoundManager.play_sfx("HALTSND")
		EnemyType.DOG:
			SoundManager.play_sfx("DOGBARKSND")
		EnemyType.SS:
			SoundManager.play_sfx("SCHUTZADSND")
		_:
			SoundManager.play_sfx("HALTSND")

# ============================================================================  
# DAMAGE & DEATH
# ============================================================================

func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	health -= amount
	
	if health <= 0:
		die()
	else:
		state = State.PAIN
		in_attack_mode = true
		first_attack = true

func die() -> void:
	if is_dead:
		return
	

	var points = POINT_VALUES.get(enemy_type, 100)
	GameState.give_points(points)
	
	if GameState.level_stats:
		GameState.level_stats.kill_count += 1
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	match enemy_type:
		EnemyType.GUARD:
			SoundManager.play_sfx("DEATHSCREAM1SND")
		EnemyType.DOG:
			SoundManager.play_sfx("DOGDEATHSND")
		EnemyType.SS:
			SoundManager.play_sfx("LEBENSND")
		EnemyType.OFFICER:
			SoundManager.play_sfx("NEINSOVASSND")
		_:
			SoundManager.play_sfx("DEATHSCREAM1SND")
	
	_show_death_sprite()
	
	died.emit(self)
	
	await get_tree().create_timer(3.0).timeout
	state = State.DEAD

func _show_death_sprite() -> void:
	if sprite == null:
		return
	
	# Calculate death sprite
	# Death sprite layout varies by enemy type
	var base = SPRITE_BASES.get(enemy_type, 48)
	var death_offset = 45  # Default for humanoid enemies
	
	if enemy_type == EnemyType.DOG:
		death_offset = 35
	
	var death_sprite_idx = base + death_offset
	
	var sprite_path = "%sSPR_STAT_%d.png" % [sprite_texture_folder, death_sprite_idx]
	var img = Image.load_from_file(sprite_path)
	if img != null:
		sprite.texture = ImageTexture.create_from_image(img)
	else:
		sprite.visible = false

# ============================================================================
# ANIMATION
# ============================================================================

func _update_animation(delta: float) -> void:
	anim_timer += delta
	
	if anim_timer >= 0.15:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 4
		_update_sprite()

func _update_sprite() -> void:
	if sprite == null or is_dead or player == null:
		return
	
	# Calculate sprite index based on direction and frame
	var base = SPRITE_BASES.get(enemy_type, 48)
	var sprite_idx = base

	var rotation_offset = _calc_rotate()
	
	if state == State.STAND:
		sprite_idx = base + rotation_offset
	elif state == State.CHASE or state == State.PATH:
		var walk_frame = anim_frame % 4
		if enemy_type == EnemyType.DOG:
			sprite_idx = base + (walk_frame * 8) + rotation_offset
		else:
			sprite_idx = base + 8 + (walk_frame * 8) + rotation_offset
	elif state == State.SHOOT:
		sprite_idx = base + 46 + (anim_frame % 3)
	elif state == State.PAIN:
		sprite_idx = base + 40
	
	var sprite_path = "%sSPR_STAT_%d.png" % [sprite_texture_folder, sprite_idx]
	var img = Image.load_from_file(sprite_path)
	if img != null:
		sprite.texture = ImageTexture.create_from_image(img)

func _calc_rotate() -> int:
	if player == null:
		return 0
	
	var player_angle = 0.0
	if player.has_node("Head/Camera3D"):
		var camera = player.get_node("Head/Camera3D")
		player_angle = camera.global_rotation.y
	elif player.has_node("Camera3D"):
		var camera = player.get_node("Camera3D")
		player_angle = camera.global_rotation.y
	else:
		player_angle = player.global_rotation.y
	
	var dx = position.x - player.global_position.x
	var dz = position.z - player.global_position.z
	var angle_to_enemy = atan2(dz, dx)
	
	var enemy_facing_angle = direction * (PI / 4.0)
	
	var relative_angle = (angle_to_enemy - player_angle) - enemy_facing_angle
	
	while relative_angle < 0:
		relative_angle += TAU
	while relative_angle >= TAU:
		relative_angle -= TAU
	
	var rotation = int((relative_angle + PI / 8.0) / (PI / 4.0))
	rotation = rotation % 8
	
	return rotation

# ============================================================================
# SETUP
# ============================================================================

func setup(type: EnemyType, sprite_idx: int, sprite_folder: String) -> void:
	enemy_type = type
	standing_sprite_idx = sprite_idx
	sprite_texture_folder = sprite_folder
	health = HEALTH_VALUES.get(enemy_type, 25)
	speed = SPEED_VALUES.get(enemy_type, 1.5)
