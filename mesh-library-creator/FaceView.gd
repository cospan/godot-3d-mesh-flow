extends Control

##############################################################################
# Signals
##############################################################################
signal face_selected

##############################################################################
# Constants
##############################################################################
const X_OFFSET = 10
const Y_OFFSET = 20
const PART_OFFSET = X_OFFSET + 50
const Y_MODULE_FACE_OFFSET = 60
const VIEW_SCALE = 100
const FACE_COUNT_X_OFFSET = X_OFFSET
const FACE_COUNT_Y_OFFSET = Y_OFFSET + 20
const Y_SYMMETRY_OFFSET = Y_OFFSET + 40
const Y_BASE_OFFSET = Y_OFFSET + 60
const Y_HASH_OFFSET = Y_OFFSET + 80

const SHOW_ALL_HEIGHT = 20
const SHOW_SINGLE_HEIGHT = 200


##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Face View", LogStream.LogLevel.INFO)
var m_font
var m_font_size
var m_db_adapter = null
var m_current_module = null
var m_base_agnostic_enable:bool = false
var m_face_width = 10
var m_selected_face = -1
var m_mlp = null



##############################################################################
# Exports
##############################################################################
@export var DEBUG:bool = false

##############################################################################
# Public Functions
##############################################################################
func set_module_processor(module_processor):
    m_mlp = module_processor
    m_db_adapter = module_processor.m_db_adapter

func set_current_module(module_name):
    m_current_module = m_mlp.m_mesh_dict[module_name].duplicate()
    size.y = SHOW_SINGLE_HEIGHT
    queue_redraw()

func clear_selected_module():
    m_current_module = null
    size.y = SHOW_ALL_HEIGHT
    queue_redraw()

func enable_base_agnostic(enable):
    m_base_agnostic_enable = enable
    queue_redraw()


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    if DEBUG:
      m_logger.set_current_level = LogStream.LogLevel.DEBUG
    m_logger.debug("Ready Entered!")
    m_font = theme.default_font
    m_font_size = theme.default_font_size
    m_face_width = get_size().x / 6


func _notification(what):
    if what == NOTIFICATION_RESIZED:
        m_face_width = get_size().x / 6
        queue_redraw()
    if what == NOTIFICATION_VISIBILITY_CHANGED:
        m_logger.debug ("Visibility Changed")
        if is_visible():
            queue_redraw()

func _draw():

    if m_current_module == null or m_mlp == null:
        return

    var width = get_size().x
    var module_y_pos = get_size().y / 2 + Y_MODULE_FACE_OFFSET
    # Divide the width into 6 parts
    var part_width = width / 6
    var pos = Vector2(X_OFFSET, Y_OFFSET)
    #var symmetry_pos = Vector2(X_OFFSET, Y_SYMMETRY_OFFSET)
    draw_string(m_font, pos, "Front", HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
    pos.x += part_width
    draw_string(m_font, pos, "Back", HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
    pos.x += part_width
    draw_string(m_font, pos, "Top", HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
    pos.x += part_width
    draw_string(m_font, pos, "Bottom", HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
    pos.x += part_width
    draw_string(m_font, pos, "Right", HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
    pos.x += part_width
    draw_string(m_font, pos, "Left", HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))

    var bb_module_faces = null
    bb_module_faces = m_mlp.get_faces_from_name(m_current_module, m_base_agnostic_enable)

    if bb_module_faces.size() > 0:
        #Draw all the triangles in the front face
        for i in range(bb_module_faces.size()):
        #for i in range(2):
            #m_logger.debug ("Face: %d" % i)
            var front_face = bb_module_faces[i]
            var face_count_pos = Vector2(FACE_COUNT_X_OFFSET + part_width * i, FACE_COUNT_Y_OFFSET)
            var face_count_string = "Face Count: " + str(front_face.size())
            draw_string(m_font, face_count_pos, face_count_string, HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
            pos = Vector2(PART_OFFSET + part_width * i, module_y_pos)
            for j in range(front_face.size()):
                var triangle = front_face[j][0]
                var color = front_face[j][1]

                var triangle_verticies = PackedVector2Array()
                var colors = PackedColorArray()

                triangle_verticies.append((triangle[0] * VIEW_SCALE) + pos)
                triangle_verticies.append((triangle[1] * VIEW_SCALE) + pos)
                triangle_verticies.append((triangle[2] * VIEW_SCALE) + pos)

                colors.append(color)
                colors.append(color)
                colors.append(color)
                #m_logger.debug ("Triangles: %s" % str(triangle_verticies))
                #m_logger.debug ("Color: %s" % str(color))
                draw_polygon(triangle_verticies, colors)

            # Symmetry
            var symmetric_string = "Asymmetric"
            if (m_mlp.is_module_face_symmetrical(m_current_module, i)):
                symmetric_string = "Symmetric"
            var symmetry_pos = Vector2(X_OFFSET + (part_width * i), Y_SYMMETRY_OFFSET)
            draw_string(m_font, symmetry_pos, symmetric_string, HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
            #symmetry_pos.x= part_width

    var base_offset_dict = m_db_adapter.get_bottom_offset_dict()
    if m_current_module in base_offset_dict:
        pos = Vector2(X_OFFSET, Y_BASE_OFFSET)
        for i in range(6):
            var base_offset = base_offset_dict[m_current_module][i]
            var base_offset_string = "NAN"
            if base_offset != null:
                base_offset_string = "B: %0.4f" % base_offset
            draw_string(m_font, pos, base_offset_string, HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))
            pos.x += part_width


    for i in range(6):
        var _hash = m_mlp.get_hash_from_module_name_and_face(m_current_module, i, m_base_agnostic_enable)
        var hash_string = "NAN"
        if _hash != null:
            hash_string = "H: %s" % _hash.left(5)
        var _pos = Vector2(X_OFFSET + (part_width * i), Y_HASH_OFFSET)
        draw_string(m_font, _pos, hash_string, HORIZONTAL_ALIGNMENT_CENTER, -1, m_font_size, Color(1, 1, 1, 1))

    if m_selected_face >= 0 and m_selected_face < 6:
        draw_rect(Rect2(Vector2(m_selected_face * part_width, 0), Vector2(part_width, get_size().y)), Color(1, 1, 1, 0.2))



func _on_gui_input(event:InputEvent):
    if event is InputEventMouseButton:
        #m_logger.debug ("Mouse Event")
        if event.button_index == 1 && event.pressed == true:
            #m_logger.debug ("Global Position: %s" % str(event.global_position))
            #m_logger.debug ("Event Position: %s" % str(event.position))
            m_selected_face = floori(event.position.x / m_face_width)
            emit_signal("face_selected", m_selected_face)

        #m_logger.debug ("Global Rects: %s" % str(get_global_rect()))
        #m_logger.debug ("Full Screen Size: %s" % str(get_))
        queue_redraw()
