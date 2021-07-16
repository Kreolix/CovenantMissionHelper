CovenantMissionHelper, CMH = ...

local MetaBoard = {}
CMH.MetaBoard = MetaBoard

local function copy(obj, seen)
    if type(obj) ~= 'table' then
        return obj
    end
    if seen and seen[obj] then
        return seen[obj]
    end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do
        res[copy(k, s)] = copy(v, s)
    end
    return res
end

function MetaBoard:new(missionPage, isCalcRandom)
    local newObj = {
        baseBoard = CMH.Board:new(missionPage, isCalcRandom)
    }
    self.__index = self
    setmetatable(newObj, self)

    return newObj
end

function MetaBoard:findBestDisposition()
    self.baseBoard.isCalcRandom = false;
    self.baseBoard.isEmpty = false;

    local bestBoard = copy(self.baseBoard)
    local bestLostHP = 9999999

    for _, board in ipairs(self:getAllBoardCombinations()) do
        board:simulate()
        local isWin = board:isWin()
        local lostHP = board:getTotalLostHP(isWin)
        if isWin then
            if lostHP < bestLostHP then
                bestLostHP = lostHP
                bestBoard = board
            end
        end

        wipe(CMH.Board.CombatLog)
        wipe(CMH.Board.HiddenCombatLog)
        wipe(CMH.Board.CombatLogEvents)
    end
    return bestBoard
end

function MetaBoard:getAllBoardCombinations()
    local followers = {};
    for i = 0, 4 do
        local unit = self.baseBoard.units[i];
        if unit ~= nil and unit.isAutoTroop == false then
            followers[unit.ID] = unit;
        end
    end
    local troopCombinations = CMH.CombinationUtil:getTroopCombinations(followers);
    local boards = {};

    for _, troopCombination in pairs(troopCombinations) do
        local newBoard = copy(self.baseBoard)

        for index, troopId in pairs(troopCombination) do
            if troopId == -1 then
                newBoard.units[index - 1] = nil;
            else
                if troopId == 1 or troopId == 2 then
                    local unit = C_Garrison.GetAutoTroops(123)[troopId]

                    local autoCombatSpells, autoCombatAutoAttack = C_Garrison.GetFollowerAutoCombatSpells(unit.followerID, unit.level)
                    local autoCombatStats = C_Garrison.GetFollowerAutoCombatStats(unit.followerID, unit.level)

                    unit.boardIndex = index - 1
                    unit.followerGUID = unit.followerID
                    unit.autoCombatSpells = autoCombatSpells
                    unit.health = autoCombatStats.maxHealth
                    unit.maxHealth = autoCombatStats.maxHealth
                    unit.attack = autoCombatStats.attack
                    newBoard.units[index - 1] = CMH.Unit:new(unit);
                else
                    local unit = followers[troopId]
                    local autoCombatSpells, autoCombatAutoAttack = C_Garrison.GetFollowerAutoCombatSpells(unit.ID, unit.level)

                    unit.boardIndex = index - 1
                    unit.autoCombatSpells = autoCombatSpells
                    unit.health = unit.currentHealth
                    newBoard.units[index - 1] = CMH.Unit:new(unit);
                end
            end
        end
        table.insert(boards, newBoard)
    end
    return boards
end