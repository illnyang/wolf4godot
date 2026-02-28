extends Control

const BORDER_COLOR = Color(0.0/255.0, 65.0/255.0, 65.0/255.0, 1.0)

const ORIG_WIDTH = 320
const ORIG_HEIGHT = 200
const STATUSLINES = 40
const GAME_AREA_HEIGHT = 160

@onready var sub_viewport_container: SubViewportContainer = $SubViewportContainer
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var background: ColorRect = $Background

var scale_factor: float = 2.0


func _ready() -> void:
	var window_size = get_viewport().get_visible_rect().size
	scale_factor = window_size.x / float(ORIG_WIDTH)
	
	background.color = BORDER_COLOR
	background.size = Vector2(ORIG_WIDTH * scale_factor, GAME_AREA_HEIGHT * scale_factor)
	
	GameState.view_size_changed.connect(_on_view_size_changed)
	
	_update_viewport_size()


func _on_view_size_changed(_new_size: int) -> void:
	_update_viewport_size()


func _update_viewport_size() -> void:
	var view_width = GameState.get_view_width()
	var view_height = GameState.get_view_height()
	
	view_width = mini(view_width, ORIG_WIDTH)
	view_height = mini(view_height, GAME_AREA_HEIGHT)
	
	sub_viewport.size = Vector2i(view_width, view_height)
	
	var viewport_x = (ORIG_WIDTH - view_width) / 2.0
	var viewport_y = (GAME_AREA_HEIGHT - view_height) / 2.0
	
	sub_viewport_container.position = Vector2(viewport_x, viewport_y) * scale_factor
	sub_viewport_container.size = Vector2(view_width, view_height) * scale_factor
	
	print("GameViewport: View %dx%d at (%d, %d)" % [view_width, view_height, int(viewport_x), int(viewport_y)])


func get_sub_viewport() -> SubViewport:
	return sub_viewport
