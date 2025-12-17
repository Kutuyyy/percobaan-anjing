-- Papi Dimz |HUB (All-in-One: Local Player + XENO GLASS Fishing + Original Features)
-- Versi: Fully Integrated UI
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
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
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
-- LOAD WINDUI
---------------------------------------------------------
local WindUI = nil
local function createFallbackNotify(msg)
    print("[PapiDimz][FALLBACK NOTIFY] " .. tostring(msg))
end
do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    end)
    if ok and res then
        WindUI = res
        pcall(function()
            WindUI:SetTheme("Dark")
            WindUI.TransparencyValue = 0.2
        end)
    else
        warn("[UI] Gagal load WindUI. Menggunakan fallback minimal.")
        WindUI = nil
    end
end
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
local MoveMode = "DragPivot"  -- kalau masih dipakai di print
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
-- UI & HUD
local Window
local mainTab, localTab, fishingTab, farmTab, utilTab, nightTab, webhookTab, healthTab
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
    local parent
    pcall(function()
        if gethui then parent = gethui() end
    end)
    if not parent then
        parent = LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    end
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

local function teleportToCFrame(cf)
    if not cf then
        notifyUI("Error", "Lokasi tidak ditemukan!", 4, "alert-triangle")
        return
    end
    rootPart.CFrame = cf + Vector3.new(0, 4, 0)
    notifyUI("Teleport!", "Berhasil teleport!", 4, "navigation")
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
        g.Parent = parent
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
end
local function createMiniHud()
    if miniHudGui then return end
    local parent = getGuiParent()
    if not parent then return end
    miniHudGui = Instance.new("ScreenGui")
    miniHudGui.Name = "PapiDimz_MiniHUD"
    miniHudGui.ResetOnSpawn = false
    miniHudGui.Parent = parent
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
-- LOCAL PLAYER FUNCTIONS
---------------------------------------------------------
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChild("Humanoid")
end
local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function zeroVelocities(part)
    if part and part:IsA("BasePart") then
        pcall(function()
            part.AssemblyLinearVelocity = Vector3.new(0,0,0)
            part.AssemblyAngularVelocity = Vector3.new(0,0,0)
        end)
    end
end
local function applyFOV()
    if fovEnabled then Camera.FieldOfView = fovValue else Camera.FieldOfView = defaultFOV end
end
local function applyWalkspeed()
    if humanoid and walkEnabled then humanoid.WalkSpeed = math.clamp(walkSpeedValue, 16, 200) else if humanoid then humanoid.WalkSpeed = defaultWalkSpeed end end
end
local function applyHipHeight()
    if humanoid and hipEnabled then humanoid.HipHeight = hipValue else if humanoid then humanoid.HipHeight = defaultHipHeight end end
end
local function updateNoclipConnection()
    local should = (noclipManualEnabled or flyEnabled)
    if should and not noclipConn then
        noclipConn = RunService.Stepped:Connect(function()
            local char = getCharacter()
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    elseif not should and noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
end
local function setVisibility(on)
    local char = getCharacter()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") or (part:IsA("MeshPart") and part.Name == "Handle") then
            if on then
                part.Transparency = 1
                part.LocalTransparencyModifier = 0
            else
                part.Transparency = originalTransparency[part] or 0
                part.LocalTransparencyModifier = 0
            end
        end
    end
end
local function playIdleAnimation()
    if idleTrack then idleTrack:Stop() end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://180435571"
    idleTrack = humanoid:LoadAnimation(anim)
    idleTrack.Priority = Enum.AnimationPriority.Core
    idleTrack.Looped = true
    idleTrack:Play()
end
local function startFly()
    if flyEnabled or scriptDisabled then return end
    local char = getCharacter()
    rootPart = getRoot()
    if not char or not rootPart then return end
    flyEnabled = true
    if next(originalTransparency) == nil then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") or (part:IsA("MeshPart") and part.Name == "Handle") then
                originalTransparency[part] = part.Transparency
            end
        end
    end
    setVisibility(false)
    rootPart.Anchored = true
    humanoid.PlatformStand = true
    for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
    playIdleAnimation()
    updateNoclipConnection()
    flyConn = RunService.RenderStepped:Connect(function(dt)
        if not flyEnabled or not rootPart then stopFly(); return end
        local move = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0,1,0) end
        if move.Magnitude > 0 then
            move = move.Unit * math.clamp(flySpeedValue, 16, 200) * dt
            rootPart.CFrame += move
        end
        rootPart.CFrame = CFrame.new(rootPart.Position) * Camera.CFrame.Rotation
        zeroVelocities(rootPart)
    end)
    notifyUI("Fly ON", "Ultimate Stealth Fly aktif!", 3, "plane")
end
local function stopFly()
    if not flyEnabled then return end
    flyEnabled = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local char = getCharacter()
    rootPart = getRoot()
    if idleTrack then idleTrack:Stop(); idleTrack = nil end
    humanoid.PlatformStand = false
    setVisibility(false)
    local targetCFrame = rootPart.CFrame
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 30000
    bp.Position = targetCFrame.Position
    bp.Parent = rootPart
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 30000
    bg.CFrame = targetCFrame
    bg.Parent = rootPart
    rootPart.Anchored = false
    for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end
    task.delay(0.1, function() if bp and bp.Parent then bp:Destroy() end if bg and bg.Parent then bg:Destroy() end end)
    updateNoclipConnection()
    notifyUI("Fly OFF", "Fly dimatikan.", 3, "plane")
end
local function startTPWalk()
    if tpWalkEnabled or scriptDisabled then return end
    tpWalkEnabled = true
    tpWalkConn = RunService.RenderStepped:Connect(function(dt)
        if not tpWalkEnabled then return end
        local h = getHumanoid()
        local r = getRoot()
        if h and r and h.MoveDirection.Magnitude > 0 then
            local dist = tpWalkSpeedValue * dt * 10
            r.CFrame += h.MoveDirection.Unit * dist
        end
    end)
end
local function stopTPWalk()
    tpWalkEnabled = false
    if tpWalkConn then tpWalkConn:Disconnect(); tpWalkConn = nil end
end
local function startInfiniteJump()
    if infiniteJumpEnabled or scriptDisabled then return end
    infiniteJumpEnabled = true
    infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
        if infiniteJumpEnabled then getHumanoid():ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end
local function stopInfiniteJump()
    infiniteJumpEnabled = false
    if infiniteJumpConn then infiniteJumpConn:Disconnect(); infiniteJumpConn = nil end
end
local function enableFullBright()
    fullBrightEnabled = true
    for k, v in pairs(oldLightingProps) do oldLightingProps[k] = Lighting[k] end
    local function apply()
        if not fullBrightEnabled then return end
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e4
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
    end
    apply()
    fullBrightConn = RunService.RenderStepped:Connect(apply)
end
local function disableFullBright()
    fullBrightEnabled = false
    if fullBrightConn then fullBrightConn:Disconnect(); fullBrightConn = nil end
    for k, v in pairs(oldLightingProps) do Lighting[k] = v end
end
local function removeFog()
    Lighting.FogEnd = 1e9
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then atmo.Density = 0; atmo.Haze = 0 end
    notifyUI("Remove Fog", "Fog dihapus.", 3, "wind")
end
local function removeSky()
    for _, obj in ipairs(Lighting:GetChildren()) do if obj:IsA("Sky") then obj:Destroy() end end
    notifyUI("Remove Sky", "Skybox dihapus.", 3, "cloud-off")
end
local function applyInstantOpenToPrompt(prompt)
    if prompt and prompt:IsA("ProximityPrompt") then
        if promptOriginalHold[prompt] == nil then promptOriginalHold[prompt] = prompt.HoldDuration end
        prompt.HoldDuration = 0
    end
end
local function enableInstantOpen()
    instantOpenEnabled = true
    for _, v in ipairs(Workspace:GetDescendants()) do if v:IsA("ProximityPrompt") then applyInstantOpenToPrompt(v) end end
    if promptConn then promptConn:Disconnect() end
    promptConn = Workspace.DescendantAdded:Connect(function(inst)
        if instantOpenEnabled and inst:IsA("ProximityPrompt") then applyInstantOpenToPrompt(inst) end
    end)
    notifyUI("Instant Open", "Semua ProximityPrompt jadi instant.", 3, "bolt")
end
local function disableInstantOpen()
    instantOpenEnabled = false
    if promptConn then promptConn:Disconnect(); promptConn = nil end
    for prompt, orig in pairs(promptOriginalHold) do
        if prompt and prompt.Parent then pcall(function() prompt.HoldDuration = orig end) end
    end
    promptOriginalHold = {}
    notifyUI("Instant Open", "Durasi dikembalikan.", 3, "refresh-ccw")
end
---------------------------------------------------------
-- FISHING FUNCTIONS (XENO GLASS)
---------------------------------------------------------
local function fishingEnsureOverlay()
    local pg = LocalPlayer.PlayerGui
    if pg:FindFirstChild("XenoPositionOverlay") then return pg.XenoPositionOverlay end
    local g = Instance.new("ScreenGui")
    g.Name = "XenoPositionOverlay"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = 9999
    g.Parent = pg
    local dot = Instance.new("Frame", g)
    dot.Name = "RedDot"
    dot.Size = UDim2.new(0, 14, 0, 14)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BackgroundColor3 = Color3.fromRGB(220,50,50)
    dot.BorderSizePixel = 0
    dot.ZIndex = 9999
    dot.Visible = false
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    g.Enabled = false
    return g
end
local function fishingShowOverlay(x,y)
    local g = fishingEnsureOverlay()
    g.Enabled = true
    local dot = g.RedDot
    if dot then
        dot.Visible = true
        dot.Position = UDim2.new(0, math.floor(x + fishingOffsetX), 0, math.floor(y + fishingOffsetY))
    end
end
local function fishingHideOverlay()
    local g = LocalPlayer.PlayerGui:FindFirstChild("XenoPositionOverlay")
    if g then g.Enabled = false; if g.RedDot then g.RedDot.Visible = false end end
end
local function fishingDoClick()
    if not fishingSavedPosition then return end
    local x = math.floor(fishingSavedPosition.x + fishingOffsetX)
    local y = math.floor(fishingSavedPosition.y + fishingOffsetY)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end
local function zone_getTimingBar()
    local iface = LocalPlayer.PlayerGui:FindFirstChild("Interface")
    if not iface then return nil end
    local fcf = iface:FindFirstChild("FishingCatchFrame")
    if not fcf then return nil end
    return fcf:FindFirstChild("TimingBar")
end
local function zone_makeGreenFull()
    if not zoneEnabled or zoneDestroyed then return end
    pcall(function()
        local tb = zone_getTimingBar()
        if tb and tb:FindFirstChild("SuccessArea") then
            local sa = tb.SuccessArea
            sa.Size = UDim2.new(0,120,0,330)
            sa.Position = UDim2.new(0,52,0,-5)
            sa.BackgroundTransparency = 0
            if not sa:FindFirstChild("UICorner") then Instance.new("UICorner", sa).CornerRadius = UDim.new(0,12) end
        end
    end)
end
local function zone_isTimingBarVisible()
    if zoneDestroyed then return false end
    local tb = zone_getTimingBar()
    if not tb then return false end
    local cur = tb
    while cur and cur ~= LocalPlayer.PlayerGui do
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        cur = cur.Parent
    end
    return true
end
local function zone_doSpamClick()
    pcall(function()
        local cam = Workspace.CurrentCamera
        local pt = cam and Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2) or Vector2.new(300,300)
        VirtualUser:Button1Down(pt); task.wait(0.02); VirtualUser:Button1Up(pt)
    end)
end
local function zone_startSpam()
    if zoneSpamClicking or zoneDestroyed or not zoneEnabled then return end
    zoneSpamClicking = true
    zoneSpamThread = task.spawn(function()
        while zoneSpamClicking and not zoneDestroyed and zoneEnabled do
            if not zone_isTimingBarVisible() then zoneSpamClicking = false; break end
            zone_doSpamClick()
            task.wait(zoneSpamInterval)
        end
    end)
end
local function zone_stopSpam()
    zoneSpamClicking = false
end
local function startZone()
    zoneDestroyed = false
    zoneEnabled = true
    task.spawn(function()
        while not zoneDestroyed do
            task.wait(0.15)
            if zoneEnabled then pcall(zone_makeGreenFull) end
        end
    end)
    task.spawn(function()
        zoneLastVisible = zone_isTimingBarVisible()
        wasTimingBarVisible = zoneLastVisible
        if zoneLastVisible then lastTimingBarSeenAt = tick() end
        while not zoneDestroyed do
            task.wait(0.06)
            local nowVisible = zone_isTimingBarVisible()
            if nowVisible then lastTimingBarSeenAt = tick() end
            if nowVisible ~= zoneLastVisible then
                zoneLastVisible = nowVisible
                if nowVisible then
                    wasTimingBarVisible = true
                    lastTimingBarSeenAt = tick()
                    if zoneEnabled then pcall(zone_makeGreenFull); zone_startSpam() end
                else
                    zone_stopSpam()
                    if autoRecastEnabled and fishingSavedPosition then
                        local sinceSeen = tick() - lastTimingBarSeenAt
                        local sinceRecast = tick() - lastRecastAt
                        if wasTimingBarVisible and sinceSeen <= MAX_RECENT_SECS and sinceRecast >= RECAST_DELAY then
                            task.spawn(function()
                                task.wait(RECAST_DELAY)
                                fishingDoClick()
                                lastRecastAt = tick()
                                notifyUI("Auto Recast", "Recast dilakukan.", 2)
                            end)
                        end
                    end
                    wasTimingBarVisible = false
                end
            end
        end
    end)
    task.spawn(function()
        task.wait(0.15)
        if zoneEnabled and zone_isTimingBarVisible() then zone_startSpam() end
    end)
end
local function stopZone()
    zoneEnabled = false
    zone_stopSpam()
    zoneDestroyed = true
end
-- Fishing auto click loop
fishingLoopThread = task.spawn(function()
    while true do
        if fishingAutoClickEnabled and fishingSavedPosition and not scriptDisabled then
            fishingDoClick()
        end
        task.wait(fishingClickDelay)
    end
end)
-- Position set handler
UserInputService.InputBegan:Connect(function(input, gp)
    if gp or not waitingForPosition or scriptDisabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local loc = UserInputService:GetMouseLocation()
        local vp = Camera.ViewportSize
        local px = math.clamp(math.floor(loc.X), 0, vp.X)
        local py = math.clamp(math.floor(loc.Y), 0, vp.Y)
        fishingSavedPosition = {x = px, y = py}
        waitingForPosition = false
        notifyUI("Position Set", ("X=%d Y=%d"):format(px, py), 3)
        if fishingOverlayVisible then fishingShowOverlay(px, py) end
    end
end)
---------------------------------------------------------
-- ORIGINAL FEATURES (Lava, Cook, Scrap, Aura, etc) - omitted for space but fully included in actual execution
---------------------------------------------------------
---------------------------------------------------------
-- LAVA FINDER
---------------------------------------------------------
local function findLava()
    if lavaFound then return end
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    local landmarks = map:FindFirstChild("Landmarks")
    if not landmarks then return end
    local volcano = landmarks:FindFirstChild("Volcano")
    if not volcano then return end
    local functional = volcano:FindFirstChild("Functional")
    if not functional then return end
    local lava = functional:FindFirstChild("Lava")
    if lava and lava:IsA("BasePart") then
        LavaCFrame = lava.CFrame * CFrame.new(0, 4, 0)
        lavaFound = true
        print("[Lava] Volcano lava ditemukan.")
        notifyUI("Lava", "Volcano lava ditemukan. Auto-sacrifice siap.", 4, "flame")
    end
end
task.spawn(function()
    while not lavaFound and not scriptDisabled do
        findLava()
        task.wait(1.5)
    end
end)

---------------------------------------------------------
-- AUTO SACRIFICE LAVA
---------------------------------------------------------
local function sacrificeItemToLava(item)
    if not AutoSacEnabled then return end
    if not item or not item.Parent or not item:IsA("Model") or not item.PrimaryPart then return end
    if not lavaFound or not LavaCFrame then return end
    if not table.find(SacrificeList, item.Name) then return end
    pcall(function()
        if RequestStartDragging then RequestStartDragging:FireServer(item) end
        task.wait(0.1)
        local offset = CFrame.new(math.random(-6, 6), 0, math.random(-6, 6))
        item:PivotTo(LavaCFrame * offset)
        task.wait(0.2)
        if RequestStopDragging then RequestStopDragging:FireServer(item) end
    end)
end
task.spawn(function()
    while not scriptDisabled do
        if AutoSacEnabled and lavaFound and ItemsFolder then
            for _, obj in ipairs(ItemsFolder:GetChildren()) do
                sacrificeItemToLava(obj)
            end
        end
        task.wait(0.7)
    end
end)

---------------------------------------------------------
-- AUTO CROCKPOT
---------------------------------------------------------
local function ensureCookingStations()
    local structures = Workspace:FindFirstChild("Structures")
    if not structures then
        CookingStations = {}
        warn("[Cook] workspace.Structures tidak ditemukan.")
        return false
    end
    local stations = {}
    local crock = structures:FindFirstChild("Crock Pot")
    local chef = structures:FindFirstChild("Chefs Station")
    if crock then table.insert(stations, crock) end
    if chef then table.insert(stations, chef) end
    if #stations == 0 then
        CookingStations = {}
        warn("[Cook] Tidak ada Crock Pot / Chefs Station.")
        return false
    end
    CookingStations = stations
    local names = {}
    for _, s in ipairs(stations) do table.insert(names, s.Name) end
    print("[Cook] Cooking Stations:", table.concat(names, ", "))
    return true
end
local function getStationBase(station)
    if not station then return nil end
    local base = station.PrimaryPart or station:FindFirstChildOfClass("BasePart")
    if not base then warn("[Cook] Station tanpa PrimaryPart/BasePart:", station.Name) end
    return base
end
local function getCookDropCFrame(basePart, index)
    local radius = 2
    local height = 3
    local angle = (index - 1) * (math.pi / 4)
    local basePos = basePart.Position
    local offsetX = math.cos(angle) * radius
    local offsetZ = math.sin(angle) * radius
    return CFrame.new(basePos + Vector3.new(offsetX, height, offsetZ))
end
local function collectCookCandidates(basePart, targetSet, maxCount)
    local best = {}
    if not ItemsFolder then return {} end
    for _, item in ipairs(ItemsFolder:GetChildren()) do
        if item:IsA("Model")
            and item.PrimaryPart
            and targetSet[item.Name]
            and not string.find(item.Name, "Item Chest")
        then
            local dist = (item.PrimaryPart.Position - basePart.Position).Magnitude
            if #best < maxCount then
                table.insert(best, { instance = item, distance = dist })
            else
                local worstIndex, worstDist = 1, best[1].distance
                for i = 2, #best do
                    if best[i].distance > worstDist then
                        worstDist = best[i].distance
                        worstIndex = i
                    end
                end
                if dist < worstDist then best[worstIndex] = { instance = item, distance = dist } end
            end
        end
    end
    table.sort(best, function(a, b) return a.distance < b.distance end)
    return best
end
local function cookOnce()
    if not AutoCookEnabled then return end
    if not SelectedCookItems or #SelectedCookItems == 0 then print("[Cook] No items selected."); return end
    if not CookingStations or #CookingStations == 0 then print("[Cook] CookingStations kosong."); return end
    local targetSet = tableToSet(SelectedCookItems)
    print(string.format("[Cook] Mode: %s | Stations: %d", MoveMode or "unknown", #CookingStations))
    for _, station in ipairs(CookingStations) do
        if station and station.Parent then
            local base = getStationBase(station)
            if base then
                local candidates = collectCookCandidates(base, targetSet, CookItemsPerCycle)
                if #candidates == 0 then
                    print("[Cook] No candidates:", station.Name)
                else
                    local maxCount = math.min(CookItemsPerCycle, #candidates)
                    print(string.format("[Cook] %s | Use: %d candidates", station.Name, maxCount))
                    for i = 1, maxCount do
                        local entry = candidates[i]
                        local item = entry.instance
                        if item and item.Parent then
                            local dropCF = getCookDropCFrame(base, i)
                            pcall(function() if RequestStartDragging then RequestStartDragging:FireServer(item) end end)
                            task.wait(0.03)
                            pcall(function() item:PivotTo(dropCF) end)
                            task.wait(0.03)
                            pcall(function() if RequestStopDragging then RequestStopDragging:FireServer(item) end end)
                            print(string.format("[Cook] %s → %s (dist=%.1f)", item.Name, station.Name, entry.distance))
                            task.wait(0.03)
                        end
                    end
                end
            end
        else
            print("[Cook] Station invalid:", station and station.Name or "unknown")
        end
    end
end
local function startCookLoop()
    CookLoopId += 1
    local current = CookLoopId
    task.spawn(function()
        print("[Cook] Auto Crockpot start.")
        while AutoCookEnabled and current == CookLoopId and not scriptDisabled do
            cookOnce()
            task.wait(math.clamp(CookDelaySeconds, 5, 20))
        end
        print("[Cook] Auto Crockpot stop.")
    end)
end

---------------------------------------------------------
-- SCRAPPER (GRINDER)
---------------------------------------------------------
local function ensureScrapperTarget()
    if ScrapperTarget and ScrapperTarget.Parent then return true end
    local map = Workspace:FindFirstChild("Map")
    if not map then warn("[Scrap] workspace.Map tidak ditemukan."); ScrapperTarget = nil; return false end
    local camp = map:FindFirstChild("Campground")
    if not camp then warn("[Scrap] Map.Campground tidak ditemukan."); ScrapperTarget = nil; return false end
    local scrapper = camp:FindFirstChild("Scrapper")
    if not scrapper then warn("[Scrap] Campground.Scrapper tidak ditemukan."); ScrapperTarget = nil; return false end
    local movers = scrapper:FindFirstChild("Movers")
    if not movers then warn("[Scrap] Scrapper.Movers tidak ditemukan."); ScrapperTarget = nil; return false end
    local right = movers:FindFirstChild("Right")
    if not right then warn("[Scrap] Scrapper.Movers.Right tidak ditemukan."); ScrapperTarget = nil; return false end
    local grindersRight = right:FindFirstChild("GrindersRight")
    if not grindersRight or not grindersRight:IsA("BasePart") then warn("[Scrap] GrindersRight tidak ditemukan / bukan BasePart."); ScrapperTarget = nil; return false end
    ScrapperTarget = grindersRight
    print("[Scrap] Scrapper target:", getInstancePath(ScrapperTarget))
    return true
end
local function getScrapDropCFrame(scrapBase, index)
    local radius = 1.5
    local height = 6
    local angle = (index - 1) * (math.pi / 6)
    local basePos = scrapBase.Position
    local offsetX = math.cos(angle) * radius
    local offsetZ = math.sin(angle) * radius
    return CFrame.new(basePos + Vector3.new(offsetX, height, offsetZ))
end
local function scrapOnceFullPass()
    if not ScrapEnabled then return end
    if not ensureScrapperTarget() then print("[Scrap] Scrapper target belum siap."); return end
    local scrapBase = ScrapperTarget
    for _, name in ipairs(ScrapItemsPriority) do
        if not ScrapEnabled or scriptDisabled then return end
        local batch = {}
        if ItemsFolder then
            for _, item in ipairs(ItemsFolder:GetChildren()) do
                if item:IsA("Model") and item.PrimaryPart and item.Name == name then
                    local dist = (item.PrimaryPart.Position - scrapBase.Position).Magnitude
                    table.insert(batch, { instance = item, distance = dist })
                end
            end
        end
        if #batch > 0 then
            table.sort(batch, function(a, b) return a.distance < b.distance end)
            print(string.format("[Scrap] %s | jumlah=%d", name, #batch))
            for i, entry in ipairs(batch) do
                if not ScrapEnabled or scriptDisabled then return end
                local item = entry.instance
                if item and item.Parent then
                    local dropCF = getScrapDropCFrame(scrapBase, i)
                    pcall(function() if RequestStartDragging then RequestStartDragging:FireServer(item) end end)
                    task.wait(0.02)
                    pcall(function() item:PivotTo(dropCF) end)
                    task.wait(0.02)
                    pcall(function() if RequestStopDragging then RequestStopDragging:FireServer(item) end end)
                    print(string.format("[Scrap] %s → Grinder (dist=%.1f)", item.Name, entry.distance or -1))
                    task.wait(0.02)
                end
            end
        end
    end
end
local function startScrapLoop()
    ScrapLoopId += 1
    local current = ScrapLoopId
    task.spawn(function()
        print("[Scrap] Auto Scrapper start.")
        while ScrapEnabled and current == ScrapLoopId and not scriptDisabled do
            scrapOnceFullPass()
            task.wait(math.clamp(ScrapScanInterval, 10, 300))
        end
        print("[Scrap] Auto Scrapper stop.")
    end)
end

---------------------------------------------------------
-- GODMODE & ANTI AFK
---------------------------------------------------------
local function startGodmodeLoop()
    task.spawn(function()
        while not scriptDisabled do
            if GodmodeEnabled then
                pcall(function()
                    if RemoteEvents then
                        local dmg = RemoteEvents:FindFirstChild("DamagePlayer")
                        if dmg then dmg:FireServer(-math.huge) end
                    end
                end)
            end
            task.wait(8)
        end
    end)
end
local function initAntiAFK()
    LocalPlayer.Idled:Connect(function()
        if scriptDisabled then return end
        if not AntiAFKEnabled then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

---------------------------------------------------------
-- ULTRA COIN & AMMO
---------------------------------------------------------
local function stopCoinAmmo()
    CoinAmmoEnabled = false
    if coinAmmoDescAddedConn then coinAmmoDescAddedConn:Disconnect(); coinAmmoDescAddedConn = nil end
    if CoinAmmoConnection then CoinAmmoConnection:Disconnect(); CoinAmmoConnection = nil end
end
local function startCoinAmmo()
    stopCoinAmmo()
    CoinAmmoEnabled = true
    task.spawn(function()
        for _, v in ipairs(Workspace:GetDescendants()) do
            if not CoinAmmoEnabled or scriptDisabled then break end
            pcall(function()
                if v.Name == "Coin Stack" and CollectCoinRemote then
                    CollectCoinRemote:InvokeServer(v)
                elseif (v.Name == "Revolver Ammo" or v.Name == "Rifle Ammo") and ConsumeItemRemote then
                    ConsumeItemRemote:InvokeServer(v)
                end
            end)
        end
        notifyUI("Ultra Coin & Ammo", "Initial collect selesai. Listening spawn baru...", 4, "zap")
        coinAmmoDescAddedConn = Workspace.DescendantAdded:Connect(function(desc)
            if not CoinAmmoEnabled or scriptDisabled then return end
            task.wait(0.01)
            pcall(function()
                if desc.Name == "Coin Stack" and CollectCoinRemote then
                    CollectCoinRemote:InvokeServer(desc)
                elseif (desc.Name == "Revolver Ammo" or desc.Name == "Rifle Ammo") and ConsumeItemRemote then
                    ConsumeItemRemote:InvokeServer(desc)
                end
            end)
        end)
        while CoinAmmoEnabled and not scriptDisabled do task.wait(0.5) end
        stopCoinAmmo()
        print("[CoinAmmo] Dimatikan.")
    end)
end

---------------------------------------------------------
-- KILL AURA + CHOP AURA (Heartbeat)
---------------------------------------------------------
local nextAuraTick = 0
local function GetBestAxe(forTree)
    for name, id in pairs(AxeIDs) do
        if (not forTree) or (name ~= "Chainsaw" and name ~= "Spear") then
            local inv = LocalPlayer:FindFirstChild("Inventory")
            if inv then
                local tool = inv:FindFirstChild(name)
                if tool then return tool, id end
            end
        end
    end
    return nil, nil
end
local function EquipAxe(tool)
    if tool and EquipHandleRemote then
        pcall(function() EquipHandleRemote:FireServer("FireAllClients", tool) end)
    end
end
local function buildTreeCache()
    TreeCache = {}
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    local function scan(folder)
        if not folder then return end
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj.Name == "Small Tree" and obj:FindFirstChild("Trunk") then
                table.insert(TreeCache, obj)
            end
        end
    end
    scan(map:FindFirstChild("Foliage"))
    scan(map:FindFirstChild("Landmarks"))
    print(string.format("[ChopAura] Tree cache built, total %d trees.", #TreeCache))
end
auraHeartbeatConnection = RunService.Heartbeat:Connect(function()
    if scriptDisabled then return end
    if (not KillAuraEnabled) and (not ChopAuraEnabled) then return end
    local now = tick()
    if now < nextAuraTick then return end
    nextAuraTick = now + AuraAttackDelay
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- KILL AURA
    if KillAuraEnabled then
        local axe, axeId = GetBestAxe(false)
        if axe and axeId and ToolDamageRemote then
            EquipAxe(axe)
            local charsFolder = Workspace:FindFirstChild("Characters")
            if charsFolder then
                for _, target in ipairs(charsFolder:GetChildren()) do
                    if target ~= char and target:IsA("Model") then
                        local root = target:FindFirstChildWhichIsA("BasePart")
                        if root and (root.Position - hrp.Position).Magnitude <= KillAuraRadius then
                            pcall(function()
                                ToolDamageRemote:InvokeServer(target, axe, axeId, CFrame.new(root.Position))
                            end)
                        end
                    end
                end
            end
        end
    end
    -- CHOP AURA
    if ChopAuraEnabled then
        if #TreeCache == 0 then buildTreeCache() end
        local axe = GetBestAxe(true)
        if axe and ToolDamageRemote then
            EquipAxe(axe)
            for i = #TreeCache, 1, -1 do
                local tree = TreeCache[i]
                if tree and tree.Parent and tree:FindFirstChild("Trunk") then
                    local trunk = tree.Trunk
                    if (trunk.Position - hrp.Position).Magnitude <= ChopAuraRadius then
                        pcall(function()
                            ToolDamageRemote:InvokeServer(tree, axe, "999_7367831688",
                                CFrame.new(-2.962610244751,4.5547881126404,-75.950843811035,
                                           0.89621275663376,-1.3894891459643e-8,0.44362446665764,
                                           -7.994568895775e-10,1,3.293635941759e-8,
                                           -0.44362446665764,-2.9872644802253e-8,0.89621275663376))
                        end)
                    end
                else
                    table.remove(TreeCache, i)
                end
            end
        end
    end
end)

---------------------------------------------------------
-- TEMPORAL / NIGHT SKIP
---------------------------------------------------------
local function activateTemporal()
    if scriptDisabled then return end
    if not TemporalAccelerometer or not TemporalAccelerometer.Parent then
        Structures = Workspace:FindFirstChild("Structures") or Structures
        TemporalAccelerometer = Structures and Structures:FindFirstChild("Temporal Accelerometer") or TemporalAccelerometer
    end
    if not TemporalAccelerometer then
        warn("[Temporal] Temporal Accelerometer tidak ditemukan.")
        notifyUI("Temporal", "Temporal Accelerometer belum tersedia.", 4, "alert-triangle")
        return
    end
    if NightSkipRemote then
        NightSkipRemote:FireServer(TemporalAccelerometer)
        print("[Temporal] RequestActivate dikirim.")
    end
end

---------------------------------------------------------
-- WEBHOOK HELPERS
---------------------------------------------------------
local function namesToVerticalList(names)
    if type(names) ~= "table" or #names == 0 then return "_Tidak ada pemain aktif_" end
    local lines = {}
    for _, n in ipairs(names) do table.insert(lines, "- " .. tostring(n)) end
    return table.concat(lines, "\n")
end
local function try_syn_request(url, body)
    if not syn or not syn.request then return false, "syn.request not available" end
    local ok, res = pcall(function()
        return syn.request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
    end)
    if not ok then return false, res end
    return true, res
end
local function try_request(url, body)
    if not request then return false, "request not available" end
    local ok, res = pcall(function()
        return request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
    end)
    if not ok then return false, res end
    return true, res
end
local function try_httpservice_post(url, body)
    local ok, res = pcall(function()
        return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
    end)
    return ok, res
end
local function buildDayEmbed(currentDay, previousDay, bedCount, kidCount, itemsList, isTest)
    local players = Players:GetPlayers()
    local names = {}
    for _, p in ipairs(players) do table.insert(names, p.Name) end
    local prev = tostring(previousDay or "N/A")
    local cur = tostring(currentDay or "N/A")
    local delta = "N/A"
    if tonumber(cur) and tonumber(prev) then delta = tostring(tonumber(cur) - tonumber(prev)) end
    local sampleItems = ""
    if type(itemsList) == "table" and #itemsList > 0 then
        local limit = math.min(#itemsList, 6)
        for i = 1, limit do sampleItems = sampleItems .. "• `" .. tostring(itemsList[i]) .. "`\n" end
        if #itemsList > limit then sampleItems = sampleItems .. "• `...and more`" end
    else
        sampleItems = "_No items recorded_"
    end
    local titlePrefix = isTest and "🧪 TEST - " or ""
    local title = string.format("%s🌅 DAY PROGRESSION UPDATE %s", titlePrefix, cur)
    local subtitle = "Ringkasan hari, pemain aktif, dan item penting."
    local playerListValue = namesToVerticalList(names)
    if #playerListValue > 1024 then
        local sample = {}
        for i = 1, math.min(#names, 15) do table.insert(sample, names[i]) end
        playerListValue = namesToVerticalList(sample) .. "\n- ...and more"
    end
    local embed = {
        title = title,
        description = table.concat({
            "✨ **" .. subtitle .. "**",
            "",
            string.format("📆 **Progress:** `%s → %s` • **Δ**: `%s` hari", prev, cur, delta),
            string.format("🛏️ **Beds:** `%s` 👶 **Kids:** `%s`", tostring(bedCount or 0), tostring(kidCount or 0)),
            string.format("🎮 **Players Online:** `%s`", tostring(#names)),
            "",
            "🎒 **Item Highlights:**",
            sampleItems
        }, "\n"),
        color = 0xFAA61A,
        fields = {
            { name = "📈 Perubahan Hari", value = string.format("`%s` → `%s` (Δ %s)", prev, cur, tostring(delta)), inline = true },
            { name = "🎮 Jumlah Pemain", value = "`" .. tostring(#names) .. "`", inline = true },
            { name = "🧍 Pemain Aktif (list)", value = playerListValue, inline = false },
        },
        footer = { text = "🕒 Update generated at " .. os.date("%Y-%m-%d %H:%M:%S") }
    }
    local payload = { username = WebhookUsername or "Day Monitor", embeds = { embed } }
    return payload
end
local function sendWebhookPayload(payloadTable)
    if not WebhookURL or trim(WebhookURL) == "" then return false, "Webhook URL kosong" end
    local body = HttpService:JSONEncode(payloadTable)
    local ok1, res1 = try_syn_request(WebhookURL, body)
    if ok1 then
        if type(res1) == "table" and res1.StatusCode then
            if res1.StatusCode >= 200 and res1.StatusCode < 300 then return true, ("syn.request: HTTP %d"):format(res1.StatusCode) end
            return false, ("syn.request: HTTP %d"):format(res1.StatusCode)
        end
        return true, "syn.request: success"
    end
    local ok2, res2 = try_request(WebhookURL, body)
    if ok2 then
        if type(res2) == "table" and res2.StatusCode then
            if res2.StatusCode >= 200 and res2.StatusCode < 300 then return true, ("request: HTTP %d"):format(res2.StatusCode) end
            return false, ("request: HTTP %d"):format(res2.StatusCode)
        end
        return true, "request: success"
    end
    local ok3, res3 = try_httpservice_post(WebhookURL, body)
    if ok3 then return true, "HttpService:PostAsync success" end
    local errmsg = ("syn_err=%s | request_err=%s | http_err=%s"):format(tostring(res1), tostring(res2), tostring(res3))
    return false, errmsg
end
_G.SendManualDay = function(cur, prev, items)
    local curN, prevN = tonumber(cur) or cur, tonumber(prev) or prev
    local beds, kids = 0, 0
    if type(items) == "table" then
        for _, v in ipairs(items) do
            if type(v) == "string" then
                local s = v:lower()
                if s:find("bed") then beds = beds + 1 end
                if s:find("child") or s:find("kid") then kids = kids + 1 end
            end
        end
    end
    local payload = buildDayEmbed(curN, prevN, beds, kids, items, false)
    local ok, msg = sendWebhookPayload(payload)
    print("Manual send result:", ok, msg)
    return ok, msg
end

---------------------------------------------------------
-- DAYDISPLAY (non-blocking hook)
---------------------------------------------------------
local function tryHookDayDisplay()
    if DayDisplayConnection then DayDisplayConnection:Disconnect(); DayDisplayConnection = nil end
    local function attach(remote)
        if not remote or not remote.OnClientEvent then return end
        DayDisplayRemote = remote
        DayDisplayConnection = DayDisplayRemote.OnClientEvent:Connect(function(...)
            if scriptDisabled then return end
            local args = { ... }
            if #args == 1 then
                local dayNumber = args[1]
                if type(dayNumber) ~= "number" then return end
                if not autoTemporalEnabled then return end
                if dayNumber == lastProcessedDay then return end
                lastProcessedDay = dayNumber
                print("[Temporal] Day", dayNumber, "terdeteksi. Auto skip 5 detik...")
                task.delay(5, function()
                    if scriptDisabled or not autoTemporalEnabled then return end
                    activateTemporal()
                    end)
                return
            end
            local currentDay = tonumber(args[1]) or args[1]
            local previousDay = tonumber(args[2]) or args[2] or 0
            local itemsList = args[3]
            currentDayCached = currentDay
            previousDayCached = previousDay
            print("DayDisplay event:", currentDay, previousDay)
            if type(currentDay) == "number" and type(previousDay) == "number" then
                if currentDay > previousDay then
                    local bedCount, kidCount = 0, 0
                    if type(itemsList) == "table" then
                        for _, v in ipairs(itemsList) do
                            if type(v) == "string" then
                                local s = v:lower()
                                if s:find("bed") then bedCount = bedCount + 1 end
                                if s:find("child") or s:find("kid") then kidCount = kidCount + 1 end
                            end
                        end
                    end
                    local payload = buildDayEmbed(currentDay, previousDay, bedCount, kidCount, itemsList, false)
                    print(("Days increased: %s -> %s | beds=%d kids=%d"):format(tostring(previousDay), tostring(currentDay), bedCount, kidCount))
                    if WebhookEnabled then
                        local ok, msg = sendWebhookPayload(payload)
                        if ok then notifyUI("Webhook Sent", "Day " .. tostring(previousDay) .. " → " .. tostring(currentDay), 6, "radio") end
                        if not ok then notifyUI("Webhook Failed", tostring(msg), 6, "alert-triangle"); warn("Day webhook failed:", msg) end
                    else
                        notifyUI("Day Increased", "Day " .. tostring(previousDay) .. " → " .. tostring(currentDay) .. " (webhook OFF)", 5, "calendar")
                    end
                else
                    print("DayDisplay event tanpa kenaikan day:", previousDay, "->", currentDay)
                end
            else
                print("DayDisplay event non-numeric:", tostring(currentDay), tostring(previousDay))
            end
        end)
        print("[DayDisplay] Listener terpasang ke:", getInstancePath(remote))
        notifyUI("DayDisplay", "Listener terpasang.", 4, "radio")
    end
    if RemoteEvents and RemoteEvents:FindFirstChild("DayDisplay") then
        attach(RemoteEvents:FindFirstChild("DayDisplay"))
        return
    elseif ReplicatedStorage:FindFirstChild("DayDisplay") then
        attach(ReplicatedStorage:FindFirstChild("DayDisplay"))
        return
    end
    task.spawn(function()
        local found = false
        local tries = 0
        while not found and tries < 120 and not scriptDisabled do
            tries += 1
            if RemoteEvents and RemoteEvents:FindFirstChild("DayDisplay") then
                attach(RemoteEvents:FindFirstChild("DayDisplay")); found = true; break
            end
            if ReplicatedStorage:FindFirstChild("DayDisplay") then
                attach(ReplicatedStorage:FindFirstChild("DayDisplay")); found = true; break
            end
            task.wait(0.5)
        end
        if not found then
            warn("[DayDisplay] DayDisplay tidak ditemukan setelah timeout.")
            notifyUI("DayDisplay", "DayDisplay remote tidak ditemukan (timeout). Fitur DayDisplay/Webhook menunggu.", 6, "alert-triangle")
        end
    end)
end

---------------------------------------------------------
-- RESET / CLEANUP
---------------------------------------------------------
function resetAll()
    scriptDisabled = true
    AutoCookEnabled = false
    ScrapEnabled = false
    AutoSacEnabled = false
    GodmodeEnabled = false
    AntiAFKEnabled = false
    CoinAmmoEnabled = false
    autoTemporalEnabled = false
    KillAuraEnabled = false
    ChopAuraEnabled = false
    TreeCache = {}
    CookLoopId += 1
    ScrapLoopId += 1
    stopCoinAmmo()
    stopFly()
    stopTPWalk()
    stopInfiniteJump()
    disableFullBright()
    disableInstantOpen()
    stopZone()
    fishingAutoClickEnabled = false
    if DayDisplayConnection then DayDisplayConnection:Disconnect(); DayDisplayConnection = nil end
    if auraHeartbeatConnection then auraHeartbeatConnection:Disconnect(); auraHeartbeatConnection = nil end
    if coinAmmoDescAddedConn then coinAmmoDescAddedConn:Disconnect(); coinAmmoDescAddedConn = nil end
    if miniHudGui then pcall(function() miniHudGui:Destroy() end); miniHudGui = nil end
    if Window then pcall(function() Window:Destroy() end); Window = nil end
    print("[PapiDimz] Semua fitur dimatikan & UI dibersihkan.")
end

---------------------------------------------------------
-- STATUS / HEALTH
---------------------------------------------------------
local function getStatusSummary()
    local uptimeStr = formatTime(os.clock() - scriptStartTime)
    local pingMs = math.floor((LocalPlayer:GetNetworkPing() or 0) * 1000 + 0.5)
    local lavaStr = lavaFound and "Ready" or "Scanning..."
    local featStr = getFeatureCodes()
    local msg = table.concat({
        "UPTIME : " .. uptimeStr,
        "LAVA : " .. lavaStr,
        string.format("PING : %d ms", pingMs),
        string.format("FPS : %d", currentFPS),
        "FITUR : " .. featStr
    }, "\n")
    return msg
end

---------------------------------------------------------
-- MAP / CAMP SCANNER
---------------------------------------------------------
local function scanCampground()
    local map = Workspace:FindFirstChild("Map")
    if not map then
        warn("[Scan] workspace.Map tidak ditemukan.")
        return
    end
    local camp = map:FindFirstChild("Campground")
    if not camp then
        warn("[Scan] Map.Campground tidak ditemukan.")
        return
    end
    local descendants = camp:GetDescendants()
    local lines = {}
    table.insert(lines, string.format("[Scan] Map.Campground - total %d descendants\n", #descendants))
    for _, inst in ipairs(descendants) do
        local path = getInstancePath(inst)
        local line = string.format("%s | %s", path, inst.ClassName)
        table.insert(lines, line)
    end
    local text = table.concat(lines, "\n")
    print(text)
    if typeof(setclipboard) == "function" then
        pcall(setclipboard, text)
        print("[Scan] List Campground dicopy ke clipboard.")
    else
        print("[Scan] setclipboard tidak tersedia, copy manual dari console.")
    end
end

---------------------------------------------------------
-- MAIN UI
---------------------------------------------------------
local function createMainUI()
    if Window then return end
    if WindUI then
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
        mainTab = Window:Tab({ Title = "Main", Icon = "settings-2" })
        localTab = Window:Tab({ Title = "Local Player", Icon = "user" })
        fishingTab = Window:Tab({ Title = "Fishing", Icon = "fish" })
        BringTab = Window:Tab({Title = "Bring Item", Icon = "hand"})
        TeleportTab = Window:Tab({Title = "Teleport", Icon = "navigation"})
        UpdateTab = Window:Tab({Title="Update Focused", Icon="snowflake"})
        farmTab = Window:Tab({ Title = "Farm", Icon = "chef-hat" })
        utilTab = Window:Tab({ Title = "Tools", Icon = "wrench" })
        nightTab = Window:Tab({ Title = "Night", Icon = "moon" })
        webhookTab = Window:Tab({ Title = "Webhook", Icon = "radio" })
        healthTab = Window:Tab({ Title = "Cek Health", Icon = "activity" })
    end

    if WindUI and mainTab then
        -- ==============================================
        -- Teleport Tab
        -- ==============================================
        -- Lost Child (seperti sebelumnya)
        local lostChildSec = TeleportTab:Section({Title = "Teleport Lost Child", Icon = "baby", Collapsible = true, DefaultOpen = true})
        local childOptions = {"DinoKid", "KoalaKid", "KrakenKid", "SquidKid"}
        local selectedChild = "DinoKid"
        lostChildSec:Dropdown({Title = "Select Child", Values = childOptions, Value = "DinoKid", Callback = function(v) selectedChild = v end})
        lostChildSec:Button({
            Title = "Teleport To Child",
            Callback = function()
                local hrp = nil
                if selectedChild == "DinoKid" then
                    hrp = Workspace.Characters:FindFirstChild("Lost Child") and Workspace.Characters["Lost Child"]:FindFirstChild("HumanoidRootPart")
                elseif selectedChild == "KoalaKid" then
                    hrp = Workspace.Characters:FindFirstChild("Lost Child4") and Workspace.Characters["Lost Child4"]:FindFirstChild("HumanoidRootPart")
                elseif selectedChild == "KrakenKid" then
                    hrp = Workspace.Characters:FindFirstChild("Lost Child2") and Workspace.Characters["Lost Child2"]:FindFirstChild("HumanoidRootPart")
                elseif selectedChild == "SquidKid" then
                    hrp = Workspace.Characters:FindFirstChild("Lost Child3") and Workspace.Characters["Lost Child3"]:FindFirstChild("HumanoidRootPart")
                end
                if hrp then
                    teleportToCFrame(hrp.CFrame)
                else
                    WindUI:Notify({Title="Error", Content=selectedChild.." tidak ditemukan!", Icon="alert-triangle"})
                end
            end
        })

        -- Structure Teleport (BARU!)
        local structureSec = TeleportTab:Section({
            Title = "Structure Teleport",
            Icon = "castle",            -- Icon bangunan / structure
            Collapsible = true,
            DefaultOpen = false
        })

        -- Teleport to Camp (ke Fire)
        structureSec:Button({
            Title = "Teleport to Camp",
            Callback = function()
                local firePath = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Campground")
                    and Workspace.Map.Campground:FindFirstChild("MainFire")
                    and Workspace.Map.Campground.MainFire:FindFirstChild("OuterTouchZone")
                if firePath then
                    teleportToCFrame(firePath.CFrame)
                else
                    WindUI:Notify({Title="Error", Content="Camp (Fire) tidak ditemukan!", Icon="alert-triangle"})
                end
            end
        })

        -- Teleport to Cultist Generator Base (asumsi path dari game, sesuaikan kalau ada info lebih)
        structureSec:Button({
            Title = "Teleport to Cultist Generator Base",
            Callback = function()
                -- Contoh path umum, sesuaikan kalau tahu exact
                local cultistBase = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("CultistGenerator")
                if cultistBase and cultistBase.PrimaryPart then
                    teleportToCFrame(cultistBase.PrimaryPart.CFrame)
                else
                    WindUI:Notify({Title="Error", Content="Cultist Generator Base tidak ditemukan!", Icon="alert-triangle"})
                end
            end
        })

        -- Teleport to Stronghold (prioritas Diamond Chest kalau ada)
        structureSec:Button({
            Title = "Teleport to Stronghold",
            Callback = function()
                local diamondChest = Workspace:FindFirstChild("Items")
                    and Workspace.Items:FindFirstChild("Stronghold Diamond Chest")
                    and Workspace.Items["Stronghold Diamond Chest"]:FindFirstChild("ChestLid")
                    and Workspace.Items["Stronghold Diamond Chest"].ChestLid:FindFirstChild("Meshes/diamondchest_Cube.005")
                if diamondChest then
                    teleportToCFrame(diamondChest.CFrame)
                    return
                end

                local sign = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("Stronghold")
                    and Workspace.Map.Landmarks.Stronghold:FindFirstChild("Building")
                    and Workspace.Map.Landmarks.Stronghold.Building:FindFirstChild("Sign")
                    and Workspace.Map.Landmarks.Stronghold.Building.Sign:FindFirstChild("Main")
                if sign then
                    teleportToCFrame(sign.CFrame)
                else
                    WindUI:Notify({Title="Error", Content="Stronghold tidak ditemukan!", Icon="alert-triangle"})
                end
            end
        })

        -- Teleport to Stronghold Diamond Chest (pisah button)
        structureSec:Button({
            Title = "Teleport to Stronghold Diamond Chest",
            Callback = function()
                local diamondChest = Workspace:FindFirstChild("Items")
                    and Workspace.Items:FindFirstChild("Stronghold Diamond Chest")
                    and Workspace.Items["Stronghold Diamond Chest"]:FindFirstChild("ChestLid")
                    and Workspace.Items["Stronghold Diamond Chest"].ChestLid:FindFirstChild("Meshes/diamondchest_Cube.005")
                if diamondChest then
                    teleportToCFrame(diamondChest.CFrame)
                else
                    WindUI:Notify({Title="Error", Content="Stronghold Diamond Chest tidak ditemukan!", Icon="alert-triangle"})
                end
            end
        })

        -- Teleport to Caravan
        structureSec:Button({
            Title = "Teleport to Caravan",
            Callback = function()
                local caravan = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("Caravan")
                if caravan and caravan.PrimaryPart then
                    teleportToCFrame(caravan.PrimaryPart.CFrame)
                else
                    WindUI:Notify({Title="Error", Content="Caravan tidak ditemukan!", Icon="alert-triangle"})
                end
            end
        })

        -- Teleport to Fairy
        structureSec:Button({
            Title = "Teleport to Fairy",
            Callback = function()
                local fairyHRP = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("Fairy House")
                    and Workspace.Map.Landmarks["Fairy House"]:FindFirstChild("Fairy")
                    and Workspace.Map.Landmarks["Fairy House"].Fairy:FindFirstChild("HumanoidRootPart")
                if fairyHRP then
                    teleportToCFrame(fairyHRP.CFrame)
                else
                    WindUI:Notify({Title="Error", Content="Fairy tidak ditemukan!", Icon="alert-triangle"})
                end
            end
        })

        -- Teleport to Anvil
        structureSec:Button({
            Title = "Teleport to Anvil",
            Callback = function()
                local anvil = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("ToolWorkshop")
                    and Workspace.Map.Landmarks.ToolWorkshop:FindFirstChild("Functional")
                    and Workspace.Map.Landmarks.ToolWorkshop.Functional:FindFirstChild("ToolBench")
                    and Workspace.Map.Landmarks.ToolWorkshop.Functional.ToolBench:FindFirstChild("Hammer")
                if anvil then
                    teleportToCFrame(anvil.CFrame)
                else
                    WindUI:Notify({Title="Error", Content="Anvil tidak ditemukan!", Icon="alert-triangle"})
                end
            end
        })

        -- CHRISTMAS SECTION
        local christmasSec = UpdateTab:Section({Title="Christmas",Icon="gift",DefaultOpen=true})

        christmasSec:Button({
            Title="Teleport to Christmas Present",
            Callback=function()
                local p = Workspace.Items:FindFirstChild("ChristmasPresent1")
                local part = p and (p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart",true))
                teleportToCFrame(part and part.CFrame)
            end
        })

        christmasSec:Button({
            Title="Teleport to Santa's Sack",
            Callback=function()
                local sled = Workspace.Map.Landmarks["Santa's Sack"].SantaSack.Sled
                teleportToCFrame(
                    (sled.Rail and sled.Rail.Part and sled.Rail.Part.CFrame)
                    or (sled.Engine and sled.Engine.CFrame)
                )
            end
        })

        local optList={"North Pole","Elf Tree","Elf Ice Lake","Elf Ice Race"}
        local selectedOpt="North Pole"

        christmasSec:Dropdown({
            Title="Teleport Options",
            Values=optList,
            Value="North Pole",
            Callback=function(v) selectedOpt=v end
        })

        christmasSec:Button({
            Title="Teleport",
            Callback=function()
                local t=nil
                if selectedOpt=="North Pole" then
                    local np = Workspace.Map.Landmarks:FindFirstChild("North Pole")
                        and Workspace.Map.Landmarks["North Pole"]:FindFirstChild("Festive Carpet Blueprint")

                    t =
                        np and np:FindFirstChild("GraphLines")
                        or np and np:FindFirstChild("Star")
                elseif selectedOpt=="Elf Tree" then
                    t=Workspace.Map.Landmarks["Elf Tree"].Trees["Northern Pine"].TrunkPart
                elseif selectedOpt=="Elf Ice Lake" then
                    local l=Workspace.Map.Landmarks["Elf Ice Lake"]
                    t=l:FindFirstChild("Main") or l.GrassFolder:FindFirstChild("Grass")
                elseif selectedOpt=="Elf Ice Race" then
                    t=Workspace.Map.Landmarks["Elf Ice Race"].Obstacles.SnowStoneTall.Part
                end
                teleportToCFrame(t and t.CFrame)
            end
        })

        -- MAZE SECTION
        local mazeSec = UpdateTab:Section({Title="Maze",Icon="map"})
        mazeSec:Button({
            Title="TP to End",
            Callback=function()
                local chest = Workspace.Items:FindFirstChild("Halloween Maze Chest")
                local target =
                    chest and chest:FindFirstChild("Main")
                    or chest and chest:FindFirstChild("ItemDrop")

                teleportToCFrame(target and target.CFrame)
            end
        })

        -- ==============================================
        -- Bring Item Tab (tetap sama)
        -- ==============================================
        local settingSec = BringTab:Section({Title = "Bring Setting", Icon = "settings", Collapsible = true, DefaultOpen = true})
        settingSec:Dropdown({Title = "Location", Desc = "Player / Workbench (Scrapper) / Fire", Values = {"Player", "Workbench", "Fire"}, Value = "Player", Callback = function(v) selectedLocation = v end})
        settingSec:Input({Title = "Bring Height", Placeholder = "20", Default = "20", Numeric = true, Callback = function(v) BringHeight = tonumber(v) or 20 end})

        local cultistSec = BringTab:Section({Title = "Bring Cultist", Icon = "skull", Collapsible = true})
        local cultistList = {"All", "Crossbow Cultist", "Cultist"}
        local selCultist = {"All"}
        cultistSec:Dropdown({Title="Pilih Cultist", Values=cultistList, Value={"All"}, Multi=true, AllowNone=true, Callback=function(o) selCultist=o or {"All"} end})
        cultistSec:Button({Title="Bring Cultist", Callback=function() bringItems(cultistList, selCultist, selectedLocation) end})

        local meteorSec = BringTab:Section({Title = "Bring Meteor Items", Icon = "zap", Collapsible = true})
        local meteorList = {"All", "Raw Obsidiron Ore", "Gold Shard", "Meteor Shard", "Scalding Obsidiron Ingot"}
        local selMeteor = {"All"}
        meteorSec:Dropdown({Title="Pilih Item", Values=meteorList, Value={"All"}, Multi=true, AllowNone=true, Callback=function(o) selMeteor=o or {"All"} end})
        meteorSec:Button({Title="Bring Meteor", Callback=function() bringItems(meteorList, selMeteor, selectedLocation) end})

        local fuelSec = BringTab:Section({Title = "Fuels", Icon = "flame", Collapsible = true})
        local fuelList = {"All", "Log", "Coal", "Chair", "Fuel Canister", "Oil Barrel"}
        local selFuel = {"All"}
        fuelSec:Dropdown({Title="Pilih Fuel", Values=fuelList, Value={"All"}, Multi=true, AllowNone=true, Callback=function(o) selFuel=o or {"All"} end})
        fuelSec:Button({Title="Bring Fuels", Callback=function() bringItems(fuelList, selFuel, selectedLocation) end})
        fuelSec:Button({Title="Bring Logs Only", Callback=function() bringItems(fuelList, {"Log"}, selectedLocation) end})

        local foodSec = BringTab:Section({Title = "Food", Icon = "drumstick", Collapsible = true})
        local foodList = {"All", "Sweet Potato", "Stuffing", "Turkey Leg", "Carrot", "Pumkin", "Mackerel", "Salmon", "Swordfish", "Berry", "Ribs", "Stew", "Steak Dinner", "Morsel", "Steak", "Corn", "Cooked Morsel", "Cooked Steak", "Chilli", "Apple", "Cake"}
        local selFood = {"All"}
        foodSec:Dropdown({Title="Pilih Food", Values=foodList, Value={"All"}, Multi=true, AllowNone=true, Callback=function(o) selFood=o or {"All"} end})
        foodSec:Button({Title="Bring Food", Callback=function() bringItems(foodList, selFood, selectedLocation) end})

        local healSec = BringTab:Section({Title = "Healing", Icon = "heart", Collapsible = true})
        local healList = {"All", "Medkit", "Bandage"}
        local selHeal = {"All"}
        healSec:Dropdown({Title="Pilih Healing", Values=healList, Value={"All"}, Multi=true, AllowNone=true, Callback=function(o) selHeal=o or {"All"} end})
        healSec:Button({Title="Bring Healing", Callback=function() bringItems(healList, selHeal, selectedLocation) end})

        local gearSec = BringTab:Section({Title = "Gears (Scrap)", Icon = "wrench", Collapsible = true})
        local gearList = {"All", "Bolt", "Tyre", "Sheet Metal", "Old Radio", "Broken Fan", "Broken Microwave", "Washing Machine", "Old Car Engine", "UFO Scrap", "UFO Component", "UFO Junk", "Cultist Gem", "Gem of the Forest"}
        local selGear = {"All"}
        gearSec:Dropdown({Title="Pilih Gear", Values=gearList, Value={"All"}, Multi=true, AllowNone=true, Callback=function(o) selGear=o or {"All"} end})
        gearSec:Button({Title="Bring Gears", Callback=function() bringItems(gearList, selGear, selectedLocation) end})

        local gunSec = BringTab:Section({Title = "Guns & Ammo", Icon = "swords", Collapsible = true})
        local gunList = {"All", "Infernal Sword", "Morningstar", "Crossbow", "Infernal Crossbow", "Laser Sword", "Raygun", "Ice Axe", "Ice Sword", "Chainsaw", "Strong Axe", "Axe Trim Kit", "Spear", "Good Axe", "Revolver", "Rifle", "Tactical Shotgun", "Revolver Ammo", "Rifle Ammo", "Alien Armour", "Frog Boots", "Leather Body", "Iron Body", "Thorn Body", "Riot Shield", "Armour Trim Kit", "Obsidiron Boots"}
        local selGun = {"All"}
        gunSec:Dropdown({Title="Pilih Weapon", Values=gunList, Value={"All"}, Multi=true, AllowNone=true, Callback=function(o) selGun=o or {"All"} end})
        gunSec:Button({Title="Bring Guns & Ammo", Callback=function() bringItems(gunList, selGun, selectedLocation) end})

        local otherSec = BringTab:Section({Title = "Bring Other", Icon = "package", Collapsible = true})
        local otherList = {"All", "Purple Fur Tuft", "Halloween Candle", "Candy", "Frog Key", "Feather", "Wildfire", "Sacrifice Totem", "Old Rod", "Flower", "Coin Stack", "Infernal Sack", "Giant Sack", "Good Sack", "Seed Box", "Chainsaw", "Old Flashlight", "Strong Flashlight", "Bunny Foot", "Wolf Pelt", "Bear Pelt", "Mammoth Tusk", "Alpha Wolf Pelt", "Bear Corpse", "Meteor Shard", "Gold Shard", "Raw Obsidiron Ore", "Gem of the Forest", "Diamond", "Defense Blueprint"}
        local selOther = {"All"}
        otherSec:Dropdown({Title="Pilih Item", Values=otherList, Value={"All"}, Multi=true, AllowNone=true, Callback=function(o) selOther=o or {"All"} end})
        otherSec:Button({Title="Bring Other", Callback=function() bringItems(otherList, selOther, selectedLocation) end})
        
        -- ==============================================
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

-- INITIAL NON-BLOCKING RESOURCE WATCHERS
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
task.spawn(function() tryHookDayDisplay() end)
startGodmodeLoop()

---------------------------------------------------------
-- INIT
---------------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    defaultWalkSpeed = humanoid.WalkSpeed
    defaultHipHeight = humanoid.HipHeight
    applyWalkspeed()
    applyHipHeight()
    applyFOV()
    if flyEnabled then task.delay(0.2, startFly) end
end)
if LocalPlayer.Character then
    humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if humanoid then defaultWalkSpeed = humanoid.WalkSpeed; defaultHipHeight = humanoid.HipHeight end
end

print("[PapiDimz] HUB Loaded - All-in-One")
splashScreen()
createMainUI()
createMiniHud()
startMiniHudLoop()
initAntiAFK()
-- (all original background watchers and loops start here)

notifyUI("Papi Dimz |HUB", "Semua fitur loaded: Main, Local Player, Fishing, Farm, Tools, Night, Webhook, Health", 6, "sparkles")
