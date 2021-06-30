if not(GetLocale() == "ruRU") then
  return
end

local L = MissionHelper.L

L['.'] = '.'
L['HP'] = 'HP'
--Board.lua
L["Round"] = "Раунд"
L['kill'] = 'убивает'
L["Units have random abilities. The mission isn't simulate automatically.\nClick on the button to check the result."] = "У отрядов есть случайные заклинания. Такие миссии не расчитываются автоматически.\nНажмите на кнопку для проверки результата."
L['LOST'] = 'ПОТЕРЯНО'
L['RECEIVED'] = 'ВОССТАНОВЛЕНО'
L["Units have random abilities. Actual rest HP may not be the same as predicted"] = "У отрядов есть случайные заклинания. В действительности оставшееся здоровье может отличаться от предсказанного"
L["My units"] = "Мои отряды"
L["TOTAL"] = "ВСЕГО"
L['Add units on board'] = 'Добавьте спутников на поле'
L['More than %s rounds. Winner is undefined'] = 'Более чем %s раундов. Победитель неопределен'
L['WIN'] = 'ПОБЕДА'
L['LOSE'] = 'ПОРАЖЕНИЕ'
L['Enemy units'] = 'Вражеские отряды'
L['TOTAL REMAINING HP'] = 'ВСЕГО ОСТАЛОСЬ HP'

--CovenantMissionHelper.lua
L['Base XP'] = 'Базовый опыт'
L['XP'] = 'опыт'
L['XP/hour'] = 'опыт/ч'

--DataTables.lua
L["for spellID = 17 only"] = "for spellID = 17 only"
L["damage"] = "атакует"
L["heal"] = "исцеляет"
L["DoT"] = "DoT"
L["HoT"] = "HoT"
-- Надо переводить сами шаблоны строк для комбат лога. Пока оставлю так.
L["Taunt"] = "Угрозу. Цель:"
L["Untargetable"] = "Невидимость. Цель:"
L["Damage dealt multiplier"] = "Модификатор наносимого урона. Цель:"
L["Damage taken multiplier"] = "Модификатор получаемого урона. Цель:"
L["Reflect"] = "Reflect"
L["Maximum health multiplier"] = "Модификатор максимального здоровья. Цель:"
L["Additional damage dealt"] = "Дополнительно наносимый урон. Цель:"
L["Additional receive damage"] = "Дополнительно получаемый урон. Цель:"

--MissionHelperFrame.lua
L['Duration'] = 'Продолжительность'
L['Offer time'] = 'Доступно в течение'

--UI.lua
L["Simulate mission 100 times to find approximate success rate"] = "Симулировать миссию 100 раз для нахождения примерного шанса победы"
L['Simulate'] = 'Симуляция'
L["Change the order of your troops to minimize HP loss"] = "Изменить расположение отрядов для минимизации потерянного здоровья"
L["It shuffles only units on board and doesn't consider others"] = "Меняет расположение только выставленных отрядов, не учитывает остальные"
L["Addon doesn't support "] = "Аддон не поддерживает"
L['"Optimize" if units have random abilities'] = '"Оптимизировать", если у отрядов есть случайные способности'
L['Optimize'] = 'Оптимизация'
L['Result'] = 'Результат'
L['Combat log'] = 'Журнал боя'

--Unit.lua
L['Auto Attack'] = 'Автоатака'
L['for'] = 'на'
L['apply'] = 'применяет'
L['remove'] = 'снимает'
L['from'] = 'с'
