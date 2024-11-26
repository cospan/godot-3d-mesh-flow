extends Resource
## Contains serializable settings for creation of a WFC2DPrecondition.
##
## This base class creates an empty precondition that does not limit a content of any cells.
## For custom precondition classes a corresponding [WFC2DPrecondition2DNullSettings] subclasses should
## exist.
## [br]
## This class is named [code]WFC2DPrecondition2DNullSettings[/code], not
## [code]WFC2DPrecondition2DSettings[/code] to make it clearer to node inspector users that it will
## create a "null" (empty, default) precondition.
## If GdScript supported interfaces or abstract classes then there would be an interface/abstract
## class [code]IWFC2DPrecondition2DSettings[/code] and [code]WFC2DPrecondition2DNullSettings[/code]
## extending/implementing it along with other concreate classes.
## But with GdScript all other precondition settings classes should extend
## [WFC2DPrecondition2DNullSettings].
class_name WFC2DPrecondition2DNullSettings

## Parameters passed to [method WFC2DPrecondition2DNullSettings.create_precondition].
class CreationParameters:
	## Settings of a [WFC2DProblem] that will use the created precondition.
	var problem_settings: WFC2DProblem.WFC2DProblemSettings

	## Target node of a [WFC2DProblem] that will use the created precondition.
	var target_node: Node

	## A [WFC2DGenerator] that is creating this precondition.
	#XXX: If we require a WFC2DGenerator then we can only use the Grid and Tilemap generators
	# Because if I try and instantiate a WFC2DGenerator in the editor, it will throw an error
	# saying that the class is already declared.
	#var generator_node: WFC2DGenerator
	var generator_node: Node

## Instantiates a precondition using settings from this object.
func create_precondition(parameters: CreationParameters) -> WFC2DPrecondition:
	return WFC2DPrecondition.new()
