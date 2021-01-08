CovenantMissionHelper, CMH = ...
local hooksecurefunc = _G["hooksecurefunc"]

MissionHelper = CreateFrame("Frame", "missionHelper", UIParent)
MissionHelper.isLoaded = false

function MissionHelper:ADDON_LOADED(event, addon)
    if addon == "Blizzard_GarrisonUI" then
        if self.isLoaded then return end
        hooksecurefunc(_G["CovenantMissionFrame"], "SetupTabs", self.hookSetupTabs)
        self.isLoaded = true
    end
end

function MissionHelper:hookShowMission(...)
    local missionPage = CovenantMissionFrame:GetMissionPage()
    missionPage.Board:ShowHealthValues()

    local board = CMH.Board:new(missionPage)
    MissionHelper.missionHelperFrame:Show()
    CMH.Board.CombatLog = {}
    CMH.Board.HiddenCombatLog = {}
    board:fight()

    local combatLogMessageFrame = MissionHelper.missionHelperFrame.combatLogFrame.CombatLogMessageFrame
    local combat_log = false and CMH.Board.HiddenCombatLog or CMH.Board.CombatLog
    combatLogMessageFrame:Clear()
    MissionHelper.missionHelperFrame.resultHeader.text:SetText(board:getResult())
    MissionHelper.missionHelperFrame.resultInfo.text:SetText(board:getTeams())
    for _, text in ipairs(combat_log) do MissionHelper:updateText(combatLogMessageFrame, text) end
    MissionHelper:updateText(combatLogMessageFrame, board:getResult())

    combatLogMessageFrame.ScrollBar:SetMinMaxValues(0, combatLogMessageFrame:GetNumMessages())
    combatLogMessageFrame:SetScrollOffset(
            math.max(
                    combatLogMessageFrame:GetNumMessages() - math.floor(combatLogMessageFrame:GetNumVisibleLines() / 2),
                    0))

    MissionHelper.missionHelperFrame.board = board

    --[[ TODO: board after fight
        HP after fight = CovenantMissionFrame.MissionComplete.Board.framesByBoardIndex.HealthBar.health
        blizzard combat log = CovenantMissionFrame.MissionComplete.AdventuresCombatLog.CombatLogMessageFrame.historyBuffer.elements[].message
    --]]

    return ...

end

function MissionHelper:hookCloseMission(...)
    MissionHelper.missionHelperFrame.combatLogFrame.CombatLogMessageFrame:Clear()
    MissionHelper.missionHelperFrame:Hide()
    MissionHelper.missionHelperFrame.resultHeader.text:SetText('')
    MissionHelper.missionHelperFrame.resultInfo.text:SetText('')
    return ...
end

local function registerHook(...)
    hooksecurefunc(_G["CovenantMissionFrame"], "ShowMission", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "UpdateAllyPower", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "UpdateEnemyPower", MissionHelper.hookShowMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "CloseMission", MissionHelper.hookCloseMission)
    hooksecurefunc(_G["CovenantMissionFrame"], "InitiateMissionCompletion", MissionHelper.hookShowMission)
end

local function editDefaultFrame(...)
    CovenantMissionFrame:ClearAllPoints()
    CovenantMissionFrame:SetPoint("CENTER", UIParent, "CENTER", -300, 100)
end

local function createMissionHelperFrame(...)

    -- TODO: clean code
    local frame  = CreateFrame("Frame", "missionHelperFrame", _G["CovenantMissionFrame"], "CovenantMissionBaseFrameTemplate") -- GarrisonUITemplate/BasicFrameTemplate
    frame:SetPoint("TOPLEFT", CovenantMissionFrame, "TOPRIGHT")
    frame:SetClampedToScreen(true)
    frame:SetSize(700, CovenantMissionFrame:GetHeight())
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame.BaseFrameTopLeft:Hide()
    frame.BaseFrameTopRight:Hide()
    frame.BaseFrameBottomLeft:Hide()
    frame.BaseFrameBottomRight:Hide()
    frame.BaseFrameBackground:SetAtlas('adventures-missions-bg-02', false)

    local resultHeader = CreateFrame("Frame", nil, frame)
    frame.resultHeader = resultHeader
    resultHeader:SetPoint("TOP", frame, "TOP", 0, -20)
    resultHeader:SetSize(200, 30)
    resultHeader.BaseFrameBackground = resultHeader:CreateTexture()
    resultHeader.BaseFrameBackground:SetAtlas("adventures_mission_materialframe")
    resultHeader.BaseFrameBackground:SetAllPoints(resultHeader)
    resultHeader.text = resultHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    resultHeader.text:SetPoint("CENTER")
    resultHeader.text:SetJustifyH("CENTER")
    resultHeader.text:SetJustifyV("CENTER")

    local resultInfo = CreateFrame("Frame", nil, frame, "CovenantMissionBaseFrameTemplate")
    frame.resultInfo = resultInfo
    resultInfo:SetSize(frame:GetWidth() - 40, 120)
    resultInfo:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -60)
    resultInfo.BaseFrameTopLeft:Hide()
    resultInfo.BaseFrameTopRight:Hide()
    resultInfo.BaseFrameBottomLeft:Hide()
    resultInfo.BaseFrameBottomRight:Hide()
    resultInfo.RaisedFrameEdges.BaseFrameTopLeftCorner:Hide()
    resultInfo.RaisedFrameEdges.BaseFrameTopRightCorner:Hide()
    resultInfo.RaisedFrameEdges.BaseFrameBottomLeftCorner:Hide()
    resultInfo.RaisedFrameEdges.BaseFrameBottomRightCorner:Hide()
    resultInfo.text = resultInfo:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resultInfo.text:SetSize(resultInfo:GetWidth() - 20 , resultInfo:GetHeight() - 20)
    resultInfo.text:SetPoint("TOPLEFT", 20, -10)
    resultInfo.text:SetJustifyH("LEFT")
    resultHeader.text:SetJustifyV("TOP")

    --frame:SetFrameStrata("FULLSCREEN_DIALOG")
    --[[
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true,
        tileSize = 32,
        edgeSize = 32,
        insets   = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    --]]

    local combatLogFrame = CreateFrame("Frame", "missionHelperCombatLogFrame", frame, "CovenantMissionBaseFrameTemplate")
    combatLogFrame:SetPoint("TOPLEFT", resultInfo, "BOTTOMLEFT", 0, -10)
    combatLogFrame:SetSize(frame:GetWidth() - 40, frame:GetHeight() - 220)
    --combatLogFrame.BaseFrameBackground:SetAtlas('ClassHall_StoneFrame-BackgroundTile', false)
    combatLogFrame.BaseFrameBackground:SetAtlas('adventures-missions-bg-01', false)
    combatLogFrame.BaseFrameTopLeft:Hide()
    combatLogFrame.BaseFrameTopRight:Hide()
    combatLogFrame.BaseFrameBottomLeft:Hide()
    combatLogFrame.BaseFrameBottomRight:Hide()
    combatLogFrame.RaisedFrameEdges.BaseFrameTopLeftCorner:Hide()
    combatLogFrame.RaisedFrameEdges.BaseFrameTopRightCorner:Hide()
    combatLogFrame.RaisedFrameEdges.BaseFrameBottomLeftCorner:Hide()
    combatLogFrame.RaisedFrameEdges.BaseFrameBottomRightCorner:Hide()
    frame.combatLogFrame = combatLogFrame

    -- ScrollingMessageFrame
    local messageFrame = CreateFrame("ScrollingMessageFrame", "missionHelperMessageFrame", combatLogFrame)
    messageFrame:SetFontObject(GameFontNormal)
    messageFrame:SetSize(frame:GetWidth() - 80, frame:GetHeight() - 260)
    messageFrame:SetPoint("TOPLEFT", 20, -20)
    --messageFrame:SetTextColor(1, 1, 1, 1) -- default color
    messageFrame:SetJustifyH("LEFT")
    messageFrame:SetJustifyV("TOP")
    messageFrame:SetHyperlinksEnabled(true)
    messageFrame:SetFading(false)
    messageFrame:SetMaxLines(20000)
    messageFrame:ScrollToTop()
    combatLogFrame.CombatLogMessageFrame = messageFrame


    -------------------------------------------------------------------------------
    -- Scroll bar
    -------------------------------------------------------------------------------
    local scrollBar = CreateFrame("Slider", "missionHelperScrollBar", combatLogFrame, "OribosScrollBarTemplate")
    scrollBar:SetPoint("TOPRIGHT", combatLogFrame, "TOPRIGHT", -10, -30)
    scrollBar:SetSize(10, frame:GetHeight() - 280)
    scrollBar:SetFrameLevel(combatLogFrame:GetFrameLevel() + 1)
    scrollBar:SetMinMaxValues(0, 100)
    scrollBar:SetValueStep(5)
    scrollBar.scrollStep = 5
    combatLogFrame.CombatLogMessageFrame.ScrollBar = scrollBar

    scrollBar:SetScript("OnValueChanged", function(self, value)
        messageFrame:SetScrollOffset(select(2, scrollBar:GetMinMaxValues()) - value)
    end)

    scrollBar:SetValue(select(2, scrollBar:GetMinMaxValues()))

    frame:SetScript("OnMouseWheel", function(self, delta)
        local cur_val = scrollBar:GetValue()
        local min_val, max_val = scrollBar:GetMinMaxValues()

        if delta < 0 and cur_val < max_val then
            cur_val = math.min(max_val, cur_val + 5)
            scrollBar:SetValue(cur_val)
        elseif delta > 0 and cur_val > min_val then
            cur_val = math.max(min_val, cur_val - 5)
            scrollBar:SetValue(cur_val)
        end
    end)

    frame:Hide()
    MissionHelper.missionHelperFrame = frame
    return frame

end

function MissionHelper:hookSetupTabs(...)
    registerHook(...)
    editDefaultFrame(...)
    local missionHelperFrame = createMissionHelperFrame(...)

    return ...
end

function MissionHelper:updateText(frame, newText)
    frame:AddMessage(newText)
end

missionHelper:RegisterEvent("ADDON_LOADED")
missionHelper:SetScript("OnEvent", MissionHelper.ADDON_LOADED)

function CMH:log(msg)
    table.insert(CMH.Board.CombatLog, msg)
    table.insert(CMH.Board.HiddenCombatLog, msg)
end

function CMH:debug_log(msg)
    table.insert(CMH.Board.HiddenCombatLog, msg)
end
