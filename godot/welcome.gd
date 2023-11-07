extends Node3D

var main_scene = "res://main.tscn"
var welcome_song = preload("res://audio/music/song-tmp0t1rmrfi.mp3")

@onready var lul : Node3D = $Lul

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var child = lul.get_children()[randi_range(0,lul.get_child_count()) - 1 ]
	child.scale += .1 * Vector3(rand(),rand(),rand())

func rand():
	return randf() - randf()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file(main_scene)
