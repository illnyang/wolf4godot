class_name Player
extends Node3D

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


func _ready() -> void:
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
	# rotation (yaw)
	if Input.is_action_pressed("turn_right"):
		rotate_y(-TURN_SPEED * delta)
	elif Input.is_action_pressed("turn_left"):
		rotate_y(TURN_SPEED * delta)

	# movement in XZ plane based on camera orientation
	var move_dir := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		move_dir -= cam.global_transform.basis.z
	if Input.is_action_pressed("move_backward"):
		move_dir += cam.global_transform.basis.z
	if Input.is_action_pressed("ui_right"):
		move_dir += cam.global_transform.basis.x
	if Input.is_action_pressed("ui_left"):
		move_dir -= cam.global_transform.basis.x

	# flatten to XZ, normalize if needed
	move_dir.y = 0
	if move_dir.length_squared() > 0.000001:
		move_dir = move_dir.normalized()

	var displacement := move_dir * SPEED * delta

	var vertical_delta := 0.0
	if Input.is_action_pressed("fly_up"):
		vertical_delta += SPEED * delta
	if Input.is_action_pressed("fly_down"):
		vertical_delta -= SPEED * delta

	# attempt movement with collision resolution
	_attempt_move(displacement, vertical_delta)

	_update_tile_indices()


func _attempt_move(offset_3d: Vector3, vertical_delta: float) -> void:
	# apply vertical movement directly (no collisions vertically)
	position.y += vertical_delta

	# if no grid available, simply move
	if grid == null:
		position += offset_3d
		return

	var new_pos := position + offset_3d
	var new_x := new_pos.x
	var new_z := new_pos.z

	# figure tile search bounds
	var min_tx := int(floor(new_x - radius))
	var max_tx := int(floor(new_x + radius))
	var min_tz := int(floor(new_z - radius))
	var max_tz := int(floor(new_z + radius))

	min_tx = max(min_tx, 0)
	min_tz = max(min_tz, 0)
	max_tx = min(max_tx, grid.width() - 1)
	max_tz = min(max_tz, grid.height() - 1)

	for tz in range(min_tz, max_tz + 1):
		for tx in range(min_tx, max_tx + 1):
			var tile_id = grid.tile_at(tx, tz)

			if map_loader.L1Utils.is_wall(tile_id):
				var box_min_x = tx
				var box_max_x = tx + 1
				var box_min_z = tz
				var box_max_z = tz + 1

				var closest_x = clamp(new_x, box_min_x, box_max_x)
				var closest_z = clamp(new_z, box_min_z, box_max_z)
				var dx = new_x - closest_x
				var dz = new_z - closest_z
				var dist_sq = dx * dx + dz * dz

				if dist_sq < (radius * radius):
					var dist = sqrt(dist_sq) if dist_sq > 0.0 else 0.0
					var push_vec_x := 0.0
					var push_vec_z := 0.0
					if dist > 0.000001:
						var penetration = radius - dist + skin
						push_vec_x = (dx / dist) * penetration
						push_vec_z = (dz / dist) * penetration
					else:
						var center_x = tx + 0.5
						var center_z = tz + 0.5
						if abs(new_x - center_x) > abs(new_z - center_z):
							push_vec_x = (radius + skin) * sign(new_x - center_x)
						else:
							push_vec_z = (radius + skin) * sign(new_z - center_z)

					new_x += push_vec_x
					new_z += push_vec_z

	position.x = new_x
	position.z = new_z


func _update_tile_indices() -> void:
	tilex = int(floor(position.x))
	tiley = int(floor(position.z))


func sign(v: float) -> int:
	return -1 if v < 0 else 1
