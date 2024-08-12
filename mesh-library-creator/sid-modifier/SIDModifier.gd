extends HBoxContainer


##############################################################################
# Signals
##############################################################################
signal progress_percent_update
signal continue_step
signal finished_loading
signal back_button_pressed
signal add_remove_faces

##############################################################################
# Constants
##############################################################################

enum STATE_TYPES {
    STATE_TYPE_RESET,
    STATE_TYPE_IDLE,
    STATE_TYPE_UPDATE,
}

var m_state = STATE_TYPES.STATE_TYPE_RESET

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("SID Manager", LogStream.LogLevel.DEBUG)


var m_sids_dict = {}
var m_sids = {}
var m_props = {}

##############
# Flags
##############
var m_flag_reset = false
var m_flag_ready = false
var m_flag_update = false
var m_flag_finished_loading = false

##############################################################################
# Scenes
##############################################################################

var m_mlp = null
var m_properties = null
var m_hbsids = null


var m_sid_modifier_box_scene = preload("res://mesh-library-creator/sid-modifier/SIDModifierBox.tscn")


##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func set_module_processor(_mlp):
    m_mlp = _mlp
    m_flag_ready = true

func update():
    m_flag_update = true


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_properties = $DebugDictProperty
    m_hbsids = $SC/HBSIDS
    m_flag_ready = false
    m_flag_update = false
    m_flag_reset = false
    m_flag_finished_loading = false
    m_state = STATE_TYPES.STATE_TYPE_RESET


    m_props["back"] = {"type": "Button", "name": "Back", "value": "Return", "tooltip": "Return to the previous screen"}
    m_properties.set_properties_dict(m_props)

    # Connect Signals
    m_properties.property_changed.connect(_property_changed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    match(m_state):
        STATE_TYPES.STATE_TYPE_RESET:
            if m_flag_ready:
                m_logger.debug("Resetting!")
                m_flag_reset = false
                m_state = STATE_TYPES.STATE_TYPE_IDLE

        STATE_TYPES.STATE_TYPE_IDLE:
            if m_flag_ready:
                m_flag_ready = false
                m_logger.debug("Ready!")

            if m_flag_reset:
                m_state = STATE_TYPES.STATE_TYPE_RESET

            elif m_flag_update:
                m_state = STATE_TYPES.STATE_TYPE_UPDATE

        STATE_TYPES.STATE_TYPE_UPDATE:
            if m_flag_update:
                m_logger.debug("Updating SID Children!")
                m_flag_update = false
                m_flag_finished_loading = false
                _update_sid_children()
                m_state = STATE_TYPES.STATE_TYPE_IDLE

            # Asynchronous Loading is finished
            if m_flag_finished_loading:
                m_logger.debug("Finished Loading!")
            else:
                emit_signal("continue_step")

            if m_flag_reset:
                m_state = STATE_TYPES.STATE_TYPE_RESET
        _:
            pass

func _update_sid_children():
    if m_mlp == null:
        m_logger.error("Module Processor is not set!")
        m_flag_reset = true
        return

    if len(m_sids) > 0:
        for sid in m_sids:
            sid.queue_free()

    m_sids_dict = m_mlp.get_sids()
    var percent = 0.0
    var total_size = len(m_sids_dict)
    var _pname = "Update"
    call_deferred("emit_percent_update", _pname, percent)
    m_logger.debug("Length of SID Dict: %d" % total_size)
    for sid in m_sids_dict:
        var sid_box = m_sid_modifier_box_scene.instantiate()
        sid_box.set_module_processor(m_mlp)
        sid_box.set_sid(sid)
        m_hbsids.add_child(sid_box)
        sid_box.add_remove_faces.connect(_on_add_remove_faces)
        percent = percent + 1.0
        call_deferred("emit_percent_update", _pname, percent / total_size * 100.0)
        #await continue_step

    percent = 100.0
    call_deferred("emit_percent_update", _pname, percent)
    m_flag_finished_loading = true



func _populate_sid_tree(tree):
    # Configure the tree
    var sid = tree.get_meta("sid")
    tree.set_anchor_preset(PRESET_FULL_RECT)
    tree.anchor_right = 1.0
    tree.anchor_bottom = 1.0
    tree.anchor_top = 1.0
    tree.anchor_left = 1.0
    tree.columns = 2
    tree.hide_root = true
    tree.scroll_horizontal = false
    tree.scroll_vertical = true
    tree.select_mode = Tree.SelectMode.SELECT_ROW
    var _root = tree.create_item()
    var info_child = tree.create_item(_root)
    var name_child = info_child.create_item()
    name_child.set_text(0, "Name")
    name_child.set_text(1, str(sid))


##############################################################################
# Signal Handlers
##############################################################################

func _on_face_draw():
    pass

func emit_percent_update(_pname, _percent):
    emit_signal("progress_percent_update", _pname, _percent)

func _property_changed(prop_name:String, _prop_value):
    m_logger.debug("Property Changed: %s" % prop_name)
    match prop_name:
        "back":
            m_logger.debug("Back Button Pressed!")
            m_flag_reset = true
            emit_signal("back_button_pressed")
        _:
            pass

func _on_add_remove_faces(module_name, _face_index):
    m_logger.debug("Add/Remove Faces: %s, %d" % [module_name, _face_index])
    emit_signal("add_remove_faces", module_name, _face_index)
