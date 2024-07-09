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
var m_logger = LogStream.new("SID Face View", LogStream.LogLevel.DEBUG)

var m_face = null
var m_bounds = null
#var m_enable_bounding_box = false
var m_enable_bounding_box = true

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################
@export var PADDING = 10

##############################################################################
# Public Functions
##############################################################################

func set_face_and_bounds(_face, _bounds) -> void:
    m_face = _face
    m_bounds = _bounds

func enable_bounding_box(enable:bool) -> void:
    m_logger.debug("Enable Bounding Box: " + str(enable))
    m_enable_bounding_box = enable


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    pass

func _draw():
    var view_scale = size / m_bounds.size.x
    m_logger.debug("View Scale: " + str(view_scale))
    if m_face == null:
        draw_rect(Rect2(Vector2(0, 0), size), Color(1, 0, 0, 1))
        return

    var t = Transform2D()
    m_logger.debug("Bounds: " + str(m_bounds))
    var translated_position = m_bounds.position * view_scale * -1
    m_logger.debug("Translated Position: " + str(translated_position))


    t = t.translated(translated_position)
    draw_set_transform_matrix(t)
    for i in range(len(m_face)):
        var triangle = m_face[i][0]
        var color = m_face[i][1]

        var triangle_verticies = PackedVector2Array()
        var colors = PackedColorArray()

        triangle_verticies.append((triangle[0]) * view_scale)
        triangle_verticies.append((triangle[1]) * view_scale)
        triangle_verticies.append((triangle[2]) * view_scale)

        colors.append(color)
        colors.append(color)
        colors.append(color)

        draw_polygon(triangle_verticies, colors)

    if m_enable_bounding_box:
        draw_rect(Rect2(m_bounds.position * view_scale, m_bounds.size * view_scale), Color(0, 1, 0, 1), false, 1.0)

