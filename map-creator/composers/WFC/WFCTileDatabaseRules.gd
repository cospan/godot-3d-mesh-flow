extends WFCRules2D

class_name WFCTileDatabaseRules

##############################################################################
# Signals
##############################################################################

##############################################################################
# Constants
##############################################################################

##############################################################################
# Members
##############################################################################
var m_logger = LogStream.new("_BASE_", LogStream.LogLevel.DEBUG)
var m_id_dict: Dictionary = {}
var m_attribute_dict: Dictionary = {}

## Flags ##

##############################################################################
# Scenes
##############################################################################
var m_tile_db_adapter = null

##############################################################################
# Exports
##############################################################################

##############################################################################
# Public Functions
##############################################################################
func set_tile_db_adapter(adapter: Node):
    m_tile_db_adapter = adapter

func set_id_dict(id_dict: Dictionary):
    m_id_dict = id_dict

func set_attribution_dict(attribution_dict: Dictionary):
    m_attribute_dict = attribution_dict

##############################################################################
# Private Functions
##############################################################################
func _learn_from(map: Node, positive: bool):
    var module_dict = m_tile_db_adapter.get_module_dict()
    var sid_dict = m_tile_db_adapter.get_sid_dict()

    for index in m_id_dict:
        var tile_id = m_id_dict[index]["attr"][0]
        var module_name = m_id_dict[index]["name"]
        var rot_values = [0, 90, 180, 270]
        # Get the sids for the non rotated version of the module
        var module_sids = []
        # Faces is a list where 0: "front", "back", "top", "bottom", "right", "left"
        # the 'front' is the 'down' in 2D and the 'back' is the 'up' in 2D
        module_sids.append(module_dict[module_name]["faces"][1])
        module_sids.append(module_dict[module_name]["faces"][0])
        module_sids.append(module_dict[module_name]["faces"][5])
        module_sids.append(module_dict[module_name]["faces"][4])


        for rot in rot_values:
            var module_attr = Vector2i(tile_id, rot)
            var module_id = m_attribute_dict[module_attr]

            for a in range(axes.size()):
                var a_dir:Vector2i = axes[a]
                if (a_dir.x == 0 and a_dir.y == 1):
                    # Up
                    # Get the SID for the right face of the module
                    var sid = module_sids[0]
                    if sid not in sid_dict:
                        m_logger.warn("SID not in SID dict: %s" % [sid])
                        continue
                    var sid_data = sid_dict[sid]
                    # There are a list of other modules
                    for m in sid_data["module_list"]:
                        var other_module_id = module_dict[m]["id"]
                        var other_module_sids = []
                        other_module_sids.append(module_dict[m]["faces"][1])
                        other_module_sids.append(module_dict[m]["faces"][0])
                        other_module_sids.append(module_dict[m]["faces"][5])
                        other_module_sids.append(module_dict[m]["faces"][4])

                        # Go through all the rotations that will allow the top SID to connect to the bottom SID
                        for orot in rot_values:
                            var attrs = Vector2i(other_module_id, orot)
                            var other_attr_id = m_attribute_dict[attrs]
                            # Get the SID for the bottom face of the other module
                            var other_sid = other_module_sids[1]
                            if other_sid == sid:
                                axis_matrices[a].set_bit(module_id, other_attr_id, positive)

                            # need to rotate the other_module_sids
                            var otmp_sid = other_module_sids.pop_front()
                            other_module_sids.push_back(otmp_sid)

                        #axis_matrices[a].set_bit(, other_attr_id, positive)
                elif (a_dir.x == 0 and a_dir.y == -1):
                    # Down
                    var sid = module_sids[1]
                    if sid not in sid_dict:
                        m_logger.warn("SID not in SID dict: %s" % [sid])
                        continue

                    var sid_data = sid_dict[sid]
                    # There are a list of other modules
                    for m in sid_data["module_list"]:
                        var other_module_id = module_dict[m]["id"]
                        var other_module_sids = []
                        other_module_sids.append(module_dict[m]["faces"][1])
                        other_module_sids.append(module_dict[m]["faces"][0])
                        other_module_sids.append(module_dict[m]["faces"][5])
                        other_module_sids.append(module_dict[m]["faces"][4])

                        # Go through all the rotations that will allow the top SID to connect to the bottom SID
                        for orot in rot_values:
                            var attrs = Vector2i(other_module_id, orot)
                            var other_attr_id = m_attribute_dict[attrs]
                            # Get the SID for the bottom face of the other module
                            var other_sid = other_module_sids[0]
                            if other_sid == sid:
                                axis_matrices[a].set_bit(module_id, other_attr_id, positive)

                            # need to rotate the other_module_sids
                            var otmp_sid = other_module_sids.pop_front()
                            other_module_sids.push_back(otmp_sid)

                elif (a_dir.x == 1 and a_dir.y == 0):
                    # Right
                    var sid = module_sids[3]
                    if sid not in sid_dict:
                        m_logger.warn("SID not in SID dict: %s" % [sid])
                        continue

                    var sid_data = sid_dict[sid]
                    # There are a list of other modules
                    for m in sid_data["module_list"]:
                        var other_module_id = module_dict[m]["id"]
                        var other_module_sids = []
                        other_module_sids.append(module_dict[m]["faces"][1])
                        other_module_sids.append(module_dict[m]["faces"][0])
                        other_module_sids.append(module_dict[m]["faces"][5])
                        other_module_sids.append(module_dict[m]["faces"][4])

                        # Go through all the rotations that will allow the top SID to connect to the bottom SID
                        for orot in rot_values:
                            var attrs = Vector2i(other_module_id, orot)
                            var other_attr_id = m_attribute_dict[attrs]
                            # Get the SID for the bottom face of the other module
                            var other_sid = other_module_sids[2]
                            if other_sid == sid:
                                axis_matrices[a].set_bit(module_id, other_attr_id, positive)

                            # need to rotate the other_module_sids
                            var otmp_sid = other_module_sids.pop_front()
                            other_module_sids.push_back(otmp_sid)

                elif (a_dir.x == -1 and a_dir.y == 0):
                    # Left
                    var sid = module_sids[2]
                    if sid not in sid_dict:
                        m_logger.warn("SID not in SID dict: %s" % [sid])
                        continue

                    var sid_data = sid_dict[sid]
                    # There are a list of other modules
                    for m in sid_data["module_list"]:
                        var other_module_id = module_dict[m]["id"]
                        var other_module_sids = []
                        other_module_sids.append(module_dict[m]["faces"][1])
                        other_module_sids.append(module_dict[m]["faces"][0])
                        other_module_sids.append(module_dict[m]["faces"][5])
                        other_module_sids.append(module_dict[m]["faces"][4])

                        # Go through all the rotations that will allow the top SID to connect to the bottom SID
                        for orot in rot_values:
                            var attrs = Vector2i(other_module_id, orot)
                            var other_attr_id = m_attribute_dict[attrs]
                            # Get the SID for the bottom face of the other module
                            var other_sid = other_module_sids[3]
                            if other_sid == sid:
                                axis_matrices[a].set_bit(module_id, other_attr_id, positive)

                            # need to rotate the other_module_sids
                            var otmp_sid = other_module_sids.pop_front()
                            other_module_sids.push_back(otmp_sid)

                else:
                    # Not handled
                    m_logger.error("Axis not handled: %s" % [a_dir])
                    continue

            # Rotate the module sids
            var tmp_sid = module_sids.pop_front()
            module_sids.push_back(tmp_sid)




    #var learning_rect: Rect2i = mapper.get_used_rect(map)
    #for x in range(learning_rect.position.x, learning_rect.end.x):
    #    for y in range(learning_rect.position.y, learning_rect.end.y):
    #        var cell_coords: Vector2i = Vector2i(x, y)
    #        var cell: int = mapper.read_cell(map, cell_coords)

    #        if cell < 0:
    #            continue

    #        for a in range(axes.size()):
    #            var a_dir: Vector2i = axes[a]
    #            var other_cell: int = mapper.read_cell(
    #                map,
    #                cell_coords + a_dir,
    #            )
    #            if other_cell < 0:
    #                continue

    #            axis_matrices[a].set_bit(cell, other_cell, positive)



##############################################################################
# Signal Handlers
##############################################################################
