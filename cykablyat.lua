--====================================================
-- FRENESIS x HexaCore HUB (FINAL COMPLETE + AUTO RUN)
--====================================================
--https://chatgpt.com/c/6985abb6-601c-8321-8204-d5fe06a08a0e
------------------------------------------------------
-- STATE ROOT
------------------------------------------------------
local State = {}

------------------------------------------------------
-- LOAD WINDUI
------------------------------------------------------
local ok, WindUI = pcall(function()
    return loadstring(game:HttpGet(
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
    ))()
end)
if not ok or type(WindUI) ~= "table" then return end
State.WindUI = WindUI

------------------------------------------------------
-- SERVICES
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
local ReplicatorEvent = ReplicatedStorage.__ReplicatorInternal.RemoteEvent
local PlotAction = ReplicatedStorage.Packages.Net and ReplicatedStorage.Packages.Net["RF/Plot.PlotAction"]
local UpgradeSpeed = ReplicatedStorage.RemoteFunctions and ReplicatedStorage.RemoteFunctions.UpgradeSpeed
local Rebirth = ReplicatedStorage.RemoteFunctions and ReplicatedStorage.RemoteFunctions.Rebirth
local UpgradeCarry = ReplicatedStorage.RemoteFunctions and ReplicatedStorage.RemoteFunctions.UpgradeCarry
local WheelSpinRoll = ReplicatedStorage.Packages and ReplicatedStorage.Packages.Net and ReplicatedStorage.Packages.Net["RF/WheelSpin.Roll"]
local WheelSpinComplete = ReplicatedStorage.Packages and ReplicatedStorage.Packages.Net and ReplicatedStorage.Packages.Net["RE/WheelSpin.Complete"]

------------------------------------------------------
-- FLAGS
------------------------------------------------------
local AutoCollect, AutoUpgrade, AutoCollectGoldBar = false, false, false
local AutoBuySpeed, AutoRebirth, AutoBuyCarry = false, false, false
local AutoCollectRadioactive, AutoCollectUFO = false, false
local AutoSpinRadioactive, AutoSpinUFO, AutoSpinGoldBar = false, false, false

local InstantGrabEnabled = false
local InfiniteZoomEnabled = false
local InfiniteJumpEnabled = false

local SelectiveNoClipEnabled = false
local vipNoClipConn = nil
local NoClipEnabled = false
local noClipConn = nil

local AutoRunEnabled = false
local TargetGapIndex = 1

local infiniteJumpConn, promptConn = nil, nil
local promptOriginalHold = {}

local Plots, ActiveUUIDs = {}, {}
local UUIDSnapshotDone = false
local isMovingGap = false

-- STATE (platform builder)
local isTweening = false
local platformEnabled = false

local autoMoveEnabled = false
local autoMoveTask = nil

local autoCollectEnabled = false
local autoCollectTask = nil

-- selected floor index (shared between UI & onCharacterAdded)
local selectedFloorIndex = 1

-- jumlah brainrot per loop (1..6)
local BRAINROT_PICK_COUNT = 1

-- Auto collect lucky block state
local autoCollectBlockEnabled = false
local autoCollectBlockTask = nil
local LuckyBlockTargets = {}   -- set table, e.g. { ["Secret"] = true, ["Legendary"] = true }
local pendingRestartCollectRarity = false  -- Untuk auto collect brainrot (rarity-based)
local selectedRarities = {}  -- Untuk menyimpan rarity yang dipilih
local pendingRestartCollectBlock = false  -- Untuk auto collect lucky block
local brainrotCache = {}  -- Cache realtime brainrot (huruf kecil konsisten)
local BRAINROT_PRIORITY_ORDER = {
    "Infinity",    -- 1. Priority 1
    "Divine",      -- 2. Priority 2
    "Celestial",   -- 3. Priority 3
    "Secret",      -- 4. Priority 4
    "Cosmic",      -- 5. Priority 5
    "Mythical",    -- 6. Priority 6
    "Legendary",   -- 7. Priority 7
    "Epic",        -- 8. Priority 8
    "Rare",        -- 9. Priority 9
    "Uncommon",    -- 10. Priority 10
    "Common"       -- 11. Priority 11
}

-- debug toggle
local DEBUG_LUCKY = false

-- Lucky Block live watcher
local LuckyBlockQueue = {}   -- FIFO queue
local LuckyBlockSeen = {}    -- prevent duplicate enqueue


local Floors = {
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

-- tween cancel / respawn
local lastTween = nil
local pendingRestartMove = false
local pendingRestartCollect = false
local humanoidDiedConn = nil

local scannerEnabled = false
local scannerTask = nil
local brainrotCache = {} -- Cache realtime brainrot

local platformBooting = false
local hardResetOnRespawn = false

-- INTERNAL STORAGE
local platformParts = {}
local wallParts = {}

local OpenBlockState = {
    chosenTypes = {} -- set table, contoh { ["Legendary"]=true }
}

local coinCache = {
    ["Radioactive Coin"] = {},
    ["UFO Coin"] = {},
    ["GoldBar"] = {}
}
local cachePointers = {
    ["Radioactive Coin"] = 1,
    ["UFO Coin"] = 1,
    ["GoldBar"] = 1
}
------------------------------------------------------
-- HELPERS
------------------------------------------------------
local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- RUN SERVICES Extra safety: ensure auto tasks react if user drifts (already in update.lua)
RunService.Heartbeat:Connect(function()
    -- Cek jika karakter mati, skip semua
    local hum = getHumanoid()
    if hum and hum.Health <= 0 then
        return
    end
    
    if autoMoveEnabled and not autoMoveTask then
        startAutoMoveToTarget(selectedFloorIndex)
    end

    if autoCollectEnabled and not autoCollectTask then
        startAutoCollectBrainrot(selectedFloorIndex)
    end
end)

local function waitCharacterReady()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart", 5)
    char:WaitForChild("Humanoid", 5)
end

-- helper to try-get a BasePart from descendant
local function getCoinPart(desc)
    if desc:IsA("BasePart") then return desc end
    return desc:FindFirstChildWhichIsA("BasePart")
end

-- helpers kecil
local function safeGetAttr(inst, name)
    local ok, res = pcall(function() return inst:GetAttribute(name) end)
    if ok then return res end
    return nil
end

-- trim whitespace
local function trim(s)
    if not s then return nil end
    return (tostring(s):match("^%s*(.-)%s*$"))
end

-- Tambahkan di HELPERS SECTION (sekitar line 150-200):
local function restorePrompts()
    -- Restore dari sistem misc
    for p, d in pairs(promptOriginalHold) do
        if p and p.Parent then
            p.HoldDuration = d
        end
    end
    promptOriginalHold = {}
    
    -- Restore dari platform builder (jika ada)
    if promptOriginalHold_PB then
        for p, d in pairs(promptOriginalHold_PB) do
            if p and p.Parent then
                p.HoldDuration = d
            end
        end
        promptOriginalHold_PB = {}
    end
end

local function sortBrainrotsByPriority(brainrotList)
    -- Buat map priority untuk sorting cepat
    local priorityMap = {}
    for i, rarity in ipairs(BRAINROT_PRIORITY_ORDER) do
        priorityMap[rarity] = i
    end
    
    -- Sort brainrot list: pertama berdasarkan priority, lalu berdasarkan X position
    table.sort(brainrotList, function(a, b)
        -- Urut berdasarkan priority (angka lebih kecil = priority lebih tinggi)
        local priorityA = priorityMap[a.rarity] or 999
        local priorityB = priorityMap[b.rarity] or 999
        
        if priorityA ~= priorityB then
            return priorityA < priorityB
        end
        
        -- Jika priority sama, urut berdasarkan X (terdekat dari start)
        return a.position.X < b.position.X
    end)
    
    return brainrotList
end

-- cari index floor dari nama -- lebih toleran (trim, case-insensitive, partial)
local function getFloorIndexByName(name)
    -- Pastikan Floors ada
    if not Floors then
        print("[ERROR] Floors table is nil!")
        return nil
    end
    
    if not name then 
        print("[DEBUG] getFloorIndexByName: name is nil")
        return nil 
    end
    
    local tn = trim(name)
    if not tn then 
        print("[DEBUG] getFloorIndexByName: trimmed name is nil")
        return nil 
    end
    
    print("[DEBUG] getFloorIndexByName searching for:", tn)
    print("[DEBUG] Floors table has", #Floors, "entries")
    
    -- Simple exact match
    for i, f in ipairs(Floors) do
        if f.name == tn then
            print("[DEBUG] Found floor", tn, "at index", i)
            return i
        end
    end
    
    print("[DEBUG] Floor not found:", tn)
    return nil
end

-- fallback: pilih floor terdekat berdasarkan posisi X (pivot.X)
local function getFloorIndexByPosition(x)
    if not x then return 1 end
    local bestIndex = 1
    local bestDist = math.huge
    for i, f in ipairs(Floors) do
        local d = math.abs(x - (f.x or 0))
        if d < bestDist then
            bestDist = d
            bestIndex = i
        end
    end
    return bestIndex
end

------------------------------------------------------
-- RESPAWN PATCH
------------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function()
    isMovingGap = false
    waitCharacterReady()
end)

------------------------------------------------------
-- PLOT LISTENER (ASLI)
------------------------------------------------------
if ReplicatorEvent then
    ReplicatorEvent.OnClientEvent:Connect(function(p)
        if not p or not p[1] or not p[1][3] then return end
        for uuid, info in pairs(p[1][3]) do
            if info.data and info.data.Stands then
                Plots[uuid] = info.data.Stands
            end
        end
    end)
end

local function SnapshotUUIDsOnce()
    if UUIDSnapshotDone then return end
    for uuid in pairs(Plots) do ActiveUUIDs[uuid] = true end
    UUIDSnapshotDone = true
end

------------------------------------------------------
-- AUTO CORE LOOPS (ASLI)
------------------------------------------------------
task.spawn(function()
    while true do
        if AutoBuySpeed and UpgradeSpeed then pcall(function() UpgradeSpeed:InvokeServer(10) end) end
        task.wait(2)
    end
end)

task.spawn(function()
    while true do
        if AutoRebirth and Rebirth then pcall(function() Rebirth:InvokeServer() end) end
        task.wait(5)
    end
end)

task.spawn(function()
    while true do
        if AutoBuyCarry and UpgradeCarry then pcall(function() UpgradeCarry:InvokeServer() end) end
        task.wait(3)
    end
end)

task.spawn(function()
    while true do
        if UUIDSnapshotDone then
            if AutoCollect and PlotAction then
                for uuid in pairs(ActiveUUIDs) do
                    for i=1,40 do
                        pcall(function()
                            PlotAction:InvokeServer("Collect Money", uuid, tostring(i))
                        end)
                    end
                end
            end
            if AutoUpgrade and PlotAction then
                for uuid in pairs(ActiveUUIDs) do
                    for i=1,40 do
                        pcall(function()
                            PlotAction:InvokeServer("Upgrade Brainrot", uuid, tostring(i))
                        end)
                    end
                end
            end
        end
        task.wait(0.6)
    end
end)

------------------------------------------------------
-- EVENT COINS
------------------------------------------------------
-- initial fill (single scan)
for _,v in ipairs(Workspace:GetDescendants()) do
    local n = v.Name
    if coinCache[n] then
        local p = getCoinPart(v)
        if p then table.insert(coinCache[n], p) end
    end
end

-- keep cache updated on add/remove
local function onDescendantAdded(v)
    local n = v.Name
    if coinCache[n] then
        local p = getCoinPart(v)
        if p then
            table.insert(coinCache[n], p)
        end
    end
end

local function onDescendantRemoving(v)
    local n = v.Name
    if coinCache[n] then
        local cache = coinCache[n]
        -- remove any reference matching the part or model
        for i = #cache, 1, -1 do
            if not cache[i].Parent or cache[i] == v or cache[i].Parent == v then
                table.remove(cache, i)
            end
        end
        -- clamp pointer
        if cachePointers[n] > #cache then cachePointers[n] = 1 end
    end
end

local addConn = Workspace.DescendantAdded:Connect(onDescendantAdded)
local remConn = Workspace.DescendantRemoving:Connect(onDescendantRemoving)

local function cleanupCoinCollector()
    if addConn then addConn:Disconnect() addConn = nil end
    if remConn then remConn:Disconnect() remConn = nil end
end

-- processing loop: spread work across frames to avoid spikes
local PROCESS_PER_TYPE = 12        -- how many coins per type per heartbeat (tuneable)
local DISTANCE_THRESHOLD = 500    -- only move coins within this distance (studs)
RunService.Heartbeat:Connect(function()
    if not (AutoCollectRadioactive or AutoCollectUFO or AutoCollectGoldBar) then
        return
    end

    local hrp = getRoot()
    if not hrp then return end

    -- iterate types
    for coinName, cache in pairs(coinCache) do
        local enabled = (coinName == "Radioactive Coin" and AutoCollectRadioactive)
                     or (coinName == "UFO Coin" and AutoCollectUFO)
                     or (coinName == "GoldBar" and AutoCollectGoldBar)
        if enabled and #cache > 0 then
            local ptr = cachePointers[coinName] or 1
            local toProcess = math.min(PROCESS_PER_TYPE, #cache)
            for i = 1, toProcess do
                if #cache == 0 then break end
                if ptr > #cache then ptr = 1 end
                local part = cache[ptr]
                -- validate part
                if not part or not part.Parent then
                    table.remove(cache, ptr)
                    -- don't advance ptr, because we removed current index
                else
                    -- distance check to reduce pointless teleports
                    local dist = (part.Position - hrp.Position).Magnitude
                    if dist <= DISTANCE_THRESHOLD then
                        -- small random offset to avoid stacking exactly on top
                        local offset = CFrame.new(math.random(-2,2), 0.5, math.random(-2,2))
                        -- pcall to be safe if part becomes invalid mid-op
                        pcall(function() part.CFrame = hrp.CFrame * offset end)
                    end
                    ptr = ptr + 1
                end
            end
            cachePointers[coinName] = (ptr > 0 and ptr) or 1
        end
    end
end)

------------------------------------------------------
-- AUTO SPIN
------------------------------------------------------
local function doSpin(kind)
    if not WheelSpinRoll or not WheelSpinComplete then return end
    pcall(function() WheelSpinRoll:InvokeServer(kind,false) end)
    task.wait(0.25)
    pcall(function()
        WheelSpinComplete:FireServer(tostring(os.clock().."_"..math.random(10000,99999)))
    end)
end

task.spawn(function()
    while true do
        if AutoSpinRadioactive then doSpin("Radioactive") end
        if AutoSpinUFO then doSpin("UFO") end
        if AutoSpinGoldBar then doSpin("Money") end
        task.wait(1.2)
    end
end)

------------------------------------------------------
-- INSTANT GRAB
------------------------------------------------------
local function applyInstantGrab(p)
    if p:IsA("ProximityPrompt") then
        if not promptOriginalHold[p] then
            promptOriginalHold[p] = p.HoldDuration
        end
        p.HoldDuration = 0
    end
end

local function enableInstantGrab()
    InstantGrabEnabled = true
    for _,v in ipairs(Workspace:GetDescendants()) do applyInstantGrab(v) end
    if promptConn then promptConn:Disconnect() end
    promptConn = Workspace.DescendantAdded:Connect(function(v)
        if InstantGrabEnabled then applyInstantGrab(v) end
    end)
end

local function disableInstantGrab()
    InstantGrabEnabled = false
    if promptConn then promptConn:Disconnect() promptConn=nil end
    for p,d in pairs(promptOriginalHold) do
        if p.Parent then p.HoldDuration=d end
    end
    promptOriginalHold = {}
end

------------------------------------------------------
-- INFINITE ZOOM
------------------------------------------------------
local minZoom,maxZoom = LocalPlayer.CameraMinZoomDistance,LocalPlayer.CameraMaxZoomDistance
local function enableInfiniteZoom()
    InfiniteZoomEnabled=true
    LocalPlayer.CameraMinZoomDistance=0.5
    LocalPlayer.CameraMaxZoomDistance=1e6
end
local function disableInfiniteZoom()
    InfiniteZoomEnabled=false
    LocalPlayer.CameraMinZoomDistance=minZoom
    LocalPlayer.CameraMaxZoomDistance=maxZoom
end

------------------------------------------------------
-- INFINITE JUMP
------------------------------------------------------
local function enableInfiniteJump()
    if InfiniteJumpEnabled then return end
    InfiniteJumpEnabled=true
    infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
        if InfiniteJumpEnabled then
            local h=getHumanoid()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
end

local function disableInfiniteJump()
    InfiniteJumpEnabled=false
    if infiniteJumpConn then infiniteJumpConn:Disconnect() infiniteJumpConn=nil end
end

------------------------------------------------------
-- NO CLIP
------------------------------------------------------
local VIP_PART_NAMES = {
    ["VIP"] = true,
    ["VIP_PLUS"] = true
}

local function isTargetVIPPart(v)
    return v:IsA("BasePart")
        and VIP_PART_NAMES[v.Name]
        and v.Parent
        and v.Parent.Name == "VIPWalls"
end

local function applyVIPNoClip(v)
    if isTargetVIPPart(v) then
        v.CanCollide = false
    end
end

local function enableSelectiveNoClip()
    if SelectiveNoClipEnabled then return end
    SelectiveNoClipEnabled = true

    -- scan awal (dynamic safe)
    for _,v in ipairs(Workspace:GetDescendants()) do
        applyVIPNoClip(v)
    end

    -- jaga kalau map berubah / respawn part
    vipNoClipConn = Workspace.DescendantAdded:Connect(function(v)
        if SelectiveNoClipEnabled then
            applyVIPNoClip(v)
        end
    end)
end

local function disableSelectiveNoClip()
    SelectiveNoClipEnabled = false

    if vipNoClipConn then
        vipNoClipConn:Disconnect()
        vipNoClipConn = nil
    end

    -- balikin collision normal
    for _,v in ipairs(Workspace:GetDescendants()) do
        if isTargetVIPPart(v) then
            v.CanCollide = true
        end
    end
end

local function applyVIPWallTouchBlock(v)
    if isTargetVIPPart(v) then
        v.CanTouch = false
    end
end

local function restoreVIPWallTouch(v)
    if isTargetVIPPart(v) then
        v.CanTouch = true
    end
end

local function enableVIPWallTouchBlock()
    -- scan awal
    for _,v in ipairs(Workspace:GetDescendants()) do
        applyVIPWallTouchBlock(v)
    end

    -- jaga kalau part baru muncul
    vipTouchBlockConn = Workspace.DescendantAdded:Connect(function(v)
        applyVIPWallTouchBlock(v)
    end)
end

local function disableVIPWallTouchBlock()
    if vipTouchBlockConn then
        vipTouchBlockConn:Disconnect()
        vipTouchBlockConn = nil
    end

    -- balikin CanTouch normal
    for _,v in ipairs(Workspace:GetDescendants()) do
        restoreVIPWallTouch(v)
    end
end

------------------------------------------------------
-- NO CLIP GLOBAL (TEMBUS SEMUA)
------------------------------------------------------

local function applyGlobalNoClip()
    local char = LocalPlayer.Character
    if not char then return end

    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = false
        end
    end
end

local function enableNoClip()
    if NoClipEnabled then return end
    NoClipEnabled = true

    noClipConn = RunService.Stepped:Connect(function()
        if NoClipEnabled then
            applyGlobalNoClip()
        end
    end)
end

local function disableNoClip()
    NoClipEnabled = false

    if noClipConn then
        noClipConn:Disconnect()
        noClipConn = nil
    end

    -- balikin collision normal
    local char = LocalPlayer.Character
    if not char then return end

    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = true
        end
    end
end

------------------------------------------------------
-- GAP SYSTEM (ASLI)
-- (keperluan auto-run & moveGap tetap dipertahankan)
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
    if isMovingGap then return end
    isMovingGap=true

    local hrp=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hum=getHumanoid()
    if not (hrp and hum) then isMovingGap=false return end

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
    isMovingGap=false
end

------------------------------------------------------
-- MANUAL OVERRIDE PATCH (FIX GAP UP/DOWN)
-- (manualMoveGap removed as requested)
------------------------------------------------------

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
        if AutoRunEnabled and not isMovingGap then
            local cur=nearestGap()
            if cur<TargetGapIndex and isPathClear(cur,cur+1) then
                moveGap(cur+1)
            end
        end
        task.wait(0.2)
    end
end)

--------------------------------------------------------------------------------
-- ===================== MERGE: PLATFORM BUILDER (from update.lua) =====================
-- Add: START_POS/END_POS, platform config, floor list, functions to move HRP,
-- create/destroy platform parts, auto-move / auto-collect brainrot, platform UI.
--------------------------------------------------------------------------------

-- STATIC START / END
local START_POS = Vector3.new(149.957, 3.561, -134.743)
local END_POS   = Vector3.new(5000.347, 3.561, -134.743)

-- CONFIG (platform builder)
local PLATFORM_THICKNESS = 2
local PLATFORM_WIDTH_Z  = 20
local PLATFORM_Y_OFFSET = -3

local WALL_THICKNESS     = 2
local WALL_HEIGHT        = 70
local WALL_IN_OUT_OFFSET = 3
local WALL_SAFE_DISTANCE = -3.5 -- ubah agar karakter lebih/kurang dekat ke wall

local MAX_PART_LENGTH = 2000

local TWEEN_SPEED = 400
local AUTO_MOVE_SPEED_MULT = 2.5
local AUTO_MOVE_MIN_DELAY = 0.03


-- TARGET MAP WALLS (for removeMapWalls)
local TARGET_RIGHT_WALLS = {
    RightWall1=true,RightWall2=true,RightWall3=true,
    RightWall4=true,RightWall5=true,RightWall6=true,RightWall7=true
}

-- Character helpers for platform builder (use existing LocalPlayer)
local function getCharacter()
    return LocalPlayer.Character
end

local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function getHumanoidSafe()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("Humanoid")
end

-- FLOOR UTIL
local function getBasePositionForFloor(floor)
    local targetZ =
        START_POS.Z
        - PLATFORM_WIDTH_Z/2
        - WALL_THICKNESS/2
        + WALL_IN_OUT_OFFSET
        - WALL_SAFE_DISTANCE

    return Vector3.new(floor.x, 0, targetZ)
end

local function getFloorIndexByX(x)
    local index = 1
    for i = 1, #Floors do
        if x >= Floors[i].x then
            index = i
        else
            break
        end
    end
    return index
end

local function getNextFloor(currentX)
    for i = 1, #Floors do
        if Floors[i].x > currentX then
            return Floors[i]
        end
    end
    return nil
end

local function getPrevFloor(currentX)
    for i = #Floors, 1, -1 do
        if Floors[i].x < currentX then
            return Floors[i]
        end
    end
    return nil
end

-- TWEEN MOVE (cancelable + keep Y)
local function cancelLastTween()
    if lastTween then
        pcall(function()
            lastTween:Cancel()
        end)
        lastTween = nil
    end
end


local function moveHRPToPosition(targetPosVec3, speedMultiplier)
    print("[DEBUG] moveHRPToPosition called with target:", targetPosVec3, "speed:", speedMultiplier)
    if not targetPosVec3 then 
        print("[DEBUG] targetPosVec3 is nil")
        return 
    end
    
    cancelLastTween()
    
    local hrp = getRoot()
    local hum = getHumanoid()
    
    print("[DEBUG] hrp:", hrp, "hum:", hum)
    -- Tambahkan di awal setiap iterasi loop


    local startPos = hrp.Position
    local targetPos = Vector3.new(targetPosVec3.X, startPos.Y, targetPosVec3.Z)
    print("[DEBUG] startPos:", startPos, "targetPos:", targetPos)

    local dist = (startPos - targetPos).Magnitude
    if dist < 1 then
        print("[DEBUG] distance too small, skipping tween")
        return
    end

    local speed = (TWEEN_SPEED * (speedMultiplier or 1))
    local time = math.clamp(dist / speed, 0.12, 2.0)
    print("[DEBUG] dist:", dist, "speed:", speed, "time:", time)

    -- Simpan state humanoid sebelumnya
    local previousState = hum:GetState()
    
    -- Gunakan Physics state untuk tween
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    
    local tweenInfo = TweenInfo.new(
        time,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out,
        0, -- repeatCount
        false, -- reverses
        0 -- delay
    )
    
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
    lastTween = tween
    
    local completed = false
    local connection
    connection = tween.Completed:Connect(function()
        completed = true
        if connection then connection:Disconnect() end
        print("[DEBUG] tween completed normally")
    end)
    
    tween:Play()
    print("[DEBUG] tween started")
    
    -- Wait dengan timeout yang lebih realistis
    local startTime = tick()
    local maxWaitTime = time + 2.0 -- Tambah buffer 2 detik
    
    while not completed and (tick() - startTime) < maxWaitTime do
        task.wait(0.05)
    end
    
    if not completed then
        print("[WARN] Tween timeout after", maxWaitTime, "seconds, canceling")
        if tween then
            pcall(function() tween:Cancel() end)
        end
    else
        print("[DEBUG] Tween finished successfully")
    end
    
    -- Cleanup
    if connection and connection.Connected then
        connection:Disconnect()
    end
    
    if lastTween == tween then lastTween = nil end
    
    -- Kembalikan ke state running
    hum:ChangeState(Enum.HumanoidStateType.Running)
    
    print("[DEBUG] moveHRPToPosition finished")
end

local function tweenToFloor(floor, isAutoMove)
    if not floor then 
        print("[ERROR] tweenToFloor: floor is nil")
        return 
    end
    
    if not floor.name then
        print("[ERROR] tweenToFloor: floor.name is nil")
        return
    end
    
    -- Safety check: pastikan karakter ada
    local hrp = getRoot()
    if not hrp then
        print("[WARN] tweenToFloor: No HRP found, skipping tween")
        return
    end
    
    -- Cek jika karakter sedang mati
    local hum = getHumanoid()
    if hum and hum.Health <= 0 then
        print("[WARN] tweenToFloor: Character is dead, skipping tween")
        return
    end
    
    local speedMult = isAutoMove and AUTO_MOVE_SPEED_MULT or 1

    local targetZ =
        START_POS.Z
        - PLATFORM_WIDTH_Z/2
        - WALL_THICKNESS/2
        + WALL_IN_OUT_OFFSET
        - WALL_SAFE_DISTANCE

    local targetPos = Vector3.new(floor.x, 0, targetZ)
    
    print("[DEBUG] tweenToFloor: Moving to", floor.name, "at", targetPos)
    
    -- Gunakan pcall untuk handle error
    local success, err = pcall(function()
        moveHRPToPosition(targetPos, speedMult)
    end)
    
    if not success then
        print("[ERROR] tweenToFloor failed:", err)
        WindUI:Notify({
            Title = "Tween Error",
            Content = "Gagal berpindah ke " .. floor.name,
            Duration = 2
        })
    end
end

-- UTIL: parts create / destroy
local function destroyList(t)
    for _,v in ipairs(t) do
        if v and v.Parent then
            pcall(function() v:Destroy() end)
        end
    end
end

local function clearClientParts()
    destroyList(platformParts)
    destroyList(wallParts)
    platformParts = {}
    wallParts = {}
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

--scanner brainrot
local function scanActiveBrainrots()
    brainrotCache = {}  -- Gunakan huruf kecil konsisten
    local ActiveBrainrots = workspace:WaitForChild("ActiveBrainrots")
    
    for _, rarityFolder in ipairs(ActiveBrainrots:GetChildren()) do
        if not rarityFolder:IsA("Folder") then continue end
        
        local rarityName = rarityFolder.Name
        brainrotCache[rarityName] = {}
        
        for _, brainrotModel in ipairs(rarityFolder:GetChildren()) do
            if brainrotModel:IsA("Model") and brainrotModel.Name == "RenderedBrainrot" then
                local pivot = brainrotModel:GetPivot()
                local pos = pivot.Position
                local name = brainrotModel:GetAttribute("BrainrotName") or brainrotModel.Name
                local level = brainrotModel:GetAttribute("Level") or 0
                
                table.insert(brainrotCache[rarityName], {
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

-- BRAINROT SCANNER & COLLECTOR (from update.lua)
local promptOriginalHold_PB = promptOriginalHold or {}

local function applyInstantGrab_PB(p)
    if not p then return end
    if p:IsA("ProximityPrompt") then
        if not promptOriginalHold_PB[p] then
            promptOriginalHold_PB[p] = p.HoldDuration
        end
        p.HoldDuration = 0
    end
end

local function restorePrompts_PB()
    for p, d in pairs(promptOriginalHold_PB) do
        if p and p.Parent then
            p.HoldDuration = d
        end
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
    if not hrpSafe then
        -- fallback to getRoot
        hrpSafe = getRoot()
        if not hrpSafe then return result end
    end

    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Model") and obj.Name == "RenderedBrainrot" then
            local rootPart = obj:FindFirstChild("Root") or obj:FindFirstChildWhichIsA("BasePart")
            if rootPart then
                table.insert(result, { model = obj, dist = (rootPart.Position - hrpSafe.Position).Magnitude })
            end
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

    local rootPart =
        brainrotModel:FindFirstChild("Root")
        or brainrotModel:FindFirstChildWhichIsA("BasePart")

    if not rootPart then return end

    -- 1) samperin brainrot
    moveHRPToPosition(
        Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z),
        AUTO_MOVE_SPEED_MULT
    )
    task.wait(0.08)

    -- 2) instant grab + take
    for _, d in ipairs(brainrotModel:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            applyInstantGrab_PB(d)
            firePromptSafe(d)
            task.wait(0.03)
        end
    end

    -- 3) BALIK KE BASE FLOOR (tembok buatan)
    local basePos = getBasePositionForFloor(targetFloor)
    moveHRPToPosition(basePos, AUTO_MOVE_SPEED_MULT)
    task.wait(0.08)
end

-- AUTO-MOVE (1 per 1 floor toward target index)
local function stopAutoMove()
    autoMoveEnabled = false
    if autoMoveTask then
        task.cancel(autoMoveTask)
        autoMoveTask = nil
    end
    cancelLastTween()
end

local function moveThroughFloorsTo(targetIndex)
    print("[DEBUG] moveThroughFloorsTo called with targetIndex:", targetIndex)
    
    local hrp = getRoot()
    if not hrp then 
        print("[DEBUG] No HRP found")
        return false 
    end
    
    local currentX = hrp.Position.X
    local currentIndex = getFloorIndexByX(currentX) or 1
    print("[DEBUG] Current position - X:", currentX, "Index:", currentIndex)
    
    if currentIndex == targetIndex then
        print("[DEBUG] Already at target floor", targetIndex)
        return true
    end
    
    print("[DEBUG] Starting movement from floor", currentIndex, "to", targetIndex)
    print("[DEBUG] moveThroughFloorsTo called with targetIndex:", targetIndex)
    
    local hrp = getRoot()
    if not hrp then 
        print("[DEBUG] hrp is nil, waiting for character...")
        waitCharacterReady()
        hrp = getRoot()
        if not hrp then
            print("[ERROR] Cannot get HRP after waiting")
            return false
        end
    end

    local currentX = hrp.Position.X
    local currentIndex = getFloorIndexByX(currentX) or 1
    print("[DEBUG] currentIndex:", currentIndex, "targetIndex:", targetIndex, "currentX:", currentX)

    if currentIndex == targetIndex then
        print("[DEBUG] Already at target floor")
        return true
    end

    local attempts = 0
    while currentIndex ~= targetIndex and attempts < 20 do
        attempts = attempts + 1
        
        if currentIndex < targetIndex then
            currentIndex = currentIndex + 1
        else
            currentIndex = currentIndex - 1
        end

        local floor = Floors[currentIndex]
        if not floor then 
            print("[DEBUG] floor not found for index:", currentIndex)
            break 
        end

        print("[DEBUG] Attempt", attempts, "- tweening to floor:", floor.name, "(index:", currentIndex, ")")
        
        -- Coba tween dengan retry mechanism
        local tweenSuccess = false
        for retry = 1, 2 do
            if retry > 1 then
                print("[DEBUG] Retry", retry, "for floor:", floor.name)
            end
            
            tweenToFloor(floor, true)
            
            -- Tunggu sedikit untuk melihat apakah tween bekerja
            task.wait(0.1)
            
            -- Periksa apakah karakter masih ada
            local newHrp = getRoot()
            if not newHrp then
                print("[DEBUG] HRP lost during tween")
                break
            end
            
            -- Periksa apakah kita sudah bergerak
            local newX = newHrp.Position.X
            local movedDistance = math.abs(newX - currentX)
            
            if movedDistance > 10 then -- Jika bergerak lebih dari 10 studs
                tweenSuccess = true
                currentX = newX
                break
            else
                print("[DEBUG] Movement too small (", movedDistance, "studs), retrying...")
            end
        end
        
        if not tweenSuccess then
            print("[WARN] Failed to move to floor:", floor.name)
            return false
        end
        
        task.wait(AUTO_MOVE_MIN_DELAY)
        
        -- Update HRP untuk iterasi berikutnya
        hrp = getRoot()
        if not hrp then
            print("[DEBUG] HRP lost after tween")
            return false
        end
        
        currentX = hrp.Position.X
        currentIndex = getFloorIndexByX(currentX) or currentIndex
        
        print("[DEBUG] After tween - currentIndex:", currentIndex, "currentX:", currentX)
    end

    local finalIndex = getFloorIndexByX(hrp.Position.X) or currentIndex
    local success = (finalIndex == targetIndex)
    
    print("[DEBUG] moveThroughFloorsTo completed. Success:", success, "Final index:", finalIndex)
    return success
end


local function startAutoMoveToTarget(targetIndex)
    if autoMoveTask then return end
    autoMoveTask = task.spawn(function()
        if autoMoveEnabled then
            local hrp = getRoot()
            if hrp and getFloorIndexByX(hrp.Position.X) ~= 1 then
                moveThroughFloorsTo(1)
            end
        end

        while autoMoveEnabled do
            local hrp = nil
            pcall(function() hrp = getHRP() end)
            if not hrp then
                hrp = getRoot()
            end

            local currentIndex = hrp and getFloorIndexByX(hrp.Position.X) or 1

            if currentIndex == targetIndex then
                autoMoveEnabled = false
                break
            end

            local nextIndex
            if currentIndex < targetIndex then
                nextIndex = currentIndex + 1
            else
                nextIndex = currentIndex - 1
            end

            local nextFloor = Floors[nextIndex]
            if not nextFloor then
                autoMoveEnabled = false
                break
            end

            tweenToFloor(nextFloor, true)
            task.wait(AUTO_MOVE_MIN_DELAY)
        end

        autoMoveTask = nil
    end)
end

-- AUTO-COLLECT BRAINROT
local function stopAutoCollect()
    autoCollectEnabled = false
    if autoCollectTask then
        task.cancel(autoCollectTask)
        autoCollectTask = nil
    end
    cancelLastTween()
    restorePrompts_PB()
end

local function startRealtimeScanner()
    if scannerEnabled then return end
    scannerEnabled = true
    
    scannerTask = task.spawn(function()
        while scannerEnabled do
            -- Clear cache lama
            brainrotCache = {}
            
            -- Scan ActiveBrainrots
            local ActiveBrainrots = workspace:FindFirstChild("ActiveBrainrots")
            if ActiveBrainrots then
                for _, rarityFolder in ipairs(ActiveBrainrots:GetChildren()) do
                    if not rarityFolder:IsA("Folder") then continue end
                    
                    local rarityName = rarityFolder.Name
                    brainrotCache[rarityName] = {}
                    
                    for _, brainrotModel in ipairs(rarityFolder:GetChildren()) do
                        if brainrotModel:IsA("Model") and brainrotModel.Name == "RenderedBrainrot" then
                            local pivot = brainrotModel:GetPivot()
                            local pos = pivot.Position
                            local name = brainrotModel:GetAttribute("BrainrotName") or brainrotModel.Name
                            local level = brainrotModel:GetAttribute("Level") or 0
                            
                            table.insert(brainrotCache[rarityName], {
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
            
            task.wait(0.3) -- Update setiap 0.3 detik
        end
    end)
end

local function stopRealtimeScanner()
    scannerEnabled = false
    if scannerTask then
        task.cancel(scannerTask)
        scannerTask = nil
    end
    brainrotCache = {} -- Clear cache
end

-- GANTI fungsi startAutoCollectBrainrotByRarity di line 858-928 dengan ini:
local function startAutoCollectBrainrotByRarity()
    -- Safety check: pastikan karakter ready
    if not getRoot() then
        print("[WARN] No character found, waiting...")
        waitCharacterReady()
        task.wait(0.8)
    end
    
    -- Pastikan scanner hidup
    if not scannerEnabled then
        print("[INFO] Starting scanner for auto collect brainrot...")
        startRealtimeScanner()
        task.wait(0.3)  -- Tunggu scanner pertama
    end
    
    -- Start main loop
    autoCollectTask = task.spawn(function()
        print("[INFO] Auto collect brainrot loop started")
        
        while autoCollectEnabled do
            -- 1. Kumpulkan brainrot dari rarity terpilih
            local targetBrainrots = {}
            for rarity, isSelected in pairs(selectedRarities) do
                if isSelected and brainrotCache[rarity] then
                    for _, brainrotData in ipairs(brainrotCache[rarity]) do
                        table.insert(targetBrainrots, brainrotData)
                    end
                end
            end
            
            -- 2. URUTKAN BERDASARKAN PRIORITAS
            targetBrainrots = sortBrainrotsByPriority(targetBrainrots)
            
            -- 3. Jika tidak ada brainrot, tunggu dan continue
            if #targetBrainrots == 0 then
                task.wait(0.5)
                continue
            end
            
            -- 4. Ambil N brainrot sesuai BRAINROT_PICK_COUNT
            local collected = 0
            for _, brainrotData in ipairs(targetBrainrots) do
                if collected >= BRAINROT_PICK_COUNT then break end
                if not autoCollectEnabled then break end
                
                -- Validasi brainrot masih ada
                if not brainrotData.model or not brainrotData.model.Parent then
                    continue
                end
                
                -- Safety check: pastikan karakter masih hidup
                local hum = getHumanoid()
                if hum and hum.Health <= 0 then
                    print("[WARN] Character died during collection, stopping loop")
                    break
                end
                
                -- ALUR UTAMA
                -- a. Ke SAFE AREA sejajar X brainrot
                local safePos = Vector3.new(
                    brainrotData.position.X, 
                    START_POS.Y + PLATFORM_Y_OFFSET, 
                    START_POS.Z - PLATFORM_WIDTH_Z/2 - WALL_THICKNESS/2 + WALL_IN_OUT_OFFSET - WALL_SAFE_DISTANCE
                )
                
                tweenToFloor(Floors[1], true)
                task.wait(0.1)
                
                moveHRPToPosition(safePos, AUTO_MOVE_SPEED_MULT)
                task.wait(0.08)
                
                -- b. Ke POSISI BRAINROT
                local brainrotPos = Vector3.new(
                    brainrotData.position.X,
                    0,
                    brainrotData.position.Z
                )
                
                moveHRPToPosition(brainrotPos, AUTO_MOVE_SPEED_MULT)
                task.wait(0.08)
                
                -- c. AMBIL BRAINROT
                for _, prompt in ipairs(brainrotData.model:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        applyInstantGrab(prompt)
                        firePromptSafe(prompt)
                        task.wait(0.03)
                    end
                end
                
                -- d. Kembali ke SAFE AREA
                moveHRPToPosition(safePos, AUTO_MOVE_SPEED_MULT)
                task.wait(0.08)
                
                collected = collected + 1
                
                -- e. Kembali ke START
                tweenToFloor(Floors[1], true)
                task.wait(0.15)
            end
            
            -- 5. Tunggu sebelum loop berikutnya
            task.wait(0.5)
        end
        
        -- Cleanup setelah loop selesai
        autoCollectTask = nil
        restorePrompts()
        print("[INFO] Auto collect brainrot loop stopped")
    end)
end

-- GANTI fungsi stopAllAutoCollect di line 935-989 dengan ini:
local function stopAllAutoCollect()
    -- Jika sudah dimatikan, skip
    if not autoCollectEnabled and not scannerEnabled then
        return
    end
    
    print("[STOP] Stopping all auto collect systems...")
    
    -- 1. Hentikan auto collect task
    if autoCollectTask then
        task.cancel(autoCollectTask)
        autoCollectTask = nil
    end
    
    -- 2. Hentikan semua tween aktif
    cancelLastTween()
    
    -- 3. Kembalikan prompt ke normal
    restorePrompts()
    
    -- 4. Kembalikan kontrol karakter
    local hum = getHumanoid()
    if hum then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
    
    -- 5. Hentikan scanner REAL (tapi jangan clear cache)
    stopRealtimeScanner()
    
    -- 6. Reset semua pending restart
    pendingRestartCollect = false
    pendingRestartCollectRarity = false
    
    -- 7. HANYA clear cache jika benar-benar perlu
    brainrotCache = {}
    
    -- 8. Notify user
    WindUI:Notify({
        Title = "Auto Collect Dimatikan",
        Content = "Scanner dan semua movement dihentikan",
        Duration = 2
    })
    
    print("[SYSTEM] All auto collect systems stopped (manual stop)")
end

local function startAutoCollectBrainrot(targetFloorIndex)
    if autoCollectTask then return end
    autoCollectTask = task.spawn(function()
        local targetFloor = Floors[targetFloorIndex]
        if not targetFloor then
            autoCollectEnabled = false
            autoCollectTask = nil
            return
        end

        while autoCollectEnabled do
            tweenToFloor(Floors[1], true)
            task.wait(0.2)

            tweenToFloor(targetFloor, true)
            task.wait(0.15)

            local brainrots = getBrainrotsInFloor(targetFloor.name)

            if #brainrots > 0 then
                local toTake = math.min(#brainrots, math.max(1, math.floor(BRAINROT_PICK_COUNT)))
                for i = 1, toTake do
                    if not autoCollectEnabled then break end
                    local b = brainrots[i]
                    if b then
                        collectBrainrot(b, targetFloor)
                        task.wait(0.12)
                    end
                end
            end

            tweenToFloor(Floors[1], true)
            task.wait(0.18)
        end

        autoCollectTask = nil
        restorePrompts_PB()
    end)
end

-- Lucky Block watcher (dynamic queue)
local ActiveLuckyBlocks = Workspace:FindFirstChild("ActiveLuckyBlocks")

local luckyWatcherConnAdded, luckyWatcherConnRemoved, workspaceChildAddedConn = nil, nil, nil

local function enqueueExistingLuckyBlocks()
    local root = Workspace:FindFirstChild("ActiveLuckyBlocks")
    if not root then 
        print("[DEBUG] ActiveLuckyBlocks not found")
        return 
    end

    print("[DEBUG] Scanning existing lucky blocks...")
    for _, lb in ipairs(root:GetChildren()) do
        if lb and lb.Parent and not LuckyBlockSeen[lb] then
            local ok, pivot = pcall(function() return lb:GetPivot() end)
            if ok and pivot then
                local blockType = safeGetAttr(lb, "LuckyBlockType")
                local spawnedFloor = trim(safeGetAttr(lb, "SpawnedFloor") or "")
                
                -- HAPUS: Jika dropdown kosong, tidak ada yang dipilih, jangan masukkan.
                -- if next(LuckyBlockTargets) == nil then
                --     return
                -- end

                if blockType and LuckyBlockTargets[blockType] then
                    LuckyBlockSeen[lb] = true
                    table.insert(LuckyBlockQueue, {
                        model = lb,
                        pos = pivot.Position,
                        spawnedFloor = spawnedFloor,
                        blockType = blockType
                    })
                    print("[DEBUG] Enqueued existing block:", blockType, "at floor:", spawnedFloor)
                end
            end
        end
    end
    print("[DEBUG] Total blocks enqueued:", #LuckyBlockQueue)
end

local function attachActiveLuckyBlocksWatcher()
    local active = Workspace:FindFirstChild("ActiveLuckyBlocks")
    if not active then
        if workspaceChildAddedConn then return end
        workspaceChildAddedConn = Workspace.ChildAdded:Connect(function(c)
            if c and c.Name == "ActiveLuckyBlocks" then
                if DEBUG_LUCKY then print("[LuckyWatcher] ActiveLuckyBlocks created -> attaching") end
                attachActiveLuckyBlocksWatcher()
                if workspaceChildAddedConn then workspaceChildAddedConn:Disconnect() workspaceChildAddedConn = nil end
            end
        end)
        if DEBUG_LUCKY then print("[LuckyWatcher] waiting for ActiveLuckyBlocks...") end
        return
    end

    if luckyWatcherConnAdded then return end

    luckyWatcherConnAdded = active.ChildAdded:Connect(function(lb)
        task.wait(0.08) -- beri waktu attributes
        if not autoCollectBlockEnabled then return end
        if not lb or not lb.Parent then return end
        if LuckyBlockSeen[lb] then return end

        local ok, pivot = pcall(function() return lb:GetPivot() end)
        if not ok or not pivot then return end

        local blockType = safeGetAttr(lb, "LuckyBlockType")
        local spawnedFloor = tostring(safeGetAttr(lb, "SpawnedFloor") or "")
        
        -- Jika dropdown kosong, berarti tidak ada yang dipilih, maka jangan masukkan.
        if next(LuckyBlockTargets) == nil then
            return
        end

        -- Cek apakah blockType ada dalam LuckyBlockTargets
        if blockType and LuckyBlockTargets[blockType] then
            LuckyBlockSeen[lb] = true
            table.insert(LuckyBlockQueue, {
                model = lb,
                pos = pivot.Position,
                spawnedFloor = trim(spawnedFloor),
                blockType = blockType
            })
            if DEBUG_LUCKY then
                print("[LuckyWatcher] queued new luckyblock:", tostring(lb), "type=", blockType, "spawnedFloor=", spawnedFloor)
            end
        else
            if DEBUG_LUCKY then
                print("[LuckyWatcher] new luckyblock ignored:", tostring(lb), "type=", blockType, "spawnedFloor=", spawnedFloor)
            end
        end
    end)

    luckyWatcherConnRemoved = active.ChildRemoved:Connect(function(lb)
        LuckyBlockSeen[lb] = nil
        for i = #LuckyBlockQueue, 1, -1 do
            local it = LuckyBlockQueue[i]
            if it and it.model == lb then
                table.remove(LuckyBlockQueue, i)
            end
        end
    end)

    if DEBUG_LUCKY then print("[LuckyWatcher] attached to ActiveLuckyBlocks") end
end

-- start watcher immediately
attachActiveLuckyBlocksWatcher()

-- start / stop auto collect lucky block
local function stopAutoCollectLuckyBlock()
    autoCollectBlockEnabled = false
    if autoCollectBlockTask then
        task.cancel(autoCollectBlockTask)
        autoCollectBlockTask = nil
    end
    -- restore prompts if used
    restorePrompts_PB()
    cancelLastTween()
end

-- start / stop auto collect lucky block (REPLACEMENT)
local function startAutoCollectLuckyBlock()
    if autoCollectBlockTask then return end

    autoCollectBlockTask = task.spawn(function()
        print("[DEBUG] Auto Collect Lucky Block started")
        
        -- Pastikan Floors ada
        if not Floors then
            print("[ERROR] Floors table not found! Cannot continue.")
            autoCollectBlockEnabled = false
            return
        end
        
        print("[DEBUG] Available floors:")
        for i, f in ipairs(Floors) do
            print(string.format("[DEBUG]   %d: %s (x: %.1f)", i, f.name, f.x))
        end
        
        -- Pastikan platform builder aktif
        if not platformEnabled then
            print("[WARN] Platform builder is not enabled! Enabling now...")
            platformEnabled = true
            enablePlatform()
            task.wait(1) -- Beri waktu untuk platform dibangun
        end
        
        while autoCollectBlockEnabled do
            -- Pastikan karakter ada
            if not getRoot() then
                print("[DEBUG] No character, waiting...")
                waitCharacterReady()
                task.wait(0.5)
                continue
            end
            
            -- Pastikan kita ada di start (floor 1) sebelum memulai
            print("[DEBUG] Moving to floor 1")
            if not Floors[1] then
                print("[ERROR] Floors[1] not found!")
                task.wait(1)
                continue
            end
            
            tweenToFloor(Floors[1], true)
            task.wait(0.2)

            -- Ambil block dari queue
            local blockData = nil
            if #LuckyBlockQueue > 0 then
                blockData = table.remove(LuckyBlockQueue, 1)
                print("[DEBUG] Found block in queue:", blockData and blockData.blockType)
            end

            if not blockData then
                print("[DEBUG] No blocks in queue, waiting...")
                task.wait(1)
                continue
            end

            local lb = blockData.model
            local pos = blockData.pos
            local spawnedFloorName = blockData.spawnedFloor
            local blockType = blockData.blockType

            print("[DEBUG] Processing block:", blockType, "| Floor attribute:", spawnedFloorName)

            -- Validasi block masih ada
            if not lb or not lb.Parent then
                print("[DEBUG] Block no longer exists, skipping")
                continue
            end

            -- Tentukan floor index - gunakan posisi X langsung jika nama gagal
            local floorIndex = nil
            
            -- Coba cari berdasarkan nama terlebih dahulu
            if spawnedFloorName and #spawnedFloorName > 0 then
                floorIndex = getFloorIndexByName(spawnedFloorName)
            end
            
            -- Jika tidak ditemukan berdasarkan nama, gunakan posisi X
            if not floorIndex then
                floorIndex = getFloorIndexByPosition(pos.X)
                print("[DEBUG] Using position-based floor:", floorIndex, "| Pos X:", pos.X)
            end

            -- Validasi floor index
            if not floorIndex or floorIndex < 1 or floorIndex > #Floors then
                print("[WARN] Invalid floor index:", floorIndex, "| Skipping block")
                continue
            end

            local targetFloor = Floors[floorIndex]
            if not targetFloor then
                print("[WARN] Invalid floor at index:", floorIndex)
                continue
            end

            print("[DEBUG] Moving to floor:", floorIndex, "(", targetFloor.name, ")")
            
            -- Pergi ke target floor
            tweenToFloor(targetFloor, true)
            task.wait(0.15)

            -- Validasi karakter
            local hrp = getRoot()
            if not hrp then
                print("[WARN] HRP lost, requeuing block")
                table.insert(LuckyBlockQueue, blockData)
                task.wait(1)
                continue
            end

            -- Pergi ke posisi lucky block
            print("[DEBUG] Moving to block position:", pos)
            moveHRPToPosition(Vector3.new(pos.X, 0, pos.Z), AUTO_MOVE_SPEED_MULT)
            task.wait(0.08)

            -- Ambil lucky block
            print("[DEBUG] Collecting block...")
            local collected = false
            for _, d in ipairs(lb:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    applyInstantGrab_PB(d)
                    firePromptSafe(d)
                    collected = true
                    task.wait(0.03)
                end
            end
            
            if collected then
                print("[DEBUG] Block collected successfully")
            else
                print("[WARN] No proximity prompt found on block")
            end

            -- Kembali ke safe area
            print("[DEBUG] Returning to safe area")
            local backSafe = getBasePositionForFloor(targetFloor)
            moveHRPToPosition(backSafe, AUTO_MOVE_SPEED_MULT)
            task.wait(0.12)

            -- Kembali ke start
            print("[DEBUG] Returning to start")
            tweenToFloor(Floors[1], true)
            task.wait(0.18)
            
            print("[DEBUG] Block collection cycle completed")
        end

        -- Cleanup
        print("[DEBUG] Auto Collect Lucky Block stopped")
        autoCollectBlockTask = nil
        restorePrompts_PB()
    end)
end

-- MAP WALL REMOVE / BUILD PLATFORM
local function removeMapWalls()
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and (
            (v.Name=="Wall" and v.Parent and v.Parent.Name=="Walls")
            or (TARGET_RIGHT_WALLS[v.Name] and v.Parent and v.Parent.Name=="RightWalls")
        ) then
            pcall(function() v:Destroy() end)
        end
    end
end

local function buildPlatform()
    clearClientParts()

    local length = math.max(END_POS.X - START_POS.X, 1)
    local cursor = START_POS.X
    local remain = length

    local baseY = START_POS.Y + PLATFORM_Y_OFFSET
    local baseZ = START_POS.Z

    while remain > 0 do
        local seg = math.min(remain, MAX_PART_LENGTH)
        local center = cursor + seg/2

        table.insert(platformParts, createPart({
            Size = Vector3.new(seg, PLATFORM_THICKNESS, PLATFORM_WIDTH_Z),
            CFrame = CFrame.new(center, baseY - PLATFORM_THICKNESS/2, baseZ),
            Transparency = 0.25
        }))

        table.insert(wallParts, createPart({
            Size = Vector3.new(seg, WALL_HEIGHT, WALL_THICKNESS),
            CFrame = CFrame.new(
                center,
                baseY + WALL_HEIGHT/2,
                baseZ - PLATFORM_WIDTH_Z/2 - WALL_THICKNESS/2 + WALL_IN_OUT_OFFSET
            ),
            Transparency = 0.15
        }))

        cursor = cursor + seg
        remain = remain - seg
    end
end

local function removePartsAbovePlatform()
    local topY = START_POS.Y + PLATFORM_Y_OFFSET + PLATFORM_THICKNESS
    local minX = math.min(START_POS.X, END_POS.X)
    local maxX = math.max(START_POS.X, END_POS.X)
    local zPad = PLATFORM_WIDTH_Z/2 + 10

    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            if table.find(platformParts,v) or table.find(wallParts,v) then continue end
            local p = v.Position
            if p.X>=minX and p.X<=maxX
            and math.abs(p.Z-START_POS.Z)<=zPad
            and p.Y>topY then
                pcall(function() v:Destroy() end)
            end
        end
    end
end

-- VIP BYPASS (platform builder version uses same enableVIP/disableVIP)
local vipEnabled_PB = false
local function enableVIP_PB()
    if vipEnabled_PB then return end
    vipEnabled_PB=true

    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name=="VIP" or v.Name=="VIP_PLUS") and v.Parent and v.Parent.Name=="VIPWalls" then
            v.CanCollide=false
            v.CanTouch=false
        end
    end
end

local function disableVIP_PB()
    vipEnabled_PB=false
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name=="VIP" or v.Name=="VIP_PLUS") and v.Parent and v.Parent.Name=="VIPWalls" then
            v.CanCollide=true
            v.CanTouch=true
        end
    end
end

-- PLATFORM CONTROL
local function enablePlatform()
    -- Validasi: pastikan karakter ready
    if not getRoot() then
        print("[ERROR] enablePlatform: No character found")
        return
    end
    
    -- Clear existing parts first
    clearClientParts()
    
    -- Bangun platform baru
    removeMapWalls()
    buildPlatform()
    removePartsAbovePlatform()
    enableVIP_PB()
    
    print("[PLATFORM] Platform enabled successfully")
end

local function disablePlatform()
    clearClientParts()
    disableVIP_PB()
end

-- RESPAWN / TWEEN CANCEL HANDLING (platform builder)
local function onCharacterDied_PB()
    -- Cek apakah ini death yang legitimate atau force death
    local isForceDeath = platformBooting
    
    cancelLastTween()
    
    -- HANYA SIMPAN STATE, TAPI JANGAN HENTIKAN SISTEM SELAMANYA!
    pendingRestartMove = autoMoveEnabled
    pendingRestartCollectRarity = autoCollectEnabled  -- Simpan state untuk restart nanti
    pendingRestartCollect = autoCollectEnabled
    pendingRestartCollectBlock = autoCollectBlockEnabled
    
    -- Hentikan TWEEN SAJA, tapi JANGAN hentikan scanner atau auto collect flags!
    cancelLastTween()
    
    -- Hentikan TASK TWEEN saja, tapi biarkan flags tetap true untuk restart
    if autoMoveTask then
        task.cancel(autoMoveTask)
        autoMoveTask = nil
    end
    
    if autoCollectTask then
        task.cancel(autoCollectTask)
        autoCollectTask = nil
    end
    
    if autoCollectBlockTask then
        task.cancel(autoCollectBlockTask)
        autoCollectBlockTask = nil
    end
    
    print("[DEATH] Character died. Saved states for restart.")
    print("[DEATH] autoCollectEnabled was:", autoCollectEnabled)
    print("[DEATH] pendingRestartCollectRarity:", pendingRestartCollectRarity)
end

-- GANTI fungsi onCharacterAdded_PB di line 1159-1228 dengan ini:
local function onCharacterAdded_PB(char)
    -- Disconnect old death connection
    if humanoidDiedConn then
        pcall(function() humanoidDiedConn:Disconnect() end)
        humanoidDiedConn = nil
    end

    -- Wait for character components
    local hum = char:WaitForChild("Humanoid", 6)
    local hrp = char:WaitForChild("HumanoidRootPart", 6)

    -- Setup death listener
    if hum then
        humanoidDiedConn = hum.Died:Connect(function()
            onCharacterDied_PB()
        end)
    end

    -- Tunggu untuk pastikan karakter stabil
    task.wait(1.5)
    
    -- RESTART LOGIC SETELAH RESPAWN:
    print("[RESPAWN] Character respawned. Checking pending restarts...")
    print("[RESPAWN] pendingRestartCollectRarity:", pendingRestartCollectRarity)
    print("[RESPAWN] autoCollectEnabled before restart:", autoCollectEnabled)
    
    -- 1. Restart Auto Move (floor-based)
    if pendingRestartMove then
        pendingRestartMove = false
        autoMoveEnabled = true
        startAutoMoveToTarget(selectedFloorIndex or 1)
        print("[RESPAWN] Auto Move restarted")
    end
    
    -- 2. Restart Auto Collect Brainrot (RARITY-BASED) - PRIORITAS UTAMA
    if pendingRestartCollectRarity then
        pendingRestartCollectRarity = false
        
        -- Validasi sebelum restart
        if next(selectedRarities) == nil then
            WindUI:Notify({
                Title = "Restart Failed",
                Content = "No rarity selected. Auto Collect Brainrot stopped.",
                Duration = 3
            })
            autoCollectEnabled = false  -- Matikan kalau tidak ada rarity
        elseif not platformEnabled then
            WindUI:Notify({
                Title = "Restart Failed",
                Content = "Platform builder not active. Auto Collect Brainrot stopped.",
                Duration = 3
            })
            autoCollectEnabled = false  -- Matikan kalau platform tidak aktif
        else
            -- SET FLAG TRUE DAN START ULANG
            autoCollectEnabled = true
            startAutoCollectBrainrotByRarity()
            WindUI:Notify({
                Title = "Auto Collect Restarted",
                Content = "Brainrot collection resumed after respawn.",
                Duration = 2
            })
            print("[RESPAWN] Auto Collect Brainrot (Rarity) restarted")
        end
    end
    
    -- 3. Restart Auto Collect Lucky Block
    if pendingRestartCollectBlock then
        pendingRestartCollectBlock = false
        autoCollectBlockEnabled = true
        
        -- Pastikan platform aktif
        if not platformEnabled then
            platformEnabled = true
            enablePlatform()
            task.wait(1)
        end
        
        enqueueExistingLuckyBlocks()
        startAutoCollectLuckyBlock()
        print("[RESPAWN] Auto Collect Lucky Block restarted")
    end
    
    -- 4. Restart Scanner jika auto collect masih aktif
    if autoCollectEnabled and not scannerEnabled then
        startRealtimeScanner()
        print("[RESPAWN] Scanner restarted")
    end
    
    -- Reset tween state
    isTweening = false
    hardResetOnRespawn = false
end

if LocalPlayer.Character then
    onCharacterAdded_PB(LocalPlayer.Character)
end
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

    -- 1. equip tool
    pcall(function()
        hum:EquipTool(tool)
    end)
    task.wait(0.15)

    -- 2. ACTIVATE TOOL (INI KUNCI UTAMA)
    pcall(function()
        tool:Activate()
    end)
    task.wait(0.15)

    -- 3. optional: fire remote (amanin semua game logic)
    local openRemote =
        ReplicatedStorage
        :WaitForChild("Packages")
        :WaitForChild("Net")
        :FindFirstChild("RE/OpenLuckyBlock")

    if openRemote then
        pcall(function()
            openRemote:FireServer()
        end)
    end

    return true
end


--------------------------------------------------------------------------------
-- ===================== END MERGE: PLATFORM BUILDER ============================
--------------------------------------------------------------------------------

------------------------------------------------------
-- UI WINDOW (MAIN Hub)
------------------------------------------------------
local Window = WindUI:CreateWindow({
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
        Color = ColorSequence.new(
            Color3.fromHex("FF0F7B"),
            Color3.fromHex("F89B29")
        ),
        OnlyMobile = false,
        Enabled = true,
        Draggable = true,
    }
})

------------------------------------------------------
-- INFORMATION TAB
------------------------------------------------------
local infoTab=Window:Tab({Title="Information",Icon="info"})
infoTab:Paragraph({Title="Welcome To HexaCore Hub Official",Desc="Youtube Official : Hexacore-OFFICIAL"})
infoTab:Button({Title="Copy Discord Link",Callback=function()
    if setclipboard then setclipboard("https://discord.gg/Wcfqwy6Mdn") end
end})
infoTab:Keybind({Title="HexaCore Keybind",Value="p",Callback=function(v)
    Window:SetToggleKey(Enum.KeyCode[v])
end})

------------------------------------------------------
-- MAIN TAB
------------------------------------------------------
local MainTab=Window:Tab({Title="Main",Icon="settings-2"})
MainTab:Section({ Title = "Automation" })
MainTab:Toggle({Title="Auto Collect",Callback=function(v)AutoCollect=v SnapshotUUIDsOnce()end})
MainTab:Toggle({Title="Auto Upgrade",Callback=function(v)AutoUpgrade=v SnapshotUUIDsOnce()end})
MainTab:Toggle({Title="Auto Buy Speed",Callback=function(v)AutoBuySpeed=v end})
MainTab:Toggle({Title="Auto Rebirth",Callback=function(v)AutoRebirth=v end})
MainTab:Toggle({Title="Auto Buy Carry",Callback=function(v)AutoBuyCarry=v end})
MainTab:Toggle({
    Title = "No Clip (Tembus Semua)",
    Callback = function(v)
        if v then
            enableNoClip()
        else
            disableNoClip()
        end
    end
})

------------------------------------------------------
-- RUN TAB
-- We restore Premium Bypass here, and put Platform Builder UI (from update.lua) under it
------------------------------------------------------
local RunTab=Window:Tab({Title="Run",Icon="activity"})
RunTab:Section({ Title = "Premium Bypass" })
RunTab:Toggle({
    Title = "Bypass VIP",
    Callback = function(v)
        if v then
            enableSelectiveNoClip()        -- CanCollide = false
            enableVIPWallTouchBlock()     -- CanTouch = false
        else
            disableSelectiveNoClip()      -- CanCollide = true
            disableVIPWallTouchBlock()    -- CanTouch = true
        end
    end
})

-- Platform Builder UI (inserted from update.lua) placed under Bypass VIP
RunTab:Section({ Title = "Platform Builder" })

RunTab:Toggle({
    Title = "Platform Builder",
    Description = "ON = Build Platform | OFF = Remove Platform",
    Callback = function(v)
        platformEnabled = v
        
        if v then
            platformBooting = true
            
            -- Hentikan sistem yang mungkin konflik
            stopAutoMove()
            stopAutoCollect()
            stopAutoCollectLuckyBlock()
            
            -- Validasi: pastikan karakter ada
            if not getRoot() then
                waitCharacterReady()
                task.wait(1)
            end
            
            -- Pindah ke floor 1 tanpa membunuh karakter
            local success = pcall(function()
                tweenToFloor(Floors[1], true)
            end)
            
            if not success then
                WindUI:Notify({
                    Title = "Tween Gagal",
                    Content = "Gagal pindah ke start, mencoba lagi...",
                    Duration = 2
                })
                task.wait(0.5)
                tweenToFloor(Floors[1], true)
            end
            
            -- Tunggu karakter stabil
            task.wait(0.8)
            
            -- Bangun platform
            enablePlatform()
            platformBooting = false
            
            WindUI:Notify({
                Title = "Platform Ready",
                Content = "Platform & VIP telah aktif",
                Duration = 2
            })
            
        else
            -- Hentikan semua sistem
            stopAutoMove()
            stopAutoCollect()
            stopAutoCollectLuckyBlock()
            
            -- Matikan platform
            disablePlatform()
            
            WindUI:Notify({
                Title = "Platform Dimatikan",
                Content = "Platform & VIP telah dihapus",
                Duration = 2
            })
        end
    end
})

RunTab:Slider({
    Title = "Wall Safe Distance (positive => lebih ke dalam pijakan)",
    Value = { Min = -6, Max = 6, Default = WALL_SAFE_DISTANCE, Step = 0.1 },
    Callback = function(v)
        WALL_SAFE_DISTANCE = v
    end
})

RunTab:Slider({
    Title = "Tween Speed (higher = faster)",
    Value = { Min = 100, Max = 1200, Default = TWEEN_SPEED, Step = 10 },
    Callback = function(v)
        TWEEN_SPEED = v
    end
})

-- Floor Navigation
RunTab:Section({ Title = "Floor Navigation" })

-- GANTI bagian dropdown di line 1240-1248 dengan ini:
RunTab:Dropdown({
    Title = "Target Brainrot",  -- TITLE TETAP SAMA
    Values = BRAINROT_PRIORITY_ORDER,  -- VALUES mengikuti urutan prioritas
    Multi = true,
    Default = {},
    Callback = function(selectedList)
        selectedRarities = {}
        for _, rarity in ipairs(selectedList) do
            selectedRarities[rarity] = true
        end
    end
})

RunTab:Dropdown({
    Title = "Target Lucky Block",
    Values = {
        "Admin","Gamer","Radioactive","Celestial","Divine","Secret","Void",
        "Common","Epic","Legendary","Mythical","Cosmic","Uncommon","Rare",
        "UFO","Alien","Jackpot","Money"
    },
    Multi = true,
    Default = {},
    Callback = function(selectedList)
        LuckyBlockTargets = {}
        for _, v in ipairs(selectedList) do
            LuckyBlockTargets[tostring(v)] = true
        end
    end
})

RunTab:Slider({
    Title = "Jumlah Brainrot per Loop",
    Description = "Berapa banyak brainrot yang diambil tiap loop (1..6)",
    Value = { Min = 1, Max = 6, Default = BRAINROT_PICK_COUNT, Step = 1 },
    Callback = function(v)
        BRAINROT_PICK_COUNT = v
    end
})

-- Modifikasi notifikasi di toggle auto collect:
RunTab:Toggle({
    Title = "Auto Collect Brainrot",
    Description = "Farm brainrot dengan sistem prioritas otomatis",
    Default = false,
    Callback = function(v)
        if v then
            -- Validasi sebelum start
            if next(selectedRarities) == nil then
                WindUI:Notify({
                    Title = "Error",
                    Content = "Pilih minimal 1 rarity brainrot!",
                    Duration = 3
                })
                return
            end
            
            if not platformEnabled then
                WindUI:Notify({
                    Title = "Aktifkan Platform Builder",
                    Content = "Platform builder harus aktif untuk safe area",
                    Duration = 3
                })
                return
            end
            
            -- Stop competing systems
            stopAutoMove()
            stopAutoCollectLuckyBlock()
            
            -- Tampilkan urutan prioritas yang akan dipakai
            local selectedOrdered = {}
            for _, rarity in ipairs(BRAINROT_PRIORITY_ORDER) do
                if selectedRarities[rarity] then
                    table.insert(selectedOrdered, rarity)
                end
            end
            
            -- Set flag dan start
            autoCollectEnabled = true
            startAutoCollectBrainrotByRarity()
            
            WindUI:Notify({
                Title = "Auto Collect Aktif",
                Content = string.format(
                    "Mengambil brainrot dari %d rarity\nUrutan prioritas: %s",
                    #selectedOrdered,
                    table.concat(selectedOrdered, " > ")
                ),
                Duration = 4
            })
            
        else
            -- Matikan sistem dengan clean (MANUAL STOP)
            print("[MANUAL] User manually stopped auto collect brainrot")
            autoCollectEnabled = false  -- Set flag false dulu
            stopAllAutoCollect()        -- Kemudian cleanup
            
            -- Reset semua pending restart
            pendingRestartCollect = false
            pendingRestartCollectRarity = false
            
            WindUI:Notify({
                Title = "Auto Collect Dimatikan",
                Content = "Sistem dihentikan manual oleh user",
                Duration = 2
            })
        end
    end
})

RunTab:Toggle({
    Title = "Auto Collect Block",
    Description = "Ambil Lucky Blocks (jenis sesuai Target Lucky Block) di spawned floor target.",
    Default = false,
    Callback = function(v)
        if v then
            stopAutoMove()
            stopAutoCollect()
            autoCollectBlockEnabled = true
            
            -- Clear previous queue
            LuckyBlockQueue = {}
            LuckyBlockSeen = {}
            
            -- Pastikan platform builder aktif
            if not platformEnabled then
                WindUI:Notify({
                    Title = "Platform Builder Required",
                    Content = "Mengaktifkan Platform Builder terlebih dahulu...",
                    Duration = 3
                })
                platformEnabled = true
                enablePlatform()
                task.wait(1) -- Beri waktu untuk platform dibangun
            end
            
            enqueueExistingLuckyBlocks()
            startAutoCollectLuckyBlock()
        else
            stopAutoCollectLuckyBlock()
            -- Bersihkan queue
            LuckyBlockQueue = {}
            LuckyBlockSeen = {}
        end
    end
})

RunTab:Button({
    Title = "⬆ Move Up",
    Callback = function()
        stopAutoMove()
        stopAutoCollect()

        local hrp = nil
        pcall(function() hrp = getHRP() end)
        if not hrp then
            hrp = getRoot()
        end
        if not hrp then return end
        local nextFloor = getNextFloor(hrp.Position.X)
        if nextFloor then tweenToFloor(nextFloor, false) end
    end
})

RunTab:Button({
    Title = "⬇ Move Down",
    Callback = function()
        stopAutoMove()
        stopAutoCollect()

        local hrp = nil
        pcall(function() hrp = getHRP() end)
        if not hrp then
            hrp = getRoot()
        end
        if not hrp then return end
        local prevFloor = getPrevFloor(hrp.Position.X)
        if prevFloor then tweenToFloor(prevFloor, false) end
    end
})

RunTab:Toggle({
    Title = "Auto Move To Target",
    Description = "Bergerak 1 per 1 floor menuju target (melewati tiap floor)",
    Default = false,
    Callback = function(v)
        if v then
            stopAutoCollect()
            autoMoveEnabled = true
            startAutoMoveToTarget(selectedFloorIndex)
        else
            stopAutoMove()
        end
    end
})

------------------------------------------------------
-- EVENT TAB
------------------------------------------------------
local EventTab=Window:Tab({Title="Event",Icon="radio"})
EventTab:Section({ Title = "Event Collect Coins" })
EventTab:Toggle({Title="Collect Radioactive Coin",Callback=function(v) AutoCollectRadioactive = v end})
EventTab:Toggle({Title="Collect UFO Coin",Callback=function(v) AutoCollectUFO = v end})
EventTab:Toggle({Title = "Collect Gold Bar",Callback = function(v) AutoCollectGoldBar = v end})
EventTab:Section({ Title = "Auto Spin Wheel" })
EventTab:Toggle({Title="Auto Spin Radioactive",Callback=function(v)AutoSpinRadioactive=v end})
EventTab:Toggle({Title="Auto Spin UFO",Callback=function(v)AutoSpinUFO=v end})
EventTab:Toggle({
    Title = "Auto Spin Gold Bar",
    Callback = function(v)
        AutoSpinGoldBar = v
    end
})

------------------------------------------------------
-- SELL BRAINROT (existing SellState & UI kept)
-- (the Sell tab earlier in your merged utama.lua remains unchanged)
------------------------------------------------------
-- =========================
-- SELL STATE + HELPERS (required oleh Sell Brainrot tab)
-- =========================
local SellState = {
    scanResults = {},
    chosenTypes = {},
    levelThreshold = 1,
}

-- 1) definisi list (sesuaikan nama persis seperti data yang kamu gunakan)
SellState.BRAINROT_LISTS = {
    Celestial = {
        "Diamantusa","Caffe Trinity","Alessio","Job Job Job Sahur","Dug Dug Dug",
        "Bisonte Giuppitere","Esok Sekolah","Zung Zung Zung Lazur","Avocadini Antilopini",
        "Los Orcaleritos","Capuccino Policia","Rattini Machini","La Malita","Money Elephant"
    },

    Cosmic = {
        "Darlungini Pandanneli","Vroosh Boosh","Nuclearo Dinossauro","La Grande Combinasion",
        "Garama and Madundung","Dragon Cannelloni","Chimpanzini Spiderini","Agarrini la Palini",
        "Las Vaquitas Saturnitas","Graipuss Medussi","Torrtuginni Dragonfrutini",
        "Los Tralaleritos","La Vacca Saturno Saturnita","Pot Hotspot",
        "Las Tralaleritas","Chicleteira Bicicleteira"
    },

    Epic = {
        "Blueberrinni Octopussini","Ballerina Cappuccina","Burbaloni Luliloli",
        "Strawberrelli Flamingelli","Sigma Boy","Pi Pi Watermelon","Pandaccini Bananini",
        "Lionel Cactuseli","Guesto Angelic","Cocosini Mama","Chef Crabracadabra",
        "Chimpanzini Bananini","Glorbo Fruttodrillo"
    },

    Legendary = {
        "Eaglucci Cocosucci","Zibra Zubra Zibralini","Tigrilini Watermelini",
        "Spioniro Golubiro","Rhino Toasterino","Orangutini Ananasini",
        "Gorillo Watermelondrillo","Ganganzelli Trulala","Frigo Camelo",
        "Bombombini Gusini","Bombardiro Crocodilo","Avocadorilla","Cavallo Virtuoso"
    },

    Mythical = {
        "Ballerino Lololo","Cocofanto Elefanto","Los Crocodillitos","Piccione Macchina",
        "Tigroligre Frutonni","Trenostruzzo Turbo 3000",
        "Trippi Troppi Troppa Trippa","Tukanno Bananno","Udin Din Din Dun",
        "Orcalero Orcala","Giraffa Celeste","Tralalero Tralala"
    },

    Rare = {
        "Trulimero Trulicina","Ti Ti Ti Sahur","Salamino Penguino",
        "Perochello Lemonchello","Penguino Cocosino","Cappuccino Assassino",
        "Bananita Dolphinita","Bambini Crostini","Brr Brr Patapim","Avocadini Guffo"
    },

    Secret = {
        "Bambooini Bombini","Eek Eek Eek Sahur","Rainbow 67",
        "La Vacca Black Hole Goat","Fragola La La La","Aura Farma",
        "Los Tungtungtungcitos","Los Combinasionas","Espresso Signora",
        "Unclito Samito","Gattatino Neonino","Gatattino Donutino",
        "Statutino Libertino","Capybara Monitora","Tractoro Dinosauro",
        "Mastodontico Telepiedone","Patatino Astronauta","Matteo",
        "Patito Dinerito","Onionello Penguini"
    },

    Uncommon = {
        "Trippi Troppi","Tric Tric Baraboom","Ta Ta Ta Sahur","Pipi Avocado",
        "Gangster Footera","Cacto Hipopotamo","Boneca Ambalabu",
        "Bobrito Bandito","67"
    },

    Common = {
        "Tim Cheese","Talpa Di Fero","Svinino Bombondino","Pipi Kiwi",
        "Pipi Corni","Noobini Cakenini","Lirili Larila","Frulli Frulla"
    },

    Divine = {
        "Strawberry Elephant","Burgerini Bearini","Bulbito Bandito Traktorito",
        "Martino Gravitino","Galactio Fantasma","Din Din Vaultero","Grappellino D'Oro"
    },

    Infinity = {
        "Noobini Infeeny"
    }
}

-- 2) build lookup table (lowercase) untuk cek cepat
local function buildLookups()
    SellState.BRAINROT_LOOKUP = {}
    for rarity, list in pairs(SellState.BRAINROT_LISTS) do
        local t = {}
        for _, name in ipairs(list) do
            t[string.lower(name)] = true
        end
        SellState.BRAINROT_LOOKUP[rarity] = t
    end
end
buildLookups()

-- 3) scan inventory: baca Backpack semua tool yang punya RenderModel dan attributes
local function scanInventory()
    SellState.scanResults = {}
    local plr = Players.LocalPlayer
    if not plr then return 0 end
    local bp = plr:FindFirstChild("Backpack")
    if not bp then return 0 end

    for _, item in ipairs(bp:GetChildren()) do
        if item and item.Parent and item:FindFirstChild("RenderModel") then
            local r = item.RenderModel
            local brName = nil
            local lvl = nil
            local mut = nil
            if r.GetAttribute then
                brName = r:GetAttribute("BrainrotName")
                lvl = r:GetAttribute("Level")
                mut = r:GetAttribute("Mutation")
            end
            local nameStr = brName and tostring(brName) or tostring(item.Name)
            local levelNum = tonumber(lvl) or 0
            local mutStr = mut and tostring(mut) or ""

            table.insert(SellState.scanResults, {
                tool = item,
                name = nameStr,
                level = levelNum,
                mutation = mutStr
            })
        end
    end

    return #SellState.scanResults
end

-- helper: sell tool instance (equip + invoke remote)
local function sellToolInstance(toolInstance)
    if not toolInstance or not toolInstance.Parent then return false, "tool invalid" end

    local rf = ReplicatedStorage:FindFirstChild("RemoteFunctions")
    local remote = rf and rf:FindFirstChild("SellTool")
    if not remote then
        return false, "remote not found"
    end

    local ok, res = pcall(function()
        if toolInstance:IsA("Tool") then
            pcall(function()
                local hum = getHumanoid()
                if hum then
                    hum:EquipTool(toolInstance)
                end
            end)
            task.wait(0.06)
        end
        return remote:InvokeServer()
    end)

    if not ok then
        return false, "invoke error"
    end

    return true, nil
end

-- === helper: cek nama terhadap single rarity ===
local function isNameInRarity(name, rarity)
    if not name then return false end
    if not rarity or rarity == "All" then return true end
    local ln = string.lower(name)
    local lookup = SellState.BRAINROT_LOOKUP[rarity]
    return lookup and lookup[ln]
end

-- === collect matches (dipakai UI Sell) ===
local function collectMatchesFromScan()
    local matches = {}
    local thr = tonumber(SellState.levelThreshold) or 0

    for _, entry in ipairs(SellState.scanResults) do
        -- 1) jika user memilih tipe (multi-select), pastikan nama brainrot
        --    cocok dengan salah satu rarity yang dipilih.
        local passesTypeFilter = true
        if next(SellState.chosenTypes) then
            passesTypeFilter = false
            for ty, _ in pairs(SellState.chosenTypes) do
                if isNameInRarity(entry.name, ty) then
                    passesTypeFilter = true
                    break
                end
            end
        end

        -- 2) cek level BELOW (<= threshold)
        if not passesTypeFilter then
            -- skip
        else
            if entry.level <= thr then
                table.insert(matches, entry)
            end
        end
    end

    return matches
end


-- If SellTab not created earlier (defensive), create it here:
local hasSellTab = false
for _, t in ipairs(Window.Tabs or {}) do
    if t.Title == "Sell Brainrot" then hasSellTab = true break end
end

if not hasSellTab then
    local SellTab = Window:Tab({ Title = "Sell Brainrot", Icon = "shopping-bag" })

    SellTab:Section({ Title = "Filter / Sell" })

    SellTab:Dropdown({
        Title = "Type Brainrot",
        Values = {
            "Common","Uncommon","Rare","Epic","Legendary",
            "Mythical","Cosmic","Secret","Celestial",
            "Divine","Infinity"
        },
        Multi = true,
        Default = {},
        Callback = function(selectedList)
            SellState.chosenTypes = {}
            for _, v in ipairs(selectedList) do
                SellState.chosenTypes[v] = true
            end
        end
    })

    SellTab:Input({
        Title = "Level (below)",
        Placeholder = tostring(SellState.levelThreshold),
        Callback = function(v)
            local n = tonumber(v)
            if n and n >= 0 then
                SellState.levelThreshold = n
                WindUI:Notify({ Title = "Threshold Set", Content = tostring(n), Duration = 1 })
            else
                WindUI:Notify({ Title = "Error", Content = "Masukkan angka valid", Duration = 1 })
            end
        end
    })

    SellTab:Button({
        Title = "Sell Brainrot",
        Description = "Scan inventory lalu jual semua brainrot yang cocok (type + level below).",
        Callback = function()
            local found = scanInventory()
            if found == 0 then
                WindUI:Notify({ Title = "No Items", Content = "Tidak ada item dengan RenderModel di Backpack.", Duration = 2 })
                return
            end

            local matches = collectMatchesFromScan()
            if #matches == 0 then
                WindUI:Notify({ Title = "No Matches", Content = "Tidak ada brainrot sesuai kriteria.", Duration = 2 })
                return
            end

            WindUI:Notify({ Title = "Selling...", Content = ("Menjual %d brainrot"):format(#matches), Duration = 2 })

            local sold = 0
            for _, entry in ipairs(matches) do
                local toolObj = entry.tool
                if toolObj and toolObj.Parent then
                    local ok, err = sellToolInstance(toolObj)
                    if ok then
                        sold = sold + 1
                        print(("[Sell] OK: %s lvl=%d"):format(entry.name, entry.level))
                    else
                        warn(("[Sell] Failed %s: %s"):format(entry.name, tostring(err)))
                    end
                    task.wait(0.18)
                else
                    warn("[Sell] tool missing or moved: " .. tostring(entry.tool and entry.tool.Name))
                end
            end

            WindUI:Notify({ Title = "Done", Content = ("Terjual: %d / %d"):format(sold, #matches), Duration = 3 })
        end
    })
    SellTab:Section({ Title = "Open Lucky Block" })
    SellTab:Dropdown({
        Title = "Type Lucky Block",
        Values = {
            "All",
            "Common","Uncommon","Rare","Epic","Legendary",
            "Mythical","Cosmic","Secret","Celestial",
            "Divine","Infinity"
        },
        Multi = true,
        Default = { "All" },
        Callback = function(selected)
            OpenBlockState.chosenTypes = {}

            -- kalau pilih All, kita tandai khusus
            for _, v in ipairs(selected) do
                if v == "All" then
                    OpenBlockState.chosenTypes = { All = true }
                    return
                end
                OpenBlockState.chosenTypes[v] = true
            end
        end
    })

    SellTab:Button({
        Title = "Open Block",
        Description = "Buka semua Lucky Block di Backpack sesuai Type Lucky Block",
        Callback = function()
            local bp = Players.LocalPlayer:FindFirstChild("Backpack")
            if not bp then
                WindUI:Notify({
                    Title = "Error",
                    Content = "Backpack tidak ditemukan",
                    Duration = 2
                })
                return
            end

            local opened = 0
            local total = 0

            for _, tool in ipairs(bp:GetChildren()) do
                if tool:IsA("Tool") then
                    local rig = tool:FindFirstChild("LuckyBlockRig")
                    if rig then
                        local blockType = rig:GetAttribute("LuckyBlockType")
                        blockType = blockType and tostring(blockType)

                        -- cek filter
                        local allow = false
                        if OpenBlockState.chosenTypes.All then
                            allow = true
                        elseif blockType and OpenBlockState.chosenTypes[blockType] then
                            allow = true
                        end

                        if allow then
                            total += 1
                            local ok = openLuckyBlockTool(tool)
                            if ok then
                                opened += 1
                            end
                            task.wait(0.2) -- amanin spam remote
                        end
                    end
                end
            end

            WindUI:Notify({
                Title = "Open Block Done",
                Content = string.format("Opened %d / %d Lucky Blocks", opened, total),
                Duration = 3
            })
        end
    })
end

------------------------------------------------------
-- MISC TAB
------------------------------------------------------
local MiscTab=Window:Tab({Title="Misc",Icon="sparkles"})
MiscTab:Section({ Title = "I dont know but i know u need this features" })
MiscTab:Toggle({Title="Instant Grab",Callback=function(v) if v then enableInstantGrab() else disableInstantGrab() end end})
MiscTab:Toggle({Title="Infinite Zoom Out",Callback=function(v) if v then enableInfiniteZoom() else disableInfiniteZoom() end end})
MiscTab:Toggle({Title="Infinite Jump",Callback=function(v) if v then enableInfiniteJump() else disableInfiniteJump() end end})

------------------------------------------------------
-- READY
------------------------------------------------------
WindUI:Notify({
    Title="HexaCore Hub Loaded",
    Content="Auto Run + Respawn + Manual Override FIXED",
    Duration=4
})
