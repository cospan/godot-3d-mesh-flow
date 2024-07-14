#extends TextureRect
extends SubViewportContainer

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("SVPContainer", LogStream.LogLevel.INFO)
var m_mesh_viewer = null
var m_sub_viewport = null
var m_root = null
var m_parent = null
var m_siblings = []

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################


##############################################################################
# Private Functions
##############################################################################

# Called when the node enters the scene tree for the first time.
func _ready():
    m_logger.debug("Ready Entered!")
    resized.connect(on_resize)
    #item_rect_changed.connect(on_item_rect_changed)
    m_sub_viewport = $SVP
    m_mesh_viewer = $SVP/MapView
    m_parent = get_parent().get_parent()
    m_root = m_parent.get_parent()
    var kids = m_parent.get_children()
    for k in kids:
        if k != get_parent():
            m_siblings.append(k)

    m_logger.debug("Siblings: %s" % str(m_siblings))

    m_root.resized.connect(on_root_resize)
    m_parent.resized.connect(on_parent_resize)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func on_resize():
    m_logger.debug("On Resized: New Size: %s" % str(size))
    m_sub_viewport.size = size
    m_logger.debug("New Canvas Position: %s" % str(m_sub_viewport.canvas_transform.origin))

func on_parent_resize():
    m_logger.debug("On Parent ItemRect Changed: New Size: %s" % str(size))
    m_logger.debug("Parent Position: %s" % str(m_parent.position))
    if m_parent.position.x < 0:
        # Find the difference and resize the m_mesh_viewport so that the position is 0
        #m_sub_viewport.size.x += m_parent.position.x
        var x_size = m_root.size.x
        for s in m_siblings:
            x_size -= s.size.x
        m_sub_viewport.size.x = x_size
        size.x = x_size

        m_parent.position.x = 0
        m_parent.size.x = m_root.size.x

    if m_parent.position.y < 0:
        var y_size = m_root.size.y
        for s in m_siblings:
            y_size -= s.size.y
        m_sub_viewport.size.y = y_size
        size.y = y_size

        m_parent.position.y = 0
        m_parent.size.y = m_root.size.y


func on_root_resize():
    m_logger.debug("On Root Resized: New Size: %s" % str(m_root.size))
    #m_parent.set_size(m_root.size)
    if m_parent.position.x < 0:
        # Find the difference and resize the m_mesh_viewport so that the position is 0
        #m_sub_viewport.size.x += m_parent.position.x
        var x_size = m_root.size.x
        for s in m_siblings:
            x_size -= s.size.x
        m_sub_viewport.size.x = x_size
        size.x = x_size

        m_parent.position.x = 0
        m_parent.size.x = m_root.size.x

    if m_parent.position.y < 0:
        var y_size = m_root.size.y
        for s in m_siblings:
            y_size -= s.size.y
        m_sub_viewport.size.y = y_size
        size.y = y_size

        m_parent.position.y = 0
        m_parent.size.y = m_root.size.y



