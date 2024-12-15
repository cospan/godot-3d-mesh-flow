extends Node2D

class_name ComposerBase

##############################################################################
# Signals
##############################################################################
signal remove_composer(String)

##############################################################################
# Constants
##############################################################################
var PROP_LABEL:String
var PROP_ENABLE:String

##############################################################################
# Members
##############################################################################
#var m_logger = LogStream.new("ComposerBase", LogStream.LogLevel.DEBUG)

var m_config = null
var m_map_db_adapter = null
var m_properties = null
var m_popup_menu = null

## Flags ##

##############################################################################
# Scenes
##############################################################################
var m_remove_button = null

##############################################################################
# Exports
##############################################################################
@export var composer_name:String = ""
@export var enabled = true
@export var mesh_layer = 1
#@export var mesh_priority = 1
@export var mesh_mask = 1

##############################################################################
# Public Functions
##############################################################################
func setup(_map_db_adapter, _config):
    m_map_db_adapter = _map_db_adapter
    m_config = _config

func get_properties():
    return m_properties

func step():
    print ("composer Step Function: (OVERRIDE THIS FUNCTION!)")

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


func get_toolbar():
    #m_logger.debug("Get Toolbar Entered!")
    return null

func get_remove_button():
    return m_remove_button

##############################################################################
# Private Functions
##############################################################################
func _remove_all_meshes():
    m_map_db_adapter.remove_all_composer_modules(name)

func _remove_composer():
    if m_map_db_adapter != null:
        _remove_all_meshes()
    if m_config != null:
        if m_config.has_section(name):
            m_config.remove_section(name)
    emit_signal("remove_composer", name)

##############################################################################
# Signal Handlers
##############################################################################

func _ready():
    PROP_LABEL = name + "_label"
    PROP_ENABLE = name + "_enable"
    m_remove_button = Button.new()
    m_remove_button.text = "Remove"
    var stylebox_theme: StyleBoxFlat = StyleBoxFlat.new()
    stylebox_theme.bg_color = Color(0.501961, 0, 0, 1)
    m_remove_button.add_theme_stylebox_override("normal", stylebox_theme)
    m_remove_button.add_theme_stylebox_override("hover", stylebox_theme)
    m_remove_button.add_theme_stylebox_override("pressed", stylebox_theme)
    m_remove_button.pressed.connect(_remove_composer)

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
    add_to_group("composer")
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
        m_popup_menu.add_item("Remove composer", 1)
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
            _remove_composer()
        _:
            pass
