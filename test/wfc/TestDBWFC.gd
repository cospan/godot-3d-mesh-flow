extends Node

##############################################################################
# Test Description
##############################################################################
# This is a test script for the WFC Database. It will test the database
# adapter for WFC.
# * The WFC system should generate the rules based off of the database
#   * We need to figure out how to generate the rules from the database
#     The easiest way would be to have a pseudo map that will return
# * The WFC system should generate the output based off of the rules


##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################
const MAP_DATABASE_DIR = "res://test/wfc/data/"
const MAP_DATABASE_FILE = "database_map.db"
const MAP_DATABASE_TEST_FILE = "database_map_test.db"

const TILE_DATABASE_DIR = "res://test/wfc/data/"
const TILE_DATABASE_FILE = "database_tile.db"
const TILE_DATABASE_TEST_FILE = "database_tile_test.db"

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Test DB WFC", LogStream.LogLevel.DEBUG)

var MAP_DATABASE_PATH = MAP_DATABASE_DIR + MAP_DATABASE_FILE
var MAP_DATABASE_TEST_PATH = MAP_DATABASE_DIR + MAP_DATABASE_TEST_FILE

var TILE_DATABASE_PATH = TILE_DATABASE_DIR + TILE_DATABASE_FILE
var TILE_DATABASE_TEST_PATH = TILE_DATABASE_DIR + TILE_DATABASE_TEST_FILE

## Flags ##

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################
@export var reset_map_database:bool = true

##############################################################################
# Public Functions
##############################################################################

##############################################################################
# Private Functions
##############################################################################

##############################################################################
# Signal Handlers
##############################################################################

func _ready():
    m_logger.debug("Ready Entered!")


    m_logger.debug("Copy over the databases so we have a good reference")
    var da = DirAccess.open(TILE_DATABASE_DIR)
    assert(da.file_exists(TILE_DATABASE_FILE), "Tile Database file does not exist")
    if da.file_exists(TILE_DATABASE_TEST_FILE):
        da.remove(TILE_DATABASE_TEST_FILE)
    da.copy(TILE_DATABASE_PATH, TILE_DATABASE_TEST_PATH)

    da = DirAccess.open(MAP_DATABASE_DIR)
    da.file_exists(MAP_DATABASE_FILE)
    if da.file_exists(MAP_DATABASE_TEST_FILE):
        da.remove(MAP_DATABASE_TEST_FILE)
    da.copy(MAP_DATABASE_PATH, MAP_DATABASE_TEST_PATH)

    m_logger.debug("Instantiate the adapters and generator")
    var wfc_generator = $WFCGenerator
    var map_db_adapter = $MapDatabaseAdapter
    var tile_db_adapter = $TileDatabaseAdapter
    var node_3d_display = $Node3DDisplay
    node_3d_display.set_map_db_adapter(map_db_adapter)

    m_logger.debug("Open up the databases")
    tile_db_adapter.open_database(TILE_DATABASE_TEST_PATH)
    map_db_adapter.open_database(MAP_DATABASE_TEST_PATH, reset_map_database, reset_map_database)

    wfc_generator.m_map_db_adapter = map_db_adapter
    wfc_generator.m_tile_db_adapter = tile_db_adapter
    wfc_generator.m_target_node = node_3d_display
    if wfc_generator.start_on_ready:
        wfc_generator.start()

func _process(_delta):
    pass
