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
    --print('hook show mission')
    MissionHelper:clearFrames()
    MissionHelper.missionHelperFrame:Show()
    local board = MissionHelper:simulateFight(false)
    MissionHelper:showResult(board)
    return ...
end

local function setBoard(isCalcRandom)
    local missionPage = CovenantMissionFrame:GetMissionPage()
    --TODO: always show health
    missionPage.Board:ShowHealthValues()
    local board = CMH.Board:new(missionPage, isCalcRandom)
    MissionHelper.missionHelperFrame.board = board
    return board
end

function MissionHelper:simulateFight(isCalcRandom)
    if isCalcRandom == nil then isCalcRandom = true end

    local board = setBoard(isCalcRandom)
    board:simulate()

    board.CombatLog = CMH.Board.CombatLog
    board.HiddenCombatLog = CMH.Board.HiddenCombatLog
    return board

    --[[ TODO: board after fight
        HP after fight = CovenantMissionFrame.MissionComplete.Board.framesByBoardIndex.HealthBar.health
    --]]
end

function MissionHelper:showResult(board)
    local combatLogMessageFrame = MissionHelper.missionHelperFrame.combatLogFrame.CombatLogMessageFrame
    local combat_log = false and CMH.Board.HiddenCombatLog or CMH.Board.CombatLog

    MissionHelper:setResultHeader(board:getResult())
    MissionHelper:setResultInfo(board:getTeams())
    for _, text in ipairs(combat_log) do MissionHelper:AddCombatLogMessage(text) end
    MissionHelper:AddCombatLogMessage(board:getResult())

    if board.hasRandomSpells then
        MissionHelper:showPredictButton()
    else
        MissionHelper:hidePredictButton()
    end

    combatLogMessageFrame.ScrollBar:SetMinMaxValues(0, combatLogMessageFrame:GetNumMessages())
    combatLogMessageFrame:SetScrollOffset(
            math.max(
                    combatLogMessageFrame:GetNumMessages() - math.floor(combatLogMessageFrame:GetNumVisibleLines() / 2),
                    0))
end

function MissionHelper:hookShowRewardScreen(...)
    --print('hook show reward screen')
    local board = MissionHelper.missionHelperFrame.board
    if board.hasRandomSpells then
        return
    end

    board.blizzardLog = _G["CovenantMissionFrame"].MissionComplete.autoCombatResult.combatLog
    board.CombatLogEvents = CMH.Board.CombatLogEvents
    board.compareLogs = MissionHelper:compareLogs(board.CombatLogEvents, board.blizzardLog)
end

function MissionHelper:hookCloseMission(...)
    --print('hook close mission')
    MissionHelper:clearFrames()
    MissionHelper.missionHelperFrame:Hide()
    return ...
end

local function registerHook(...)
    hooksecurefunc(_G["CovenantMissionFrame"], "InitiateMissionCompletion", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "UpdateAllyPower", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"].MissionComplete, "ShowRewardsScreen", MissionHelper.hookShowRewardScreen)
    hooksecurefunc(_G["CovenantMissionFrame"], "CloseMission", MissionHelper.hookCloseMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "CloseMissionComplete", MissionHelper.hookCloseMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "Hide", MissionHelper.hookCloseMission)
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
