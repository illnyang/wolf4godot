extends Node3D
## Simple Wolf 3‑D map loader that skins each wall instance
## with the matching wall##.png texture.
##
##  • 0‑63  regular walls  (extracted as wall00.png … wall63.png)
##  • 64‑255 floors / empty space – ignored here
##  • 90‑101 doors          (optional – see comments below)

@export var wall_scene      : PackedScene            # your current wall scene
@export var json_path       : String = "res://maps/map_00_Wolf1 Map1.json"
@export var tile_size       : float  = 1.0           # 1 Godot unit == 1 tile
@export var texture_folder  : String = "res://assets/walls/"


# -------------------------------------------------------------------
# Cached materials – one per wall id, created on first use
# -------------------------------------------------------------------
var _mat_cache: Dictionary = {}      # int → StandardMaterial3D


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
# -------------------------------------------------------------------
func _spawn_walls(grid: Array) -> void:
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var id := int(grid[y][x])

			# ------  regular walls 0‑63  ----------------------------
			if id >= 0 and id <= 63:
				var wall := wall_scene.instantiate()
				wall.position = Vector3(x * tile_size, 0, y * tile_size)
				_apply_texture(wall, id)
				add_child(wall)

			# ------  doors 90‑101  (optional)  ----------------------
			# elif id >= 90 and id <= 101:
			#     var door := door_scene.instantiate()
			#     door.position = Vector3(x * tile_size, 0, y * tile_size)
			#     _apply_texture(door, id)   # or dedicated door material
			#     add_child(door)
			# --------------------------------------------------------


# ------------------------------------------------------------
#  helper: recursively find the first MeshInstance3D in a node
# ------------------------------------------------------------
func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _find_mesh(c)
		if m:
			return m
	return null


# ------------------------------------------------------------
#  Build / fetch the material, then apply it to that mesh
# ------------------------------------------------------------
func _apply_texture(node: Node3D, id: int) -> void:
	var mesh := _find_mesh(node)
	if mesh == null:
		push_warning("No MeshInstance3D inside wall_scene!")
		return

	if _mat_cache.has(id):
		mesh.material_override = _mat_cache[id]
		return

	var tex_path := "%swall%02d.png" % [texture_folder, id]
	if not ResourceLoader.exists(tex_path):
		push_warning("Texture file missing: " + tex_path)
		return

	var tex: Texture2D = load(tex_path)
	var mat := StandardMaterial3D.new()
	mat.shading_mode   = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = tex

	_mat_cache[id] = mat
	mesh.material_override = mat
