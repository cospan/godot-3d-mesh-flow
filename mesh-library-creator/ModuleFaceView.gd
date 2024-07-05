extends Control

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################
##############################################################################
# Members
##############################################################################
var m_module = null
var m_offset = Vector2(0, 0)
var m_module_name = ""
var m_face_index = -1
var m_base_agnostic_enabled = false
var m_face_triangles = null
var m_face_bounds_rect = null
var m_logger = LogStream.new("Face View", LogStream.LogLevel.INFO)

##############################################################################
# Scenes
##############################################################################
var m_mlp = null

##############################################################################
# Exports
##############################################################################
@export var VIEW_SCALE = 100
@export var DEBUG:bool = false
#@export var VIEW_OFFSET = Vector2(0, 0)

##############################################################################
# Public Functions
##############################################################################

func set_module_processor(_module_parser):
    m_mlp = _module_parser

func set_module_and_face(_module_name, _face_index, _base_agnostic_enabled = false):
    m_module_name = _module_name
    m_offset = m_mlp.get_default_size() * VIEW_SCALE
    m_face_index = _face_index
    m_base_agnostic_enabled = _base_agnostic_enabled
    m_face_triangles = m_mlp.get_faces_from_name(m_module_name, m_base_agnostic_enabled)[_face_index]
    m_face_bounds_rect = m_mlp.get_face_bounds_rect(m_module_name, m_face_index, m_base_agnostic_enabled)
    m_logger.debug ("m_face_bounds_rect: %s" % str(m_face_bounds_rect))
    queue_redraw()

func _notification(what):
    match what:
        NOTIFICATION_FOCUS_ENTER:
            #VIEW_OFFSET = Vector2(get_size().x / 2, get_size().y / 2)
            queue_redraw()
        NOTIFICATION_VISIBILITY_CHANGED:
            #VIEW_OFFSET = Vector2(get_size().x / 2, get_size().y / 2)
            queue_redraw()
        NOTIFICATION_RESIZED:
            #VIEW_OFFSET = Vector2(get_size().x / 2, get_size().y / 2)
            queue_redraw()

##############################################################################
# Private Functions
##############################################################################

func _ready():
    if DEBUG:
      m_logger.set_current_level = LogStream.LogLevel.DEBUG

func _draw():
    if m_face_triangles == null:
        return

    for i in range(m_face_triangles.size()):
        var _triangle = m_face_triangles[i][0]
        var _color = m_face_triangles[i][1]
        var triangle_vertices = PackedVector2Array()
        var colors = PackedColorArray()

        #triangle_vertices.append((_triangle[0] * VIEW_SCALE) + VIEW_OFFSET)
        #triangle_vertices.append((_triangle[1] * VIEW_SCALE) + VIEW_OFFSET)
        #triangle_vertices.append((_triangle[2] * VIEW_SCALE) + VIEW_OFFSET)

        triangle_vertices.append((_triangle[0] * VIEW_SCALE) + m_offset)
        triangle_vertices.append((_triangle[1] * VIEW_SCALE) + m_offset)
        triangle_vertices.append((_triangle[2] * VIEW_SCALE) + m_offset)


        colors.append(_color)
        colors.append(_color)
        colors.append(_color)

        draw_polygon(triangle_vertices, colors)
    var r = m_face_bounds_rect
    r.size = r.size * VIEW_SCALE
    r.position = (r.position * VIEW_SCALE) + m_offset
    m_logger.debug ("Final Rectangle: %s" % str(r))
    draw_rect(r, Color.GREEN, false, 1.0)
