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
var m_config = null
var m_props = {}

#######################################
# Flags
#######################################
var m_flag_ready = false
var m_flag_load_library = false
var m_flag_load_finished = false
var m_flag_auto_load = false

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
    var config_file = "%s/%s" % [_dir, "map.cfg"]
    m_config.load(config_file)


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
                _check_library_database_path()
                m_flag_auto_load = m_config.get_value("config", "auto_load")
                m_state = STATE_TYPE.IDLE
        STATE_TYPE.IDLE:
            if m_flag_load_library or m_flag_auto_load:
                m_logger.debug("Loading Library Database!")
                m_flag_load_library = false
                m_flag_auto_load = false
                #XXX: TODO
                #m_processor.load_library()
                m_state = STATE_TYPE.LOADING
        STATE_TYPE.LOADING:
            if m_flag_load_finished:
                m_flag_load_finished = false
                m_logger.debug("Loading Finished!")
                m_state = STATE_TYPE.IDLE
        _:
            m_logger.debug("Unknown State: %s" % m_state)

func _check_library_database_path():
    # Check if the library database path is set
    m_logger.debug("Checking Library Database Path")
    var lib_db_path = m_config.get_value("config", "library_database")
    if len(lib_db_path) != 0:
        m_logger.error("Library Database Path is set")
        return

    # Get parent path from config
    var parent_path = m_config.get_value("config", "base_path")
    var database_path = parent_path + "/database.db"
    # Check if the file exists
    var confirm = $ConfirmDialogAsync
    confirm.set_text("Okay to set library database path to: \'%s\'?" % database_path)
    confirm.exclusive = true
    confirm.popup_exclusive_centered(self, Vector2(300, 100))
    var auto_accept = await confirm.finished
    print ("Auto Accept: %s" % auto_accept)


    #if FileAccess.file_exists(database_path):
    #    m_props["library_database"]["value"] = database_path
    #    m_config.set_value("config", "library_database", database_path)
    #    var confirm = ConfirmationDialog.new()
    #    confirm.popup_centered()
    #    confirm.set_text("Okay to set library database path to: \'%s\'?" % database_path)
    #    confirm.exclusive = true
    #    confirm.get_ok_button().pressed.connect(func(): auto_accept = true)
    #    confirm.popup_exclusive_centered(self, minsize = Vector2(300, 100))




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
        _:
            pass
    m_config.save()


func _loading_finished():
    m_flag_load_finished = true
