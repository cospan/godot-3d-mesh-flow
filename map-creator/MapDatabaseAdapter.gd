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
var m_logger = LogStream.new("Map Database Adapter", LogStream.LogLevel.INFO)
var m_database : SQLite
var m_submodule_dict:Dictionary = {}
var m_mesh_dict:Dictionary = {}
var m_id_subcomposer_dict:Dictionary = {}
var m_curr_id:int = 0
var m_commands:Array = []
var m_prev_commands:Array = []

var m_database_timestamp = 0
var m_dict_timestamp = 0


# TODO: Adda member that will dictate how far away from the player we will load
# the map data. This will be used to determine how much data we need to load
# from the database.
@export var load_distance:float = 100.0:
    set(v):
        load_distance = v
        m_logger.debug("Load Distance: %s" % str(v))
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
    "id"            : {"data_type":"int",   "primary_key":true, "not_null":true, "auto_increment":false},
    "subcomposer_id": {"data_type":"text",  "not_null":false},
    "module_name"   : {"data_type":"text",  "not_null":true},
    "x"             : {"data_type":"int",   "not_null":false},
    "y"             : {"data_type":"int",   "not_null":false},
    "z"             : {"data_type":"int",   "not_null":false},
    "layer"         : {"data_type":"int",   "not_null":false},
    "x_reflect"     : {"data_type":"int",   "not_null":false},
    "y_reflect"     : {"data_type":"int",   "not_null":false},
    "rot_x_90_cw"   : {"data_type":"int",   "not_null":false}, # 0, 90, 180, 270
    "rot_y_90_cw"   : {"data_type":"int",   "not_null":false}, # 0, 90, 180, 270
    "rot_z_90_cw"   : {"data_type":"int",   "not_null":false}, # 0, 90, 180, 270
    "scale"         : {"data_type":"real",  "not_null":false},
    #"transform" : {"data_type":"blob",  "not_null":false}, # Extra transform after rotation
    "metadata"      : {"data_type":"blob",  "not_null":false}
}

const MESH_TABLE = "mesh"
const MESH_TABLE_SCHEME = {
    "id"        : {"data_type":"int", "primary_key":true, "not_null":true, "auto_increment":true},
    "name"      : {"data_type":"text", "not_null":true},
    "mesh"      : {"data_type":"blob", "not_null":true},
    "transform" : {"data_type":"blob", "not_null":true}
}

var m_tables = {
    CONFIG_TABLE  : CONFIG_TABLE_SCHEME,
    POS_TABLE     : POS_TABLE_SCHEME,
    MESH_TABLE    : MESH_TABLE_SCHEME
    }

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
                m_database.drop_table(table)

    elif clear_rows:
        m_logger.info("Clear all rows")
        for table in m_tables.keys():
            m_database.delete_rows(table, "*")

    if force_new_tables or clear_rows:
        m_curr_id = 0

    ##########################################################################
    # Create the tables if they don't exist
    ##########################################################################
    for table in m_tables.keys():
        m_logger.debug("Adding Table: %s" % str(table))
        var sel_string = "SELECT tbl_name FROM sqlite_master WHERE tbl_name = '{0}'".format({0:table})
        m_database.query(sel_string)
        if len(m_database.query_result) == 0:
            m_logger.debug("{0} does not exist, creating it now.".format({0:table}))
            m_database.create_table(table, m_tables[table])

func clear_tables():
    m_logger.info("Clear all rows")
    for table in m_tables.keys():
        m_database.delete_rows(table, "*")

func clear_pos_table():
    m_logger.info("Clear all rows in pos table")
    m_dict_timestamp = 0
    m_database_timestamp = 0
    m_database.delete_rows(POS_TABLE, "*")

func get_pos_dict() -> Dictionary:
    var rows = m_database.select_rows(POS_TABLE, "", ["*"])
    var pos_dict = {}
    for row in rows:
        var k = row["id"]
        pos_dict[k] = _row_to_dict_entry(row)
    _update_both_dict_and_database_timestamp()
    return pos_dict

func get_module_at_pos(pos:Vector3i) -> Dictionary:
    var k = _v3i_to_key(pos)
    var pos_dict = get_pos_dict()
    if pos_dict.has(k):
        return pos_dict[k]
    return {}

func get_modules_with_attribute(_id:int, _rot:int) -> Array:
    var res = []
    var pos_dict = get_pos_dict()
    for k in pos_dict.keys():
        var v = pos_dict[k]
        if v["module_name"] == _id and v["rot_y_90_cw"] == _rot:
            res.append(v)
    return res

func insert_module( threaded: bool,
                    subcomposer_id:String,
                    module_name,
                    pos,
                    scale:float,
                    rot_x_90_cw:int,
                    rot_y_90_cw:int,
                    rot_z_90_cw:int,
                    x_reflect:int,
                    y_reflect:int,
                    metadata:Dictionary,
                    _mesh = null,
                    _transform = null):
    var d:Dictionary = {}
    if module_name == null or len(module_name) == 0:
        module_name = subcomposer_id + str(m_curr_id)
    d["subcomposer_id"] = subcomposer_id
    d["module_name"] = module_name
    if pos is Vector3i or pos is Vector3:
        d["x"] = pos.x
        d["y"] = pos.y
        d["z"] = pos.z
    elif pos is Vector2i or pos is Vector2:
        d["x"] = pos.x
        d["y"] = 0
        d["z"] = pos.z
    else:
        assert(false, "Invalid Position Type")
    d["x_reflect"] = x_reflect
    d["y_reflect"] = y_reflect
    d["rot_x_90_cw"] = rot_x_90_cw
    d["rot_y_90_cw"] = rot_y_90_cw
    d["rot_z_90_cw"] = rot_z_90_cw
    d["scale"] = scale
    d["metadata"] = metadata
    d["id"] = m_curr_id
    m_curr_id += 1
    if threaded:
        var mesh_d = {}
        mesh_d["mesh"] = _mesh
        mesh_d["transform"] = _transform
        m_task_db_adapter_to_thread_queue.push(['w', d, mesh_d])
    else:
        if _mesh != null:
            insert_mesh(module_name, _mesh, _transform)
        _insert_module(d)

func get_pos_dict_in_region_xyz(start_xyz:Vector3i, end_xyz:Vector3i):
    var x_min:int = start_xyz.x
    var x_max:int = end_xyz.x
    var y_min:int = start_xyz.y
    var y_max:int = end_xyz.y
    var z_min:int = start_xyz.z
    var z_max:int = end_xyz.z
    var d = {}
    var select_condition = "x > {0} and x < {1} and y > {2} and y < {3} and z > {4} and z < {5}".format({0:x_min, 1:x_max, 2:y_min, 3:y_max, 4:z_min, 5:z_max})
    var rows = m_database.select_rows(POS_TABLE, select_condition, ["*"])
    for row in rows:
        var k = row["id"]
        d[k] = _row_to_dict_entry(row)
    return d

func get_pos_dict_in_region_xz(start_xz: Vector2i, end_xz: Vector2i):
    var x_min = start_xz.x
    var x_max = end_xz.x
    var z_min = start_xz.y
    var z_max = end_xz.y
    var d = {}
    var select_condition = "x > {0} and x < {1} and z > {2} and z < {3}".format({0:x_min, 1:x_max, 2:z_min, 3:z_max})
    var rows = m_database.select_rows(POS_TABLE, select_condition, ["*"])
    for row in rows:
        var k = row["id"]
        d[k] = _row_to_dict_entry(row)
    return d

func remove_all_subcomposer_modules(_submodule:String):
    if m_database == null:
        return
    var select_condition = "subcomposer_id = '{0}'".format({0:_submodule})
    var rows = m_database.select_rows(POS_TABLE, select_condition, ["id"])
    m_database.delete_rows(POS_TABLE, select_condition)
    for row in rows:
        var k = row["id"]
        m_commands.push_back([COMMANDS_T.REMOVE, k])

func remove_module_by_id(_id:int):
    if m_database == null:
        return
    var select_condition = "id = {0}".format({0:_id})
    m_database.delete_rows(POS_TABLE, select_condition)
    m_commands.push_back([COMMANDS_T.REMOVE, _id])

func get_pos_dict_threaded():
    var d = ['r']
    m_task_db_adapter_to_thread_queue.push(d)

func get_pos_dict_in_region_xz_threaded(start_xz: Vector2i, end_xz: Vector2i):
    var d = ['r', start_xz, end_xz]
    m_task_db_adapter_to_thread_queue.push(d)

func get_pos_dict_in_region_xyz_threaded(start_xyz: Vector3i, end_xyz: Vector3i):
    var d = ['r', start_xyz, end_xyz]
    m_task_db_adapter_to_thread_queue.push(d)

func get_used_rect_2d() -> Rect2i:
    m_logger.debug("Get Used Rect 2D")
    var pos_dict = get_pos_dict()
    var res = Rect2i()
    for k in pos_dict.keys():
        var v = pos_dict[k]
        if !res.has_area():
            res.position = Vector2i(v["x"], v["z"])
            res.size = Vector2i(1, 1)
        else:
            res = res.expand(Vector2i(v["x"], v["z"]))
    return res

func get_used_rect_3d() -> AABB:
    m_logger.debug("Get Used Rect 3D")
    var pos_dict = get_pos_dict()
    var res = AABB()
    for k in pos_dict.keys():
        var v = pos_dict[k]
        if !res.has_area():
            res.position = v["pos"]
            res.size = Vector3i(1, 1, 1)
        else:
            res = res.expand(v["pos"])
    return res

func get_commands() -> Array:
    return m_commands

func insert_mesh(_name: String, _mesh: ArrayMesh, _transform = null):
    var mesh_data = var_to_bytes_with_objects(_mesh)
    if _transform == null:
        _transform = Transform3D()
    var transform_data = var_to_bytes_with_objects(_transform)
    var select_condition = "name = '{0}'".format({0: _name})
    var rows = m_database.select_rows(MESH_TABLE, select_condition, ["name"])
    if len(rows):
        m_database.update_rows(MESH_TABLE, select_condition, {"mesh": mesh_data, "transform": transform_data})
    else:
        var row = {"name": _name, "mesh": mesh_data, "transform": transform_data}
        m_database.insert_row(MESH_TABLE, row)
    m_logger.debug("Inserted mesh: %s" % _name)
    _update_mesh_references()

func remove_mesh(_name: String):
    var select_condition = "name = '{0}'".format({0: _name})
    m_database.delete_rows(MESH_TABLE, select_condition)
    m_logger.debug("Removed mesh: %s" % _name)
    _update_mesh_references()

# TODO: Implement this function
func read_all_commands_from_database(_pos:Vector3, _load_all:bool = false):
    m_logger.debug("Read all commands from database")
    m_logger.warn("Not Implemented Yet")

    # populate the local dictionary with data from the database.
    # XXX: We can isolate this to range dictated by the location we are at
    # (so we don't need to load everything)


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

func _rot_reflect_to_transform(rot_y_90_cw:int, x_reflect:int, y_reflect:int) -> Transform3D:
    var transform = Transform3D()
    transform.basis = Basis(Vector3(0, 0, 1), rot_y_90_cw * PI / 2.0)
    transform.origin = Vector3(0, 0, 0)
    if x_reflect:
        transform.basis = transform.basis.scaled(Vector3(-1, 1, 1))
    if y_reflect:
        transform.basis = transform.basis.scaled(Vector3(1, -1, 1))
    return transform

func _transform_to_rot_reflect(t:Transform3D) -> Dictionary:
    var rot_y_90_cw = 0
    var x_reflect = 0
    var y_reflect = 0
    var basis = t.basis
    if basis.get_axis(0).x < 0:
        x_reflect = 1
    if basis.get_axis(1).y < 0:
        y_reflect = 1
    if basis.get_axis(0).y < 0:
        rot_y_90_cw = 1
    elif basis.get_axis(1).x < 0:
        rot_y_90_cw = 2
    elif basis.get_axis(0).y > 0:
        rot_y_90_cw = 3
    return {"rot_y_90_cw":rot_y_90_cw, "x_reflect":x_reflect, "y_reflect":y_reflect}

func _row_to_dict_entry(row:Dictionary) -> Dictionary:
    var d = row.duplicate(true)
    d["metadata"] = bytes_to_var(row["metadata"])
    return d

func _dict_entry_to_row(d:Dictionary) -> Dictionary:
    var row = d.duplicate(true)
    row["metadata"] = var_to_bytes(d["metadata"])
    return row

func _background_db_adapter():
    var finished = false
    m_logger.debug("Entered Background Thread")
    while not finished:
        finished = is_queued_for_deletion()
        var data = m_task_db_adapter_to_thread_queue.pop()
        m_logger.debug("Background Thread Read: %s" % str(data))
        if data == null:
            m_logger.debug("background thread finished")
            finished = true
            break
        match data[0]:
            'w':
                if data[1]["mesh"] != null:
                    insert_mesh(data[1]["module_name"], data[2]["mesh"], data[2]["transform"])
                _insert_module(data[1])
            'r':
                if len(data) == 1:
                    var d = get_pos_dict()
                    m_task_db_adapter_from_thread_queue.push(d)
                elif len(data) == 3:
                    if data[1] is Vector2i and data[2] is Vector2i:
                        var d = get_pos_dict_in_region_xz(data[1], data[2])
                        m_task_db_adapter_from_thread_queue.push(d)
                    elif data[1] is Vector3i and data[2] is Vector3i:
                        var d = get_pos_dict_in_region_xyz(data[1], data[2])
                        m_task_db_adapter_from_thread_queue.push(d)

func _insert_module(d:Dictionary):
    var k = d["id"]

    var select_condition = "id = {0}".format({0:k})
    var rows = m_database.select_rows(POS_TABLE, select_condition, ["id"])
    m_logger.debug("Rows: %s" % str(rows))
    var row = _dict_entry_to_row(d)
    if len(rows):
        m_logger.debug("Update Rows")
        m_database.update_rows(POS_TABLE, select_condition, row)
    else:
        m_logger.debug("Insert Row")
        m_database.insert_row(POS_TABLE, row)

    var transform = Transform3D()
    transform.basis = Basis(Vector3(0, 0, 1), d["rot_y_90_cw"] * PI / 2.0)
    transform.origin = Vector3(d["x"], d["y"], d["z"])
    if d["x_reflect"]:
        transform.basis = transform.basis.scaled(Vector3(-1, 1, 1))
    if d["y_reflect"]:
        transform.basis = transform.basis.scaled(Vector3(1, -1, 1))


    m_commands.push_back([  COMMANDS_T.ADD_MESH,
                            m_mesh_dict[d["module_name"]],
                            transform,
                            d["metadata"],
                            k])
    _update_both_dict_and_database_timestamp()


func _update_mesh_references():
    var select_condition = ""
    var rows = m_database.select_rows(MESH_TABLE, select_condition, ["*"])
    m_mesh_dict = {}
    for row in rows:
        var _mesh: Mesh = bytes_to_var_with_objects(row["mesh"])
        m_mesh_dict[row["name"]] = _mesh

func _update_database_timestamp(ts):
    if m_database.query("SELECT data_group FROM \"" + CONFIG_TABLE + "\" WHERE data_group = 'timestamp'") and m_database.query_result.size() == 0:
        m_logger.debug("Timestamp does not exist. Creating it now.")
        m_database.insert_row(CONFIG_TABLE, {"name": "timestamp", "type": "int", "data_group": "timestamp", "int_value": m_database_timestamp})
    m_database.update_rows(CONFIG_TABLE, "name = 'timestamp'", {"int_value": ts})

func _update_dict_timestamp(ts):
    m_dict_timestamp = ts

func _update_both_dict_and_database_timestamp():
    var ts = Time.get_ticks_msec()
    _update_database_timestamp(ts)
    _update_dict_timestamp(ts)

func _is_dict_out_of_date():
    return m_dict_timestamp < m_database_timestamp

func _is_database_out_of_date():
    return m_database_timestamp < m_dict_timestamp

func _are_dict_and_database_same():
    return m_dict_timestamp == m_database_timestamp

##############################################################################
# Signal Handlers
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("_ready Entered")

func _process(_delta):
    if !m_task_db_adapter_from_thread_queue.is_empty():
        m_logger.debug("Data in Read Thread")
        emit_signal("database_data_ready", m_task_db_adapter_from_thread_queue.pop())

func _init():
    m_tables[POS_TABLE] = POS_TABLE_SCHEME
    m_task_db_adapter_to_thread_queue = ThreadSafeQueue.new()
    m_task_db_adapter_from_thread_queue = ThreadSafeQueue.new()
    m_task_db_adapter = TaskManager.create_task(_background_db_adapter, false, "Manage Database in the background")

func _exit_tree():
    var d = null
    m_task_db_adapter_to_thread_queue.push(d)
