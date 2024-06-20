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
var m_logger = LogStream.new("Main", LogStream.LogLevel.DEBUG)
var m_config = null
var m_tab_container = null
var m_landing_page

var m_library_project_configs = []
var m_project_selected:int = -1

@onready var m_project_types = {
        "mesh-library": $MeshLibraryUtils,
        "map": $MapUtils
}


var m_state = STATE_T.IDLE

##############################################################################
# Exports
##############################################################################
@export_dir var CONFIG_FILE_DIR:String = "user://godot-3d-mesh-flow.cfg"
@export var CLEAR_CONFIG:bool = false
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

    m_tab_container = $VBoxMain/TabControl

    m_landing_page = $VBoxMain/TabControl/HBoxLandingPage
    var landing_page_index = m_tab_container.get_tab_idx_from_control(m_landing_page)
    m_tab_container.set_tab_title(landing_page_index, "Landing Page")
    m_tab_container.tab_selected.connect(_tab_selected)

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

    var project_item_menu = $PopupMenuItemActivate
    project_item_menu.index_pressed.connect(_project_item_menu_pressed)


    m_tab_container = $VBoxMain/TabControl

    var project_list = $VBoxMain/TabControl/HBoxLandingPage/VBoxProject/ProjectList
    project_list.empty_clicked.connect(_project_item_empty_selected) # For Clearing the preview
    project_list.item_selected.connect(_project_item_menu_selected)   # For Updating the Preview
    project_list.item_clicked.connect(_project_item_menu_clicked)     # For Opening the menu
    project_list.item_activated.connect(_project_item_menu_activated) # For Opening the project


    var tb = m_tab_container.get_tab_bar()
    tb.tab_close_pressed.connect(_on_tab_close_pressed)

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
                _update_project_list()
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
        m_logger.debug("Inserting project: %s" % project_path)
        m_logger.debug("Recent projects (Before Insert): %s" % str(recent_projects))
        if recent_projects.size() >= MAX_RECENT_PROJECTS:
            recent_projects.pop_back()
        recent_projects.insert(0, project_path)
        m_logger.debug("Recent projects (After Insert): %s" % str(recent_projects))
        m_config.set_value("config", "project_path", recent_projects)
        m_config.save(CONFIG_FILE_DIR)
        _update_project_list()

func _update_project_list():
        var project_path_list = []
        var recent_projects = m_config.get_value("config", "project_path")
        # Validate the recent projects do exist and they are not duplicates
        for project_path in recent_projects:
            if project_path not in project_path_list:
                project_path_list.append(project_path)
                continue

        m_config.set_value("config", "project_path", project_path_list)
        recent_projects = m_config.get_value("config", "project_path")
        var project_list = $VBoxMain/TabControl/HBoxLandingPage/VBoxProject/ProjectList
        project_list.clear()
        for project_path in recent_projects:
            m_logger.debug("Adding project: %s" % project_path)
            # Go through the project types and see if we can find a match
            var found = false
            var project_dict = {}
            var icon = null
            for project_type in m_project_types.keys():
                var project = m_project_types[project_type]
                if project.is_type(project_path):
                    icon = project.get_icon()
                    project_dict = project.get_project_dict(project_path)
                    found = true
                    break

            #project_list.add_item(project_path)
            if not found:
                m_logger.warn("Unknown project type: %s" % project_path)
                continue

            var index = project_list.add_item(project_dict["name"], icon, true)
            project_list.set_item_metadata(index, project_dict)
            project_list.set_item_tooltip(index, project_dict["description"])


func _open_project(project_dict):
    var project_type = project_dict["type"]
    var project = m_project_types[project_type]
    # Check if project is already open
    for i in range(m_tab_container.get_tab_count()):
        var c = m_tab_container.get_child(i)
        if c == $VBoxMain/TabControl/HBoxLandingPage:
            # Skip the landing page
            continue
        if c.get_project_path() == project_dict["path"]:
            m_tab_container.current_tab = i
            return

    # Open the project
    var control = project.open(project_dict["path"])
    if control != null:
        m_tab_container.add_child(control)
        m_tab_container.current_tab = m_tab_container.get_tab_count() - 1

func _close_project(project_path:String):
    for i in range(m_tab_container.get_tab_count()):
        var control = m_tab_container.get_child(i)
        if control.get_project_path() == project_path:
            m_tab_container.remove_child(control)
            return

func _update_project_preview(_project_index):
    var project_list = $VBoxMain/TabControl/HBoxLandingPage/VBoxProject/ProjectList
    var project_dict = project_list.get_item_metadata(_project_index)
    var project_type = project_dict["type"]
    var project = m_project_types[project_type]
    var preview = project.get_preview(project_dict["path"])
    if preview == null:
        m_logger.warn("Failed to get preview for project: %s" % project_dict["path"])
        return
    var preview_container = $VBoxMain/TabControl/HBoxLandingPage/VBoxProject/Preview
    preview_container.add_child(preview)

##############################################################################
# Signal Handlers
##############################################################################
func _on_home_pressed():
    m_logger.debug("Home button pressed")
    var landing_page_index = m_tab_container.get_tab_idx_from_control(m_landing_page)
    m_tab_container.current_tab = landing_page_index

func _on_add_new_mesh_library_pressed():
    m_logger.debug("Add new mesh library")
    var mlu = $MeshLibraryUtils
    var project_path = await mlu.create()
    if project_path == null:
        m_logger.info("MeshLibraryUtils.create() failed")
        return

    m_logger.debug("MeshLibraryUtils.create() success: %s" % project_path)
    # Insert the path to the recent project list
    _insert_recent_project(project_path)


func _on_new_map_pressed():
    m_logger.debug("New map")
    # Create a new map
    # Use a dialog to select a directory
    var mu = $MapUtils
    var project_path = await mu.create()
    if project_path == null:
        m_logger.info("MapUtils.create() failed")
        return

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


func _project_item_menu_pressed(_index):
    var project_item_menu = $PopupMenuItemActivate
    var project_list = $VBoxMain/TabControl/HBoxLandingPage/VBoxProject/ProjectList
    var project_dict = project_list.get_item_metadata(m_project_selected)
    #var project_type = project_dict["type"]
    #var project = m_project_types[project_type]
    var text = project_item_menu.get_item_text(_index)
    match text.to_lower():
        "open":
            m_logger.debug("Open project: %s" % project_dict["path"])
            _open_project(project_dict)
        "delete":
            m_logger.debug("Delete project: %s" % project_dict["path"])
            #project.delete(project_dict["path"])
            _update_project_list()
        "reset":
            m_logger.debug("Reset project: %s" % project_dict["path"])
            #project.reset(project_dict["path"])
            _update_project_list()
    #   _:
    #       # Check for custom items
    #       var menu_items_dict = project.get_menu_items_dict()
    #       for mi in menu_items_dict:
    #           if text != mi:
    #               continue
    #           m_logger.debug("Found: %s" % text)

    #           var project_dict = project_list.get_item_metadata(_project_index)
    #           var project_type = project_dict["type"]
    #           var project = m_project_types[project_type]
    #           #var preview = project.get_menu_items(project_dict["path"])
    #           project.menu_items_dict[text](project_dict)
    ## Remove custom Items
    #var menu_items_dict = project.get_menu_items_dict()



func _project_item_menu_selected(_index):
    #var project_item_menu = $PopupMenuItemActive
    #var project_list = $VBoxMain/TabControl/HBoxLandingPage/VBoxProject/ProjectList
    #var project_dict = project_list.get_item_metadata(_index)
    #var project_type = project_dict["type"]
    #var project = m_project_types[project_type]
    m_project_selected = _index
    _update_project_preview(_index)

func _project_item_menu_activated(_index):
    var project_list = $VBoxMain/TabControl/HBoxLandingPage/VBoxProject/ProjectList
    var project_dict = project_list.get_item_metadata(_index)
    _open_project(project_dict)


func _project_item_empty_selected(_pos, _mouse_button_index):
    m_logger.debug("Project item empty selected")
    var project_list = $VBoxMain/TabControl/HBoxLandingPage/VBoxProject/ProjectList
    project_list.deselect_all()
    m_project_selected = -1

func _project_item_menu_clicked(_index, _pos, mouse_button_index):
    m_logger.debug("Project item menu clicked")
    if mouse_button_index == 1:
        return
    elif mouse_button_index == 2:
        m_project_selected = _index
        #var project_list = $VBoxMain/TabControl/HBoxLandingPage/VBoxProject/ProjectList
        var project_item_menu = $PopupMenuItemActivate
        #var project_dict = project_list.get_item_metadata(_index)
        project_item_menu.show()

func _tab_selected(_index):
    var tab_bar = m_tab_container.get_tab_bar()
    var landing_page_index = m_tab_container.get_tab_idx_from_control(m_landing_page)
    if _index == landing_page_index:
        m_logger.debug("Landing Page selected")
        tab_bar.tab_close_display_policy = tab_bar.CLOSE_BUTTON_SHOW_NEVER
    else:
        tab_bar.tab_close_display_policy = tab_bar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY

func _on_tab_close_pressed(_index):
    m_logger.debug("Tab close pressed: %d" % _index)
    var control = m_tab_container.get_tab_control(_index)
    m_tab_container.remove_child(control)
    control.queue_free()
