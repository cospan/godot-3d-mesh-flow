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
var m_project_directory:String = ""
var m_config = null
var m_props = {}

#######################################
# State Machine
#######################################


##############################################################################
# Scenes
##############################################################################
var m_properties = null

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func init(dir:String):
    m_logger.debug("Init Entered!")
    m_config = ConfigFile.new()
    m_project_directory = dir
    var lib_folder = "%s/%s" % [m_project_directory, ".map"]
    var config_file = "%s/%s" % [lib_folder, "map.cfg"]
    m_config.load(config_file)
    m_config.set_value("config", "auto_load", true)

func get_project_path():
    return m_project_directory


##############################################################################
# Private Functions
##############################################################################


# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_logger.set_name("MC (%s)" % m_config.get_value("config", "name"))
    m_properties = $HBMain/DictProperties


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass
