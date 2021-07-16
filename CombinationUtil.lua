CovenantMissionHelper, CMH = ...

local CombinationUtil = {}
CMH.CombinationUtil = CombinationUtil

function CombinationUtil:tableToString(table)
    if type(table) == 'table' then
        local s = '{ '
        for k, v in pairs(table) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. CombinationUtil:tableToString(v) .. ','
        end
        return s .. '} '
    else
        return tostring(table)
    end
end

function CombinationUtil:tableLength(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

function CombinationUtil:everyFollowerPresentedExactlyOnce(combination, followers)
    local seen = {}
    for id, follower in pairs(followers) do
        seen[id] = 0
    end

    for _, id in ipairs(combination) do
        if followers[id] ~= nil then
            seen[id] = seen[id] + 1;
        end
    end

    local valid = true;
    for _, seenCount in pairs(seen) do
        if seenCount ~= 1 then
            valid = false;
        end
    end
    return valid;
end

function CombinationUtil:getTroopCombinations(followers)
    local index = 0;
    local combinations = {};
    local unitIds = { -1, 1, 2 }

    for id, follower in pairs(followers) do
        table.insert(unitIds, id)
    end

    for _, index0 in ipairs(unitIds) do
        for _, index1 in ipairs(unitIds) do
            for _, index2 in ipairs(unitIds) do
                for _, index3 in ipairs(unitIds) do
                    for _, index4 in ipairs(unitIds) do
                        local combination = { index0, index1, index2, index3, index4 }
                        if self:everyFollowerPresentedExactlyOnce(combination, followers) then
                            if index0 ~= -1 or index1 ~= -1 or index2 ~= -1 or index3 ~= -1 or index4 ~= -1 then
                                combinations[index] = combination;
                                index = index + 1;
                            end
                        end
                    end
                end
            end
        end
    end

    --print(self:tableLength(combinations))
    --print(self:tableToString(combinations))
    return combinations;
end