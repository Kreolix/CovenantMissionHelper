CovenantMissionHelper, CMH = ...

local Board = {Errors = {}, CombatLog = {}, HiddenCombatLog = {}}

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

function Board:new(missionPage)
    local newObj = {units = {}}
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
            if info.autoCombatSpells == nil then info.autoCombatSpells = follower.autoCombatSpells end
            local myUnit = CMH.Unit:new(info)
            --SELECTED_CHAT_FRAME:AddMessage("myUnitName = " .. myUnit.name)
            newObj.units[i] = myUnit
        end
    end

    self.__index = self
    return setmetatable(newObj, self)
end

function Board:fight()
    local round = 1
    while self:isMissionOver() == false and round < 100 do
        local turnOrder = self:getTurnOrder()
        CMH:log("\n |c0000FF33Round " .. round .. "|r")
        CMH:debug_log("turn order -> " .. arrayForPrint(turnOrder))

        self:manageBuffsFromDeadUnits()
        for _, boardIndex in pairs(turnOrder) do
            CMH:debug_log('turn for index ' .. boardIndex)
            self:makeUnitAction(boardIndex)
        end
        round = round + 1
    end

    if not self:isMissionOver() then CMH:log('\n\nMore than 100 rounds. Winner is undefined\n\n') end
end

--- If one team dead, mission over
function Board:isMissionOver()
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

    return order
end

function Board:makeUnitAction(boardIndex)
    local unit = self.units[boardIndex]
    if not unit:isAlive() then return end
    local isMissionOver = self:isMissionOver()
    local targetIndexes, aliveUnits, lastTargetType

    unit:decreaseSpellsCooldown()
    self:manageAppliedBuffs(unit)

    for _, spell in pairs(unit:getAvailableSpells()) do
        if isMissionOver then break end
        CMH:debug_log("Spell: " .. spell.name .. ' (' .. #spell.effects .. ')')
        lastTargetType = -1
        for _, effect in pairs(spell.effects) do
            CMH:debug_log("Effect: " .. effect.Effect .. ', TargetType: ' .. effect.TargetType)
            -- update targets if skill has different effects target type
            if lastTargetType ~= effect.TargetType and effect.TargetType ~= 0 then
                aliveUnits = self:getTargetableUnits()
                CMH:debug_log("aliveUnits -> " .. arrayForPrint(aliveUnits))
                targetIndexes = CMH.TargetManager:getTargetIndexes(boardIndex, effect.TargetType, aliveUnits, unit.tauntedBy)
            end

            CMH:debug_log("targetIndexes -> " .. arrayForPrint(targetIndexes))
            for _, targetIndex in pairs(targetIndexes) do
                unit:castSpellEffect(self.units[targetIndex], effect, spell.duration, spell.name)
            end

            if effect.TargetType ~= 0 then lastTargetType = effect.TargetType end
            isMissionOver = self:isMissionOver()
            if isMissionOver then break end
        end

        unit:startSpellCooldown(spell.ID)
    end
    --self:decreaseAuras()
end

function Board:manageAppliedBuffs(sourceUnit)
    for _, unit in pairs(self.units) do
        if self:isUnitAlive(unit.boardIndex) then unit:manageBuffs(sourceUnit) end
    end
end

function Board:manageBuffsFromDeadUnits()
    for _, unit in pairs(self.units) do
        if not self:isUnitAlive(unit.boardIndex) then self:manageAppliedBuffs(unit) end
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
        end
    end
    if text ~= '' then text = 'Alive my units:\n' .. text end
    return enemy_text  .. text
end

function Board:getResult()
    if not self:isMissionOver() then CMH:log('\n\nMore than 100 rounds. Winner is undefined\n\n') end

    for _, unit in pairs(self.units) do
        if unit:isAlive() then
            if unit.boardIndex <= 4 then
                return '|cFF00FF00Predicted result: WIN|r'
            else
                return '|cFFFF0000Predicted result: LOSE|r'
            end
        end
    end
end

CMH.Board = Board
