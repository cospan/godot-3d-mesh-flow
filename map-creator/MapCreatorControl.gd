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
var m_logger = LogStream.new("MC", LogStream.LogLevel.INFO)
var m_project_path:String = ""
var m_config_file:String = ""
var m_config = null
var m_props = {}
var m_mesh_lib_dict = {}
@onready var m_wfc_composer_scene = preload("res://map-creator/sub-composers/WFCComposer.tscn")

#######################################
# Flags
#######################################
var m_flag_ready = false
var m_flag_load_library = false
var m_flag_load_finished = false
var m_flag_auto_load = false
var m_flag_select_new_db = false
var m_flag_reset_tile_db = false
var m_flag_mesh_lib_to_process = false

#######################################
# State Machine
#######################################
enum STATE_TYPE {
    IDLE,
    LOADING,
}
var m_state = STATE_TYPE.IDLE


##############################################################################
# Scenes
##############################################################################
#var m_library_db_adapter = null
#var m_library_2_tile_converter = null
#var m_tile_db_adapter = null
var m_composer = null

var m_properties = null
var m_map_composer = null
var m_view = null

##############################################################################
# Exports
##############################################################################
var DATABASE_NAME = "tile_database.db"

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

#func _check_library_database_path(clear_db = false) -> bool:
#    # Check if the library database path is set
#    m_logger.debug("Checking Library Database Path")
#    var lib_db_path = ""
#    if not clear_db:
#        lib_db_path = m_config.get_value("config", "library_database")
#    if len(lib_db_path) != 0 and FileAccess.file_exists(lib_db_path):
#        m_logger.info("Library Database Path is set")
#        return true
#
#    # Get parent path from config
#    var parent_path = m_config.get_value("config", "base_path")
#    var database_path = parent_path + "/database.db"
#
#
#    if FileAccess.file_exists(database_path):
#        # Check if the file exists
#        var confirm = $ConfirmDialogAsync
#        confirm.set_text("Okay to set library database path to: \'%s\'?" % database_path)
#        confirm.exclusive = true
#        confirm.show()
#        var auto_accept = await confirm.finished
#        print ("Auto Accept: %s" % auto_accept)
#        if auto_accept:
#            m_props["library_database"]["value"] = database_path
#            m_properties.set_value("library_database", database_path)
#            m_config.set_value("config", "library_database", database_path)
#            m_config.save(m_config_file)
#            return true
#    else:
#        m_logger.info("Library Database Path is not set, please set it manually")
#        var fdialog = $DatabaseFileDialog
#        fdialog.current_dir = parent_path
#        fdialog.show()
#        var result = await fdialog.finished
#        if result:
#            m_props["library_database"]["value"] = fdialog.selected_file
#            m_properties.set_value("library_database", fdialog.selected_file)
#            m_config.set_value("config", "library_database", fdialog.selected_file)
#            m_config.save(m_config_file)
#            return true
#        else:
#            m_logger.error("Library Database Path is not set, please set it manually")
#            m_props["library_database"]["value"] = ""
#            m_properties.set_value("library_database", "")
#            m_config.set_value("config", "library_database", "")
#            m_config.save(m_config_file)
#    return false

#func _convert_library_db_2_tile_db(_library_db_path:String, _tile_db_path:String, _clear_rows:bool, _force_new_tables:bool):
#    m_logger.debug("Converting Library DB to Tile DB")
#    m_library_db_adapter.open_database(_library_db_path)
#    m_tile_db_adapter.open_database(_tile_db_path, _clear_rows, _force_new_tables)
#    m_library_2_tile_converter.process_database(m_library_db_adapter, m_tile_db_adapter)


func _create_wfc_composer_from_mesh_library(_library_db_path:String, _tile_db_path = null):
    #XXX: Not implemented yet
    m_logger.debug("Adding Tile Database")
    m_logger.debug("If the user doesn't specify the tile database path, it will be created in the configuration file for the project")
    if _tile_db_path == null:
        # Get the parent path from the _library_db_path
        var parent_path = _library_db_path.get_base_dir()
        var lib_file_name = _library_db_path.get_file()
        var tile_db_name = lib_file_name.get_basename() + "_tile.db"
        _tile_db_path = "%s/%s" % [parent_path, tile_db_name]

    # Create a new WFCComposer and add it to the MapComposer
    var wfc_composer = m_wfc_composer_scene.instantiate()
    m_map_composer.add_child(wfc_composer)
    wfc_composer.initialize(_library_db_path, _tile_db_path)

##############################################################################
# Signal Handlers
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_logger.set_name("MC (%s)" % m_config.get_value("config", "name"))
    m_properties = $HBMain/DictProperty
    m_map_composer = $MapComposer
    m_view = $HBMain/VBMain/SVPContainer/SVP/MapView

    #m_library_db_adapter = $ModuleDatabaseAdapter
    #m_library_2_tile_converter = $Library2TileConverter
    #m_tile_db_adapter = $TileDatabaseAdapter
    m_composer = $MapComposer

    m_composer.set_map_view(m_view)
    m_map_composer.set_map_view(m_view)
    if not m_config.has_section_key("config", "database_path"):
        var _dir = m_config.get_value("config", "path")
        m_config.set_value("config", "database_path", "%s/%s" % [_dir, DATABASE_NAME])
        m_config.save(m_config_file)

    # Populate the m_mesh_lib_dict with all the libraries
    var mesh_lib_paths = m_config.get_value("config", "library_databases")
    for lib_path in mesh_lib_paths:
        var mesh_lib_name = lib_path.split("/")[-2]
        m_mesh_lib_dict[mesh_lib_name] = {"path": lib_path, "processed": false}

    m_props["reload_lib_button"] = {"type": "Button", "name": "Reload Library", "tooltip": "Reload Library"}
    m_props["auto_load"] = {"type": "CheckBox", "name": "Auto Load", "value": m_config.get_value("config", "auto_load"), "tooltip": "Auto Load Library on Start"}
    m_props["library_databases"] = {"type": "ItemList", "name": "Library Databases", "value": m_mesh_lib_dict.keys(), "size": Vector2(200, 200), "tooltip": "Library Database Path"}
    m_props["reset_db"] = {"type": "CheckBox", "name": "Reset DB", "value": m_config.get_value("config", "reset_db"), "tooltip": "Reset DB and reload DB Tables on start"}
    m_props["clear_db"] = {"type": "CheckBox", "name": "Clear DB", "value": m_config.get_value("config", "clear_db"), "tooltip": "Clear all database rows on Start"}
    m_props["select_db"] = {"type": "Button", "name": "Select DB", "tooltip": "Select Library Database Path"}
    m_props["reset_tile_db"] = {"type": "Button", "name": "Reset Tile DB", "tooltip": "Regenerate the Tile DB from the library DB"}
    m_properties.set_properties_dict(m_props)
    m_properties.interrogate_tree("map-creator-properties")

    # Connect Signals
    m_properties.property_changed.connect(_property_changed)
    #m_library_2_tile_converter.finished_loading.connect(_loading_finished)

    m_flag_ready = true
    if len(m_mesh_lib_dict.keys()) > 0:
        m_flag_mesh_lib_to_process = true



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if m_flag_mesh_lib_to_process:
        m_flag_mesh_lib_to_process = false
        for lib_name in m_mesh_lib_dict.keys():
            var lib_path = m_mesh_lib_dict[lib_name]["path"]
            var processed = m_mesh_lib_dict[lib_name]["processed"]
            if not processed:
                m_logger.debug("Processing Library: %s" % lib_name)
                m_mesh_lib_dict[lib_name]["processed"] = true
                _create_wfc_composer_from_mesh_library(lib_path)

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
            m_flag_load_library = true
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
