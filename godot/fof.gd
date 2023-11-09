extends Node

# Friend of Foe?
# this class takes care of
# 1. managing textures
# 2. defining friend or foe
# 3. results of match / mismatch

const NAME = "name"
const MATERIAL = "material"
const FOF = "fof"
enum {FRIEND,FOE,SHELTER,WEAPON,ARMOR,ITEM,ERROR}
const DERP = [FRIEND,FOE,SHELTER,WEAPON,ARMOR,ITEM,ERROR]

const FRIEND_LIST = " archer_r archer_w assassin_m bird crossbowman_s frog great_axeman_r great_swordsman_g knight_o lancer_l pikeman_c raider_b short_swordsman_p swordsman_r eagle crow "
const FOE_LIST = " balrog bat behemoth demon demon_flying dragon dragon_flying dragon_transform firedrake ghost giant goblin_axe goblin_spear goblin_sword griffon imp lion lizardman minotaur octopus orc_archer orc_sword sabertooth scorpion serpent spider squirrel swamphaunt wolf "
const SHELTER_LIST = " house inn "
const WEAPON_LIST = " frostgiant_axe "
const ARMOR_LIST = " warhorse "
const ITEM_LIST = ""
const LISTS = [FRIEND_LIST, FOE_LIST, SHELTER_LIST, WEAPON_LIST, ARMOR_LIST, ITEM_LIST]

var images =["res://images/mr-tiles/archer_r.png", "res://images/mr-tiles/archer_w.png", "res://images/mr-tiles/assassin_m.png", "res://images/mr-tiles/balrog.png", "res://images/mr-tiles/bat.png", "res://images/mr-tiles/behemoth.png", "res://images/mr-tiles/bird.png", "res://images/mr-tiles/crossbowman_s.png", "res://images/mr-tiles/crow.png", "res://images/mr-tiles/demon.png", "res://images/mr-tiles/demon_flying.png", "res://images/mr-tiles/dragon.png", "res://images/mr-tiles/dragon_flying.png", "res://images/mr-tiles/dragon_transform.png", "res://images/mr-tiles/eagle.png", "res://images/mr-tiles/firedrake.png", "res://images/mr-tiles/frog.png", "res://images/mr-tiles/frostgiant_axe.png", "res://images/mr-tiles/ghost.png", "res://images/mr-tiles/giant.png", "res://images/mr-tiles/goblin_axe.png", "res://images/mr-tiles/goblin_spear.png", "res://images/mr-tiles/goblin_sword.png", "res://images/mr-tiles/great_axeman_r.png", "res://images/mr-tiles/great_swordsman_g.png", "res://images/mr-tiles/griffon.png", "res://images/mr-tiles/house.png", "res://images/mr-tiles/imp.png", "res://images/mr-tiles/inn.png", "res://images/mr-tiles/knight_o.png", "res://images/mr-tiles/lancer_l.png", "res://images/mr-tiles/lion.png", "res://images/mr-tiles/lizardman.png", "res://images/mr-tiles/minotaur.png", "res://images/mr-tiles/octopus.png", "res://images/mr-tiles/orc_archer.png", "res://images/mr-tiles/orc_sword.png", "res://images/mr-tiles/pikeman_c.png", "res://images/mr-tiles/raider_b.png", "res://images/mr-tiles/sabertooth.png", "res://images/mr-tiles/scorpion.png", "res://images/mr-tiles/serpent.png", "res://images/mr-tiles/short_swordsman_p.png", "res://images/mr-tiles/spider.png", "res://images/mr-tiles/squirrel.png", "res://images/mr-tiles/swamphaunt.png", "res://images/mr-tiles/swordsman_r.png", "res://images/mr-tiles/warhorse.png", "res://images/mr-tiles/wolf.png"]
var entities = {}

func _init():
	var x = RegEx.new()
	x.compile(".*/(.*).png")
	for image in images:
		var entity_name = x.sub(image,"$1")
		entities[entity_name] = _new_entity(entity_name, image)

func _new_entity(entity_name, image):
	var material = _image_to_material(image)
	var leFof = 0
	for list in LISTS:
		var search = " " + entity_name + " "
		if list.contains(search):
			break
		leFof = leFof + 1
	return {NAME:entity_name, MATERIAL:material, FOF:DERP[leFof]}

func _image_to_material(image):
	var material = StandardMaterial3D.new()
	material.set_texture(StandardMaterial3D.TEXTURE_ALBEDO, load(image)) 
	return material

func random_entity():
	var k = entities.keys()
	k.shuffle() # cuz this doesn't return the array :-/
	return entities[k[0]]
