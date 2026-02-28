@tool
class_name MapLoader
extends Node3D

enum {
	NORTH, EAST, SOUTH, WEST
}

class L1Utils:
	const door_id = 50
	const door_side_id = 51

	static func is_wall(id: int) -> bool:
		return id >= 1 and id <= 53

	static func is_door(id: int) -> bool:
		return id >= 90 and id <= 95

	static func is_elevator_door(id: int) -> bool:
		return id == 100 or id == 101

	static func is_floor(id: int) -> bool:
		return id >= 106 and id <= 143

	static func get_axis(id: int) -> bool:
		return id % 2 == 0


class L2Utils:
	static func is_start(id: int) -> bool:
		return id >= 19 and id <= 22

	static func get_start_dir(id: int) -> int:
		return id - 19

	static func is_push_wall(id: int) -> bool:
		return id == 98

	static func is_static(id: int) -> bool:
		return id >= 23 and id <= 70
	
	static func is_pickup(id: int) -> bool:
		# Pickups are statics that give bonuses (based on WL_ACT1.C statinfo array)
		var static_idx = id - 23
		return static_idx in [6, 20, 21, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33]
	
	static func get_pickup_type(id: int) -> int:
		# Returns Pickup.PickupType enum value, or -1 if not a pickup
		var static_idx = id - 23
		match static_idx:
			6: return 0   # FOOD (alpo/dog food)
			24: return 0  # FOOD
			25: return 1  # HEALTH_KIT
			26: return 2  # CLIP
			27: return 4  # MACHINEGUN
			28: return 5  # CHAINGUN
			20: return 6  # GOLD_KEY
			21: return 7  # SILVER_KEY
			29: return 8  # CROSS (100 pts)
			30: return 9  # CHALICE (500 pts)
			31: return 10 # BIBLE (1000 pts)
			32: return 11 # CROWN (5000 pts)
			33: return 12 # EXTRA_LIFE
		return -1

	static func get_static_idx(id: int) -> int:
		return id - 23
	
	static func is_blocking_static(id: int) -> bool:
		var static_idx = id - 23
		return static_idx in [1, 2, 3, 7, 8, 9, 10, 12, 13, 16, 17, 23, 34, 35, 36, 37, 38, 39, 40]

	enum EnemyType { NONE, GUARD, OFFICER, SS, DOG, MUTANT, BOSS }

	static func is_enemy(id: int) -> bool:
		return get_enemy_info(id)[0] != EnemyType.NONE

	static func get_enemy_info(id: int) -> Array:
		var base_id = id
		
		# Guard standing: 108-111 (easy), 144-147 (med), 180-183 (hard)
		# Guard patrol:  112-115 (easy), 148-151 (med), 184-187 (hard)
		if id >= 180 and id <= 187:
			base_id = id - 72
		elif id >= 144 and id <= 151:
			base_id = id - 36
		if base_id >= 108 and base_id <= 111:
			return [EnemyType.GUARD, base_id - 108, false]
		if base_id >= 112 and base_id <= 115:
			return [EnemyType.GUARD, base_id - 112, true]
		
		# Officer standing: 116-119 (easy), 152-155 (med), 188-191 (hard)
		# Officer patrol:  120-123 (easy), 156-159 (med), 192-195 (hard)
		if id >= 188 and id <= 195:
			base_id = id - 72
		elif id >= 152 and id <= 159:
			base_id = id - 36
		else:
			base_id = id
		if base_id >= 116 and base_id <= 119:
			return [EnemyType.OFFICER, base_id - 116, false]
		if base_id >= 120 and base_id <= 123:
			return [EnemyType.OFFICER, base_id - 120, true]
		
		# SS standing: 126-129 (easy), 162-165 (med), 198-201 (hard)
		# SS patrol:  130-133 (easy), 166-169 (med), 202-205 (hard)
		if id >= 198 and id <= 205:
			base_id = id - 72
		elif id >= 162 and id <= 169:
			base_id = id - 36
		else:
			base_id = id
		if base_id >= 126 and base_id <= 129:
			return [EnemyType.SS, base_id - 126, false]
		if base_id >= 130 and base_id <= 133:
			return [EnemyType.SS, base_id - 130, true]
		
		# Dog standing: 134-137 (easy), 170-173 (med), 206-209 (hard)
		# Dog patrol:  138-141 (easy), 174-177 (med), 210-213 (hard)
		if id >= 206 and id <= 213:
			base_id = id - 72
		elif id >= 170 and id <= 177:
			base_id = id - 36
		else:
			base_id = id
		if base_id >= 134 and base_id <= 137:
			return [EnemyType.DOG, base_id - 134, false]
		if base_id >= 138 and base_id <= 141:
			return [EnemyType.DOG, base_id - 138, true]
		
		# Mutant standing: 216-219 (easy), 234-237 (med), 252-255 (hard)
		# Mutant patrol:  220-223 (easy), 238-241 (med), 256-259 (hard)
		if id >= 252 and id <= 259:
			base_id = id - 36
		elif id >= 234 and id <= 241:
			base_id = id - 18
		else:
			base_id = id
		if base_id >= 216 and base_id <= 219:
			return [EnemyType.MUTANT, base_id - 216, false]
		if base_id >= 220 and base_id <= 223:
			return [EnemyType.MUTANT, base_id - 220, true]
		
		# Boss enemies (special cases, no direction/patrol)
		if id == 214: return [EnemyType.BOSS, 0, false]
		if id == 197: return [EnemyType.BOSS, 0, false]
		if id == 215: return [EnemyType.BOSS, 0, false] 
		if id == 179: return [EnemyType.BOSS, 0, false]
		if id == 196: return [EnemyType.BOSS, 0, false]
		if id == 160: return [EnemyType.BOSS, 0, false]
		if id == 178: return [EnemyType.BOSS, 0, false]
		
		return [EnemyType.NONE, 0, false]
	
	static func is_dead_guard(id: int) -> bool:
		return id == 124
	
	# Check if enemy should spawn for current difficulty
	static func should_spawn_for_difficulty(id: int) -> bool:
		var diff = GameState.difficulty
		
		if id >= 180 and id <= 187: return diff >= GameState.Difficulty.HARD
		if id >= 144 and id <= 151: return diff >= GameState.Difficulty.NORMAL
		
		if id >= 188 and id <= 195: return diff >= GameState.Difficulty.HARD
		if id >= 152 and id <= 159: return diff >= GameState.Difficulty.NORMAL
		
		if id >= 198 and id <= 205: return diff >= GameState.Difficulty.HARD
		if id >= 162 and id <= 169: return diff >= GameState.Difficulty.NORMAL
		
		if id >= 206 and id <= 213: return diff >= GameState.Difficulty.HARD
		if id >= 170 and id <= 177: return diff >= GameState.Difficulty.NORMAL
		
		if id >= 252 and id <= 259: return diff >= GameState.Difficulty.HARD
		if id >= 234 and id <= 241: return diff >= GameState.Difficulty.NORMAL
		
		return true


class MapGrid:
	const _map_size: int = 64
	var _tileGrid: Array
	var _thingGrid: Array

	var map_name: String
	var ceiling_color: Color
	var floor_color: Color

	func _init(json_path: String) -> void:
		load_root(json_path)

	func load_root(json_path: String) -> void:
		var file := FileAccess.open(json_path, FileAccess.READ)
		if not file:
			push_error("Failed to open map file: ", json_path)
			return
		var content := file.get_as_text()
		file.close()
		var root = JSON.parse_string(content) as Dictionary

		_tileGrid = root["Tiles"]
		_thingGrid = root["Things"]
		assert(_tileGrid.size() == _map_size * _map_size)
		assert(_thingGrid.size() == _map_size * _map_size)

		map_name = root["Name"]

		var t: Array = root["CeilingColor"]
		ceiling_color = Color.from_rgba8(t[0], t[1], t[2])

		t = root["FloorColor"]
		floor_color = Color.from_rgba8(t[0], t[1], t[2])

	func width() -> int:
		return _map_size

	func height() -> int:
		return _map_size

	func is_within_grid(x: int, y: int) -> bool:
		if y < 0 or x < 0:
			return false
		if y >= _map_size or x >= _map_size:
			return false
		return true

	func tile_at(x: int, y: int) -> int:
		return _tileGrid[y * height() + x]

	func thing_at(x: int, y: int) -> int:
		return _thingGrid[y * height() + x]

@export var json_path : String = ""
var grid: MapGrid

var root_node: Node3D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	
	if GameState.has_saved_state():
		print("MapLoader: Restoring saved game state")
		_restore_saved_state()
		return
	
	var map_path = GameState.selected_map_path if GameState.selected_map_path != "" else json_path
	print("MapLoader: Loading map from: ", map_path)
	grid = MapGrid.new(map_path)
	print("MapLoader: Map name: ", grid.map_name) 
	
	GameState.start_level()
	
	update_tile_material()
	spawn_layer1()
	spawn_layer2()
	add_child(root_node)


func _restore_saved_state() -> void:
	var state = GameState.saved_game_state
	
	if state.has("health"):
		GameState.health = state["health"]
	if state.has("lives"):
		GameState.lives = state["lives"]
	if state.has("ammo"):
		GameState.ammo = state["ammo"]
	if state.has("score"):
		GameState.score = state["score"]
	if state.has("keys"):
		GameState.keys = state["keys"]
	if state.has("weapon"):
		GameState.weapon = state["weapon"]
	if state.has("best_weapon"):
		GameState.best_weapon = state["best_weapon"]
	if state.has("chosen_weapon"):
		GameState.chosen_weapon = state["chosen_weapon"]
	if state.has("current_map"):
		GameState.current_map = state["current_map"]
	if state.has("episode"):
		GameState.episode = state["episode"]
	if state.has("selected_map_path"):
		GameState.selected_map_path = state["selected_map_path"]
	if state.has("selected_game"):
		GameState.selected_game = state["selected_game"]
	if state.has("difficulty"):
		GameState.difficulty = state["difficulty"]
	if state.has("view_size"):
		GameState.view_size = state["view_size"]
	if state.has("next_extra_life"):
		GameState.next_extra_life = state["next_extra_life"]
	
	print("MapLoader: Restored GameState - Health: ", GameState.health, ", Lives: ", GameState.lives, ", Ammo: ", GameState.ammo)
	
	var map_path = state.get("selected_map_path", json_path)
	print("MapLoader: Restoring map from: ", map_path)
	grid = MapGrid.new(map_path)
	update_tile_material()
	spawn_layer1()
	
	spawn_layer2(true)
	add_child(root_node)
	
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if player and state.has("player_position"):
		var pos_dict = state["player_position"]
		player.global_position = Vector3(pos_dict["x"], pos_dict["y"], pos_dict["z"])
		player.rotation.y = state.get("player_rotation", 0.0)
		print("MapLoader: Player position restored to ", player.global_position)
	
	if state.has("enemies"):
		var saved_enemies = state["enemies"]
		var enemy_scene = preload("res://Enemy.tscn")
		
		for saved_enemy in saved_enemies:
			var enemy_node: Area3D = enemy_scene.instantiate()
			enemy_node.name = "Enemy_Restored_%d" % saved_enemies.find(saved_enemy)
			
			var pos_dict = saved_enemy["position"]
			enemy_node.global_position = Vector3(pos_dict["x"], pos_dict["y"], pos_dict["z"])
			enemy_node.rotation.y = saved_enemy["rotation"]
			enemy_node.enemy_type = saved_enemy["enemy_type"]
			enemy_node.sprite_texture_folder = _get_sprite_texture_folder()
			enemy_node.health = saved_enemy["health"]
			enemy_node.state = saved_enemy["state"]
			enemy_node.direction = saved_enemy["direction"]
			enemy_node.in_attack_mode = saved_enemy["in_attack_mode"]
			enemy_node.tilex = saved_enemy["tilex"]
			enemy_node.tiley = saved_enemy["tiley"]
			
			root_node.add_child(enemy_node)
		
		print("MapLoader: Restored ", saved_enemies.size(), " enemies")
	
	if state.has("corpses"):
		var saved_corpses = state["corpses"]
		var enemy_scene = preload("res://Enemy.tscn")
		
		for saved_corpse in saved_corpses:
			var corpse_node: Area3D = enemy_scene.instantiate()
			corpse_node.name = "Corpse_Restored_%d" % saved_corpses.find(saved_corpse)
			
			var pos_dict = saved_corpse["position"]
			corpse_node.global_position = Vector3(pos_dict["x"], pos_dict["y"], pos_dict["z"])
			corpse_node.rotation.y = saved_corpse["rotation"]
			corpse_node.enemy_type = saved_corpse["enemy_type"]
			corpse_node.sprite_texture_folder = _get_sprite_texture_folder()
			corpse_node.is_dead = true
			corpse_node.state = saved_corpse.get("state", 5)  # State.DEAD
			corpse_node.health = 0
			
			root_node.add_child(corpse_node)
			
			await get_tree().process_frame
			if corpse_node.has_method("_show_death_sprite"):
				corpse_node._show_death_sprite()
			if corpse_node.has_node("CollisionShape3D"):
				var col = corpse_node.get_node("CollisionShape3D")
				col.disabled = true
		
		print("MapLoader: Restored ", saved_corpses.size(), " corpses")
	
	if state.has("doors"):
		var saved_doors = state["doors"]
		var doors = get_tree().get_nodes_in_group("doors")
		
		for saved_door in saved_doors:
			var grid_x = saved_door.get("grid_x", -1)
			var grid_y = saved_door.get("grid_y", -1)
			
			if grid_x < 0 or grid_y < 0:
				continue
			
			for door in doors:
				if door and is_instance_valid(door):
					var door_x = door.get_meta("grid_x") if door.has_meta("grid_x") else -1
					var door_y = door.get_meta("grid_y") if door.has_meta("grid_y") else -1
					
					if door_x == grid_x and door_y == grid_y:
						door.current_state = saved_door.get("current_state", 0)
						door.open_ratio = saved_door.get("open_ratio", 0.0)
						door.auto_close_timer = saved_door.get("auto_close_timer", 0.0)
						if door.has_method("_apply_slide"):
							door._apply_slide()
						break
		
		print("MapLoader: Restored ", saved_doors.size(), " doors state")
	
	if state.has("pushwalls"):
		var saved_pushwalls = state["pushwalls"]
		var pushwalls = get_tree().get_nodes_in_group("pushwalls")
		
		for saved_pw in saved_pushwalls:
			var grid_x = saved_pw.get("grid_x", -1)
			var grid_y = saved_pw.get("grid_y", -1)
			
			if grid_x < 0 or grid_y < 0:
				continue
			
			for pw in pushwalls:
				if pw and is_instance_valid(pw):
					var pw_x = pw.grid_x if "grid_x" in pw else -1
					var pw_y = pw.grid_y if "grid_y" in pw else -1
					
					if pw_x == grid_x and pw_y == grid_y:
						if pw.has_method("restore_push_state"):
							pw.restore_push_state(saved_pw)
						break
		
		print("MapLoader: Restored ", saved_pushwalls.size(), " pushwalls state")
	
	print("MapLoader: Game state restored successfully")
	
	GameState.clear_saved_state()

func _get_tile_texture_folder() -> String:
	return "user://assets/%s/walls/" % GameState.selected_game

var tile_shader: Shader = preload("res://Tile.gdshader")
var tile_material: ShaderMaterial = null

func update_tile_material() -> void:
	if tile_material == null:
		tile_material = ShaderMaterial.new()
		tile_material.shader = tile_shader
	tile_material.set_shader_parameter("texture_array", _generate_texture_array(_get_tile_texture_folder()))

static func _generate_texture_array(texture_folder: String) -> Texture2DArray:
	const tex_size: int = 64

	var dir = DirAccess.open(texture_folder)
	if dir == null:
		push_error("Cannot open directory: " + texture_folder)
		return null
	
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".png"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	files.sort()
	
	var images = []

	for file in files:
		var image: Image = Image.load_from_file(texture_folder + file)

		if not image.has_mipmaps():
			image.generate_mipmaps()

		assert(image.get_width() == tex_size and image.get_height() == tex_size)
		images.append(image)

	assert(images.size() != 0)

	var result = Texture2DArray.new()
	result.create_from_images(images)
	return result

#-----------------------------------------------------
# Layer1 (Tiles) spawning
#-----------------------------------------------------
var pushwall_editor_overlay_mat: StandardMaterial3D = preload("res://PushWallEditorOverlayMat.tres")

func spawn_layer1() -> void:
	var tiles_inst := MeshInstance3D.new()
	tiles_inst.name = "Map"
	tiles_inst.mesh = get_tiles_mesh()
	tiles_inst.material_override = tile_material

	var ceiling_inst := MeshInstance3D.new()
	ceiling_inst.name = "Ceiling"
	ceiling_inst.position = Vector3(0, 0.5, 0)
	ceiling_inst.mesh = get_sector_mesh(grid.ceiling_color, true)

	var floor_inst := MeshInstance3D.new()
	floor_inst.name = "Floor"
	floor_inst.position = Vector3(0, -0.5, 0)
	floor_inst.mesh = get_sector_mesh(grid.floor_color, false)

	root_node = tiles_inst
	root_node.add_child(ceiling_inst)
	root_node.add_child(floor_inst)

	var pushwall_meshes: Dictionary = {}
	var door_ew_mesh: ArrayMesh = get_door_mesh(true)
	var door_ns_mesh: ArrayMesh = get_door_mesh(false)
	for y in range(grid.height()):
		for x in range(grid.width()):
			var tile_id = grid.tile_at(x, y)
			var thing_id = grid.thing_at(x, y)

			if L1Utils.is_door(tile_id) or L1Utils.is_elevator_door(tile_id):
				var door_axis: bool = L1Utils.get_axis(tile_id)
				var door_inst := MeshInstance3D.new()
				door_inst.set_script(load("res://doors.gd"))
				door_inst.name = "Door_%d_%d" % [x, y]
				door_inst.mesh = door_ew_mesh if door_axis else door_ns_mesh
				door_inst.material_override = tile_material
				door_inst.position = Vector3(x + 0.5, 0, y + 0.5)
				door_inst.rotation_degrees.y += -90 * float(door_axis)
				door_inst.set_meta("grid_x", x)
				door_inst.set_meta("grid_y", y)

				root_node.add_child(door_inst)

			elif L2Utils.is_push_wall(thing_id) and L1Utils.is_wall(tile_id):
				var pushwall_mesh: ArrayMesh = pushwall_meshes.get(tile_id)

				if pushwall_mesh == null:
					pushwall_mesh = get_pushwall_mesh(tile_id)
					pushwall_meshes[tile_id] = pushwall_mesh

				var pushwall_inst := MeshInstance3D.new()
				pushwall_inst.set_script(load("res://PushWall.gd"))
				pushwall_inst.name = "PushWall_%d_%d" % [x, y]
				pushwall_inst.mesh = pushwall_mesh
				pushwall_inst.material_override = tile_material

				if Engine.is_editor_hint():
					pushwall_inst.material_overlay = pushwall_editor_overlay_mat

				pushwall_inst.position = Vector3(x + 0.5, 0, y + 0.5)
				
				pushwall_inst.set("grid", grid)
				pushwall_inst.set("grid_x", x)
				pushwall_inst.set("grid_y", y)
				
				if GameState.level_stats:
					GameState.level_stats.secret_total += 1

				root_node.add_child(pushwall_inst)
				
				if GameState.level_stats:
					GameState.level_stats.secret_total += 1


func _get_sprite_texture_folder() -> String:
	return "user://assets/%s/sprites/" % GameState.selected_game

var player_scene = preload("res://Player.tscn")

func spawn_layer2(skip_enemies: bool = false) -> void:
	var added_player: bool = false
	for y in range(grid.height()):
		for x in range(grid.width()):
			var id = grid.thing_at(x, y)
			if L2Utils.is_start(id) and not added_player:
				var start_dir = L2Utils.get_start_dir(id)
				var player_node: Node3D = player_scene.instantiate()

				player_node.position = Vector3(x + 0.5, 0, y + 0.5)
				player_node.rotation_degrees.y = start_dir * -90
				root_node.add_child(player_node)

				added_player = true

			elif L2Utils.is_static(id):
				var static_idx = L2Utils.get_static_idx(id)
				
				if L2Utils.is_pickup(id):
					var pickup = Pickup.new()
					pickup.name = "Pickup_%d_%d" % [x, y]
					pickup.position = Vector3(x + 0.5, 0, y + 0.5)
					pickup.pickup_type = L2Utils.get_pickup_type(id)
					
					var collision = CollisionShape3D.new()
					var shape = BoxShape3D.new()
					shape.size = Vector3(0.5, 0.5, 0.5)
					collision.shape = shape
					pickup.add_child(collision)
					
					var sprite: Sprite3D = Sprite3D.new()
					sprite.name = "Sprite3D"
					var sprite_path = "%sSPR_STAT_%d.png" % [_get_sprite_texture_folder(), static_idx]
					var img = Image.load_from_file(sprite_path)
					if img != null:
						sprite.texture = ImageTexture.create_from_image(img)
					sprite.centered = true
					sprite.pixel_size = 0.015
					sprite.axis = 2
					sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
					sprite.transparent = true
					sprite.double_sided = false
					sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					pickup.add_child(sprite)
					pickup.sprite = sprite
					
					root_node.add_child(pickup)
					
					if GameState.level_stats:
						var p_type = L2Utils.get_pickup_type(id)
						if p_type >= 8 and p_type <= 11:
							GameState.level_stats.treasure_total += 1
				else:
					var sprite: Sprite3D = Sprite3D.new()
					sprite.position = Vector3(x + 0.5, 0, y + 0.5)
					
					var sprite_path = "%sSPR_STAT_%d.png" % [_get_sprite_texture_folder(), static_idx]
					var img = Image.load_from_file(sprite_path)
					if img != null:
						sprite.texture = ImageTexture.create_from_image(img)
					else:
						push_error("Failed to load sprite: " + sprite_path)
						continue
					
					sprite.centered = true
					sprite.pixel_size = 0.015
					sprite.axis = 2
					sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
					sprite.transparent = true
					sprite.double_sided = false
					sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					
					if L2Utils.is_blocking_static(id):
						var static_body = StaticBody3D.new()
						static_body.name = "StaticObject_%d_%d" % [x, y]
						static_body.position = Vector3(x + 0.5, 0, y + 0.5)
						static_body.add_to_group("static_objects")
						
						var collision = CollisionShape3D.new()
						var shape = CylinderShape3D.new()
						shape.radius = 0.3
						shape.height = 1.0
						collision.shape = shape
						static_body.add_child(collision)
						
						sprite.position = Vector3.ZERO
						static_body.add_child(sprite)
						root_node.add_child(static_body)
					else:
						root_node.add_child(sprite)
			
			elif L2Utils.is_enemy(id):
				if skip_enemies:
					continue
				
				if not L2Utils.should_spawn_for_difficulty(id):
					continue
				
				var enemy_info = L2Utils.get_enemy_info(id)
				var enemy_type = enemy_info[0]
				var direction = enemy_info[1]
				var is_patrol = enemy_info[2]
				
				var sprite_base_idx: int = 0
				match enemy_type:
					L2Utils.EnemyType.GUARD:
						sprite_base_idx = 48
					L2Utils.EnemyType.DOG:
						sprite_base_idx = 97 
					L2Utils.EnemyType.SS:
						sprite_base_idx = 129
					L2Utils.EnemyType.MUTANT:
						sprite_base_idx = 152
					L2Utils.EnemyType.OFFICER:
						sprite_base_idx = 177
					L2Utils.EnemyType.BOSS:
						sprite_base_idx = 48
				
				var dir_to_sprite = [0, 2, 4, 6]
				var sprite_idx = sprite_base_idx + dir_to_sprite[direction]
				
				var enemy_scene = preload("res://Enemy.tscn")
				var enemy_node: Area3D = enemy_scene.instantiate()
				enemy_node.name = "Enemy_%d_%d" % [x, y]
				enemy_node.position = Vector3(x + 0.5, 0, y + 0.5)
				enemy_node.rotation_degrees.y = direction * -90
				
				enemy_node.enemy_type = enemy_type
				enemy_node.sprite_texture_folder = _get_sprite_texture_folder()
				enemy_node.set_meta("sprite_idx", sprite_idx)
				enemy_node.set_meta("direction", direction)
				enemy_node.set_meta("is_patrol", is_patrol)
				
				var sprite: Sprite3D = enemy_node.get_node("Sprite3D")
				if sprite:
					var sprite_path = "%sSPR_STAT_%d.png" % [_get_sprite_texture_folder(), sprite_idx]
					var img = Image.load_from_file(sprite_path)
					if img != null:
						sprite.texture = ImageTexture.create_from_image(img)
					else:
						sprite_path = "%sSPR_STAT_0.png" % _get_sprite_texture_folder()
						img = Image.load_from_file(sprite_path)
						if img != null:
							sprite.texture = ImageTexture.create_from_image(img)
						push_warning("Enemy: missing sprite %d at (%d, %d)" % [sprite_idx, x, y])
				
				root_node.add_child(enemy_node)
				
				if GameState.level_stats:
					GameState.level_stats.kill_total += 1


#-----------------------------------------------------
# Floor/Ceiling (aka sector) mesh generation
#-----------------------------------------------------
func get_sector_mesh(color: Color, flip_faces: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	quad.size = Vector2(grid.width(), grid.height())
	quad.center_offset = Vector3(grid.width() * 0.5, 0, grid.height() * 0.5)
	quad.orientation = PlaneMesh.FACE_Y
	quad.flip_faces = flip_faces
	quad.material = mat

	return quad


#-----------------------------------------------------
# ArrayMesh generation utils
#-----------------------------------------------------
class TileMeshBuilder:
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	var face_count: int = 0

	# NOTE: We are repurposing the "UV" shader built-in such that:
	#		- x component is now an index to an array of actual UV vec2s:
	#			const vec2 texCoords[4] = vec2[4](
	#				vec2(0.0f, 0.0f),
	#				vec2(1.0f, 0.0f),
	#				vec2(1.0f, 1.0f),
	#				vec2(0.0f, 1.0f)
	#			);
	#		- y component is now an index to Texture2DArray layers
	func add_uvs(id: int, shaded: bool, fliph: bool = false) -> void:
		var idx = (((id - 1) * 2) + (1 * int(shaded)))
		if not fliph:
			uvs.append(Vector2(0, idx))
			uvs.append(Vector2(1, idx))
			uvs.append(Vector2(2, idx))
			uvs.append(Vector2(3, idx))
		else:
			uvs.append(Vector2(1, idx))
			uvs.append(Vector2(0, idx))
			uvs.append(Vector2(3, idx))
			uvs.append(Vector2(2, idx))

	func add_tris() -> void:
		indices.append(face_count * 4 + 0)
		indices.append(face_count * 4 + 1)
		indices.append(face_count * 4 + 2)
		indices.append(face_count * 4 + 0)
		indices.append(face_count * 4 + 2)
		indices.append(face_count * 4 + 3)
		face_count += 1

	func get_mesh() -> ArrayMesh:
		var mesh = ArrayMesh.new()
		var array = []
		array.resize(Mesh.ARRAY_MAX)
		array[Mesh.ARRAY_VERTEX] = vertices
		array[Mesh.ARRAY_INDEX] = indices
		array[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
		return mesh


#-----------------------------------------------------
# Door mesh generation (two quads)
#-----------------------------------------------------
func get_door_mesh(axis: bool) -> ArrayMesh:
	var builder := TileMeshBuilder.new()
	builder.vertices.append(Vector3(-0.5,  0.5, 0))
	builder.vertices.append(Vector3( 0.5,  0.5, 0))
	builder.vertices.append(Vector3( 0.5, -0.5, 0))
	builder.vertices.append(Vector3(-0.5, -0.5, 0))
	builder.add_tris()
	builder.add_uvs(L1Utils.door_id, axis)
	builder.vertices.append(Vector3( 0.5,  0.5, 0))
	builder.vertices.append(Vector3(-0.5,  0.5, 0))
	builder.vertices.append(Vector3(-0.5, -0.5, 0))
	builder.vertices.append(Vector3( 0.5, -0.5, 0))
	builder.add_tris()
	builder.add_uvs(L1Utils.door_id, axis, true) # door handle stays on the same side
	return builder.get_mesh()


#-----------------------------------------------------
# PushWall mesh generation (cube)
#-----------------------------------------------------
func get_pushwall_mesh(id: int) -> ArrayMesh:
	var builder := TileMeshBuilder.new()

	if Engine.is_editor_hint():
		# TOP (editor only, makes it look nicer)
		builder.vertices.append(Vector3(-0.5, 0.5, -0.5))
		builder.vertices.append(Vector3( 0.5, 0.5, -0.5))
		builder.vertices.append(Vector3( 0.5, 0.5,  0.5))
		builder.vertices.append(Vector3(-0.5, 0.5,  0.5))
		builder.add_tris()
		builder.add_uvs(id, false)

	# EAST
	builder.vertices.append(Vector3(0.5,  0.5,  0.5))
	builder.vertices.append(Vector3(0.5,  0.5, -0.5))
	builder.vertices.append(Vector3(0.5, -0.5, -0.5))
	builder.vertices.append(Vector3(0.5, -0.5,  0.5))
	builder.add_tris()
	builder.add_uvs(id, true)

	# SOUTH
	builder.vertices.append(Vector3(-0.5,  0.5, 0.5))
	builder.vertices.append(Vector3( 0.5,  0.5, 0.5))
	builder.vertices.append(Vector3( 0.5, -0.5, 0.5))
	builder.vertices.append(Vector3(-0.5, -0.5, 0.5))
	builder.add_tris()
	builder.add_uvs(id, false)

	# WEST
	builder.vertices.append(Vector3(-0.5,  0.5, -0.5))
	builder.vertices.append(Vector3(-0.5,  0.5,  0.5))
	builder.vertices.append(Vector3(-0.5, -0.5,  0.5))
	builder.vertices.append(Vector3(-0.5, -0.5, -0.5))
	builder.add_tris()
	builder.add_uvs(id, true)

	# NORTH
	builder.vertices.append(Vector3( 0.5,  0.5, -0.5))
	builder.vertices.append(Vector3(-0.5,  0.5, -0.5))
	builder.vertices.append(Vector3(-0.5, -0.5, -0.5))
	builder.vertices.append(Vector3( 0.5, -0.5, -0.5))
	builder.add_tris()
	builder.add_uvs(id, false)

	if Engine.is_editor_hint():
		# BOTTOM (editor only, makes it look nicer)
		builder.vertices.append(Vector3(-0.5, -0.5,  0.5))
		builder.vertices.append(Vector3( 0.5, -0.5,  0.5))
		builder.vertices.append(Vector3( 0.5, -0.5, -0.5))
		builder.vertices.append(Vector3(-0.5, -0.5, -0.5))
		builder.add_tris()
		builder.add_uvs(id, false)

	return builder.get_mesh()


#-----------------------------------------------------
# TileGrid mesh generation
#-----------------------------------------------------
func is_air(x: int, y: int) -> bool:
	if not grid.is_within_grid(x, y):
		return true
	return not L1Utils.is_wall(grid.tile_at(x, y)) or L2Utils.is_push_wall(grid.thing_at(x, y))

enum {
	FLAG_NORTH = 1 << NORTH,
	FLAG_EAST  = 1 << EAST,
	FLAG_SOUTH = 1 << SOUTH,
	FLAG_WEST  = 1 << WEST
}

func is_adjecent_to_door(x: int, y: int) -> int:
	if not grid.is_within_grid(x, y):
		return 0

	# NORTH, EAST, SOUTH, WEST
	var adj_arr = [
		Vector2i(x - 1, y),
		Vector2i(x, y - 1),
		Vector2i(x + 1, y),
		Vector2i(x, y + 1)
	]

	var flags: int = 0
	for i in range(adj_arr.size()):
		var adj = adj_arr[i]

		if not grid.is_within_grid(adj.x, adj.y):
			continue

		var id = grid.tile_at(adj.x, adj.y)
		
		if L1Utils.is_door(id) or L1Utils.is_elevator_door(id):
			var door_axis: bool = L1Utils.get_axis(id)
			var adj_axis: bool = i % 2 == 1
			if door_axis == adj_axis:
				flags |= 1 << i

	return flags


func get_tiles_mesh() -> ArrayMesh:
	var builder := TileMeshBuilder.new()

	for y in range(grid.height()):
		for x in range(grid.width()):
			if is_air(x, y):
				continue

			var id = grid.tile_at(x, y)
			var pos: Vector3 = Vector3(x + 0.5, 0, y + 0.5)

			var door_sides = is_adjecent_to_door(x, y)

			if Engine.is_editor_hint():
				# TOP (editor only, makes it look nicer)
				builder.vertices.append(pos + Vector3(-0.5, 0.5, -0.5))
				builder.vertices.append(pos + Vector3( 0.5, 0.5, -0.5))
				builder.vertices.append(pos + Vector3( 0.5, 0.5,  0.5))
				builder.vertices.append(pos + Vector3(-0.5, 0.5,  0.5))
				builder.add_tris()
				builder.add_uvs(id, false)

			if is_air(x + 1, y):
				# EAST
				builder.vertices.append(pos + Vector3(0.5,  0.5,  0.5))
				builder.vertices.append(pos + Vector3(0.5,  0.5, -0.5))
				builder.vertices.append(pos + Vector3(0.5, -0.5, -0.5))
				builder.vertices.append(pos + Vector3(0.5, -0.5,  0.5))
				builder.add_tris()
				builder.add_uvs(L1Utils.door_side_id if door_sides & FLAG_SOUTH else id, true)

			if is_air(x, y + 1):
				# SOUTH
				builder.vertices.append(pos + Vector3(-0.5,  0.5, 0.5))
				builder.vertices.append(pos + Vector3( 0.5,  0.5, 0.5))
				builder.vertices.append(pos + Vector3( 0.5, -0.5, 0.5))
				builder.vertices.append(pos + Vector3(-0.5, -0.5, 0.5))
				builder.add_tris()
				builder.add_uvs(L1Utils.door_side_id if door_sides & FLAG_WEST else id, false)

			if is_air(x - 1, y):
				# WEST
				builder.vertices.append(pos + Vector3(-0.5,  0.5, -0.5))
				builder.vertices.append(pos + Vector3(-0.5,  0.5,  0.5))
				builder.vertices.append(pos + Vector3(-0.5, -0.5,  0.5))
				builder.vertices.append(pos + Vector3(-0.5, -0.5, -0.5))
				builder.add_tris()
				builder.add_uvs(L1Utils.door_side_id if door_sides & FLAG_NORTH else id, true)

			if is_air(x, y - 1):
				# NORTH
				builder.vertices.append(pos + Vector3( 0.5,  0.5, -0.5))
				builder.vertices.append(pos + Vector3(-0.5,  0.5, -0.5))
				builder.vertices.append(pos + Vector3(-0.5, -0.5, -0.5))
				builder.vertices.append(pos + Vector3( 0.5, -0.5, -0.5))
				builder.add_tris()
				builder.add_uvs(L1Utils.door_side_id if door_sides & FLAG_EAST else id, false)

			if Engine.is_editor_hint():
				# BOTTOM (editor only, makes it look nicer)
				builder.vertices.append(pos + Vector3(-0.5, -0.5,  0.5))
				builder.vertices.append(pos + Vector3( 0.5, -0.5,  0.5))
				builder.vertices.append(pos + Vector3( 0.5, -0.5, -0.5))
				builder.vertices.append(pos + Vector3(-0.5, -0.5, -0.5))
				builder.add_tris()
				builder.add_uvs(id, false)

	return builder.get_mesh()
