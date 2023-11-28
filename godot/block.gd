extends Node3D

@onready var collision : CollisionShape3D = $RigidBody3D/CollisionShape3D
@onready var body : RigidBody3D = $RigidBody3D
@onready var box : CSGBox3D = $RigidBody3D/Box
@onready var animationPlayer = $AnimationPlayer

var particle_override = false
@onready var particles = $RigidBody3D/GPUParticles3D
@onready var redder = $RigidBody3D/RedParticles

var shape : BoxShape3D = null
var main = null

var size = -1
var entity = {}
var in_bonus_zone = false

# sleeping or mostly sleeping
var sleeping = false
var lastY = 88
var sleepyTime = 0
@export var maxSleepiness   : float = .12
@export var sleepyThreshold : float = 3.3

@export var glow_color = Color.WHITE
@export var glow_intensity = .3

@export var SCALE_MINIMUM = 1.5
@export var SCALE_MAXIMUM = 3

var og = Vector3(0,7,0)

# Called when the node enters the scene tree for the first time.
func _ready():
	# don't share the collision shape!
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(.5,.5,.5)
	shape = collision.shape
	show_particles(true, false)
	add_to_group("blocks")
	print(particles.draw_pass_1.material)
 
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !sleeping:
		_am_i_getting_sleepy(delta)

func configure(main_, position_:Vector3, spin:Vector3, gravity:float, entity_):
	self.main = main_
	position = position_
	body.angular_velocity = spin
	body.gravity_scale = gravity
	entity = entity_
	og = position_
	box.set_material(entity[Fof.MATERIAL])

func _max_size():
	return entity[Fof.LEVEL]

func update_size(size_change:int):
	if Fof.BONUS == entity.type:
		return
	set_size(size+size_change)
	
# try to avoid picking a size that matches something already on the floor
# this is a lot of work in gdscript since it's array lack explicity sizing
# and fill can't take a lambda
func random_size(sized:Array = []):
	if Fof.BONUS == entity.type:
		return set_size(0)
	var possible = []
	var lame = {}
	for s in sized:
		lame[s] = true
	var maxs = _max_size()
	for t in range(0, maxs + 1):
		if not t in lame:
			possible.append(t)
	var r = randi_range(0, maxs) if !possible.size() else possible.pick_random()
	#print("SZ:", sized, " vs ", possible, " from 0 to ", _max_size(), " gives us ", r)
	return set_size(r)
	#return set_size(randi_range(0, _max_size()))

func set_size(size_:int):
	var b4 = size
	var max_size = _max_size()
	size = clamp(size_, 0, max_size)
	if b4 == size:
		return size
	var scale_ = SCALE_MINIMUM + (SCALE_MAXIMUM - SCALE_MINIMUM) / max_size * size
	#print("set> size to ", size, ", wanted ", size_, " but max is ", max_size, "so scale is ", scale)
	body.mass = scale_
	if false:
		var halb = v3(.5 * scale_)
		shape.size = halb
		particles.process_material.emission_box_extents = halb
		box.scale = v3(scale_)
	else:
		var halb = .5 * scale_
		shape.size.x = halb
		particles.process_material.emission_box_extents.x = halb
		box.scale.x = scale_
		shape.size.y = halb
		particles.process_material.emission_box_extents.y = halb
		box.scale.y = scale_
	return size

func v3(v:float):
	return Vector3(v,v,1+0*v)

# the particle_override_ keeps the sleeping -> once the main has 
# taken over particle state (selection)
func show_particles(value:bool = true, particle_override_:bool = true):
	if particle_override and not particle_override_:
		return
	if particle_override_:
		particle_override = particle_override_
	particles.emitting = value

func go_red():
	animationPlayer.play("redzoned")

func move(force):
	body.apply_central_force(force)

func wakeUp():
	if sleeping and false:
		print("But I was having such a wonderful dream :-(")
	sleeping = false
	# FIXME: none of these work at all :-/
	body.sleeping = false 
	var f = Vector3(0,.1,0)
	body.apply_impulse(f)
	body.apply_central_force(f)

func _am_i_getting_sleepy(delta):
	var debug = false
	var ydiff = abs(body.position.y - lastY) / delta
	if 0 == ydiff:
		return # gross...
	if debug:
		print(entity.name, " is falling ", ydiff, ", threshold is ", sleepyThreshold, ", time is ", sleepyTime, ", max is ", maxSleepiness, ", delta is ", delta)
	lastY = body.position.y
	if ydiff < sleepyThreshold:
		sleepyTime = sleepyTime + delta
		if debug:
			print("getting sleepy...", ydiff, " so ", sleepyTime, " cuz ", delta)
		if sleepyTime > maxSleepiness:
			if debug:
				print("SNORING AIN'T BORING!")
			sleeping = true
			show_particles(false, false)
			main.i_was_so_tired(self)
	else:
		if debug && sleepyTime > 0:
			print("I'm WIDE AWAKE!!! cuz", ydiff, " vs ", abs(body.position.y - lastY), " in ", delta)
		sleepyTime = 0

func remove():
	if not true:
		return main.remove_child(self)
	#print("removing ", entity.name)
	box.set_material(entity[Fof.MATERIAL_COPY])
	Fof.glow(box.material, glow_color, .3)
	await get_tree().create_timer(randf()*.25).timeout
	animationPlayer.play("remove") # TODO: make this less lame

func _on_rigid_body_3d_body_entered(body_):
	main.on_collision(self, body_)

func _on_rigid_body_3d_body_shape_entered(_body_rid, _body, _body_shape_index, _local_shape_index):
	#print("bump...", body_rid, body_, body_shape_index, local_shape_index)
	#print("FALL ", _body.name)
	#sleeping = true
	pass # Replace with function body.

func _on_rigid_body_3d_sleeping_state_changed():
	if body.sleeping:
		sleeping = true
		show_particles(false, false)

func show_me():
	return JSON.stringify(info())

func info():
	return {"size":size, "position": body.position, "entity":entity.name, "type":entity.type, "sleeping":sleeping, "sleepyTime":sleepyTime, "in_bonus_zone":in_bonus_zone}

func _on_animation_player_animation_finished(anim_name):
	if "remove" == anim_name:
		main.remove_child(self)

func _on_red_particles_visibility_changed():
	redder.emitting = redder.is_visible_in_tree() 
	print("RED ", redder.emitting)
