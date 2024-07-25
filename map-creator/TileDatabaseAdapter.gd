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
    "name": {"data_type":"text", "primary_key":true, "not_null":true, "auto_increment":false},
    "md5" :  {"data_type":"text", "not_null":false},

    "front_face_index"  : {"data_type":"int", "not_null":false},
    "back_face_index"   : {"data_type":"int", "not_null":false},
    "top_face_index"    : {"data_type":"int", "not_null":false},
    "bottom_face_index" : {"data_type":"int", "not_null":false},
    "right_face_index"  : {"data_type":"int", "not_null":false},
    "left_face_index"   : {"data_type":"int", "not_null":false}
}

const SID_TABLE = "sid"
const SID_TABLE_SCHEME = {
    "sid" : {"data_type":"int", "primary_key":true, "not_null":true, "auto_increment":false},

    "asymmetric"  : {"data_type":"int",   "not_null":false},
    "module_list" : {"data_type":"blob",  "not_null":false}
}

var m_tables = {CONFIG_TABLE  : CONFIG_TABLE_SCHEME,
                MODULE_TABLE  : MODULE_TABLE_SCHEME,
                SID_TABLE     : SID_TABLE_SCHEME}

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


func insert_modules(dict):
    m_logger.debug("Entered update_module")
    m_database.delete_rows(MODULE_TABLE, "*")
    for _name in dict.keys():
        #Change the face indexes to the text label
        var d = { "name": _name,
                  "front_face_index":      dict[_name][FACE_T.FRONT]["sid"],
                  "back_face_index":       dict[_name][FACE_T.BACK]["sid"],
                  "top_face_index":        dict[_name][FACE_T.TOP]["sid"],
                  "bottom_face_index":     dict[_name][FACE_T.BOTTOM]["sid"],
                  "right_face_index":      dict[_name][FACE_T.RIGHT]["sid"],
                  "left_face_index":       dict[_name][FACE_T.LEFT]["sid"],

                  "front_face_reflected":  dict[_name][FACE_T.FRONT]["reflected"],
                  "back_face_reflected":   dict[_name][FACE_T.BACK]["reflected"],
                  "top_face_reflected":    dict[_name][FACE_T.TOP]["reflected"],
                  "bottom_face_reflected": dict[_name][FACE_T.BOTTOM]["reflected"],
                  "right_face_reflected":  dict[_name][FACE_T.RIGHT]["reflected"],
                  "left_face_reflected":   dict[_name][FACE_T.LEFT]["reflected"]
        }

        m_database.insert_row(MODULE_TABLE, d)

func insert_sid_socket_map(sid_dict:Dictionary):
    m_logger.debug("Entered insert_sids")
    #Each SID is dictionary with the following keys:
    # "sid" : int
    # "asymmetric" : int
    # "module_list" : Array of Strings
    m_database.delete_rows(SID_TABLE, "*")
    for sid in sid_dict.keys():
        var d = { "sid" : sid,
                  "asymmetric" : sid_dict[sid]["asymmetric"],
                  "module_list" : sid_dict[sid]["module_list"] }
        m_database.insert_row(SID_TABLE, d)

func get_module_dict() -> Dictionary:
    m_logger.debug("Get all modules dictionary")
    var module_dict = {}
    var rows = m_database.select_rows(MODULE_TABLE, "", ["name", "front_face_index", "back_face_index", "top_face_index", "bottom_face_index", "right_face_index", "left_face_index", "front_face_reflected", "back_face_reflected", "top_face_reflected", "bottom_face_reflected", "right_face_reflected", "left_face_reflected"])

    for row in rows:
        var _name = row["name"]
        module_dict[_name] = {}
        module_dict[_name][FACE_T.FRONT]  = {}
        module_dict[_name][FACE_T.BACK  ] = {}
        module_dict[_name][FACE_T.TOP   ] = {}
        module_dict[_name][FACE_T.BOTTOM] = {}
        module_dict[_name][FACE_T.RIGHT ] = {}
        module_dict[_name][FACE_T.LEFT  ] = {}

        module_dict[_name][FACE_T.FRONT ]["sid"] = row["front_face_index"]
        module_dict[_name][FACE_T.BACK  ]["sid"] = row["back_face_index"]
        module_dict[_name][FACE_T.TOP   ]["sid"] = row["top_face_index"]
        module_dict[_name][FACE_T.BOTTOM]["sid"] = row["bottom_face_index"]
        module_dict[_name][FACE_T.RIGHT ]["sid"] = row["right_face_index"]
        module_dict[_name][FACE_T.LEFT  ]["sid"] = row["left_face_index"]

        module_dict[_name][FACE_T.FRONT ]["reflected"] = row["front_face_reflected"]
        module_dict[_name][FACE_T.BACK  ]["reflected"] = row["back_face_reflected"]
        module_dict[_name][FACE_T.TOP   ]["reflected"] = row["top_face_reflected"]
        module_dict[_name][FACE_T.BOTTOM]["reflected"] = row["bottom_face_reflected"]
        module_dict[_name][FACE_T.RIGHT ]["reflected"] = row["right_face_reflected"]
        module_dict[_name][FACE_T.LEFT  ]["reflected"] = row["left_face_reflected"]

    return module_dict


###############################################################################
# Functions
###############################################################################
func _ready():
    #if DEBUG:
    #    m_logger.set_current_level = LogStream.LogLevel.DEBUG
    m_tables[CONFIG_TABLE]  = CONFIG_TABLE_SCHEME
    m_tables[MODULE_TABLE]  = MODULE_TABLE_SCHEME
    m_tables[SID_TABLE]     = SID_TABLE_SCHEME

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

