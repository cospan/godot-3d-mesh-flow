extends Node

class_name ModuleRWDatabaseAdapter

##############################################################################
# Signals
##############################################################################

@export var DEBUG:bool = false

##############################################################################
# Constants
##############################################################################
const ADAPTER_NAME = "DB RW Adapter"
const CONFIG_TABLE = "config_table"
const MODULE_TABLE = "mesh_table"
const HASH_TABLE = "hash_table"
const BA_HASH_TABLE = "ba_hash_table"
const VERSION:float = 0.1

enum FACE_T {
    FRONT = 0,
    BACK = 1,
    TOP = 2,
    BOTTOM = 3,
    RIGHT = 4,
    LEFT = 5
}

##############################################################################
# Member Variables
##############################################################################
var m_logger = LogStream.new(ADAPTER_NAME, LogStream.LogLevel.INFO)
var m_database : SQLite

##############################################################################
# Table Definitions
##############################################################################

const CONFIG_TABLE_SCHEME = {
    "name": {"data_type":"text", "primary_key":true, "not_null":true, "auto_increment":false},
    "data_group": {"data_type":"text", "not_null":false},
    "type": {"data_type":"text", "not_null":true},
    "int_value": {"data_type":"int", "not_null":false},
    "text_value": {"data_type":"text", "not_null":false},
    "float_value": {"data_type":"real", "not_null":false},
    "blob_value": {"data_type":"blob", "not_null":false}
}
const MODULE_TABLE_SCHEME = {
    "name": {"data_type":"text", "primary_key":true, "not_null":true, "auto_increment":false},
    "filename" : {"data_type":"text", "not_null":true},
    "md5" :  {"data_type":"text", "not_null":true},

    "bounds": {"data_type":"blob", "not_null":false},

    "faces_2d": {"data_type":"blob", "not_null":false},
    "faces_2d_r": {"data_type":"blob", "not_null":false},

    "ba_faces_2d": {"data_type":"blob", "not_null":false},
    "ba_faces_2d_r": {"data_type":"blob", "not_null":false},

    "front_face_hash": {"data_type":"text", "not_null":false},
    "back_face_hash": {"data_type":"text", "not_null":false},
    "top_face_hash": {"data_type":"text", "not_null":false},
    "bottom_face_hash": {"data_type":"text", "not_null":false},
    "right_face_hash": {"data_type":"text", "not_null":false},
    "left_face_hash": {"data_type":"text", "not_null":false},

    "ba_front_face_hash": {"data_type":"text", "not_null":false},
    "ba_back_face_hash": {"data_type":"text", "not_null":false},
    "ba_top_face_hash": {"data_type":"text", "not_null":false},
    "ba_bottom_face_hash": {"data_type":"text", "not_null":false},
    "ba_right_face_hash": {"data_type":"text", "not_null":false},
    "ba_left_face_hash": {"data_type":"text", "not_null":false},


    "front_top_offset": {"data_type": "real", "not_null":false},
    "back_top_offset": {"data_type": "real", "not_null":false},
    "top_top_offset": {"data_type": "real", "not_null":false},
    "bottom_top_offset": {"data_type": "real", "not_null":false},
    "right_top_offset": {"data_type": "real", "not_null":false},
    "left_top_offset": {"data_type": "real", "not_null":false},

    "front_bottom_offset": {"data_type": "real", "not_null":false},
    "back_bottom_offset": {"data_type": "real", "not_null":false},
    "top_bottom_offset": {"data_type": "real", "not_null":false},
    "bottom_bottom_offset": {"data_type": "real", "not_null":false},
    "right_bottom_offset": {"data_type": "real", "not_null":false},
    "left_bottom_offset": {"data_type": "real", "not_null":false},
}
const HASH_TABLE_SHEME = {
    "hash": {"data_type":"text", "primary_key":true, "not_null":true, "auto_increment":false},
    "r_hash": {"data_type":"text", "not_null":false},
    "symmetric": {"data_type":"int", "not_null":true},
    "reflected": {"data_type":"int", "not_null":true},
    "sid": {"data_type":"int", "not_null":false},
}
const BA_HASH_TABLE_SCHEME = {
    "hash": {"data_type":"text", "primary_key":true, "not_null":true, "auto_increment":false},
    "r_hash": {"data_type":"text", "not_null":false},
    "symmetric": {"data_type":"int", "not_null":false},
    "reflected": {"data_type":"int", "not_null":false},
    "sid": {"data_type":"int", "not_null":false},
}

###############################################################################
# Functions
###############################################################################
func _ready():
    if DEBUG:
      m_logger.set_current_level = LogStream.LogLevel.DEBUG

func _face_name_from_index(face_index, base_agnostic = false) -> String:
    if (base_agnostic):
        match(face_index):
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
        match(face_index):
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

##############################################################################
# Public Functions
##############################################################################
func open_database(database_path: String, force_new: bool = false):
    m_logger.debug("Entered Open Database")
    m_database = SQLite.new()
    m_database.path = database_path
    m_database.open_db()

    if force_new:
        m_database.delete_rows(CONFIG_TABLE, "*")
        m_database.delete_rows(MODULE_TABLE, "*")
        m_database.delete_rows(HASH_TABLE, "*")
        m_database.delete_rows(BA_HASH_TABLE, "*")

    ##########################################################################
    # Create the tables if they don't exist
    ##########################################################################
    # Config Table
    m_database.query("SELECT tbl_name FROM sqlite_master WHERE tbl_name = \"" + CONFIG_TABLE + "\"")
    if len(m_database.query_result) == 0:
        m_logger.debug("Config Table does not exist. Creating it now.")
        m_database.create_table(CONFIG_TABLE, CONFIG_TABLE_SCHEME)
    # Hash Table
    m_database.query("SELECT tbl_name FROM sqlite_master WHERE tbl_name = \"" + HASH_TABLE + "\"")
    if len(m_database.query_result) == 0:
        m_logger.debug("Hash Table does not exist. Creating it now.")
        m_database.create_table(HASH_TABLE, HASH_TABLE_SHEME)
    # Mesh Table
    m_database.query("SELECT tbl_name FROM sqlite_master WHERE tbl_name = \"" + MODULE_TABLE + "\"")
    if len(m_database.query_result) == 0:
        m_logger.debug("Mesh Table does not exist. Creating it now.")
        m_database.create_table(MODULE_TABLE, MODULE_TABLE_SCHEME)
    # BA Hash Table
    m_database.query("SELECT tbl_name FROM sqlite_master WHERE tbl_name = \"" + BA_HASH_TABLE + "\"")
    if len(m_database.query_result) == 0:
        m_logger.debug("BA Hash Table does not exist. Creating it now.")
        m_database.create_table(BA_HASH_TABLE, BA_HASH_TABLE_SCHEME)

##############################################################################
# Config Table Functions
##############################################################################
func get_default_size_3d() -> Vector3:
    #m_logger.debug("Entered Get Default Size 3D")
    m_database.query("SELECT float_value FROM \"" + CONFIG_TABLE + "\" WHERE name = 'default_size_x'")
    var x = m_database.query_result[0]["float_value"]
    m_database.query("SELECT float_value FROM \"" + CONFIG_TABLE + "\" WHERE name = 'default_size_y'")
    var y = m_database.query_result[0]["float_value"]
    m_database.query("SELECT float_value FROM \"" + CONFIG_TABLE + "\" WHERE name = 'default_size_z'")
    var z = m_database.query_result[0]["float_value"]
    return Vector3(x, y, z)

func get_default_size_2d() -> Vector2:
    #m_logger.debug("Entered Get Default Size 2D")
    if m_database == null:
        return Vector2(0, 0)

    m_database.query("SELECT float_value FROM \"" + CONFIG_TABLE + "\" WHERE name = 'default_size_x'")
    var x = m_database.query_result[0]["float_value"]
    m_database.query("SELECT float_value FROM \"" + CONFIG_TABLE + "\" WHERE name = 'default_size_z'")
    var z = m_database.query_result[0]["float_value"]
    return Vector2(x, z)

func get_version() -> float:
    m_logger.debug("Entered Get Version")
    m_database.query("SELECT float_value FROM \"" + CONFIG_TABLE + "\" WHERE name = 'version'")
    return m_database.query_result[0]["float_value"]


##############################################################################
# Module Table Functions
##############################################################################
func get_module_count() -> int:
    m_logger.debug("Entered Get Module Count")
    m_database.query("SELECT name FROM '" + MODULE_TABLE + "'")
    return len(m_database.query_result)

func get_module_names() -> Array:
    m_logger.debug("Entered Get Module Names")
    m_database.query("SELECT name FROM '" + MODULE_TABLE + "'")
    var module_names = []
    for row in m_database.query_result:
        module_names.append(row["name"])
    return module_names

func get_top_offset(module_name:String, face_index):
    m_logger.debug("Entered Get Top Offset")
    var face_top_offset = "%s_top_offset" % _face_name_from_index(face_index)
    var select_condition = "name = '%s' and " % module_name
    var rows = m_database.select_rows(MODULE_TABLE, select_condition, [face_top_offset])
    if len(rows) == 0:
        return null
    return rows[0][face_top_offset]

func get_top_offset_dict():
    m_logger.debug("Entered get_bottom_offset_dict")
    var rows = m_database.select_rows(MODULE_TABLE, "", ["name", "front_top_offset", "back_top_offset", "top_top_offset", "bottom_top_offset", "right_top_offset", "left_top_offset"])
    var dict = {}
    for row in rows:
        var _name = row["name"]
        dict[name] = {}
        dict[_name][0] = row["front_top_offset"]
        dict[_name][1] = row["back_top_offset"]
        dict[_name][2] = row["top_top_offset"]
        dict[_name][3] = row["bottom_top_offset"]
        dict[_name][4] = row["right_top_offset"]
        dict[_name][5] = row["left_top_offset"]
    return dict

func get_bottom_offset(module_name:String, face_index: int):
    m_logger.debug("Entered Get Bottom Offset")
    var face_bottom_offset = "%s_bottom_offset" % _face_name_from_index(face_index)
    var select_condition = "name = '%s'" % module_name
    var rows = m_database.select_rows(MODULE_TABLE, select_condition, [face_bottom_offset])
    if len(rows) == 0:
        return null
    return rows[0][face_bottom_offset]

func get_bottom_offset_dict():
    m_logger.debug("Entered get_bottom_offset_dict")
    var rows = m_database.select_rows(MODULE_TABLE, "", ["name", "front_bottom_offset", "back_bottom_offset", "top_bottom_offset", "bottom_bottom_offset", "right_bottom_offset", "left_bottom_offset"])
    var dict = {}
    for row in rows:
        var _name = row["name"]
        dict[_name] = {}
        dict[_name][0] = row["front_bottom_offset"]
        dict[_name][1] = row["back_bottom_offset"]
        dict[_name][2] = row["top_bottom_offset"]
        dict[_name][3] = row["bottom_bottom_offset"]
        dict[_name][4] = row["right_bottom_offset"]
        dict[_name][5] = row["left_bottom_offset"]
    return dict

func get_bounds(module_name: String):
    m_logger.debug("Entered Get Bounds")
    #m_database.query("SELECT bounds FROM '" + MODULE_TABLE + "' WHERE name = '" + module_name + "'")
    var select_condition = "name = '%s'" % module_name
    var rows = m_database.select_rows(MODULE_TABLE, select_condition, ["bounds"])
    if len(rows) == 0:
        return null
    return bytes_to_var(rows[0]["bounds"])

func get_module_2d_faces(module_name: String, reflected:bool = false):
    m_logger.debug("Entered Get 2D Faces for %s" % module_name)
    var face_name = "faces_2d"
    if reflected:
        face_name = "faces_2d_r"
    var select_cond = "name = '%s'" % module_name
    var rows = m_database.select_rows(MODULE_TABLE, select_cond, ["faces_2d", "faces_2d_r"])
    if len(rows) == 0:
        return null
    return bytes_to_var(rows[0][face_name])

func get_module_2d_faces_dict(reflected:bool = false):
    m_logger.debug("Entered Get 2D Faces Dict")
    var face_dict = {}
    var face_type = "faces_2d"
    if reflected:
        face_type = "faces_2d_r"
    var rows = m_database.select_rows(MODULE_TABLE, "", ["name", "faces_2d", "faces_2d_r"])
    for row in rows:
        face_dict[row["name"]] = bytes_to_var(row[face_type])
    return face_dict

##############################################################################
# Hash ID Table Functions
##############################################################################
func get_sids(base_agnostic:bool = false) -> Array:
    m_logger.debug("Entered get_sids")
    var table_name = HASH_TABLE
    if base_agnostic:
        table_name = BA_HASH_TABLE
    var rows = m_database.select_rows(table_name, "", ["sid"])
    var sids = []
    for row in rows:
        sids.append(row["sid"])
    return sids

func get_sids_hash_dict(bash_agnostic:bool = false) -> Dictionary:
    m_logger.debug("Entered get_sids_hash_dict")
    var sids_hash_dict = {}
    var table_name = HASH_TABLE
    if bash_agnostic:
        table_name = BA_HASH_TABLE
    var rows = m_database.select_rows(table_name, "", ["sid", "hash"])
    for row in rows:
        var sid = row["sid"]
        if sid not in sids_hash_dict:
            sids_hash_dict[sid] = []
        sids_hash_dict[sid].append(row["hash"])
    return sids_hash_dict

func get_sids_total_module_face_count(_sid:int, _base_agnostic:bool = false) -> int:
    #XXX: is there a better way to do this using SQL?
    m_logger.debug("Entered Get Sids Total Module Face Count")
    var hash_dict = get_sids_hash_dict(_base_agnostic)
    var count = 0
    # Go through each of the hashes and find the total number of module faces that are associated with the hash
    for h in hash_dict[_sid]:
        count += len(get_name_face_tuple_from_hash(h, _base_agnostic))
    return count

func get_next_available_sid(base_agnostic:bool = false) -> int:
    var table_name = HASH_TABLE
    if base_agnostic:
        table_name = BA_HASH_TABLE
    var rows = m_database.select_rows(table_name, "", ["sid"])
    var sids = []
    for row in rows:
        sids.push_back(row["sid"])
    sids.sort()
    for sid_index in range(len(sids)):
        if not sids.has(sid_index):
            return sid_index
    return len(sids)

func get_hash_dict(base_agnostic:bool = false) -> Dictionary:
    #m_logger.debug("Entered Get Hash Dict")
    var hash_dict = {}
    var table_name = HASH_TABLE
    if base_agnostic:
        table_name = BA_HASH_TABLE
    var rows = m_database.select_rows(table_name, "", ["hash", "r_hash", "symmetric", "reflected", "sid"])
    for row in rows:
        hash_dict[row["hash"]] = {}
        hash_dict[row["hash"]]["r_hash"] = row["r_hash"]
        hash_dict[row["hash"]]["symmetric"] = row["symmetric"]
        hash_dict[row["hash"]]["reflected"] = row["reflected"]
        hash_dict[row["hash"]]["sid"] = row["sid"]
    return hash_dict

func get_hashes_from_sid(sid:int, base_agnostic:bool = false) -> Array:
    var hashes = []
    m_logger.debug("Entered Get Hashes from sid: %d" % sid)
    var table_name = HASH_TABLE
    if base_agnostic:
        table_name = BA_HASH_TABLE
    var select_cond = "sid = %d" % sid
    var rows = m_database.select_rows(table_name, select_cond, ["hash"])
    for row in rows:
        hashes.append(row["hash"])
    return hashes

func get_hash_dict_from_module_name_and_face(module_name:String, face_index:int, base_agnostic:bool = false):
    m_logger.debug("Entered Get Hash Dict From name and face")
    var face_name = "%s_face_hash" % _face_name_from_index(face_index, base_agnostic)
    var table_name = HASH_TABLE
    if base_agnostic:
        table_name = BA_HASH_TABLE
    var select_condition = "select * from {0} join mesh_table on mesh_table.{1} = hash_table.hash where mesh_table.name = '{2}'"
    select_condition = select_condition.format({0:table_name, 1:face_name, 2:module_name})
    m_database.query(select_condition)
    if len(m_database.query_result) == 0:
        return null
    var hash_dict = {}
    hash_dict["hash"] = m_database.query_result[0]["hash"]
    hash_dict["r_hash"] = m_database.query_result[0]["r_hash"]
    hash_dict["reflected"] = m_database.query_result[0]["reflected"]
    hash_dict["symmetric"] = m_database.query_result[0]["symmetric"]
    hash_dict["sid"] = m_database.query_result[0]["sid"]
    return hash_dict

func get_hash_from_module_name_and_face(module_name:String, face_index:int, base_agnostic:bool = false):
    var face_name = "%s_face_hash" % _face_name_from_index(face_index, base_agnostic)
    var select_condition = "name = '%s'" % module_name
    var rows = m_database.select_rows(MODULE_TABLE, select_condition, [face_name])
    if len(rows) == 0:
        return ""
    return rows[0][face_name]

func get_name_face_tuple_from_hash(_hash: String, base_agnostic:bool = false):
    m_logger.debug("Entered Get name face tuple from hash: %s" % _hash)
    var face_names = ["front_face_hash", "back_face_hash", "top_face_hash", "bottom_face_hash", "right_face_hash", "left_face_hash"]
    var mesh_table = MODULE_TABLE
    if base_agnostic:
        face_names = ["ba_front_face_hash", "ba_back_face_hash", "ba_top_face_hash", "ba_bottom_face_hash", "ba_right_face_hash", "ba_left_face_hash"]
    var select_cond = "{0} = {1}"
    var face_array = []
    for i in range(len(face_names)):
        var face = face_names[i]
        var sc = select_cond.format({0:face, 1:"'" + _hash + "'"})
        var rows = m_database.select_rows(mesh_table, sc, ["name"])
        for row in rows:
            face_array.append([row["name"], i])
    return face_array

func get_hash_name_face_tuple_dict(base_agnostic:bool = false) -> Dictionary:
    m_logger.debug("Entered get_hash_name_face_tuple_dict")
    var face_names = ["front_face_hash", "back_face_hash", "top_face_hash", "bottom_face_hash", "right_face_hash", "left_face_hash"]
    var htable = HASH_TABLE
    if base_agnostic:
        face_names = ["ba_front_face_hash", "ba_back_face_hash", "ba_top_face_hash", "ba_bottom_face_hash", "ba_right_face_hash", "ba_left_face_hash"]
        htable = BA_HASH_TABLE
    var hash_face_dict = {}
    var hrows = m_database.select_rows(htable, "", ["hash"])
    for row in hrows:
        hash_face_dict[row["hash"]] = []

    var select_list = face_names.duplicate()
    select_list.append("name")
    var rows = m_database.select_rows(MODULE_TABLE, "", select_list)
    for row in rows:
        for face_name in face_names:
            #XXX: Possible crash when database is in the middle of loading, need to validate before starting
            hash_face_dict[row[face_name]].append([row["name"], row[face_name]])
    return hash_face_dict

##############################################################################
# Update Functions
##############################################################################
func cleanup_database():
    var hash_dict = get_hash_name_face_tuple_dict()
    for _hash in hash_dict.keys():
        if len(hash_dict[_hash]) == 0:
            m_logger.info("Removing orphan hash: %s from hash table" % _hash)
            var query_string = "hash = '%s'" % _hash
            m_database.delete_rows(HASH_TABLE, query_string)
    hash_dict = get_hash_name_face_tuple_dict(true)
    for _hash in hash_dict.keys():
        if len(hash_dict[_hash]) == 0:
            m_logger.info("Removing orphan hash: %s from BA hash table" % _hash)
            var query_string = "hash = '%s'" % _hash
            m_database.delete_rows(HASH_TABLE, query_string)

func update_hash_sid(_hash: String, sid: int, reflected: int, base_agnostic:bool = false) -> bool:
    m_logger.debug("Entered Update Hash SID")
    var table_name = HASH_TABLE
    if base_agnostic:
        table_name = BA_HASH_TABLE

    m_database.query("SELECT hash FROM '" + table_name + "' WHERE hash = '" + _hash + "'")
    if len(m_database.query_result) == 0:
        return false
    m_database.update_rows(table_name, "hash = '" + _hash + "'", {"sid": sid, "reflected": reflected})
    return true

func remove_hash_from_sid(_hash: String, base_agnostic:bool = false) -> bool:
    m_logger.debug("Entered Remove Hash from SID")
    var table_name = HASH_TABLE
    if base_agnostic:
        table_name = BA_HASH_TABLE
    var select_condition = "hash = '%s'" % _hash
    var rows = m_database.select_rows(table_name, select_condition, ["hash"])
    if len(rows) == 0:
        return false
    var new_sid = get_next_available_sid(base_agnostic)
    m_database.update_rows(table_name, select_condition, {"hash" : _hash, "sid" : new_sid})
    return true

func set_default_size(default_size: Vector3):
    m_logger.debug("Entered Set Default Size")
    if m_database.query("SELECT data_group FROM \"" + CONFIG_TABLE + "\" WHERE data_group = 'default_size'") and m_database.query_result.size() == 0:
        m_logger.debug("Default Size does not exist. Creating it now.")
        m_database.insert_row(CONFIG_TABLE, {"name": "default_size_x", "type": "real", "data_group": "default_size", "float_value": default_size.x})
        m_database.insert_row(CONFIG_TABLE, {"name": "default_size_y", "type": "real", "data_group": "default_size", "float_value": default_size.y})
        m_database.insert_row(CONFIG_TABLE, {"name": "default_size_z", "type": "real", "data_group": "default_size", "float_value": default_size.z})

    m_database.update_rows(CONFIG_TABLE, "name = 'default_size_x'", {"float_value": default_size.x})
    m_database.update_rows(CONFIG_TABLE, "name = 'default_size_y'", {"float_value": default_size.y})
    m_database.update_rows(CONFIG_TABLE, "name = 'default_size_z'", {"float_value": default_size.z})

func update_module(module_dict:Dictionary):
    m_logger.debug("Entered Update Module")
    var module_name = module_dict["name"]
    m_database.query("SELECT name FROM '" + MODULE_TABLE + "' WHERE name = '" + module_name  + "'")
    if len(m_database.query_result) == 0:
        m_logger.debug("Module does not exist. Creating it now.")
        m_database.insert_row(MODULE_TABLE, module_dict)
    else:
        m_logger.debug("Module exists. Updating it now.")
        m_database.update_rows(MODULE_TABLE, "name = '" + module_name + "'", module_dict)

func update_mesh_hashes(_module_name:String, _hash_dict:Dictionary, _r_hash_dict:Dictionary, base_agnostic:bool = false):
    m_logger.debug("Entered mesh face hash")
    # Check if there exist a row with the module name within the 'mesh_table'
    var module_dict =  {"name" : _module_name}
    var table_name = HASH_TABLE
    if base_agnostic:
        table_name = BA_HASH_TABLE

    for _face_index in _hash_dict.keys():
        var _hash = _hash_dict[_face_index]
        var _r_hash = _r_hash_dict[_face_index]
        m_database.query("SELECT hash FROM '" + table_name + "' WHERE hash = '" + _hash + "'")
        if len(m_database.query_result) == 0:
            m_database.insert_row(table_name, {"hash": _hash, "r_hash": _r_hash, "symmetric": int(_hash == _r_hash), "reflected": 0})
        # Update the module table
        var face_name = "%s_face_hash" % _face_name_from_index(_face_index, base_agnostic)
        module_dict[face_name] = _hash

    m_database.query("SELECT name FROM '" + MODULE_TABLE + "' WHERE name = '" + _module_name + "'")
    if len(m_database.query_result) == 0:
        m_database.insert_row(MODULE_TABLE, {"name": _module_name})
    var select_cond = "name = '" + _module_name + "'"
    m_database.update_rows(MODULE_TABLE, select_cond, module_dict)

func update_hash_row(hash_dict:Dictionary, base_agnostic:bool = false):
    m_logger.debug("Entered Update Hash Row")
    var _hash = hash_dict["hash"]
    var table_name = HASH_TABLE
    if base_agnostic:
        table_name = BA_HASH_TABLE
    m_database.query("SELECT hash FROM '" + table_name + "' WHERE hash = '" + _hash + "'")
    if len(m_database.query_result) == 0:
        m_database.insert_row(table_name, hash_dict)
    else:
        m_database.update_rows(table_name, "hash = '" + _hash + "'", hash_dict)

func update_top_offset(module_name:String, face_index: int, top_offset:float):
    m_logger.debug("Entered set top offset")
    var select_condition = "name = '%s'" % module_name
    var rows = m_database.select_rows(MODULE_TABLE, select_condition, ["bounds"])
    #m_database.query("SELECT name FROM '" + MODULE_TABLE + "' WHERE name = '" + module_name + "'")
    var face_top_offset = "%s_top_offset" % _face_name_from_index(face_index)
    var d = {"name" : module_name, face_top_offset: top_offset}

    #if len(m_database.query_result) == 0:
    if len(rows) == 0:
        m_database.insert_row(MODULE_TABLE, d)
    else:
        m_database.update_rows(MODULE_TABLE, "name = '" + module_name + "'", d)

func update_bottom_offset(module_name:String, face_index: int, bottom_offset:float):
    m_logger.debug("Entered set top offset")
    var face_bottom_offset = "%s_bottom_offset" % _face_name_from_index(face_index)
    var select_condition = "name = '%s'" % module_name
    var rows = m_database.select_rows(MODULE_TABLE, select_condition, [face_bottom_offset])
    #m_database.query("SELECT name FROM '" + MODULE_TABLE + "' WHERE name = '" + module_name + "'")
    var d = {"name" : module_name, face_bottom_offset: bottom_offset}

    #if len(m_database.query_result) == 0:
    if len(rows) == 0:
        m_database.insert_row(MODULE_TABLE, d)
    else:
        m_database.update_rows(MODULE_TABLE, "name = '" + module_name + "'", d)

func update_parser_bounds(module_name:String, bounds: Array):
    var select_condition = "name = '%s'" % module_name
    var rows = m_database.select_rows(MODULE_TABLE, select_condition, ["bounds"])
    #m_database.query("SELECT name FROM '" + MODULE_TABLE + "' WHERE name = '" + module_name + "'")
    var d = {"name" : module_name, "bounds": var_to_bytes(bounds)}

    #if len(m_database.query_result) == 0:
    if len(rows) == 0:
        m_database.insert_row(MODULE_TABLE, d)
    else:
        m_database.update_rows(MODULE_TABLE, "name = '" + module_name + "'", d)

func update_2d_faces(module_name:String, face_dict:Dictionary, reflected_face_dict = null, base_agnostic:bool = false):
    m_logger.debug("Entered Update 2D Faces")
    var d = {"name" : module_name}
    var column_name = "faces_2d"
    var column_name_r = "faces_2d_r"
    if base_agnostic:
        column_name = "ba_faces_2d"
        column_name_r = "ba_faces_2d_r"
    if reflected_face_dict:
        d[column_name_r] = var_to_bytes(reflected_face_dict)
    d[column_name] = var_to_bytes(face_dict)
    var select_condition = "name = '%s'" % module_name
    #var rows = m_database.select_rows(MODULE_TABLE, select_condition, ["face_2d"])
    m_database.query("SELECT name FROM '" + MODULE_TABLE + "' WHERE name = '" + module_name + "'")

    if len(m_database.query_result) == 0:
        m_database.insert_row(MODULE_TABLE, d)
    else:
        m_database.update_rows(MODULE_TABLE, select_condition, d)


##############################################################################
# RW Functions
##############################################################################

func set_version(version: float):
    m_logger.debug("Entered Set Version")
    if m_database.query("SELECT data_group FROM \"" + CONFIG_TABLE + "\" WHERE data_group = 'version'") and m_database.query_result.size() == 0:
        m_logger.debug("Version does not exist. Creating it now.")
        m_database.insert_row(CONFIG_TABLE, {"name": "version", "type": "real", "data_group": "version", "float_value": version})
    m_database.update_rows(CONFIG_TABLE, "name = 'version'", {"float_value": version})

func backup_to(destination:String) -> bool:
    m_logger.debug("Backing up database to %s" % destination)
    return m_database.backup_to(destination)

func get_bounds_dict():
    m_logger.debug("Entered Get Bounds Dict")
    var bounds_dict = {}
    var rows = m_database.select_rows(MODULE_TABLE, "", ["name", "bounds"])
    for row in rows:
        var _name = row["name"]
        bounds_dict[_name] = bytes_to_var(row["bounds"])
    return bounds_dict

func delete_all_modules():
    m_logger.debug("Entered Delete All Modules")
    m_database.delete_rows(MODULE_TABLE, "*")

func delete_module(module_name:String):
    m_logger.debug("Entered Delete Module")
    var sel_con = "name = '%s'" % module_name
    m_database.delete_rows(MODULE_TABLE, sel_con)

func get_file_info_dict() -> Dictionary:
    var file_info_dict = {}
    var rows = m_database.select_rows(MODULE_TABLE, "", ["name", "md5", "filename"])
    for row in rows:
        var n = row["name"]
        file_info_dict[n] = {}
        file_info_dict[n]["md5"] = row["md5"]
        file_info_dict[n]["filename"] = row["filename"]
    return file_info_dict

func set_file_info_dict(fs_dict:Dictionary):
    for _name in fs_dict.keys():
        var select_cond = "name = '%s'" % _name
        var d = {"name" : _name, "md5": fs_dict[_name]["md5"], "filename":fs_dict[_name]["filename"]}
        var rows = m_database.select_rows(MODULE_TABLE, select_cond, ["name"])
        if len(rows) == 0:
            m_database.insert_row(MODULE_TABLE, d)
        else:
            m_database.update_rows(MODULE_TABLE, select_cond, d)


