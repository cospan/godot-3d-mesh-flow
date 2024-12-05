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
var m_mesh_lib_dict = {}
var m_wfc_dict = {}
@onready var m_wfc_composer_scene = preload("res://map-creator/composers/WFCComposer.tscn")

#######################################
# Flags
#######################################
var m_flag_ready = false
#var m_flag_load_library = false
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
var m_properties = null
var m_map_composer = null
var m_map_database_adapter = null
var m_view = null
var m_toolbar = null

##############################################################################
# Exports
##############################################################################
var DATABASE_NAME:String = "map.db"
var RESET_DATABASE:bool = false

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
func _create_wfc_composer_from_mesh_library(_library_db_path:String, _tile_db_path = null):
    #XXX: Not implemented yet
    m_logger.debug("Adding Tile Database")
    m_logger.debug("If the user doesn't specify the tile database path, it will be created in the configuration file for the project")
    var parent_path = _library_db_path.get_base_dir()
    var lib_file_name = _library_db_path.get_file()
    var wfc_name = lib_file_name.get_basename()

    if _tile_db_path == null:
        # Get the parent path from the _library_db_path
        var tile_db_name = wfc_name + "_tile.db"
        _tile_db_path = "%s/%s" % [parent_path, tile_db_name]

    # Create a new WFCComposer and add it to the MapComposer
    var wfc_composer = m_wfc_composer_scene.instantiate()
    m_map_composer.add_child(wfc_composer)
    wfc_composer.initialize(_library_db_path, _tile_db_path)
    m_wfc_dict[wfc_name] = wfc_composer
    #XXX For initial testing add a polygon
    var p = Polygon2D.new()
    p.polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, 10), Vector2(10, 10), Vector2(10, 0)])
    wfc_composer.add_wfc_polygon_area(p, 1.0)

##############################################################################
# Signal Handlers
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_logger.set_name("MC (%s)" % m_config.get_value("config", "name"))
    m_properties = $HBMain/DictProperty
    m_map_composer = $MapComposer
    m_map_database_adapter = $MapDatabaseAdapter
    m_view = $HBMain/VBMain/SVPContainer/SVP/MapView
    m_toolbar = $HBMain/VBMain/HBoxToolbar

    # Check the configuration file for the map database
    var map_database = m_config.get_value("config", "map_database")

    if len(map_database) == 0:
        # If one doesn't exist, create it
        map_database = "%s/%s" % [m_project_path, "map.db"]
        m_config.set_value("config", "map_database", map_database)
        m_config.save(m_config_file)

    # Open the map database
    m_map_database_adapter.open_database(map_database, RESET_DATABASE, RESET_DATABASE)

    # Setup the map composer to control the view
    m_map_composer.set_view(m_view)
    m_map_composer.set_database_adapter(m_map_database_adapter)
    m_map_composer.set_toolbar(m_toolbar)
    m_map_composer.set_dict_prop_view(m_properties)
    m_map_composer.add_composer.connect(_map_composer_composer_loaded)
    m_map_composer.remove_composer.connect(_map_composer_composer_removed)


    #if not m_config.has_section_key("config", "database_path"):
    #    var _dir = m_config.get_value("config", "path")
    #    m_config.set_value("config", "database_path", "%s/%s" % [_dir, DATABASE_NAME])
    #    m_config.save(m_config_file)

    # Populate the m_mesh_lib_dict with all the libraries
    #var mesh_lib_paths = m_config.get_value("config", "library_databases")
    #for lib_path in mesh_lib_paths:
    #    var mesh_lib_name = lib_path.split("/")[-2]
    #    m_mesh_lib_dict[mesh_lib_name] = {"path": lib_path, "processed": false}

    #m_props["reload_lib_button"] = {"type": "Button", "name": "Reload Library", "tooltip": "Reload Library"}
    #m_props["auto_load"] = {"type": "CheckBox", "name": "Auto Load", "value": m_config.get_value("config", "auto_load"), "tooltip": "Auto Load Library on Start"}
    #m_props["library_databases"] = {"type": "ItemList", "name": "Library Databases", "value": m_mesh_lib_dict.keys(), "size": Vector2(200, 200), "tooltip": "Library Database Path"}
    m_props["reset_db"] = {"type": "CheckBox", "name": "Reset DB", "value": m_config.get_value("config", "reset_db"), "tooltip": "Reset DB and reload DB Tables on start"}
    m_props["clear_db"] = {"type": "CheckBox", "name": "Clear DB", "value": m_config.get_value("config", "clear_db"), "tooltip": "Clear all database rows on Start"}
    #m_props["select_db"] = {"type": "Button", "name": "Select DB", "tooltip": "Select Library Database Path"}
    #m_props["reset_tile_db"] = {"type": "Button", "name": "Reset Tile DB", "tooltip": "Regenerate the Tile DB from the library DB"}
    m_properties.set_properties_dict(m_props)
    m_properties.interrogate_tree("map-creator-properties")

    # Connect Signals
    m_properties.property_changed.connect(_property_changed)

    m_flag_ready = true
    if len(m_mesh_lib_dict.keys()) > 0:
        m_flag_mesh_lib_to_process = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    #if m_flag_mesh_lib_to_process:
    #    m_flag_mesh_lib_to_process = false
    #    for lib_name in m_mesh_lib_dict.keys():
    #        var lib_path = m_mesh_lib_dict[lib_name]["path"]
    #        var processed = m_mesh_lib_dict[lib_name]["processed"]
    #        if not processed:
    #            m_logger.debug("Processing Library: %s" % lib_name)
    #            m_mesh_lib_dict[lib_name]["processed"] = true
    #            #XXX: Get the name of the wfc composer and wfc composer and put it into a dictionary
    #            _create_wfc_composer_from_mesh_library(lib_path)
    pass

func _property_changed(prop_name:String, value):
    m_logger.debug("Property Changed: %s = %s" % [name, value])
    match prop_name:
        #"auto_load":
        #    m_config.set_value("config", "auto_load", value)
        "reset_db":
            m_config.set_value("config", "reset_db", value)
        "clear_db":
            m_config.set_value("config", "clear_db", value)
        #"reload_lib_button":
        #    m_flag_load_library = true
        #"select_db":
        #    m_logger.debug("Select DB Button Pressed!")
        #    m_flag_select_new_db = true
        #    m_flag_ready = true
        #"reset_tile_db":
        #    m_flag_reset_tile_db = true
        #    m_flag_select_new_db = true
        #    m_flag_ready = true
        _:
            pass
    m_config.save(m_config_file)


func _loading_finished():
    m_flag_load_finished = true

func _map_composer_composer_loaded(_name):
    m_logger.info("Map Composer composer Loaded: %s" % _name)
    m_properties.interrogate_tree("map-creator-properties")

func _map_composer_composer_removed(_name):
    m_logger.info("Map Composer composer Removed: %s" % _name)
    m_properties.remove_node_by_name(_name)
