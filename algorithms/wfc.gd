extends Node

##############################################################################
# Constants
##############################################################################
#XXX: This might need to be more flexible in the future
enum FACE_T {
    FRONT = 0,
    BACK = 1,
    TOP = 2,
    BOTTOM = 3,
    RIGHT = 4,
    LEFT = 5
}
enum VALID_FACE_T {
    FRONT = 0,
    BACK = 1,
    RIGHT = 4,
    LEFT = 5
}

var m_dir = [0, 1, 2, 3]
enum DIR_T {
    R = 0,
    B = 1,
    L = 2,
    T = 3
}

##############################################################################
# Signals
##############################################################################



##############################################################################
# Members
##############################################################################
var m_tile_map:Array
# Use this count to make sure we don't repeat entropy calculations
var m_propagation_count:int = 0
var m_tile_map_x:Array
var m_tile_dict:Dictionary
var m_sid_dict:Dictionary
var m_entropy_dict:Dictionary = Dictionary()
var m_soft_constraint_callback = null # A function that returns an array [tile name, rotation 0, 1, 2, 3]
var m_enable_edge:bool = false
var MAX_ENTROPY:int = -1
const WILD_TILE:int = 0
var m_logger = LogStream.new("WFC", LogStream.LogLevel.DEBUG)

##############################################################################
# Debug Members
##############################################################################

signal soft_constraint

##############################################################################
# WFC Public Functions
##############################################################################
func initialize(width:int, height:int, tile_dict:Dictionary, empty_tile_index:int = -1, enable_edge = true, soft_constraint_callback = null):
    # Create a tilemap
    m_enable_edge = enable_edge
    MAX_ENTROPY = len(tile_dict.keys())
    if empty_tile_index > -1:
        MAX_ENTROPY = MAX_ENTROPY - 1 # -1 because the first tile is the empty tile
    m_soft_constraint_callback = soft_constraint_callback
    m_tile_dict = tile_dict
    m_sid_dict = _invert_tile_dict(tile_dict)
    m_tile_map = Array()
    m_tile_map_x = Array()
    m_tile_map.resize(width)
    m_tile_map_x.resize(width)
    # How to make this seamlessly transition between 2D and 3D?

    for x in range(width):
        m_tile_map[x] = Array()
        m_tile_map_x[x] = Array()
        m_tile_map_x[x].resize(height)

        m_tile_map[x].resize(height)
        for y in range(height):
            # 2D Tilemap
            m_tile_map[x][y] = {"module": null, "valid_tiles":null, "rot_90_ccw": 0, "prop_count":0}
            m_tile_map_x[x][y] = null
            # Populate the entropy dictionary with the initial maximum entropy
            _initialize_tile_entropy(x, y)


#-----------------------------------------------------------------------------
# Every iteration analyze a tile, if there are no more tiles to analyze, return null
# If the user gives a priority tile, we will only analyze that tile otherwise
# we will analyze the tile with the lowest entropy
#
# 0 = Complete
# -1 = Contradiction
#-----------------------------------------------------------------------------
func step(priority_tile = null):
    # If a priority tile is given, we will only update that tile
    var tile_pos = priority_tile
    if priority_tile == null:
        tile_pos = _find_lowest_entropy_tile_pos()

    if tile_pos.x == -1 and tile_pos.y == -1:
        m_logger.debug("step: We are done, '_find_lowest_entropy_tile_pos' return (-1, -1)")
        # We're done, no more entries
        return 0

    var adjacent_tile_positions = _get_adjacent_tile_positions(tile_pos)
    var valid_tiles = null

    if m_tile_map[tile_pos.x][tile_pos.y]["valid_tiles"] == null:
        var adjacent_tile_sockets = _get_sockets_from_tile_positions(adjacent_tile_positions)
        valid_tiles = _get_valid_tiles_from_sockets(adjacent_tile_sockets)
    else:
        valid_tiles = m_tile_map[tile_pos.x][tile_pos.y]["valid_tiles"]

    if len(valid_tiles) == 0:
        return -1
        #assert (false, "Contradiction found, no valid tiles for tile at position: " + str(tile_pos))

    var collapsed_tile
    if m_soft_constraint_callback:
        collapsed_tile = m_soft_constraint_callback.call(valid_tiles)
    else:
        var _name = valid_tiles.keys()[randi() % len(valid_tiles)]
        collapsed_tile = [_name, valid_tiles[_name]]

    _collapse_tile(tile_pos, collapsed_tile[0], collapsed_tile[1])

    var adj_tile_pos = _propagate_entropy(tile_pos, adjacent_tile_positions)

    return tile_pos

func get_tile_map() -> Array:
    for x in range(len(m_tile_map)):
        for y in range(len(m_tile_map[x])):
            var tile = m_tile_map[x][y]
            var _name = tile["module"]
            var _face = m_tile_dict[_name]
            var _rot = tile["rot_90_ccw"]

    return m_tile_map_x

func get_tile_info(pos:Vector2i) -> Dictionary:

        var tile = m_tile_map[pos.x][pos.y]
        var _name = tile["module"]
        var _rot = tile["rot_90_ccw"]
        var index_of_tile = m_tile_dict.keys().find(_name)
        return {"name":_name, "index": index_of_tile, "rot":_rot}

func _collapse_tile(tile_pos, tile_name, rotation):
    # Update the entropy dictionary
    # Update the tile map
    m_tile_map[tile_pos.x][tile_pos.y]["module"] = tile_name
    m_tile_map[tile_pos.x][tile_pos.y]["rot_90_ccw"] = rotation
    m_tile_map[tile_pos.x][tile_pos.y]["valid_tiles"] = -1

func convert_expanded_module_to_module_dict(ename:String, efaces:Array) -> Dictionary:
    # Read in a single module, with the 'expanded' format and convert it to the 'module' format
    # every expanded module is named as follows: <module_name>_<reflection>
    # where reflection is one of: "", "_r_x", "_r_y", "_r_xy"
    # we need to convert this back to the original module name
    # we also need to convert the face indexes back to the original face indexes
    # we also need to convert the reflected flag back to the original reflected flag
    # we also need to convert the symmetric flag back to the original symmetric flag
    # we also need to convert the sid back to the original sid

    var module_name
    var faces = [null, null, null, null, null, null]


    if ename.find("_r_x") != -1:
        module_name = ename.replace("_r_x", "")
        faces[FACE_T.FRONT] = efaces[FACE_T.BACK].duplicate()
        faces[FACE_T.BACK] = efaces[FACE_T.FRONT].duplicate()
        faces[FACE_T.RIGHT] = efaces[FACE_T.LEFT].duplicate()
        faces[FACE_T.LEFT] = efaces[FACE_T.RIGHT].duplicate()
        faces[FACE_T.TOP] = efaces[FACE_T.TOP].duplicate()
        faces[FACE_T.BOTTOM] = efaces[FACE_T.BOTTOM].duplicate()

        # Check if the front is symmetric
        if not efaces[FACE_T.FRONT]["symmetric"]:
            faces[FACE_T.FRONT]["reflected"] = not efaces[FACE_T.FRONT]["reflected"]

        # Check if the back is symmetric
        if not efaces[FACE_T.BACK]["symmetric"]:
            faces[FACE_T.BACK]["reflected"] = not efaces[FACE_T.BACK]["reflected"]


    elif ename.find("_r_y") != -1:
        module_name = ename.replace("_r_y", "")
        faces[FACE_T.FRONT] = efaces[FACE_T.BACK].duplicate()
        faces[FACE_T.BACK] = efaces[FACE_T.FRONT].duplicate()
        faces[FACE_T.RIGHT] = efaces[FACE_T.RIGHT].duplicate()
        faces[FACE_T.LEFT] = efaces[FACE_T.LEFT].duplicate()
        faces[FACE_T.TOP] = efaces[FACE_T.TOP].duplicate()
        faces[FACE_T.BOTTOM] = efaces[FACE_T.BOTTOM].duplicate()

        # Check if the right side is symmetric
        if not efaces[FACE_T.RIGHT]["symmetric"]:
            faces[FACE_T.RIGHT]["reflected"] = not efaces[FACE_T.RIGHT]["reflected"]
        # Check if the left side is symmetric
        if not efaces[FACE_T.LEFT]["symmetric"]:
            faces[FACE_T.LEFT]["reflected"] = not efaces[FACE_T.LEFT]["reflected"]



    elif ename.find("_r_xy") != -1:
        module_name = ename.replace("_r_xy", "")
        faces[FACE_T.FRONT] = efaces[FACE_T.BACK].duplicate()
        faces[FACE_T.BACK] = efaces[FACE_T.FRONT].duplicate()
        faces[FACE_T.RIGHT] = efaces[FACE_T.LEFT].duplicate()
        faces[FACE_T.LEFT] = efaces[FACE_T.RIGHT].duplicate()
        faces[FACE_T.TOP] = efaces[FACE_T.TOP].duplicate()
        faces[FACE_T.BOTTOM] = efaces[FACE_T.BOTTOM].duplicate()

        if not efaces[FACE_T.FRONT]["symmetric"]:
            faces[FACE_T.FRONT]["reflected"] = not efaces[FACE_T.FRONT]["reflected"]
        if not efaces[FACE_T.BACK]["symmetric"]:
            faces[FACE_T.BACK]["reflected"] = not efaces[FACE_T.BACK]["reflected"]
        if not efaces[FACE_T.RIGHT]["symmetric"]:
            faces[FACE_T.RIGHT]["reflected"] = not efaces[FACE_T.RIGHT]["reflected"]
        if not efaces[FACE_T.LEFT]["symmetric"]:
            faces[FACE_T.LEFT]["reflected"] = not efaces[FACE_T.LEFT]["reflected"]
    else:
        module_name = ename
        faces = efaces.duplicate()

    return {module_name:faces}


##############################################################################
# WFC Utility Functions
##############################################################################
func _invert_tile_dict(tile_dict:Dictionary) -> Dictionary:
    var sid_dict = {}
    for m in tile_dict:
        for f in tile_dict[m]:
            var sid = tile_dict[m][f]["sid"]
            if tile_dict[m][f]["sid"] not in sid_dict:
                sid_dict[sid] = []
            sid_dict[sid].append([m, f])
    return sid_dict


#-----------------------------------------------------------------------------
# Entropy
#
# We have an 'entropy dictionary' where the keys of the dictionary are the
# calculated entropy and the values of the dictionary are the list of position
# that correspond with that entropy, this way we can quickly find the lowest
# entropy by sorting the list of keys. There is work when we need to find the
# entropy so we pay for this during propagation.
#
# because we are managing a dictionary we should wrap all 'entropy' related
# calls within functions in order to reduce the mismanagement of the data.
# As long as all entropy manipulation are in a few functions the dictionary
# should be maintainable.
#
# Initialize Tile Entropy
# Propagate Entropy
# Calculate Entropy
# Retrieve Entropy
# Update Entropy Dictionary
# Find Lowest Entropy Position
#
#-----------------------------------------------------------------------------

func _initialize_tile_entropy(x:int, y:int):
    __update_entropy_dict(Vector2i(x, y), -1, MAX_ENTROPY)

#XXX We need to somehow keep track of all the things we have evaluted so we don't infinitely evaluate them over and over again
func _propagate_entropy(tile_pos:Vector2i, adjacent_tile_entry = []):
    m_propagation_count += 1
    return __propagate_entropy(tile_pos, adjacent_tile_entry)

func __propagate_entropy(tile_pos:Vector2i, adjacent_tile_entry = []):
    m_propagation_count += 1

    # Determine if we already have a list of tiles to work on
    if len(adjacent_tile_entry) == 0:
        # We don't have a list, we need to get one
        adjacent_tile_entry = _get_adjacent_tile_positions(tile_pos)

    # Add all the positions to the found to the list of positions to evaluate
    var adjacent_tile_positions = []
    for adjacent_tile in adjacent_tile_entry:
        if m_tile_map[adjacent_tile[0].x][adjacent_tile[0].y]["prop_count"] == m_propagation_count:
            # We have already processed this tile
            continue

        m_tile_map[adjacent_tile[0].x][adjacent_tile[0].y]["prop_count"] = m_propagation_count
        adjacent_tile_positions.append(adjacent_tile[0])


    for adjacent_tile_pos in adjacent_tile_positions:
        var adjacent_tile = m_tile_map[adjacent_tile_pos.x][adjacent_tile_pos.y]
        var np = _evaluate_tile(adjacent_tile_pos)
        if np == null:
            continue
        __propagate_entropy(np)

    return null



func _evaluate_tile(tile_pos:Vector2i):
    var current_entropy = __get_tile_current_entropy(tile_pos)
    #XXX: When we actually collapse the module this will change the entropy,
    #  the 'new_entropy != current_entropy` will not allow us to update the
    # dictionary and the m_entropy_dict will be out of date, we might need to
    # address this when we collapse the tile... Effectively wouldn't this be
    # The same? Say the same value is retrieved and is calculated then we wouldn't
    # need to update the dictionary

    #if new_entropy == 1:
    #    return adjacent_tile_pos
    var new_entropy
    if m_tile_map[tile_pos.x][tile_pos.y]["module"] != null:
        new_entropy = -1 # Already collapsed
        m_tile_map[tile_pos.x][tile_pos.y]["valid_tiles"] = -1

    else:
        var adjacent_tile_positions = _get_adjacent_tile_positions(tile_pos)
        var adjacent_sockets = _get_sockets_from_tile_positions(adjacent_tile_positions)
        m_tile_map[tile_pos.x][tile_pos.y]["valid_tiles"] = _get_valid_tiles_from_sockets(adjacent_sockets)
        new_entropy = len(m_tile_map[tile_pos.x][tile_pos.y]["valid_tiles"])

    if new_entropy == current_entropy:
        # No change return null
        return null

    __update_entropy_dict(tile_pos, current_entropy, new_entropy)
    if (_propagate_entropy(tile_pos) != null):
        # We saw a change we need to propagate the entropy
        return tile_pos



func _find_lowest_entropy_tile_pos():
    var lowest_entropy = MAX_ENTROPY
    var lowest_entropy_pos = Vector2i(-1, -1)
    var keys = m_entropy_dict.keys()
    keys.sort()
    for key in keys:
        if key < lowest_entropy:
            lowest_entropy = key

    if lowest_entropy not in m_entropy_dict:
        return Vector2i(-1, -1)

    lowest_entropy_pos = m_entropy_dict[lowest_entropy].pop_back()
    if m_entropy_dict[lowest_entropy].size() == 0:
        m_entropy_dict.erase(lowest_entropy)
    return lowest_entropy_pos


# Support Functions
func __get_tile_current_entropy(tile_pos) -> int:
    if m_tile_map[tile_pos.x][tile_pos.y]["valid_tiles"] == null:
        return MAX_ENTROPY
    if typeof(m_tile_map[tile_pos.x][tile_pos.y]["valid_tiles"]) == TYPE_INT:
        return -1
    return len(m_tile_map[tile_pos.x][tile_pos.y]["valid_tiles"])

#XXX: if implementing an undo function this will need to be updated
func __update_entropy_dict(pos, current_entropy:int, new_entropy:int):
    if current_entropy in m_entropy_dict:
        m_entropy_dict[current_entropy].erase(pos)
        if len(m_entropy_dict[current_entropy]) == 0:
            m_entropy_dict.erase(current_entropy)
    if new_entropy == -1:
        # Collapsed Tile
        return
    if new_entropy in m_entropy_dict:
        m_entropy_dict[new_entropy].append(pos)
    else:
        m_entropy_dict[new_entropy] = Array()
        m_entropy_dict[new_entropy].append(pos)



#-----------------------------------------------------------------------------
# Adjacent Tile Functions
# The tile positions could also define the socket to be analyzed, this
# would reduce computation time
#
# Only working with 2D for now
#-----------------------------------------------------------------------------

func _get_adjacent_tile_positions(tile_pos) -> Array:
    var adjacent_positions = Array()
    # Do we need to worry about when 'x' == 0?
    if tile_pos.x > 0:
        # Get the Right Socket
        adjacent_positions.append([Vector2i(tile_pos.x - 1, tile_pos.y), DIR_T.R])    # We need to mirror of the face we are on
    if tile_pos.x < len(m_tile_map) - 1:
        # Get the left socket
        adjacent_positions.append([Vector2i(tile_pos.x + 1, tile_pos.y), DIR_T.L])
    if tile_pos.y > 0:
        # Get the Front Socket
        adjacent_positions.append([Vector2i(tile_pos.x, tile_pos.y - 1), DIR_T.B])
    if tile_pos.y < len(m_tile_map[0]) - 1:
        # Get the Back Socket
        adjacent_positions.append([Vector2i(tile_pos.x, tile_pos.y + 1), DIR_T.T])
    return adjacent_positions

func _get_sockets_from_tile_positions(adjacent_positions:Array) -> Array:
    # We can make this more flexible by finding the lengths of sockets from the tilemap

    var tile_sockets = [null, null, null, null]

    for adjacent_element in adjacent_positions:
        var pos = adjacent_element[0]
        var socket = adjacent_element[1]
        var adjacent_tile_module = m_tile_map[pos.x][pos.y]["module"]
        var adjacent_tile_rot = m_tile_map[pos.x][pos.y]["rot_90_ccw"]

        #XXX: need to apply rotation

        # Just working with 2D Positions right now
        if adjacent_tile_module == null:
            #Already defined above
            continue

        var dir_sr = (socket - adjacent_tile_rot) % 4
        dir_sr = m_dir[dir_sr]
        # Get socket for an adjacent tile
        var sockets = _get_wfc_tile_sockets(adjacent_tile_module)
        # Set only the valid sockets
        tile_sockets[socket] = sockets[dir_sr]
        #var tile_sockets[socket] = _get_wfc_tile_sockets(adjacent_tile_module, dir_sr)

    return tile_sockets

func _get_valid_tiles_from_sockets(sockets:Array) -> Dictionary:
    # XXX: instead of just returning the valid tiles return the valid tiles and rotation
    #var valid_tile_modules = m_tile_dict.keys()
    #var valid_tile_modules = m_tile_dict.keys()
    var tdict = {}
    for t in m_tile_dict.keys():
        tdict[t] = 0

    for i in range(len(sockets)):

        if sockets[i] == null:
            continue

        # Rotate the tiles so that the first non-null socket is at the front
        var s = sockets[i]
        sockets = sockets.slice(i) + sockets.slice(0, i)
        #var keys = valid_tile_modules.duplicate()
        var keys = m_tile_dict.keys()

        for key in keys:
            var ks = _get_wfc_tile_sockets(key)
            # Check if the first socket 's' is in the valid sockets
            if s not in ks:
                tdict.erase(key)
                #valid_tile_modules.erase(key)
                continue

            var tile_rot_index = ks.find(s)
            # rotate the tile sockets so that the first socket is at the front
            ks = ks.slice(tile_rot_index) + ks.slice(0, tile_rot_index)
            # Check if the sockets are valid
            var r = (tile_rot_index + i) % 4
            tdict[key] = 4 - r
            for k in range(len(ks)):
                #if ks[k] == null:
                if sockets[k] == null:
                    continue
                if ks[k] != sockets[k]:
                    #valid_tile_modules.erase(key)
                    tdict.erase(key)
                    break
        break

    return tdict



##############################################################################
# Tile Transform Functions
##############################################################################
func _dir_to_socket(d:DIR_T):
        match d:
            DIR_T.R:
                return VALID_FACE_T.RIGHT
            DIR_T.L:
                return VALID_FACE_T.LEFT
            DIR_T.T:
                return VALID_FACE_T.BACK
            DIR_T.B:
                return VALID_FACE_T.FRONT
        return null

func _socket_to_dir(s:VALID_FACE_T):
    match s:
        VALID_FACE_T.RIGHT:
            return DIR_T.R
        VALID_FACE_T.LEFT:
            return DIR_T.L
        VALID_FACE_T.FRONT:
            return DIR_T.B
        VALID_FACE_T.BACK:
            return DIR_T.T

func _get_wfc_tile_sockets(tile_name, direction = null):
    var tile = m_tile_dict[tile_name]

    # User specified a direction
    if direction != null:
        var s = _dir_to_socket(direction)
        if tile[s]["symmetric"] or tile[s]["reflected"]:
            return tile[s]["sid"]
        else:
            return -1 * tile[s]["sid"]

    var sockets = [null, null, null, null]
    for i in VALID_FACE_T:
        var v = VALID_FACE_T[i]
        var d = _socket_to_dir(v)
        if tile[v]["symmetric"] or tile[v]["reflected"]:
            sockets[d] = tile[v]["sid"]
        else:
            sockets[d] = -1 * tile[v]["sid"]

    return sockets



