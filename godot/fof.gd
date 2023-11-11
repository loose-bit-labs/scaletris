extends Node

# Friend of Foe?
# this class takes care of
# 1. managing textures
# 2. defining friend or foe
# 3. results of match / mismatch

const NAME = "name"
const MATERIAL = "material"
const TYPE = "type"
const FOF = "fof"
const BESTIARY = "bestiary"
const CHANCE = "chance"
const LEVELS = "levels"
const PICKER = "picker"
const MUSIC = "music"
const BOSS = "boss"

#################################################################################################

const IMAGE_ROOT = "res://images/mr-tiles/"
const IMAGE_EXTENSION = ".png"

const BG_ROOT = "res://images/bg/"

const WORLD_FILE = "res://data/world.json"
var world
var bestiary

#################################################################################################

func _init():
	_load_world()

##########################################################

func _load_world():
	world = _unspace(JSON.parse_string(FileAccess.open(WORLD_FILE, FileAccess.READ).get_as_text()))
	bestiary = _load_bestiary(world[BESTIARY])
	_load_levels(world[LEVELS])

func _load_bestiary(b):
	var lookup = {}
	for type in b:
		var entities = b[type]
		for name_ in entities:
			var entity = entities[name_]
			var resource = IMAGE_ROOT + name_ + IMAGE_EXTENSION
			var material = _image_to_material(resource)
			#print(name_," is a ", type, " gimme ", resource, material)
			entity[NAME] = name_
			entity[TYPE] = type
			entity[MATERIAL] = material
			lookup[name_] = entity # TODO: check collisions
	return lookup

# TODO: load the "name" of level for the fx
func _load_levels(levels):
	for level in levels:
		var chance = level[CHANCE]
		level[PICKER] = _entity_probability(chance)
		level[MATERIAL] = _image_to_material(BG_ROOT+level[NAME]+IMAGE_EXTENSION)
		level[MUSIC] = load("res://audio/music/"+level[MUSIC])

func get_level(level:int = 0):
	level = level if level >= 0 else 0
	level = level if level < world[LEVELS].size() else world[LEVELS].size() - 1
	return world[LEVELS][level]

func _map_count(entity_name, block_map:Dictionary):
	return 0 if entity_name not in block_map else block_map[entity_name].size()

func _forbidden_entities(block_map:Dictionary):
	var no_go = {}
	for entity_name in block_map:
		if block_map[entity_name].size() >= 2:
			no_go[entity_name] = true
	return no_go

func entity_for_level(level_index, block_map = {}):
	var thou_shalt_not = _forbidden_entities(block_map)
	var picker = get_level(level_index)[PICKER]
	var filtered = picker.filter(func(e): return not e[0] in thou_shalt_not)
	if 0 == filtered.size():
		return null
	var previous_sum = picker.reduce(func(accum, e): return accum + e[1], 0)
	var current_sum = filtered.reduce(func(accum, e): return accum + e[1], 0)
	var scale = previous_sum / current_sum
	for e in filtered:
		e[1] *= scale
	filtered[filtered.size()-1][1] = 88
	var r = randf()
	for entry in filtered:
		if entry[1] >= r:
			return entity_by_name(entry[0])
	return entity_by_name(filtered[filtered.size()-1][0])

func entity_by_name(entity_name:String):
	if not entity_name in bestiary:
		print("ERROR: no beasty matches ", entity_name)
	return bestiary[entity_name]

##########################################################

func _image_to_material(image):
	var material = StandardMaterial3D.new()
	material.set_texture(StandardMaterial3D.TEXTURE_ALBEDO, load(image)) 
	return material

# rather than have 10 keys with the same value in the json,
# you can just separate them with spaces: {"a b c":1} -> {a:1,b:1,c:1}
func _unspace(node, path="/"):
	var debug = false
	if debug :
		var ww = "idk"
		if node is Dictionary:
			ww = "dict"
		if node is Array:
			ww = "array"
		print("HI ", path, "! I see you are a ", ww)
	if node is Dictionary:
		var nu = {}
		for k in node:
			var v = _unspace(node[k], path + "/" +k )
			#print("K>",k," : ", v)
			if k.contains(" "):
				if debug:
					print("OH! ", path, "! You also have spaces in '", k, "'! let's split that up!!!")
				for subk in k.split(" "):
					if(debug):
						print(">>, ", path, " SAVE ", subk, " with ", v )
					nu[subk] = v
			else:
				nu[k] = v
		node = nu
	if node is Array:
		for i in range(0,node.size()):
			#print("hi there, butthole! ", i, " is ", node[i])
			node[i] = _unspace(node[i], path + "[" + str(i) + "]")
	return node

##########################################################

# chatGPT + fiddling
func _entity_probability(chance):
	var probably = []
	var sum = 0
	for k in chance:
		var v = chance[k]
		probably.append([k,v])
		sum = sum + v
	probably = probably.map(func(e): return _ep_weak_sauce(e,sum))
	probably.sort_custom(func(a,b): return a[1]<b[1])
	var so_far = 0
	for p in probably:
		var v = p[1]
		p[1] += so_far
		so_far += v
	return probably

func _ep_weak_sauce(e,sum):
	e[1] /= sum
	return e
