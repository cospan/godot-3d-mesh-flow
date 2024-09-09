extends Control

class_name FaceViewItem
##############################################################################
# Export
##############################################################################
@export var PADDING = 10

##############################################################################
# Signals
##############################################################################
signal selected
signal r_selected

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_index = -1
var m_hash = ""
var m_offset = Vector2(0, 0)
var m_face_triangles = []
var m_bound_box = null
var m_flag_reflection = false
var m_view_scale = 100:
    get:
        return m_view_scale
    set (v):
        m_view_scale = v

var m_calc_size = Vector2(0, 0)

# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func set_face_size(_size:Vector2):
    m_calc_size = (_size * m_view_scale)
    m_calc_size.x += PADDING * 2
    m_calc_size.y += PADDING * 2
    custom_minimum_size = m_calc_size
    set_size(m_calc_size)
    m_offset = Vector2((size.x / 2) + PADDING, (size.y / 2) + PADDING)

func set_index_and_face_triangles(index:int, _hash:String, face_triangles:Array, bound_box = null):
    m_index = index
    m_hash = _hash
    m_face_triangles = face_triangles
    m_bound_box = bound_box
    queue_redraw()

func enable_reflection(_enable:bool):
    m_flag_reflection = _enable
    queue_redraw()

func _gui_input(event):
    if event is InputEventMouseButton:
        if event.button_index == 1 && event.pressed == true:
            if m_flag_reflection:
                emit_signal("r_selected", m_index, m_hash)
            else:
                emit_signal("selected", m_index, m_hash)

func _draw():
    var t = Transform2D()
    #t.scaled(Vector2(m_view_scale, m_view_scale))
    if m_flag_reflection:
        t = t.scaled(Vector2(-1, 1))

    t = t.translated(m_offset)
    draw_set_transform_matrix(t)
    #var ti = t.affine_inverse()

    for i in range (len(m_face_triangles)):
        var _triangle = m_face_triangles[i][0]
        var _color = m_face_triangles[i][1]
        var triangle_verticies = PackedVector2Array()
        var colors = PackedColorArray()

        triangle_verticies.append((_triangle[0] * m_view_scale))
        triangle_verticies.append((_triangle[1] * m_view_scale))
        triangle_verticies.append((_triangle[2] * m_view_scale))
        #triangle_verticies.append((_triangle[0]))
        #triangle_verticies.append((_triangle[1]))
        #triangle_verticies.append((_triangle[2]))

        colors.append(_color)
        colors.append(_color)
        colors.append(_color)
        draw_polygon(triangle_verticies, colors)

    #draw_set_transform_matrix(ti)
    if m_bound_box != null:
        var r = m_bound_box
        r.size = r.size * m_view_scale
        #r.position = (r.position * m_view_scale) + m_offset
        r.position = (r.position * m_view_scale)
        draw_rect(r, Color.GREEN, false, 1.0)
