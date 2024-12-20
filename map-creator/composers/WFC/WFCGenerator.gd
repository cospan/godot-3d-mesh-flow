#class_name WFC2DGenerator
## Generates content of a map (Database) using WFC algorithm.
extends Node
class_name WFCGenerator

##############################################################################
# Signals
##############################################################################
## Emited when the generator starts generating map.
signal started

## Emitted when generation is completed.
signal done

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("WFC Generator", LogStream.LogLevel.DEBUG)
var m_runner: WFCSolverRunner = null
var m_mapper: WFCMapper2D = null
var m_modifiers = {}
var m_map_db_adapter = null
var m_tile_db_adapter = null
var m_target_node = null
var m_subcomposer_id = "WFC"
var m_wfc_step_enabled = false

## Flags ##

##############################################################################
# Scenes
##############################################################################

##############################################################################
# Exports
##############################################################################

@export var MESH_LAYER:int = 1
@export var MESH_MASK:int = 1

## A tile database that contains the tiles to be sed by WFC algorithm.
@export_global_file("res://test/wfc/tile_database.db")
var tile_db_target: String

## A map where the WFC will store the results, this will be generated
# by the WFC algorithm if it does not exist, if it does it will initialize the
# WFC algorithm with the map
@export_global_file("res://test/wfc/map_database.db")
var map_db_target: String

## flag to indicate if the map database should be cleared before running the WFC
@export var clear_map_db: bool = false

## Rect of a map that will be filled.
## [br]
## Interpretation of this rect may depend on [WFCMapper2D] used.
## E.g. [WFCGridMapMapper2D] may use different planes with different offsets.
@export var rect: Rect2i = Rect2i(0, 0, 10, 10)

## m_rules that will be used.
## [br]
## If not specified, default m_rules will be created.
@export
@export_category("Rules")
var m_rules: WFCRules2D = WFCRules2D.new()

## Settings for a [WFCSolver].
@export
var m_solver_settings: WFCSolverSettings = WFCSolverSettings.new()

## What preconditions ([WFC2DPrecondition]) will be used.
## [br]
## If not set, a [WFC2DPreconditionReadExistingSettings] will be created and thus WFC will read
## existing tiles from [member target] map.
## If that's not necessary - set a [WFC2DPrecondition2DNullSettings] here.
@export
var null_precondition: WFC2DPrecondition2DNullSettings

## Settings for multithreaded solver runner.
## [br]
## Relevant iff [member use_multithreading] is [code]true[/code].
@export
@export_category("Runner")
var multithreaded_runner_settings: WFCMultithreadedRunnerSettings = WFCMultithreadedRunnerSettings.new()

## Settings for main thread solver runner.
## [br]
## Relevant iff [member use_multithreading] is [code]false[/code].
@export
var main_thread_runner_settings: WFCMainThreadRunnerSettings = WFCMainThreadRunnerSettings.new()

## If enabled, solver(s) will run on separate thread(s).
## Otherwise, there will be only one solver running on main thread, bit by bit every frame.
## [br]
## It's preferrable to use separate thread(s) in almost all cases.
## However, in some cases WFC may fail and/or produce invalid results when running in multiple
## threads.
## In such cases, it may make sense to still use multithreading but set
## [member WFCMultithreadedRunnerSettings.max_threads] in [member multithreaded_runner_settings] to
## [code]1[/code].
@export
var use_multithreading: bool = false

## If enabled, the generator will start WFC as soon as it is ready (i.e. literally in
## [method Node._ready]).
@export
@export_category("Behavior")
var start_on_ready: bool = true

## If enabled, current generation state will be rendered to [member target] map every frame while
## generation is in progress.
## [br]
## This is mostly useful for demos.
## In real game the map most likely won't be visible before it is generated completely, so updating
## it every frame is a waste of resources.
## [br]
## Even if this flag is disabled, generator [b]will[/b] render some intermediate results when
## running in multithreaded mode.
@export
var render_intermediate_results: bool = false

## If enabled, some debug information about m_rules will be printed to console.
@export
@export_category("Debug mode")
var print_rules: bool = false


##############################################################################
# Public Functions
##############################################################################

func set_subcomposer_id(_id: String):
    m_subcomposer_id = _id

func set_layer_and_mask(_layer: int, _mask: int):
    MESH_LAYER = _layer
    MESH_MASK = _mask
    if m_mapper != null:
        m_mapper.set_mesh_layer_and_mask(MESH_LAYER, MESH_MASK)

func set_step_enable(_enable: bool):
    m_wfc_step_enabled = _enable

## Starts generation.
## [br]
## Should be called at most once.
## [br]
## Should not be called manually when [member start_on_ready] is [code]true[/code].
func start():

    m_logger.debug("Starting WFC generation")
    assert(m_runner == null)
    assert(rect.has_area())

    if not m_rules.is_ready():
        m_logger.debug("Rules are not ready, learning from scratch")

        assert(m_map_db_adapter != null, "Map Database Adapter is null")
        assert(m_tile_db_adapter != null, "Tile Database Adapter is null")


        #assert(positive_sample != null)

        #var positive_sample_node: Node = get_node(positive_sample)
        #assert(positive_sample_node != null)

        if m_rules == null:
            m_rules = WFCRules2D.new()
        else:
            m_rules = m_rules.duplicate(false) as WFCRules2D

            assert(m_rules != null)

        if m_rules.mapper == null:
            #m_rules.mapper = _create_mapper(target_node)
            m_mapper = WFCTileDatabaseMapper.new()
            m_mapper.set_subcomposer_id(m_subcomposer_id)
            m_mapper.set_mesh_layer_and_mask(MESH_LAYER, MESH_MASK)
            m_mapper.set_modifiers(m_modifiers)
            m_mapper.set_map_db_adapter(m_map_db_adapter)
            m_mapper.set_tile_db_adapter(m_tile_db_adapter)
            m_mapper.learn_from(null)
            m_rules.mapper = m_mapper

        #if not m_rules.mapper.is_ready():
        #    #m_rules.mapper.learn_from(positive_sample_node)
        #    m_rules.mapper.learn_from(null)
        #m_rules.learn_from(positive_sample_node)
        m_rules.learn_from(null)

        #if m_rules.complete_matrices and negative_sample != null and not negative_sample.is_empty():
        #    var negative_sample_node: Node = get_node(negative_sample)

        #    if negative_sample_node != null:
        #        m_rules.learn_negative_from(negative_sample_node)

        if print_rules and OS.is_debug_build():
            print_debug('Rules learned:\n', m_rules.format())

            print_debug('Influence range: ', m_rules.get_influence_range())

    m_logger.debug("Creating problem and precondition")
    var problem_settings: WFC2DProblem.WFC2DProblemSettings = WFC2DProblem.WFC2DProblemSettings.new()

    problem_settings.rules = m_rules
    problem_settings.rect = rect

    var precondition: WFC2DPrecondition = _create_precondition(problem_settings, m_target_node)

    started.emit()

    # TODO: Call this in separate thread if long-running generators will be used to generate preconditions
    precondition.prepare()

    var problem: WFC2DProblem = _create_problem(problem_settings, m_target_node, precondition)

    m_logger.debug("Starting solver")
    m_runner = _create_runner()

    m_logger.debug("Starting problem")
    m_runner.start(problem)

    m_runner.all_solved.connect(func(): done.emit())
    m_runner.sub_problem_solved.connect(_on_solved)
    m_runner.partial_solution.connect(_on_partial_solution)

## Returns generation progress.
## [br]
## Returned value is in range between [code]0.0[/code] and [code]1.0[/code] (both inclusive).
## Just like in [method WFCSolverRunner.get_progress].
## [br]
## Returns [code]0.0[/code] if generation was not yet started.
func get_progress() -> float:
    if m_runner == null:
        return 0

    return m_runner.get_progress()

## Returns [code]true[/code] iff any solver is currently running.
func is_running() -> bool:
    if m_runner == null:
        return false

    return m_runner.is_running()

## Resets this generator to it's initial state.
## [br]
## Stops any running solver(s), if any.
func reset():
    if m_runner != null:
        if m_runner.is_running():
            m_runner.interrupt()
        m_runner = null

func validate_inputs() -> bool:
    if m_map_db_adapter == null:
        m_logger.error("Map Database Adapter is null")
        return false
    if m_tile_db_adapter == null:
        m_logger.error("Tile Database Adapter is null")
        return false
    if rect == null:
        m_logger.error("Rect is null")
        return false
    if not rect.has_area():
        m_logger.error("Rect has no area")
        return false
    m_logger.debug("All inputs are valid")
    return true

##############################################################################
# Private Functions
##############################################################################
func _create_runner() -> WFCSolverRunner:
    if use_multithreading:
        var res: WFCMultithreadedSolverRunner = WFCMultithreadedSolverRunner.new()

        if multithreaded_runner_settings != null:
            res.runner_settings = multithreaded_runner_settings

        res.solver_settings = m_solver_settings
        return res
    else:
        var res: WFCMainThreadSolverRunner = WFCMainThreadSolverRunner.new()

        if main_thread_runner_settings != null:
            res.runner_settings = main_thread_runner_settings

        res.solver_settings = m_solver_settings
        return res

func _create_precondition(problem_settings: WFC2DProblem.WFC2DProblemSettings, map: Node) -> WFC2DPrecondition:
    var settings: WFC2DPrecondition2DNullSettings = self.null_precondition

    if settings == null:
        settings = WFC2DPreconditionReadExistingSettings.new()

    var parameters: WFC2DPrecondition2DNullSettings.CreationParameters = WFC2DPrecondition2DNullSettings.CreationParameters.new()

    parameters.target_node = map
    parameters.problem_settings = problem_settings
    parameters.generator_node = self

    return settings.create_precondition(parameters)

func _create_problem(
    settings: WFC2DProblem.WFC2DProblemSettings,
    map: Node,
    precondition: WFC2DPrecondition
) -> WFC2DProblem:
    return WFC2DProblem.new(settings, map, precondition)

func _exit_tree():
    if m_runner != null:
        m_runner.interrupt()
        m_runner = null



##############################################################################
# Signal Handlers
##############################################################################

func _on_solved(problem: WFC2DProblem, state: WFCSolverState):
    if state != null:
        problem.render_state_to_map(state)

func _on_partial_solution(problem: WFC2DProblem, state: WFCSolverState):
    if not render_intermediate_results:
        return

    _on_solved(problem, state)


func _ready():
    #m_map_db_adapter = $MapDatabaseAdapter
    #m_target_node = $Node3DDisplay
    #if start_on_ready:
    #    start()
    m_modifiers = {
        #"color":mesh_color,
        "layer":MESH_LAYER,
        "mask":MESH_MASK
        #"priority":mesh_priority
    }
    pass

func _process(_delta):
    if not m_wfc_step_enabled:
        step()

func step():
    if m_runner != null and m_runner.is_running():
        m_runner.update()
