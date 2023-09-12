-- MMDK - Moveset Mod Development Kit for Street Fighter 6
-- By alphaZomega
-- September 12, 2023
local version = "1.0.1"

player_data = {}
local changed = false
local ran_once = false
local can_setup = false
local time_last_reset = 0.0
local action_speed = 1.0
local hud_fn, tmp_fn

local was_changed = false
local function set_wc() 
	was_changed = was_changed or changed 
end

local gBattle = sdk.find_type_definition("gBattle")
local gCommand = gBattle:get_field("Command"):get_data()
local gPlayer = gBattle:get_field("Player"):get_data()
local gResource = gBattle:get_field("Resource"):get_data()
local gRollback = gBattle:get_field("Rollback"):get_data()
local gWork = gBattle:get_field("Work"):get_data()
local mot_info = sdk.create_instance("via.motion.MotionInfo"):add_ref()
local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
local speed_sfix = sdk.find_type_definition("via.sfix"):get_field("Zero"):get_data(nil)


local fn = require("MMDK\\functions")
local append_to_list = fn.append_to_list
local clone = fn.clone
local create_resource = fn.create_resource
local edit_obj = fn.edit_obj
local extend_tables = fn.extend_tables
local find_index = fn.find_index
local find_key = fn.find_key
local getC = fn.getC
local get_unique_name = fn.get_unique_name
local lua_get_array = fn.lua_get_array
local lua_get_dict = fn.lua_get_dict
local merge_tables = fn.merge_tables
local read_sfix = fn.read_sfix
local recurse_def_settings = fn.recurse_def_settings
local write_valuetype = fn.write_valuetype

local common_move_dict = {}
local engines = {}
local last_r_info = {}
local moveset_functions = {}
local spawned_projectiles = {}
local tooltips = {}

local characters = { 
	[1] = "Ryu", 
	[2] = "Luke", 
	[3] = "Kimberly", 
	[4] = "Chun-Li", 
	[5] = "Manon", 
	[6] = "Zangief", 
	[7] = "JP", 
	[8] = "Dhalsim", 
	[9] = "Cammy", 
	[10] = "Ken", 
	[11] = "Dee Jay", 
	[12] = "Lily", 
	[14] = "Rashid", 
	[15] = "Blanka", 
	[16] = "Juri", 
	[17] = "Marisa", 
	[18] = "Guile", 
	[20] = "E Honda", 
	[21] = "Jamie", 
}

local chara_list = {}
for chara_id, chara_name in pairs(characters) do 
	table.insert(chara_list, chara_name) 
end
table.sort(chara_list)
table.insert(chara_list, 1, "All Characters")

local default_mmsettings = {
	enabled = true,
	p1_hud = true,
	p2_hud = true,
	do_common_dict = false,
	research_enabled = false,
	research_p2 = false,
	transparent_window = false,
	fighter_options = {},
	hotkeys = {
		["Enable/Disable Autorun"] = "Alpha1",
		["Show Research Window"] = "Alpha2",
		["Framestep Backward"] = "Left",
		["Framestep Forward"] = "Right",
		["Pause/Resume"] = "Space",
		["Request Last Action"] = "Return",
		["Switch P1/P2"] = "Q",
	},
}

for i, chara_name in ipairs(chara_list) do
	default_mmsettings.fighter_options[chara_name] = {enabled=false, [chara_name]={enabled=true}}
	moveset_functions[chara_name] = {}
	tooltips[chara_name] = "Contains:"
	for i, path in ipairs(fs.glob([[MMDK\\]]..chara_name..[[\\.*.lua]], "$autorun")) do
		local filename = path:match("^.+\\(.+)%.lua")
		local lua_file = require(path:gsub(".lua", ""))
		moveset_functions[chara_name][i] = {chara_name=chara_name, filename=filename, lua=lua_file, name=(lua_file.mod_name ~= "" and lua_file.mod_name or filename)}
		moveset_functions[chara_name][i].tooltip = "Version " .. lua_file.mod_version .. "\n" .. (((lua_file.mod_author ~= "") and "By "..lua_file.mod_author.."\n") or "") .. "reframework\\autorun\\" .. path 
		if not default_mmsettings.fighter_options[chara_name][filename] then 
			default_mmsettings.fighter_options[chara_name][filename] = {enabled=true}
			default_mmsettings.fighter_options[chara_name].enabled = true
		end
		tooltips[chara_name] = tooltips[chara_name]  .. "\n	reframework\\autorun\\" .. path
	end
end

mmsettings = recurse_def_settings(json.load_file("MMDK\\MMDKsettings.json") or {}, default_mmsettings)

local hk = require("Hotkeys/Hotkeys")
local hk_timers = {}

hk.setup_hotkeys(mmsettings.hotkeys, default_mmsettings.hotkeys)

local act_id_enum = fn.get_enum("nBattle.ACT_ID")

local function tooltip(text)
	if imgui.is_item_hovered() then
		imgui.set_tooltip(text)
	end
end

local function managed_object_control_panel(object)
	if EMV then
		imgui.managed_object_control_panel(object)
	else
		object_explorer:handle_address(object)
	end
end

local PlayerData = {
	
	basic_fighter_data = {},
	
	--Create a new instance of this Lua class:
	new = function(self, player_index, do_make_dict)
		
		local data = {}
		local old_data = player_data[player_index]
		self.__index = self
		setmetatable(data, self)
		
		player_data[player_index] = data
		data.player_index = player_index
		data.moves_dict = {By_Name = {}, By_ID = {}, By_Index = {}}
		data.person = gResource.Data[player_index-1]
		data.chara_id = gPlayer.mPlayerType[player_index-1].mValue
		data.name = characters[data.chara_id]
		data.cPlayer = gPlayer.mcPlayer[player_index-1]
		data.hit_datas = gPlayer.mpLoadHitDataAddress[player_index-1]
		data.projectile_datas = data.person.Projectile
		data.engine = engines[player_index]
		data.pb = sdk.find_type_definition("gBattle"):get_field("PBManager"):get_data().Players[player_index-1]
		data.gameobj = data.pb:get_GameObject()
		data.drivebar_fn = old_data and old_data.drivebar_fn
		
		data.sfx_component = getC(getC(data.gameobj, "app.sound.SoundBattleObjectAccessor")["<BattleObjectRef>k__BackingField"], "app.sound.SoundContainerApp")
		data.sound_dict = data.sfx_component:get_RequestRefTable().SeRequestDataDictionary
		data.voice_dict = data.sfx_component:get_RequestRefTable().VoiceRequestDataDictionary
		
		data.vfx_by_ctr_id = {}
		local vfx_arrays = {
			gResource.VfxHolder.commonData.mStandardData,
			gResource.VfxHolder.systemData.mStandardData,
		}
		for i, vfx_container in pairs(lua_get_array(data.person.VfxDatas._items)) do
			table.insert(vfx_arrays, vfx_container.mStandardData)
		end
		for i, mStandardData in ipairs(vfx_arrays) do
			for i, std_data_settings in pairs(lua_get_array(mStandardData._items)) do
				local vfx_gameobj = scene:call("findGameObject(System.String)", std_data_settings.mData:get_Path():match(".+(epvs.+)%.pfb"))
				local ctr_tbl = data.vfx_by_ctr_id[std_data_settings.mID] or {elements={}}
				ctr_tbl.std_data_settings = std_data_settings
				ctr_tbl.std_data = getC(vfx_gameobj, "via.effect.script.EPVStandardData")
				if vfx_gameobj then
					for i, element in pairs(lua_get_array(ctr_tbl.std_data.Elements, true)) do
						ctr_tbl.elements[element.ID] = element --overwrite old System elements with new fighter-specific ones
					end
				end
				data.vfx_by_ctr_id[std_data_settings.mID] = ctr_tbl
			end
		end
		
		data.act_ids_by_trigger_idx = {}
		data.triggers = gCommand:get_mUserEngine()[player_index-1]:call("GetTrigger()")
		data.triggers_by_id = {}
		
		for i, trigger in pairs(data.triggers) do
			if trigger then 
				data.act_ids_by_trigger_idx[trigger.action_id] = i
				data.triggers_by_id[trigger.action_id] = data.triggers_by_id[trigger.action_id] or {}
				data.triggers_by_id[trigger.action_id][i] = trigger
			end
		end
		
		data.tgroups = {dict=gCommand.mpBCMResource[data.player_index-1].pTrgGrp}
		
		if do_make_dict then
			local act_list = lua_get_dict(data.person.FAB.StyleDict[0].ActionList, true, function(a, b) return a.ActionID < b.ActionID end)
			for i=0, #act_list do
				data:collect_fab_action(act_list[i])
			end
			if mmsettings.do_common_dict then
				local act_list = lua_get_dict(gResource.Data[6].FAB.StyleDict[0].ActionList, true, function(a, b) return a.ActionID < b.ActionID end)
				for i=0, #act_list do
					common_move_dict[act_list[i].ActionID] = data:collect_fab_action(act_list[i], true) or common_move_dict[act_list[i].ActionID]
				end
			end
			data:collect_additional()
		end
		
		return data
	end,
	
	-- Collect an action for moves_dict:
	collect_fab_action = function(self, fab_action, is_common)
		
		local act_id = fab_action.ActionID
		local name = act_id_enum.reverse_enum[act_id] or "_"..string.format("%03d", act_id)
		local move = {fab=fab_action, id=act_id, name=name, box={}}
		local person = self.person
		
		if is_common then 
			if self.moves_dict.By_ID[act_id] then return end --Prioritize non-common moves
			if common_move_dict[act_id] then --Collect non-common moves first
				move = common_move_dict[act_id]
				goto finish
			end
		end
		
		for j, keys_list in pairs(lua_get_array(fab_action.Keys)) do
			if keys_list._items[0] then
				local keytype_name = keys_list._items[0]:get_type_definition():get_name()
				for k, key in pairs(lua_get_array(keys_list, true)) do
					move[keytype_name] = move[keytype_name] or {}
					move[keytype_name][k] = key
					
					if keytype_name == "AttackCollisionKey" or keytype_name == "GimmickCollisionKey" then
						if key.AttackDataListIndex > -1 then --STRIKE, PROJECTILE, THROW
							local d = self.hit_datas and self.hit_datas[key.AttackDataListIndex]
							move.dmg = move.dmg or {}
							move.dmg[key.AttackDataListIndex] = d
							move.box.hit = move.box.hit or {}
							move.box.hit[k] = move.box.hit[k] or {}
							pcall(function()
								for b, box_id in pairs(key.BoxList) do
									move.box.hit[k][box_id.mValue] = person.Rect:Get(key.CollisionType, box_id.mValue)
								end
							end)
						elseif key.CollisionType == 3 then --PROXIMITY
							move.box.prox = move.box.prox or {}
							local tbl = {}
							pcall(function()
								for b, box_id in pairs(key.BoxList) do
									tbl[box_id.mValue] = person.Rect:Get(3, box_id.mValue)
								end
							end)
							move.box.prox[k] = tbl
						end
					end

					if keytype_name == "DamageCollisionKey" then
						move.box.hurt = move.box.hurt or {}
						local tbl = {}
						for b, box_id in pairs(key.HeadList.get_elements and key.HeadList or {}) do
							tbl.head = tbl.head or {}
							tbl.head[box_id.mValue] = person.Rect:Get(8, box_id.mValue)
						end
						for b, box_id in pairs(key.BodyList.get_elements and key.BodyList or {}) do
							tbl.body = tbl.body or {}
							tbl.body[box_id.mValue] = person.Rect:Get(8, box_id.mValue)
						end
						for b, box_id in pairs(key.LegList.get_elements and key.LegList or {}) do
							tbl.leg = tbl.leg or {}
							tbl.leg[box_id.mValue] = person.Rect:Get(8, box_id.mValue)
						end
						for b, box_id in pairs(key.ThrowList.get_elements and key.ThrowList or {}) do
							tbl.throw = tbl.throw or {}
							tbl.throw[box_id.mValue] = person.Rect:Get(7, box_id.mValue)
						end
						move.box.hurt[k] = tbl
					end
					
					--[[if keytype_name == "PushCollisionKey" then
						move.box.push = move.box.push or {}
						move.box.push[k] = person.Rect:Get(9, key.BoxNo) --fixme, 5 or 9 or 10?
					end]]
					
					if keytype_name == "ShotKey" then
						move.projectiles = move.projectiles or {}
						table.insert(move.projectiles, key.ActionId)
					end
					
					if keytype_name == "BranchKey" then
						move.branches = move.branches or {}
						table.insert(move.branches, key.Action)
					end
					
					if self.player_index then
						
						if keytype_name == "TriggerKey" then
							move.tgroups = move.tgroups or {}
							local tgroup = gCommand:GetTriggerGroup(self.player_index-1, key.TriggerGroup)
							local bits = tgroup.Flag:BitArray():add_ref()
							move.tgroups[key.TriggerGroup] = move.tgroups[key.TriggerGroup] or {tgroup=tgroup, bits=bits, tkeys={}}
							move.tgroups[key.TriggerGroup].tkeys[k] = key
						end
						
						--[[if keytype_name:find("SEKey") or keytype_name == "VoiceKey" then
							move[keytype_name].sfx = move[keytype_name].sfx or {}
							move[keytype_name].sfx[key.SoundID] = ((keytype_name == "SEKey") and self.sound_dict or self.voice_dict)[key.SoundID]
						end]]
						
						if keytype_name == "VfxKey" or keytype_name == "VFXKey" then
							move.vfx = move.vfx or {}
							--move[keytype_name].vfx = move.vfx
							local vfx_tbl = self.vfx_by_ctr_id[key.ContainerID] and self.vfx_by_ctr_id[key.ContainerID].elements[key.ElementID]
							if vfx_tbl and not find_index(move.vfx, vfx_tbl) then
								move.vfx[k] = vfx_tbl
							end
						end
						
						if keytype_name == "MotionKey" or keytype_name == "ExtMotionKey" or keytype_name == "FacialAutoKey" or keytype_name == "FacialKey" then
							local motion = (not keytype_name:find("Facial") and self.pb:get_MotComp()) or getC(self.pb:get_HeadObjRef(), "via.motion.Motion")
							motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", key.MotionType, key.MotionID, mot_info)
							move[keytype_name].names = move[keytype_name].names or {}
							local try, mot_name = pcall(mot_info.get_MotionName, mot_info)
							if try and mot_name and not find_index(move[keytype_name].names, mot_name) then
								table.insert(move[keytype_name].names, mot_name)
							end
							if keytype_name == "MotionKey" then
								move.mot_name = mot_name
								mot_name = mot_name:gsub("esf0%d%d_", "")
								name = get_unique_name(mot_name, self.moves_dict.By_Name)
								move.name = name
							end
						end
					end
				end
				if move[keytype_name] then
					move[keytype_name].list = keys_list
					move[keytype_name].keys_index = j-1
				end
			end
		end
		
		if self.player_index then
			if move.fab.Projectile.DataIndex > -1 then
				move.pdata = self.projectile_datas[move.fab.Projectile.DataIndex]
				move.vfx = move.vfx or move.pdata and self.vfx_by_ctr_id[move.pdata.VfxID] and {
					core = self.vfx_by_ctr_id[move.pdata.VfxID].elements[move.pdata.Core.Data.ElementID],
					aura = self.vfx_by_ctr_id[move.pdata.VfxID].elements[move.pdata.Aura.Data.ElementID],
					fade = self.vfx_by_ctr_id[move.pdata.VfxID].elements[move.pdata.FadeAway.Data.ElementID],
				}
			end
			
			move.trigger = self.triggers_by_id[move.id]
		end
		
		if move.pdata and not move.mot_name then
			name, move.name = name.." PROJ", move.name.." PROJ"
		end
		
		::finish::
		self.moves_dict.By_Name[name] = move
		self.moves_dict.By_ID[act_id] = move
		self.moves_dict.By_Index[#self.moves_dict.By_Index+1] = move
		
		return move
	end,
	
	-- Collect additional data that requires moves_dict to already be complete:
	collect_additional = function(self)
		
		if self.tgroups then
			for id, triggergroup in pairs(lua_get_dict(self.tgroups.dict)) do
				local bitarray = triggergroup.Flag:BitArray(); while not bitarray.get_elements do bitarray = triggergroup.Flag:BitArray() end
				for i, t_idx in pairs(bitarray:add_ref():get_elements()) do
					self.tgroups[id] = self.tgroups[id] or {}
					self.tgroups[id][t_idx.mValue] = self.triggers[t_idx.mValue] and self.moves_dict.By_ID[self.triggers[t_idx.mValue].action_id]
				end
			end
		end
		
		for id, move_obj in pairs(self.moves_dict.By_ID) do
			for j, act_id in pairs(move_obj.projectiles or {}) do
				action_obj = self.moves_dict.By_ID[act_id]
				move_obj.projectiles[j] = action_obj or "NOT_FOUND: "..act_id
				if action_obj and not action_obj.mot_name then
					self.moves_dict.By_Name[action_obj.name] = nil
					action_obj.name = get_unique_name(move_obj.name.." PROJ", self.moves_dict.By_Name)
					self.moves_dict.By_Name[action_obj.name] = action_obj
				end
			end
			if move_obj.branches and type(move_obj.branches[1]) == "number" then
				for j, act_id in pairs(move_obj.branches) do
					move_obj.branches[j] = self.moves_dict.By_ID[act_id] or "NOT_FOUND: "..act_id
				end
			end
			if move_obj.tgroups then --and type(move_obj.tgroups[1]) == "number" then
				for idx, tbl in pairs(move_obj.tgroups) do
					tbl.CancelList = self.tgroups[idx]
				end
			end
			if move_obj.name:find("A_") == 3 then move_obj.guest = self.moves_dict.By_Name[move_obj.name:gsub("A_", "D_")] end
			if move_obj.name:find("D_") == 3 then move_obj.owner = self.moves_dict.By_Name[move_obj.name:gsub("D_", "A_")] end
			--if move_obj.trigger then move_obj.name = "*" .. move_obj.name end
		end
	end,
	
	--Clone a FAB.ACTION 'old_id_or_obj' into a new available HIT_DT_TBL with 'new_id'. Returns a MMDK action object
	clone_action = function(self, old_id_or_obj, new_id)
		
		local act_dict = self.person.FAB.StyleDict[0].ActionList
		local old_action = ((type(old_id_or_obj)=="number") and act_dict[old_id_or_obj]) or old_id_or_obj.fab or old_id_or_obj
		local new_action = clone(old_action)
		new_action.ActionID = new_id
		new_action.Keys = old_action.Keys:MemberwiseClone():add_ref_permanent()
		new_action.Keys:call(".ctor(System.Int32)", old_action.Keys._size)
		old_action.Keys:call("CopyTo(via.fighter.ActionKey[])", new_action.Keys._items)
		
		for i=1, old_action.Keys._size do
			local key_list = old_action.Keys[i-1]:MemberwiseClone():add_ref_permanent()
			local old_arr = key_list._items
			key_list:call(".ctor(System.Int32)", key_list._size)
			for k=1, key_list._size do
				key_list[k-1] = clone(old_arr[k-1])
			end
			new_action.Keys._items[i-1] = key_list
		end
		act_dict[new_id] = new_action
		
		return self:collect_fab_action(new_action)
	end,
	
	-- Add a new motlist to a character using a new MotionType, making new animations accessible:
	add_dynamic_motionbank = function(self, motlist_path, new_motiontype)
		if sdk.find_type_definition("via.io.file"):get_method("exists"):call(nil, "natives/stm/"..motlist_path..".653") then
			local motion = getC(self.gameobj, "via.motion.Motion")
			local new_dbank
			local bank_count = motion:getDynamicMotionBankCount()
			for i=1, bank_count do
				local dbank = motion:getDynamicMotionBank(i-1)
				new_dbank = new_dbank or (dbank and dbank:get_MotionList() and ((dbank:get_MotionList():ToString():find(motlist_path)) or (dbank:get_BankID() == new_motiontype)) and dbank)
			end
			if not new_dbank then
				motion:setDynamicMotionBankCount(bank_count+1)
			end
			new_dbank = new_dbank or sdk.create_instance("via.motion.DynamicMotionBank"):add_ref()
			new_dbank:set_MotionList(create_resource("via.motion.MotionListResource", motlist_path))
			new_dbank:set_OverwriteBankID(true)
			new_dbank:set_BankID(new_motiontype)
			motion:setDynamicMotionBank(bank_count, new_dbank)
			
			return new_dbank
		end
	end,
	
	-- Add a new unique HitRect16 to a fighter and to a given AttackCollisionKey / DamageCollisionKey
	add_rect_to_col_key = function(self, col_key, boxlist_name, new_rect_id, boxlist_idx, rect_to_add)
		
		local box_type = (boxlist_name=="BoxList" and col_key.CollisionType) or (boxlist_name=="ThrowList" and 7) or 8
		local dict = self.person.Rect.RectList[box_type]
		local boxlist = col_key[boxlist_name]
		rect_to_add = rect_to_add or (boxlist[0] and self.person.Rect:Get(box_type, boxlist[0])) or sdk.create_instance("CharacterAsset.HitRect16"):add_ref()
		dict[new_rect_id] = rect_to_add
		
		if not find_key(boxlist, new_rect_id, "mValue") then
			if boxlist_idx and boxlist_idx < #boxlist then
				boxlist[boxlist_idx] = sdk.create_int32(new_rect_id):add_ref()
			else
				col_key[boxlist_name] = fn.append_to_array(boxlist, sdk.create_int32(new_rect_id):add_ref())
			end
		end
		
		return rect_to_add
	end,
	
	--Add a Trigger (by its index in the Triggers list) to a TriggerGroup, or create the TriggerGroup if it's not there
	add_to_triggergroup = function(self, tgroup_idx, new_trigger_idx)
		
		local tgroup = gCommand:GetTriggerGroup(self.player_index-1, tgroup_idx) or ValueType.new(sdk.find_type_definition("BCM.TRIGGER_GROUP"))
		local flag = tgroup.Flag
		list = {}; for i, elem in pairs(flag:BitArray():add_ref():get_elements()) do list[elem.mValue] = true end
		if not list[new_trigger_idx] then
			flag:addBit(new_trigger_idx)
			write_valuetype(tgroup, 0, flag)
			gCommand.mpBCMResource[self.player_index-1].pTrgGrp[tgroup_idx] = tgroup
			self.do_update_commands = true
		end
		return tgroup
	end,
	
	--Add or edit a Commands list with a list of inputs
	add_command = function(self, new_cmd_id, cmd_idx, input_list, cond_list, maxframe_list, fields, new_trigger_idxs)
		
		local cmds_lists = gCommand.mpBCMResource[self.player_index-1].pCommand
		local cmds_list = cmds_lists[new_cmd_id] or sdk.create_managed_array("BCM.COMMAND", 1):add_ref()
		local new_cmd = cmds_list[cmd_idx] or sdk.create_instance("BCM.COMMAND"):add_ref()
		new_cmd.input_num = #input_list
		
		edit_obj(new_cmd, fields or {})
		
		local frame_total = 0
		for j, button_id in ipairs(input_list) do
			local input = new_cmd.inputs[j-1]
			input.frame_num = maxframe_list[j]
			input:write_dword(20, button_id)
			input:write_dword(32, cond_list[j])
			frame_total = frame_total + maxframe_list[j]
			new_cmd.inputs[j-1] = input
		end
		
		new_cmd.max_frame = frame_total
		cmds_list[cmd_idx] = new_cmd
		cmds_lists[new_cmd_id] = cmds_list
		 
		if new_trigger_idxs then
			for i, new_trigger_idx in ipairs(new_trigger_idxs) do
				local trig = gCommand.mpBCMResource[self.player_index-1].pTrigger[new_trigger_idx]
				trig.norm.command_no = new_cmd_id
				trig.norm.command_ptr = cmds_list
				trig.norm.command_index = cmd_idx
			end
		end
		self.do_update_commands = true
		
		return cmds_list
	end,
	
	-- Clone a trigger with 'old_id' into a new available trigger with 'new_id'. Use 'tgroup_idx' to add it to a TriggerGroup (by TriggerGroup index)
	-- The new trigger will be given a free index as close as possible to 'max_priority' without exceeding it (important! An index of the wrong number will make the trigger have low priority / not work)
	clone_triggers = function(self, old_id, new_id, tgroup_idxs, max_priority)
		
		max_priority = max_priority or 167
		local user_engine = gCommand:get_mUserEngine()[self.player_index-1]
		local trg_list = user_engine:call("GetTrigger()")
		local old_trigs = self.triggers_by_id[old_id]
		local new_trigs = {}
		local new_trig_idx_dict = {}
		local new_trig_idxs = {}
		gCommand.StorageData.UserEngines[self.player_index-1]:set_TriggerMax(256)
		
		for i, trigger in pairs(old_trigs) do -- make list of clones from old_id triggers
			table.insert(new_trigs, clone(trigger))
			new_trigs[#new_trigs].action_id = new_id
		end
		
		local to_add = merge_tables({}, new_trigs)
		local rev_trg_list = {}
		
		local function append_trigger(idx, trigger)
			trg_list[idx] = trigger
			new_trig_idx_dict[idx] = trigger
			table.insert(new_trig_idxs, idx)
			for k, tgroup_idx in ipairs(tgroup_idxs or {}) do
				self:add_to_triggergroup(tgroup_idx, idx)
			end
			table.remove(to_add, 1)
		end
		
		for i, trigger in pairs(trg_list) do
			if not trigger and i <= max_priority then
				table.insert(rev_trg_list, 1, i)
			elseif trigger and trigger.action_id == new_id then
				trg_list[i] = nil
				table.insert(rev_trg_list, 1, i)
			end
		end
		
		for i, new_trig in ipairs(merge_tables({}, to_add)) do
			for j, trg_idx in ipairs(rev_trg_list) do
				if not trg_list[trg_idx] then
					append_trigger(trg_idx, new_trig)
					break
				end
			end
		end
		
		if to_add[1] then
			print("ERROR: Could not add " .. #to_add .. " new trigger(s) to " .. self.name .. ", all 256 triggers are taken!")
		end
		self.triggers_by_id[new_id] = new_trigs
		
		return new_trig_idx_dict, new_trig_idxs
	end,
	
	--Clone a HIT_DT_TBL with 'old_hit_id_or_dt' into a new available HIT_DT_TBL with 'new_hit_id'. Use action_obj to add it to a MMDK action object
	clone_dmg = function(self, old_hit_id_or_dt, new_hit_id, action_obj, src_key, target_key_index) 
		
		local old_hit_dt_tbl = ((type(old_hit_id_or_dt)=="userdata") and old_hit_id_or_dt) or self.hit_datas[old_hit_id_or_dt]
		local new_hit_dt_tbl = sdk.create_instance("nBattle.HIT_DT_TBL"):add_ref()
		for i, hit_dt in pairs(old_hit_dt_tbl.param) do
			new_hit_dt_tbl.param[i] = clone(hit_dt)
		end
		for i, hit_dt in pairs(old_hit_dt_tbl.common) do
			new_hit_dt_tbl.common[i] = clone(hit_dt)
		end
		local new_key
		self.hit_datas[new_hit_id] = new_hit_dt_tbl
		if action_obj then
			action_obj.AttackCollisionKey = action_obj.AttackCollisionKey or {list=action_obj.fab.Keys._items[10]}
			--impossible to find 'Internal game exception thrown in REMethodDefinition::invoke for get_Item' around here
			new_key = src_key or action_obj.AttackCollisionKey.list._items[action_obj.AttackCollisionKey.list._size-1]
			new_key = (new_key and clone(new_key)) or sdk.create_instance("CharacterAsset.AttackCollisionKey"):add_ref()
			new_key.AttackDataListIndex = new_hit_id
			action_obj.dmg = action_obj.dmg or {}
			action_obj.dmg[new_hit_id] = new_hit_dt_tbl
			if target_key_index and target_key_index < action_obj.AttackCollisionKey.list._size then 
				action_obj.AttackCollisionKey.list[target_key_index] = new_key
			end
			
		end
		return new_hit_dt_tbl, new_key
	end,
	
	--Clone a EPVStandardData.Element into a new one at on container 'target_container_id' and ID 'new_id'. Use action_obj to add it to a MMDK action object and then 'key_to_clone' to clone a VfxKey for it
	clone_vfx = function(self, src_element, target_container_id, new_id, action_obj, key_to_clone)
		
		key_to_clone = key_to_clone or action_obj.VfxKey.list._items[0]
		local clone_key = key_to_clone and clone(key_to_clone)
		local target_vfx_tbl = self.vfx_by_ctr_id[target_container_id]
		local target_list = target_vfx_tbl.std_data.Elements
		local new_vfx = clone(src_element)
		local new_arr = sdk.create_managed_array("via.effect.script.EPVStandardData.Element", target_list._size+1)
		
		for i, element in pairs(target_list._items) do
			if element.ID == new_id then
				new_vfx = element --no dupes
				goto action_obj_part
			end
			new_arr[i] = element
		end
		
		new_vfx.ID = new_id
		new_vfx.Owner = target_vfx_tbl.std_data:get_GameObject()
		write_valuetype(new_vfx, "GUID", sdk.find_type_definition("System.Guid"):get_method("NewGuid"):call(nil))
		new_arr[target_list._size] = new_vfx
		target_list._items = new_arr
		target_list._size = target_list._size + 1
		target_vfx_tbl.std_data.ElementNumOld = target_list._size
		target_vfx_tbl.elements[new_id] = new_vfx
		
		::action_obj_part::
		if action_obj then
			action_obj.vfx = action_obj.vfx or {}
			table.insert(action_obj.vfx, new_vfx)
			action_obj.VfxKey = action_obj.VfxKey or {list=action_obj.fab.Keys[30]}
			if not find_index(action_obj.VfxKey, new_id, "ElementID") then 
				append_to_list(action_obj.VfxKey.list, clone_key or sdk.create_instance("app.battle.VfxKey"):add_ref())
				action_obj.VfxKey.list[action_obj.VfxKey.list._size-1].ContainerID = target_container_id
				action_obj.VfxKey.list[action_obj.VfxKey.list._size-1].ElementID = new_id
			end
		end
		
		return new_vfx, clone_key
	end,
	
	--Takes a fighter name or ID and returns a simple/fake version of this class with a moves_dict for that fighter
	get_simple_fighter_data = function(self, chara_name_or_id)
		
		local chara_id = tonumber(chara_name_or_id) or find_key(characters, chara_name_or_id)
		if self.basic_fighter_data[chara_id] then 
			return self.basic_fighter_data[chara_id] 
		end
		local person = sdk.create_instance("app.BattleResource.Person"):add_ref()
		person.ActContainer:set_Asset(create_resource("via.fighter.FighterCharacterResource", string.format("product/charparam/esf/esf%03d/action/%03d.fchar", chara_id, chara_id)))
		person.FAB = sdk.create_instance("FAB"):add_ref()
		person.FAB:Convert(person.ActContainer, gResource.Data[6].ActContainer)
		if person.FAB.StyleDict[0] then
			local simple_playerdata = {moves_dict={By_Name = {}, By_ID = {}, By_Index={}}, person=person, name=chara_name, chara_id=chara_id, name=characters[chara_id], hit_datas={}}
			self.basic_fighter_data[chara_id] = simple_playerdata
			local isvec2 = ValueType.new(sdk.find_type_definition("nAction.isvec2"))
			for id, hit_dt_tbl in pairs(json.load_file("MMDK\\HIT_DTs\\"..characters[chara_id].." HIT_DT.json") or {}) do
				simple_playerdata.hit_datas[tonumber(id)] = sdk.create_instance("nBattle.HIT_DT_TBL"):add_ref()
				for p_name, param_tbl in pairs(hit_dt_tbl) do 
					for j, hit_dt in pairs(param_tbl) do
						local hdt_obj = sdk.create_instance("nBattle.HIT_DT"):add_ref()
						simple_playerdata.hit_datas[tonumber(id)][p_name][tonumber(j)] = hdt_obj
						for name, field_value in pairs(hit_dt) do
							if type(field_value) == "table" then
								isvec2:call(".ctor(System.Int16, System.Int16)", field_value.x, field_value.y)
								write_valuetype(hdt_obj, name, isvec2)
							else
								hdt_obj[name] = field_value
							end
						end
					end
				end
			end
			for i, fab_action in ipairs(lua_get_dict(person.FAB.StyleDict[0].ActionList, true, function(a, b) return a.ActionID < b.ActionID end)) do
				self.collect_fab_action(simple_playerdata, fab_action)
			end
			self.collect_additional(simple_playerdata)
			
			return simple_playerdata
		end
	end,
	
	update = function(self)
		
		if self.do_update_commands then
			self.do_update_commands = nil
			gCommand:SetCommand(self.player_index-1, gCommand.mpBCMResource[self.player_index-1].pCommand)
			gCommand:SetTriggerGroup(self.player_index-1, gCommand.mpBCMResource[self.player_index-1].pTrgGrp)
			gCommand:SetTrigger(self.player_index-1, gCommand.mpBCMResource[self.player_index-1].pTrigger)
			gCommand:SetupFixedParameter(self.player_index-1)
			self.do_refresh = true
		end
		
		if self.temp_fn then
			self.temp_fn()
		end
		if self.drivebar_fn then
			self.drivebar_fn()
		end
	end
}

fn.PlayerData = PlayerData

local function set_player_data(player_index)
	tmp_fn = function()
		tmp_fn = nil
		player_data[player_index] = PlayerData:new(player_index, true)
	end
end

local function set_huds(player_idx)
	
	hud_fn = function()
		local battle_hud = gRollback.m_battleHud
		
		if battle_hud and gPlayer.move_ctr > 3 and battle_hud.FighterStatusParts._items[0] then
			
			hud_fn = nil
			local p1_lifebar = battle_hud.FighterStatusParts[0].HudParts["<Control>k__BackingField"]:get_Child():get_Next():get_Next():get_Next()
			local p2_lifebar = battle_hud.FighterStatusParts[7].HudParts["<Control>k__BackingField"]:get_Child():get_Next():get_Next():get_Next()
			local col = ValueType.new(sdk.find_type_definition("via.Color"))
			
			if player_data[1] and mmsettings.p1_hud and ((not player_idx and mmsettings.fighter_options[player_data[1].name].enabled) or player_idx == 1)  then --Player1 Hud
				col.rgba = 0x00FF0000
				p1_lifebar:set_AdjustAddColor(col)
				local p1_drivebar = {battle_hud.FighterStatusParts[1].HudParts["<Control>k__BackingField"]:get_Child()}
				for i=1, 5 do  p1_drivebar[i+1] = p1_drivebar[i]:get_Next() end
				local colors = {Vector4f.new(1,0,1,1), Vector4f.new(1,0.2,1,1), Vector4f.new(1,0.4,1,1), Vector4f.new(1,0.6,1,1), Vector4f.new(1,0.8,1,1), Vector4f.new(1,1,1,1)}
				player_data[1].drivebar_fn = function()
					for i, color in ipairs(colors) do
						p1_drivebar[i]:set_ColorScale(color)
					end
				end
			end
			
			if player_data[2] and mmsettings.p2_hud and ((not player_idx and mmsettings.fighter_options[player_data[2].name].enabled) or player_idx == 2) then --Player2 Hud
				col.rgba = 0x84848400
				p2_lifebar:set_AdjustAddColor(col)
				local p2_drivebar = {battle_hud.FighterStatusParts[8].HudParts["<Control>k__BackingField"]:get_Child()}
				for i=1, 5 do  p2_drivebar[i+1] = p2_drivebar[i]:get_Next() end
				local colors = {Vector4f.new(0,1,1,1), Vector4f.new(0.2,1,1,1), Vector4f.new(0.4,1,1,1), Vector4f.new(0.6,1,1,1), Vector4f.new(0.8,1,1,1), Vector4f.new(1,1,1,1)}
				player_data[2].drivebar_fn = function()
					for i, color in ipairs(colors) do
						p2_drivebar[i]:set_ColorScale(color)
					end
				end
			end
		end
	end
end

local function check_make_playerdata()
	
	engines = {}
	local act_engines = characters[gPlayer.mPlayerType[0].mValue] and gRollback:GetLatestEngine().ActEngines
	if act_engines and act_engines[0] and act_engines[0]._Parent then
		engines = {[1]=act_engines[0]._Parent._Engine, [2]=act_engines[1]._Parent._Engine}
	end
	
	if not ran_once and mmsettings.enabled and engines[1] then 
		ran_once = true
		print(os.clock() .. " Getting MMDK player data...")
		can_setup = false
		
		--Apply MMDK:
		for i=1, 2 do
			local chara_name = characters[gPlayer.mPlayerType[i-1].mValue]
			if mmsettings.fighter_options[chara_name].enabled then 
				--Get data:
				player_data[i] = PlayerData:new(i, true)
				
				--Run functions to change moveset:
				local all_copy = (mmsettings.fighter_options["All Characters"].enabled and merge_tables({}, moveset_functions["All Characters"])) or {}
				for c, character_tbl in ipairs(extend_tables(all_copy, moveset_functions[chara_name])) do
					if mmsettings.fighter_options[character_tbl.chara_name][character_tbl.filename].enabled then
						print(os.clock() .. " Autorunning moveset function from '" .. character_tbl.name .. ".lua' for " .. chara_name)
						character_tbl.lua.apply_moveset_changes(player_data[i]) 
					end
				end
				
			end
		end
		set_huds() 
	end
end

re.on_application_entry("UpdateBehavior", function()
	
	if tmp_fn then
		tmp_fn()
	end
	check_make_playerdata()
	
end)

re.on_frame(function()
	
	if hud_fn then
		hud_fn()
	end
	
	pressed_skip_fwd, pressed_skip_bwd, pressed_pause = false, false, false
	last_r_info.last_action_speed = (action_speed ~= 0) and action_speed or last_r_info.last_action_speed or 1.0
	local p_idx = (mmsettings.research_p2 and 2) or 1
	local other_p_idx = ((p_idx == 1) and 2) or 1
	local data = player_data[p_idx]
	local other_data = player_data[other_p_idx]
	
	if reframework:is_drawing_ui() and gPlayer.move_ctr > 0 and engines[1] and (os.clock() - time_last_reset) > 0.5 then
		
		if not mmsettings.research_enabled or imgui.begin_window("MMDK - Moveset Research ", true, (mmsettings.transparent_window and 128) or 0) == false then 
			mmsettings.research_enabled = false
		else
			
			if not data or data.do_refresh or not next(data.moves_dict.By_ID) then
				imgui.end_window()
				set_player_data(p_idx)
				return nil
			end
			
			
			local r_info = data.research_info or {time_last_clicked=os.clock(), data=data, other_data=other_data}
			last_r_info = r_info
			data.research_info = r_info
			
			if not other_data or not next(other_data.moves_dict.By_ID) then
				imgui.end_window()
				set_player_data(other_p_idx)
				return nil
			end
			
			changed, mmsettings.research_p2 = imgui.checkbox("P2", mmsettings.research_p2); set_wc()  
			tooltip("View P2\n	Hotkey:    " .. hk.get_button_string("Switch P1/P2"))
			
			if hk.check_hotkey("Switch P1/P2") then
				mmsettings.research_p2 = not mmsettings.research_p2
			end
			
			if not r_info.names then
				r_info.names = {}
				r_info.id_map = {}
				for id, move in pairs(data.moves_dict.By_ID) do
					local name = move.name:gsub("*", "")
					table.insert(r_info.names, name)
					r_info.id_map[name] = tostring(id)
				end
				table.sort(r_info.names, function(name1, name2)  return tonumber(r_info.id_map[name1]) < tonumber(r_info.id_map[name2])  end)
			end
			
			imgui.same_line()
			imgui.text_colored(data.name, (mmsettings.research_p2 and 0xFFE0853D) or 0xFF3D3DFF)
			
			local current_act_id = data.engine:get_ActionID()
			local current_move = data.moves_dict.By_ID[current_act_id] or other_data.moves_dict.By_ID[current_act_id]
			local current_act_name = current_move and current_move.name:gsub("*", "")
			r_info.current_move = current_move
			
			if r_info.last_act_id ~= current_act_id and not r_info.was_typed then
				r_info.text = current_act_name
			end
			
			r_info.last_act_id = current_act_id
			
			imgui.same_line()
			imgui.text_colored((" "..string.format("%04d", current_act_id)):gsub(" 0", "   "):gsub(" 0", "   "):gsub(" 0", "   "), 0xFFAAFFFF)
			tooltip("Action ID")
			read_sfix(data.engine:get_ActionFrame())
			imgui.same_line()
			imgui.begin_rect()
			
			local engine_frame = read_sfix(data.engine:get_ActionFrame()) or 0
			local engine_endframe = read_sfix(data.engine:get_ActionFrameNum())
			r_info.last_engine_start_frame = ((engine_frame == 0) and r_info.frame_ctr) or r_info.last_engine_start_frame or 0
			r_info.frame_ctr = math.floor(r_info.last_engine_start_frame + engine_frame)
			
			local is_slow, is_paused = (action_speed ~= 1), (action_speed == 0)
			local act_frame_str = string.format("%04d", math.floor(engine_frame))
			local margin_frame_str = string.format("%04d", math.floor(read_sfix(data.engine:get_MarginFrame())))
			local end_frame_str = string.format("%04d", math.floor(engine_endframe))
			imgui.text((" " .. act_frame_str .. " / " .. margin_frame_str .. " : " .. end_frame_str):gsub(" 0", "   "):gsub(" 0", "   "):gsub(" 0", "   "))
			imgui.end_rect(2)
			tooltip("ActionFrame / MarginFrame : EndFrame")
			
			imgui.same_line()
			imgui.text_colored(current_act_name, 0xFFAAFFFF)
			tooltip("Action name")
			
			changed, action_speed = imgui.slider_float("Speed", action_speed, 0, 1)
			tooltip("Change moveset speed")
			if changed then
				speed_sfix = speed_sfix:call("From(System.Single)", action_speed)
			end
			
			local current_frame
			changed, current_frame = imgui.slider_float("Frame", read_sfix(data.engine.mParam.frame), 0, read_sfix(data.engine.mParam.frame_num))
			tooltip("Change move frame")
			if changed then
				current_frame = math.floor(current_frame)
				write_valuetype(data.engine, 84, speed_sfix:call("From(System.Single)", current_frame + 0.0))
				if current_move and (current_move.guest or current_move.owner) then 
					write_valuetype(engines[other_p_idx], 84, speed_sfix:call("From(System.Single)", current_frame + 0.0)) 
				end
			end
			
			local num = tonumber(r_info.text) or tonumber(r_info.id_map[r_info.text])
			
			if r_info.was_typed then imgui.begin_rect(); imgui.begin_rect() end
			
			changed, r_info.text = imgui.input_text("Request action", r_info.text)
			tooltip("Play an action by name or by ID")
			
			if r_info.was_typed then imgui.end_rect(2); imgui.end_rect(3) end
			
			if imgui.button("Request") or hk.check_hotkey("Request Last Action") then
				r_info.was_typed = true
				data.cPlayer:setAction(num or 0, sdk.find_type_definition("via.sfix"):get_field("Zero"):get_data(nil))
				r_info.last_engine_start_frame = r_info.frame_ctr
			end
			tooltip("Play an action by name or by ID\n	Hotkey:    " .. hk.get_button_string("Request Last Action"))
			
			imgui.same_line()
			pressed_skip_bwd = imgui.button("<--")
			tooltip("Step backward one frame and pause\n	Hotkey:    " .. hk.get_button_string("Framestep Backward") .. "     (HOLD to seek)")
			
			imgui.same_line()
			pressed_skip_fwd = imgui.button("-->")
			tooltip("Step forward one frame and pause\n	Hotkey:    " .. hk.get_button_string("Framestep Forward") .. "    (HOLD to seek)")
			
			imgui.same_line()
			pressed_pause = imgui.button((is_paused and "Resume") or "Pause")
			tooltip("Pause speed to 0%% or resume at the last chosen speed\n	Hotkey:    " .. hk.get_button_string("Pause/Resume"))
			
			if imgui.begin_list_box(data.name .. " action", #r_info.names) then
				for j, action_name in ipairs(r_info.names) do
					if imgui.menu_item(action_name, r_info.id_map[action_name], (r_info.new_action_idx==j), true) then
						r_info.new_action_idx = j
						r_info.text = action_name
						r_info.was_typed = true
						r_info.time_last_clicked = os.clock()
						data.cPlayer:setAction(tonumber(r_info.id_map[action_name]), sdk.find_type_definition("via.sfix"):get_field("Zero"):get_data(nil))
						r_info.last_engine_start_frame = r_info.frame_ctr
						if action_speed < 0.0 then 
							write_valuetype(data.engine, 84, data.engine:get_ActionFrameNum())
						end
					end
				end
				imgui.end_list_box()
			end
			
			r_info.was_typed = data.moves_dict.By_ID[num or -1234] and r_info.was_typed or changed
			
			if imgui.button("Apply moveset mod") then
				tmp_fn = function()
					tmp_fn = nil
					local all_copy = (mmsettings.fighter_options["All Characters"].enabled and merge_tables({}, moveset_functions["All Characters"])) or {}
					for c, character_tbl in ipairs(extend_tables(all_copy, moveset_functions[data.name])) do
						if mmsettings.fighter_options[character_tbl.chara_name][character_tbl.filename].enabled then
							character_tbl.lua.apply_moveset_changes(data) 
						end
					end
				end
				set_huds(data.player_index)
			end
			tooltip(tooltips[data.name])
			
			imgui.same_line()
			if imgui.button("Reload") then
				set_player_data(data.player_index)
			end
			tooltip("Refreshes this data")
			
			imgui.same_line()
			changed, r_info.research_sort_by_name = imgui.checkbox("ABC", r_info.research_sort_by_name)
			tooltip("Sort by name")
			
			if changed then 
				if r_info.research_sort_by_name then
					table.sort(r_info.names)
				else
					table.sort(r_info.names, function(name1, name2)  return tonumber(r_info.id_map[name1]) < tonumber(r_info.id_map[name2])  end)
				end
			end
			
			imgui.same_line()
			changed, mmsettings.do_common_dict = imgui.checkbox("Collect shared moves", mmsettings.do_common_dict); set_wc() 
			tooltip("Adds shared/common move data")
			
			if changed then
				tmp_fn = function()
					tmp_fn = nil
					player_data[1] = player_data[1] and PlayerData:new(1, true)
					player_data[2] = player_data[2] and PlayerData:new(2, true)
				end
			end
			
			imgui.same_line()
			if imgui.button("Dump HIT_DT json") then
				local hit_json = {}
				for key, hit_dt_tbl in pairs(lua_get_dict(data.hit_datas)) do
					hit_json[key] = {param={}, common={}}
					for n, name in ipairs({"param", "common"}) do
						for p, hit_dt in pairs(hit_dt_tbl[name]) do
							local tbl = {}
							for j, field in ipairs(hit_dt:get_type_definition():get_fields()) do
								if field:get_type():is_a("nAction.isvec2") then
									tbl[field:get_name()] = {x=field:get_data(hit_dt).x, y=field:get_data(hit_dt).y}
								else
									tbl[field:get_name()] = field:get_data(hit_dt)
								end
							end
							hit_json[key][name][p] = tbl
						end
					end
				end
				json.dump_file("MMDK\\HIT_DTs\\" .. data.name .. " HIT_DT.json", hit_json)
			end
			tooltip("Saves damage data to\n	reframework\\data\\MMDK\\HIT_DTs\\" .. data.name .. " HIT_DT.json")
			
			if EMV then 
			
				local function display_active_move(move, name, this_frame, keyname)
					
					this_frame = this_frame or current_frame
					
					if imgui.tree_node_str_id(keyname or name or "cmove", name or move.name) then
						
						local active_boxes, active_tgroups, active_vfx, active_branches
						if imgui.tree_node_str_id("ac", "Active Keys:  Frame " .. math.floor(this_frame)) then
							imgui.begin_rect()
							local active_keys = {}
							for title, tbl in pairs(move) do
								if title:find("Key") then
									for i, key in ipairs(tbl) do
										local sf, ef = key:get_StartFrame(), key:get_EndFrame()
										if this_frame >= sf and this_frame < ef then
											active_keys[title .. "[" .. i .. "]  Frames " .. sf .. " - ".. ef .. ""] = key
											if title:find("CollisionKey") then
												active_boxes = active_boxes or {}
												if title:find("Attack") then
													for b, box in pairs(move.box.hit and move.box.hit[i] or {}) do
														active_boxes["HitBox[" .. i .. "][" .. b .. "]:   Frames " .. sf .. " - " .. ef] = box
													end
													for b, box in pairs(move.box.prox and move.box.prox[i] or {}) do
														active_boxes["ProximityBox[" .. i .. "][" .. b .. "]:   Frames " .. sf .. " - " .. ef] = box
													end
												end
												if title:find("Damage") then
													for bodypart, part_tbl in pairs(move.box.hurt[i]) do
														for b, box in pairs(part_tbl) do
															active_boxes["HurtBox[" .. i .. "]." .. bodypart .. "[" .. b .. "]:   Frames " .. sf .. " - " .. ef] = box
														end
													end
												end
											end
											if title:lower():find("vfx") then
												active_vfx = active_vfx or {}
												active_vfx["VFX["..i.."]:   Frames " .. sf .. " - " .. ef] = move.vfx[i]
											end
											if title == "TriggerKey" then
												active_tgroups = active_tgroups or {}
												active_tgroups["TriggerGroup[" .. key.TriggerGroup .. "] " .. key.ConditionFlag .. ":   Frames " .. sf .. " - " .. ef] = move.tgroups[key.TriggerGroup].CancelList
											end
											if title == "BranchKey" then
												active_branches = active_branches or {}
												active_branches["Branch[" .. i .. "]:   Frames " .. sf .. " - " .. ef] = move.branches[i]
											end
										end
										if title == "ShotKey" and this_frame >= sf and this_frame < ef then
											local keyname = move.name .. ".Projectile[" .. i .. "] @ " .. r_info.frame_ctr ..  "f:   Frames " .. sf .. " - " .. ef .. " (" .. move.projectiles[i].fab.Frame .. "f)"
											spawned_projectiles[get_unique_name(move.projectiles[i].name .. " ", spawned_projectiles)] = not find_key(spawned_projectiles, keyname, "keyname") and {
												keyname = keyname,
												move = move.projectiles[i],
												start_frame = r_info.frame_ctr,
											} or nil
										end
									end
								end
							end
							
							if active_boxes and imgui.tree_node("Active Boxes") then
								imgui.begin_rect()
								EMV.read_imgui_element(active_boxes, nil, nil, "box")
								imgui.end_rect(2)
								imgui.tree_pop()
							end
							
							if active_tgroups and imgui.tree_node("Active TriggerGroups") then
								imgui.begin_rect()
								EMV.read_imgui_element(active_tgroups, nil, nil, "box")
								imgui.end_rect(2)
								imgui.tree_pop()
							end
							
							if active_branches and imgui.tree_node("Active Branches") then
								imgui.begin_rect()
								EMV.read_imgui_element(active_branches, nil, nil, "bra")
								imgui.end_rect(2)
								imgui.tree_pop()
							end
							
							if active_vfx and imgui.tree_node("Active VFX") then
								imgui.begin_rect()
								EMV.read_imgui_element(active_vfx, nil, nil, "vfx")
								imgui.end_rect(2)
								imgui.tree_pop()
							end
							
							EMV.read_imgui_element(active_keys, nil, nil, "ack")
							
							imgui.end_rect(2)
							imgui.spacing()
							imgui.tree_pop()
						end
						imgui.spacing()
						
						if imgui.tree_node("Action data") then
							imgui.begin_rect()
							EMV.read_imgui_element(move)
							imgui.end_rect(2)
							imgui.spacing()
							imgui.tree_pop()
						end
						
						imgui.tree_pop()
					end
				end	
			
				imgui.begin_child_window(nil, false, 0)
				if imgui.tree_node("[Lua Data]") then
					EMV.read_imgui_element(data)
					imgui.tree_pop()
				else
					tooltip("Access through the global variable 'player_data'")
				end
				
				if imgui.tree_node("TriggerGroups (CancelLists)") then
					EMV.read_imgui_element(data.tgroups)
					imgui.tree_pop()
				end
				
				if imgui.tree_node("Animations") then
					imgui.begin_rect()
					if not r_info.motion then
						tmp_fn = function()
							tmp_fn = nil
							r_info.motion = getC(data.gameobj, "via.motion.Motion")
							r_info.mixed_banks = {}
							local minfo = sdk.create_instance("via.motion.MotionInfo"):add_ref()
							for i, name in ipairs({"ActiveMotionBank", "DynamicMotionBank"}) do
								for j, motionbank in ipairs(lua_get_array(r_info.motion:call("get_"..name))) do
									local bank_id = motionbank:get_BankID()
									local name = motionbank:get_MotionList(); name = name and name:ToString():match("^.+%[.+/(.+)%.motlist%]")
									if name then
										r_info.mixed_banks[bank_id] = r_info.mixed_banks[bank_id] or {name=name}
										for k=0, r_info.motion:getMotionCount(bank_id) - 1 do
											r_info.motion:call("getMotionInfoByIndex(System.UInt32, System.UInt32, via.motion.MotionInfo)", bank_id, k, minfo)
											r_info.mixed_banks[bank_id][minfo:get_MotionID()] = minfo:get_MotionName():gsub("esf%d%d%d_", "")
										end
									end
								end
							end
							table.sort(r_info.mixed_banks)
							r_info.motion:set_PlaySpeed(1.0)
							data.pb:set_Enabled(false)
						end
					else
						local set = imgui.button("Set")
						imgui.same_line()
						imgui.push_id(123)
						changed, r_info.add_motlist_path = imgui.input_text("", r_info.add_motlist_path)
						imgui.pop_id()
						imgui.same_line()
						imgui.set_next_item_width(60)
						changed, r_info.add_motlist_id = imgui.input_text("New Motlist + BankID", r_info.add_motlist_id)
						if set and tonumber(r_info.add_motlist_id) then
							str = (r_info.add_motlist_path:match("stm\\(.+)") or r_info.add_motlist_path):gsub("\\", "/"):gsub("%.653", "")
							if data:add_dynamic_motionbank(str, tonumber(r_info.add_motlist_id)) then
								r_info.motion, r_info.mixed_banks = nil
								re.msg("Added DynamicMotionBank")
							end
						end
						for bank_id, bank_tbl in EMV.orderedPairs(r_info.mixed_banks or {}) do
							if imgui.tree_node_colored(bank_id, bank_id, bank_tbl.name) then
								imgui.begin_rect()
								local ctr, chara_ctr = 0, 0
								for motion_id, mot_name in EMV.orderedPairs(bank_tbl) do
									if type(motion_id) == "number" then
										ctr = ctr + 1; chara_ctr = chara_ctr + mot_name:len()
										if ctr % 5 ~= 1 and chara_ctr < 70 then imgui.same_line() else ctr, chara_ctr = 1, 0 end
										if imgui.button(mot_name) then
											for m, layer in ipairs(lua_get_array(r_info.motion:get_Layer())) do
												layer:set_BlendRate(1.0)
												layer:call("changeMotion(System.UInt32, System.UInt32, System.Single)", bank_id, motion_id, 0.0)
											end
										end
										tooltip(motion_id)
									end
								end
								imgui.end_rect(2)
								imgui.tree_pop()
							end
						end
					end
					imgui.end_rect(2)
					imgui.tree_pop()
				elseif r_info.motion then
					data.pb:set_Enabled(true)
					r_info.motion:set_PlaySpeed(0.0)
					for m, layer in ipairs(lua_get_array(r_info.motion:get_Layer())) do
						layer:set_BlendRate(0.0)
					end
					r_info.motion, r_info.mixed_banks = nil
				end
				
				if imgui.tree_node("Sound and Voice") then
					do_stop = imgui.button("Stop All")
					
					for i, name in ipairs({"sound", "voice"}) do
						if imgui.tree_node("Play " .. name .. "s by ID") then
							imgui.begin_rect()
							for i, req in ipairs(lua_get_dict(data[name.."_dict"], true, function(a, b) return a.UniqueID < b.UniqueID end)) do
								if i % 10 ~= 1 then imgui.same_line() end
								if imgui.button(req.UniqueID) then
									local trg_info_idx = find_key(data.sfx_component._TriggerInfoList._items, req.TriggerId, "_TriggerId") or 0
									if trg_info_idx then
										local snd_req = data.sfx_component:call("createRequestInfo", trg_info_idx, data.gameobj, data.gameobj, data.sfx_component._TriggerInfoList[trg_info_idx]._OffsetJointHash, false, false, 0, 0, nil, nil):add_ref()
										snd_req["<Container>k__BackingField"] = data.sfx_component
										data.sfx_component:call("trigger(soundlib.SoundManager.RequestInfo)", snd_req)
									end
								end
								if do_stop then
									data.sfx_component:call("stopTriggered(System.UInt32, via.GameObject, System.UInt32)", req.TriggerId, data.gameobj, 1.0)
								end
							end
							imgui.end_rect(2)
							imgui.tree_pop()
						end
					end
					imgui.tree_pop()
				end
				--[[
				if imgui.tree_node("Person") then
					managed_object_control_panel(data.person)
					imgui.tree_pop()
				end
				
				if data.engine and imgui.tree_node("Engine") then
					managed_object_control_panel(data.engine)
					imgui.tree_pop()
				end
				]]
				if data.moves_dict and imgui.tree_node("Moves Dict") then
					EMV.read_imgui_element(data.moves_dict)
					imgui.tree_pop()
				end
				
				if next(spawned_projectiles) and imgui.tree_node("Spawned Projectiles") then
					imgui.begin_rect()
					for proj_name, proj_tbl in EMV.orderedPairs(spawned_projectiles) do
						display_active_move(proj_tbl.move, proj_tbl.keyname .. "  " .. proj_tbl.move.name, r_info.frame_ctr - proj_tbl.start_frame, proj_name)
						if r_info.frame_ctr - proj_tbl.start_frame >= proj_tbl.move.fab.Frame + 30 then
							spawned_projectiles[proj_name] = nil
						end
					end
					imgui.end_rect(2)
					imgui.tree_pop()
				end
				
				if current_move and data.moves_dict then
					display_active_move(current_move)
					
					if current_move.guest then
						display_active_move(current_move.guest, "Guest Action: " .. current_move.guest.name, nil, current_move.guest.name)
					end
					
					if current_move.owner then
						display_active_move(current_move.owner, "Owner Action: " .. current_move.owner.name, nil, current_move.owner.name)
					end
				end
				
				imgui.spacing()
				imgui.end_child_window()
			else
				imgui.text("Get EMV Engine for more information\nhttps://github.com/alphazolam/EMV-Engine")
			end
			
			imgui.end_window()
		end
	end
	
	for p_idx, data in ipairs(player_data) do
		data:update()
	end
	
	if hk.check_hotkey("Enable/Disable Autorun") then
		mmsettings.enabled = not mmsettings.enabled
	end
	
	if hk.check_hotkey("Show Research Window") then
		mmsettings.research_enabled = not mmsettings.research_enabled
	end
	
	if mmsettings.research_enabled and engines[2] then
		
		hk_timers.bwd = hk.check_hotkey("Framestep Backward", true) and hk_timers.bwd or os.clock()
		hk_timers.fwd = hk.check_hotkey("Framestep Forward", true) and hk_timers.fwd or os.clock()
		
		if pressed_skip_bwd or ((os.clock() - hk_timers.bwd) > 0.25) or hk.check_hotkey("Framestep Backward") then
			pressed_pause = (action_speed ~= 0.0)
			local current_frame = read_sfix(engines[p_idx].mParam.frame)
			local value = math.floor(current_frame - 1 >= 0 and current_frame - 1 or 0) + 0.0
			write_valuetype(engines[p_idx], 84, speed_sfix:call("From(System.Single)", value))
			if last_r_info.current_move and (last_r_info.current_move.guest or last_r_info.current_move.owner) then 
				write_valuetype(engines[other_p_idx], 84, speed_sfix:call("From(System.Single)", value)) 
				engines[other_p_idx]:set_Speed(speed_sfix:call("From(System.Single)", 0))
			end
		end
		
		imgui.same_line()
		if pressed_skip_fwd or ((os.clock() - hk_timers.fwd) > 0.25) or hk.check_hotkey("Framestep Forward") then
			pressed_pause = (action_speed ~= 0.0)
			local current_frame, engine_endframe = read_sfix(engines[p_idx].mParam.frame), read_sfix(engines[p_idx]:get_ActionFrameNum())
			local value = math.floor(current_frame + 1 <= engine_endframe and current_frame + 1 or engine_endframe) + 0.0
			write_valuetype(engines[p_idx], 84, speed_sfix:call("From(System.Single)", value))
			if last_r_info.current_move and (last_r_info.current_move.guest or last_r_info.current_move.owner) then 
				write_valuetype(engines[other_p_idx], 84, speed_sfix:call("From(System.Single)", value)) 
				engines[other_p_idx]:set_Speed(speed_sfix:call("From(System.Single)", 0))
			end
		end
		
		if pressed_pause or hk.check_hotkey("Pause/Resume") then
			action_speed = (action_speed ~= 0) and 0 or last_r_info.last_action_speed
			speed_sfix = fn.to_sfix(action_speed)
			engines[1]:set_Speed(speed_sfix)
			engines[2]:set_Speed(speed_sfix)
		end
		
	end
	
	if was_changed then
		hk.update_hotkey_table(mmsettings.hotkeys)
		json.dump_file("MMDK\\MMDKsettings.json", mmsettings)
	end
	was_changed = false
	
end)

re.on_draw_ui(function()
	
	if imgui.tree_node("MMDK") then
		imgui.begin_rect()
		imgui.begin_rect()
		
		if imgui.button("Reset to Defaults") then
			mmsettings = recurse_def_settings({}, default_mmsettings)
			hk.reset_from_defaults_tbl(default_mmsettings.hotkeys)
			was_changed = true
		end
		
		changed, mmsettings.enabled = imgui.checkbox("Autorun", mmsettings.enabled); set_wc()
		tooltip("Enable/Disable automatic modification of fighter movesets")
		
		changed, mmsettings.p1_hud = imgui.checkbox("Modify P1 HUD", mmsettings.p1_hud); set_wc() 
		tooltip("Changes P1 HUD to purple when modded")
		
		changed, mmsettings.p2_hud = imgui.checkbox("Modify P2 HUD", mmsettings.p2_hud); set_wc() 
		tooltip("Changes P2 HUD to blue when modded")
		
		if imgui.tree_node("Enabled mods") then
			imgui.begin_rect()
			for i, chara_name in ipairs(chara_list) do
				changed, mmsettings.fighter_options[chara_name].enabled = imgui.checkbox(chara_name, mmsettings.fighter_options[chara_name].enabled); set_wc()
				tooltip("Enable/Disable autorun for this character\n" .. (i==1 and "Loads for all enabled characters\n" or "") .. tooltips[chara_name])
				imgui.same_line()
				local tree_open = imgui.tree_node_str_id(chara_name.."Options", "")
				tooltip("Select files to load")
				if tree_open then
					imgui.begin_rect()
					for c, character_tbl in pairs(moveset_functions[chara_name]) do
						local mm_tbl = mmsettings.fighter_options[chara_name][character_tbl.filename]
						changed, mm_tbl.enabled = imgui.checkbox(character_tbl.name, mm_tbl.enabled); set_wc()
						tooltip(character_tbl.tooltip)
						if mm_tbl.enabled and character_tbl.lua.imgui_options then 
							imgui.indent()
							
							character_tbl.lua.imgui_options()
							
							imgui.unindent()
						end
					end
					imgui.end_rect(2)
					imgui.spacing()
					imgui.tree_pop()
				end
				
			end
			imgui.end_rect(1)
			imgui.tree_pop()
		end
		
		if imgui.tree_node("Moveset research") then
			
			imgui.begin_rect()
			
			changed, mmsettings.research_enabled = imgui.checkbox("Show research window", mmsettings.research_enabled); set_wc() 
			tooltip("Display a moveset research window")
		
			changed, mmsettings.transparent_window = imgui.checkbox("Transparent window", mmsettings.transparent_window); set_wc()
			
			if imgui.tree_node("Hotkeys") then
				imgui.begin_rect()
				changed = hk.hotkey_setter("Enable/Disable Autorun"); set_wc()
				changed = hk.hotkey_setter("Show Research Window"); set_wc()
				changed = hk.hotkey_setter("Pause/Resume"); set_wc()
				changed = hk.hotkey_setter("Switch P1/P2"); set_wc()
				changed = hk.hotkey_setter("Framestep Backward"); set_wc()
				changed = hk.hotkey_setter("Framestep Forward"); set_wc()
				changed = hk.hotkey_setter("Request Last Action"); set_wc()
				imgui.end_rect(2)
				imgui.tree_pop()
			end
			
			if imgui.tree_node("gBattle") then
				for g, field in ipairs(sdk.find_type_definition("gBattle"):get_fields()) do
					local obj = field:get_data()
					if imgui.tree_node(field:get_name())  then
						managed_object_control_panel(obj)
						imgui.tree_pop()
					end
				end
				imgui.tree_pop()
			end
			
			if EMV and imgui.tree_node("Simple fighter data") then
				for id, name in pairs(characters) do
					if imgui.tree_node(name) then
						EMV.read_imgui_element(PlayerData:get_simple_fighter_data(name))
						imgui.tree_pop()
					end
				end
				imgui.tree_pop()
			end
			
			if EMV and next(common_move_dict) and imgui.tree_node("Common moves") then
				EMV.read_imgui_element(common_move_dict)
				imgui.tree_pop()
			end
			
			imgui.end_rect(2)
			imgui.tree_pop()
		end
		
		imgui.text("																			v"..version.."  |  By alphaZomega")   
		imgui.spacing()
		imgui.end_rect(2)
		imgui.end_rect(3)
		imgui.tree_pop()
	end	
	
end)

sdk.hook(sdk.find_type_definition("app.battle.bBattleFlow"):get_method("setupBattleDesc"), function() can_setup = true end)

sdk.hook(sdk.find_type_definition("app.BattleResource"):get_method("LoadUniqueAsset"), function() can_setup = true end) 

sdk.hook(sdk.find_type_definition("nAction.Engine"):get_method("Prepare"),
	function(args)
		if mmsettings.research_enabled and action_speed ~= 1.0 then
			sdk.to_managed_object(args[2]):call("set_Speed(via.sfix)", speed_sfix)
		end
	end
)

--Timing is critical
sdk.hook(sdk.find_type_definition("Command.CommandCheckInfo"):get_method("ResetOneShot"),
	function(args)
		if can_setup then
			if (os.clock() - time_last_reset > 0.25) then
				common_move_dict = {}
				player_data = {}
				ran_once = false
				print(os.clock() .. " Cleared MMDK player data")
			end
			time_last_reset = os.clock()
			check_make_playerdata()
		end
	end
)