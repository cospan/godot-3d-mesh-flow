extends Node

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
var m_logger = LogStream.new("MapUtils", LogStream.LogLevel.DEBUG)
var m_created_project_path = null

#######################################
# Scenes
#######################################
var scene = preload("res://map-creator/MapCreatorControl.tscn")
var icon = preload("res://assets/icons/map.png")

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func create():
    m_created_project_path = null
    m_logger.debug("Find a directory to create a new map")
    var folder_dialog = $FileDialogNewMapFolder
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

    var mc = scene.instantiate()
    mc.init(_path)
    return mc


func get_icon():
    return icon.duplicate()

func get_project_dict(_path:String):
    var project_dict = {}
    # Open up the config file within the .map folder and populate the project_dict
    var config = ConfigFile.new()
    var map_folder = _path + "/.map"
    var map_info_file = map_folder + "/map.cfg"
    var err = config.load(map_info_file)
    if err != OK:
        m_logger.error("Failed to load map config file: %s" % map_info_file)
        return project_dict

    project_dict["name"] = config.get_value("config", "name")
    project_dict["type"] = config.get_value("config", "type")
    project_dict["version"] = config.get_value("config", "version")
    project_dict["description"] = config.get_value("config", "description")
    project_dict["author"] = config.get_value("config", "author")
    project_dict["created"] = config.get_value("config", "created")
    project_dict["modified"] = config.get_value("config", "modified")
    project_dict["base_path"] = _path
    project_dict["path"] = map_folder
    return project_dict


func get_preview(_path:String):
    var d = DirAccess.open(_path)
    if not d.dir_exists(_path):
        m_logger.warn("Project directory does not exist: %s" % _path)
        return null
    var map_folder = _path + "/.map"
    if not d.dir_exists(map_folder):
        m_logger.warn("Map folder does not exist: %s" % map_folder)
        return null
    var preview_file = map_folder + "/preview.png"
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
    # Connect FileDialog signals
    var new_map_folder_dialog = $FileDialogNewMapFolder
    new_map_folder_dialog.confirmed.connect(_on_file_dialog_new_map_folder_confirm)
    new_map_folder_dialog.canceled.connect(_on_file_dialog_new_map_folder_canceled)


##############################################################################
# Signal Handlers
##############################################################################
func _on_file_dialog_new_map_folder_confirm():
    m_logger.debug("New map folder selected")

    var folder_dialog = $FileDialogNewMapFolder
    var folder_path = folder_dialog.current_path
    # Check if there exists a folder called '.map' within the selected folder 'folder_path'
    var map_folder = folder_path + "/.map"
    m_logger.debug("Map folder: %s" % map_folder)
    var d = DirAccess.open(folder_path)
    if d.dir_exists(map_folder):
        m_logger.info("Map folder already exists!")
        # Ask the user if they want to overwrite the existing map
        var dialog = $ConfirmDialogAsync
        dialog.show()
        await dialog.finished
        if dialog.result():
            m_logger.info("Overwriting map folder")
        else:
            m_logger.info("Not overwriting map folder, cancelling")
            return
    else:
        m_logger.debug("Creating map folder")
        var err = d.make_dir(map_folder)
        if err != OK:
            m_logger.error("Failed to create map folder: %s" % map_folder)
            return
        m_logger.debug("Map folder created: %s" % map_folder)

        # Create a configuration file for the map

    _create(folder_path)


func _create(_path):

    # Within this directory create a 'config' file that will contain the map information
    var map_info_file = _path + "/.map/map.cfg"


    # Get the name of the folder that was selected as the proposed name of the map
    var parts = _path.split("/")
    var map_name = ""
    # iterate through 'parts' from the end, find the first non-empty string
    for i in range(parts.size() - 1, 0, -1):
        if parts[i] != "":
            map_name = parts[i]
            break

    m_logger.debug("Map Name: %s" % map_name)
    var datetime = Time.get_datetime_dict_from_system()
    var formatted_datetime = "%s-%s-%s %s:%s:%s" % [datetime["year"], datetime["month"], datetime["day"], datetime["hour"], datetime["minute"], datetime["second"]]

    var config = ConfigFile.new()
    config.set_value("config", "name", map_name)
    config.set_value("config", "type", "map")
    config.set_value("config", "version", "1.0")
    config.set_value("config", "description", "A new map created with the Map Creator Tool.")
    config.set_value("config", "author", "Author")
    config.set_value("config", "created", formatted_datetime)
    config.set_value("config", "modified", formatted_datetime)
    config.set_value("config", "auto_load", true)
    config.set_value("config", "reset_map", false)
    config.save(map_info_file)

    m_created_project_path = _path
    emit_signal("create_finished")

func _on_file_dialog_new_map_folder_canceled():
    m_logger.debug("New map folder selection canceled")
    m_created_project_path = null
    emit_signal("create_finished")

func on_clear_database(_project_dict):
    pass

