# GameViewport.gd
# Manages scaled 3D viewport using SubViewportContainer
# The 3D game renders at actual scaled size, centered in game area
extends Control

# Border color - RGB(0, 65, 65) dark teal/cyan from original Wolf3D
const BORDER_COLOR = Color(0.0/255.0, 65.0/255.0, 65.0/255.0, 1.0)

# Original game resolution
const ORIG_WIDTH = 320
const ORIG_HEIGHT = 200
const STATUSLINES = 40  # HUD height
const GAME_AREA_HEIGHT = 160  # 200 - 40

@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var background: ColorRect = $Background

var scale_factor: float = 2.0


func _ready() -> void:
	# Get window scale
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / float(ORIG_WIDTH)
	
	# Set background color
	background.color = BORDER_COLOR
	background.size = Vector2(ORIG_WIDTH * scale_factor, GAME_AREA_HEIGHT * scale_factor)
	
	# Connect to view size changes
	GameState.view_size_changed.connect(_on_view_size_changed)
	
	# Initial update
	_update_viewport_size()


func _on_view_size_changed(_new_size: int) -> void:
	_update_viewport_size()


func _update_viewport_size() -> void:
	var view_width = GameState.get_view_width()
	var view_height = GameState.get_view_height()
	
	# Clamp to game area
	view_width = mini(view_width, ORIG_WIDTH)
	view_height = mini(view_height, GAME_AREA_HEIGHT)
	
	# Update SubViewport render size
	sub_viewport.size = Vector2i(view_width, view_height)
	
	# Calculate centered position in game area (in original coordinates)
	var viewport_x = (ORIG_WIDTH - view_width) / 2.0
	var viewport_y = (GAME_AREA_HEIGHT - view_height) / 2.0
	
	# Scale and position the container
	sub_viewport_container.position = Vector2(viewport_x, viewport_y) * scale_factor
	sub_viewport_container.size = Vector2(view_width, view_height) * scale_factor
	
	print("GameViewport: View %dx%d at (%d, %d)" % [view_width, view_height, int(viewport_x), int(viewport_y)])


func get_sub_viewport() -> SubViewport:
	return sub_viewport
