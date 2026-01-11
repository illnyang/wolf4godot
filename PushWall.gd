extends MeshInstance3D

# PushWall - Secret sliding walls (like in original Wolf3D)
# When activated by player, slides in one direction to reveal secret area

enum State { IDLE, PUSHING }
var current_state = State.IDLE

var push_speed: float = 0.5  # Slower than doors (original: 256 frames to move 2 tiles)
var push_distance: float = 0.0  # How far pushed (0.0 to 2.0 tiles)
var push_direction: Vector3 = Vector3.ZERO
var start_pos: Vector3 = Vector3.ZERO
var grid = null

# Grid position for collision tracking
var grid_x: int = 0
var grid_y: int = 0

func _ready() -> void:
	add_to_group("pushwalls")
	start_pos = position

func _process(delta: float) -> void:
	if current_state == State.PUSHING:
		push_distance += delta * push_speed
		position = start_pos + (push_direction * push_distance)
		
		# Update grid position for collision detection
		var current_tile_x = int(floor(position.x))
		var current_tile_z = int(floor(position.z))
		
		# After pushing 2 tiles, stop
		if push_distance >= 2.0:
			current_state = State.IDLE
			push_distance = 2.0
			position = start_pos + (push_direction * 2.0)
			# Update final grid position
			_update_grid_collision(current_tile_x, current_tile_z)

func push(direction: Vector3) -> bool:
	if current_state == State.PUSHING:
		return false
	
	# Check if space ahead is clear
	var check_pos1 = start_pos + direction
	var check_x1 = int(floor(check_pos1.x))
	var check_z1 = int(floor(check_pos1.z))
	
	var check_pos2 = start_pos + direction * 2.0
	var check_x2 = int(floor(check_pos2.x))
	var check_z2 = int(floor(check_pos2.z))
	
	if grid != null:
		# Check if both tiles ahead are walkable
		if not _is_tile_walkable(check_x1, check_z1):
			SoundManager.play_sound(SoundManager.SoundID.NOWAYSND)
			return false
		
		if not _is_tile_walkable(check_x2, check_z2):
			SoundManager.play_sound(SoundManager.SoundID.NOWAYSND)
			return false
	
	# Start pushing
	current_state = State.PUSHING
	push_direction = direction.normalized()
	
	# Clear current tile collision
	if grid != null and grid.has_method("clear_tile_collision"):
		grid.call("clear_tile_collision", grid_x, grid_y)
	
	# Increment secret count
	GameState.increment_secrets_found()
	
	# Play push sound
	SoundManager.play_sound(SoundManager.SoundID.PUSHWALLSND)
	
	return true

func _is_tile_walkable(tx: int, tz: int) -> bool:
	if not grid.is_within_grid(tx, tz):
		return false
	
	var tile_id = grid.tile_at(tx, tz)
	
	# Wall tiles block movement
	if tile_id >= 1 and tile_id <= 53:
		return false
	
	# Door tiles block movement
	if tile_id >= 90 and tile_id <= 101:
		return false
	
	# Check for other actors
	var actors = get_tree().get_nodes_in_group("enemies")
	for actor in actors:
		var actor_x = int(floor(actor.position.x))
		var actor_z = int(floor(actor.position.z))
		if actor_x == tx and actor_z == tz:
			return false
	
	return true

func _update_grid_collision(new_x: int, new_z: int) -> void:
	if grid != null and grid.has_method("set_tile_collision"):
		# Clear old position
		grid.call("clear_tile_collision", grid_x, grid_y)
		# Set new position
		grid.call("set_tile_collision", new_x, new_z, true)
		grid_x = new_x
		grid_y = new_z

func is_blocking() -> bool:
	# Pushwall always blocks - collision is checked at its current position
	return true

# For save/load system
func get_push_state() -> Dictionary:
	return {
		"grid_x": grid_x,
		"grid_y": grid_y,
		"state": current_state,
		"push_distance": push_distance,
		"push_direction": {"x": push_direction.x, "y": push_direction.y, "z": push_direction.z},
		"position": {"x": position.x, "y": position.y, "z": position.z}
	}

func restore_push_state(state: Dictionary) -> void:
	current_state = state.get("state", State.IDLE)
	push_distance = state.get("push_distance", 0.0)
	
	var dir_dict = state.get("push_direction", {"x": 0, "y": 0, "z": 0})
	push_direction = Vector3(dir_dict["x"], dir_dict["y"], dir_dict["z"])
	
	var pos_dict = state.get("position", {"x": position.x, "y": position.y, "z": position.z})
	position = Vector3(pos_dict["x"], pos_dict["y"], pos_dict["z"])
	
	grid_x = state.get("grid_x", grid_x)
	grid_y = state.get("grid_y", grid_y)
