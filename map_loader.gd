extends Node3D
## Simple Wolf 3‑D map loader that skins each wall instance
## with the matching wall##.png texture.

@export var wall_scene      : PackedScene            # your current wall scene
@export var wall_shader     : Shader
@export var json_path       : String = "res://assets/maps/map_00_Wolf1 Map1.json"
@export var tile_size       : float  = 1.0           # 1 Godot unit == 1 tile
@export var texture_folder  : String = "res://assets/walls/"


# -------------------------------------------------------------------
# Layer 1 (Walls/Floors) ID helpers
# -------------------------------------------------------------------
const door_side_id = 51

func _l1_is_wall(id: int) -> bool:
	return id >= 1 and id <= 53

func _l1_is_door(id: int) -> bool:
	return id >= 90 and id <= 95

func _l1_is_elevator_door(id: int) -> bool:
	return id == 100 or id == 101

func _l1_is_floor(id: int) -> bool:
	return id >= 106 and id <= 143


# -------------------------------------------------------------------
# Cached materials - each for every combination of textures on 4 faces
# -------------------------------------------------------------------
var _mat_cache: Dictionary = {}          # int → ShaderMaterial


# -------------------------------------------------------------------
# Main entry
# -------------------------------------------------------------------
func _ready() -> void:
	print("Wolf map loader running —", json_path)
	var grid: Array = _load_grid()
	_spawn_walls(grid)


# -------------------------------------------------------------------
# JSON parsing (expects layer‑0 data as 2‑D array)
# -------------------------------------------------------------------
func _load_grid() -> Array:
	var file := FileAccess.open(json_path, FileAccess.READ)
	var content := file.get_as_text()
	var data: Array = JSON.parse_string(content) as Array


	# If your exporter wrapped the grid in a “layers” array, adjust here.
	# This example assumes data IS the 2‑D int array already.
	return data


# -------------------------------------------------------------------
# Walk the grid and instantiate walls
# TODO: BoxMesh3D includes top & bottom faces, which is wasteful.
#       We only need 4 faces - front, back, left & right.
# TODO: ideally, we should be able to generate entire map geometry in one go
#       by using SurfaceTool and some shader/UV mathemagics, perhaps with greedy meshing
# NOTE: In some edge-cases two-pass nature of this function will generate unused materials.
# -------------------------------------------------------------------
func _spawn_walls(grid: Array) -> void:
	var _walls: Array = []

	# Spawn regular walls
	for y in range(grid.size()):
		_walls.append([])
		_walls[y].resize(grid[y].size())
		for x in range(grid[y].size()):
			var id := int(grid[y][x])
			if _l1_is_wall(id):
				var wall := wall_scene.instantiate()
				wall.position = Vector3(x * tile_size, 0, y * tile_size)

				var mesh = _find_mesh(wall)
				mesh.material_override = _get_cached_material(id, id, id, id)

				_walls[y][x] = wall
				add_child(wall)

	# Apply side door texture to walls (hence the second pass) which are adjacent to doors
	# TODO: Check for invalid door placement at grid boundaries
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var id := int(grid[y][x])

			var elevator: bool = _l1_is_elevator_door(id)
			if _l1_is_door(id) or elevator:
				# We assume EW/NS ids alternate here (holds for WL6)
				var ew: bool = id % 2 == 0

				# TODO: id should be included in Wall node itself
				var id_n := int(grid[y][x - 1])
				var id_e := int(grid[y - 1][x])
				var id_s := int(grid[y][x + 1])
				var id_w := int(grid[y + 1][x])

				var mesh_n := _find_mesh(_walls[y][x - 1])
				var mesh_e := _find_mesh(_walls[y - 1][x])
				var mesh_s := _find_mesh(_walls[y][x + 1])
				var mesh_w := _find_mesh(_walls[y + 1][x])

				# Make sure adjacent walls exist and set side door texture
				if ew:
					assert(_l1_is_wall(id_e) and _l1_is_wall(id_w))
					mesh_e.material_override = _get_cached_material(door_side_id, id_e, id_e, id_e)
					mesh_w.material_override = _get_cached_material(door_side_id, id_w, id_w, id_w)
				else:
					assert(_l1_is_wall(id_n) and _l1_is_wall(id_s))
					mesh_n.material_override = _get_cached_material(id_n, id_n, id_n, door_side_id)
					mesh_s.material_override = _get_cached_material(id_s, id_n, id_s, door_side_id)

				# Make sure door is accessible from at least one side
				# NOTE: This assumes floor tiles must be used!
				if ew:
					assert(_l1_is_floor(id_n) or _l1_is_floor(id_s))
				else:
					assert(_l1_is_floor(id_e) or _l1_is_floor(id_w))

# ------------------------------------------------------------
#  helper: recursively find the first MeshInstance3D in a node
#  TODO: this is neither idiomatic GDScript nor optimal
#  https://www.reddit.com/r/godot/comments/18hgna7/best_way_to_reference_a_node/
#  https://www.reddit.com/r/godot/comments/13pm5o5/instantiating_a_scene_with_constructor_parameters/
# ------------------------------------------------------------
func _find_mesh(n: Node) -> MeshInstance3D:
	if n == null:
		return null
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _find_mesh(c)
		if m:
			return m
	return null


# ------------------------------------------------------------
#  Build/fetch material given textures for each face
# ------------------------------------------------------------
func _get_cached_material(id_n: int, id_e: int, id_s: int, id_w: int) -> ShaderMaterial:
	# Unique integer for every possible combination
	var combined_id: int = (id_n << 24) | (id_e << 16) | (id_s << 8) | id_w

	if _mat_cache.has(combined_id):
		return _mat_cache[combined_id]

	var tex_n := "%s%d.png" % [texture_folder, id_n - 1]
	var tex_e := "%s%d_shaded.png" % [texture_folder, id_e - 1]
	var tex_s := "%s%d.png" % [texture_folder, id_s - 1]
	var tex_w := "%s%d_shaded.png" % [texture_folder, id_w - 1]

	if not ResourceLoader.exists(tex_n):
		push_warning("North wall texture file missing: " + tex_n)
		return null
	
	if not ResourceLoader.exists(tex_e):
		push_warning("East wall texture file missing: " + tex_e)
		return null

	if not ResourceLoader.exists(tex_s):
		push_warning("South wall texture file missing: " + tex_s)
		return null

	if not ResourceLoader.exists(tex_w):
		push_warning("West wall texture file missing: " + tex_w)
		return null

	var mat := ShaderMaterial.new()
	mat.shader = wall_shader
	mat.set_shader_parameter("tex_front", load(tex_n))
	mat.set_shader_parameter("tex_back", load(tex_s))
	mat.set_shader_parameter("tex_left", load(tex_e))
	mat.set_shader_parameter("tex_right", load(tex_w))

	_mat_cache[combined_id] = mat

	return mat
