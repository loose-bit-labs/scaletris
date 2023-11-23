extends Node3D

var main_scene = "res://main.tscn"

@onready var left = $NewWelcome/LeftBox
@onready var right = $NewWelcome/RightBox
@onready var camera = $Camera3D
@onready var floor_ = $NewWelcome/Floor
@onready var player = $AnimationPlayer

@onready var rightV = $NewWelcome/RightBox/RightBoxV
@onready var rightC = $NewWelcome/RightBox/RightBoxC

@onready var music = $AudioStreamPlayer3D
@onready var fx = $fxPlayer

var selected = ""
var options = ["classic", "quest"]

func _ready():
	_handle_mute()
	reset()

func reset():
	left.position.x = 2.2
	left.position.y = 5.5
	right.position.y = 9.9
	right.position.x = -2.2
	rightV.scale = Vector3(.5, .5, .5)
	rightC.scale = Vector3(.5, .5, .5)
	right.show()
	left.show()

func _input(event):
	if event.is_action_pressed("mute"):
		_toggle_mute()
	if event.is_action_pressed("ui_accept"):
		_active(selected, true)
	if event.is_action_pressed("ui_up"):
		_selecto(-1)
	if event.is_action_pressed("ui_down"):
		_selecto(+1)
	if event is InputEventMouseMotion:
		mousey(false)
	if event is InputEventMouseButton and event.pressed:
		mousey(true)

func _toggle_mute():
	Fof.muted = !Fof.muted
	_handle_mute()

func _handle_mute():
	print("TODO: ", Fof.muted)
	music.stream_paused = Fof.muted
	# FIXME: this probably won't work"
	fx.stream_paused = Fof.muted 

func _selecto(dir:int = +1):
	match selected:
		"": _active("quest" if dir < 0 else "classic")
		"quest": _active("classic")
		"classic": _active("quest")

func mousey(start:bool = false):
	var collision = Fof.camera_mouse(self, camera, [floor_,left,right])
	if not collision or 0 != collision.name.find("Hot_"):
		player.stop()
		selected = ""
		return
	_active(collision.name.substr(4), start)

func _active(which:String = "", start:bool = false):
	if start and "" != which:
		var world = Fof.GAME_CLASSIC if "classic" == which else Fof.GAME_SCALETRIS
		print("let's go! ", which, " -> ", world)
		Fof.load_world(world)
		_start_game()
	if which != selected:
		selected = which
		player.stop()
		player.play("spin_" + which)

func _start_game():
	get_tree().change_scene_to_file(main_scene)

