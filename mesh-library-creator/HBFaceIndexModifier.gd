extends HBoxContainer

##############################################################################
# Signals
##############################################################################
signal back_button_pressed

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_module_parser = null
var m_module_name = ""
var m_face_side_index = -1
var m_base_agnostic_enabled = false
var m_sid = -1
var m_face_hash = null
var m_debug_props = {}
#var m_logger = LogStream.new("HBox Face Index Modifier", LogStream.LogLevel.INFO)
var m_logger = LogStream.new("HBox Face Index Modifier", LogStream.LogLevel.DEBUG)

##############################################################################
# Sub-modules
##############################################################################
var m_list_all_faces = null
var m_list_index_faces = null
var m_debug_dict_view = null
var m_module_face_view = null

##############################################################################
# Exports
##############################################################################
@export var VIEW_SCALE = 100
@export var DEBUG = false

##############################################################################
# Public Functions
##############################################################################

func set_module_processor(_module_parser):
    m_module_parser = _module_parser
    m_module_face_view.set_module_processor(m_module_parser)

func set_module_and_face(_module_name, _face, _base_agnostic_enabled = false):
    m_module_name = _module_name
    m_base_agnostic_enabled = _base_agnostic_enabled
    m_face_side_index = _face
    m_face_hash = m_module_parser.get_hash_from_module_name_and_face(m_module_name, m_face_side_index, m_base_agnostic_enabled)
    m_module_face_view.set_module_and_face(_module_name, m_face_side_index, m_base_agnostic_enabled)
    m_sid = m_module_parser.get_sid_from_hash(m_face_hash, m_base_agnostic_enabled)
    _populate_all_face_list()
    queue_redraw()

##############################################################################
# Private Functions
##############################################################################
# Called when the node enters the scene tree for the first time.
func _ready():
    m_list_all_faces = $VSAllFaces/GCAllFaces
    assert(m_list_all_faces != null)
    m_list_index_faces = $VSSelectedFaces/GCASelectedFaces
    assert(m_list_index_faces != null)
    m_debug_dict_view = $VB/DPFaceDebug
    assert(m_debug_dict_view != null)
    m_module_face_view = $VB/ModuleFaceView
    assert(m_module_face_view != null)
    m_debug_props["back_button"] = {"type": "Button", "name": "Back", "value": "Back"}
    m_debug_dict_view.set_properties_dict(m_debug_props)
    m_debug_dict_view.property_changed.connect(_on_debug_dict_property_changed)

func _on_debug_dict_property_changed(_property_name, _property_value):
    match _property_name:
        "back_button":
            m_logger.debug ("Back Button Pressed")
            emit_signal("back_button_pressed")

func _populate_all_face_list():

    # delete all children from the lists
    for c in m_list_all_faces.get_children():
        m_list_all_faces.remove_child(c)
        c.queue_free()

    for c in m_list_index_faces.get_children():
        m_list_index_faces.remove_child(c)
        c.queue_free()

    # Retrieve all face hash indexes
    var sids = m_module_parser.get_sids(m_base_agnostic_enabled)
    m_logger.debug ("Face Hash Indexes Count: %d" % len(sids))
    m_logger.debug ("Face Hash Exclude Index: %d" % m_sid)
    sids.sort()
    while (sids.has(m_sid)):
        sids.erase(m_sid)

    # Get a flag if the face we are looking for is symmetrical,
    # we only want to compare symmetrical faces with symmetrical
    # faces and asymmetrical with asymmetrical
    #XXX: Use this flag to keep only the asymmetrical faces for comparison
    var is_output_asymmetrical = not m_module_parser.is_module_face_symmetrical(m_module_name, m_face_side_index)

    var included_face_hashes = m_module_parser.get_hashes_from_sid(m_sid, m_base_agnostic_enabled)
    var face_bounds_rect = m_module_parser.get_face_bounds_rect(m_module_name, m_face_side_index, m_base_agnostic_enabled)
    m_logger.debug ("Face bound rect: %s" % str(face_bounds_rect))

    if is_output_asymmetrical:
        m_logger.debug ("Asymmetric!")
        m_list_all_faces.columns = 2
        var l = Label.new()
        l.text = "Normal"
        m_list_all_faces.add_child(l)
        l = Label.new()
        l.text = "Reflected"
        m_list_all_faces.add_child(l)
    else:
        m_list_all_faces.columns = 1


    for i in sids:
        var face_hash = m_module_parser.get_hashes_from_sid(i, m_base_agnostic_enabled)[0]
        var face_dict = m_module_parser.get_name_face_tuple_from_hash(face_hash, m_base_agnostic_enabled)[0]
        var face_triangles = m_module_parser.get_faces_from_name(face_dict[0], m_base_agnostic_enabled)[face_dict[1]]
        var face_view_index = FaceViewItem.new()
        face_view_index.set_face_size(m_module_parser.get_default_size())
        face_view_index.set_index_and_face_triangles(i, face_hash, face_triangles, face_bounds_rect)
        m_list_all_faces.add_child(face_view_index)
        face_view_index.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_KEEP_SIZE)
        face_view_index.connect("selected", _all_hash_indexes_selected)
        if is_output_asymmetrical:
            face_view_index = FaceViewItem.new()
            face_view_index.set_face_size(m_module_parser.get_default_size())
            face_view_index.set_index_and_face_triangles(i, face_hash, face_triangles, face_bounds_rect)
            face_view_index.enable_reflection(true)
            m_list_all_faces.add_child(face_view_index)
            face_view_index.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_KEEP_SIZE)
            face_view_index.connect("r_selected", _all_hash_indexes_reflected_selected)

    m_logger.info ("Hashed from Selected Index: %s" % str(included_face_hashes))
    for _hash in included_face_hashes:
        var name_face_tuple_list = m_module_parser.get_name_face_tuple_from_hash(_hash, m_base_agnostic_enabled)
        var name_face_tuple = name_face_tuple_list[0]
        var face_triangles = m_module_parser.get_faces_from_name(name_face_tuple[0], m_base_agnostic_enabled)[name_face_tuple[1]]
        var face_view_index = FaceViewItem.new()
        face_view_index.set_face_size(m_module_parser.get_default_size())
        face_view_index.set_index_and_face_triangles(m_sid, _hash, face_triangles)
        m_list_index_faces.add_child(face_view_index)
        face_view_index.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_KEEP_SIZE)
        face_view_index.connect("selected", _output_hash_index_selected)

func _output_hash_index_selected(_hash_index, _hash):
    m_logger.debug ("Output Hash Selected: %s" % _hash)
    var hash_index = m_module_parser.get_sid_from_hash(_hash, m_base_agnostic_enabled)
    if len(m_module_parser.get_hashes_from_sid(hash_index, m_base_agnostic_enabled)) == 1:
        m_logger.warn ("Last Index, Cannot Remove")
        return
    m_module_parser.remove_hash_from_sid(_hash, m_base_agnostic_enabled)
    call_deferred("_populate_all_face_list")


func _all_hash_indexes_selected(_hash_index, _in_hash):
    m_logger.debug ("All Hash Indexes Selected: %s" % str(_hash_index))
    var hashes = m_module_parser.get_hashes_from_sid(_hash_index, m_base_agnostic_enabled)
    for _hash in hashes:
        m_logger.info ("Move Hash %s to selected" % _hash)
        m_module_parser.move_hash_to_sid(m_sid, _hash, m_base_agnostic_enabled)
    call_deferred("_populate_all_face_list")

func _all_hash_indexes_reflected_selected(_hash_index, _in_hash):
    m_logger.debug ("All Hash Indexes Reflected Selected: %s" % str(_hash_index))
    var hashes = m_module_parser.get_hashes_from_sid(_hash_index, m_base_agnostic_enabled)
    for _hash in hashes:
        m_logger.info ("Move Hash %s to selected" % _hash)
        m_module_parser.move_hash_to_sid(m_sid, _hash, m_base_agnostic_enabled)
        m_logger.info ("Set Reflected for hash: %s" % _hash)
        m_module_parser.set_hash_reflected_for_sid(m_sid, _hash, true, m_base_agnostic_enabled)


    call_deferred("_populate_all_face_list")
