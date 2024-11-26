extends Node

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("_BASE_", LogStream.LogLevel.DEBUG)

var m_library_database_adapter = null
var m_tile_database_adapter = null
var m_library_2_tile_converter = null

## Flags ##

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################
@export_file("*.db") var LibraryDatabasePath:String = "res://demo/test_pack1/database.json"
@export_file("*.db") var TileDatabasePath:String = "res://demo/database_tile.db"
@export var display_content:bool = false

##############################################################################
# Public Functions
##############################################################################

##############################################################################
# Private Functions
##############################################################################

##############################################################################
# Signal Handlers
##############################################################################

func _ready() -> void:
    m_logger.debug("Ready Entered!")
    m_library_database_adapter = $ModuleDatabaseAdapter
    m_tile_database_adapter = $TileDatabaseAdapter
    m_library_2_tile_converter = $Library2TileConverter

    m_library_database_adapter.open_database(LibraryDatabasePath)
    m_tile_database_adapter.open_database(TileDatabasePath, true, true)

    m_library_2_tile_converter.process_database(m_library_database_adapter, m_tile_database_adapter)
    m_library_2_tile_converter.finished_loading.connect(_loading_finished)

func _process(_delta: float) -> void:
    pass

func _loading_finished():
    m_logger.debug("Loading Finished!")
