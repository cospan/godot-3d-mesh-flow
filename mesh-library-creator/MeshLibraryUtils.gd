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
var m_logger = LogStream.new("MeshLibraryUtils", LogStream.LogLevel.DEBUG)
var m_created_project_path = null


var scene = preload("res://mesh-library-creator/MeshLibraryControl.tscn")
var icon = preload("res://assets/icons/library.png")

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func create():
    m_created_project_path = null
    m_logger.debug("Find a directory to create a new library")
    var folder_dialog = $FileDialogNewLibraryFolder
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

    var mlc = scene.instantiate()
    mlc.init(_path)
    return mlc

func is_type(_path:String):
    var d = DirAccess.open(_path)
    if not d.dir_exists(_path):
        return false
    var lib_folder = _path + "/.library"
    if not d.dir_exists(lib_folder):
        return false
    var lib_info_file = lib_folder + "/library.cfg"
    if not d.file_exists(lib_info_file):
        return false
    return true

func get_icon():
    return icon.duplicate()

func get_project_dict(_path:String):
    var project_dict = {}
    # Open up the config file within the .library folder and populate the project_dict
    var config = ConfigFile.new()
    var lib_folder = _path + "/.library"
    var lib_info_file = lib_folder + "/library.cfg"
    var err = config.load(lib_info_file)
    if err != OK:
        m_logger.error("Failed to load library config file: %s" % lib_info_file)
        return project_dict

    project_dict["name"] = config.get_value("config", "name")
    project_dict["type"] = config.get_value("config", "type")
    project_dict["version"] = config.get_value("config", "version")
    project_dict["description"] = config.get_value("config", "description")
    project_dict["author"] = config.get_value("config", "author")
    project_dict["created"] = config.get_value("config", "created")
    project_dict["modified"] = config.get_value("config", "modified")
    project_dict["auto_laod"] = config.get_value("config", "auto_load")
    project_dict["reset_library"] = config.get_value("config", "reset_library")
    project_dict["path"] = _path
    return project_dict


func delete(_path:String):
    var d = DirAccess.open(_path)
    if not d.dir_exists(_path):
        m_logger.error("Project directory does not exist: %s" % _path)
        return false
    var lib_folder = _path + "/.library"
    if not d.dir_exists(lib_folder):
        m_logger.error("Library folder does not exist: %s" % lib_folder)
        return false
    var err = d.remove_dir(lib_folder)
    if err != OK:
        m_logger.error("Failed to remove library folder: %s" % lib_folder)
        return false
    return true

func reset(_path:String):
    m_logger.debug("Resetting library: %s" % _path)
    delete(_path)
    _create(_path)


func get_preview(_path:String):
    var d = DirAccess.open(_path)
    if not d.dir_exists(_path):
        m_logger.warn("Project directory does not exist: %s" % _path)
        return null
    var lib_folder = _path + "/.library"
    if not d.dir_exists(lib_folder):
        m_logger.warn("Library folder does not exist: %s" % lib_folder)
        return null
    var preview_file = lib_folder + "/preview.png"
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
    var menu_item_dict = {"Clear Database":on_clear_database}
    pass

##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    # Connect FileDialog signals
    var new_lib_folder_dialog = $FileDialogNewLibraryFolder
    new_lib_folder_dialog.confirmed.connect(_on_file_dialog_new_library_folder_confirm)
    new_lib_folder_dialog.canceled.connect(_on_file_dialog_new_library_folder_canceled)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass


##############################################################################
# Signal Handlers
##############################################################################
func _on_file_dialog_new_library_folder_confirm():
    m_logger.debug("New library folder selected")

    var folder_dialog = $FileDialogNewLibraryFolder
    var folder_path = folder_dialog.current_path
    # Check if there exists a folder called '.library' within the selected folder 'folder_path'
    var lib_folder = folder_path + "/.library"
    m_logger.debug("Library folder: %s" % lib_folder)
    var d = DirAccess.open(folder_path)
    if d.dir_exists(lib_folder):
        m_logger.info("Library folder already exists!")
        # Ask the user if they want to overwrite the existing library
        var dialog = $ConfirmDialogAsync
        dialog.show()
        await dialog.finished
        if dialog.result():
            m_logger.info("Overwriting library folder")
        else:
            m_logger.info("Not overwriting library folder, cancelling")
            return
    else:
        m_logger.debug("Creating library folder")
        var err = d.make_dir(lib_folder)
        if err != OK:
            m_logger.error("Failed to create library folder: %s" % lib_folder)
            return
        m_logger.debug("Library folder created: %s" % lib_folder)

        # Create a configuration file for the library

    _create(folder_path)


func _create(_path):

    # Within this directory create a 'config' file that will contain the library information
    var lib_info_file = _path + "/.library/library.cfg"


    # Get the name of the folder that was selected as the proposed name of the library
    var parts = _path.split("/")
    var lib_name = ""
    # iterate through 'parts' from the end, find the first non-empty string
    for i in range(parts.size() - 1, 0, -1):
        if parts[i] != "":
            lib_name = parts[i]
            break

    m_logger.debug("Library Name: %s" % lib_name)
    var datetime = Time.get_datetime_dict_from_system()
    var formatted_datetime = "%s-%s-%s %s:%s:%s" % [datetime["year"], datetime["month"], datetime["day"], datetime["hour"], datetime["minute"], datetime["second"]]

    var config = ConfigFile.new()
    config.set_value("config", "name", lib_name)
    config.set_value("config", "type", "mesh-library")
    config.set_value("config", "version", "1.0")
    config.set_value("config", "description", "A library of mesh assets")
    config.set_value("config", "author", "Author")
    config.set_value("config", "created", formatted_datetime)
    config.set_value("config", "modified", formatted_datetime)
    config.set_value("config", "auto_load", true)
    config.set_value("config", "reset_library", false)
    config.save(lib_info_file)

    m_created_project_path = _path
    emit_signal("create_finished")

func _on_file_dialog_new_library_folder_canceled():
    m_logger.debug("New library folder selection canceled")
    m_created_project_path = null
    emit_signal("create_finished")

func on_clear_database(_project_dict):
    pass

