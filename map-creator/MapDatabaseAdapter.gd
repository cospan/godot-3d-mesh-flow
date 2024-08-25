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

enum COMMANDS_T {
    ADD_MESH = 0,
    ADD_TILE = 1,
    ADD_LINE = 2,
    ADD_POINT = 3,
    ADD_TEXT = 4,
    ADD_CIRCLE = 5,
    ADD_RECT = 6,
    ADD_POLYGON = 7,
    REMOVE = 8
}

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Map Database Adapter", LogStream.LogLevel.DEBUG)
var m_database : SQLite
var m_map_dict:Dictionary = {}
var m_id_subcomposer_dict:Dictionary = {}
var m_curr_id:int = 0
var m_commands:Array = []
var m_prev_commands:Array = []

# TODO: Adda member that will dictate how far away from the player we will load
# the map data. This will be used to determine how much data we need to load
# from the database.
@export var load_distance:float = 100.0:
    set(v):
        load_distance = v
        m_logger.info("Load Distance: %s" % str(v))
    get:
        return load_distance

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


const CONFIG_TABLE = "config"
const CONFIG_TABLE_SCHEME = {
    "name"        : {"data_type":"text", "primary_key":true, "not_null":true, "auto_increment":false},
    "data_group"  : {"data_type":"text",  "not_null":false},
    "type"        : {"data_type":"text",  "not_null":true},
    "int_value"   : {"data_type":"int",   "not_null":false},
    "text_value"  : {"data_type":"text",  "not_null":false},
    "float_value" : {"data_type":"real",  "not_null":false},
    "blob_value"  : {"data_type":"blob",  "not_null":false}
}

const POS_TABLE = "pos"
const POS_TABLE_SCHEME = {
    "id"        : {"data_type":"int",   "primary_key":true, "not_null":true, "auto_increment":false},
    "name"      : {"data_type":"text",  "not_null":true},
    "x"         : {"data_type":"int",   "not_null":false},
    "y"         : {"data_type":"int",   "not_null":false},
    "z"         : {"data_type":"int",   "not_null":false},
    "layer"     : {"data_type":"int",   "not_null":false},
    "rot_90_cw" : {"data_type":"int",   "not_null":false}, # 0, 90, 180, 270
    "transform" : {"data_type":"blob",  "not_null":false}, # Extra transform after rotation
    "metadata"  : {"data_type":"blob",  "not_null":false}
}

var m_tables = {
    CONFIG_TABLE  : CONFIG_TABLE_SCHEME,
    POS_TABLE     : POS_TABLE_SCHEME
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




# TODO: Implement this function
func read_all_commands_from_database(_pos:Vector3, _load_all:bool = false):
    m_logger.debug("Read all commands from database")
    m_logger.warn("Not Implemented Yet")

    # populate the local dictionary with data from the database.
    # XXX: We can isolate this to range dictated by the location we are at
    # (so we don't need to load everything)

func subcomposer_add_mesh(_submodule:String, _mesh:Mesh, _transfrom:Transform3D, _modifiers:Dictionary={}) -> int:
    # Submit a command to the local dictionary and submit it to the database
    # in a background thread.
    # Return a unique ID that can be used to reference the command
    # The ID will be the key to the dictionary and the ID in the database
    # in order to avoid constantly searching for the command in the database
    # when we need to update it we will use a dictionary to store the command
    # and the ID in the database. This will allow us to update the command
    #m_database.insert_row(POS_TABLE, command)
    if not m_map_dict.has(_submodule):
        m_map_dict[_submodule] = {}
    m_logger.debug("Add Mesh: %s, ID: %d" % [str(_mesh), m_curr_id])
    m_map_dict[_submodule][m_curr_id] = {"mesh":_mesh, "transform":_transfrom, "modifiers":_modifiers}
    m_id_subcomposer_dict[m_curr_id] = _submodule
    m_commands.push_back([COMMANDS_T.ADD_MESH, _mesh, _transfrom, _modifiers, m_curr_id])
    var curr_id = m_curr_id
    m_curr_id = m_curr_id + 1
    return curr_id

func subcomposer_remove_mesh(_submodule:String, _id:int):
    # Submit a command to remove a command from the local dictionary and
    # submit it to the database in a background thread.
    # The ID will be the key to the dictionary and the ID in the database
    # in order to avoid constantly searching for the command in the database
    # when we need to update it we will use a dictionary to store the command
    # and the ID in the database. This will allow us to update the command
    #m_database.delete_rows(POS_TABLE, "id = %s" % str(_id))
    if m_map_dict.has(_submodule):
        if m_map_dict[_submodule].has(_id):
            m_map_dict[_submodule].erase(_id)
            m_id_subcomposer_dict.erase(_id)
            # XXX Remove from the database
            m_commands.push_back([COMMANDS_T.REMOVE, _id])

func composer_read_step_commands() -> Array:
    m_prev_commands = m_commands.duplicate(true)
    m_commands.clear()
    return m_prev_commands

func subcomposer_read_previous_commands() -> Array:
    return m_prev_commands

func get_subcomposer_name(_id:int) -> String:
    if m_id_subcomposer_dict.has(_id):
        return m_id_subcomposer_dict[_id]
    return ""

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
