extends Node3D

var block_scene = preload("res://block.tscn")

# FIXME: this should be based on level difficulty
var gravity = .25
var move_force = 100
var size_steps = 4

var current_block = null
var started = false
var block_map = {}
var save_size = -1
@onready var tiles = _load_tiles("res://images/tiles")
@onready var fxAudio = $fxAudio

var should_watch_mouse = false
var mouse_button_at = null

# Called when the node enters the scene tree for the first time.
func _ready():
	started = true
	_create_new_box()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if current_block && current_block.sleeping:
		_you_have_fallen_and_you_cant_get_up() 

func _input(event):
	if event.is_action_pressed("left"):
		_move(Vector3(-1, 0, 0))
	if event.is_action_pressed("right"):
		_move(Vector3(+1, 0, 0))
	if event.is_action_pressed("ui_accept"):
		_move(Vector3(0, -1, 0))
	if event.is_action_pressed("up"):
		_size(+1)
	if event.is_action_pressed("down"):
		_size(-1)
	if event.is_action_pressed("ui_accept") && !started:
		_create_new_box()
		started = true
	if event is InputEventMouseButton:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN):
			_size(-1)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP):
			_size(+1)
		if event.button_index == MOUSE_BUTTON_LEFT:
			should_watch_mouse = event.pressed
			mouse_button_at = event.position
	if event is InputEventMouseMotion && should_watch_mouse:
		var x = event.position[0]
		var y = event.position[1]
		var xdiff = x - mouse_button_at[0]
		var ydiff = y - mouse_button_at[1]
		var threshold = 50 # FIXME: magic number goes where?!
		if abs(xdiff)>threshold:
			_move(Vector3(-1 if xdiff<0 else +1, 0, 0))
			mouse_button_at[0] = x
		# dunno if this is a good idea or not 
		if abs(ydiff)>threshold:
			_move(Vector3(0, .5 * (+1 if ydiff<0 else -1), 0))
			mouse_button_at[1] = y

func _move(force:Vector3):
	if current_block:
		current_block.move(force * move_force)

func _size(size:int):
	if current_block:
		current_block.update_size(size, size_steps)

func _create_new_box():
	var block = block_scene.instantiate()
	var result = _random_material()
	var material = result[0]
	var index = result[1]
	_add_block(block, index)
	
	block.configure(self, _random_position(), _random_spin(), gravity, material)
	return block

func _add_block(block, index):
	add_child(block)
	current_block = block
	var size = randi_range(1, size_steps)
	block.set_size(size, size_steps)
	block.index = index
	if index in block_map:
		if block_map[index].size():
			save_size = -1
		else:
			save_size = size
		block_map[index].append(block)
	else:
		block_map[index] = [block]
		save_size = size

func on_collision(block,body):
	if body.name == "frontwall" || body.name == "backwall":
		return
	fxAudio.play_tonk() 

func _you_have_fallen_and_you_cant_get_up():
	if save_size > -.33:
		current_block.set_size(save_size, size_steps)
	_check_match()
	_create_new_box()
	
func _check_match():
	var blocks = block_map[current_block.index]
	for other in blocks:
		if other != current_block:
			#print("CHECK: ", current_block.size, " vs ", other.size)
			if other.size == current_block.size:
				_matched(other, current_block)

# TODO: some sound / animation / something amazing
func _matched(a,b):
	fxAudio.play_fx(fxAudio.BELL2)
	remove_child(a)
	remove_child(b)
	var blocks = block_map[current_block.index]
	blocks.erase(a)
	blocks.erase(b)
	for block in _get_blocks():
		block.wakeUp()	

func _random_material():
	var index = randi_range(0, tiles.size() - 1)
	var material = tiles[index]
	return [material, index]

func _random_position():
	return Vector3( 4 *_rand() - 1, 6 ,0*_rand())

func _random_spin():
	return 6.6 * Vector3(_rand(), _rand(), _rand())

func _rand():
	return randf_range(-1,+1)

func _get_blocks():
	var blocks = []
	for kid in get_children():
		if "Block" == kid.name:
			blocks.append(kid)
	return blocks

func _image_to_material(image):
	var TEXTURE_ALBEDO = 0 # idk this is supposed to be a TextureParam enum but I can't seem to get the magic right
	var new_material = StandardMaterial3D.new()
	var texture = ImageTexture.create_from_image(image)
	new_material.set_texture(TEXTURE_ALBEDO, texture)
	return new_material

# FIXME: long term this won't work, see the debugger crying about it
func _load_tiles(path):
	var _tiles = []
	var dir = DirAccess.open(path)
	if not dir:
		return _tiles
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if dir.current_is_dir():
			print("Found directory: " + file)
		else:
			if file.ends_with(".png") or file.ends_with(".jpg"):
				var rez = path + "/" + file
				var image = Image.load_from_file(rez)
				_tiles.append(_image_to_material(image))
				print("Found image: ", rez)
		file = dir.get_next()
	return _tiles
