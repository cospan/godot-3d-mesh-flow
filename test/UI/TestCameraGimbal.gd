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
var m_logger = LogStream.new("Test Camera Gimbal", LogStream.LogLevel.DEBUG)

##############################################################################
# Scenes
##############################################################################
var m_gimbal = null

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################

##############################################################################
# Private Functions
##############################################################################

##############################################################################
# Signal Handlers
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    m_gimbal = $CameraGimbal
    for c in get_children():
        m_logger.debug("Child: %s" % str(c))
        if c is Node3D:
            m_logger.debug("Found Node3D: %s" % str(c))
            for n in c.get_children():
                if n is MeshInstance3D:
                    m_logger.debug("Found MeshInstance3D: %s" % str(n))
                    var static_body = StaticBody3D.new()
                    var collision_shape = CollisionShape3D.new()
                    var box_shape = BoxShape3D.new()
                    box_shape.size = n.mesh.get_aabb().size
                    collision_shape.shape = box_shape
                    n.add_child(static_body)
                    static_body.add_child(collision_shape)
                    static_body.input_event.connect(func(_camera, _event, _pos, _normal, _shape_idx):  \
                                            if _event is InputEventMouseButton and _event.pressed: \
                                                _on_node_clicked(_event, c))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass


func _on_node_clicked(event, target):
    m_logger.debug("Mesh Clicked: %s" % str(target))
    m_gimbal.set_target(target)
    get_viewport().set_input_as_handled()
