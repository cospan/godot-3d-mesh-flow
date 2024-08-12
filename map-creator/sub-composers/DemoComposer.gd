extends Node

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################
const SUBCOMPOSER_ID = "demo"

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("DemoComposer", LogStream.LogLevel.DEBUG)
var m_debug_count = 0
var m_st:SurfaceTool

#Flags
var m_flag_reset:bool = false

#######################################
# Exports
#######################################
@export var enabled = true


var m_map_db_adapter = null
var m_properties = {"_demo_composer_enable": {"type": "CheckBox", "name" : "Enable Demo Composer", "value": enabled, "callback": _on_property_changed},
                    "_demo_composer_reset" : {"type": "Button",   "name" : "Reset Demo Composer",  "value": enabled, "callback": _on_property_changed}}


##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func setup(map_db_adapter):
    m_logger.debug("Setup Entered!")
    m_map_db_adapter = map_db_adapter

func get_properties():
    return m_properties

func step():
    if m_flag_reset:
        m_flag_reset = false
        var curr_ids = m_map_db_adapter.m_map_data[SUBCOMPOSER_ID].keys()
        for _id in curr_ids:
            m_logger.debug("Removing mesh: %d" % _id)
            m_map_db_adapter.subcomposer_remove_mesh(SUBCOMPOSER_ID, _id)
        m_debug_count = 0

    if enabled and m_debug_count == 0:
        var t = Transform3D()
        m_logger.debug("Demo Composer Enabled!")
        # Create a surface tool to create a new mesh
        # Prepare attributes for add_vertex.
        m_st.clear()

        m_st.begin(Mesh.PRIMITIVE_TRIANGLES)


        m_st.set_normal(Vector3(0, 0, 1))
        m_st.set_uv(Vector2(0, 0))
        # Call last for each vertex, adds the above attributes.
        m_st.add_vertex(Vector3(-1, -1, 1))

        m_st.set_normal(Vector3(0, 0, 1))
        m_st.set_uv(Vector2(0, 1))
        m_st.add_vertex(Vector3(-1, 1, 0))

        m_st.set_normal(Vector3(0, 0, 1))
        m_st.set_uv(Vector2(1, 1))
        m_st.add_vertex(Vector3(1, 1, 0))

        # Creates a quad from four corner vertices.
        # add_index does not need to be called before add_vertex.
        m_st.add_index(0)
        m_st.add_index(1)
        m_st.add_index(2)

        m_st.add_index(1)
        m_st.add_index(3)
        m_st.add_index(2)

        #m_st.generate_normals()
        m_st.generate_tangents()

        # Commit to a mesh.
        var mesh = m_st.commit()
        m_debug_count += 1
        var _id = m_map_db_adapter.subcomposer_add_mesh(SUBCOMPOSER_ID, mesh, t, Color.GREEN)
        m_logger.debug("Adding mesh: %d" % _id)


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    add_to_group("subcomposer")
    add_to_group("map-creator-properties")
    m_st = SurfaceTool.new()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

##############################################################################
# Signal Handler
##############################################################################


func _on_property_changed(property_name, property_value):
    match property_name:
        "_demo_composer_enable":
            m_logger.debug("Demo Composer Enable: %s" % str(property_value))
            enabled = !property_value

        "_demo_composer_reset":
            m_logger.debug("User Reset Demo Composer")
            m_flag_reset = true


