extends Node

##############################################################################
# Signals
##############################################################################

signal database_data_ready
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
const KEY_SIZE = int(64 / 3.0)
const KEY_Z_POS = KEY_SIZE * 0
const KEY_Y_POS = KEY_SIZE * 1
const KEY_X_POS = KEY_SIZE * 2
const KEY_MASK = (2 ** KEY_SIZE) - 1
const KEY_SHIFT_SIZE = KEY_SIZE - 1
const KEY_SHIFT_VAL = (2 ** KEY_SHIFT_SIZE)

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Location Database Adapter", LogStream.LogLevel.DEBUG)
var m_database : SQLite

#######################################
# Thread Members
#######################################

var m_task_db_adapter_to_thread_queue:ThreadSafeQueue
var m_task_db_adapter_from_thread_queue:ThreadSafeQueue

var m_task_db_adapter = null

#######################################
# Exports
#######################################
@export var DATABASE_NAME:String = "wfc_database.db"
@export var DEBUG:bool = true



########################################
# Table Definitions
########################################

const POS_TABLE = "pos"
const POS_TABLE_SCHEME = {
    "id"        : {"data_type":"int",   "primary_key":true, "not_null":true, "auto_increment":false},
    "name"      : {"data_type":"text",  "not_null":true},
    "x"         : {"data_type":"int",   "not_null":false},
    "y"         : {"data_type":"int",   "not_null":false},
    "z"         : {"data_type":"int",   "not_null":false},
    "x_reflect" : {"data_type":"int",   "not_null":false},
    "y_reflect" : {"data_type":"int",   "not_null":false},
    "rot_90_cw" : {"data_type":"int",   "not_null":false},
}

var m_tables = {
      POS_TABLE: POS_TABLE_SCHEME,
    }


##############################################################################
# Public Functions
##############################################################################
func open_database(database_path: String, clear_rows: bool = false, force_new_tables:bool = false):
    m_logger.debug("Entered Open Database")
    m_database = SQLite.new()
    #m_database.path = folder_path + DATABASE_NAME
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
        m_logger.info("Adding Table: %s" % str(table))
        var sel_string = "SELECT tbl_name FROM sqlite_master WHERE tbl_name = '{0}'".format({0:table})
        m_database.query(sel_string)
        if len(m_database.query_result) == 0:
            m_logger.debug("{0} does not exist, creating it now.".format({0:table}))
            m_database.create_table(table, m_tables[table])

func clear_tables():
    m_logger.info("Clear all rows")
    for table in m_tables.keys():
        m_database.delete_rows(table, "*")

func get_pos_dict() -> Dictionary:
    var rows = m_database.select_rows(POS_TABLE, "", ["id", "name", "x", "y", "z", "rot_90_cw", "x_reflect", "y_reflect"])
    var d = {}
    for row in rows:
        var k = row["id"]
        var v = Vector3i(row["x"], row["y"], row["z"])
        d[k] = {}
        d[k]["pos"] = v
        d[k]["rot_90_cw"] = row["rot_90_cw"]
        d[k]["x_reflect"] = row["x_reflect"]
        d[k]["y_reflect"] = row["y_reflect"]
        d[k]["name"] = row["name"]
    return d

func set_pos(module_name:String, pos:Vector3i, rot_90_cw:int, x_reflect:int, y_reflect:int):
    var d:Dictionary = {}
    var k = _v3i_to_key(pos)
    d["name"] = module_name
    d["x"] = pos.x
    d["y"] = pos.y
    d["z"] = pos.z
    d["rot_90_cw"] = rot_90_cw
    d["x_reflect"] = x_reflect
    d["x_reflect"] = y_reflect
    d["id"] = k
    var select_condition = "id = {0}".format({0:k})
    var rows = m_database.select_rows(POS_TABLE, select_condition, ["id"])
    m_logger.debug("Rows: %s" % str(rows))
    if len(rows):
        m_logger.debug("Update Rows")
        m_database.update_rows(POS_TABLE, select_condition, d)
    else:
        m_logger.debug("Insert Row")
        m_database.insert_row(POS_TABLE, d)

func get_pos_dict_in_region_xyz(start_xyz:Vector3i, end_xyz:Vector3i):
    var x_min:int = start_xyz.x
    var x_max:int = end_xyz.x
    var y_min:int = start_xyz.y
    var y_max:int = end_xyz.y
    var z_min:int = start_xyz.z
    var z_max:int = end_xyz.z
    var d = {}
    var select_condition = "x > {0} and x < {1} and y > {2} and y < {3} and z > {4} and z < {5}".format({0:x_min, 1:x_max, 2:y_min, 3:y_max, 4:z_min, 5:z_max})
    var rows = m_database.select_rows(POS_TABLE, select_condition, ["id", "name", "x", "y", "z", "rot_90_cw", "x_reflect", "y_reflect"])
    for row in rows:
        var k = row["id"]
        var v = Vector3i(row["x"], row["y"], row["z"])
        d[k] = {}
        d[k]["pos"] = v
        d[k]["rot_90_cw"] = row["rot_90_cw"]
        d[k]["x_reflect"] = row["x_reflect"]
        d[k]["y_reflect"] = row["y_reflect"]
        d[k]["name"] = row["name"]
    return d


func get_pos_dict_in_region_xz(start_xz: Vector2i, end_xz: Vector2i):
    var x_min = start_xz.x
    var x_max = end_xz.x
    var z_min = start_xz.y
    var z_max = end_xz.y
    var d = {}
    var select_condition = "x > {0} and x < {1} and z > {2} and z < {3}".format({0:x_min, 1:x_max, 2:z_min, 3:z_max})
    var rows = m_database.select_rows(POS_TABLE, select_condition, ["id", "name", "x", "y", "z", "rot_90_cw", "x_reflect", "y_reflect"])
    for row in rows:
        var k = row["id"]
        var v = Vector3i(row["x"], row["y"], row["z"])
        d[k] = {}
        d[k]["pos"] = v
        d[k]["rot_90_cw"] = row["rot_90_cw"]
        d[k]["x_reflect"] = row["x_reflect"]
        d[k]["y_reflect"] = row["y_reflect"]
        d[k]["name"] = row["name"]
    return d

func set_pos_threaded(module_name:String, pos:Vector3i, rot_90_cw:int, x_reflect:int, y_reflect:int):
    var d = ['w', module_name, pos, rot_90_cw, x_reflect, y_reflect]
    m_task_db_adapter_to_thread_queue.push(d)

func get_pos_dict_threaded():
    var d = ['r']
    m_task_db_adapter_to_thread_queue.push(d)

func get_pos_dict_in_region_xz_threaded(start_xz: Vector2i, end_xz: Vector2i):
    var d = ['r', start_xz, end_xz]
    m_task_db_adapter_to_thread_queue.push(d)

func get_pos_dict_in_region_xyz_threaded(start_xyz: Vector3i, end_xyz: Vector3i):
    var d = ['r', start_xyz, end_xyz]
    m_task_db_adapter_to_thread_queue.push(d)

##############################################################################
# Private Functions
##############################################################################
# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.info("_ready Entered")

func _init():
    m_tables[POS_TABLE] = POS_TABLE_SCHEME
    m_task_db_adapter_to_thread_queue = ThreadSafeQueue.new()
    m_task_db_adapter_from_thread_queue = ThreadSafeQueue.new()
    m_task_db_adapter = TaskManager.create_task(_background_db_adapter, false, "Manage Database in the background")


func _exit_tree():
    var d = null
    m_task_db_adapter_to_thread_queue.push(d)

func _v3i_to_key(v:Vector3i) -> int:
    var vx = int(v.x + KEY_SHIFT_VAL)
    var vy = int(v.y + KEY_SHIFT_VAL)
    var vz = int(v.z + KEY_SHIFT_VAL)
    return int((vx << KEY_X_POS) + (vy << KEY_Y_POS) + (vz << KEY_Z_POS))

func _key_to_v3i(k:int) -> Vector3i:
    var vx = int(((k >> KEY_X_POS) & KEY_MASK) - KEY_SHIFT_VAL)
    var vy = int(((k >> KEY_Y_POS) & KEY_MASK) - KEY_SHIFT_VAL)
    var vz = int(((k >> KEY_Z_POS) & KEY_MASK) - KEY_SHIFT_VAL)
    return Vector3i(vx, vy, vz)

func _background_db_adapter():
    var finished = false
    m_logger.debug("Entered Background Thread")
    while not finished:
        finished = is_queued_for_deletion()
        var data = m_task_db_adapter_to_thread_queue.pop()
        m_logger.info("Background Thread Read: %s" % str(data))
        if data == null:
            m_logger.info("background thread finished")
            finished = true
            break
        match data[0]:
            'w':
                set_pos(data[1], data[2], data[3], data[4], data[5])
            'r':
                if len(data) == 1:
                    # Read Everything and return the entire dictionary
                    var d = get_pos_dict()
                    m_task_db_adapter_from_thread_queue.push(d)
                elif len(data) == 3:
                    if data[1] is Vector2i and data[2] is Vector2i:
                        var d = get_pos_dict_in_region_xz(data[1], data[2])
                        m_task_db_adapter_from_thread_queue.push(d)
                    elif data[1] is Vector3i and data[2] is Vector3i:
                        var d = get_pos_dict_in_region_xyz(data[1], data[2])
                        m_task_db_adapter_from_thread_queue.push(d)



func _process(_delta):
    if !m_task_db_adapter_from_thread_queue.is_empty():
        print ("Data in Read Thread")
        emit_signal("database_data_ready", m_task_db_adapter_from_thread_queue.pop())
