@tool
extends Node3D
class_name AdventureShieldMount
## Put this node under a BoneAttachment3D and shield mesh under this node.
## Offset is local to bone; adjust in inspector while previewing the pose.
@export var offset_meters := Vector3(0.0, 0.10, 0.10):
    set(value):
        offset_meters = value
        position = value
@export var rotation_degrees_offset := Vector3.ZERO:
    set(value):
        rotation_degrees_offset = value
        rotation_degrees = value

func _ready() -> void:
    position = offset_meters
    rotation_degrees = rotation_degrees_offset
