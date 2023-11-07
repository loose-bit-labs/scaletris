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
@onready var images = _load_images("res://images")
@onready var fxAudio = $fxAudio

# Called when the node enters the scene tree for the first time.
func _ready():
	started = true
	_create_new_box()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# FIXME: this isn't perfect... if you move it then it won't sleep :-/
	if current_block && current_block.body.sleeping:
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
	print("colliders gunna collide! ", block, " and ", body)
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
# TODO: need to wake up sleeping blocks to prevent stuff hanging out in mid air!
func _matched(a,b):
	remove_child(a)
	remove_child(b)
	var blocks = block_map[current_block.index]
	blocks.erase(a)
	blocks.erase(b)

func _random_material():
	var index = randi_range(0, images.size() - 1)
	var image = images[index]
	var TEXTURE_ALBEDO = 0 # idk this is supposed to be a TextureParam enum but I can't seem to get the magic right
	var new_material = StandardMaterial3D.new()
	new_material.set_texture(TEXTURE_ALBEDO, image)
	return [new_material, index]

func _random_position():
	return Vector3( 4 *_rand() - 1, 6 ,0*_rand())

func _random_spin():
	return 6.6 * Vector3(_rand(), _rand(), _rand())

func _rand():
	return randf_range(-1,+1)

# FIXME: long term this won't work, see the debugger crying about it
func _load_images(path):
	var _images = []
	var dir = DirAccess.open(path)
	if not dir:
		return _images
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if dir.current_is_dir():
			print("Found directory: " + file)
		else:
			if file.ends_with(".png") or file.ends_with(".jpg"):
				var rez = path + "/" + file
				var image = Image.load_from_file(rez)
				#var image = load(rez) # doesn't work...
				var texture = ImageTexture.create_from_image(image)
				_images.append(texture)
				print("Found image: ", rez)
		file = dir.get_next()
	return _images
