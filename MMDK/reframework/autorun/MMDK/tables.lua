-- MMDK - Moveset Mod Development Kit for Street Fighter 6 -- Shared Tables
-- By alphaZomega
-- May 22, 2024

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
	[13] = "AKI", 
	[14] = "Rashid", 
	[15] = "Blanka", 
	[16] = "Juri", 
	[17] = "Marisa", 
	[18] = "Guile", 
	[19] = "Ed",
	[20] = "E Honda", 
	[21] = "Jamie", 
	[22] = "Akuma", 
	[26] = "M Bison", 
	[27] = "Terry", 
}

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
	NEUTRAL = 0,
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
}

--BCM.TRIGGER CategoryFlags:
local cat_flags = { 
    IsPunch = 1, 
    IsKick = 2,
    IsHeadButt = 4,
    IsBodyAttack = 8,
    IsLight = 16, 
    IsMiddle = 32,
    IsHeavy = 64,
    IsLv1 = 128, 
    IsLv2 = 256,
    IsLv3 = 512,
    IsLv4 = 1024, 
    IsNormal = 2048,
    IsUnique = 4096,
    IsSpecial = 8192,
    IsExtra = 16384,
    IsSuper = 32768,
    IsDriveImpact = 65536,
    IsThrowNormal = 131072,
    IsThrowSpecial = 262144, -- IsThrowCommand  
    IsThrowShell = 524288, -- IsThrowCommand
    IsDriveDash = 1048576,
    IsParryDash = 2097152,
    Unk1 = 4194304, -- Set on Dash Forward            
    Unk2 = 8388608, -- Set on Dash Backward           
    Unk3 = 16777216, 
    Unk4 = 3554432, 
    IsJump = 67108864, 
    Unk5 = 134217728,
    IsFly = 268435456, -- IsProjectile
    IsGround = 536870912,
    IsAir = 1073741824,
}

-- For ok_key_cond_flags or dc_exc_flags:
local inputflags = { 
    unk1 = 1,
    unk2 = 2,
    unk3 = 4,
    unk4 = 8,
    unk5 = 16,
    unk6 = 32, --match all buttons?
    unk7 = 128,
    unk8 = 256,
    unk9 = 512,
    unk10 = 1024,
    unk11 = 2048,
    unk12 = 4096,
    unk13 = 8192,
    unk14 = 16384, -- Direction matching?
    unk15 = 32768,
    unk16 = 65536,
    unk17 = 131072,
    unk18 = 262144,
    unk19 = 524288,
    unk20 = 1048576,
    unk21 = 2097152,
    unk22 = 4194304,
}

local key_types = {
    [0] = "BranchKey",
    [1] = "StatusKey",
    [2] = "SwitchKey",
    [3] = "ExtSwitchKey",
    [4] = "VisualSwitchKey",
    [5] = "SteerKey",
    [6] = "TriggerKey",
    [7] = "AutoTriggerKey",
    [8] = "EventKey",
    [9] = "WorldKey",
    [10] = "AttackCollisionKey",
    [11] = "OtherCollisionKey",
    [12] = "_UnknownKey12",
    [13] = "DamageCollisionKey",
    [14] = "PushCollisionKey",
    [15] = "MotionKey",
    [16] = "SimpleMotionKey",
    [17] = "ExtMotionKey",
    [18] = "MotionCameraKey",
    [19] = "FacialKey",
    [20] = "FacialAutoKey",
    [21] = "MergeKey",
    [22] = "SEKey",
    [23] = "ShellSEKey",
    [24] = "_UnknownKey24",
    [25] = "VoiceKey",
    [26] = "_UnknownKey26",
    [27] = "SoundStateKey",
    [28] = "BGMKey",
    [29] = "VfxKey",
    [30] = "VFXKey",
    [31] = "PlaceKey",
    [32] = "ShotKey",
    [33] = "_UnknownKey33",
    [34] = "ModelPartsKey",
    [35] = "PropsKey",
    [36] = "CameraKey",
    [37] = "SystemCameraKey",
    [38] = "UniqueCollisionKey",
    [39] = "BonePlaceKey",
    [40] = "GimmickCollisionKey",
    [41] = "GimmickCollisionKey2",
    [42] = "WindKey",
    [43] = "TimelineKey",
    [44] = "BlendShapeKey",
    [45] = "NormalShapeKey",
    [46] = "FacialMergeKey",
    [47] = "LockKey",
    [48] = "BGPlaceKey",
    [49] = "BGPlaceKey",
    [50] = "DynamicTriggerKey",
    [51] = "DriveSteerKey",
    [52] = "DriveSteerKey2",
    [53] = "_UnknownKey53",
    [54] = "_UnknownKey54",
}

local key_types_by_index = {}
for i, list_name in pairs(key_types) do
	key_types_by_index[list_name] = i
end

tbls = {
	cat_flags = cat_flags,
	characters = characters,
	hit_types = hit_types,
	key_types = key_types,
	key_types_by_index = key_types_by_index,
	--inputflags = inputflags,
	inputs = inputs,
}

return tbls