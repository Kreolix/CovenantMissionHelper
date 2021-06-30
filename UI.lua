local CovenantMissionHelper, CMH = ...
local MissionHelper = _G["MissionHelper"]
local L = MissionHelper.L

local MAX_FRAME_WIDTH = 500
local PADDING = 20
local MISSION_HEADER_HEIGHT = 90
local BUTTONS_FRAME_WIDTH = 300
local BUTTONS_FRAME_HEIGHT = 40
local RESULT_HEADER_WIDTH = 300
local RESULT_HEADER_HEIGHT = 30
local MAX_RESULT_INFO_HEIGHT = 400
local SCROLL_BAR_WIDTH = 10
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 25

local function hideCorners(frame)
    frame.BaseFrameTopLeft:Hide()
    frame.BaseFrameTopRight:Hide()
    frame.BaseFrameBottomLeft:Hide()
    frame.BaseFrameBottomRight:Hide()
end

local function hideBaseCorners(frame)
    frame.RaisedFrameEdges.BaseFrameTopLeftCorner:Hide()
    frame.RaisedFrameEdges.BaseFrameTopRightCorner:Hide()
    frame.RaisedFrameEdges.BaseFrameBottomLeftCorner:Hide()
    frame.RaisedFrameEdges.BaseFrameBottomRightCorner:Hide()
end

local function editMainFrame()
    local frame  = _G["MissionHelperFrame"]

    -- Looks like Blizz frame doesn't scale more then x1. But now it's EffectiveScale = value in user settings. (for example, 1.15)
    -- Somewhere after ADDON_LOADED blizz changes CovenantMissionFrame.EffectiveScale to ~1.
    -- Here I set my frame's set EffectiveScale = 1 (if needed) and calculate correct width.
    if CovenantMissionFrame:GetEffectiveScale() > 1 then frame:SetScale(1/CovenantMissionFrame:GetEffectiveScale()) end
    local scaleFix = math.max(1, CovenantMissionFrame:GetEffectiveScale())
    local mainFrameWidth = math.min(
            scaleFix * (GetScreenWidth() - CovenantMissionFrame:GetRight()/scaleFix) - 10,
            MAX_FRAME_WIDTH
    )
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", CovenantMissionFrame, "TOPRIGHT", 2, 2)
        frame:SetClampedToScreen(true)
        frame:SetSize(mainFrameWidth, CovenantMissionFrame:GetHeight() + 4)
        frame:EnableMouse(true)
        frame:EnableMouseWheel(true)
        frame.BaseFrameBackground:SetAtlas('adventures-missions-bg-02', false)
        hideCorners(frame)

    -- move frame
    frame:SetMovable(true)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and (IsShiftKeyDown()) and not self.isMoving then
            self:StartMoving();
            self.isMoving = true;
        end
    end)

    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and (IsShiftKeyDown()) and self.isMoving then
            self:StopMovingOrSizing();
            self.isMoving = false;
        end
    end)

    return frame
end

local function createMissionHeader(mainFrame)
    local missionHeader = CreateFrame("Frame", nil, mainFrame, "MissionHelperHeaderTemplate") -- CovenantMissionListButtonTemplate/MissionHelperHeaderTemplate
    mainFrame.missionHeader = missionHeader
        missionHeader:SetPoint("TOP", mainFrame, "TOP", 0, -PADDING)
        missionHeader:SetSize(mainFrame:GetWidth() - 2*PADDING, MISSION_HEADER_HEIGHT)

    return missionHeader
end

-------------------------------------------
--- Mission Result
-------------------------------------------

local function createResultHeader(mainFrame)
    local resultHeader = CreateFrame("Frame", nil, mainFrame)
    mainFrame.resultHeader = resultHeader
        resultHeader:SetPoint("TOP", mainFrame.missionHeader, "BOTTOM", 0, -PADDING)
        resultHeader:SetSize(RESULT_HEADER_WIDTH, RESULT_HEADER_HEIGHT)
        resultHeader.BaseFrameBackground = resultHeader:CreateTexture()
        resultHeader.BaseFrameBackground:SetAtlas("adventures_mission_materialframe")
        resultHeader.BaseFrameBackground:SetAllPoints(resultHeader)

    resultHeader.text = resultHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        resultHeader.text:SetPoint("CENTER")
        resultHeader.text:SetJustifyH("CENTER")
        resultHeader.text:SetJustifyV("CENTER")

    return resultHeader
end

local function createResultInfo(mainFrame)
    local resultInfo = CreateFrame("Frame", nil, mainFrame, "CovenantMissionBaseFrameTemplate")
    mainFrame.resultInfo = resultInfo
        local frame_height = min(MAX_RESULT_INFO_HEIGHT, mainFrame.resultHeader:GetBottom() - mainFrame:GetBottom() - BUTTONS_FRAME_HEIGHT - 3*PADDING)
        resultInfo:SetSize(mainFrame:GetWidth() - 2*PADDING, frame_height)
        resultInfo:SetPoint("TOP", mainFrame.resultHeader, "BOTTOM", 0, -PADDING/2)
        hideBaseCorners(resultInfo)
        hideCorners(resultInfo)

    resultInfo.text = resultInfo:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        resultInfo.text:SetSize(resultInfo:GetWidth() - 2*PADDING , resultInfo:GetHeight() - PADDING)
        resultInfo.text:SetPoint("TOPLEFT", PADDING, -PADDING)
        resultInfo.text:SetJustifyH("LEFT")
        resultInfo.text:SetJustifyV("TOP")

    return resultInfo
end

-------------------------------------------
--- Combat Log
-------------------------------------------

local function createScrollingMessageFrame(mainFrame, combatLogFrame)
    local frame_height = combatLogFrame:GetHeight() - 2*PADDING
    local messageFrame = CreateFrame("ScrollingMessageFrame", "missionHelperMessageFrame", combatLogFrame)
    combatLogFrame.CombatLogMessageFrame = messageFrame
        messageFrame:SetFontObject(GameFontNormal)
        messageFrame:SetSize(mainFrame:GetWidth() - 5*PADDING, frame_height)
        messageFrame:SetPoint("TOPLEFT", PADDING, -PADDING)
        messageFrame:SetJustifyH("LEFT")
        messageFrame:SetJustifyV("TOP")
        messageFrame:SetFading(false)
        messageFrame:SetMaxLines(20000)
    return messageFrame
end

local function createScrollBar(mainFrame, combatLogFrame)
    local frame_height = combatLogFrame:GetHeight() - 3*PADDING
    local scrollBar = CreateFrame("Slider", nil, combatLogFrame, "OribosScrollBarTemplate")
    combatLogFrame.CombatLogMessageFrame.ScrollBar = scrollBar
        scrollBar:SetPoint("TOPRIGHT", combatLogFrame, "TOPRIGHT", -SCROLL_BAR_WIDTH, -1.5*PADDING)
        scrollBar:SetSize(SCROLL_BAR_WIDTH, frame_height)
        scrollBar:SetFrameLevel(combatLogFrame:GetFrameLevel() + 1)
        scrollBar:SetMinMaxValues(0, 100)
        scrollBar:SetValueStep(5)

    scrollBar:SetScript("OnValueChanged", function(self, value)
        MissionHelperFrame.combatLogFrame.CombatLogMessageFrame:SetScrollOffset(select(2, self:GetMinMaxValues()) - value)
    end)

    scrollBar:SetValue(select(2, scrollBar:GetMinMaxValues()))

    return scrollBar
end

local function createCombatLogFrame(mainFrame)
    local combatLogFrame = CreateFrame("Frame", nil, mainFrame, "CovenantMissionBaseFrameTemplate")
    mainFrame.combatLogFrame = combatLogFrame
        combatLogFrame:SetSize(mainFrame:GetWidth() - 2*PADDING, mainFrame.resultInfo:GetHeight())
        combatLogFrame:SetPoint("TOP", mainFrame.resultHeader, "BOTTOM", 0, -PADDING/2)
        combatLogFrame.BaseFrameBackground:SetAtlas('adventures-missions-bg-01', false)
        hideCorners(combatLogFrame)
        hideBaseCorners(combatLogFrame)

    createScrollingMessageFrame(mainFrame, combatLogFrame)
    createScrollBar(mainFrame, combatLogFrame)
    return combatLogFrame
end

-------------------------------------------
--- Buttons
-------------------------------------------

local function createPredictButton(frame)
    local function onClick()
        MissionHelper:showResult(MissionHelper:simulateFight(true))
    end

    local function onEnter(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMRIGHT", 0, 0)
        GameTooltip_AddNormalLine(GameTooltip, L["Simulate mission 100 times to find approximate success rate"])
        GameTooltip:Show()
    end

    local function onLeave()
        GameTooltip_Hide()
    end

    local predictButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.predictButton = predictButton
        predictButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        predictButton:SetPoint("LEFT", frame, "CENTER", PADDING/2, 0)
        predictButton:SetText(L['Simulate'])
        predictButton:SetMotionScriptsWhileDisabled(true)
        predictButton:SetScript('onClick', onClick)
        predictButton:SetScript('onEnter', onEnter)
        predictButton:SetScript('onLeave', onLeave)
        predictButton:Hide()
end

local function createBestDispositionButton(frame)
    local function onClick(self)
        if self:IsEnabled() then MissionHelper:findBestDisposition() end
    end

    local function onEnter(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMRIGHT", 0, 0)

        if self:IsEnabled() then
            GameTooltip_AddNormalLine(GameTooltip, L["Change the order of your troops to minimize HP loss"])
            GameTooltip_AddColoredLine(GameTooltip, L["It shuffles only units on board and doesn't consider others"], RED_FONT_COLOR)
        else
            GameTooltip_AddColoredLine(GameTooltip, L["Addon doesn't support "] .. L['"Optimize" if units have random abilities'], RED_FONT_COLOR)
        end

        GameTooltip:Show()
    end

    local function onLeave()
        GameTooltip_Hide()
    end

    local BestDispositionButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.BestDispositionButton = BestDispositionButton
        BestDispositionButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
        BestDispositionButton:SetPoint("RIGHT", frame, "CENTER", -PADDING/2, 0)
        BestDispositionButton:SetText(L['Optimize'])
        BestDispositionButton:SetMotionScriptsWhileDisabled(true)
        BestDispositionButton:SetScript('onClick', onClick)
        BestDispositionButton:SetScript('onEnter', onEnter)
        BestDispositionButton:SetScript('onLeave', onLeave)
        BestDispositionButton:Hide()
end

local function createButtonsFrame(mainFrame)
    local buttonsFrame = CreateFrame("Frame", nil, mainFrame)
    mainFrame.buttonsFrame = buttonsFrame
        buttonsFrame:SetSize(BUTTONS_FRAME_WIDTH, BUTTONS_FRAME_HEIGHT)
        buttonsFrame:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, PADDING/2)
        buttonsFrame.bg = buttonsFrame:CreateTexture()
        buttonsFrame.bg:SetAtlas("adventures-rewards-banner", false)
        buttonsFrame.bg:SetAllPoints(buttonsFrame)


    createBestDispositionButton(buttonsFrame)
    createPredictButton(buttonsFrame)
end

-------------------------------------------
--- Tabs
-------------------------------------------

local function createTabs(mainFrame)

    local ResultTab = CreateFrame("Button", "MissionHelperTab1", mainFrame, "MissionHelperTabButtonTemplate")
    mainFrame.ResultTab = ResultTab
        ResultTab:SetID(1)
        ResultTab:SetPoint("TOPLEFT", mainFrame.resultInfo, "BOTTOMLEFT", PADDING, 0)
        ResultTab:SetText(L['Result'])

    local CombatLogTab = CreateFrame("Button", "MissionHelperTab2", mainFrame, "MissionHelperTabButtonTemplate")
    mainFrame.CombatLogTab = CombatLogTab
        CombatLogTab:SetID(2)
        CombatLogTab:SetPoint("LEFT", mainFrame.ResultTab, "RIGHT", -15, 0)
        CombatLogTab:SetText(L['Combat log'])

    MissionHelperFrame_SelectTab(ResultTab)
end

function MissionHelper:createMissionHelperFrame()

    local mainFrame = editMainFrame()
    local missionHeader = createMissionHeader(mainFrame)
    local resultHeader = createResultHeader(mainFrame)
    local resultInfo = createResultInfo(mainFrame)
    local combatLogFrame = createCombatLogFrame(mainFrame)
    combatLogFrame:Hide()
    local buttonsFrame = createButtonsFrame(mainFrame)
    createTabs(mainFrame)

    mainFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur_val = mainFrame.combatLogFrame.CombatLogMessageFrame.ScrollBar:GetValue()
        local min_val, max_val = mainFrame.combatLogFrame.CombatLogMessageFrame.ScrollBar:GetMinMaxValues()

        if delta < 0 and cur_val < max_val then
            cur_val = math.min(max_val, cur_val + 5)
            mainFrame.combatLogFrame.CombatLogMessageFrame.ScrollBar:SetValue(cur_val)
        elseif delta > 0 and cur_val > min_val then
            cur_val = math.max(min_val, cur_val - 5)
            mainFrame.combatLogFrame.CombatLogMessageFrame.ScrollBar:SetValue(cur_val)
        end
    end)

    mainFrame:Hide()
    return mainFrame

end

function MissionHelper:editDefaultFrame()
    local left = CovenantMissionFrame:GetLeft() or 0
    CovenantMissionFrame:ClearAllPoints()
    CovenantMissionFrame:SetPoint("LEFT", UIParent, "LEFT", math.max(5, left - 300), 0)
end
