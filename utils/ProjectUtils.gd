extends Node

class_name ProjectUtils
##############################################################################
# Signals
##############################################################################

signal finished
signal create_finished


##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("ProjectUtils", LogStream.LogLevel.INFO)
var m_created_project_path = null

var m_folder_name = ""
var m_config_file = ""

#var m_project_scene = null

#######################################
# Scenes
#######################################

##############################################################################
# Exports
##############################################################################
@export var    PROJECT_SCENE:PackedScene
@export var    PROJECT_TYPE:String = ""
@export var    ICON:CompressedTexture2D
@export var    CUSTOM_CONFIG_KEYS:Dictionary

##############################################################################
# Subclass Functions: These functions should be overridden by subclasses
##############################################################################


func _create_stub(_path:String) -> bool:
    return true

func _open_stub(_path:String) -> bool:
    # Set return to true to indicate that the project should be opened
    return false


##############################################################################
# Public Functions
##############################################################################

func create():
    m_created_project_path = null
    m_logger.debug("Find a directory to create a new project")
    var folder_dialog = $FileDialogNewFolder
    folder_dialog.show()
    await create_finished
    return m_created_project_path

func open(_path:String):
    # Return a instantiated scene
    m_logger.debug("Initializing Project Directory: %s" % _path)
    var d = DirAccess.open(_path)
    if not d.dir_exists(_path):
      m_logger.error("Project directory does not exist: %s" % _path)
      return null

    #var mlc = m_project_scene.instantiate()
    var mlc = PROJECT_SCENE.instantiate()
    mlc.init(_path)
    return mlc

func is_type(_path:String):
    var base_path = _get_base_path(_path)
    var d = DirAccess.open(base_path)
    if not d.dir_exists(_path):
        return false
    var proj_info_file = _path + "/" + m_config_file
    if not d.file_exists(proj_info_file):
        return false
    return true

func get_icon():
    return ICON

func get_project_dict(_path:String):
    var project_dict = {}
    # Open up the config file within the project folder and populate the project_dict
    var config = ConfigFile.new()
    var proj_info_file = _path + "/" + m_config_file
    var err = config.load(proj_info_file)
    if err != OK:
        m_logger.error("Failed to load the project config file: %s" % proj_info_file)
        return project_dict

    project_dict["name"] = config.get_value("config", "name")
    project_dict["type"] = config.get_value("config", "type")
    project_dict["version"] = config.get_value("config", "version")
    project_dict["description"] = config.get_value("config", "description")
    project_dict["author"] = config.get_value("config", "author")
    project_dict["created"] = config.get_value("config", "created")
    project_dict["modified"] = config.get_value("config", "modified")
    #project_dict["auto_laod"] = config.get_value("config", "auto_load")
    #project_dict["reset_project"] = config.get_value("config", "reset_project")
    project_dict["base_path"] = config.get_value("config", "base_path")
    project_dict["path"] = _path
    return project_dict


func delete(_path:String):
    var base_path = _get_base_path(_path)
    var d = DirAccess.open(base_path)
    if not d.dir_exists(_path):
        m_logger.error("Project folder does not exist: %s" % _path)
        return false
    var err = d.remove(_path)
    if err != OK:
        m_logger.error("Failed to remove project folder: %s" % _path)
        return false
    return true

func reset(_path:String):
    m_logger.debug("Resetting project: %s" % _path)
    delete(_path)
    _create(_path)


func get_preview(_path:String):
    var base_path = _get_base_path(_path)
    var d = DirAccess.open(base_path)
    if not d.dir_exists(_path):
        m_logger.warn("Library folder does not exist: %s" % _path)
        return null
    var preview_file = _path + "/preview.png"
    if not d.file_exists(preview_file):
        m_logger.warn("Preview file does not exist: %s" % preview_file)
        return null
    var image = Image.new()
    var err = image.load(preview_file)
    if err != OK:
        m_logger.error("Failed to load preview image: %s" % preview_file)
        return null
    return image

func get_menu_items_dict():
    #var menu_item_dict = {"Clear Database":on_clear_database}
        pass

##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_folder_name = "." + PROJECT_TYPE
    m_config_file = PROJECT_TYPE + ".cfg"

    #m_logger.debug("Loading Project Scene: %s" % PROJECT_SCENE)
    #m_project_scene = load(PROJECT_SCENE)

    # Connect FileDialog signals
    var new_folder_dialog = $FileDialogNewFolder
    new_folder_dialog.confirmed.connect(_on_file_dialog_new_folder_confirm)
    new_folder_dialog.canceled.connect(_on_file_dialog_new_folder_canceled)


##############################################################################
# Signal Handlers
##############################################################################
func _on_file_dialog_new_folder_confirm():
    m_logger.debug("New project folder selected")

    var folder_dialog = $FileDialogNewFolder
    var folder_path = folder_dialog.current_path
    # Check if there exists a folder called '.project' within the selected folder 'folder_path'
    var proj_folder = folder_path + "/" + m_folder_name
    m_logger.debug("Project folder: %s" % proj_folder)
    var d = DirAccess.open(folder_path)
    if d.dir_exists(proj_folder):
        m_logger.info("Library folder already exists!")
        # Ask the user if they want to overwrite the existing project
        var dialog = $ConfirmDialogAsync
        dialog.show()
        await dialog.finished
        if dialog.result():
            m_logger.info("Overwriting project folder")
        else:
            m_logger.info("Not overwriting project folder, cancelling")
            return
    else:
        m_logger.debug("Creating project folder")
        var err = d.make_dir(proj_folder)
        if err != OK:
            m_logger.error("Failed to create project folder: %s" % proj_folder)
            return
        m_logger.debug("Library folder created: %s" % proj_folder)

        # Create a configuration file for the project

    _create(folder_path)


func _create(_folder_path):

    # Within this directory create a 'config' file that will contain the project information
    var _path = _folder_path + m_folder_name

    # Get the name of the folder that was selected as the proposed name of the project
    var proj_info_file = _path + "/" + m_config_file

    var parts = _folder_path.split("/")
    var proj_name = ""
    # iterate through 'parts' from the end, find the first non-empty string
    for i in range(parts.size() - 1, 0, -1):
        if parts[i] != "":
            proj_name = parts[i]
            break

    var base_path = _get_base_path(_path)

    m_logger.debug("Project Name: %s" % proj_name)
    var datetime = Time.get_datetime_dict_from_system()
    var formatted_datetime = "%s-%s-%s %s:%s:%s" % [datetime["year"], datetime["month"], datetime["day"], datetime["hour"], datetime["minute"], datetime["second"]]

    var config = ConfigFile.new()
    config.set_value("config", "name", proj_name)
    config.set_value("config", "type", PROJECT_TYPE)
    config.set_value("config", "version", "1.0")
    config.set_value("config", "description", "A project of mesh assets")
    config.set_value("config", "author", "Author")
    config.set_value("config", "created", formatted_datetime)
    config.set_value("config", "modified", formatted_datetime)
    config.set_value("config", "base_path", base_path)
    config.set_value("config", "path", _path)
    for key in CUSTOM_CONFIG_KEYS.keys():
            config.set_value("config", key, CUSTOM_CONFIG_KEYS[key])
    config.save(proj_info_file)

    m_created_project_path = _path
    emit_signal("create_finished")

func _get_base_path(_path:String):
    var parts = _path.split("/")
    parts.remove_at(parts.size() - 1)
    #parts.remove_at(- 1)
    return "/".join(parts)

func _on_file_dialog_new_folder_canceled():
    m_logger.debug("New project folder selection canceled")
    m_created_project_path = null
    emit_signal("create_finished")

func on_clear_database(_project_dict):
    pass

