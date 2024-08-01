extends Node

##############################################################################
# Signals
##############################################################################

signal progress_percent_update
signal continue_step
signal finished_loading

# Signal Functions
func emit_percent_update(_name:String, _percent:float):
    emit_signal("progress_percent_update", _name, _percent)

##############################################################################
# Constants
##############################################################################
const GENERATE_FID_DICT_NAME = "Generate FID Dict"
const GENERATE_MODULE_DICT_NAME = "Generate Module Dict"
const EXPAND_MODULE_DICT_NAME = "Expand Module Dict"
const INSERT_INTO_DATABASE = "Insert Into Database"

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Library 2 Tile Converter", LogStream.LogLevel.DEBUG)
var m_db_adapter
var m_db_wfc_adapter
var m_flag_async_finished:bool = true
var m_flag_process_database:bool = false

var m_module_face_sid_dict = {}
var m_expanded_module_face_sid_dict = {}
var m_reflected_sid_dict = {}

#var m_existing_module_face_sid_dict = {}
#var m_existing_module_hash_dict = {}


#######################################
# State
#######################################
enum STATE_T {
  IDLE,
  GENERATE_FID_DICT,
  GENERATE_MODULE_DICT,
  GENERATE_EXPANDED_MODULE_DICT,
  INSERT_INTO_DATABASE
}
var m_state = STATE_T.IDLE


##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################
func process_database(db_adapter, db_wfc_adapter):
    m_db_adapter = db_adapter
    m_db_wfc_adapter = db_wfc_adapter
    m_flag_process_database = true

##############################################################################
# Private Functions
##############################################################################
func _process(_delta):
    match(m_state):
        STATE_T.IDLE:
            if m_flag_process_database:
                m_flag_process_database = false
                #m_existing_module_face_sid_dict = m_db_wfc_adapter.get_module_dict()
                #m_existing_module_hash_dict = m_db_wfc_adapter.get_module_hash_dict()
                _start_generate_module_dict_from_database()
                m_state = STATE_T.GENERATE_MODULE_DICT
                m_logger.debug("_process: IDLE -> GENERATE_MODULE_DICT")
        STATE_T.GENERATE_MODULE_DICT:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_logger.debug("_process: GENERATE_MODULE_DICT -> GENERATE_EXPANDED_MODULE_DICT")
                _start_generate_expanded_module_dict()
                m_state = STATE_T.GENERATE_EXPANDED_MODULE_DICT
                emit_signal("finished_loading")
        STATE_T.GENERATE_EXPANDED_MODULE_DICT:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_logger.debug("_process: GENERATE_EXPANDED_MODULE_DICT -> INSERT_INTO_DATABASE")
                m_state = STATE_T.INSERT_INTO_DATABASE
                _start_insert_database()
                emit_signal("finished_loading")
        STATE_T.INSERT_INTO_DATABASE:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                m_logger.debug("_process: INSERT_INTO_DATABASE -> IDLE")
                m_state = STATE_T.IDLE
                emit_signal("finished_loading")
        _:
            pass

########################################
# Generate Module Dict From Database
########################################
func _start_generate_module_dict_from_database():
    m_logger.debug("Entered: generate_module_dict_from_database")
    var percent = 0.0
    m_flag_async_finished = false
    var _pname = GENERATE_MODULE_DICT_NAME

    var sids_hash_dict = m_db_adapter.get_sids_hash_dict()
    var hash_dict = m_db_adapter.get_hash_dict()
    var hash_face_dict = m_db_adapter.get_hash_name_face_tuple_dict()
    var modules = m_db_adapter.get_module_names()

    var total_size = len(modules) * 6
    call_deferred("emit_percent_update", _pname, percent)
    m_module_face_sid_dict = {}
    for m in modules:
        m_module_face_sid_dict[m] = {}
        m_module_face_sid_dict[m]["faces"] = {0:{}, 1:{}, 2:{}, 3:{}, 4:{}, 5:{}}
        m_module_face_sid_dict[m]["x_flip"] = false
        m_module_face_sid_dict[m]["y_flip"] = false

    var index = 0
    for _sid in sids_hash_dict.keys():
        for _hash in sids_hash_dict[_sid]:
            var modifier = hash_dict[_hash]["reflected"]
            for ftpl in hash_face_dict[_hash]:
                var module_name = ftpl[0]
                var face_index = ftpl[1]
                m_module_face_sid_dict[module_name]["faces"][face_index]["symmetric"] = hash_dict[_hash]["symmetric"]
                m_module_face_sid_dict[module_name]["faces"][face_index]["reflected"] = modifier
                m_module_face_sid_dict[module_name]["faces"][face_index]["sid"] = _sid
                index += 1
        percent = (float((index)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    #Add the module to the tables
    #m_db_wfc_adapter.insert_modules(m_module_face_sid_dict)
    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

########################################
# Generate Expanded Module Dict
########################################
func _start_generate_expanded_module_dict():
    # From the m_module_face_sid_dict generate a dictionary and find the faces that are
    # reflected
    # If a module has 1 or more faces that are reflected then generate new modules
    # with the module flipped so that the reflected faces are now unreflected
    # We will need to do this for the front/back, and left/right only so there
    # will possibly be 4 new modules if all faces are reflected
    # The names of the modules will be the same with the addition of a 'rx', 'ry' or 'rxry'
    # We also need a coupld of flags indicating that the module is reflected on the X and or Y axis
    # perhaps a transform?



    m_logger.debug("Entered: generate_expanded_module_dict")
    var percent = 0.0
    m_flag_async_finished = false
    var _pname = EXPAND_MODULE_DICT_NAME

    var total_size = len(m_module_face_sid_dict.keys())
    var sid_list_array = m_db_adapter.get_sids()
    var sid_list:Array = []
    for s in sid_list_array:
        if not sid_list.has(s):
            sid_list.append(s)


    call_deferred("emit_percent_update", _pname, percent)
    var index = 0
    m_reflected_sid_dict = {}
    sid_list.sort()
    var next_sid = sid_list[-1] + 1

    for sid in sid_list:
        m_reflected_sid_dict[sid] = -1

    for m in m_module_face_sid_dict.keys():
        var module = m_module_face_sid_dict[m]
        # Generate a table of faces that are reflected

        var face_asymmetric_table = {0:false, 1:false, 2:false, 3:false, 4:false, 5:false}
        var face_reflect_table = {0:false, 1:false, 2:false, 3:false, 4:false, 5:false}
        for f in module["faces"].keys():
            if not module["faces"][f]["symmetric"]:
                var s = module["faces"][f]["sid"]
                if m_reflected_sid_dict[s] == -1:
                    m_reflected_sid_dict[s] = next_sid
                    next_sid += 1

                face_asymmetric_table[f] = true
            if module["faces"][f]["reflected"]:
                face_reflect_table[f] = true

        # Check if any face is asymmetric, if so we want to create a unique sid for the reflected version of the SID

        # Copy the module to the expanded module dict
        var emodule = module.duplicate(true)
        for f in module["faces"]:
            emodule["faces"][f] = module["faces"][f]["sid"]
        m_expanded_module_face_sid_dict[m] = emodule

        # Check if the front:0 and back:1 are reflected, if so generate a new module
        # Where we flip along the x axis, this means the front and back faces are now
        # unreflected but the left and right faces are still reflected and the left is now the right
        # and the right is now the left
        if face_asymmetric_table[0] or face_asymmetric_table[1]:
            var new_module = emodule.duplicate(true)
            new_module["x_flip"] = true
            new_module["y_flip"] = false
            if not module["faces"][0]["symmetric"]:
                new_module["faces"][0] = m_reflected_sid_dict[emodule["faces"][0]]
            if not module["faces"][1]["symmetric"]:
                new_module["faces"][1] = m_reflected_sid_dict[emodule["faces"][1]]
            new_module["faces"][4] = emodule["faces"][5]
            new_module["faces"][5] = emodule["faces"][4]
            var nm_name = m + "_rx"
            m_expanded_module_face_sid_dict[nm_name] = new_module

        # Check if the right:4 and left:5 are reflected, if so generate a new module
        # Where we flip along the y axis, this means the right and left faces are now
        # unreflected but the front and back faces are still reflected and the front is now the back
        # and the back is now the front
        if face_asymmetric_table[4] or face_asymmetric_table[5]:
            var new_module = emodule.duplicate(true)
            new_module["x_flip"] = false
            new_module["y_flip"] = true
            if not module["faces"][4]["symmetric"]:
                new_module["faces"][4] = m_reflected_sid_dict[emodule["faces"][4]]
            if not module["faces"][5]["symmetric"]:
                new_module["faces"][5] = m_reflected_sid_dict[emodule["faces"][5]]
            new_module["faces"][0] = emodule["faces"][1]
            new_module["faces"][1] = emodule["faces"][0]
            var nm_name = m + "_ry"
            m_expanded_module_face_sid_dict[nm_name] = new_module

        # Check if a face in the front or back and a face in the left or right are reflected
        # if so generate a new module where we flip along the x and y axis
        # this means the front and back faces are now unreflected and the left and right faces are now
        # unreflected and the front is now the back and the back is now the front and the left is now the right
        # and the right is now the left
        if (face_asymmetric_table[0] or face_asymmetric_table[1]) and (face_asymmetric_table[4] or face_asymmetric_table[5]):
            var new_module = emodule.duplicate(true)
            new_module["x_flip"] = true
            new_module["y_flip"] = true
            if not module["faces"][0]["symmetric"]:
                new_module["faces"][0] = m_reflected_sid_dict[emodule["faces"][0]]
            if not module["faces"][1]["symmetric"]:
                new_module["faces"][1] = m_reflected_sid_dict[emodule["faces"][1]]
            if not module["faces"][4]["symmetric"]:
                new_module["faces"][4] = m_reflected_sid_dict[emodule["faces"][4]]
            if not module["faces"][5]["symmetric"]:
                new_module["faces"][5] = m_reflected_sid_dict[emodule["faces"][5]]
            new_module["faces"][0] = emodule["faces"][1]
            new_module["faces"][1] = emodule["faces"][0]
            new_module["faces"][4] = emodule["faces"][5]
            new_module["faces"][5] = emodule["faces"][4]
            var nm_name = m + "_rxry"
            m_expanded_module_face_sid_dict[nm_name] = new_module



        index += 1
        percent = (float((index)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    percent = 100
    #m_db_wfc_adapter.insert_expanded_modules_and_sids(
    #            m_expanded_module_face_sid_dict,
    #            m_reflected_sid_dict)
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

func _start_insert_database():
    m_logger.debug("Entered: insert_database")
    m_db_wfc_adapter.clear_tables()
    m_flag_async_finished = false
    var _pname = INSERT_INTO_DATABASE
    var percent = 0.0
    var total_size = len(m_reflected_sid_dict.keys())
    call_deferred("emit_percent_update", _pname, percent)
    # Insert Reflected SID Elements
    m_logger.debug("Insert Reflected SID Elements")
    percent = 0.0
    var index = 0
    for sid in m_reflected_sid_dict.keys():
        m_db_wfc_adapter.insert_reflected_sid(sid, m_reflected_sid_dict[sid])
        index+= 1
        percent = (float((index)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step


    percent = 100.0
    call_deferred("emit_percent_update", _pname, percent)
    # Insert Expanded Module Elements

    var sid_dict = {}

    percent = 0.0
    _pname = "Insert Expanded Module Elements"
    m_logger.debug("Insert Expanded Module Elements")
    total_size = len(m_expanded_module_face_sid_dict.keys())
    index = 0
    for module in m_expanded_module_face_sid_dict.keys():
        var d = m_expanded_module_face_sid_dict[module]
        m_db_wfc_adapter.insert_expanded_module(module, d["x_flip"], d["y_flip"], d["faces"])
        for f in d["faces"].keys():
            var fsid = d["faces"][f]
            if not sid_dict.has(fsid):
                if not m_reflected_sid_dict.has(fsid):
                    # This means we are looking at a reflected face, not an original
                    continue
                sid_dict[fsid] = {"asymmetric": 0, "module_list": []}
                if m_reflected_sid_dict[fsid] != -1:
                    sid_dict[fsid]["asymmetric"] = 1
            sid_dict[fsid]["module_list"].append(module)
        index += 1
        percent = (float((index)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    percent = 100
    call_deferred("emit_percent_update", _pname, percent)

    _pname = "Insert SID Module List"
    m_logger.debug("Insert SID Module List")
    percent = 0.0
    total_size = len(sid_dict.keys())
    index = 0
    for sid in sid_dict.keys():
        m_db_wfc_adapter.insert_sid_mapping(sid, sid_dict[sid]["asymmetric"], sid_dict[sid]["module_list"])
        index += 1
        percent = (float((index)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

