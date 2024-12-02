extends Node2D

class_name SubComposerBase

##############################################################################
# Signals
##############################################################################
signal remove_subcomposer(String)

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
var m_popup_menu = null

## Flags ##

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################
@export var subcomposer_name:String = ""
@export var enabled = true
@export var mesh_layer = 1
#@export var mesh_priority = 1
@export var mesh_mask = 1

##############################################################################
# Public Functions
##############################################################################
func setup(map_db_adapter):
    m_map_db_adapter = map_db_adapter

func get_properties():
    return m_properties


func step():
    print ("SubComposer Step Function: (OVERRIDE THIS FUNCTION!)")

func test_collision(local_mesh:MeshInstance3D, other_mesh:MeshInstance3D):
    for c in local_mesh.get_children():
        if c is CollisionObject3D:
            break
    for c in other_mesh.get_children():
        if c is CollisionObject3D:
            break
    collision(local_mesh, other_mesh)

func collision(local_mesh:MeshInstance3D, other_mesh:MeshInstance3D):
    print ("%s: COLLISION: %s -> %s" % [name, local_mesh.name, other_mesh.name])
    print ("OVERRIDE THIS FUNCTION!")

##############################################################################
# Private Functions
##############################################################################
func _remove_all_meshes():
    # Remove all previous meshes
    m_map_db_adapter.remove_all_subcomposer_modules(name)
    #if m_map_db_adapter.m_map_dict.has(name):
    #    var m_dict = m_map_db_adapter.m_map_dict[name]
    #    for k in m_dict.keys():
    #        m_map_db_adapter.subcomposer_remove_mesh(name, k)

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
          "right_click_menu": _on_property_right_click
        },
        PROP_ENABLE:
        {
          "type": "CheckBox",
          "name" : "Enable",
          "value": enabled,
          "callback": _on_property_changed,
          "tooltip": "Enable " + name
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


func _on_property_right_click():
    # Create a popup menu
    if m_popup_menu == null:
        m_popup_menu = PopupMenu.new()
        m_popup_menu.add_item("Remove SubComposer", 1)
        m_popup_menu.id_pressed.connect(_on_popup_menu_selected)
        m_popup_menu.set_position(get_global_mouse_position())
        m_popup_menu.mouse_exited.connect(_on_popup_leave_focus)
        add_child(m_popup_menu)
    m_popup_menu.popup()

func _on_popup_leave_focus():
    m_popup_menu.hide()

func _on_popup_menu_selected(id):
    match id:
        1:
            if m_map_db_adapter != null:
                _remove_all_meshes()
            emit_signal("remove_subcomposer", name)
        _:
            pass
