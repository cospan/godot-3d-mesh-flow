extends Node3D

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("CameraGimbal", LogStream.LogLevel.DEBUG)
var m_mouse_control = true


var m_camera_top_pos = Vector3(0, 5, 0)
var m_prev_target = null

#### Flags
var m_flag_change_target = false

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################
@export var TARGET:Node3D = null
@export_range(0.0, 2.0) var MOUSE_SENSITIVITY:float = 0.005
@export var INVERT_X:bool = false
@export var INVERT_Y:bool = false

@export var MAX_Y_ROT_SPEED:float = 30

@export_range(0.05, 1.0) var CHANGE_TARGET_SPEED:float = 0.1
# Zoom Settings
@export var MAX_ZOOM:float = 10.0
@export var MIN_ZOOM:float = 0.4
@export_range(0.05, 1.0) var ZOOM_SPEED:float = 0.09

var m_zoom = 1.5

@onready var m_inner = $InnerGimbal
@onready var m_camera = $InnerGimbal/Camera3D


##############################################################################
# Public Functions
##############################################################################

func set_bound_size(_size:Vector2):
    if m_mouse_control:
        return
    var hyp_val = sqrt(_size[0] * _size[0] + _size[1] * _size[1])
    var theta = deg_to_rad(m_camera.fov * 0.5)
    m_zoom = hyp_val / tan(theta)
    m_logger.debug("Zoom: %s" % m_zoom)

##############################################################################
# Private Functions
##############################################################################
func enable_mouse_caputre_mode(enable:bool):
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enable else Input.MOUSE_MODE_VISIBLE

##############################################################################
# Signal Handler
##############################################################################
func _ready():
    enable_mouse_caputre_mode(m_mouse_control)
    set_bound_size(Vector2(3, 3))
    m_prev_target = TARGET

func _process(_delta):
    m_inner.rotation.x = clamp(m_inner.rotation.x, -1.4, -0.01)
    scale = lerp(scale, Vector3.ONE * m_zoom, ZOOM_SPEED)
    if m_prev_target != TARGET:
        m_flag_change_target = true

    if m_flag_change_target:
        var tpos = Vector3.ZERO if TARGET == null else TARGET.global_position
        if tpos.is_equal_approx(global_position):
            m_logger.debug("Lerp Finished")
            m_flag_change_target = false
        else:
            global_position = lerp(global_position, tpos, CHANGE_TARGET_SPEED)
    else:
        if TARGET:
            global_position = TARGET.global_position
        else:
            global_position = Vector3.ZERO


    m_prev_target = TARGET


func _unhandled_input(event):
    if event.is_action_pressed("toggle_mouse_control"):
        m_mouse_control = not m_mouse_control
        enable_mouse_caputre_mode(m_mouse_control)

    if event.is_action_pressed("cam_zoom_in"):
        #m_logger.debug("Zoom In")
        m_zoom -= ZOOM_SPEED
    if event.is_action_pressed("cam_zoom_out"):
        #m_logger.debug("Zoom Out")
        m_zoom += ZOOM_SPEED
    m_zoom = clamp(m_zoom, MIN_ZOOM, MAX_ZOOM)

    if m_mouse_control and event is InputEventMouseMotion:
        if event.relative.x != 0:
            #m_logger.debug("X Rotation: %s" % event.relative.x)
            var dir = 1 if INVERT_X else -1
            rotate_object_local(Vector3.UP, dir * event.relative.x * MOUSE_SENSITIVITY)
        if event.relative.y != 0:
            #m_logger.debug("Y Rotation: %s" % event.relative.y)
            var dir = 1 if INVERT_Y else -1
            var y_rotation = clamp(event.relative.y, -MAX_Y_ROT_SPEED, MAX_Y_ROT_SPEED)
            m_inner.rotate_object_local(Vector3.RIGHT, dir * y_rotation * MOUSE_SENSITIVITY)

    if event is InputEventMouseButton and event.pressed:
        # Set TARGET to NULL
        if event.button_index == MOUSE_BUTTON_LEFT:
            TARGET = null
