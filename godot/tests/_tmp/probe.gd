extends Node
func _ready() -> void:
	var m: Node3D = (load("res://models/hero.glb") as PackedScene).instantiate()
	add_child(m)
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	print("PATH ", ap.get_node(ap.root_node).get_path_to(sk))
	print("BONES ", sk.get_bone_count(), " first ", sk.get_bone_name(0), " ", sk.get_bone_name(1))
	for n in ["LeftArm", "LeftForeArm", "LeftHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "Hips", "Head"]:
		var b := PoseLib.bone(sk, n)
		print("REST ", n, " ", sk.get_bone_global_rest(b).origin.snapped(Vector3.ONE * 0.01))
	var a := ap.get_animation("Combat_Stance")
	print("TRACK0 ", a.track_get_path(0))
	print("SKX ", sk.global_transform.basis.get_scale(), " model rot ", m.rotation)
	get_tree().quit()
