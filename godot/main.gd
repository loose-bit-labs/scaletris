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

@onready var fof = preload("res://fof.gd").new()
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
	var entity = fof.random_entity()
	#var result = _random_material()
	_add_block(block, entity)
	
	block.configure(self, _random_position(), _random_spin(), gravity, entity)
	return block

func _add_block(block, entity):
	var entity_name = entity[fof.NAME]
	add_child(block)
	current_block = block
	var size = randi_range(1, size_steps)
	block.set_size(size, size_steps)
	if entity_name in block_map:
		if block_map[entity_name].size():
			save_size = -1
		else:
			save_size = size
		block_map[entity_name].append(block)
	else:
		block_map[entity_name] = [block]
		save_size = size

func on_collision(_block,body):
	if body.name == "frontwall" || body.name == "backwall":
		return
	fxAudio.play_tonk() 

func _you_have_fallen_and_you_cant_get_up():
	if save_size > -.33:
		current_block.set_size(save_size, size_steps)
	_check_match()
	_create_new_box()
	
func _check_match():
	var entity_name = current_block.entity[fof.NAME]
	var blocks = block_map[entity_name]
	var missed = []
	var matched = []
	for other in blocks:
		if other != current_block:
			#print("CHECK: ", current_block.size, " vs ", other.size)
			if other.size == current_block.size:
				matched.append(other)
			else:
				missed.append(other)
	if matched.size():
		_matched(current_block, matched, blocks)
	else:
		if missed.size():
			_missed(current_block, missed, blocks)

# TODO: play the right tone for win / gain
# TODO: give out the reward
func _matched(primary, others, blocks):
	print("matched ", primary.entity, " and ", others.size(), " others")
	fxAudio.play_fx(fxAudio.BELL2)
	remove_child(primary)
	blocks.erase(primary)
	for other in others:
		remove_child(other)
		blocks.erase(other)
	for block in _get_blocks():
		block.wakeUp()

# TODO: handle the consequences
func _missed(primary, others, _blocks):
	print("missed ", primary.entity, " and ", others.size(), " others")

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
