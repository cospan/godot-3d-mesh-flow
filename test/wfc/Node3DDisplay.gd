extends Node3D


##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################
enum kStates {
    STATE_RESET,
    STATE_WAIT_FOR_MAP_DB,
    STATE_READY
}

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("_BASE_", LogStream.LogLevel.DEBUG)
var m_state = kStates.STATE_RESET

## Flags ##

##############################################################################
# Scenes
##############################################################################
var m_map_db_adapter:Node = null

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################
func set_map_db_adapter(p_map_db_adapter: Node) -> void:
    m_map_db_adapter = p_map_db_adapter
    m_state = kStates.STATE_WAIT_FOR_MAP_DB


##############################################################################
# Private Functions
##############################################################################

##############################################################################
# Signal Handlers
##############################################################################

func _ready() -> void:
    m_logger.debug("Ready Entered!")

func _process(_delta: float) -> void:
    match m_state:
        kStates.STATE_RESET:
            pass
        kStates.STATE_WAIT_FOR_MAP_DB:
            if m_map_db_adapter != null:
                m_state = kStates.STATE_READY
        kStates.STATE_READY:
            var commands = m_map_db_adapter.get_commands()
            if len(commands) > 0:
                _new_map_data(commands)

func _new_map_data(commands):
    m_logger.debug("  Command: %s" % commands)
