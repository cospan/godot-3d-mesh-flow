extends CanvasLayer

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Help Overlay", LogStream.LogLevel.DEBUG)

## Flags ##

##############################################################################
# Scenes
##############################################################################
var m_tree = null
var m_tree_root = null

##############################################################################
# Exports
##############################################################################
@export var default_keyboard_shortcuts:Array = [
    {"key":"F1", "description":"Toggle Help Overlay"},
    {"key":"F2", "description":"Toggle Debug Overlay"},
    {"key":"F3", "description":"Toggle Performance Overlay"},
    {"key":"F4", "description":"Toggle Console Overlay"},
    {"key":"F5", "description":"Toggle Fullscreen"},
    {"key":"F6", "description":"Toggle Wireframe"},
    {"key":"F7", "description":"Toggle Debug Shapes"},
    {"key":"F8", "description":"Toggle Debug Physics"},
    {"key":"F9", "description":"Toggle Debug Navigation"},
    {"key":"F10", "description":"Toggle Debug AI"},
    {"key":"F11", "description":"Toggle Debug Profiler"},
    {"key":"F12", "description":"Toggle Debug Network"},
]

##############################################################################
# Public Functions
##############################################################################

func add_keyboard_shortcut(_key:String, _description:String):
    var child1 = m_tree.create_item(m_tree_root)
    child1.set_text(0, _description)
    child1.set_text(1, _key)

##############################################################################
# Private Functions
##############################################################################

##############################################################################
# Signal Handlers
##############################################################################

func _ready():
    m_logger.debug("Ready Entered!")
    m_tree = $Tree
    m_tree_root = m_tree.create_item()
    m_tree.set_column_expand(0, true)
    m_tree.set_column_expand(1, true)
    m_tree.hide_root = true

    for shortcut in default_keyboard_shortcuts:
        add_keyboard_shortcut(shortcut["key"], shortcut["description"])

func _process(_delta):
    pass
