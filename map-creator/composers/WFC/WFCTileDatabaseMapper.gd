extends WFCMapper2D

class_name WFCTileDatabaseMapper
##############################################################################
# Description
##############################################################################
## Mapper allows the algorithm to access a map node as something like a
## 2D-array of numbers.
##
## We need to be able to convert the tiles and their rotation as a number
## I think our database will already do this for us

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("Mappder 2D DB", LogStream.LogLevel.DEBUG)
var m_attribute_dict:Dictionary = {}
var m_id_dict:Dictionary = {}
var m_tile_dict:Dictionary = {}
var m_subcomposer_id = "WFC"
var m_modifiers = {}
var m_mesh_layer = 1
var m_mesh_mask = 1
## Flags ##

##############################################################################
# Scenes
##############################################################################
var m_map_db_adapter = null
var m_tile_db_adapter = null

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################
func set_subcomposer_id(id: String):
    m_subcomposer_id = id

func set_mesh_layer_and_mask(layer: int, mask: int):
    m_mesh_layer = layer
    m_mesh_mask = mask

func set_modifiers(modifiers: Dictionary):
    m_modifiers = modifiers

func set_map_db_adapter(adapter: Node):
    m_map_db_adapter = adapter

func set_tile_db_adapter(adapter: Node):
    m_tile_db_adapter = adapter

### From Base Class ###

## Populate the attribute dictionary
func learn_from(_map: Node):
    m_attribute_dict = {}
    m_id_dict = {}
    # Read the map and populate the attribute dictionary
    # The attribute dictionary maps the tile ID and the rotation to a number

    # Get the tile dictionary from m_tile_db_adapter
    m_tile_dict = m_tile_db_adapter.get_module_dict()

    # iterate through the tiles
    for module in m_tile_dict:
        # Go through the tiles and rotate create an attribute for each rotation
        # 0, 90, 180, 270
        var attrs:Vector2i
        attrs = Vector2i(m_tile_dict[module]["id"], 0)
        m_id_dict[m_attribute_dict.size()] = {}
        m_id_dict[m_attribute_dict.size()]["attr"] = attrs
        m_id_dict[m_attribute_dict.size()]["name"] = module
        m_attribute_dict[attrs] = m_attribute_dict.size()
        attrs = Vector2i(m_tile_dict[module]["id"], 90)
        m_id_dict[m_attribute_dict.size()] = {}
        m_id_dict[m_attribute_dict.size()]["attr"] = attrs
        m_id_dict[m_attribute_dict.size()]["name"] = module
        m_attribute_dict[attrs] = m_attribute_dict.size()
        attrs = Vector2i(m_tile_dict[module]["id"], 180)
        m_id_dict[m_attribute_dict.size()] = {}
        m_id_dict[m_attribute_dict.size()]["attr"] = attrs
        m_id_dict[m_attribute_dict.size()]["name"] = module
        m_attribute_dict[attrs] = m_attribute_dict.size()
        attrs = Vector2i(m_tile_dict[module]["id"], 270)
        m_id_dict[m_attribute_dict.size()] = {}
        m_id_dict[m_attribute_dict.size()]["attr"] = attrs
        m_id_dict[m_attribute_dict.size()]["name"] = module
        m_attribute_dict[attrs] = m_attribute_dict.size()


## Returns rect of target map that contains all non-empty cells.
func get_used_rect(_map: Node) -> Rect2i:
    return m_map_db_adapter.get_used_rect_2d()

## Read cell from map and return a mapped code.
## [br]
## Returns a negative value if cell is empty or mapping for the cell is missing.
func read_cell(_map: Node, _coords: Vector2i) -> int:
    var module_dict = m_map_db_adapter.get_module_at_pos(Vector2i(_coords.x, _coords.y))
    if module_dict:
        var attrs:Vector2i
        var module_name = module_dict["module_name"]
        attrs = Vector2i(m_tile_dict[module_name]["id"], module_dict["rot_y_90_cw"])
        return m_attribute_dict[attrs]
    return -1

## Read metadata attribute values associated with given cell type.
## [br]
## May return array of multiple values if cell type consists of multiple objects having metadata.
## E.g. combinations of different tiles in multi-layer tilemap.
func read_tile_meta(_tile_id: int, _meta_name: String) -> Array:
    var retval = []
    var attr = m_id_dict[_tile_id]["attr"]
    var _tile = attr.x
    var module_dict = m_map_db_adapter.get_module_at_pos(Vector2i(attr.x, attr.y))
    if len(module_dict) == 0:
        return retval
    if not module_dict.has("metadata"):
        return retval
    if  module_dict["metadata"].has(_meta_name):
        retval.append(module_dict["metadata"][_meta_name])
    return retval

## Reads meta of given tile (see [method read_tile_meta]) and converts it to a single boolean value.
## [br]
## Returns [code]true[/code] iff there is at least one truthy meta value.
func read_tile_meta_boolean(tile: int, meta_name: String) -> bool:
    for v in read_tile_meta(tile, meta_name):
        if v:
            return true

    return false

## Name of a metadata attribute/custom data layer (as interpreted by [method read_tile_meta]) used
## to read tile probabilities.

## Read probability value assigned to given tile type.
## [br]
## By default uses values from metadata attribute using name from probability_meta_key property.
## Sub-classes may override this behavior.
func read_tile_probability(tile: int) -> float:
    if tile < 0:
        return 0.0

    var probability := 1.0

    for p in read_tile_meta(tile, probability_meta_key):
        probability *= p

    return probability

## Write a cell to map.
## [br]
## [param _code] should be inside acceptable range for mapped codes.
func write_cell(_map: Node, _coords: Vector2i, _code: int):
    if _code == -1:
        m_logger.warn("WFC Solution Failed!")
        return
    m_map_db_adapter.insert_module( false,
                                    m_subcomposer_id,
                                    m_id_dict[_code]["name"],
                                    _coords,
                                    1.0,
                                    0,
                                    m_id_dict[_code]["attr"].y,
                                    0,
                                    0,
                                    0,
                                    {"layer": m_mesh_layer, "mask": m_mesh_mask},)

## Returns number of cell types known by the mapper.
func size() -> int:
    #var s = m_map_db_adapter.get_pos_dict().size()
    #return s
    return m_attribute_dict.size()

## Check if this mapper is capable of working with given map node.
func supports_map(_map: Node) -> bool:
    # We don't really use the _map variable, so just return true
    return true

## Reset state (everything learned in [method learn_from] calls) of this mapper.
func clear():
    m_map_db_adapter.remove_all_composer_modules(m_subcomposer_id)

## Return true if this mapper is ready to read/write a map.
func is_ready() -> bool:
    # We're always ready
    return true


##############################################################################
# Private Functions
##############################################################################

##############################################################################
# Signal Handlers
##############################################################################

func _ready():
    m_logger.debug("Ready Entered!")

func _process(_delta):
    pass
