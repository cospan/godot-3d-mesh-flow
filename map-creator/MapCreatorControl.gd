extends Control

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("MC", LogStream.LogLevel.DEBUG)
var m_project_path:String = ""
var m_config_file:String = ""
var m_config = null
var m_props = {}

#######################################
# Flags
#######################################
var m_flag_ready = false
var m_flag_load_library = false
var m_flag_load_finished = false
var m_flag_auto_load = false
var m_flag_select_new_db = false
var m_flag_reset_tile_db = false

#######################################
# State Machine
#######################################
enum STATE_TYPE {
    RESET,
    IDLE,
    LOADING,
}
var m_state = STATE_TYPE.RESET


##############################################################################
# Scenes
##############################################################################
var m_properties = null
var m_processor = null

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func init(_dir:String):
    m_logger.debug("Init Entered!")
    m_config = ConfigFile.new()
    m_project_path = _dir
    m_config_file = "%s/%s" % [_dir, "map.cfg"]
    m_config.load(m_config_file)


func get_project_path():
    return m_project_path


##############################################################################
# Private Functions
##############################################################################


# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_logger.set_name("MC (%s)" % m_config.get_value("config", "name"))
    m_properties = $HBMain/DictProperty
    m_processor = $MapCreatorProcessor

    m_props["reload_lib_button"] = {"type": "Button", "name": "Reload Library", "tooltip": "Reload Library"}
    m_props["auto_load"] = {"type": "CheckBox", "name": "Auto Load", "value": m_config.get_value("config", "auto_load"), "tooltip": "Auto Load Library on Start"}
    m_props["library_database"] = {"type": "LineEdit", "name": "Library Database", "value": m_config.get_value("config", "library_database"), "tooltip": "Library Database Path"}
    m_props["reset_db"] = {"type": "CheckBox", "name": "Reset DB", "value": m_config.get_value("config", "reset_db"), "tooltip": "Reset DB and reload DB Tables on start"}
    m_props["clear_db"] = {"type": "CheckBox", "name": "Clear DB", "value": m_config.get_value("config", "clear_db"), "tooltip": "Clear all database rows on Start"}
    m_props["select_db"] = {"type": "Button", "name": "Select DB", "tooltip": "Select Library Database Path"}
    m_props["reset_tile_db"] = {"type": "Button", "name": "Reset Tile DB", "tooltip": "Regenerate the Tile DB from the library DB"}
    m_properties.update_dict(m_props)

    # Connect Signals
    m_properties.property_changed.connect(_property_changed)
    m_processor.loading_finished.connect(_loading_finished)
    m_flag_ready = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    match m_state:
        STATE_TYPE.RESET:
            if m_flag_ready:
                m_flag_ready = false
                if await _check_library_database_path(m_flag_select_new_db):
                    m_flag_select_new_db = false
                    m_flag_auto_load = m_config.get_value("config", "auto_load")
                    m_state = STATE_TYPE.IDLE
        STATE_TYPE.IDLE:
            if m_flag_load_library or m_flag_auto_load:
                m_logger.debug("Loading Library Database!")
                m_flag_load_library = false
                m_flag_auto_load = false
                #XXX: TODO
                var library_db_path = m_config.get_value("config", "library_database")
                var tile_db_path = ""
                if m_config.has_section_key("config", "tile_database"):
                    tile_db_path = m_config.get_value("config", "tile_database")
                else:
                    var p = m_config.get_value("config", "path")
                    tile_db_path = p + "/tile.db"

                m_processor.convert_library_db_2_tile_db(library_db_path, tile_db_path, false, m_flag_reset_tile_db)
                m_flag_reset_tile_db = false
                m_state = STATE_TYPE.LOADING
            if m_flag_select_new_db:
                m_logger.debug("Selecting New Library Database!")
                m_state = STATE_TYPE.RESET
        STATE_TYPE.LOADING:
            if m_flag_load_finished:
                m_flag_load_finished = false
                m_logger.debug("Loading Finished!")
                m_state = STATE_TYPE.IDLE
        _:
            m_logger.debug("Unknown State: %s" % m_state)

func _check_library_database_path(clear_db = false) -> bool:
    # Check if the library database path is set
    m_logger.debug("Checking Library Database Path")
    var lib_db_path = ""
    if not clear_db:
        lib_db_path = m_config.get_value("config", "library_database")
    if len(lib_db_path) != 0:
        m_logger.info("Library Database Path is set")
        return true

    # Get parent path from config
    var parent_path = m_config.get_value("config", "base_path")
    var database_path = parent_path + "/database.db"


    if FileAccess.file_exists(database_path):
        # Check if the file exists
        var confirm = $ConfirmDialogAsync
        confirm.set_text("Okay to set library database path to: \'%s\'?" % database_path)
        confirm.exclusive = true
        confirm.show()
        var auto_accept = await confirm.finished
        print ("Auto Accept: %s" % auto_accept)
        if auto_accept:
            m_props["library_database"]["value"] = database_path
            m_properties.update_dict(m_props)
            m_config.set_value("config", "library_database", database_path)
            m_config.save(m_config_file)
            return true
    else:
        m_logger.info("Library Database Path is not set, please set it manually")
        var fdialog = $DatabaseFileDialog
        fdialog.current_dir = parent_path
        fdialog.show()
        var result = await fdialog.finished
        if result:
            m_props["library_database"]["value"] = fdialog.selected_file
            m_properties.update_dict(m_props)
            m_config.set_value("config", "library_database", fdialog.selected_file)
            m_config.save(m_config_file)
            return true
        else:
            m_logger.error("Library Database Path is not set, please set it manually")
            m_props["library_database"]["value"] = ""
            m_properties.update_dict(m_props)
            m_config.set_value("config", "library_database", "")
            m_config.save(m_config_file)
    return false





##############################################################################
# Signal Handlers
##############################################################################

func _property_changed(prop_name:String, value):
    m_logger.debug("Property Changed: %s = %s" % [name, value])
    match prop_name:
        "auto_load":
            m_config.set_value("config", "auto_load", value)
        "reset_db":
            m_config.set_value("config", "reset_db", value)
        "clear_db":
            m_config.set_value("config", "clear_db", value)
        "reload_lib_button":
            m_processor.reload_library()
        "select_db":
            m_logger.debug("Select DB Button Pressed!")
            m_flag_select_new_db = true
            m_flag_ready = true
        "reset_tile_db":
            m_flag_reset_tile_db = true
            m_flag_select_new_db = true
            m_flag_ready = true
        _:
            pass
    m_config.save(m_config_file)


func _loading_finished():
    m_flag_load_finished = true
