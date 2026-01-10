# ViewBorder.gd
# Draws the border around the 3D viewport when view size is smaller than full
# Based on original Wolf3D DrawPlayBorder() function from WL_GAME.C
extends CanvasLayer

# Border color - RGB(0, 65, 65) dark teal/cyan
const BORDER_COLOR = Color(0.0/255.0, 65.0/255.0, 65.0/255.0, 1.0)

# Original resolution
const ORIG_WIDTH = 320
const ORIG_HEIGHT = 200

# References
var border_rects: Array[ColorRect] = []  # [top, bottom, left, right]
var scale_factor: float = 2.0

func _ready() -> void:
	# Set layer to render above 3D but below HUD
	layer = 5
	
	# Calculate scale
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / float(ORIG_WIDTH)
	
	# Create border rectangles
	_create_border_rects()
	
	# Connect to view size changes
	GameState.view_size_changed.connect(_on_view_size_changed)
	
	# Initial update
	_update_borders()


func _create_border_rects() -> void:
	# Create 4 rectangles for top, bottom, left, right borders
	for i in range(4):
		var rect = ColorRect.new()
		rect.color = BORDER_COLOR
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		border_rects.append(rect)


func _on_view_size_changed(_new_size: int) -> void:
	_update_borders()


func _update_borders() -> void:
	if border_rects.size() < 4:
		return
	
	# Get view dimensions in original coordinates
	var view_width = GameState.get_view_width()
	var view_height = GameState.get_view_height()
	
	# Game area is 160 pixels (200 - 40 STATUSLINES)
	var game_area_height = GameState.GAME_AREA_HEIGHT
	
	# Calculate viewport position (centered in game area)
	var viewport_x = (ORIG_WIDTH - view_width) / 2.0
	var viewport_y = (game_area_height - view_height) / 2.0
	
	# Check if at full size (no borders needed)
	var is_full = view_width >= ORIG_WIDTH and view_height >= game_area_height
	
	# Top border
	var top_rect = border_rects[0]
	top_rect.visible = not is_full and viewport_y > 0
	if top_rect.visible:
		top_rect.position = Vector2(0, 0)
		top_rect.size = Vector2(ORIG_WIDTH * scale_factor, viewport_y * scale_factor)
	
	# Bottom border (above HUD, below viewport)
	var bottom_rect = border_rects[1]
	var bottom_y = viewport_y + view_height
	var bottom_height = game_area_height - bottom_y
	bottom_rect.visible = not is_full and bottom_height > 0
	if bottom_rect.visible:
		bottom_rect.position = Vector2(0, bottom_y * scale_factor)
		bottom_rect.size = Vector2(ORIG_WIDTH * scale_factor, bottom_height * scale_factor)
	
	# Left border
	var left_rect = border_rects[2]
	left_rect.visible = not is_full and viewport_x > 0
	if left_rect.visible:
		left_rect.position = Vector2(0, viewport_y * scale_factor)
		left_rect.size = Vector2(viewport_x * scale_factor, view_height * scale_factor)
	
	# Right border
	var right_rect = border_rects[3]
	var right_x = viewport_x + view_width
	var right_width = ORIG_WIDTH - right_x
	right_rect.visible = not is_full and right_width > 0
	if right_rect.visible:
		right_rect.position = Vector2(right_x * scale_factor, viewport_y * scale_factor)
		right_rect.size = Vector2(right_width * scale_factor, view_height * scale_factor)
