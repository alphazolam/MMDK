-- MMDK - Moveset Mod Development Kit for Street Fighter 6 by alphaZomega

local mod_name = "Ken Donkey Kick"
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
	
	
	local ATK_D_KICK_L = data:clone_action(ryu_moves_by_id[1025], 939)
	if ATK_D_KICK_L then
		local move = ATK_D_KICK_L
		--100604 is Ryu's original bankID, so his original MotionKeys will work without edit:
		data:add_dynamic_motionbank("Product/Animation/esf/esf001/v00/motionlist/SpecialSkill/esf001v00_SpecialSkill_04.motlist", 100604) 
		
		local new_hit_dt_tbl, new_attack_key = data:clone_dmg(ryu_moves_by_id[1025].dmg[181], 1337, move, nil, #move.AttackCollisionKey-1)
		--edit_hit_dt_tbl(new_hit_dt_tbl, hit_types.allhit, {DmgValue=1000, DmgType=11, MoveTime=24, MoveType=13, HitStopOwner=20, HitStopTarget=20, MoveDest=to_isvec2(200, 70), JuggleLimit=10, HitStun=20, SndPower=4, HitmarkStrength=3})
		
		local new_hit_rect = data:add_rect_to_col_key(new_attack_key, "BoxList", 451, 0)
		edit_obj(new_hit_rect, {OffsetX=80, OffsetY=121, SizeX=54, SizeY=23})
		
		for i, atk_key in ipairs(move.AttackCollisionKey) do
			if atk_key.AttackDataListIndex ~= -1 then
				atk_key.AttackDataListIndex = 1337
				atk_key.BoxList[0] = sdk.create_int32(451)
			end
		end
		
		--Create custom hurtbox for the kicking leg:
		local new_hurt_rect = data:add_rect_to_col_key(move.DamageCollisionKey[2], "LegList", 777, 0)
		edit_obj(new_hurt_rect, {OffsetX=77, OffsetY=127, SizeX=48, SizeY=27})
		
		--Clone all triggers for Action #615 and add them to Action #939, then optionally add to TriggerGroup 0 with an optional target TriggerGroup ID of 118:
		local new_trigs_by_id, new_trig_ids = data:clone_triggers(615, 939, {0}, 118)
		
		for id, trig in pairs(new_trigs_by_id) do
			--Add a new Command as Command #29 (was free), then change the 0th element and give it button IDs back, forward with conditions 2,2, set some fields and give it to the new created trigger(s) with 'new_trig_ids':
			local new_cmds = data:add_command(29, 0, {inputs.BACK, inputs.FORWARD}, {2, 2}, {11, 11}, {total_frame=-1}, new_trig_ids)
			trig.norm.ok_key_flags = inputs.LK --Change the button input to LK
			copy_fields(trig.norm, trig.sprt) --For modern controls
		end
		
		--Copy effects from an existing Ken action 
		clone_list_items(moves_by_id[922].SEKey.list, move.SEKey.list)
		clone_list_items(moves_by_id[922].VoiceKey.list, move.VoiceKey.list)
		clone_list_items(moves_by_id[922].VfxKey.list, move.VfxKey.list)
		move.VoiceKey.list[0].SoundID = 10115 --SEYUH!
	end
	
	local ATK_D_KICK_M = data:clone_action(ryu_moves_by_id[1027], 940)
	if ATK_D_KICK_M then 
		
		local move = ATK_D_KICK_M
		local new_hit_dt_tbl, new_attack_key = data:clone_dmg(ryu_moves_by_id[1027].dmg[182], 1338, move, nil, #move.AttackCollisionKey-1)
		--edit_hit_dt_tbl(new_hit_dt_tbl, hit_types.allhit, {DmgValue=1100, MoveDest=to_isvec2(200, 70)})
		local new_hit_rect = data:add_rect_to_col_key(new_attack_key, "BoxList", 451, 0)
		edit_obj(new_hit_rect, {OffsetX=80, OffsetY=121, SizeX=54, SizeY=23})
		for i, atk_key in ipairs(move.AttackCollisionKey) do
			if atk_key.AttackDataListIndex ~= -1 then
				atk_key.AttackDataListIndex = 1338
				atk_key.BoxList[0] = sdk.create_int32(451)
			end
		end
	
		local new_trigs_by_id, new_trig_ids = data:clone_triggers(939, 940, {0}, 118)
		for id, trig in pairs(new_trigs_by_id) do
			trig.norm.ok_key_flags = inputs.MK
			copy_fields(trig.norm, trig.sprt)
		end
		
		clone_list_items(moves_by_id[921].SEKey.list, move.SEKey.list)
		clone_list_items(moves_by_id[921].VoiceKey.list, move.VoiceKey.list)
		clone_list_items(moves_by_id[921].VfxKey.list, move.VfxKey.list)
		move.VoiceKey.list[0].SoundID = 10301 --TUH!
		clear_list(move.BranchKey.list) --Prevents early cancel
	end
	
	local ATK_D_KICK_H = data:clone_action(ryu_moves_by_id[1029], 941)
	if ATK_D_KICK_H then 
		
		local move = ATK_D_KICK_H
		local new_hit_dt_tbl, new_attack_key = data:clone_dmg(ryu_moves_by_id[1029].dmg[183], 1339, move, nil, #move.AttackCollisionKey-1)
		--edit_hit_dt_tbl(new_hit_dt_tbl, hit_types.allhit, {DmgValue=1300, MoveDest=to_isvec2(235, 60)})
		local new_hit_rect = data:add_rect_to_col_key(new_attack_key, "BoxList", 451, 0)
		edit_obj(new_hit_rect, {OffsetX=80, OffsetY=121, SizeX=54, SizeY=23})
		for i, atk_key in ipairs(move.AttackCollisionKey) do
			if atk_key.AttackDataListIndex ~= -1 then
				atk_key.AttackDataListIndex = 1339
				atk_key.BoxList[0] = sdk.create_int32(451)
			end
		end
	
		local new_trigs_by_id, new_trig_ids = data:clone_triggers(939, 941, {0}, 118)
		for id, trig in pairs(new_trigs_by_id) do
			trig.norm.ok_key_flags = inputs.HK
			copy_fields(trig.norm, trig.sprt)
		end
		
		clone_list_items(moves_by_id[920].SEKey.list, move.SEKey.list)
		clone_list_items(moves_by_id[920].VoiceKey.list, move.VoiceKey.list)
		clone_list_items(moves_by_id[920].VfxKey.list, move.VfxKey.list)
		edit_obj(move.VoiceKey.list[0], {SoundID=10111, _StartFrame=17, _EndFrame=18}) --HUAHH!
	end
	
	local ATK_D_KICK_EX = data:clone_action(ryu_moves_by_id[1031], 942)
	if ATK_D_KICK_EX then 
		
		local move = ATK_D_KICK_EX
		local new_hit_dt_tbl, new_attack_key = data:clone_dmg(ryu_moves_by_id[1031].dmg[184], 1340, move, nil, #move.AttackCollisionKey-1)
		--edit_hit_dt_tbl(new_hit_dt_tbl, hit_types.allhit, {DmgValue=800, MoveDest=to_isvec2(500, 45), WallDest=to_isvec2(-325, 115), WallTime=31, WallStop=10, MoveTime=19, DmgPower=3, Attr0=5, CurveOwnID=2, CurveTgtID=3, DmgKind=2})
		
		local new_hit_rect = data:add_rect_to_col_key(new_attack_key, "BoxList", 451, 0)
		edit_obj(new_hit_rect, {OffsetX=80, OffsetY=121, SizeX=54, SizeY=23})
		for i, atk_key in ipairs(move.AttackCollisionKey) do
			if atk_key.AttackDataListIndex ~= -1 then
				atk_key.AttackDataListIndex = 1340
				atk_key.BoxList[0] = sdk.create_int32(451)
			end
		end
	
		local new_trigs_by_id, new_trig_ids = data:clone_triggers(939, 942, {0}, 136)
		for id, trig in pairs(new_trigs_by_id) do
			edit_obj(trig.norm, {ok_key_flags=(inputs.HK + inputs.LK + inputs.MK), ok_key_cond_flags=82016, attribute=4})
			edit_obj(trig, {focus_need=1, focus_consume=20000, category_flags=536887298})
			copy_fields(trig.norm, trig.sprt)
		end
		
		clone_list_items(moves_by_id[938].SEKey.list, move.SEKey.list)
		clone_list_items(moves_by_id[938].VoiceKey.list, move.VoiceKey.list)
		clone_list_items(moves_by_id[938].VfxKey.list, move.VfxKey.list)
		move.VoiceKey.list[0].SoundID = 10336 --AND SHUT UP!
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
