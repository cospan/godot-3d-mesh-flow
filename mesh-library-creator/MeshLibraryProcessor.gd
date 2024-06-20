extends Node

##############################################################################
# Signals
##############################################################################
signal progress_percent_update
signal continue_step


##############################################################################
# Constants
##############################################################################

const PROGRESS_UPDATE_FIND_BOUNDS                 = "find_novel_bounds"
const PROGRESS_UPDATE_FIND_LIBRARY_BOUNDS         = "find_total_bounds"
const PROGRESS_UPDATE_FACE_PARSER                 = "face_parser"
const PROGRESS_UPDATE_HASHING                     = "hashing"
const PROGRESS_UPDATE_BASE_REMOVAL                = "base_removal"
const PROGRESS_UPDATE_HASH_ANALYSIS               = "hash_analysis"
const PROGRESS_UPDATE_BASE_AGNOSTIC_HASH          = "base_agnostic_hash"
const PROGRESS_UPDATE_BASE_AGNOSTIC_HASH_ANALYSIS = "base_agnostic_hash_analsys"
const PROGRESS_UPDATE_HASH_SID                    = "hash_sid_update"
const PROGRESS_UPDATE_GENERATE_EXPORT_DICTS       = "generate_export_dicts"
const PROGRESS_UPDATE_EXPORT_LIBRARY              = "export_library"
const PROGRESS_UPDATE_UPDATE_DATABASE             = "update_database"


enum STATE_T {
    RESET,
    IDLE,
    FIND_MODULE_BOUNDS,
    FIND_DEFAULT_SIZE,
    PARSE_FACE,
    GENERATE_VERTEX_LISTS,
    HASH_LIBRARY,
    GENERATE_BASE_AGNOSTIC_HASHES,
    GENERATE_INDEX_MAP,
}

enum FACE_T {
    FRONT = 0,
    BACK = 1,
    TOP = 2,
    BOTTOM = 3,
    RIGHT = 4,
    LEFT = 5
}

var C_BB_NORMALS = [
    Vector3(0, 0, 1),  # + Z
    Vector3(0, 0, -1), # - Z #XXX: Is this reversed?
    Vector3(0, 1, 0),  # + Y
    Vector3(0, -1, 0), # - Y
    Vector3(1, 0, 0),  # + X
    Vector3(-1, 0, 0)  # - X #XXX: Is this reversed?
]


##############################################################################
# Members
##############################################################################
var m_state = STATE_T.RESET
var m_logger = LogStream.new("MLP", LogStream.LogLevel.DEBUG)
var m_mesh_dict = {}
var m_novel_modules = []
var m_database_path = null

# Hash Context
var m_hash_ctx = null

# Database Adapter
var m_db_adapter = null


# Flags
var m_flag_start_loading_library = false
var m_flag_force_new_database = false
var m_flag_begin_export = false
var m_flag_async_finished = false


##############################################################################
# Exports
##############################################################################
@export_range(0, 90.0, 0.01) var NORMAL_TOERLANCE:float = 0.01
@export_range(0, 1.0, 0.01) var VECTOR_DISTANCE_TOLERANCE:float = 0.05
@export_range(0, 0.1, 0.0001) var AABB_SNAP:float = 0.001
@export_range(0, 0.1, 0.0001) var FACE_SNAP:float = 0.001


##############################################################################
# Public Functions
##############################################################################
func load_library(database_path:String, force_new_database:bool = false):
    m_logger.debug("Loading Library")
    m_flag_force_new_database = force_new_database
    m_database_path = database_path
    m_flag_start_loading_library = true

func get_default_size() -> Vector2:
    return m_db_adapter.get_default_size_2d()


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_hash_ctx = HashingContext.new()
    m_logger.debug("Ready Entered!")
    m_db_adapter = $ModuleDatabaseAdapter


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    match m_state:
        STATE_T.RESET:
            m_logger.info("Resetting")
            if is_node_ready():
                m_state = STATE_T.IDLE
        STATE_T.IDLE:
            if m_flag_start_loading_library:
                m_flag_start_loading_library = false
                m_db_adapter.open_database(m_database_path, m_flag_force_new_database)
                m_flag_force_new_database = false

                # Determine which modules are new
                m_logger.info("Finding Novel Modules")
                var db_info_dict = m_db_adapter.get_file_info_dict()
                var fs_info_dict = _get_mesh_file_info_from_dir(m_database_path)
                m_mesh_dict = get_mesh_dict_from_dir(m_database_path)
                var novel_modules = _find_novel_mesh_files(fs_info_dict, db_info_dict)
                m_novel_modules = novel_modules.keys()
                m_db_adapter.set_file_info_dict(novel_modules)

                m_flag_async_finished = false
                _find_novel_modules_bounds()
                m_state = STATE_T.FIND_MODULE_BOUNDS
                m_logger.info("_process: IDLE -> FIND_MODULE_BOUNDS")

        STATE_T.FIND_MODULE_BOUNDS:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_logger.info("Finding Library Bounds")
                m_flag_async_finished = false
                _find_default_size_of_modules()
                m_state = STATE_T.FIND_DEFAULT_SIZE
                m_logger.info("_process: FIND_MODULE_BOUNDS -> FIND_DEFAULT_SIZE")
        STATE_T.FIND_DEFAULT_SIZE:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_logger.info("Parsing Faces")
                m_flag_async_finished = false
                _create_2d_face_library()
                m_state = STATE_T.PARSE_FACE
                m_logger.info("_process: FIND_DEFAULT_SIZE -> PARSE_FACE")
        STATE_T.PARSE_FACE:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_logger.info("Base Offset Removal")
                m_flag_async_finished = false
                _start_base_offset_removal()
                m_state = STATE_T.GENERATE_VERTEX_LISTS
                m_logger.info("_process: PARSE_FACE -> GENERATE_VERTEX_LISTS")
        STATE_T.GENERATE_VERTEX_LISTS:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_logger.info("Hashing Library")
                m_flag_async_finished = false
                _start_library_hash()
                m_state = STATE_T.HASH_LIBRARY
                m_logger.info("_process: GENERATE_VERTEX_LISTS -> HASH_LIBRARY")
        STATE_T.HASH_LIBRARY:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_logger.info("Base Agnostic Hashing")
                m_flag_async_finished = false
                _start_base_agnostic_library_hash()
                m_state = STATE_T.GENERATE_BASE_AGNOSTIC_HASHES
                m_logger.info("_process: HASH_LIBRARY -> GENERATE_BASE_AGNOSTIC_HASHES")
        STATE_T.GENERATE_BASE_AGNOSTIC_HASHES:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_logger.info("Analyzing Hash Library")
                m_flag_async_finished = false
                _start_generating_index_dict()
                m_state = STATE_T.GENERATE_INDEX_MAP
                m_logger.info("_process: GENERATE_BASES_AGNOSTIC_HASHES -> GENERATE_INDEX_MAP")
        STATE_T.GENERATE_INDEX_MAP:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_db_adapter.cleanup_database()
                m_logger.info("_process: GENERATE_BASES_AGNOSTIC_HASHES -> IDLE")
                m_state = STATE_T.IDLE
        _:
            m_logger.error("Invalid State: {m_state}")



##############################################################################
# Emit Signal Functions
##############################################################################
func emit_percent_update(_name:String, _percent:float):
    emit_signal("progress_percent_update", _name, _percent)



##############################################################################
# Module 2D Face Library Loading
#
# - Reads in each mesh into a module mesh dictionary
# - Goes through each mesh and finds the faces that are on the outside of the
#   mesh
# - Finds the module bounds by going through all modules and finding the
#   most common start and end points
#         - XXX: It might be better to use the maximum size of the modules
#           instead of the most common start and end points
##############################################################################
func get_mesh_dict_from_dir(_mesh_data_dir:String):
    var mesh_dict = {}
    var dir = DirAccess.open(_mesh_data_dir)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".obj"):
                var mesh = load(_mesh_data_dir + file_name)
                if mesh:
                    var m3d = MeshInstance3D.new()
                    m3d.set_mesh(mesh)
                    mesh_dict[file_name.get_basename()] = m3d
            file_name = dir.get_next()
        dir.list_dir_end()
    return mesh_dict


func _get_mesh_file_info_from_dir(_mesh_data_dir:String):
    var mesh_info_dict = {}
    var dir = DirAccess.open(_mesh_data_dir)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".obj"):
                var md5 = FileAccess.get_md5(_mesh_data_dir + file_name)
                if len(md5) > 0:
                    var fn = file_name.get_basename()
                    mesh_info_dict[fn] = {}
                    mesh_info_dict[fn]["md5"] = md5
                    mesh_info_dict[fn]["filename"] = file_name
            file_name = dir.get_next()
        dir.list_dir_end()
    return mesh_info_dict


func _find_novel_mesh_files(fs_dict: Dictionary, db_dict: Dictionary) -> Dictionary:
    var output_dict = {}
    var fs_keys = fs_dict.keys()
    var db_keys = db_dict.keys()
    fs_keys.sort()
    db_keys.sort()
    while (len(fs_keys) > 0):
        var fs_key = fs_keys[-1]
        # Check if the database has this key
        if not db_keys.has(fs_key):
            output_dict[fs_key] = fs_dict[fs_key]
            fs_keys.erase(fs_key)
            continue
        # Both the database and the filesystem have the same name
        # Check if the filenames are the same
        if fs_dict[fs_key]["filename"] != db_dict[fs_key]["filename"]:
            output_dict[fs_key] = fs_dict[fs_key]
            fs_keys.erase(fs_key)
            continue

        # The filenames of both matching names are the same
        # Check if the MD5s are the same
        if fs_dict[fs_key]["md5"] != db_dict[fs_key]["md5"]:
            output_dict[fs_key] = fs_dict[fs_key]
            fs_keys.erase(fs_key)
            continue

        # Everything already matches, we don't need to process this one
        fs_keys.erase(fs_key)
        db_keys.erase(fs_key)

    while (len(db_keys) > 0):
        var db_key = db_keys[-1]
        db_keys.erase(db_key)
        m_db_adapter.delete_module(db_key)
    return output_dict

##############################################################################
# Find the bounds of all the new modules
##############################################################################
func _find_novel_modules_bounds():
    var percent = 0.0
    var total_size = len(m_novel_modules)
    var _pname  = PROGRESS_UPDATE_FIND_BOUNDS
    call_deferred("emit_percent_update", _pname, percent)
    for i in range(len(m_novel_modules)):
        var mesh_name = m_novel_modules[i]
        _find_module_bounds(mesh_name)
        percent = (float((i + 1)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step
    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

func _find_module_bounds(module_name:String):
    var module_aabb = m_mesh_dict[module_name].mesh.get_aabb()
    var module_sp = module_aabb.position
    var module_ep = module_aabb.position + module_aabb.size
    #m_module_bounds[module_name] = [module_sp, module_ep]
    #var bounds_dict = {"name": module_name, "bounds": [module_sp, module_ep]}
    m_db_adapter.update_parser_bounds(module_name, [module_sp, module_ep])


##############################################################################
# Find the default size of all the modules
##############################################################################
func _find_default_size_of_modules():
    var sp_x = {}
    var sp_z = {}
    var sp_y = {}
    var ep_x = {}
    var ep_y = {}
    var ep_z = {}
    var percent = 0.0
    m_flag_async_finished = false
    var total_size = len(m_mesh_dict.keys())
    var _pname = PROGRESS_UPDATE_FIND_LIBRARY_BOUNDS
    var bounds_dict = m_db_adapter.get_bounds_dict()
    call_deferred("emit_percent_update", _pname, percent)
    for i in range(len(bounds_dict.keys())):
        var mesh_name = bounds_dict.keys()[i]
        #var bounds = m_db_adapter.get_bounds(mesh_name)
        var bounds = bounds_dict[mesh_name]
        if bounds == null:
            m_logger.warn("Did not find module bounds for %s" % mesh_name)
            continue
        var module_sp = bounds[0].snapped(Vector3(AABB_SNAP, AABB_SNAP, AABB_SNAP))
        var module_ep = bounds[1].snapped(Vector3(AABB_SNAP, AABB_SNAP, AABB_SNAP))
        if not sp_x.has(module_sp.x):
            sp_x[module_sp.x] = 1
        else:
            sp_x[module_sp.x] += 1

        if not sp_y.has(module_sp.y):
            sp_y[module_sp.y] = 1
        else:
            sp_y[module_sp.y] += 1

        if not sp_z.has(module_sp.z):
            sp_z[module_sp.z] = 1
        else:
            sp_z[module_sp.z] += 1

        if not ep_x.has(module_ep.x):
            ep_x[module_ep.x] = 1
        else:
            ep_x[module_ep.x] += 1

        if not ep_y.has(module_ep.y):
            ep_y[module_ep.y] = 1
        else:
            ep_y[module_ep.y] += 1

        if not ep_z.has(module_ep.z):
            ep_z[module_ep.z] = 1
        else:
            ep_z[module_ep.z] += 1

        percent = (float((i + 1)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    m_logger.debug ("Total Start Points X: %d" % len(sp_x.keys()))
    m_logger.debug ("  %s" % str(sp_x.keys()))
    m_logger.debug ("Total Start Points Z: %d" % len(sp_z.keys()))
    m_logger.debug ("  %s" % str(sp_z.keys()))
    m_logger.debug ("Total End Points X: %d" % len(ep_x.keys()))
    m_logger.debug ("  %s" % str(ep_x.keys()))
    m_logger.debug ("Total End Points Z: %d" % len(ep_z.keys()))
    m_logger.debug ("  %s" % str(ep_z.keys()))

    # Find the most common start and end points
    var sp_x_max = 0
    var sp_x_max_key = 0
    for key in sp_x.keys():
        if sp_x[key] > sp_x_max:
            sp_x_max = sp_x[key]
            sp_x_max_key = key

    var sp_y_max = 0
    var sp_y_max_key = 0
    for key in sp_y.keys():
        if sp_y[key] > sp_y_max:
            sp_y_max = sp_y[key]
            sp_y_max_key = key

    var sp_z_max = 0
    var sp_z_max_key = 0
    for key in sp_z.keys():
        if sp_z[key] > sp_z_max:
            sp_z_max = sp_z[key]
            sp_z_max_key = key

    var ep_x_max = 0
    var ep_x_max_key = 0
    for key in ep_x.keys():
        if ep_x[key] > ep_x_max:
            ep_x_max = ep_x[key]
            ep_x_max_key = key

    var ep_y_max = 0
    var ep_y_max_key = 0
    for key in ep_y.keys():
        if ep_y[key] > ep_y_max:
            ep_y_max = ep_y[key]
            ep_y_max_key = key

    var ep_z_max = 0
    var ep_z_max_key = 0
    for key in ep_z.keys():
        if ep_z[key] > ep_z_max:
            ep_z_max = ep_z[key]
            ep_z_max_key = key

    m_logger.debug ("Start Point X: %f" % sp_x_max_key)
    m_logger.debug ("Start Point Y: %f" % ep_x_max_key)
    m_logger.debug ("Start Point Z: %f" % sp_z_max_key)
    m_logger.debug ("End Point X: %f" % ep_x_max_key)
    m_logger.debug ("End Point Y: %f" % ep_y_max_key)
    m_logger.debug ("End Point Z: %f" % ep_z_max_key)

    var x_size = ep_x_max_key - sp_x_max_key
    var y_size = ep_y_max_key - sp_y_max_key
    var z_size = ep_z_max_key - sp_z_max_key

    m_db_adapter.set_default_size(Vector3(x_size, y_size, z_size))

    m_logger.debug ("Default Size: %s" % str(get_default_size()))

    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

##############################################################################
# Create 2D Face Library
##############################################################################
func _create_2d_face_library():
    var percent = 0.0
    m_flag_async_finished = false
    var total_size = float(len(m_novel_modules))
    var _pname = PROGRESS_UPDATE_FACE_PARSER
    call_deferred("emit_percent_update", _pname, percent)
    for mesh_index in range(len(m_novel_modules)):
        var mesh_name = m_novel_modules[mesh_index]
        var curr_mesh = m_mesh_dict[mesh_name]
        var face_2d = _get_faces_from_mesh(mesh_name, curr_mesh)
        var face_2d_r = _get_reflected_faces(face_2d)
        m_db_adapter.update_2d_faces(mesh_name, face_2d, face_2d_r)
        percent = (float((mesh_index + 1)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step
    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

func _get_faces_from_mesh(curr_m3d_name:String, curr_m3d) -> Dictionary:
    var module_aabb = curr_m3d.mesh.get_aabb()
    var module_sp = module_aabb.position
    var module_ep = module_aabb.position + module_aabb.size

    # Create a list of normal vectors for the bounding box
    # Go through each surface of the mesh and find the normal vectors, add them to a dictionary
    var module_surface_normals = {}
    module_surface_normals[0] = [] # + Z
    module_surface_normals[1] = [] # - Z
    module_surface_normals[2] = [] # + Y
    module_surface_normals[3] = [] # - Y
    module_surface_normals[4] = [] # + X
    module_surface_normals[5] = [] # - X

    for i in range(curr_m3d.mesh.get_surface_count()):
        var mdt = MeshDataTool.new()
        mdt.create_from_surface(curr_m3d.mesh, i)
        for j in range(mdt.get_face_count()):
            var normal = mdt.get_face_normal(j)
            for k in range(len(C_BB_NORMALS)):
                if normal.is_equal_approx(C_BB_NORMALS[k]):
                    module_surface_normals[k].push_back([i,j])


    for i in module_surface_normals:
        m_logger.debug ("Normal: %s" % str(C_BB_NORMALS[i]))
        m_logger.debug ("  Number of Faces: %d" % len(module_surface_normals[i]))

    # We only want to keep the faces that are on the outside of the mesh

    # Create a list of verticies for the bounding box
    var module_bb_verticies = []
    module_bb_verticies.push_back(snapped(Vector3(0, 0, module_ep.z), Vector3(FACE_SNAP, FACE_SNAP, FACE_SNAP)))  # + Z
    module_bb_verticies.push_back(snapped(Vector3(0, 0, module_sp.z), Vector3(FACE_SNAP, FACE_SNAP, FACE_SNAP)))  # - Z
    module_bb_verticies.push_back(snapped(Vector3(0, module_ep.y, 0), Vector3(FACE_SNAP, FACE_SNAP, FACE_SNAP)))  # + Y
    module_bb_verticies.push_back(snapped(Vector3(0, module_sp.y, 0), Vector3(FACE_SNAP, FACE_SNAP, FACE_SNAP)))  # - Y
    module_bb_verticies.push_back(snapped(Vector3(module_ep.x, 0, 0), Vector3(FACE_SNAP, FACE_SNAP, FACE_SNAP)))  # + X
    module_bb_verticies.push_back(snapped(Vector3(module_sp.x, 0, 0), Vector3(FACE_SNAP, FACE_SNAP, FACE_SNAP)))  # - X

    # Go through each face in the module_surface_normals and determine if the faces have a vertex that is on the outside of the mesh
    # If the face has a vertex that is on the outside of the mesh, then add the face to the list of faces for the bounding box
    var module_3d_faces = {}
    module_3d_faces[FACE_T.FRONT]   = [] # + Z
    module_3d_faces[FACE_T.BACK]    = [] # - Z
    module_3d_faces[FACE_T.TOP]     = [] # + Y
    module_3d_faces[FACE_T.BOTTOM]  = [] # - Y
    module_3d_faces[FACE_T.RIGHT]   = [] # + X
    module_3d_faces[FACE_T.LEFT]    = [] # - X

    var module_2d_faces = {}
    module_2d_faces[FACE_T.FRONT]   = [] # + Z
    module_2d_faces[FACE_T.BACK]    = [] # - Z
    module_2d_faces[FACE_T.TOP]     = [] # + Y
    module_2d_faces[FACE_T.BOTTOM]  = [] # - Y
    module_2d_faces[FACE_T.RIGHT]   = [] # + X
    module_2d_faces[FACE_T.LEFT]    = [] # - X


    for i in module_surface_normals:
        #print ("Normal: %s" % str(bb_normals[i]))
        #print ("-> Module Face Vector: %s" % str(module_bb_verticies[i]))
        for j in range(len(module_surface_normals[i])):
            var mdt = MeshDataTool.new()
            #var surface_index = module_surface_normals[i][j][0]
            mdt.create_from_surface(curr_m3d.mesh, module_surface_normals[i][j][0])
            var face_index = module_surface_normals[i][j][1]
            var face_verticies = []
            #print ("  Face: %d" % face_index)
            #print ("Face Vertex Index: %s" % str(mdt.get_face_vertex(face_index, 0)))
            #print ("Face Vertex: %s" % str(mdt.get_vertex(mdt.get_face_vertex(face_index, 0))))
            face_verticies.push_back(snapped(mdt.get_vertex(mdt.get_face_vertex(face_index, 0)), Vector3(FACE_SNAP, FACE_SNAP, FACE_SNAP)))
            face_verticies.push_back(snapped(mdt.get_vertex(mdt.get_face_vertex(face_index, 1)), Vector3(FACE_SNAP, FACE_SNAP, FACE_SNAP)))
            face_verticies.push_back(snapped(mdt.get_vertex(mdt.get_face_vertex(face_index, 2)), Vector3(FACE_SNAP, FACE_SNAP, FACE_SNAP)))
            var found = false
            for k in range(len(face_verticies)):
                var normal_vertex = face_verticies[k] * C_BB_NORMALS[i]
                var bb_vertex = module_bb_verticies[i] * C_BB_NORMALS[i]
                m_logger.debug ("    Face Vertex: %s" % str(face_verticies[k]))
                m_logger.debug ("    Normalalized Face Vertex: %s" % str(normal_vertex))
                m_logger.debug ("    Normalized Module BB Vertex: %s" % str(module_bb_verticies[i]))
                if normal_vertex.is_equal_approx(bb_vertex):
                    found = true
                    #m_logger.debug ("    Found")
                    break
                if found:
                    break
            if found:
                # Instead of putting the normals in the list, put the face vertex list and color in the list
                #var m = mdt.get_material()
                var face_color = mdt.get_material().get("albedo_color")
                #var face_color = mdt.get_vertex_color(mdt.get_face_vertex(face_index, 0))
                #module_3d_faces[i].push_back(module_surface_normals[i][j])
                module_3d_faces[i].push_back([face_verticies, face_color])

    # Add the module_3d_faces to the dictionary
    #m_module_3d_faces[curr_m3d_name] = module_3d_faces

    for i in module_3d_faces:
        ## Find the 2D Coordinates of the face verticies
        for j in range(len(module_3d_faces[i])):
            var face_verticies = module_3d_faces[i][j][0]
            var face_color = module_3d_faces[i][j][1]
            var face_2d = []
            for k in range(len(face_verticies)):
                var face_2d_point
                # XXX Do I need to reverse the direction of the face vertices with the negative normals?
                match i:
                    FACE_T.FRONT:
                        face_2d_point = Vector2(face_verticies[k].x, -face_verticies[k].y)
                    FACE_T.BACK:
                        face_2d_point = Vector2(-face_verticies[k].x, -face_verticies[k].y)
                    FACE_T.TOP:
                        face_2d_point = Vector2(face_verticies[k].x, face_verticies[k].z)
                    FACE_T.BOTTOM:
                        face_2d_point = Vector2(face_verticies[k].x, face_verticies[k].z)
                    FACE_T.RIGHT:
                        face_2d_point = Vector2(face_verticies[k].z, -face_verticies[k].y)
                    FACE_T.LEFT:
                        face_2d_point = Vector2(-face_verticies[k].z, -face_verticies[k].y)
                face_2d.push_back(face_2d_point)
            module_2d_faces[i].push_back([face_2d, face_color])

        if len(module_2d_faces[i]) == 0:
            var _face_name = "front"
            match(i):
                FACE_T.FRONT:
                    _face_name = "front"
                FACE_T.BACK:
                    _face_name = "back"
                FACE_T.TOP:
                    _face_name = "top"
                FACE_T.BOTTOM:
                    _face_name = "bottom"
                FACE_T.RIGHT:
                    _face_name = "right"
                FACE_T.LEFT:
                    _face_name = "left"
            #var b = "Module" + curr_m3d_name + ", Face: " + _face_name
            #m_possible_face_issue_buffer.push_back(b)
            m_logger.warn("Module %s, has no faces" % str(curr_m3d_name, _face_name))
    return module_2d_faces

func _get_reflected_faces(_face:Dictionary) -> Dictionary:
    var reflection_face = {}
    var keys = _face.keys()
    for i in range(len(keys)):
        var triangles = _face[i]
        var new_triangles = []
        for j in range(len(triangles)):
            var triangle = triangles[j][0]
            var new_verticies = []
            #var r_triangle = triangle.reflect(Vector2(0, 1))
            for k in range(3):
                new_verticies.push_back(triangle[k].reflect(Vector2(0, 1)))
                #new_verticies.push_back(r_triangle[k])

            new_triangles.append([new_verticies, triangles[j][1]])
        reflection_face[i] = new_triangles
    return reflection_face


##############################################################################
# Base Offset Removal
##############################################################################

func _start_base_offset_removal():
    var percent = 0.0
    m_flag_async_finished = false
    var total_size = len(m_novel_modules)
    var _pname = PROGRESS_UPDATE_BASE_REMOVAL
    call_deferred("emit_percent_update", _pname, percent)
    # Go through each of the faces in each of the modules and find the hashes that are equal
    # If the hashes are equal, then the faces are the same, put them in a dictionary of faces
    for module_index in range(len(m_novel_modules)):
        var module_name = m_novel_modules[module_index]
        _base_offset_removal_step(module_name)
        percent = (float((module_index + 1)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step
    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

func _base_offset_removal_step(_module_name:String):
    #var module_faces = m_module_2d_face_library[_module_name].duplicate()
    var module_faces = m_db_adapter.get_module_2d_faces(_module_name)
    var module_face_triangle_dict = {}
    module_face_triangle_dict[FACE_T.FRONT] = []
    module_face_triangle_dict[FACE_T.BACK] = []
    module_face_triangle_dict[FACE_T.TOP] = []
    module_face_triangle_dict[FACE_T.BOTTOM] = []
    module_face_triangle_dict[FACE_T.RIGHT] = []
    module_face_triangle_dict[FACE_T.LEFT] = []

    var module_face_base_offset_array = [0, 0, 0, 0, 0, 0]
    var module_face_top_offset_array = [0, 0, 0, 0, 0, 0]
    for i in range (6):
        if i == 2 or i == 3:

            module_face_base_offset_array[i] = 0
            module_face_top_offset_array[i] = 0
        else:
            module_face_base_offset_array[i] = null
            module_face_top_offset_array[i] = null



    # Find the base and top offset of the face (except top and bottom)
    for face_index in range(len(module_faces.keys())):
        #for face_triangle in m_module_2d_face_library[_module_name][face_index]:
        for face_triangle in module_faces[face_index]:
            if face_index != 2 and face_index != 3:
                var v = face_triangle[0]
                for k in range(3):
                    if module_face_base_offset_array[face_index] == null:
                        module_face_base_offset_array[face_index] = v[k].y
                    elif v[k].y < module_face_base_offset_array[face_index]:
                        module_face_base_offset_array[face_index] = v[k].y

                    if module_face_top_offset_array[face_index] == null:
                        module_face_top_offset_array[face_index] = v[k].y
                    elif v[k].y > module_face_top_offset_array[face_index]:
                        module_face_top_offset_array[face_index] = v[k].y


    for face_index in range(len(module_face_base_offset_array)):
        var bot_offset = module_face_base_offset_array[face_index]
        var top_offset = module_face_top_offset_array[face_index]
        if bot_offset == null:
          bot_offset = 0
        if top_offset == null:
          top_offset = 0
        m_db_adapter.update_bottom_offset(_module_name, face_index, bot_offset)
        m_db_adapter.update_top_offset(_module_name, face_index, top_offset)

    # Apply the base offset to the faces
    for face_index in range(len(module_faces.keys())):
        # Get a list of vertices for the face
        if face_index != 2 and face_index != 3:
            #for face in m_module_2d_face_library[_module_name][face_index]:
            for face in module_faces[face_index]:
                var _face_triangle = face.duplicate()
                var face_verticies = _face_triangle[0]
                var new_triangle = []
                var new_verticies = []

                for k in range(3):
                    var new_vert = face_verticies[k]
                    new_vert.y -= module_face_base_offset_array[face_index]
                    new_verticies.push_back(new_vert.snapped(Vector2(FACE_SNAP, FACE_SNAP)))

                new_triangle.push_back(new_verticies)
                new_triangle.push_back(_face_triangle[1])
                module_face_triangle_dict[face_index].push_back(new_triangle)
        else:
            for face in module_faces[face_index]:
                var _face_triangle = face.duplicate()
                module_face_triangle_dict[face_index].push_back(_face_triangle)

    #m_db_adapter.update_2d_faces(_module_name, module_face_triangle_dict, false, true)
    m_db_adapter.update_2d_faces(_module_name, module_face_triangle_dict, null, true)

##############################################################################
# Hashing
#
# - Go through each modules and find the hash of each face
##############################################################################
func _start_library_hash():
    #var _face_library = m_module_2d_face_library
    var _face_library = m_db_adapter.get_module_2d_faces_dict()
    var _face_r_library = m_db_adapter.get_module_2d_faces_dict(true)
    var percent = 0.0
    m_flag_async_finished = false
    var total_size = len(m_novel_modules)
    var _pname = PROGRESS_UPDATE_HASHING
    call_deferred("emit_percent_update", _pname, percent)
    for module_index in range(len(m_novel_modules)):
        var module_name = m_novel_modules[module_index]
        var face_hash   = _hash_step( _face_library[module_name])
        var face_hash_r = _hash_step(_face_r_library[module_name])
        m_db_adapter.update_mesh_hashes(module_name, face_hash, face_hash_r)
        percent = (float((module_index + 1)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step
    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

func _hash_step(_curr_module_entry) -> Dictionary:
    var face_hash_dict = {}
    for i in range(len(_curr_module_entry)):
        var curr_face = _curr_module_entry[i]
        var face_hash_value = "0"
        if len(curr_face) > 0:
            m_hash_ctx.start(HashingContext.HASH_SHA256)
            #var face = _sort_face(curr_face)
            var face = _create_sorted_vertex_list(curr_face)
            var pba = PackedByteArray(str(face).to_utf32_buffer())
            m_hash_ctx.update(pba)
            face_hash_value = m_hash_ctx.finish().hex_encode()
        face_hash_dict[i] = face_hash_value
    return face_hash_dict

func _create_sorted_vertex_list(_face:Array) -> Array:
    var vlist = []
    for i in range(len(_face)):
        var triangle = _face[i]
        for j in range(3):
            var vertex = _face[i][0][j]
            vlist.push_back([vertex, triangle[1]])

    var sorted:bool = false
    while not sorted:
        sorted = true
        for i in range(len(vlist) - 1):
            var v1 = vlist[i]
            var v2 = vlist[i + 1]
            # Compare the color first
            if v1[1].to_rgba64() < v2[1].to_rgba64():
                sorted = false
                var temp = vlist[i]
                vlist[i] = vlist[i + 1]
                vlist[i + 1] = temp
                break
            if (v1[1].to_rgba64() == v2[1].to_rgba64()) and (v1[0] < v2[0]):
                sorted = false
                var temp = vlist[i]
                vlist[i] = vlist[i + 1]
                vlist[i + 1] = temp
                break
            if (v1[1].to_rgba64() == v2[1].to_rgba64()) and (v1[0] == v2[0]):
                sorted = false
                vlist.remove_at(i+1)
                break
    #m_logger.debug ("Sorted: %s" % str(vlist))
    return vlist

func _sort_face(_face:Array) -> Array:
    # Sort the face's triangles, we can't change the order of the verticies, but we can change the order of the triangles
    # face is a a list of triangles along with their colors in the following format: [[Vector3, Vector3, Vector3], Color]
    var sorted:bool = false
    while not sorted:
        # If we can iterrate through the entire list without switching any triangles, then the list is sorted
        sorted = true
        for i in range(len(_face) - 1):
            var triangle1 = _face[i][0]
            var triangle2 = _face[i + 1][0]
            # Check if the first triangle is bigger than the second triangle
            if _is_triangle1_bigger(triangle1, triangle2):
                # Switch the triangles
                sorted = false
                var temp = _face[i]
                _face[i] = _face[i + 1]
                _face[i + 1] = temp
    return _face

func _is_triangle1_bigger(triangle1:Array, triangle2:Array) -> bool:

    for i in range(3):
        if triangle1[i] < triangle2[i]:
            return false
        if triangle1[i] > triangle2[i]:
            return true
    return false


##############################################################################
# Base Agnostic Hashing
#
# - Removes the base offset from the faces and generates a new hash
# XXX: I should be able to reuse the functions above to do this
# I need to modify '_start_library_hash' to be atomic
# I need to modify '_start_library_hash_analysis' to be atomic
##############################################################################
func _start_base_agnostic_library_hash():
    var percent = 0.0
    m_flag_async_finished = false
    var _face_library = m_db_adapter.get_module_2d_faces_dict()
    var _face_r_library = m_db_adapter.get_module_2d_faces_dict(true)
    var total_size = len(m_novel_modules)
    var _pname = PROGRESS_UPDATE_BASE_AGNOSTIC_HASH
    call_deferred("emit_percent_update", _pname, percent)
    for module_index in range(len(m_novel_modules)):
        var module_name = m_novel_modules[module_index]
        var _faces = _face_library[module_name]
        var _faces_r = _face_r_library[module_name]
        var _face_hashes = _hash_step( _faces)
        var _face_r_hashes = _hash_step(_faces_r)
        m_db_adapter.update_mesh_hashes(module_name, _face_hashes, _face_r_hashes, true)
        percent = (float((module_index + 1)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step
    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

##############################################################################
# Generate Index Map
#
# - Go through each module and find the faces that are the same
# - Create a dictionary of faces that are the same
##############################################################################
func _start_generating_index_dict():
    var percent = 0.0
    var _pname = PROGRESS_UPDATE_HASH_SID
    m_flag_async_finished = false

    var hash_dict = m_db_adapter.get_hash_dict()
    var ba_hash_dict = m_db_adapter.get_hash_dict(true)

    var h_len = len(hash_dict.keys())
    var ba_h_len = len(ba_hash_dict.keys())
    var current_index = 0
    var total_size = h_len + ba_h_len
    var sids = m_db_adapter.get_sids()
    sids.erase(null)
    sids.sort()
    var orphan_hashes = []
    var ba_orphan_hashes = []
    # Get a list of hashes
    for h in hash_dict.keys():
        if hash_dict[h]["sid"] == null:
            m_logger.debug("Found orphan hash: %s" % h)
            orphan_hashes.append(h)
    for h in ba_hash_dict.keys():
        if ba_hash_dict[h]["sid"] == null:
            m_logger.debug("Found ba orphan hash: %s" % h)
            ba_orphan_hashes.append(h)

    total_size = len(orphan_hashes) + len(ba_orphan_hashes)


    sids.sort()
    while len(sids) > 0 and sids[-1] == null:
        sids.pop_back()
    # insert an SID for the orphan hash
    var next_sid = 1
    if len(sids) > 0:
        next_sid = sids[-1] + 1
    for h in orphan_hashes:
        m_db_adapter.update_hash_sid(h, next_sid, false, false)
        next_sid += 1
        current_index += 1
        percent = (float((current_index)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    sids = m_db_adapter.get_sids(true)
    sids.sort()
    while len(sids) > 0 and sids[-1] == null:
        sids.pop_back()
    # insert an SID for the orphan hash
    next_sid = 1
    if len(sids) > 0:
        next_sid = sids[-1] + 1
    for h in ba_orphan_hashes:
        m_db_adapter.update_hash_sid(h, next_sid, false, true)
        next_sid += 1
        current_index += 1
        percent = (float((current_index)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

