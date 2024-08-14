extends Node


##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("MapDrawer", LogStream.LogLevel.DEBUG)

var m_vector_size:Vector2 = Vector2(0, 0)
var m_module_dict:Dictionary = {}
var m_map_view = null
var m_map_db_adapter = null
var m_map_object_dict:Dictionary = {}
var m_material:ORMMaterial3D

enum STATE_TYPE {
  RESET,
  WORK,
  PROCESS_TILES,
}
var m_state:STATE_TYPE = STATE_TYPE.RESET
var m_sub_composers:Dictionary = {}

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


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_material = ORMMaterial3D.new()
    m_state = STATE_TYPE.RESET
    m_map_db_adapter = $MapDatabaseAdapter

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    match m_state:
        STATE_TYPE.RESET:
            if m_map_db_adapter != null:
                m_logger.debug("Map Database is ready")
                # On the initial load we need to get all the data inserted into the map previously

                var subcomposers = get_tree().get_nodes_in_group("subcomposer")
                for c in subcomposers:
                    m_sub_composers[c.get_name()] = c
                    m_logger.debug("Added Subcomposer: " + c.get_name())
                    c.setup(m_map_db_adapter)
                m_state = STATE_TYPE.WORK
        STATE_TYPE.WORK:
            # All of the subcomposers will update the map data
            for c in m_sub_composers.values():
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
                #_draw_mesh(mesh, transform.origin, transform, modifiers, _id)
                _draw_mesh(mesh, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_TILE:
                var _tile = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Tile: " + str(_tile))
                #_draw_tile(tile, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_LINE:
                var _line = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Line: " + str(_line))
                #_draw_line(line, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_POINT:
                var _point = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Point: " + str(_point))
                #_draw_point(point, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_TEXT:
                var _text = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Text: " + str(_text))
                #_draw_text(text, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_CIRCLE:
                var _circle = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Circle: " + str(_circle))
                #_draw_circle(circle, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_RECT:
                var _rect = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Rect: " + str(_rect))
                #_draw_rect(rect, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.ADD_POLYGON:
                var _polygon = c[1]
                var _transform = c[2]
                var _modifiers = c[3]
                var _id = c[4]
                m_logger.debug("Draw Polygon: " + str(_polygon))
                #_draw_polygon(polygon, transform.origin, transform, modifiers, _id)
            m_map_db_adapter.COMMANDS_T.REMOVE:
                m_logger.debug("Remove Object with ID: " + str(c[1]))
                _remove_object(c[1])


func _draw_mesh(_mesh:Mesh, _transform: Transform3D, _modifiers:Dictionary, _id:int):
    var mi = MeshInstance3D.new()
    mi.mesh = _mesh
    mi.transform = _transform
    if _modifiers != null:
        m_logger.debug("Modifiers: " + str(_modifiers))
        for key in _modifiers.keys():
            match key:
                "color":
                    m_logger.debug("Color: " + str(_modifiers["color"]))
                    m_material.albedo_color = _modifiers["color"]
                    mi.material_override = m_material
    m_map_object_dict[_id] = mi
    m_map_view.add_child(mi)

func _remove_object(_id:int):
    if m_map_object_dict.has(_id):
        var obj = m_map_object_dict[_id]
        m_map_view.remove_child(obj)
        m_map_object_dict.erase(_id)
    else:
        m_logger.error("Object with ID: " + str(_id) + " not found!")
