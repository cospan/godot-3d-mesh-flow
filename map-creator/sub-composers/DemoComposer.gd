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

#######################################
# Exports
#######################################
@export var enabled = true


var m_map_db_adapter = null
var m_properties = {"_demo_composer_enable": {"type": "CheckBox", "name" : "Enable Demo Composer", "value": enabled, "callback": _on_property_changed}}


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
    if enabled and m_debug_count == 0:
        var t = Transform3D()
        m_logger.debug("Demo Composer Enabled!")

        var vertices  := PackedVector3Array(
          [
            Vector3(0, 1, 0),
            Vector3(1, 1, 0),
            Vector3(1, 1, 1),
            Vector3(0, 1, 1),

            Vector3(0, 0, 0),
            Vector3(1, 0, 0),
            Vector3(1, 0, 1),
            Vector3(0, 0, 1)
          ]
        )

        var indices := PackedInt32Array(
          [
            0, 1, 2,
            0, 2, 3,
            3, 2, 7,
            2, 6, 7,
            2, 1, 6,
            1, 5, 6,
            1, 4, 5,
            1, 0, 4,
            0, 3, 7,
            4, 0, 7,
            6, 5, 4,
            4, 7, 6
          ]
        )


        # Create a surface tool to create a new mesh
        # Prepare attributes for add_vertex.
        m_st.clear()

        m_st.begin(Mesh.PRIMITIVE_TRIANGLES)

        m_st.set_uv(Vector2(0, 0))
        m_st.add_vertex(vertices[0])

        m_st.set_uv(Vector2(0, 1))
        m_st.add_vertex(vertices[1])

        m_st.set_uv(Vector2(1, 1))
        m_st.add_vertex(vertices[2])

        m_st.set_uv(Vector2(1, 0))
        m_st.add_vertex(vertices[3])


        m_st.set_uv(Vector2(0, 0))
        m_st.add_vertex(vertices[4])

        m_st.set_uv(Vector2(0, 1))
        m_st.add_vertex(vertices[5])

        m_st.set_uv(Vector2(1, 1))
        m_st.add_vertex(vertices[6])

        m_st.add_vertex(vertices[7])


        # Creates a quad from four corner vertices.
        # add_index does not need to be called before add_vertex.
        for i in range(indices.size()):
            m_st.add_index(indices[i])

        m_st.generate_normals()
        #m_st.generate_tangents()

        # Commit to a mesh.
        var mesh = m_st.commit()
        m_debug_count += 1
        m_map_db_adapter.subcomposer_add_mesh(SUBCOMPOSER_ID, mesh, t, Color.GREEN)


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
    m_logger.debug("Property Changed: %s = %s" % [property_name, property_value])
