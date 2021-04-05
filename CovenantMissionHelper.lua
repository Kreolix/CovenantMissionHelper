local CovenantMissionHelper, CMH = ...
local hooksecurefunc = _G["hooksecurefunc"]
local MissionHelper = MissionHelper
local L = MissionHelper.L

local function registerHook()
    -- open/close mission
    hooksecurefunc(_G["CovenantMissionFrame"], "InitiateMissionCompletion", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "UpdateAllyPower", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"].MissionComplete, "ShowRewardsScreen", MissionHelper.hookShowRewardScreen)
    hooksecurefunc(_G["CovenantMissionFrame"], "CloseMission", MissionHelper.hookCloseMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "CloseMissionComplete", MissionHelper.hookCloseMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "Hide", MissionHelper.hookCloseMission)

    -- mission's rewards
    hooksecurefunc("GarrisonMissionButton_SetRewards", MissionHelper.addBaseXPToRewards)
    hooksecurefunc(_G["C_Garrison"], "GetInProgressMissions", MissionHelper.addXPPerHour)
    hooksecurefunc(_G["C_Garrison"], "GetAvailableMissions", MissionHelper.addXPPerHour)

    -- always show HP
    hooksecurefunc(_G["CovenantMissionFrame"].MissionTab.MissionPage.Board, "HideHealthValues", MissionHelper.ShowHealthValues)
    hooksecurefunc(_G["CovenantMissionFrame"].MissionComplete.Board, "HideHealthValues", MissionHelper.ShowHealthValues)
end

function MissionHelper:ADDON_LOADED(event, addon)
    if addon == "Blizzard_GarrisonUI" then
        if self.isLoaded then return end
        registerHook()
        MissionHelper:editDefaultFrame()
        MissionHelper:createMissionHelperFrame()
        self.isLoaded = true
    end
end

function MissionHelper:hookShowMission(...)
    local missionPage = CovenantMissionFrame:GetMissionPage()
    local missionInfo = missionPage.missionInfo
    MissionHelperFrame:clearFrames()
    MissionHelperFrame:updateMissionHeader(missionInfo and missionInfo or _G["CovenantMissionFrame"].MissionComplete.currentMission)
    MissionHelperFrame:Show()

    local isCompletedMission = missionInfo == nil
    local board = MissionHelper:simulateFight(isCompletedMission)
    if isCompletedMission then _G["CovenantMissionFrame"].MissionComplete.Board:ShowHealthValues() else missionPage.Board:ShowHealthValues() end
    MissionHelper:showResult(board)
    return ...
end

local function setBoard(isCalcRandom)
    local missionPage = CovenantMissionFrame:GetMissionPage()
    local board = CMH.Board:new(missionPage, isCalcRandom)
    MissionHelperFrame.board = board
    return board
end

function MissionHelper:simulateFight(isCalcRandom)
    MissionHelperFrame:clearFrames()
    if isCalcRandom == nil then isCalcRandom = true end

    local board = setBoard(isCalcRandom)
    board:simulate()

    board.CombatLog = CMH.Board.CombatLog
    board.HiddenCombatLog = CMH.Board.HiddenCombatLog
    board.CombatLogEvents = CMH.Board.CombatLogEvents
    return board

    --[[ TODO: board after fight
        HP after fight = CovenantMissionFrame.MissionComplete.Board.framesByBoardIndex.HealthBar.health
    --]]
end

function MissionHelper:findBestDisposition()
    local missionPage = CovenantMissionFrame:GetMissionPage()
    local metaBoard = CMH.MetaBoard:new(missionPage, false)

    MissionHelper:clearBoard(missionPage)
    MissionHelperFrame.board = metaBoard:findBestDisposition()

    for _, unit in pairs(MissionHelperFrame.board.units) do
        if unit.boardIndex < 5 then
            local followerInfo = C_Garrison.GetFollowerInfo(unit.followerGUID)
            followerInfo.autoCombatSpells = C_Garrison.GetFollowerAutoCombatSpells(unit.followerGUID, followerInfo.level);
            CovenantMissionFrame:AssignFollowerToMission(missionPage.Board:GetFrameByBoardIndex(unit.boardIndex), followerInfo)
        end
    end
end

function MissionHelper:showResult(board)
    --print('hook show result')
    local combatLogMessageFrame = MissionHelperFrame.combatLogFrame.CombatLogMessageFrame
    local combat_log = false and CMH.Board.HiddenCombatLog or CMH.Board.CombatLog

    MissionHelperFrame:setResultHeader(board:constructResultString())
    MissionHelperFrame:setResultInfo(board:getResultInfo())
    for _, text in ipairs(combat_log) do MissionHelperFrame:AddCombatLogMessage(text) end
    MissionHelperFrame:AddCombatLogMessage(board:constructResultString())

    if CovenantMissionFrame:GetMissionPage().missionInfo ~= nil then -- open mission, not completed
        MissionHelperFrame:showButtonsFrame()
        if board.hasRandomSpells then
            MissionHelperFrame:disableBestDispositionButton()
            MissionHelperFrame:enablePredictButton()
        else
            MissionHelperFrame:enableBestDispositionButton()
            MissionHelperFrame:disablePredictButton()
        end
    else
        MissionHelperFrame:hideButtonsFrame()
    end

    combatLogMessageFrame.ScrollBar:SetMinMaxValues(0, combatLogMessageFrame:GetNumMessages())
    combatLogMessageFrame:SetScrollOffset(
            math.max(
                    combatLogMessageFrame:GetNumMessages() - math.floor(combatLogMessageFrame:GetNumVisibleLines() / 2),
                    0))
end

function MissionHelper:hookShowRewardScreen(...)
    --print('hook show reward screen')
    local board = MissionHelperFrame.board
    --if board.hasRandomSpells then
    --    return
    --end

    board.blizzardLog = _G["CovenantMissionFrame"].MissionComplete.autoCombatResult.combatLog
    -- TODO: fix it
    -- my events log cleared somewhere. run it another time to compare blizz and my log
    --board:simulate()
    --board.CombatLogEvents = CMH.Board.CombatLogEvents
    --board.compareLogs = MissionHelper:compareLogs(board.CombatLogEvents, board.blizzardLog)
end

function MissionHelper:clearBoard(missionPage)
    for followerFrame in missionPage.Board:EnumerateFollowers() do
		local followerGUID = followerFrame:GetFollowerGUID();
		if followerGUID then
			C_Garrison.RemoveFollowerFromMission(missionPage.missionInfo.missionID, followerGUID, followerFrame.boardIndex)
            followerFrame:SetEmpty()
		end
	end
end

function MissionHelper:hookCloseMission(...)
    --print('hook close mission')
    MissionHelperFrame:clearFrames()
    MissionHelperFrame:Hide()
    collectgarbage("collect")
    return ...
end

function MissionHelper:addBaseXPToRewards(rewards)
    if self.info == nil then return end

    local baseXPReward = {
        icon = 894556,
        followerXP = self.info.xp,
        title = L['Base XP'],
        tooltip = '+' .. self.info.xp .. ' ' .. L['XP'] ..
                '\n+' .. string.format("%3d", self.info.xp / (self.info.durationSeconds / 3600)) .. L['XP/hour'],
    }

    local Reward = self.Rewards[#rewards + 1]
    if not Reward then
        Reward = CreateFrame("Frame", nil, self, "GarrisonMissionListButtonRewardTemplate")
        Reward:SetPoint("RIGHT", self.Rewards[#rewards], "LEFT", 0, 0)
        self.Rewards[#rewards + 1] = Reward
    end

    GarrisonMissionButton_SetReward(Reward, baseXPReward, {})
    Reward:Show()
end

function MissionHelper:addXPPerHour(followerTypeID)
    if type(self) ~= 'table' then return end

    for _, mission in pairs(self) do
        if mission.rewards[1].followerXP then
            mission.rewards[1].tooltip = mission.rewards[1].tooltip ..
                    '\n+' .. string.format("%3d", mission.rewards[1].followerXP / (mission.durationSeconds / 3600)) .. L['XP/hour']
        end
    end
end

function MissionHelper:ShowHealthValues()
    self:ShowHealthValues()
end

MissionHelper:RegisterEvent("ADDON_LOADED")
MissionHelper:SetScript("OnEvent", MissionHelper.ADDON_LOADED)

function CMH:log(msg)
    table.insert(CMH.Board.CombatLog, msg)
    if CMH.isDebug then
        table.insert(CMH.Board.HiddenCombatLog, msg)
    end
end

function CMH:debug_log(msg)
    if CMH.isDebug then
        table.insert(CMH.Board.HiddenCombatLog, msg)
    end
end
