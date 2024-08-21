extends SubComposerBase

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################
const PROP_GENERATE_TERRAIN = "generate_terrain"

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("_BASE_", LogStream.LogLevel.DEBUG)
var m_st:SurfaceTool

## Flags ##
var m_flag_generate_terrain = false

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################
@export var noise:FastNoiseLite
@export var terrain_xz_scale:float = 1.0
#@export var terrain_y_scale:float = 100.0
@export var terrain_y_scale:float = 10.0
@export var terrain_x_count:int = 10
@export var terrain_z_count:int = 10

@export var mesh_color:Color = Color.PURPLE


#var m_pos = Vector3(-50.0, 0, -50.0)
var m_pos = Vector3(-5.0, 0, -5.0)


##############################################################################
# Public Functions
##############################################################################

func step():
    if enabled:
        _draw_terrain()
    else:
        pass

func collision(local_mesh:MeshInstance3D, other_mesh:MeshInstance3D):
    m_logger.debug ("%s: COLLISION: %s -> %s" % [name, local_mesh.name, other_mesh.name])
    # Need to figure out where this collision occurred
    var local_aabb = local_mesh.get_aabb()
    var other_aabb = other_mesh.get_aabb()
    m_logger.debug("  Position: %s" % local_aabb.position)




##############################################################################
# Private Functions
##############################################################################

func _draw_terrain():

    if not m_flag_generate_terrain:
        return

    m_flag_generate_terrain = false
    var t = Transform3D()

    m_st.clear()
    m_st.begin(Mesh.PRIMITIVE_TRIANGLES)

    for z in terrain_z_count + 1:
        for x in terrain_x_count + 1:
            var percent_x = float(x) / float(terrain_x_count)
            #m_logger.debug("Percent X: %s" % percent_x)
            var percent_z = float(z) / float(terrain_z_count)
            #m_logger.debug("Percent Z: %s" % percent_z)
            m_st.set_uv(Vector2(percent_x, percent_z))
            var x_terrain_pos = (x * terrain_xz_scale) + m_pos.x
            var z_terrain_pos = (z * terrain_xz_scale) + m_pos.z
            var y_terrain_pos = noise.get_noise_2d(x_terrain_pos, z_terrain_pos) * terrain_y_scale
            m_logger.debug("X: %s, Y: %s -> X: %s, Y: %s, Z: %s" % [x, z, x_terrain_pos, y_terrain_pos, z_terrain_pos])
            m_st.add_vertex(Vector3(x_terrain_pos, y_terrain_pos, z_terrain_pos))


    # Now that we have all these vertices we need to create the triangles
    var vert = 0
    for z in range(0, terrain_z_count):
        for x in range(0,  terrain_x_count):
            #var vert = z * terrain_x_count + x
            m_st.add_index(vert + 0)
            m_st.add_index(vert + 1)
            m_st.add_index(vert + terrain_x_count + 1)

            m_st.add_index(vert + terrain_x_count + 1)
            m_st.add_index(vert + 1)
            m_st.add_index(vert + terrain_x_count + 2)
            vert += 1
        vert += 1

    m_st.generate_normals()
    #t = t.translated(m_pos)



    # Commit to a mesh.
    var mesh = m_st.commit()
    var modifiers = {
        "color":mesh_color,
        "layer":mesh_layer,
        "priority":mesh_priority
    }
    m_map_db_adapter.subcomposer_add_mesh(name, mesh, t, modifiers)

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
        },
        PROP_GENERATE_TERRAIN:
        {
          "type": "Button",
          "name" : "Generate Terrain",
          "callback": _on_property_changed,
          "tooltip": name + ": Generate Terrain"
        }
    }
    add_to_group("subcomposer")
    add_to_group("map-creator-properties")
    m_st = SurfaceTool.new()
    m_flag_generate_terrain = true


func _on_property_changed(property_name, property_value):
    #m_logger.debug("Property Changed For %s: %s = %s" % [name, property_name, property_value])
    match property_name:
        PROP_ENABLE:
            enabled = property_value
            if not enabled:
                if m_map_db_adapter != null:
                    _remove_all_meshes()
        PROP_GENERATE_TERRAIN:
            # Clear all previous meshes
            _remove_all_meshes()
            # Request to generate new terrain
            m_flag_generate_terrain = property_value
