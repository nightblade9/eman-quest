extends Node

const AreaType = preload("res://Scripts/Enums/AreaType.gd")
const Boss = preload("res://Entities/Battle/Boss.gd")
const MapNameLabel = preload("res://Scenes/UI/MapNameLabel.tscn")
const MemoryTileBattleScene = preload("res://Scenes/Battle/MemoryTileBattleScene.tscn")
const StreamlinedRecallBattleScene = preload("res://Scenes/Battle/StreamlinedRecall/StreamlinedRecallBattleScene.tscn")
const PopulatedMapScene = preload("res://Scenes/PopulatedMapScene.tscn")
const TweenHelper = preload("res://Scripts/TweenHelper.gd")

# Polymorphic. Target can be a type (eg. "Forest") or a submap.
static func change_map_to(tree, target):
	_remove_monster_instances()
	
	# Create map instance
	var map_type = target
	
	if typeof(target) != TYPE_STRING:
		map_type = Globals.current_map.map_type
		
	var map_data = Globals.maps[map_type]
	var target_areamap
	
	if typeof(target) == TYPE_STRING:
		target_areamap = map_data
		
		if typeof(map_data) == TYPE_ARRAY:
			for map in map_data:
				if map.area_type == AreaType.ENTRANCE:
					target_areamap = map
					break
	else:
		# probably an array of submap(s). Or if loading, could be the overworld.
		if typeof(map_data) == TYPE_ARRAY:
			for map in map_data:
				if map.grid_x == target.grid_x and map.grid_y == target.grid_y:
					target_areamap = map
					break
		else:
			target_areamap = map_data
	
	var show_map_name = (
		# Globals.current_map is ull on new game
		Globals.current_map == null or 
		# change map type, not change to submap of the same type
		Globals.current_map.map_type != target_areamap.map_type)
		
	var populated_map = PopulatedMapScene.instance()
	populated_map.initialize(target_areamap)
	
	change_scene_to(tree, populated_map)
	Globals.current_map_scene = populated_map
	
	if show_map_name:
		var map_name_label = MapNameLabel.instance()
		map_name_label.show_map_name(target_areamap)
		
		# Center, 100px from top
		var container = CenterContainer.new()
		container.name = "Fade Container"
		container.set_anchors_and_margins_preset(Control.PRESET_CENTER_TOP)
		container.margin_top += 100
		
		# Add to scene
		var root = tree.get_root()
		var current_scene = root.get_child(root.get_child_count() - 1)
		var ui = current_scene.get_node("UI")
		ui.add_child(container)
		container.add_child(map_name_label)
		
		# Wait 3s, then fade over 1s
		var tween_helper = TweenHelper.new().fade_out(current_scene, container, 1)
		var timer = Timer.new()
		timer.wait_time = 5.0
		timer.connect("timeout", tween_helper, "start")
		timer.start()
		current_scene.add_child(timer)
	
	if map_type == "Overworld":
		var camera = Globals.player.get_node("Camera2D")
		# zoom of 2 = 50%
		# TODO: tween
		camera.zoom.x = 2
		camera.zoom.y = 2
	
# Make it the current scene. Necessary to keep the type.
# If we use change_scene, it becomes a Node2D, not an AreaMap.
static func change_scene_to(tree, scene_instance):
	_remove_monster_instances()
	
	# http://docs.godotengine.org/en/3.0/getting_started/step_by_step/singletons_autoload.html?highlight=change_scene
	var root = tree.get_root()
	var current_scene = root.get_child(root.get_child_count() - 1)
	call_deferred("_free_current_scene", current_scene)
	
	current_scene = scene_instance
	tree.get_root().add_child(current_scene)
	# Optional, to make it compatible with the SceneTree.change_scene() API.
	tree.set_current_scene(current_scene)

static func switch_to_battle_if_touched_player(monster, body):
	if body == Globals.player and Globals.player.can_fight():
		
		# Reset state of last battle's results
		Globals.pre_battle_position = [Globals.player.position.x, Globals.player.position.y]
		Globals.won_battle = false
		
		# Keep a list of monsters to restore after battle
		Globals.previous_monsters = Globals.current_map_scene.get_monsters()
		# Keep track of who to remove if we won
		Globals.current_monster_type = monster.data_object["data"]["type"]
		Globals.current_monster = monster.data_object
		
		if monster.data_object is Boss:
			Globals.battle_spoils = Globals.current_monster.key_item
		
		var battle_scene = null
		if Features.is_enabled("streamlined battles"):
			battle_scene = StreamlinedRecallBattleScene.instance()
		else:
			battle_scene = MemoryTileBattleScene.instance()
			
		battle_scene.set_monster_data(monster.data_object["data"].duplicate())
		change_scene_to(monster.get_tree(), battle_scene)

static func _free_current_scene(scene):
	scene.free()

static func _remove_monster_instances():
	if Globals.current_map != null:
		# GCed. Don't leave deleted objects around. If you do, the next
		# time you save (iterate all maps/submaps and save objects), you
		# run into [deleted, deleted, ...] which crashes.
		Globals.current_map.monsters = {}
