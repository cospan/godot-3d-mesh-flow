extends Node2D

class_name SubComposerBase

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################
var PROP_LABEL:String
var PROP_ENABLE:String

##############################################################################
# Members
##############################################################################
#var m_logger = LogStream.new("SubComposerBase", LogStream.LogLevel.DEBUG)

var m_map_db_adapter = null
var m_properties = null

## Flags ##

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################
@export var enabled = true
@export var mesh_layer = 1
@export var mesh_priority = 1

##############################################################################
# Public Functions
##############################################################################
func setup(map_db_adapter):
    m_map_db_adapter = map_db_adapter

func get_properties():
    return m_properties


func step():
    print ("OVERRIDE THIS FUNCTION!")

func test_collision(local_mesh:MeshInstance3D, other_mesh:MeshInstance3D):
    var local_collision_object
    var other_collision_object
    for c in local_mesh.get_children():
        if c is CollisionObject3D:
            local_collision_object = c
            break
    for c in other_mesh.get_children():
        if c is CollisionObject3D:
            other_collision_object = c
            break
    if local_collision_object.collision_layer != other_collision_object.collision_mask:
        return
    if (local_collision_object.collision_mask & (1 << (other_collision_object.collision_layer - 1))) == 0:
        return
    if local_collision_object.collision_priority >= other_collision_object.collision_priority:
        return
    collision(local_mesh, other_mesh)

func collision(local_mesh:MeshInstance3D, other_mesh:MeshInstance3D):
    print ("%s: COLLISION: %s -> %s" % [name, local_mesh.name, other_mesh.name])
    print ("OVERRIDE THIS FUNCTION!")

##############################################################################
# Private Functions
##############################################################################
func _remove_all_meshes():
    # Remove all previous meshes
    if m_map_db_adapter.m_map_dict.has(name):
        var m_dict = m_map_db_adapter.m_map_dict[name]
        for k in m_dict.keys():
            m_map_db_adapter.subcomposer_remove_mesh(name, k)

##############################################################################
# Signal Handlers
##############################################################################

func _ready():
    PROP_LABEL = name + "_label"
    PROP_ENABLE = name + "_enable"

    m_properties = {
        PROP_LABEL:
        {
          "type": "Label",
          "name": "",
          "value": name,
        },
        PROP_ENABLE:
        {
          "type": "CheckBox",
          "name" : "Enable",
          "value": enabled,
          "callback": _on_property_changed,
          "tooltip": name + ": Enable Composer"
        }
    }
    add_to_group("subcomposer")
    add_to_group("map-creator-properties")


func _on_property_changed(property_name, property_value):
    #m_logger.debug("Property Changed For %s: %s = %s" % [name, property_name, property_value])
    match property_name:
        PROP_ENABLE:
            enabled = property_value
            if not enabled:
                if m_map_db_adapter != null:
                    _remove_all_meshes()
