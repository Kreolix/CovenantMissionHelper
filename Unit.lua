CovenantMissionHelper, CMH = ...

local Unit = {}
local EffectTypeEnum = CMH.DataTables.EffectTypeEnum
function Unit:new(blizzardUnitInfo)
    local newObj = {
        -- use for unusual attack only, blizz dont store combatantID in mission's tables
        ID = blizzardUnitInfo.garrFollowerID ~= nil and blizzardUnitInfo.garrFollowerID or blizzardUnitInfo.portraitFileDataID,
        name = blizzardUnitInfo.name,
        maxHealth = blizzardUnitInfo.maxHealth,
        currentHealth = blizzardUnitInfo.health,
        attack = blizzardUnitInfo.attack,
        isAutoTroop = blizzardUnitInfo.isAutoTroop,
        boardIndex = blizzardUnitInfo.boardIndex,
        role = blizzardUnitInfo.role,
        tauntedBy = nil,
        untargetable = false,
        reflect = 0,
        buffs = {}
    }

    self.__index = self
    setmetatable(newObj, self)
    newObj:setSpells(blizzardUnitInfo.autoCombatSpells)


    return newObj
end

function Unit:getAttackType()
    if CMH.DataTables.UnusualAttackType[self.ID] ~= nil then
        return CMH.DataTables.UnusualAttackType[self.ID]
    elseif self.role == 1 or self.role == 5 then -- melee and tank
        return 11
    else
        return 15
    end
end

function Unit:setSpells(autoCombatSpells)
    self.spells = {}
    -- auto attack is spell
    local autoAttack = {
        autoCombatSpellID = self:getAttackType(),
        name = 'Auto Attack',
        duration = 0,
        cooldown = 0,
        flags = 0
    }
    local autoAttackSpell = CMH.Spell:new(autoAttack)
    table.insert(self.spells, autoAttackSpell)

    for _, autoCombatSpell in pairs(autoCombatSpells) do
        table.insert(self.spells, CMH.Spell:new(autoCombatSpell))
    end
end

function Unit:isAlive()
    return self.currentHealth > 0
end

function Unit:getEffectBaseValue(effect)
    if effect.Effect == 12 or effect.Effect == 13 or effect.Effect == 14 or effect.Effect == 15 then return effect.Points end
    if effect.Flags == 1 or effect.Flags == 3 then
        return math.floor(effect.Points * self.attack)
    else
        return effect.Points
    end
end

function Unit:calculateEffectValue(targetUnit, effect)
    local value
    if effect.Flags == 0 or effect.Flags == 2 then
        value = math.floor(effect.Points * targetUnit.maxHealth)
    else
        value = math.floor(effect.Points * self.attack)
    end

    if effect.Effect == EffectTypeEnum.Damage or effect.Effect == EffectTypeEnum.Damage_2 or effect.Effect == EffectTypeEnum.DoT then
        value = self:getDamageMultiplier(targetUnit) * (value + self:getAdditionalDamage(targetUnit))
    end

    return math.max(math.floor(value), 0)
end

function Unit:manageDoTHoT(sourceUnit, buff, isInitialPeriod)
    if isInitialPeriod == nil then isInitialPeriod = false end
    if (buff.Effect == EffectTypeEnum.DoT or buff.Effect == EffectTypeEnum.HoT) and (buff.currentPeriod == 0 or isInitialPeriod) then
        local oldHP = self.currentHealth
        local value = sourceUnit:calculateEffectValue(self, buff)
        local text = ''

        if buff.Effect == EffectTypeEnum.DoT then
            self.currentHealth = math.max(0, self.currentHealth - value)
            text = 'DoT'
        else
            self.currentHealth = math.min(self.maxHealth, self.currentHealth + value)
            text = 'HoT'
        end

        CMH:log(string.format('|cFFFFFF00%s %s %s for %s. (HP %s -> %s)|r',
                sourceUnit.name, text, self.name, value, oldHP, self.currentHealth))
    end
end

function Unit:applyBuff(targetUnit, effect, effectBaseValue, duration, name)
    table.insert(targetUnit.buffs, CMH.Buff:new(effect, effectBaseValue, self.boardIndex, duration, name))
    CMH:log(string.format('|c0066CCFF%s %s %s to %s (%s)|r',
                self.name, 'apply', CMH.DataTables.EffectType[effect.Effect], targetUnit.name, effectBaseValue))
    if effect.Effect == EffectTypeEnum.Taunt then
        targetUnit.tauntedBy = self.boardIndex
    elseif effect.Effect == EffectTypeEnum.Untargetable then
        targetUnit.untargetable = true
    elseif effect.Effect == EffectTypeEnum.Reflect or effect.Effect == EffectTypeEnum.Reflect_2 then
        targetUnit.reflect = effectBaseValue
    end

    -- extra initial period
    if effect.Flags == 2 or effect.Flags == 3 then
        targetUnit:manageDoTHoT(self, effect, true)
    end
end

function Unit:getDamageMultiplier(targetUnit)
    local negative_value = 0
    local positive_value = 1
    for _, buff in pairs(self.buffs) do
        if buff.Effect == EffectTypeEnum.DamageDealtMultiplier or buff.Effect == EffectTypeEnum.DamageDealtMultiplier_2 then
            CMH:debug_log('self buff ' .. CMH.DataTables.EffectType[buff.Effect] .. ' ' .. buff.baseValue)
            if buff.baseValue < 0 then
                negative_value = negative_value + buff.baseValue
            else
                positive_value = positive_value + buff.baseValue
            end
        end
    end

    for _, buff in pairs(targetUnit.buffs) do
        if buff.Effect == EffectTypeEnum.DamageTakenMultiplier or buff.Effect == EffectTypeEnum.DamageTakenMultiplier_2 then
            CMH:debug_log('target buff ' .. CMH.DataTables.EffectType[buff.Effect] .. ' ' .. buff.baseValue)
            if buff.baseValue < 0 then
                negative_value = negative_value + buff.baseValue
            else
                positive_value = positive_value + buff.baseValue
            end
        end
    end

    local result = (1 + negative_value) * positive_value
    if result ~= 1 then CMH:debug_log('damage multiplier = ' .. result) end
    return math.max(result, 0)
end

function Unit:getAdditionalDamage(targetUnit)
    local result = 0
    for _, buff in pairs(self.buffs) do
        if buff.Effect == EffectTypeEnum.AdditionalDamageDealt then
            result = result + buff.baseValue
        end
    end

    for _, buff in pairs(targetUnit.buffs) do
        if buff.Effect == EffectTypeEnum.AdditionalTakenDamage then
            result = result + buff.baseValue
        end
    end
    if result ~= 0 then CMH:debug_log('additional damage = ' .. result) end
    return result
end

function Unit:castSpellEffect(targetUnit, effect, duration, name)
    local oldTargetHP = targetUnit.currentHealth
    local value = 0
    -- deal damage
    if effect.Effect == EffectTypeEnum.Damage or effect.Effect == EffectTypeEnum.Damage_2 then
        value = self:calculateEffectValue(targetUnit, effect)
        targetUnit.currentHealth = math.max(0, targetUnit.currentHealth - value)
        local color = (effect.ID == 17 or effect.ID == 21) and '00FFFFFF' or '0066CCFF'
        CMH:log(string.format('|c%s%s %s %s for %s. (HP %s -> %s)|r',
                color, self.name, 'attack', targetUnit.name, value, oldTargetHP, targetUnit.currentHealth))
        targetUnit:dealReflectDamage(self)

    -- heal
    elseif effect.Effect == EffectTypeEnum.Heal or effect.Effect == EffectTypeEnum.Heal_2 then
        value = self:calculateEffectValue(targetUnit, effect)
        targetUnit.currentHealth = math.min(targetUnit.maxHealth, targetUnit.currentHealth + value)
        CMH:log(string.format('|c0066CCFF%s %s %s for %s. (HP %s -> %s)|r',
                self.name, 'heal', targetUnit.name, value, oldTargetHP, targetUnit.currentHealth))

    -- Maximum health multiplier
    elseif effect.Effect == EffectTypeEnum.MaxHPMultiplier then
        value = self:calculateEffectValue(targetUnit, effect)
        targetUnit.maxHealth = targetUnit.maxHealth + value
        CMH:log(string.format('|c0066CCFF%s %s %s for %s. (HP %s -> %s)|r',
                self.name, 'add max HP', targetUnit.name, value, oldTargetHP, targetUnit.maxHealth))
    else
        value = self:getEffectBaseValue(effect)
        CMH:debug_log('effectBaseValue = ' .. tostring(value))
        self:applyBuff(targetUnit, effect, value, duration, name)
    end

    return {
        boardIndex = targetUnit.boardIndex,
        maxHealth = targetUnit.maxHealth,
        oldHealth = oldTargetHP,
        newHealth = targetUnit.currentHealth,
        points = value
    }
end

function Unit:dealReflectDamage(targetUnit)
    if self.reflect == 0 then return end

    local damage = math.max(math.floor(self:getDamageMultiplier(targetUnit) * (self.reflect + self:getAdditionalDamage(targetUnit))), 0)
    local oldHP = targetUnit.currentHealth
    targetUnit.currentHealth = math.max(0, targetUnit.currentHealth - damage)
    local color = '0066CCFF'
    CMH:log(string.format('|c%s%s %s %s for %s. (HP %s -> %s)|r',
            color, self.name, 'reflect damage to', targetUnit.name, damage, oldHP, targetUnit.currentHealth))
end

function Unit:getAvailableSpells()
    -- Return autoAttack's and all spell's effects
    local result = {}

    for _, spell in pairs(self.spells) do
        if spell:isAvailable() then table.insert(result, spell) end
    end

    return result
end

function Unit:startSpellCooldown(spellID)
    --CMH:log('Start Cooldown. SpellID = ' .. spellID .. '. name = ' .. type(spellID))
    for _, spell in ipairs(self.spells) do
        if spell.ID == spellID then
            spell:startCooldown()
            break
        end
    end
end

function Unit:decreaseSpellsCooldown()
    for _, spell in pairs(self.spells) do spell:decreaseCooldown() end
end

function Unit:manageBuffs(sourceUnit)
    local i = 1
    local removed_buffs = {}
    if #self.buffs > 0 then CMH:debug_log('unit = ' .. self.boardIndex .. ' buffs = ' .. #self.buffs) end
    while i <= #self.buffs do
        local buff = self.buffs[i]
        CMH:debug_log('buff effect = ' .. buff.Effect .. ' duration = ' .. tostring(buff.duration) ..
                ' period = ' .. tostring(buff.Period))
        if buff.sourceIndex == sourceUnit.boardIndex then
            self:manageDoTHoT(sourceUnit, buff, false)
            buff:decreaseRestTime()
        end

        if buff.duration == 0 then
            table.insert(removed_buffs, {
                buff = buff,
                targetBoardIndex = self.boardIndex,
            })
            CMH:log(string.format('|c000088CC%s remove %s from %s|r',
                    tostring(sourceUnit.name), tostring(buff.name), tostring(self.name)))
            table.remove(self.buffs, i)
            if buff.Effect == EffectTypeEnum.Taunt then
                self.tauntedBy = nil
            elseif buff.Effect == EffectTypeEnum.Untargetable then
                self.untargetable = false
            elseif buff.Effect == EffectTypeEnum.Reflect or buff.Effect == EffectTypeEnum.Reflect_2 then
                self.reflect = 0
            end
        else
            i = i + 1
        end
    end

    return removed_buffs
end

CMH.Unit = Unit