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
    "x_flip": {"data_type":"int", "not_null":false},
    "y_flip": {"data_type":"int", "not_null":false},
    "front"  : {"data_type":"int", "not_null":false},
    "back"   : {"data_type":"int", "not_null":false},
    "top"    : {"data_type":"int", "not_null":false},
    "bottom" : {"data_type":"int", "not_null":false},
    "right"  : {"data_type":"int", "not_null":false},
    "left"   : {"data_type":"int", "not_null":false}
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


func insert_expanded_modules_and_sids(dict = {}, reflected_dict = {}):
    m_logger.debug("Entered update_module")
    m_database.delete_rows(MODULE_TABLE, "*")
    m_database.delete_rows(REFLECTED_SID_TABLE, "*")
    m_database.delete_rows(SID_TABLE, "*")

    m_logger.debug("Writing Reflected SID Table")
    for s in reflected_dict.keys():
        var d = { "sid": s,
                  "reflected_sid": reflected_dict[s]
        }
        m_database.insert_row(REFLECTED_SID_TABLE, d)

    m_sid_dict = {}

    m_logger.debug("Writing Module Table")
    for _name in dict.keys():
        var d = { "name":       _name,
                  "x_flip":     dict[_name]["x_flip"],
                  "y_flip":     dict[_name]["y_flip"],
                  "front":      dict[_name]["faces"][FACE_T.FRONT],
                  "back":       dict[_name]["faces"][FACE_T.BACK],
                  "top":        dict[_name]["faces"][FACE_T.TOP],
                  "bottom":     dict[_name]["faces"][FACE_T.BOTTOM],
                  "right":      dict[_name]["faces"][FACE_T.RIGHT],
                  "left":       dict[_name]["faces"][FACE_T.LEFT],
        }

        m_database.insert_row(MODULE_TABLE, d)

        for f in dict[_name]["faces"].keys():
            var fsid = dict[_name]["faces"][f]
            if not m_sid_dict.has(fsid):
                if not reflected_dict.keys().has(fsid):
                    continue
                m_sid_dict[fsid] = {"asymmetric": 0, "module_list": []}
                if reflected_dict[fsid] != -1:
                    m_sid_dict[fsid]["asymmetric"] = 1

            m_sid_dict[fsid]["module_list"].append([_name, f])

    m_logger.debug("Writing SID Table")
    for sid in m_sid_dict.keys():
        var d = { "sid": sid,
                  "asymmetric": m_sid_dict[sid]["asymmetric"],
                  "module_list": var_to_bytes(m_sid_dict[sid]["module_list"])
        }
        m_database.insert_row(SID_TABLE, d)


func clear_tables():
    m_logger.debug("Entered clear_tables")
    m_database.delete_rows(MODULE_TABLE, "*")
    m_database.delete_rows(REFLECTED_SID_TABLE, "*")
    m_database.delete_rows(SID_TABLE, "*")

func insert_reflected_sid(sid, reflected_sid):
    var d = { "sid": sid,
              "reflected_sid": reflected_sid
    }
    m_database.insert_row(REFLECTED_SID_TABLE, d)

func insert_expanded_module(_name, x_flip, y_flip, faces):
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
    }
    m_database.insert_row(MODULE_TABLE, d)

func insert_sid_mapping(sid:int, asymmetric_flag:int, module_list: Array):
    m_logger.debug("Entered insert_sid_mapping")
    var d = { "sid": sid,
              "asymmetric": asymmetric_flag,
              "module_list": var_to_bytes(module_list)
    }
    m_database.insert_row(SID_TABLE, d)


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

