extends Node


##############################################################################
# Exports
##############################################################################
@export var DATABASE_NAME:String = "wfc_database.db"
@export var DEBUG:bool = true

##############################################################################
# Constants
##############################################################################

enum FACE_T {
    FRONT = 0,
    BACK = 1,
    TOP = 2,
    BOTTOM = 3,
    RIGHT = 4,
    LEFT = 5
}
const LOGGER_NAME = "WFC DB Adapter"

##############################################################################
# Member Variables
##############################################################################
var m_logger = LogStream.new(LOGGER_NAME, LogStream.LogLevel.INFO)
var m_database : SQLite
var m_sid_dict = {}
var m_reflected_sid_dict = {}
var m_mesh_dict = null

##############################################################################
# Table Definitions
##############################################################################

const CONFIG_TABLE = "config"
const CONFIG_TABLE_SCHEME = {
    "name"        : {"data_type":"text",  "primary_key":true, "not_null":true, "auto_increment":false},
    "data_group"  : {"data_type":"text",  "not_null":false},
    "type"        : {"data_type":"text",  "not_null":true},
    "int_value"   : {"data_type":"int",   "not_null":false},
    "text_value"  : {"data_type":"text",  "not_null":false},
    "float_value" : {"data_type":"real",  "not_null":false},
    "blob_value"  : {"data_type":"blob",  "not_null":false}
}

const MODULE_TABLE = "modules"
const MODULE_TABLE_SCHEME = {
    "id"         : {"data_type":"int",    "primary_key":true, "not_null":true, "auto_increment":true},
    "name"       : {"data_type":"text",   "primary_key":false, "not_null":true},
    "x_flip"     : {"data_type":"int",    "not_null":false},
    "y_flip"     : {"data_type":"int",    "not_null":false},
    "front"      : {"data_type":"int",    "not_null":false},
    "back"       : {"data_type":"int",    "not_null":false},
    "top"        : {"data_type":"int",    "not_null":false},
    "bottom"     : {"data_type":"int",    "not_null":false},
    "right"      : {"data_type":"int",    "not_null":false},
    "left"       : {"data_type":"int",    "not_null":false},
    "x_rotation" : {"data_type":"float",  "not_null":false},
    "y_rotation" : {"data_type":"float",  "not_null":false},
    "z_rotation" : {"data_type":"float",  "not_null":false},
    "mesh"       : {"data_type":"blob",   "not_null":false}, # Mesh
    "transform"  : {"data_type":"blob",   "not_null":false}, # Transform
    "metadata"   : {"data_type":"blob",   "not_null":false}  # Dictionary
}

const SID_TABLE = "sid"
const SID_TABLE_SCHEME = {
    "sid" : {"data_type":"int", "primary_key":true, "not_null":true, "auto_increment":false},

    "asymmetric"  : {"data_type":"int",   "not_null":false},
    "module_list" : {"data_type":"blob",  "not_null":false}
}

const REFLECTED_SID_TABLE = "reflected_sids"
const REFLECTED_SID_TABLE_SCHEME = {
    "sid" : {"data_type":"int", "primary_key":true, "not_null":true, "auto_increment":false},
    "reflected_sid" : {"data_type":"int", "not_null":true}
}

var m_tables = {CONFIG_TABLE        : CONFIG_TABLE_SCHEME,
                MODULE_TABLE        : MODULE_TABLE_SCHEME,
                SID_TABLE           : SID_TABLE_SCHEME,
                REFLECTED_SID_TABLE : REFLECTED_SID_TABLE_SCHEME}

##############################################################################
# Public Functions
##############################################################################
func open_database(database_path: String, clear_rows: bool = false, force_new_tables:bool = false):
    m_logger.debug("Entered Open Database")
    m_database = SQLite.new()
    m_database.path = database_path
    m_database.open_db()

    if force_new_tables:
        m_logger.info("Drop all Tables")
        for table in m_tables.keys():
            var sel_string = "SELECT tbl_name FROM sqlite_master WHERE tbl_name = '{0}'".format({0:table})
            m_database.query(sel_string)
            if len(m_database.query_result) != 0:
                m_logger.debug("Dropping Table: {0}".format({0:table}))
                #for table in m_tables.keys():
                m_database.drop_table(table)

    elif clear_rows:
        m_logger.info("Clear all rows")
        for table in m_tables.keys():
            m_database.delete_rows(table, "*")

    ##########################################################################
    # Create the tables if they don't exist
    ##########################################################################
    for table in m_tables.keys():
        var sel_string = "SELECT tbl_name FROM sqlite_master WHERE tbl_name = '{0}'".format({0:table})
        m_database.query(sel_string)
        if len(m_database.query_result) == 0:
            m_logger.debug("{0} does not exist, creating it now.".format({0:table}))
            m_database.create_table(table, m_tables[table])

func clear_tables():
    m_logger.debug("Entered clear_tables")
    m_database.delete_rows(CONFIG_TABLE, "*")
    m_database.delete_rows(MODULE_TABLE, "*")
    m_database.delete_rows(REFLECTED_SID_TABLE, "*")
    m_database.delete_rows(SID_TABLE, "*")

func insert_reflected_sid(sid, reflected_sid):
    var d = { "sid": sid,
              "reflected_sid": reflected_sid
    }
    m_database.insert_row(REFLECTED_SID_TABLE, d)

func insert_expanded_module(_name, x_flip, y_flip, faces, _mesh, _transform, metadata=null):
    m_logger.debug("Entered insert_expanded_module")
    var d = { "name":       _name,
              "x_flip":     x_flip,
              "y_flip":     y_flip,
              "front":      faces[FACE_T.FRONT],
              "back":       faces[FACE_T.BACK],
              "top":        faces[FACE_T.TOP],
              "bottom":     faces[FACE_T.BOTTOM],
              "right":      faces[FACE_T.RIGHT],
              "left":       faces[FACE_T.LEFT],
              "mesh":       var_to_bytes_with_objects(_mesh),
              "transform":  var_to_bytes_with_objects(_transform),
              "x_rotation": 0,
              "y_rotation": 0,
              "z_rotation": 0

    }
    if metadata != null:
        d["metadata"] = var_to_bytes(metadata)
    m_database.insert_row(MODULE_TABLE, d)



func insert_sid_mapping(sid:int, asymmetric_flag:int, module_list: Array):
    m_logger.debug("Entered insert_sid_mapping")
    var d = { "sid": sid,
              "asymmetric": asymmetric_flag,
              "module_list": var_to_bytes(module_list)
    }
    m_database.insert_row(SID_TABLE, d)

func set_mesh_dir_path(_path):
    m_logger.debug("Entered set_mesh_dir_path")
    var d = { "name": "mesh_dir_path",
              "data_group": "config",
              "type": "text",
              "text_value": _path
    }
    m_database.insert_row(CONFIG_TABLE, d)

func get_mesh_dir_path() -> String:
    m_logger.debug("Entered get_mesh_dir_path")
    var sel_string = "SELECT text_value FROM config WHERE name = 'mesh_dir_path'"
    m_database.query(sel_string)
    return m_database.query_result[0]["text_value"]

func set_default_size_3d(_size:Vector3):
    m_logger.debug("Entered set_default_size_3d")
    var sizes = {"default_size_x": _size.x, "default_size_y": _size.y, "default_size_z": _size.z}
    for size_name in sizes.keys():
        var sel_string = "SELECT name FROM config WHERE name = '{0}'".format({0: size_name})
        m_database.query(sel_string)
        var d = { "name": size_name,
                  "data_group": "config",
                  "type": "float",
                  "float_value": sizes[size_name]
        }
        if len(m_database.query_result) == 0:
            m_database.insert_row(CONFIG_TABLE, d)
        else:
            m_database.update_rows(CONFIG_TABLE, "name = '{0}'".format({0: size_name}), d)

func get_default_size_3d() -> Vector3:
    m_logger.debug("Entered get_default_size_3d")
    var sel_string = "SELECT float_value FROM config WHERE name = 'default_size_x'"
    m_database.query(sel_string)
    var x = m_database.query_result[0]["float_value"]
    sel_string = "SELECT float_value FROM config WHERE name = 'default_size_y'"
    m_database.query(sel_string)
    var y = m_database.query_result[0]["float_value"]
    sel_string = "SELECT float_value FROM config WHERE name = 'default_size_z'"
    m_database.query(sel_string)
    var z = m_database.query_result[0]["float_value"]
    return Vector3(x, y, z)

func get_tile_size() -> Vector2:
    m_logger.debug("Entered get_tile_size")
    var sel_string = "SELECT float_value FROM config WHERE name = 'default_size_x'"
    m_database.query(sel_string)
    var x = m_database.query_result[0]["float_value"]
    sel_string = "SELECT float_value FROM config WHERE name = 'default_size_y'"
    m_database.query(sel_string)
    var y = m_database.query_result[0]["float_value"]
    return Vector2(x, y)

func get_module_dict() -> Dictionary:
    m_logger.debug("Entered get_module_dict")
    var sel_string = "SELECT * FROM modules"
    m_database.query(sel_string)
    var module_dict = {}
    for row in m_database.query_result:
        var _name = row["name"]
        var x_flip = row["x_flip"]
        var y_flip = row["y_flip"]
        var faces = [row["front"], row["back"], row["top"], row["bottom"], row["right"], row["left"]]
        var metadata = null
        if row["metadata"] != null:
            metadata = bytes_to_var(row["metadata"])
        module_dict[_name] = {  "id": row["id"],
                                "x_flip": x_flip,
                                "y_flip": y_flip,
                                "faces": faces,
                                "mesh" : bytes_to_var_with_objects(row["mesh"]),
                                "transform": bytes_to_var_with_objects(row["transform"]),
                                "metadata": metadata}
    return module_dict

func get_mesh_dict() -> Dictionary:
    m_logger.debug("Entered get_mesh_dict")
    if m_mesh_dict != null:
        return m_mesh_dict
    m_mesh_dict = {}
    var base_mesh_dir = get_mesh_dir_path()

    var sel_string = "SELECT * FROM modules"
    m_database.query(sel_string)
    for row in m_database.query_result:
        var _name = row["name"]
        # if the module has an x_flip or y_flip, then it is a duplicate of a mesh so we just continue
        if row["x_flip"] == 1 or row["y_flip"] == 1:
            continue
        m_mesh_dict[_name] = {  "id": row["id"]}
        # Open up the mesh and add it to the mesh_dict
        var mesh_path = "{0}{1}.obj".format({0: base_mesh_dir, 1: _name})
        var mesh = load(mesh_path)
        m_mesh_dict[_name]["mesh"] = mesh
    return m_mesh_dict

func get_sid_dict() -> Dictionary:
    m_logger.debug("Entered get_sid_dict")
    var sel_string = "SELECT * FROM sid"
    m_database.query(sel_string)
    var sid_dict = {}
    for row in m_database.query_result:
        var sid = row["sid"]
        var asymmetric = row["asymmetric"]
        var module_list = bytes_to_var(row["module_list"])
        sid_dict[sid] = {"asymmetric": asymmetric,
                         "module_list": module_list}
    return sid_dict

###############################################################################
# Private Functions
###############################################################################
func _ready():
    m_logger.debug("Entered _ready")

func _face_name_from_index(sid, base_agnostic = false) -> String:
    if (base_agnostic):
        match(sid):
            FACE_T.FRONT:
                return "ba_front"
            FACE_T.BACK:
                return "ba_back"
            FACE_T.TOP:
                return "ba_top"
            FACE_T.BOTTOM:
                return "ba_bottom"
            FACE_T.RIGHT:
                return "ba_right"
            FACE_T.LEFT:
                return "ba_left"
    else:
        match(sid):
            FACE_T.FRONT:
                return "front"
            FACE_T.BACK:
                return "back"
            FACE_T.TOP:
                return "top"
            FACE_T.BOTTOM:
                return "bottom"
            FACE_T.RIGHT:
                return "right"
            FACE_T.LEFT:
                return "left"
    return ""
