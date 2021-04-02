local CovenantMissionHelper, CMH = ...
local MissionHelperFrame = _G["MissionHelperFrame"]
local L = MissionHelper.L

function MissionHelperFrame:updateMissionHeader(missionInfo)
    if self.board and self.board.missionID == missionInfo.missionID then return end

    self.missionHeader.info = missionInfo -- for compatibility
    GarrisonMissionButton_SetRewards(self.missionHeader, missionInfo.rewards)

    for _, reward in pairs(self.missionHeader.Rewards) do
        reward:SetSize(58, 58)
    end

    self.missionHeader.Level:SetText(missionInfo.missionScalar)
    self.missionHeader.Duration:SetText(L['Duration'] .. ': ' ..tostring(missionInfo.duration))
    if missionInfo.offerTimeRemaining and not missionInfo.canBeCompleted then
        self.missionHeader.OfferTime:SetText(L['Offer time'] .. ': ' .. tostring(missionInfo.offerTimeRemaining))
    end
end

function MissionHelperFrame:clearFrames()
    self.combatLogFrame.CombatLogMessageFrame:Clear()
    self.combatLogFrame.CombatLogMessageFrame.ScrollBar:SetMinMaxValues(0, 10)
    self.combatLogFrame.CombatLogMessageFrame:SetScrollOffset(0)
    self:setResultHeader('')
    self:setResultInfo('')
    self:hideButtonsFrame()
    wipe(CMH.Board.CombatLog)
    wipe(CMH.Board.HiddenCombatLog)
    wipe(CMH.Board.CombatLogEvents)
end

function MissionHelperFrame:setResultHeader(message)
    self.resultHeader.text:SetText(message)
end

function MissionHelperFrame:setResultInfo(message)
    self.resultInfo.text:SetText(message)
end

function MissionHelperFrame:AddCombatLogMessage(message)
    self.combatLogFrame.CombatLogMessageFrame:AddMessage(message)
end

function MissionHelperFrame:hidePredictButton()
    self.buttonsFrame.predictButton:Hide()
end

function MissionHelperFrame:hideBestDispositionButton()
    self.buttonsFrame.BestDispositionButton:Hide()
end

function MissionHelperFrame:disableBestDispositionButton()
    self.buttonsFrame.BestDispositionButton:Show()
    self.buttonsFrame.BestDispositionButton:Disable()
end

function MissionHelperFrame:enableBestDispositionButton()
    self.buttonsFrame.BestDispositionButton:Show()
    self.buttonsFrame.BestDispositionButton:Enable()
end

function MissionHelperFrame:disablePredictButton()
    self.buttonsFrame.predictButton:Show()
    self.buttonsFrame.predictButton:Disable()
end

function MissionHelperFrame:enablePredictButton()
    self.buttonsFrame.predictButton:Show()
    self.buttonsFrame.predictButton:Enable()
end

function MissionHelperFrame:showButtonsFrame()
    self.buttonsFrame:Show()
end

function MissionHelperFrame:hideButtonsFrame()
    self.buttonsFrame:Hide()
end

local function setSelectedTab(tab, isSelected)
    tab.Left:SetShown(isSelected)
    tab.Middle:SetShown(isSelected)
    tab.Right:SetShown(isSelected)

    tab.LeftDisabled:SetShown(not isSelected)
    tab.MiddleDisabled:SetShown(not isSelected)
    tab.RightDisabled:SetShown(not isSelected)
end

function MissionHelperFrame_SelectTab(tab)
    PlaySound(SOUNDKIT.UI_GARRISON_NAV_TABS)

    local id = tab:GetID()
    local parentFrame = tab:GetParent()
    if (id == 1) then
        parentFrame.resultInfo:Show()
        parentFrame.combatLogFrame:Hide()
        setSelectedTab(parentFrame.ResultTab, true)
        setSelectedTab(parentFrame.CombatLogTab, false)
    elseif (id == 2) then
        parentFrame.resultInfo:Hide()
        parentFrame.combatLogFrame:Show()
        setSelectedTab(parentFrame.ResultTab, false)
        setSelectedTab(parentFrame.CombatLogTab, true)
    end
end

function MissionHelperFrame_TabOnShow(self)
    if self.LeftDisabled:IsShown() then self.HighlightTexture:Show() end
end

function MissionHelperFrame_TabOnLeave(self)
    self.HighlightTexture:Hide()
end
