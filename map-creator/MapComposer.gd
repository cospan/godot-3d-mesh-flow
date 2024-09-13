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
const PROP_DRAW_REFERENCE:String = "Draw Reference"


##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("MapDrawer", LogStream.LogLevel.INFO)

var m_vector_size:Vector2 = Vector2(0, 0)
var m_module_dict:Dictionary = {}
var m_map_view = null
var m_map_db_adapter = null
var m_map_object_dict:Dictionary = {}
var m_seleted_mesh_instance = null
@onready var m_outline_shader = load(OUTLINE_SHADER_PATH)
#var m_material:ORMMaterial3D

enum STATE_TYPE {
  RESET,
  WORK,
  PROCESS_TILES,
}
var m_state:STATE_TYPE = STATE_TYPE.RESET
var m_subcomposers:Dictionary = {}
var m_properties:Dictionary = {}
var m_ref_sphere = null

## Flags ##
var m_flag_collisions_enabled = true
var m_flag_edit_mode = true
var m_draw_reference = false

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################
@export var OUTLINE_SHADER_PATH:String = "res://shaders/outline.gdshader"

##############################################################################
# Public Functions
##############################################################################

func set_map_view(map_view):
    if m_map_view == null:
        map_view.null_selected.connect(_deselect_target)
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
        },
        PROP_DRAW_REFERENCE: {
            "type": "CheckBox",
            "name": "Draw Reference",
            "value": m_draw_reference,
            "callback": _on_property_changed,
            "tooltip": "Draw the reference grid"
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
        m_logger.debug("  Command: %s" % str(c))
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
    var ormm = ORMMaterial3D.new()
    var sm = ShaderMaterial.new()
    sm.shader = m_outline_shader
    sm.set_shader_parameter("color", Color(1.0, 0.0, 0.0, 1.0))
    sm.set_shader_parameter("border_width", 0.01)

    ormm.albedo_color = mi.mesh.surface_get_material(0).albedo_color
    ormm.next_pass = sm
    mi.material_override = ormm

    if m_flag_collisions_enabled:
        var collision_body
        if m_flag_edit_mode:
            collision_body = Area3D.new()
            collision_body.monitoring = true
            collision_body.area_shape_entered.connect(func(_area_rid, area_shape, _area_shape_idx, _local_shape_idx): \
              _on_area_shape_entered(mi, area_shape.get_parent()))
        else:
            collision_body = StaticBody3D.new()

        var collision_shape = _mesh.create_convex_shape()

        var collision_shape_3d = CollisionShape3D.new()
        collision_shape_3d.shape = collision_shape

        mi.add_child(collision_body)
        collision_body.add_child(collision_shape_3d)
        collision_body.input_event.connect(func(_camera, _event, _pos, _normal, _shape_idx):  \
                                            if _event is InputEventMouseButton and _event.pressed: \
                                                _set_target(mi, sm))
        collision_body.collision_layer = _modifiers["layer"]
        collision_body.collision_mask = _modifiers["mask"]

    m_map_object_dict[_id] = mi
    m_map_view.add_child(mi)

func _set_target(target:Node3D, sm:ShaderMaterial):
    m_logger.debug("Setting Target: %s" % str(target))
    m_map_view.set_target(target)
    sm.set_shader_parameter("enable", true)
    if m_seleted_mesh_instance != null:
        m_seleted_mesh_instance.material_override.next_pass.set_shader_parameter("enable", false)
    m_seleted_mesh_instance = target

func _deselect_target():
    if m_seleted_mesh_instance != null:
        m_seleted_mesh_instance.material_override.next_pass.set_shader_parameter("enable", false)
        m_seleted_mesh_instance = null

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
        PROP_DRAW_REFERENCE:
            m_draw_reference = property_value
            if m_draw_reference:
                if m_ref_sphere == null:
                    var ref_sphere = SphereMesh.new()
                    m_ref_sphere = MeshInstance3D.new()
                    m_ref_sphere.mesh = ref_sphere
                    m_map_view.add_child(m_ref_sphere)
            else:
                if m_ref_sphere != null:
                    m_map_view.remove_child(m_ref_sphere)
                    m_ref_sphere = null
            m_logger.debug("Draw Reference: " + str(m_draw_reference))


func _on_area_shape_entered(local_mesh_instance, other_mesh_instance):
    #m_logger.debug("Area Shape Entered: " + str(local_mesh_instance) + " " + str(other_mesh_instance))
    #m_logger.debug("  Mesh IDs: " + str(local_mesh_instance.get_meta("id")) + " " + str(other_mesh_instance.get_meta("id")))
    var local_id = local_mesh_instance.get_meta("id")
    #var other_id = other_mesh_instance.get_meta("id")
    var local_subcomposer_name = m_map_db_adapter.get_subcomposer_name(local_id)
    if len(local_subcomposer_name) == 0:
        m_logger.warn("No Subcomposer Name Found for ID: " + str(local_id))
        assert(false)
        return
    #var other_subcomposer_name = m_map_db_adapter.get_subcomposer_name(other_id)
    #m_logger.debug("  Subcomposer Names: " + local_subcomposer_name + " " + other_subcomposer_name)
    var local_subcomposer = m_subcomposers[local_subcomposer_name]
    #var other_subcomposer = m_subcomposers[other_subcomposer_name]
    local_subcomposer.test_collision(local_mesh_instance, other_mesh_instance)

func _unhandled_input(event: InputEvent) -> void:
    if m_seleted_mesh_instance == null:
        return
    var translation = Vector3(0, 0, 0)
    if event.is_action_pressed("forward"):
        translation.z = -1
    if event.is_action_pressed("back"):
        translation.z = 1
    if event.is_action_pressed("left"):
        translation.x = -1
    if event.is_action_pressed("right"):
        translation.x = 1

    m_seleted_mesh_instance.translate(translation)
    #m_map_view.force_update_transform()
    #m_map_view.get_world_3d().space.update()
