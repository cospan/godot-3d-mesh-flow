extends Node


##############################################################################
# Signals
##############################################################################

signal loading_finished

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Template", LogStream.LogLevel.INFO)

#######################################
# Scenes
#######################################
var m_library_db_adapter = null
var m_library_2_tile_converter = null
var m_tile_db_adapter = null

#######################################
# Flags
#######################################
var m_flag_reset_finished = false
var m_flag_start_conversion = false

#######################################
# State Machine
#######################################

enum STATE_TYPE {
    RESET,
    IDLE,
    CONVERT_LIBRARY_DB_2_TILE_DB,
}
var m_state = STATE_TYPE.RESET

#######################################
# Exports
#######################################


##############################################################################
# Public Functions
##############################################################################
func convert_library_db_2_tile_db(_library_db_path:String, _tile_db_path:String, _clear_rows:bool, _force_new_tables:bool):
    m_logger.debug("Converting Library DB to Tile DB")
    m_library_db_adapter.open_database(_library_db_path)
    m_tile_db_adapter.open_database(_tile_db_path, _clear_rows, _force_new_tables)
    m_library_2_tile_converter.process_database(m_library_db_adapter, m_tile_db_adapter)
    m_flag_start_conversion = true


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_library_db_adapter = $ModuleDatabaseAdapter
    m_library_2_tile_converter = $Library2TileConverter
    m_tile_db_adapter = $TileDatabaseAdapter
    m_flag_reset_finished = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
        match(m_state):
            STATE_TYPE.RESET:
                if m_flag_reset_finished:
                    m_flag_reset_finished = false
                    m_state = STATE_TYPE.IDLE

            STATE_TYPE.IDLE:
                if m_flag_start_conversion:
                    m_flag_start_conversion = false
                    m_state = STATE_TYPE.CONVERT_LIBRARY_DB_2_TILE_DB

            STATE_TYPE.CONVERT_LIBRARY_DB_2_TILE_DB:
                pass

            _:
                m_logger.error("Unknown State: {m_state}")

