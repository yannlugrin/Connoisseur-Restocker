local _, ns = ...

--[[
    Scanner-Character -- reads the character's own facts: profession skills and
    the session constants (race and class, spell-name caches, the conjure-spell
    cache). Which buffs the character still needs is Scanner-Auras.lua's job.
]]

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

ns.currentFirstAidSkill = 0
ns.currentAlchemySkill = 0
ns.currentEngineeringSkill = 0

--------------------------------------------------------------------------------
-- Profession Skills
--------------------------------------------------------------------------------

-- The rank of a skill line, found in the skill list by the name the client
-- gives its ID. 0 when unlearned. A profession's spell can be named differently
-- from its skill line (frFR First Aid: "Premiers soins" vs "Secourisme").
local function GetSkillRank(skillLineID)
	local skillLineName = C_TradeSkillUI.GetTradeSkillDisplayName(skillLineID)
	if not skillLineName or skillLineName == "" then
		return 0
	end

	for i = 1, ns.GetNumSkillLines() do
		local skillName, isHeader, _, skillRank = ns.GetSkillLineInfo(i)
		if not isHeader and skillName == skillLineName then
			return skillRank
		end
	end

	return 0
end

function ns.UpdateFirstAidSkill()
	ns.currentFirstAidSkill = GetSkillRank(ns.FIRST_AID_SKILL_LINE_ID)
end

function ns.UpdateAlchemySkill()
	ns.currentAlchemySkill = GetSkillRank(ns.ALCHEMY_SKILL_LINE_ID)
end

function ns.UpdateEngineeringSkill()
	ns.currentEngineeringSkill = GetSkillRank(ns.ENGINEERING_SKILL_LINE_ID)
end

--------------------------------------------------------------------------------
-- Session Constants
--------------------------------------------------------------------------------

--[[
    One-time, session-constant character setup: race/class detection,
    spell-name caches, the conjure-spell existence cache, and profession skills.
    None of these change during a session, so they resolve once and the event
    handlers (PLAYER_LEVEL_UP, SPELLS_CHANGED, SKILL_LINES_CHANGED) keep the
    level-dependent pieces fresh afterward. Called once at login, after ns.db
    exists.
]]
function ns.InitCharacterConstants()
	local _, raceToken = UnitRace("player")
	ns.isNightElf = (raceToken == "NightElf")

	-- Resolve the Shadowmeld spell name once for macro building
	if ns.isNightElf then
		ns.shadowmeldSpellName = C_Spell.GetSpellName(ns.SHADOWMELD_SPELL_ID)
	end

	--[[
	    Class detection. Used by macro builders to decide which conjure
	    branches the player could *eventually* know — so a low-level mage
	    gets "You don't currently know Conjure Food." while a hunter sees no
	    message at all (they'll never learn that spell).
	]]
	local _, classToken = UnitClass("player")
	ns.isHunter = (classToken == "HUNTER")
	ns.isDruid = (classToken == "DRUID")
	ns.isMage = (classToken == "MAGE")
	ns.isWarlock = (classToken == "WARLOCK")
	ns.isRogue = (classToken == "ROGUE")

	-- Resolve the Stealth spell name once for macro building (Stealth Eating)
	if ns.isRogue then
		ns.stealthSpellName = C_Spell.GetSpellName(ns.STEALTH_SPELL_ID)
	end

	if ns.isHunter then
		ns.ResolveHunterSpells()
		ns.petDeadDismissed = false
	end

	ns.spellCache = {}
	for _, spellList in pairs(ns.CONJURE_SPELLS) do
		for _, data in ipairs(spellList) do
			local spellID = data[1]
			if C_Spell.GetSpellName(spellID) then
				ns.spellCache[spellID] = true
			end
		end
	end

	ns.UpdateFirstAidSkill()
	ns.UpdateAlchemySkill()
	ns.UpdateEngineeringSkill()
end
