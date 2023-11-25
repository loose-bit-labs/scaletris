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

@onready var info_lives = $Board/Info/Lives
@onready var label_lives = $Board/Info/Lives/Value

@onready var u_win = $Informatica/Win
@onready var u_lose = $Informatica/Lose
@onready var explain_normal = $Informatica/Paused/NormalExplanation
@onready var explain_bonus = $Informatica/Paused/BonusExplanation

@onready var camera = $Camera3D

# note: these are set by level difficulty
var gravity = .25
var move_force = 100

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
var lives = 0

# state variables 
var current_block = null
var last_block = null
var started = false
var block_map = {}
var save_size = -1
var in_bonus_zone = false

var bonus_index = 0
var bonus_last = 0
var bonus_list1 = []
var bonus_list2 = []

var should_watch_mouse = false
var mouse_button_at = null

var score_bonus_cleared = 100

###################################################################################################

func _ready():
	started = true
	if Fof.GAME in Fof.world and Fof.LIVES in Fof.world.game:
		lives =  Fof.world.game.lives
		info_lives.show()
	else:
		lives = -33
		info_lives.hide()
	_update_audio()
	_load_level(current_level)

###################################################################################################

func _load_level(level_index:int=0):
	if level_index >= Fof.world.levels.size():
		game_over = true
		u_win.show()
		return
	
	loading = true
	current_level = level_index
	level = Fof.get_level(current_level)
	
	if _load_is_bonus():
		_next_level(false)
		loading = false
		return
	
	print("loading level ", current_level)
	
	_load_reset_values()
	_load_blocks()
	_load_has_bonus()
	_load_start_level()
	_update_status()

func _load_is_bonus(_level_index:int=0):
	is_bonus_level = Fof.BONUS_LEVEL in level
	if is_bonus_level:
		if bonus_count < required_bonus_count:
			print("sorry, needed ", required_bonus_count, " but you only collected ", bonus_count)
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

func _load_reset_values():
	possible_count = level.chance.size()
	kills = 0
	missed_count = 0
	bonus_count = 0
	gravity = level.speed
	move_force = level.force
	mainAudio.stream = level[Fof.MUSIC]
	last_block = null
	current_block = null
	if !Fof.muted:
		mainAudio.play()
	_update_audio()

func _load_blocks():
	block_map = {}
	_remove_blocks()
	# TODO: make this nicer / make sense / fix uvs
	for box in boxes:
		box.set_material(level.material)

func _load_has_bonus():
	required_bonus_count = 3
	if Fof.BONUS in level:
		label_bonus_count.show()
		hide_bonus.hide()
		right_wall.position.y = level.bonus.gap
		if Fof.REQUIRED in level.bonus:
			required_bonus_count = level.bonus.required
	else:
		label_bonus_count.hide()
		hide_bonus.show()
		right_wall.position.y = 7

func _load_start_level():
	loading = false
	if is_bonus_level:
		explain_normal.hide()
		explain_bonus.show()
		_load_bonus_level()
	else:
		explain_normal.show()
		explain_bonus.hide()

func _load_bonus_level():
	bonus_timer = level.bonusLevel.timer
	bonus_index = 0
	bonus_last = 0
	bonus_list1 = Fof.get_level(current_level-1).chance.keys()
	bonus_list2 = Fof.get_level(current_level-1).chance.keys()
	bonus_list1.shuffle()
	bonus_list2.shuffle()

func _drop_bonus_item():
	var modo = bonus_index % 2
	bonus_index = bonus_index + 1
	var list = bonus_list1 if modo else bonus_list2
	var side = +1 if modo else - 1
	var next = list.pop_front()
	if !next:
		#print("_load_bonus_level done? ", bonus_list1, " vs ",bonus_list2 )
		bonus_index = -88
		return
	var entity = Fof.entity_by_name(next)
	var block = _instantiate_block()
	add_child(block)
	var p = Vector3( side * 2 * randf() + side, 6, 0)
	block.configure(self, p, _random_spin(), gravity, entity)
	if next in block_map:
		block.random_size([block_map[next][0].size])
		block_map[next].append(block)
	else:
		block_map[next] = [block]
		block.random_size()

func _instantiate_block():
	var block = block_scene.instantiate()
	var scale_ = Fof.get_scale(current_level)
	if Fof.MINIMUM in scale_:
		block.SCALE_MINIMUM = scale_.minimum
	if Fof.MAXIMUM in scale_:
		block.SCALE_MAXIMUM = scale_.maximum
	return block

###################################################################################################

func _process(delta):
	if game_over or loading:
		return
	if is_bonus_level:
		_process_bonus_level(delta)
		return
	_count_bonus()
	if  current_block && current_block.sleeping:
		_you_have_fallen_and_you_cant_get_up()
	if !current_block:
		_create_new_box()

func _process_bonus_level(delta):
	bonus_timer -= delta
	bonus_last -= delta
	if bonus_index >= 0 && bonus_last < 0:
		_drop_bonus_item()
		bonus_last = 1
	_update_status()
	if bonus_timer <= 0:
		print("TODO: play the sadness tune")
		_next_level(false)

func _next_level(sweet:bool = true):
	if sweet:
		print("TODO: play level success sound")
	else:
		print("TODO: play level fail sound")
	_load_level(1 + current_level)

func _update_status():
	label_level.text = level.name.replace("_", " ")
	label_score.text = str(score)
	label_bonus.text = str(bonus_count)
	if is_bonus_level:
		_update_show_timer()
	else:
		label_kills.text = str(kills)
		label_required.text = str(level.required)
		label_health.text = str(possible_count - missed_count)
		label_max_health.text = str(possible_count)
		label_lives = str(lives)

func _update_show_timer():
	var format_this = ""
	if bonus_timer >= 60:
		var minutes: int = int(bonus_timer / 60.)
		var seconds: int = int(bonus_timer) % 60
		format_this = "%d:%02d" % [minutes,seconds]
	else:
		format_this = str(int(bonus_timer))
	label_bonus_timer.text = format_this

###################################################################################################

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
		_handle_mouse_button(event)
	if event is InputEventMouseMotion:
		_handle_mouse_move(event)

func _handle_mouse_button(event):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN):
		_capture_mouse()
		_size(-1)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP):
		_capture_mouse()
		_size(+1)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_capture_mouse()
		if is_bonus_level:
			_bonus_click()
		else:
			should_watch_mouse = event.pressed
			mouse_button_at = event.position
	else:
		if event.button_index == MOUSE_BUTTON_LEFT:
			should_watch_mouse = event.pressed

func _capture_mouse():
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	# doesn't exist: get_tree().set_input_as_handled()
	pass

func _handle_mouse_move(event):
	if !should_watch_mouse:
		return
	_capture_mouse()
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
		KEY_5: _load_level(5) # pit'
		KEY_9: _load_level(9) # win
		KEY_B: _bonus_hack()
		KEY_N: _next_level(true)
		KEY_Q: _show_blocks()
		KEY_I: _tmi()

func _bonus_hack():
	
	bonus_count = 33
	print("HELLO!", bonus_count)
	#_load_level(1)
	_update_status()

func _bonus_click():
	var hit = Fof.camera_mouse(self, camera, [front_wall])
	var block = hit.get_parent()
	if  hit and Fof.ENTITY in block:
		_handle_bonus_blocks(block)

func _check_misses():
	var c =_count_misses()
	if c != missed_count:
		_count_misses(true)
		missed_count = c
		_check_misses()
		_update_status()

func _count_misses(debug:bool = false):
	var c = 0
	if debug:
		print("\nmissed count mismatch ", c, " versus ", missed_count)
	for ez in block_map.values():
		ez = ez.filter(func(b): return Fof.BONUS == b.entity.name or b.sleeping).map(func(b): return b.show_me())
		c = c + (1 if 2 == ez.size() else 0)
		if debug:
			print(c, ez)
	return c

func _handle_bonus_blocks(block):
	if current_block:
		current_block.show_particles(false)
	last_block = current_block
	current_block = block
	current_block.show_particles(true)
	# FIXME: this is not working
	current_block.body.apply_central_force(Vector3(0,2.1,0))
	#body.apply_impulse(f) #frq
	#body.apply_central_force(f)
	#TODO: some kinda of indicator for current
	if not last_block:
		return
	
	if last_block == current_block:
		# TODO: clear indicator 
		current_block = null
		last_block = null
		return
	
	if last_block.entity.name == current_block.entity.name:
		print("nice, two ", current_block.entity.name)
		if last_block.size == current_block.size:
			score = score + 33
			_remove_block(current_block)
			_remove_block(last_block)
			var remaining = block_map.size()
			print("size matched ", block.entity.name, ", bonus_index is ", bonus_index, " and ", remaining )
			if bonus_index < 0 and !remaining:
				print("DECENT!")
				score = score + score_bonus_cleared * current_level
				_update_status()
				_next_level(true)
				return
			score = score + current_level * 10
			_update_status()
			current_block = null
			last_block = null
		else:
			print("size no match ", block.entity.name)
	else:
		pass
		#print("no match...")
		#current_block = last_block

###################################################################################################

func toggle_mute():
	Fof.muted = !Fof.muted
	return _update_audio()

func _update_audio():
	mainAudio.set_mute(Fof.muted)
	fxAudio.muted = Fof.muted
	return Fof.muted

###################################################################################################

func _move(force:Vector3):
	if current_block:
		current_block.move(force * move_force)

func _size(size_change:int):
	if current_block:
		current_block.update_size(size_change)

# bonus levels use _drop_bonus_item instead
func _create_new_box():
	if is_bonus_level:
		# FIXME: should not happen
		print("how did you get here?")
		return
	if loading:
		# TODO: don't think this happens...
		print("still loading...")
		return
	var block = _instantiate_block()
	var entity = Fof.entity_for_level(current_level, block_map)
	if null == entity:
		print("U LOST I GUESS....", kills , " vs ", level.required)
		u_lose.show()
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
	current_block = null

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
		_next_level(true)
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
	remove_child(block)
	if not block:
		return
	block.remove()
	if block.entity.name in block_map:
		block_map[block.entity.name].erase(block)
		if 0 == block_map[block.entity.name].size():
			block_map.erase(block.entity.name)
	else:
		# thinks this is actually ok...
		if false:
			print("ERROR: _remove_block could not find ", block.entity.name, " in ", block_map)

func _remove_blocks():
	for block in _get_blocks():
		#remove_child(block)
		_remove_block(block)

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

func _tmi():
	print("gravity: ", gravity)
	print("move_force: ", move_force)
	print("kills: ", kills)
	print("current_level: ", current_level)
	print("level: ", level)
	print("score: ", score)
	print("required_bonus_count: ", required_bonus_count)
	print("bonus_count: ", bonus_count)
	print("bonus_timer: ", bonus_timer)
	print("possible_count: ", possible_count)
	print("missed_count: ", missed_count)
	print("is_bonus_level: ", is_bonus_level)
	print("loading: ", loading)
	print("game_over: ", game_over)
	print("current_block: ", current_block)
	print("last_block: ", last_block)
	print("started: ", started)
	print("block_map: ", block_map)
	print("save_size: ", save_size)
	print("in_bonus_zone: ", in_bonus_zone)
	print("bonus_index: ", bonus_index)
	print("bonus_last: ", bonus_last)
	print("bonus_list1: ", bonus_list1)
	print("bonus_list2: ", bonus_list2)
	print("muted: ", Fof.muted)
	print("should_watch_mouse: ", should_watch_mouse)
	print("mouse_button_at: ", mouse_button_at)
