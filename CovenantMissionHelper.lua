CovenantMissionHelper, CMH = ...
local hooksecurefunc = _G["hooksecurefunc"]

MissionHelper = CreateFrame("Frame", "MissionHelper", UIParent)
MissionHelper.isLoaded = false

function MissionHelper:ADDON_LOADED(event, addon)
    if addon == "Blizzard_GarrisonUI" then
        if self.isLoaded then return end
        hooksecurefunc(_G["CovenantMissionFrame"], "SetupTabs", self.hookSetupTabs)
        self.isLoaded = true
    end
end

function MissionHelper:hookShowMission(...)
    MissionHelper:clearFrames()
    MissionHelper.missionHelperFrame:Show()

    local missionPage = CovenantMissionFrame:GetMissionPage()
    missionPage.Board:ShowHealthValues()

    local board = CMH.Board:new(missionPage)
    board:simulate()

    local combatLogMessageFrame = MissionHelper.missionHelperFrame.combatLogFrame.CombatLogMessageFrame
    local combat_log = false and CMH.Board.HiddenCombatLog or CMH.Board.CombatLog
    MissionHelper:setResultHeader(board:getResult())
    MissionHelper:setResultInfo(board:getTeams())
    for _, text in ipairs(combat_log) do MissionHelper:AddCombatLogMessage(text) end
    MissionHelper:AddCombatLogMessage(board:getResult())

    combatLogMessageFrame.ScrollBar:SetMinMaxValues(0, combatLogMessageFrame:GetNumMessages())
    combatLogMessageFrame:SetScrollOffset(
            math.max(
                    combatLogMessageFrame:GetNumMessages() - math.floor(combatLogMessageFrame:GetNumVisibleLines() / 2),
                    0))

    MissionHelper.missionHelperFrame.board = board
    board.CombatLog = CMH.Board.CombatLog
    board.HiddenCombatLog = CMH.Board.HiddenCombatLog

    --[[ TODO: board after fight
        HP after fight = CovenantMissionFrame.MissionComplete.Board.framesByBoardIndex.HealthBar.health
        blizzard combat log = CovenantMissionFrame.MissionComplete.AdventuresCombatLog.CombatLogMessageFrame.historyBuffer.elements[].message
    --]]

    return ...
end

function MissionHelper:hookShowRewardScreen(...)
    local board = MissionHelper.missionHelperFrame.board
    if board.hasRandomSpells then
        print(tostring(board.hasRandomSpells))
        return
    end

    board.blizzardLog = _G["CovenantMissionFrame"].MissionComplete.autoCombatResult.combatLog
    print(tostring(board.blizzardLog))
    board.compareLogs = MissionHelper:compareLogs(board.combatLogEvents, board.blizzardLog)


end

function MissionHelper:hookCloseMission(...)
    MissionHelper:clearFrames()
    MissionHelper.missionHelperFrame:Hide()
    return ...
end

local function registerHook(...)
    hooksecurefunc(_G["CovenantMissionFrame"], "InitiateMissionCompletion", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "ShowMission", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "UpdateAllyPower", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "UpdateEnemyPower", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"].MissionComplete, "ShowRewardsScreen", MissionHelper.hookShowRewardScreen)
    hooksecurefunc(_G["CovenantMissionFrame"], "CloseMission", MissionHelper.hookCloseMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "CloseMissionComplete", MissionHelper.hookCloseMission)
end

function MissionHelper:hookSetupTabs(...)
    registerHook(...)
    MissionHelper:editDefaultFrame(...)
    MissionHelper:createMissionHelperFrame(...)

    return ...
end

function MissionHelper:updateText(frame, newText)
    frame:AddMessage(newText)
end

MissionHelper:RegisterEvent("ADDON_LOADED")
MissionHelper:SetScript("OnEvent", MissionHelper.ADDON_LOADED)

function CMH:log(msg)
    table.insert(CMH.Board.CombatLog, msg)
    table.insert(CMH.Board.HiddenCombatLog, msg)
end

function CMH:debug_log(msg)
    table.insert(CMH.Board.HiddenCombatLog, msg)
end
