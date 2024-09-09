extends Node3D

##############################################################################
# Signals
##############################################################################
signal null_selected

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
var m_bound_rect = Rect2(0, 0, 1, 1)

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

func move_target_to(target:Node3D, dest_pos:Vector3):
    m_logger.debug("Moving Target: %s" % str([target, dest_pos]))
    target.translate(Vector3(dest_pos.x, target.position.y, dest_pos.z))

func resized(_size:Vector2):
    pass

##################
# GUI Functions
##################

##############################################################################
# Private Functions
##############################################################################

func _calculate_view_rect(n):
    var m = n.mesh
    var mesh_aabb = m.get_aabb()
    #m_logger.debug("Evaluate Child with AABB: %s" % str(mesh_aabb))
    var mesh_g_min = Vector3(mesh_aabb.position.x, 0, mesh_aabb.position.z)
    var mesh_g_max = Vector3(mesh_aabb.end.x, 0, mesh_aabb.end.z)
    #m_logger.debug("  Global Position: %s" % str([mesh_g_min, mesh_g_max]))
    var x_min = mesh_g_min.x
    var x_max = mesh_g_max.x
    var y_min = mesh_g_min.z
    var y_max = mesh_g_max.z
    m_bound_rect.position = Vector2(x_min, y_min)
    var end_pos = m_bound_rect.end
    var start_pos = m_bound_rect.position
    if x_min < start_pos.x:
        start_pos.x = x_min
    if x_max > end_pos.x:
        end_pos.x = x_max

    if y_min < start_pos.y:
        start_pos.y = y_min
    if y_max > end_pos.y:
        end_pos.y = y_max

    m_bound_rect.position = start_pos
    m_bound_rect.size = end_pos - start_pos


##############################################################################
# Signal Handlers
##############################################################################
# Called when the node enters the scene tree for the first time.
func _ready():
    if DEBUG:
      m_logger.set_current_level = LogStream.LogLevel.DEBUG
    m_camera_gimbal = $CameraGimbal
    m_camera_gimbal.null_selected.connect(emit_null_selected)
    m_camera_gimbal.set_top_view()
    child_entered_tree.connect(_child_entered_tree)
    child_exiting_tree.connect(_child_exiting_tree)

func emit_null_selected():
    emit_signal("null_selected")

func _child_entered_tree(n):
    #m_logger.debug("+++++++Child Entered Tree: %s" % str(n))
    _calculate_view_rect(n)
    m_camera_gimbal.set_bound_rect(m_bound_rect)

func _child_exiting_tree(n):
    #m_logger.debug("-------Child Exiting Tree: %s" % str(n))
    m_bound_rect = Rect2(0, 0, 1, 1)
    for c in get_children():
        if c == n:
            continue
        if c is MeshInstance3D:
            _calculate_view_rect(c)
    m_camera_gimbal.set_bound_rect(m_bound_rect)
