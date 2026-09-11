-- Manual, local engine integration test. Run on a disposable solo map:
-- lua_openscript ufg/tests/smoke.lua
-- Writes data/gmod_factory/smoke_result.json, restores progress, and exits GMod.
if not SERVER or not game.SinglePlayer() then error("Run this test in native single-player") end
assert(GF and WireLib, "Load Untitled Factory Gamemode with Wiremod first")

local results, spawned = {}, {}
local terrain = {}
local originalBuildAccount, testOwner
local originalMakeStock = GF.MakeStock
local originalContract = table.Copy(GF.Contract)
local finished = false

local function check(condition, description)
    if not condition then error(description) end
    results[#results + 1] = description
    print("[UFG TEST] PASS: " .. description)
end

local function track(ent)
    if IsValid(ent) then
        spawned[#spawned + 1] = ent
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
    end
    return ent
end

local function finish(ok, message)
    if finished then return end
    finished = true
    GF.MakeStock = originalMakeStock
    timer.Remove("ufg_smoke_wait")
    for _, ent in ipairs(spawned) do
        GF.RefundBuild(ent)
        if IsValid(ent) then ent:Remove() end
    end
    if originalBuildAccount then
        GF.BuildAccounts[testOwner] = originalBuildAccount
        GF.SaveBuildAccounts()
        GF.PublishBuildAccount(testOwner)
    end
    GF.Contract = originalContract
    GF.PublishContract()
    GF.SaveContract()
    local result = {ok = ok, message = message or "Completed", checks = results, terrain = terrain, version = VERSIONSTR}
    file.Write("gmod_factory/smoke_result.json", util.TableToJSON(result, true))
    print("[UFG TEST] " .. (ok and "SUCCESS" or "FAILED") .. ": " .. (message or "Completed"))
    timer.Simple(1, function() game.ConsoleCommand("quit\n") end)
end

local function guard(fn)
    local thread = coroutine.create(fn)
    local function resume()
        if finished then return end
        local ok, delay = coroutine.resume(thread)
        if not ok then finish(false, debug.traceback(thread, tostring(delay)))
        elseif coroutine.status(thread) ~= "dead" then timer.Simple(delay or 0.05, resume) end
    end
    resume()
end

local function pulse(ent, input)
    -- Wire limits repeated input callbacks within one tick. Separate test actions.
    coroutine.yield(0.05)
    WireLib.TriggerInput(ent, input, 0)
    WireLib.TriggerInput(ent, input, 1)
end

local function findGround(ply)
    local soil, concrete
    -- A bounded, test-only survey. Gameplay traces only beneath each extractor.
    for x = -3072, 3072, 256 do
        for y = -3072, 3072, 256 do
            local origin = ply:GetPos() + Vector(x, y, 1024)
            local trace = util.TraceLine({start = origin, endpos = origin - Vector(0, 0, 4096),
                filter = ply, mask = MASK_SOLID})
            if GF.CheckSoilTrace(trace) then
                local outlet = trace.HitPos + Vector(40, 0, 18)
                local clearance = util.TraceHull({start = outlet, endpos = outlet,
                    mins = Vector(-10, -10, -10), maxs = Vector(10, 10, 10), mask = MASK_SOLID})
                local clear = not clearance.Hit
                for _, offset in ipairs({Vector(0, 0, 18), Vector(150, 0, 82), Vector(300, 0, 82),
                    Vector(450, 0, 82), Vector(150, 160, 98)}) do
                    local point = trace.HitPos + offset
                    local space = util.TraceHull({start = point, endpos = point,
                        mins = Vector(-18, -18, -18), maxs = Vector(18, 18, 18), mask = MASK_SOLID})
                    if space.Hit or not util.IsInWorld(point) then clear = false end
                end
                if clear then soil = soil or trace end
            end
            if trace.HitWorld and trace.MatType == MAT_CONCRETE and trace.HitNormal.z > 0.8 then concrete = trace end
            if soil and concrete then return soil, concrete end
        end
    end
    return soil, concrete
end

local function start(ply)
    local account, owner = GF.GetBuildAccount(ply)
    originalBuildAccount, testOwner = table.Copy(account), owner
    GF.BuildAccounts[owner] = GF.Build.NewAccount()
    for _, filename in ipairs({"soil-separator-controller.txt", "press-controller.txt"}) do
        local example = file.Read("addons/untitled_factory_gamemode/examples/" .. filename, "GAME")
        check(example ~= nil, filename .. " is available")
        local compiled, compileError = E2Lib.compileScript(example, ply)
        check(compiled, filename .. " compiles in E2: " .. (compiled and "OK" or tostring(compileError)))
    end
    local ground, concrete = findGround(ply)
    check(ground and concrete, "Survey finds real soil and concrete on the map")
    local allowed, reason, surface = GF.CheckSoilTrace(ground)
    terrain = {material = ground.HitTexture, materialType = ground.MatType, surface = surface, reason = reason}
    check(allowed and not GF.CheckSoilTrace(concrete), "Soil accepted and concrete rejected using real engine traces")
    check(not GF.Machines.gf_feeder and not GF.Machines.gf_press, "Tier 0 has no free-blank production path")

    local position = ground.HitPos + Vector(0, 0, 18)
    local extractor = track(GF.SpawnMachine(ply, "gf_extractor", position, angle_zero))
    local separator = track(GF.SpawnMachine(ply, "gf_separator", position + Vector(150, 0, 64), angle_zero))
    local uplink = track(GF.SpawnMachine(ply, "gf_dispatch", position + Vector(300, 0, 64), angle_zero))
    local hub = track(GF.SpawnMachine(ply, "gf_hub", position + Vector(450, 0, 64), angle_zero))
    check(IsValid(extractor) and IsValid(separator) and IsValid(uplink) and IsValid(hub), "Bootstrap funds all four Tier 0 machines")
    local balance = GF.GetBuildAccount(ply)
    check(GF.Build.Available(balance, "gravel") == 14 and GF.Build.Available(balance, "mineral") == 22,
        "Starter hardware reserves its exact construction cost")
    check(IsValid(separator:GetPhysicsObject()), "Separator has real physics")
    check(extractor.Inputs.Extract and separator.Inputs.Resource and separator.Outputs.Mineral and uplink.Outputs.Target,
        "Installed Wiremod registers extraction, selection, inventory and order ports")
    local initialCount = GF.StockCount()
    extractor:MachineTick(CurTime())
    check(GF.StockCount() == initialCount and extractor.Outputs.Ground.Value == 1, "Idle extractor reports soil without producing")
    extractor:SetPos(concrete.HitPos + Vector(0, 0, 18))
    pulse(extractor, "Extract")
    check(GF.StockCount() == initialCount, "Extract pulse on concrete produces nothing")
    extractor:SetPos(position + Vector(0, 0, 200))
    pulse(extractor, "Extract")
    check(GF.StockCount() == initialCount, "Extractor cannot mine distant ground")
    extractor:SetPos(position)
    extractor:SetAngles(Angle(90, 0, 0))
    pulse(extractor, "Extract")
    check(GF.StockCount() == initialCount, "Tipped extractor produces nothing")
    extractor:SetAngles(angle_zero)

    local obstruction = track(ents.Create("prop_physics"))
    obstruction:SetModel("models/hunter/blocks/cube05x05x05.mdl")
    obstruction:SetPos(ground.HitPos + Vector(0, 0, 3))
    obstruction:Spawn()
    obstruction:GetPhysicsObject():EnableMotion(false)
    pulse(extractor, "Extract")
    check(GF.StockCount() == initialCount and not GF.ExtractorGround(extractor), "A prop covering soil blocks extraction")
    obstruction:SetPos(position + Vector(0, 160, 80))
    pulse(extractor, "Extract")
    local soil, soilKind = GF.FindStock(extractor:LocalToWorld(extractor.Outlet), 18)
    track(soil)
    local groundReady, groundReason = GF.ExtractorGround(extractor)
    check(IsValid(soil) and soilKind == "soil", "Wire pulse mines soil (ground=" .. tostring(groundReady) ..
        ", blocked=" .. tostring(extractor:OutletBlocked()) .. ", reason=" .. groundReason .. ")")
    WireLib.TriggerInput(extractor, "Extract", 1)
    check(GF.StockCount() == initialCount + 1, "Held-high Extract does not repeat")
    soil:SetPos(separator:LocalToWorld(separator.Inlet))
    pulse(separator, "Load")
    check(not GF.LiveStock[soil] and separator.GFState.soil, "Load claims the physical soil parcel exactly once")
    pulse(extractor, "Extract")
    check(GF.StockCount() == initialCount, "Fresh pulse during extractor cooldown produces nothing")
    pulse(separator, "Cycle")
    pulse(separator, "Reset")
    check(separator.GFState.soil and not separator.GFState.busy, "Reset preserves the unfinished soil")
    pulse(separator, "Cycle")
    check(separator.GFState.busy, "Wire starts the separation cycle")

    local copyData = duplicator.CopyEntTable(separator)
    copyData.Pos = position + Vector(150, 160, 80)
    local copy = track(duplicator.CreateEntityFromTable(ply, copyData))
    check(IsValid(copy) and not copy.GFState.soil and not copy.GFState.busy and copy.GFState:Pending() == 0,
        "Duplicated working separator starts empty")

    timer.Simple(4.3, function() guard(function()
        separator:MachineTick(CurTime())
        local state = separator.GFState
        check(state:Pending() == 4 and separator.Outputs.Done.Value == 1 and not state.soil,
            "Real engine cycle yields all four fractions")
        check(GF.StockCount() == initialCount and separator.Outputs.CanLoad.Value == 0,
            "Finished batch waits for commands and blocks another load")
        WireLib.TriggerInput(separator, "Resource", 11)
        obstruction:SetPos(separator:LocalToWorld(separator.Outlet))
        pulse(separator, "Eject")
        check(state.fault == 3 and state:Pending() == 4, "Blocked outlet preserves all fractions")
        obstruction:SetPos(position + Vector(0, 160, 80))
        pulse(separator, "Reset")
        local makeStock = GF.MakeStock
        GF.MakeStock = function() return nil end
        pulse(separator, "Eject")
        GF.MakeStock = makeStock
        check(state:Pending() == 4, "Failed entity creation preserves selected fraction")

        local function eject(resource, expected)
            WireLib.TriggerInput(separator, "Resource", resource)
            pulse(separator, "Eject")
            local stock, kind = GF.FindStock(separator:LocalToWorld(separator.Outlet), 18)
            track(stock)
            check(IsValid(stock) and kind == expected, "Resource selection ejects " .. expected)
            return stock
        end

        local sand = eject(12, "sand")
        sand:SetPos(uplink:LocalToWorld(uplink.Inlet))
        GF.Contract = GF.Logic.NewContract({order = 1, delivered = 9, favor = 0})
        pulse(uplink, "Submit")
        check(GF.LiveStock[sand] == "sand" and uplink.GFRejected == 1 and GF.Contract.delivered == 9,
            "Wrong-order resource remains available for future use")
        sand:SetPos(position + Vector(300, 160, 80))
        check(not IsValid(duplicator.CreateEntityFromTable(ply, duplicator.CopyEntTable(sand))), "Raw resources cannot be duplicated")
        local gravel = eject(11, "gravel")
        gravel:SetPos(uplink:LocalToWorld(uplink.Inlet))
        uplink.GFNextSubmit = 0 -- Exercise material identity independently of cooldown.
        pulse(uplink, "Submit")
        check(not GF.LiveStock[gravel] and uplink.GFAccepted == 1, "Uplink claims the requested gravel once")
        uplink:MachineTick(CurTime())
        check(GF.Contract.order == 2 and GF.Contract.favor == 100 and uplink.Outputs.Target.Value == 12 and
            GetGlobalString("gf_target") == "sand", "Completed gravel order advances to sand and publishes the new target")
        local saved = util.JSONToTable(file.Read("gmod_factory/tier0_solo_" .. game.GetMap() .. ".json", "DATA"))
        check(saved.order == 2 and saved.favor == 100, "Tier 0 contract persists through the real file API")
        uplink.GFNextSubmit = 0
        pulse(uplink, "Submit")
        check(GF.Contract.delivered == 0 and uplink.GFAccepted == 1, "Repeated submission cannot credit removed gravel")
        local clay = eject(13, "clay")
        clay:SetPos(position + Vector(450, 160, 80))
        local mineral = eject(14, "mineral")
        mineral:SetPos(position + Vector(600, 160, 80))
        check(state:CanLoad() and state:Pending() == 0, "Collecting every fraction unlocks the next batch")
        sand:SetPos(separator:LocalToWorld(separator.Inlet))
        pulse(separator, "Load")
        check(state.fault == 2 and GF.LiveStock[sand] == "sand", "Separator refuses to consume processed resources")
        sand:SetPos(hub:LocalToWorld(hub.Inlet))
        local before = balance.total.sand
        pulse(hub, "Deposit")
        check(not GF.LiveStock[sand] and balance.total.sand == before + 1 and hub.GFAccepted == 1,
            "Hub consumes one separated parcel and credits its builder's reserve")
        hub.GFNextDeposit = 0
        pulse(hub, "Deposit")
        check(balance.total.sand == before + 1, "Repeated hub deposit cannot credit consumed stock")
        local savedBuild = util.JSONToTable(file.Read("gmod_factory/build_solo_" .. game.GetMap() .. ".json", "DATA"), false, true)
        check(savedBuild[owner].sand == balance.total.sand, "Personal resources persist without a second bootstrap grant")

        local prop = track(ents.Create("prop_physics"))
        prop:SetModel("models/hunter/blocks/cube05x05x05.mdl")
        prop:SetPos(position + Vector(0, 400, 80))
        prop:Spawn()
        local available = GF.Build.Available(balance, "gravel")
        ply:AddCount("props", prop)
        ply:AddCount("gf_test_extra", prop)
        check(GF.Build.Available(balance, "gravel") == available - 1, "Sandbox AddCount charges a prop once across count categories")
        prop:Remove()
        timer.Simple(0.1, function() guard(function()
            check(GF.Build.Available(balance, "gravel") == available, "Engine removal returns the prop's cost")
            GF.RefundBuild(prop)
            check(GF.Build.Available(balance, "gravel") == available, "Repeated refund does not mint construction resources")
            local wireSand, wireMineral = GF.Build.Available(balance, "sand"), GF.Build.Available(balance, "mineral")
            local chip = track(MakeWireExpression2(ply, position + Vector(0, 500, 80), angle_zero,
                "models/beer/wiremod/gate_e2.mdl"))
            check(IsValid(chip) and GF.Build.Available(balance, "sand") == wireSand - 1 and
                GF.Build.Available(balance, "mineral") == wireMineral - 1, "Actual E2 chip construction pays the Wire device price")
            local retained = GF.BuildAccounts[owner]
            GF.BuildAccounts[owner] = GF.Build.NewAccount({})
            local denied = GF.SpawnMachine(ply, "gf_extractor", position + Vector(0, 600, 80), angle_zero)
            GF.BuildAccounts[owner] = retained
            check(not IsValid(denied), "An empty construction reserve cannot spawn hardware")
            finish(true)
        end) end)
    end) end)
end

timer.Create("ufg_smoke_wait", 1, 30, function()
    local ply = player.GetAll()[1]
    if IsValid(ply) then
        timer.Remove("ufg_smoke_wait")
        guard(function() start(ply) end)
    end
end)
timer.Simple(40, function() if not finished then finish(false, "Timed out waiting for the local player") end end)
