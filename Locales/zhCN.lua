if not(GetLocale() == "zhCN") then
  return
end

local L = MissionHelper.L

L['.'] = '。'
L['HP'] = '生命值'
--Board.lua
L["Round"] = "回合"
L['kill'] = '杀死'
L["Units have random abilities. The mission isn't simulate automatically.\nClick on the button to check the result."] = "部队拥有随机能力，任务无法自动模拟。\n单击按钮确认模拟结果。"
L['LOST'] = '失去'
L['RECEIVED'] = 'RECEIVED'
L["Units have random abilities. Actual rest HP may not be the same as predicted"] = "部队拥有随机能力.。实际剩余生命可能与预测结果不同"
L["My units"] = "我的单位"
L["TOTAL"] = "总计"
L['Add units on board'] = '添加伙伴以及部队'
L['More than %s rounds. Winner is undefined'] = '超过 %s 回合。胜利方无法确定。'
L['WIN'] = '胜利'
L['LOSE'] = '失败'
L['Enemy units'] = '敌人单位'
--TODO: translate
L['TOTAL REMAINING HP'] = 'TOTAL REMAINING HP'

--CovenantMissionHelper.lua
L['Base XP'] = '基础经验值'
L['XP'] = '经验值'
L['XP/hour'] = '经验值/小时'

--DataTables.lua
L["for spellID = 17 only"] = "来自 技能编号 = 17"
L["damage"] = "伤害"
L["heal"] = "治疗"
L["DoT"] = "持续伤害"
L["HoT"] = "持续治疗"
L["Taunt"] = "嘲讽"
L["Untargetable"] = "未命中"
L["Damage dealt multiplier"] = "造成伤害倍率"
L["Damage taken multiplier"] = "承受伤害倍率"
L["Reflect"] = "反伤"
L["Maximum health multiplier"] = "最大生命值倍率"
L["Additional damage dealt"] = "造成额外伤害"
L["Additional receive damage"] = "受到额外伤害"

--MissionHelperFrame.lua
L['Duration'] = '需要时间'
L['Offer time'] = '过期时间'

--UI.lua
L["Simulate mission 100 times to find approximate success rate"] = "模拟100次冒险战斗，以获得更准确的成功率。（部队拥有随机技能时可用）"
L['Simulate'] = '战斗模拟'
L["Change the order of your troops to minimize HP loss"] = "优化调整部队的站位，可最大限度的减少生命值损失。"
L["It shuffles only units on board and doesn't consider others"] = "该操作只考虑指挥台上的部队，不考虑未上场部队。"
L["Addon doesn't support "] = "如果部队拥有随机技能，"
L['"Optimize" if units have random abilities'] = '则"优化站位"功能不可用'
L['Optimize'] = '优化站位'
L['Result'] = '冒险结果'
L['Combat log'] = '冒险记录'

--Unit.lua
L['Auto Attack'] = '自动攻击'
L['for'] = '的'
L['apply'] = '使用'
L['remove'] = '移除'
L['from'] = '从'
