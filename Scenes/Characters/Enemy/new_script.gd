@tool
extends EditorScript

# CONFIGURATION
# -------------------------------------------------
# The name of your skeleton node inside the model
const SKELETON_NAME := "Skeleton3D"
# Only replace if the path starts with this (optional)
const SEARCH_STRING := "Skeleton3D:mixamorig_"
# Folder to process (set "" to only modify the current scene)
const TARGET_FOLDER := ""
# -------------------------------------------------


func _run() -> void:
	print("🔧 Starting batch animation track renamer...")

	if TARGET_FOLDER != "":
		_process_folder(TARGET_FOLDER)
	else:
		_process_scene(EditorInterface.get_edited_scene_root())

	print("✅ Batch rename complete!")


func _process_folder(folder_path: String) -> void:
	var dir := DirAccess.open(folder_path)
	if not dir:
		push_error("❌ Cannot open folder: %s" % folder_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_process_folder(folder_path.path_join(file_name))
		elif file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
			var scene_path = folder_path.path_join(file_name)
			print("📂 Processing scene:", scene_path)
			var packed_scene: PackedScene = load(scene_path)
			if packed_scene:
				var root = packed_scene.instantiate()
				_process_scene(root)
		file_name = dir.get_next()

	dir.list_dir_end()


func _process_scene(root: Node) -> void:
	if root == null:
		return

	for anim_player in root.get_children():
		_process_node_recursive(anim_player)


func _process_node_recursive(node: Node) -> void:
	if node is AnimationPlayer:
		_rename_tracks_in_player(node)
	for child in node.get_children():
		_process_node_recursive(child)


func _rename_tracks_in_player(anim_player: AnimationPlayer) -> void:
	print("🎞️  Found AnimationPlayer:", anim_player.name)

	for anim_name in anim_player.get_animation_list():
		var anim: Animation = anim_player.get_animation(anim_name)
		var modified := false

		for i in anim.get_track_count():
			var old_path: NodePath = anim.track_get_path(i)
			var old_str := str(old_path)

			# Example renaming logic:
			# Add Skeleton3D: before bone name if missing
			if SEARCH_STRING in old_str:
				var bone_str = old_str.split("_")
				print(bone_str[1])
				var new_str = "%s:%s" % [SEARCH_STRING, bone_str[1]]
				anim.track_set_path(i, NodePath(new_str))
				print("  🦴 Renamed:", old_str, "→", new_str)
				modified = true

		if modified:
			print("  💾 Updated animation:", anim_name)
			ResourceSaver.save(anim, anim.resource_path)
