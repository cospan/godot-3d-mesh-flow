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
#@export var terrain_xz_scale:float = 1.0
@export var terrain_xz_step:int = 1
#@export var terrain_y_scale:float = 100.0
@export var terrain_y_scale:float = 10.0
#@export var terrain_x_count:int = 10
#@export var terrain_z_count:int = 10

@export var chunk_size:int = 10

@export var mesh_color:Color = Color.PURPLE


#var m_pos = Vector3(-50.0, 0, -50.0)
var m_pos = Vector3(-5.0, 0, -5.0)


##############################################################################
# Public Functions
##############################################################################

func step():
    if enabled and m_flag_generate_terrain:
        m_flag_generate_terrain = false
        _generate_chunk()
    else:
        pass

func collision(local_mesh:MeshInstance3D, other_mesh:MeshInstance3D):
    m_logger.debug ("%s: COLLISION: %s -> %s" % [name, local_mesh.name, other_mesh.name])
    # Need to figure out where this collision occurred
    var local_aabb = local_mesh.get_aabb()
    var other_aabb = other_mesh.get_aabb()
    var lrect = Rect2(local_aabb.position.x, local_aabb.position.z, local_aabb.size.x, local_aabb.size.z)
    var orect = Rect2(other_aabb.position.x, other_aabb.position.z, other_aabb.size.x, other_aabb.size.z)
    m_logger.debug("Local Rect: %s" % str(lrect))
    m_logger.debug("Other Rect: %s" % str(orect))
    # Create some polygons by using the PackedVector2Array
    var lpoints = PackedVector2Array()
    lpoints.push_back(Vector2(lrect.position.x, lrect.position.y))
    lpoints.push_back(Vector2(lrect.end.x,      lrect.position.y))
    lpoints.push_back(Vector2(lrect.end.x,      lrect.end.y))
    lpoints.push_back(Vector2(lrect.position.x, lrect.end.y))

    var opoints = PackedVector2Array()
    opoints.push_back(Vector2(orect.position.x, orect.position.y))
    opoints.push_back(Vector2(orect.end.x,      orect.position.y))
    opoints.push_back(Vector2(orect.end.x,      orect.end.y))
    opoints.push_back(Vector2(orect.position.x, orect.end.y))

    # Use Geometry2D to create a clipped polygon of the local from the other
    var clipped = Geometry2D.clip_polygons(lpoints, opoints)
    m_logger.debug("Clipped Polygon: %s" % str(clipped))
    if len(clipped) == 2:
        m_logger.debug("Other Polygon is completely inside the Local Polygon")

        # We are going to cut up the big rectangle
        var lrect1 = Rect2( lrect.position.x,
                            lrect.position.y,
                            lrect.size.x,
                            orect.position.y - lrect.position.y)
        var lpoints1 = PackedVector2Array()
        lpoints1.push_back(Vector2(lrect1.position.x, lrect1.position.y))
        lpoints1.push_back(Vector2(lrect1.end.x,      lrect1.position.y))
        lpoints1.push_back(Vector2(lrect1.end.x,      lrect1.end.y))
        lpoints1.push_back(Vector2(lrect1.position.x, lrect1.end.y))

        var new_lpoints = Geometry2D.clip_polygons(lpoints, lpoints1)[0]
        var concave = Geometry2D.clip_polygons(new_lpoints, opoints)[0]
        m_logger.debug("  lpoints1: %s" % str(lpoints1))
        m_logger.debug("  new_lpoints: %s" % str(lpoints1))
        m_logger.debug("  Clipped Polygon: %s" % str(concave))



        var local_id = local_mesh.get_meta("id")
        m_map_db_adapter.subcomposer_remove_mesh(name, local_id)

        m_st.clear()
        m_st.begin(Mesh.PRIMITIVE_TRIANGLES)

        for p in concave:
            var y = noise.get_noise_2d(p.x, p.y) * terrain_y_scale
            m_st.add_vertex(Vector3(p.x, y, p.y))
        var triangulated_polygon = Geometry2D.triangulate_polygon(concave)
        m_logger.debug("  Triangulated Polygon For Concave: %s" % str(triangulated_polygon))
        for t in triangulated_polygon:
            m_st.add_index(t)
        m_st.generate_normals()
        var mesh = m_st.commit()
        # Commit to a mesh.
        var modifiers = {
            "color":Color.BLUE,
            "layer":mesh_layer,
            "priority":mesh_priority
        }
        m_map_db_adapter.subcomposer_add_mesh(name, mesh, Transform3D(), modifiers)



        m_st.clear()
        m_st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for p in lpoints1:
            var y = noise.get_noise_2d(p.x, p.y) * terrain_y_scale
            m_st.add_vertex(Vector3(p.x, y, p.y))

        triangulated_polygon = Geometry2D.triangulate_polygon(lpoints1)
        m_logger.debug("  Triangulated Polygon For New lpoints: %s" % str(triangulated_polygon))
        for t in triangulated_polygon:
            m_st.add_index(t)
        m_st.generate_normals()
        var mesh2 = m_st.commit()
        # Commit to a mesh.
        var modifiers2 = {
            "color":Color.RED,
            "layer":mesh_layer,
            "priority":mesh_priority
        }
        m_map_db_adapter.subcomposer_add_mesh(name, mesh2, Transform3D(), modifiers2)






##############################################################################
# Private Functions
##############################################################################


func _generate_chunk():

    var t = Transform3D()

    m_st.clear()
    m_st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var chunk_rect = Rect2(m_pos.x, m_pos.z, chunk_size, chunk_size)
    var mesh = generate_terrain(chunk_rect)

    # Commit to a mesh.
    var modifiers = {
        "color":mesh_color,
        "layer":mesh_layer,
        "priority":mesh_priority
    }
    m_map_db_adapter.subcomposer_add_mesh(name, mesh, t, modifiers)


# Need a function that we give it a cooridinates and size of the terrain and it returns the terrain.
# The position and size of the terrain will be floats
# The terrain will be a mesh
func generate_terrain(r:Rect2) -> Mesh:
    m_logger.debug("Generating Terrain: %s" % str(r))
    if r.size.x > chunk_size or r.size.y > chunk_size:
        m_logger.error("Terrain Size is too large: %s" % str(r.size))
        return

    m_logger.debug("End Position: %s" % str(r.end))
    m_st.clear()
    m_st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var x = r.position.x
    var z = r.position.y

    var col_count = ceil(r.size.x / terrain_xz_step)
    var row_count = ceili(r.size.y / terrain_xz_step)
    m_logger.debug("Row Count: %s" % str(row_count))
    m_logger.debug("Col Count: %s" % str(col_count))

    while z <= r.end.y:
        x = r.position.x
        while x <= r.end.x:
            m_logger.debug("Generating Vertex: %s, %s" % [x, z])
            var percent_x = (x - r.position.x) / float(r.size.x)
            var percent_z = (z - r.position.y) / float(r.size.y)
            m_st.set_uv(Vector2(percent_x, percent_z))
            var y = noise.get_noise_2d(x, z) * terrain_y_scale
            m_st.add_vertex(Vector3(x, y, z))
            if x == r.end.x:
                break

            x += terrain_xz_step
            if x > r.end.x:
                x = r.end.x

        if z == r.end.y:
            break

        z += terrain_xz_step
        if z > r.end.y:
            z = r.end.y


    # Now that we have all these vertices we need to create the triangles
    var vi = 0
    for a in row_count:
        for b in col_count:
            m_st.add_index(vi + 0)
            m_st.add_index(vi + 1)
            m_st.add_index(vi + col_count + 1)

            m_st.add_index(vi + col_count + 1)
            m_st.add_index(vi + 1)
            m_st.add_index(vi + col_count + 2)
            vi += 1
        vi += 1

    m_logger.debug("Vertex Count: %s" % vi)

    m_st.generate_normals()
    return m_st.commit()

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
