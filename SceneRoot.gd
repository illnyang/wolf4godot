# https://github.com/godotengine/godot/issues/79336#issuecomment-1631627181
extends Node3D

func _ready() -> void:
	$"/root".set_script(load("res://SceneRootWindow.gd"))

func _input(event):
	if event.is_action_pressed("exit"):
		exit_game()

func exit_game():
	var platform = OS.get_name()

	if platform == "HTML5":
		print("NThe game cannot be closed in the browser.")
	else:
		get_tree().quit()
