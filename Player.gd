class_name Player
extends CharacterBody3D

@export var map_loader: MapLoader    
@export var radius: float = 0.28
@export var skin: float = 0.001

const SPEED := 7.0
const TURN_SPEED := 1.5
# Runtime
var grid = null
var tilex: int = 0
var tiley: int = 0

@onready var cam: Camera3D = $Camera3D
signal hp_changed(current_hp: int, max_hp: int)
signal died
@export var max_hp: int = 100
var current_hp: int

func _ready() -> void:
	current_hp = max_hp
	emit_signal("hp_changed", current_hp, max_hp)
	
	# If not assigned in the editor, find MapLoader parent automatically
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

func _physics_process(delta: float) -> void:
	# Obrót
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
	if Input.is_action_pressed("ui_right"): 
		move_dir += cam.global_transform.basis.x
	if Input.is_action_pressed("ui_left"): 
		move_dir -= cam.global_transform.basis.x
	
	move_dir.y = 0
	if move_dir.length_squared() > 0.000001:
		move_dir = move_dir.normalized()

	_attempt_move(move_dir * SPEED * delta)

func _try_interact() -> void:
	if not map_loader or not grid: return
	
	var forward = -cam.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var target_pos = position + (forward * 1.2)
	var tx = int(floor(target_pos.x))
	var tz = int(floor(target_pos.z))
	
	var door_node = _find_door_at_tile(tx, tz)
	if door_node:
		door_node.interact()

func _find_door_at_tile(tx: int, tz: int) -> Node3D:
	var all_doors = get_tree().get_nodes_in_group("doors")
	for door in all_doors:
		var d_pos = door.get("start_pos")
		if d_pos == null: d_pos = door.position
		
		if int(floor(d_pos.x)) == tx and int(floor(d_pos.z)) == tz:
			return door
	return null

func _attempt_move(offset_3d: Vector3) -> void:
	if grid == null:
		position += offset_3d
		return

	var new_x = position.x + offset_3d.x
	var new_z = position.z + offset_3d.z

	var min_tx = int(floor(new_x - radius))
	var max_tx = int(floor(new_x + radius))
	var min_tz = int(floor(new_z - radius))
	var max_tz = int(floor(new_z + radius))

	for tz in range(min_tz, max_tz + 1):
		for tx in range(min_tx, max_tx + 1):
			if tx < 0 or tx >= grid.width() or tz < 0 or tz >= grid.height(): continue
			
			var tile_id = grid.tile_at(tx, tz)
			var is_solid = false
			
			if map_loader.L1Utils.is_wall(tile_id):
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
			position.x += radius + skin

func _update_tile_indices() -> void:
	tilex = int(floor(position.x))
	tiley = int(floor(position.z))
func take_damage(amount: int) -> void:
	GameState.take_damage(amount)

func heal(amount: int) -> void:
	GameState.heal(amount)
	
func die() -> void:
	print("Player died")
	emit_signal("died")
	queue_free() # or respawn later

func sign(v: float) -> int:
	return -1 if v < 0 else 1
