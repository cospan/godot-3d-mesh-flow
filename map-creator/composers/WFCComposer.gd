extends ComposerBase


##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################
const PROP_GENERATE_TERRAIN = "WFC Composer"

enum STATES_T {
    RESET,
    LOADING,
    READY,
    START_PROCESSING_AREA,
    PROCESSING_AREA,
}
var m_state:STATES_T = STATES_T.RESET

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("WFC Composer", LogStream.LogLevel.DEBUG)
var m_area_polygon_map = {}
var m_area_index = -1
var m_mesh_lib_database_path_temp = ""
var m_mesh_lib_database_path = ""
var m_tile_database_path:String = ""
var m_wfc_pos = Vector2i(0, 0)
var m_wfc_size = Vector2i(10, 10)
var m_wfc_rect = Rect2i(0, 0, 10, 10)

###################
# Flags
###################
var m_flag_ready = false
var m_flag_initialize_library = false
var m_flag_reset_tile_db = false
var m_flag_load_finished = false
var m_flag_new_area_outline = false
var m_flag_start_wfc = false

##############################################################################
# Scenes
##############################################################################
var m_library_db_adapter = null
var m_library_2_tile_converter = null
var m_tile_db_adapter = null
var m_toolbar
var m_mesh_library_dialog = null
@onready var m_text_edit_x_pos = $HBoxToolbar/VBoxPos/HBoxPos/TextEditXPos
@onready var m_text_edit_y_pos = $HBoxToolbar/VBoxPos/HBoxPos/TextEditYPos
@onready var m_text_edit_x_size = $HBoxToolbar/VBoxSize/HBoxSize/TextEditXSize
@onready var m_text_edit_y_size = $HBoxToolbar/VBoxSize/HBoxSize/TextEditYSize
@onready var m_start_button = $HBoxToolbar/VBoxControl/ButtonStart
@onready var m_step_button = $HBoxToolbar/VBoxControl/ButtonStep
@onready var m_wfc_generator = $WFCGenerator
@onready var m_status = $HBoxToolbar/TextEditStatus

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func add_wfc_polygon_area(polygon: Polygon2D, height:float) -> int:
    #XXX: Not Tested Yet
    var keys = m_area_polygon_map.keys()
    keys.sort()
    var index = 0 if len(keys) == 0 else keys[-1] + 1
    m_area_polygon_map[index] = {"polygon": polygon, "height": height, "finished": false}
    m_flag_new_area_outline = true
    return index

func remove_wfc_polygon_area_by_index(index:int) -> void:
    #XXX: Not Tested Yet
    if index in m_area_polygon_map.keys():
        m_area_polygon_map.erase(index)

func get_toolbar():
    m_logger.debug("Get Toolbar Entered!")
    return m_toolbar

func step():
    pass

##############################################################################
# Private Functions
##############################################################################

func _generate_tile_database(_library_db_path:String, _tile_db_path:String, _reset_tile_db:bool):
    m_logger.debug("Converting Library DB to Tile DB")
    m_library_db_adapter.open_database(_library_db_path)
    m_tile_db_adapter.open_database(_tile_db_path, _reset_tile_db, _reset_tile_db)
    m_library_2_tile_converter.process_database(m_library_db_adapter, m_tile_db_adapter)

func _step():
    var status = "Step Start..."
    if m_wfc_generator != null:
        m_wfc_generator.step()
        status = "Step Complete!"
        status += "\nProgress: %f" % m_wfc_generator.get_progress()
    else:
        status = "WFC Generator Not Found!"

    m_status.text = status

##############################################################################
# Signal Handlers
##############################################################################

func _ready():

    super()
    m_logger.debug("Ready Entered!")
    m_library_db_adapter = $ModuleDatabaseAdapter
    m_library_2_tile_converter = $Library2TileConverter
    m_tile_db_adapter = $TileDatabaseAdapter

    #add_to_group("composer")
    #add_to_group("map-creator-properties")

    # Connect Signals
    m_library_2_tile_converter.finished_loading.connect(_loading_finished)

    # We are ready to go
    m_flag_ready = true

    #Set up toolbar
    m_toolbar = $HBoxToolbar
    m_toolbar.add_child(get_remove_button())
    m_toolbar.move_child(get_remove_button(), 0)

    var set_mesh_dir_button = $HBoxToolbar/VBoxMeshLib/ButtonSetMeshLibrary
    set_mesh_dir_button.pressed.connect(_on_button_mesh_library_pressed)

    m_mesh_library_dialog = $MeshLibraryPathDialog
    m_mesh_library_dialog.file_selected.connect(_on_mesh_library_dialog_file_selected)
    m_mesh_library_dialog.confirmed.connect(_on_mesh_library_dialog_file_confirmed)

    m_tile_database_path = m_config.get_value("config", "path") + "/%s.db" % name

    m_start_button.pressed.connect(_on_start_pressed)
    m_wfc_generator.done.connect(_wfc_done)



    if m_config.has_section(name):
        m_mesh_lib_database_path = m_config.get_value(name, "mesh_library_path")
        if m_mesh_lib_database_path != "":
            var mesh_lib_path = $HBoxToolbar/VBoxMeshLib/MeshLibraryPath
            mesh_lib_path.text = m_mesh_lib_database_path
            #Check if the path is valid and is pointing to a database
            if FileAccess.file_exists(m_mesh_lib_database_path):
                m_flag_initialize_library= true
        else:
            m_logger.debug("No Mesh Library Path Set!")

        # Attempt to load position and size
        if m_config.has_section_key(name, "x_pos"):
            m_wfc_pos.x = int(m_config.get_value(name, "x_pos"))
        if m_config.has_section_key(name, "y_pos"):
            m_wfc_pos.y = int(m_config.get_value(name, "y_pos"))
        if m_config.has_section_key(name, "x_size"):
            m_wfc_size.x = int(m_config.get_value(name, "x_size"))
        if m_config.has_section_key(name, "y_size"):
            m_wfc_size.y = int(m_config.get_value(name, "y_size"))

        if m_config.has_section_key(name, "reset_on_start"):
            $HBoxToolbar/GridContainerConfig/EnableResetOnStart.button_pressed = m_config.get_value(name, "reset_on_start")
        if m_config.has_section_key(name, "wfc_step_enable"):
            $HBoxToolbar/GridContainerConfig/EnableWFCStep.button_pressed = m_config.get_value(name, "wfc_step_enable")


    m_text_edit_x_pos.text = str(m_wfc_pos.x)
    m_text_edit_y_pos.text = str(m_wfc_pos.y)
    m_text_edit_x_size.text = str(m_wfc_size.x)
    m_text_edit_y_size.text = str(m_wfc_size.y)
    m_wfc_rect = Rect2i(m_wfc_pos, m_wfc_size)

    # Create a lambda for each of the above text boxes that will pass in the text box and the member
    # variable to set the value of the member variable when the text box changes
    m_text_edit_x_pos.text_changed.connect(func(text):
        _on_pos_size_changed("x_pos", text))
    m_text_edit_y_pos.text_changed.connect(func(text):
        _on_pos_size_changed("y_pos", text))
    m_text_edit_x_size.text_changed.connect(func(text):
        _on_pos_size_changed("x_size", text))
    m_text_edit_y_size.text_changed.connect(func(text):
        _on_pos_size_changed("y_size", text))


    # Get references to configuration checkbuttons
    var reset_on_start = $HBoxToolbar/GridContainerConfig/EnableResetOnStart
    var wfc_step_enable = $HBoxToolbar/GridContainerConfig/EnableWFCStep
    reset_on_start.toggled.connect(func(value):
        m_config.set_value(name, "reset_on_start", value)
        m_config.save(m_config.get_value("config", "config_path"))
        )
    wfc_step_enable.toggled.connect(func(value):
        m_config.set_value(name, "wfc_step_enable", value)
        m_config.save(m_config.get_value("config", "config_path"))
        m_wfc_generator.set_step_enable(value)
        )

    m_step_button.pressed.connect(func():
        _step()
        )

    # Set the WFC Generator's Map Adapter
    m_wfc_generator.set_subcomposer_id(name)
    m_wfc_generator.set_layer_and_mask(mesh_layer, mesh_mask)
    m_wfc_generator.m_map_db_adapter = m_map_db_adapter

    remove_child(m_toolbar)


func _process(_delta):
    match m_state:
        STATES_T.RESET:
            if m_flag_initialize_library and enabled and m_flag_ready:
                m_flag_initialize_library = false
                m_flag_ready = false
                _generate_tile_database(m_mesh_lib_database_path, m_tile_database_path, m_flag_reset_tile_db)
                m_state = STATES_T.LOADING
        STATES_T.LOADING:
            if m_flag_load_finished:
                m_logger.debug("Loading Finished!")
                m_flag_load_finished = false
                # If we reload the library, we also want to kick off the tile builder
                for index in m_area_polygon_map.keys():
                    m_area_polygon_map[index]["finished"] = false
                m_flag_new_area_outline = true
                m_wfc_generator.m_tile_db_adapter = m_tile_db_adapter
                m_state = STATES_T.READY
        STATES_T.READY:
            if m_flag_start_wfc:
                m_logger.debug("Validating WFC!")
                m_flag_start_wfc = false
                var mesh_dict = m_tile_db_adapter.get_module_dict()
                for key in mesh_dict.keys():
                    m_logger.debug("Insert: %s" % key)
                    m_map_db_adapter.insert_mesh(key, mesh_dict[key]["mesh"], mesh_dict[key]["transform"])
                if m_wfc_generator.validate_inputs():
                    var status = "Inputs Valid, Starting WFC!"
                    m_logger.debug("Starting WFC Generator!")
                    if m_config.get_value(name, "reset_on_start"):
                        status += "\nResetting WFC Map..."
                        m_wfc_generator.reset()
                        m_map_db_adapter.remove_all_composer_modules(name)
                    m_status.text = status
                    m_wfc_generator.start()
                    m_state = STATES_T.START_PROCESSING_AREA
                else:
                    m_logger.error("Invalid WFC Inputs: %s %s %s" % [str(m_wfc_generator.m_tile_db_adapter), str(m_wfc_generator.m_map_db_adapter), str(m_wfc_generator.rect)])
            if not enabled:
                m_state = STATES_T.RESET
            #if m_flag_new_area_outline:
            #    m_state = STATES_T.START_PROCESSING_AREA
        STATES_T.START_PROCESSING_AREA:
            m_logger.debug("Start Processing Area!")
            m_flag_new_area_outline = false
            m_state = STATES_T.PROCESSING_AREA
            #for index in m_area_polygon_map.keys():
            #    if not m_area_polygon_map[index]["finished"]:
            #        m_flag_new_area_outline = true
            #        var _polygon = m_area_polygon_map[index]["polygon"]
            #        var _height = m_area_polygon_map[index]["height"]
            #        #XXX: Add Polygon to WFC
            #        m_area_polygon_map[index]["finished"] = true
        STATES_T.PROCESSING_AREA:
            #step()
            pass


func _on_property_changed(property_name, property_value):
    #m_logger.debug("Property Changed For %s: %s = %s" % [name, property_name, property_value])
    match property_name:
        PROP_ENABLE:
            enabled = property_value
            #if not enabled:
            #    if m_map_db_adapter != null:
            #        _remove_all_meshes()

func _loading_finished():
    m_flag_load_finished = true

func _on_button_mesh_library_pressed():
    m_logger.debug("Button Mesh Library Pressed!")
    m_mesh_library_dialog.visible = true

func _on_mesh_library_dialog_file_selected(path:String):
    m_logger.debug("Mesh Library Database Path Selected: %s" % path)
    m_mesh_lib_database_path_temp = path

func _on_mesh_library_dialog_file_confirmed():
    m_logger.debug("Mesh Library Path Confirmed: %s" % m_mesh_lib_database_path_temp)
    var config_path = m_config.get_value("config", "config_path")
    m_config.set_value(name, "mesh_library_path", m_mesh_lib_database_path_temp)
    m_config.save(config_path)
    m_mesh_lib_database_path = m_mesh_lib_database_path_temp
    m_mesh_lib_database_path_temp = ""
    m_mesh_library_dialog.visible = false
    m_flag_initialize_library = true

func _on_pos_size_changed(type_val, text):
    print ("Type: %s, Text: %s" % [type_val, text])
    if not text.is_valid_int():
        return
    match type_val:
        "x_pos":
            m_wfc_pos.x = int(text)
        "y_pos":
            m_wfc_pos.y = int(text)
        "x_size":
            m_wfc_size.x = int(text)
        "y_size":
            m_wfc_size.y = int(text)
    m_wfc_rect = Rect2i(m_wfc_pos, m_wfc_size)


func _on_start_pressed():
    # Check if the size is valid
    if m_wfc_size.x < 1 or m_wfc_size.y < 1:
        m_logger.error("Invalid WFC Size: %s" % m_wfc_size)
        return

    # Save all the configuration values
    var config_path = m_config.get_value("config", "config_path")
    m_config.set_value(name, "x_pos", str(m_wfc_pos.x))
    m_config.set_value(name, "y_pos", str(m_wfc_pos.y))
    m_config.set_value(name, "x_size", str(m_wfc_size.x))
    m_config.set_value(name, "y_size", str(m_wfc_size.y))
    m_config.save(config_path)

    m_flag_start_wfc = true

func _wfc_done():
    var status = "WFC Done!"
    m_status.text = status
