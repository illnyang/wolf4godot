extends Node3D

@export var wall_scene: PackedScene
@export var json_path := "res://maps/map_00_Wolf1 Map1.json"
@export var tile_size := 1.0

func _ready():
	# Debug message to check if the script is running
	print("Map Loader script is running!")

	# Load the JSON map data
	var file = FileAccess.open(json_path, FileAccess.READ)
	var content = file.get_as_text()
	var grid = JSON.parse_string(content)

	# Loop through the grid and instantiate walls
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var tile = int(grid[y][x])
			if tile > 0 and tile <= 63:  # Check for valid wall tiles
				var wall = wall_scene.instantiate()  # Instantiate a new wall
				wall.position = Vector3(x * tile_size, 0, y * tile_size)  # Set wall position
				add_child(wall)  # Add the wall to the scene
