# https://github.com/godotengine/godot/issues/79336#issuecomment-1631627181
extends Node3D

func _ready() -> void:
	$"/root".set_script(load("res://SceneRootWindow.gd"))
