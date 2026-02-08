--https://chatgpt.com/c/69874aeb-7038-8323-bb34-800c4e370f94
-- FRENESIS x HexaCore HUB (FINAL COMPLETE + AUTO RUN)
-- Reworked: semua variabel stateful dimasukkan ke `local state = {}` untuk mengurangi usage local registers
-- Struktur dirapikan: helpers / listeners / loops / platform builder / UI tetap sama alurnya

------------------------------------------------------
-- STATE ROOT (semua variable ditempatkan di sini)
------------------------------------------------------
local state = {}

------------------------------------------------------
-- LOAD WINDUI
------------------------------------------------------
local ok, WindUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
    ))()
end)
if not ok or type(WindUI) ~= "table" then return end
state.WindUI = WindUI

------------------------------------------------------
-- SERVICES (local karena sering dipakai)
------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService") -- needed for platform builder tweens

------------------------------------------------------
-- REMOTES
------------------------------------------------------
state.ReplicatorEvent = ReplicatedStorage.__ReplicatorInternal and ReplicatedStorage.__ReplicatorInternal.RemoteEvent
state.PlotAction = ReplicatedStorage.Packages and ReplicatedStorage.Packages.Net and ReplicatedStorage.Packages.Net["RF/Plot.PlotAction"]
state.UpgradeSpeed = ReplicatedStorage.RemoteFunctions and ReplicatedStorage.RemoteFunctions.UpgradeSpeed
state.Rebirth = ReplicatedStorage.RemoteFunctions and ReplicatedStorage.RemoteFunctions.Rebirth
state.UpgradeCarry = ReplicatedStorage.RemoteFunctions and ReplicatedStorage.RemoteFunctions.UpgradeCarry
state.WheelSpinRoll = ReplicatedStorage.Packages and ReplicatedStorage.Packages.Net and ReplicatedStorage.Packages.Net["RF/WheelSpin.Roll"]
state.WheelSpinComplete = ReplicatedStorage.Packages and ReplicatedStorage.Packages.Net and ReplicatedStorage.Packages.Net["RE/WheelSpin.Complete"]

------------------------------------------------------
-- FLAGS & STATE (dipindah ke state)
------------------------------------------------------
-- automation toggles
state.AutoCollect = false
state.AutoUpgrade = false
state.AutoCollectGoldBar = false
state.AutoBuySpeed = false
state.AutoRebirth = false
state.AutoBuyCarry = false
state.AutoCollectRadioactive = false
state.AutoCollectUFO = false
state.AutoSpinRadioactive = false
state.AutoSpinUFO = false
state.AutoSpinGoldBar = false

-- misc features
state.InstantGrabEnabled = false
state.InfiniteZoomEnabled = false
state.InfiniteJumpEnabled = false

state.SelectiveNoClipEnabled = false
state.vipNoClipConn = nil
state.NoClipEnabled = false
state.noClipConn = nil
state.vipTouchBlockConn = nil
state.vipTouchBlockConn = state.vipTouchBlockConn  -- (dummy, cukup untuk deklarasi)

state.AutoRunEnabled = false
state.TargetGapIndex = 1

state.infiniteJumpConn = nil
state.promptConn = nil
state.promptOriginalHold = {}

-- plots / uuids
state.Plots = {}
state.ActiveUUIDs = {}
state.UUIDSnapshotDone = false
state.isMovingGap = false

-- platform builder
state.isTweening = false
state.platformEnabled = false

state.autoMoveEnabled = false
state.autoMoveTask = nil

state.autoCollectEnabled = false
state.autoCollectTask = nil

-- ui/shared selection
state.selectedFloorIndex = 1

-- brainrot settings
state.BRAINROT_PICK_COUNT = 1

-- lucky block auto collect state
state.autoCollectBlockEnabled = false
state.autoCollectBlockTask = nil
state.LuckyBlockTargets = {}   -- set table
state.pendingRestartCollectRarity = false
state.selectedRarities = {}
state.pendingRestartCollectBlock = false
state.brainrotCache = {}
state.BRAINROT_PRIORITY_ORDER = {
    "Infinity","Divine","Celestial","Secret","Cosmic","Mythical","Legendary","Epic","Rare","Uncommon","Common"
}
state.DEBUG_LUCKY = false
state.LUCKY_RETRY_DELAY = 0.6     -- detik antar attempt
state.LUCKY_MAX_ATTEMPTS = 6      -- retry sebelum reset

-- Lucky block watcher
state.LuckyBlockQueue = {}
state.LuckyBlockSeen = {}
state.luckyWatcherConnAdded = nil
state.luckyWatcherConnRemoved = nil
state.workspaceChildAddedConn = nil
state.promptOriginalHold_PB = {}
state.LUCKY_PRIORITY_ORDER = {
    "Admin","Divine","Celestial","Gamer","Radioactive","Void","UFO","Alien","Jackpot","Money",
    "Secret","Cosmic","Mythical","Legendary","Epic","Rare","Uncommon","Common"
}

state.LUCKY_PRIORITY_MAP = {}
for i, name in ipairs(state.LUCKY_PRIORITY_ORDER) do
    state.LUCKY_PRIORITY_MAP[name] = i
end

-- floors data
state.Floors = {
    {name="Start",      x=119.389}, -- index 1
    {name="Common",     x=242},
    {name="Uncommon",   x=341},
    {name="Rare",       x=470},
    {name="Epic",       x=649},
    {name="Legendary",  x=913},
    {name="Mythical",   x=1310},
    {name="Cosmic",     x=1900},
    {name="Secret",     x=2430},
    {name="Celestial",  x=2785},
}

-- tween / respawn
state.lastTween = nil
state.pendingRestartMove = false
state.pendingRestartCollect = false
state.humanoidDiedConn = nil

state.scannerEnabled = false
state.scannerTask = nil

state.platformBooting = false
state.hardResetOnRespawn = false

-- platform builder internal parts
state.platformParts = {}
state.wallParts = {}

state.OpenBlockState = { chosenTypes = {} }

state.AutoCollectTicket = false
state.AutoCollectGamer = false

state.coinCache = {
    ["Radioactive Coin"] = {},
    ["UFO Coin"] = {},
    ["GoldBar"] = {},
    ["Ticket"] = {},
    ["Game Console"] = {}
}
state.cachePointers = {
    ["Radioactive Coin"] = 1,
    ["UFO Coin"] = 1,
    ["GoldBar"] = 1,
    ["Ticket"] = 1,
    ["Game Console"] = 1
}

-- obby gold
state.AutoObbyGoldEnabled = false
state.obbyGoldTask = nil
state.OBBY_TARGETS = {
    "MoneyObby1End",
    "MoneyObby2End",
    "MoneyObby3End"
}
state.obbyPartCache = {}
state.isRunningObbySequence = false
state.obbyCurrentStep = 0

state.OBBY_PAIRS = {
    {start = "MoneyObbyStart1", finish = "MoneyObby1End"},
    {start = "MoneyObbyStart2", finish = "MoneyObby2End"},
    {start = "MoneyObbyStart3", finish = "MoneyObby3End"}
}

state.AutoCollectTarget = false
state.autoCollectTargetTask = nil

------------------------------------------------------
-- HELPERS (functions kecil)
------------------------------------------------------
local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

RunService.Heartbeat:Connect(function()
    -- Cek jika karakter mati, skip semua
    local hum = getHumanoid()
    if hum and hum.Health <= 0 then
        return
    end

    if state.autoMoveEnabled and not state.autoMoveTask then
        startAutoMoveToTarget(state.selectedFloorIndex)
    end

    if state.autoCollectEnabled and not state.autoCollectTask then
        startAutoCollectBrainrot(state.selectedFloorIndex)
    end
end)

local function waitCharacterReady()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart", 5)
    char:WaitForChild("Humanoid", 5)
end

local function getCoinPart(desc)
    if desc:IsA("BasePart") then return desc end
    return desc:FindFirstChildWhichIsA("BasePart")
end

local function safeGetAttr(inst, name)
    local ok, res = pcall(function() return inst:GetAttribute(name) end)
    if ok then return res end
    return nil
end

local function trim(s)
    if not s then return nil end
    return (tostring(s):match("^%s*(.-)%s*$"))
end

local function findObbyPart(name)
    local part = Workspace:FindFirstChild(name)
    if part then return part end

    local moneyMap = Workspace:FindFirstChild("MoneyMap_SharedInstances")
    if moneyMap then
        return moneyMap:FindFirstChild(name)
    end

    return nil
end

local function killCharacterSafe()
    local humanoid = getHumanoid()
    if humanoid then
        pcall(function() humanoid.Health = 0 end)
    end
end

local function waitForCharacterAlive()
    local char = LocalPlayer.Character
    if not char then char = LocalPlayer.CharacterAdded:Wait() end
    local humanoid = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    task.wait(1)
    return char
end

local function teleportToPart(part)
    if not part then return false end
    local hrp = getRoot()
    if not hrp then return false end
    pcall(function() hrp.CFrame = CFrame.new(part.Position) end)
    return true
end

local function getLuckyPriority(name)
    if not name then return #state.LUCKY_PRIORITY_ORDER + 1 end
    return state.LUCKY_PRIORITY_MAP[tostring(name)] or (#state.LUCKY_PRIORITY_ORDER + 1)
end

-- PATCH: refresh queue sesuai target (hapus items yg tidak match targets)
local function refreshLuckyBlockQueueForTargets()
    -- jika targets kosong => artinya semua diizinkan
    if next(state.LuckyBlockTargets) == nil then return end
    for i = #state.LuckyBlockQueue, 1, -1 do
        local it = state.LuckyBlockQueue[i]
        if it and it.blockType then
            if not state.LuckyBlockTargets[it.blockType] then
                table.remove(state.LuckyBlockQueue, i)
            end
        end
    end
end


------------------------------------------------------
-- OBBY GOLD: start/stop + listener + sequence
------------------------------------------------------
local function startObbyGoldSequence()
    if state.isRunningObbySequence then return end
    state.isRunningObbySequence = true

    state.obbyGoldTask = task.spawn(function()
        print("[Obby Gold] Starting sequence dengan pola Start → End...")
        state.obbyPartCache = {}
        for _, pair in ipairs(state.OBBY_PAIRS) do
            local startPart = findObbyPart(pair.start)
            local endPart = findObbyPart(pair.finish)
            if startPart then state.obbyPartCache[pair.start] = startPart; print("[Obby Gold] Found start part:", pair.start, "at position:", startPart.Position) else print("[Obby Gold] WARNING: Start part not found:", pair.start) end
            if endPart then state.obbyPartCache[pair.finish] = endPart; print("[Obby Gold] Found end part:", pair.finish, "at position:", endPart.Position) else print("[Obby Gold] WARNING: End part not found:", pair.finish) end
        end

        if not next(state.obbyPartCache) then
            state.WindUI:Notify({ Title = "Obby Gold Error", Content = "MoneyObby parts not found in workspace", Duration = 3 })
            state.isRunningObbySequence = false
            state.AutoObbyGoldEnabled = false
            return
        end

        while state.AutoObbyGoldEnabled do
            for step, pair in ipairs(state.OBBY_PAIRS) do
                state.obbyCurrentStep = step
                if not state.AutoObbyGoldEnabled then break end
                local startPart = state.obbyPartCache[pair.start]
                local endPart = state.obbyPartCache[pair.finish]
                if not startPart or not endPart then
                    print("[Obby Gold] Skipping step", step, "- Parts not found")
                    continue
                end
                print("[Obby Gold] Step", step, "- Processing", pair.start, "→", pair.finish)
                print("[Obby Gold] Teleporting to", pair.start)
                if teleportToPart(startPart) then
                    state.WindUI:Notify({ Title = "Obby Gold", Content = string.format("Step %d/%d: Teleported to %s", step, #state.OBBY_PAIRS, pair.start), Duration = 2 })
                else
                    print("[Obby Gold] Failed to teleport to", pair.start)
                    continue
                end
                task.wait(1)
                print("[Obby Gold] Teleporting to", pair.finish)
                if teleportToPart(endPart) then
                    state.WindUI:Notify({ Title = "Obby Gold", Content = string.format("Step %d/%d: Teleported to %s", step, #state.OBBY_PAIRS, pair.finish), Duration = 2 })
                else
                    print("[Obby Gold] Failed to teleport to", pair.finish)
                end
                task.wait(3)
                print("[Obby Gold] Killing character for respawn")
                killCharacterSafe()
                waitForCharacterAlive()
                task.wait(0.5)
            end
            state.obbyCurrentStep = 0
            if state.AutoObbyGoldEnabled then
                print("[Obby Gold] Sequence completed, restarting in 2 seconds...")
                task.wait(2)
            end
        end

        state.isRunningObbySequence = false
        state.obbyCurrentStep = 0
        print("[Obby Gold] Sequence stopped")
    end)
end

local function stopObbyGold()
    state.AutoObbyGoldEnabled = false
    state.isRunningObbySequence = false
    state.obbyCurrentStep = 0
    if state.obbyGoldTask then task.cancel(state.obbyGoldTask); state.obbyGoldTask=nil end
    if obbyListenerConn then obbyListenerConn:Disconnect(); obbyListenerConn=nil end
    state.WindUI:Notify({ Title = "Obby Gold", Content = "Auto Obby Gold stopped", Duration = 2 })
    print("[Obby Gold] System completely stopped")
end

-- obby listener
local obbyListenerConn = nil
local function setupObbyListener()
    if obbyListenerConn then obbyListenerConn:Disconnect(); obbyListenerConn=nil end
    obbyListenerConn = Workspace.DescendantAdded:Connect(function(descendant)
        if not state.AutoObbyGoldEnabled then return end
        local isObbyPart = false
        for _, pair in ipairs(state.OBBY_PAIRS) do
            if descendant.Name == pair.start or descendant.Name == pair.finish then isObbyPart = true break end
        end
        if isObbyPart and descendant:IsA("BasePart") then
            state.obbyPartCache[descendant.Name] = descendant
            print("[Obby Gold] Detected new part:", descendant.Name)
            if state.isRunningObbySequence then print("[Obby Gold] New part detected while sequence is running") end
        end
    end)
end

local function cleanupObbyListener()
    if obbyListenerConn then obbyListenerConn:Disconnect(); obbyListenerConn=nil end
end

local function safeGetPivotPosition(model)
    local ok, pivot = pcall(function() return model:GetPivot() end)
    if ok and pivot then return pivot.Position end
    return nil
end

local function sortLuckyBlockQueue()
    table.sort(state.LuckyBlockQueue, function(a,b)
        local pa = getLuckyPriority(a.blockType)
        local pb = getLuckyPriority(b.blockType)
        if pa ~= pb then return pa < pb end

        local hrp = getRoot()
        if hrp and a.pos and b.pos then
            local da = (hrp.Position - a.pos).Magnitude
            local db = (hrp.Position - b.pos).Magnitude
            if da ~= db then return da < db end
        end

        -- fallback: earlier queued first
        return (a.queuedAt or 0) < (b.queuedAt or 0)
    end)
end

------------------------------------------------------
-- PROMPTS / UTIL RESTORE
------------------------------------------------------
local function restorePrompts()
    for p, d in pairs(state.promptOriginalHold) do
        if p and p.Parent then p.HoldDuration = d end
    end
    state.promptOriginalHold = {}

    if promptOriginalHold_PB then
        for p, d in pairs(promptOriginalHold_PB) do
            if p and p.Parent then p.HoldDuration = d end
        end
        promptOriginalHold_PB = {}
    end
end

local function sortBrainrotsByPriority(brainrotList)
    local priorityMap = {}
    for i, rarity in ipairs(state.BRAINROT_PRIORITY_ORDER) do priorityMap[rarity] = i end
    table.sort(brainrotList, function(a, b)
        local priorityA = priorityMap[a.rarity] or 999
        local priorityB = priorityMap[b.rarity] or 999
        if priorityA ~= priorityB then return priorityA < priorityB end
        return a.position.X < b.position.X
    end)
    return brainrotList
end

local function getFloorIndexByName(name)
    if not state.Floors then print("[ERROR] Floors table is nil!") return nil end
    if not name then print("[DEBUG] getFloorIndexByName: name is nil") return nil end
    local tn = trim(name)
    if not tn then print("[DEBUG] getFloorIndexByName: trimmed name is nil") return nil end
    for i, f in ipairs(state.Floors) do
        if f.name == tn then return i end
    end
    return nil
end

local function getFloorIndexByPosition(x)
    if not x then return 1 end
    local bestIndex = 1
    local bestDist = math.huge
    for i, f in ipairs(state.Floors) do
        local d = math.abs(x - (f.x or 0))
        if d < bestDist then bestDist = d bestIndex = i end
    end
    return bestIndex
end

------------------------------------------------------
-- RESPAWN PATCH
------------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function()
    state.isMovingGap = false
    waitCharacterReady()
end)

------------------------------------------------------
-- PLOT LISTENER (ASLI)
------------------------------------------------------
if state.ReplicatorEvent then
    state.ReplicatorEvent.OnClientEvent:Connect(function(p)
        if not p or not p[1] or not p[1][3] then return end
        for uuid, info in pairs(p[1][3]) do
            if info.data and info.data.Stands then
                state.Plots[uuid] = info.data.Stands
            end
        end
    end)
end

local function SnapshotUUIDsOnce()
    if state.UUIDSnapshotDone then return end
    for uuid in pairs(state.Plots) do state.ActiveUUIDs[uuid] = true end
    state.UUIDSnapshotDone = true
end

------------------------------------------------------
-- AUTO CORE LOOPS (ASLI)
------------------------------------------------------
task.spawn(function()
    while true do
        if state.AutoBuySpeed and state.UpgradeSpeed then pcall(function() state.UpgradeSpeed:InvokeServer(10) end) end
        task.wait(2)
    end
end)

task.spawn(function()
    while true do
        if state.AutoRebirth and state.Rebirth then pcall(function() state.Rebirth:InvokeServer() end) end
        task.wait(5)
    end
end)

task.spawn(function()
    while true do
        if state.AutoBuyCarry and state.UpgradeCarry then pcall(function() state.UpgradeCarry:InvokeServer() end) end
        task.wait(3)
    end
end)

task.spawn(function()
    while true do
        if state.UUIDSnapshotDone then
            if state.AutoCollect and state.PlotAction then
                for uuid in pairs(state.ActiveUUIDs) do
                    for i=1,40 do
                        pcall(function() state.PlotAction:InvokeServer("Collect Money", uuid, tostring(i)) end)
                    end
                end
            end
            if state.AutoUpgrade and state.PlotAction then
                for uuid in pairs(state.ActiveUUIDs) do
                    for i=1,40 do
                        pcall(function() state.PlotAction:InvokeServer("Upgrade Brainrot", uuid, tostring(i)) end)
                    end
                end
            end
        end
        task.wait(0.6)
    end
end)

------------------------------------------------------
-- EVENT COINS (cache & heartbeat mover)
------------------------------------------------------
for _,v in ipairs(Workspace:GetDescendants()) do
    local n = v.Name
    if state.coinCache[n] then
        local p = getCoinPart(v)
        if p then table.insert(state.coinCache[n], p) end
    end
end

local function onDescendantAdded(v)
    local n = v.Name
    if state.coinCache[n] then
        local p = getCoinPart(v)
        if p then table.insert(state.coinCache[n], p) end
    end
end

local function onDescendantRemoving(v)
    local n = v.Name
    if state.coinCache[n] then
        local cache = state.coinCache[n]
        for i = #cache, 1, -1 do
            if not cache[i].Parent or cache[i] == v or cache[i].Parent == v then
                table.remove(cache, i)
            end
        end
        if state.cachePointers[n] > #cache then state.cachePointers[n] = 1 end
    end
end

local addConn = Workspace.DescendantAdded:Connect(onDescendantAdded)
local remConn = Workspace.DescendantRemoving:Connect(onDescendantRemoving)

local function cleanupCoinCollector()
    if addConn then addConn:Disconnect(); addConn=nil end
    if remConn then remConn:Disconnect(); remConn=nil end
end

local PROCESS_PER_TYPE = 12
local DISTANCE_THRESHOLD = 500

RunService.Heartbeat:Connect(function()
    if not (state.AutoCollectRadioactive or state.AutoCollectUFO or state.AutoCollectGoldBar) then return end
    local hrp = getRoot()
    if not hrp then return end
    for coinName, cache in pairs(state.coinCache) do
        local enabled = (coinName == "Radioactive Coin" and state.AutoCollectRadioactive)
                     or (coinName == "UFO Coin" and state.AutoCollectUFO)
                     or (coinName == "GoldBar" and state.AutoCollectGoldBar)
                     or (coinName == "Ticket" and state.AutoCollectTicket)
                     or (coinName == "Game Console" and state.AutoCollectGamer)
        if enabled and #cache > 0 then
            local ptr = state.cachePointers[coinName] or 1
            local toProcess = math.min(PROCESS_PER_TYPE, #cache)
            for i = 1, toProcess do
                if #cache == 0 then break end
                if ptr > #cache then ptr = 1 end
                local part = cache[ptr]
                if not part or not part.Parent then
                    table.remove(cache, ptr)
                else
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist <= DISTANCE_THRESHOLD then
                        local offset = CFrame.new(math.random(-2,2), 0.5, math.random(-2,2))
                        pcall(function() part.CFrame = hrp.CFrame * offset end)
                    end
                    ptr = ptr + 1
                end
            end
            state.cachePointers[coinName] = (ptr > 0 and ptr) or 1
        end
    end
end)

------------------------------------------------------
-- AUTO SPIN
------------------------------------------------------
local function doSpin(kind)
    if not state.WheelSpinRoll or not state.WheelSpinComplete then return end
    pcall(function() state.WheelSpinRoll:InvokeServer(kind,false) end)
    task.wait(0.25)
    pcall(function() state.WheelSpinComplete:FireServer(tostring(os.clock().."_"..math.random(10000,99999))) end)
end

task.spawn(function()
    while true do
        if state.AutoSpinRadioactive then doSpin("Radioactive") end
        if state.AutoSpinUFO then doSpin("UFO") end
        if state.AutoSpinGoldBar then doSpin("Money") end
        task.wait(1.2)
    end
end)

------------------------------------------------------
-- INSTANT GRAB
------------------------------------------------------
local function applyInstantGrab(p)
    if p:IsA("ProximityPrompt") then
        if not state.promptOriginalHold[p] then state.promptOriginalHold[p] = p.HoldDuration end
        p.HoldDuration = 0
    end
end

local function enableInstantGrab()
    state.InstantGrabEnabled = true
    for _,v in ipairs(Workspace:GetDescendants()) do applyInstantGrab(v) end
    if state.promptConn then state.promptConn:Disconnect() end
    state.promptConn = Workspace.DescendantAdded:Connect(function(v)
        if state.InstantGrabEnabled then applyInstantGrab(v) end
    end)
end

local function disableInstantGrab()
    state.InstantGrabEnabled = false
    if state.promptConn then state.promptConn:Disconnect() state.promptConn=nil end
    for p,d in pairs(state.promptOriginalHold) do
        if p.Parent then p.HoldDuration=d end
    end
    state.promptOriginalHold = {}
end

------------------------------------------------------
-- INFINITE ZOOM
------------------------------------------------------
local minZoom,maxZoom = LocalPlayer.CameraMinZoomDistance,LocalPlayer.CameraMaxZoomDistance
local function enableInfiniteZoom()
    state.InfiniteZoomEnabled=true
    LocalPlayer.CameraMinZoomDistance=0.5
    LocalPlayer.CameraMaxZoomDistance=1e6
end
local function disableInfiniteZoom()
    state.InfiniteZoomEnabled=false
    LocalPlayer.CameraMinZoomDistance=minZoom
    LocalPlayer.CameraMaxZoomDistance=maxZoom
end

------------------------------------------------------
-- INFINITE JUMP
------------------------------------------------------
local function enableInfiniteJump()
    if state.InfiniteJumpEnabled then return end
    state.InfiniteJumpEnabled=true
    state.infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
        if state.InfiniteJumpEnabled then
            local h=getHumanoid()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
end

local function disableInfiniteJump()
    state.InfiniteJumpEnabled=false
    if state.infiniteJumpConn then state.infiniteJumpConn:Disconnect(); state.infiniteJumpConn=nil end
end

------------------------------------------------------
-- NO CLIP (selective & global)
------------------------------------------------------
local VIP_PART_NAMES = { ["VIP"] = true, ["VIP_PLUS"] = true }

local function isTargetVIPPart(v)
    return v:IsA("BasePart") and VIP_PART_NAMES[v.Name] and v.Parent and v.Parent.Name == "VIPWalls"
end

local function applyVIPNoClip(v)
    if isTargetVIPPart(v) then v.CanCollide = false end
end

local function enableSelectiveNoClip()
    if state.SelectiveNoClipEnabled then return end
    state.SelectiveNoClipEnabled = true
    for _,v in ipairs(Workspace:GetDescendants()) do applyVIPNoClip(v) end
    state.vipNoClipConn = Workspace.DescendantAdded:Connect(function(v) if state.SelectiveNoClipEnabled then applyVIPNoClip(v) end end)
end

local function disableSelectiveNoClip()
    state.SelectiveNoClipEnabled = false
    if state.vipNoClipConn then state.vipNoClipConn:Disconnect(); state.vipNoClipConn = nil end
    for _,v in ipairs(Workspace:GetDescendants()) do if isTargetVIPPart(v) then v.CanCollide = true end end
end

local function applyVIPWallTouchBlock(v) if isTargetVIPPart(v) then v.CanTouch = false end end
local function restoreVIPWallTouch(v) if isTargetVIPPart(v) then v.CanTouch = true end end

local function enableVIPWallTouchBlock()
    for _,v in ipairs(Workspace:GetDescendants()) do applyVIPWallTouchBlock(v) end
    if state.vipTouchBlockConn then state.vipTouchBlockConn:Disconnect(); state.vipTouchBlockConn = nil end
    state.vipTouchBlockConn = Workspace.DescendantAdded:Connect(function(v) applyVIPWallTouchBlock(v) end)
end

local function disableVIPWallTouchBlock()
    if state.vipTouchBlockConn then state.vipTouchBlockConn:Disconnect(); state.vipTouchBlockConn = nil end
    for _,v in ipairs(Workspace:GetDescendants()) do restoreVIPWallTouch(v) end
end

local function applyGlobalNoClip()
    local char = LocalPlayer.Character
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end
end

local function enableNoClip()
    if state.NoClipEnabled then return end
    state.NoClipEnabled = true
    state.noClipConn = RunService.Stepped:Connect(function()
        if state.NoClipEnabled then applyGlobalNoClip() end
    end)
end

local function disableNoClip()
    state.NoClipEnabled = false
    if state.noClipConn then state.noClipConn:Disconnect(); state.noClipConn = nil end
    local char = LocalPlayer.Character
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = true end end
end

------------------------------------------------------
-- GAP SYSTEM (ASLI)
------------------------------------------------------
local Gaps = {
    CFrame.new(130.016,3.25,23.369),
    CFrame.new(201.683,-2.75,-6.683),
    CFrame.new(283.754,-2.75,-2.985),
    CFrame.new(399.726,-2.75,1.785),
    CFrame.new(547.405,-2.75,0.532),
    CFrame.new(758.278,-2.75,-8.769),
    CFrame.new(1074.190,-2.75,0.681),
    CFrame.new(1549.928,-2.75,1.204),
    CFrame.new(2245.095,-2.75,2.923),
    CFrame.new(2599.562,-2.75,-2.707)
}

local function nearestGap()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    local best,dist=0,math.huge
    for i,cf in ipairs(Gaps) do
        local d=(hrp.Position-cf.Position).Magnitude
        if d<dist then dist=d best=i-1 end
    end
    return best
end

local function moveGap(idx)
    if state.isMovingGap then return end
    state.isMovingGap=true
    local hrp=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hum=getHumanoid()
    if not (hrp and hum) then state.isMovingGap=false return end
    local startPos=hrp.Position
    local endPos=Gaps[idx+1].Position
    local from=nearestGap()
    local slow=(from==7 and idx==8) or (from==8 and idx==7)
    local steps=slow and 36 or 18
    local delay=slow and 0.024 or 0.018
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    for i=1,steps do
        hrp.CFrame=CFrame.new(startPos:Lerp(endPos,i/steps))
        task.wait(delay)
    end
    hum:ChangeState(Enum.HumanoidStateType.Running)
    state.isMovingGap=false
end

------------------------------------------------------
-- AUTO RUN PATCH
------------------------------------------------------
local SAFE_BUFFER=10
local function isPathClear(fromIdx,toIdx)
    local a=Gaps[fromIdx+1].Position.X
    local b=Gaps[toIdx+1].Position.X
    local minX=math.min(a,b)+SAFE_BUFFER
    local maxX=math.max(a,b)-SAFE_BUFFER
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v.Name=="TsunamiWave" and v:IsA("BasePart") then
            local x=v.Position.X
            if x>minX and x<maxX then return false end
        end
    end
    return true
end

task.spawn(function()
    while true do
        if state.AutoRunEnabled and not state.isMovingGap then
            local cur=nearestGap()
            if cur<state.TargetGapIndex and isPathClear(cur,cur+1) then
                moveGap(cur+1)
            end
        end
        task.wait(0.2)
    end
end)

--------------------------------------------------------------------------------
-- ===================== MERGE: PLATFORM BUILDER ===============================
--------------------------------------------------------------------------------

-- STATIC START / END
state.START_POS = Vector3.new(149.957, 3.561, -134.743)
state.END_POS   = Vector3.new(5000.347, 3.561, -134.743)

-- CONFIG
state.PLATFORM_THICKNESS = 2
state.PLATFORM_WIDTH_Z  = 20
state.PLATFORM_Y_OFFSET = -3
state.WALL_THICKNESS     = 2
state.WALL_HEIGHT        = 70
state.WALL_IN_OUT_OFFSET = 3
state.WALL_SAFE_DISTANCE = -3.5
state.MAX_PART_LENGTH = 2000
state.TWEEN_SPEED = 400
state.AUTO_MOVE_SPEED_MULT = 2.5
state.AUTO_MOVE_MIN_DELAY = 0.03

state.TARGET_RIGHT_WALLS = {
    RightWall1=true,RightWall2=true,RightWall3=true,
    RightWall4=true,RightWall5=true,RightWall6=true,RightWall7=true
}

local function getCharacter() return LocalPlayer.Character end
local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end
local function getHumanoidSafe()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("Humanoid")
end

local function getBasePositionForFloor(floor)
    local targetZ = state.START_POS.Z - state.PLATFORM_WIDTH_Z/2 - state.WALL_THICKNESS/2 + state.WALL_IN_OUT_OFFSET - state.WALL_SAFE_DISTANCE
    return Vector3.new(floor.x, 0, targetZ)
end

local function getFloorIndexByX(x)
    local index = 1
    for i = 1, #state.Floors do
        if x >= state.Floors[i].x then index = i else break end
    end
    return index
end

local function getNextFloor(currentX)
    for i = 1, #state.Floors do if state.Floors[i].x > currentX then return state.Floors[i] end end
    return nil
end

local function getPrevFloor(currentX)
    for i = #state.Floors, 1, -1 do if state.Floors[i].x < currentX then return state.Floors[i] end end
    return nil
end

local function cancelLastTween()
    if state.lastTween then
        pcall(function() state.lastTween:Cancel() end)
        state.lastTween = nil
    end
    -- Pastikan humanoid tidak tertinggal di Physics state
    pcall(function()
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end


local function moveHRPToPosition(targetPosVec3, speedMultiplier)
    if not targetPosVec3 then return end
    cancelLastTween()
    local hrp = getRoot()
    local hum = getHumanoid()
    if not hrp or not hum then return end
    local startPos = hrp.Position
    local targetPos = Vector3.new(targetPosVec3.X, startPos.Y, targetPosVec3.Z)
    local dist = (startPos - targetPos).Magnitude
    if dist < 1 then return end
    local speed = (state.TWEEN_SPEED * (speedMultiplier or 1))
    local time = math.clamp(dist / speed, 0.12, 2.0)
    local previousState = hum:GetState()
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
    state.lastTween = tween
    local completed = false
    local connection
    connection = tween.Completed:Connect(function()
        completed = true
        if connection then connection:Disconnect() end
    end)
    tween:Play()
    local startTime = tick()
    local maxWaitTime = time + 2.0
    while not completed and (tick() - startTime) < maxWaitTime do task.wait(0.05) end
    if not completed then pcall(function() tween:Cancel() end) end
    if connection and connection.Connected then connection:Disconnect() end
    if state.lastTween == tween then state.lastTween = nil end
    hum:ChangeState(Enum.HumanoidStateType.Running)
end

local function tweenToFloor(floor, isAutoMove)
    if not floor or not floor.name then return end
    local hrp = getRoot()
    if not hrp then return end
    local hum = getHumanoid()
    if hum and hum.Health <= 0 then return end
    local speedMult = isAutoMove and state.AUTO_MOVE_SPEED_MULT or 1
    local targetZ = state.START_POS.Z - state.PLATFORM_WIDTH_Z/2 - state.WALL_THICKNESS/2 + state.WALL_IN_OUT_OFFSET - state.WALL_SAFE_DISTANCE
    local targetPos = Vector3.new(floor.x, 0, targetZ)
    local success, err = pcall(function() moveHRPToPosition(targetPos, speedMult) end)
    if not success then
        state.WindUI:Notify({ Title = "Tween Error", Content = "Gagal berpindah ke " .. floor.name, Duration = 2 })
    end
end

local function destroyList(t)
    for _,v in ipairs(t) do if v and v.Parent then pcall(function() v:Destroy() end) end end
end

local function clearClientParts()
    destroyList(state.platformParts)
    destroyList(state.wallParts)
    state.platformParts = {}
    state.wallParts = {}
end

local function createPart(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = true
    p.CanTouch = false
    p.CanQuery = false
    p.Size = props.Size
    p.CFrame = props.CFrame
    p.Transparency = props.Transparency or 0
    p.Material = Enum.Material.SmoothPlastic
    p.Color = props.Color or Color3.fromRGB(255,255,255)
    p.Parent = Workspace
    return p
end

-- scanner brainrot (single-run)
local function scanActiveBrainrots()
    state.brainrotCache = {}
    local ActiveBrainrots = workspace:FindFirstChild("ActiveBrainrots")
    if not ActiveBrainrots then return end
    for _, rarityFolder in ipairs(ActiveBrainrots:GetChildren()) do
        if not rarityFolder:IsA("Folder") then continue end
        local rarityName = rarityFolder.Name
        state.brainrotCache[rarityName] = {}
        for _, brainrotModel in ipairs(rarityFolder:GetChildren()) do
            if brainrotModel:IsA("Model") and brainrotModel.Name == "RenderedBrainrot" then
                local pivot = brainrotModel:GetPivot()
                local pos = pivot.Position
                local name = brainrotModel:GetAttribute("BrainrotName") or brainrotModel.Name
                local level = brainrotModel:GetAttribute("Level") or 0
                table.insert(state.brainrotCache[rarityName], {
                    model = brainrotModel,
                    name = name,
                    level = level,
                    position = pos,
                    rarity = rarityName
                })
            end
        end
    end
end

-- BRAINROT SCANNER & COLLECTOR (platform builder)
local promptOriginalHold_PB = state.promptOriginalHold or {}

local function applyInstantGrab_PB(p)
    if not p then return end
    if p:IsA("ProximityPrompt") then
        if not promptOriginalHold_PB[p] then promptOriginalHold_PB[p] = p.HoldDuration end
        p.HoldDuration = 0
    end
end

local function restorePrompts_PB()
    for p, d in pairs(promptOriginalHold_PB) do
        if p and p.Parent then p.HoldDuration = d end
    end
    promptOriginalHold_PB = {}
end

local function getBrainrotsInFloor(floorName)
    local result = {}
    local root = Workspace:FindFirstChild("ActiveBrainrots")
    if not root then return result end
    local folder = root:FindFirstChild(floorName)
    if not folder then return result end
    local hrpSafe
    local ok, _ = pcall(function() hrpSafe = getHRP() end)
    if not ok then hrpSafe = getRoot(); if not hrpSafe then return result end end
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Model") and obj.Name == "RenderedBrainrot" then
            local rootPart = obj:FindFirstChild("Root") or obj:FindFirstChildWhichIsA("BasePart")
            if rootPart then table.insert(result, { model = obj, dist = (rootPart.Position - hrpSafe.Position).Magnitude }) end
        end
    end
    table.sort(result, function(a, b) return a.dist < b.dist end)
    local out = {}
    for _, v in ipairs(result) do table.insert(out, v.model) end
    return out
end

local function firePromptSafe(prompt)
    pcall(function()
        if typeof(fireproximityprompt) == "function" then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(0.05)
            prompt:InputHoldEnd()
        end
    end)
end

local function collectBrainrot(brainrotModel, targetFloor)
    if not brainrotModel or not brainrotModel.Parent then return end
    if not targetFloor then return end
    local rootPart = brainrotModel:FindFirstChild("Root") or brainrotModel:FindFirstChildWhichIsA("BasePart")
    if not rootPart then return end
    moveHRPToPosition(Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z), state.AUTO_MOVE_SPEED_MULT)
    task.wait(0.08)
    for _, d in ipairs(brainrotModel:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            applyInstantGrab_PB(d)
            firePromptSafe(d)
            task.wait(0.03)
        end
    end
    local basePos = getBasePositionForFloor(targetFloor)
    moveHRPToPosition(basePos, state.AUTO_MOVE_SPEED_MULT)
    task.wait(0.08)
end

-- auto move control
local function stopAutoMove()
    state.autoMoveEnabled = false
    if state.autoMoveTask then task.cancel(state.autoMoveTask); state.autoMoveTask=nil end
    cancelLastTween()
end

local function moveThroughFloorsTo(targetIndex)
    local hrp = getRoot()
    if not hrp then return false end
    local currentX = hrp.Position.X
    local currentIndex = getFloorIndexByX(currentX) or 1
    if currentIndex == targetIndex then return true end
    if not hrp then waitCharacterReady(); hrp = getRoot(); if not hrp then return false end end
    currentX = hrp.Position.X
    currentIndex = getFloorIndexByX(currentX) or 1
    local attempts = 0
    while currentIndex ~= targetIndex and attempts < 20 do
        attempts = attempts + 1
        if currentIndex < targetIndex then currentIndex = currentIndex + 1 else currentIndex = currentIndex - 1 end
        local floor = state.Floors[currentIndex]
        if not floor then break end
        local tweenSuccess = false
        for retry = 1, 2 do
            tweenToFloor(floor, true)
            task.wait(0.1)
            local newHrp = getRoot()
            if not newHrp then break end
            local newX = newHrp.Position.X
            local movedDistance = math.abs(newX - currentX)
            if movedDistance > 10 then tweenSuccess = true; currentX = newX; break end
        end
        if not tweenSuccess then return false end
        task.wait(state.AUTO_MOVE_MIN_DELAY)
        hrp = getRoot()
        if not hrp then return false end
        currentX = hrp.Position.X
        currentIndex = getFloorIndexByX(currentX) or currentIndex
    end
    local finalIndex = getFloorIndexByX(hrp.Position.X) or currentIndex
    return (finalIndex == targetIndex)
end

local function startAutoMoveToTarget(targetIndex)
    if state.autoMoveTask then return end
    state.autoMoveTask = task.spawn(function()
        if state.autoMoveEnabled then
            local hrp = getRoot()
            if hrp and getFloorIndexByX(hrp.Position.X) ~= 1 then moveThroughFloorsTo(1) end
        end
        while state.autoMoveEnabled do
            local hrp = nil
            pcall(function() hrp = getHRP() end)
            if not hrp then hrp = getRoot() end
            local currentIndex = hrp and getFloorIndexByX(hrp.Position.X) or 1
            if currentIndex == targetIndex then state.autoMoveEnabled = false break end
            local nextIndex = currentIndex < targetIndex and currentIndex + 1 or currentIndex - 1
            local nextFloor = state.Floors[nextIndex]
            if not nextFloor then state.autoMoveEnabled = false break end
            tweenToFloor(nextFloor, true)
            task.wait(state.AUTO_MOVE_MIN_DELAY)
        end
        state.autoMoveTask = nil
    end)
end

-- AUTO-COLLECT BRAINROT (rarity-based)
local function stopAutoCollect()
    state.autoCollectEnabled = false
    if state.autoCollectTask then task.cancel(state.autoCollectTask); state.autoCollectTask=nil end
    cancelLastTween()
    restorePrompts_PB()
end

local function startRealtimeScanner()
    if state.scannerEnabled then return end
    state.scannerEnabled = true
    state.scannerTask = task.spawn(function()
        while state.scannerEnabled do
            state.brainrotCache = {}
            local ActiveBrainrots = workspace:FindFirstChild("ActiveBrainrots")
            if ActiveBrainrots then
                for _, rarityFolder in ipairs(ActiveBrainrots:GetChildren()) do
                    if not rarityFolder:IsA("Folder") then continue end
                    local rarityName = rarityFolder.Name
                    state.brainrotCache[rarityName] = {}
                    for _, brainrotModel in ipairs(rarityFolder:GetChildren()) do
                        if brainrotModel:IsA("Model") and brainrotModel.Name == "RenderedBrainrot" then
                            local pivot = brainrotModel:GetPivot()
                            local pos = pivot.Position
                            local name = brainrotModel:GetAttribute("BrainrotName") or brainrotModel.Name
                            local level = brainrotModel:GetAttribute("Level") or 0
                            table.insert(state.brainrotCache[rarityName], {
                                model = brainrotModel,
                                name = name,
                                level = level,
                                position = pos,
                                rarity = rarityName
                            })
                        end
                    end
                end
            end
            task.wait(0.3)
        end
    end)
end

local function stopRealtimeScanner()
    state.scannerEnabled = false
    if state.scannerTask then task.cancel(state.scannerTask); state.scannerTask=nil end
    state.brainrotCache = {}
end

-- START auto collect by rarity
local function startAutoCollectBrainrotByRarity()
    if not getRoot() then waitCharacterReady(); task.wait(0.8) end
    if not state.scannerEnabled then startRealtimeScanner(); task.wait(0.3) end

    state.autoCollectTask = task.spawn(function()
        while state.autoCollectEnabled do
            local targetBrainrots = {}
            for rarity, isSelected in pairs(state.selectedRarities) do
                if isSelected and state.brainrotCache[rarity] then
                    for _, brainrotData in ipairs(state.brainrotCache[rarity]) do table.insert(targetBrainrots, brainrotData) end
                end
            end
            targetBrainrots = sortBrainrotsByPriority(targetBrainrots)
            if #targetBrainrots == 0 then task.wait(0.5); continue end
            local collected = 0
            for _, brainrotData in ipairs(targetBrainrots) do
                if collected >= state.BRAINROT_PICK_COUNT then break end
                if not state.autoCollectEnabled then break end
                if not brainrotData.model or not brainrotData.model.Parent then continue end
                local hum = getHumanoid()
                if hum and hum.Health <= 0 then break end
                local safePos = Vector3.new(brainrotData.position.X, state.START_POS.Y + state.PLATFORM_Y_OFFSET, state.START_POS.Z - state.PLATFORM_WIDTH_Z/2 - state.WALL_THICKNESS/2 + state.WALL_IN_OUT_OFFSET - state.WALL_SAFE_DISTANCE)
                tweenToFloor(state.Floors[1], true); task.wait(0.1)
                moveHRPToPosition(safePos, state.AUTO_MOVE_SPEED_MULT); task.wait(0.08)
                local brainrotPos = Vector3.new(brainrotData.position.X, 0, brainrotData.position.Z)
                moveHRPToPosition(brainrotPos, state.AUTO_MOVE_SPEED_MULT); task.wait(0.08)
                for _, prompt in ipairs(brainrotData.model:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        applyInstantGrab(prompt)
                        firePromptSafe(prompt)
                        task.wait(0.03)
                    end
                end
                moveHRPToPosition(safePos, state.AUTO_MOVE_SPEED_MULT); task.wait(0.08)
                collected = collected + 1
                tweenToFloor(state.Floors[1], true); task.wait(0.15)
            end
            task.wait(0.5)
        end
        state.autoCollectTask = nil
        restorePrompts()
    end)
end

-- stop all auto collect (replacement)
local function stopAllAutoCollect()
    if not state.autoCollectEnabled and not state.scannerEnabled then return end
    if state.autoCollectTask then task.cancel(state.autoCollectTask); state.autoCollectTask = nil end
    cancelLastTween()
    restorePrompts()
    local hum = getHumanoid()
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end) end
    stopRealtimeScanner()
    state.pendingRestartCollect = false
    state.pendingRestartCollectRarity = false
    state.brainrotCache = {}
    state.WindUI:Notify({ Title = "Auto Collect Dimatikan", Content = "Scanner dan semua movement dihentikan", Duration = 2 })
    print("[SYSTEM] All auto collect systems stopped (manual stop)")
end

-- startAutoCollectBrainrot (floor-based)
local function startAutoCollectBrainrot(targetFloorIndex)
    if state.autoCollectTask then return end
    state.autoCollectTask = task.spawn(function()
        local targetFloor = state.Floors[targetFloorIndex]
        if not targetFloor then state.autoCollectEnabled = false; state.autoCollectTask = nil; return end
        while state.autoCollectEnabled do
            tweenToFloor(state.Floors[1], true); task.wait(0.2)
            tweenToFloor(targetFloor, true); task.wait(0.15)
            local brainrots = getBrainrotsInFloor(targetFloor.name)
            if #brainrots > 0 then
                local toTake = math.min(#brainrots, math.max(1, math.floor(state.BRAINROT_PICK_COUNT)))
                for i = 1, toTake do
                    if not state.autoCollectEnabled then break end
                    local b = brainrots[i]
                    if b then collectBrainrot(b, targetFloor); task.wait(0.12) end
                end
            end
            tweenToFloor(state.Floors[1], true); task.wait(0.18)
        end
        state.autoCollectTask = nil
        restorePrompts_PB()
    end)
end

-- LUCKY BLOCK WATCHER (queue)
local ActiveLuckyBlocks = Workspace:FindFirstChild("ActiveLuckyBlocks")
local luckyWatcherConnAdded, luckyWatcherConnRemoved, workspaceChildAddedConn = nil, nil, nil

-- PATCH: enqueueExistingLuckyBlocks (respect targets + queuedAt)
local function enqueueExistingLuckyBlocks()
    local root = Workspace:FindFirstChild("ActiveLuckyBlocks")
    if not root then return end
    for _, lb in ipairs(root:GetChildren()) do
        if lb and lb.Parent and not state.LuckyBlockSeen[lb] then
            local ok, pivotPos = pcall(function() return safeGetPivotPosition(lb) end)
            if ok and pivotPos then
                local blockType = safeGetAttr(lb, "LuckyBlockType")
                -- only enqueue if this type is selected in targets (or targets empty -> all)
                if blockType and (next(state.LuckyBlockTargets) == nil or state.LuckyBlockTargets[blockType]) then
                    state.LuckyBlockSeen[lb] = true
                    table.insert(state.LuckyBlockQueue, {
                        model = lb,
                        pos = pivotPos,
                        spawnedFloor = trim(safeGetAttr(lb, "SpawnedFloor") or ""),
                        blockType = blockType,
                        attempts = 0,
                        lastTry = 0
                    })
                end
            end
        end
    end
    -- sort queue whenever we bulk-enqueued
    sortLuckyBlockQueue()
end


local function attachActiveLuckyBlocksWatcher()
    local active = Workspace:FindFirstChild("ActiveLuckyBlocks")
    if not active then
        if state.workspaceChildAddedConn then return end
        state.workspaceChildAddedConn = Workspace.ChildAdded:Connect(function(c)
            if c and c.Name == "ActiveLuckyBlocks" then
                attachActiveLuckyBlocksWatcher()
                if state.workspaceChildAddedConn then
                    state.workspaceChildAddedConn:Disconnect()
                    state.workspaceChildAddedConn = nil
                end
            end
        end)
        return
    end
    if state.luckyWatcherConnAdded then return end

    state.luckyWatcherConnAdded = active.ChildAdded:Connect(function(lb)
        task.wait(0.06)
        if not lb or not lb.Parent then return end
        
        -- Hanya proses jika ada sistem yang aktif yang membutuhkan lucky block
        if not state.AutoCollectTarget and not state.autoCollectBlockEnabled then
            return
        end
        
        -- get pivot position safely
        local ok, pivotPos = pcall(function() return safeGetPivotPosition(lb) end)
        if not ok or not pivotPos then return end

        local blockType = safeGetAttr(lb, "LuckyBlockType")
        local spawnedFloor = tostring(safeGetAttr(lb, "SpawnedFloor") or "")
        if next(state.LuckyBlockTargets) == nil or (blockType and state.LuckyBlockTargets[blockType]) then
            if not state.LuckyBlockSeen[lb] then
                state.LuckyBlockSeen[lb] = true
                table.insert(state.LuckyBlockQueue, {
                    model = lb,
                    pos = pivotPos,
                    spawnedFloor = trim(spawnedFloor),
                    blockType = blockType,
                    attempts = 0,
                    lastTry = 0
                })
                if state.DEBUG_LUCKY then
                    print("[LuckyWatcher] queued new luckyblock:", tostring(lb), "type=", blockType, "pos=", tostring(pivotPos))
                end
                -- reorder queue after insert
                sortLuckyBlockQueue()
            end
        else
            if state.DEBUG_LUCKY then print("[LuckyWatcher] new luckyblock ignored:", tostring(lb), "type=", blockType) end
        end
    end)

    state.luckyWatcherConnRemoved = active.ChildRemoved:Connect(function(lb)
        state.LuckyBlockSeen[lb] = nil
        for i = #state.LuckyBlockQueue, 1, -1 do
            local it = state.LuckyBlockQueue[i]
            if it and it.model == lb then table.remove(state.LuckyBlockQueue, i) end
        end
    end)
end

-- ensure initial watcher is attached
attachActiveLuckyBlocksWatcher()

-- PATCH: stopAutoCollectLuckyBlock (pastikan cancel & reset)
local function stopAutoCollectLuckyBlock()
    state.autoCollectBlockEnabled = false
    if state.autoCollectBlockTask then
        pcall(function() task.cancel(state.autoCollectBlockTask) end)
        state.autoCollectBlockTask = nil
    end

    -- restore prompts dan cancel tween (pastikan humanoid bebas)
    restorePrompts_PB()
    cancelLastTween()
    pcall(function()
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
    end)

    -- juga reset pendingRestart flag
    state.pendingRestartCollectBlock = false

    -- jangan auto-disable platform (biar user bisa kontrol)
end

-- PATCH: startAutoCollectLuckyBlock (tunda tween jika queue kosong; enable platform only when needed)
local function startAutoCollectLuckyBlock()
    if state.autoCollectBlockTask then return end

    state.autoCollectBlockTask = task.spawn(function()
        while state.autoCollectBlockEnabled do
            if not getRoot() then
                waitCharacterReady()
                task.wait(0.4)
                continue
            end

            if #state.LuckyBlockQueue == 0 then
                enqueueExistingLuckyBlocks()

                -- jika masih kosong → exit lucky mode
                if #state.LuckyBlockQueue == 0 then
                    state.autoCollectBlockEnabled = false
                    break -- ⬅️ KELUAR DARI LOOP LUCKY BLOCK
                end

                task.wait(0.3)
                continue
            end

            local blockData = state.LuckyBlockQueue[1]
            if not blockData then
                task.wait(0.3)
                continue
            end

            local lb = blockData.model
            local pos = blockData.pos

            -- jika block sudah hilang → sukses
            if not lb or not lb.Parent then
                table.remove(state.LuckyBlockQueue, 1)
                task.wait(0.1)
                continue
            end

            -- retry delay
            if tick() - (blockData.lastTry or 0) < state.LUCKY_RETRY_DELAY then
                table.insert(state.LuckyBlockQueue, table.remove(state.LuckyBlockQueue, 1))
                task.wait(0.1)
                continue
            end

            -- enable platform jika perlu
            if not state.platformEnabled then
                state.platformEnabled = true
                enablePlatform()
                task.wait(0.6)
            end

            blockData.lastTry = tick()
            blockData.attempts += 1

            ----------------------------------------------------------------
            -- STEP 1: START (floor 1)
            ----------------------------------------------------------------
            tweenToFloor(state.Floors[1], true)
            task.wait(0.15)

            ----------------------------------------------------------------
            -- STEP 2: SAFE POS (SEJAJAR DENGAN BLOCK)
            ----------------------------------------------------------------
            local safePos = Vector3.new(
                pos.X,
                state.START_POS.Y + state.PLATFORM_Y_OFFSET,
                state.START_POS.Z
                - state.PLATFORM_WIDTH_Z/2
                - state.WALL_THICKNESS/2
                + state.WALL_IN_OUT_OFFSET
                - state.WALL_SAFE_DISTANCE
            )

            moveHRPToPosition(safePos, state.AUTO_MOVE_SPEED_MULT)
            task.wait(0.08)

            ----------------------------------------------------------------
            -- STEP 3: BLOCK
            ----------------------------------------------------------------
            moveHRPToPosition(Vector3.new(pos.X, 0, pos.Z), state.AUTO_MOVE_SPEED_MULT)
            task.wait(0.06)

            for _, d in ipairs(lb:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    applyInstantGrab_PB(d)
                    firePromptSafe(d)
                    task.wait(0.04)
                end
            end

            task.wait(0.15)

            ----------------------------------------------------------------
            -- STEP 4: SAFE POS LAGI (SEJAJAR BLOCK)
            ----------------------------------------------------------------
            moveHRPToPosition(safePos, state.AUTO_MOVE_SPEED_MULT)
            task.wait(0.08)

            ----------------------------------------------------------------
            -- STEP 5: BALIK KE START
            ----------------------------------------------------------------
            tweenToFloor(state.Floors[1], true)
            task.wait(0.15)

            ----------------------------------------------------------------
            -- EVALUASI
            ----------------------------------------------------------------
            if lb and lb.Parent then
                if blockData.attempts >= state.LUCKY_MAX_ATTEMPTS then
                    blockData.attempts = 0
                end
                table.insert(state.LuckyBlockQueue, table.remove(state.LuckyBlockQueue, 1))
            else
                table.remove(state.LuckyBlockQueue, 1)
            end

            task.wait(0.2)
        end

        state.autoCollectBlockTask = nil
        restorePrompts_PB()
    end)
end

------------------------------------------------------
-- AUTO COLLECT TARGET (BLOCK > BRAINROT)
------------------------------------------------------
local function stopAutoCollectTarget()
    state.AutoCollectTarget = false

    -- Hentikan controller utama
    if state.autoCollectTargetTask then
        task.cancel(state.autoCollectTargetTask)
        state.autoCollectTargetTask = nil
    end

    -- Hentikan semua subsystem
    stopAutoCollectLuckyBlock()
    stopAllAutoCollect()

    -- Hentikan scanner
    stopRealtimeScanner()

    -- Lepaskan listener Lucky Block JIKA tidak ada sistem lain yang membutuhkan
    if not state.autoCollectBlockEnabled then
        detachLuckyBlockWatcher()
    end

    -- Kosongkan semua queue dan cache
    state.LuckyBlockQueue = {}
    state.LuckyBlockSeen = {}
    state.brainrotCache = {}

    -- Reset semua pending flags
    state.pendingRestartCollectBlock = false
    state.pendingRestartCollectRarity = false
    state.pendingRestartCollectTarget = false

    -- Reset state sub-sistem
    state.autoCollectBlockEnabled = false
    state.autoCollectEnabled = false

    print("[TARGET] Auto Collect Target completely stopped")
end

local function detachLuckyBlockWatcher()
    if state.luckyWatcherConnAdded then
        state.luckyWatcherConnAdded:Disconnect()
        state.luckyWatcherConnAdded = nil
    end
    if state.luckyWatcherConnRemoved then
        state.luckyWatcherConnRemoved:Disconnect()
        state.luckyWatcherConnRemoved = nil
    end
    if state.workspaceChildAddedConn then
        state.workspaceChildAddedConn:Disconnect()
        state.workspaceChildAddedConn = nil
    end
end

local function startAutoCollectTarget()
    -- cegah double task
    if state.autoCollectTargetTask then return end

    -- VALIDASI: Pastikan karakter hidup dan ready
    if not getRoot() then
        waitCharacterReady()
        task.wait(1.0)
    end

    -- ===============================
    -- VALIDASI TARGET
    -- ===============================
    if next(state.selectedRarities) == nil and next(state.LuckyBlockTargets) == nil then
        state.WindUI:Notify({
            Title = "Error",
            Content = "Pilih minimal 1 Target Lucky Block atau Brainrot!",
            Duration = 3
        })
        return
    end

    if not state.platformEnabled then
        state.WindUI:Notify({
            Title = "Error",
            Content = "Platform Builder harus aktif!",
            Duration = 3
        })
        return
    end

    -- ===============================
    -- HENTIKAN SISTEM LAIN
    -- ===============================
    stopAutoMove()
    stopAllAutoCollect()
    stopAutoCollectLuckyBlock()

    -- ===============================
    -- INISIALISASI SISTEM
    -- ===============================
    state.AutoCollectTarget = true

    if not state.scannerEnabled then
        startRealtimeScanner()
        task.wait(0.3)
    end

    enqueueExistingLuckyBlocks()
    attachActiveLuckyBlocksWatcher()

    -- ===============================
    -- CONTROLLER TASK
    -- ===============================
    state.autoCollectTargetTask = task.spawn(function()
        while state.AutoCollectTarget do
            -- ===============================
            -- PRIORITAS 1: LUCKY BLOCK
            -- ===============================
            if #state.LuckyBlockQueue > 0 then
                if not state.autoCollectBlockEnabled then
                    -- hentikan brainrot saja
                    stopAutoCollect()

                    state.autoCollectBlockEnabled = true
                    startAutoCollectLuckyBlock()
                end

            -- ===============================
            -- PRIORITAS 2: BRAINROT
            -- ===============================
            elseif next(state.selectedRarities) ~= nil then
                if not state.autoCollectEnabled then
                    stopAutoCollectLuckyBlock()

                    state.autoCollectEnabled = true
                    startAutoCollectBrainrotByRarity()
                end

            else
                -- tidak ada target sama sekali
                task.wait(0.4)
            end

            task.wait(0.25)
        end

        -- cleanup ketika controller berhenti
        state.autoCollectTargetTask = nil
    end)

    state.WindUI:Notify({
        Title = "Auto Collect Target",
        Content = "Prioritas: Lucky Block → Brainrot",
        Duration = 3
    })
end

-- remove map walls / build platform
local function removeMapWalls()
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and ((v.Name=="Wall" and v.Parent and v.Parent.Name=="Walls") or (state.TARGET_RIGHT_WALLS[v.Name] and v.Parent and v.Parent.Name=="RightWalls")) then
            pcall(function() v:Destroy() end)
        end
    end
end

local function buildPlatform()
    clearClientParts()
    local length = math.max(state.END_POS.X - state.START_POS.X, 1)
    local cursor = state.START_POS.X
    local remain = length
    local baseY = state.START_POS.Y + state.PLATFORM_Y_OFFSET
    local baseZ = state.START_POS.Z
    while remain > 0 do
        local seg = math.min(remain, state.MAX_PART_LENGTH)
        local center = cursor + seg/2
        table.insert(state.platformParts, createPart({
            Size = Vector3.new(seg, state.PLATFORM_THICKNESS, state.PLATFORM_WIDTH_Z),
            CFrame = CFrame.new(center, baseY - state.PLATFORM_THICKNESS/2, baseZ),
            Transparency = 0.25
        }))
        table.insert(state.wallParts, createPart({
            Size = Vector3.new(seg, state.WALL_HEIGHT, state.WALL_THICKNESS),
            CFrame = CFrame.new(center, baseY + state.WALL_HEIGHT/2, baseZ - state.PLATFORM_WIDTH_Z/2 - state.WALL_THICKNESS/2 + state.WALL_IN_OUT_OFFSET),
            Transparency = 0.15
        }))
        cursor = cursor + seg
        remain = remain - seg
    end
end

local function removePartsAbovePlatform()
    local topY = state.START_POS.Y + state.PLATFORM_Y_OFFSET + state.PLATFORM_THICKNESS
    local minX = math.min(state.START_POS.X, state.END_POS.X)
    local maxX = math.max(state.START_POS.X, state.END_POS.X)
    local zPad = state.PLATFORM_WIDTH_Z/2 + 10
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            if table.find(state.platformParts,v) or table.find(state.wallParts,v) then continue end
            local p = v.Position
            if p.X>=minX and p.X<=maxX and math.abs(p.Z-state.START_POS.Z)<=zPad and p.Y>topY then
                pcall(function() v:Destroy() end)
            end
        end
    end
end

-- vip bypass (platform builder)
local vipEnabled_PB = false
local function enableVIP_PB()
    if vipEnabled_PB then return end
    vipEnabled_PB = true
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name=="VIP" or v.Name=="VIP_PLUS") and v.Parent and v.Parent.Name=="VIPWalls" then
            v.CanCollide=false; v.CanTouch=false
        end
    end
end

local function disableVIP_PB()
    vipEnabled_PB = false
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name=="VIP" or v.Name=="VIP_PLUS") and v.Parent and v.Parent.Name=="VIPWalls" then
            v.CanCollide=true; v.CanTouch=true
        end
    end
end

local function enablePlatform()
    if not getRoot() then print("[ERROR] enablePlatform: No character found"); return end
    clearClientParts()
    removeMapWalls()
    buildPlatform()
    removePartsAbovePlatform()
    enableVIP_PB()
end

local function disablePlatform()
    clearClientParts()
    disableVIP_PB()
end

-- respawn / tween cancel handling (platform builder)
local function onCharacterDied_PB()
    local isForceDeath = state.platformBooting
    cancelLastTween()

    -- SIMPAN STATE UNTUK RESTART (TAMBAHKAN INI)
    state.pendingRestartMove = state.autoMoveEnabled
    state.pendingRestartCollectRarity = state.autoCollectEnabled
    state.pendingRestartCollect = state.autoCollectEnabled
    state.pendingRestartCollectBlock = state.autoCollectBlockEnabled
    state.pendingRestartCollectTarget = state.AutoCollectTarget  -- <- BARIS BARU

    -- Cancel semua task
    if state.autoMoveTask then task.cancel(state.autoMoveTask); state.autoMoveTask=nil end
    if state.autoCollectTask then task.cancel(state.autoCollectTask); state.autoCollectTask=nil end
    if state.autoCollectBlockTask then task.cancel(state.autoCollectBlockTask); state.autoCollectBlockTask=nil end
    if state.autoCollectTargetTask then task.cancel(state.autoCollectTargetTask); state.autoCollectTargetTask=nil end  -- <- BARIS BARU

    ---print("[DEATH] Character died. Saved states for restart.")
end

local function onCharacterAdded_PB(char)
    --------------------------------------------------
    -- CLEAN OLD CONNECTION
    --------------------------------------------------
    if state.humanoidDiedConn then
        pcall(function()
            state.humanoidDiedConn:Disconnect()
        end)
        state.humanoidDiedConn = nil
    end

    --------------------------------------------------
    -- WAIT CHARACTER READY
    --------------------------------------------------
    local hum = char:WaitForChild("Humanoid", 6)
    local hrp = char:WaitForChild("HumanoidRootPart", 6)

    if hum then
        state.humanoidDiedConn = hum.Died:Connect(onCharacterDied_PB)
    end

    -- tunggu physics & replication stabil
    task.wait(1.5)

    --------------------------------------------------
    -- PRIORITAS 1: RESTART AUTO COLLECT TARGET
    --------------------------------------------------
    if state.pendingRestartCollectTarget then
        state.pendingRestartCollectTarget = false
        
        -- Hentikan semua subsystem terlebih dahulu
        stopAutoCollect()
        stopAutoCollectLuckyBlock()
        
        -- Pastikan platform aktif
        if not state.platformEnabled then
            state.platformEnabled = true
            enablePlatform()
            task.wait(1.2)
        end
        
        -- Pastikan scanner aktif
        if not state.scannerEnabled then
            startRealtimeScanner()
            task.wait(0.3)
        end
        
        -- Refresh lucky block queue
        enqueueExistingLuckyBlocks()
        attachActiveLuckyBlocksWatcher()
        
        -- Tunggu sedikit untuk stabilisasi
        task.wait(0.8)
        
        -- RESTART CONTROLLER UTAMA
        state.AutoCollectTarget = true
        state.autoCollectTargetTask = task.spawn(function()
            while state.AutoCollectTarget do
                -- Logika prioritas Lucky Block > Brainrot
                if #state.LuckyBlockQueue > 0 then
                    if not state.autoCollectBlockEnabled then
                        stopAutoCollect()
                        state.autoCollectBlockEnabled = true
                        startAutoCollectLuckyBlock()
                    end
                elseif next(state.selectedRarities) ~= nil then
                    if not state.autoCollectEnabled then
                        stopAutoCollectLuckyBlock()
                        state.autoCollectEnabled = true
                        startAutoCollectBrainrotByRarity()
                    end
                else
                    task.wait(0.4)
                end
                task.wait(0.25)
            end
            state.autoCollectTargetTask = nil
        end)
        
        state.WindUI:Notify({
            Title = "Auto Collect Target",
            Content = "Restarted after respawn",
            Duration = 2
        })
        
    --------------------------------------------------
    -- FALLBACK: Restart sistem lama (jika tidak pakai Auto Collect Target)
    --------------------------------------------------
    elseif state.pendingRestartCollectBlock then
        state.pendingRestartCollectBlock = false
        
        if next(state.LuckyBlockTargets) ~= nil then
            state.autoCollectBlockEnabled = true
            
            if not state.platformEnabled then
                state.platformEnabled = true
                enablePlatform()
                task.wait(1)
            end
            
            enqueueExistingLuckyBlocks()
            startAutoCollectLuckyBlock()
        end
        
    elseif state.pendingRestartCollectRarity then
        state.pendingRestartCollectRarity = false
        
        if next(state.selectedRarities) ~= nil and state.platformEnabled then
            state.autoCollectEnabled = true
            startAutoCollectBrainrotByRarity()
        else
            state.autoCollectEnabled = false
        end
    end

    --------------------------------------------------
    -- AUTO MOVE RESUME (fallback)
    --------------------------------------------------
    if state.pendingRestartMove then
        state.pendingRestartMove = false
        state.autoMoveEnabled = true
        startAutoMoveToTarget(state.selectedFloorIndex or 1)
    end

    --------------------------------------------------
    -- SAFETY RESET
    --------------------------------------------------
    state.isTweening = false
    state.hardResetOnRespawn = false

    if hum then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
end

if LocalPlayer.Character then onCharacterAdded_PB(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded_PB)

------------------------------------------------------
-- HELPER: open lucky block tool
------------------------------------------------------
local function openLuckyBlockTool(tool)
    if not tool or not tool.Parent then return false end
    local rig = tool:FindFirstChild("LuckyBlockRig")
    if not rig then return false end
    local hum = getHumanoid()
    if not hum then return false end
    pcall(function() hum:EquipTool(tool) end)
    task.wait(0.15)
    pcall(function() tool:Activate() end)
    task.wait(0.15)
    local openRemote = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):FindFirstChild("RE/OpenLuckyBlock")
    if openRemote then pcall(function() openRemote:FireServer() end) end
    return true
end

--------------------------------------------------------------------------------
-- UI WINDOW (MAIN Hub) - WindUI usage kept as original
--------------------------------------------------------------------------------
local Window = state.WindUI:CreateWindow({
    Title="HexaCore | HUB",
    Icon="gamepad-2",
    Author="HexaCore by Dimz",
    Folder="PapiDimz_HUB_Config",
    Size=UDim2.fromOffset(600,520),
    Theme="Dark",
    Transparent=true,
    Acrylic=true,
    SideBarWidth=180,
    HasOutline=true,
    OpenButton = {
        Title = "HexaCore Hub",
        Icon = "monitor",
        CornerRadius = UDim.new(0, 16),
        StrokeThickness = 2,
        Color = ColorSequence.new(Color3.fromHex("FF0F7B"), Color3.fromHex("F89B29")),
        OnlyMobile = false,
        Enabled = true,
        Draggable = true,
    }
})

-- INFORMATION TAB
local infoTab=Window:Tab({Title="Information",Icon="info"})
infoTab:Paragraph({Title="Welcome To HexaCore Hub Official",Desc="Youtube Official : Hexacore-OFFICIAL"})
infoTab:Button({Title="Copy Discord Link",Callback=function() if setclipboard then setclipboard("https://discord.gg/Wcfqwy6Mdn") end end})
infoTab:Keybind({Title="HexaCore Keybind",Value="p",Callback=function(v) Window:SetToggleKey(Enum.KeyCode[v]) end})

-- MAIN TAB
local MainTab=Window:Tab({Title="Main",Icon="settings-2"})
MainTab:Section({ Title = "Automation" })
MainTab:Toggle({Title="Auto Collect",Callback=function(v) state.AutoCollect=v SnapshotUUIDsOnce() end})
MainTab:Toggle({Title="Auto Upgrade",Callback=function(v) state.AutoUpgrade=v SnapshotUUIDsOnce() end})
MainTab:Toggle({Title="Auto Buy Speed",Callback=function(v) state.AutoBuySpeed=v end})
MainTab:Toggle({Title="Auto Rebirth",Callback=function(v) state.AutoRebirth=v end})
MainTab:Toggle({Title="Auto Buy Carry",Callback=function(v) state.AutoBuyCarry=v end})
MainTab:Toggle({Title = "No Clip (Tembus Semua)", Callback = function(v) if v then enableNoClip() else disableNoClip() end end})

-- RUN TAB
local RunTab=Window:Tab({Title="Run",Icon="activity"})
RunTab:Section({ Title = "Premium Bypass" })
RunTab:Toggle({ Title = "Bypass VIP", Callback = function(v)
    if v then enableSelectiveNoClip(); enableVIPWallTouchBlock() else disableSelectiveNoClip(); disableVIPWallTouchBlock() end
end })

RunTab:Toggle({ Title = "Auto Obby Gold", Default = false, Callback = function(v)
    if v then
        stopAutoMove(); stopAutoCollect(); stopAutoCollectLuckyBlock()
        state.AutoObbyGoldEnabled = true
        setupObbyListener()
        state.WindUI:Notify({ Title = "Obby Gold", Content = "Starting Auto Obby Gold sequence...", Duration = 2 })
        task.wait(0.5); startObbyGoldSequence()
    else
        stopObbyGold()
    end
end })

RunTab:Section({ Title = "Platform Builder" })
RunTab:Toggle({ Title = "Platform Builder", Description = "ON = Build Platform | OFF = Remove Platform", Callback = function(v)
    state.platformEnabled = v
    if v then
        state.platformBooting = true
        stopAutoMove(); stopAutoCollect(); stopAutoCollectLuckyBlock()
        if not getRoot() then waitCharacterReady(); task.wait(1) end
        local success = pcall(function() tweenToFloor(state.Floors[1], true) end)
        if not success then state.WindUI:Notify({ Title = "Tween Gagal", Content = "Gagal pindah ke start, mencoba lagi...", Duration = 2 }); task.wait(0.5); tweenToFloor(state.Floors[1], true) end
        task.wait(0.8)
        enablePlatform()
        state.platformBooting = false
        state.WindUI:Notify({ Title = "Platform Ready", Content = "Platform & VIP telah aktif", Duration = 2 })
    else
        stopAutoMove(); stopAutoCollect(); stopAutoCollectLuckyBlock()
        disablePlatform()
        state.WindUI:Notify({ Title = "Platform Dimatikan", Content = "Platform & VIP telah dihapus", Duration = 2 })
    end
end })

RunTab:Slider({ Title = "Wall Safe Distance (positive => lebih ke dalam pijakan)", Value = { Min = -6, Max = 6, Default = state.WALL_SAFE_DISTANCE, Step = 0.1 }, Callback = function(v) state.WALL_SAFE_DISTANCE = v end })
RunTab:Slider({ Title = "Tween Speed (higher = faster)", Value = { Min = 100, Max = 1200, Default = state.TWEEN_SPEED, Step = 10 }, Callback = function(v) state.TWEEN_SPEED = v end })

-- Floor Navigation
RunTab:Section({ Title = "Floor Navigation" })
RunTab:Dropdown({ Title = "Target Brainrot", Values = state.BRAINROT_PRIORITY_ORDER, Multi = true, Default = {}, Callback = function(selectedList)
    state.selectedRarities = {}
    for _, rarity in ipairs(selectedList) do state.selectedRarities[rarity] = true end
end })

RunTab:Dropdown({ 
    Title = "Target Lucky Block", 
    Values = state.LUCKY_PRIORITY_ORDER,  -- Menggunakan priority order yang sudah didefinisikan
    Multi = true, 
    Default = {}, 
    Callback = function(selectedList)
        state.LuckyBlockTargets = {}
        for _, v in ipairs(selectedList) do 
            state.LuckyBlockTargets[tostring(v)] = true 
        end

        -- PATCH: jika auto collect block sedang aktif, refresh queue agar target baru langsung berlaku
        if state.autoCollectBlockEnabled then
            -- remove queued items that are no longer allowed
            refreshLuckyBlockQueueForTargets()
            -- try to enqueue any existing blocks matching new targets
            enqueueExistingLuckyBlocks()
            sortLuckyBlockQueue()
            state.WindUI:Notify({ 
                Title = "Lucky Block Targets Updated", 
                Content = "Target Lucky Block diperbarui dan queue direfresh.", 
                Duration = 2 
            })
        end
    end 
})


RunTab:Slider({ Title = "Jumlah Brainrot per Loop", Description = "Berapa banyak brainrot yang diambil tiap loop (1..6)", Value = { Min = 1, Max = 6, Default = state.BRAINROT_PICK_COUNT, Step = 1 }, Callback = function(v) state.BRAINROT_PICK_COUNT = v end })

RunTab:Toggle({
    Title = "Auto Collect Target",
    Description = "Prioritas: Lucky Block → Brainrot (movement aman)",
    Default = false,
    Callback = function(v)
        if v then
            stopAutoMove()
            startAutoCollectTarget()
        else
            stopAutoCollectTarget()
        end
    end
})


RunTab:Button({ Title = "⬆ Move Up", Callback = function()
    stopAutoMove(); stopAutoCollect()
    local hrp = nil; pcall(function() hrp = getHRP() end); if not hrp then hrp = getRoot() end
    if not hrp then return end
    local nextFloor = getNextFloor(hrp.Position.X)
    if nextFloor then tweenToFloor(nextFloor, false) end
end })

RunTab:Button({ Title = "⬇ Move Down", Callback = function()
    stopAutoMove(); stopAutoCollect()
    local hrp = nil; pcall(function() hrp = getHRP() end); if not hrp then hrp = getRoot() end
    if not hrp then return end
    local prevFloor = getPrevFloor(hrp.Position.X)
    if prevFloor then tweenToFloor(prevFloor, false) end
end })

RunTab:Toggle({ Title = "Auto Move To Target", Description = "Bergerak 1 per 1 floor menuju target (melewati tiap floor)", Default = false, Callback = function(v)
    if v then stopAutoCollect(); state.autoMoveEnabled = true; startAutoMoveToTarget(state.selectedFloorIndex) else stopAutoMove() end
end })

-- EVENT TAB
local EventTab=Window:Tab({Title="Event",Icon="radio"})
EventTab:Section({ Title = "Event Collect Coins" })
EventTab:Toggle({Title="Collect Radioactive Coin",Callback=function(v) state.AutoCollectRadioactive = v end})
EventTab:Toggle({Title="Collect UFO Coin",Callback=function(v) state.AutoCollectUFO = v end})
EventTab:Toggle({Title = "Collect Gold Bar",Callback = function(v) state.AutoCollectGoldBar = v end})
EventTab:Toggle({ Title = "Collect Ticket", Callback = function(v) state.AutoCollectTicket = v end })
EventTab:Toggle({ Title = "Collect Gamer", Callback = function(v) state.AutoCollectGamer = v end })

EventTab:Section({ Title = "Auto Spin Wheel" })
EventTab:Toggle({Title="Auto Spin Radioactive",Callback=function(v) state.AutoSpinRadioactive=v end})
EventTab:Toggle({Title="Auto Spin UFO",Callback=function(v) state.AutoSpinUFO=v end})
EventTab:Toggle({ Title = "Auto Spin Gold Bar", Callback = function(v) state.AutoSpinGoldBar = v end })

-- SELL BRAINROT (Sell tab build kept)
-- ... (SellState and sell helpers are kept below unchanged in logic)
local SellState = {
    scanResults = {},
    chosenTypes = {},
    levelThreshold = 1,
}
SellState.BRAINROT_LISTS = {
    Celestial = { "Diamantusa","Caffe Trinity","Alessio","Job Job Job Sahur","Dug Dug Dug",
        "Bisonte Giuppitere","Esok Sekolah","Zung Zung Zung Lazur","Avocadini Antilopini",
        "Los Orcaleritos","Capuccino Policia","Rattini Machini","La Malita","Money Elephant"
    },
    Cosmic = { "Darlungini Pandanneli","Vroosh Boosh","Nuclearo Dinossauro","La Grande Combinasion",
        "Garama and Madundung","Dragon Cannelloni","Chimpanzini Spiderini","Agarrini la Palini",
        "Las Vaquitas Saturnitas","Graipuss Medussi","Torrtuginni Dragonfrutini",
        "Los Tralaleritos","La Vacca Saturno Saturnita","Pot Hotspot",
        "Las Tralaleritas","Chicleteira Bicicleteira"
    },
    Epic = { "Blueberrinni Octopussini","Ballerina Cappuccina","Burbaloni Luliloli",
        "Strawberrelli Flamingelli","Sigma Boy","Pi Pi Watermelon","Pandaccini Bananini",
        "Lionel Cactuseli","Guesto Angelic","Cocosini Mama","Chef Crabracadabra",
        "Chimpanzini Bananini","Glorbo Fruttodrillo"
    },
    Legendary = { "Eaglucci Cocosucci","Zibra Zubra Zibralini","Tigrilini Watermelini",
        "Spioniro Golubiro","Rhino Toasterino","Orangutini Ananasini",
        "Gorillo Watermelondrillo","Ganganzelli Trulala","Frigo Camelo",
        "Bombombini Gusini","Bombardiro Crocodilo","Avocadorilla","Cavallo Virtuoso"
    },
    Mythical = { "Ballerino Lololo","Cocofanto Elefanto","Los Crocodillitos","Piccione Macchina",
        "Tigroligre Frutonni","Trenostruzzo Turbo 3000",
        "Trippi Troppi Troppa Trippa","Tukanno Bananno","Udin Din Din Dun",
        "Orcalero Orcala","Giraffa Celeste","Tralalero Tralala"
    },
    Rare = { "Trulimero Trulicina","Ti Ti Ti Sahur","Salamino Penguino",
        "Perochello Lemonchello","Penguino Cocosino","Cappuccino Assassino",
        "Bananita Dolphinita","Bambini Crostini","Brr Brr Patapim","Avocadini Guffo"
    },
    Secret = { "Bambooini Bombini","Eek Eek Eek Sahur","Rainbow 67",
        "La Vacca Black Hole Goat","Fragola La La La","Aura Farma",
        "Los Tungtungtungcitos","Los Combinasionas","Espresso Signora",
        "Unclito Samito","Gattatino Neonino","Gatattino Donutino",
        "Statutino Libertino","Capybara Monitora","Tractoro Dinosauro",
        "Mastodontico Telepiedone","Patatino Astronauta","Matteo",
        "Patito Dinerito","Onionello Penguini"
    },
    Uncommon = { "Trippi Troppi","Tric Tric Baraboom","Ta Ta Ta Sahur","Pipi Avocado",
        "Gangster Footera","Cacto Hipopotamo","Boneca Ambalabu",
        "Bobrito Bandito","67"
    },
    Common = { "Tim Cheese","Talpa Di Fero","Svinino Bombondino","Pipi Kiwi",
        "Pipi Corni","Noobini Cakenini","Lirili Larila","Frulli Frulla"
    },
    Divine = { "Strawberry Elephant","Burgerini Bearini","Bulbito Bandito Traktorito",
        "Martino Gravitino","Galactio Fantasma","Din Din Vaultero","Grappellino D'Oro"
    },
    Infinity = { "Noobini Infeeny" }
}

local function buildLookups()
    SellState.BRAINROT_LOOKUP = {}
    for rarity, list in pairs(SellState.BRAINROT_LISTS) do
        local t = {}
        for _, name in ipairs(list) do t[string.lower(name)] = true end
        SellState.BRAINROT_LOOKUP[rarity] = t
    end
end
buildLookups()

local function scanInventory()
    SellState.scanResults = {}
    local plr = Players.LocalPlayer
    if not plr then return 0 end
    local bp = plr:FindFirstChild("Backpack")
    if not bp then return 0 end
    for _, item in ipairs(bp:GetChildren()) do
        if item and item.Parent and item:FindFirstChild("RenderModel") then
            local r = item.RenderModel
            local brName = nil; local lvl = nil; local mut = nil
            if r.GetAttribute then brName = r:GetAttribute("BrainrotName"); lvl = r:GetAttribute("Level"); mut = r:GetAttribute("Mutation") end
            local nameStr = brName and tostring(brName) or tostring(item.Name)
            local levelNum = tonumber(lvl) or 0
            local mutStr = mut and tostring(mut) or ""
            table.insert(SellState.scanResults, { tool = item, name = nameStr, level = levelNum, mutation = mutStr })
        end
    end
    return #SellState.scanResults
end

local function sellToolInstance(toolInstance)
    if not toolInstance or not toolInstance.Parent then return false, "tool invalid" end
    local rf = ReplicatedStorage:FindFirstChild("RemoteFunctions")
    local remote = rf and rf:FindFirstChild("SellTool")
    if not remote then return false, "remote not found" end
    local ok, res = pcall(function()
        if toolInstance:IsA("Tool") then
            pcall(function() local hum = getHumanoid(); if hum then hum:EquipTool(toolInstance) end end)
            task.wait(0.06)
        end
        return remote:InvokeServer()
    end)
    if not ok then return false, "invoke error" end
    return true, nil
end

local function isNameInRarity(name, rarity)
    if not name then return false end
    if not rarity or rarity == "All" then return true end
    local ln = string.lower(name)
    local lookup = SellState.BRAINROT_LOOKUP[rarity]
    return lookup and lookup[ln]
end

local function collectMatchesFromScan()
    local matches = {}
    local thr = tonumber(SellState.levelThreshold) or 0
    for _, entry in ipairs(SellState.scanResults) do
        local passesTypeFilter = true
        if next(SellState.chosenTypes) then
            passesTypeFilter = false
            for ty, _ in pairs(SellState.chosenTypes) do
                if isNameInRarity(entry.name, ty) then passesTypeFilter = true; break end
            end
        end
        if passesTypeFilter then
            if entry.level <= thr then table.insert(matches, entry) end
        end
    end
    return matches
end

-- Sell Tab (defensive create if not exists)
local hasSellTab = false
for _, t in ipairs(Window.Tabs or {}) do if t.Title == "Sell Brainrot" then hasSellTab = true break end end

if not hasSellTab then
    local SellTab = Window:Tab({ Title = "Sell Brainrot", Icon = "shopping-bag" })
    SellTab:Section({ Title = "Filter / Sell" })
    SellTab:Dropdown({ Title = "Type Brainrot", Values = { "Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Celestial","Divine","Infinity" }, Multi = true, Default = {}, Callback = function(selectedList) SellState.chosenTypes = {}; for _, v in ipairs(selectedList) do SellState.chosenTypes[v] = true end end })
    SellTab:Input({ Title = "Level (below)", Placeholder = tostring(SellState.levelThreshold), Callback = function(v) local n = tonumber(v); if n and n >= 0 then SellState.levelThreshold = n; state.WindUI:Notify({ Title = "Threshold Set", Content = tostring(n), Duration = 1 }) else state.WindUI:Notify({ Title = "Error", Content = "Masukkan angka valid", Duration = 1 }) end end })
    SellTab:Button({ Title = "Sell Brainrot", Description = "Scan inventory lalu jual semua brainrot yang cocok (type + level below).", Callback = function()
        local found = scanInventory()
        if found == 0 then state.WindUI:Notify({ Title = "No Items", Content = "Tidak ada item dengan RenderModel di Backpack.", Duration = 2 }); return end
        local matches = collectMatchesFromScan()
        if #matches == 0 then state.WindUI:Notify({ Title = "No Matches", Content = "Tidak ada brainrot sesuai kriteria.", Duration = 2 }); return end
        state.WindUI:Notify({ Title = "Selling...", Content = ("Menjual %d brainrot"):format(#matches), Duration = 2 })
        local sold = 0
        for _, entry in ipairs(matches) do
            local toolObj = entry.tool
            if toolObj and toolObj.Parent then
                local ok, err = sellToolInstance(toolObj)
                if ok then sold = sold + 1; print(("[Sell] OK: %s lvl=%d"):format(entry.name, entry.level)) else warn(("[Sell] Failed %s: %s"):format(entry.name, tostring(err))) end
                task.wait(0.18)
            else
                warn("[Sell] tool missing or moved: " .. tostring(entry.tool and entry.tool.Name))
            end
        end
        state.WindUI:Notify({ Title = "Done", Content = ("Terjual: %d / %d"):format(sold, #matches), Duration = 3 })
    end })
    SellTab:Section({ Title = "Open Lucky Block" })
    SellTab:Dropdown({ Title = "Type Lucky Block", Values = { "All","Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Celestial","Divine","Infinity" }, Multi = true, Default = { "All" }, Callback = function(selected)
        state.OpenBlockState.chosenTypes = {}
        for _, v in ipairs(selected) do
            if v == "All" then state.OpenBlockState.chosenTypes = { All = true } return end
            state.OpenBlockState.chosenTypes[v] = true
        end
    end })
    SellTab:Button({ Title = "Open Block", Description = "Buka semua Lucky Block di Backpack sesuai Type Lucky Block", Callback = function()
        local bp = Players.LocalPlayer:FindFirstChild("Backpack")
        if not bp then state.WindUI:Notify({ Title = "Error", Content = "Backpack tidak ditemukan", Duration = 2 }); return end
        local opened = 0; local total = 0
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local rig = tool:FindFirstChild("LuckyBlockRig")
                if rig then
                    local blockType = rig:GetAttribute("LuckyBlockType")
                    blockType = blockType and tostring(blockType)
                    local allow = false
                    if state.OpenBlockState.chosenTypes.All then allow = true
                    elseif blockType and state.OpenBlockState.chosenTypes[blockType] then allow = true end
                    if allow then
                        total += 1
                        local ok = openLuckyBlockTool(tool)
                        if ok then opened += 1 end
                        task.wait(0.2)
                    end
                end
            end
        end
        state.WindUI:Notify({ Title = "Open Block Done", Content = string.format("Opened %d / %d Lucky Blocks", opened, total), Duration = 3 })
    end })
end

-- MISC TAB
local MiscTab=Window:Tab({Title="Misc",Icon="sparkles"})
MiscTab:Section({ Title = "I dont know but i know u need this features" })
MiscTab:Toggle({Title="Instant Grab",Callback=function(v) if v then enableInstantGrab() else disableInstantGrab() end end})
MiscTab:Toggle({Title="Infinite Zoom Out",Callback=function(v) if v then enableInfiniteZoom() else disableInfiniteZoom() end end})
MiscTab:Toggle({Title="Infinite Jump",Callback=function(v) if v then enableInfiniteJump() else disableInfiniteJump() end end})

------------------------------------------------------
-- COMPLETE CLEANUP FUNCTION
------------------------------------------------------
local function cleanupAll()
    print("[CLEANUP] Starting complete cleanup...")
    
    -- 1. Hentikan semua sistem automasi dan task
    stopObbyGold()
    stopAutoMove()
    stopAllAutoCollect()
    stopAutoCollectLuckyBlock()
    stopAutoCollectTarget()
    
    -- 2. Hentikan scanner
    stopRealtimeScanner()
    
    -- 3. Matikan platform builder
    if state.platformEnabled then
        state.platformEnabled = false
        disablePlatform()
    end
    
    -- 4. Matikan semua fitur instant/misc
    if state.InstantGrabEnabled then disableInstantGrab() end
    if state.InfiniteZoomEnabled then disableInfiniteZoom() end
    if state.InfiniteJumpEnabled then disableInfiniteJump() end
    if state.NoClipEnabled then disableNoClip() end
    if state.SelectiveNoClipEnabled then disableSelectiveNoClip() end
    
    -- 5. Hentikan semua koneksi event
    if addConn then addConn:Disconnect(); addConn = nil end
    if remConn then remConn:Disconnect(); remConn = nil end
    if state.promptConn then state.promptConn:Disconnect(); state.promptConn = nil end
    if state.vipNoClipConn then state.vipNoClipConn:Disconnect(); state.vipNoClipConn = nil end
    if state.vipTouchBlockConn then state.vipTouchBlockConn:Disconnect(); state.vipTouchBlockConn = nil end
    if state.noClipConn then state.noClipConn:Disconnect(); state.noClipConn = nil end
    if state.infiniteJumpConn then state.infiniteJumpConn:Disconnect(); state.infiniteJumpConn = nil end
    if state.humanoidDiedConn then state.humanoidDiedConn:Disconnect(); state.humanoidDiedConn = nil end
    if state.luckyWatcherConnAdded then state.luckyWatcherConnAdded:Disconnect(); state.luckyWatcherConnAdded = nil end
    if state.luckyWatcherConnRemoved then state.luckyWatcherConnRemoved:Disconnect(); state.luckyWatcherConnRemoved = nil end
    if state.workspaceChildAddedConn then state.workspaceChildAddedConn:Disconnect(); state.workspaceChildAddedConn = nil end
    if obbyListenerConn then obbyListenerConn:Disconnect(); obbyListenerConn = nil end
    
    -- 6. Cancel semua tweens
    cancelLastTween()
    
    -- 7. Restore semua prompts yang dimodifikasi
    restorePrompts()
    restorePrompts_PB()
    
    -- 8. Hapus semua bagian platform yang dibuat
    clearClientParts()
    
    -- 9. Reset semua state ke default (kecuali yang diperlukan untuk restart)
    for k, _ in pairs(state) do
        -- Hanya reset flag boolean dan tabel, jangan hapus WindUI
        if type(state[k]) == "boolean" then
            state[k] = false
        elseif type(state[k]) == "table" and k ~= "WindUI" and k ~= "Floors" then
            state[k] = {}
        end
    end
    
    -- 10. Reset camera zoom
    pcall(function()
        LocalPlayer.CameraMinZoomDistance = minZoom
        LocalPlayer.CameraMaxZoomDistance = maxZoom
    end)
    
    print("[CLEANUP] Complete cleanup finished.")
end

-- CLEANUP ON SCRIPT DISABLE
Window:OnClose(function()
    cleanupAll()
    state.WindUI:Notify({ Title = "HexaCore Hub", Content = "All systems stopped and cleaned up.", Duration = 3 })
end)

-- READY
state.WindUI:Notify({ Title="HexaCore Hub Loaded", Content="Auto Run + Respawn + Manual Override FIXED", Duration=4 })

