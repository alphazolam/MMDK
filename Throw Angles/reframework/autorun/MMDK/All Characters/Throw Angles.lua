-- MMDK - Moveset Mod Development Kit for Street Fighter 6 by alphaZomega

local mod_name = "Throw Angles"
local mod_version = 1.0
local mod_author = "alphaZomega"


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
local copy_array = fn.copy_array
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

local target_types = fn.get_enum("CharacterAsset.ECamTargetType")

local default_options = {
	cut_frame = 60,
	target_type_idx = 4,
	cam_target_idx = 1,
}
local options = fn.recurse_def_settings(json.load_file("MMDK\\Throw Angles.json") or {}, default_options)

local function imgui_options()
	local changed, wc
	imgui.begin_rect()
	if imgui.button("Reset") then
		options = fn.recurse_def_settings({}, default_options); wc = true
	end
	changed, options.cut_frame = imgui.drag_int("Time between cuts", options.cut_frame, 1, 1, 10000); wc = wc or changed
	changed, options.target_type_idx = imgui.combo("Cam focal point", options.target_type_idx, target_types.names); wc = wc or changed
	changed, options.cam_target_idx = imgui.combo("Cam interest target", options.cam_target_idx, {"Thrown player", "Throwing player", "None"}); wc = wc or changed
	
	if wc then 
		json.dump_file("MMDK\\Throw Angles.json", options)
	end
	imgui.end_rect(2)
end

--This function runs on match start:
local function apply_moveset_changes(data)
	print(os.clock() .. " Running MMDK function for " .. data.name .. "\n	" .. mod_name .. " v" .. mod_version .. ((mod_author~="" and " by " .. mod_author) or ""))	
	
	--Local variables for the move dictionaries:
	local moves_by_id = data.moves_dict.By_ID
	local moves_by_name = data.moves_dict.By_Name
	
	local cool_angles = {
		{pos=to_sfix(Vector3f.new(31.0, 124.0, 262.0))},
		{pos=to_sfix(Vector3f.new(-140.0, 25.0, 230.0))},
		{pos=to_sfix(Vector3f.new(467.0, 67.0, 131.0))},
		{pos=to_sfix(Vector3f.new(-175.0, 178.0, 384.0))},
	}
	
	local di_counter_tbl --drive impact counter
	for name, move_tbl in pairs(moves_by_name) do
		if name:find("ATK_CTA") and move_tbl.CameraKey then 
			di_counter_tbl = move_tbl 
			break
		end
	end
	
	data.interests = {}
	local cf = options.cut_frame

	for name, move_tbl in pairs(moves_by_name) do
		local max_frame = move_tbl.fab.ActionFrame.MarginFrame - 15
		if move_tbl.guest and move_tbl.name:find("NGA") then
			local cf = ((cf > max_frame) and max_frame) or cf
			data.interests[move_tbl.id] = move_tbl
			local keys, last_pair_idx = move_tbl.fab.Keys[di_counter_tbl.CameraKey.keys_index]
			for i=0, math.floor(max_frame/cf) do
				math.randomseed(math.floor(os.clock()*100))
				local idx = last_pair_idx; while idx == last_pair_idx do  idx = math.random(1, #cool_angles)  end; last_pair_idx = idx
				if not keys._items[i] then
					append_to_list(keys, clone(di_counter_tbl.CameraKey[1]):add_ref_permanent()) --not sure why but this crashes after a few minutes without add_ref_permanent
				end
				write_valuetype(keys[i].Position, "Offset", cool_angles[idx].pos)
				keys[i]:set_StartFrame(i*cf)
				keys[i]:set_EndFrame((i*cf+cf < max_frame and i*cf+cf) or max_frame)
			end
		end
	end
	
	re.on_application_entry("PrepareRendering", function()
		if options.cam_target_idx ~= 3 then
			for i, data in ipairs(player_data) do
				if data and data.engine and data.interests and data.gameobj then
					local act_id = data.engine:get_ActionID()
					local followed_idx = ((options.cam_target_idx == 2) and i) or ((i==1 and 2) or 1)
					local followed_data = player_data[followed_idx] or getmetatable(data):new(followed_idx)
					for j, throw_tbl in pairs(data.interests) do
						if throw_tbl.id == act_id then
							local hip_joint = followed_data.gameobj:get_Transform():getJointByName("C_Hip")
							for i, key in pairs(lua_get_array(throw_tbl.fab.Keys[37]._items)) do
								key.Position.TargetType = options.target_type_idx - 1
								key.Interest.TargetType = options.target_type_idx - 1
								write_valuetype(key.Interest, "Offset", to_sfix(hip_joint:get_LocalPosition() * 100.0))
							end
						end
					end
				end
			end
		end
	end)
	
	return true
end
	


return {
	apply_moveset_changes = apply_moveset_changes,
	mod_version = mod_version,
	mod_name = mod_name,
	mod_author = mod_author,
	imgui_options = imgui_options,
}