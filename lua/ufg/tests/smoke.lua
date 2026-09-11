-- Manual, local engine integration test. Run on a disposable solo map:
-- lua_openscript ufg/tests/smoke.lua
-- Writes data/gmod_factory/smoke_result.json, restores progress, and exits GMod.
if not SERVER or not game.SinglePlayer() then error("Run this test in native single-player") end
assert(GF and WireLib, "Load Untitled Factory Gamemode with Wiremod first")

local results, spawned = {}, {}
local originalContract = table.Copy(GF.Contract)
local finished = false

local function check(condition, description)
    if not condition then error(description) end
    results[#results + 1] = description
    print("[UFG TEST] PASS: " .. description)
end

local function track(ent)
    if IsValid(ent) then spawned[#spawned + 1] = ent end
    return ent
end

local function finish(ok, message)
    if finished then return end
    finished = true
    timer.Remove("ufg_smoke_wait")
    for _, ent in ipairs(spawned) do if IsValid(ent) then ent:Remove() end end
    GF.Contract = originalContract
    GF.PublishContract()
    GF.SaveContract()
    local result = {ok = ok, message = message or "Completed", checks = results, version = VERSIONSTR}
    file.Write("gmod_factory/smoke_result.json", util.TableToJSON(result, true))
    print("[UFG TEST] " .. (ok and "SUCCESS" or "FAILED") .. ": " .. (message or "Completed"))
    timer.Simple(1, function() game.ConsoleCommand("quit\n") end)
end

local function guard(fn)
    local ok, message = xpcall(fn, debug.traceback)
    if not ok then finish(false, message) end
end

local function pulse(ent, input)
    WireLib.TriggerInput(ent, input, 0)
    WireLib.TriggerInput(ent, input, 1)
end

local function start(ply)
    local example = file.Read("addons/untitled_factory_gamemode/examples/press-controller.txt", "GAME")
    check(example ~= nil, "Example E2 source is available")
    local compiled, compileError = E2Lib.compileScript(example, ply)
    check(compiled, "Example controller compiles in installed Expression 2: " .. (compiled and "OK" or tostring(compileError)))
    local position = ply:GetPos() + Vector(0, 120, 40)
    local feeder = track(GF.SpawnMachine(ply, "gf_feeder", position, angle_zero))
    local press = track(GF.SpawnMachine(ply, "gf_press", position + Vector(150, 0, 0), angle_zero))
    local uplink = track(GF.SpawnMachine(ply, "gf_dispatch", position + Vector(300, 0, 0), angle_zero))
    check(IsValid(feeder) and IsValid(press) and IsValid(uplink), "All three machines spawn with real physics")
    check(IsValid(press:GetPhysicsObject()), "Press has a valid physics object")
    check(press.Inputs.Cycle and press.Outputs.Ready, "Installed Wiremod registers the machine ports")
    check(not feeder:OutletBlocked(), "Feeder dock is clear")

    pulse(feeder, "Dispense")
    local blank = track(GF.FindStock(feeder:LocalToWorld(feeder.Outlet), 18))
    check(IsValid(blank), "Wire pulse dispenses a physical blank")
    local count = GF.StockCount()
    WireLib.TriggerInput(feeder, "Dispense", 1)
    check(GF.StockCount() == count, "Held-high Dispense does not manufacture another item")
    blank:SetPos(press:LocalToWorld(press.Inlet))
    pulse(press, "Load")
    check(not GF.LiveStock[blank] and press.GFState.item == "blank", "Press claims only the physical blank at its dock (state=" ..
        tostring(press.GFState.item) .. ", fault=" .. press.GFState.fault .. ")")
    pulse(press, "Cycle")
    check(press.GFState.fault == 3, "Unclamped cycle faults")
    pulse(press, "Reset")
    WireLib.TriggerInput(press, "Clamp", 1)
    pulse(press, "Cycle")
    check(press.GFState.busy, "Wire starts a clamped cycle")
    WireLib.TriggerInput(press, "Clamp", 0)
    check(press.GFState.fault == 5 and press.GFState.item == "blank", "Clamp release interrupts without a free component")
    pulse(press, "Reset")
    WireLib.TriggerInput(press, "Clamp", 1)
    pulse(press, "Cycle")

    local copyData = duplicator.CopyEntTable(press)
    copyData.Pos = position + Vector(150, 140, 0)
    local copy = track(duplicator.CreateEntityFromTable(ply, copyData))
    check(IsValid(copy) and not copy.GFState.item and not copy.GFState.busy, "Duplicated working hardware starts empty")

    timer.Simple(3.3, function() guard(function()
        press:MachineTick(CurTime())
        check(press.GFState.done and press.Outputs.Done.Value == 1, "Real engine timer finishes the cycle and publishes Done")
        pulse(press, "Eject")
        check(press.GFState.fault == 2, "Closed clamp prevents ejection")
        WireLib.TriggerInput(press, "Clamp", 0)
        pulse(press, "Reset")
        local obstruction = track(ents.Create("prop_physics"))
        obstruction:SetModel("models/hunter/blocks/cube05x05x05.mdl")
        obstruction:SetPos(press:LocalToWorld(press.Outlet))
        obstruction:Spawn()
        pulse(press, "Eject")
        check(press.GFState.fault == 6 and press.GFState.item == "component", "Physical outlet obstruction preserves the completed item")
        obstruction:Remove()
        pulse(press, "Reset")
        pulse(press, "Eject")
        local component, kind = GF.FindStock(press:LocalToWorld(press.Outlet), 18)
        track(component)
        check(IsValid(component) and kind == "component" and not press.GFState.item, "Eject commits exactly one physical component")
        check(not IsValid(duplicator.CreateEntityFromTable(ply, duplicator.CopyEntTable(component))), "Stock cannot be duplicated")
        component:SetPos(uplink:LocalToWorld(uplink.Inlet))
        GF.Contract = GF.Logic.NewContract({order = 1, delivered = 9, favor = 0})
        pulse(uplink, "Submit")
        check(not GF.LiveStock[component] and uplink.GFAccepted == 1, "Submission consumes one real component")
        check(GF.Contract.order == 2 and GF.Contract.favor == 100, "Completing an order advances shared progression")
        local saved = util.JSONToTable(file.Read("gmod_factory/solo_" .. game.GetMap() .. ".json", "DATA"))
        check(saved.order == 2 and saved.favor == 100, "Contract is saved through GMod's actual file API")
        pulse(uplink, "Submit")
        check(GF.Contract.delivered == 0 and uplink.GFAccepted == 1, "Repeated Submit cannot credit the removed component")
        finish(true)
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
