-- MMDK - Moveset Mod Development Kit for Street Fighter 6 by alphaZomega

local mod_name = ""
local mod_version = 1.0
local mod_author = ""


local fn = require("MMDK\\functions") 

--Check functions.lua for descriptions of most of these:
local append_key = fn.append_key
local append_to_array = fn.append_to_array
local append_to_list = fn.append_to_list
local append_trigger_key = fn.append_trigger_key
local clear_list = fn.clear_list
local clone = fn.clone
local clone_array = fn.clone_array
local clone_list_items = fn.clone_list_items
local clone_list_items = fn.clone_list_items
local copy_fields = fn.copy_fields
local create_poslist = fn.create_poslist
local create_resource = fn.create_resource
local edit_hit_dt_tbl = fn.edit_hit_dt_tbl
local edit_obj = fn.edit_obj
local edit_objs = fn.edit_objs
local find_index = fn.find_index
local find_key = fn.find_key
local getC = fn.getC
local get_enum = fn.get_enum
local get_enumerator = fn.get_enumerator
local get_unique_name = fn.get_unique_name
local inputs = fn.inputs
local lua_get_array = fn.lua_get_array
local lua_get_dict = fn.lua_get_dict
local merge_tables = fn.merge_tables
local read_sfix = fn.read_sfix
local to_isvec2 = fn.to_isvec2
local to_sfix = fn.to_sfix
local write_valuetype = fn.write_valuetype

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

--This function runs on match start:
local function apply_moveset_changes(data)
	print(os.clock() .. " Running MMDK function for " .. data.name .. "\n	" .. mod_name .. " v" .. mod_version .. ((mod_author~="" and " by " .. mod_author) or ""))	
	
	--Local variables for the move dictionaries:
	local moves_by_id = data.moves_dict.By_ID
	local moves_by_name = data.moves_dict.By_Name
	
	--Fetch a basic copy of Ryu's move dict
	local ryu = data:get_simple_fighter_data("Ryu")
	local ryu_moves_by_id = ryu.moves_dict.By_ID
	
	
	--Mod code here
	
	
	return true
end

return {
	apply_moveset_changes = apply_moveset_changes,
	mod_version = mod_version,
	mod_name = mod_name,
	mod_author = mod_author,
}
