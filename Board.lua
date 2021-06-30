local CovenantMissionHelper, CMH = ...
local L = MissionHelper.L

local SIMULATE_ITERATIONS = 100
local MAX_ROUNDS = 100
local MAX_RANDOM_ROUNDS = 50
local LVL_UP_ICON = "|TInterface\\petbattles\\battlebar-abilitybadge-strong-small:0|t"
local SKULL_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t"

local Board = {Errors = {}, CombatLog = {}, HiddenCombatLog = {}, CombatLogEvents = {}}
local TargetTypeEnum, EffectTypeEnum = CMH.DataTables.TargetTypeEnum, CMH.DataTables.EffectTypeEnum

local function arrayForPrint(array)
    if not array then
        for _, text in ipairs(CMH.Board.CombatLog) do print(text) end
        return 'EMPTY ARRAY'
    end
    local result = ''
    for _, e in pairs(array) do
        result = result .. tostring(e) .. ', '
    end
    return result
end

local function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end

local function isAura(effectType)
    return effectType >= EffectTypeEnum.DoT and effectType <= EffectTypeEnum.AdditionalTakenDamage
end

function Board:new(missionPage, isCalcRandom)
    local newObj = {
        units = {},
        hasRandomSpells = false,
        probability = 100,
        isMissionOver = false,
        isEmpty = true,
        initialAlliesHP = 0,
        initialEnemiesHP = 0,
        isCalcRandom = isCalcRandom,
        max_rounds = MAX_ROUNDS,
        baseXP = 0,
        winXP = 0,
        --missionPage = missionPage,
    }
    local isCompletedMission = (missionPage.missionInfo == nil)
    local missionInfo = isCompletedMission and _G["CovenantMissionFrame"].MissionComplete.currentMission or missionPage.missionInfo

    newObj.missionID = missionInfo.missionID
    newObj.baseXP = missionInfo.xp
    newObj.winXP = newObj.baseXP
    for _, reward in pairs (missionInfo.rewards) do
        if reward.followerXP then
            newObj.winXP = newObj.winXP + reward.followerXP
        end
    end

    -- set enemy's units
    local enemies = C_Garrison.GetMissionCompleteEncounters(newObj.missionID)
    for i = 1, #enemies do
        local enemyUnit = CMH.Unit:new(enemies[i])
        --SELECTED_CHAT_FRAME:AddMessage("enemyUnitName = " .. enemyUnit.name)
        newObj.units[enemyUnit.boardIndex] = enemyUnit
        newObj.initialEnemiesHP = newObj.initialEnemiesHP + enemyUnit.currentHealth
    end

    --set my team
    -- If completed mission have < 5 followers, "empty" frames isn't empty actually.
    -- It saved from last completed mission.
    local framesByBoardIndex, boardIndexes = {}, {}
    if isCompletedMission then
        -- completed mission
        for _, follower in pairs(_G["CovenantMissionFrame"].MissionComplete.followerGUIDToInfo) do
            table.insert(boardIndexes, follower.boardIndex)
        end
        framesByBoardIndex = _G["CovenantMissionFrame"].MissionComplete.Board.framesByBoardIndex
    else
        boardIndexes = {0, 1, 2, 3, 4}
        framesByBoardIndex = missionPage.Board.framesByBoardIndex
    end

    for _, boardIndex in pairs(boardIndexes) do
        local follower = framesByBoardIndex[boardIndex]
        local info = follower.info
        if info then
            info.boardIndex = follower.boardIndex
            info.maxHealth = info.autoCombatantStats.maxHealth
            info.health = info.autoCombatantStats.currentHealth
            info.attack = info.autoCombatantStats.attack
            info.isAutoTroop = info.isAutoTroop ~= nil and info.isAutoTroop or (info.quality == 0)
            info.followerGUID = follower:GetFollowerGUID()
            local XPToLvlUp = 0
            if info.isAutoTroop or info.level == 60 then
                info.isLoseLvlUp = false
                info.isWinLvlUp = false
            else
                XPToLvlUp = isCompletedMission and info.maxXP - info.currentXP or info.levelXP - info.xp
                info.isLoseLvlUp = XPToLvlUp <= newObj.baseXP
                info.isWinLvlUp = XPToLvlUp <= newObj.winXP
            end
            if info.autoCombatSpells == nil then info.autoCombatSpells = follower.autoCombatSpells end
            local myUnit = CMH.Unit:new(info)
            --SELECTED_CHAT_FRAME:AddMessage("myUnitName = " .. myUnit.name)
            newObj.units[follower.boardIndex] = myUnit
            newObj.isEmpty = false
            if myUnit.isAutoTroop == false then newObj.initialAlliesHP = newObj.initialAlliesHP + myUnit.currentHealth end
        end
    end

    self.__index = self
    setmetatable(newObj, self)
    newObj:setHasRandomSpells()
    if self.hasRandomSpells then self.max_rounds = MAX_RANDOM_ROUNDS end
    return newObj
end

local boardForSimulate = {}
function Board:simulate()
    if self.isEmpty then return end

    if self.hasRandomSpells and self.isCalcRandom then
        local win_count = 0
        for i = 1, SIMULATE_ITERATIONS do
            boardForSimulate = copy(self)
            boardForSimulate:fight()
            if boardForSimulate:isWin() then win_count = win_count + 1 end
            wipe(CMH.Board.CombatLog)
            wipe(CMH.Board.HiddenCombatLog)
            wipe(CMH.Board.CombatLogEvents)
        end
        self.probability = math.floor(100 * win_count/SIMULATE_ITERATIONS)
    elseif self.hasRandomSpells then
        return
    end

   self:fight()
end

function Board:fight(round)
    round = round or 1
    if round == 1 then self:applyUnitsPassiveSkills() end

    while self.isMissionOver == false and round < self.max_rounds do
        CMH:log('\n')
        CMH:log(GREEN_FONT_COLOR:WrapTextInColorCode(L["Round"] .. ' ' .. round))
        MissionHelper:addRound()
        local turnOrder = self:getTurnOrder()

        local removed_effects = self:manageBuffsFromDeadUnits()
        local enemy_turn = false
        for _, boardIndex in pairs(turnOrder) do
            CMH:debug_log('turn for index ' .. boardIndex)
            if boardIndex > 4 and enemy_turn == false then
                enemy_turn = true
                CMH:log('\n')
            end
            self:makeUnitAction(round, boardIndex)
        end
        -- unit can die by DoT, but I don't check it inside makeUnitAction
        self.isMissionOver = self:checkMissionOver()
        round = round + 1
    end
end

function Board:setHasRandomSpells()
    for _, unit in pairs(self.units) do
        for _, spell in pairs(unit.spells) do
            for _, effect in pairs(spell.effects) do
                if effect.TargetType == TargetTypeEnum.randomEnemy or effect.TargetType == TargetTypeEnum.randomEnemy_2
                    or effect.TargetType == TargetTypeEnum.randomAlly then
                        self.hasRandomSpells = true
                        return
                end
            end
        end
    end

    self.hasRandomSpells = false
end

function Board:applyUnitsPassiveSkills()
    for _, unit in pairs(self.units) do
        if unit.passive_spell ~= nil then
            for _, effect in pairs(unit.passive_spell.effects) do
                local targetIndexes = self:getTargetIndexes(unit, effect.TargetType, -1)
                CMH:debug_log("Effect: " .. effect.Effect .. ', TargetType: ' .. effect.TargetType)
                CMH:debug_log("targetIndexes -> " .. arrayForPrint(targetIndexes))

                local targetInfo = {}
                for _, targetIndex in pairs(targetIndexes) do
                    local eventTargetInfo = unit:castSpellEffect(self.units[targetIndex], effect, unit.passive_spell, false)
                    table.insert(targetInfo, eventTargetInfo)
                end
                MissionHelper:addEvent(unit.passive_spell.ID, isAura(effect.Effect) and EffectTypeEnum.ApplyAura or effect.Effect, unit.boardIndex, targetInfo)
            end
        end
    end
end

--- If one team dead, mission over
function Board:checkMissionOver()
    local isMyTeamAlive = false
    for i = 0, 4 do
        if self:isUnitAlive(i) then
            isMyTeamAlive = true
            break
        end
    end

    local isEnemyTeamAlive = false
    for i = 5, 12 do
        if self:isUnitAlive(i) then
            isEnemyTeamAlive = true
            break
        end
    end

    return not (isMyTeamAlive and isEnemyTeamAlive)
end

function Board:isUnitAlive(boardIndex)
    local unit = self.units[boardIndex]
    if unit then
        return unit:isAlive()
    end
    return false
end

local function isFriendlyUnit(sourceIndex, targetIndex)
    return (sourceIndex <= 4 and targetIndex <= 4) or (sourceIndex > 4 and targetIndex > 4)
end

function Board:isTargetableUnit(sourceIndex, targetIndex)
    return self:isUnitAlive(targetIndex) and (not self.units[targetIndex].untargetable or isFriendlyUnit(sourceIndex, targetIndex))
end

function Board:getTargetableUnits(sourceIndex)
    local result = {}
    for i = 0, 12 do
        table.insert(result, i, self:isTargetableUnit(sourceIndex, i))
    end
    CMH:debug_log("targetableUnits -> " .. arrayForPrint(result))
    return result
end

function Board:getTurnOrder()
    local order = {}
    local sort_table = {}
    for i = 0, 4 do
        if self:isUnitAlive(i) then table.insert(sort_table, self.units[i]) end
    end
    table.sort(sort_table, function (a, b) return (b.currentHealth < a.currentHealth) end)

    for _, unit in pairs(sort_table) do
        table.insert(order, unit.boardIndex)
    end

    sort_table = {}
    for i = 5, 12 do
        if self:isUnitAlive(i) then table.insert(sort_table, self.units[i]) end
    end
    table.sort(sort_table, function (a, b) return (b.currentHealth < a.currentHealth) end)

    for _, unit in pairs(sort_table) do
        table.insert(order, unit.boardIndex)
    end

    CMH:debug_log("turn order -> " .. arrayForPrint(order))
    return order
end

function Board:makeUnitAction(round, boardIndex)
    if self.isMissionOver then return end
    local unit = self.units[boardIndex]
    if not unit:isAlive() then return end

    local targetIndexes, aliveUnits, lastTargetType

    unit:decreaseSpellsCooldown()
    self:manageAppliedBuffs(unit)

    for _, spell in pairs(unit:getAvailableSpells()) do
        if self.isMissionOver then break end
        CMH:debug_log("Spell: " .. spell.name .. ' (' .. #spell.effects .. ')')
        lastTargetType = -1

        for _, effect in pairs(spell.effects) do
            targetIndexes = self:getTargetIndexes(unit, effect.TargetType, lastTargetType, targetIndexes)
            CMH:debug_log("Effect: " .. effect.Effect .. ', TargetType: ' .. effect.TargetType)
            CMH:debug_log("targetIndexes -> " .. arrayForPrint(targetIndexes))

            local targetInfo = {}
            for _, targetIndex in pairs(targetIndexes) do
                local eventTargetInfo = unit:castSpellEffect(self.units[targetIndex], effect, spell, false)
                table.insert(targetInfo, eventTargetInfo)
            end
            MissionHelper:addEvent(spell.ID, isAura(effect.Effect) and EffectTypeEnum.ApplyAura or effect.Effect, boardIndex, targetInfo)

            for _, info in pairs(targetInfo) do
                self:onUnitTakeDamage(spell.ID, boardIndex, info, effect)
            end

            if effect.TargetType ~= TargetTypeEnum.lastTarget then lastTargetType = effect.TargetType end
        end

        unit:startSpellCooldown(spell.ID)
    end
end

function Board:manageAppliedBuffs(sourceUnit)
    local removed_buffs = {}
    for _, unit in pairs(self.units) do
        if unit:isAlive() then
            local unit_removed_buffs = unit:manageBuffs(sourceUnit)
            for _, buff in pairs(unit_removed_buffs) do
                table.insert(removed_buffs, buff)
            end
        end
    end

    return removed_buffs
end

function Board:manageBuffsFromDeadUnits()
    local removed_buffs = {}
    for _, unit in pairs(self.units) do
        if not self:isUnitAlive(unit.boardIndex) then
            local unit_removed_buffs = self:manageAppliedBuffs(unit)
            for _, buff in pairs(unit_removed_buffs) do
                table.insert(removed_buffs, buff)
            end
        end
    end
end

function Board:onUnitTakeDamage(spellID, casterBoardIndex, eventTargetInfo, effect)
    -- check reflect
    if effect.Effect == EffectTypeEnum.Damage or effect.Effect == EffectTypeEnum.Damage_2 then
        --CMH:debug_log(string.format('casterIndex = %s, targetIndex = %s, spellID = %s, effect = %s, targetReflect = %s',
        --        casterBoardIndex, eventTargetInfo.boardIndex, spellID, effect.Effect, self.units[eventTargetInfo.boardIndex].reflect))
        local targetUnit = self.units[eventTargetInfo.boardIndex]
        if targetUnit.reflect > 0 then
            local reflectEventTargetInfo = targetUnit:castSpellEffect(self.units[casterBoardIndex], {Effect = EffectTypeEnum.Reflect, ID = -1}, {}, true)
            MissionHelper:addEvent(spellID, CMH.DataTables.EffectTypeEnum.Reflect, targetUnit.boardIndex, {reflectEventTargetInfo})
            self:onUnitTakeDamage(spellID, targetUnit.boardIndex, reflectEventTargetInfo, {Effect = EffectTypeEnum.Reflect})
        end
    end

    -- unit died
    if eventTargetInfo.newHealth == 0 then
        MissionHelper:addEvent(spellID, CMH.DataTables.EffectTypeEnum.Died, casterBoardIndex, {eventTargetInfo})
        CMH:log(ORANGE_FONT_COLOR:WrapTextInColorCode(string.format('%s %s %s ',
                self.units[casterBoardIndex].name, L['kill'], self.units[eventTargetInfo.boardIndex].name)))
        self.isMissionOver = self:checkMissionOver()
    end
end

function Board:getTotalLostHP(isWin)
    local restHP = 0
    local _start, _end, startHP = 0, 4, self.initialAlliesHP
    if not isWin then _start, _end, startHP = 5, 12, self.initialEnemiesHP end
    for i = _start, _end do
        if self.units[i] and (self.units[i].isAutoTroop == false or not isWin) then
            if self.units[i].isWinLvlUp then
                restHP = restHP + self.units[i].maxHealth
            elseif self:isUnitAlive(i) then
                restHP = restHP + self.units[i].currentHealth
            end
        end
    end

    return startHP - restHP
end

local function constructString(unit, isWin)
        local result = unit.name .. L['.'] .. ' ' .. L['HP'] .. ' = ' .. unit.currentHealth .. '/' .. unit.maxHealth .. '\n'
        --result = unit.isWinLvlUp and result .. ' (Level Up)\n' or result .. '\n'
        if (isWin and unit.isWinLvlUp) or (not isWin and unit.isLoseLvlUp) then result = LVL_UP_ICON .. result end
        if unit.currentHealth == 0 then result = SKULL_ICON .. result end
        return '    ' .. result
    end

function Board:getResultInfo()
    if self.isEmpty then return '' end

    if self.hasRandomSpells and self.isCalcRandom == false then
        return L["Units have random abilities. The mission isn't simulate automatically.\nClick on the button to check the result."]
    end

    local isWin = self:isWin()
    local lostHP = self:getTotalLostHP(true)
    local loseOrGain = lostHP >= 0 and L['LOST'] or L['RECEIVED']
    local warningText = self.hasRandomSpells and RED_FONT_COLOR:WrapTextInColorCode(
            L["Units have random abilities. Actual rest HP may not be the same as predicted"]) or ''

    local text = ''
    for i = 0, 4 do
        if self.units[i] then
            text = text .. constructString(self.units[i], isWin)
        end
    end
    text = string.format("%s\n%s:\n%s \n\n%s %s %s = %s",
            warningText, L['My units'], text, L['TOTAL'], loseOrGain, L['HP'], math.abs(lostHP))

    if isWin == false then
        local enemyInfo = ''
        for i = 5, 12 do
            if self.units[i] then enemyInfo = enemyInfo .. constructString(self.units[i], isWin) end
        end
        local remainingHP = self.initialEnemiesHP - self:getTotalLostHP(false)
        enemyInfo = string.format('%s:\n%s', L['Enemy units'], enemyInfo)
        local total = RED_FONT_COLOR:WrapTextInColorCode(
                string.format('%s = %s/%s (%s%%)',
                        L['TOTAL REMAINING HP'], remainingHP, self.initialEnemiesHP, math.floor(100*remainingHP/self.initialEnemiesHP))
        )
        text = text .. '\n\n\n\n' ..enemyInfo .. '\n\n' .. total
    end

    return text
end

function Board:constructResultString()
    if self.isEmpty then
        return L['Add units on board']
    elseif self.hasRandomSpells and self.isCalcRandom == false then
        return ''
    elseif not self.isMissionOver then
        return RED_FONT_COLOR:WrapTextInColorCode(string.format(L['More than %s rounds. Winner is undefined'], self.max_rounds))
    end

    local result = self:isWin()
    if self.probability == 100 and result then
        return GREEN_FONT_COLOR:WrapTextInColorCode(L['WIN'])
    elseif self.probability == 0 or (result == false and self.probability == 100) then
        return RED_FONT_COLOR:WrapTextInColorCode(L['LOSE'])
    else
        return ORANGE_FONT_COLOR:WrapTextInColorCode(string.format(L['WIN'] .. ' (~%s%%)', self.probability))
    end
end

function Board:isWin()
    for _, unit in pairs(self.units) do
        if unit:isAlive() then
            if unit.boardIndex > 4 then return false else return true
            end
        end
    end
end

function Board:getTargetIndexes(unit, targetType, lastTargetType, lastTargetIndexes)
    -- update targets if skill has different effects target type
    if lastTargetType ~= targetType and targetType ~= TargetTypeEnum.lastTarget then
        local aliveUnits = self:getTargetableUnits(unit.boardIndex)
        return CMH.TargetManager:getTargetIndexes(unit.boardIndex, targetType, aliveUnits, unit.tauntedBy)
    else
        return lastTargetIndexes
    end
end

CMH.Board = Board
