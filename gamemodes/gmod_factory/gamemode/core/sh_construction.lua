-- A personal reserve: owned resources minus resources committed to live builds.
local Build = {}
Build.Kinds = {"gravel", "sand", "clay", "mineral"}
Build.Cap = 1000000
Build.Bootstrap = {gravel = 40, sand = 30, clay = 20, mineral = 40}
Build.Costs = {
    gf_hub = {gravel = 8, sand = 2, clay = 4, mineral = 4},
    gf_extractor = {gravel = 6, sand = 2, mineral = 4},
    gf_separator = {gravel = 8, sand = 4, clay = 4, mineral = 6},
    gf_dispatch = {gravel = 4, sand = 4, clay = 2, mineral = 4}
}
Build.PropCost = {gravel = 1}
Build.WireCost = {sand = 1, mineral = 1}

local function validNumber(value)
    return type(value) == "number" and value == value and value >= 0 and value <= Build.Cap and value % 1 == 0
end

function Build.Cost(class)
    if Build.Costs[class] then return Build.Costs[class] end
    if class:sub(1, 10) == "gmod_wire_" then return Build.WireCost end
    return Build.PropCost
end

function Build.NewAccount(saved)
    local initial = saved == nil and Build.Bootstrap or type(saved) == "table" and saved or {}
    local account = {total = {}, reserved = {}}
    for _, kind in ipairs(Build.Kinds) do
        account.total[kind] = validNumber(initial[kind]) and initial[kind] or 0
        account.reserved[kind] = 0
    end
    return account
end

function Build.Available(account, kind)
    return (account.total[kind] or 0) - (account.reserved[kind] or 0)
end

function Build.CanAfford(account, cost)
    for kind, amount in pairs(cost) do
        if account.total[kind] == nil or not validNumber(amount) or Build.Available(account, kind) < amount then return false end
    end
    return true
end

function Build.Reserve(account, cost)
    if not Build.CanAfford(account, cost) then return false end
    for kind, amount in pairs(cost) do account.reserved[kind] = account.reserved[kind] + amount end
    return true
end

function Build.Release(account, cost)
    for kind, amount in pairs(cost) do
        if account.reserved[kind] == nil or not validNumber(amount) or account.reserved[kind] < amount then return false end
    end
    for kind, amount in pairs(cost) do account.reserved[kind] = account.reserved[kind] - amount end
    return true
end

function Build.CanCredit(account, kind)
    return account.total[kind] ~= nil and account.total[kind] < Build.Cap
end

function Build.Credit(account, kind)
    if not Build.CanCredit(account, kind) then return false end
    account.total[kind] = account.total[kind] + 1
    return true
end

return Build
