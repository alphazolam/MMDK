Below is a list of current methods for the PlayerData class (passed as `data` in sample MMDK scripts)
Example usage:
	local new_cmds = data:add_command(30, 0, {inputs.FORWARD}, {2}, {11}, {total_frame=-1}, {parry_trig_id})


-- Add a new CharacterAsset.ProjectileData to this player
--Returns the new ProjectileData:
add_pdata(player_index, new_p_id, src_or_src_id, fields)

-- Add a new motlist to a character using a new MotionType, making new animations accessible
--Returns the new DynamicMotionbank:
add_dynamic_motionbank(player_index, motlist_path, new_motiontype, via_motion)

-- Add a new unique HitRect16 to a fighter and to a given AttackCollisionKey / DamageCollisionKey 
--Returns the new HitRect16:
add_rect_to_col_key(player_index, col_key, boxlist_name, new_rect_id, boxlist_idx, rect_to_add)

--Add a Trigger (by its index in the Triggers list) to a BCM.TRIGGER_GROUP, or create the TriggerGroup if it's not there
--Returns the BCM.TRIGGER_GROUP:
add_to_triggergroup(player_index, tgroup_idx, trigger_idx)

--Takes CommandList index 'new_cmdlist_id' and adds a new command at index 'new_cmd_idx' of it. Optionally takes 'fields' table to apply afterwards, and 'new_trigger_ids' to apply itself to all trigger IDs in the table
--Creates an array of 16 inputs and optionally sets fields on them using three optional array-tables as arguments: 
--'input_list' sets the 'ok_key_flags' for inputs; 'cond_list' sets the 'ok_key_cond_check_flags' for inputs; 'maxframe_list' sets the 'frame_num' for inputs. Use 'fn.edit_command_input' to edit other fields
--Returns the new/edited BCM.COMMAND (commands list):
add_command(player_index, new_cmdlist_id, new_cmd_idx, input_list, cond_list, maxframe_list, fields, new_trigger_ids)

--Wrapper for clone_triggers that doesnt overwrite old triggers that use new_id
--Returns a Lua table of triggers for this actionID, and a matching Lua table of TriggerIDs for them as the 2nd return value:
add_triggers(player_index, old_id_or_trigs, new_id, tgroup_idxs, max_priority)

-- Collect an action for moves_dict:
collect_fab_action(player_index, fab_action, is_common)

-- Collect additional data that requires moves_dict to already be complete:
collect_additional(player_index)

--Populate the moves_dict in full:
collect_moves_dict(player_index)

-- Clone triggers using 'old_id_or_trigs' ActionID (or a table of BCM.TRIGGERs) into new triggers for ActionID 'action_id'. Use table 'tgroup_idxs' to add it to a list of TriggerGroups (by number TriggerGroup ID)
-- The new trigger will be given a free Trigger ID as close as possible to 'max_priority' without exceeding it (Important! An ID of the wrong number will make the trigger have low priority / not work)
-- All old triggers using 'action_id' will be deleted unless 'no_overwrite' is true. Returns 2 Lua array-tables, 1st one of the new Triggers at that ActionID and 2nd one of its matching new TriggerIDs 
clone_triggers(player_index, old_id_or_trigs, action_id, tgroup_idxs, max_priority, no_overwrite)

--Clone a MMDK move / ActionID 'old_id_or_obj' into a new move with the ActionID 'new_id'. Returns the new move Lua object
clone_action(player_index, old_id_or_obj, new_id)

--Clone a HIT_DT_TBL as 'old_hit_id_or_dt' into a new available HIT_DT_TBL with ID 'new_hit_id'. Use 'action_obj' to add it to a MMDK action object.
--Use 'src_key' to provied an existing key as the basis for the returned key,  and 'target_key_index' to assign it to a specific index in the key list
--Returns 2 objects: the new HIT_DT_TBL and the new AttackCollisionKey it was added to
clone_dmg(player_index, old_hit_id_or_dt, new_hit_id, action_obj, src_key, target_key_index) 

--Clone a EPVStandardData.Element into a new one at on container 'target_container_id' and ID 'new_id'. Use action_obj to add it to a MMDK action object and then 'key_to_clone' to clone a VfxKey for it
--Returns the new EPVStandardData.Element and optionally the cloned key it was added to
clone_vfx(player_index, src_element, target_container_id, new_id, action_obj, key_to_clone)

--Dumps a json file of this PlayerData's commands. 'commands' and 'path' are optional
dump_commands_json(player_index, path, commands)

--Dumps a json file of this PlayerData's hit_datas. 'hit_datas' and 'path' are optional
dump_hit_dt_json(player_index, path, hit_datas)

--Dumps a json file of this data's moves_dict. 'moves_dict' and 'path' are optional
dump_moves_dict_json(player_index, path, moves_dict)

--Dumps a json file of this PlayerData's rects. 'rects' and 'path' are optional
dump_rects_json(player_index, path, rects)

--Dumps a json file of this PlayerData's tgroups. 'tgroups' and 'path' are optional
dump_tgroups_json(player_index, path, tgroups)

--Dumps a json file of this PlayerData's triggers. 'triggers_by_act_id' and 'path' are optional
dump_trigger_json(player_index, path, triggers_by_act_id)

--Retrieves an unmodified moves dict from a json file or from cache, and creates it if its not there (or creates all missing moves dicts):
get_moves_dict_json(player_index, chara_name, path, collect_all)

--Gets the generic PlayerData for Common moves (Fighter ID 0)
get_common_fighter_data(player_index)

--Takes a fighter name or ID and returns a simple/fake version of this class with a moves_dict for that fighter
get_simple_fighter_data(player_index, chara_name_or_id)

--Create a new instance of this Lua class:
new(player_index, do_make_dict, data)