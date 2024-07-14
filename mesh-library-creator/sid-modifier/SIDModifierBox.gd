extends Control

#class_name SIDModifierBox
##############################################################################
# Signals
##############################################################################
signal add_remove_faces

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("SID Mod Box", LogStream.LogLevel.DEBUG)
var m_mlp = null
var m_ba = false
var m_sid = null
var m_module_dict = null

var m_module_name = null
var m_face_index = null

##############################################################################
# Scenes
##############################################################################
var m_sid_info_tree = null
var m_neighbor_sid_tree = null
var m_sid_face_view = null
var m_add_remove_faces_button = null


##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func set_module_processor(_mlp) -> void:
    m_logger.debug("Setting Module Processor!")
    m_mlp = _mlp
    m_module_dict = m_mlp.get_module_dict()

func set_sid(_sid:int) -> void:
    m_logger.debug("Setting SID Name!")
    m_sid = _sid
    m_logger.debug ("SID Name: ", m_sid)


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")


    # Scenes

    m_sid_info_tree = $VB/SidInfoTree
    m_sid_info_tree.columns = 2
    m_sid_info_tree.hide_folding = true
    m_sid_info_tree.hide_root = true
    m_sid_info_tree.scroll_horizontal_enabled = false
    m_sid_info_tree.scroll_vertical_enabled = false
    m_sid_info_tree.select_mode = Tree.SelectMode.SELECT_ROW

    m_sid_face_view = $VB/SIDFaceView

    m_add_remove_faces_button = $VB/AddRemoveFacesButton

    m_neighbor_sid_tree = $VB/NeighborSIDTree
    m_neighbor_sid_tree.columns = 2
    m_neighbor_sid_tree.hide_folding = true
    m_neighbor_sid_tree.hide_root = true
    m_neighbor_sid_tree.scroll_horizontal_enabled = false
    m_neighbor_sid_tree.scroll_vertical_enabled = true
    m_neighbor_sid_tree.select_mode = Tree.SelectMode.SELECT_ROW

    # Signals
    m_sid_info_tree.item_selected.connect(_on_info_tree_item_selected)
    m_neighbor_sid_tree.item_selected.connect(_on_neighbor_sid_tree_item_selected)
    m_add_remove_faces_button.pressed.connect(_on_add_remove_faces_button_pressed)
    _update()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func _update():
    #m_logger.debug("Updating!")

    if m_mlp == null:
        m_logger.error("Module Processor is null!")
        return

    if m_sid == null:
        m_logger.error("SID Name is null!")
        return

    # Set the name/Face as <Module Name>:<Face Name>
    #var sid_hash_dict = m_mlp.get_sid(m_sid, m_ba)

    var sid_hashes = m_mlp.get_hashes_from_sid(m_sid, m_ba)
    var face_name_tuple = m_mlp.get_name_face_tuple_from_hash(sid_hashes[0], m_ba)
    var module_name = face_name_tuple[0][0]
    var face_index = face_name_tuple[0][1]
    #m_logger.debug("Face Name Tuple: ", face_name_tuple)
    var faces = m_mlp.get_faces_from_name(module_name)

    var face_bounds_rect = m_mlp.get_face_bounds_rect(module_name, face_index, m_ba)
    #m_logger.debug("SID, Module, Face Index: %s" % str([m_sid, module_name, face_index]))
    m_sid_face_view.set_face_and_bounds(faces[face_index], face_bounds_rect)
    _update_info_tree()
    _update_neighbor_tree()

func _update_info_tree() -> void:
    #m_logger.debug("Updating Tree!")
    var sid_hashes = m_mlp.get_hashes_from_sid(m_sid, m_ba)
    if len(sid_hashes) == 0:
        m_logger.error("No hashes found for SID: ", m_sid)
        return


    # All the faces associated with the SID should be identical so we just need the first face we can find
    var face_name_tuple = m_mlp.get_name_face_tuple_from_hash(sid_hashes[0], m_ba)
    var module_name = face_name_tuple[0][0]
    var face_index = face_name_tuple[0][1]
    #m_logger.debug("Face Name Tuple: ", face_name_tuple)
    #var faces = m_mlp.get_faces_from_name(module_name)
    #var face = faces[face_index]
    var symmetric = m_mlp.is_module_face_symmetrical(module_name, face_index, m_ba)



    m_sid_info_tree.clear()

    # Create the tree root
    var _root = m_sid_info_tree.create_item()
    #var info_child = m_sid_info_tree.create_item(_root)
    #info_child.set_text(0, "Info")
    var name_child = m_sid_info_tree.create_item(_root)
    var sc = m_sid_info_tree.create_item(_root)
    name_child.set_text(0, "SID")
    name_child.set_text(1, str(m_sid))
    sc.set_text(0, "Symmetrc")
    if symmetric:
        sc.set_text(1, "True")
    else:
        sc.set_text(1, "False")
    var tc = m_sid_info_tree.create_item(_root)
    tc.set_text(0, "Total Faces")
    tc.set_text(1, str(m_mlp.get_sids_total_module_face_count(m_sid, m_ba)))

    #m_logger.debug("Updated Tree!")


func _update_neighbor_tree() -> void:
    #m_logger.debug("Updating Neighbor Tree!")

    var _root = m_neighbor_sid_tree.create_item()
    var sid_hashes = m_mlp.get_hashes_from_sid(m_sid, m_ba)
    if len(sid_hashes) == 0:
        m_logger.error("No hashes found for SID: ", m_sid)
        return
    var index = 0
    for h in sid_hashes:
        var face_name_tuples = m_mlp.get_name_face_tuple_from_hash(h, m_ba)
        #m_logger.debug("Face Name Tuple: ", face_name_tuple)
        for fnt in face_name_tuples:
            var module_name = fnt[0]
            m_module_name = module_name
            var face_index = fnt[1]
            m_face_index = face_index
            var face_name = m_mlp.get_face_name_from_face(face_index)
            var name_child = m_neighbor_sid_tree.create_item(_root)
            var fn = module_name + ":" + face_name
            name_child.set_text(0, str(index))
            name_child.set_text(1, fn)

            #var face_index = face_name_tuple[0][1]
            #var faces = m_mlp.get_faces_from_name(module_name)
            #var face = faces[face_index]

            #var _root = m_neighbor_sid_tree.create_item()
            #var name_child = m_neighbor_sid_tree.create_item(_root)
            ##tc.set_text(0, "Total Faces")
            ##tc.set_text(1, str(m_mlp.get_sids_total_module_face_count(ns, m_ba)))


##############################################################################
# Signal Handlers
##############################################################################

func _on_info_tree_item_selected():
    m_logger.debug("Info Tree Item Selected!")

func _on_neighbor_sid_tree_item_selected():
    m_logger.debug("Matching SID Tree Item Selected!")

func _on_add_remove_faces_button_pressed():
    m_logger.debug("Add/Remove Faces Button Pressed!")
    emit_signal("add_remove_faces", m_module_name, m_face_index)

