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

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Library 2 Tile Converter", LogStream.LogLevel.DEBUG)
var m_db_adapter
var m_db_wfc_adapter
var m_flag_async_finished:bool = true
var m_flag_process_database:bool = false

var m_novel_module_face_sid_dict = {}
var m_novel_module_hash_dict = {}

#var m_existing_module_face_sid_dict = {}
#var m_existing_module_hash_dict = {}

#######################################
# State
#######################################
enum STATE_T {
  IDLE,
  GENERATE_FID_DICT,
  GENERATE_MODULE_DICT
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
                m_logger.debug("_process: GENERATE_MODULE_DICT -> IDLE")
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
    var sid_socket_map = {}

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
            var modifier = bool(hash_dict[_hash]["reflected"])
            for mft in hash_face_dict[_hash]:
                mft.append(modifier)
                mlist.append(mft)
        sid_socket_map[sid] = mlist
        percent = (float((i + 1)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    percent = 100
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
    #var sids_list = sids_hash_dict.keys()
    m_novel_module_face_sid_dict = m_db_adapter.get_module_hash_dict()
    var module_face_sid_dict = m_db_adapter.get_sids_hash_dict()
    #m_novel_module_hash_dict = module_face_sid_dict.duplicate()

    var total_size = len(m_novel_module_face_sid_dict.keys()) * 6
    call_deferred("emit_percent_update", _pname, percent)
    for m in module_face_sid_dict.keys():
        m_novel_module_face_sid_dict[m] = {0:{}, 1:{}, 2:{}, 3:{}, 4:{}, 5:{}}

    var index = 0
    for _sid in sids_hash_dict.keys():
        for _hash in sids_hash_dict[_sid]:
            var modifier = hash_dict[_hash]["reflected"]
            for ftpl in hash_face_dict[_hash]:
                var module_name = ftpl[0]
                var face_index = ftpl[1]
                m_novel_module_face_sid_dict[module_name][face_index]["reflected"] = modifier
                m_novel_module_face_sid_dict[module_name][face_index]["sid"] = _sid
                index += 1
        percent = (float((index)) / total_size) * 100.0
        call_deferred("emit_percent_update", _pname, percent)
        await continue_step

    #Add the module to the tables
    #m_db_wfc_adapter.insert_module_hashes(m_novel_module_hash_dict)
    m_db_wfc_adapter.insert_modules(m_novel_module_face_sid_dict)
    percent = 100
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_async_finished = true

