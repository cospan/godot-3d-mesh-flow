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
var m_flag_load_library = false
var m_flag_reset_library = false


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

var m_props = {}

var m_properties = null
var m_mlp = null


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
    m_logger.set_name("MLC (%s)" % m_config.get_value("config", "name"))
    m_properties = $HBMain/DictProperty
    m_mlp = $MeshLibraryProcessor

    m_props["progress"] = {"type": "ProgressBar", "name": "Progress", "value": 0, "min": 0, "max": 100, "tooltip": "Display Progress of Loading"}
    m_props["auto_load"] = {"type": "CheckBox", "name": "Auto Load", "value": m_config.get_value("config", "auto_load"), "tooltip": "Auto Load Library on Start"}
    m_props["load_library"] = {"type": "Button", "name": "Load Library", "value": "Load Library", "tooltip": "Load Library", "visible": not m_config.get_value("config", "auto_load"), }
    m_props["reset_library"] = {"type": "Button", "name": "Reset Library", "value": "Reset Library", "tooltip": "Reset Library and initialize it again"}
    m_props["view_all_modules"] = {"type": "Button", "name": "View All Modules", "value": "View All Modules", "tooltip": "View All Modules"}
    m_props["module_select"] = {"type": "ItemList", "name": "Module Select", "value": 0, "size": Vector2(100, 200), "tooltip": "Select Module Using List"}
    m_props["module_xy_size"] = {"type": "SpinBox", "name": "Module XZ Size", "value": Vector2(0, 0), "tooltip": "Module XY Size is Calculated and Displayed Here"}
    m_properties.update_dict(m_props)
    m_properties.property_changed.connect(_property_changed)

    m_mlp.progress_percent_update.connect(_mlp_progress_percent_updated)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    match (m_state):
        STATE_TYPE.STATE_RESET:
            m_logger.debug("State: Reset")
            m_state = STATE_TYPE.STATE_READY
        STATE_TYPE.STATE_READY:
            m_logger.debug("State: Ready")
            if m_config.get_value("config", "auto_load") or m_flag_load_library:
                m_flag_load_library = false
                m_mlp.load_library(m_project_directory, m_flag_reset_library)
                m_flag_reset_library = false
                m_state = STATE_TYPE.STATE_LOADING
            else:
                m_logger.debug("Auto Load Disabled")
            m_state = STATE_TYPE.STATE_LOADING
        STATE_TYPE.STATE_LOADING:
            if m_prev_state != STATE_TYPE.STATE_LOADING:
                m_logger.debug("State: Loading")
            #m_state = STATE_TYPE.STATE_NOTHING_SELECTED
            pass
        STATE_TYPE.STATE_NOTHING_SELECTED:
            m_logger.debug("State: Nothing Selected")
        STATE_TYPE.STATE_MODULE_SELECTED:
            m_logger.debug("State: Module Selected")
        STATE_TYPE.STATE_FACE_SELECTED:
            m_logger.debug("State: Face Selected")
        _:
            m_logger.debug("State: Unknown")
            m_state = STATE_TYPE.STATE_RESET

    m_prev_state = m_state

func get_project_path():
    return m_project_directory


##############################################################################
# Signal Handlers
##############################################################################


func _property_changed(prop_name:String, prop_value):
    m_logger.debug("Property Changed: %s" % prop_name)
    match prop_name:
      "module_select":
          m_logger.debug("Module Selected: %s" % prop_value)
      "view_all_modules":
          m_logger.debug("View All Modules")
      "load_library":
          m_logger.debug("Load Library")
          m_flag_load_library = true
      "auto_load":
          m_logger.debug("Auto Load: %s" % prop_value)
          m_config.set_value("config", "auto_load", prop_value)
          m_props["load_library"]["visible"] = not prop_value
          m_properties.set_prop_visible("load_library", not prop_value)
      "reset_library":
          m_logger.debug("Reset Library")
          m_state = STATE_TYPE.STATE_RESET
          m_flag_reset_library = true
          m_flag_load_library = true
      _:
          m_logger.debug("Unknown Property: %s" % str(prop_name))


func _mlp_progress_percent_updated(_name:String, _percent:float):
    #m_logger.debug("Progress: %s" % _percent)
    m_properties.set_label("progress", _name)
    m_properties.set_value("progress", _percent)

