CovenantMissionHelper, CMH = ...

local SIMULATE_ITERATIONS = 100
local MAX_ROUNDS = 100
local MAX_RANDOM_ROUNDS = 50

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
        isCalcRandom = isCalcRandom,
        max_rounds = MAX_ROUNDS
    }
    if missionPage.missionInfo == nil then
        -- completed mission
        newObj.missionID = _G["CovenantMissionFrame"].MissionComplete.currentMission.missionID
    else
        newObj.missionID = missionPage.missionInfo.missionID
    end

    -- set enemy's units
    local enemies = C_Garrison.GetMissionCompleteEncounters(newObj.missionID)
    for i = 1, #enemies do
        local enemyUnit = CMH.Unit:new(enemies[i])
        --SELECTED_CHAT_FRAME:AddMessage("enemyUnitName = " .. enemyUnit.name)
        newObj.units[enemyUnit.boardIndex] = enemyUnit
    end

    --set my team
    local myTeam
    if missionPage.missionInfo == nil then
        -- completed mission
        myTeam = _G["CovenantMissionFrame"].MissionComplete.Board.framesByBoardIndex

    else
        myTeam = missionPage.Board.framesByBoardIndex
    end

    for i, follower in pairs(myTeam) do
        local info = follower.info
        if info and follower.boardIndex <= 4 then
            info.boardIndex = i
            info.maxHealth = info.autoCombatantStats.maxHealth
            info.health = info.autoCombatantStats.currentHealth
            info.attack = info.autoCombatantStats.attack
            info.isAutoTroop = info.isAutoTroop ~= nil and info.isAutoTroop or (info.quality == 0)
            if info.autoCombatSpells == nil then info.autoCombatSpells = follower.autoCombatSpells end
            local myUnit = CMH.Unit:new(info)
            --SELECTED_CHAT_FRAME:AddMessage("myUnitName = " .. myUnit.name)
            newObj.units[i] = myUnit
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

function Board:simulate()
    if self.isEmpty then return end

    if self.hasRandomSpells and self.isCalcRandom then
        local new_board = {}
        local win_count = 0
        for i = 1, SIMULATE_ITERATIONS do
            new_board = copy(self)
            new_board:fight()
            win_count = win_count + new_board:getResultInt()
            CMH.Board.CombatLog = {}
            CMH.Board.HiddenCombatLog = {}
            CMH.Board.CombatLogEvents = {}
        end
        self.probability = math.floor(100 * win_count/SIMULATE_ITERATIONS)
    elseif self.hasRandomSpells then
        return
    end

   self:fight()
end

function Board:fight()
    local round = 1
    while self.isMissionOver == false and round < self.max_rounds do
        CMH:log('\n')
        CMH:log("|c0000FF33Round " .. round .. "|r")
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

function Board:isTargetableUnit(boardIndex)
    return self:isUnitAlive(boardIndex) and not self.units[boardIndex].untargetable
end

function Board:getTargetableUnits()
    local result = {}
    for i = 0, 12 do
        table.insert(result, i, self:isTargetableUnit(i) and true or false)
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
    table.sort(sort_table, function (a, b) return (a.currentHealth > b.currentHealth) end)

    for _, unit in pairs(sort_table) do
        table.insert(order, unit.boardIndex)
    end

    sort_table = {}
    for i = 5, 12 do
        if self:isUnitAlive(i) then table.insert(sort_table, self.units[i]) end
    end
    table.sort(sort_table, function (a, b) return (a.currentHealth > b.currentHealth) end)

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
                if info.newHealth == 0 then
                    MissionHelper:addEvent(spell.ID, CMH.DataTables.EffectTypeEnum.Died, boardIndex, targetInfo)
                    CMH:log(string.format('|cFFFF7700 %s kill %s |r', unit.name, self.units[info.boardIndex].name))
                    self.isMissionOver = self:checkMissionOver()
                end
            end

            if effect.TargetType ~= TargetTypeEnum.lastTarget then lastTargetType = effect.TargetType end
        end

        unit:startSpellCooldown(spell.ID)

        -- auto attack always has 1 effect and 1 target, so i can check it after cycle
        if #targetIndexes > 0 and spell:isAutoAttack() then
            local targetUnit = self.units[targetIndexes[1]]
            -- dead unit can reflect ...
            if targetUnit.reflect > 0 then
                local eventTargetInfo = targetUnit:castSpellEffect(unit, {Effect = CMH.DataTables.EffectTypeEnum.Reflect, ID = -1}, {}, true)
                MissionHelper:addEvent(spell.ID, CMH.DataTables.EffectTypeEnum.Reflect, targetUnit.boardIndex, {eventTargetInfo})
                if eventTargetInfo.newHealth == 0 then
                    MissionHelper:addEvent(spell.ID, CMH.DataTables.EffectTypeEnum.Died, boardIndex, {eventTargetInfo})
                    CMH:log(string.format('|cFFFF7700 %s kill %s |r', unit.name, self.units[eventTargetInfo.boardIndex].name))
                    self.isMissionOver = self:checkMissionOver()
                end
            end
        end
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

function Board:getTeams()
    local function constructString(unit)
        local spells = ''
        for _, spell in ipairs(unit.spells) do
            -- without auto attack
            if spell.ID ~= 11 and spell.ID ~= 15 then
                spells = spells .. spell.name .. '(ID = ' .. spell.ID .. ', cd=' .. spell.cooldown .. ', duration=' .. spell.duration .. '),'
            end
        end
        local result = '    ' .. unit.boardIndex .. '. ' .. unit.name .. '. HP = ' .. unit.currentHealth .. '/' .. unit.maxHealth .. '\n'
        return result
    end

    if self.hasRandomSpells and self.isCalcRandom == false then
        return "Units have random abilities. The mission isn't simulate automatically.\nClick on the button to check the result."
    end

    local totalHP = 0
    local enemy_text = ''
    for i = 5, 12 do
        if self:isUnitAlive(i) then
            enemy_text = enemy_text .. constructString(self.units[i])
        end
    end
    if enemy_text ~= '' then enemy_text = 'Alive enemy units:\n' .. enemy_text end

    local text = ''
    for i = 0, 4 do
        if self:isUnitAlive(i) then
            text = text .. constructString(self.units[i])
            if self.units[i].isAutoTroop == false then totalHP = totalHP + self.units[i].currentHealth end
        end
    end
    if text ~= '' then
        local loseOrGain = (totalHP <= self.initialAlliesHP) and 'LOST' or 'RECEIVED'
        text = string.format("Alive my units:\n%s \n\nTOTAL %s HP = %s", text, loseOrGain, self.initialAlliesHP - totalHP)
    end
    local warningText = ''
    if self.hasRandomSpells then
        warningText = "|cFFFF0000Units have random abilities. Actual rest HP may not be the same as predicted|r\n"
    end
    return warningText .. enemy_text  .. text
end

function Board:getResult()
    if self.isEmpty then
        return 'Add units on board'
    elseif self.hasRandomSpells and self.isCalcRandom == false then
        return ''
    elseif not self.isMissionOver then
        return string.format('|cFFFF0000More than %s rounds. Winner is undefined|r', self.max_rounds)
    end

    local result = self:getResultInt()
    if self.probability == 100 and result == 1 then
        return '|cFF00FF00 Predicted result: WIN |r'
    elseif self.probability == 0 or (result == 0 and self.probability == 100) then
        return '|cFFFF0000 Predicted result: LOSE |r'
    else
        return string.format('FFFF7700 Predicted result: WIN (%s%%)', self.probability)
    end
end

function Board:getResultInt()
    -- 1 - win, 0 - lose
    for _, unit in pairs(self.units) do
        if unit:isAlive() then
            if unit.boardIndex > 4 then return 0 else return 1
            end
        end
    end
end

function Board:getTargetIndexes(unit, targetType, lastTargetType, lastTargetIndexes)
    -- update targets if skill has different effects target type
    if lastTargetType ~= targetType and targetType ~= TargetTypeEnum.lastTarget then
        local aliveUnits = self:getTargetableUnits()
        return CMH.TargetManager:getTargetIndexes(unit.boardIndex, targetType, aliveUnits, unit.tauntedBy)
    else
        return lastTargetIndexes
    end
end

CMH.Board = Board
