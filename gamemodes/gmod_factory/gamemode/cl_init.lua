include("shared.lua")

local ink = Color(13, 21, 29, 235)
local accent = Color(90, 230, 185)
local muted = Color(170, 185, 195)
local white = Color(232, 239, 243)

surface.CreateFont("GFTitle", {font = "Roboto", size = 22, weight = 700})
surface.CreateFont("GFBody", {font = "Roboto", size = 17, weight = 400})
surface.CreateFont("GFSmall", {font = "Roboto", size = 14, weight = 500})

hook.Add("HUDPaint", "gf_directive", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local width = math.min(370, ScrW() - 32)
    local x, y = ScrW() - width - 16, 20
    local required = GetGlobalInt("gf_required", 10)
    local delivered = GetGlobalInt("gf_delivered", 0)
    local target = GetGlobalString("gf_target", "gravel")
    draw.RoundedBox(5, x, y, width, 144, ink)
    surface.SetDrawColor(accent)
    surface.DrawRect(x, y, 3, 144)
    draw.SimpleText("OFFICE OF PRODUCTIVE LABOR", "GFSmall", x + 16, y + 13, accent)
    draw.SimpleText("DIRECTIVE " .. string.format("%03d", GetGlobalInt("gf_order", 1)), "GFTitle", x + 16, y + 34, white)
    draw.SimpleText(delivered .. " / " .. required .. " " .. (GF.StockLabels[target] or target), "GFBody", x + 16, y + 66, white)
    surface.SetDrawColor(42, 61, 72)
    surface.DrawRect(x + 16, y + 94, width - 32, 4)
    surface.SetDrawColor(accent)
    surface.DrawRect(x + 16, y + 94, (width - 32) * math.Clamp(delivered / math.max(1, required), 0, 1), 4)
    draw.SimpleText("Favor " .. GetGlobalInt("gf_favor", 0) .. "   /   F1: briefing", "GFSmall", x + 16, y + 113, muted)

    local reserveY = ScrH() - 200
    draw.RoundedBox(5, 16, reserveY, 345, 88, ink)
    draw.SimpleText("PERSONAL CONSTRUCTION RESERVE", "GFSmall", 30, reserveY + 10, accent)
    draw.SimpleText("Gravel " .. ply:GetNWInt("gf_res_gravel", 0) .. "    Sand " .. ply:GetNWInt("gf_res_sand", 0),
        "GFBody", 30, reserveY + 32, white)
    draw.SimpleText("Clay " .. ply:GetNWInt("gf_res_clay", 0) .. "    Concentrate " .. ply:GetNWInt("gf_res_mineral", 0),
        "GFBody", 30, reserveY + 57, white)

    if not GetGlobalBool("gf_wire_ready", false) then
        draw.RoundedBox(5, x, y + 154, width, 60, ink)
        draw.SimpleText("Wiremod is required", "GFBody", x + 16, y + 164, Color(255, 180, 90))
        draw.SimpleText("Enable Wiremod, then reload the map.", "GFSmall", x + 16, y + 189, white)
    end

    local ent = ply:GetEyeTrace().Entity
    if IsValid(ent) and ent:GetClass() == "gf_stock" and ply:GetPos():DistToSqr(ent:GetPos()) < 400 * 400 then
        local kind = ent:GetNWString("gf_kind", "")
        local label = string.upper(GF.StockLabels[kind] or "Unknown material")
        local purpose = kind == "soil" and " / Separate into raw resources" or kind == target and " / Requested for tribute" or " / Store for future orders"
        draw.SimpleText(label .. purpose,
            "GFBody", ScrW() / 2, ScrH() / 2 + 40, accent, TEXT_ALIGN_CENTER)
    end
end)

local briefing
local function showBriefing()
    if IsValid(briefing) then briefing:MakePopup() return end
    briefing = vgui.Create("DFrame")
    briefing:SetSize(math.min(760, ScrW() - 32), math.min(710, ScrH() - 32))
    briefing:Center()
    briefing:SetTitle("Untitled Factory Gamemode / Labor briefing")
    briefing:MakePopup()
    briefing.Paint = function(_, width, height) draw.RoundedBox(6, 0, 0, width, height, ink) end

    local kit = vgui.Create("DButton", briefing)
    kit:Dock(BOTTOM)
    kit:SetTall(42)
    kit:SetText("Build starter cell from your reserve (26 gravel, 12 sand, 10 clay, 18 concentrate)")
    kit.DoClick = function() briefing:Close() RunConsoleCommand("gf_starterkit") end

    local scroll = vgui.Create("DScrollPanel", briefing)
    scroll:Dock(FILL)
    scroll:DockMargin(16, 14, 16, 14)
    local text = vgui.Create("DLabel", scroll)
    text:Dock(TOP)
    text:SetFont("GFBody")
    text:SetTextColor(white)
    text:SetWrap(true)
    text:SetAutoStretchVertical(true)
    text:SetText([[Your overlords require raw resources. Your continued usefulness is under review.

TIER 0 / EVERYTHING STARTS IN THE DIRT

Look at clear grass or dirt before requesting starter hardware, or spawn machines from Q > Entities > Untitled Factory Gamemode. Keep the extractor upright and close to exposed ground. Its Ground output must be 1. The gf_ground console command surveys the surface under your crosshair.

1. Wire Extract on the soil extractor. Each pulse issues one soil parcel if Ground and Ready are 1. The extractor has a two-second cooldown.
2. Move soil from its green dock to the separator's amber dock. Build a chute, piston, grabber, or E2-controlled transport. Use the physgun while testing.
3. Pulse Load when CanLoad is 1, then Cycle when Ready is 1. After four seconds, Done becomes 1: gravel, sand, clay, and mineral concentrate are waiting inside.
4. Set Resource to 11, 12, 13, or 14. Pulse Eject for that fraction when Blocked is 0. Move each parcel clear and collect all four fractions before loading another batch.
5. Feed separated resources into your construction hub and pulse Deposit to grow your personal reserve. Any player can supply a hub; its builder receives the resources, even while offline.
6. The uplink's Target tells you which resource the overlords want. Move that resource to its amber dock and pulse Submit. Balance tribute against construction and storage.

PROGRAM THE FACTORY

Use Wire logic gates or Expression 2. Action inputs respond to a rising edge; holding an action high does not repeat it. Resource is a selection value. Read the outputs and wait for feedback before the next operation.

Resource IDs: 10 soil, 11 gravel, 12 sand, 13 clay, 14 mineral concentrate. Inlet 0 means empty. Target uses the same IDs.
Gravel, Sand, Clay, Mineral: quantities waiting inside. Pending: total fractions remaining.
Ground, CanLoad, Ready, Loaded, Busy, Done, Blocked: 0 or 1.
Progress: 0 to 100. Fault: 0 means operational.
If the separator faults, correct the cause and pulse Reset. Reset cancels processing but keeps the soil. Finished fractions survive Reset. To recover unprocessed soil, select Resource 10 and pulse Eject while idle.

COOPERATIVE LABOR

Everyone contributes to the same order. Order progress and favor save per map; solo and multiplayer have separate progress files. Contraptions and loose items are not automatically saved in this prototype. Duplicated machines start empty.

CONSTRUCTION RESERVE

Your one-time bootstrap is 40 gravel, 30 sand, 20 clay, and 40 concentrate per map and play mode. Death and reconnecting do not grant it again. The starter cell costs 26 / 12 / 10 / 18 respectively, leaving materials for props and Wire devices.

Hub: 8 gravel, 2 sand, 4 clay, 4 concentrate.
Extractor: 6 gravel, 2 sand, 4 concentrate.
Separator: 8 gravel, 4 sand, 4 clay, 6 concentrate.
Uplink: 4 gravel, 4 sand, 2 clay, 4 concentrate.
Ordinary counted build objects: 1 gravel each.
Wire devices, gates and E2 chips: 1 sand + 1 concentrate each.

Moving, rewiring and editing existing objects is free. Undo/removal releases their construction cost to the original builder. Duplicates require their own resources. Run gf_resources to inspect totals and prices. Spent materials remain reserved while the build exists; reload returns them because factory structures are not yet saved.

Prototype rules: renewable soil, limited loose items, no deadline or power requirement yet. Transfer rails are planned; the current docks use physical parcels. The first goal is a reliable unattended cell.]])
end

net.Receive("gf_help", showBriefing)
concommand.Add("gf_help", showBriefing)
