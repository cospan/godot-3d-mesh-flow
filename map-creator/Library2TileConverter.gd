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
const RESOLVE_FIDS_NAME = "Resolve FIDS"
const EXPAND_MODULE_DICT_NAME = "Expand Module Dict"

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Library 2 Tile Converter", LogStream.LogLevel.DEBUG)
var m_db_adapter
var m_db_wfc_adapter
var m_flag_async_finished:bool = true
var m_flag_process_database:bool = false

var m_sid_socket_map = {}
var m_module_face_sid_dict = {}
var m_expanded_module_face_sid_dict = {}

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
                _start_generate_sid_dict_from_database()
                m_state = STATE_T.GENERATE_FID_DICT
                m_logger.debug("_process: IDLE -> GENERATE_FID_DICT")
        STATE_T.GENERATE_FID_DICT:
            if not m_flag_async_finished:
                emit_signal("continue_step")
            else:
                _start_generate_module_dict_from_database()
                m_state = STATE_T.GENERATE_MODULE_DICT
                m_logger.debug("_process: GENERATE_FID_DICT -> GENERATE_MODULE_DICT")
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
                m_logger.debug("_process: GENERATE_EXPANDED_MODULE_DICT -> IDLE")
                m_state = STATE_T.IDLE
                emit_signal("finished_loading")
        _:
            pass

########################################
# Generate FID Dict From Database
########################################
func _start_generate_sid_dict_from_database():
    m_logger.debug("Entered: generate_sid_dict_from_database")
    var percent = 0.0
    m_flag_async_finished = false
    var _pname = GENERATE_FID_DICT_NAME

    var sids_hash_dict = m_db_adapter.get_sids_hash_dict()
    var hash_dict = m_db_adapter.get_hash_dict()
    var hash_face_dict = m_db_adapter.get_hash_name_face_tuple_dict()
    var sids_list = sids_hash_dict.keys()
    m_sid_socket_map = {}

    var total_size = len(sids_list)
    call_deferred("emit_percent_update", _pname, percent)

    for i in len(sids_list):
        var sid = sids_list[i]
        #var vid = sids_hash_dict
        var _hash_list = sids_hash_dict[sid]
        var mlist = []
        # Generate an array of module, faces that are associated with the FID,
        # The generated list will have a flags indicating the rotation and the flipped

        for _hash in  _hash_list:
            for mft in hash_face_dict[_hash]:
                mft.append(hash_dict[_hash]["symmetric"])
                mft.append(hash_dict[_hash]["reflected"])
                mlist.append(mft)
        m_sid_socket_map[sid] = mlist
        percent = (float((i + 1)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    percent = 100

    #XXX: Add the 'sid_socket_map' to the Tile Database

    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

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

    call_deferred("emit_percent_update", _pname, percent)
    var index = 0

    for m in m_module_face_sid_dict.keys():
        var module = m_module_face_sid_dict[m]
        # Generate a table of faces that are reflected

        var face_asymmetric_table = {0:false, 1:false, 2:false, 3:false, 4:false, 5:false}
        var face_reflect_table = {0:false, 1:false, 2:false, 3:false, 4:false, 5:false}
        for f in module["faces"].keys():
            if not module["faces"][f]["symmetric"]:
                face_asymmetric_table[f] = true
            if module["faces"][f]["reflected"]:
                face_reflect_table[f] = true

        # Copy the module to the expanded module dict
        m_expanded_module_face_sid_dict[m] = module.duplicate()

        # Check if the front:0 and back:1 are reflected, if so generate a new module
        # Where we flip along the x axis, this means the front and back faces are now
        # unreflected but the left and right faces are still reflected and the left is now the right
        # and the right is now the left
        if face_asymmetric_table[0] or face_asymmetric_table[1]:
            var new_module = module.duplicate()
            new_module["x_flip"] = true
            new_module["y_flip"] = false
            if module["faces"][0]["symmetric"]:
                new_module["faces"][0]["reflected"] = not module["faces"][0]["reflected"]
            if module["faces"][1]["symmetric"]:
                new_module["faces"][1]["reflected"] = not module["faces"][1]["reflected"]
            new_module["faces"][4] = module["faces"][5]
            new_module["faces"][5] = module["faces"][4]
            var nm_name = m + "_rx"
            m_expanded_module_face_sid_dict[nm_name] = new_module
            # We now need to update m_sid_socket_map with the new module
            for face in new_module["faces"].keys():
                var sid = new_module["faces"][face]["sid"]
                m_sid_socket_map[sid].append([nm_name, face, new_module["faces"][face]["reflected"]])

        # Check if the right:4 and left:5 are reflected, if so generate a new module
        # Where we flip along the y axis, this means the right and left faces are now
        # unreflected but the front and back faces are still reflected and the front is now the back
        # and the back is now the front
        if face_asymmetric_table[4] or face_asymmetric_table[5]:
            var new_module = module.duplicate()
            new_module["x_flip"] = false
            new_module["y_flip"] = true
            if module["faces"][4]["symmetric"]:
                new_module["faces"][4]["reflected"] = not module["faces"][4]["reflected"]
            if module["faces"][5]["symmetric"]:
                new_module["faces"][5]["reflected"] = not module["faces"][5]["reflected"]
            new_module["faces"][0] = module["faces"][1]
            new_module["faces"][1] = module["faces"][0]
            var nm_name = m + "_ry"
            m_expanded_module_face_sid_dict[nm_name] = new_module
            # We now need to update m_sid_socket_map with the new module
            for face in new_module["faces"].keys():
                var sid = new_module["faces"][face]["sid"]
                m_sid_socket_map[sid].append([nm_name, face, new_module["faces"][face]["reflected"]])

        # Check if a face in the front or back and a face in the left or right are reflected
        # if so generate a new module where we flip along the x and y axis
        # this means the front and back faces are now unreflected and the left and right faces are now
        # unreflected and the front is now the back and the back is now the front and the left is now the right
        # and the right is now the left
        if (face_asymmetric_table[0] or face_asymmetric_table[1]) and (face_asymmetric_table[4] or face_asymmetric_table[5]):
            var new_module = module.duplicate()
            new_module["x_flip"] = true
            new_module["y_flip"] = true
            if module["faces"][0]["symmetric"]:
                new_module["faces"][0]["reflected"] = not module["faces"][0]["reflected"]
            if module["faces"][1]["symmetric"]:
                new_module["faces"][1]["reflected"] = not module["faces"][1]["reflected"]
            if module["faces"][4]["symmetric"]:
                new_module["faces"][4]["reflected"] = not module["faces"][4]["reflected"]
            if module["faces"][5]["symmetric"]:
                new_module["faces"][5]["reflected"] = not module["faces"][5]["reflected"]
            new_module["faces"][0] = module["faces"][1]
            new_module["faces"][1] = module["faces"][0]
            new_module["faces"][4] = module["faces"][5]
            new_module["faces"][5] = module["faces"][4]
            var nm_name = m + "_rxry"
            m_expanded_module_face_sid_dict[nm_name] = new_module
            # We now need to update m_sid_socket_map with the new module
            for face in new_module["faces"].keys():
                var sid = new_module["faces"][face]["sid"]
                m_sid_socket_map[sid].append([nm_name, face, new_module["faces"][face]["reflected"]])



        index += 1
        percent = (float((index)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

func _start_insert_database():
		m_logger.debug("Entered: insert_database")
		m_flag_async_finished = false
		var _pname = RESOLVE_FIDS_NAME
		var percent = 0.0
		call_deferred("emit_percent_update", _pname, percent)
		for module in m_expanded_module_face_sid_dict.keys():
				percent += 1.0
				call_deferred("emit_percent_update", _pname, percent)
				await continue_step

		percent = 100
		call_deferred("emit_percent_update", _pname, percent)
		m_flag_async_finished = true
