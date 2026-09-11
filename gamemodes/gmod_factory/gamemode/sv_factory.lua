util.AddNetworkString("gf_help")
resource.AddWorkshop("160250458")

local machineLimit = CreateConVar("sbox_maxgf_machines", "24", FCVAR_ARCHIVE, "Factory machines per player", 1, 128)
local stockLimit = CreateConVar("gf_max_stock", "128", FCVAR_ARCHIVE, "Maximum loose factory items", 8, 512)
cleanup.Register("gf_machines")
GF.LiveStock = GF.LiveStock or {}

-- Preserve earlier component-prototype saves; Tier 0 has different order contents.
local savePath = "gmod_factory/tier0_" .. (game.SinglePlayer() and "solo_" or "coop_") .. game.GetMap() .. ".json"
local saved = file.Read(savePath, "DATA")
GF.Contract = GF.Logic.NewContract(saved and util.JSONToTable(saved))

function GF.PublishContract()
    SetGlobalInt("gf_order", GF.Contract.order)
    SetGlobalInt("gf_delivered", GF.Contract.delivered)
    SetGlobalInt("gf_required", GF.Logic.Quota(GF.Contract.order))
    SetGlobalInt("gf_favor", GF.Contract.favor)
    SetGlobalString("gf_target", GF.Logic.OrderResource(GF.Contract.order))
end

function GF.SaveContract()
    file.CreateDir("gmod_factory")
    file.Write(savePath, util.TableToJSON(GF.Contract, true))
end

function GF.Deliver(kind)
    if kind ~= GF.Logic.OrderResource(GF.Contract.order) then return false end
    local completed = GF.Logic.Deliver(GF.Contract, kind)
    GF.PublishContract()
    GF.SaveContract()
    if completed then
        for _, ply in ipairs(player.GetAll()) do
            ply:ChatPrint("DIRECTIVE: Shipment accepted. +100 favor. Your next order has arrived.")
        end
    end
    return true
end

GF.PublishContract()

function GF.StockCount()
    local count = 0
    for ent in pairs(GF.LiveStock) do
        if IsValid(ent) then count = count + 1 else GF.LiveStock[ent] = nil end
    end
    return count
end

function GF.CanMakeStock()
    return GF.StockCount() < stockLimit:GetInt()
end

function GF.MakeStock(kind, position, angles, owner)
    if not GF.StockKinds[kind] or not GF.CanMakeStock() then return end
    local ent = ents.Create("gf_stock")
    if not IsValid(ent) then return end
    ent:SetPos(position)
    ent:SetAngles(angles)
    ent:Spawn()
    if not IsValid(ent) then return end
    GF.LiveStock[ent] = kind
    ent:SetNWString("gf_kind", kind)
    local resource = GF.Tier0.Resources[kind]
    local color = resource and resource.color or {120, 150, 165}
    ent:SetColor(Color(color[1], color[2], color[3]))
    if IsValid(owner) then
        ent:SetCreator(owner)
        owner:AddCleanup("gf_machines", ent)
    end
    return ent
end

function GF.TakeStock(ent)
    local kind = GF.LiveStock[ent]
    if not IsValid(ent) or not kind then return end
    GF.LiveStock[ent] = nil -- Claim before callbacks can observe it again.
    ent:Remove()
    return kind
end

function GF.FindStock(position, radius)
    local nearest, distance
    for _, ent in ipairs(ents.FindInSphere(position, radius)) do
        if GF.LiveStock[ent] then
            local candidate = ent:GetPos():DistToSqr(position)
            if not distance or candidate < distance then nearest, distance = ent, candidate end
        end
    end
    return nearest, GF.LiveStock[nearest]
end

function GF.SpawnMachine(ply, class, position, angles)
    if not GF.Machines[class] or not IsValid(ply) then return end
    if not GF.CanBuild(ply, GF.Build.Cost(class), true) then return end
    if not WireLib then ply:ChatPrint("Untitled Factory Gamemode requires Wiremod. Enable it and reload the map.") return end
    if ply:GetCount("gf_machines") >= machineLimit:GetInt() then
        ply:ChatPrint("Factory machine limit reached.") return
    end
    local trace = util.TraceHull({start = position, endpos = position,
        mins = Vector(-16, -16, -16), maxs = Vector(16, 16, 16), filter = ply, mask = MASK_SOLID})
    if trace.Hit or not util.IsInWorld(position) then
        ply:ChatPrint("Machine placement obstructed. Choose a clear space.") return
    end
    local ent = ents.Create(class)
    if not IsValid(ent) then return end
    if not GF.PayForBuild(ply, ent) then return end
    ent:SetPos(position)
    ent:SetAngles(angles)
    ent:SetPlayer(ply)
    ent:SetCreator(ply)
    ent:Spawn()
    ent:Activate()
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
    ply:AddCount("gf_machines", ent)
    ply:AddCleanup("gf_machines", ent)
    return ent
end

for class in pairs(GF.Machines) do
    local machineClass = class
    duplicator.RegisterEntityClass(class, function(ply, data)
        -- A blueprint creates empty hardware; production state is never duplicated.
        return GF.SpawnMachine(ply, machineClass, data.Pos, data.Angle)
    end, "Data")
end
duplicator.RegisterEntityClass("gf_stock", function() return nil end, "Data")

concommand.Add("gf_starterkit", function(ply)
    if not IsValid(ply) or (ply.GFNextKit or 0) > CurTime() then return end
    ply.GFNextKit = CurTime() + 5
    local trace = ply:GetEyeTrace()
    if not trace.Hit or trace.HitSky or trace.HitNormal.z < 0.8 or trace.HitPos:DistToSqr(ply:GetPos()) > 600 * 600 then
        ply:ChatPrint("Look at clear, level ground within 600 units, then run gf_starterkit.") return
    end
    local angle = Angle(0, ply:EyeAngles().y + 90, 0)
    local soil, reason = GF.CheckSoilTrace(trace)
    if not soil then ply:ChatPrint("Place the starter extractor on soil: " .. reason .. ". Use gf_ground to survey.") return end
    local total = {}
    for _, class in ipairs(GF.StarterClasses) do
        for kind, amount in pairs(GF.Build.Cost(class)) do total[kind] = (total[kind] or 0) + amount end
    end
    if not GF.CanBuild(ply, total, true) then return end
    local built = 0
    undo.Create("Factory starter kit")
    for index, class in ipairs(GF.StarterClasses) do
        local origin = trace.HitPos + angle:Forward() * ((index - 1) * 160)
        local ground = util.TraceLine({start = origin + Vector(0, 0, 32), endpos = origin - Vector(0, 0, 64), filter = ply})
        if ground.Hit and ground.HitNormal.z >= 0.8 then
            local ent = GF.SpawnMachine(ply, class, ground.HitPos + Vector(0, 0, 18), angle)
            if IsValid(ent) then undo.AddEntity(ent) built = built + 1 end
        end
    end
    undo.SetPlayer(ply)
    undo.Finish()
    ply:ChatPrint("Built " .. built .. "/4 starter machines from your reserve. Extract soil and feed your hub to expand. F1: briefing.")
end)

function GM:ShowHelp(ply)
    net.Start("gf_help")
    net.Send(ply)
end

hook.Add("InitPostEntity", "gf_dependency", function()
    SetGlobalBool("gf_wire_ready", WireLib ~= nil)
    if not WireLib then ErrorNoHalt("[Untitled Factory Gamemode] Wiremod is required. Enable it and reload the map.\n") end
end)

hook.Add("PlayerInitialSpawn", "gf_welcome", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then ply:ChatPrint("DIRECTIVE: Your labor has been requisitioned. Press F1 for your assignment.") end
    end)
end)
