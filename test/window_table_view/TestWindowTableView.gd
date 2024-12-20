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
var m_logger = LogStream.new("Test Window Table View", LogStream.LogLevel.DEBUG)

## Flags ##

##############################################################################
# Scenes
##############################################################################
@onready var m_window_table_view = $WindowTableView

##############################################################################
# Exports
##############################################################################
@export var m_data: Array = [[1, 2, 3, 4],
                             [5.0, 6, 7, 8],
                             [9, 10, 11, 12],
                             [13, 14, 15, 16]]

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
    m_window_table_view.set_data(m_data)
    m_window_table_view.visible = true
    m_window_table_view.cell_selected.connect(_cell_selected)
    m_window_table_view.cell_hover_down.connect(_cell_hover_down)
    m_window_table_view.cell_hover_up.connect(_cell_hover_up)


func _cell_hover_down(y: int, x: int) -> void:
    m_logger.debug("Cell Hover Down: y: %d, x: %d" % [y, x])
    if m_data[y][x] is int:
        m_data[y][x] -= 1
    elif m_data[y][x] is float:
        m_data[y][x] -= 0.1
    else:
        m_logger.debug("Data is something else!")
    m_window_table_view.update_value(y, x, m_data[y][x])

func _cell_hover_up(y: int, x: int) -> void:
    m_logger.debug("Cell Hover Up: y: %d, x: %d" % [y, x])
    if m_data[y][x] is int:
        m_data[y][x] += 1
    elif m_data[y][x] is float:
        m_data[y][x] += 0.1
    else:
        m_logger.debug("Data is something else!")
    m_window_table_view.update_value(y, x, m_data[y][x])

func _cell_selected(y: int, x: int) -> void:
    m_logger.debug("Cell Selected: y: %d, x: %d" % [y, x])
    if m_data[y][x] is int:
        m_logger.debug("Data is an int!")
    elif m_data[y][x] is Array:
        m_logger.debug("Data is an array!")
    elif m_data[y][x] is String:
        m_logger.debug("Data is a string!")
    elif m_data[y][x] is float:
        m_logger.debug("Data is a float!")
    else:
        m_logger.debug("Data is something else!")
