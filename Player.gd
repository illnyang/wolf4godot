class_name Player
extends CharacterBody3D

@export var map_loader: MapLoader    
@export var radius: float = 0.28
@export var skin: float = 0.001
@onready var weapon_anim: AnimatedSprite2D = $CanvasLayer/WeponUI/AnimatedSprite2D
@export var sprite_texture_folder: String:
	get: return GameState.get_sprites_path()
@onready var weapon_manager = $CanvasLayer/WeaponUI/AnimatedSprite2D
const SPEED := 7.0
const TURN_SPEED := 1.5
const FIRE_RATES = {
	GameState.Weapon.KNIFE: 0.5,
	GameState.Weapon.PISTOL: 0.2,
	GameState.Weapon.MACHINEGUN: 0.125,
	GameState.Weapon.CHAINGUN: 0.1,
}

var fire_cooldown: float = 0.0
var is_firing: bool = false
var current_weapon_name: String = "pistol"
var grid = null
var tilex: int = 0
var tiley: int = 0

@onready var cam: Camera3D = $Camera3D
signal hp_changed(current_hp: int, max_hp: int)
signal died
@export var max_hp: int = 100
var current_hp: int

func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	emit_signal("hp_changed", current_hp, max_hp)
	if weapon_anim.has_method("load_external_weapon_animations"):
		weapon_anim.load_external_weapon_animations()
	weapon_anim.animation_finished.connect(_on_weapon_animation_finished)
	
	GameState.player_died.connect(die)
	
	if map_loader == null:
		var p = get_parent()
		while p:
			if p is MapLoader:
				map_loader = p
				break
			p = p.get_parent()

	if map_loader:
		grid = map_loader.grid
	else:
		push_warning("Player: MapLoader not found; collisions disabled.")
	
	_update_tile_indices()
	_update_weapon_visuals()
	
func _physics_process(delta: float) -> void:
	if fire_cooldown > 0:
		fire_cooldown -= delta
	
	if Input.is_action_pressed("shoot"):
		_try_shoot()
	
	if Input.is_action_pressed("turn_right"):
		rotate_y(-TURN_SPEED * delta)
	elif Input.is_action_pressed("turn_left"):
		rotate_y(TURN_SPEED * delta)
	if Input.is_action_just_pressed("action") or Input.is_action_just_pressed("ui_select"): 
		_try_interact()
	var move_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"): 
		move_dir -= cam.global_transform.basis.z
	if Input.is_action_pressed("move_backward"): 
		move_dir += cam.global_transform.basis.z

	
	move_dir.y = 0
	if move_dir.length_squared() > 0.000001:
		move_dir = move_dir.normalized()

	_attempt_move(move_dir * SPEED * delta)

func _try_shoot() -> void:
	if fire_cooldown > 0:
		return
	var weapon = GameState.weapon
	_update_weapon_visuals()
	if weapon != GameState.Weapon.KNIFE:
		if not GameState.use_ammo():
			return
	
	fire_cooldown = FIRE_RATES.get(weapon, 0.2)
	if weapon_anim.has_method("play_shoot"):
		weapon_anim.play_shoot(current_weapon_name)
	
	match weapon:
		GameState.Weapon.KNIFE:
			pass
		GameState.Weapon.PISTOL:
			SoundManager.play_sfx("ATKPISTOLSND")
		GameState.Weapon.MACHINEGUN:
			SoundManager.play_sfx("ATKMACHINEGUNSND")
		GameState.Weapon.CHAINGUN:
			SoundManager.play_sfx("ATKGATLINGSND")
	
	var damage = randi_range(15, 30)
	_perform_hitscan(damage, weapon)

func _on_weapon_animation_finished() -> void:
	if "_shoot" in weapon_anim.animation:
		if weapon_anim.has_method("play_idle"):
			weapon_anim.play_idle(current_weapon_name)

func _update_weapon_visual_names(weapon_type) -> void:
	match weapon_type:
		GameState.Weapon.KNIFE: current_weapon_name = "knife"
		GameState.Weapon.PISTOL: current_weapon_name = "pistol"
		GameState.Weapon.MACHINEGUN: current_weapon_name = "machinegun"
		GameState.Weapon.CHAINGUN: current_weapon_name = "chaingun"
		
func _update_weapon_visuals() -> void:
	_update_weapon_visual_names(GameState.weapon)
	if weapon_anim.has_method("play_idle"):
		weapon_anim.play_idle(current_weapon_name)
	if not weapon_anim.is_playing() or not weapon_anim.animation.ends_with("_shoot"):
		weapon_anim.play(current_weapon_name + "_idle")

func _try_interact() -> void:
	if not map_loader or not grid: return
	
	var forward = -cam.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var target_pos = position + (forward * 1.2)
	var tx = int(floor(target_pos.x))
	var tz = int(floor(target_pos.z))
	
	var player_tx = int(floor(position.x))
	var player_tz = int(floor(position.z))
	if _is_inside_elevator(player_tx, player_tz):
		var target_tile = grid.tile_at(tx, tz)
		if map_loader.L1Utils.is_wall(target_tile):
			_trigger_level_complete()
			return
	
	var door_at_player = _find_door_at_tile(player_tx, player_tz)
	if door_at_player:
		door_at_player.interact()
		return
	
	var pushwall_node = _find_pushwall_at_tile(tx, tz)
	if pushwall_node:
		pushwall_node.push(forward)
		return
	
	var door_node = _find_door_at_tile(tx, tz)
	if door_node:
		door_node.interact()

func _is_inside_elevator(px: int, pz: int) -> bool:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var check_tile = grid.tile_at(px + dx, pz + dz)
			if map_loader.L1Utils.is_elevator_door(check_tile):
				return true
	return false

func _trigger_level_complete() -> void:
	SoundManager.play_sfx("LEVELDONESND")
	
	var level_complete_script = preload("res://LevelComplete.gd")
	var level_complete = CanvasLayer.new()
	level_complete.set_script(level_complete_script)
	get_tree().root.add_child(level_complete)
	
	get_tree().paused = true

func _find_door_at_tile(tx: int, tz: int) -> Node3D:
	var all_doors = get_tree().get_nodes_in_group("doors")
	for door in all_doors:
		var d_pos = door.get("start_pos")
		if d_pos == null: d_pos = door.position
		
		if int(floor(d_pos.x)) == tx and int(floor(d_pos.z)) == tz:
			return door
	return null

func _find_pushwall_at_tile(tx: int, tz: int) -> Node3D:
	var all_pushwalls = get_tree().get_nodes_in_group("pushwalls")
	for pushwall in all_pushwalls:
		var pw_pos = pushwall.position
		var pw_x = int(floor(pw_pos.x))
		var pw_z = int(floor(pw_pos.z))
		
		if pw_x == tx and pw_z == tz:
			return pushwall
	return null

func _attempt_move(offset_3d: Vector3) -> void:
	if grid == null:
		position += offset_3d
		return

	var new_x = position.x + offset_3d.x
	var new_z = position.z + offset_3d.z

	var all_pushwalls = get_tree().get_nodes_in_group("pushwalls")
	for pushwall in all_pushwalls:
		if pushwall and is_instance_valid(pushwall):
			var pw_pos = pushwall.position
			var closest_x = clamp(new_x, pw_pos.x - 0.5, pw_pos.x + 0.5)
			var closest_z = clamp(new_z, pw_pos.z - 0.5, pw_pos.z + 0.5)
			var dx = new_x - closest_x
			var dz = new_z - closest_z
			var dist = sqrt(dx*dx + dz*dz)
			
			if dist < radius:
				var penetration = radius - dist + skin
				if dist > 0:
					new_x = new_x + (dx / dist) * penetration
					new_z = new_z + (dz / dist) * penetration
				else:
					if offset_3d.length() > 0:
						var push_dir = -offset_3d.normalized()
						new_x = pw_pos.x + push_dir.x * (radius + skin)
						new_z = pw_pos.z + push_dir.z * (radius + skin)
	
	var all_static_objects = get_tree().get_nodes_in_group("static_objects")
	for static_obj in all_static_objects:
		if static_obj and is_instance_valid(static_obj):
			var obj_pos = static_obj.position
			var dx = new_x - obj_pos.x
			var dz = new_z - obj_pos.z
			var dist = sqrt(dx*dx + dz*dz)
			var combined_radius = radius + 0.3
			
			if dist < combined_radius:
				var penetration = combined_radius - dist + skin
				if dist > 0:
					new_x = new_x + (dx / dist) * penetration
					new_z = new_z + (dz / dist) * penetration
				else:
					if offset_3d.length() > 0:
						var push_dir = -offset_3d.normalized()
						new_x = obj_pos.x + push_dir.x * combined_radius
						new_z = obj_pos.z + push_dir.z * combined_radius

	var min_tx = int(floor(new_x - radius))
	var max_tx = int(floor(new_x + radius))
	var min_tz = int(floor(new_z - radius))
	var max_tz = int(floor(new_z + radius))

	for tz in range(min_tz, max_tz + 1):
		for tx in range(min_tx, max_tx + 1):
			if tx < 0 or tx >= grid.width() or tz < 0 or tz >= grid.height(): continue
			
			var tile_id = grid.tile_at(tx, tz)
			var thing_id = grid.thing_at(tx, tz)
			var is_solid = false
			
			var pushwall = _find_pushwall_at_tile(tx, tz)
			if pushwall and pushwall.has_method("is_blocking"):
				is_solid = pushwall.is_blocking()
			elif not map_loader.L2Utils.is_push_wall(thing_id) and map_loader.L1Utils.is_wall(tile_id):
				is_solid = true
			elif map_loader.L1Utils.is_door(tile_id) or map_loader.L1Utils.is_elevator_door(tile_id):
				var door = _find_door_at_tile(tx, tz)
				if door:
					is_solid = not door.is_open()
				else:
					is_solid = true

			if is_solid:
				_resolve_box_collision(tx, tz, new_x, new_z)
				new_x = position.x
				new_z = position.z

	position.x = new_x
	position.z = new_z

func _resolve_box_collision(tx: int, tz: int, target_x: float, target_z: float) -> void:
	var closest_x = clamp(target_x, tx, tx + 1)
	var closest_z = clamp(target_z, tz, tz + 1)
	var dx = target_x - closest_x
	var dz = target_z - closest_z
	var dist = sqrt(dx*dx + dz*dz)

	if dist < radius:
		var penetration = radius - dist + skin
		if dist > 0:
			position.x = target_x + (dx / dist) * penetration
			position.z = target_z + (dz / dist) * penetration
		else:
			var tile_center_x = tx + 0.5
			var tile_center_z = tz + 0.5
			var away_x = position.x - tile_center_x
			var away_z = position.z - tile_center_z
			var away_dist = sqrt(away_x * away_x + away_z * away_z)
			
			if away_dist > 0.01:
				position.x = tile_center_x + (away_x / away_dist) * (radius + skin)
				position.z = tile_center_z + (away_z / away_dist) * (radius + skin)
			else:
				position.x = tile_center_x + radius + skin
				position.z = tile_center_z

func _update_tile_indices() -> void:
	tilex = int(floor(position.x))
	tiley = int(floor(position.z))
func take_damage(amount: int, attacker: Node3D = null) -> void:
	GameState.take_damage(amount, attacker)

func heal(amount: int) -> void:
	GameState.heal(amount)
	
func die() -> void:
	print("Player died")
	emit_signal("died")
	set_physics_process(false)
	set_process_input(false)

func sign(v: float) -> int:
	return -1 if v < 0 else 1

func _perform_hitscan(damage: int, weapon: GameState.Weapon) -> void:
	var space_state = get_world_3d().direct_space_state
	
	var from = cam.global_position
	var forward = -cam.global_transform.basis.z
	
	var range = 1.5 if weapon == GameState.Weapon.KNIFE else 100.0
	var to = from + forward * range
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider:
		var hit_position = result.position
		if not _check_shot_line(from, hit_position):
			return
		
		if result.collider.is_in_group("enemies"):
			if result.collider.has_method("take_damage"):
				result.collider.take_damage(damage)
	else:
		if not _check_shot_line(from, to):
			return
		if not _check_shot_line(from, to):
			return

func _check_shot_line(from: Vector3, to: Vector3) -> bool:
	"""Check if shot line is blocked by walls or closed doors"""
	if not grid or not map_loader:
		return true
	
	# Bresenham's line algorithm to check tiles between from and to
	var x0 = int(floor(from.x))
	var z0 = int(floor(from.z))
	var x1 = int(floor(to.x))
	var z1 = int(floor(to.z))
	
	var dx = abs(x1 - x0)
	var dz = abs(z1 - z0)
	var sx = 1 if x0 < x1 else -1
	var sz = 1 if z0 < z1 else -1
	var err = dx - dz
	
	var x = x0
	var z = z0
	
	while true:
		if not (x == x0 and z == z0):
			if not grid.is_within_grid(x, z):
				return false
			
			var tile_id = grid.tile_at(x, z)
			var thing_id = grid.thing_at(x, z)
			var is_air = map_loader.is_air(x, z)
			
			if not is_air:
				if thing_id == 98:
					var pushwall = _find_pushwall_at_tile(x, z)
					if not pushwall:
						pass
					else:
						return false
				else:
					return false
			
			if tile_id >= 90 and tile_id <= 101:
				var door = _find_door_at_tile(x, z)
				if door:
					var open_ratio = door.get("open_ratio")
					if open_ratio != null and open_ratio < 0.3:
						return false
		
		if x == x1 and z == z1:
			break
		
		var e2 = 2 * err
		if e2 > -dz:
			err -= dz
			x += sx
		if e2 < dx:
			err += dx
			z += sz
	
	return true

func _start_benchmark():
	var PerfMonitor = preload("res://tests/performance_monitor.gd")
	var perf = PerfMonitor.new()
	add_child(perf)
	perf.start_benchmark(10.0)
	
