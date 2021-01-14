CovenantMissionHelper, CMH = ...

local SIMULATE_ITERATIONS = 20

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

local function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end

function Board:new(missionPage)
    local newObj = {
        units = {},
        hasRandomSpells = false,
        combatLogEvents = {},
        probability = 100,
        isMissionOver = false,
        isEmpty = true,
        initialAlliesHP = 0
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
            if info.autoCombatSpells == nil then info.autoCombatSpells = follower.autoCombatSpells end
            local myUnit = CMH.Unit:new(info)
            --SELECTED_CHAT_FRAME:AddMessage("myUnitName = " .. myUnit.name)
            newObj.units[i] = myUnit
            newObj.isEmpty = false
            if myUnit.isAutoTroop == false then newObj.initialAlliesHP = newObj.initialAlliesHP + info.health end
        end
    end

    self.__index = self
    setmetatable(newObj, self)
    newObj:setHasRandomSpells()
    return newObj
end

function Board:simulate()
    if self.isEmpty then return end

    if self.hasRandomSpells then
        local new_board = {}
        local win_count = 0
        for i = 1, SIMULATE_ITERATIONS do
            new_board = copy(self)
            new_board:fight()
            win_count = win_count + new_board:getResultInt()
            CMH.Board.CombatLog = {}
            CMH.Board.HiddenCombatLog = {}
        end
        self.probability = math.floor(100 * win_count/SIMULATE_ITERATIONS)
    end

   self:fight()
end

function Board:fight()
    local round = 1
    while self.isMissionOver == false and round < 100 do
        CMH:log("\n |c0000FF33Round " .. round .. "|r")
        self:addRound()
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

    if not self.isMissionOver then CMH:log('\n\nMore than 100 rounds. Winner is undefined\n\n') end
end

function Board:setHasRandomSpells()
    for _, unit in pairs(self.units) do
        for _, spell in pairs(unit.spells) do
            for _, effect in pairs(spell.effects) do
                if effect.TargetType == 19 or effect.TargetType == 20 or effect.TargetType == 21 then
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

    for i = 5, 12 do
        if self:isUnitAlive(i) then table.insert(order, self.units[i].boardIndex) end
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
                local eventTargetInfo = unit:castSpellEffect(self.units[targetIndex], effect, spell.duration, spell.name)
                table.insert(targetInfo, eventTargetInfo)
            end
            self:addEvent(round, spell.ID, effect.Effect, boardIndex, targetInfo)
            for _, info in pairs(targetInfo) do
                if info.newHealth == 0 then
                    self:addEvent(round, spell.ID, CMH.DataTables.EffectTypeEnum.Died, boardIndex, targetInfo)
                    self.isMissionOver = self:checkMissionOver()
                end
            end

            if effect.TargetType ~= 0 then lastTargetType = effect.TargetType end
        end

        unit:startSpellCooldown(spell.ID)
    end
end

function Board:manageAppliedBuffs(sourceUnit)
    local removed_buffs = {}
    for _, unit in pairs(self.units) do
        local unit_removed_buffs = unit:manageBuffs(sourceUnit)
        for _, buff in pairs(unit_removed_buffs) do
            table.insert(removed_buffs, buff)
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
        text = string.format("Alive my units:\n%s \n\nTOTAL FOLLOWER'S REST HP = %s (%s)", text, totalHP, totalHP - self.initialAlliesHP)
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
    elseif not self.isMissionOver then
        return '|cFFFF0000More than 100 rounds. Winner is undefined|r'
    end

    local result = self:getResultInt()
    local color = ''
    if self.probability == 100 and result == 1 then
        color = 'FF00FF00'
    elseif self.probability == 0 or result == 0 then
        color = 'FFFF0000'
    else
        color = 'FFFF7700'
    end

    local str_format = '|c%sPredicted result: %s (%s%%)|r'
    --str_format = '%s %s %s'
    if self.probability > 0 and self.probability < 100 and result == 1 then
        return str_format:format(color, 'WIN', '< ' .. tostring(self.probability))
    elseif self.probability == 100 and result == 1 then
        return str_format:format(color, 'WIN', tostring(self.probability))
    else
        return str_format:format(color, 'LOSE', '100')
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

function Board:addRound()
    table.insert(self.combatLogEvents, {events = {}})
end

function Board:addEvent(round, spellID, effectType, casterBoardIndex, targetInfo)
    table.insert(self.combatLogEvents[round].events, {
                casterBoardIndex = casterBoardIndex,
                spellID = spellID,
                type = self:getBlizzardEventType(effectType, spellID),
                targetInfo = targetInfo
            })
end

function Board:getBlizzardEventType(effectType, spellID)
    if spellID == 11 then
        return Enum.GarrAutoMissionEventType.MeleeDamage
    elseif spellID == 15 then
        return Enum.GarrAutoMissionEventType.RangeDamage
    elseif effectType == CMH.DataTables.EffectTypeEnum.Damage or effectType == CMH.DataTables.EffectTypeEnum.Damage_2 then
        return Enum.GarrAutoMissionEventType.SpellMeleeDamage -- or Enum.GarrAutoMissionEventType.SpellRangeDamage?
    elseif effectType == CMH.DataTables.EffectTypeEnum.DoT then
        return Enum.GarrAutoMissionEventType.PeriodicDamage
    elseif effectType == CMH.DataTables.EffectTypeEnum.Heal or effectType == CMH.DataTables.EffectTypeEnum.Heal_2 then
        return Enum.GarrAutoMissionEventType.Heal
    elseif effectType == CMH.DataTables.EffectTypeEnum.HoT then
        return Enum.GarrAutoMissionEventType.PeriodicHeal
    elseif effectType == CMH.DataTables.EffectTypeEnum.Died then
        return Enum.GarrAutoMissionEventType.Died
    elseif effectTpye == CMH.DataTables.EffectTypeEnum.RemoveAura then
        return Enum.GarrAutoMissionEventType.RemoveAura
    else
        return Enum.GarrAutoMissionEventType.ApplyAura
    end
end

function Board:getTargetIndexes(unit, targetType, lastTargetType, lastTargetIndexes)
    -- update targets if skill has different effects target type
    if lastTargetType ~= targetType and targetType ~= 0 then
        local aliveUnits = self:getTargetableUnits()
        return CMH.TargetManager:getTargetIndexes(unit.boardIndex, targetType, aliveUnits, unit.tauntedBy)
    else
        return lastTargetIndexes
    end
end

CMH.Board = Board
