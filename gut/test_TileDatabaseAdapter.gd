extends GutTest

const TILE_DATABASE_DIR = "res://gut/data/"
const TILE_DATABASE_FILE = "database_tile.db"
const TILE_DATABASE_TEST_FILE = "database_tile_test.db"
var TILE_DATABASE_PATH = TILE_DATABASE_DIR + TILE_DATABASE_FILE
var TILE_DATABASE_TEST_PATH = TILE_DATABASE_DIR + TILE_DATABASE_TEST_FILE

var m_dba

func before_all():
    pass

func before_each():
    #gut.p("Runs before each test.")
    # Duplicate the tile and map database then sets up the mapper
    var da = DirAccess.open(TILE_DATABASE_DIR)
    assert(da.file_exists(TILE_DATABASE_FILE), "Tile Database file does not exist")
    if da.file_exists(TILE_DATABASE_TEST_FILE):
        da.remove(TILE_DATABASE_TEST_FILE)
    da.copy(TILE_DATABASE_PATH, TILE_DATABASE_TEST_PATH)

    m_dba = load('res://map-creator/TileDatabaseAdapter.gd').new()
    m_dba.open_database(TILE_DATABASE_TEST_PATH)

func after_each():
    #gut.p("Runs after each test.")
    pass

func after_all():
    #gut.p("Runs once after all tests")
    pass

func test_get_tile_size():
    var size = Vector2(1, 2)
    m_dba.set_default_size_3d(Vector3(size.x, size.y, 0))
    var result = m_dba.get_tile_size()
    assert_eq(result, size, "Tile size value incorrect")

func test_get_module_dict():
    var faces = [1, 2, 3, 4, 5, 6]
    m_dba.insert_expanded_module("test_module", 0, 0, faces)
    var module_dict = m_dba.get_module_dict()
    assert_eq(module_dict.has("test_module"), true, "Module dictionary does not contain inserted module")

func test_get_sid_dict():
    var module_list = ["tile000", "tile001"]
    m_dba.insert_sid_mapping(1, 0, module_list)
    var sid_dict = m_dba.get_sid_dict()
    assert_eq(sid_dict.has(1), true, "SID dictionary does not contain inserted SID")
    assert_eq(sid_dict[1]["asymmetric"], 0, "SID dictionary asymmetric flag value incorrect")
    assert_eq(sid_dict[1]["module_list"], module_list, "SID dictionary module list value incorrect")

func test_get_mesh_dict():
    var mesh_dict = m_dba.get_mesh_dict()
    assert_has(mesh_dict, "tile000", "Mesh dictionary does not contain tile000")
    #assert_eq(mesh_dict.has(1), true, "Mesh dictionary does not contain inserted mesh")
    #assert_eq(mesh_dict[1], mesh, "Mesh dictionary mesh value incorrect")
