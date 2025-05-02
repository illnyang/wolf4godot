@tool
class_name MapLoader
extends Node3D

@export var json_path : String = "res://assets/maps/00_Wolf1 Map1.json"
@export var texture_folder: String = "res://assets/walls/"

enum {
	NORTH, EAST, SOUTH, WEST
}

class L1Utils:
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
		# Holds for WL6
		# false = north/south
		# true = east/west
		return id % 2 == 0


class L2Utils:
	static func is_start(id: int) -> bool:
		return id >= 19 and id <= 22

	static func get_start_dir(id: int) -> int:
		return id - 19


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
		var content := file.get_as_text()
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

	# layer 1 accessor
	func tile_at(x: int, y: int) -> int:
		return _tileGrid[y * height() + x]

	# layer 2 accessor
	func thing_at(x: int, y: int) -> int:
		return _thingGrid[y * height() + x]


class WallAtlas:
	const atlas_columns: int = 8 
	const tex_size: int = 64
	var tex_div: Vector2
	static var material: StandardMaterial3D = null

	func _init(texture_folder: String) -> void:
		if material == null:
			material = StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			# TODO: Using anything other than nearest filtering will cause bleeding artifacts
			#		at the edges. This could be avoided if we switch to using `Texture2DArray`.
			#       It would also get rid of the requirement that all wall textures must be
			#		of the same size.
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.albedo_texture = _generate_atlas_texture(texture_folder)

	func _generate_atlas_texture(texture_folder: String) -> ImageTexture:
		# Get all files in the source folder
		var dir = DirAccess.open(texture_folder)
		if not dir:
			push_error("Could not open directory: " + texture_folder)
			return

		var files = dir.get_files()
		var textures = []

		# Load all valid texture files (assumes id-prefixed filenames cuz sorting)
		for file in files:
			if file.ends_with(".png"):
				var texture: Texture2D = load(texture_folder + file)
				assert(texture.get_width() == tex_size and texture.get_height() == tex_size)
				textures.append(texture)

		assert(textures.size() != 0)

		# Calculate atlas dimensions
		var atlas_rows = ceil(textures.size() / float(atlas_columns))
		var atlas_width = atlas_columns * tex_size
		var atlas_height = atlas_rows * tex_size
		tex_div = Vector2(float(tex_size) / atlas_width, float(tex_size) / atlas_height)

		# Create new image for the atlas
		var atlas_image = Image.create_empty(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)

		# Composite all textures into the atlas
		for i in range(textures.size()):
			var x = i % atlas_columns
			var y = i / atlas_columns

			var src_image = textures[i].get_image()
			src_image.convert(Image.FORMAT_RGBA8)

			var pos = Vector2i(x * tex_size, y * tex_size)
			atlas_image.blit_rect(src_image, Rect2i(0, 0, tex_size, tex_size), pos)

		return ImageTexture.create_from_image(atlas_image)


var grid: MapGrid
var atlas: WallAtlas


# NOTE: It is crucial that we use `add_child` in tandem with `@tool` annonated scripts.
#		By doing this, anything we generate doesn't get serialized into the tscn file.
#		This is precisely what we want, online-only generation of resources from raw data.
func _ready() -> void:
	grid = MapGrid.new(json_path)
	atlas = WallAtlas.new(texture_folder)
	spawn_layer1()
	spawn_layer2()


#-----------------------------------------------------
# Layer1 (Tiles) spawning code
#-----------------------------------------------------
func spawn_layer1() -> void:
	var tiles_mesh := MeshInstance3D.new()
	tiles_mesh.name = "MapMesh"
	tiles_mesh.mesh = get_tiles_mesh()
	tiles_mesh.material_override = atlas.material

	var ceiling_mesh := MeshInstance3D.new()
	ceiling_mesh.name = "CeilingMesh"
	ceiling_mesh.position = Vector3(0, 0.5, 0)
	ceiling_mesh.mesh = get_sector_mesh(grid.ceiling_color, true)

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "FloorMesh"
	floor_mesh.position = Vector3(0, -0.5, 0)
	floor_mesh.mesh = get_sector_mesh(grid.floor_color, false)

	tiles_mesh.add_child(ceiling_mesh)
	tiles_mesh.add_child(floor_mesh)
	add_child(tiles_mesh)


#-----------------------------------------------------
# Layer2 (Things) spawning code
#---------------------------------------------dsd--------
var player_scene = preload("res://Player.tscn")

func spawn_layer2() -> void:
	# Spawn Player in the correct orientation
	for y in range(grid.height()):
		for x in range(grid.width()):
			var id = grid.thing_at(x, y)
			if L2Utils.is_start(id):
				var start_dir = L2Utils.get_start_dir(id)
				var player_node: Node3D = player_scene.instantiate()
				
				player_node.position = Vector3(x + 0.5, 0, y + 0.5)
				player_node.rotation_degrees.y = start_dir * -90
				add_child(player_node)
				
				# Ignore multiple start points even if present
				break

#-----------------------------------------------------
# Floor/Ceiling (aka sector) mesh generation code
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
# TileGrid mesh generation code
#-----------------------------------------------------
func is_air(x: int, y: int) -> bool:
	return grid.is_within_grid(x, y) and not L1Utils.is_wall(grid.tile_at(x, y))

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


var vertices = PackedVector3Array()
var indices = PackedInt32Array()
var uvs = PackedVector2Array()
var face_count: int = 0

func get_tiles_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()

	vertices = PackedVector3Array()
	indices = PackedInt32Array()
	uvs = PackedVector2Array()
	face_count = 0

	# TODO: spawn pushwalls independently, will require loading layer2 from json
	for y in range(grid.height()):
		for x in range(grid.width()):
			if is_air(x, y):
				continue

			var id = grid.tile_at(x, y)
			var pos: Vector3 = Vector3(x + 0.5, 0, y + 0.5)

			var door_sides = is_adjecent_to_door(x, y)

			if Engine.is_editor_hint():
				# TOP (editor only, makes it look nicer)
				vertices.append(pos + Vector3(-0.5, 0.5, -0.5))
				vertices.append(pos + Vector3( 0.5, 0.5, -0.5))
				vertices.append(pos + Vector3( 0.5, 0.5,  0.5))
				vertices.append(pos + Vector3(-0.5, 0.5,  0.5))
				add_tris()
				add_uvs(id, false)

			if is_air(x + 1, y):
				# EAST
				vertices.append(pos + Vector3( 0.5, 0.5, 0.5))
				vertices.append(pos + Vector3( 0.5, 0.5, -0.5))
				vertices.append(pos + Vector3( 0.5, -0.5,-0.5))
				vertices.append(pos + Vector3( 0.5, -0.5,  0.5))
				add_tris()
				add_uvs(L1Utils.door_side_id if door_sides & FLAG_SOUTH else id, true)

			if is_air(x, y + 1):
				# SOUTH
				vertices.append(pos + Vector3(-0.5, 0.5, 0.5))
				vertices.append(pos + Vector3( 0.5, 0.5, 0.5))
				vertices.append(pos + Vector3( 0.5, -0.5,0.5))
				vertices.append(pos + Vector3(-0.5, -0.5, 0.5))
				add_tris()
				add_uvs(L1Utils.door_side_id if door_sides & FLAG_WEST else id, false)

			if is_air(x - 1, y):
				# WEST
				vertices.append(pos + Vector3(-0.5, 0.5, -0.5))
				vertices.append(pos + Vector3(-0.5, 0.5,  0.5))
				vertices.append(pos + Vector3(-0.5, -0.5, 0.5))
				vertices.append(pos + Vector3(-0.5, -0.5, -0.5))
				add_tris()
				add_uvs(L1Utils.door_side_id if door_sides & FLAG_NORTH else id, true)

			if is_air(x, y - 1):
				# NORTH
				vertices.append(pos + Vector3( 0.5,  0.5, -0.5))
				vertices.append(pos + Vector3(-0.5,  0.5, -0.5))
				vertices.append(pos + Vector3(-0.5, -0.5, -0.5))
				vertices.append(pos + Vector3( 0.5, -0.5, -0.5))
				add_tris()
				add_uvs(L1Utils.door_side_id if door_sides & FLAG_EAST else id, false)

			if Engine.is_editor_hint():
				# BOTTOM (editor only, makes it look nicer)
				vertices.append(pos + Vector3(-0.5, -0.5, 0.5))
				vertices.append(pos + Vector3( 0.5, -0.5, 0.5))
				vertices.append(pos + Vector3( 0.5, -0.5, -0.5))
				vertices.append(pos + Vector3(-0.5, -0.5, -0.5))
				add_tris()
				add_uvs(id, false)

	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_INDEX] = indices
	array[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)

	return mesh


func add_uvs(id: int, shaded: bool):
	var idx = (((id - 1) * 2) + (1 * int(shaded)))
	var x = (idx % atlas.atlas_columns)
	var y = (idx / atlas.atlas_columns)
	uvs.append(Vector2(
		atlas.tex_div.x * x,
		atlas.tex_div.y * y))
	uvs.append(Vector2(
		atlas.tex_div.x * x + atlas.tex_div.x,
		atlas.tex_div.y * y))
	uvs.append(Vector2(
		atlas.tex_div.x * x + atlas.tex_div.x,
		atlas.tex_div.y * y + atlas.tex_div.y))
	uvs.append(Vector2(
		atlas.tex_div.x * x,
		atlas.tex_div.y * y + atlas.tex_div.y))


func add_tris():
	indices.append(face_count * 4 + 0)
	indices.append(face_count * 4 + 1)
	indices.append(face_count * 4 + 2)
	indices.append(face_count * 4 + 0)
	indices.append(face_count * 4 + 2)
	indices.append(face_count * 4 + 3)
	face_count += 1
