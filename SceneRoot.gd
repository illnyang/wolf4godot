# https://github.com/godotengine/godot/issues/79336#issuecomment-1631627181
extends Node3D
@export var player_scene: PackedScene

func _ready() -> void:
	$"/root".set_script(load("res://SceneRootWindow.gd"))
	
func _input(event):
	if event.is_action_pressed("exit"):
		return_to_menu()

func return_to_menu():
	GameState.save_game_state()
	
	GameState.menu_from_game = true
	get_tree().change_scene_to_file("res://MainMenu.tscn")
