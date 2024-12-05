-- MMDK - Moveset Mod Development Kit for Street Fighter 6 -- Shared Functions
-- By alphaZomega
-- September 19, 2023

local enums = {}

--Gets a table with IDs-by-name, a list of names, and names-by-ID from a System.Enum type name
local function get_enum(typename)
	if enums[typename] then return enums[typename] end
	local enum, names, reverse_enum = {}, {}, {}
	for i, field in ipairs(sdk.find_type_definition(typename):get_fields()) do
		if field:is_static() and field:get_data() ~= nil then
			enum[field:get_name()] = field:get_data() 
			reverse_enum[field:get_data()] = field:get_name()
			table.insert(names, field:get_name())
		end
	end
	enums[typename] = {enum=enum, names=names, reverse_enum=reverse_enum}
	return enums[typename]
end

-- Copies fields from defaults_tbl to tbl, then does the same for any child tables of defaults_tbl
local function recurse_def_settings(tbl, defaults_tbl)
	for key, value in pairs(defaults_tbl) do
		if type(tbl[key]) ~= type(value) then 
			if type(value) == "table" then
				tbl[key] = recurse_def_settings({}, value)
			else
				tbl[key] = value
			end
		elseif type(value) == "table" and value[1] == nil then --no indexed tables
			tbl[key] = recurse_def_settings(tbl[key], value)
		end
	end
	return tbl
end

--Generates a unique name (relative to a dictionary of names)
local function get_unique_name(start_name, used_names_list)
	local ctr = 0
	local nm = start_name
	while used_names_list[nm] do 
		ctr = ctr + 1
		nm = start_name.."("..ctr..")"
	end
	return nm
end

--Display a tooltip over the last imgui element
local function tooltip(text)
	if imgui.is_item_hovered() then
		imgui.set_tooltip(text)
	end
end

--Test if a lua variable can be indexed
local function can_index(lua_object)
	local mt = getmetatable(lua_object)
	return (not mt and type(lua_object) == "table") or (mt and (not not mt.__index))
end

--Gets a SystemArray, List or WrappedArrayContainer:
local function lua_get_array(src_obj, allow_empty)
	if not src_obj then return (allow_empty and {} or nil) end
	src_obj = src_obj._items or src_obj.mItems or src_obj
	local system_array
	if src_obj.get_Count then
		system_array = {}
		for i=1, src_obj:call("get_Count") do
			system_array[i] = src_obj:get_Item(i-1)
		end
	end
	system_array = system_array or src_obj.get_elements and src_obj:get_elements() 
	return (allow_empty and system_array) or (system_array and system_array[1] and system_array)
end

--Gets a dictionary from a RE Managed Object
local function lua_get_dict(dict, as_array, sort_fn)
	local output = {}
	if not dict._entries then return output end
	if as_array then 
		for i, value_obj in pairs(dict._entries) do
			output[i] = value_obj.value
		end
		if sort_fn then
			table.sort(output, sort_fn)
		end
	else
		for i, value_obj in pairs(dict._entries) do
			if value_obj.value ~= nil then
				output[value_obj.key] = output[value_obj.key] or value_obj.value
			end
		end
	end
	return output
end

--Gets the size of any table
local function get_table_size(tbl)
	local i = 0
	for k, v in pairs(tbl) do i = i + 1 end
	return i
end

--Gets the actual size of a System.Array (not Capacity)
local function get_true_array_sz(system_array)
	for i, item in pairs(system_array) do
		if item == nil then return i end
	end
	return #system_array
end

local clone --Defined below

--Makes a duplicate of an array at size 'new_array_sz' of type 'td_name'
local function clone_array(re_array, new_array_sz, td_name, do_copy_only)
	new_array_sz = new_array_sz or #re_array
	td_name = td_name or re_array:get_type_definition():get_full_name():gsub("%[%]", "")
	local new_array = sdk.create_managed_array(td_name, new_array_sz):add_ref()
	for i, item in pairs(re_array) do 
		if item ~= nil then
			new_array[i] = (not do_copy_only and sdk.is_managed_object(item) and not item.type and clone(item)) or item
		end
	end
	return new_array
end

--Makes a new array with the same elements
local function copy_array(re_array, new_array_sz, td_name)
	return clone_array(re_array, new_array_sz, td_name, true)
end

--Clones all elements of a source Generic.List's '._items' Array to a target Generic.List
local function clone_list_items(source_list, target_list)
	target_list._items = clone_array(source_list._items)
	target_list._size = get_true_array_sz(target_list._items)
end

--Clears a Generic.List
local function clear_list(list)
	list._items = sdk.create_managed_array(list._items:get_type_definition():get_full_name():gsub("%[%]", ""), 0):add_ref()
	list._size = 0
end

--Adds elements from array_b to the end of array_a
local function extend_array(array_a, array_b, new_sz)
	local size_a = #array_a
	local new_arr = copy_array(array_a, new_sz or (size_a + #array_b))
	for i, item in pairs(array_b) do
		new_arr[size_a+i] = item
	end
	return new_arr
end

--Adds elements from list_b (or array_b) to the end of list_a
local function extend_list(list_a, list_b)
	list_a._items = extend_array(list_a._items, list_b._items or list_b)
	list_a._size = get_true_array_sz(list_a._items)
end

--Adds one new blank item to a SystemArray; can be passed the array or a string typename if the array doesnt yet exist
local function append_to_array(re_array, new_item, fields)
	
	if type(re_array) == "string" then 
		re_array =  sdk.create_managed_array(re_array, 0):add_ref()
	end
	local sz = 0
	local td_name = re_array:get_type_definition():get_full_name():gsub("%[%]", "")
	local new_array = sdk.create_managed_array(td_name, re_array:get_Count()+1):add_ref()
	
	for i=0, new_array:get_Count() - 1 do 
		if re_array[i] ~= nil then
			new_array[i] = re_array[i] 
		else 
			new_array[i] = new_item or (sdk.create_instance(td_name) or sdk.create_instance(td_name, true)):add_ref()
			sz = i + 1
			break
		end
	end
	
	if fields then
		edit_obj(new_item, fields)
	end
	
	return new_array, sz
end

--Adds a new entry to a Systems.Collections.Generic.List
local function append_to_list(list, new_item)
	list._items, list._size = append_to_array(list._items, new_item)
	return list._size, new_item
end

--Inserts an element or a table/System.Array of elements ('array_or_elem_b') into a System.Array 'array_a' at position 'insert_idx'
local function insert_array(array_a, array_or_elem_b, insert_idx)
	local insert_elems = (type(array_or_elem_b)=="table" or tostring(type(array_or_elem_b)):find("Array")) and merge_tables({}, array_or_elem_b) or {array_or_elem_b}
	if insert_idx then 
		local insert_sz = get_table_size(insert_elems)
		local new_arr = sdk.create_managed_array(array_a:get_type_definition():get_full_name():gsub("%[%]", ""), insert_sz + #array_a):add_ref()
		local ctr = 0
		for i=0, insert_idx-1 do
			new_arr[ctr] = array_a[i]; ctr=ctr+1
		end
		for i, insert_elem in pairs(insert_elems) do
			new_arr[ctr] = insert_elem; ctr=ctr+1
		end
		for i=insert_idx, #array_a-1 do
			new_arr[ctr] = array_a[i]; ctr=ctr+1
		end
		return new_arr
	end
	return extend_array(array_a, insert_elems)
end

--Inserts an element or a table/System.Array/Generic.List of elements ('list_b') into a Generic.List 'list_a' at position 'insert_idx'
local function insert_list(list_a, list_or_item_b, insert_idx)
	list_or_item_b = can_index(list_or_item_b) and list_or_item_b._items or list_or_item_b
	list_a._items = insert_array(list_a._items, list_or_item_b, insert_idx)
	list_a._size = get_true_array_sz(list_a._items)
end

--Find the index of a value (or key/value) in a list table
local function find_index(tbl, value, key)
	if key ~= nil then 
		for i, item in ipairs(tbl) do
			if item[key] == value then return i end
		end
	else
		for i, item in ipairs(tbl) do
			if item == value then return i end
		end
	end
end

--Check if a table has an element that is a given value or has a given key/value pair, and get the key for that element
local function find_key(tbl, value, key)
	if key ~= nil then
		for k, subtbl in pairs(tbl) do
			if subtbl and subtbl[key] == value then return k end
		end
	else
		for k, v in pairs(tbl) do
			if v == value then return k end
		end
	end
end

--Turn a list of keys into a dictionary
local function set(list)
	local set = {}
	for i, v in ipairs(list) do set[v] = true end
	return set
end

--Combines elements of table B into table A
local function merge_tables(table_a, table_b)
	for key_b, value_b in pairs(table_b) do 
		table_a[key_b] = value_b 
	end
	return table_a
end

--Adds elements of indexed table B to indexed table A
local function extend_table(table_a, table_b, unique_only)
	for i, value_b in ipairs(table_b) do 
		if not unique_only or not find_index(table_a, value_b) then
			table.insert(table_a, value_b)
		end
	end
	return table_a
end

--Converts a float to a via.sfix
local function as_sfix(float_value)
    return sdk.find_type_definition("via.sfix"):get_method("From(System.Single)"):call(nil, float_value)
end

--Converts a Vector2f to a via.Sfix2
local function as_sfix2(vec2)
    local sfix_obj = ValueType.new(sdk.find_type_definition("via.Sfix2"))
    sfix_obj:call(".ctor(System.Single, System.Single)", vec2.x, vec2.y)
    return sfix_obj
end

--Converts a Vector3f to a via.Sfix3
local function as_sfix3(vec3)
    local sfix_obj = ValueType.new(sdk.find_type_definition("via.Sfix3"))
    sfix_obj:call(".ctor(System.Single, System.Single, System.Single)", vec3.x, vec3.y, vec3.z)
    return sfix_obj
end

--Converts a Vector4f to a via.Sfix4
local function as_sfix4(vec4)
    local sfix_obj = ValueType.new(sdk.find_type_definition("via.Sfix4"))
    sfix_obj:call(".ctor(System.Single, System.Single, System.Single, System.Single)", vec4.x, vec4.y, vec4.z, vec4.w)
    return sfix_obj
end

--Manually writes a ValueType at a field's position or specific offset
local function write_valuetype(parent_obj, offset_or_field_name, value)
    local offset = tonumber(offset_or_field_name) or parent_obj:get_type_definition():get_field(offset_or_field_name):get_offset_from_base()
    for i=0, (value.type or value:get_type_definition()):get_valuetype_size()-1 do
        parent_obj:write_byte(offset+i, value:read_byte(i))
    end
end

--Takes a sfix/sfix2/sfix3/sfix4 object and returns it as its equivalent Lua VectorXf or float
local function read_sfix(sfix_obj)
    if sfix_obj.w then
        return Vector4f.new(sfix_obj.x:ToFloat(), sfix_obj.y:ToFloat(), sfix_obj.z:ToFloat(), sfix_obj.w:ToFloat())
    elseif sfix_obj.z then
        return Vector3f.new(sfix_obj.x:ToFloat(), sfix_obj.y:ToFloat(), sfix_obj.z:ToFloat())
    elseif sfix_obj.y then
        return Vector2f.new(sfix_obj.x:ToFloat(), sfix_obj.y:ToFloat())
    end
    return sfix_obj:ToFloat()
end

--Takes a float or Vector2/3/4 and returns a Sfix equivalent
local function to_sfix(value)
    if type(value) == "number" then
		return as_sfix(value)
	elseif value.w then
        return as_sfix4(value)
    elseif value.z then
        return as_sfix3(value)
    elseif value.y then
        return as_sfix2(value)
    end
end

--Take X and Y and a return an isvec2 object with them
local function to_isvec2(x, y)
	local isvec2 = ValueType.new(sdk.find_type_definition("nAction.isvec2"))
	isvec2:call(".ctor(System.Int16, System.Int16)", x, y)
	return isvec2
end

--Gets a component from a GameObject (or other component) by name
local function getC(gameobj, component_name)
	if not gameobj then return end
	gameobj = gameobj.get_GameObject and gameobj:get_GameObject() or gameobj
	return gameobj:call("getComponent(System.Type)", sdk.typeof(component_name))
end

--Gets a table from a System.Collections.Generic.IEnumerable
local function lua_get_enumerable(m_obj)
	if pcall(sdk.call_object_func, m_obj, ".ctor", 0) then
		local elements = {}
		local fields = m_obj:get_type_definition():get_fields()
		local state = fields[1]:get_data(m_obj)
		while (state == 1 or state == 0) and ({pcall(sdk.call_object_func, m_obj, "MoveNext")})[2] == true do
			local current = fields[2]:get_data(m_obj)
			state = fields[1]:get_data(m_obj)
			if current ~= nil then
				table.insert(elements, current)
			end
		end
		return elements
	end
end

--Gets a format string for 'string.format' that will give all numeric keys the number of leading zeroes necessary to be alphabetically sorted (when converted to strings by json.dump_file)
local function get_fmt_string(tbl)
	local zeroes_ct = 0
	for key, value in pairs(tbl) do
		local len = tonumber(key) and tostring(tonumber(key)):len()
		if len and len > zeroes_ct then zeroes_ct = len end
	end
	return "%0"..zeroes_ct.."d"
end

--Loads a json file from a path and converts all its string number keys into actual numbers in a new table, then returns that table
local function convert_tbl_to_numeric_keys(json_tbl)
	local function recurse(tbl)
		local t = {}
		for k, v in pairs(tbl) do
			t[tonumber(k) or k] = ((type(v) == "table") and recurse(v)) or v
		end
		return t
	end
	return recurse(json_tbl)
end

--Converts a REManagedObject or a Lua table with REManagedObjects into a pure Lua table for json.dump_file
local function convert_to_json_tbl(tbl_or_object, max_layers, skip_arrays, skip_collections, skip_method_objs)
	
	max_layers = max_layers or 15
	local xyzw = {"x", "y", "z", "w"}
	local XYZW = {"X", "Y", "Z", "W"}
	local found_objs = {}
	local fms = {}
	
	local function get_fields_and_methods(typedef)
		local name = typedef:get_full_name()
		if fms[name] then return fms[name][1], fms[name][2] end
		local fields, methods = typedef:get_fields(), typedef:get_methods()
		local parent_type = typedef:get_parent_type()
		while parent_type and parent_type:get_full_name() ~= "System.Object" and parent_type:get_full_name() ~= "System.ValueType" do
			for i, field in ipairs(parent_type:get_fields()) do
				table.insert(fields, field)
			end
			for i, method in ipairs(parent_type:get_methods()) do
				table.insert(methods, method)
			end
			parent_type = parent_type:get_parent_type()
		end
		fms[name] = {fields, methods}
		return fields, methods
	end
	
	local function get_non_null_value(value)
		if value ~= nil and json.dump_string(value) ~= "null" then return value end
	end
	
	local function can_index(typedef)
		
	end
	
	local function recurse(obj, layer_no)
		if layer_no < max_layers and not found_objs[obj] then -- or tostring(obj):find("ValueType")) then
			found_objs[obj] = true
			local new_tbl = {}
			if type(obj) == "table" then
				local fmt_string = get_fmt_string(obj)
				for name, field in pairs(obj) do
					local num = tonumber(name) 
					local jname = (num and string.format(fmt_string, num)) or name
					new_tbl[jname] = get_non_null_value(((type(field)=="table" or type(field)=="userdata") and recurse(field, layer_no + 1)) or field)
				end
			elseif not obj.get_type_definition and obj.x then --Vector3f etc
				for i, name in ipairs(xyzw) do
					new_tbl[name] = obj[name]
					if new_tbl[name] == nil then break end
				end
			else
				local td = obj:get_type_definition()
				local td_name = td:get_full_name()
				local parent_vt = td:is_value_type()
				if td:is_a("System.Array") then
					if not skip_arrays then
						local elem_td = sdk.find_type_definition(td_name:gsub("%[%]", ""))
						local fmt_string = get_fmt_string(obj)
						local is_obj = false
						for i, elem in pairs(lua_get_array(obj, true)) do
							is_obj = is_obj or (elem_td and type(elem) == "userdata" and (elem_td:is_value_type() or sdk.is_managed_object(elem)))
							elem = (is_obj and elem.add_ref and elem:add_ref()) or elem
							new_tbl[string.format(fmt_string, i-1)] = get_non_null_value((is_obj and recurse(elem, layer_no + 1)) or elem)
						end
					end
				elseif td_name:find("via%.[Ss]fix") then
					return read_sfix(obj)
				elseif td:get_field("x") then --ValueTypes with xyzw
					local xtype = td:get_field("x"):get_type()
					for i, name in ipairs(xyzw) do
						new_tbl[name] = obj[name]
						if new_tbl[name] == nil then break end
						if xtype:is_a("via.sfix") then new_tbl[name] = new_tbl[name]:ToFloat() end
					end
				elseif td:get_field("X") then --ValueTypes with XYZW
					local xtype = td:get_field("X"):get_type()
					for i, name in ipairs(XYZW) do
						new_tbl[name] = obj[name]
						if new_tbl[name] == nil then break end
						if xtype:is_a("via.sfix") then new_tbl[name] = new_tbl[name]:ToFloat() end
					end
				elseif td:is_value_type() and obj["ToString()"] and pcall(obj["ToString()"], obj) then
					return obj:call("ToString()")
				elseif obj.mValue then
					return obj.mValue
				elseif obj.v then
					return obj.v
				elseif td_name:find("Collections") or td_name:find("WrappedArray") then
					if skip_collections then return end
					if td_name:find("Dict") then
						return get_non_null_value(recurse(lua_get_dict(obj), layer_no + 1))
					elseif td_name:find("List") or td_name:find("WrappedArray") then
						return get_non_null_value(recurse(lua_get_array(obj, true), layer_no + 1))
					elseif td:get_method("GetEnumerator") then
						return get_non_null_value(recurse(lua_get_enumerable(obj:GetEnumerator()), layer_no + 1))
					end
				else
					local fields, methods = get_fields_and_methods(td)
					for i, field in pairs(fields) do
						local name = field:get_name()
						if not field:is_static() and name:sub(1,2) ~= "<>" and name ~= "_object" then
							local try, fdata = pcall(field.get_data, field, obj)
							local should_recurse = try and type(fdata) == "userdata" and (field:get_type():is_value_type() or sdk.is_managed_object(fdata))
							new_tbl[name] = try and get_non_null_value(((should_recurse and recurse(fdata, layer_no + 1)) or fdata))
						end
					end
					for i, method in pairs(methods) do
						local name = method:get_name()
						if not method:is_static() and method:get_num_params() == 0 and name:find("[Gg]et") == 1 and not method:get_return_type():is_a("via.Component") then
							local try, mdata = pcall(method.call, method, obj)
							if try and mdata ~= nil then
								if not skip_method_objs and sdk.is_managed_object(mdata) and (obj[name:gsub("[Gg]et", "set")] or obj[name:gsub("[Gg]et", "Set")]) then
									new_tbl[name:gsub("[Gg]et", "")] = get_non_null_value(recurse(mdata:add_ref(), layer_no + 1) or mdata)
								else
									new_tbl[name:gsub("[Gg]et", "")] = get_non_null_value(mdata) 
								end
							end
						end
					end
				end
			end
			return get_non_null_value(new_tbl)
		end
	end
	
	local is_recursable = (type(tbl_or_object)=="table" or type(tbl_or_object)=="userdata")
	return get_non_null_value(is_recursable and recurse(tbl_or_object, 0) or tbl_or_object)
end

--Create a resource
local function create_resource(resource_type, resource_path)
	local new_resource = resource_path and sdk.create_resource(resource_type, resource_path)
	if not new_resource then return end
	new_resource = new_resource:add_ref()
	return new_resource:create_holder(resource_type .. "Holder"):add_ref()
end

-- Edits the fields of a RE Managed Object using a dictionary of field/method names to values. Use the string "nil" to save values as nil
local function edit_obj(obj, fields)
	local td = obj:get_type_definition()
    for name, value in pairs(fields) do
		local field = td:get_field(name)
		if value == "nil" then value = nil end
		if tonumber(name) and obj.get_Item then --arrays
			name = tonumber(name)
			local arr = obj._items or obj
			if name >= arr:get_Count() then
				if obj._size then 
					obj._items, obj._size = append_to_array(arr, value)
				else
					append_to_array(arr, value)
				end
			else
				arr[name] = value
			end
		elseif obj["set"..name] ~= nil then --Methods
			obj:call("set"..name, value) 
        elseif type(value) == "userdata" and value.type and tostring(value.type):find("RETypeDef") then --valuetypes
			write_valuetype(obj, name, value) 
		elseif type(value) == "table" then --All other fields
			if obj[name] and can_index(obj[name]) and obj[name].add_ref then
				obj[name] = edit_obj(obj[name], value)
			end
		elseif field then
			local field_type = field:get_type()
			if type(value) == "string" and field_type:is_value_type() and not field_type:is_a("System.String") then 
				local new_val = ValueType.new(field_type)
				if field_type:get_method(".ctor(System.String)") then
					new_val:call(".ctor(System.String)", value)
					write_valuetype(obj, name, new_val)
				elseif field_type:is_a("nAction.isvec2") then
					new_val.x, new_val.y = tonumber(value:match("(.+),")),  tonumber(value:match(",(.+)"))
					write_valuetype(obj, name, new_val)
				end
			else
				obj[name] = value
			end
		end
    end
	return obj
end

--Wrapper for edit_obj to handle a list of objects with the same fields
local function edit_objs(objs, fields)
	for i, obj in pairs(objs) do
		edit_obj(obj, fields)
	end
end

--Copy TDB fields from one object to another without cloning, optionally only copying with fields from 'selected_fields':
local function copy_fields(src_obj, target_obj, selected_fields)
	for i, field in ipairs(target_obj:get_type_definition():get_fields()) do
		local name = field:get_name()
		if not selected_fields or selected_fields[name] ~= nil then 
			target_obj[name] = src_obj[name] 
		end
	end
	return target_obj
end

--Wrapper for copy_fields to handle a list of objects with the same fields
local function copy_fields_to_objs(src_obj, target_objs, selected_fields)
	for i, target_obj in pairs(target_objs) do
		copy_fields(src_obj, target_obj, selected_fields)
	end
end

-- Make a duplicate of a managed object
clone = function(m_obj, fields, do_clone_props)

	local new_obj = m_obj:MemberwiseClone():add_ref()
	local td = new_obj:get_type_definition()
	
	for i, field in ipairs(new_obj:get_type_definition():get_fields()) do
		local data =  not field:is_static() and new_obj[field:get_name()]
		if type(data) == "userdata" and sdk.is_managed_object(data) then
			if data:get_type_definition():is_a("System.Array") then
				new_obj[field:get_name()] = clone_array(data)
			elseif not data:get_type_definition():get_full_name():match("<(.+)>") then
				new_obj[field:get_name()] = clone(data)
			end
		end
	end
	if do_clone_props then
		for i, method in ipairs(td:get_methods()) do
			local name = method:get_name()
			local set_method = not method:is_static() and (method:get_num_params() == 0) and (name:find("[Gg]et") == 1) and td:get_method(name:gsub("get", "set"):gsub("Get", "Set"))
			if set_method and set_method:get_num_params() == 1 and not method:get_return_type():is_a("System.Array") and not method:get_return_type():get_full_name():match("<(.+)>") then
				local data = method:call(new_obj)
				if data and sdk.is_managed_object(data) then
					set_method:call(new_obj, clone(data))
				end
			end
		end
	end
	if fields then
		edit_obj(new_obj, fields)
	end
	
	return new_obj
end

-- Adds a new key to a keys Generic.List and then applies the given fields to it
local function append_key(keylist, keytype_short, fields)
	local new_key = (sdk.create_instance("CharacterAsset."..keytype_short) or sdk.create_instance("app.battle."..keytype_short)):add_ref()
	append_to_list(keylist, new_key)
	if fields then	
		edit_obj(new_key, fields)
	end
	return new_key
end

-- Adds a TriggerKey to an action, then sets 4 values of it
local function append_trigger_key(action, ConditionFlag, TriggerGroup, StartFrame, EndFrame)
	local list = action.fab.Keys[6]
	local idx = list._size
	append_to_list(list, sdk.create_instance("CharacterAsset.TriggerKey"):add_ref())
	list[idx].ConditionFlag = ConditionFlag
	list[idx].TriggerGroup = TriggerGroup 
	list[idx]:set_StartFrame(StartFrame)
	list[idx]:set_EndFrame(EndFrame)
end

-- Edits all the param tables from 'param_types' of a dmg table using the given fields
local function edit_hit_dt_tbl(hit_dt_tbl, param_types, fields)
	for i, param_type in pairs(param_types) do
		edit_obj(hit_dt_tbl.param[param_type], fields)
	end
end

--Takes a table of frame indexes to position floats (keyframes) and returns a System.Array of positions, with the gaps between frames interpolated since the last frame:
local function create_poslist(positions_by_frame)
	
	positions_by_frame[0] = positions_by_frame[0] or 0.0
	local sorted_frames = {}
	for frame, position in pairs(positions_by_frame) do
		table.insert(sorted_frames, frame)
	end
	table.sort(sorted_frames)
	
	local new_poslist = sdk.create_managed_array("via.sfix", sorted_frames[#sorted_frames]+1):add_ref()
	local last_pos, sorted_frames_ctr, num_interp_frames, interp_slice = 0, 0, 0, 0
	local next_frame = sorted_frames[1]
	
	for i=0, new_poslist:get_Count() - 1 do
		if positions_by_frame[i] then
			last_pos = positions_by_frame[i]
			sorted_frames_ctr = sorted_frames_ctr + 1
			next_frame = sorted_frames[sorted_frames_ctr+1] or next_frame
			num_interp_frames = (next_frame - i)
			interp_slice = ((num_interp_frames == 0) and 0) or (positions_by_frame[next_frame] - last_pos) / num_interp_frames
		end 
		local num_interp_slices = num_interp_frames - (next_frame - i)
		new_poslist[i] = as_sfix(last_pos + (interp_slice * num_interp_slices))
	end
	
	return new_poslist
end

--Edit one of a BCM.COMMAND's BCM.INPUTs, using a fields table for 'normal' and an optional fields table for regular BCM.INPUT fields
--Charge and Rotate not yet supported
local function edit_command_input(bcm_command, input_idx, norm_fields, input_fields)
	local input = bcm_command.inputs[input_idx]
	local normal, charge, rotate = input.normal, input.charge, input.rotate
	if input_fields then edit_obj(input, input_fields) end
	if norm_fields then 
		edit_obj(normal, norm_fields) 
		write_valuetype(input, "normal", normal)
	end
	bcm_command.inputs[input_idx] = input
end


--Key-specific wrapper functions by Killbox:

local function edit_hitdata(dmg_table, param_type, fields)
	edit_obj(dmg_table.param[param_type], fields)
end

local function edit_hitdatas(dmg_table, param_types, fields)
	for i, param_type in ipairs(param_types) do
		edit_obj(dmg_table.param[param_type], fields)
	end
end

local function edit_common_dt_tbl(hit_dt_tbl, common_types, fields)
	for i, param_type in pairs(common_types) do
		edit_obj(hit_dt_tbl.common[common_type], fields)
	end
end

local function edit_speed(action, value)
    for _, keyTypes in ipairs(action.fab.Keys) do
        for _, key in ipairs(keyTypes._items) do
            if key.MotionStartFrame ~= 0 then
                key.MotionStartFrame = key.MotionStartFrame / value
            end
            if key._StartFrame ~= 0 then
                key._StartFrame = key._StartFrame / value
            end
            if key.StartFrame ~= 0 then
                key.StartFrame = key.StartFrame / value
            end
            --all end frames
            key._EndFrame = key._EndFrame / value
            key.EndFrame = key.EndFrame / value
			--MotionFrameEnd
			key.MotionEndFrame = key.MotionEndFrame / value
        end
    end
    
    -- Update action frame and total framecount outside the loop
    action.fab.ActionFrame.MarginFrame = action.fab.ActionFrame.MarginFrame / value
    action.fab.Frame = action.fab.Frame / value
end



local function edit_branchkey(action, keyindex, append, fields)
    local list = action.fab.Keys[0]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.BranchKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_triggerkey(action, keyindex, append, fields)
    local list = action.fab.Keys[6]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.TriggerKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_steerkey(action, keyindex, append, fields)
    local list = action.fab.Keys[5]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.SteerKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_worldkey(action, keyindex, append, fields)
    local list = action.fab.Keys[9]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.WorldKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_hitbox(action, keyindex, append, fields)
    local list = action.fab.Keys[10]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.AttackCollisionKey"):add_ref())
	end
	list[keyindex].BoxList = sdk.create_managed_array("System.Int32", 0)
    edit_obj(list[keyindex], fields)
end

local function edit_hurtbox(action, keyindex, append, fields)
    local list = action.fab.Keys[13]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.DamageCollisionKey"):add_ref())
	end
	list[keyindex].HeadList = sdk.create_managed_array("System.Int32", 0)
	list[keyindex].ThrowList = sdk.create_managed_array("System.Int32", 0)
	list[keyindex].LegList = sdk.create_managed_array("System.Int32", 0)
	list[keyindex].BodyList = sdk.create_managed_array("System.Int32", 0)
	
    edit_obj(list[keyindex], fields)
end

local function edit_motionkey(action, keyindex, append, fields)
    local list = action.fab.Keys[15]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.MotionKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_sfx(action, keyindex, append, fields)
    local list = action.fab.Keys[22]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.SEKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_voicekey(action, keyindex, append, fields)
    local list = action.fab.Keys[25]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.VoiceKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_vfxkey(action, keyindex, append, fields)
    local list = action.fab.Keys[30]
	if append == 1 then
        append_to_list(list, sdk.create_instance("app.battle.VfxKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_placekey(action, keyindex, append, fields)
    local list = action.fab.Keys[31]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.PlaceKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_shotkey(action, keyindex, append, fields)
    local list = action.fab.Keys[32]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.ShotKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local function edit_uniquebox(action, keyindex, append, fields)
    local list = action.fab.Keys[39]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.UniqueCollisionKey"):add_ref())
	end
	edit_obj(list[keyindex], fields)
end

local function edit_uniquebox(action, keyindex, append, fields, dataindex, box, datafields)
    local list = action.fab.Keys[39]
    if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.UniqueCollisionKey"):add_ref())
    end
    edit_obj(list[keyindex], fields)
    local datalist = list[keyindex].Datas
	if not datalist[dataindex] then
		list[keyindex].Datas = append_to_array("CharacterAsset.UniqueCollisionKey.Data")
    end
	if not datalist[dataindex].BoxList[0] then
		datalist[dataindex].BoxList[0] = sdk.create_int32(box)
	end
    edit_obj(datalist[dataindex], datafields)
end

local function edit_uniqueboxdata(action, keyindex, append, dataindex, datafields)
local list = action.fab.Keys[39]
local datalist = action.fab.Keys[39][keyindex].Datas
	if append == 1 then
		append_to_array("CharacterAsset.UniqueCollisionKey.Data")
	end
	edit_obj(list[keyindex].Datas[dataindex], datafields)
end

local function edit_lockkey(action, keyindex, append, fields)
    local list = action.fab.Keys[48]
	if append == 1 then
        append_to_list(list, sdk.create_instance("CharacterAsset.LockKey"):add_ref())
	end
    edit_obj(list[keyindex], fields)
end

local tables = require("MMDK\\tables")


fn = {
	append_key = append_key,
	append_to_array = append_to_array,
	append_to_list = append_to_list,
	append_trigger_key = append_trigger_key,
	as_sfix = as_sfix,
	as_sfix2 = as_sfix2,
	as_sfix3 = as_sfix3,
	as_sfix4 = as_sfix4,
	can_index = can_index,
	clear_list = clear_list,
	clone = clone,
	clone_array = clone_array,
	clone_list_items = clone_list_items,
	convert_to_json_tbl = convert_to_json_tbl,
	copy_array = copy_array,
	copy_fields = copy_fields,
	copy_fields_to_objs = copy_fields_to_objs,
	create_poslist = create_poslist,
	create_resource = create_resource,
	edit_command_input = edit_command_input,
	edit_hit_dt_tbl = edit_hit_dt_tbl,
	edit_hitdata = edit_hitdata,
	edit_hitdatas = edit_hitdatas,
	edit_hitdatas = edit_hitdatas,
	edit_common_dt_tbl = edit_common_dt_tbl,
	edit_key = edit_obj, --alias
	edit_obj = edit_obj, 
	edit_objs = edit_objs,
	edit_steerkey = edit_steerkey,
	edit_triggerkey = edit_triggerkey,
	edit_worldkey = edit_worldkey,
	edit_motionkey = edit_motionkey,
	edit_placekey = edit_placekey,
	edit_hurtbox = edit_hurtbox,
	edit_branchkey = edit_branchkey,
	edit_voicekey = edit_voicekey,
	edit_shotkey = edit_shotkey,
	edit_vfxkey = edit_vfxkey,
	edit_uniquebox = edit_uniquebox,
	edit_uniqueboxdata = edit_uniqueboxdata,
	edit_lockkey = edit_lockkey,
	edit_hitbox = edit_hitbox,
	edit_sfx = edit_sfx,
	edit_speed = edit_speed,
	extend_array = extend_array,
	extend_list = extend_list,
	extend_table = extend_table,
	find_index = find_index,
	find_key = find_key,
	getC = getC,
	get_enum = get_enum,
	get_fmt_string = get_fmt_string,
	get_table_size = get_table_size,
	get_unique_name = get_unique_name,
	hit_types = tables.hit_types, --backup
	inputs = tables.inputs, --backup
	insert_array = insert_array,
	insert_list = insert_list,
	lua_get_array = lua_get_array, 
	lua_get_dict = lua_get_dict,
	lua_get_enumerable = lua_get_enumerable,
	merge_tables = merge_tables,
	read_sfix = read_sfix,
	recurse_def_settings = recurse_def_settings,
	to_isvec2 = to_isvec2,
	to_sfix = to_sfix,
	tooltip = tooltip,
	write_valuetype = write_valuetype,
	convert_tbl_to_numeric_keys = convert_tbl_to_numeric_keys,
}

return fn