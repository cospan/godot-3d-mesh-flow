extends Node3D

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################
const CAMERA_LERP_SPEED = 1.0
const DEFAULT_CAMERA_HEIGHT = 5.0


##############################################################################
# Members
##############################################################################

var m_camera = null
var m_enable_mouse = false
var m_camera_dest_pos = Vector3(0, DEFAULT_CAMERA_HEIGHT, 0)
var m_camera_dest_rot = Vector3(-1.5708, 0, 0)

var m_camera_top_pos = Vector3(0, DEFAULT_CAMERA_HEIGHT, 0)
var m_camera_top_rotation = Vector3(-1.5708, 0, 0)

var DEBUG = false
var m_logger = LogStream.new("Map View", LogStream.LogLevel.DEBUG)

var m_camera_angle=0
var m_camera_pitch:float = 0.0

var m_max_size = Vector2(10, 10)

##############################################################################
# Exports
##############################################################################
@export var MOUSE_Y_SENSITIVITY = 0.10
@export var MOUSE_X_SENSITIVITY = 0.01

##############################################################################
# Public Functions
##############################################################################


##################
# GUI Functions
##################
func set_camera_top_view():
    m_camera_dest_pos = m_camera_top_pos
    m_camera_dest_rot = m_camera_top_rotation

##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    if DEBUG:
      m_logger.set_current_level = LogStream.LogLevel.DEBUG
    m_camera = $Camera3D
    m_camera_dest_pos = m_camera_top_pos
    m_camera_dest_rot = m_camera_top_rotation
    #child_entered_tree.connect(_child_entered_tree)
    #child_exiting_tree.connect(_child_exiting_tree)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func _physics_process(_delta):
    if not m_camera:
        return
    if not m_enable_mouse:
        m_camera.position = m_camera.position.lerp(m_camera_dest_pos, _delta * CAMERA_LERP_SPEED)
        m_camera.rotation = m_camera.rotation.lerp(m_camera_dest_rot, _delta * CAMERA_LERP_SPEED)


##############################################################################
# Signal Handlers
##############################################################################

func _input(event):
    if m_enable_mouse and event is InputEventMouseMotion:

        m_camera_pitch = clamp(m_camera_pitch + event.relative.y * MOUSE_X_SENSITIVITY, -0.5 * PI, 0.5 * PI)
        m_camera.rotation.x = m_camera_pitch
        #m_camera.rotation.y += event.relative.x * MOUSE_SENSITIVITY

        m_camera.rotate_y(deg_to_rad(-event.relative.x*MOUSE_Y_SENSITIVITY))
        #var changev=-event.relative.y*MOUSE_X_SENSITIVITY
        #if m_camera_angle+changev>-50 and m_camera_angle+changev<50:
        #    m_camera_angle+=changev
        #    m_camera.rotate_x(deg_to_rad(changev))
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            m_camera.scale *= 0.9
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            m_camera.scale *= 1.1
        # Disable mouse if right click
        if event.button_index == MOUSE_BUTTON_RIGHT:
            m_camera.scale = Vector3(1, 1, 1)
            set_camera_top_view()

        if event.button_index == MOUSE_BUTTON_MIDDLE:
            if event.pressed:
                m_enable_mouse = not m_enable_mouse

func _child_entered_tree(n):
    _evaluate_child_size(n)

func _child_exiting_tree(n):
    m_max_size = Vector2(1, 1)
    for c in get_children():
        if c == n:
            continue
        if c is MeshInstance3D:
            _evaluate_child_size(c)

func _evaluate_child_size(n):
    var m = n.mesh
    m_logger.debug("Evaluate Child: %s" % m)
    var mesh_aabb = m.get_aabb()
    var x_min = mesh_aabb.position[0]
    var x_max = mesh_aabb.end[0]
    var y_min = mesh_aabb.position[1]
    var y_max = mesh_aabb.end[1]
    if abs(x_min) > (m_max_size[0] / 2):
        m_max_size[0] = abs(x_min) * 2
        m_logger.debug("x_min is smaller, new size: %s" % str(m_max_size))
    if abs(x_max) > (m_max_size[0] / 2):
        m_max_size[0] = abs(x_max) * 2
        m_logger.debug("x_max is smaller, new size: %s" % str(m_max_size))

    if abs(y_min) > (m_max_size[1] / 2):
        m_max_size[1] = abs(y_min) * 2
        m_logger.debug("y_min is smaller, new size: %s" % str(m_max_size))
    if abs(y_max) > (m_max_size[1] / 2):
        m_max_size[1] = abs(y_max) * 2
        m_logger.debug("y_max is smaller, new size: %s" % str(m_max_size))

