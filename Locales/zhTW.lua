if not(GetLocale() == "zhTW") then
  return
end

local L = MissionHelper.L

L['.'] = '。'
L['HP'] = '生命值'
--Board.lua
L["Round"] = "回合"
L['kill'] = '殺死'
L["Units have random abilities. The mission isn't simulate automatically.\nClick on the button to check the result."] = "部隊擁有隨機能力，任務無法自動模擬。\n單擊按鈕確認模擬結果。"
L['LOST'] = '失去'
L['RECEIVED'] = '獲得'
L["Units have random abilities. Actual rest HP may not be the same as predicted"] = "部隊擁有隨機能力.。實際剩余生命可能與預測結果不同"
L["My units"] = "我的單位"
L["TOTAL"] = "總計"
L['Add units on board'] = '添加夥伴以及部隊'
L['More than %s rounds. Winner is undefined'] = '超過 %s 回合。勝方無法確定。'
L['WIN'] = '勝利'
L['LOSE'] = '失敗'
L['Enemy units'] = '敵方單位'
L['TOTAL REMAINING HP'] = '總計剩餘生命值'
-- TODO: translate
L['Average HP'] = '平均 HP'
L['Minimal HP'] = '最低 HP'

--CovenantMissionHelper.lua
L['Base XP'] = '基礎經驗值'
L['XP'] = '經驗值'
L['XP/hour'] = '經驗值/小時'

--DataTables.lua
L["for spellID = 17 only"] = "來自 技能編號 = 17"
L["damage"] = "傷害"
L["heal"] = "治療"
L["DoT"] = "持續傷害"
L["HoT"] = "持續治療"
L["Taunt"] = "嘲諷"
L["Untargetable"] = "未命中"
L["Damage dealt multiplier"] = "造成傷害倍率"
L["Damage taken multiplier"] = "承受傷害倍率"
L["Reflect"] = "反傷"
L["Maximum health multiplier"] = "最大生命值倍率"
L["Additional damage dealt"] = "造成額外傷害"
L["Additional receive damage"] = "受到額外傷害"

--MissionHelperFrame.lua
L['Duration'] = '花費時間'
L['Offer time'] = '過期時間'

--UI.lua
L["Simulate mission 100 times to find approximate success rate"] = "模擬100次冒險戰鬥，以獲得更準確的成功率。（部隊擁有隨機技能時可用）"
L['Simulate'] = '戰鬥模擬'
L["Change the order of your troops to minimize HP loss"] = "優化調整部隊的站位，可最大限度的減少生命值損失。"
L["It shuffles only units on board and doesn't consider others"] = "該操作只考慮指揮台上的部隊，不考慮未上場部隊。"
--TODO: translate
L["Find the disposition with the maximum average left HP as a percentage"] = "找到具有最大平均剩餘HP百分比的佈署"
L["Find the disposition with the maximum of lowest left HP as a percentage"] = "找到具有最大最低剩餘HP百分比的佈署"
L["Addon doesn't support "] = "如果部隊擁有隨機技能，"
L['"Optimize" if units have random abilities'] = '則"最佳化"功能不可用'
L['Optimize'] = '最佳化'
L['Result'] = '冒險結果'
L['Combat log'] = '冒險記錄'
--TODO: translate
L['Optimize by\navg. % HP'] = '最佳化根據\n平均 百分比HP'
L["Optimize by\nmin. % HP"] = "最佳化根據\n最低 百分比HP"

--Unit.lua
L['Auto Attack'] = '自動攻擊'
L['for'] = '的'
L['apply'] = '使用'
L['remove'] = '移除'
L['from'] = '從'
