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
var m_logger = LogStream.new("MapDrawer", LogStream.LogLevel.DEBUG)

var m_vector_size:Vector2 = Vector2(0, 0)
var m_module_dict:Dictionary = {}
var m_map_view = null
var m_map_database_adapter = null

enum STATE_TYPE {
  RESET,
  IDLE,
  PROCESS_TILES,
}
var m_state:STATE_TYPE = STATE_TYPE.RESET
var m_sub_composers:Dictionary = {}

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func set_map_view(map_view):
    m_map_view = map_view

func set_map_database_adapter(map_database_adapter):
    m_map_database_adapter = map_database_adapter

func set_tile_size(tile_size:Vector2):
    m_vector_size = tile_size

func set_module_dict(module_dict:Dictionary):
    m_module_dict = module_dict


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_state = STATE_TYPE.RESET
    m_map_database_adapter = $MapDatabaseAdapter

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    match m_state:
        STATE_TYPE.RESET:
            if m_map_database_adapter != null:
                m_logger.debug("Map Database is ready")
                var subcomposers = get_tree().get_nodes_in_group("subcomposer")
                for c in subcomposers:
                    m_sub_composers[c.get_name()] = c
                    m_logger.debug("Added Subcomposer: " + c.get_name())
                    c.setup(m_map_database_adapter)
                m_state = STATE_TYPE.IDLE
        STATE_TYPE.IDLE:
            pass
        STATE_TYPE.PROCESS_TILES:
            pass

func _process_tiles():
    pass
