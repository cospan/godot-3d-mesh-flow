extends SubComposerBase


##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################
const PROP_GENERATE_TERRAIN = "WFC_generator"

enum STATES_T {
    RESET,
    LOADING,
    READY,
    START_PROCESSING_AREA,
    PROCESSING_AREA,
}
var m_state:STATES_T = STATES_T.RESET

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("WFC Generator", LogStream.LogLevel.DEBUG)
var m_area_polygon_map = {}
var m_area_index = -1

###################
# Flags
###################
var m_flag_ready = false
var m_flag_initialize_library = false
var m_flag_reset_tile_db = false
var m_flag_load_finished = false
var m_flag_new_area_outline = false

##############################################################################
# Scenes
##############################################################################
var m_library_db_adapter = null
var m_library_2_tile_converter = null
var m_tile_db_adapter = null

var m_library_database_path:String = ""
var m_tile_database_path:String = ""


##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################
func initialize(library_database_path:String, tile_database_path:String, reset_tile_db:bool = false):
    #XXX: Not Tested Yet
    m_library_database_path = library_database_path
    m_tile_database_path = tile_database_path
    m_flag_reset_tile_db = reset_tile_db
    m_flag_initialize_library = true

func add_wfc_polygon_area(polygon: Polygon2D, height:float) -> int:
    #XXX: Not Tested Yet
    var keys = m_area_polygon_map.keys()
    keys.sort()
    var index = 0 if len(keys) == 0 else keys[-1] + 1
    m_area_polygon_map[index] = {"polygon": polygon, "height": height, "finished": false}
    m_flag_new_area_outline = true
    return index

func remove_wfc_polygon_area_by_index(index:int) -> void:
    #XXX: Not Tested Yet
    if index in m_area_polygon_map.keys():
        m_area_polygon_map.erase(index)

##############################################################################
# Private Functions
##############################################################################

func _generate_tile_database(_library_db_path:String, _tile_db_path:String, _reset_tile_db:bool):
    m_logger.debug("Converting Library DB to Tile DB")
    m_library_db_adapter.open_database(_library_db_path)
    m_tile_db_adapter.open_database(_tile_db_path, _reset_tile_db, _reset_tile_db)
    m_library_2_tile_converter.process_database(m_library_db_adapter, m_tile_db_adapter)



func step():
    # Override this function, Process WFC step at a time
    if m_area_index < 0:
        return

##############################################################################
# Signal Handlers
##############################################################################

func _ready():
    PROP_LABEL = name + "_label"
    PROP_ENABLE = name + "_enable"

    m_logger.debug("Ready Entered!")
    m_library_db_adapter = $ModuleDatabaseAdapter
    m_library_2_tile_converter = $Library2TileConverter
    m_tile_db_adapter = $TileDatabaseAdapter

    m_properties = {
        PROP_LABEL:
        {
          "type": "Label",
          "name": "",
          "value": name,
        },
        PROP_ENABLE:
        {
          "type": "CheckBox",
          "name" : "Enable",
          "value": enabled,
          "callback": _on_property_changed,
          "tooltip": name + ": Enable Composer"
        }
    }
    add_to_group("subcomposer")
    add_to_group("map-creator-properties")

    # Connect Signals
    m_library_2_tile_converter.finished_loading.connect(_loading_finished)

    # We are ready to go
    m_flag_ready = true

func _process(_delta):
    match m_state:
        STATES_T.RESET:
            if m_flag_initialize_library and enabled and m_flag_ready:
                m_flag_initialize_library = false
                m_flag_ready = false
                _generate_tile_database(m_library_database_path, m_tile_database_path, m_flag_reset_tile_db)
                m_state = STATES_T.LOADING
        STATES_T.LOADING:
            if m_flag_load_finished:
                m_logger.debug("Loading Finished!")
                m_flag_load_finished = false
                # If we reload the library, we also want to kick off the tile builder
                for index in m_area_polygon_map.keys():
                    m_area_polygon_map[index]["finished"] = false
                m_flag_new_area_outline = true
                m_state = STATES_T.READY
        STATES_T.READY:
            if not enabled:
                m_state = STATES_T.RESET
            if m_flag_new_area_outline:
                m_state = STATES_T.START_PROCESSING_AREA
        STATES_T.START_PROCESSING_AREA:
            m_flag_new_area_outline = false
            for index in m_area_polygon_map.keys():
                if not m_area_polygon_map[index]["finished"]:
                    m_flag_new_area_outline = true
                    var polygon = m_area_polygon_map[index]["polygon"]
                    var height = m_area_polygon_map[index]["height"]
                    #XXX: Add Polygon to WFC
                    m_area_polygon_map[index]["finished"] = true
        STATES_T.PROCESSING_AREA:
            step()


func _on_property_changed(property_name, property_value):
    #m_logger.debug("Property Changed For %s: %s = %s" % [name, property_name, property_value])
    match property_name:
        PROP_ENABLE:
            enabled = property_value
            #if not enabled:
            #    if m_map_db_adapter != null:
            #        _remove_all_meshes()

func _loading_finished():
    m_flag_load_finished = true
