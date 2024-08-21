extends Node


##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

const PROP_LABEL:String = "Map Composer"
const PROP_COLLISIONS:String = "Collisions"
const PROP_EDIT_MODE:String = "Building Mode"


##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("MapDrawer", LogStream.LogLevel.DEBUG)

var m_vector_size:Vector2 = Vector2(0, 0)
var m_module_dict:Dictionary = {}
var m_map_view = null
var m_map_db_adapter = null
var m_map_object_dict:Dictionary = {}
#var m_material:ORMMaterial3D

enum STATE_TYPE {
  RESET,
  WORK,
  PROCESS_TILES,
}
var m_state:STATE_TYPE = STATE_TYPE.RESET
var m_subcomposers:Dictionary = {}
var m_properties:Dictionary = {}

## Flags ##
var m_flag_collisions_enabled = true
var m_flag_edit_mode = true

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func set_map_view(map_view):
    m_map_view = map_view

func set_map_database_adapter(map_database_adapter):
    m_map_db_adapter = map_database_adapter

func set_tile_size(tile_size:Vector2):
    m_vector_size = tile_size

func set_module_dict(module_dict:Dictionary):
    m_module_dict = module_dict

func get_properties():
    m_properties = {
        PROP_LABEL: {
            "type": "Label",
            "name": "",
            "value": "Map Composer",
        },
        PROP_COLLISIONS: {
            "type": "CheckBox",
            "name": "Collisions",
            "value": m_flag_collisions_enabled,
            "callback": _on_property_changed,
            "tooltip": "Enable Collisions"
        },
        PROP_EDIT_MODE: {
            "type": "CheckBox",
            "name": "Edit Mode",
            "value": m_flag_edit_mode,
            "callback": _on_property_changed,
            "tooltip": "When disabled the map can be interacted with by user, when enabled the map is locked for editing."
        }
    }
    return m_properties

##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    #m_material = ORMMaterial3D.new()
    m_state = STATE_TYPE.RESET
    m_map_db_adapter = $MapDatabaseAdapter
    add_to_group("map-creator-properties")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    match m_state:
        STATE_TYPE.RESET:
            if m_map_db_adapter != null:
                m_logger.debug("Map Database is ready")
                # On the initial load we need to get all the data inserted into the map previously

                var subcomposers = get_tree().get_nodes_in_group("subcomposer")
                for c in subcomposers:
                    m_subcomposers[c.get_name()] = c
                    m_logger.debug("Added Subcomposer: " + c.get_name())
                    c.setup(m_map_db_adapter)
                m_state = STATE_TYPE.WORK
        STATE_TYPE.WORK:
            # All of the subcomposers will update the map data
            for c in m_subcomposers.values():
                c.step()
            # The subcomposers have inserted commands to process
            _process_map_data()
        STATE_TYPE.PROCESS_TILES:
            pass

func _process_map_data():
    var commands = m_map_db_adapter.composer_read_step_commands()
    for c in commands:
        match c[0]:
            m_map_db_adapter.COMMANDS_T.ADD_MESH:
                var mesh = c[1]
                var transform = c[2]
                var modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Mesh: " + str(mesh))
                #_process_mesh(mesh, transform.origin, transform, modifiers, _id)
                _process_mesh(mesh, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_TILE:
                var _tile = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Tile: " + str(_tile))
                #_process_tile(tile, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_LINE:
                var _line = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Line: " + str(_line))
                #_process_line(line, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_POINT:
                var _point = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Point: " + str(_point))
                #_process_point(point, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_TEXT:
                var _text = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Text: " + str(_text))
                #_process_text(text, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_CIRCLE:
                var _circle = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Circle: " + str(_circle))
                #_process_circle(circle, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_RECT:
                var _rect = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Rect: " + str(_rect))
                #_process_rect(rect, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_POLYGON:
                var _polygon = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Polygon: " + str(_polygon))
                #_process_polygon(polygon, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.REMOVE:
                m_logger.debug("Remove Object with ID: " + str(c[1]))
                _remove_object(c[1])


func _process_mesh(_mesh:Mesh, _transform: Transform3D, _modifiers:Dictionary, _id:int):
    var mi = MeshInstance3D.new()
    mi.mesh = _mesh
    mi.set_meta("id", _id)
    mi.transform = _transform
    if _modifiers != null:
        m_logger.debug("Modifiers: " + str(_modifiers))
        for key in _modifiers.keys():
            match key:
                "color":
                    m_logger.debug("Color: " + str(_modifiers["color"]))
                    var mat = ORMMaterial3D.new()
                    mat.albedo_color = _modifiers["color"]
                    mi.material_override = mat
    if m_flag_collisions_enabled:
        var collision_body
        if m_flag_edit_mode:
            collision_body = Area3D.new()
            collision_body.monitoring = true
            collision_body.area_shape_entered.connect(func(area_rid, area_shape, area_shape_idx, local_shape_idx): \
              _on_area_shape_entered(mi, area_shape.get_parent()))
        else:
            collision_body = StaticBody3D.new()

        var collision_shape = CollisionShape3D.new()
        var box_shape = BoxShape3D.new()
        box_shape.size = mi.mesh.get_aabb().size
        collision_shape.shape = box_shape

        mi.add_child(collision_body)
        collision_body.add_child(collision_shape)
        collision_body.input_event.connect(func(_camera, _event, _pos, _normal, _shape_idx):  \
                                            if _event is InputEventMouseButton and _event.pressed: \
                                                m_map_view.set_target(mi))
        collision_body.collision_layer = _modifiers["layer"]
        collision_body.collision_priority = _modifiers["priority"]


    m_map_object_dict[_id] = mi
    m_map_view.add_child(mi)

func _remove_object(_id:int):
    if m_map_object_dict.has(_id):
        var obj = m_map_object_dict[_id]
        if obj is Array:
            for o in obj:
                m_map_view.remove_child(o)
        else:
            m_map_view.remove_child(obj)
        m_map_object_dict.erase(_id)
    else:
        m_logger.error("Object with ID: " + str(_id) + " not found!")

func _on_property_changed(property_name, property_value):
    match property_name:
        PROP_COLLISIONS:
            m_flag_collisions_enabled = property_value
            m_logger.debug("Collisions Enabled: " + str(m_flag_collisions_enabled))


func _on_area_shape_entered(local_mesh_instance, other_mesh_instance):
    #m_logger.debug("Area Shape Entered: " + str(local_mesh_instance) + " " + str(other_mesh_instance))
    #m_logger.debug("  Mesh IDs: " + str(local_mesh_instance.get_meta("id")) + " " + str(other_mesh_instance.get_meta("id")))
    var local_id = local_mesh_instance.get_meta("id")
    var other_id = other_mesh_instance.get_meta("id")
    var local_subcomposer_name = m_map_db_adapter.get_subcomposer_name(local_id)
    var other_subcomposer_name = m_map_db_adapter.get_subcomposer_name(other_id)
    #m_logger.debug("  Subcomposer Names: " + local_subcomposer_name + " " + other_subcomposer_name)
    var local_subcomposer = m_subcomposers[m_map_db_adapter.get_subcomposer_name(local_id)]
    var other_subcomposer = m_subcomposers[m_map_db_adapter.get_subcomposer_name(other_id)]
    local_subcomposer.test_collision(local_mesh_instance, other_mesh_instance)
