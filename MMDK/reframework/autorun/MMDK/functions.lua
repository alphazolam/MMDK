-- MMDK - Moveset Mod Development Kit for Street Fighter 6 -- Shared Functions
-- By alphaZomega
-- September 6, 2023

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
		elseif type(value) == "table" then
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

--Gets a SystemArray, List or WrappedArrayContainer:
local function lua_get_array(sys_array, allow_empty)
	if not sys_array then return (allow_empty and {}) end
	sys_array = sys_array.mItems or sys_array._items or sys_array
	local system_array
	local is_wrap = (sys_array:get_type_definition():get_name():sub(1,12) == "WrappedArray")
	if is_wrap or sys_array.get_Count then
		system_array = {}
		for i=1, sys_array:call("get_Count") do
			system_array[i] = sys_array[i-1]
		end
	end
	system_array = system_array or sys_array.get_elements and sys_array:get_elements() 
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

local clone

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

local function copy_array(re_array, new_array_sz, td_name)
	return clone_array(re_array, new_array_sz, td_name, true)
end

--Clones all elements of a source Generic.List's '._items' Array to a target Generic.List
local function clone_list_items(source_list, target_list)
	target_list._items = clone_array(source_list._items)
	target_list._size = source_list._size
end

local function clear_list(list)
	list._items = sdk.create_managed_array(list._items:get_type_definition():get_full_name():gsub("%[%]", ""), 0):add_ref()
	list._size = 0
end

--Adds one new blank item to a SystemArray; can be passed the array or a string typename if the array doesnt yet exist
local function append_to_array(re_array, new_item)
	
	if type(re_array) == "string" then 
		re_array =  sdk.create_managed_array(re_array, 0):add_ref()
	end
	local sz = 0
	local td_name = re_array:get_type_definition():get_full_name():gsub("%[%]", "")
	local new_array = sdk.create_managed_array(td_name, re_array:get_size()+1):add_ref()
	for i, item in pairs(new_array) do 
		if re_array[i] ~= nil then
			new_array[i] = re_array[i] 
		else 
			new_array[i] = new_item or (sdk.create_instance(td_name) or sdk.create_instance(td_name, true)):add_ref()
			sz = i + 1
			break
		end
	end
	
	return new_array, sz
end

--Adds a new entry to a Systems.Collections.Generic.List
local function append_to_list(list, new_item)
	list._items, list._size = append_to_array(list._items, new_item)
	return list._size, new_item
end

--Find the index containing a value (or value as a field) in a table
local function find_index(tbl, value, key)
	if key ~= nil then 
		for i, item in ipairs(tbl) do
			if item[key] == value then
				return i
			end
		end
	else
		for i, item in ipairs(tbl) do
			if item == value then
				return i
			end
		end
	end
end

--Combines elements of table B into table A
local function merge_tables(table_a, table_b)
	for key_b, value_b in pairs(table_b) do 
		table_a[key_b] = value_b 
	end
	return table_a
end

--Adds elements of indexed table B to indexed table A
local function extend_tables(table_a, table_b, unique_only)
	for i, value_b in ipairs(table_b) do 
		if not unique_only or not find_index(table_a, value_b) then
			table.insert(table_a, value_b)
		end
	end
	return table_a
end

--Check if a table of objects has an object with a given key/value pair, and get the key for that object
local function find_key(tbl, value, key)
	if key then
		for k, subtbl in pairs(tbl) do
			if subtbl and subtbl[key] == value then
				return k
			end
		end
	else
		for k, v in pairs(tbl) do
			if v == value then
				return k
			end
		end
	end
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
local function get_enumerable(m_obj, o_tbl)
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

--Create a resource
local function create_resource(resource_type, resource_path)
	local new_resource = resource_path and sdk.create_resource(resource_type, resource_path)
	if not new_resource then return end
	new_resource = new_resource:add_ref()
	return new_resource:create_holder(resource_type .. "Holder"):add_ref()
end

-- Edits the fields of a RE Managed Object using a dictionary of field/method names to values
local function edit_obj(obj, fields)
    for name, value in pairs(fields) do
		if obj["set"..name] ~= nil then --methods
			obj:call("set"..name, value) 
        elseif type(value) == "userdata" and value.type and tostring(value.type):find("RETypeDef") then --valuetypes
			write_valuetype(obj, name, value) 
        else --all other fields
            obj[name] = value 
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

--Copy fields from one object to another without cloning, optionally overriding with fields from 'override_fields':
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
clone = function(m_obj, fields)

	local new_obj = m_obj:MemberwiseClone():add_ref() -- I love memory leaks
	local td = new_obj:get_type_definition()
	
	for i, field in ipairs(new_obj:get_type_definition():get_fields()) do
		local data =  not field:is_static() and new_obj[field:get_name()]
		if data and sdk.is_managed_object(data) then
			if data:get_type_definition():is_a("System.Array") then
				new_obj[field:get_name()] = clone_array(data)
			elseif not data:get_type_definition():get_full_name():match("<(.+)>") then
				new_obj[field:get_name()] = clone(data)
			end
		end
	end
	--[[for i, method in ipairs(td:get_methods()) do
		local name = method:get_name()
		local set_method = (name:find("[Gg]et") == 1) and td:get_method(name:gsub("get", "set"):gsub("Get", "Set"))
		if set_method and set_method:get_num_params() == 1 and not set_method:is_static() and not method:get_return_type():is_a("System.Array") and not method:get_return_type():get_full_name():match("<(.+)>") then
			local data = method:call(new_obj)
			if data and sdk.is_managed_object(data) and not data:get_type_definition():is_a("System.Array") and not data:get_type_definition():get_full_name():match("<(.+)>") then
				set_method:call(new_obj, clone(data))
			end
		end
	end]]
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
	
	for i, sfix in pairs(new_poslist) do
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


--Key-specific wrapper functions by Killbox:

local function edit_hitdata(dmg_table, param_type, fields)
    for field_name, field_value in pairs(fields) do
        dmg_table.param[param_type][field_name] = field_value
    end
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

--Table of indexes into the param of a HIT_DT_TBL, labelled by their purpose
local hit_types = {
	s_c_only = {0, 1}, -- Stand+Crouch
	s_c_counter_only = {8, 9}, -- counter hit Stand+Crouch
	s_c_punish_only = {12, 13}, -- punish Stand+Crouch
	groundhit_only = {0, 1, 8, 9, 12, 13}, -- ALL ground hit + CH + PC
	airhit_only = {2, 10, 14}, -- all air hit + CH + PC
	all_counter = {8, 9, 10, 11}, -- Stand+Crouch+Air+Otg
	all_punish = {12, 13, 14, 15}, -- Stand+Crouch+Air+Otg
	allblock = {16, 17, 18, 19},
	allhit = {0, 1, 2, 8, 9, 10, 11, 12, 13, 14, 15}, -- all_air + allground
	hit = {
		stand = 0,
		crouch = 1,
		air = 2,
		otg = 3,
		unk = 4,
		counter_stand = 8,
		counter_crouch = 9,
		counter_air = 10,
		counter_otg = 11,
		punish_stand = 12,
		punish_crouch = 13,
		punish_air = 14,
		punish_otg = 15,
		block_stand = 16,
		block_crouch = 17,
		block_air = 18,
		block_otg = 19
	},
}

local inputs = {
	UP = 1,
	DOWN = 2,
	BACK = 4, 
	FORWARD = 8,
	LP = 16,
	MP = 32,
	HP = 64,
	LK = 128,
	MK = 256,
	HK = 512,
	NEUTRAL = 4096,
}

fn = {
	append_key = append_key,
	append_to_array = append_to_array,
	append_to_list = append_to_list,
	append_trigger_key = append_trigger_key,
	as_sfix = as_sfix,
	as_sfix2 = as_sfix2,
	as_sfix3 = as_sfix3,
	as_sfix4 = as_sfix4,
	clear_list = clear_list,
	clone = clone,
	clone_array = clone_array,
	copy_array = copy_array,
	copy_fields = copy_fields,
	clone_list_items = clone_list_items,
	create_poslist = create_poslist,
	create_resource = create_resource,
	edit_hit_dt_tbl = edit_hit_dt_tbl,
	edit_hitdata = edit_hitdata,
	edit_key = edit_obj, --alias
	edit_obj = edit_obj, 
	edit_objs= edit_objs,
	edit_steerkey = edit_steerkey,
	edit_tgroup = edit_tgroup,
	edit_tgrp_dict = edit_tgrp_dict,
	edit_triggerkey = edit_triggerkey,
	edit_worldkey = edit_worldkey,
	extend_tables = extend_tables,
	find_index = find_index,
	find_key = find_key,
	getC = getC,
	get_enum = get_enum,
	get_enumerable = get_enumerable,
	get_unique_name = get_unique_name,
	hit_types = hit_types,
	inputs = inputs,
	lua_get_array = lua_get_array, 
	lua_get_dict = lua_get_dict,
	merge_tables = merge_tables,
	read_sfix = read_sfix,
	recurse_def_settings = recurse_def_settings,
	to_isvec2 = to_isvec2,
	to_sfix = to_sfix,
	write_valuetype = write_valuetype,
}

return fn