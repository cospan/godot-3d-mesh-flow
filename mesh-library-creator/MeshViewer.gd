extends Node3D

##############################################################################
# Signals
##############################################################################

signal module_clicked

##############################################################################
# Constants
##############################################################################
const DEFAULT_ROTATION_STEP = 0.01
const CAMERA_LERP_SPEED = 1.0
const DEFAULT_CAMERA_HEIGHT = 10.0
const MODULE_SPACING = 2.0

enum MODE_T {SINGLE_MODE, ALL_MODE, FACE_MODE}

# 3D Visual Variables

var MODE:MODE_T = MODE_T.SINGLE_MODE

##############################################################################
# Members
##############################################################################

var m_bounding_box = null
var m_test_pos = Vector3(0, 1.5, -2)
var m_bb_transparent = 0.5
var m_bb_transparent_direction = 1
var m_bb_transparent_step = 0.01
var m_bb_rotation = 0.0
var m_bb_rotation_step = DEFAULT_ROTATION_STEP
var m_selected_module = null
var m_modules = {}
var m_manual_rotation = Vector3(0, 0, 0)
var m_camera = null
#var m_camera_single_pos = Vector3(0, 2, 0)
var m_camera_single_pos = Vector3(0, 1, 2)
#var m_camera_single_pos = Vector3(0, 0.5, -2)
var m_camera_single_rotation = Vector3(-0.52, 0, 0)
var m_camera_dest_pos = m_camera_single_pos
var m_camera_dest_rot = m_camera_single_rotation

var m_module_bounds = Vector2(-1, -1)
var m_camera_top_pos = Vector3(0, DEFAULT_CAMERA_HEIGHT, 0)
var m_camera_top_rotation = Vector3(-1.5708, 0, 0)
var m_face_mesh_dict = {}

var DEBUG = false
var m_logger = LogStream.new("Mesh Viewer", LogStream.LogLevel.DEBUG)
#var m_logger = LogStream.new("Mesh Viewer", LogStream.LogLevel.INFO)

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################


##################
# GUI Functions
##################
func create_bounding_box(mesh:Mesh, tran:Vector3 = Vector3(0, 0, 0)):
    var bb_visible = false
    if m_bounding_box:
        bb_visible = m_bounding_box.visible
        remove_child(m_bounding_box)
        m_bounding_box = null
    var mesh_aabb = mesh.get_aabb()
    var m = BoxMesh.new()
    m.size = mesh_aabb.size
    m_bounding_box = MeshInstance3D.new()
    m_bounding_box.set_mesh(m)
    m_bounding_box.position = tran + Vector3(0, mesh_aabb.size.y / 2, 0)
    m_bounding_box.transparency = m_bb_transparent
    m_bounding_box.visible = bb_visible
    add_child(m_bounding_box)

func set_modules_with_bounds(_modules:Dictionary, _bounds:Vector2):
    m_logger.debug ("Set module dict")
    if len(m_modules) > 0:
        for m in m_modules:
            m_modules[m].queue_free()

    m_modules = {}
    m_module_bounds = _bounds
    for m in _modules:
        m_modules[m] = _modules[m].duplicate()
    configure_all_modules()

func configure_all_modules():
    var square_size = ceili(sqrt(len(m_modules)))
    m_logger.debug ("Square size: ", square_size)
    var x_size = square_size * m_module_bounds.x * MODULE_SPACING * 0.5
    m_logger.debug ("X Size: ", x_size)
    var hyp_val = sqrt((x_size * x_size) + (x_size * x_size))
    m_logger.debug ("Hypotinus Value: ", hyp_val)
    var y_offset = DEFAULT_CAMERA_HEIGHT
    var theta = deg_to_rad(m_camera.fov * 0.5)
    m_logger.debug ("Theta: ", theta)
    y_offset = hyp_val / tan(theta)
    m_logger.debug ("Camera Y Offset: ", y_offset)

    for i in range(len(m_modules.keys())):
        var y = floori((float(i) / square_size)) * (m_module_bounds.y * MODULE_SPACING)
        var x = (i % square_size) * (m_module_bounds.x * MODULE_SPACING)
        #m_logger.debug ("X, Y: %s" % str([x, y]))

        var m = m_modules.keys()[i]
        m_modules[m].visible = true
        m_modules[m].position = Vector3(x, 0, y)

        var static_body = StaticBody3D.new()
        var collision_shape = CollisionShape3D.new()
        var box_shape = BoxShape3D.new()
        box_shape.size = m_modules[m].mesh.get_aabb().size
        collision_shape.shape = box_shape

        add_child(m_modules[m])
        m_modules[m].add_child(static_body)
        static_body.add_child(collision_shape)
        #static_body.input_event.connect(_on_module_input_event)
        static_body.input_event.connect(func(_camera, _event, _pos, _normal, _shape_idx):  \
                                            if _event is InputEventMouseButton and _event.pressed: \
                                                _on_module_clicked(m))

    #m_camera_top_pos += Vector3(float(square_size) / 2.0, 0, float(square_size) / 2.0)
    m_camera_top_pos = Vector3(square_size * MODULE_SPACING / 2.0, y_offset, square_size * MODULE_SPACING / 2.0)
    set_camera_top_view()

func recalculate_camera_pos():
    var square_size = ceili(sqrt(len(m_modules)))
    var y_offset = DEFAULT_CAMERA_HEIGHT
    var x_size = square_size * m_module_bounds.x * MODULE_SPACING * 0.5
    var hyp_val = sqrt((x_size * x_size) + (x_size * x_size))
    var theta = deg_to_rad(m_camera.fov * 0.5)
    y_offset = hyp_val / tan(theta)

    m_camera_top_pos = Vector3(square_size * MODULE_SPACING / 2.0, y_offset, square_size * MODULE_SPACING / 2.0)
    set_camera_top_view()

func _on_module_clicked(_module_name:String):
    m_logger.debug ("Module Clicked: ", _module_name)
    emit_signal("module_clicked", _module_name)

func view_all_modules():
    if m_selected_module == null:
        return

    m_selected_module.rotation = Vector3(0, 0, 0)
    m_selected_module = null
    m_camera_dest_pos = m_camera_top_pos
    m_camera_dest_rot = m_camera_top_rotation

#func select_face(_face_index:int, _face_hash_match_dict:Array):
#    m_logger.debug ("Face Selected with total hash matches: %s" % str([_face_index, len(_face_hash_match_dict)]))

func select_module(_mesh_name):
    if m_selected_module:
        m_selected_module.rotation = Vector3(0, 0, 0)
    if _mesh_name == null:
        view_all_modules()
    else:
        m_selected_module = m_modules[_mesh_name]
        set_camera_single_view()

func is_module_selected():
    return m_selected_module != null

func set_enable_rotation(_enable:bool):
    if _enable:
        m_bb_rotation_step = DEFAULT_ROTATION_STEP
    else:
        m_bb_rotation_step = 0.0

func set_manual_rotation(_rotation:Vector3):
    m_manual_rotation = _rotation

func set_camera_single_view():
    var pos = m_selected_module.position
    #pos.x -= m_module_bounds.x * MODULE_SPACING / 2.0

    m_camera_dest_pos = pos + m_camera_single_pos
    m_camera_dest_rot = m_camera_single_rotation

func set_camera_top_view():
    #m_camera.position = m_camera_top_pos
    #m_camera.rotation = m_camera_top_rotation
    m_camera_dest_pos = m_camera_top_pos
    m_camera_dest_rot = m_camera_top_rotation

##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    if DEBUG:
      m_logger.set_current_level = LogStream.LogLevel.DEBUG
    m_camera = $Camera
    m_camera_dest_pos = m_camera_top_pos
    m_camera_dest_rot = m_camera_top_rotation


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if m_selected_module == null:
        return

    if m_bb_rotation_step != 0.0:
        m_bb_rotation += m_bb_rotation_step
        m_selected_module.rotation = Vector3(0, m_bb_rotation, 0)
        if m_bounding_box:
            m_bounding_box.rotation = Vector3(0, m_bb_rotation, 0)
    else:
        m_selected_module.rotation_degrees = m_manual_rotation
        if m_bounding_box:
            m_bounding_box.rotation_degrees = m_manual_rotation

func _physics_process(_delta):
    if not m_camera:
        return
    m_camera.position = m_camera.position.lerp(m_camera_dest_pos, _delta * CAMERA_LERP_SPEED)
    m_camera.rotation = m_camera.rotation.lerp(m_camera_dest_rot, _delta * CAMERA_LERP_SPEED)


#func _input(_event):
#    m_logger.debug ("Input Event: ", _event)



#func _on_static_body_3d_input_event(camera, event, position, normal, shape_idx):
#    m_logger.debug ("Static Body Input Event: ", event)
#    pass # Replace with function body.
