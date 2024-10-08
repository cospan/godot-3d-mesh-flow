extends GridContainer

class_name DebugDictProperty

signal property_changed(property_name, property_value)

var m_node_dict = {}
var m_widget_dict = {}
@export var LABEL_MIN_X_SIZE:int = 200

func _init(property_dict = null):
    if property_dict != null:
        set_properties_dict(property_dict)

func set_properties_dict(property_dict = {}):
    for key in property_dict:
        if key in m_widget_dict:
            m_widget_dict[key]["label"].queue_free()
            m_widget_dict[key]["widget"].queue_free()
            m_widget_dict.erase(key)

    for key in property_dict:
        add_property(key, property_dict[key])

func add_property(_name:String, property_dict:Dictionary):

    var label = Label.new()
    var prop = null
    label.text = property_dict["name"]
    add_child(label)
    label.custom_minimum_size = Vector2i(LABEL_MIN_X_SIZE, 0)
    match property_dict["type"].to_lower():
        "button":
            #print ("Button")
            label.text = ""
            prop = Button.new()
            prop.text = property_dict["name"]
            add_child(prop)
            m_widget_dict[_name] = {"type": property_dict["type"], "label": label, "widget": prop}
            prop.connect("pressed", func() : _property_update(_name, true))
        "checkbox":
            #print ("BOOL")
            prop = CheckBox.new()
            prop.button_pressed = property_dict["value"]
            add_child(prop)
            m_widget_dict[_name] = {"type": property_dict["type"], "label": label, "widget": prop}
            prop.connect("pressed", func() : _property_update(_name, prop.button_pressed))
        "optionbutton":
            #print ("OPTION")
            prop = OptionButton.new()
            for option in property_dict["options"]:
                prop.add_item(option)
            prop.selected = property_dict["value"]
            add_child(prop)
            m_widget_dict[_name] = {"type": property_dict["type"], "label": label, "widget": prop}
            prop.connect("item_selected", func(_val) : _property_update(_name, m_widget_dict[_name]["widget"].get_item_text(_val)))
        "spinbox":
            #print("FLOAT")
            if "value" in property_dict:
                if property_dict["value"] is Vector2 or property_dict["value"] is Vector2i:
                    add_child(add_vector2_spinbox(_name, property_dict, label))
                    if "visible" in property_dict:
                        set_spinbox_vector2_visible(_name, property_dict["visible"])
                    return
                elif property_dict["value"] is Vector3 or property_dict["value"] is Vector3i:
                    add_child(add_vector3_spinbox(_name, property_dict, label))
                    if "visible" in property_dict:
                        set_spinbox_vector3_visible(_name, property_dict["visible"])
                    return
                else:
                    add_child(add_float_spinbox(_name, property_dict, label))
                    if "visible" in property_dict:
                        set_prop_visible(_name, property_dict["visible"])
        "progressbar":
            #print("FLOAT")
            prop = ProgressBar.new()
            prop.value = property_dict["value"]
            if "min" in property_dict:
                prop.min_value = property_dict["min"]
            if "max" in property_dict:
                prop.max_value = property_dict["max"]
            add_child(prop)
            m_widget_dict[_name] = {"type": property_dict["type"], "label": label, "widget": prop}
        "hslider":
            #print("FLOAT")
            prop = HSlider.new()
            prop.custom_minimum_size = Vector2(200, 0) # Set minimum size
            prop.min_value = property_dict["min"]
            prop.max_value = property_dict["max"]
            prop.value = property_dict["value"]
            if "step" in property_dict:
                prop.step = property_dict["step"]
            else:
                prop.step = 1.0
            add_child(prop)
            m_widget_dict[_name] = {"type": property_dict["type"], "label": label, "widget": prop}
            prop.connect("value_changed", func(_val) : _property_update(_name, _val))
        "lineedit":
            #print("STRING")
            prop = LineEdit.new()
            prop.text = property_dict["value"]
            if "readonly" in property_dict:
                prop.editable = !property_dict["readonly"]

            add_child(prop)
            m_widget_dict[_name] = {"type": property_dict["type"], "label": label, "widget": prop}
            prop.connect("text_submitted", func(_val) : _property_update(_name, _val))
        "label":
            prop = Label.new()
            prop.text = property_dict["value"]
            add_child(prop)
            m_widget_dict[_name] = {"type": property_dict["type"], "label": label, "widget": prop}
        "itemlist":
            var scroll_box = ScrollContainer.new()
            prop = ItemList.new()
            scroll_box.add_child(prop)
            if "size" in property_dict:
                scroll_box.custom_minimum_size = property_dict["size"]
                prop.custom_minimum_size = property_dict["size"]
            prop.auto_height = true
            if "items" in property_dict:
                for item in property_dict["items"]:
                    if item is Array:
                        var sub_texture = Texture2D
                        var sub_string = ""
                        var sub_select = false
                        for sub_item in item:
                            if sub_item is String:
                                sub_string = sub_item
                            if sub_item is Texture2D:
                                sub_texture = sub_item
                            if sub_item is bool:
                                sub_select = sub_item

                        prop.add_item(sub_string, sub_texture, sub_select)
                    elif item is String:
                        prop.add_item(item)
                    elif item is Texture2D:
                        prop.add_item("", item)

            #add_child(prop)
            add_child(scroll_box)
            m_widget_dict[_name] = {"type": property_dict["type"], "label": label, "widget": prop}
            prop.connect("item_selected", func(_val) : _property_update(_name, m_widget_dict[_name]["widget"].get_item_text(_val)))
        _:
            print ("Unknown Property: %s" % property_dict["type"])

    if "callback" in property_dict:
        prop.set_meta("callback", property_dict["callback"])

    if "tooltip" in property_dict and prop != null:
        prop.tooltip_text = property_dict["tooltip"]

    if property_dict.has("visible"):
        label.visible = property_dict["visible"]
        if prop:
            if prop.get_parent() is ScrollContainer:
                prop = prop.get_parent()
            prop.visible = property_dict["visible"]

# Called when the node enters the scene tree for the first time.
func _ready():
    columns = 2

func interrogate_tree(group_name):
    var nodes = get_tree().get_nodes_in_group(group_name)
    for node in nodes:
        #print(node.get_name())
        # Get the properties from the node
        m_node_dict[node.get_name()] = node.get_properties()
        for prop in m_node_dict[node.get_name()]:
            add_property(prop, m_node_dict[node.get_name()][prop])
        node.child_exiting_tree.connect(_on_node_exiting_tree)

func _on_node_exiting_tree(node):
    if m_node_dict.has(node.get_name()):
        for key in m_node_dict[node.get_name()]:
            if key in m_widget_dict:
                m_widget_dict[key]["label"].queue_free()
                m_widget_dict[key]["widget"].queue_free()
                m_widget_dict.erase(key)

func set_label(n, text):
    m_widget_dict[n]["label"].text = text

func set_prop_visible(n, enable:bool):
    if !m_widget_dict.has(n):
        print ("No such property: %s" % n)
        return

    m_widget_dict[n]["label"].visible = enable
    if m_widget_dict[n]["type"] == "SpinBox":
        if len(m_widget_dict[n]["widget"].get_children()) == 2:
            set_spinbox_vector2_visible(n, enable)
        elif len(m_widget_dict[n]["widget"].get_children()) == 3:
            set_spinbox_vector3_visible(n, enable)
        else:
            var prop = m_widget_dict[n]["widget"]
            if prop.get_parent() is ScrollContainer:
                prop = prop.get_parent()
            prop.visible = enable
    else:
        var prop = m_widget_dict[n]["widget"]
        if prop.get_parent() is ScrollContainer:
            prop = prop.get_parent()
        prop.visible = enable

func set_prop_readonly(n, enable:bool):
    if !m_widget_dict.has(n):
        print ("No such property: %s" % n)
        return

    if m_widget_dict[n]["type"] == "SpinBox":
        var prop = m_widget_dict[n]["widget"]
        if prop.get_parent() is ScrollContainer:
            prop = prop.get_parent()
        prop.editable = !enable
    elif m_widget_dict[n]["type"] == "LineEdit":
        m_widget_dict[n]["widget"].editable = !enable
    elif m_widget_dict[n]["type"] == "CheckBox":
        m_widget_dict[n]["widget"].disabled = enable
    elif m_widget_dict[n]["type"] == "Button":
        m_widget_dict[n]["widget"].disabled = enable

func set_value(n, value):
    if !m_widget_dict.has(n):
        print ("No such property: %s" % n)
        return

    match(m_widget_dict[n]["type"]):
        "CheckBox":
            m_widget_dict[n]["widget"].button_pressed = value
        "SpinBox":
            if value is Vector2 or value is Vector2i:
                set_spinbox_vector2_value(n, value)
                return
            elif value is Vector3 or value is Vector3i:
                set_spinbox_vector3_value(n, value)
                return
            else:
                #print ("Name: %s, Value: %s" % [n, value])
                var v:SpinBox = m_widget_dict[n]["widget"]
                if value < v.min_value:
                    v.min_value = value
                if value > v.max_value:
                    v.max_value = value
                v.value = value
        "LineEdit":
            m_widget_dict[n]["widget"].text = value
        "ProgressBar":
            m_widget_dict[n]["widget"].value = value
        "HSlider":
            m_widget_dict[n]["widget"].value = value
        "Button":
            m_widget_dict[n]["widget"].text = value
        "OptionButton":
            m_widget_dict[n]["widget"].selected = value
        "Label":
            m_widget_dict[n]["widget"].text = value
        "ItemList":
            m_widget_dict[n]["widget"].clear()
            for item in value:
                if item is Array:
                    var sub_texture = Texture2D
                    var sub_string = ""
                    var sub_select = false
                    for sub_item in item:
                        if sub_item is String:
                            sub_string = sub_item
                        if sub_item is Image:
                            sub_texture = ImageTexture.create_from_image(sub_item)
                        if sub_item is Texture2D:
                            sub_texture = sub_item
                        if sub_item is bool:
                            sub_select = sub_item

                    m_widget_dict[n]["widget"].add_item(sub_string, sub_texture, sub_select)
                elif item is String:
                    m_widget_dict[n]["widget"].add_item(item)
                elif item is Texture2D:
                    m_widget_dict[n]["widget"].add_item("", item)

func get_value(n):
    match(m_widget_dict[n]["type"]):
        "CheckBox":
            return m_widget_dict[n]["widget"].button_pressed
        "SpinBox":
            return get_spinbox_value(n)
        "LineEdit":
            return m_widget_dict[n]["widget"].text
        "ProgressBar":
            return m_widget_dict[n]["widget"].value
        "HSlider":
            return m_widget_dict[n]["widget"].value
        "Button":
            return m_widget_dict[n]["widget"].text
        "OptionButton":
            return m_widget_dict[n]["widget"].selected
        "ItemList":
            return m_widget_dict[n]["widget"].get_selected_items()
        "Label":
            return m_widget_dict[n]["widget"].text

func _property_update(property_name, property_value):
    if m_widget_dict[property_name]["widget"].has_meta("callback"):
        m_widget_dict[property_name]["widget"].get_meta("callback").call(property_name, property_value)
    else:
      property_changed.emit(property_name, property_value)

func set_spinbox_vector2_visible(n, enable:bool):
    if !m_widget_dict.has(n):
        print ("No such property: %s" % n)
        return

    m_widget_dict[n]["label"].visible = enable
    var prop = m_widget_dict[n]["widget"]
    if prop.get_parent() is ScrollContainer:
        prop = prop.get_parent()
    prop.visible = enable

    if enable:
        var v:SpinBox = m_widget_dict[n]["widget"].get_child(0)
        v.visible = true
        v = m_widget_dict[n]["widget"].get_child(1)
        v.visible = true
    else:
        var v:SpinBox = m_widget_dict[n]["widget"].get_child(0)
        v.visible = false
        v = m_widget_dict[n]["widget"].get_child(1)
        v.visible = false

func set_spinbox_vector3_visible(n, enable:bool):
    if !m_widget_dict.has(n):
        print ("No such property: %s" % n)
        return

    m_widget_dict[n]["label"].visible = enable
    var prop = m_widget_dict[n]["widget"]
    if prop.get_parent() is ScrollContainer:
        prop = prop.get_parent()
    prop.visible = enable

    if enable:
        var v:SpinBox = m_widget_dict[n]["widget"].get_child(0)
        v.visible = true
        v = m_widget_dict[n]["widget"].get_child(1)
        v.visible = true
        v = m_widget_dict[n]["widget"].get_child(2)
        v.visible = true
    else:
        var v:SpinBox = m_widget_dict[n]["widget"].get_child(0)
        v.visible = false
        v = m_widget_dict[n]["widget"].get_child(1)
        v.visible = false
        v = m_widget_dict[n]["widget"].get_child(2)
        v.visible = false

func set_spinbox_vector2_value(n, value):
    var v:SpinBox = m_widget_dict[n]["widget"].get_child(0)
    if value.x < v.min_value:
        v.min_value = value.x
    if value.x > v.max_value:
        v.max_value = value.x
    v.value = value.x
    v = m_widget_dict[n]["widget"].get_child(1)
    if value.y < v.min_value:
        v.min_value = value.y
    if value.y > v.max_value:
        v.max_value = value.y
    v.value = value.y

func set_spinbox_vector3_value(n, value):
    var v:SpinBox = m_widget_dict[n]["widget"].get_child(0)
    if value.x < v.min_value:
        v.min_value = value.x
    if value.x > v.max_value:
        v.max_value = value.x
    v.value = value.x
    v = m_widget_dict[n]["widget"].get_child(1)
    if value.y < v.min_value:
        v.min_value = value.y
    if value.y > v.max_value:
        v.max_value = value.y
    v.value = value.y
    v = m_widget_dict[n]["widget"].get_child(2)
    if value.z < v.min_value:
        v.min_value = value.z
    if value.z > v.max_value:
        v.max_value = value.z
    v.value = value.z

func add_float_spinbox(key: String, property_dict: Dictionary, label:Label) -> SpinBox:
    var val = property_dict["value"]
    var min_value = -100
    var max_value = 100
    var step = 1.0
    var editable = true

    if "min" in property_dict:
        min_value = property_dict["min"]
    if "max" in property_dict:
        max_value = property_dict["max"]
    if "step" in property_dict:
        step = property_dict["step"]
    if "readonly" in property_dict:
        editable = !property_dict["readonly"]

    var prop = SpinBox.new()
    if "tooltip" in property_dict:
        prop.tooltip_text = property_dict["tooltip"]

    prop.value = val
    prop.min_value = min_value
    prop.max_value = max_value
    prop.step = step
    prop.editable = editable
    prop.connect("value_changed", func(_val) : _property_update(key, _val))
    m_widget_dict[key] = {"type": property_dict["type"], "label": label, "widget": prop}
    return prop

func add_vector2_spinbox(key: String, property_dict: Dictionary, label:Label) -> HBoxContainer:
    var hbox = HBoxContainer.new()
    if "tooltip" in property_dict:
        hbox.tooltip_text = property_dict["tooltip"]
    hbox.custom_minimum_size = Vector2(200, 0) # Set minimum size

    var val1 = property_dict["value"][0]
    var val2 = property_dict["value"][1]
    var min_value = -100
    var max_value = 100
    var step = 1.0
    var editable = true

    if "min" in property_dict:
        min_value = property_dict["min"]
    if "max" in property_dict:
        max_value = property_dict["max"]
    if "step" in property_dict:
        step = property_dict["step"]
    if "readonly" in property_dict:
        editable = !property_dict["readonly"]

    # Create the first spinbox
    var prop1 = SpinBox.new()
    var prop2 = SpinBox.new()

    prop1.value = val1
    prop1.min_value = min_value
    prop1.max_value = max_value
    prop1.step = step
    prop1.editable = editable
    prop1.connect("value_changed", func(_val) : _property_update(key, [_val, prop2.value]))
    hbox.add_child(prop1)

    # Create the second spinbox
    prop2.value = val2
    prop2.min_value = min_value
    prop2.max_value = max_value
    prop2.step = step
    prop2.editable = editable
    hbox.add_child(prop2)
    prop2.connect("value_changed", func(_val) : _property_update(key, [prop1.value, _val]))
    m_widget_dict[key] = {"type": property_dict["type"], "label": label, "widget": hbox}
    return hbox

func add_vector3_spinbox(key: String, property_dict: Dictionary, label:Label) -> HBoxContainer:
    var hbox = HBoxContainer.new()
    hbox.custom_minimum_size = Vector2(200, 0) # Set minimum size
    if "tooltip" in property_dict:
        hbox.tooltip_text = property_dict["tooltip"]

    var val1 = property_dict["value"][0]
    var val2 = property_dict["value"][1]
    var val3 = property_dict["value"][2]

    var min_value = -100
    var max_value = 100
    var step = 1.0
    var editable = true

    if "min" in property_dict:
        min_value = property_dict["min"]
    if "max" in property_dict:
        max_value = property_dict["max"]
    if "step" in property_dict:
        step = property_dict["step"]
    if "readonly" in property_dict:
        editable = !property_dict["readonly"]

    # Create the first spinbox
    var prop1 = SpinBox.new()
    var prop2 = SpinBox.new()
    var prop3 = SpinBox.new()

    prop1.value = val1
    prop1.min_value = min_value
    prop1.max_value = max_value
    prop1.step = step
    prop1.editable = editable
    prop1.connect("value_changed", func(_val) : _property_update(key, [_val, prop2.value, prop3.value]))
    hbox.add_child(prop1)

    # Create the second spinbox
    prop2.value = val2
    prop2.min_value = min_value
    prop2.max_value = max_value
    prop2.step = step
    prop2.editable = editable
    prop2.connect("value_changed", func(_val) : _property_update(key, [prop1.value, _val, prop3.value]))
    hbox.add_child(prop2)

    # Create the third spinbox
    prop3.value = val3
    prop3.min_value = min_value
    prop3.max_value = max_value
    prop3.step = step
    prop3.editable = editable
    prop3.connect("value_changed", func(_val) : _property_update(key, [prop1.value, prop2.value, _val]))
    hbox.add_child(prop3)
    m_widget_dict[key] = {"type": property_dict["type"], "label": label, "widget": hbox}
    return hbox

func get_spinbox_value(n):
    # Check the number of children
    var wv = m_widget_dict[n]["widget"]
    var v = null
    if wv is HBoxContainer:
        if wv.get_child_count() == 3:
            #Vector3
            v = Vector3()
            v.x = wv.get_child(0).value
            v.y = wv.get_child(1).value
            v.z = wv.get_child(2).value
        else:
            #Vector2
            v = Vector2()
            v.x = wv.get_child(0).value
            v.y = wv.get_child(1).value
    else:
        v = wv.value
    return v
