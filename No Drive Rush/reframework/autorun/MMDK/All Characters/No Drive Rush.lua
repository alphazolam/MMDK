-- MMDK - Moveset Mod Development Kit for Street Fighter 6 by alphaZomega

local mod_name = "No Drive Rush"
local mod_version = 1.0
local mod_author = "alphaZomega"


local tbls = require("MMDK\\tables") 

--Check tables.lua to see what's inside these:
local hit_types = tbls.hit_types
local characters = tbls.characters
local cat_flags = tbls.cat_flags
local inputs = tbls.inputs


local fn = require("MMDK\\functions") 

--Check functions.lua for descriptions of most of these:
local append_key = fn.append_key
local append_to_array = fn.append_to_array
local append_to_list = fn.append_to_list
local append_trigger_key = fn.append_trigger_key
local can_index = fn.can_index
local clear_list = fn.clear_list
local clone = fn.clone
local clone_array = fn.clone_array
local clone_list_items = fn.clone_list_items
local copy_array = fn.copy_array
local copy_fields = fn.copy_fields
local create_poslist = fn.create_poslist
local create_resource = fn.create_resource
local edit_hit_dt_tbl = fn.edit_hit_dt_tbl
local edit_obj = fn.edit_obj
local edit_objs = fn.edit_objs
local extend_list = fn.extend_list
local find_index = fn.find_index
local find_key = fn.find_key
local getC = fn.getC
local get_enum = fn.get_enum
local get_unique_name = fn.get_unique_name
local insert_array = fn.insert_array
local insert_list = fn.insert_list
local lua_get_array = fn.lua_get_array
local lua_get_dict = fn.lua_get_dict
local lua_get_enumerable = fn.lua_get_enumerable
local merge_tables = fn.merge_tables
local read_sfix = fn.read_sfix
local to_isvec2 = fn.to_isvec2
local to_sfix = fn.to_sfix
local write_valuetype = fn.write_valuetype

local function imgui_options()
	local changed, wc
	--Mod options for this mod in the main MMDK menu will be displayed from this function
end

--This function runs on match start:
local function apply_moveset_changes(data)
	print(os.clock() .. " Running MMDK function for " .. data.name .. "\n	" .. mod_name .. " v" .. mod_version .. ((mod_author~="" and " by " .. mod_author) or ""))	
	
	--Local variables for the move dictionaries:
	local moves_by_id = data.moves_dict.By_ID
	local moves_by_name = data.moves_dict.By_Name
	
	for name, move_tbl in pairs(moves_by_name) do
		if (name:find("ATK_CTA_[DR][AU]SH") or name:find("DRIVE_RUSH")) and move_tbl.WorldKey and move_tbl.trigger then 
			for id, trig in pairs(move_tbl.trigger) do
				trig.norm.ok_key_flags = 0
				trig.norm.dc_exc_flags = 0
				trig.sprt.ok_key_flags = 0
				trig.sprt.dc_exc_flags = 0
			end
		end
	end
	
	return true
end

return {
	apply_moveset_changes = apply_moveset_changes,
	imgui_options = imgui_options,
	mod_version = mod_version,
	mod_name = mod_name,
	mod_author = mod_author,
}
