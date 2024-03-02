# MMDK - Moveset Mod Development Kit

MMDK is a [REFramework](https://github.com/praydog/REFramework) script and mod development kit for creating and researching Lua moveset mods in Street Fighter 6. It creates a dictionary of all the relevant data needed to mod movesets for each fighter, along with functions and methods to change and add-to various aspects of the moves, and then allows you to edit this dictionary at the start of each match using a Lua file.

It also can produce a "Moveset Research" window where you can set the current move being performed, view its keys live and skip frame-by-frame as they are executed. Combined with the [Hitbox Viewer](https://github.com/WistfulHopes/SF6Mods), it can provide a lot of insight into SF6's mechanics.

MMDK allows for full moveset modding including adding entirely new moves with new command inputs while using animations, VFX, keyframe data and damage data from any characters. Mods for MMDK are created as Lua files and multiple of them can run on a character per match.

## Installation

1. Download [REFramework](https://github.com/praydog/REFramework) SF6.zip [here](https://github.com/praydog/REFramework-nightly/releases/download/latest/SF6.zip) (must be newer than Sept 8 2023) and place its dinput8.dll in your game folder
2. Download this repository under Code -> Download as Zip and extract the the contents of each folder inside to your game folder or install as a mod with [Fluffy Mod Manager](https://www.fluffyquack.com/)

## EMV Engine

Download [EMV Engine + Console](https://github.com/alphazolam/EMV-Engine) to see useful control panels for each object (including keys) while developing moveset mods, allowing you to do live testing more easily. EMV is also required to see the imgui menu trees for the fighter in the Moveset Research window.

## Usage

1. Open REFramework's main window by pressing **Insert** (default)
2. Navigate to '`Script Generated UI`' and open the MMDK menu
3. Here you can enable and disable the automatic modification of specific characters by the mod's fighter Lua files, control which mods are active for what characters, control individual mod options, and set the visibility of the Moveset Research window

## The Street Fighter Battle System

- Street Fighter 6 uses the same battle system as Street Fighter V and IV (and maybe earlier), ported into RE Engine's "Managed Objects"
- The battle system for each fighter is completely independent from their visual appearance (mesh, GameObject); one can exist without the other
- Each fighter has a list of "Actions" (moves), each identified by a number ID
- Each Action has 50+ arrays of keys for different key types (most empty) across its duration
- A **Key** activates game logic for the character over a specific frame-range of the action


## Key Types

- A **`MotionKey`** activates an animation (MotionID) from a motlist file (MotionType) at a certain frame
- A **`AttackCollisionKey`** activates a hitbox rectangle from the character's rectangle list over a frame range, and applies damage from a linked 'HIT_DT_TBL' when the hit connects
- A **`DamageCollisionKey`** activates a hurtbox rectangle over a frame range
- A **`TriggerKey`** determines the move's cancel list (what actions the move can transition into)
- A **`VfxKey`** plays a visual effect
- A **`BranchKey`** connects actions together automatically without player inputs
- A **`ShotKey`** spawns a projectile (another action)
- A **`SEKey`** plays a sound effect by its unique ID (number)
- A **`VoiceKey`** plays a voice line by its unique ID (number)
- A **`FacialKey`** plays a facial animation, similar to a MotionKey
- A **`SteerKey`** moves the fighter in a X,Y direction
- A **`PlaceKey`** also moves a fighter in a X,Y direction during a move, but frame-by-frame
- A **`LockKey`** links certain actions together and can apply damage in some cases
- Various other types of keys are also available; test them in the Moveset Research window with EMV Engine

## The 'Moveset Research' Window

Under REFramework `Script Generated UI`, MMDK features a checkbox to enable a Moveset Research window. This window will appear during a match and allow you to trigger moves from the fighter's list, seek across the frames of their move, play in slow motion (or reverse), and seek frame by frame. It can also preview animations and sound effects, among other things. 

![image](https://i.imgur.com/56LRPki.png)

Functionalities of the Moveset Research window are largely explained through its tooltips; hover your mouse over each element to see what it does.


# Scripting Fighter Lua Files

MMDK provides a lua template file for each fighter by name, under `reframework/autorun/MMDK`. These files each contain a function called `apply_moveset_changes`, which is automatically run when the character is enabled in the mod and they are detected in a match.

Within this function, you have access to many useful tables and objects from the battle system for the context of modding that character's moveset, all contained in the **`data`** parameter. **`data`** is a lua class, and it has several attached methods that facilitate adding new objects such as Actions, VFX, and Triggers to the moveset.

- The `data` parameter contains `data.moves_dict`, which has a dictionary of actions/moves (as Lua tables). You can assign a move to a local variable such as Juri's: 

**`local MyAction = data.moves_dict.By_Name.SPA_TENSINREN_L`**

- Each action will have subtables for its active keys, such as `MyAction.TriggerKey[1]`(for the first key in the Lua table of the list), `MyAction.AttackCollisionKey.list` (for the actual List object), etc.

**NOTE**: RE Engine objects use 0-based indexing and are actually parts of the game, while Lua uses 1-based indexing and its tables are only part of MDMK.  `MyAction.TriggerKey` is a Lua table while `MyAction.TriggerKey.list` isn't, so it's important to know the difference

- You can also access the keys through the `fab` 'FAB_ACTION 'object of the action, which has the 54+ keys lists as an array called `MyAction.fab.Keys` and also has the master frame count of an action

- The `MyAction.dmg` table can exist if a move has an AttackCollisionKey that does damage. Here contains a HIT_DT_TBL, which has 20 different `param` subtables for different scenarios like being in midair or on the ground when an attack connects. A damage table from an AttackCollisionKey that uses AttackDataIndex `15` can be accessed as `MyAction.dmg[15]`

- The `MyAction.box` table may also be present, containing hurtbox and hitbox rectangles for the move

- The `MyAction.vfx` table contains the VFX elements used by a move

- The `MyAction.trigger` table contains the BCM.TRIGGER elements used by a move, dictated by its TriggerKeys. These decide how a move is inputted by button presses

- The `MyAction.tgroups` table contains information about TriggerGroups for a move. These are lists of other actions which the move can cancel into

## Lua Basics

For a general understanding of Lua, check out the official [Programming in Lua](https://www.lua.org/pil/1.html) textbook and read through Part I.

Then check out the [REFramework guide](https://cursey.github.io/reframework-book/index.html) to see which APIs you have available within a REFramework script like this.

## Functions.lua

Functions.lua is included with MMDK and is shared among all its scripts by Lua's 'require' function. Its functions can be accessed through the table **`fn`**, by default. Check the source code for a description of each function, provided in comments. Some useful functions being:
- **edit_obj** - takes a RE Managed object and a table of fields/properties vs values in which to change, and changes them. Use the value `"nil"` (in quotes) to set a field to nil (delete it).
- **append_to_list** - takes a RE Managed Object 'Generic.Dictionary/List' object and adds a new element to it, then returns the incremented list
- **append_key** - Takes a RE Engine System.Collections.Generic.List object, a string KeyType, and a table of field names vs values and adds a new instance of that key to the list object while applying the fields table to it as changes
- **clone** - Takes a RE Managed Object and returns a basic duplicate of it. Fields of the object are cloned as well unless they are System.Arrays or System.Collections objects
- **insert_list/array** - Inserts elements from list B (or just element B) into list A at the given index


## Fighter Lua Examples

Check out 'Ken Donkey Kick.lua' and ['SF6 Balance Tweaks.lua'](https://www.nexusmods.com/streetfighter6/mods/1485) for some working examples of MDMK scripts. Since these are Lua scripts, you have full access to what [REFramework provides](https://cursey.github.io/reframework-book/api/sdk.html) inside each mod and can add things like loading options from json files or creating hooks and callbacks to support your changes.

There are also mods to disable parry/perfect parry, Drive Impact and Drive Rush.


#### Getting a move:
```lua
local moves_by_name = data.moves_dict.By_Name
local ATK_5LP = moves_by_name["ATK_5LP"] --Light punch
-- or --
local moves_by_id = data.moves_dict.By_ID
local ATK_5LP = moves_by_id[600] --Light punch
```

#### Getting a move from another character
```lua
local ryu_data = data:get_simple_fighter_data("Ryu")
local ryu_moves_by_id = ryu_data.moves_dict.By_ID
local ryu_ATK_5HK = ryu_moves_by_id[617]
```


#### Editing damage data:
```lua
--ATK_5LP

for attack_idx, dmg_tbl in pairs(ATK_5LP.dmg) do
    --Only going through dmg params for standing and crouching:
    for i, param_idx in ipairs(hit_types.s_c_only) do
        --Use 'to_isvec2' to save special isvec2 Vector2 fields like FloorDest
        edit_obj(dmg_tbl.param[param_idx], {DmgType=11, MoveType=15,  JuggleLimit=15, JuggleAdd=1, FloorDest=to_isvec2(50, 80)})
        
        --or you can save fields one at a time:
        dmg_tbl.param[tbl_idx].DmgType = 11
        dmg_tbl.param[tbl_idx].MoveType = 15
        dmg_tbl.param[tbl_idx].JuggleLimit = 15
        dmg_tbl.param[tbl_idx].JuggleAdd = 1
        write_valuetype(dmg_tbl.param[tbl_idx], "FloorDest", to_isvec2(50, 80)) --This is required when assigning oddball ValueTypes like isvec2 to fields
    end
end
```

#### Adding a new triggers to an ActionID and to different TriggerGroups
Triggers control when a move is executed. They contain button presses and commands, as well as other requirements for doing the move. A move (by ActionID) can have multiple independent triggers.
TriggerGroups (also known as Cancel Lists) are lists of triggers that can only execute at a specific time, such as during the end of a different move (like a 2nd hit in a combo). 
A TriggerKey gives a frame range during a move in which the triggers in its TriggerGroup can be triggered. 
TriggerGroups also have priorities, this is determined by the Trigger's ID: its order in the Triggers list.
```lua
local new_trigs, new_trig_ids = data:add_triggers(18, 599, {10}, 112)

for id, trig in pairs(new_trigs) do
    edit_obj(trig, {focus_need=1, focus_consume=5000, category_flags=1048476, function_id=3, })
end

local new_trigs2, new_trig_ids2 = data:add_triggers(663, 599, {30, 45}, 96)
--Edit new triggers to new inputs:
for id, trig in pairs(new_trigs2) do
    edit_obj(trig, {focus_need=1, focus_consume=5000, category_flags=1048476, function_id=3})
    edit_obj(trig.norm, {ok_key_flags=0, dc_exc_flags=(inputs.MP + inputs.MK + inputs.BACK), ok_key_cond_flags=16512})
end
```

#### Adding a TriggerKey:
```lua
if not ATK_5LP.TriggerKey.list._items[3] then --This will not append if there are already more than the default 3 keys
-- or that could be written as --
if not ATK_5LP.fab.Keys[6]._items[3] then --ATK_5LP.fab.Keys[6] is the same list. However, 'ATK_5LP.TriggerKey' will only exist if there's already at least one key

    append_key(ATK_5LP.fab.Keys[6], "TriggerKey", {ConditionFlag=5199, TriggerGroup=47, StartFrame=4, EndFrame=18}) --generic function
    -- or that could be written as  --
    edit_triggerkey(ATK_5LP, 3, 1, {ConditionFlag=5199, TriggerGroup=47, StartFrame=4, EndFrame=18}) --specific function
    
end
```


#### Editing a single BCM.TRIGGER object:
```lua
edit_obj(ATK_5LP.trigger[1], {category_flags=1048476, function_id=3})
```

#### Delayed execution / startup
Some code you may need to run on script startup (but still inside of a callback), have run on the next frame, or have it run repeatedly until you want it to stop. You can do this by putting it inside a temporary function in the global variable `tmp_fns`.
Any function in `tmp_fns` will be executed every frame during the game's 'UpdateBehavior' module.
```lua
local timer_start = os.clock()

tmp_fns.timer_func = function()
    if os.clock() - timer_start > 1.0 then --one second elapsed
        tmp_fns.timer_func = nil
        re.msg("Timer's up!")
    end
end
```
Callbacks can be used within any Lua script in REFramework including MMDK mods, so you can create one to do things like manage cameras real-time as seen in the Throw Angles mod.

### Adding a VfxKey
```lua
--Clone a VFX from RYU_ACTION.DRIVE_RUSH_CANCEL to ContainerID #530 as new ElementID #30, then add it to RYU_ACTION.NEW_5HP as a clone of RYU_ACTION.DRIVE_RUSH_CANCEL's 1st VfxKey:
local new_vfx = data:clone_vfx(RYU_ACTION.DRIVE_RUSH_CANCEL.vfx[2], 530, 30, RYU_ACTION.NEW_5HP, RYU_ACTION.DRIVE_RUSH_CANCEL.VfxKey[0])

--Load an EFX file from anywhere and assign it as the effect that will be used for the new VFX:
new_vfx:setResources(0, fn.create_resource("via.effect.EffectResource", "product/vfx/character/fgm/esf016/effecteditor/efd_10_esf016_1612_36.efx"))
```

#### Adding a new action

Search MMDK.lua for more information about these functions, as they are a part of the `data` class defined there
```lua
local ATK_D_KICK_L = data:clone_action(ryu_moves_by_id[1025], 939)
if ATK_D_KICK_L then
    local move = ATK_D_KICK_L
    --100604 is Ryu's original bankID, so his original MotionKeys will work without edit:
    data:add_dynamic_motionbank("Product/Animation/esf/esf001/v00/motionlist/SpecialSkill/esf001v00_SpecialSkill_04.motlist", 100604) 
    
    local new_hit_dt_tbl, new_attack_key = data:clone_dmg(ryu_moves_by_id[1025].dmg[181], 1337, move, nil, #move.AttackCollisionKey-1)
    --edit_hit_dt_tbl(new_hit_dt_tbl, hit_types.allhit, {DmgValue=1000, DmgType=11, MoveTime=24, MoveType=13, HitStopOwner=20, HitStopTarget=20, MoveDest=to_isvec2(200, 70), JuggleLimit=10, HitStun=20, SndPower=4, HitmarkStrength=3})
    
    --Create a new HitRect16 and add it to the new AttackCollisionKey
    local new_hit_rect = data:add_rect_to_col_key(new_attack_key, "BoxList", 451, 0)
    edit_obj(new_hit_rect, {OffsetX=80, OffsetY=121, SizeX=54, SizeY=23})
    
    --The old action had a bunch of extra STRIKE AttackCollisionKeys, so set them to all use the new hitbox rect ID
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
    local new_triggers, new_trig_ids = data:clone_triggers(615, 939, {0}, 118)
    
    for i, trig in ipairs(new_triggers) do
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
```

## Scripting Tips
- After cloning an action, you can usually copy+paste the code block used to create it and edit it a little to create another new action. You can clone things created for the first action to the second one.
- Use [EMV Engine](https://github.com/alphazolam/EMV-Engine) with the Moveset Research window to see what's available to edit. The contents shown under `[Lua Data]` are Lua tables exactly as you can access them from the `data` parameter.
- Search for function descriptions in MMDK.lua and functions.lua if you are confused about how to use them

## JSON Data
- MMDK comes with json files for fighter HIT_DT_TBLs (damage), rects (hitboxes), triggers, triggergroups and it can generate json files of the moves dict. Most of this data is loaded at script startup to be used when calling `get_simple_fighter_data`, but it is also useful for cross-reference when developing mods. Click the `Dump` buttons under `[Lua Data]` to re-dump this data when the game is updated.

## Credits
Thanks to Killbox for testing and praydog for creating REFramework


[Modding Haven Discord](https://discord.gg/acCRqRyUB2)

[SF Moveset Modding Discord](https://discord.gg/T5raMgr)