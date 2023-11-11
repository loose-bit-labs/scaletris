extends Node3D

var block_scene = preload("res://block.tscn")

@onready var fxAudio = $fxAudio
@onready var mainAudio = $mainAudio
@onready var backBox = $Board/backwall/CollisionShape3D/Box
@onready var floorBox = $Board/floor/CollisionShape3D/Box
@onready var leftBox = $Board/leftwall/CollisionShape3D/Box
@onready var rightBox = $Board/rightwall/CollisionShape3D/Box
@onready var boxes = [backBox, floorBox, leftBox, rightBox]

# note: these are set by level difficulty
var gravity = .25
var move_force = 100
var size_steps_not = 4

var kills = 0
var current_level = 0
var level = {}
var experience = 0
var health = 10

var current_block = null
var started = false
var block_map = {}
var save_size = -1

@export var muted = false

var should_watch_mouse = false
var mouse_button_at = null

# Called when the node enters the scene tree for the first time.
func _ready():
	started = true
	_update_audio()
	_load_level(0)

func _load_level(level_index:int=0):
	current_level = level_index
	kills = 0
	block_map = {}
	for b in _get_blocks():
		remove_child(b)
	level = Fof.get_level(current_level)
	gravity = level.speed
	move_force = level.force
	mainAudio.stream = level[Fof.MUSIC]
	mainAudio.play()
	# TODO: make this nicer / make sense / fix uvs
	for box in boxes:
		box.set_material(level.material)
	
	_create_new_box()

func _process(_delta):
	if current_block && current_block.sleeping:
		_you_have_fallen_and_you_cant_get_up() 

# TODO: clean this up ... it's disgusting
func _input(event):
	if event is InputEventKey and event.pressed:
		_key_pressed(event.keycode) # temporary hack...
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

func _key_pressed(code:int):
	if code == KEY_1: _load_level(0) # village
	if code == KEY_2: _load_level(1) # woods
	if code == KEY_3: _load_level(2) # cave
	if code == KEY_4: _load_level(3) # lair
	if code == KEY_5: _load_level(4) # pit
	if code == KEY_M: _toggle_mute()

func _toggle_mute():
	muted = !muted
	_update_audio()

func _update_audio():
	mainAudio.set_mute(muted)
	fxAudio.muted = muted	

func _move(force:Vector3):
	if current_block:
		current_block.move(force * move_force)

func _size(size_change:int):
	if current_block:
		current_block.update_size(size_change)

func _create_new_box():
	var block = block_scene.instantiate()
	var entity = Fof.entity_for_level(current_level, block_map)
	block.entity = entity
	_add_block(block, entity)
	block.configure(self, _random_position(), _random_spin(), gravity, entity)
	return block

func _add_block(block, entity):
	var entity_name = entity[Fof.NAME]
	add_child(block)
	current_block = block
	
	var sizes = []
	if entity_name in block_map:
		sizes = block_map[entity_name].map(func(b): return b.size)
	var size = block.random_size(sizes)
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
		current_block.set_size(save_size)
	_check_match()
	_create_new_box()
	
func _check_match():
	var entity_name = current_block.entity[Fof.NAME]
	var blocks = block_map[entity_name]
	var missed = []
	var matched = []
	for other in blocks:
		if other != current_block:
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

func _matched(primary, others, _blocks):
	print("matched ", primary.entity, " and ", others.size(), " others")
	match primary.entity.type:
		"foes":   _killed(primary, others.size()+1)
		"friend": _helped(primary, others.size()+1)
	_remove_block(primary)
	for other in others:
		_remove_block(other)
	for block in _get_blocks():
		block.wakeUp()

# TODO: give out the reward
# TODO: play per monster sound?
func _killed(block, count):
	fxAudio.play_fx(fxAudio.CLASH)
	kills = kills + 1
	experience += block.entity.level * count * 17
	print(kills, " of ",level.required, " kills, and experience is ", experience )
	if kills >= level.required:
		print("VICTORIOUS!")
		_load_level(current_level + 1 )

# TODO: remove a baddy
# TODO: play per helper sound?
func _helped(entity, count):
	fxAudio.play_fx(fxAudio.BELL3)
	print("you got help from ", count, " ", entity.name, "!")

# TODO: animate this
func _remove_block(block):
	remove_child(block)
	if block.entity.name in block_map:
		block_map[block.entity.name].erase(block)
	else:
		print("ERROR: could not find ", block.entity.name, " in ", block_map)

# TODO: handle the consequences
func _missed(primary, others, _blocks):
	print("missed ", primary.entity, " and ", others.size(), " others")
	fxAudio.play_fx(fxAudio.OUCH)

func _random_position():
	return Vector3( 4 *_rand() - 1, 6 ,0*_rand())

func _random_spin():
	return 6.6 * Vector3(_rand(), _rand(), _rand())

func _rand():
	return randf_range(-1,+1)

func _get_blocks():
	return get_tree().get_nodes_in_group("blocks")
