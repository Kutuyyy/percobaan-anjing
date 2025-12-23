-- Papi Dimz |HUB (All-in-One: Local Player + Fishing + Farm + Bring + Teleport + Original Features)
-- Versi: Fixed UI Loading Issue
-- WARNING: Use at your own risk.
---------------------------------------------------------
-- SERVICES
---------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
---------------------------------------------------------
-- UTIL: NON-BLOCKING FIND HELPERS
---------------------------------------------------------
local function findWithTimeout(parent, name, timeout, pollInterval)
    timeout = timeout or 6
    pollInterval = pollInterval or 0.25
    local t0 = tick()
    while tick() - t0 < timeout do
        local v = parent:FindFirstChild(name)
        if v then return v end
        task.wait(pollInterval)
    end
    return nil
end
local function backgroundFind(parent, name, callback, pollInterval)
    pollInterval = pollInterval or 0.5
    task.spawn(function()
        while true do
            local v = parent:FindFirstChild(name)
            if v then
                pcall(callback, v)
                break
            end
            task.wait(pollInterval)
        end
    end)
end
---------------------------------------------------------
-- LOAD WINDUI DENGAN ERROR HANDLING
---------------------------------------------------------
local WindUI = nil
local function createFallbackNotify(msg)
    print("[PapiDimz][FALLBACK NOTIFY] " .. tostring(msg))
end

local function safeLoadWindUI()
    local success, result = pcall(function()
        -- Coba beberapa sumber
        local sources = {
            "https://raw.githubusercontent.com/Footagesus/WindUI/main/WindUI.lua",
            "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
            "https://raw.githubusercontent.com/Footagesus/WindUI/releases/latest/download/main.lua"
        }
        
        for _, url in ipairs(sources) do
            local ok, content = pcall(function()
                return game:HttpGet(url, true)
            end)
            
            if ok and content then
                local loaded = loadstring(content)
                if loaded then
                    return loaded()
                end
            end
        end
        return nil
    end)
    
    if success and result then
        WindUI = result
        pcall(function()
            WindUI:SetTheme("Dark")
            WindUI.TransparencyValue = 0.2
        end)
        return true
    else
        warn("[UI] Gagal load WindUI dari semua sumber.")
        WindUI = nil
        return false
    end
end

-- Coba load WindUI
task.spawn(function()
    local uiLoaded = safeLoadWindUI()
    if not uiLoaded then
        warn("[UI] Menggunakan fallback UI minimal.")
        -- Fallback UI sederhana akan dibuat nanti
    end
end)
---------------------------------------------------------
-- STATE & CONFIG
---------------------------------------------------------
local scriptDisabled = false
-- Remotes / folders
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local RequestStartDragging, RequestStopDragging, CollectCoinRemote, ConsumeItemRemote, NightSkipRemote, ToolDamageRemote, EquipHandleRemote
local ItemsFolder = Workspace:FindFirstChild("Items")
local Structures = Workspace:FindFirstChild("Structures")
-- Original features state
local CookingStations = {}
local ScrapperTarget = nil
local MoveMode = "DragPivot"
local AutoCookEnabled = false
local CookLoopId = 0
local CookDelaySeconds = 10
local CookItemsPerCycle = 5
local SelectedCookItems = { "Carrot", "Corn" }
local ScrapEnabled = false
local ScrapLoopId = 0
local ScrapScanInterval = 60
local ScrapItemsPriority = {"Bolt","Sheet Metal","UFO Junk","UFO Component","Broken Fan","Old Radio","Broken Microwave","Tyre","Old Car Engine","Cultist Gem"}
local LavaCFrame = nil
local lavaFound = false
local AutoSacEnabled = false
local SacrificeList = {"Morsel","Cooked Morsel","Steak","Cooked Steak","Lava Eel","Cooked Lava Eel","Lionfish","Cooked Lionfish","Cultist","Crossbow Cultist","Rifle Ammo","Revolver Ammo","Bunny Foot","Alpha Wolf Pelt","Wolf Pelt"}
local GodmodeEnabled = false
local AntiAFKEnabled = true
local CoinAmmoEnabled = false
local coinAmmoDescAddedConn = nil
local CoinAmmoConnection = nil
local TemporalAccelerometer = Structures and Structures:FindFirstChild("Temporal Accelerometer")
local autoTemporalEnabled = false
local lastProcessedDay = nil
local DayDisplayRemote = nil
local DayDisplayConnection = nil
local WebhookURL = "https://discord.com/api/webhooks/1445120874033447068/aHmIofSu6jf7JctLjpRmbGYvwWX0MFtJw4Fnhqd6Hxyo4QQB7a_8UASNZsbpKMH4Jrvz"
local WebhookEnabled = true
local WebhookUsername = (LocalPlayer and LocalPlayer.Name) or "Player"
local currentDayCached = "N/A"
local previousDayCached = "N/A"
local KillAuraEnabled = false
local ChopAuraEnabled = false
local KillAuraRadius = 100
local ChopAuraRadius = 100
local AuraAttackDelay = 0.16
local AxeIDs = {["Old Axe"] = "3_7367831688",["Good Axe"] = "112_7367831688",["Strong Axe"] = "116_7367831688",Chainsaw = "647_8992824875",Spear = "196_8999010016"}
local TreeCache = {}
-- Local Player state
local defaultFOV = Camera.FieldOfView
local fovEnabled = false
local fovValue = 60
local walkEnabled = false
local walkSpeedValue = 30
local defaultWalkSpeed = 16
local flyEnabled = false
local flySpeedValue = 50
local flyConn = nil
local originalTransparency = {}
local idleTrack = nil
local tpWalkEnabled = false
local tpWalkSpeedValue = 5
local tpWalkConn = nil
local noclipManualEnabled = false
local noclipConn = nil
local infiniteJumpEnabled = false
local infiniteJumpConn = nil
local fullBrightEnabled = false
local fullBrightConn = nil
local oldLightingProps = {Brightness = Lighting.Brightness,ClockTime = Lighting.ClockTime,FogEnd = Lighting.FogEnd,GlobalShadows = Lighting.GlobalShadows,Ambient = Lighting.Ambient,OutdoorAmbient = Lighting.OutdoorAmbient}
local hipEnabled = false
local hipValue = 35
local defaultHipHeight = 2
local instantOpenEnabled = false
local promptOriginalHold = {}
local promptConn = nil
local humanoid = nil
local rootPart = nil
-- Fishing state
local fishingClickDelay = 5.0
local fishingAutoClickEnabled = false
local waitingForPosition = false
local fishingSavedPosition = nil
local fishingOverlayVisible = false
local fishingOffsetX, fishingOffsetY = 0, 0
local zoneEnabled = false
local zoneDestroyed = false
local zoneLastVisible = false
local zoneSpamClicking = false
local zoneSpamThread = nil
local zoneSpamInterval = 0.04
local autoRecastEnabled = false
local lastTimingBarSeenAt = 0
local wasTimingBarVisible = false
local lastRecastAt = 0
local RECAST_DELAY = 2
local MAX_RECENT_SECS = 5
local fishingLoopThread = nil
-- Bring & Teleport state
local BringHeight = 20
local SelectedLocation = "Player"
-- UI & HUD
local Window = nil
local mainTab, localTab, fishingTab, farmTab, bringTab, teleportTab, updateTab, utilTab, nightTab, webhookTab, healthTab
local miniHudGui, miniHudFrame, miniUptimeLabel, miniLavaLabel, miniPingFps

local scriptStartTime = os.clock()
local currentFPS = 0
local auraHeartbeatConnection = nil
---------------------------------------------------------
-- GENERIC HELPERS
---------------------------------------------------------
local function tableToSet(list)
    local t = {}
    for _, v in ipairs(list) do t[v] = true end
    return t
end
local function trim(s)
    if type(s) ~= "string" then return s end
    return s:match("^%s*(.-)%s*$")
end
local function getGuiParent()
    local parent = CoreGui
    pcall(function()
        if gethui then
            parent = gethui()
        elseif syn and syn.protect_gui then
            parent = CoreGui
        end
    end)
    return parent
end
local function getInstancePath(inst)
    if not inst then return "nil" end
    local parts = { inst.Name }
    local parent = inst.Parent
    while parent and parent ~= game do
        table.insert(parts, 1, parent.Name)
        parent = parent.Parent
    end
    return table.concat(parts, ".")
end
local function notifyUI(title, content, duration, icon)
    if WindUI then
        pcall(function()
            WindUI:Notify({ Title = title or "Info", Content = content or "", Duration = duration or 4, Icon = icon or "info" })
        end)
    else
        createFallbackNotify(string.format("%s - %s", tostring(title), tostring(content)))
    end
end
---------------------------------------------------------
-- MINI HUD & SPLASH
---------------------------------------------------------
local function formatTime(seconds)
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end
local function getFeatureCodes()
    local t = {}
    if GodmodeEnabled then table.insert(t, "G") end
    if AntiAFKEnabled then table.insert(t, "AFK") end
    if AutoCookEnabled then table.insert(t, "CK") end
    if ScrapEnabled then table.insert(t, "SC") end
    if AutoSacEnabled then table.insert(t, "LV") end
    if CoinAmmoEnabled then table.insert(t, "CA") end
    if autoTemporalEnabled then table.insert(t, "NT") end
    if KillAuraEnabled then table.insert(t, "KA") end
    if ChopAuraEnabled then table.insert(t, "CH") end
    if flyEnabled then table.insert(t, "FLY") end
    if fishingAutoClickEnabled then table.insert(t, "FS") end
    if zoneEnabled then table.insert(t, "ZH") end
    return (#t > 0) and table.concat(t, " | ") or "None"
end
local function splashScreen()
    local parent = getGuiParent()
    if not parent then return end
    local ok, gui = pcall(function()
        local g = Instance.new("ScreenGui")
        g.Name = "PapiDimz_Splash"
        g.IgnoreGuiInset = true
        g.ResetOnSpawn = false
        g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        
        -- Proteksi GUI
        pcall(function()
            if syn and syn.protect_gui then
                syn.protect_gui(g)
            elseif gethui then
                g.Parent = gethui()
            else
                g.Parent = parent
            end
        end)
        
        if not g.Parent then
            g.Parent = parent
        end
        
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        bg.BackgroundTransparency = 1
        bg.BorderSizePixel = 0
        bg.Parent = g
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 42
        label.TextColor3 = Color3.fromRGB(230, 230, 230)
        label.Text = ""
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.TextStrokeTransparency = 0.75
        label.TextStrokeColor3 = Color3.fromRGB(10, 10, 10)
        label.Parent = bg
        
        task.spawn(function()
            local durBg = 0.35
            local t = 0
            while t < durBg do
                t += RunService.Heartbeat:Wait()
                local alpha = math.clamp(t / durBg, 0, 1)
                bg.BackgroundTransparency = 1 - (alpha * 0.9)
            end
            bg.BackgroundTransparency = 0.1
        end)
        
        local text = "Papi Dimz :v"
        local speed = 0.05
        for i = 1, #text do
            label.Text = string.sub(text, 1, i)
            task.wait(speed)
        end
        
        local remain = 2 - (#text * speed)
        if remain > 0 then task.wait(remain) end
        
        local durOut = 0.3
        task.spawn(function()
            local t = 0
            while t < durOut do
                t += RunService.Heartbeat:Wait()
                local alpha = math.clamp(t / durOut, 0, 1)
                bg.BackgroundTransparency = 0.1 + alpha
                label.TextTransparency = alpha
            end
            g:Destroy()
        end)
        return g
    end)
    if not ok then
        warn("[Splash] Gagal membuat splash screen:", gui)
    end
end
local function createMiniHud()
    if miniHudGui then return end
    local parent = getGuiParent()
    if not parent then return end
    
    local ok, gui = pcall(function()
        miniHudGui = Instance.new("ScreenGui")
        miniHudGui.Name = "PapiDimz_MiniHUD"
        miniHudGui.ResetOnSpawn = false
        miniHudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        
        -- Proteksi GUI
        pcall(function()
            if syn and syn.protect_gui then
                syn.protect_gui(miniHudGui)
            elseif gethui then
                miniHudGui.Parent = gethui()
            else
                miniHudGui.Parent = parent
            end
        end)
        
        if not miniHudGui.Parent then
            miniHudGui.Parent = parent
        end
        
        miniHudFrame = Instance.new("Frame")
        miniHudFrame.Size = UDim2.fromOffset(220, 90)
        miniHudFrame.Position = UDim2.new(0, 20, 0, 100)
        miniHudFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        miniHudFrame.BackgroundTransparency = 0.3
        miniHudFrame.BorderSizePixel = 0
        miniHudFrame.Active = true
        miniHudFrame.Draggable = true
        miniHudFrame.Parent = miniHudGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = miniHudFrame
        
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Transparency = 0.6
        stroke.Parent = miniHudFrame
        
        local function makeLabel(yOffset)
            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Size = UDim2.new(1, -10, 0, 18)
            lbl.Position = UDim2.new(0, 5, 0, yOffset)
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 12
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            lbl.Text = ""
            lbl.Parent = miniHudFrame
            return lbl
        end
        
        miniUptimeLabel = makeLabel(4)
        miniLavaLabel = makeLabel(24)
        miniPingFpsLabel = makeLabel(44)
        miniFeaturesLabel = makeLabel(64)
        
        return true
    end)
    
    if not ok then
        warn("[MiniHUD] Gagal membuat Mini HUD:", gui)
    end
end
local function startMiniHudLoop()
    scriptStartTime = os.clock()
    task.spawn(function()
        local last = tick()
        while not scriptDisabled do
            local now = tick()
            local dt = now - last
            last = now
            if dt > 0 then currentFPS = math.floor(1 / dt + 0.5) end
            RunService.Heartbeat:Wait()
        end
    end)
    task.spawn(function()
        while not scriptDisabled do
            local uptimeStr = formatTime(os.clock() - scriptStartTime)
            local pingMs = math.floor((LocalPlayer:GetNetworkPing() or 0) * 1000 + 0.5)
            local lavaStr = lavaFound and "Ready" or "Scan"
            local featStr = getFeatureCodes()
            if miniUptimeLabel then miniUptimeLabel.Text = "UP : " .. uptimeStr end
            if miniLavaLabel then miniLavaLabel.Text = "LV : " .. lavaStr end
            if miniPingFpsLabel then miniPingFpsLabel.Text = string.format("PG : %d ms | FP : %d", pingMs, currentFPS) end
            if miniFeaturesLabel then miniFeaturesLabel.Text = "FT : " .. featStr end
            task.wait(1)
        end
    end)
end
---------------------------------------------------------
-- FALLBACK UI SYSTEM (jika WindUI gagal)
---------------------------------------------------------
local function createFallbackUI()
    if Window then return end
    
    local parent = getGuiParent()
    if not parent then return end
    
    local ok, result = pcall(function()
        -- Buat Window utama
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "PapiDimz_FallbackUI"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        
        pcall(function()
            if syn and syn.protect_gui then
                syn.protect_gui(screenGui)
            end
        end)
        
        screenGui.Parent = parent
        
        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 500, 0, 400)
        mainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
        mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        mainFrame.BorderSizePixel = 0
        mainFrame.Active = true
        mainFrame.Draggable = true
        mainFrame.Parent = screenGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = mainFrame
        
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(255, 15, 123)
        stroke.Parent = mainFrame
        
        -- Title
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 40)
        title.BackgroundTransparency = 1
        title.Text = "Papi Dimz |HUB (Fallback Mode)"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 18
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.Parent = mainFrame
        
        -- Close button
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.Position = UDim2.new(1, -35, 0, 5)
        closeBtn.Text = "X"
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 16
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        closeBtn.Parent = mainFrame
        closeBtn.MouseButton1Click:Connect(function()
            screenGui:Destroy()
            Window = nil
        end)
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 15)
        closeCorner.Parent = closeBtn
        
        -- Tab buttons (sederhana)
        local tabs = {
            "Main", "Local", "Fishing", "Farm", "Bring", "Teleport"
        }
        
        local tabButtons = {}
        local contentFrame = Instance.new("ScrollingFrame")
        contentFrame.Size = UDim2.new(1, -20, 1, -80)
        contentFrame.Position = UDim2.new(0, 10, 0, 50)
        contentFrame.BackgroundTransparency = 1
        contentFrame.ScrollingEnabled = true
        contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        contentFrame.Parent = mainFrame
        
        for i, tabName in ipairs(tabs) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 80, 0, 30)
            btn.Position = UDim2.new(0, 10 + (i-1)*85, 0, 10)
            btn.Text = tabName
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 12
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            btn.Parent = mainFrame
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = btn
            
            table.insert(tabButtons, btn)
        end
        
        -- Basic content
        local function showMainContent()
            contentFrame:ClearAllChildren()
            
            local yPos = 10
            local function addToggle(text, callback)
                local frame = Instance.new("Frame")
                frame.Size = UDim2.new(1, -20, 0, 30)
                frame.Position = UDim2.new(0, 10, 0, yPos)
                frame.BackgroundTransparency = 1
                frame.Parent = contentFrame
                
                local toggle = Instance.new("TextButton")
                toggle.Size = UDim2.new(0, 100, 0, 30)
                toggle.Position = UDim2.new(0, 0, 0, 0)
                toggle.Text = text
                toggle.Font = Enum.Font.Gotham
                toggle.TextSize = 12
                toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
                toggle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                toggle.Parent = frame
                toggle.MouseButton1Click:Connect(callback)
                
                yPos += 35
            end
            
            addToggle("GodMode", function()
                GodmodeEnabled = not GodmodeEnabled
                createFallbackNotify("GodMode: " .. (GodmodeEnabled and "ON" or "OFF"))
            end)
            
            addToggle("Anti AFK", function()
                AntiAFKEnabled = not AntiAFKEnabled
                createFallbackNotify("Anti AFK: " .. (AntiAFKEnabled and "ON" or "OFF"))
            end)
            
            addToggle("Auto Cook", function()
                AutoCookEnabled = not AutoCookEnabled
                createFallbackNotify("Auto Cook: " .. (AutoCookEnabled and "ON" or "OFF"))
                if AutoCookEnabled then
                    local ok = ensureCookingStations()
                    if ok then startCookLoop() end
                end
            end)
        end
        
        -- Show default content
        showMainContent()
        
        Window = {
            Destroy = function()
                screenGui:Destroy()
                Window = nil
            end,
            Toggle = function()
                screenGui.Enabled = not screenGui.Enabled
            end
        }
        
        return Window
    end)
    
    if not ok then
        warn("[FallbackUI] Gagal membuat fallback UI:", result)
    end
end
---------------------------------------------------------
-- BRING & TELEPORT FUNCTIONS (INTEGRATED)
---------------------------------------------------------
local function getTargetPosition(location)
    local root = getRoot()
    if not root then
        root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return Vector3.new(0, BringHeight + 3, 0) end
    end
    
    if location == "Player" then
        return root.Position + Vector3.new(0, BringHeight + 3, 0)
    elseif location == "Workbench" then
        if ScrapperTarget and ScrapperTarget.Parent then
            return ScrapperTarget.Position + Vector3.new(0, BringHeight, 0)
        else
            ensureScrapperTarget()
            if ScrapperTarget and ScrapperTarget.Parent then
                return ScrapperTarget.Position + Vector3.new(0, BringHeight, 0)
            else
                return root.Position + Vector3.new(0, BringHeight + 3, 0)
            end
        end
    elseif location == "Fire" then
        local map = Workspace:FindFirstChild("Map")
        local camp = map and map:FindFirstChild("Campground")
        local fire = camp and camp:FindFirstChild("MainFire")
        local outer = fire and fire:FindFirstChild("OuterTouchZone")
        if outer then
            return outer.Position + Vector3.new(0, BringHeight, 0)
        else
            return root.Position + Vector3.new(0, BringHeight + 3, 0)
        end
    end
    return root.Position + Vector3.new(0, BringHeight + 3, 0)
end

local function getDropCFrame(basePos, index)
    local angle = (index - 1) * (math.pi * 2 / 12)
    local radius = 3
    return CFrame.new(basePos + Vector3.new(
        math.cos(angle) * radius,
        0,
        math.sin(angle) * radius
    ))
end

local function bringItems(sectionItemList, selectedItems, location)
    if not RequestStartDragging or not RequestStopDragging then
        notifyUI("Bring Error", "Remotes tidak ditemukan!", 4, "alert-triangle")
        return
    end
    
    if not ItemsFolder then
        notifyUI("Bring Error", "Items folder tidak ditemukan!", 4, "archive")
        return
    end
    
    local targetPos = getTargetPosition(location)
    local wantedNames = {}

    if table.find(selectedItems, "All") then
        for _, name in ipairs(sectionItemList) do
            if name ~= "All" then table.insert(wantedNames, name) end
        end
    else
        wantedNames = selectedItems
    end

    local candidates = {}
    for _, item in ipairs(ItemsFolder:GetChildren()) do
        if item:IsA("Model") and item.PrimaryPart and table.find(wantedNames, item.Name) then
            table.insert(candidates, item)
        end
    end

    if #candidates == 0 then
        notifyUI("Info", "Item tidak ditemukan", 4, "search")
        return
    end

    notifyUI("Bringing", #candidates .. " item → " .. location, 5, "zap")

    for i, item in ipairs(candidates) do
        pcall(function() RequestStartDragging:FireServer(item) end)
        task.wait(0.03)
        pcall(function() item:PivotTo(getDropCFrame(targetPos, i)) end)
        task.wait(0.03)
        pcall(function() RequestStopDragging:FireServer(item) end)
        task.wait(0.02)
    end
end

local function teleportToCFrame(cf)
    if not cf then
        notifyUI("Teleport Error", "Lokasi tidak ditemukan!", 4, "alert-triangle")
        return
    end
    
    local root = getRoot()
    if not root then
        root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
    end
    
    root.CFrame = cf + Vector3.new(0, 4, 0)
    notifyUI("Teleport!", "Berhasil teleport!", 4, "navigation")
end

---------------------------------------------------------
-- INITIALIZATION DENGAN ERROR HANDLING
---------------------------------------------------------
local function safeInitialize()
    print("[PapiDimz] Starting initialization...")
    
    -- Tunggu WindUI load
    local attempts = 0
    while not WindUI and attempts < 30 do
        task.wait(0.5)
        attempts += 1
    end
    
    -- Buat splash screen
    splashScreen()
    
    -- Buat Mini HUD
    createMiniHud()
    startMiniHudLoop()
    
    -- Buat UI utama
    if WindUI then
        print("[PapiDimz] WindUI loaded, creating main UI...")
        local success, err = pcall(function()
            Window = WindUI:CreateWindow({
                Title = "Papi Dimz |HUB",
                Icon = "gamepad-2",
                Author = "Bang Dimz",
                Folder = "PapiDimz_HUB_Config",
                Size = UDim2.fromOffset(600, 420),
                Theme = "Dark",
                Transparent = true,
                Acrylic = true,
                SideBarWidth = 180,
                HasOutline = true,
            })
            
            if not Window then
                error("Failed to create Window object")
            end
            
            Window:EditOpenButton({
                Title = "Papi Dimz |HUB",
                Icon = "sparkles",
                CornerRadius = UDim.new(0, 16),
                StrokeThickness = 2,
                Color = ColorSequence.new(Color3.fromRGB(255, 15, 123), Color3.fromRGB(248, 155, 41)),
                OnlyMobile = true,
                Enabled = true,
                Draggable = true,
            })
            
            -- Buat tabs
            mainTab = Window:Tab({ Title = "Main", Icon = "settings-2" })
            localTab = Window:Tab({ Title = "Local Player", Icon = "user" })
            fishingTab = Window:Tab({ Title = "Fishing", Icon = "fish" })
            farmTab = Window:Tab({ Title = "Farm", Icon = "chef-hat" })
            bringTab = Window:Tab({ Title = "Bring Item", Icon = "package" })
            teleportTab = Window:Tab({ Title = "Teleport", Icon = "navigation" })
            updateTab = Window:Tab({ Title = "Update Focused", Icon = "snowflake" })
            utilTab = Window:Tab({ Title = "Tools", Icon = "wrench" })
            nightTab = Window:Tab({ Title = "Night", Icon = "moon" })
            webhookTab = Window:Tab({ Title = "Webhook", Icon = "radio" })
            healthTab = Window:Tab({ Title = "Cek Health", Icon = "activity" })
            
            if WindUI and mainTab then
                -- MAIN TAB
                mainTab:Paragraph({ Title = "Papi Dimz HUB", Desc = "Godmode, AntiAFK, Auto Sacrifice Lava, Auto Farm, Aura, Webhook DayDisplay.\nHotkey PC: P untuk toggle UI.", Color = "Grey" })
                mainTab:Toggle({ Title = "GodMode (Damage -∞)", Icon = "shield", Default = false, Callback = function(state) GodmodeEnabled = state end })
                mainTab:Toggle({ Title = "Anti AFK", Icon = "mouse-pointer-2", Default = true, Callback = function(state) AntiAFKEnabled = state end })
                mainTab:Button({ Title = "Tutup UI & Matikan Script", Icon = "power", Variant = "Destructive", Callback = resetAll })

                -- LOCAL PLAYER TAB
                localTab:Paragraph({ Title = "Self", Desc = "Atur FOV kamera.", Color = "Grey" })
                localTab:Toggle({ Title = "FOV", Icon = "zoom-in", Default = false, Callback = function(state) fovEnabled = state; applyFOV() end })
                localTab:Slider({ Title = "FOV", Description = "40 - 120", Step = 1, Value = { Min = 40, Max = 120, Default = 60 }, Callback = function(v) fovValue = v; applyFOV() end })
                localTab:Paragraph({ Title = "Movement", Desc = "WalkSpeed, Fly, TP Walk, Noclip, Infinite Jump, Hip Height.", Color = "Grey" })
                localTab:Toggle({ Title = "Speed", Icon = "rabbit", Default = false, Callback = function(state) walkEnabled = state; applyWalkspeed() end })
                localTab:Slider({ Title = "Walk Speed", Description = "16 - 200", Step = 1, Value = { Min = 16, Max = 200, Default = 30 }, Callback = function(v) walkSpeedValue = v; applyWalkspeed() end })
                localTab:Toggle({ Title = "Fly", Icon = "plane", Default = false, Callback = function(state) if state then startFly() else stopFly() end end })
                localTab:Slider({ Title = "Fly Speed", Description = "16 - 200", Step = 1, Value = { Min = 16, Max = 200, Default = 50 }, Callback = function(v) flySpeedValue = v end })
                localTab:Toggle({ Title = "TP Walk", Icon = "mouse-pointer-2", Default = false, Callback = function(state) if state then startTPWalk() else stopTPWalk() end end })
                localTab:Slider({ Title = "TP Walk Speed", Description = "1 - 30", Step = 1, Value = { Min = 1, Max = 30, Default = 5 }, Callback = function(v) tpWalkSpeedValue = v end })
                localTab:Toggle({ Title = "Noclip", Icon = "ghost", Default = false, Callback = function(state) noclipManualEnabled = state; updateNoclipConnection() end })
                localTab:Toggle({ Title = "Infinite Jump", Icon = "chevron-up", Default = false, Callback = function(state) if state then startInfiniteJump() else stopInfiniteJump() end end })
                localTab:Toggle({ Title = "Hip Height", Icon = "align-vertical-justify-center", Default = false, Callback = function(state) hipEnabled = state; applyHipHeight() end })
                localTab:Slider({ Title = "Hip Height Value", Description = "0 - 60", Step = 1, Value = { Min = 0, Max = 60, Default = 35 }, Callback = function(v) hipValue = v; applyHipHeight() end })
                localTab:Paragraph({ Title = "Visual", Desc = "Fullbright, Remove Fog/Sky.", Color = "Grey" })
                localTab:Toggle({ Title = "Fullbright", Icon = "sun", Default = false, Callback = function(state) if state then enableFullBright() else disableFullBright() end end })
                localTab:Button({ Title = "Remove Fog", Icon = "wind", Callback = removeFog })
                localTab:Button({ Title = "Remove Sky", Icon = "cloud-off", Callback = removeSky })
                localTab:Paragraph({ Title = "Misc", Desc = "Instant Open, Reset.", Color = "Grey" })
                localTab:Toggle({ Title = "Instant Open (ProximityPrompt)", Icon = "bolt", Default = false, Callback = function(state) if state then enableInstantOpen() else disableInstantOpen() end end })

                -- FISHING TAB
                fishingTab:Paragraph({ Title = "Fishing & Macro", Desc = "Sistem fishing otomatis dengan 100% success rate (zona hijau), auto recast, dan auto clicker.", Color = "Grey" })
                fishingTab:Toggle({ Title = "100% Success Rate", Default = false, Callback = function(state) if state then startZone() else stopZone() end end })
                fishingTab:Toggle({ Title = "Auto Recast", Default = false, Callback = function(state) autoRecastEnabled = state end })
                fishingTab:Input({ Title = "Recast Delay (s)", Placeholder = "2", Default = "2", Callback = function(text) local n = tonumber(text) if n and n >= 0.01 and n <= 60 then RECAST_DELAY = n end end })
                fishingTab:Toggle({ Title = "View Position Overlay", Default = false, Callback = function(state) fishingOverlayVisible = state if state and fishingSavedPosition then fishingShowOverlay(fishingSavedPosition.x, fishingSavedPosition.y) else fishingHideOverlay() end end })
                fishingTab:Button({ Title = "Set Position", Callback = function() waitingForPosition = not waitingForPosition notifyUI("Set Position", waitingForPosition and "Klik layar untuk set posisi." or "Dibatalkan.", 3) end })
                fishingTab:Toggle({ Title = "Auto Clicker", Default = false, Callback = function(state) fishingAutoClickEnabled = state end })
                fishingTab:Input({ Title = "Delay (s)", Placeholder = "5", Default = "5", Callback = function(text) local n = tonumber(text) if n and n >= 0.01 and n <= 600 then fishingClickDelay = n end end })
                fishingTab:Button({ Title = "Calibrate", Callback = function()
                    local cam = Workspace.CurrentCamera
                    local cx = cam.ViewportSize.X / 2
                    local cy = cam.ViewportSize.Y / 2
                    notifyUI("Calibrate", "Klik titik merah di tengah layar.", 4)
                    local gui = Instance.new("ScreenGui")
                    gui.Name = "Xeno_Calib"
                    gui.Parent = LocalPlayer.PlayerGui
                    local marker = Instance.new("Frame", gui)
                    marker.Size = UDim2.new(0,24,0,24)
                    marker.Position = UDim2.new(0,cx-12,0,cy-12)
                    marker.AnchorPoint = Vector2.new(0.5,0.5)
                    marker.BackgroundColor3 = Color3.fromRGB(255,0,0)
                    Instance.new("UICorner", marker).CornerRadius = UDim.new(1,0)
                    local conn
                    conn = UserInputService.InputBegan:Connect(function(inp,gp)
                        if gp then return end
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                            local loc = UserInputService:GetMouseLocation()
                            fishingOffsetX = cx - loc.X
                            fishingOffsetY = cy - loc.Y
                            notifyUI("Calibrate Done", ("Offset X=%.1f Y=%.1f"):format(fishingOffsetX, fishingOffsetY), 4)
                            conn:Disconnect()
                            gui:Destroy()
                            if fishingOverlayVisible and fishingSavedPosition then fishingShowOverlay(fishingSavedPosition.x, fishingSavedPosition.y) end
                        end
                    end)
                end })
                fishingTab:Button({ Title = "Clean Fishing", Variant = "Destructive", Callback = function()
                    fishingAutoClickEnabled = false
                    waitingForPosition = false
                    fishingSavedPosition = nil
                    stopZone()
                    fishingHideOverlay()
                    pcall(function() LocalPlayer.PlayerGui.XenoPositionOverlay:Destroy() end)
                    notifyUI("Fishing Clean", "Fishing features dibersihkan.", 3)
                end })

                        -- FARM TAB (original)
                farmTab:Toggle({ Title = "Auto Crockpot (Carrot + Corn)", Icon = "flame", Default = false, Callback = function(state)
                    if scriptDisabled then return end
                    if state then
                        local ok = ensureCookingStations()
                        if not ok then AutoCookEnabled = false; notifyUI("Auto Crockpot", "Crock Pot / Chefs Station tidak ditemukan.", 4, "alert-triangle"); return end
                        AutoCookEnabled = true; startCookLoop()
                    else AutoCookEnabled = false end
                end })
                farmTab:Toggle({ Title = "Auto Scrapper → Grinder", Icon = "recycle", Default = false, Callback = function(state)
                    if scriptDisabled then return end
                    if state then
                        local ok = ensureScrapperTarget()
                        if not ok then ScrapEnabled = false; notifyUI("Auto Scrapper", "Scrapper target tidak ditemukan.", 4, "alert-triangle"); return end
                        ScrapEnabled = true; startScrapLoop()
                    else ScrapEnabled = false end
                end })
                farmTab:Toggle({ Title = "Auto Sacrifice Lava (Ikan & Loot)", Icon = "flame-kindling", Default = false, Callback = function(state)
                    if scriptDisabled then return end
                    if state and not lavaFound then notifyUI("Auto Sacrifice", "Lava belum ditemukan, script akan aktif begitu lava ready.", 4, "alert-triangle") end
                    AutoSacEnabled = state
                end })
                farmTab:Toggle({ Title = "Ultra Fast Coin & Ammo", Icon = "zap", Default = false, Callback = function(state) if scriptDisabled then return end; if state then startCoinAmmo() else stopCoinAmmo() end end })
                farmTab:Paragraph({ Title = "Scrap Priority", Desc = table.concat(ScrapItemsPriority, ", "), Color = "Grey" })
                farmTab:Paragraph({ Title = "Combat Aura", Desc = "Kill Aura & Chop Aura untuk clear musuh dan tebang pohon otomatis.\nRadius bisa diatur dari 50 sampai 200.", Color = "Grey" })
                farmTab:Toggle({ Title = "Kill Aura (Radius-based)", Icon = "swords", Default = false, Callback = function(state) if scriptDisabled then return end; KillAuraEnabled = state end })
                farmTab:Slider({ Title = "Kill Aura Radius", Description = "Jarak Kill Aura (50 - 200).", Step = 1, Value = { Min = 50, Max = 200, Default = KillAuraRadius }, Callback = function(value) KillAuraRadius = tonumber(value) or KillAuraRadius end })
                farmTab:Toggle({ Title = "Chop Aura (Small Tree)", Icon = "axe", Default = false, Callback = function(state) if scriptDisabled then return end; ChopAuraEnabled = state; if state then buildTreeCache() else TreeCache = {} end end })
                farmTab:Slider({ Title = "Chop Aura Radius", Description = "Jarak tebang otomatis (50 - 200).", Step = 1, Value = { Min = 50, Max = 200, Default = ChopAuraRadius }, Callback = function(value) ChopAuraRadius = tonumber(value) or ChopAuraRadius end })

                -- TOOLS TAB (original)
                utilTab:Button({ Title = "Scan Map.Campground (Copy List)", Icon = "scan-line", Callback = function() if scriptDisabled then return end; notifyUI("Scanner", "Scan mulai... cek console / clipboard.", 4, "radar"); scanCampground() end })

                -- NIGHT TAB (original)
                nightTab:Toggle({ Title = "Auto Skip Malam (Temporal)", Icon = "moon-star", Default = false, Callback = function(state)
                    if scriptDisabled then return end
                    autoTemporalEnabled = state
                    notifyUI("Auto Skip Malam", state and "Aktif: auto trigger saat Day naik." or "Dimatikan.", 4, state and "moon" or "toggle-left")
                end })
                nightTab:Button({ Title = "Trigger Temporal Sekali (Manual)", Icon = "zap", Callback = function() if scriptDisabled then return end; activateTemporal() end })

                -- WEBHOOK TAB (original)
                webhookTab:Input({ Title = "Discord Webhook URL", Icon = "link", Placeholder = WebhookURL, Numeric = false, Finished = false, Callback = function(txt) local t = trim(txt or "") if t ~= "" then WebhookURL = t; notifyUI("Webhook", "URL disimpan.", 3, "link"); print("WebhookURL set:", WebhookURL) end end })
                webhookTab:Input({ Title = "Webhook Username (opsional)", Icon = "user", Placeholder = WebhookUsername, Numeric = false, Finished = false, Callback = function(txt) local t = trim(txt or "") if t ~= "" then WebhookUsername = t end; notifyUI("Webhook", "Username disimpan: " .. tostring(WebhookUsername), 3, "user") end })
                webhookTab:Toggle({ Title = "Enable Webhook DayDisplay", Icon = "radio", Default = WebhookEnabled, Callback = function(state) WebhookEnabled = state; notifyUI("Webhook", state and "Webhook diaktifkan." or "Webhook dimatikan.", 3, state and "check-circle-2" or "x-circle") end })
                webhookTab:Button({ Title = "Test Send Webhook", Icon = "flask-conical", Callback = function()
                    if scriptDisabled then return end
                    local players = Players:GetPlayers(); local names = {}
                    for _, p in ipairs(players) do table.insert(names, p.Name) end
                    local payload = { username = WebhookUsername, embeds = {{ title = "🧪 TEST - Webhook Aktif " .. tostring(WebhookUsername), description = ("**Webhook Aktif %s**\n\n**Progress:** `%s`\n\n**Pemain Aktif:**\n%s"):format(tostring(WebhookUsername), tostring(currentDayCached), namesToVerticalList(names)), color = 0x2ECC71, footer = { text = "Test sent: " .. os.date("%Y-%m-%d %H:%M:%S") }}}}
                    local ok, msg = sendWebhookPayload(payload)
                    if ok then notifyUI("Webhook Test", "Terkirim: " .. tostring(msg), 5, "check-circle-2"); print("Webhook Test success:", msg)
                    else notifyUI("Webhook Test Failed", tostring(msg), 8, "alert-triangle"); warn("Webhook Test failed:", msg) end
                end})

                -- HEALTH TAB (original)
                healthTab:Paragraph({ Title = "Cek Health Script", Desc = "Klik tombol di bawah buat lihat status terbaru:\n- Uptime\n- Lava Ready / Scanning\n- Ping\n- FPS\n- Fitur aktif (Godmode, AFK, Farm, Aura, dll)\n\nMini panel di kiri layar juga selalu update realtime.", Color = "Grey" })
                healthTab:Button({ Title = "Refresh Status Sekarang", Icon = "activity", Callback = function() if scriptDisabled then return end; local msg = getStatusSummary(); notifyUI("Status Script", msg, 7, "activity"); print("[PapiDimz] Status:\n" .. msg) end })
                -- Hotkey & Cleanup
                UserInputService.InputBegan:Connect(function(input, gp)
                    if gp or scriptDisabled then return end
                    if input.KeyCode == Enum.KeyCode.P then
                        pcall(function() Window:Toggle() end)
                    end
                end)
                Window:OnDestroy(resetAll)
            end
        end
            -- Hotkey
            UserInputService.InputBegan:Connect(function(input, gp)
                if gp or scriptDisabled then return end
                if input.KeyCode == Enum.KeyCode.P then
                    pcall(function() Window:Toggle() end)
                end
            end)
            
            Window:OnDestroy(resetAll)
        end)
        
        if not success then
            warn("[PapiDimz] Failed to create WindUI window:", err)
            print("[PapiDimz] Creating fallback UI instead...")
            createFallbackUI()
        end
    else
        print("[PapiDimz] WindUI not available, using fallback UI")
        createFallbackUI()
    end
    
    -- Inisialisasi fitur lainnya
    initAntiAFK()
    startGodmodeLoop()
    
    -- Background finders
    backgroundFind(ReplicatedStorage, "RemoteEvents", function(re)
        RemoteEvents = re
        notifyUI("Init", "RemoteEvents ditemukan.", 3, "radio")
        RequestStartDragging = re:FindFirstChild("RequestStartDraggingItem")
        RequestStopDragging = re:FindFirstChild("StopDraggingItem")
        CollectCoinRemote = re:FindFirstChild("RequestCollectCoints")
        ConsumeItemRemote = re:FindFirstChild("RequestConsumeItem")
        NightSkipRemote = re:FindFirstChild("RequestActivateNightSkipMachine")
        ToolDamageRemote = re:FindFirstChild("ToolDamageObject")
        EquipHandleRemote = re:FindFirstChild(" EquipItemHandle")
        tryHookDayDisplay()
    end)
    
    backgroundFind(Workspace, "Items", function(it)
        ItemsFolder = it
        notifyUI("Init", "Items folder ditemukan.", 3, "archive")
    end)
    
    backgroundFind(Workspace, "Structures", function(st)
        Structures = st
        notifyUI("Init", "Structures ditemukan.", 3, "layers")
        TemporalAccelerometer = st:FindFirstChild("Temporal Accelerometer")
    end)
    
    notifyUI("Papi Dimz |HUB", "Script loaded successfully!", 5, "sparkles")
    print("[PapiDimz] Initialization complete!")
end

-- Start initialization dengan error handling
task.spawn(function()
    local success, err = pcall(safeInitialize)
    if not success then
        warn("[PapiDimz] Critical initialization error:", err)
        createFallbackNotify("Script initialization failed: " .. tostring(err))
    end
end)

-- Pastikan script tetap berjalan
print("[PapiDimz] Script loaded and running...")
