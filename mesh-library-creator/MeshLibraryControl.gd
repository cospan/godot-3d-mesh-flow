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
var m_logger = LogStream.new("MeshLibraryControl", LogStream.LogLevel.DEBUG)
var m_project_directory:String = ""
var m_config = null

# Flags



##############################################################################
# State Machine
##############################################################################
enum STATE_TYPE {
    STATE_RESET,
    STATE_READY,
    STATE_LOADING,
    STATE_NOTHING_SELECTED,
    STATE_MODULE_SELECTED,
    STATE_FACE_SELECTED
}
var m_state = STATE_TYPE.STATE_RESET
var m_prev_state = STATE_TYPE.STATE_RESET


##############################################################################
# Exports
##############################################################################
@export var FORCE_NEW_DB:bool = false
@export var DEBUG:bool = false


##############################################################################
# Public Functions
##############################################################################
func init(dir:String):
    m_logger.debug("Init Entered!")
    m_config = ConfigFile.new()
    m_project_directory = dir
    var lib_folder = "%s/%s" % [m_project_directory, ".library"]
    var config_file = "%s/%s" % [lib_folder, "library.cfg"]
    m_config.load(config_file)
    m_config.set_value("config", "auto_load", true)

func enable_auto_load(enable:bool):
    m_config.set_value("config", "auto_load", enable)
    if enable:
        m_logger.debug("Enabling Auto Load")
    else:
        m_logger.debug("Disabling Auto Load")



##############################################################################
# Private Functions
##############################################################################


# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

