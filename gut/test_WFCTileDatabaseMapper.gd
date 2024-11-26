
extends GutTest

# Map DB Adapter Location
const MAP_DATABASE_DIR = "res://gut/data/"
const MAP_DATABASE_FILE = "database_map.db"
const MAP_DATABASE_TEST_FILE = "database_map_test.db"
var MAP_DATABASE_PATH = MAP_DATABASE_DIR + MAP_DATABASE_FILE
var MAP_DATABASE_TEST_PATH = MAP_DATABASE_DIR + MAP_DATABASE_TEST_FILE

const TILE_DATABASE_DIR = "res://gut/data/"
const TILE_DATABASE_FILE = "database_tile.db"
const TILE_DATABASE_TEST_FILE = "database_tile_test.db"
var TILE_DATABASE_PATH = TILE_DATABASE_DIR + TILE_DATABASE_FILE
var TILE_DATABASE_TEST_PATH = TILE_DATABASE_DIR + TILE_DATABASE_TEST_FILE

var m_tile_db_adapter = null
var m_map_db_adapter = null
var m_mapper = null


#var m_dba
func before_all():
    #gut.p("Runs once before all tests")
    #m_dba = load('res://utils/LibraryRODatabaseAdapter.tscn').instantiate()
    #m_dba.open_database('res://assets/mesh_resources/database.db')
    pass

func before_each():
    #gut.p("Runs before each test.")
    # Duplicate the tile and map database then sets up the mapper
    var da = DirAccess.open(TILE_DATABASE_DIR)
    assert(da.file_exists(TILE_DATABASE_FILE), "Tile Database file does not exist")
    if da.file_exists(TILE_DATABASE_TEST_FILE):
        da.remove(TILE_DATABASE_TEST_FILE)
    da.copy(TILE_DATABASE_PATH, TILE_DATABASE_TEST_PATH)

    da = DirAccess.open(MAP_DATABASE_DIR)
    da.file_exists(MAP_DATABASE_FILE)
    if da.file_exists(MAP_DATABASE_TEST_FILE):
        da.remove(MAP_DATABASE_TEST_FILE)
    da.copy(MAP_DATABASE_PATH, MAP_DATABASE_TEST_PATH)
    m_tile_db_adapter = load('res://map-creator/TileDatabaseAdapter.tscn').instantiate()
    m_tile_db_adapter.open_database(TILE_DATABASE_TEST_PATH)
    m_map_db_adapter = load('res://map-creator/MapDatabaseAdapter.tscn').instantiate()
    m_map_db_adapter.open_database(MAP_DATABASE_TEST_PATH, true, true)
    m_mapper = WFCTileDatabaseMapper.new()
    m_mapper.set_map_db_adapter(m_map_db_adapter)
    m_mapper.set_tile_db_adapter(m_tile_db_adapter)
    m_mapper.learn_from(null)


func after_each():
    #gut.p("Runs after each test.")
    pass

func after_all():
    #gut.p("Runs once after all tests")
    pass

func _test_assert_eq_number_not_equal():
    assert_eq(1, 2, "Should fail.  1 != 2")

func _test_assert_eq_number_equal():
    assert_eq('asdf', 'asdf', "Should pass")

func test_learn_from():
    m_mapper.learn_from(null)
    var len_map = m_tile_db_adapter.get_module_dict().size()
    assert_eq(len_map * 4, m_mapper.m_attribute_dict.size(), "Should pass")

func test_get_used_rect_empty_map():
    # Received the used area of a map with an empty map, this should return a rect of 0,0
    var rect = m_mapper.get_used_rect(null)
    assert_eq(Vector2i(0, 0), rect.position, "Should pass")
    assert_eq(Vector2i(0, 0), rect.size, "Should pass")

func test_get_used_rect_not_empty_map():
    # Received the used area of a map with an empty map, this should return a rect of 0,0
    m_map_db_adapter.insert_module_xy(4, Vector2i( 0,  0), 0, 0, 0)
    m_map_db_adapter.insert_module_xy(8, Vector2i(10, 10), 0, 0, 0)
    var rect = m_mapper.get_used_rect(null)
    assert_eq(Vector2i(0, 0), rect.position, "Should pass")
    assert_eq(Vector2i(10, 10), rect.size, "Should pass")


#func test_open():
#  #var Foo = load('res://foo.gd')
#  #var double_foo = double(Foo).new()
#  #var double_scene = double(MyScene).instantiate()
#  #var double_foo = double(Foo).new()
#
#  #var lib_db_adapter_scene = load('res://utils/module_database_ro_adapter.tscn')
#  #var lib_db_adapter = double(lib_db_adapter_scene).instantiate()
#
#  #stub(double_foo, 'bar').to_return(42)
#  #stub(double_foo, 'something').to_call_super() # do what method would normally do
#  #stub(double_foo, 'other_thing').to_return(null).when_passed(1, 2, 'c')
#  #stub(double_foo, 'method').to_do_nothing()
#  #var dba = load('res://utils/LibraryRODatabaseAdapter.tscn').instantiate()
#  #dba.open_database('res://assets/mesh_resources/database.db')
#  #assert_eq('asdf', 'asdf', "Should pass")

func test_read_cell():
    # Test reading a cell
    m_map_db_adapter.insert_module_xy(0, Vector2i( 0,  0), 0, 0, 0) # tile000
    m_map_db_adapter.insert_module_xy(1, Vector2i(10, 10), 0, 0, 0) # tile001
    var cell = m_mapper.read_cell(null, Vector2i(0, 0))
    assert_eq(0, cell, "Should pass")
    cell = m_mapper.read_cell(null, Vector2i(10, 10))
    assert_eq(4, cell, "Should pass")
    cell = m_mapper.read_cell(null, Vector2i(5, 5))
    assert_eq(-1, cell, "Should pass")

func test_read_tile_meta():
    # Test reading a cell
    m_map_db_adapter.insert_module_xy(0, Vector2i(  0,   0),  90, 0, 0, {"test":100}) # tile000
    m_map_db_adapter.insert_module_xy(1, Vector2i( 10,  10),   0, 0, 0, {"test":500}) # tile000
    # To address it, we need to use the mapper ID, which then uses the attribute dictionary
    # to get the actual id, in this case this is tile '0' rotation 90 degrees
    var meta_good = m_mapper.read_tile_meta(1, "test")
    var meta_bad = m_mapper.read_tile_meta(1, "bad")
    assert_eq(len(meta_good), 1, "Should Pass")
    assert_eq(meta_good[0], 100, "Should Pass")
    assert_eq(len(meta_bad), 0, "Should Pass")
    assert_eq(meta_bad, [], "Should Pass")

func test_read_tile_meta_boolean():
    # Test reading a cell
    m_map_db_adapter.insert_module_xy(0, Vector2i(  0,   0),  90, 0, 0, {"test":100, "test_bool":true}) # tile000
    m_map_db_adapter.insert_module_xy(1, Vector2i( 10,  10),   0, 0, 0, {"test":500, "test_bool":false}) # tile000
    # To address it, we need to use the mapper ID, which then uses the attribute dictionary
    # to get the actual id, in this case this is tile '0' rotation 90 degrees
    var meta_good = m_mapper.read_tile_meta_boolean(1, "test_bool")
    var meta_bad = m_mapper.read_tile_meta_boolean(1, "bad_bool")

    # Test reading a cell
    assert_eq(meta_good, true, "Should Pass")
    assert_eq(meta_bad, false, "Should Pass")


func test_read_tile_probability():
    # Test reading a cell
    m_map_db_adapter.insert_module_xy(1, Vector2i(  0,   0),  90, 0, 0, {"wfc_probability":0.5}) # tile000
    m_map_db_adapter.insert_module_xy(1, Vector2i(  5,   3),  90, 0, 0, {"wfc_probability":0.5}) # tile000
    m_map_db_adapter.insert_module_xy(2, Vector2i( 10,  10),   0, 0, 0, {"test":500}) # tile000
    # To address it, we need to use the mapper ID, which then uses the attribute dictionary
    # to get the actual id, in this case this is tile '0' rotation 90 degrees
    var meta_good = m_mapper.read_tile_probability(5)
    var meta_bad = m_mapper.read_tile_probability(8)
    assert_almost_eq(meta_good, 0.25, 0.01, "Should Pass")
    assert_almost_eq(meta_bad, 1.0, 0.01, "Should Pass")

func test_write_cell():
    # Test reading a cell
    m_mapper.write_cell(null, Vector2i(0, 0), 4)
    m_mapper.write_cell(null, Vector2i(10, 10), 9)
    var cell = m_mapper.read_cell(null, Vector2i(0, 0))
    assert_eq(4, cell, "Should pass")
    cell = m_mapper.read_cell(null, Vector2i(10, 10))
    assert_eq(9, cell, "Should pass")
    cell = m_mapper.read_cell(null, Vector2i(5, 5))
    assert_eq(-1, cell, "Should pass")

func test_size():
    #var results = m_mapper.size()
    #assert_eq(results, 0, "Should pass")
    #m_map_db_adapter.insert_module_xy(1, Vector2i(  0,   0),  90, 0, 0, {"wfc_probability":0.5}) # tile000
    #results = m_mapper.size()
    #assert_eq(results, 1, "Should pass")
    #m_mapper.clear()
    var results = m_mapper.size()
    assert_eq(results, 12, "Should pass")

func test_supports_map():
    var results = m_mapper.supports_map(null)
    assert_eq(results, true, "Should pass")

func test_clear():
    m_map_db_adapter.insert_module_xy(1, Vector2i(  0,   0),  90, 0, 0, {"wfc_probability":0.5}) # tile000
    var s = m_mapper.get_used_rect(null)
    assert_eq(s.size, Vector2i(1, 1), "Should pass")
    m_mapper.clear()
    s = m_mapper.get_used_rect(null)
    assert_eq(s.size, Vector2i(0, 0), "Should pass")

func test_is_ready():
    var results = m_mapper.is_ready()
    assert_eq(results, true, "Should pass")
