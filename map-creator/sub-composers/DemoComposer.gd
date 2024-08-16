extends Node

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

enum DRAW_TYPE {
    BOX,
    TERRAIN
}
var m_draw_type = DRAW_TYPE.BOX

var PROP_LABEL:String
var PROP_ENABLE:String
var PROP_DRAW_SELECT:String
##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("DemoComposer", LogStream.LogLevel.DEBUG)
var m_st:SurfaceTool

var m_flag_reset = false

#######################################
# Exports
#######################################
@export var enabled = true
@export var mesh_color:Color = Color.GREEN
@export var mesh_layer = 0
@export var mesh_priority = 0


var m_map_db_adapter = null
var m_properties = null
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
    if enabled:
        # Remove all previous meshes
        if m_map_db_adapter.m_map_data.has(name):
            var m_dict = m_map_db_adapter.m_map_data[name]
            for k in m_dict.keys():
                m_map_db_adapter.subcomposer_remove_mesh(name, k)
        enabled = false
        match m_draw_type:
            DRAW_TYPE.BOX:
                draw_box()
            DRAW_TYPE.TERRAIN:
                draw_terrain()

func draw_terrain():

    var TERRAIN_WIDTH = 10
    var TERRAIN_HEIGHT = 10
    var TERRAIN_SIZE = 1

    var TERRAIN_X_OFFSET = -(TERRAIN_WIDTH / 2)
    var TERRAIN_Z_OFFSET = -(TERRAIN_WIDTH / 2)

    var t = Transform3D()

    m_st.clear()
    m_st.begin(Mesh.PRIMITIVE_TRIANGLES)

    for z in TERRAIN_HEIGHT + 1:
        for x in TERRAIN_WIDTH + 1:
        # Create a percent of the terain starting from -TERAIN_SIZE / 2 to TERRAIN_SIZE / 2
            var percent_x = float(x) / float(TERRAIN_WIDTH)
            #m_logger.debug("Percent X: %s" % percent_x)
            var percent_z = float(z) / float(TERRAIN_HEIGHT)
            #m_logger.debug("Percent Z: %s" % percent_z)
            m_st.set_uv(Vector2(percent_x, percent_z))
            # Geta random y value between -1 and 1
            var y = randf_range(-1, 1)
            m_st.add_vertex(Vector3(x + TERRAIN_X_OFFSET, y, z + TERRAIN_Z_OFFSET))


    # Now that we have all these vertices we need to create the triangles
    for z in range(0, TERRAIN_HEIGHT):
        for x in range(0,  TERRAIN_WIDTH):
            var vert = z * TERRAIN_WIDTH + x
            m_st.add_index(vert + 0)
            m_st.add_index(vert + 1)
            m_st.add_index(vert + TERRAIN_WIDTH + 1)

            m_st.add_index(vert + 0)
            m_st.add_index(vert + TERRAIN_WIDTH + 1)
            m_st.add_index(vert + TERRAIN_WIDTH)

    m_st.generate_normals()

    # Commit to a mesh.
    var mesh = m_st.commit()
    m_map_db_adapter.subcomposer_add_mesh(name, mesh, t, {"color":mesh_color})

func draw_box():
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
    m_map_db_adapter.subcomposer_add_mesh(name, mesh, t, {"color":mesh_color})


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!: Name: %s" % name)

    PROP_LABEL = name + "_label"
    PROP_ENABLE = name + "_demo_composer_enable"
    PROP_DRAW_SELECT = name + "_demo_composer_draw_select"

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
          "tooltip": name + ": Enable Demo Composer"
        },
        PROP_DRAW_SELECT:
        {
          "type": "ItemList",
          "name" : "Draw Select",
          "items":["box", "terrain"],
          "callback": _on_property_changed,
          "tooltip": name + ": Select the type of draw to use",
          "size": Vector2(100, 100)
        }
    }



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
    m_logger.debug("Property Changed For %s: %s = %s" % [name, property_name, property_value])
    match property_name:
        PROP_ENABLE:
            enabled = true
        PROP_DRAW_SELECT:
            match property_value:
                "box":
                    m_draw_type = DRAW_TYPE.BOX
                "terrain":
                    m_draw_type = DRAW_TYPE.TERRAIN
            enabled = true
