extends Node3D

var main_scene = "res://main.tscn"

@onready var left = $NewWelcome/LeftBox
@onready var right = $NewWelcome/RightBox
@onready var camera = $Camera3D
@onready var floor_ = $NewWelcome/Floor
@onready var player = $AnimationPlayer

@onready var rightV = $NewWelcome/RightBox/RightBoxV
@onready var rightC = $NewWelcome/RightBox/RightBoxC
@onready var back = $NewWelcome/AngledBack

@onready var loading = $Loading

@onready var music = $AudioStreamPlayer3D
@onready var fx = $fxPlayer

@onready var pick_pick = preload("res://images/textures/x-pick.png")
@onready var pick_classic = preload("res://images/textures/x-classic.png")
@onready var pick_quest = preload("res://images/textures/x-quest.png")

var selected = ""
var options = ["classic", "quest"]

var material_pick
var material_classic
var material_quest

func _ready():
	if false:
		print("WL",JSON.stringify({
			"selected":selected,
			"options": options,
			"loading":loading.is_visible_in_tree(),
			"paused": get_tree().paused
		}))
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_materials()
	loading.hide()
	reset()

func _materials():
	material_pick = _material(pick_pick)
	material_classic = _material(pick_classic)
	material_quest =_material(pick_quest)
	material_pick.uv1_scale.y = .5
	material_pick.uv1_offset.y = .2
	material_pick.albedo_color = Color(.4,.4,.4)
	back.material = material_pick

func _material(txt):
	var material = StandardMaterial3D.new()
	material.uv1_scale.x = -1
	material.set_texture(StandardMaterial3D.TEXTURE_ALBEDO, txt)
	return material

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
	if loading.is_visible_in_tree():
		return
	if event.is_action_pressed("mute"):
		Fof.toggle_mute()
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
	if event.is_action_pressed("quit"):
		#TODO: prompt
		Fof.quit()
	if event.is_action_pressed("fullscreen"):
		if DisplayServer.WINDOW_MODE_FULLSCREEN == DisplayServer.window_get_mode():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

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
		back.material = material_pick
		return
	_active(collision.name.substr(4), start)

func _active(which:String = "", start:bool = false):
	if start and "" != which:
		var world = Fof.GAME_CLASSIC if "classic" == which else Fof.GAME_QUEST
		#print("let's go! ", which, " -> ", world)
		loading.show()
		Fof.load_world(world, _start_game)
	if which != selected:
		selected = which
		player.stop()
		player.play("spin_" + which)
		match which:
			"classic": back.material = material_classic
			"quest":  back.material = material_quest
			"": back.material = material_pick

func _start_game():
	loading.hide()
	get_tree().paused = false
	get_tree().change_scene_to_file(main_scene)
