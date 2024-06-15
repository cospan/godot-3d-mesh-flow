extends Node3D

##############################################################################
# Signals
##############################################################################
signal texture_baked(image:Image)
signal texture_finished

##############################################################################
# Exports
##############################################################################

#XXX: Change this to a mesh
var object : Node3D
var m_mesh_instance : MeshInstance3D

var m_viewport : SubViewport
var m_camera : Camera3D
var m_capture_flag = false
var m_transmit_flag = false
var m_rotation_angle = 0.0
var m_output_texture = null

func _ready():
    m_viewport = $SubViewport

func start_preview_capture(_mesh_instance, _size:Vector2i):
    m_viewport.size = _size
    m_mesh_instance = _mesh_instance
    m_capture_flag = true
    #var del_childrens = []
    #for child in m_viewport.get_children():
    #    if child == m_camera:
    #        continue
    #    del_childrens.append(child)
    #
    #for child in del_childrens:
    #    child.queue_free()

    m_viewport.add_child(m_mesh_instance)
    _center_object_to_camera()

    refresh()

func get_preview_texture() ->ImageTexture:
    return m_output_texture.duplicate()

func _center_object_to_camera():
    var aabb = m_mesh_instance.get_aabb()
    var ofs = aabb.get_center()
#	aabb.position -= ofs # Center AABB to 0

    # Optional: Rotate the object (just for fun)
    var xform = Transform3D()
    xform.basis = Basis().rotated(Vector3(0, 1, 0), -PI * 0.125)
    xform.basis = Basis().rotated(Vector3(1, 0, 0), PI * 0.125) * xform.basis;
    var rot_aabb = xform * aabb

    # Scale the object to x,y component fill the camera frustum
    var m = max(rot_aabb.size.x, rot_aabb.size.y)
    #m = 1.0 / (0.5 * m)
    #m *= 0.5
    m *= 1.5
    xform.basis = xform.basis.scaled(Vector3(m, m, m))

    # Center the object
    xform.origin = -(xform.basis * ofs)
    xform.origin.z -= (rot_aabb.size.z-ofs.z)  * 2.0
    m_mesh_instance.global_transform = xform

# Instantiate the scene and center the object to camera
func refresh():
    pass

func _process(_delta):
    # 0 is the render frame. 1: frame has been rendered, emit the signal
    if m_capture_flag:
        m_capture_flag = false
        m_transmit_flag = true
    elif m_transmit_flag:
        m_output_texture = ImageTexture.create_from_image(m_viewport.get_texture().get_image())
        m_viewport.remove_child(m_mesh_instance)
        m_mesh_instance.queue_free()
        m_transmit_flag = false
        texture_finished.emit()
