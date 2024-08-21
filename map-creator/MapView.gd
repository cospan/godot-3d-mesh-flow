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

var m_enable_mouse = false
var m_camera_dest_pos = Vector3(0, DEFAULT_CAMERA_HEIGHT, 0)
var m_camera_dest_rot = Vector3(-1.5708, 0, 0)

var m_camera_top_pos = Vector3(0, DEFAULT_CAMERA_HEIGHT, 0)
var m_camera_top_rotation = Vector3(-1.5708, 0, 0)

var DEBUG = false
var m_logger = LogStream.new("Map View", LogStream.LogLevel.DEBUG)

var m_camera_angle=0
var m_camera_pitch:float = 0.0
var m_camera_focal_point:Vector3 = Vector3(0, 0, 0)
var m_camera_rot_quat:Quaternion = Quaternion.IDENTITY

var m_max_size = Vector2(1, 1)

##############################################################################
# Scenes
##############################################################################

#var m_camera = null
var m_camera_gimbal = null

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

func set_target(target:Node3D):
    m_logger.debug("Setting Target: %s" % str(target))
    m_camera_gimbal.set_target(target)

##################
# GUI Functions
##################

##############################################################################
# Private Functions
##############################################################################

func _evaluate_child_size(n):
    var m = n.mesh
    var mesh_aabb = m.get_aabb()
    m_logger.debug("Evaluate Child with AABB: %s" % str(mesh_aabb))
    m_logger.debug("  Start: %s" % str(mesh_aabb.position))
    m_logger.debug("  End: %s" % str(mesh_aabb.end))
    var x_min = mesh_aabb.position[0]
    var x_max = mesh_aabb.end[0]
    var y_min = mesh_aabb.position[2]
    var y_max = mesh_aabb.end[2]
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


##############################################################################
# Signal Handlers
##############################################################################
# Called when the node enters the scene tree for the first time.
func _ready():
    if DEBUG:
      m_logger.set_current_level = LogStream.LogLevel.DEBUG
    m_camera_gimbal = $CameraGimbal
    m_camera_gimbal.set_top_view()

func _child_entered_tree(n):
    _evaluate_child_size(n)
    #_recalculate_camera_pos()
    m_camera_gimbal.set_bound_size(m_max_size)


func _child_exiting_tree(n):
    m_max_size = Vector2(1, 1)
    for c in get_children():
        if c == n:
            continue
        if c is MeshInstance3D:
            _evaluate_child_size(c)
    m_camera_gimbal.set_bound_size(m_max_size)
