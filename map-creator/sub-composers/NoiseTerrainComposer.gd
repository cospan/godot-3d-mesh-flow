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
var m_logger = LogStream.new("NoisTerrainComposer", LogStream.LogLevel.INFO)
var m_st:SurfaceTool
var m_rng = RandomNumberGenerator.new()

var m_tmp_gen_triangle_count = 0
var m_tmp_mesh_color = Color(0.0, 0.0, 0.0, 1.0)

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
var m_pos = Vector3(0, 0, 0)


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

    var chunk_rect = _get_chunk_rect_from_position(local_mesh.global_transform.origin)
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

        #m_st.clear()
        #m_st.begin(Mesh.PRIMITIVE_TRIANGLES)

        #for p in concave:
        #    var y = noise.get_noise_2d(p.x, p.y) * terrain_y_scale
        #    m_st.add_vertex(Vector3(p.x, y, p.y))
        var triangulated_polygon = Geometry2D.triangulate_polygon(concave)
        #m_logger.debug("  Triangulated Polygon For Concave: %s" % str(triangulated_polygon))
        # Generate a list of triangles using the verticies and indexes
        var triangles = []
        for i in range(0, len(triangulated_polygon), 3):
            triangles.append([concave[triangulated_polygon[i]],
                              concave[triangulated_polygon[i + 1]],
                              concave[triangulated_polygon[i + 2]]])
        m_logger.debug("  G1: Triangles: %s" % str(triangles))

        var ti = 0
        for triangle in triangles:
            #m_tmp_mesh_color = Color(m_rng.randf_range(0.5, 1.0),
            #                         m_rng.randf_range(0.5, 1.0),
            #                         m_rng.randf_range(0.5, 1.0), 1.0)
            if ti == 4:
                m_tmp_mesh_color = Color(0.0, 1.0, 0.0, 1.0)
            else:
                m_tmp_mesh_color = Color(0.0, 0.0, 1.0, 1.0)

            var m = _generate_terrain_by_triangle(triangle, chunk_rect)
            var mat = ORMMaterial3D.new()
            mat.albedo_color = m_tmp_mesh_color
            m.surface_set_material(0, mat)

            var mdf = {
                #"color":Color(m_rng.randf_range(0.5, 1.0),
                #              m_rng.randf_range(0.5, 1.0),
                #              m_rng.randf_range(0.5, 1.0), 1.0),
                #"color":m_tmp_mesh_color,
                "layer":mesh_layer,
                "mask":mesh_mask
                #"priority":mesh_priority
            }

            m_map_db_adapter.subcomposer_add_mesh(name, m, Transform3D(), mdf)
            ti = ti + 1

        m_st.clear()
        m_st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for p in lpoints1:
            var y = noise.get_noise_2d(p.x, p.y) * terrain_y_scale
            m_st.add_vertex(Vector3(p.x, y, p.y))

        triangulated_polygon = Geometry2D.triangulate_polygon(lpoints1)
        #m_logger.debug("  Triangulated Polygon For New lpoints: %s" % str(triangulated_polygon))
        triangles = []
        for i in range (0, len(triangulated_polygon), 3):
            triangles.append([lpoints1[triangulated_polygon[i]],
                              lpoints1[triangulated_polygon[i + 1]],
                              lpoints1[triangulated_polygon[i + 2]]])
        m_logger.debug("  G2: Triangles: %s" % str(triangles))

        for triangle in triangles:
            m_tmp_mesh_color = Color(1.0, 0.0, 0.0, 1.0)
            #m_tmp_mesh_color = Color(m_rng.randf_range(0.5, 1.0),
            #                         m_rng.randf_range(0.5, 1.0),
            #                         m_rng.randf_range(0.5, 1.0), 1.0)
            var m = _generate_terrain_by_triangle(triangle, chunk_rect)
            var mat = ORMMaterial3D.new()
            mat.albedo_color = m_tmp_mesh_color
            m.surface_set_material(0, mat)

            var mdf = {
                #"color":Color(m_rng.randf_range(0.5, 1.0),
                #              m_rng.randf_range(0.5, 1.0),
                #              m_rng.randf_range(0.5, 1.0), 1.0),
                #"color":m_tmp_mesh_color,
                "layer":mesh_layer,
                "mask":mesh_mask
                #"priority":mesh_priority
            }

            m_map_db_adapter.subcomposer_add_mesh(name, m, Transform3D(), mdf)
    elif len(clipped) == 1:
        # Clip len == 1, we just need
        if len(clipped[0]) == len(lpoints):
            var c_len = len(clipped[0])
            for p in lpoints:
                if p in clipped[0]:
                    c_len -= 1
            if c_len == 0:
                m_logger.debug("Local Polygon is right on the edge of other polygon, do nothing")
                return

        var local_id = local_mesh.get_meta("id")
        m_map_db_adapter.subcomposer_remove_mesh(name, local_id)


        var triangulated_polygon = Geometry2D.triangulate_polygon(clipped[0])
        #m_logger.debug("  Triangulated Polygon For Concave: %s" % str(triangulated_polygon))
        # Generate a list of triangles using the verticies and indexes
        var triangles = []
        for i in range(0, len(triangulated_polygon), 3):
            triangles.append([clipped[0][triangulated_polygon[i]],
                              clipped[0][triangulated_polygon[i + 1]],
                              clipped[0][triangulated_polygon[i + 2]]])
        m_logger.debug("  G1: Triangles: %s" % str(triangles))

        var ti = 0
        for triangle in triangles:
            #m_tmp_mesh_color = Color(m_rng.randf_range(0.5, 1.0),
            #                         m_rng.randf_range(0.5, 1.0),
            #                         m_rng.randf_range(0.5, 1.0), 1.0)
            if ti == 4:
                m_tmp_mesh_color = Color(0.0, 1.0, 0.0, 1.0)
            else:
                m_tmp_mesh_color = Color(0.0, 0.0, 1.0, 1.0)

            var m = _generate_terrain_by_triangle(triangle, chunk_rect)
            var mat = ORMMaterial3D.new()
            mat.albedo_color = m_tmp_mesh_color
            m.surface_set_material(0, mat)
            var mdf = {
                #"color":Color(m_rng.randf_range(0.5, 1.0),
                #              m_rng.randf_range(0.5, 1.0),
                #              m_rng.randf_range(0.5, 1.0), 1.0),
                #"color":m_tmp_mesh_color,
                "layer":mesh_layer,
                "mask":mesh_mask
                #"priority":mesh_priority
            }

            m_map_db_adapter.subcomposer_add_mesh(name, m, Transform3D(), mdf)
            ti = ti + 1






##############################################################################
# Private Functions
##############################################################################


func _generate_chunk():

    var t = Transform3D()

    m_st.clear()
    m_st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var chunk_rect = Rect2(m_pos.x, m_pos.z, chunk_size, chunk_size)
    var mesh = generate_terrain(chunk_rect)
    var mat = ORMMaterial3D.new()
    mat.albedo_color = mesh_color
    mesh.surface_set_material(0, mat)

    # Commit to a mesh.
    var modifiers = {
        #"color":mesh_color,
        "layer":mesh_layer,
        "mask":mesh_mask
        #"priority":mesh_priority
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
            #m_logger.debug("Generating Vertex: %s, %s" % [x, z])
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


#func _create_slope(p1:Vector2, p2:Vector2) -> Array:
#    #Generate the slope and intercept and return them as an array
#    var slope = null
#    var intercept = null
#    if p2.x - p1.x != 0:
#        slope = (p2.y - p1.y) / (p2.x - p1.x)
#        intercept = p1.y - slope * p1.x
#        return [slope, intercept]
#    return [null, null]

func _generate_terrain_by_triangle(triangle:PackedVector2Array, chunk_rect:Rect2) -> Mesh:
    m_tmp_gen_triangle_count += 1
    m_st.clear()
    m_st.begin(Mesh.PRIMITIVE_TRIANGLES)

    # find top of triangle
    var top_index = 0
    var bot_index = 0
    var left_index = 0
    var right_index = 0
    for i in range(1, 3):
        if triangle[i].y < triangle[top_index].y:
            top_index = i
        if triangle[i].y > triangle[bot_index].y:
            bot_index = i
        if triangle[i].x < triangle[left_index].x:
            left_index = i
        if triangle[i].x > triangle[right_index].x:
            right_index = i

    var top_tr = triangle[top_index]
    var left_tr = triangle[left_index]
    if is_equal_approx(top_tr.y, left_tr.y) and not is_equal_approx(top_tr.x, left_tr.x):
        top_index = left_index

    # Top and Bottom are not the same
    # Left and right are not the same

    #  /
    # /
    var next_index = (top_index + 2) % 3
    var slope_triangle_l = null
    var slope_triangle_l_b = null
    if triangle[next_index].x - triangle[top_index].x != 0:
        slope_triangle_l =  (triangle[next_index].y - triangle[top_index].y) /  \
                            (triangle[next_index].x - triangle[top_index].x)
        # b = y - mx
        slope_triangle_l_b = triangle[top_index].y - slope_triangle_l * triangle[top_index].x

    # We need to find the slopes of the triangles
    #  \
    #   \
    next_index = (top_index + 1) % 3
    var slope_triangle_r = null
    var slope_triangle_r_b = null
    if triangle[next_index].x - triangle[top_index].x != 0:
        slope_triangle_r =  (triangle[next_index].y - triangle[top_index].y) /  \
                            (triangle[next_index].x - triangle[top_index].x)
        # b = y - mx
        slope_triangle_r_b = triangle[top_index].y - slope_triangle_r * triangle[top_index].x



    #if slope_triangle_l != 0 and slope_triangle_l != null and top_index == right_index:
    #    m_logger.debug("Triangle Slope L Need Segements??")
    #if slope_triangle_r != 0 and slope_triangle_r != null and top_index == left_index:
    #    m_logger.debug("Triangle Slope R Need Segements??")
    var top = triangle[top_index]
    var bottom = triangle[bot_index]

    #Assume we don't need a segment by setting the segment to the bottom
    var segment_l_z = bottom.y
    var segment_r_z = bottom.y
    var slope_triangle_s = null
    var slope_triangle_s_b = null
    if slope_triangle_l != 0 and slope_triangle_l != null and slope_triangle_r != 0 and slope_triangle_r != null:
        #m_logger.debug("Triangle Slope L and R Need Segements??")
        if top_index == right_index:
            var prev_index = (top_index + 2) % 3
            #m_logger.debug("Triangle Slope L Need Segements??")
            slope_triangle_s = (triangle[bot_index].y - triangle[prev_index].y) / (triangle[bot_index].x - triangle[prev_index].x)
            slope_triangle_s_b = triangle[prev_index].y - slope_triangle_s * triangle[prev_index].x
            segment_l_z = triangle[prev_index].y
        elif top_index == left_index:
            #m_logger.debug("Triangle Slope R Need Segements??")
            var prev_index = (top_index + 1) % 3
            slope_triangle_s = (triangle[bot_index].y - triangle[prev_index].y) / (triangle[bot_index].x - triangle[prev_index].x)
            slope_triangle_s_b = triangle[prev_index].y - slope_triangle_s * triangle[prev_index].x
            segment_r_z = triangle[prev_index].y



    #XXX: Need to figure out how to create the slopes for the triangles

    var prev_row = []
    var cur_row = []
    var cur_index = 0

    var z = top.y
    while z <= bottom.y:
        var x = top.x
        var x_end = top.x
        if slope_triangle_l != null:
            if z > segment_l_z:
                x = (z - slope_triangle_s_b) / slope_triangle_s
            else:
                x = (z - slope_triangle_l_b) / slope_triangle_l

        if slope_triangle_r == 0:
            x_end = triangle[(top_index + 1) % 3].x
        elif slope_triangle_r != null:
            if z > segment_r_z:
                x_end = (z - slope_triangle_s_b) / slope_triangle_s
            else:
                x_end = (z - slope_triangle_r_b) / slope_triangle_r
        cur_row = []
        while x <= x_end:
            # We need to get the percent from the chunk position

            var percent_x = (x - chunk_rect.position.x) / float(chunk_rect.size.x)
            var percent_z = (z - chunk_rect.position.y) / float(chunk_rect.size.y)
            m_st.set_uv(Vector2(percent_x, percent_z))

            var y = noise.get_noise_2d(x, z) * terrain_y_scale
            m_st.add_vertex(Vector3(x, y, z))
            cur_row.append(cur_index)
            cur_index += 1

            if x == x_end:
                break

            x += terrain_xz_step
            if x > x_end:
                x = x_end


        # Set the indexes of the triangles
        if len(prev_row) == 0:
            prev_row = cur_row
        else:
            var pindex = 0
            var cindex = 0
            while pindex < (len(prev_row) - 1) or cindex < (len(cur_row) - 1):

                if cindex < (len(cur_row) - 1):
                    m_st.add_index(cur_row[cindex])
                    m_st.add_index(prev_row[pindex])
                    cindex += 1
                    m_st.add_index(cur_row[cindex])

                if pindex < (len(prev_row) - 1):
                    m_st.add_index(prev_row[pindex])
                    pindex += 1
                    m_st.add_index(prev_row[pindex])
                    m_st.add_index(cur_row[cindex])

            prev_row = cur_row


        if z == bottom.y:
            break

        z += terrain_xz_step
        if z > bottom.y:
            z = bottom.y



    m_st.generate_normals()
    return m_st.commit()


func _get_chunk_rect_from_position(pos:Vector3) -> Rect2:
    var x = floor(pos.x / chunk_size) * chunk_size
    var z = floor(pos.z / chunk_size) * chunk_size
    return Rect2(x, z, chunk_size, chunk_size)

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
