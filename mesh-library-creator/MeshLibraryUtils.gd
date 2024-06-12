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

    var mlc = scene.instance()
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

    # Within this directory create a 'config' file that will contain the library information
    var lib_info_file = lib_folder + "/library.cfg"

    # Get the name of the folder that was selected as the proposed name of the library
    var lib_name = folder_path.get_file().get_basename()
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
    config.save(lib_info_file)

    m_created_project_path = folder_path
    emit_signal("create_finished")

func _on_file_dialog_new_library_folder_canceled():
    m_logger.debug("New library folder selection canceled")
    m_created_project_path = null
    emit_signal("create_finished")

