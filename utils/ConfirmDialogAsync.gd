class_name ConfirmationDialogAsync extends ConfirmationDialog

##############################################################################
# Signals
##############################################################################

signal finished

##############################################################################
# Members
##############################################################################

var m_result = false

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
    confirmed.connect(_on_ConfirmationDialog_confirmed)
    canceled.connect(_on_ConfirmationDialog_rejected)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

func result() -> bool:
    return m_result

func _on_ConfirmationDialog_confirmed():
    m_result = true
    emit_signal("finished", true)
    hide()

func _on_ConfirmationDialog_rejected():
    m_result = false
    emit_signal("finished", false)
    hide()
