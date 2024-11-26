extends GutTest

const MAP_DATABASE_DIR = "res://gut/data/"
const MAP_DATABASE_FILE = "database_map.db"
const MAP_DATABASE_TEST_FILE = "database_map_test.db"
var MAP_DATABASE_PATH = MAP_DATABASE_DIR + MAP_DATABASE_FILE
var MAP_DATABASE_TEST_PATH = MAP_DATABASE_DIR + MAP_DATABASE_TEST_FILE

var m_dba

func before_all():
    pass

func before_each():
    var da = DirAccess.open(MAP_DATABASE_DIR)
    assert(da.file_exists(MAP_DATABASE_FILE), "Map Database file does not exist")
    if da.file_exists(MAP_DATABASE_TEST_FILE):
        da.remove(MAP_DATABASE_TEST_FILE)
    da.copy(MAP_DATABASE_PATH, MAP_DATABASE_TEST_PATH)

    m_dba = load('res://map-creator/MapDatabaseAdapter.gd').new()
    m_dba.open_database(MAP_DATABASE_TEST_PATH)
    #m_dba.open_database(MAP_DATABASE_TEST_PATH, true, true)
    #m_dba.insert_module("test_subcomposer", "tile002", Vector3i(0, 0, 0), 1.0, 0, 0, 0, 0, 0, {})

func after_each():
    pass

func after_all():
    pass

func test_open_database():
    assert_not_null(m_dba.m_database, "Database should be initialized")
    assert_eq(m_dba.m_database.path, MAP_DATABASE_TEST_PATH, "Database path should be set correctly")

func test_insert_module():
    var pos = Vector3i(1, 2, 3)
    m_dba.insert_module("test_subcomposer", "tile000", pos, 1.0, 0, 0, 0, 0, 0, {})
    var pos_dict = m_dba.get_pos_dict()
    var key = m_dba._v3i_to_key(pos)
    assert_eq(pos_dict.has(key), true, "Position dictionary should contain the inserted module")

func test_get_module_at_pos():
    var pos = Vector3i(1, 2, 3)
    m_dba.insert_module("test_subcomposer", "tile000", pos, 1.0, 0, 0, 0, 0, 0, {})
    var module = m_dba.get_module_at_pos(pos)
    assert_eq(module["module_id"], "tile000", "Module ID should match the inserted module")

func test_clear_pos_table():
    var pos = Vector3i(1, 2, 3)
    m_dba.insert_module("test_subcomposer", "tile000", pos, 1.0, 0, 0, 0, 0, 0, {})
    m_dba.clear_pos_table()
    var pos_dict = m_dba.get_pos_dict()
    assert_eq(pos_dict.size(), 0, "Position dictionary should be empty after clearing the table")

func test_get_pos_dict_in_region_xyz():
    var pos1 = Vector3i(1, 2, 3)
    var pos2 = Vector3i(4, 5, 6)
    m_dba.insert_module("test_subcomposer", "tile000", pos1, 1.0, 0, 0, 0, 0, 0, {})
    m_dba.insert_module("test_subcomposer", "tile001", pos2, 1.0, 0, 0, 0, 0, 0, {})
    var region_dict = m_dba.get_pos_dict_in_region_xyz(Vector3i(0, 0, 0), Vector3i(5, 5, 5))
    assert_eq(region_dict.size(), 1, "Region dictionary should contain one module within the specified region")
    assert_eq(region_dict.has(m_dba._v3i_to_key(pos1)), true, "Region dictionary should contain the first module")
    assert_eq(region_dict.has(m_dba._v3i_to_key(pos2)), false, "Region dictionary should not contain the second module")

func test_insert_mesh():
    var mesh = Mesh.new()
    m_dba.insert_mesh("tile002", mesh)
    var select_condition = "name = 'tile002'"
    var rows = m_dba.m_database.select_rows(m_dba.MESH_TABLE, select_condition, ["*"])
    assert_eq(rows.size(), 1, "Mesh table should contain one entry for the inserted mesh")
    assert_eq(rows[0]["name"], "tile002", "Mesh name should match the inserted mesh")

func test_remove_mesh():
    var mesh = Mesh.new()
    m_dba.insert_mesh("test_mesh", mesh)
    m_dba.remove_mesh("test_mesh")
    var select_condition = "name = 'test_mesh'"
    var rows = m_dba.m_database.select_rows(m_dba.MESH_TABLE, select_condition, ["*"])
    assert_eq(rows.size(), 0, "Mesh table should be empty after removing the mesh")
