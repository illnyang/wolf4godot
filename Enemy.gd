class_name Enemy
extends Node3D

@export var sprite_texture_folder: String = "user://assets/sprites/"
@export var sprite_index: int = 0

@onready var _sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	_apply_sprite_texture()

func _apply_sprite_texture() -> void:
	if not is_instance_valid(_sprite):
		return

	if sprite_texture_folder == "":
		return

	var sprite_path = "%sSPR_STAT_%d.png" % [sprite_texture_folder, sprite_index]
	var img = Image.load_from_file(sprite_path)
	if img == null:
		push_warning("Enemy: missing sprite " + sprite_path)
		return

	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.centered = true
	_sprite.pixel_size = 0.015
	_sprite.axis = 2
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.transparent = true
	_sprite.double_sided = false
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
