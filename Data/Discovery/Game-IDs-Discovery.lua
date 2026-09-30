local _, ns = ...

if not ns.IS_DISCOVERY then
	return
end

--[[
    Source: the pre-split shared data files, as the Classic Era client loaded
    them, pruned of the rows Validate Data on the Classic Era client (1.15.9,
    build 69722) flagged NOT ON CLIENT. The values await Validate Data on a
    Season of Discovery realm.
]]

--------------------------------------------------------------------------------
-- Stealth Abilities
--------------------------------------------------------------------------------

ns.SHADOWMELD_SPELL_ID = 20580

--[[
    Rogue Stealth, rank 1. C_Spell.GetSpellName resolves the base name "Stealth", which
    a bare /cast fires at the highest rank the rogue knows (Stealth Eating).
]]
ns.STEALTH_SPELL_ID = 1784

--------------------------------------------------------------------------------
-- Druid Forms
--------------------------------------------------------------------------------

ns.DRUID_DIRE_BEAR_FORM_SPELL_ID = 9634
ns.DRUID_BEAR_FORM_SPELL_ID = 5487
ns.DRUID_CAT_FORM_SPELL_ID = 768

--------------------------------------------------------------------------------
-- Rogue Poisons Skill
--------------------------------------------------------------------------------

--[[
    "Poisons" (spell 2842) — the rogue poison-crafting skill; the same ID on
    Era and TBC. Knowing it gates the Poisons macro (a rogue without it can't
    apply poisons at all) and provides the middle-click crafting branch.
]]
ns.POISONS_SPELL_ID = 2842

--------------------------------------------------------------------------------
-- Hunter Pet Spells
--------------------------------------------------------------------------------

ns.CALL_PET_SPELL_ID = 883
ns.DISMISS_PET_SPELL_ID = 2641
ns.FEED_PET_SPELL_ID = 6991
ns.MEND_PET_SPELL_ID = 136
ns.REVIVE_PET_SPELL_ID = 982

--------------------------------------------------------------------------------
-- Pet Buff Food
--------------------------------------------------------------------------------

--[[
    Hunter and Warlock pet buff foods. The pet-buff override offers the highest
    rank the bags hold, settingKey names each food's petBuffTypes toggle, and
    requiredLevel is the level a player needs before the food is offered.
]]
-- [itemID] = { buffSpellID, rank, settingKey, requiredLevel }, -- Item Name
ns.PET_BUFF_FOODS = {}

--------------------------------------------------------------------------------
-- Professions
--------------------------------------------------------------------------------

-- The professions whose skill ranks gate which consumables can be used.
ns.FIRST_AID_SKILL_LINE_ID = 129
ns.ALCHEMY_SKILL_LINE_ID = 171
ns.ENGINEERING_SKILL_LINE_ID = 202

-- The Engineering specialization Diagnostics checks the player for.
ns.GOBLIN_ENGINEER_SPELL_ID = 20222
