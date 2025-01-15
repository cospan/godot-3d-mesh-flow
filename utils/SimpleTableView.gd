extends Control

class_name SimpleTableView

##############################################################################
# Signals
##############################################################################
signal cell_selected(y: int, x: int)
signal cell_hover_up(y: int, x: int)
signal cell_hover_down(y: int, x: int)

##############################################################################
# Constants
##############################################################################
enum STATES_T {
    STATE_RESET,
    STATE_IDLE,
    STATE_LOADING,
    STATE_READY,
    STATE_ERROR
}
var m_state:STATES_T = STATES_T.STATE_RESET
##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Window Table View", LogStream.LogLevel.DEBUG)
var m_table_name:String = ""

var m_data: Array = []

## Flags ##
var m_flag_loading_finished = false
var m_flag_data_parse_error = false
var m_flag_refresh = false
var m_flag_input_handled = false
var m_flag_initialized = false

##############################################################################
# Scenes
##############################################################################
@onready var m_grid_view: GridContainer = $VBox/ScrollContainer/GridContainer
@onready var m_status: LineEdit = $VBox/HBoxStatus/LineEditStatusField
@onready var m_refresh_button: Button = $VBox/HBoxMenu/ButtonRefresh
@onready var m_table_name_label: Label = $VBox/LabelTableName


##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################
func set_data(data: Array) -> void:
    m_data = data

func update_value(y: int, x: int, value) -> void:
    if y < m_data.size() and x < m_data[0].size():
        m_data[y][x] = value
        var cell = m_grid_view.get_child(y * m_grid_view.columns + x)
        if m_data[y][x] is float:
            cell.text = String.num(m_data[y][x], 2)
        else:
            cell.text = str(m_data[y][x])


    else:
        m_logger.error("Index out of bounds! y: %d, x: %d" % [y, x])

func set_table_name(_name: String) -> void:
    m_table_name = _name

##############################################################################
# Private Functions
##############################################################################

func _start_parse_data() -> void:
    # First find the size of the table
    if m_data == null:
        m_logger.error("Data is null!")
        _set_status("Error: Data is null!")
        m_flag_data_parse_error = true
        return

    if not m_data is Array:
        m_logger.error("Data is not an array!")
        _set_status("Error: Data is not an array!")
        m_flag_data_parse_error = true
        return

    if m_data.size() == 0:
        m_logger.error("Data is empty!")
        _set_status("Error: Data is empty!")
        m_flag_data_parse_error = true
        return

    var height = m_data.size()
    var width = m_data[0].size()
    m_grid_view.columns = width

    m_logger.debug("Data Size: %d x %d" % [height, width])
    _set_status("Loading Data with Size: %d x %d" % [height, width])
    for i in range(height):
        for j in range(width):
            #m_logger.debug("Data[%d][%d] = %d" % [i, j, m_data[i][j]])
            var cell = Button.new()
            if m_data[i][j] is float:
                cell.text = String.num(m_data[i][j], 2)
            else:
                cell.text = str(m_data[i][j])

            cell.text = str(m_data[i][j])
            cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
            m_grid_view.add_child(cell)
            cell.pressed.connect(func() -> void:
                emit_signal("cell_selected", i, j)
            )
            # Send a signal when the user scrolls up and down on the mouse when hovering over the cell
            cell.gui_input.connect(func(event:InputEvent) -> void:
                if event is InputEventMouseButton and not m_flag_input_handled:
                    if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                        emit_signal("cell_hover_up", i, j)
                    elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                        emit_signal("cell_hover_down", i, j)
                    m_flag_input_handled = true
            )
    m_flag_loading_finished = true


func _ready_to_parse_data() -> bool:
    return (len(m_data) > 0) and (m_grid_view != null)

func _set_status(status: String) -> void:
    m_status.text = status


##############################################################################
# Signal Handlers
##############################################################################

func _ready() -> void:
    m_logger.debug("Delayed Ready Entered!")
    m_refresh_button.pressed.connect(func() -> void:
        m_flag_refresh = true
    )
    _set_status("Ready")
    m_table_name_label.text = m_table_name
    m_flag_initialized = true



#func _delayed_ready() -> void:
#    if m_refresh_button == null:
#        return
#    if m_table_name_label == null:
#        return
#    if m_status == null:
#        return
#    if m_grid_view == null:
#        return


func _process(_delta: float) -> void:
    m_flag_input_handled = false
    match m_state:
        STATES_T.STATE_RESET:
            if m_flag_initialized:
                m_flag_initialized = false
                m_logger.debug("Reset State! return to IDLE")
                m_state = STATES_T.STATE_IDLE
            #else:
            #    _delayed_ready()
        STATES_T.STATE_IDLE:
            if _ready_to_parse_data():
                m_logger.debug("Ready to parse data!")
                _set_status("Loading...")
                _start_parse_data()
                m_state = STATES_T.STATE_LOADING
            if m_flag_refresh:
                m_flag_refresh = false
                _set_status("No data to refresh!")
        STATES_T.STATE_LOADING:
            if m_flag_loading_finished:
                _set_status("Finished Loading")
                m_state = STATES_T.STATE_READY
            if m_flag_data_parse_error:
                _set_status("Error Loading Data")
                m_state = STATES_T.STATE_ERROR
        STATES_T.STATE_READY:
            if m_flag_refresh:
                m_flag_refresh = false
                if _ready_to_parse_data():
                    m_logger.debug("Ready to parse data!")
                    _set_status("Loading...")
                    _start_parse_data()
                    m_state = STATES_T.STATE_LOADING
                else:
                    _set_status("No data to refresh!")

        STATES_T.STATE_ERROR:
            m_logger.error("Error State! return to IDLE")
            m_state = STATES_T.STATE_IDLE
