-- MMDK - Moveset Mod Development Kit for Street Fighter 6
-- By alphaZomega
-- December 5th, 2024
local version = "1.0.8"

player_data = {}
tmp_fns = {}
engines = {}
persons = {}

local ran_once = false
local can_setup = false
local time_last_reset = 0.0
local action_speed = 1.0
local changed = false
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
local minfo = sdk.create_instance("via.motion.MotionInfo"):add_ref()

local mot_fns = {}
local cached_names = {}
local common_move_dict = {}
local last_ri = {}
local moveset_functions = {}
local spawned_projectiles = {}
local tooltips = {}
local chara_list = {}

local fn = require("MMDK\\functions")

local append_to_list = fn.append_to_list
local clone = fn.clone
local convert_to_json_tbl = fn.convert_to_json_tbl
local create_resource = fn.create_resource
local edit_obj = fn.edit_obj
local edit_objs = fn.edit_objs
local extend_table = fn.extend_table
local find_index = fn.find_index
local find_key = fn.find_key
local getC = fn.getC
local get_unique_name = fn.get_unique_name
local lua_get_array = fn.lua_get_array
local lua_get_dict = fn.lua_get_dict
local merge_tables = fn.merge_tables
local read_sfix = fn.read_sfix
local recurse_def_settings = fn.recurse_def_settings
local tooltip = fn.tooltip
local write_valuetype = fn.write_valuetype


local tables = require("MMDK\\tables")

local characters = tables.characters
tables.cached_names = cached_names

local function add_person(chara_id)
	if persons[chara_id] then return persons[chara_id] end
	persons[chara_id] = sdk.create_instance("app.BattleResource.Person"):add_ref()
	persons[chara_id].ActContainer:set_Asset(create_resource("via.fighter.FighterCharacterResource", string.format("product/charparam/esf/esf%03d/action/%03d.fchar", chara_id, chara_id)))
	persons[chara_id].FAB = sdk.create_instance("FAB"):add_ref()
	if not pcall(function()
		persons[chara_id].FAB:Convert(persons[chara_id].ActContainer, gResource.Data[6].ActContainer)
	end) then 
		tmp_fns[chara_id.."Convert"] = function()
			tmp_fns[chara_id.."Convert"] = nil
			print("Retrying convert FAB for character " .. chara_id)
			add_person(chara_id)
		end 
	end
	return persons[chara_id]
end

--Cache all person.FABs
tmp_fns.add_chars = function()
	tmp_fns.add_chars = nil
	add_person(0)
	for chara_id, chara_name in pairs(characters) do 
		add_person(chara_id)
	end
end

for chara_id, chara_name in pairs(characters) do 
	cached_names[chara_name] = json.load_file("MMDK\\PlayerData\\" .. chara_name .. "\\" .. chara_name .. " Names.json") or {}
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
		["Enable/Disable Autorun"] = "F1",
		["Show Research Window"] = "F2",
		["Framestep Backward"] = "Left",
		["Framestep Forward"] = "Right",
		["Pause/Resume"] = "Space",
		["Request Last Action"] = "Return",
		["Switch P1/P2"] = "Q",
		["Play prev"] = "R",
		["Play next"] = "T",
		["Change to Facial Anims"] = "E",
	},
}

for i, chara_name in ipairs(chara_list) do
	
	local def = default_mmsettings.fighter_options[chara_name] or {enabled=false, [chara_name]={enabled=true}, ordered={chara_name}}
	default_mmsettings.fighter_options[chara_name] = def
	moveset_functions[chara_name] = {}
	tooltips[chara_name] = "Contains:"
	
	for p, path in ipairs(fs.glob([[MMDK\\]]..chara_name..[[\\.*.lua]], "$autorun")) do
		local filename = path:match("^.+\\(.+)%.lua")
		local lua_file = require(path:gsub(".lua", ""))
		moveset_functions[chara_name][p] = {chara_name=chara_name, filename=filename, lua=lua_file, name=(lua_file.mod_name ~= "" and lua_file.mod_name or filename)}
		moveset_functions[chara_name][p].tooltip = "Version " .. lua_file.mod_version .. "\n" .. (((lua_file.mod_author ~= "") and "By "..lua_file.mod_author.."\n") or "") .. "reframework\\autorun\\" .. path 
		has_all_chars_file = has_all_chars_file or (i == 1 and p > 1)
		def.enabled = def.enabled or has_all_chars_file
		if not def[filename] then 
			def.enabled = true
			def[filename] = {enabled=true}
			table.insert(def.ordered, filename)
		end
		tooltips[chara_name] = tooltips[chara_name]  .. "\n	reframework\\autorun\\" .. path
	end
end
has_all_chars_file = nil

mmsettings = recurse_def_settings(json.load_file("MMDK\\MMDKsettings.json") or {}, default_mmsettings)

for i, chara_name in ipairs(chara_list) do
	if #mmsettings.fighter_options[chara_name].ordered ~= #default_mmsettings.fighter_options[chara_name].ordered then
		mmsettings.fighter_options[chara_name].ordered = merge_tables({}, default_mmsettings.fighter_options[chara_name].ordered) --reset order when a file is added/removed
	end
end

local hk = require("Hotkeys/Hotkeys")
local hk_timers = {}

hk.setup_hotkeys(mmsettings.hotkeys, default_mmsettings.hotkeys)

local act_id_enum = fn.get_enum("nBattle.ACT_ID")

local function managed_object_control_panel(object)
	if EMV then
		imgui.managed_object_control_panel(object)
	else
		object_explorer:handle_address(object)
	end
end

--Class to manage a player:
PlayerData = {
	
	--Cache of PlayerData instances for unspawned characters:
	simple_fighter_data = {},
	
	--Cache of json files for moves_dicts
	cached_moves_dicts = {},
	
	--Accessor for 'persons'
	persons = persons,
	
	--MMDK version as number with no decimals
	version = tonumber(({version:gsub("%.", "")})[1]),
	
	--Create a new instance of this Lua class:
	new = function(self, player_index, do_make_dict, data)
		local pl_id = player_index - 1
		data = data or {}
		self.__index = self
		setmetatable(data, self)
		player_data[player_index] = data
		data.player_index = player_index
		data.moves_dict = {By_Name = {}, By_ID = {}, By_Index = {}}
		data.person = gResource.Data[pl_id]
		data.chara_id = gPlayer.mPlayerType[pl_id].mValue
		data.name = characters[data.chara_id]
		data.cPlayer = gPlayer.mcPlayer[pl_id]
		data.hit_datas = gPlayer.mpLoadHitDataAddress[pl_id]
		data.projectile_datas = data.person.Projectile
		data.engine = engines[player_index]
		data.pb = gBattle:get_field("PBManager"):get_data().Players[pl_id]
		data.gameobj = data.pb:get_GameObject()
		data.motion =  data.pb.mpMot
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
			for j, std_data_settings in pairs(lua_get_array(mStandardData._items)) do
				if not std_data_settings.mData:get_IsEmpty() then
					local vfx_gameobj = scene:call("findGameObject(System.String)", std_data_settings.mData:get_Path():match(".+(epvs.+)%.pfb"))
					local ctr_tbl = data.vfx_by_ctr_id[std_data_settings.mID] or {elements={}}
					ctr_tbl.std_data_settings = std_data_settings
					ctr_tbl.std_data = getC(vfx_gameobj, "via.effect.script.EPVStandardData")
					if vfx_gameobj then
						for k, element in pairs(lua_get_array(ctr_tbl.std_data.Elements, true)) do
							ctr_tbl.elements[element.ID] = element --overwrite old System elements with new fighter-specific ones
						end
					end
					data.vfx_by_ctr_id[std_data_settings.mID] = ctr_tbl
				end
			end
		end
		
		data.triggers = gCommand:get_mUserEngine()[pl_id]:call("GetTrigger()")
		data.triggers_by_act_id = {}
		
		for i, trigger in pairs(data.triggers) do
			if trigger then 
				data.triggers_by_act_id[trigger.action_id] = data.triggers_by_act_id[trigger.action_id] or {}
				data.triggers_by_act_id[trigger.action_id][i] = trigger
			end
		end
		
		data.rects = {}
		
		for i, dict in pairs(data.person.Rect.RectList) do
			data.rects[i] = {}
			for id, rect in pairs(lua_get_dict(dict)) do
				data.rects[i][id] = rect
			end
		end
		
		data.tgroups = {}
		data.tgroups_dict = gCommand.mpBCMResource[pl_id].pTrgGrp
		
		data.commands = {}
		for i, list in pairs(lua_get_dict(gCommand.mpBCMResource[pl_id].pCommand)) do
			data.commands[i] = {}
			for j, command in pairs(list) do
				if command then data.commands[i][j] = command end
			end
		end
		
		data.charge = {}
		for id, charge in pairs(lua_get_dict(gCommand.StorageData.UserEngines[pl_id].m_charge_infos)) do
			data.charge[id] = charge
		end
		
		data.atemi = lua_get_dict(gResource.Data[pl_id].Atemi)
		
		data.assist_combo = gCommand.mpBCMResource[pl_id].pAstCmb.RecipeData
		
		data.char_info = {
			PlData = gResource.Data[pl_id].FAB.PlData, 
			Styles = {},
		}
		for i = 0, gResource.Data[pl_id].FAB:GetStyleNum()-1 do
			data.char_info.Styles[i] = {}
			data.char_info.Styles[i].ParentStyleID = gResource.Data[pl_id].FAB:GetParentStyleID(i)
			data.char_info.Styles[i].StyleData = gResource.Data[pl_id].FAB:GetStyleData(i)
		end
		
		if do_make_dict then
			data:collect_moves_dict()
		end
		
		return data
	end,
	
	--Populate the moves_dict in full:
	collect_moves_dict = function(self)
		self.moves_dict = {By_Name = {}, By_ID = {}, By_Index = {}}
		--local act_list = lua_get_dict(self.person.FAB.StyleDict[0].ActionList, true, function(a, b) return a.ActionID < b.ActionID end)
		--for i=0, #act_list do
		--	self:collect_fab_action(act_list[i])
		--end
		for i=0, self.person.FAB.StyleDict:call("get_Count()") - 1 do
			local act_list = lua_get_dict(self.person.FAB.StyleDict[i].ActionList, true, function(a, b) return a.ActionID < b.ActionID end)
			for j=0, #act_list do
				if act_list[j] ~= nil then
					self:collect_fab_action(act_list[j])["_PL_StyleID"] = i;
				end
			end
 		end
		if mmsettings.do_common_dict then
			local act_list = lua_get_dict(gResource.Data[6].FAB.StyleDict[0].ActionList, true, function(a, b) return a.ActionID < b.ActionID end)
			for i=0, #act_list do
				common_move_dict[act_list[i].ActionID] = self:collect_fab_action(act_list[i], true) or common_move_dict[act_list[i].ActionID]
			end
		end
		self:collect_additional()
		
		if self.motion then
			cached_names[self.name] = cached_names[self.name] or {}
			for name, move in pairs(self.moves_dict.By_Name) do
				cached_names[self.name][string.format("%04d", move.id)] = name
			end
			json.dump_file("MMDK\\PlayerData\\" .. self.name .. "\\" .. self.name .. " Names.json", cached_names[self.name])
		end
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
		
		if self.player_index then --if its a player and not a simple_fighter_data
			if move.fab.Projectile.DataIndex > -1 then
				move.pdata = self.projectile_datas[move.fab.Projectile.DataIndex]
				move.vfx = move.vfx or move.pdata and self.vfx_by_ctr_id[move.pdata.VfxID] and {
					core = self.vfx_by_ctr_id[move.pdata.VfxID].elements[move.pdata.Core.Data.ElementID],
					aura = self.vfx_by_ctr_id[move.pdata.VfxID].elements[move.pdata.Aura.Data.ElementID],
					fade = self.vfx_by_ctr_id[move.pdata.VfxID].elements[move.pdata.FadeAway.Data.ElementID],
				}
			end
		end
		
		for j, keys_list in pairs(lua_get_array(fab_action.Keys)) do
			if keys_list._items[0] then
				local keytype_name = keys_list._items[0]:get_type_definition():get_name()
				for k, key in pairs(lua_get_array(keys_list, true)) do
					move[keytype_name] = move[keytype_name] or {}
					move[keytype_name][k] = key
					
					if keytype_name == "AttackCollisionKey" or keytype_name == "GimmickCollisionKey" or keytype_name == "OtherCollisionKey" then
						if key.AttackDataListIndex > -1 then --STRIKE, PROJECTILE, THROW
							move.dmg = move.dmg or {}
							move.dmg[key.AttackDataListIndex] = self.hit_datas and self.hit_datas[key.AttackDataListIndex]
							move.box.hit = move.box.hit or {}
							move.box.hit[k] = move.box.hit[k] or {}
							for b, box_id in pairs(key.BoxList) do
								move.box.hit[k][box_id.mValue] = self.rects[key.CollisionType or key.Kind][box_id.mValue] --person.Rect:Get(key.CollisionType, box_id.mValue) or 
							end
						elseif key.CollisionType == 3 then --PROXIMITY
							move.box.prox = move.box.prox or {}
							local tbl = {}
							pcall(function()
								for b, box_id in pairs(key.BoxList) do
									tbl[box_id.mValue] =  self.rects[3][box_id.mValue]
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
							tbl.head[box_id.mValue] =  self.rects[8][box_id.mValue]
						end
						for b, box_id in pairs(key.BodyList.get_elements and key.BodyList or {}) do
							tbl.body = tbl.body or {}
							tbl.body[box_id.mValue] = self.rects[8][box_id.mValue]
						end
						for b, box_id in pairs(key.LegList.get_elements and key.LegList or {}) do
							tbl.leg = tbl.leg or {}
							tbl.leg[box_id.mValue] = self.rects[8][box_id.mValue]
						end
						for b, box_id in pairs(key.ThrowList.get_elements and key.ThrowList or {}) do
							tbl.throw = tbl.throw or {}
							tbl.throw[box_id.mValue] = self.rects[8][box_id.mValue]
						end
						move.box.hurt[k] = tbl
					end
					
					--[[if keytype_name == "PushCollisionKey" then
						move.box.push = move.box.push or {}
						move.box.push[k] =data.rects[9][box_id.mValue] --fixme, 5 or 9 or 10?
					end]]
					
					if keytype_name == "ShotKey" then
						move.projectiles = move.projectiles or {}
						table.insert(move.projectiles, key.ActionId)
					end
					
					if keytype_name == "BranchKey" then
						move.branches = move.branches or {}
						table.insert(move.branches, key.Action)
					end
					
					if keytype_name == "TriggerKey" then
						move.tgroups = move.tgroups or {}
						local tgroup = self.player_index and gCommand:GetTriggerGroup(self.player_index-1, key.TriggerGroup)
						move.tgroups[key.TriggerGroup] = move.tgroups[key.TriggerGroup] or {tgroup=tgroup, tkeys={}, bits={}}
						move.tgroups[key.TriggerGroup].tkeys[k] = key
						if tgroup then
							move.tgroups[key.TriggerGroup].bits = tgroup.Flag:BitArray():add_ref()
						end
					end
					
					if keytype_name == "LockKey" and key.Type == 2 and self.hit_datas and self.hit_datas[key.Param02] then
						move.dmg = move.dmg or {}
						move.dmg[key.Param02] = self.hit_datas[key.Param02]
					end
					
					if self.player_index then
						
						--[[if keytype_name:find("SEKey") or keytype_name == "VoiceKey" then
							move[keytype_name].sfx = move[keytype_name].sfx or {}
							move[keytype_name].sfx[key.SoundID] = ((keytype_name == "SEKey") and self.sound_dict or self.voice_dict)[key.SoundID]
						end]]
						
						if keytype_name:lower() == "vfxkey" then
							move.vfx = move.vfx or {}
							local vfx_tbl = self.vfx_by_ctr_id[key.ContainerID] and self.vfx_by_ctr_id[key.ContainerID].elements[key.ElementID]
							if vfx_tbl and not find_index(move.vfx, vfx_tbl) then
								move.vfx[k] = vfx_tbl
							end
						end
						
						if self.motion and (keytype_name == "MotionKey" or keytype_name == "ExtMotionKey" or keytype_name == "FacialAutoKey" or keytype_name == "FacialKey") then
							local motion = (keytype_name:find("Facial") and self.motion_fac) or self.motion
							motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", key.MotionType, key.MotionID, mot_info)
							move[keytype_name].names = move[keytype_name].names or {}
							local try, mot_name = pcall(mot_info.get_MotionName, mot_info)
							if try and mot_name and not find_index(move[keytype_name].names, mot_name) then
								table.insert(move[keytype_name].names, mot_name)
							end
							if keytype_name == "MotionKey" and self.motion then
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
		
		move.trigger = self.triggers_by_act_id[move.id]
		
		if move.pdata and not move.mot_name then
			name, move.name = name.." PROJ", move.name.." PROJ"
		end
		
		if not self.motion and characters[self.chara_id] then
			move.name = cached_names[self.name][string.format("%04d", move.id)] or move.name
			name = move.name
		end
		
		::finish::
		self.moves_dict.By_Name[name] = move
		self.moves_dict.By_ID[act_id] = move
		self.moves_dict.By_Index[#self.moves_dict.By_Index+1] = move
		
		return move
	end,
	
	-- Collect additional data that requires moves_dict to already be complete:
	collect_additional = function(self)
		
		if self.tgroups_dict then
			for id, triggergroup in pairs(lua_get_dict(self.tgroups_dict)) do
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
			if move_obj.branches then
				for j, act_id in pairs(move_obj.branches) do
					if type(move_obj.branches[j]) == "number" then
						move_obj.branches[j] = self.moves_dict.By_ID[act_id] or "NOT_FOUND: "..act_id
					end
					if type(move_obj.branches[j]) == "table" then
						local typex = (move_obj.BranchKey[j]:get_TypeX() == 63) and "t_input" or "catch"
						local bp = move_obj.branches[j].branch_parents or {}
						bp[typex] = bp[typex] or {}
						bp[typex][move_obj.name] = move_obj
						move_obj.branches[j].branch_parents = bp
					end
				end
			end
			if move_obj.tgroups then --and type(move_obj.tgroups[1]) == "number" then
				for idx, tbl in pairs(move_obj.tgroups) do
					tbl.CancelList = self.tgroups[idx]
				end
			end
			if move_obj.LockKey then
				move_obj.guest = self.moves_dict.By_ID[move_obj.LockKey[1].Param01]
				if move_obj.guest then move_obj.guest.owner = move_obj end
			end
		end
	end,
	
	--Dumps a json file of this PlayerData's hit_datas. 'hit_datas' and 'path' are optional
	dump_hit_dt_json = function(self, path, hit_datas)
		hit_datas = hit_datas or self.hit_datas
		hit_datas = (type(hit_datas)=="table" and hit_datas) or lua_get_dict(hit_datas)
		local hit_json = convert_to_json_tbl(hit_datas, nil, nil, nil, true)
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " HIT_DT.json", hit_json)
	end,
	
	--Dumps a json file of this PlayerData's triggers. 'triggers_by_act_id' and 'path' are optional
	dump_trigger_json = function(self, path, triggers_by_act_id)
		triggers_by_act_id = triggers_by_act_id or self.triggers_by_act_id
		triggers_by_act_id = (type(triggers_by_act_id)=="table" and triggers_by_act_id) or lua_get_array(triggers)
		local trig_json = convert_to_json_tbl(triggers_by_act_id)
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " triggers.json", trig_json)
	end,
	
	--Dumps a json file of this PlayerData's commands. 'commands' and 'path' are optional
	dump_commands_json = function(self, path, commands)
		commands = commands or self.commands
		commands = (type(commands)=="table" and commands) or lua_get_dict(commands)
		local cmd_json = convert_to_json_tbl(commands)
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " commands.json", cmd_json)
	end,
	
	--Dumps a json file of this PlayerData's tgroups. 'tgroups' and 'path' are optional
	dump_tgroups_json = function(self, path, tgroups)
		tgroups = tgroups or self.tgroups
		local tgroup_json = {}
		for id, group_tbl in pairs(tgroups) do
			id = string.format("%03d", id)
			tgroup_json[id] = {}
			for trigger_id, move_tbl in pairs(group_tbl) do
				tgroup_json[id][string.format("%03d", trigger_id)] = move_tbl.id .. " " .. move_tbl.name
			end
		end
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " tgroups.json", tgroup_json)
	end,
	
	--Dumps a json file of this PlayerData's rects. 'rects' and 'path' are optional
	dump_rects_json = function(self, path, rects)
		rects = rects or self.rects
		local rect_json = {}
		for list_id, rect_list in pairs(rects) do
			list_id = string.format("%02d", list_id)
			rect_json[list_id] = {}
			for rect_id, rect in pairs(rect_list) do
				rect_json[list_id][string.format("%03d", rect_id)] = convert_to_json_tbl(rect)
			end
		end
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " rects.json", rect_json)
	end,
	
	--Dumps a json file of this PlayerData's charges. 'charges' and 'path' are optional
	dump_charge_json = function(self, path, charges)
		charges = charges or self.charge
		local charge_json = {}
		for charge_id, charge in pairs(charges) do
			charge_id = string.format("%02d", charge_id)
			charge_json[charge_id] = convert_to_json_tbl(charge)
		end
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " charge.json", charge_json)
	end,
	
	--Dumps a json file of this data's moves_dict. 'moves_dict' and 'path' are optional
	dump_moves_dict_json = function(self, path, moves_dict)
		local json_data = {}
		local bad_fnames = {guest=1, owner=1, box=1, dmg=1, tgroups=1, branches=1, projectiles=1, trigger=1, branch_parents=1, vfx=1}
		for mname, move_tbl in pairs(moves_dict or self.moves_dict.By_Name) do
			json_data[mname] = {name=move_tbl.name, id=move_tbl.id}
			for fname, field in pairs(move_tbl) do
				if type(field) ~= "table" or not bad_fnames[fname] then
					json_data[mname][fname] = convert_to_json_tbl(field, nil, false, (fname=="fab"))
				end
			end
		end
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " moves_dict.json", json_data)
		return json_data
	end,
	
	--Dumps a json file of this PlayerData's atemis. 'atemis' and 'path' are optional
	dump_atemi_json = function(self, path, atemis)
		atemis = atemis or self.atemi
		local atemi_json = {}
		for atemi_id, atemi in pairs(atemis) do
			atemi_id = string.format("%02d", atemi_id)
			atemi_json[atemi_id] = convert_to_json_tbl(atemi)
		end
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " atemi.json", atemi_json)
	end,
	
	--Dumps a json file of this PlayerData's assist combos. 'assist_combo' and 'path' are optional
	dump_assist_combo_json = function(self, path, assist_combo)
		assist_combo = assist_combo or self.assist_combo
		local ac_json = {}
		for idx, recipedata in pairs(lua_get_array(self.assist_combo)) do
			idx = string.format("%03d", idx-1)
			ac_json[idx] = convert_to_json_tbl(recipedata)
		end
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " assist_combo.json", ac_json)
	end,
	
	dump_char_info_json = function(self, path, char_info)
		char_info = char_info or self.char_info
		local cinfo_json = convert_to_json_tbl(char_info)
		json.dump_file(path or "MMDK\\PlayerData\\" .. self.name .."\\" .. self.name .. " char_info.json", cinfo_json)
	end,
	
	--Returns an unmodified moves dict from a json file or from cache, and creates it if its not there (or creates all missing moves dicts)
	get_moves_dict_json = function(self, chara_name, path, collect_all)
		chara_name = chara_name or self.name
		path = path or "MMDK\\PlayerData\\" .. chara_name .. "\\".. chara_name .." moves_dict.json"
		if self.cached_moves_dicts[chara_name] then return self.cached_moves_dicts[chara_name] end
		local f = io.open("MMDK\\PlayerData\\" .. chara_name .. "\\".. chara_name .." moves_dict.json", "r")
		if f == nil then
			if collect_all then
				re.msg("Moves Dict not found! Dumping action data for all characters, this may take a minute...")
				for ch_id, ch_name in pairs(characters) do
					self:get_moves_dict_json(ch_name, nil, false)
				end
			else
				local tmp_data = self:get_simple_fighter_data(chara_name)
				self.cached_moves_dicts[chara_name] = tmp_data:dump_moves_dict_json(path)
			end
		else
			io.close(f)
		end
		self.cached_moves_dicts[chara_name] = self.cached_moves_dicts[chara_name] or (collect_all ~= false and json.load_file(path))
		
		return self.cached_moves_dicts[chara_name]
	end,
	
	--Clone a MMDK move / ActionID 'old_id_or_obj' into a new move with the ActionID 'new_id'. Returns the new move Lua object
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
	
	-- Add a new motlist using the path 'motlist_path' to a character using type 'new_motiontype', making new animations accessible. Returns the new DynamicMotionBank
	add_dynamic_motionbank = function(self, motlist_path, new_motiontype, via_motion)
		if sdk.find_type_definition("via.io.file"):get_method("exists"):call(nil, "natives/stm/"..motlist_path..".653") then
			local motion = via_motion or getC(self.gameobj, "via.motion.Motion")
			local new_dbank
			local bank_count = motion:getDynamicMotionBankCount()
			local insert_idx = bank_count
			for i=0, bank_count-1 do
				local dbank = motion:getDynamicMotionBank(i)
				if dbank and (dbank:get_BankID() == new_motiontype) or (dbank:get_MotionList() and dbank:get_MotionList():ToString():lower():find(motlist_path:lower())) then
					new_dbank, insert_idx = dbank, i
					break
				end
			end
			if not new_dbank then
				motion:setDynamicMotionBankCount(bank_count+1)
			end
			new_dbank = new_dbank or sdk.create_instance("via.motion.DynamicMotionBank"):add_ref()
			new_dbank:set_MotionList(create_resource("via.motion.MotionListResource", motlist_path))
			new_dbank:set_OverwriteBankID(true)
			new_dbank:set_BankID(new_motiontype)
			motion:setDynamicMotionBank(insert_idx, new_dbank)
			
			return new_dbank
		end
	end,
	
	-- Add a new unique HitRect16 to a fighter and to a given AttackCollisionKey / DamageCollisionKey. Returns the modified AttackCollisionKey
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
	
	--Add a Trigger (by its index in the Triggers list) to a TriggerGroup, or create the TriggerGroup if it's not there. Returns the trigger group at 'tgroup_idx'
	add_to_triggergroup = function(self, tgroup_idx, trigger_idx)
		
		local tgroup = gCommand:GetTriggerGroup(self.player_index-1, tgroup_idx) or ValueType.new(sdk.find_type_definition("BCM.TRIGGER_GROUP"))
		local flag = tgroup.Flag
		local list = {}; for i, elem in pairs(flag:BitArray():add_ref():get_elements()) do list[elem.mValue] = true end
		if not list[trigger_idx] then
			flag:addBit(trigger_idx)
			write_valuetype(tgroup, 0, flag)
			gCommand.mpBCMResource[self.player_index-1].pTrgGrp[tgroup_idx] = tgroup
			self.do_update_commands = true
		end
		return tgroup
	end,
	
	--Takes CommandList index 'new_cmdlist_id' and adds a new command at index 'new_cmd_idx' of it. Optionally takes 'fields' table to apply afterwards, and 'new_trigger_ids' to apply itself to all trigger IDs in the table
	--Creates an array of 16 inputs and optionally sets fields on them using three optional array-tables as arguments: 
	--'input_list' sets the 'ok_key_flags' for inputs; 'cond_list' sets the 'ok_key_cond_check_flags' for inputs; 'maxframe_list' sets the 'frame_num' for inputs. Use 'fn.edit_command_input' to edit other fields
	--Returns the command list at 'new_cmdlist_id'
	add_command = function(self, new_cmdlist_id, new_cmd_idx, input_list, cond_list, maxframe_list, fields, new_trigger_ids)
		
		local cmds_lists = gCommand.mpBCMResource[self.player_index-1].pCommand
		local cmds_list = cmds_lists[new_cmdlist_id] or sdk.create_managed_array("BCM.COMMAND", 1):add_ref()
		local new_cmd = cmds_list[new_cmd_idx] or sdk.create_instance("BCM.COMMAND"):add_ref()
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
		cmds_list[new_cmd_idx] = new_cmd
		cmds_lists[new_cmdlist_id] = cmds_list
		 
		if new_trigger_ids then
			for i, new_trigger_idx in ipairs(new_trigger_ids) do
				local trig = gCommand.mpBCMResource[self.player_index-1].pTrigger[new_trigger_idx]
				trig.norm.command_no = new_cmdlist_id
				trig.norm.command_ptr = cmds_list
				trig.norm.command_index = new_cmd_idx
			end
		end
		self.do_update_commands = true
		
		return cmds_list
	end,
	
	--Add a new BCM.CHARGE to this player. Returns the new charge
	add_charge = function(self, new_charge_id, fields)
		local charge_dict = gCommand.mpBCMResource[self.player_index-1].pCharge
		local new_charge = sdk.create_instance("BCM.CHARGE"):add_ref()
		charge_dict[new_charge_id] = new_charge
		if fields then
			edit_obj(new_charge, fields)
		end
		return new_charge
	end,
	
	--Add a new CharacterAsset.ProjectileData to this player at 'new_p_id', optionally cloning from 'src_or_src_id' and optionally applying 'fields'. Returns the new pdata
	add_pdata = function(self, new_p_id, src_or_src_id, fields)
		local source = src_or_src_id and (type(src_or_src_id)=="UserData" and src_or_src_id) or self.projectile_datas[src_or_src_id]
		local cloned_pdata = source and clone(source)
		local new_pdata = cloned_pdata or sdk.create_instance("CharacterAsset.ProjectileData"):add_ref()
		self.projectile_datas[new_p_id] = new_pdata
		if fields then
			edit_obj(new_pdata, fields)
		end
		return new_pdata
	end,
	
	--Add a new CharacterAsset.HitRect16 to this player at boxlist 'new_rect_type' with ID 'new_p_id', optionally cloning from 'src_or_src_id' and optionally applying 'fields'
	add_rect = function(self, new_rect_type, new_rect_id, src_rect, fields)
		local new_rect = src_rect and clone(src_rect) or sdk.create_instance("CharacterAsset.HitRect16"):add_ref()
		self.person.Rect.RectList[new_rect_type][new_rect_id] = new_rect
		if fields then
			edit_obj(new_rect, fields)
		end
		return new_rect
	end,
	
	-- Clone triggers using 'old_id_or_trigs' ActionID (or a table of BCM.TRIGGERs) into new triggers for ActionID 'action_id'. Use table 'tgroup_idxs' to add it to a list of TriggerGroups (by number TriggerGroup ID)
	-- The new trigger will be given a free Trigger ID as close as possible to 'max_priority' without exceeding it (Important! An ID of the wrong number will make the trigger have low priority / not work)
	-- All old triggers using 'action_id' will be deleted unless 'no_overwrite' is true. Returns 2 Lua array-tables, 1st one of the new Triggers at that ActionID and 2nd one of its matching new TriggerIDs 
	clone_triggers = function(self, old_id_or_trigs, action_id, tgroup_idxs, max_priority, no_overwrite)
		
		max_priority = max_priority or 167
		local user_engine = gCommand:get_mUserEngine()[self.player_index-1]
		local trg_list = user_engine:call("GetTrigger()")
		local old_trigs = self.triggers_by_act_id[old_id_or_trigs] or old_id_or_trigs
		local new_trigs = {}
		local new_triggers = {}
		local new_trig_idxs = {}
		gCommand.StorageData.UserEngines[self.player_index-1]:set_TriggerMax(256)
		
		for i, trigger in pairs(old_trigs) do -- make list of clones from old_id triggers
			table.insert(new_trigs, clone(trigger))
			new_trigs[#new_trigs].action_id = action_id
		end
		
		local to_add = merge_tables({}, new_trigs)
		local rev_trg_list = {}
		
		local function append_trigger(idx, trigger)
			trg_list[idx] = trigger
			table.insert(new_triggers, trigger)
			table.insert(new_trig_idxs, idx)
			for k, tgroup_idx in ipairs(tgroup_idxs or {}) do
				self:add_to_triggergroup(tgroup_idx, idx)
			end
			table.remove(to_add, 1)
		end
		
		for i, trigger in pairs(trg_list) do
			if not trigger and i <= max_priority then
				table.insert(rev_trg_list, 1, i)
			elseif not no_overwrite and trigger and trigger.action_id == action_id then
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
			log.error("[MMDK] Could not add " .. #to_add .. " new trigger(s) to " .. self.name .. ", all 256 triggers are taken!")
		end
		self.triggers_by_act_id[action_id] = new_trigs
		
		return new_triggers, new_trig_idxs
	end,
	
	--Wrapper for clone_triggers that doesnt overwrite old triggers that use new_id
	add_triggers = function(self, old_id_or_trigs, new_id, tgroup_idxs, max_priority)
		return self:clone_triggers(old_id_or_trigs or {sdk.create_instance("BCM.TRIGGER"):add_ref()}, new_id, tgroup_idxs, max_priority, true)
	end,
	
	--Clone a HIT_DT_TBL as 'old_hit_id_or_dt' into a new available HIT_DT_TBL with ID 'new_hit_id'. Use 'action_obj' to add it to a MMDK action object.
	--Use 'src_key' to provied an existing key as the basis for the returned key,  and 'target_key_index' to assign it to a specific index in the key list
	--Returns 2 objects: the new HIT_DT_TBL and the new AttackCollisionKey it was added to
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
	--Returns the new EPVStandardData.Element and optionally the cloned key it was added to
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
	
	--Loads a MMDK json table and applies it to the current character
	autoload_json = function(self, mmdk_tbl)
		
		local output = {moves = {}, trigger_lists = {},}
		for i, new_move in ipairs(fn.convert_tbl_to_numeric_keys(mmdk_tbl)) do
			
			local action = self.moves_dict.By_ID[new_move.id]
			if not action then
				local clone_action = (new_move.clone_src and PlayerData:get_simple_fighter_data(new_move.clone_src) or self).moves_dict.By_ID[new_move.clone_id]
				action = self:clone_action(clone_action, new_move.id) --add action
			end
			output.moves[new_move.id] = action
			
			if new_move.dynamic_motionbank then
				self:add_dynamic_motionbank(new_move.dynamic_motionbank.path, new_move.dynamic_motionbank.bank_id) 
			end
			
			if new_move.rects then
				for i, jrect in ipairs(new_move.rects) do 
					local rects_dict = self.person.Rect.RectList[jrect.box_type]
					local re_rect = rects_dict[jrect.id] or sdk.create_instance("CharacterAsset.HitRect16"):add_ref()
					rects_dict[jrect.id] = re_rect
					if jrect.fields then
						edit_obj(re_rect, jrect.fields)
					end
				end
			end

			if new_move.hit_dts then
				for i, jhit_dt in ipairs(new_move.hit_dts) do 
					local hit_dt_tbl = self.hit_datas[jhit_dt.id], nil
					if not hit_dt_tbl then
						local clone_hdt = (jhit_dt.clone_src and PlayerData:get_simple_fighter_data(jhit_dt.clone_src) or self).hit_datas[jhit_dt.clone_id]
						hit_dt_tbl = self:clone_dmg(clone_hdt, jhit_dt.id)
					end
					if jhit_dt.fields then
						for param_type, fields in pairs(jhit_dt.fields) do
							fn.edit_hit_dt_tbl(hit_dt_tbl, tables.hit_types[param_type], fields)
						end
					end
				end
			end
			
			if new_move.commands then
				for i, jcmd in ipairs(new_move.commands) do 
					local new_cmds = self:add_command(jcmd.id, jcmd.index, jcmd.inputs_list, jcmd.cond_list, jcmd.maxframe_list, jcmd.fields, output.trigger_lists[jcmd.triggers_to_add_to])
				end
			end
			
			if new_move.charges then
				for i, jcharge in ipairs(new_move.charges) do 
					--add or edit charges
				end
			end
			
			if new_move.triggers then
				for i, jtrigger in ipairs(new_move.triggers) do 
					local new_triggers, new_trig_ids = self:clone_triggers(jtrigger.clone_id, jtrigger.id, jtrigger.trigger_groups, jtrigger.target_trigger_group_id)
					output.trigger_lists[new_move.id] = new_trig_ids
					for t, trig in ipairs(new_triggers) do
						if jtrigger.fields then
							print("Fields")
							testing = true
							edit_obj(trig, jtrigger.fields)
							testing = false
						end
						if jtrigger.copy_over_modern then
							fn.copy_fields(trig.norm, trig.sprt)
						end
						if jtrigger.commands_id and self.commands[jtrigger.commands_id][jtrigger.command_idx] then
							trig.norm.command_ptr = self.commands[jtrigger.commands_id][jtrigger.command_idx]
						end
					end
				end
			end
			
			
			for name, jkey_list_tbl in pairs(new_move.key_list) do
				for i, jkey_tbl in ipairs(jkey_list_tbl) do
					local list = action.fab.Keys[ tables.key_types_by_index[name] ]
					local resolved_idx = jkey_tbl.replace_index or jkey_tbl.insert_index
					local our_key = jkey_tbl.clone_index and clone(list[jkey_tbl.clone_index]) or list[resolved_idx]
					if jkey_tbl.replace_index and jkey_tbl.replace_index < list._items:get_Count() then
						list[jkey_tbl.replace_index] = our_key
					else
						fn.insert_list(list, our_key, resolved_idx)
					end
					if jkey_tbl.fields then
						edit_obj(list[resolved_idx], jkey_tbl.fields)
					end
				end
			end
			
		end
		
		return output
	end,
	
	--Takes a fighter name or ID and returns a simple/fake version of this class with a moves_dict for that fighter
	get_simple_fighter_data = function(self, chara_name_or_id)
		
		local chara_id = tonumber(chara_name_or_id) or find_key(characters, chara_name_or_id)
		
		if self.simple_fighter_data[chara_id] then 
			return self.simple_fighter_data[chara_id] 
		end
		local person = persons[chara_id] or add_person(chara_id)
		
		if person.FAB.StyleDict[0] then
			local chara_name = characters[chara_id]
			local sdata = {moves_dict={By_Name = {}, By_ID = {}, By_Index={}}, person=person, name=chara_name or "Common", chara_id=chara_id, hit_datas={}}
			self.simple_fighter_data[chara_id] = sdata
			local isvec2 = ValueType.new(sdk.find_type_definition("nAction.isvec2"))
			setmetatable(sdata, PlayerData)
			
			sdata.rects =  {[0]={},{},{},{},{},{},{},{},{},{},{},{},{},{}}
			sdata.triggers = {}
			sdata.triggers_by_act_id = {}
			sdata.tgroups = {}
			
			if chara_name then
				for id, hit_dt_tbl in pairs(json.load_file("MMDK\\PlayerData\\" .. chara_name .. "\\".. chara_name .." HIT_DT.json") or {}) do
					sdata.hit_datas[tonumber(id)] = sdk.create_instance("nBattle.HIT_DT_TBL"):add_ref()
					for p_name, param_tbl in pairs(hit_dt_tbl) do 
						for j, hit_dt in pairs(param_tbl) do
							local hdt_obj = sdk.create_instance("nBattle.HIT_DT"):add_ref()
							sdata.hit_datas[tonumber(id)][p_name][tonumber(j)] = hdt_obj
							for i, field in ipairs(hdt_obj:get_type_definition():get_fields()) do
								local field_value = hit_dt[name]
								if type(field_value) == "table" then
									isvec2:call(".ctor(System.Int16, System.Int16)", field_value.x, field_value.y)
									write_valuetype(hdt_obj, field:get_name(), isvec2)
								else
									hdt_obj[field:get_name()] = field_value
								end
							end
						end
					end
				end
				
				
				local json_rects = json.load_file("MMDK\\PlayerData\\" .. chara_name .. "\\".. chara_name .." rects.json") or {}
				
				for list_idx, rect_list in pairs(json_rects) do
					list_idx = tonumber(list_idx)
					for rect_id, rect_tbl in pairs(rect_list) do
						local rect = sdk.create_instance("CharacterAsset.HitRect16"):add_ref()
						sdata.rects[list_idx][tonumber(rect_id)] = rect
						edit_obj(rect, rect_tbl)
					end
				end
				
				local json_triggers = json.load_file("MMDK\\PlayerData\\" .. chara_name .. "\\".. chara_name .." triggers.json") or {}
				
				for action_id, trigger_list in pairs(json_triggers) do
					action_id = tonumber(action_id)
					sdata.triggers_by_act_id[action_id] = {}
					for trigger_id, trig_tbl in pairs(trigger_list) do
						local trig = sdk.create_instance("BCM.TRIGGER"):add_ref()
						sdata.triggers[tonumber(trigger_id)] = trig
						sdata.triggers_by_act_id[action_id][tonumber(trigger_id)] = trig
						edit_obj(trig, trig_tbl, true)
					end
				end
				--sdata.moves_dict_json = json.load_file("MMDK\\PlayerData\\" .. chara_name .. "\\".. chara_name .." moves_dict.json") or {}
			end
			
			for i, fab_action in ipairs(lua_get_dict(person.FAB.StyleDict[0].ActionList, true, function(a, b) return a.ActionID < b.ActionID end)) do
				self.collect_fab_action(sdata, fab_action)
			end
			
			if chara_name then
				local json_tgroups = json.load_file("MMDK\\PlayerData\\" .. chara_name .. "\\".. chara_name .." tgroups.json") or {}
				for tgroup_id, tgroup_list in pairs(json_tgroups) do
					tgroup_id = tonumber(tgroup_id)
					sdata.tgroups[tgroup_id] = {}
					for trigger_id, name_str in pairs(tgroup_list) do
						sdata.tgroups[tgroup_id][tonumber(trigger_id)] = sdata.moves_dict.By_ID[tonumber(name_str:match("(.+) "))]
					end
				end
			end
			
			self.collect_additional(sdata)
			
			return sdata
		end
	end,
	
	get_common_fighter_data = function(self)
		return self:get_simple_fighter_data(0)
	end,
	
	--Update important data in this class every frame
	update = function(self)
		
		if self.do_update_commands then
			self.do_update_commands = nil
			gCommand:SetCommand(self.player_index-1, gCommand.mpBCMResource[self.player_index-1].pCommand)
			gCommand:SetTriggerGroup(self.player_index-1, gCommand.mpBCMResource[self.player_index-1].pTrgGrp)
			gCommand:SetTrigger(self.player_index-1, gCommand.mpBCMResource[self.player_index-1].pTrigger)
			gCommand:SetupFixedParameter(self.player_index-1)
			--self.do_refresh = true
		end
		
		if self.temp_fn then
			self.temp_fn()
		end
		
		if self.drivebar_fn then
			self.drivebar_fn()
		end
	end
}

local function set_player_data(player_index)
	tmp_fns.set_p_data = function()
		tmp_fns.set_p_data = nil
		player_data[player_index] = PlayerData:new(player_index, true, player_data[player_index])
	end
end

--Applies colored drivebars and health bars for modified fighters
local function set_huds(player_idx)
	
	tmp_fns.hud_fn = function()
		local battle_hud = gRollback.m_battleHud
		
		if battle_hud and gPlayer.move_ctr > 3 and battle_hud.FighterStatusParts._items[0] then
			
			tmp_fns.hud_fn = nil
			local p1_lifebar = battle_hud.FighterStatusParts[0].HudParts["<Control>k__BackingField"]:get_Child():get_Next():get_Next():get_Next()
			local p2_lifebar = battle_hud.FighterStatusParts[7].HudParts["<Control>k__BackingField"]:get_Child():get_Next():get_Next():get_Next()
			local col = ValueType.new(sdk.find_type_definition("via.Color"))
			
			if player_data[1] and mmsettings.p1_hud and ((not player_idx and mmsettings.fighter_options[player_data[1].name].enabled) or player_idx == 1)  then --Player1 Hud
				col.rgba = 0x00BE0000
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

--Checks if player_data should be created/updated and then modified
local function check_make_playerdata()
	
	engines = {}
	local act_engines = characters[gPlayer.mPlayerType[0].mValue] and gRollback:GetLatestEngine() and gRollback:GetLatestEngine().ActEngines
	if act_engines and act_engines[0] and act_engines[0]._Parent then
		engines = {[1]=act_engines[0]._Parent._Engine, [2]=act_engines[1]._Parent._Engine}
	end
	
	if not ran_once and mmsettings.enabled and engines[1] then 
		ran_once = true
		print(os.clock() .. " Getting MMDK player data...")
		can_setup = false
		local did_set = false
		local all_chars = mmsettings.fighter_options["All Characters"]
		
		for i=1, 2 do
			if mmsettings.fighter_options[characters[gPlayer.mPlayerType[i-1].mValue] ].enabled then 
				--Get data:
				player_data[i] = PlayerData:new(i, true, player_data[i])
			end
		end
		for i=1, 2 do
			local chara_name = characters[gPlayer.mPlayerType[i-1].mValue]
			if mmsettings.fighter_options[chara_name].enabled then 
				--Run functions to change moveset:
				merged_modlist = extend_table(merge_tables({}, all_chars.enabled and moveset_functions["All Characters"] or {}), moveset_functions[chara_name])
				for c, character_tbl in ipairs(merged_modlist) do
					if mmsettings.fighter_options[character_tbl.chara_name][character_tbl.filename].enabled then
						character_tbl.lua.apply_moveset_changes(player_data[i]) 
						did_set = true
					end
				end
			end
		end
		if did_set then
			set_huds() 
		end
	end
end

--Plays an animation for the research_info window, finds a synchronized animation if possible
local function play_anim(ri, new_bank_id, new_mot_id)
	local allmot = ri.all_mots[find_key(ri.all_mots, new_bank_id.." "..new_mot_id, "key")]
	local matched_allmot = ri.sync.layers and ri.sync.all_mots.dict[allmot.name]
	for m, layer in ipairs(ri.layers) do
		layer:call("changeMotion(System.UInt32, System.UInt32, System.Single)", new_bank_id, new_mot_id, 0.0)
		ri.motion:set_PlayState(0)
	end
	if ri.do_sync and ri.sync.motion and (matched_allmot or ri.sync.motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", new_bank_id, new_mot_id,  minfo) 
	or ri.sync.motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", tonumber(ri.data.chara_id.."00"..new_bank_id), new_mot_id,  minfo)
	or ri.sync.motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", tonumber(ri.data.chara_id.."0"..new_bank_id), new_mot_id,  minfo)
	or ri.sync.motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", tonumber(({tostring(new_bank_id):gsub("^"..ri.data.chara_id.."00", "")})[1]), new_mot_id,  minfo)
	or ri.sync.motion:call("getMotionInfo(System.UInt32, System.UInt32, via.motion.MotionInfo)", tonumber(({tostring(new_bank_id):gsub("^"..ri.data.chara_id.."0", "")})[1]), new_mot_id,  minfo))	then 
		for m, layer in ipairs(ri.sync.layers) do
			layer:call("changeMotion(System.UInt32, System.UInt32, System.Single)", matched_allmot and matched_allmot.bank or minfo:get_BankID(), matched_allmot and matched_allmot.id or minfo:get_MotionID(), 0.0)
		end
		ri.sync.motion:set_PlayState(0)
	end
end

--Collects motionbanks for the research_info window
local function collect_banks(ri)
	if not ri.mixed_banks or not ri.layers then
		mot_fns.create_mixed_banks = function()
			mot_fns.create_mixed_banks = nil
			ri.sync = {all_mots=merge_tables({}, ri.all_mots or {}), motion=ri.motion, layers=ri.layers}
			ri.all_mots = {dict={}}
			ri.mixed_banks = {}
			ri.motion = (ri.do_facial_anims and ri.data.pb.mpFace) or ri.data.motion
			ri.layers = ri.do_facial_anims and {ri.motion:getLayer(0)} or lua_get_array(ri.motion:get_Layer())
			edit_objs(ri.layers, {_WrapMode=ri.do_loop and 2 or 0})
			for i, name in ipairs({"ActiveMotionBank", "DynamicMotionBank"}) do
				for j, motionbank in ipairs(lua_get_array(ri.motion:call("get_"..name):add_ref())) do 
					local bank_id = motionbank:get_BankID()
					local name = motionbank:get_MotionList(); name = name and name:ToString():match("^.+%[.+/(.+)%.motlist%]")
					if name then
						ri.mixed_banks[bank_id] = ri.mixed_banks[bank_id] or {name=name}
						local unique_banks = {}
						for k=0, ri.motion:getMotionCount(bank_id) - 1 do
							ri.motion:call("getMotionInfoByIndex(System.UInt32, System.UInt32, via.motion.MotionInfo)", bank_id, k, minfo)
							
							table.insert(ri.all_mots, {bank=bank_id, id=minfo:get_MotionID(), name=minfo:get_MotionName():gsub("esf%d%d%d_", ""):gsub("_En", ""):gsub("FCE_", ""), 
								num_frames=minfo:get_MotionEndFrame(), key=bank_id.." "..minfo:get_MotionID()})
							ri.all_mots.dict[ri.all_mots[#ri.all_mots].name] = ri.all_mots[#ri.all_mots]
							local u_name = get_unique_name(ri.all_mots[#ri.all_mots].name, unique_banks)
							ri.mixed_banks[bank_id][minfo:get_MotionID()] = u_name
							unique_banks[u_name] = true
						end
					end
				end
			end
			ri.motion:set_PlaySpeed(1.0)
			ri.data.pb:set_Enabled(false)
		end
	end
end

--Repeats every frame during UpdateMotion
re.on_application_entry("UpdateMotion", function()
	local tmp = merge_tables({}, mot_fns)
	for name, temporary_function in pairs(tmp) do
		temporary_function()
	end
end)


--Repeats every frame during UpdateBehavior
re.on_application_entry("UpdateBehavior", function()
	
	local tmp = merge_tables({}, tmp_fns)
	for name, temporary_function in pairs(tmp) do
		temporary_function()
	end
	
	for p_idx, data in ipairs(player_data) do
		data:update()
	end
	
	check_make_playerdata()
	
end)

--Repeats every frame
re.on_frame(function()
	
	local pressed_skip_fwd, pressed_skip_bwd, pressed_pause, pressed_request = false, false, false, false
	last_ri.last_action_speed = (action_speed ~= 0) and action_speed or last_ri.last_action_speed or 1.0
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
			
			if not other_data or not next(other_data.moves_dict.By_ID) then
				imgui.end_window()
				set_player_data(other_p_idx)
				return nil
			end
			
			local ri = data.research_info or {time_last_clicked=os.clock(), data=data, other_data=other_data}
			last_ri = ri
			data.research_info = ri
			
			changed, mmsettings.research_p2 = imgui.checkbox("P2", mmsettings.research_p2); set_wc()  
			tooltip("View P2\n	Hotkey:    " .. hk.get_button_string("Switch P1/P2"))
			
			if hk.check_hotkey("Switch P1/P2") then
				mmsettings.research_p2 = not mmsettings.research_p2
			end
			
			if not ri.names then
				ri.names = {}
				ri.id_map = {}
				for id, move in pairs(data.moves_dict.By_ID) do
					local name = move.name:gsub("*", "")
					table.insert(ri.names, name)
					ri.id_map[name] = tostring(id)
				end
				table.sort(ri.names, function(name1, name2)  return tonumber(ri.id_map[name1]) < tonumber(ri.id_map[name2])  end)
			end
			
			imgui.same_line()
			imgui.text_colored(data.name, (mmsettings.research_p2 and 0xFFE0853D) or 0xFF3D3DFF)
			
			local current_act_id = data.engine:get_ActionID()
			local current_move = data.moves_dict.By_ID[current_act_id] or other_data.moves_dict.By_ID[current_act_id]
			local current_act_name = current_move and current_move.name:gsub("*", "")
			ri.current_move = current_move
			
			if ri.last_act_id ~= current_act_id and not ri.was_typed then
				ri.text = current_act_name
			end
			
			ri.last_act_id = current_act_id
			
			imgui.same_line()
			imgui.text_colored((" "..string.format("%04d", current_act_id)):gsub(" 0", "   "):gsub(" 0", "   "):gsub(" 0", "   "), 0xFFAAFFFF)
			tooltip("Action ID")
			read_sfix(data.engine:get_ActionFrame())
			imgui.same_line()
			imgui.begin_rect()
			
			local engine_frame = read_sfix(data.engine:get_ActionFrame()) or 0
			local engine_endframe = read_sfix(data.engine:get_ActionFrameNum())
			ri.last_engine_start_frame = ((engine_frame == 0) and ri.frame_ctr) or ri.last_engine_start_frame or 0
			ri.frame_ctr = math.floor(ri.last_engine_start_frame + engine_frame)
			
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
			
			local num = tonumber(ri.text) or tonumber(ri.id_map[ri.text])
			ri.num = num
			
			if ri.was_typed then imgui.begin_rect(); imgui.begin_rect() end
			
			changed, ri.text = imgui.input_text("Request action", ri.text)
			tooltip("Play an action by name or by ID")
			
			if ri.was_typed then imgui.end_rect(2); imgui.end_rect(3) end
			
			pressed_request = imgui.button("Request")
			tooltip("Play an action by name or by ID\n	Hotkey:    " .. hk.get_button_string("Request Last Action"))
			
			imgui.same_line()
			pressed_skip_bwd = imgui.arrow_button(2143, 0)
			tooltip("Step backward one frame and pause\n	Hotkey:    " .. hk.get_button_string("Framestep Backward") .. "     (HOLD to seek)")
			
			imgui.same_line()
			pressed_skip_fwd = imgui.arrow_button(2144, 1)
			tooltip("Step forward one frame and pause\n	Hotkey:    " .. hk.get_button_string("Framestep Forward") .. "    (HOLD to seek)")
			
			imgui.same_line()
			pressed_pause = imgui.button((is_paused and "Resume") or "Pause")
			tooltip("Pause speed to 0%% or resume at the last chosen speed\n	Hotkey:    " .. hk.get_button_string("Pause/Resume"))
			
			if imgui.begin_list_box(data.name .. " action", #ri.names) then
				for j, action_name in ipairs(ri.names) do
					if imgui.menu_item(action_name, ri.id_map[action_name], (ri.sel_action_idx==j), true) then
						ri.sel_action_idx = j
						ri.text = action_name
						ri.was_typed = true
						ri.time_last_clicked = os.clock()
						current_move = data.moves_dict.By_Name[action_name]
						data.cPlayer:setAction(tonumber(ri.id_map[action_name]), sdk.find_type_definition("via.sfix"):get_field("Zero"):get_data(nil))
						ri.last_engine_start_frame = ri.frame_ctr
						if action_speed < 0.0 then 
							write_valuetype(data.engine, 84, data.engine:get_ActionFrameNum())
						end
					end
				end
				imgui.end_list_box()
			end
			
			ri.was_typed = data.moves_dict.By_ID[num or -1234] and ri.was_typed or changed
			
			if imgui.button("Apply moveset mods") then
				tmp_fns.apply = function()
					tmp_fns.apply = nil
					local all_copy = (mmsettings.fighter_options["All Characters"].enabled and merge_tables({}, moveset_functions["All Characters"])) or {}
					for c, character_tbl in ipairs(extend_table(all_copy, moveset_functions[data.name])) do
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
			changed, ri.research_sort_by_name = imgui.checkbox("ABC", ri.research_sort_by_name)
			tooltip("Sort by name")
			
			if changed then 
				if ri.research_sort_by_name then
					table.sort(ri.names)
				else
					table.sort(ri.names, function(name1, name2)  return tonumber(ri.id_map[name1]) < tonumber(ri.id_map[name2])  end)
				end
			end
			
			imgui.same_line()
			changed, mmsettings.do_common_dict = imgui.checkbox("Collect common moves", mmsettings.do_common_dict); set_wc() 
			tooltip("Adds shared/common move data")
			
			if changed then
				tmp_fns.create_data = function()
					tmp_fns.create_data = nil
					player_data[1] = player_data[1] and PlayerData:new(1, true, player_data[1])
					player_data[2] = player_data[2] and PlayerData:new(2, true, player_data[2])
				end
			end
			
			imgui.begin_child_window(nil, false, 0)
			
			local tooltip_msg = "Saves fighter data to\n	reframework\\data\\MMDK\\" .. data.name .. "\\" .. data.name
			if imgui.tree_node("[Lua Data]") then
				if imgui.button("Dump Moves Dict") then
					tmp_fns.dumper = function()
						tmp_fns.dumper = nil
 						data:dump_moves_dict_json()
						data:dump_moves_dict_json("common_moves.json", common_move_dict)
					end
				end
				tooltip(tooltip_msg .. " moves_dict.json")
				
				imgui.same_line()
				if imgui.button("Dump HIT_DTs") then
					data:dump_hit_dt_json()
				end
				tooltip(tooltip_msg .. " HIT_DT.json")
				
				imgui.same_line()
				if imgui.button("Dump Triggers") then
					data:dump_trigger_json()
				end
				tooltip(tooltip_msg .. " triggers.json")
				
				imgui.same_line()
				if imgui.button("Dump Atemis") then
					data:dump_atemi_json()

					-- dump common as well
					local commonAtemi = lua_get_dict(gResource.Data[6].Atemi)
					local commonAtemiJson = convert_to_json_tbl(commonAtemi, nil, nil, nil, true)
					json.dump_file("MMDK\\PlayerData\\common_atemi.json", commonAtemiJson)
				end
				
				if imgui.button("Dump TriggerGroups") then
					data:dump_tgroups_json()
				end
				tooltip(tooltip_msg .. " tgroups.json")
				
				imgui.same_line()
				if imgui.button("Dump HitRects") then
 					data:dump_rects_json()
					-- dump common rects as well
					local commonRects = {}
					for i, dict in pairs(gResource.Data[6].Rect.RectList) do
						commonRects[i] = {}
						for id, rect in pairs(lua_get_dict(dict)) do
							commonRects[i][id] = rect
						end
					end
					data:dump_rects_json("common_rects.json", commonRects)
 				end
				tooltip(tooltip_msg .. " rects.json")
				
				imgui.same_line()
				if imgui.button("Dump Commands") then
					data:dump_commands_json()
				end
				tooltip(tooltip_msg .. " commands.json")

				imgui.same_line()
				if imgui.button("Dump Charge") then
					data:dump_charge_json()
				end
				tooltip(tooltip_msg .. " charge.json")
				
				if imgui.button("Dump Char Info (Style and PlData)") then
					data:dump_char_info_json()
				end
				tooltip(tooltip_msg .. " char_info.json")
				
				imgui.same_line()
				if imgui.button("Dump Assist Combos") then
					data:dump_assist_combo_json()
				end
				tooltip(tooltip_msg .. " assist_combo.json")
				
				imgui.same_line()
				if imgui.button("Dump All") then
					tmp_fns.dumper = function()
						tmp_fns.dumper = nil
 						data:dump_moves_dict_json()
						data:dump_moves_dict_json("common_moves.json", common_move_dict)
					end
					data:dump_hit_dt_json()
					data:dump_trigger_json()
					data:dump_atemi_json()
					local commonAtemi = lua_get_dict(gResource.Data[6].Atemi)
					local commonAtemiJson = convert_to_json_tbl(commonAtemi, nil, nil, nil, true)
					json.dump_file("MMDK\\PlayerData\\common_atemi.json", commonAtemiJson)
					data:dump_tgroups_json()
 					data:dump_rects_json()
					local commonRects = {}
					for i, dict in pairs(gResource.Data[6].Rect.RectList) do
						commonRects[i] = {}
						for id, rect in pairs(lua_get_dict(dict)) do
							commonRects[i][id] = rect
						end
					end
					data:dump_rects_json("common_rects.json", commonRects)
					data:dump_commands_json()
					data:dump_charge_json()
					data:dump_char_info_json()
					data:dump_assist_combo_json()
				end
				tooltip("Dump all fighter datas to their respective json files")
				
				if EMV then
					EMV.read_imgui_element(data)
				end
				imgui.tree_pop()
			else
				tooltip("Access through the global variable 'player_data'")
			end
			
			
			if imgui.tree_node_str_id("Anims"..data.player_index, "Animations") then
				imgui.begin_rect()

				imgui.text("*Hotkeys normally for actions will control animations while this menu is open")
				
				if ri.mixed_banks and ri.layers then
					
					local changed_facial
					changed_facial, ri.do_facial_anims = imgui.checkbox("Facial Animations", ri.do_facial_anims)
					tooltip("Switch between body and facial animations")
					
					if ri.sync.layers then
						imgui.same_line()
						if ri.sync.synced then imgui.begin_rect(); imgui.begin_rect() end
						changed, ri.do_sync = imgui.checkbox("Sync", ri.do_sync)
						if ri.sync.synced then imgui.end_rect(2); imgui.end_rect(3) end
						tooltip("Synchronize body and facial animations\nThis box will be circled while animations are synced")
					end
					
					imgui.same_line()
					changed, ri.do_mirror = imgui.checkbox("Mirror", ri.do_mirror)
					if changed then 
						edit_objs(ri.layers, {_MirrorSymmetry=ri.do_mirror})
						if ri.sync.synced then edit_objs(ri.sync.layers, {_MirrorSymmetry=ri.do_mirror}) end
					end
					
					imgui.same_line()
					changed, ri.do_loop = imgui.checkbox("Loop", ri.layers[1]:get_WrapMode() == 2)
					if changed then 
						edit_objs(ri.layers, {_WrapMode=ri.do_loop and 2 or 0})
						if ri.sync.synced then edit_objs(ri.sync.layers, {_WrapMode=ri.do_loop and 2 or 0}) end
					end
					
					imgui.same_line()
					local expand_all = imgui.button(ri.anims_expanded and "Collapse All" or "Expand All")
					if expand_all then ri.anims_expanded = not ri.anims_expanded or nil end
					
					imgui.same_line()
					pressed_request = pressed_request or imgui.button("Replay")
					
					imgui.same_line()
					pressed_pause = pressed_pause or imgui.button(ri.motion:get_PlayState() == 1 and "Play" or "Pause")
					
					if ri.do_facial_anims then
						local changed, face_blend_rate = imgui.slider_float("Animation Rate", ri.layers[1]:get_BlendRate(), 0, 1.0)
						if changed then 
							ri.layers[1]:set_BlendRate(face_blend_rate)
						end
					end
					
					local set = imgui.button("Set")
					imgui.same_line()
					imgui.push_id(123)
					changed, ri.add_motlist_path = imgui.input_text("", ri.add_motlist_path)
					imgui.pop_id()
					tooltip("Add a new motlist file to this character")
					
					imgui.same_line()
					imgui.set_next_item_width(60)
					changed, ri.add_motlist_id = imgui.input_text("New Motlist + BankID", ri.add_motlist_id)
					tooltip("New BankID")
					
					local changed, anim_frame = imgui.slider_float("Frame", ri.layers[1]:get_Frame(), 0, ri.layers[1]:get_EndFrame())
					tooltip("Animation seek bar")
					if changed then 
						edit_objs(ri.layers, {_Frame=anim_frame})
						if ri.sync.synced then
							edit_objs(ri.sync.layers, {_Frame=anim_frame})
						end
					end
					
					local changed, anim_speed = imgui.slider_float("Speed", ri.layers[1]:get_Speed(), 0, 1.0)
					tooltip("Change animation speed")
					if changed then 
						edit_objs(ri.layers, {_Speed=anim_speed})
						if ri.sync.synced then
							edit_objs(ri.sync.layers, {_Speed=anim_speed})
						end
					end
					
					changed, ri.anim_filter_txt = imgui.input_text("Filter", ri.anim_filter_txt)
					local filter = (ri.anim_filter_txt ~= "") and ri.anim_filter_txt:lower()
					
					local mnode, cbank_id, cmot_id, cmot_name = ri.layers[1]:get_HighestWeightMotionNode() or ri.layers[1]:getMotionNode(0)
					if mnode then
						cbank_id, cmot_id, cmot_name = mnode:get_MotionBankID(), mnode:get_MotionID(), mnode:get_MotionName()
						imgui.text(cbank_id)
						imgui.same_line()
						imgui.text_colored(cmot_id, 0xFFE0853D)
						imgui.same_line()
						imgui.text_colored(cmot_name, 0xFFAAFFFF)
					end
					
					local pairs_mth = EMV and EMV.orderedPairs or pairs
					local tree_node_mth = imgui.tree_node_colored or imgui.tree_node
					
					if ri.mixed_banks and not ri.sorted_banks then
						ri.sorted_banks = {}
						for id, tbl in pairs(ri.mixed_banks) do  table.insert(ri.sorted_banks, id) end
						table.sort(ri.sorted_banks)
					end
					
					imgui.push_id(ri.motion:get_address()+44)
					imgui.spacing()
					imgui.begin_rect(); imgui.begin_rect()
					imgui.begin_child_window(nil, false, 0)
					
					
					
					for i, bank_id in pairs_mth(ri.sorted_banks or {}) do
						local bank_tbl = ri.mixed_banks[bank_id]
						if not bank_tbl then return end
						if expand_all then imgui.set_next_item_open(ri.anims_expanded) end
						if tree_node_mth(bank_id .. ":	" .. bank_tbl.name, bank_id, bank_tbl.name) then
							imgui.begin_rect()
							local ctr, chara_ctr = 0, 0
							for motion_id, mot_name in pairs_mth(bank_tbl) do
								if type(motion_id) == "number" and (not filter or mot_name:lower():find(filter)) then
									ctr = ctr + 1; chara_ctr = chara_ctr + mot_name:len()
									if ctr % 5 ~= 1 and chara_ctr < 70 then imgui.same_line() else ctr, chara_ctr = 1, 0 end
									local is_playing = (cbank_id==bank_id and cmot_id==motion_id) 
									if is_playing then imgui.begin_rect(); imgui.begin_rect() end
									if imgui.button(mot_name) then
										play_anim(ri, bank_id, motion_id)
									end
									if is_playing then imgui.end_rect(2); imgui.end_rect(3) end
									tooltip(motion_id)
								end
							end
							imgui.end_rect(2)
							imgui.tree_pop()
						end
					end
					
					imgui.end_child_window()
					imgui.spacing()
					imgui.end_rect(1); imgui.end_rect(2)
					imgui.pop_id()
					
					if set and tonumber(ri.add_motlist_id) then
						local str = (ri.add_motlist_path:match("stm\\(.+)") or ri.add_motlist_path):gsub("\\", "/"):gsub("%.653", "")
						if data:add_dynamic_motionbank(str, tonumber(ri.add_motlist_id), ri.motion) then
							ri.layers, ri.motion, ri.mixed_banks, ri.sorted_banks = nil
							re.msg("Added DynamicMotionBank")
						end
					end
					if changed_facial then 
						ri.mixed_banks, ri.sorted_banks = nil
					end
				end
				
				collect_banks(ri)
				
				imgui.end_rect(2)
				imgui.tree_pop()
			elseif ri.mixed_banks then
				data.pb:set_Enabled(true)
				edit_objs(ri.layers, {_WrapMode=ri.do_loop and 2 or 0})
				ri.mixed_banks, ri.layers, ri.sorted_banks, ri.layers = nil
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
			
			if EMV then 
			
				local function display_active_move(move, name, this_frame, keyname)
					
					this_frame = this_frame or current_frame
					
					if imgui.tree_node_str_id(keyname or name or "cmove", name or move.name) then
						
						if imgui.tree_node("Action Data") then
							imgui.begin_rect()
							EMV.read_imgui_element(move)
							imgui.end_rect(2)
							imgui.spacing()
							imgui.tree_pop()
						end
						
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
											local keyname = move.name .. ".Projectile[" .. i .. "] @ " .. ri.frame_ctr ..  "f:   Frames " .. sf .. " - " .. ef .. " (" .. move.projectiles[i].fab.Frame .. "f)"
											spawned_projectiles[get_unique_name(move.projectiles[i].name .. " ", spawned_projectiles)] = not find_key(spawned_projectiles, keyname, "keyname") and {
												keyname = keyname,
												move = move.projectiles[i],
												start_frame = ri.frame_ctr,
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
						
						imgui.tree_pop()
					end
				end	
				
				if imgui.tree_node("TriggerGroups (CancelLists)") then
					EMV.read_imgui_element(data.tgroups)
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
						display_active_move(proj_tbl.move, proj_tbl.keyname .. "  " .. proj_tbl.move.name, ri.frame_ctr - proj_tbl.start_frame, proj_name)
						if ri.frame_ctr - proj_tbl.start_frame >= proj_tbl.move.fab.Frame + 30 then
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
			else
				imgui.text("Get EMV Engine for more information\nhttps://github.com/alphazolam/EMV-Engine")
			end
			
			imgui.spacing()
			imgui.end_child_window()
			imgui.end_window()
		end
	end
	
	if hk.check_hotkey("Enable/Disable Autorun") then
		mmsettings.enabled = not mmsettings.enabled
	end
	
	if hk.check_hotkey("Show Research Window") then
		mmsettings.research_enabled = not mmsettings.research_enabled
	end
	
	if mmsettings.research_enabled and last_ri.data and engines[2] then
		
		local ri = last_ri
		hk_timers.bwd = hk.check_hotkey("Framestep Backward", true) and hk_timers.bwd or os.clock()
		hk_timers.fwd = hk.check_hotkey("Framestep Forward", true) and hk_timers.fwd or os.clock()
		
		local skipped_bwd_value, skipped_fwd_value
		if pressed_skip_bwd or ((os.clock() - hk_timers.bwd) > 0.25) or hk.check_hotkey("Framestep Backward") then
			local frame = (ri.layers and ri.layers[1]:get_Frame()) or read_sfix(engines[p_idx].mParam.frame)
			skipped_bwd_value = math.floor(frame - 1 >= 0 and frame - 1 or 0) + 0.0
		end
		
		if pressed_skip_fwd or ((os.clock() - hk_timers.fwd) > 0.25) or hk.check_hotkey("Framestep Forward") then
			local frame = (ri.layers and ri.layers[1]:get_Frame()) or read_sfix(engines[p_idx].mParam.frame)
			local endframe = (ri.layers and ri.layers[1]:get_EndFrame()) or read_sfix(data.engine:get_ActionFrameNum())
			skipped_fwd_value = math.floor(frame + 1 <= endframe and frame + 1 or endframe) + 0.0
		end
		
		if skipped_bwd_value or skipped_fwd_value then
			if ri.layers then
				edit_objs(ri.layers, {_Frame=(skipped_bwd_value or skipped_fwd_value)})
				ri.motion:set_PlayState(1)
				if ri.sync.synced  then
					edit_objs(ri.sync.layers, {_Frame=(skipped_bwd_value or skipped_fwd_value)})
					ri.sync.motion:set_PlayState(1)
				end
			else
				pressed_pause = (action_speed ~= 0.0)
				write_valuetype(engines[p_idx], 84, speed_sfix:call("From(System.Single)", (skipped_bwd_value or skipped_fwd_value)))
				ri.current_move = ri.data.moves_dict.By_ID[engines[p_idx]:get_ActionID()] or ri.other_data.moves_dict.By_ID[engines[p_idx]:get_ActionID()]
				if ri.current_move and (ri.current_move.guest or ri.current_move.owner) then 
					write_valuetype(engines[other_p_idx], 84, speed_sfix:call("From(System.Single)", (skipped_bwd_value or skipped_fwd_value))) 
					engines[other_p_idx]:set_Speed(speed_sfix:call("From(System.Single)", 0))
				end
			end
		end
		
		if pressed_pause or hk.check_hotkey("Pause/Resume") then
			if ri.mixed_banks then
				ri.motion:set_PlayState((ri.motion:get_PlayState()==0 and 1) or 0)
				if ri.sync.synced  then
					ri.sync.motion:set_PlayState(ri.motion:get_PlayState())
				end
			else
				action_speed = (action_speed ~= 0) and 0 or ri.last_action_speed
				speed_sfix = fn.to_sfix(action_speed)
				engines[1]:set_Speed(speed_sfix)
				engines[2]:set_Speed(speed_sfix)
			end
		end
		
		local pressed_prev = hk.check_hotkey("Play prev")
		local pressed_next = hk.check_hotkey("Play next")
		pressed_request = pressed_request or hk.check_hotkey("Request Last Action")

		local anim_function = ri.layers and (pressed_prev or pressed_next or pressed_request) and function(via_motion, new_idx)
			local current_idx = find_index(ri.all_mots, ri.layers[1]:getMotionNode(0):get_MotionBankID() .. " " .. ri.layers[1]:getMotionNode(0):get_MotionID(), "key")
			if current_idx and (pressed_request or ((pressed_prev and (current_idx > 1)) or (not pressed_prev and (current_idx < #ri.all_mots)))) then
				local new_idx_tbl = ri.all_mots[current_idx + ((pressed_prev and -1) or (pressed_next and 1) or 0)]
				play_anim(ri, new_idx_tbl.bank, new_idx_tbl.id)
			end
		end
		
		if ri.layers and ri.sync.layers then
			local nd, nd_sync = ri.layers[1]:getMotionNode(0), ri.sync.layers[1]:getMotionNode(0)
			ri.sync.synced = ri.do_sync and nd and nd_sync and (nd:get_MotionID() ==  nd_sync:get_MotionID() 
				and (nd:get_MotionBankID() == nd_sync:get_MotionBankID() or math.abs(nd:get_EndFrame() - nd_sync:get_EndFrame()) < 3.0))
			if hk.check_hotkey("Change to Facial Anims") then
				ri.do_facial_anims = not ri.do_facial_anims
				ri.mixed_banks, ri.sorted_banks = nil
				collect_banks(ri)
			end
		end
		
		if pressed_prev or pressed_next then
			if anim_function then
				anim_function()
			else
				local act_id = ri.data.engine:get_ActionID()
				local current_idx = ri.sel_action_idx or find_index(ri.names, ri.data.moves_dict.By_ID[act_id].name)
				if current_idx and ((pressed_prev and (current_idx > 1)) or (pressed_next and (current_idx < #ri.names))) then
					local new_idx = current_idx + ((pressed_prev and -1) or 1)
					ri.num = tonumber(ri.id_map[ ri.names[new_idx] ])
					ri.text = ri.names[new_idx]
					ri.sel_action_idx = new_idx
					ri.was_typed = true
					pressed_request = true
				end
			end
		end
		
		if pressed_request then
			if anim_function then
				anim_function()
			else
				ri.was_typed = ri.was_typed or pressed_request
				ri.data.cPlayer:setAction(ri.num or 0, sdk.find_type_definition("via.sfix"):get_field("Zero"):get_data(nil))
				ri.last_engine_start_frame = ri.frame_ctr
			end
		end
		
	end
	
	if was_changed then
		hk.update_hotkey_table(mmsettings.hotkeys)
		json.dump_file("MMDK\\MMDKsettings.json", mmsettings)
	end
	was_changed = false
	
end)

--Repeats every frame while REFramework window is visible
re.on_draw_ui(function()
	
	local tree_opened = imgui.tree_node("MMDK")
	tooltip("Moveset Mod Development Kit and Mod Manager")
	
	if tree_opened then
		imgui.begin_rect()
		imgui.begin_rect()
		
		if imgui.button("Reset to Defaults") then
			mmsettings = recurse_def_settings({}, default_mmsettings)
			hk.reset_from_defaults_tbl(default_mmsettings.hotkeys)
			was_changed = true
		end
		
		imgui.same_line()
		if imgui.button("Refresh Mods") then
			mmsettings.fighter_options = recurse_def_settings(mmsettings.fighter_options, default_mmsettings.fighter_options)
			for char_name, mod_list in pairs(default_mmsettings.fighter_options) do
				local new_order = {}
				for mod_name, mod_settings in pairs(mod_list) do
					table.insert(new_order, mod_name)
				end
				table.sort(new_order)
				mmsettings.fighter_options[char_name].ordered = new_order
			end
			was_changed = true
		end
		
		changed, mmsettings.enabled = imgui.checkbox("Autorun", mmsettings.enabled); set_wc()
		tooltip("Enable/Disable automatic modification of fighter movesets")
		
		changed, mmsettings.p1_hud = imgui.checkbox("Modify P1 HUD", mmsettings.p1_hud); set_wc() 
		tooltip("Changes P1 HUD to purple when modded")
		
		changed, mmsettings.p2_hud = imgui.checkbox("Modify P2 HUD", mmsettings.p2_hud); set_wc() 
		tooltip("Changes P2 HUD to blue when modded")
		
		if imgui.tree_node("Mods") then
			imgui.begin_rect()
			for i, chara_name in ipairs(chara_list) do
				changed, mmsettings.fighter_options[chara_name].enabled = imgui.checkbox(chara_name, mmsettings.fighter_options[chara_name].enabled); set_wc()
				tooltip("Enable/Disable autorun for this character\n" .. (i==1 and "Loads for all enabled characters\n" or "") .. tooltips[chara_name])
				imgui.same_line()
				local tree_open = imgui.tree_node_str_id(chara_name.."Options", "")
				tooltip("Select Lua mods to load and set their options\nRight click on a mod to move up or down in priority")
				if tree_open then
					imgui.begin_rect()
					local ord = mmsettings.fighter_options[chara_name].ordered
					for c, mod_name in ipairs(ord) do
						local character_tbl = moveset_functions[chara_name][find_index(moveset_functions[chara_name], mod_name, "filename")]
						if not character_tbl then 
							table.remove(ord, c)
						else
							local mm_tbl = mmsettings.fighter_options[chara_name][character_tbl.filename]
							changed, mm_tbl.enabled = imgui.checkbox(character_tbl.name, mm_tbl.enabled); set_wc()
							tooltip(character_tbl.tooltip)
							imgui.push_id(mod_name.."Ctx")
							if imgui.begin_popup_context_item(1) then
								local pressed_up = imgui.menu_item("Move up")
								local pressed_down = imgui.menu_item("Move Down")
								if pressed_up or pressed_down then 
									local trade_idx = (pressed_down and c < #ord and c+1) or (pressed_up and c > 1 and c-1) or c
									ord[c], ord[trade_idx] = ord[trade_idx], ord[c]
									was_changed = true
								end
								imgui.end_popup()
							end
							if changed then imgui.set_next_item_open(true) end
							if mm_tbl.enabled and character_tbl.lua.imgui_options and not imgui.same_line() and imgui.tree_node("") then 
								imgui.indent()
								character_tbl.lua.imgui_options()
								imgui.unindent()
								imgui.tree_pop()
							end
							imgui.pop_id()
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
				changed = hk.hotkey_setter("Play prev"); set_wc()
				changed = hk.hotkey_setter("Play next"); set_wc()
				changed = hk.hotkey_setter("Change to Facial Anims"); set_wc()
				
				
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
			
			if imgui.tree_node("Simple fighter data") then
				for id, name in pairs(characters) do
					if imgui.tree_node(name) then
						local data = PlayerData.simple_fighter_data[id]
						if data then
							if imgui.button("Dump moves_dict json") then
								PlayerData.dump_moves_dict_json(data)
							end
							tooltip("Dumps action data to\n	reframework\\data\\MMDK\\Moves Dict\\" .. data.name .. " moves_dict.json")
							
							if EMV then
								EMV.read_imgui_element(data)
							end
						else
							tmp_fns.get_sfdata = function()
								tmp_fns.get_sfdata = nil
								PlayerData:get_simple_fighter_data(name)
							end
						end
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

--Sets fighter speed
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