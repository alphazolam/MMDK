# MMDK - Moveset Mod Development Kit

MMDK is a [REFramework](https://github.com/praydog/REFramework) script and mod development kit for creating and researching Lua moveset mods in Street Fighter 6. It creates a dictionary of all the relevant data needed to mod movesets for each fighter, along with functions and methods to change and add-to various aspects of the moves, and then allows you to edit this dictionary at the start of each match using a Lua file.

It also can produce a "Moveset Research" window where you can set the current move being performed, view its keys live and skip frame-by-frame as they are executed. Combined with the [Hitbox Viewer](https://github.com/WistfulHopes/SF6Mods), it can provide a lot of insight into SF6's mechanics.

MMDK allows for full moveset modding including adding entirely new moves with new command inputs while using animations, VFX, keyframe data and damage data from any characters. Mods for MMDK are created as Lua files and multiple of them can run on a character per match.

## Installation

1. Download [REFramework](https://github.com/praydog/REFramework) SF6.zip [here](https://github.com/praydog/REFramework-nightly/releases/download/latest/SF6.zip) (must be newer than Sept 8 2023) and place its dinput8.dll in your game folder
2. Download this repository under Code -> Download as Zip and extract the the contents of each folder inside to your game folder or install each as a mod with [Fluffy Mod Manager](https://www.fluffyquack.com/)

## Usage

1. Open REFramework's main window by pressing **Insert** (default)
2. Navigate to '`Script Generated UI`' and open the Moveset Mod menu
3. Here you can enable and disable the automatic modification of specific characters by the mod's fighter Lua files, and set the visibility of the Moveset Research window

## The Street Fighter Battle System

- Street Fighter 6 uses the same battle system as Street Fighter V and IV (and maybe earlier), ported into RE Engine's "Managed Objects"
- The battle system for each fighter is completely independent from their visual appearance (mesh, GameObject); one can exist without the other
- Each fighter has a list of "Actions" (moves), each identified by a number ID
- Each Action has 50+ arrays of keys for different key types (most empty) across its duration
- A **Key** activates game logic for the character over a specific frame-range of the action


## Key Types

- A **`MotionKey`** activates an animation (MotionID) from a motlist file (MotionType) at a certain frame
- A **`AttackCollisionKey`** activates a hitbox rectangle from the character's rectangle list over a frame range
- A **`DamageCollisionKey`** activates a hurtbox rectangle over a frame range
- A **`TriggerKey`** determines the move's cancel list (what actions the move can transition into)
- A **`VfxKey`** plays a visual effect
- A **`SteerKey`** moves the fighter in a X,Y direction
- A **`BranchKey`** connects actions together automatically without player inputs
- A **`ShotKey`** spawns a projectile (another action)
- A **`SEKey`** plays a sound effect by its Trigger ID (number)
- A **`FacialKey`** plays a facial animation, similar to a MotionKey
- A **`PlaceKey`** also moves a fighter in a X,Y direction during a move, but frame-by-frame
- Various other types of keys are also available; test them in the Moveset Research window with EMV Engine

## The 'Moveset Research' Window

Under REFramework `Script Generated UI`, Moveset Mod features a checkbox to enable a Moveset Research window. This window will appear during a match and allow you to trigger moves from the fighter's list, seek across the frames of their move, play in slow motion (or reverse), and seek frame by frame. It can also preview animations and sound effects, among other things. 

![image](https://i.imgur.com/56LRPki.png)

Functionalities of the Moveset Research window are largely explained through its tooltips; hover your mouse over each element to see what it does.

## EMV Engine

Download [EMV Engine + Console](https://github.com/alphazolam/EMV-Engine) to see useful control panels for each object (including keys) while developing moveset mods, allowing you to do live testing more easily. EMV is also required to see the imgui menu trees for the fighter in the Moveset Research window.


# Scripting Fighter Lua Files

Moveset Mod provides a lua file for each fighter by name, under `reframework/autorun/MovesetMod`. These files each contain a function called `apply_moveset_changes`, which is automatically run when the character is enabled in the mod and they are detected in a match.

Within this function, you have access to many useful tables and objects from the battle system for the context of modding that character's moveset, all contained in the **`data`** parameter. **`data`** is a lua class, and it has several attached methods that facilitate adding new objects such as Actions, VFX, and Triggers to the moveset.

- The `data` parameter contains `data.moves_dict`, which has a dictionary of actions/moves (as Lua tables). You can assign a move to a local variable such as Juri's: **`local MyAction = data.moves_dict.By_Name.SPA_TENSINREN_L`**

- Each action will have subtables for its active keys, such as `MyAction.TriggerKey[1]`(for the first key in the Lua table of the list), `MyAction.AttackCollisionKey.list` (for the actual List object), etc.

**NOTE**: RE Engine objects use 0-based indexing and are actually parts of the game, while Lua uses 1-based indexing and its tables are only part of MDMK.  `MyAction.TriggerKey` is a Lua table while `MyAction.TriggerKey.list` isn't, so it's important to know the difference

- You can also access the triggers through the `fab` 'FAB_ACTION 'object of the action, which has the 54+ keys lists as an array called `MyAction.fab.Keys`

- The `MyAction.dmg` table can exist if a move has an AttackCollisionKey that does damage. Here contains a HIT_DT_TBL, which has 20 different `param` subtables for different scenarios like being in midair or on the ground when an attack connects. A damage table from an AttackCollisionKey that uses AttackDataIndex `15` can be accessed as `MyAction.dmg[15]`

- The `MyAction.box` table may also be present, containing hurtbox and hitbox rectangles for the move

- The `MyAction.vfx` table contains the VFX elements used by a move

- The `MyAction.trigger` table contains the BCM.TRIGGER elements used by a move, dictated by its TriggerKeys. These decide how a move is inputted by button presses

- The `MyAction.tgroups` table contains information about TriggerGroups for a move. These are lists of other actions which the move can cancel into

## Lua Basics

For a general understanding of Lua, check out the official [Programming in Lua](https://www.lua.org/pil/1.html) textbook and read through Part I.

Then check out the [REFramework guide](https://cursey.github.io/reframework-book/index.html) to see which APIs you have available within a REFramework script like this.

## Functions.lua

Functions.lua is included with Moveset Mod and is shared among all its scripts by Lua's 'require' function. Its functions can be accessed through the table **`fn`**, by default. Check the source code for a description of each function, provided in comments. Some useful functions being:
- **edit_obj** - takes a RE Managed object and a table of fields / properties vs values in which to change, and changes them
- **append_to_list** - takes a RE Managed Object 'Generic.Dictionary'object and adds a new element to it, then returns the incremented list
- **append_key** - Takes a RE Engine System.Collections.Generic.List object, a string KeyType, and a table of field names vs values and adds a new instance of that key to the list object while applying the fields table to it as changes
- **clone** - Takes a RE Managed Object and returns a basic duplicate of it. Fields of the object are cloned as well unless they are System.Arrays or System.Collections objects


## Fighter Lua Examples

Check out 'Ken Donkey Kick.lua' and 'Throw Angles.lua' for some working examples of MDMK scripts. Since these are Lua scripts, you have full access to what [REFramework provides](https://cursey.github.io/reframework-book/api/sdk.html) inside each mod and can add things like loading options from json files or creating hooks and callbacks to support your changes.

#### Getting a move:
```lua
local ATK_5LP = moves_by_name["ATK_5LP"] --Light punch
-- or --
local ATK_5LP = moves_by_id[600] --Light punch
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

#### Editing damage data:
```lua
-- A special 'isvec2' ValueType that can be reused to save isvec2 fields:
local vec2_FloorDest = ValueType.new(sdk.find_type_definition("nAction.isvec2"))

...

--ATK_5LP
vec2_FloorDest:call(".ctor", 50, 80) --Assign [50, 80] to the isvec2

for attack_idx, dmg_tbl in pairs(ATK_5LP.dmg) do
    --Only going through dmg params for standing and crouching:
	for i, param_idx in ipairs(hit_types.s_c_only) do
		edit_obj(dmg_tbl.param[param_idx], {DmgType=11, MoveType=15,  JuggleLimit=15, JuggleAdd=1, FloorDest=vec2_FloorDest})
		
		--or you can save fields one at a time:
		dmg_tbl.param[tbl_idx].DmgType = 11
		dmg_tbl.param[tbl_idx].MoveType = 15
		dmg_tbl.param[tbl_idx].JuggleLimit = 15
		dmg_tbl.param[tbl_idx].JuggleAdd = 1
		write_valuetype(dmg_tbl.param[tbl_idx], "FloorDest", vec2_FloorDest) --This is required when assigning oddball ValueTypes like isvec2 to fields
	end
end

```
#### Editing a single BCM.TRIGGER object:
```lua
edit_obj(ATK_5LP.trigger[1], {category_flags=1048476, function_id=3})
```

#### Adding a new action

Search MovesetMod.lua for more information about these functions, as they are a part of the `data` class defined there
```
if not moves_by_id[905] then
    --Clone action ID #608 to a new action with ID #905:
    RYU_ACTION.NEW_5HP = data:clone_action(608, 905)
    
    --Clone all triggers for Action #615 and add them to Action #608, then optionally add to TriggerGroup 0 with an optional target TriggerGroup ID of 118:
    local new_trigs_by_id, new_trig_ids = data:clone_triggers(615, 939, {0}, 118)
    
    --Clone a VFX from RYU_ACTION.DRIVE_RUSH_CANCEL to ContainerID #530 as new ElementID #30, then add it to RYU_ACTION.NEW_5HP as a clone of RYU_ACTION.DRIVE_RUSH_CANCEL's 1st VfxKey:
    local new_vfx = data:clone_vfx(RYU_ACTION.DRIVE_RUSH_CANCEL.vfx[2], 530, 30, RYU_ACTION.NEW_5HP, RYU_ACTION.DRIVE_RUSH_CANCEL.VfxKey[0])
    
    --Load an EFX file from anywhere and assign it as the effect that will be used for the new VFX:
    new_vfx:setResources(0, fn.create_resource("via.effect.EffectResource", "product/vfx/character/fgm/esf016/effecteditor/efd_10_esf016_1612_36.efx"))
end
```

## Tips

- Use EMV Engine with the Moveset Research window to see what's available to edit. The contents shown under `[Lua Data]` are Lua tables exactly as you can access them from the `data` parameter.
- The Moveset Research window can be used to view moves and their keys frame-by-frame and in slow motion

## Credits
Thanks to Killbox for testing and praydog for creating REFramework
