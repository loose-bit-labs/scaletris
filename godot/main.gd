extends Node3D

var block_scene = preload("res://block.tscn")

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
@onready var far_box = $Board/farrightwall/Box
@onready var bonus_box = $Board/Info/walls/backBonus
@onready var bonus_floor = $Board/Info/walls/floorBonus
@onready var info_box = $Board/Info/Box
@onready var divider_box = $Board/bonuswall/Box
@onready var status_box = $Board/Info/StatusHolder/Status
@onready var status_box_texture = $Board/Info/StatusHolder/Status/StatusTexture
@onready var status_box_color = $Board/Info/StatusHolder/Status/StatusColor
@onready var status_box_player = $Board/Info/StatusHolder/Status/Player
@onready var boxes = [backBox, floorBox, leftBox, rightBox, topBox, hide_bonus]
@onready var bonus_boxes = [far_box, bonus_box, divider_box, bonus_floor]

@onready var label_level = $Board/Info/Level/Value
@onready var label_kills = $Board/Info/Kills/Value
@onready var label_required = $Board/Info/Required/Value
@onready var label_health = $Board/Info/Health/Value
@onready var label_max_health = $Board/Info/MaxHealth/Value
@onready var label_score = $Board/Info/Score/Value
@onready var label_bonus_count = $Board/Info/Bonus/Value
@onready var label_bonus = $Board/Info/Bonus
@onready var label_bonus_timer = $Board/Info/BonusTimer
@onready var label_bonus_required = $Board/Info/Bonus/Required

@onready var info_lives = $Board/Info/Lives
@onready var label_lives = $Board/Info/Lives/Value

@onready var pauser = $Informatica/Paused
@onready var pause_title = $Informatica/Paused/Title

@onready var u_win = $Informatica/Win
@onready var u_lose = $Informatica/Lose
@onready var lose_tmi = $Informatica/Lose/TMI

@onready var explain_bonus = $Informatica/Paused/BonusExplanation
@onready var explain_normal = $Informatica/Paused/NormalExplanation
@onready var explain_levelled = $Informatica/Paused/LevelledExplanation

@onready var camera = $Camera3D
@onready var player = $AnimationPlayer

# note: these are set by level difficulty
var gravity = .25
var move_force = 100

var kills = 0
var current_level = 0
var level = {}
var score = 0
var score_before = 0
var required_bonus_count = 5
var bonus_count = 0
var bonus_timer = 0
var non_bonus = {}
var possible_count = 0
var missed_count = 0
var is_bonus_level = false
var loading = false
var game_over = false
var lives = 0
var level_up_please = false
var sweeter = 0

# state variables 
var current_block = null
var last_block = null
var started = false
var block_map = {}
var save_size = -22
var in_bonus_zone = false

var bonus_index = 0
var bonus_last = 0
var bonus_list1 = []
var bonus_list2 = []
var bonus_list = []
var bonus_force = false
var bonus_can_drop = true
var matched_blocks = {}

var should_watch_mouse = false
var mouse_button_at = null

var score_bonus_cleared = 100

@export var dev_mode = false
@export var helpful_helper = false
@export var overly_friendly = false
@export var full_auto = false

@export var health_gradient = Gradient.new()

@onready var status_ok = preload("res://images/textures/status/s-ok.png")
@onready var status_hurt = preload("res://images/textures/status/s-hurt.png")
@onready var status_dying = preload("res://images/textures/status/s-dying.png")

###################################################################################################

func _ready():
	_game_specific() 
	_load_level(current_level)
	started = true

func _game_specific():
	lives = Fof.game_lives()
	if lives:
		info_lives.show()
	else:
		lives = -33
		info_lives.hide()
	explain_normal.text = Fof.world.game.explanation
	for box in bonus_boxes:
		box.set_material(Fof.world.game.bonus_material)
	info_box.set_material(Fof.world.game.info_material)

###################################################################################################

func _load_level(level_index:int=0):
	if dev_mode:
		print("Loading level ", level_index, " of ", Fof.world.levels.size())
	if level_index >= Fof.world.levels.size():
		_on_level_over(false, "You beat all the levels!")
		return
	
	loading = true
	current_level = level_index
	level = Fof.get_level(current_level)
	
	if _load_is_bonus():
		if dev_mode:
			print("this is a bonus level, but you didn't earn it: ", level.name, ' aka ', level_index)
		_load_level(level_index + 1)
		loading = false
		return
	
	if dev_mode:
		print("loading level ", current_level)
	
	_load_reset_values()
	_load_blocks()
	_load_has_bonus()
	_load_start_level()
	_update_status()

func _load_is_bonus(_level_index:int=0):
	is_bonus_level = Fof.is_bonus_level(level)
	if is_bonus_level:
		status_box.hide()
		if not bonus_force and bonus_count < required_bonus_count:
			if dev_mode:
				print("sorry, needed ", required_bonus_count, " but you only collected ", bonus_count)
			bonus_count = 0
			return true
		else:
			label_bonus_timer.show()
			bonus_wall.position.y = 0
	else:
		in_bonus_zone = false
		label_bonus_timer.hide()
		status_box.show()
		bonus_wall.position.y = 8.8
	return false

func _load_reset_values():
	matched_blocks = {}
	non_bonus = {}
	level_up_please = false
	possible_count = level.chance.size()
	kills = 0
	score_before = score
	bonus_force = false
	missed_count = 0
	bonus_count = 0
	sweeter = 0
	gravity = level.speed
	move_force = level.force
	mainAudio.stream = level[Fof.MUSIC]
	last_block = null
	current_block = null
	status_box_player.play("happy")
	status_box_player.set_speed_scale(1)
	pause_title.text = "PAUSED"
	mainAudio.play()

func _load_blocks():
	block_map = {}
	_remove_blocks(true)
	_remove_blocks(true) # FIXME: seriously... please remove *all* of them!
	var material = level.material
	if is_bonus_level and Fof.world.game.bonus:
		material = Fof.game_bonus_material()
	if not material:
		material = level.material
	for box in boxes:
		box.set_material(material)
	if not is_bonus_level or not Fof.game_bonus_material():
		floorBox.set_material(level.material2)

func _load_has_bonus():
	var bonus = Fof.get_bonus(current_level)
	if bonus:
		label_bonus_count.show()
		hide_bonus.hide()
		right_wall.position.y = bonus.gap
		required_bonus_count = bonus.required
	else:
		required_bonus_count = 0
		label_bonus_count.hide()
		hide_bonus.show()
		right_wall.position.y = 7

func _load_start_level():
	loading = false
	_show_hide_explanations()

func _show_hide_explanations():
	for e in [explain_normal, explain_bonus, explain_levelled]:
		e.hide()
	if is_bonus_level:
		explain_bonus.show()
		_load_bonus_level()
	else:
		explain_normal.show()

func _load_bonus_level():
	bonus_can_drop = true
	bonus_timer = level.bonusLevel.timer
	bonus_index = 0
	bonus_last = 0
	bonus_list1 = Fof.get_level(current_level-1).chance.keys()
	bonus_list2 = Fof.get_level(current_level-1).chance.keys()
	bonus_list1.shuffle()
	bonus_list2.shuffle()
	hide_bonus.show()

func _drop_bonus_item():
	if not bonus_can_drop:
		return
	var block = _instantiate_block()
	var entity = Fof.entity_for_level(current_level - 1, block_map, false, matched_blocks)
	if null == entity:
		bonus_can_drop = false
		bonus_index = -33
		return null
	block.entity = entity
	if entity.name in block_map:
		var first = block_map[entity.name][0].entity
		#if dev_mode:
		#	print("second ", entity.name, " first is on ", first.right)
		entity.right = not first.right
	else:
		entity.right = true if randf() < .5 else false
		#if dev_mode:
		#	print("first ", entity.name, " on ", entity.right)
	_add_block(block, entity, false)
	
	# fixme: this is not really right anymore...
	var idxo = int(bonus_index/2.)%4
	bonus_index = bonus_index + 1
	var p = _random_position()
	if entity.right:
		p.x = 0 + idxo * 2.7 / 4
	else:
		p.x = -4.8 + idxo * (-1.77 - -4.8) / 4
	block.configure(self, p, _random_spin(), gravity, entity)

func _instantiate_block():
	var block = block_scene.instantiate()
	var scale_ = Fof.get_scale(current_level)
	if Fof.MINIMUM in scale_:
		block.SCALE_MINIMUM = scale_.minimum
	if Fof.MAXIMUM in scale_:
		block.SCALE_MAXIMUM = scale_.maximum
	return block

###################################################################################################

func _current_safety():
	current_block = current_block if current_block and is_instance_valid(current_block) else null
	return current_block
	
func _process(delta):
	if game_over or loading or pauser.is_visible_in_tree():
		return
	_process_bonus_level(delta) if is_bonus_level else _process_normal_level(delta)
	
	#frq
	if true:
		return
	if is_bonus_level:
		_process_bonus_level(delta)
		return
	_process_normal_level(delta)


func _process_normal_level(_delta):
	_count_bonus()
	_current_safety()
	if current_block:
		if current_block.sleeping:
			_automatic_for_the_people(current_block)
			_you_have_fallen_and_you_cant_get_up()
		else:
			_automatic_for_the_people(current_block, .0330)
		return
	_create_new_box()

func _process_bonus_level(delta):
	bonus_timer -= delta
	bonus_last -= delta
	if bonus_index >= 0 && bonus_last < 0:
		_drop_bonus_item()
		bonus_last = 1
	_update_status()
	if bonus_timer <= 0:
		player.play("lost_level")
		_next_level(false)

func _next_level(sweet:bool = true):
	_update_status()
	if not bonus_force and Fof.has_death_bonus(level):
		if 0 >= bonus_count:
			lives = -33
			_on_level_over(true, "You *must* collect at least one bonus item!")
			return
		if 1 == bonus_count:
			_on_level_over(true, "You only collected one bonus item...")
			return
	if sweet and current_level >= Fof.world.levels.size() - 1:
		_on_level_over(false, "You beat all the levels!")
		return
	if sweet:
		player.play("fx_success")
	else:
		player.play("fx_fail")
	_post_level_text(sweet)
	_update_status()
	_please_level_up()
	
func _please_level_up(_game_over=false):
	explain_bonus.hide()
	explain_normal.hide()
	explain_levelled.show()
	pauser.show()
	if not _game_over:
		level_up_please = true

func _post_level_text(sweet:bool):
	var diff = score - score_before
	var collected = "You collected %d points, your total score is now %d." %[diff, score]
	if is_bonus_level:
		var lived = "Congratulations, you made it through the Bonus Level!\n"
		if sweet:
			pause_title.text = "SUCCESS! 🥇"
			if lives < 5:
				lived = lived + "You cleaned this one up and get another life!"
				lives = lives + 1
			else:
				lived = lived + "You cleaned this one up and get an additional 50 Bonus Points!"
				score = score + 50
		else:
			pause_title.text = "Bonus Timer Ran Out! ⌛"
			player.play("lost_level")
		explain_levelled.text = lived
		return
		
	if sweet:
		pause_title.text = "SUCCESS! 🏆"
		var lines = []
		lines.append("You passed Level \"" + level.title + "\"")
		lines.append(collected)
		if required_bonus_count:
			if not bonus_force and bonus_count < required_bonus_count:
				lines.append("Unfortunately, you didn't make the Bonus Level.")
				player.play("lost_level")
			else:
				lines.append("You qualified for the Bonus Level!")
		explain_levelled.text = "\n".join(lines)
	else:
		pause_title.text = "Bummer... 😭"
		explain_levelled.text = "You failed Level \"" + level.title + "\""
		player.play("lost_level")

func _on_paused_visibility_changed():
	if level_up_please and not pauser.is_visible_in_tree():
		if dev_mode:
			print("LEVEL UP TO ", 1 + current_level, "; is bonus level? ", is_bonus_level)
		level_up_please = false
		_load_level(1 + current_level)
	else:
		if not pauser.is_visible_in_tree():
			_show_hide_explanations()

func _update_status():
	label_level.text = level.title
	label_score.text = str(score)
	label_bonus_count.text = str(bonus_count)
	if is_bonus_level:
		_update_show_timer()
	else:
		label_kills.text = str(kills)
		label_required.text = str(level.required)
		label_health.text = str(possible_count - missed_count)
		label_max_health.text = str(possible_count)
		label_lives.text = str(lives)
		if "" == Fof.game_life():
			label_lives.text = str(lives)
		else:
			label_lives.text = ""
			for life in range(lives):
				label_lives.text = label_lives.text + Fof.game_life()
		label_bonus_required.text = str(required_bonus_count)
		_update_status_box()

var status_tmp = 33
func _update_status_box():
	var status = (possible_count - missed_count) / float(possible_count)
	var color = health_gradient.sample(status)
	status_box_color.material.albedo_color = color
	if dev_mode && status_tmp != status:
		print("STATUS IS ", status, " for ", missed_count, " of ", possible_count, " so color is ", color)
		status_tmp = status
	status_box_player.set_speed_scale(2 + 4 * (1 - status)**2)
	var s = .1 + .2 + status * .8
	#status_box.scale = Vector3(s, s, s)
	status_box_texture.scale = Vector3(s, s, s)
	status_box_color.scale = Vector3(s, s, s)
	if status > .7:
		status_box_texture.material.set_texture(StandardMaterial3D.TEXTURE_ALBEDO,status_ok)
	elif status > .5:
		status_box_texture.material.set_texture(StandardMaterial3D.TEXTURE_ALBEDO,status_hurt)
	else:
		status_box_texture.material.set_texture(StandardMaterial3D.TEXTURE_ALBEDO,status_dying)

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
	if pauser.is_visible_in_tree():
		return
	if dev_mode and event is InputEventKey and event.pressed:
		_key_pressed(event.keycode)
	if event.is_action_pressed("left"):
		_move(Vector3(-1, 0, 0))
	if event.is_action_pressed("right"):
		_move(Vector3(+1, 0, 0))
	if event.is_action_pressed("ui_accept"):
		_move(Vector3(0, -8.8, 0))
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

###################################################################################################

func _check_misses():
	var b4 = missed_count
	missed_count = _count_misses()
	if false and missed_count < b4 - 1:
		print("\n\n\n---")
		print("missed count went from ", b4, " to ", missed_count)
		_count_misses(true)
		pauser.pause()


func _count_misses(debug:bool = false):
	var c = 0
	for blocks in block_map.values():
		var baddies = blocks.filter(
			func(block): return Fof.FOES == block.entity.type
		).map(func(block): return block.entity.name)
		c = c + (1 if 2 == baddies.size() else 0)
		if debug:
			print(c, baddies)
	return c

###################################################################################################

func _handle_bonus_blocks(block, been_here = false):
	if not _current_safety():
		current_block = null
	if not current_block:
		current_block = block
		current_block.show_particles(true)
		if dev_mode:
			print("SELECTED ", current_block.short_name())
		return
	current_block.show_particles(false)
	if dev_mode:
		print("COMPARE ", current_block.short_name(), " and ", block.short_name())
	if current_block.entity.id == block.entity.id:
		if dev_mode:
			print("SAME BLOCK ", current_block.short_name(), " and ", block.short_name())
		return
	if block.entity.name != current_block.entity.name:
		if dev_mode:
			print("SWITCHING FROM ", current_block.short_name(), " to ", block.short_name())
		current_block = null
		if been_here:
			if dev_mode:
				print("honestly... didn't think this could happen")
		else:
			_handle_bonus_blocks(block, true)
		return
	if not block.size == current_block.size:
		if dev_mode:
			print("SIZE MISMATCH ", current_block.short_name(), " to ", block.short_name())
		if Fof.FOES == current_block.entity.type:
			_play_or(current_block, "lost_item")
		else:
			_play_sad(current_block)
		current_block = null
		if been_here:
			if dev_mode:
				print("honestly... didn't think this could happen")
		else:
			_handle_bonus_blocks(block, true)
		return
		# current_block = last_block
		
	_matched(current_block, [block])
	var remaining = block_map.size()
	if dev_mode:
		print("size matched ", block.entity.name, ", bonus_index is ", bonus_index, " and ", remaining )
	if bonus_index < 0 and !remaining:
		if dev_mode:
			print("DECENT!")
		score = score + score_bonus_cleared * current_level
		_update_status()
		_next_level(true)
		return
	var sound = Fof.XF if Fof.FOES == current_block.entity.type else Fof.FX
	if Fof.FOES == current_block.entity.type and not current_block.entity.xf:
		sound = Fof.FX
	_play_or(current_block, "got_item", sound)
	score = score + current_level * 10
	_update_status()
	current_block = null

###################################################################################################

func _key_pressed(code:int):
	match code:
		KEY_1: _load_level(0) # village
		KEY_2: _load_level(2) # woods
		KEY_3: _load_level(4) # cave
		KEY_4: _load_level(6) # lair
		KEY_5: _load_level(8) # pit
		KEY_6: _load_level(10) # pit'
		KEY_7: _load_level(12) # ...
		KEY_8: _load_level(14) # ...
		KEY_9: _load_level(16) # win
		KEY_L: _go_lose()
		KEY_A: _toggle_full_auto()
		KEY_B: _bonus_hack()
		KEY_G: gravity = gravity + 1
		KEY_F: _toggle_overly_friendly()
		KEY_N: _next_level(true)
		KEY_Q: _show_blocks()
		KEY_I: _tmi()
		KEY_X: _auto_match()
		KEY_Z: _toggle_helper()
		KEY_T: bonus_timer = 999
		KEY_O: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		KEY_U: kills = level.required

func _go_lose():
	lives = 0
	_on_level_over(true, "Test losing")

func _bonus_hack():
	bonus_force = true

func _bonus_click():
	var hit = Fof.camera_mouse(self, camera, [front_wall])
	var block = hit.get_parent()
	if hit and Fof.ENTITY in block:
		_handle_bonus_blocks(block)

func _toggle_helper():
	helpful_helper = !helpful_helper
	print("helpful_helper is ", helpful_helper )

func _toggle_overly_friendly():
	overly_friendly = !overly_friendly
	print("overly_friendly is ", overly_friendly)

func _toggle_full_auto():
	full_auto = not full_auto
	print("full_auto is now ", full_auto)

func _automatic_for_the_people(block:Block, chance:float = 1.1):
	if block.is_bonus():
		chance = chance * 4.4
	if not full_auto or randf() > chance:
		return
	if block.is_bonus():
		var p = 4.04
		if block.position.x < p or randf() < .1:
			var x = max(1, p - block.body.position.x)
			block.move(Vector3(x * x * 42.24,0,0))
		return
	if not block.entity.name in block_map:
		return
	var sizes = block_map[block.entity.name].filter(
		func(b):return b.id() != block.id()
	).map(func(b):return b.size)
	if sizes.size():
		var size = sizes.pick_random()
		block.set_size(size)
		#print("what's the frequency, ", size, " x ", chance, "?")

###################################################################################################

func _move(force:Vector3):
	if _current_safety():
		current_block.move(force * move_force)

func _size(size_change:int):
	if _current_safety():
		current_block.update_size(size_change)

# bonus levels use _drop_bonus_item instead
func _create_new_box():
	if is_bonus_level:
		# FIXME: should not happen
		if dev_mode:
			print("how did you get here?")
		return
	if loading:
		# TODO: don't think this happens...
		if dev_mode:
			print("still loading...")
		return
	var block = _instantiate_block()
	
	# bonus_item_for_level(level_index:int, block_map = {}, sweeter:float = 0):
	if kills > level.required * .7:
		sweeter = .3
	if kills > level.required * .85:
		sweeter = .8
	
	var entity = Fof.entity_for_level(current_level, block_map, true, {}, sweeter)
	if null == entity:
		_on_level_over(true, "You ran out of options!")
		return null
	block.entity = entity
	_add_block(block, entity)
	block.configure(self, _random_position(), _random_spin(), gravity, entity)
	if helpful_helper:
		var xmin = -4
		var xmax = +3
		var x = xmin + (xmax - xmin) * (block.size / entity.level)
		print("helpling: ", entity.level, " vs ", block.size, " so ", x)
		block.position.x = x
	return block

func _on_level_over(lost:bool = true, tmi:String = ""):
	status_box_player.stop() 
	lose_tmi.text = tmi
	if lost:
		lives = lives - 1
		if lives <= 0:
			#{If lives = 0} You just lost your last life and have been "scaled to Zero". Wanna try again?
			player.play("game_over")
			game_over = true
			u_lose.show()
		else:
			player.play("lost_level")
			if dev_mode:
				print("You are still alive, so restart level")
			pause_title.text = "Bummer... 😭"
			explain_levelled.text = "You failed Level \"" + level.title + "\"\n\nDon't Despair!"
			if 1 == lives:
				explain_levelled.text += "\n\nBut... you only have 1 life left! Do your best!"
			else:
				explain_levelled.text += "\n\nYou are a still alive! Focus! You can do it!"
			player.play("lost_level")
			_update_status()
			current_level = current_level - 1 # FIXME: this is hacky...
			_please_level_up()
	else:
		player.play("victory")
		game_over = true
		u_win.show()

func _add_block(block, entity, make_current:bool = true):
	var entity_name = entity[Fof.NAME]
	add_child(block)
	if make_current:
		current_block = block
	in_bonus_zone = false
	
	if Fof.BONUS == entity.type:
		if not Fof.BONUS in block_map:
			block_map[Fof.BONUS] = []
		block_map[Fof.BONUS].append(block)
		block.set_size(0)
		save_size = -33
		return
	
	var sizes = []
	if entity_name in block_map:
		sizes = block_map[entity_name].map(func(b): return b.size)
	var size = block.random_size(sizes)
	if entity_name in block_map:
		if block_map[entity_name].size():
			save_size = -44
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
	if not _current_safety():
		return
	var entity_name = current_block.entity.name
	if not entity_name in block_map:
		return 
	var blocks = block_map[entity_name]
	var missed = []
	var matched = []
	var friend_hack = overly_friendly and current_block.entity.type == Fof.FRIENDS
	for other in blocks:
		if other.in_bonus_zone:
			continue
		if other != current_block:
			if other.size == current_block.size or friend_hack:
				matched.append(other)
			else:
				missed.append(other)
	if matched.size():
		_matched(current_block, matched)
	else:
		if missed.size():
			_missed(current_block, missed, blocks)

###################################################################################################

func _auto_match():
	var picks = []
	for entity_name in block_map:
		var blocks = block_map[entity_name].filter(func(b): return b.sleeping and Fof.BONUS != b.entity.type)
		if 2 == blocks.size():
			picks.append(blocks)
			print(blocks.size(), " for ", blocks[0].entity.name)
	if !picks.size():
		return
	var pick = picks.pick_random()
	var primary = pick.pop_front()
	print("pick ", pick)
	_matched(primary, pick)

# TODO: play the right tone for win / gain
func _matched(primary, others):
	print("matched ", primary.entity, " and ", others.size(), " others")
	matched_blocks[primary.entity.name] = true
	if not is_bonus_level:
		match primary.entity.type:
			Fof.FOES:    _killed(primary, others.size()+1)
			Fof.FRIENDS: _helped(primary, others.size()+1)
	_remove_block(primary)
	for other in others:
		_remove_block(other)
	for block in _get_blocks():
		block.wakeUp()
	_check_misses()

func _killed(block, count, animate = true):
	if animate:
		#player.play("game_reward")
		_play_sad(block, "game_reward") # the block is a foe and so it's sad when ur happy :-P
	kills = kills + 1
	score += block.entity.level * count * 17
	if dev_mode:
		print(kills, " of ",level.required, " kills, and experience is ", score )
	if kills >= level.required:
		if dev_mode:
			print("VICTORIOUS!")
		_next_level(true)
	else:
		_check_misses()
		_update_status()

func _helped(block, count):
	var picks = []
	for entity_name in block_map:
		var other = Fof.entity_by_name(entity_name)
		if other and other.type == Fof.FOES:
			picks.append_array(block_map[entity_name])
	var picked = null if !picks.size() else picks.pick_random()
	if picked:
		if dev_mode:
			print("you got help from ", count, " ", block.entity.name, "! they killed ", picked.entity.name, "!")
		_play_or(block, "fx_attack_blocked")
		_killed(picked, 1, false)
		_remove_block(picked)
		_check_misses()
		_update_status()
	else:
		_play_or(block, "got_item")
		_check_misses()
		_update_status()
		#player.play("got_item")
		if dev_mode:
			print(block.entity.name, " wanted to help, but you are too good!")

###################################################################################################

func _missed(primary, others, _blocks):
	if dev_mode:
		print("missed ", primary.hi(), " and ", others.map(func(b):return b.hi()))
		if full_auto:
			pauser.pause()
	if primary.entity.type == Fof.FRIENDS:
		_play_sad(primary)
	else:
		_play_or(primary, "lost_item")
	missed_count = missed_count + 1 # TODO: remove this: _check_misses is used now 
	primary.go_red()
	for o in others:
		o.go_red()
	_check_misses()
	_update_status()

###################################################################################################

func _play_sad(block, animation_name:String = "lost_item"):
	_play_or(block, animation_name, Fof.XF)
	
func _play_or(block, animation_name:String, sound = Fof.FX):
	if block.entity[sound]:
		if dev_mode:
			print(sound, " : ", block.entity[sound], " for ", block.entity.name)
		player.play(block.entity[sound])
	else:
		if dev_mode:
			print(sound, " : ", animation_name, " even for ", block.entity.name)
		player.play(animation_name)

###################################################################################################

func _random_position():
	return Vector3(4 *_rand() - 1, 8, 0)

func _random_spin():
	return 6.6 * Vector3(_rand(), _rand(), _rand())

func _rand():
	return randf_range(-1,+1)

###################################################################################################

func on_collision(_block, body):
	if body.name == "frontwall" || body.name == "backwall":
		return
	player.play("tonk")

func _get_blocks():
	return get_tree().get_nodes_in_group("blocks")

func _remove_block(block):
	if not block:
		remove_child(block)
		return
	block.remove()
	if block.entity.name in block_map:
		block_map[block.entity.name].erase(block)
		if 0 == block_map[block.entity.name].size():
			block_map.erase(block.entity.name)

func _remove_blocks(force:bool = false):
	for block in _get_blocks():
		if force:
			remove_child(block)
		else:
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
	if dev_mode and false:
		print("yawn! ", block.entity, " and ", block.in_bonus_zone)

func _count_bonus(show_:bool = false):
	if show_:
		print("------------------------------------")
	var bc = 0
	var a_bonus = null
	for entity_name in block_map:
		for block in block_map[entity_name]:
			if not block.sleeping:
				continue
			if block.in_bonus_zone:
				if entity_name == Fof.BONUS:
					a_bonus = block
					bc = bc + 1
					_sting(block, "got_item")
				else:
					bc = bc - 1
					var type = block.entity.type
					var sound = Fof.FX if Fof.FOES == type else Fof.XF
					if not block.entity.id in non_bonus:
						if dev_mode:
							print("SSS ", type, " so ", sound, " ie ", block.entity[sound])
					_sting(block, "lost_item", sound)
			else:
				if entity_name == Fof.BONUS:
					_sting(block, "lost_item", Fof.XF)
			if show_:
				print(bc, " ", block.show_me())
	if bonus_count < required_bonus_count and bc == required_bonus_count and required_bonus_count:
		if a_bonus:
			_play_or(a_bonus, "earned_bonus")
		else:
			player.play("earned_bonus")
	bonus_count = bc
	_update_status()

func _sting(block, animation_name:String = "lost_item", sound = Fof.FX):
	if not block.entity.id in non_bonus:
		non_bonus[block.entity.id] = true
		#player.play(animation_name)
		_play_or(block, animation_name, sound)

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
	print("bonus_can_drop: ", bonus_can_drop)
	print("should_watch_mouse: ", should_watch_mouse)
	print("mouse_button_at: ", mouse_button_at)
	print("possible_count: ", possible_count)
	print("missed_count: ", missed_count)
	print("block_map: ", block_map)
	for entity_name in block_map:
		print("> ", entity_name, " : ", block_map[entity_name].map(func(b): return b.show_me() )  )

# just in case...
func _on_too_far_down_body_entered(body):
	if body is StaticBody3D or body.name.contains("wall"):
		if dev_mode:
			print("ignoring ", body.name)
		return
	if body == current_block:
		current_block = null # stahp!
	if dev_mode:
		print("body is thru the ice!: ", body.name)
	body.position.y = 7.7
	#body.apply_central_force(-body.linear_velocity)
	body.set_linear_velocity(Vector3.ZERO)
