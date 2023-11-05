extends Node3D

var box_scene = preload("res://block.tscn")
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var boxes = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
	
func _input(event):
	if event.is_action_pressed("ui_accept"):
		create_new_box()

func create_new_box():
	var new_box = box_scene.instantiate()
	new_box.position = random_spawn_position()  # Set the box's position
	add_child(new_box)

func random_spawn_position():
	return Vector3(_rand(),4,_rand())  # Adjust the spawn area as needed

func _rand():
	return randf_range(-1,+1)
