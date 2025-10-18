@tool
class_name MapLoader
extends Node3D

enum {
	NORTH, EAST, SOUTH, WEST
}

class L1Utils:
	const door_id = 50 # texture id
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

	static func is_push_wall(id: int) -> bool:
		return id == 98

	static func is_static(id: int) -> bool:
		return id >= 23 and id <= 70

	static func get_static_idx(id: int) -> int:
		return id - 23


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


@export var json_path : String = "user://assets/maps/json/00_Wolf1 Map1.json"
var grid: MapGrid

# NOTE: It is crucial that we use `add_child` in tandem with `@tool` annonated scripts.
#		By doing this, anything we generate doesn't get serialized into the tscn file.
#		This is precisely what we want, online-only generation of resources from raw data.
var root_node: Node3D

func _ready() -> void:
	# Wait for the autoload extractor to finish
	if not AssetExtractor.extraction_complete:
		await AssetExtractor.extraction_finished
	
	print("MapLoader: Loading map from: ", json_path)  # ADD THIS LINE
	grid = MapGrid.new(json_path)
	print("MapLoader: Map name: ", grid.map_name) 
	update_tile_material()
	spawn_layer1()
	spawn_layer2()
	add_child(root_node)
	
#-----------------------------------------------------
# Tile texture array & stub material generation
#-----------------------------------------------------
@export var tile_texture_folder: String = "user://assets/walls/"
var tile_shader: Shader = preload("res://Tile.gdshader")
var tile_material: ShaderMaterial = null

func update_tile_material() -> void:
	if tile_material == null:
		tile_material = ShaderMaterial.new()
		tile_material.shader = tile_shader
	tile_material.set_shader_parameter("texture_array", _generate_texture_array(tile_texture_folder))

#static func _generate_texture_array(texture_folder: String) -> Texture2DArray:
	#const tex_size: int = 64
#
	#var files = ResourceLoader.list_directory(texture_folder)
	#var images = []
#
	## Load all valid texture files (assumes id-prefixed filenames cuz sorting)
	#for file in files:
		#if file.ends_with(".png"):
			#var image: Image = Image.load_from_file(texture_folder + file)
#
			#if not image.has_mipmaps():
				#image.generate_mipmaps()
#
			#assert(image.get_width() == tex_size and image.get_height() == tex_size)
			#images.append(image)
#
	#assert(images.size() != 0)
#
	#var result = Texture2DArray.new()
	#result.create_from_images(images)
	#return result
static func _generate_texture_array(texture_folder: String) -> Texture2DArray:
	const tex_size: int = 64

	# USE DirAccess INSTEAD OF ResourceLoader for user:// paths
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
	
	# Sort files to maintain order
	files.sort()
	
	var images = []

	# Load all valid texture files
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

				door_inst.name = "Door"
				door_inst.mesh = door_ew_mesh if door_axis else door_ns_mesh
				door_inst.material_override = tile_material
				door_inst.position = Vector3(x + 0.5, 0, y + 0.5)
				door_inst.rotation_degrees.y += -90 * float(door_axis)

				root_node.add_child(door_inst)

			elif L2Utils.is_push_wall(thing_id) and L1Utils.is_wall(tile_id):
				var pushwall_mesh: ArrayMesh = pushwall_meshes.get(tile_id)

				if pushwall_mesh == null:
					pushwall_mesh = get_pushwall_mesh(tile_id)
					pushwall_meshes[tile_id] = pushwall_mesh

				var pushwall_inst := MeshInstance3D.new()
				pushwall_inst.name = "PushWall"
				pushwall_inst.mesh = pushwall_mesh
				pushwall_inst.material_override = tile_material

				# Mark pushwalls in the editor
				if Engine.is_editor_hint():
					pushwall_inst.material_overlay = pushwall_editor_overlay_mat

				pushwall_inst.position = Vector3(x + 0.5, 0, y + 0.5)

				root_node.add_child(pushwall_inst)


#-----------------------------------------------------
# Layer2 (Things) spawning
#-----------------------------------------------------
@export var sprite_texture_folder: String = "user://assets/sprites/"
var player_scene = preload("res://Player.tscn")

func spawn_layer2() -> void:
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

				# Ignore multiple start points even if present
				added_player = true

			elif L2Utils.is_static(id):
				var static_idx = L2Utils.get_static_idx(id)
				var sprite: Sprite3D = Sprite3D.new()

				sprite.position = Vector3(x + 0.5, 0, y + 0.5)
				
				# FIXED: Load texture from user:// path correctly
				var sprite_path = "%sSPR_STAT_%d.png" % [sprite_texture_folder, static_idx]
				var img = Image.load_from_file(sprite_path)
				if img != null:
					sprite.texture = ImageTexture.create_from_image(img)
				else:
					push_error("Failed to load sprite: " + sprite_path)
					continue
				
				sprite.centered = true
				sprite.pixel_size = 0.015
				sprite.axis = 2 # Z-Axis
				sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				sprite.transparent = true
				sprite.double_sided = false
				sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

				root_node.add_child(sprite)


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
