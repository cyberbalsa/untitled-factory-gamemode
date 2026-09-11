local build = GF.Build
local savePath = "gmod_factory/build_" .. (game.SinglePlayer() and "solo_" or "coop_") .. game.GetMap() .. ".json"
-- SteamID64 keys must remain strings; converting them to Lua numbers loses identity.
local saved = util.JSONToTable(file.Read(savePath, "DATA") or "{}", false, true)
GF.BuildAccounts = GF.BuildAccounts or {}
GF.BuildReceipts = GF.BuildReceipts or {} -- Server ledger; never copied into duplicator data.
for id, total in pairs(type(saved) == "table" and saved or {}) do
    if type(id) == "string" and not GF.BuildAccounts[id] then GF.BuildAccounts[id] = build.NewAccount(total) end
end

function GF.SaveBuildAccounts()
    local totals = {}
    for id, account in pairs(GF.BuildAccounts) do totals[id] = account.total end
    file.CreateDir("gmod_factory")
    file.Write(savePath, util.TableToJSON(totals, true))
end

function GF.GetBuildAccount(owner)
    local id = type(owner) == "string" and owner or IsValid(owner) and owner:SteamID64()
    if not id then return end
    if not GF.BuildAccounts[id] then
        GF.BuildAccounts[id] = build.NewAccount()
        GF.SaveBuildAccounts()
    end
    return GF.BuildAccounts[id], id
end

function GF.PublishBuildAccount(owner)
    local account, id = GF.GetBuildAccount(owner)
    if not account then return end
    local ply = player.GetBySteamID64(id)
    if not IsValid(ply) then return end
    for _, kind in ipairs(build.Kinds) do ply:SetNWInt("gf_res_" .. kind, build.Available(account, kind)) end
end

function GF.BuildCostText(cost)
    local parts = {}
    for _, kind in ipairs(build.Kinds) do
        if cost[kind] then parts[#parts + 1] = cost[kind] .. " " .. GF.StockLabels[kind] end
    end
    return table.concat(parts, ", ")
end

function GF.CanBuild(ply, cost, notify)
    local account = GF.GetBuildAccount(ply)
    if not account then return false end
    if build.CanAfford(account, cost) then return true end
    if notify and (ply.GFNextBuildNotice or 0) <= CurTime() then
        ply.GFNextBuildNotice = CurTime() + 1
        ply:ChatPrint("Construction reserve too low. Cost: " .. GF.BuildCostText(cost) .. ". Feed raw resources into your hub.")
    end
    return false
end

function GF.PayForBuild(ply, ent)
    if not IsValid(ply) or not IsValid(ent) or ent:IsMarkedForDeletion() then return false end
    if ent:GetClass() == "gf_stock" or GF.BuildReceipts[ent] then return true end
    local cost = table.Copy(build.Cost(ent:GetClass()))
    if not GF.CanBuild(ply, cost, true) then ent:Remove() return false end
    local account, id = GF.GetBuildAccount(ply)
    if not build.Reserve(account, cost) then ent:Remove() return false end
    GF.BuildReceipts[ent] = {owner = id, cost = cost}
    GF.PublishBuildAccount(id)
    return true
end

function GF.RefundBuild(ent)
    local receipt = GF.BuildReceipts[ent]
    if not receipt then return end
    GF.BuildReceipts[ent] = nil -- Claim once, even if cleanup callbacks run again.
    local account = GF.GetBuildAccount(receipt.owner)
    build.Release(account, receipt.cost)
    GF.PublishBuildAccount(receipt.owner)
end

hook.Add("EntityRemoved", "gf_build_refund", GF.RefundBuild)
hook.Add("PlayerInitialSpawn", "gf_build_account", function(ply) GF.PublishBuildAccount(ply) end)

-- Sandbox props, duplicator entities, and Wire devices (including gates/E2) register
-- through AddCount. Charge per entity once, even when it has multiple count types.
local playerMeta = FindMetaTable("Player")
GF.OriginalAddCount = GF.OriginalAddCount or playerMeta.AddCount
function playerMeta:AddCount(category, ent)
    if not GF.PayForBuild(self, ent) then return end
    return GF.OriginalAddCount(self, category, ent)
end

hook.Add("PlayerSpawnProp", "gf_prop_budget", function(ply)
    if not GF.CanBuild(ply, build.PropCost, true) then return false end
end)
hook.Add("PlayerSpawnSENT", "gf_entity_budget", function(ply, class)
    if not GF.CanBuild(ply, build.Cost(class), true) then return false end
end)

concommand.Add("gf_resources", function(ply)
    if not IsValid(ply) then return end
    local account = GF.GetBuildAccount(ply)
    for _, kind in ipairs(build.Kinds) do
        ply:PrintMessage(HUD_PRINTCONSOLE, string.format("%s: %d available / %d owned\n", GF.StockLabels[kind],
            build.Available(account, kind), account.total[kind]))
    end
    for _, class in ipairs(GF.StarterClasses) do
        ply:PrintMessage(HUD_PRINTCONSOLE, class .. ": " .. GF.BuildCostText(build.Cost(class)) .. "\n")
    end
end)
