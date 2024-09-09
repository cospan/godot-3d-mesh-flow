extends Node3D

##############################################################################
# Signals
##############################################################################
signal null_selected
##############################################################################
# Constants
##############################################################################
enum CAMERA_TYPES {
    CAMERA_MOVE_IDLE,
    CAMERA_MOVE_PROCESS
}

const MAX_Y_ANGLE = 1.4


##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("CameraGimbal", LogStream.LogLevel.DEBUG)
var m_camera_move_type:CAMERA_TYPES = CAMERA_TYPES.CAMERA_MOVE_IDLE
var m_final_camera_pos:Vector3 = Vector3.ZERO


var m_camera_top_pos = Vector3(0, 5, 0)

var m_zoom = 1.5
var m_bounds_rect = Rect2(0, 0, 1, 1)

#### Flags
var m_flag_change_target = false
var m_flag_change_target_pos = false

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################
@export var DEFAULT_Y_OFFSET:float = 5.0
@export var MOUSE_CONTROL = false

@export var TARGET:Node3D = null
@export var MANUAL_POS:Vector3 = Vector3.ZERO

@export_range(0.0, 2.0) var MOUSE_SENSITIVITY:float = 0.005
@export var INVERT_X:bool = false
@export var INVERT_Y:bool = false

@export var MAX_Y_ROT_SPEED:float = 30

@export_range(0.05, 1.0) var CHANGE_TARGET_SPEED:float = 0.1
# Zoom Settings
@export var MAX_ZOOM:float = 10.0
@export var MIN_ZOOM:float = 0.4
@export_range(0.05, 1.0) var ZOOM_SPEED:float = 0.09


@onready var m_inner = $InnerGimbal
@onready var m_camera = $InnerGimbal/Camera3D


##############################################################################
# Public Functions
##############################################################################
func get_camera():
    return m_camera

func set_bound_rect(_rect:Rect2):
    m_bounds_rect = _rect
    _recalculate_camera_top_pos()

func set_top_view():
    m_inner.rotation.x = -MAX_Y_ANGLE
    m_logger.debug("Set Top View: %s" % str(m_camera_top_pos))
    _set_camera_pos(m_camera_top_pos)

func set_manual_position(pos:Vector3):
    _set_camera_pos(pos)

func set_target(target:Node3D):
    if target == null:
        set_top_view()
    else:
        _set_camera_pos(target.global_position)

##############################################################################
# Private Functions
##############################################################################
func _recalculate_camera_top_pos():
    # Find the longest side of the m_bounds_rect
    var g_pos = to_global(Vector3(m_bounds_rect.position.x, 0, m_bounds_rect.position.y))
    var x_size = m_bounds_rect.size.x
    var z_size = m_bounds_rect.size.y

    var square_size = max(x_size, z_size)
    var y_offset = DEFAULT_Y_OFFSET
    var hyp_val = sqrt(square_size * square_size + square_size * square_size)
    var theta = deg_to_rad(m_camera.fov * 0.5)
    y_offset = hyp_val / tan(theta)
    m_camera_top_pos = Vector3(g_pos.x + x_size * 0.5, y_offset, g_pos.y + z_size * 0.5)
    # We need to add a z offset to the camera because the camera rotation is not completely facing down
    # Tan (inner gimbal angle) = y_offset / z_offset
    # z_offset = y_offset / tan(inner gimbal angle)
    var z_offset = y_offset / tan(MAX_Y_ANGLE)
    m_camera_top_pos.z += z_offset

    m_logger.debug("Recalculated Camera Top Pos: %s" % m_camera_top_pos)

func _set_camera_pos(_pos:Vector3):
    m_logger.debug("Set Camera Pos: %s" % _pos)
    m_final_camera_pos = _pos
    m_camera_move_type = CAMERA_TYPES.CAMERA_MOVE_PROCESS

func enable_mouse_caputre_mode(enable:bool):
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enable else Input.MOUSE_MODE_VISIBLE

##############################################################################
# Signal Handler
##############################################################################
func _ready():
    m_camera_top_pos.y = DEFAULT_Y_OFFSET
    set_bound_rect(Rect2(0, 0, 1, 1))
    enable_mouse_caputre_mode(MOUSE_CONTROL)
    if TARGET != null:
        _set_camera_pos(TARGET.global_position)
    else:
        _set_camera_pos(m_camera_top_pos)

func _process(_delta):
    m_inner.rotation.x = clamp(m_inner.rotation.x, -1.4, -0.01)
    scale = lerp(scale, Vector3.ONE * m_zoom, ZOOM_SPEED)

    match m_camera_move_type:
        CAMERA_TYPES.CAMERA_MOVE_IDLE:
            pass
        CAMERA_TYPES.CAMERA_MOVE_PROCESS:
            if m_final_camera_pos.is_equal_approx(global_position):
                m_logger.debug("Lerp Finished")
                m_logger.debug("Global Position: %s" % global_position)
                global_position = m_final_camera_pos
                m_camera_move_type = CAMERA_TYPES.CAMERA_MOVE_IDLE
            else:
                global_position = lerp(global_position, m_final_camera_pos, CHANGE_TARGET_SPEED)





    #if m_prev_target != TARGET:
    #    m_flag_change_target = true

    #if m_flag_change_target:
    #    var tpos = Vector3.ZERO if TARGET == null else TARGET.global_position
    #    if tpos.is_equal_approx(global_position):
    #        m_logger.debug("Lerp Finished")
    #        m_flag_change_target = false
    #    else:
    #        global_position = lerp(global_position, tpos, CHANGE_TARGET_SPEED)
    #else:
    #    if TARGET:
    #        global_position = TARGET.global_position
    #    elif m_final_camera_pos != Vector3.ZERO:
    #        global_position = m_final_camera_pos
    #    else:
    #        global_position = Vector3.ZERO


    #m_prev_target = TARGET


func _unhandled_input(event):
    if event.is_action_pressed("toggle_mouse_control"):
        MOUSE_CONTROL = not MOUSE_CONTROL
        enable_mouse_caputre_mode(MOUSE_CONTROL)

    if event.is_action_pressed("cam_zoom_in"):
        #m_logger.debug("Zoom In")
        m_zoom -= ZOOM_SPEED
    if event.is_action_pressed("cam_zoom_out"):
        #m_logger.debug("Zoom Out")
        m_zoom += ZOOM_SPEED
    m_zoom = clamp(m_zoom, MIN_ZOOM, MAX_ZOOM)

    if MOUSE_CONTROL and event is InputEventMouseMotion:
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
            m_logger.debug("Mouse Position: %s" % event.position)
            m_logger.debug("Mouse Position: %s" % event.global_position)
            _set_camera_pos(m_camera_top_pos)
            emit_signal("null_selected")
