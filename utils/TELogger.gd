extends Control

class_name TELogger
##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

const UPDATE_INTERVAL = 0.1

#Any logs with three spaces at the beginning will be ignored.
const IGNORE_PREFIX := "   "

##############################################################################
# Members
##############################################################################
var m_console: RichTextLabel
var m_godot_log: FileAccess
var m_log_level: int = 0
var m_text_filter: String = ""

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################



##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():

    var file_logging_enabled = ProjectSettings.get("debug/file_logging/enable_file_logging") or ProjectSettings.get("debug/file_logging/enable_file_logging.pc")
    if !file_logging_enabled:
      push_warning("You have to enable file logging in order to use engine log monitor!")
      return

    var log_path = ProjectSettings.get("debug/file_logging/log_path")
    m_godot_log = FileAccess.open(log_path, FileAccess.READ)

    create_tween().set_loops(
    ).tween_callback(_read_data
    ).set_delay(UPDATE_INTERVAL)

    m_console = $VBox/RTConsole
    m_console.clear()
    var level_sel = $VBox/HBoxControl/OptionButton
    m_log_level = level_sel.selected
    level_sel.item_selected.connect(_on_level_select)
    Log.log_message.connect(_on_new_log_data)

    var log_filter = $VBox/HBoxControl/HBoxFilter/LineEditFilter
    log_filter.text_changed.connect(_on_filter_text_changed)


    #Log.info("Hi")
    #Log.warn("Warning")

func _read_data():
    while m_godot_log.get_position() < m_godot_log.get_length():
        var new_line = m_godot_log.get_line()
        if new_line.begins_with(IGNORE_PREFIX):
            continue

        if len(m_text_filter) > 0 and !new_line.contains(m_text_filter):
            continue

        var nl_array = new_line.split(" ")
        if nl_array.size() == 0:
            continue
        var _start = nl_array[0]

        if _start.contains("FATAL"):
            _on_new_log_data(LogStream.LogLevel.FATAL, new_line)
        elif _start.contains("ERROR"):
            if m_log_level <= LogStream.LogLevel.ERROR:
                _on_new_log_data(LogStream.LogLevel.ERROR, new_line)
        elif _start.contains("WARN"):
            if m_log_level <= LogStream.LogLevel.WARN:
                _on_new_log_data(LogStream.LogLevel.WARN, new_line)
        elif _start.contains("INFO"):
            if m_log_level <= LogStream.LogLevel.INFO:
                _on_new_log_data(LogStream.LogLevel.INFO, new_line)
        elif _start.contains("DEBUG"):
            if m_log_level <= LogStream.LogLevel.DEBUG:
                _on_new_log_data(LogStream.LogLevel.DEBUG, new_line)
        else:
            if m_log_level <= LogStream.LogLevel.INFO:
                _on_new_log_data(LogStream.LogLevel.INFO, new_line)
            #_on_new_log_data(LogStream.LogLevel.INFO, new_line)

func _on_new_log_data(_level, _message):
    match (_level):
        LogStream.LogLevel.DEBUG:
            m_console.push_bgcolor(Color(0, 1, 0, 1)) # Green
            m_console.push_color(Color(0, 0, 0, 1))   # Black
        LogStream.LogLevel.ERROR:
            m_console.push_bgcolor(Color(1, 0, 0, 1)) # Red
            m_console.push_color(Color(0, 0, 0, 1))   # Black
        LogStream.LogLevel.WARN:
            m_console.push_bgcolor(Color(1, 1, 0, 1)) # Yellow
            m_console.push_color(Color(0, 0, 0, 1))   # Black
        LogStream.LogLevel.FATAL:
            m_console.push_bgcolor(Color(1, 0, 0, 1)) # Red
            m_console.push_color(Color(0, 0, 0, 1))   # Black
        _:
            m_console.push_bgcolor(Color(0, 0, 0, 1)) # Black
            m_console.push_color(Color(1, 1, 1, 1))   # White

    m_console.append_text(_message)
    m_console.pop_all()
    m_console.newline()

##############################################################################
# Signal Handler
##############################################################################

func _on_level_select(_index):
    var level_sel = $VBox/HBoxControl/OptionButton
    m_log_level = level_sel.get_item_id(_index)
    #m_log_level = _index
    Log.info("Log Reader level set to: %d " % m_log_level)
    m_console.clear()
    m_godot_log.seek(0)
    call_deferred("_read_data")

func _on_filter_text_changed(_text):
    m_console.clear()
    m_text_filter = _text
    m_godot_log.seek(0)
    call_deferred("_read_data")
