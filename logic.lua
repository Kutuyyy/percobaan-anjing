-- =====================================================
-- logic.lua
-- Papi Dimz | HUB
-- LOGIC ONLY - NO UI - NO WINDUI
-- PART 1: CORE + CHARACTER + BRING + TELEPORT
-- =====================================================

local Logic = {}

---------------------------------------------------------
-- SERVICES
---------------------------------------------------------
local Players               = game:GetService("Players")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local Workspace             = game:GetService("Workspace")
local RunService            = game:GetService("RunService")
local UserInputService      = game:GetService("UserInputService")
local VirtualUser           = game:GetService("VirtualUser")
local VirtualInputManager   = game:GetService("VirtualInputManager")
local Lighting              = game:GetService("Lighting")
local HttpService           = game:GetService("HttpService")

local LocalPlayer           = Players.LocalPlayer
local Camera                = Workspace.CurrentCamera

---------------------------------------------------------
-- SAFE NOTIFY BRIDGE (DIINJECT OLEH UI)
---------------------------------------------------------
Logic.notify = function(title, message)
    print("[LOGIC]", title, message)
end

---------------------------------------------------------
-- GLOBAL STATE
---------------------------------------------------------
Logic.state = {
    scriptDisabled = false,

    -- Bring
    BringHeight = 20,
    BringLocation = "Player",

    -- Toggles (dipakai UI)
    GodmodeEnabled = false,
    AntiAFKEnabled = true,

    FlyEnabled = false,
    FlySpeed = 50,

    FishingEnabled = false,
    AutoRecastEnabled = false,

    AutoCookEnabled = false,
    ScrapEnabled = false,
    AutoSacEnabled = false,

    KillAuraEnabled = false,
    ChopAuraEnabled = false,

    CoinAmmoEnabled = false,
    AutoTemporalEnabled = false,
}

---------------------------------------------------------
-- REMOTES (NON-BLOCKING)
---------------------------------------------------------
local RemoteEvents
local RequestStartDragging
local RequestStopDragging
local NightSkipRemote
local ToolDamageRemote
local EquipHandleRemote
local CollectCoinRemote
local ConsumeItemRemote

task.spawn(function()
    while not RemoteEvents do
        RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
        task.wait(0.5)
    end

    RequestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    RequestStopDragging  = RemoteEvents:FindFirstChild("StopDraggingItem")
    NightSkipRemote      = RemoteEvents:FindFirstChild("RequestActivateNightSkipMachine")
    ToolDamageRemote     = RemoteEvents:FindFirstChild("ToolDamageObject")
    EquipHandleRemote    = RemoteEvents:FindFirstChild("EquipItemHandle")
    CollectCoinRemote    = RemoteEvents:FindFirstChild("RequestCollectCoints")
    ConsumeItemRemote    = RemoteEvents:FindFirstChild("RequestConsumeItem")

    Logic.notify("Init", "RemoteEvents siap")
end)

---------------------------------------------------------
-- CHARACTER HELPERS (SAFE)
---------------------------------------------------------
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------
-- ITEM / STRUCTURE CACHE
---------------------------------------------------------
local ItemsFolder
local Structures

task.spawn(function()
    while not ItemsFolder do
        ItemsFolder = Workspace:FindFirstChild("Items")
        task.wait(0.5)
    end
end)

task.spawn(function()
    while not Structures do
        Structures = Workspace:FindFirstChild("Structures")
        task.wait(0.5)
    end
end)

---------------------------------------------------------
-- SCRAPPER TARGET (CACHED)
---------------------------------------------------------
local ScrapperTarget = nil

local function getScrapperTarget()
    if ScrapperTarget and ScrapperTarget.Parent then
        return ScrapperTarget
    end

    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end

    local camp = map:FindFirstChild("Campground")
    if not camp then return nil end

    local scrapper = camp:FindFirstChild("Scrapper")
    if not scrapper then return nil end

    local movers = scrapper:FindFirstChild("Movers")
    if not movers then return nil end

    local right = movers:FindFirstChild("Right")
    if not right then return nil end

    local grindersRight = right:FindFirstChild("GrindersRight")
    if grindersRight and grindersRight:IsA("BasePart") then
        ScrapperTarget = grindersRight
        return ScrapperTarget
    end

    return nil
end

---------------------------------------------------------
-- BRING TARGET POSITION
---------------------------------------------------------
local function getBringTargetPosition()
    local root = getRoot()
    if not root then return Vector3.zero end

    if Logic.state.BringLocation == "Player" then
        return root.Position + Vector3.new(0, Logic.state.BringHeight + 3, 0)

    elseif Logic.state.BringLocation == "Workbench" then
        local scrapper = getScrapperTarget()
        if scrapper then
            return scrapper.Position + Vector3.new(0, Logic.state.BringHeight, 0)
        end

    elseif Logic.state.BringLocation == "Fire" then
        local fire = Workspace:FindFirstChild("Map")
            and Workspace.Map:FindFirstChild("Campground")
            and Workspace.Map.Campground:FindFirstChild("MainFire")
            and Workspace.Map.Campground.MainFire:FindFirstChild("OuterTouchZone")

        if fire then
            return fire.Position + Vector3.new(0, Logic.state.BringHeight, 0)
        end
    end

    return root.Position + Vector3.new(0, Logic.state.BringHeight + 3, 0)
end

---------------------------------------------------------
-- BRING ITEM CORE
---------------------------------------------------------
function Logic.bringItems(itemList, selectedNames)
    if not ItemsFolder or not RequestStartDragging or not RequestStopDragging then
        Logic.notify("Bring", "Items / Remote belum siap")
        return
    end

    local targetPos = getBringTargetPosition()
    local wanted = {}

    if table.find(selectedNames, "All") then
        for _, n in ipairs(itemList) do
            if n ~= "All" then table.insert(wanted, n) end
        end
    else
        wanted = selectedNames
    end

    local candidates = {}

    for _, item in ipairs(ItemsFolder:GetChildren()) do
        if item:IsA("Model")
            and item.PrimaryPart
            and table.find(wanted, item.Name)
        then
            table.insert(candidates, item)
        end
    end

    if #candidates == 0 then
        Logic.notify("Bring", "Item tidak ditemukan")
        return
    end

    Logic.notify("Bring", "Membawa " .. tostring(#candidates) .. " item")

    for i, item in ipairs(candidates) do
        local angle = (i - 1) * (math.pi * 2 / 12)
        local offset = Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3)
        local cf = CFrame.new(targetPos + offset)

        pcall(function() RequestStartDragging:FireServer(item) end)
        task.wait(0.03)
        pcall(function() item:PivotTo(cf) end)
        task.wait(0.03)
        pcall(function() RequestStopDragging:FireServer(item) end)
        task.wait(0.02)
    end

    Logic.notify("Bring", "Selesai")
end

---------------------------------------------------------
-- TELEPORT
---------------------------------------------------------
function Logic.teleportToCFrame(cf)
    if not cf then return end
    local root = getRoot()
    if root then
        root.CFrame = cf + Vector3.new(0, 4, 0)
        Logic.notify("Teleport", "Berhasil")
    end
end
-- =====================================================
-- PART 2: FLY + LOCAL PLAYER + FISHING CORE
-- =====================================================

---------------------------------------------------------
-- LOCAL PLAYER DEFAULTS
---------------------------------------------------------
local humanoid
local rootPart
local defaultWalkSpeed = 16
local defaultHipHeight = 2
local defaultFOV = Camera.FieldOfView

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    defaultWalkSpeed = humanoid.WalkSpeed
    defaultHipHeight = humanoid.HipHeight
end)

if LocalPlayer.Character then
    humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if humanoid then
        defaultWalkSpeed = humanoid.WalkSpeed
        defaultHipHeight = humanoid.HipHeight
    end
end

---------------------------------------------------------
-- FLY (STEALTH CLIENT SIDE)
---------------------------------------------------------
local flyConn
local originalTransparency = {}
local idleAnimTrack

local function setCharacterInvisible(enable)
    local char = getCharacter()
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if enable then
                originalTransparency[part] = originalTransparency[part] or part.Transparency
                part.Transparency = 1
                part.CanCollide = false
            else
                part.Transparency = originalTransparency[part] or 0
                part.CanCollide = true
            end
        end
    end
end

local function playIdleAnimation()
    if not humanoid then return end
    if idleAnimTrack then idleAnimTrack:Stop() end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://180435571"
    idleAnimTrack = humanoid:LoadAnimation(anim)
    idleAnimTrack.Looped = true
    idleAnimTrack.Priority = Enum.AnimationPriority.Core
    idleAnimTrack:Play()
end

function Logic.startFly()
    if Logic.state.FlyEnabled then return end
    if not humanoid or not rootPart then return end

    Logic.state.FlyEnabled = true
    setCharacterInvisible(true)

    humanoid.PlatformStand = true
    rootPart.Anchored = true

    playIdleAnimation()

    flyConn = RunService.RenderStepped:Connect(function(dt)
        if not Logic.state.FlyEnabled then return end

        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.yAxis end

        if move.Magnitude > 0 then
            rootPart.CFrame += move.Unit * Logic.state.FlySpeed * dt
        end

        rootPart.CFrame = CFrame.new(rootPart.Position) * Camera.CFrame.Rotation
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end)

    Logic.notify("Fly", "Fly ON")
end

function Logic.stopFly()
    if not Logic.state.FlyEnabled then return end
    Logic.state.FlyEnabled = false

    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if idleAnimTrack then idleAnimTrack:Stop(); idleAnimTrack = nil end

    rootPart.Anchored = false
    humanoid.PlatformStand = false

    setCharacterInvisible(false)
    Logic.notify("Fly", "Fly OFF")
end

---------------------------------------------------------
-- WALKSPEED / HIP HEIGHT / FOV
---------------------------------------------------------
function Logic.setWalkSpeed(enabled, value)
    if not humanoid then return end
    humanoid.WalkSpeed = enabled and value or defaultWalkSpeed
end

function Logic.setHipHeight(enabled, value)
    if not humanoid then return end
    humanoid.HipHeight = enabled and value or defaultHipHeight
end

function Logic.setFOV(enabled, value)
    Camera.FieldOfView = enabled and value or defaultFOV
end

---------------------------------------------------------
-- TP WALK
---------------------------------------------------------
local tpWalkConn
function Logic.startTPWalk(speed)
    if tpWalkConn then return end
    tpWalkConn = RunService.RenderStepped:Connect(function(dt)
        if humanoid and rootPart and humanoid.MoveDirection.Magnitude > 0 then
            rootPart.CFrame += humanoid.MoveDirection.Unit * speed * dt * 10
        end
    end)
end

function Logic.stopTPWalk()
    if tpWalkConn then tpWalkConn:Disconnect(); tpWalkConn = nil end
end

---------------------------------------------------------
-- INFINITE JUMP
---------------------------------------------------------
local infJumpConn
function Logic.setInfiniteJump(state)
    if state and not infJumpConn then
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    elseif not state and infJumpConn then
        infJumpConn:Disconnect()
        infJumpConn = nil
    end
end

---------------------------------------------------------
-- FISHING (XENO GLASS CORE)
---------------------------------------------------------
local fishingPos = nil
local fishingDelay = 5

function Logic.setFishingPosition(x, y)
    fishingPos = { x = x, y = y }
    Logic.notify("Fishing", ("Position set (%d, %d)"):format(x, y))
end

function Logic.setFishingDelay(sec)
    fishingDelay = math.clamp(sec, 0.1, 600)
end

task.spawn(function()
    while true do
        if Logic.state.FishingEnabled and fishingPos then
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(
                    fishingPos.x, fishingPos.y, 0, true, game, 0
                )
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(
                    fishingPos.x, fishingPos.y, 0, false, game, 0
                )
            end)
        end
        task.wait(fishingDelay)
    end
end)
-- =====================================================
-- PART 3: FARM SYSTEMS (COOK, SCRAP, LAVA, COIN)
-- =====================================================

---------------------------------------------------------
-- AUTO CROCKPOT
---------------------------------------------------------
local CookingStations = {}
local CookDelaySeconds = 10
local CookItemsPerCycle = 5
local SelectedCookItems = { "Carrot", "Corn" }
local CookLoopId = 0

local function ensureCookingStations()
    if not Structures then return false end
    CookingStations = {}

    local crock = Structures:FindFirstChild("Crock Pot")
    local chef = Structures:FindFirstChild("Chefs Station")

    if crock then table.insert(CookingStations, crock) end
    if chef then table.insert(CookingStations, chef) end

    return #CookingStations > 0
end

local function getStationBase(station)
    return station.PrimaryPart or station:FindFirstChildWhichIsA("BasePart")
end

local function collectCookCandidates(basePart)
    local results = {}
    if not ItemsFolder then return results end

    local wanted = {}
    for _, v in ipairs(SelectedCookItems) do wanted[v] = true end

    for _, item in ipairs(ItemsFolder:GetChildren()) do
        if item:IsA("Model")
            and item.PrimaryPart
            and wanted[item.Name]
        then
            local dist = (item.PrimaryPart.Position - basePart.Position).Magnitude
            table.insert(results, { item = item, dist = dist })
        end
    end

    table.sort(results, function(a, b)
        return a.dist < b.dist
    end)

    return results
end

local function cookOnce()
    if not Logic.state.AutoCookEnabled then return end
    if #CookingStations == 0 then return end

    for _, station in ipairs(CookingStations) do
        local base = getStationBase(station)
        if base then
            local candidates = collectCookCandidates(base)
            for i = 1, math.min(#candidates, CookItemsPerCycle) do
                local item = candidates[i].item
                if item and item.Parent then
                    pcall(function()
                        RequestStartDragging:FireServer(item)
                        task.wait(0.03)
                        item:PivotTo(base.CFrame * CFrame.new(0, 3, 0))
                        task.wait(0.03)
                        RequestStopDragging:FireServer(item)
                    end)
                end
            end
        end
    end
end

function Logic.startAutoCook()
    if Logic.state.AutoCookEnabled then return end
    if not ensureCookingStations() then
        Logic.notify("Cook", "Cooking station tidak ditemukan")
        return
    end

    Logic.state.AutoCookEnabled = true
    CookLoopId += 1
    local id = CookLoopId

    task.spawn(function()
        while Logic.state.AutoCookEnabled and CookLoopId == id do
            cookOnce()
            task.wait(CookDelaySeconds)
        end
    end)

    Logic.notify("Cook", "Auto Crockpot ON")
end

function Logic.stopAutoCook()
    Logic.state.AutoCookEnabled = false
    CookLoopId += 1
    Logic.notify("Cook", "Auto Crockpot OFF")
end

---------------------------------------------------------
-- AUTO SCRAPPER
---------------------------------------------------------
local ScrapLoopId = 0
local ScrapItemsPriority = {
    "Bolt","Sheet Metal","Tyre","Old Radio",
    "Broken Fan","Broken Microwave","Old Car Engine",
    "UFO Junk","UFO Component","Cultist Gem"
}

local function scrapOnce()
    if not Logic.state.ScrapEnabled then return end
    local target = getScrapperTarget()
    if not target then return end

    for _, name in ipairs(ScrapItemsPriority) do
        if not Logic.state.ScrapEnabled then return end

        for _, item in ipairs(ItemsFolder:GetChildren()) do
            if item:IsA("Model")
                and item.PrimaryPart
                and item.Name == name
            then
                pcall(function()
                    RequestStartDragging:FireServer(item)
                    task.wait(0.02)
                    item:PivotTo(target.CFrame * CFrame.new(0, 6, 0))
                    task.wait(0.02)
                    RequestStopDragging:FireServer(item)
                end)
            end
        end
    end
end

function Logic.startAutoScrap()
    if Logic.state.ScrapEnabled then return end
    Logic.state.ScrapEnabled = true
    ScrapLoopId += 1
    local id = ScrapLoopId

    task.spawn(function()
        while Logic.state.ScrapEnabled and ScrapLoopId == id do
            scrapOnce()
            task.wait(60)
        end
    end)

    Logic.notify("Scrap", "Auto Scrapper ON")
end

function Logic.stopAutoScrap()
    Logic.state.ScrapEnabled = false
    ScrapLoopId += 1
    Logic.notify("Scrap", "Auto Scrapper OFF")
end

---------------------------------------------------------
-- AUTO SACRIFICE LAVA
---------------------------------------------------------
local LavaCFrame
local lavaFound = false
local SacrificeList = {
    "Morsel","Cooked Morsel","Steak","Cooked Steak",
    "Lava Eel","Cooked Lava Eel","Lionfish","Cooked Lionfish"
}

local function findLava()
    if lavaFound then return end
    local map = Workspace:FindFirstChild("Map")
    if not map then return end

    local volcano = map:FindFirstChild("Landmarks")
        and map.Landmarks:FindFirstChild("Volcano")
        and map.Landmarks.Volcano:FindFirstChild("Functional")
        and map.Landmarks.Volcano.Functional:FindFirstChild("Lava")

    if volcano then
        LavaCFrame = volcano.CFrame * CFrame.new(0, 4, 0)
        lavaFound = true
        Logic.notify("Lava", "Lava ditemukan")
    end
end

task.spawn(function()
    while not lavaFound do
        findLava()
        task.wait(1.5)
    end
end)

task.spawn(function()
    while true do
        if Logic.state.AutoSacEnabled and lavaFound then
            for _, item in ipairs(ItemsFolder:GetChildren()) do
                if item:IsA("Model")
                    and item.PrimaryPart
                    and table.find(SacrificeList, item.Name)
                then
                    pcall(function()
                        RequestStartDragging:FireServer(item)
                        task.wait(0.05)
                        item:PivotTo(LavaCFrame)
                        task.wait(0.05)
                        RequestStopDragging:FireServer(item)
                    end)
                end
            end
        end
        task.wait(0.8)
    end
end)

---------------------------------------------------------
-- ULTRA COIN & AMMO
---------------------------------------------------------
local coinConn

function Logic.startCoinAmmo()
    if Logic.state.CoinAmmoEnabled then return end
    Logic.state.CoinAmmoEnabled = true

    coinConn = Workspace.DescendantAdded:Connect(function(obj)
        if not Logic.state.CoinAmmoEnabled then return end
        pcall(function()
            if obj.Name == "Coin Stack" and CollectCoinRemote then
                CollectCoinRemote:InvokeServer(obj)
            elseif (obj.Name == "Revolver Ammo" or obj.Name == "Rifle Ammo")
                and ConsumeItemRemote then
                ConsumeItemRemote:InvokeServer(obj)
            end
        end)
    end)

    Logic.notify("Coin", "Ultra Coin & Ammo ON")
end

function Logic.stopCoinAmmo()
    Logic.state.CoinAmmoEnabled = false
    if coinConn then coinConn:Disconnect(); coinConn = nil end
    Logic.notify("Coin", "Ultra Coin & Ammo OFF")
end
-- =====================================================
-- PART 4: AURA + TEMPORAL / NIGHT SKIP
-- =====================================================

---------------------------------------------------------
-- KILL AURA & CHOP AURA
---------------------------------------------------------
local AuraRadius = 100
local AuraDelay = 0.16
local nextAuraTick = 0

local AxeIDs = {
    ["Old Axe"]    = "3_7367831688",
    ["Good Axe"]   = "112_7367831688",
    ["Strong Axe"] = "116_7367831688",
    Chainsaw       = "647_8992824875",
    Spear          = "196_8999010016"
}

local TreeCache = {}

local function getBestAxe(forTree)
    local inv = LocalPlayer:FindFirstChild("Inventory")
    if not inv then return nil, nil end

    for name, id in pairs(AxeIDs) do
        if not forTree or (name ~= "Chainsaw" and name ~= "Spear") then
            local tool = inv:FindFirstChild(name)
            if tool then
                return tool, id
            end
        end
    end
    return nil, nil
end

local function equipAxe(tool)
    if tool and EquipHandleRemote then
        pcall(function()
            EquipHandleRemote:FireServer("FireAllClients", tool)
        end)
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
end

RunService.Heartbeat:Connect(function()
    if Logic.state.scriptDisabled then return end
    if not (Logic.state.KillAuraEnabled or Logic.state.ChopAuraEnabled) then return end

    local now = tick()
    if now < nextAuraTick then return end
    nextAuraTick = now + AuraDelay

    local char = LocalPlayer.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -----------------------------------------------------
    -- KILL AURA
    -----------------------------------------------------
    if Logic.state.KillAuraEnabled and ToolDamageRemote then
        local axe, axeId = getBestAxe(false)
        if axe and axeId then
            equipAxe(axe)
            local chars = Workspace:FindFirstChild("Characters")
            if chars then
                for _, target in ipairs(chars:GetChildren()) do
                    if target ~= char and target:IsA("Model") then
                        local root = target:FindFirstChildWhichIsA("BasePart")
                        if root and (root.Position - hrp.Position).Magnitude <= AuraRadius then
                            pcall(function()
                                ToolDamageRemote:InvokeServer(
                                    target,
                                    axe,
                                    axeId,
                                    CFrame.new(root.Position)
                                )
                            end)
                        end
                    end
                end
            end
        end
    end

    -----------------------------------------------------
    -- CHOP AURA
    -----------------------------------------------------
    if Logic.state.ChopAuraEnabled and ToolDamageRemote then
        if #TreeCache == 0 then buildTreeCache() end
        local axe, axeId = getBestAxe(true)
        if axe and axeId then
            equipAxe(axe)
            for i = #TreeCache, 1, -1 do
                local tree = TreeCache[i]
                if tree and tree.Parent and tree:FindFirstChild("Trunk") then
                    local trunk = tree.Trunk
                    if (trunk.Position - hrp.Position).Magnitude <= AuraRadius then
                        pcall(function()
                            ToolDamageRemote:InvokeServer(
                                tree,
                                axe,
                                axeId,
                                trunk.CFrame
                            )
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
local lastProcessedDay = nil
local DayDisplayRemote
local DayDisplayConnection

local function activateTemporal()
    if not NightSkipRemote then return end
    if not Structures then return end

    local temporal = Structures:FindFirstChild("Temporal Accelerometer")
    if temporal then
        pcall(function()
            NightSkipRemote:FireServer(temporal)
        end)
        Logic.notify("Temporal", "Night skip activated")
    end
end

local function hookDayDisplay(remote)
    if DayDisplayConnection then
        DayDisplayConnection:Disconnect()
        DayDisplayConnection = nil
    end

    DayDisplayRemote = remote
    DayDisplayConnection = remote.OnClientEvent:Connect(function(day)
        if not Logic.state.AutoTemporalEnabled then return end
        if type(day) ~= "number" then return end
        if day == lastProcessedDay then return end

        lastProcessedDay = day
        task.delay(5, function()
            if Logic.state.AutoTemporalEnabled then
                activateTemporal()
            end
        end)
    end)

    Logic.notify("DayDisplay", "Listener aktif")
end

task.spawn(function()
    while not DayDisplayRemote do
        if RemoteEvents and RemoteEvents:FindFirstChild("DayDisplay") then
            hookDayDisplay(RemoteEvents.DayDisplay)
            break
        elseif ReplicatedStorage:FindFirstChild("DayDisplay") then
            hookDayDisplay(ReplicatedStorage.DayDisplay)
            break
        end
        task.wait(0.5)
    end
end)
-- =====================================================
-- PART 5: ANTI AFK + RESET + CLEANUP + EXPORT
-- =====================================================

---------------------------------------------------------
-- ANTI AFK (GLOBAL, SAFE)
---------------------------------------------------------
LocalPlayer.Idled:Connect(function()
    if Logic.state.scriptDisabled then return end
    if not Logic.state.AntiAFKEnabled then return end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
end)

---------------------------------------------------------
-- HARD RESET / CLEANUP
---------------------------------------------------------
function Logic.resetAll()
    if Logic.state.scriptDisabled then return end
    Logic.state.scriptDisabled = true

    -- STOP MOVEMENT
    pcall(function() Logic.stopFly() end)
    pcall(function() Logic.stopTPWalk() end)
    pcall(function() Logic.setInfiniteJump(false) end)

    -- STOP FARM
    Logic.state.AutoCookEnabled = false
    Logic.state.ScrapEnabled = false
    Logic.state.AutoSacEnabled = false

    -- STOP COMBAT
    Logic.state.KillAuraEnabled = false
    Logic.state.ChopAuraEnabled = false

    -- STOP FISHING
    Logic.state.FishingEnabled = false
    Logic.state.AutoRecastEnabled = false

    -- STOP TEMPORAL
    Logic.state.AutoTemporalEnabled = false
    if DayDisplayConnection then
        DayDisplayConnection:Disconnect()
        DayDisplayConnection = nil
    end

    -- STOP COIN
    pcall(function() Logic.stopCoinAmmo() end)

    Logic.notify("Reset", "Semua fitur dimatikan & logic dihentikan")
end

---------------------------------------------------------
-- SAFE DISABLE (SOFT STOP)
---------------------------------------------------------
function Logic.disable()
    Logic.state.scriptDisabled = true
    Logic.notify("Logic", "Script disabled")
end

---------------------------------------------------------
-- DEBUG / STATUS HELPER (OPTIONAL)
---------------------------------------------------------
function Logic.getStatus()
    return {
        Fly = Logic.state.FlyEnabled,
        Cook = Logic.state.AutoCookEnabled,
        Scrap = Logic.state.ScrapEnabled,
        Lava = Logic.state.AutoSacEnabled,
        Aura = Logic.state.KillAuraEnabled or Logic.state.ChopAuraEnabled,
        Fishing = Logic.state.FishingEnabled,
        Temporal = Logic.state.AutoTemporalEnabled
    }
end

---------------------------------------------------------
-- FINAL EXPORT
---------------------------------------------------------
return Logic
