extends Node3D

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Collision Tester", LogStream.LogLevel.DEBUG)

## Flags ##

##############################################################################
# Scenes
##############################################################################
var m_m1
var m_cb1

var m_m2
var m_cb2
var m_speed = 4.0
var m_velocity = Vector3.ZERO

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

##############################################################################
# Private Functions
##############################################################################

##############################################################################
# Signal Handlers
##############################################################################



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    m_m1 = $MeshInstance3D
    m_cb1 = $MeshInstance3D/Area3D
    m_m2 = $MeshInstance3D2
    m_cb2 = $MeshInstance3D2/Area3D
    #m_cb1.input_event.connect(self, "_on_collision_event")


#func _on_collision_event(_camera, _event, _pos, _normal, _shape_idx)


func _on_area_3d_area_shape_entered(_area_rid: RID, _area: Area3D, _area_shape_index: int, _local_shape_index: int) -> void:
    m_logger.debug("Collision detected")


func _on_area_3d_area_entered(_area: Area3D) -> void:
    m_logger.debug("Collision detected")
