extends Control

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

enum STATE_T {
  RESET,
  LOADING_CONFIG,
  IDLE,
  ERROR_STATE,
}



##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Main", LogStream.LogLevel.INFO)
var m_config = null
var m_tab_container = null
var m_landing_page_index = -1

var m_library_project_configs = []

@onready var m_project_types = {
        "MeshLibrary": $MeshLibraryUtils,
        "Map": null,
}


var m_state = STATE_T.IDLE

##############################################################################
# Exports
##############################################################################
@export_dir var CONFIG_FILE_DIR:String = "user://godot-3d-mesh-flow.cfg"
@export var CLEAR_CONFIG:bool = true
@export var DEBUG:bool = true
@export var MAX_RECENT_PROJECTS:int = 10

##############################################################################
# Public Functions
##############################################################################


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():

    m_tab_container = $VBoxMain/TabContainer

    var landing_page = $VBoxMain/TabContainer/HBoxLandingPage
    m_landing_page_index = m_tab_container.get_tab_idx_from_control(landing_page)
    m_tab_container.set_tab_title(m_landing_page_index, "Landing Page")

    # Connecto Signals
    var home_button = $VBoxMain/HBoxContainer/TextureButtonHome
    home_button.pressed.connect(_on_home_pressed)

    var new_library_button = $VBoxMain/HBoxContainer/TextureButtonNewLibrary
    new_library_button.pressed.connect(_on_add_new_mesh_library_pressed)

    var new_map_button = $VBoxMain/HBoxContainer/TextureButtonNewMap
    new_map_button.pressed.connect(_on_new_map_pressed)

    var log_button = $VBoxMain/HBoxContainer/TextureButtonLog
    log_button.pressed.connect(_on_log_button_pressed)

    var file_button = $VBoxMain/MainMenu/HBoxContainer/File
    var file_menu = file_button.get_popup()
    file_menu.id_pressed.connect(_file_menu_item_pressed)

    var help_button = $VBoxMain/MainMenu/HBoxContainer/Help
    var help_menu = help_button.get_popup()
    help_menu.id_pressed.connect(_help_menu_item_pressed)


    var new_map_folder_dialog = $FileDialogNewMapFolder
    new_map_folder_dialog.confirmed.connect(_on_file_dialog_new_map_folder_confirm)

    m_tab_container = $VBoxMain/TabContainer

    m_config = ConfigFile.new()
    if CLEAR_CONFIG:
        _initialize_config_file()
    m_state = STATE_T.RESET


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    match m_state:
        STATE_T.RESET:
            if DEBUG:
                m_logger.current_log_level = LogStream.LogLevel.DEBUG
            m_state = STATE_T.LOADING_CONFIG
            m_logger.debug("RESET -> LOADING_CONFIG")
        STATE_T.LOADING_CONFIG:
            var err = m_config.load(CONFIG_FILE_DIR)
            if err != OK:
                _initialize_config_file()
                m_logger.debug("Failed to load config file: %s" % CONFIG_FILE_DIR)
                m_logger.warn("LOADING_CONFIG -> ERROR_STATE")
                m_state = STATE_T.ERROR_STATE
            else:
                m_logger.debug("Config file loaded: %s" % CONFIG_FILE_DIR)
                m_logger.debug("LOADING_CONFIG -> IDLE")
                m_state = STATE_T.IDLE
        STATE_T.IDLE:
            pass
        STATE_T.ERROR_STATE:
            m_logger.warn("ERROR_STATE -> IDLE")
            m_state = STATE_T.IDLE
        _:
            pass

func _initialize_config_file():
    m_logger.debug("Initializing config file: %s" % CONFIG_FILE_DIR)
    m_config.set_value("config", "project_path", [])
    m_config.save(CONFIG_FILE_DIR)

func _insert_recent_project(project_path):
        var recent_projects = m_config.get_value("config", "project_path")
        if recent_projects.size() >= MAX_RECENT_PROJECTS:
                recent_projects.pop_back()
        recent_projects.insert(0, project_path)
        m_config.set_value("config", "project_path", recent_projects)
        m_config.save(CONFIG_FILE_DIR)
        _update_project_list()

func _update_project_list():
        var recent_projects = m_config.get_value("config", "project_path")
        var project_list = $VBoxMain/TabContainer/HBoxLandingPage/VBoxProject/ProjectList
        project_list.clear()
        for project_path in recent_projects:
                project_list.add_item(project_path)


##############################################################################
# Signal Handlers
##############################################################################
func _on_home_pressed():
    m_logger.debug("Home button pressed")
    m_tab_container.current_tab = m_landing_page_index

func _on_add_new_mesh_library_pressed():
    m_logger.debug("Add new mesh library")
    var mlu = $MeshLibraryUtils
    var project_path = await mlu.create()
    if project_path == null:
        m_logger.info("MeshLibraryUtils.create() failed")
        return

    m_logger.debug("MeshLibraryUtils.create() success: %s" % project_path)
        # Insert the path to the recent project list


func _on_new_map_pressed():
    m_logger.debug("New map")
    # Create a new map
    # Use a dialog to select a directory
    var folder_dialog = $FileDialogNewMapFolder
    folder_dialog.show()

func _on_file_dialog_new_map_folder_confirm():
    m_logger.debug("New map folder selected")
    var folder_dialog = $FileDialogNewMapFolder
    var folder_path = folder_dialog.current_path
    m_logger.debug("Selected folder: %s" % folder_path)
    # Create a hidden subdirectory called '.map' to store the map files

func _on_log_button_pressed():
    m_logger.debug("Status log button pressed")
    var status_log = $VBoxMain/TeLogger
    status_log.visible = not status_log.visible

func _file_menu_item_pressed(_id):
    var file_button = $VBoxMain/MainMenu/HBoxContainer/File
    var file_menu = file_button.get_popup()
    var index = file_menu.get_item_index(_id)
    var _name = file_menu.get_item_text(index)
    match(_name.to_lower()):
        "exit":
            m_logger.debug("File -> Quit")
            get_tree().quit()
        _:
            m_logger.error("Unknown file menu item: %d", _id)

func _help_menu_item_pressed(_id):
    var help_button = $VBoxMain/MainMenu/HBoxContainer/Help
    var help_menu = help_button.get_popup()
    var index = help_menu.get_item_index(_id)
    var _name = help_menu.get_item_text(index)
    match(_name.to_lower()):
        "debug":
            help_menu.set_item_checked(index, not help_menu.is_item_checked(index))
            m_logger.debug("Help -> Debug")
            if help_menu.is_item_checked(index):
                m_logger.current_log_level = LogStream.LogLevel.DEBUG
            else:
                m_logger.current_log_level = LogStream.LogLevel.INFO
        "about":
            m_logger.debug("Help -> About")
        _:
            m_logger.error("Unknown help menu item: %d", _id)


