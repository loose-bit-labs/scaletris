extends Node3D

@onready var collision : CollisionShape3D = $RigidBody3D/CollisionShape3D
@onready var body : RigidBody3D = $RigidBody3D
@onready var box : CSGBox3D = $RigidBody3D/CollisionShape3D/Box
var shape : BoxShape3D = null
var main = null

var size = 1
var index = -1

# TODO: needs tuning!
# sleeping or mostly sleeping
var sleeping = false
var lastY = 88
var sleepyCount = 0
const maxSleepiness = 3
const sleepyThreshold = 3.3

const SCALE_MINIMUM = .8
const SCALE_MAXIMUM = 2


# Called when the node enters the scene tree for the first time.
func _ready():
	# don't share the collision shape!
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(.5,.5,.5)
	shape = collision.shape

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !sleeping:
		_am_i_getting_sleepy(delta)

func configure(main_, position_:Vector3, spin:Vector3, gravity:float, material:StandardMaterial3D):
	self.main = main_
	position = position_
	body.angular_velocity = spin
	body.gravity_scale = gravity
	box.set_material(material) 

func update_size(size_change:int, max_size:int):
	set_size(clamp(size + size_change, 0, max_size), max_size)
	
func set_size(size_:int, max_size:int):
	size = size_
	var scale_ = SCALE_MINIMUM + (SCALE_MAXIMUM - SCALE_MINIMUM) / max_size * size
	#print("size: ", size, " of ", max_size, " -> ", scale )
	body.mass = scale_
	# the box that collides
	shape.size.x = .5 * scale_
	shape.size.y = .5 * scale_
	# the box you see
	box.scale.x = scale_
	box.scale.y = scale_

func move(force):
	body.apply_central_force(force)

func wakeUp():
	if sleeping:
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
	lastY = body.position.y
	if ydiff < sleepyThreshold:
		sleepyCount = sleepyCount + delta
		if debug:
			print("getting sleepy...", ydiff, " so ", sleepyCount, " cuz ", delta)
		if sleepyCount > maxSleepiness:
			if debug:
				print("SNORING AIN'T BORING!")
			sleeping = true
	else:
		if debug && sleepyCount > 0:
			print("I'm WIDE AWAKE!!! cuz", ydiff, " vs ", abs(body.position.y - lastY), " in ", delta)
		sleepyCount = 0

func _on_rigid_body_3d_body_entered(body_):
	main.on_collision(self, body_)

func _on_rigid_body_3d_body_shape_entered(_body_rid, _body, _body_shape_index, _local_shape_index):
	#print("finally...", body_rid, body_, body_shape_index, local_shape_index)
	pass # Replace with function body.


func _on_rigid_body_3d_sleeping_state_changed():
	if body.sleeping:
		sleeping = true
