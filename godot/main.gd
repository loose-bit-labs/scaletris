extends Node3D

var block_scene = preload("res://block.tscn")

@onready var fxAudio = $fxAudio
@onready var mainAudio = $mainAudio

@onready var backBox =  $Board/backwall/Box
@onready var floorBox = $Board/floor/Box
@onready var leftBox =  $Board/leftwall/Box
@onready var rightBox = $Board/rightwall/bottomBox/Box
@onready var topBox = $Board/rightwall/topBox/Box
@onready var right_wall = $Board/rightwall
@onready var bonus_wall = $Board/bonuswall
@onready var front_wall = $Board/frontwall
@onready var hide_bonus = $Board/Info/walls/hideBonus
@onready var boxes = [backBox, floorBox, leftBox, rightBox, topBox, hide_bonus]

@onready var label_level = $Board/Info/Level/Value
@onready var label_kills = $Board/Info/Kills/Value
@onready var label_required = $Board/Info/Required/Value
@onready var label_health = $Board/Info/Health/Value
@onready var label_max_health = $Board/Info/MaxHealth/Value
@onready var label_score = $Board/Info/Score/Value
@onready var label_bonus = $Board/Info/Bonus/Value
@onready var label_bonus_count = $Board/Info/Bonus
@onready var label_bonus_timer = $Board/Info/BonusTimer

@onready var u_win = $Informatica/Win
@onready var u_lose = $Informatica/Lose

@onready var camera = $Camera3D

# note: these are set by level difficulty
var gravity = .25
var move_force = 100
var size_steps_not = 4

var kills = 0
var current_level = 0
var level = {}
var score = 0
var required_bonus_count = 5
var bonus_count = 0
var bonus_timer = 0
var possible_count = 0
var missed_count = 0
var is_bonus_level = false
var loading = false
var game_over = false

# state variables 
var current_block = null
var last_block = null
var started = false
var block_map = {}
var save_size = -1
var in_bonus_zone = false

var bonus_index = 0
var bonus_last = 0

@export var muted = false

var should_watch_mouse = false
var mouse_button_at = null

###################################################################################################

func _ready():
	started = true
	_update_audio()
	current_level = 1 #hack
	bonus_count = 33 #hack
	_load_level(current_level)

func _load_level(level_index:int=0):
	if level_index >= Fof.world.levels.size():
		game_over = true
		u_win.show()
		return
	
	loading = true
	current_level = level_index
	level = Fof.get_level(current_level)
	
	if _load_is_bonus():
		_load_level(1+level_index)
		return
	
	_load_values()
	_load_blocks()
	_load_has_bonus()
	_load_start_level()
	_update_status()
	loading = false

func _load_is_bonus(_level_index:int=0):
	is_bonus_level = Fof.BONUS_LEVEL in level
	if is_bonus_level:
		if bonus_count < required_bonus_count:
			bonus_count = 0
			return true
		else:
			label_bonus_timer.show()
			bonus_wall.position.y = 0
	else:
		in_bonus_zone = false
		label_bonus_timer.hide()
		bonus_wall.position.y = 8.8
	return false

func _load_values():
	possible_count = level.chance.size()
	kills = 0
	missed_count = 0
	bonus_count = 0
	gravity = level.speed
	move_force = level.force
	mainAudio.stream = level[Fof.MUSIC]
	if !muted:
		mainAudio.play()
	_update_audio()

func _load_blocks():
	block_map = {}
	_remove_blocks()
	# TODO: make this nicer / make sense / fix uvs
	for box in boxes:
		box.set_material(level.material)

func _load_has_bonus():
	required_bonus_count = 5
	if Fof.BONUS in level:
		label_bonus_count.show()
		hide_bonus.hide()
		right_wall.position.y = 7 + level.bonus.gap
		required_bonus_count = level.bonus.count
	else:
		label_bonus_count.hide()
		hide_bonus.show()
		right_wall.position.y = 7

func _load_start_level():
	if is_bonus_level:
		_load_bonus_level()
	else:
		_create_new_box()

func _load_bonus_level():
	bonus_timer = level.bonusLevel.timer
	bonus_index = 0
	bonus_last = 0

func _drop_bonus_item():
	var kz = level.chance.keys()
	if bonus_index >= kz.size():
		return
	var entity_name = kz[bonus_index]
	bonus_index = bonus_index + 1
	var entity = Fof.entity_by_name(entity_name)
	var block1 = block_scene.instantiate()
	var block2 = block_scene.instantiate()
	add_child(block1)
	add_child(block2)
	var p1 = Vector3( -3 * randf() -1, 6, 0)
	var p2 = Vector3( +2 * randf() +1, 6, 0)
	block1.configure(self, p1, _random_spin(), gravity, entity)
	block2.configure(self, p2, _random_spin(), gravity, entity)
	block1.random_size()
	block2.random_size([block1.size])

###################################################################################################

func _process(delta):
	if game_over or loading:
		return
	if is_bonus_level:
		_process_bonus_level(delta)
		return
	_count_bonus()
	if current_block && current_block.sleeping:
		_you_have_fallen_and_you_cant_get_up()

func _process_bonus_level(delta):
	bonus_timer -= delta
	bonus_last -= delta
	if bonus_index < level.chance.keys().size() && bonus_last < 0:
		_drop_bonus_item()
		bonus_last = 1
	_update_status()
	if bonus_timer <= 0:
		print("wamp-wah!")
		_load_level(1+current_level)

func _update_status():
	label_level.text = level.name
	label_kills.text = str(kills)
	label_required.text = str(level.required)
	label_health.text = str(possible_count - missed_count)
	label_max_health.text = str(possible_count)
	label_score.text = str(score)
	label_bonus.text = str(bonus_count)
	if is_bonus_level:
		_update_show_timer()

func _update_show_timer():
	var format_this = ""
	if bonus_timer >= 60:
		var minutes: int = int(bonus_timer) / 60
		var seconds: int = int(bonus_timer) % 60
		format_this = "%d:%02d" % [minutes,seconds]
	else:
		format_this = str(bonus_timer)
	label_bonus_timer.text = format_this

###################################################################################################

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
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if is_bonus_level:
				_bonus_click()
			else:
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
	match code:
		KEY_1: _load_level(0) # village
		KEY_2: _load_level(1) # woods
		KEY_3: _load_level(2) # cave
		KEY_4: _load_level(3) # lair
		KEY_5: _load_level(4) # pit
		KEY_9: _load_level(9) # win
		KEY_M: toggle_mute()
		KEY_B: _show_blocks()

const RAY_LENGTH = 100
func _bonus_click():
	var space_state = get_world_3d().direct_space_state
	var mousepos = get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mousepos)
	var end = origin + camera.project_ray_normal(mousepos) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.exclude = [front_wall]

	var result = space_state.intersect_ray(query)
	if !result or not "collider" in result: 
		return
	var block = result.collider.get_parent()
	if not Fof.ENTITY in block:
		return
	print(block.entity.name)
	last_block = current_block
	current_block = block
	if last_block and current_block:
		if last_block.entity.name == current_block.entity.name:
			print("nice, two ", current_block.entity.name)
			var tmp = current_block
			current_block = last_block
			last_block = tmp
		else:
			print("sry")
			last_block = null
			current_block = null
	#TODO: some kinda of indicator...

###################################################################################################

func toggle_mute():
	muted = !muted
	_update_audio()

func _update_audio():
	mainAudio.set_mute(muted)
	fxAudio.muted = muted

###################################################################################################

func _move(force:Vector3):
	if current_block:
		current_block.move(force * move_force)

func _size(size_change:int):
	if current_block:
		if is_bonus_level:
			if last_block:
				current_block.update_size(size_change)
		else:
			current_block.update_size(size_change)

func _create_new_box():
	var block = block_scene.instantiate()
	var entity = Fof.entity_for_level(current_level, block_map)
	if null == entity:
		u_lose.show()
		print("U LOST I GUESS....")
		game_over = true
		return
	block.entity = entity
	_add_block(block, entity)
	block.configure(self, _random_position(), _random_spin(), gravity, entity)
	return block

func _add_block(block, entity):
	var entity_name = entity[Fof.NAME]
	add_child(block)
	current_block = block
	in_bonus_zone = false
	
	if Fof.BONUS == entity.type:
		if not Fof.BONUS in block_map:
			block_map[Fof.BONUS] = []
		block_map[Fof.BONUS].append(block)
		block.set_size(0)
		save_size = -1
		return
	
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

###################################################################################################		

func _you_have_fallen_and_you_cant_get_up():
	if save_size > -.33:
		current_block.set_size(save_size)
	if Fof.BONUS != current_block.entity.type and !current_block.in_bonus_zone:
		_check_match()
	_create_new_box()

###################################################################################################

func _check_match():
	var entity_name = current_block.entity[Fof.NAME]
	var blocks = block_map[entity_name]
	var missed = []
	var matched = []
	for other in blocks:
		if other.in_bonus_zone:
			continue
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

###################################################################################################

# TODO: play the right tone for win / gain
func _matched(primary, others, _blocks):
	print("matched ", primary.entity, " and ", others.size(), " others")
	match primary.entity.type:
		Fof.FOES:    _killed(primary, others.size()+1)
		Fof.FRIENDS: _helped(primary, others.size()+1)
	_remove_block(primary)
	for other in others:
		_remove_block(other)
	for block in _get_blocks():
		block.wakeUp()

# TODO: play per monster sound?
func _killed(block, count):
	fxAudio.play_fx(fxAudio.CLASH)
	kills = kills + 1
	score += block.entity.level * count * 17
	print(kills, " of ",level.required, " kills, and experience is ", score )
	if kills >= level.required:
		print("VICTORIOUS!")
		_load_level(current_level + 1 )
	else:
		_update_status()

# TODO: play per helper sound?
func _helped(block, count):
	fxAudio.play_fx(fxAudio.BELL3) #TODO: better sound
	var picks = []
	for entity_name in block_map:
		var other = Fof.entity_by_name(entity_name)
		if other and other.type == Fof.FOES:
			picks.append_array(block_map[entity_name])
	var picked = null if !picks.size() else picks.pick_random()
	if picked:
		_killed(picked,1)
		_remove_block(picked)
		print("you got help from ", count, " ", block.entity.name, "! they killed ", picked.entity.name, "!")
	else:
		print(block.entity.name, " wanted to help, but you are too good!")

###################################################################################################

# TODO: handle the consequences
func _missed(primary, others, _blocks):
	print("missed ", primary.entity, " and ", others.size(), " others")
	fxAudio.play_fx(fxAudio.OUCH)
	missed_count = missed_count + 1
	_update_status()

###################################################################################################

func _random_position():
	return Vector3( 4 *_rand() - 1, 6 ,0*_rand())

func _random_spin():
	return 6.6 * Vector3(_rand(), _rand(), _rand())

func _rand():
	return randf_range(-1,+1)

###################################################################################################

func on_collision(_block,body):
	if body.name == "frontwall" || body.name == "backwall":
		return
	fxAudio.play_tonk() 

func _get_blocks():
	return get_tree().get_nodes_in_group("blocks")

func _remove_block(block):
	if not block:
		return
	block.remove()
	if block.entity.name in block_map:
		block_map[block.entity.name].erase(block)
	else:
		print("ERROR: _remove_block could not find ", block.entity.name, " in ", block_map)

func _remove_blocks():
	for b in _get_blocks():
		remove_child(b)

func _show_blocks():
	_count_bonus(true)

###################################################################################################

func _on_bonus_area_body_entered(body):
	_bonus_area(body, true)

func _on_bonus_area_body_shape_exited(_body_rid, body, _body_shape_index, _local_shape_index):
	_bonus_area(body, false)

func _bonus_area(body, entered:bool):
	var block = body.get_parent()
	if not Fof.ENTITY in block:
		print("nope! ", block, " from ", body)
		return
	block.in_bonus_zone = entered

func i_was_so_tired(block):
	if false:
		print("yawn! ", block.entity.name, " and ", in_bonus_zone)

func _count_bonus(show_:bool = false):
	if show_:
		print("------------------------------------")
	var bc = 0
	for type in block_map:
		for block in block_map[type]:
			if block.in_bonus_zone and block.sleeping:
				if type == Fof.BONUS:
					bc = bc + 1
				else:
					bc = bc - 1
			if show_:
				print(bc, " ", block.show_me())
	#print("bc:", block_map, " -> ", bc)
	bonus_count = bc
	_update_status()

###################################################################################################
