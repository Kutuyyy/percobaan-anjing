-- Bring Item Ultimate + Teleport Tab + Papi Dimz HUB + Fishing + Farm (FULL MERGE)
-- Semua fitur asli + Christmas + Maze + Local Player + Fishing + Farm (COMPLETE)
-- Author: Dimz
-- Merge: FRENESIS
local function main()
    ---------------------------------------------------------
    -- SERVICES
    ---------------------------------------------------------
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    local VirtualUser = game:GetService("VirtualUser")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")

    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera
    local VirtualInputManager = game:GetService("VirtualInputManager")

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
    -- STATE (BRING ITEM SYSTEM - ASLI)
    ---------------------------------------------------------
    -- Variabel utama (akan diinisialisasi nanti)
    local Character, HumanoidRootPart, ItemsFolder, RemoteEvents, RequestStartDragging, RequestStopDragging
    local BringHeight = 20
    local selectedLocation = "Player"

    -- Scrapper Cache untuk Bring Item system (TERPISAH dari Farm System)
    local ScrapperTarget_Bring = nil
    local function getScrapperTarget_Bring()
        if ScrapperTarget_Bring and ScrapperTarget_Bring.Parent then return ScrapperTarget_Bring end
        local map = Workspace:FindFirstChild("Map")
        local camp = map and map:FindFirstChild("Campground")
        local scrapper = camp and camp:FindFirstChild("Scrapper")
        local movers = scrapper and scrapper:FindFirstChild("Movers")
        local right = movers and movers:FindFirstChild("Right")
        local grinder = right and right:FindFirstChild("GrindersRight")
        if grinder and grinder:IsA("BasePart") then
            ScrapperTarget_Bring = grinder
            return grinder
        end
        return nil
    end

    -- Fungsi non-blocking untuk menunggu resource game
    local function waitForEssentialResources()
        repeat
            Character = LocalPlayer.Character
            task.wait()
        until Character
        HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
        print("[Resource] Karakter siap.")

        while not scriptDisabled do
            ItemsFolder = Workspace:FindFirstChild("Items")
            RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
            if ItemsFolder and RemoteEvents then
                RequestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
                RequestStopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
                if RequestStartDragging and RequestStopDragging then
                    print("[Resource] Semua remote 'Bring Item' ditemukan.")
                    -- Panggil inisialisasi farm system setelah resource dasar siap
                    initFarmRemotes()
                    break
                end
            end
            task.wait(1)
        end
    end
    -- Jalankan di background
    task.spawn(waitForEssentialResources)

    ---------------------------------------------------------
    -- STATE (PAPI DIMZ HUB - ASLI)
    ---------------------------------------------------------
    local scriptDisabled = false

    -- Main
    local GodmodeEnabled = false
    local AntiAFKEnabled = true

    -- Character refs
    local humanoid = nil
    local rootPart = nil

    -- Camera / movement
    local defaultFOV = Camera.FieldOfView
    local fovEnabled = false
    local fovValue = 60

    local walkEnabled = false
    local walkSpeedValue = 30
    local defaultWalkSpeed = 16

    -- ORIGINAL FLY STATE (ASLI TANPA DIUBAH)
    local flyEnabled = false
    local flySpeedValue = 50
    local flyConn = nil
    local noclipConn = nil
    local originalTransparency = {}
    local idleTrack = nil

    ---------------------------------------------------------
    -- STATE (FISHING SYSTEM - ASLI)
    ---------------------------------------------------------
    -- Fishing state (XENO GLASS)
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

    ---------------------------------------------------------
    -- STATE (FARM SYSTEM - COMPLETE from contekan.lua)
    ---------------------------------------------------------
    -- Remotes / folders
    local Structures = Workspace:FindFirstChild("Structures")

    -- Original features state
    local CookingStations = {}
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

    local CoinAmmoEnabled = false
    local coinAmmoDescAddedConn = nil
    local CoinAmmoConnection = nil

    local TemporalAccelerometer = Structures and Structures:FindFirstChild("Temporal Accelerometer")
    local autoTemporalEnabled = false
    local lastProcessedDay = nil
    local DayDisplayRemote = nil
    local DayDisplayConnection = nil

    -- Webhook state
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
    local AxeIDs = {
        ["Old Axe"] = "3_7367831688",
        ["Good Axe"] = "112_7367831688",
        ["Strong Axe"] = "116_7367831688",
        ["Infernal Sword"] = "1_8838463626",
        Chainsaw = "647_8992824875",
        Spear = "196_8999010016"
    }
    local TreeCache = {}
    local SelectedTreeCategories = {"Small Tree"} -- Default categories (ARRAY)
    local TreeCategories = {
        ["Small Tree"] = {"Small Tree"},
        ["Snowy Small Tree"] = {"Snowy Small Tree","Northern Pine"},
        ["Big Tree"] = {"TreeBig1", "TreeBig2", "TreeBig3"}
    }
    local auraHeartbeatConnection = nil

    -- Local Player tambahan (dari contekan.lua)
    local tpWalkEnabled = false
    local tpWalkSpeedValue = 5
    local tpWalkConn = nil
    local noclipManualEnabled = false
    local infiniteJumpEnabled = false
    local infiniteJumpConn = nil
    local fullBrightEnabled = false
    local fullBrightConn = nil
    local oldLightingProps = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient
    }
    local hipEnabled = false
    local hipValue = 35
    local defaultHipHeight = 2
    local instantOpenEnabled = false
    local promptOriginalHold = {}
    local promptConn = nil

    -- Remote events untuk farm
    local CollectCoinRemote = nil
    local ConsumeItemRemote = nil
    local NightSkipRemote = nil
    local ToolDamageRemote = nil
    local EquipHandleRemote = nil

    -- STATE (FRENESIS - 99 Night Explorer)
    local spiralActive = false
    local spiralThread
    local spiralCenter = Vector3.new(0, 50, 0)
    local flySpeed = 300

    local overlayVisible = false
    local overlayParts = {}
    local overlayRadius = 100
    local overlayHeight = 3
    local overlayCenter = Vector3.new(1, overlayHeight, 1)
    local overlayPoints = 50
    local overlayShape = "circle"
    local overlayShapes = {"circle", "square", "triangle", "star", "hexagon", "spiral", "diamond"}

    local plantingActive = false
    local plantingThread
    local plantingMode = "character"
    local plantInterval = 0.5
    local infiniteSaplingEnabled = false
    local plantSequenceIndex = 1
    local totalPlanted = 0
    local maxPlantPoints = 0
    local plantingCompleted = false

    local logWallActive = false
    local logWallThread = nil
    local placeStructureRemote = nil
    local angleIncrement = 2
    local radiusIncrement = 10

    local INFINITE_SHOW_MARKER = true
    local INFINITE_MARKER_LIFETIME = 3
    local characterPlantHistory = {}

    local isOpeningChests = false
    local chestOpeningThread = nil
    local chestOpeningSpeed = 0.3
    local chestQueue = {}
    local chestTypes = {
        "Item Chest",
        "Item Chest2", 
        "Item Chest3",
        "Item Chest4",
        "Halloween Chest1",
        "Halloween Maze Chest",
        "ChristmasPresent1"
    }
    local openedChests = {}

    -- Untuk ground position
    local groundPosition = Vector3.new(0, 6, 0)

    ---------------------------------------------------------
    -- UTILITY FUNCTIONS (from contekan.lua)
    ---------------------------------------------------------
    local function tableToSet(list)
        local t = {}
        for _, v in ipairs(list) do t[v] = true end
        return t
    end

    -- Fungsi untuk verifikasi pohon yang ditemukan
    local function verifyTreeCategory(category)
        local treeNames = TreeCategories[category]
        if not treeNames then return {} end
        
        local found = {}
        local map = Workspace:FindFirstChild("Map")
        if not map then return found end
        
        for _, treeName in ipairs(treeNames) do
            for _, obj in ipairs(map:GetDescendants()) do
                if obj.Name == treeName and obj:IsA("Model") then
                    if not table.find(found, treeName) then
                        table.insert(found, treeName)
                    end
                end
            end
        end
        
        print(string.format("[Verify] Category '%s': %s", 
            category, 
            #found > 0 and table.concat(found, ", ") or "Tidak ditemukan"
        ))
        return found
    end

    local function trim(s)
        if type(s) ~= "string" then return s end
        return s:match("^%s*(.-)%s*$")
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
                                    WindUI:Notify({Title="Auto Recast", Content="Recast dilakukan.", Duration=2})
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

    ---------------------------------------------------------
    -- FARM SYSTEM FUNCTIONS (COMPLETE from contekan.lua)
    ---------------------------------------------------------

    -- LAVA FINDER
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
            WindUI:Notify({Title="Lava", Content="Volcano lava ditemukan. Auto-sacrifice siap.", Duration=4, Icon="flame"})
        end
    end

    task.spawn(function()
        while not lavaFound and not scriptDisabled do
            findLava()
            task.wait(1.5)
        end
    end)

    -- AUTO SACRIFICE LAVA
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

    -- AUTO CROCKPOT
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

    -- SCRAPPER (GRINDER)
    local ScrapperTargetFarm = nil
    local function ensureScrapperTargetFarm()
        if ScrapperTargetFarm and ScrapperTargetFarm.Parent then return true end
        local map = Workspace:FindFirstChild("Map")
        if not map then warn("[Scrap] workspace.Map tidak ditemukan."); ScrapperTargetFarm = nil; return false end
        local camp = map:FindFirstChild("Campground")
        if not camp then warn("[Scrap] Map.Campground tidak ditemukan."); ScrapperTargetFarm = nil; return false end
        local scrapper = camp:FindFirstChild("Scrapper")
        if not scrapper then warn("[Scrap] Campground.Scrapper tidak ditemukan."); ScrapperTargetFarm = nil; return false end
        local movers = scrapper:FindFirstChild("Movers")
        if not movers then warn("[Scrap] Scrapper.Movers tidak ditemukan."); ScrapperTargetFarm = nil; return false end
        local right = movers:FindFirstChild("Right")
        if not right then warn("[Scrap] Scrapper.Movers.Right tidak ditemukan."); ScrapperTargetFarm = nil; return false end
        local grindersRight = right:FindFirstChild("GrindersRight")
        if not grindersRight or not grindersRight:IsA("BasePart") then warn("[Scrap] GrindersRight tidak ditemukan / bukan BasePart."); ScrapperTargetFarm = nil; return false end
        ScrapperTargetFarm = grindersRight
        print("[Scrap] Scrapper target:", getInstancePath(ScrapperTargetFarm))
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
        if not ensureScrapperTargetFarm() then 
            print("[Scrap] Scrapper target belum siap."); 
            return 
        end
        local scrapBase = ScrapperTargetFarm  -- GANTI INI
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
    ---------------------------------------------------------
    -- GODMODE & ANTI AFK (DIPERBAIKI)
    ---------------------------------------------------------
    local GodmodeLoopActive = false
    local DamagePlayerRemote = nil

    local function startGodmodeLoop()
        if GodmodeLoopActive then return end
        GodmodeLoopActive = true
        
        task.spawn(function()
            while GodmodeLoopActive and not scriptDisabled do
                if GodmodeEnabled then
                    pcall(function()
                        -- Coba cari remote jika belum ada
                        if not DamagePlayerRemote then
                            DamagePlayerRemote = RemoteEvents and RemoteEvents:FindFirstChild("DamagePlayer")
                        end
                        
                        if DamagePlayerRemote then
                            -- Kirim damage negatif untuk heal
                            DamagePlayerRemote:FireServer(-math.huge)
                            -- print("[GodMode] Healing applied")
                        else
                            -- Coba cari lagi di ReplicatedStorage
                            DamagePlayerRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
                                and ReplicatedStorage.RemoteEvents:FindFirstChild("DamagePlayer")
                            if not DamagePlayerRemote then
                                warn("[GodMode] Remote 'DamagePlayer' tidak ditemukan!")
                            end
                        end
                    end)
                end
                task.wait(8) -- Interval 8 detik seperti contekan.lua
            end
            GodmodeLoopActive = false
        end)
    end

    -- Panggil fungsi startGodmodeLoop() di bagian inisialisasi (tambahkan baris ini di posisi yang tepat)

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

    -- KILL AURA + CHOP AURA (Heartbeat)
    local nextAuraTick = 0
    local function GetBestAxe(forTree)
        for name, id in pairs(AxeIDs) do
            if (not forTree) or (name ~= "Infernal Sword" and name ~= "Spear" and name ~= "Chainsaw") then
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

    -- GANTI fungsi buildTreeCache (sekitar baris 480):
    local function buildTreeCache()
        TreeCache = {}
        local map = Workspace:FindFirstChild("Map")
        if not map then return end
        
        -- Kumpulkan semua nama pohon dari kategori yang dipilih
        local allTargetNames = {}
        for _, category in ipairs(SelectedTreeCategories) do
            local names = TreeCategories[category]
            if not names then
                warn("[ChopAura] Kategori pohon tidak ditemukan:", category)
            else
                for _, treeName in ipairs(names) do
                    allTargetNames[treeName] = true -- Gunakan table sebagai set
                end
            end
        end
        
        local function scanFolder(folder)
            if not folder then return end
            for _, obj in ipairs(folder:GetDescendants()) do
                -- Cek apakah nama objek ada dalam daftar target
                if obj:IsA("Model") and allTargetNames[obj.Name] then
                    -- Pastikan punya Trunk (untuk interaksi)
                    if obj:FindFirstChild("Trunk") then
                        table.insert(TreeCache, obj)
                    end
                end
            end
        end
        
        -- Scan di folder utama
        scanFolder(map:FindFirstChild("Foliage"))
        scanFolder(map:FindFirstChild("Landmarks"))
        
        -- Hitung total kategori dan nama
        local categoryStr = table.concat(SelectedTreeCategories, ", ")
        local totalTargets = 0
        for _ in pairs(allTargetNames) do totalTargets = totalTargets + 1 end
        
        print(string.format(
            "[ChopAura] Cache dibangun untuk %d kategori: %s. Total jenis pohon: %d. Pohon ditemukan: %d",
            #SelectedTreeCategories, categoryStr, totalTargets, #TreeCache
        ))
        
        -- Tampilkan notifikasi UI jika ada
        if #TreeCache > 0 and ChopAuraEnabled then
            WindUI:Notify({
                Title = "Chop Aura Cache",
                Content = string.format("Found %d trees in categories: %s", #TreeCache, categoryStr),
                Duration = 4,
                Icon = "trees"
            })
        end
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

    -- TEMPORAL / NIGHT SKIP
    local function activateTemporal()
        if scriptDisabled then return end
        if not TemporalAccelerometer or not TemporalAccelerometer.Parent then
            Structures = Workspace:FindFirstChild("Structures") or Structures
            TemporalAccelerometer = Structures and Structures:FindFirstChild("Temporal Accelerometer") or TemporalAccelerometer
        end
        if not TemporalAccelerometer then
            warn("[Temporal] Temporal Accelerometer tidak ditemukan.")
            WindUI:Notify({Title="Temporal", Content="Temporal Accelerometer belum tersedia.", Duration=4, Icon="alert-triangle"})
            return
        end
        if NightSkipRemote then
            NightSkipRemote:FireServer(TemporalAccelerometer)
            print("[Temporal] RequestActivate dikirim.")
        end
    end

    ---------------------------------------------------------
    -- WEBHOOK HELPERS (LENGKAP dari contekan.lua)
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
    -- DAYDISPLAY (non-blocking hook) - LENGKAP
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
                            if ok then WindUI:Notify({Title="Webhook Sent", Content="Day " .. tostring(previousDay) .. " → " .. tostring(currentDay), Duration=6, Icon="radio"}) end
                            if not ok then WindUI:Notify({Title="Webhook Failed", Content=tostring(msg), Duration=6, Icon="alert-triangle"}); warn("Day webhook failed:", msg) end
                        else
                            WindUI:Notify({Title="Day Increased", Content="Day " .. tostring(previousDay) .. " → " .. tostring(currentDay) .. " (webhook OFF)", Duration=5, Icon="calendar"})
                        end
                    else
                        print("DayDisplay event tanpa kenaikan day:", previousDay, "->", currentDay)
                    end
                else
                    print("DayDisplay event non-numeric:", tostring(currentDay), tostring(previousDay))
                end
            end)
            print("[DayDisplay] Listener terpasang ke:", getInstancePath(remote))
            WindUI:Notify({Title="DayDisplay", Content="Listener terpasang.", Duration=4, Icon="radio"})
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
                WindUI:Notify({Title="DayDisplay", Content="DayDisplay remote tidak ditemukan (timeout). Fitur DayDisplay/Webhook menunggu.", Duration=6, Icon="alert-triangle"})
            end
        end)
    end

    -- Inisialisasi remote events khusus untuk Farm System
    local function initFarmRemotes()
        if not RemoteEvents then return false end
        CollectCoinRemote = RemoteEvents:FindFirstChild("RequestCollectCoints")
        ConsumeItemRemote = RemoteEvents:FindFirstChild("RequestConsumeItem")
        NightSkipRemote = RemoteEvents:FindFirstChild("RequestActivateNightSkipMachine")
        ToolDamageRemote = RemoteEvents:FindFirstChild("ToolDamageObject")
        EquipHandleRemote = RemoteEvents:FindFirstChild("EquipItemHandle")
        
        print("[Farm Remotes] Inisialisasi selesai.")
        return true
    end

    ---------------------------------------------------------
    -- FRENESIS FUNCTIONS (99 Night Explorer)
    ---------------------------------------------------------

    -- Fungsi untuk mendapatkan posisi ground
    local function getRoot()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function getFootPosition()
        local root = getRoot()
        if not root then return nil end
        
        local origin = Vector3.new(root.Position.X, root.Position.Y + 2, root.Position.Z)
        local rayDir = Vector3.new(0, -20, 0)
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = { LocalPlayer.Character or LocalPlayer }
        rp.FilterType = Enum.RaycastFilterType.Blacklist
        local res = workspace:Raycast(origin, rayDir, rp)
        
        if res and res.Position then
            return res.Position + Vector3.new(0, 1, 0)
        end
        
        return root.Position - Vector3.new(0, 3, 0)
    end

    -- Spiral Flight
    local function startSpiralFlight()
        if spiralActive then return end
        spiralActive = true

        local root = getRoot()
        if not root then return end

        spiralThread = task.spawn(function()
            local startTime = tick()
            local duration = 60
            local radius = 1000
            local loops = 10

            while spiralActive and tick() - startTime < duration do
                local t = (tick() - startTime) / duration
                local angle = t * math.pi * 2 * loops
                local r = t * radius

                local target = Vector3.new(
                    spiralCenter.X + math.cos(angle) * r,
                    spiralCenter.Y,
                    spiralCenter.Z + math.sin(angle) * r
                )

                local dir = (target - root.Position)
                if dir.Magnitude > flySpeed then
                    dir = dir.Unit * flySpeed
                end

                root.CFrame = CFrame.new(root.Position + dir)
                task.wait()
            end

            spiralActive = false
            if root then
                root.CFrame = CFrame.new(groundPosition)
            end
        end)
    end

    local function stopSpiralFlight()
        spiralActive = false
        if spiralThread then
            task.cancel(spiralThread)
            spiralThread = nil
        end
        local root = getRoot()
        if root then
            root.CFrame = CFrame.new(groundPosition)
        end
    end

    -- Overlay System
    local function clearOverlay()
        for _, p in ipairs(overlayParts) do
            if p.Parent then p:Destroy() end
        end
        overlayParts = {}
    end

    local function createOverlay()
        clearOverlay()
        
        -- Hitung distribusi titik per layer
        local layers = angleIncrement
        local basePoints = math.floor(overlayPoints / layers)
        local remainder = overlayPoints % layers
        
        for layer = 1, layers do
            -- Hitung radius untuk layer ini
            local layerRadius = overlayRadius + ((layer - 1) * radiusIncrement)
            
            -- Hitung jumlah titik di layer ini
            local layerPoints = basePoints
            if layer == layers then  -- Layer terakhir dapat sisa
                layerPoints = layerPoints + remainder
            end
            
            -- Warna berbeda per layer
            local hue = (layer / layers) * 0.7  -- 0-0.7 untuk warna pelangi
            local layerColor = Color3.fromHSV(hue, 0.8, 1)
            
            if overlayShape == "circle" then
                -- Lingkaran konsentris
                for i = 1, layerPoints do
                    local a = (i / layerPoints) * math.pi * 2
                    local p = Instance.new("Part")
                    p.Size = Vector3.new(1, 1, 1)
                    p.Anchored = true
                    p.CanCollide = false
                    p.Material = Enum.Material.Neon
                    p.Color = layerColor
                    p.Transparency = 0.3
                    p.Position = Vector3.new(
                        overlayCenter.X + math.cos(a) * layerRadius,
                        overlayCenter.Y,
                        overlayCenter.Z + math.sin(a) * layerRadius
                    )
                    p.Parent = workspace
                    table.insert(overlayParts, p)
                end
                
            elseif overlayShape == "square" then
                -- Persegi konsentris
                local pointsPerSide = math.max(1, math.floor(layerPoints / 4))
                local halfSize = layerRadius
                
                for side = 1, 4 do
                    for i = 1, pointsPerSide do
                        local t = (i - 1) / math.max(1, pointsPerSide - 1)
                        local x, z = 0, 0
                        
                        if side == 1 then -- Top
                            x = -halfSize + (t * 2 * halfSize)
                            z = halfSize
                        elseif side == 2 then -- Right
                            x = halfSize
                            z = halfSize - (t * 2 * halfSize)
                        elseif side == 3 then -- Bottom
                            x = halfSize - (t * 2 * halfSize)
                            z = -halfSize
                        elseif side == 4 then -- Left
                            x = -halfSize
                            z = -halfSize + (t * 2 * halfSize)
                        end
                        
                        local p = Instance.new("Part")
                        p.Size = Vector3.new(1, 1, 1)
                        p.Anchored = true
                        p.CanCollide = false
                        p.Material = Enum.Material.Neon
                        p.Color = layerColor
                        p.Transparency = 0.3
                        p.Position = Vector3.new(
                            overlayCenter.X + x,
                            overlayCenter.Y,
                            overlayCenter.Z + z
                        )
                        p.Parent = workspace
                        table.insert(overlayParts, p)
                    end
                end
                
            elseif overlayShape == "triangle" then
                -- Segitiga konsentris
                local trianglePoints = 3
                local pointsPerSide = math.max(1, math.floor(layerPoints / trianglePoints))
                
                local vertices = {
                    Vector3.new(0, 0, layerRadius),
                    Vector3.new(layerRadius * 0.866, 0, -layerRadius * 0.5),
                    Vector3.new(-layerRadius * 0.866, 0, -layerRadius * 0.5)
                }
                
                for side = 1, trianglePoints do
                    for i = 1, pointsPerSide do
                        local t = (i - 1) / math.max(1, pointsPerSide - 1)
                        local startPoint = vertices[side]
                        local endPoint = vertices[(side % trianglePoints) + 1]
                        
                        local x = startPoint.X + (endPoint.X - startPoint.X) * t
                        local z = startPoint.Z + (endPoint.Z - startPoint.Z) * t
                        
                        local p = Instance.new("Part")
                        p.Size = Vector3.new(1, 1, 1)
                        p.Anchored = true
                        p.CanCollide = false
                        p.Material = Enum.Material.Neon
                        p.Color = layerColor
                        p.Transparency = 0.3
                        p.Position = Vector3.new(
                            overlayCenter.X + x,
                            overlayCenter.Y,
                            overlayCenter.Z + z
                        )
                        p.Parent = workspace
                        table.insert(overlayParts, p)
                    end
                end
                
            elseif overlayShape == "star" then
                -- Bintang konsentris
                for i = 1, layerPoints do
                    local angle = (i / layerPoints) * math.pi * 2
                    local innerRadius = layerRadius * 0.4
                    local outerRadius = layerRadius
                    
                    local r = i % 2 == 0 and innerRadius or outerRadius
                    local starAngle = angle * 5 / 2
                    
                    local x = math.cos(starAngle) * r
                    local z = math.sin(starAngle) * r
                    
                    local p = Instance.new("Part")
                    p.Size = Vector3.new(1, 1, 1)
                    p.Anchored = true
                    p.CanCollide = false
                    p.Material = Enum.Material.Neon
                    p.Color = layerColor
                    p.Transparency = 0.3
                    p.Position = Vector3.new(
                        overlayCenter.X + x,
                        overlayCenter.Y,
                        overlayCenter.Z + z
                    )
                    p.Parent = workspace
                    table.insert(overlayParts, p)
                end
                
            elseif overlayShape == "hexagon" then
                -- Hexagon konsentris
                local sides = 6
                local pointsPerSide = math.max(1, math.floor(layerPoints / sides))
                
                for side = 0, sides - 1 do
                    for i = 1, pointsPerSide do
                        local t = (i - 1) / math.max(1, pointsPerSide - 1)
                        local angle1 = (side / sides) * math.pi * 2
                        local angle2 = ((side + 1) / sides) * math.pi * 2
                        
                        local x1 = math.cos(angle1) * layerRadius
                        local z1 = math.sin(angle1) * layerRadius
                        local x2 = math.cos(angle2) * layerRadius
                        local z2 = math.sin(angle2) * layerRadius
                        
                        local x = x1 + (x2 - x1) * t
                        local z = z1 + (z2 - z1) * t
                        
                        local p = Instance.new("Part")
                        p.Size = Vector3.new(1, 1, 1)
                        p.Anchored = true
                        p.CanCollide = false
                        p.Material = Enum.Material.Neon
                        p.Color = layerColor
                        p.Transparency = 0.3
                        p.Position = Vector3.new(
                            overlayCenter.X + x,
                            overlayCenter.Y,
                            overlayCenter.Z + z
                        )
                        p.Parent = workspace
                        table.insert(overlayParts, p)
                    end
                end
                
            elseif overlayShape == "spiral" then
                -- Spiral konsentris (setiap layer adalah spiral sendiri)
                for i = 1, layerPoints do
                    local t = i / layerPoints
                    local angle = t * math.pi * 8
                    local r = t * layerRadius  -- Spiral dalam layer ini
                    
                    local x = math.cos(angle) * r
                    local z = math.sin(angle) * r
                    
                    local p = Instance.new("Part")
                    p.Size = Vector3.new(1, 1, 1)
                    p.Anchored = true
                    p.CanCollide = false
                    p.Material = Enum.Material.Neon
                    p.Color = layerColor
                    p.Transparency = 0.3
                    p.Position = Vector3.new(
                        overlayCenter.X + x,
                        overlayCenter.Y,
                        overlayCenter.Z + z
                    )
                    p.Parent = workspace
                    table.insert(overlayParts, p)
                end
                
            elseif overlayShape == "diamond" then
                -- Diamond konsentris
                local vertices = {
                    Vector3.new(0, 0, layerRadius),
                    Vector3.new(layerRadius, 0, 0),
                    Vector3.new(0, 0, -layerRadius),
                    Vector3.new(-layerRadius, 0, 0)
                }
                
                local pointsPerSide = math.max(1, math.floor(layerPoints / 4))
                
                for side = 1, 4 do
                    for i = 1, pointsPerSide do
                        local t = (i - 1) / math.max(1, pointsPerSide - 1)
                        local startPoint = vertices[side]
                        local endPoint = vertices[(side % 4) + 1]
                        
                        local x = startPoint.X + (endPoint.X - startPoint.X) * t
                        local z = startPoint.Z + (endPoint.Z - startPoint.Z) * t
                        
                        local p = Instance.new("Part")
                        p.Size = Vector3.new(1, 1, 1)
                        p.Anchored = true
                        p.CanCollide = false
                        p.Material = Enum.Material.Neon
                        p.Color = layerColor
                        p.Transparency = 0.3
                        p.Position = Vector3.new(
                            overlayCenter.X + x,
                            overlayCenter.Y,
                            overlayCenter.Z + z
                        )
                        p.Parent = workspace
                        table.insert(overlayParts, p)
                    end
                end
            end
        end
    end

    local function updateOverlay()
        if overlayVisible then 
            createOverlay()
        else 
            clearOverlay() 
        end
    end

    -- Sapling System (sederhana)
    local function findSaplingInstance()
        local items = workspace:FindFirstChild("Items")
        if items then
            for _, v in ipairs(items:GetChildren()) do
                if v.Name:lower():find("sapling") then
                    return v
                end
            end
        end
        return "Sapling"
    end

    -- Auto Chest Opener (sederhana)
    local function findAllChests()
        local foundChests = {}
        local itemsFolder = Workspace:FindFirstChild("Items")
        
        if itemsFolder then
            for _, chestType in ipairs(chestTypes) do
                for _, chest in ipairs(itemsFolder:GetChildren()) do
                    if chest:IsA("Model") and chest.Name == chestType then
                        table.insert(foundChests, chest)
                    end
                end
            end
        end
        return foundChests
    end

    local function startAutoOpenChests()
        if isOpeningChests then return end
        
        local chests = findAllChests()
        if #chests == 0 then
            notifyUI("Chest Opener", "Tidak ada chest ditemukan!", 3, "alert-triangle")
            return
        end
        
        isOpeningChests = true
        notifyUI("Chest Opener", "Memulai membuka " .. #chests .. " chest...", 3, "info")
        
        chestOpeningThread = task.spawn(function()
            for i, chest in ipairs(chests) do
                if not isOpeningChests then break end
                
                pcall(function()
                    if RequestOpenItemChest then
                        RequestOpenItemChest:FireServer(chest)
                        notifyUI("Chest Opener", "✓ " .. chest.Name .. " (" .. i .. "/" .. #chests .. ")", 1, "check-circle")
                    end
                end)
                
                task.wait(chestOpeningSpeed)
            end
            
            isOpeningChests = false
            notifyUI("Chest Opener", "Selesai membuka " .. #chests .. " chest!", 4, "success")
        end)
    end

    local function stopAutoOpenChests()
        isOpeningChests = false
        if chestOpeningThread then
            task.cancel(chestOpeningThread)
            chestOpeningThread = nil
        end
        notifyUI("Chest Opener", "Dihentikan", 2, "info")
    end
    ---------------------------------------------------------
    -- UTILITY FUNCTIONS (BRING ITEM - ASLI)
    ---------------------------------------------------------
    local function getTargetPosition(location)
        if not HumanoidRootPart then
            return Vector3.new(0, BringHeight + 3, 0) -- Fallback position
        end
        if location == "Player" then
            return HumanoidRootPart.Position + Vector3.new(0, BringHeight + 3, 0)
        elseif location == "Workbench" then
            local s = getScrapperTarget_Bring() -- PASTIKAN memanggil fungsi yang baru
            if s then return s.Position + Vector3.new(0, BringHeight, 0) end
        elseif location == "Fire" then
            local fire = Workspace.Map.Campground.MainFire.OuterTouchZone
            if fire then return fire.Position + Vector3.new(0, BringHeight, 0) end
        end
        -- Default fallback
        return HumanoidRootPart.Position + Vector3.new(0, BringHeight + 3, 0)
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
        if not ItemsFolder or not RequestStartDragging or not RequestStopDragging then
            WindUI:Notify({Title="System Not Ready", Content="Tunggu hingga game fully loaded.", Icon="alert-triangle", Duration=4})
            return
        end
        if not HumanoidRootPart then
            WindUI:Notify({Title="No Character", Content="Karakter tidak ditemukan.", Icon="user-x", Duration=4})
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
            WindUI:Notify({Title="Info", Content="Item tidak ditemukan", Icon="search", Duration=4})
            return
        end

        WindUI:Notify({Title="Bringing", Content=#candidates.." item → "..location, Icon="zap", Duration=5})

        for i, item in ipairs(candidates) do
            RequestStartDragging:FireServer(item)
            task.wait(0.03)
            item:PivotTo(getDropCFrame(targetPos, i))
            task.wait(0.03)
            RequestStopDragging:FireServer(item)
            task.wait(0.02)
        end
    end

    local function teleportToCFrame(cf)
        if not cf then
            WindUI:Notify({Title="Error", Content="Lokasi tidak ditemukan!", Icon="alert-triangle"})
            return
        end
        HumanoidRootPart.CFrame = cf + Vector3.new(0,4,0)
        WindUI:Notify({Title="Teleport!", Content="Berhasil teleport!", Icon="navigation", Duration=4})
    end

    ---------------------------------------------------------
    -- LOCAL PLAYER HELPERS (PAPI DIMZ - ASLI)
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
            part.AssemblyLinearVelocity = Vector3.new(0,0,0)
            part.AssemblyAngularVelocity = Vector3.new(0,0,0)
        end
    end

    ---------------------------------------------------------
    -- LOCAL PLAYER FUNCTIONS (TAMBAHAN)
    ---------------------------------------------------------
    local function applyFOV()
        Camera.FieldOfView = fovEnabled and fovValue or defaultFOV
    end

    local function applyWalkspeed()
        if humanoid then
            humanoid.WalkSpeed = walkEnabled and walkSpeedValue or defaultWalkSpeed
        end
    end

    local function applyHipHeight()
        if humanoid then
            humanoid.HipHeight = hipEnabled and hipValue or defaultHipHeight
        end
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
        WindUI:Notify({Title="Remove Fog", Content="Fog dihapus.", Duration=3, Icon="wind"})
    end

    local function removeSky()
        for _, obj in ipairs(Lighting:GetChildren()) do if obj:IsA("Sky") then obj:Destroy() end end
        WindUI:Notify({Title="Remove Sky", Content="Skybox dihapus.", Duration=3, Icon="cloud-off"})
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
        WindUI:Notify({Title="Instant Open", Content="Semua ProximityPrompt jadi instant.", Duration=3, Icon="bolt"})
    end

    local function disableInstantOpen()
        instantOpenEnabled = false
        if promptConn then promptConn:Disconnect(); promptConn = nil end
        for prompt, orig in pairs(promptOriginalHold) do
            if prompt and prompt.Parent then pcall(function() prompt.HoldDuration = orig end) end
        end
        promptOriginalHold = {}
        WindUI:Notify({Title="Instant Open", Content="Durasi dikembalikan.", Duration=3, Icon="refresh-ccw"})
    end

    ---------------------------------------------------------
    -- VISIBILITY (PAPI DIMZ - ASLI)
    ---------------------------------------------------------
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

    ---------------------------------------------------------
    -- IDLE ANIMATION (PAPI DIMZ - ASLI)
    ---------------------------------------------------------
    local function playIdleAnimation()
        if idleTrack then idleTrack:Stop() end
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://180435571"
        idleTrack = humanoid:LoadAnimation(anim)
        idleTrack.Priority = Enum.AnimationPriority.Core
        idleTrack.Looped = true
        idleTrack:Play()
    end

    ---------------------------------------------------------
    -- NOCLIP (PAPI DIMZ - ASLI)
    ---------------------------------------------------------
    local function updateNoclipConnection()
        if flyEnabled and not noclipConn then
            noclipConn = RunService.Stepped:Connect(function()
                local char = getCharacter()
                if char then
                    for _, v in ipairs(char:GetDescendants()) do
                        if v:IsA("BasePart") then
                            v.CanCollide = false
                        end
                    end
                end
            end)
        elseif not flyEnabled and noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
    end

    ---------------------------------------------------------
    -- START FLY (PAPI DIMZ - ASLI TANPA DIUBAH)
    ---------------------------------------------------------
    local function startFly()
        if flyEnabled or scriptDisabled then return end

        local char = getCharacter()
        humanoid = getHumanoid()
        rootPart = getRoot()
        if not char or not humanoid or not rootPart then return end

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

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end

        playIdleAnimation()
        updateNoclipConnection()

        flyConn = RunService.RenderStepped:Connect(function(dt)
            if not flyEnabled or not rootPart then return end

            local move = Vector3.new(0,0,0)

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                move += Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                move -= Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                move -= Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                move += Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                move += Vector3.new(0,1,0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                move -= Vector3.new(0,1,0)
            end

            if move.Magnitude > 0 then
                move = move.Unit * math.clamp(flySpeedValue, 16, 200) * dt
                rootPart.CFrame += move
            end

            -- FOLLOW CAMERA X & Y (ASLI)
            rootPart.CFrame = CFrame.new(rootPart.Position) * Camera.CFrame.Rotation

            zeroVelocities(rootPart)
        end)
    end

    ---------------------------------------------------------
    -- STOP FLY (PAPI DIMZ - ASLI TANPA DIUBAH)
    ---------------------------------------------------------
    local function stopFly()
        if not flyEnabled then return end

        flyEnabled = false
        if flyConn then flyConn:Disconnect(); flyConn = nil end

        local char = getCharacter()
        humanoid = getHumanoid()
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

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end

        task.delay(0.1, function()
            if bp then bp:Destroy() end
            if bg then bg:Destroy() end
        end)

        updateNoclipConnection()
    end

    ---------------------------------------------------------
    -- ANTI AFK (PAPI DIMZ - ASLI)
    ---------------------------------------------------------
    LocalPlayer.Idled:Connect(function()
        if AntiAFKEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end
    end)

    ---------------------------------------------------------
    -- INPUT LISTENERS (FISHING)
    ---------------------------------------------------------
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
            WindUI:Notify({Title="Position Set", Content=("X=%d Y=%d"):format(px, py), Duration=3})
            if fishingOverlayVisible then fishingShowOverlay(px, py) end
        end
    end)

    -- Fishing auto click loop
    fishingLoopThread = task.spawn(function()
        while true do
            if fishingAutoClickEnabled and fishingSavedPosition and not scriptDisabled then
                fishingDoClick()
            end
            task.wait(fishingClickDelay)
        end
    end)

    ---------------------------------------------------------
    -- INIT REMOTE EVENTS
    ---------------------------------------------------------
    local function initRemoteEvents()
        local function safeWaitForChild(parent, name, timeout)
            timeout = timeout or 10
            local start = tick()
            while tick() - start < timeout do
                local child = parent:FindFirstChild(name)
                if child then return child end
                task.wait(0.5)
            end
            return nil
        end
        
    -- Tambahkan remote untuk FRENESIS
    RequestOpenItemChest = RemoteEvents:FindFirstChild("RequestOpenItemChest")
    placeStructureRemote = RemoteEvents:FindFirstChild("RequestPlaceStructure")

        -- Tunggu RemoteEvents muncul
        local re = safeWaitForChild(ReplicatedStorage, "RemoteEvents")
        if not re then
            warn("[RemoteEvents] Tidak ditemukan setelah timeout!")
            return false
        end
        
        RemoteEvents = re
        print("[RemoteEvents] Ditemukan:", re.Name)
        
        -- Ambil semua remote secara spesifik
        -- Untuk Bring Item System
        RequestStartDragging = re:FindFirstChild("RequestStartDraggingItem")
        RequestStopDragging = re:FindFirstChild("StopDraggingItem")
        
        -- Untuk GodMode
        DamagePlayerRemote = re:FindFirstChild("DamagePlayer")
        
        -- Untuk Farm System
        CollectCoinRemote = re:FindFirstChild("RequestCollectCoints")
        ConsumeItemRemote = re:FindFirstChild("RequestConsumeItem") 
        NightSkipRemote = re:FindFirstChild("RequestActivateNightSkipMachine")
        ToolDamageRemote = re:FindFirstChild("ToolDamageObject")
        EquipHandleRemote = re:FindFirstChild("EquipItemHandle")
        
        -- Debug print
        print(string.format(
            "[Remotes] Bring: %s/%s | GodMode: %s | Farm: %s/%s/%s/%s/%s",
            tostring(RequestStartDragging ~= nil),
            tostring(RequestStopDragging ~= nil),
            tostring(DamagePlayerRemote ~= nil),
            tostring(CollectCoinRemote ~= nil),
            tostring(ConsumeItemRemote ~= nil),
            tostring(NightSkipRemote ~= nil),
            tostring(ToolDamageRemote ~= nil),
            tostring(EquipHandleRemote ~= nil)
        ))
        
        if WindUI then
            WindUI:Notify({
                Title = "Remote Events", 
                Content = "Semua remote ditemukan!", 
                Duration = 3, 
                Icon = "radio"
            })
        end
        return true
    end

    -- Panggil fungsi ini
    task.spawn(initRemoteEvents)

    ---------------------------------------------------------
    -- WINDOW & TABS
    ---------------------------------------------------------
    local Window = WindUI:CreateWindow({
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

    -- Tab 1: Main (Papi Dimz)
    local mainTab = Window:Tab({ Title = "Main", Icon = "settings-2" })
    -- Tab 2: Local Player (Papi Dimz)
    local localTab = Window:Tab({ Title = "Local Player", Icon = "user" })
    -- Tab 6: Fishing (XENO GLASS)
    local FishingTab = Window:Tab({Title="Fishing", Icon="fish"})
    -- Tab 3: Bring Item (Original)
    local BringTab = Window:Tab({Title="Bring Item", Icon="hand"})
    -- Tab 4: Teleport (Original)
    local TeleportTab = Window:Tab({Title="Teleport", Icon="navigation"})
    -- Tab 5: Update Focused (Original)
    local UpdateTab = Window:Tab({Title="Update Focused", Icon="snowflake"})
    -- Tab 7: Farm (COMPLETE)
    local FarmTab = Window:Tab({ Title = "Farm", Icon = "chef-hat" })
    -- Tab 8: Night Skip
    local NightTab = Window:Tab({ Title = "Night", Icon = "moon" })
    -- Tab 9: Webhook
    local WebhookTab = Window:Tab({ Title = "Webhook", Icon = "radio" })

    ---------------------------------------------------------
    -- MAIN TAB CONTENT
    ---------------------------------------------------------
    ;(function()
        mainTab:Paragraph({
            Title = "Papi Dimz HUB",
            Desc = "Godmode, AntiAFK, Auto Sacrifice Lava, Auto Farm, Aura, Webhook DayDisplay.\nHotkey PC: P untuk toggle UI.",
            Color = "Grey"
        })

        mainTab:Toggle({
            Title = "GodMode",
            Default = false,
            Callback = function(v)
                GodmodeEnabled = v
                
                if v then
                    -- Aktifkan GodMode dan mulai loop
                    if not DamagePlayerRemote then
                        -- Coba cari remote sekali lagi
                        DamagePlayerRemote = RemoteEvents and RemoteEvents:FindFirstChild("DamagePlayer")
                        if not DamagePlayerRemote then
                            DamagePlayerRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
                                and ReplicatedStorage.RemoteEvents:FindFirstChild("DamagePlayer")
                        end
                    end
                    
                    if DamagePlayerRemote then
                        startGodmodeLoop()
                        WindUI:Notify({
                            Title = "GodMode", 
                            Content = "AKTIF - Damage negatif dikirim setiap 8 detik", 
                            Duration = 5, 
                            Icon = "shield"
                        })
                        print("[GodMode] GodMode diaktifkan, remote ditemukan:", DamagePlayerRemote.Name)
                    else
                        GodmodeEnabled = false
                        WindUI:Notify({
                            Title = "GodMode GAGAL", 
                            Content = "Remote 'DamagePlayer' tidak ditemukan!", 
                            Duration = 6, 
                            Icon = "alert-triangle"
                        })
                        warn("[GodMode] Remote 'DamagePlayer' tidak ditemukan!")
                    end
                else
                    WindUI:Notify({
                        Title = "GodMode", 
                        Content = "DINONAKTIFKAN", 
                        Duration = 3, 
                        Icon = "shield-off"
                    })
                    print("[GodMode] GodMode dimatikan")
                end
            end
        })

        mainTab:Toggle({
            Title = "Anti AFK",
            Default = true,
            Callback = function(v)
                AntiAFKEnabled = v
            end
        })

        mainTab:Button({
            Title = "Shutdown Script",
            Variant = "Destructive",
            Callback = function()
                scriptDisabled = true
                
                -- Stop semua sistem
                stopFly()
                stopZone()
                fishingAutoClickEnabled = false
                AutoCookEnabled = false
                ScrapEnabled = false
                AutoSacEnabled = false
                KillAuraEnabled = false
                ChopAuraEnabled = false
                stopCoinAmmo()
                autoTemporalEnabled = false
                
                -- Stop semua loops dengan increment ID
                CookLoopId += 1
                ScrapLoopId += 1
                
                -- Stop webhook
                if DayDisplayConnection then 
                    DayDisplayConnection:Disconnect() 
                    DayDisplayConnection = nil 
                end
                WebhookEnabled = false
                -- Cleanup fishing
                fishingHideOverlay()
                pcall(function() 
                    if LocalPlayer.PlayerGui:FindFirstChild("XenoPositionOverlay") then
                        LocalPlayer.PlayerGui.XenoPositionOverlay:Destroy() 
                    end
                end)
                
                -- Hancurkan window
                if Window then
                    Window:Destroy()
                end
                
                warn("[PapiDimz] Script dimatikan")
            end
        })
    end)()
    ---------------------------------------------------------
    -- LOCAL PLAYER TAB CONTENT (SAMA dengan contekan.lua)
    ---------------------------------------------------------
    ;(function()
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
        localTab:Toggle({ Title = "Instant Open", Icon = "bolt", Default = false, Callback = function(state) if state then enableInstantOpen() else disableInstantOpen() end end })
        -- Tab 10: Fun (FRENESIS)
        local FunTab = Window:Tab({ Title = "Fun", Icon = "gamepad-2" })
    end)()
    ---------------------------------------------------------
    -- FISHING TAB CONTENT (ASLI)
    ---------------------------------------------------------
    ;(function()
        FishingTab:Paragraph({
            Title = "Fishing & Macro",
            Desc = "An automated fishing system featuring a 100% success rate (green zone), automatic recasting, and an auto-clicker.",
            Color = "Grey"
        })

        FishingTab:Toggle({
            Title = "100% Success Rate",
            Default = false,
            Callback = function(state)
                if state then startZone() else stopZone() end
            end
        })

        FishingTab:Toggle({
            Title = "Auto Recast",
            Default = false,
            Callback = function(state)
                autoRecastEnabled = state
            end
        })

        FishingTab:Input({
            Title = "Recast Delay (s)",
            Placeholder = "2",
            Default = "2",
            Callback = function(text)
                local n = tonumber(text)
                if n and n >= 0.01 and n <= 60 then
                    RECAST_DELAY = n
                end
            end
        })

        FishingTab:Toggle({
            Title = "View Position Overlay",
            Default = false,
            Callback = function(state)
                fishingOverlayVisible = state
                if state and fishingSavedPosition then
                    fishingShowOverlay(fishingSavedPosition.x, fishingSavedPosition.y)
                else
                    fishingHideOverlay()
                end
            end
        })

        FishingTab:Button({
            Title = "Set Position",
            Callback = function()
                waitingForPosition = not waitingForPosition
                WindUI:Notify({
                    Title = "Set Position",
                    Content = waitingForPosition and "Klik layar untuk set posisi." or "Dibatalkan.",
                    Duration = 3
                })
            end
        })

        FishingTab:Toggle({
            Title = "Auto Clicker",
            Default = false,
            Callback = function(state)
                fishingAutoClickEnabled = state
            end
        })

        FishingTab:Input({
            Title = "Delay (s)",
            Placeholder = "5",
            Default = "5",
            Callback = function(text)
                local n = tonumber(text)
                if n and n >= 0.01 and n <= 600 then
                    fishingClickDelay = n
                end
            end
        })

        FishingTab:Button({
            Title = "Calibrate",
            Callback = function()
                local cam = Workspace.CurrentCamera
                local cx = cam.ViewportSize.X / 2
                local cy = cam.ViewportSize.Y / 2
                WindUI:Notify({Title="Calibrate", Content="Klik titik merah di tengah layar.", Duration=4})
                
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
                        WindUI:Notify({
                            Title = "Calibrate Done",
                            Content = ("Offset X=%.1f Y=%.1f"):format(fishingOffsetX, fishingOffsetY),
                            Duration = 4
                        })
                        conn:Disconnect()
                        gui:Destroy()
                        if fishingOverlayVisible and fishingSavedPosition then
                            fishingShowOverlay(fishingSavedPosition.x, fishingSavedPosition.y)
                        end
                    end
                end)
            end
        })

        FishingTab:Button({
            Title = "Clean Fishing",
            Variant = "Destructive",
            Callback = function()
                fishingAutoClickEnabled = false
                waitingForPosition = false
                fishingSavedPosition = nil
                stopZone()
                fishingHideOverlay()
                pcall(function() LocalPlayer.PlayerGui.XenoPositionOverlay:Destroy() end)
                WindUI:Notify({Title="Fishing Clean", Content="Fishing features dibersihkan.", Duration=3})
            end
        })
    end)()
    ---------------------------------------------------------
    -- FARM TAB CONTENT (TERORGANISIR)
    ---------------------------------------------------------
    ;(function()
        -- Paragraph Combat Aura
        FarmTab:Paragraph({
            Title = "Combat Aura",
            Desc = "Kill Aura & Chop Aura for automatically clearing enemies and chopping down trees.\nThe radius is adjustable from 50 to 200.",
            Color = "Grey"
        })

        -- Kill Aura Toggle
        FarmTab:Toggle({
            Title = "Kill Aura (Radius-based)",
            Icon = "swords",
            Default = false,
            Callback = function(state)
                if scriptDisabled then return end
                KillAuraEnabled = state
                WindUI:Notify({
                    Title = "Kill Aura",
                    Content = state and "Kill Aura diaktifkan!" or "Kill Aura dimatikan.",
                    Duration = 3
                })
            end
        })

        -- Kill Aura Radius Slider
        FarmTab:Slider({
            Title = "Kill Aura Radius",
            Description = "Jarak Kill Aura (50 - 200).",
            Step = 1,
            Value = { Min = 50, Max = 200, Default = KillAuraRadius },
            Callback = function(value)
                KillAuraRadius = tonumber(value) or KillAuraRadius
            end
        })

        -- Chop Aura Toggle
        -- GANTI Toggle Chop Aura (sekitar baris 1312):
        FarmTab:Toggle({
            Title = "Chop Aura (" .. table.concat(SelectedTreeCategories, ", ") .. ")",
            Icon = "axe",
            Default = false,
            Callback = function(state)
                if scriptDisabled then return end
                ChopAuraEnabled = state
                if state then 
                    buildTreeCache() -- PASTIKAN panggil ini
                    WindUI:Notify({
                        Title = "Chop Aura",
                        Content = string.format("AKTIF untuk %s (%d trees ditemukan)", 
                            table.concat(SelectedTreeCategories, ", "), #TreeCache),
                        Duration = 4,
                        Icon = "zap"
                    })
                else 
                    TreeCache = {}
                    WindUI:Notify({
                        Title = "Chop Aura",
                        Content = "DIMATIKAN",
                        Duration = 3,
                        Icon = "toggle-left"
                    })
                end
            end
        })

        -- [DROPDOWN JENIS POHON] - Tambahkan di sini
        -- GANTI Dropdown UI menjadi MULTI-SELECT (sekitar baris 1340):
        FarmTab:Dropdown({
            Title = "Tree Categories",
            Description = "Pilih satu atau lebih kategori pohon untuk Chop Aura",
            Values = {"Small Tree", "Snowy Small Tree", "Big Tree"},
            Value = {"Small Tree"}, -- Default sebagai array
            Multi = true, -- ⬅️ INI PENTING: Aktifkan multi-select
            Callback = function(selectedValues)
                -- Pastikan selalu ada minimal satu pilihan
                if not selectedValues or #selectedValues == 0 then
                    selectedValues = {"Small Tree"}
                end
                
                SelectedTreeCategories = selectedValues
                WindUI:Notify({
                    Title = "Tree Categories Updated",
                    Content = string.format("Sekarang target: %s", table.concat(SelectedTreeCategories, ", ")),
                    Duration = 3,
                    Icon = "trees"
                })
                
                -- Jika ChopAura aktif, refresh cache
                if ChopAuraEnabled then
                    buildTreeCache()
                end
            end
        })

        -- Chop Aura Radius Slider
        FarmTab:Slider({
            Title = "Chop Aura Radius",
            Description = "Jarak tebang otomatis (50 - 200).",
            Step = 1,
            Value = { Min = 50, Max = 200, Default = ChopAuraRadius },
            Callback = function(value)
                ChopAuraRadius = tonumber(value) or ChopAuraRadius
            end
        })

        -- Paragraph Scrap Priority
        FarmTab:Paragraph({
            Title = "Scrap Priority",
            Desc = table.concat(ScrapItemsPriority, ", "),
            Color = "Grey"
        })

        -- Auto Crockpot
        FarmTab:Toggle({
            Title = "Auto Crockpot",
            Icon = "flame",
            Default = false,
            Callback = function(state)
                if scriptDisabled then return end
                if state then
                    local ok = ensureCookingStations()
                    if not ok then 
                        AutoCookEnabled = false
                        WindUI:Notify({
                            Title = "Auto Crockpot", 
                            Content = "Crock Pot / Chefs Station tidak ditemukan.", 
                            Duration = 4, 
                            Icon = "alert-triangle"
                        })
                        return 
                    end
                    AutoCookEnabled = true
                    startCookLoop()
                    WindUI:Notify({
                        Title = "Auto Crockpot",
                        Content = "Auto Crockpot diaktifkan!",
                        Duration = 4
                    })
                else 
                    AutoCookEnabled = false
                    WindUI:Notify({
                        Title = "Auto Crockpot",
                        Content = "Auto Crockpot dimatikan.",
                        Duration = 3
                    })
                end
            end
        })

        -- Auto Scrapper (HANYA 1 KALI)
        FarmTab:Toggle({
            Title = "Auto Scrapper",
            Icon = "recycle",
            Default = false,
            Callback = function(state)
                if scriptDisabled then return end
                if state then
                    local ok = ensureScrapperTargetFarm()
                    if not ok then
                        ScrapEnabled = false
                        WindUI:Notify({
                            Title = "Auto Scrapper",
                            Content = "Scrapper target tidak ditemukan.",
                            Duration = 4,
                            Icon = "alert-triangle"
                        })
                        return
                    end
                    ScrapEnabled = true
                    startScrapLoop()
                    WindUI:Notify({
                        Title = "Auto Scrapper",
                        Content = "Auto Scrapper diaktifkan!",
                        Duration = 4
                    })
                else
                    ScrapEnabled = false
                    WindUI:Notify({
                        Title = "Auto Scrapper",
                        Content = "Auto Scrapper dimatikan.",
                        Duration = 3
                    })
                end
            end
        })

        -- Auto Sacrifice Lava
        FarmTab:Toggle({
            Title = "Auto Sacrifice Lava",
            Icon = "flame-kindling",
            Default = false,
            Callback = function(state)
                if scriptDisabled then return end
                AutoSacEnabled = state
                if state then
                    WindUI:Notify({
                        Title = "Auto Sacrifice Lava",
                        Content = lavaFound and "Auto sacrifice diaktifkan!" or "Lava belum ditemukan, script akan aktif begitu lava ready.",
                        Duration = 4,
                        Icon = lavaFound and "check-circle" or "alert-triangle"
                    })
                else
                    WindUI:Notify({
                        Title = "Auto Sacrifice Lava",
                        Content = "Auto sacrifice dimatikan.",
                        Duration = 3
                    })
                end
            end
        })

        -- Ultra Fast Coin & Ammo
        FarmTab:Toggle({
            Title = "Ultra Fast Coin & Ammo",
            Icon = "zap",
            Default = false,
            Callback = function(state)
                if scriptDisabled then return end
                if state then
                    startCoinAmmo()
                    WindUI:Notify({
                        Title = "Coin & Ammo",
                        Content = "Auto collect diaktifkan!",
                        Duration = 4
                    })
                else
                    stopCoinAmmo()
                    WindUI:Notify({
                        Title = "Coin & Ammo",
                        Content = "Auto collect dimatikan.",
                        Duration = 3
                    })
                end
            end
        })
    end)()
    ---------------------------------------------------------
    -- NIGHT TAB CONTENT
    ---------------------------------------------------------
    ;(function()
        NightTab:Toggle({
            Title = "Auto Skip Malam (Temporal)",
            Icon = "moon-star",
            Default = false,
            Callback = function(state)
                if scriptDisabled then return end
                autoTemporalEnabled = state
                WindUI:Notify({
                    Title = "Auto Skip Malam",
                    Content = state and "Aktif: auto trigger saat Day naik." or "Dimatikan.",
                    Duration = 4,
                    Icon = state and "moon" or "toggle-left"
                })
            end
        })

        NightTab:Button({
            Title = "Trigger Temporal Sekali (Manual)",
            Icon = "zap",
            Callback = function()
                if scriptDisabled then return end
                activateTemporal()
                WindUI:Notify({
                    Title = "Temporal",
                    Content = "Temporal Accelerometer diaktifkan!",
                    Duration = 4
                })
            end
        })
    end)()
    ---------------------------------------------------------
    -- BRING SETTINGS (ORIGINAL - TIDAK DIUBAH)
    ---------------------------------------------------------
    ;(function()
        local setSec = BringTab:Section({Title="Bring Setting", Icon="settings", DefaultOpen=true})
        setSec:Dropdown({
            Title="Location",
            Values={"Player","Workbench","Fire"},
            Value="Player",
            Callback=function(v) selectedLocation=v end
        })
        setSec:Input({
            Title="Bring Height",
            Default="20",
            Numeric=true,
            Callback=function(v) BringHeight=tonumber(v) or 20 end
        })

        -- (SEMUA SECTION BRING ITEM YANG ASLI DIMASUKKAN DI SINI)
        -- Cultist Section
        do
            local list={"All","Crossbow Cultist","Cultist"}
            local sel={"All"}
            local sec=BringTab:Section({Title="Bring Cultist",Icon="skull",Collapsible=true})
            sec:Dropdown({Title="Pilih Cultist",Values=list,Value={"Crossbow Cultist","Cultist"},Multi=true,AllowNone=true,Callback=function(v)sel=v or{"All"}end})
            sec:Button({Title="Bring Cultist",Callback=function()bringItems(list,sel,selectedLocation)end})
        end

        -- Meteor Section
        do
            local list={"All","Raw Obsidiron Ore","Gold Shard","Meteor Shard","Scalding Obsidiron Ingot"}
            local sel={"All"}
            local sec=BringTab:Section({Title="Bring Meteor Items",Icon="zap",Collapsible=true})
            sec:Dropdown({Title="Pilih Item",Values=list,Value={"All"},Multi=true,AllowNone=true,Callback=function(v)sel=v or{"All"}end})
            sec:Button({Title="Bring Meteor",Callback=function()bringItems(list,sel,selectedLocation)end})
        end

        -- Fuel + Logs Section
        do
            local list={"All","Cultist","Crossbow Cultist","Log","Coal","Chair","Fuel Canister","Oil Barrel"}
            local sel={"All"}
            local sec=BringTab:Section({Title="Fuels",Icon="flame",Collapsible=true})
            sec:Dropdown({Title="Pilih Fuel",Values=list,Value={"Coal","Fuel Canister","Oil Barrel","Cultist","Crossbow Cultist"},Multi=true,AllowNone=true,Callback=function(v)sel=v or{"All"}end})
            sec:Button({Title="Bring Fuels",Callback=function()bringItems(list,sel,selectedLocation)end})
            sec:Button({Title="Bring Logs Only",Callback=function()bringItems(list,{"Log"},selectedLocation)end})
        end

        -- Food Section
        do
            local list={
                "All","Sweet Potato","Stuffing","Turkey Leg","Carrot","Pumkin","Mackerel",
                "Salmon","Swordfish","Berry","Ribs","Stew","Steak Dinner","Morsel","Steak",
                "Corn","Cooked Morsel","Cooked Steak","Chilli","Apple","Cake"
            }
            local sel={"All"}
            local sec=BringTab:Section({Title="Food",Icon="drumstick",Collapsible=true})
            sec:Dropdown({Title="Pilih Food",Values=list,Value={"All"},Multi=true,AllowNone=true,Callback=function(v)sel=v or{"All"}end})
            sec:Button({Title="Bring Food",Callback=function()bringItems(list,sel,selectedLocation)end})
        end

        -- Healing Section
        do
            local list={"All","Medkit","Bandage"}
            local sel={"All"}
            local sec=BringTab:Section({Title="Healing",Icon="heart",Collapsible=true})
            sec:Dropdown({Title="Pilih Healing",Values=list,Value={"All"},Multi=true,AllowNone=true,Callback=function(v)sel=v or{"All"}end})
            sec:Button({Title="Bring Healing",Callback=function()bringItems(list,sel,selectedLocation)end})
        end

        -- Gears Section
        do
            local list={
                "All","Bolt","Tyre","Sheet Metal","Old Radio","Broken Fan","Broken Microwave",
                "Washing Machine","Old Car Engine","UFO Scrap","UFO Component","UFO Junk",
                "Cultist Gem","Gem of the Forest"
            }
            local sel={"All"}
            local sec=BringTab:Section({Title="Gears (Scrap)",Icon="wrench",Collapsible=true})
            sec:Dropdown({Title="Pilih Gear",Values=list,Value={"All"},Multi=true,AllowNone=true,Callback=function(v)sel=v or{"All"}end})
            sec:Button({Title="Bring Gears",Callback=function()bringItems(list,sel,selectedLocation)end})
        end

        -- Guns & Ammo Section
        do
            local list={
                "All","Infernal Sword","Morningstar","Crossbow","Infernal Crossbow","Laser Sword",
                "Raygun","Ice Axe","Ice Sword","Chainsaw","Strong Axe","Axe Trim Kit","Spear",
                "Good Axe","Revolver","Rifle","Tactical Shotgun","Revolver Ammo","Rifle Ammo",
                "Alien Armour","Frog Boots","Leather Body","Iron Body","Thorn Body",
                "Riot Shield","Armour Trim Kit","Obsidiron Boots"
            }
            local sel={"All"}
            local sec=BringTab:Section({Title="Guns & Ammo",Icon="swords",Collapsible=true})
            sec:Dropdown({Title="Pilih Weapon",Values=list,Value={"All"},Multi=true,AllowNone=true,Callback=function(v)sel=v or{"All"}end})
            sec:Button({Title="Bring Guns & Ammo",Callback=function()bringItems(list,sel,selectedLocation)end})
        end

        -- Other Items Section
        do
            local list={
                "All","Purple Fur Tuft","Halloween Candle","Candy","Frog Key","Feather",
                "Wildfire","Sacrifice Totem","Old Rod","Flower","Coin Stack","Infernal Sack",
                "Giant Sack","Good Sack","Seed Box","Chainsaw","Old Flashlight",
                "Strong Flashlight","Bunny Foot","Wolf Pelt","Bear Pelt","Mammoth Tusk",
                "Alpha Wolf Pelt","Bear Corpse","Meteor Shard","Gold Shard",
                "Raw Obsidiron Ore","Gem of the Forest","Diamond","Defense Blueprint"
            }
            local sel={"All"}
            local sec=BringTab:Section({Title="Bring Other",Icon="package",Collapsible=true})
            sec:Dropdown({Title="Pilih Item",Values=list,Value={"All"},Multi=true,AllowNone=true,Callback=function(v)sel=v or{"All"}end})
            sec:Button({Title="Bring Other",Callback=function()bringItems(list,sel,selectedLocation)end})
        end
    end)()
    ---------------------------------------------------------
    -- TELEPORT TAB CONTENT
    ---------------------------------------------------------
    -- LOST CHILD
    ;(function()
        local lostChildSec = TeleportTab:Section({
            Title = "Teleport Lost Child",
            Icon = "baby",
            Collapsible = true,
            DefaultOpen = true
        })

        local childOptions = {"DinoKid", "KoalaKid", "KrakenKid", "SquidKid"}
        local selectedChild = "DinoKid"

        lostChildSec:Dropdown({
            Title = "Select Child",
            Values = childOptions,
            Value = "DinoKid",
            Callback = function(v)
                selectedChild = v
            end
        })

        lostChildSec:Button({
            Title = "Teleport To Child",
            Callback = function()
                local chars = Workspace:FindFirstChild("Characters")
                if not chars then return end

                local targetHRP = nil

                if selectedChild == "DinoKid" then
                    targetHRP = chars:FindFirstChild("Lost Child")
                elseif selectedChild == "KoalaKid" then
                    targetHRP = chars:FindFirstChild("Lost Child4")
                elseif selectedChild == "KrakenKid" then
                    targetHRP = chars:FindFirstChild("Lost Child2")
                elseif selectedChild == "SquidKid" then
                    targetHRP = chars:FindFirstChild("Lost Child3")
                end

                local hrp = targetHRP and targetHRP:FindFirstChild("HumanoidRootPart")
                teleportToCFrame(hrp and hrp.CFrame)
            end
        })
    end)()
    ---------------------------------------------------------
    -- STRUCTURE TELEPORT
    ---------------------------------------------------------
    ;(function()
        local structureSec = TeleportTab:Section({
            Title = "Structure Teleport",
            Icon = "castle",
            Collapsible = true,
            DefaultOpen = false
        })

        -- CAMP
        structureSec:Button({
            Title = "Teleport to Camp",
            Callback = function()
                local fire = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Campground")
                    and Workspace.Map.Campground:FindFirstChild("MainFire")
                    and Workspace.Map.Campground.MainFire:FindFirstChild("OuterTouchZone")

                teleportToCFrame(fire and fire.CFrame)
            end
        })

        -- CULTIST GENERATOR
        structureSec:Button({
            Title = "Teleport to Cultist Generator Base",
            Callback = function()
                local cg = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("CultistGenerator")

                teleportToCFrame(cg and cg.PrimaryPart and cg.PrimaryPart.CFrame)
            end
        })

        -- STRONGHOLD
        structureSec:Button({
            Title = "Teleport to Stronghold",
            Callback = function()
                local sign = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("Stronghold")
                    and Workspace.Map.Landmarks.Stronghold:FindFirstChild("Building")
                    and Workspace.Map.Landmarks.Stronghold.Building:FindFirstChild("Sign")
                    and Workspace.Map.Landmarks.Stronghold.Building.Sign:FindFirstChild("Main")

                teleportToCFrame(sign and sign.CFrame)
            end
        })

        -- STRONGHOLD DIAMOND CHEST
        structureSec:Button({
            Title = "Teleport to Stronghold Diamond Chest",
            Callback = function()
                local chest = Workspace:FindFirstChild("Items")
                    and Workspace.Items:FindFirstChild("Stronghold Diamond Chest")

                teleportToCFrame(chest and chest.CFrame)
            end
        })

        -- CARAVAN
        structureSec:Button({
            Title = "Teleport to Caravan",
            Callback = function()
                local caravan = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("Caravan")

                teleportToCFrame(caravan and caravan.PrimaryPart and caravan.PrimaryPart.CFrame)
            end
        })

        -- FAIRY
        structureSec:Button({
            Title = "Teleport to Fairy",
            Callback = function()
                local fairy = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("Fairy House")
                    and Workspace.Map.Landmarks["Fairy House"]:FindFirstChild("Fairy")
                    and Workspace.Map.Landmarks["Fairy House"].Fairy:FindFirstChild("HumanoidRootPart")

                teleportToCFrame(fairy and fairy.CFrame)
            end
        })

        -- ANVIL
        structureSec:Button({
            Title = "Teleport to Anvil",
            Callback = function()
                local anvil = Workspace:FindFirstChild("Map")
                    and Workspace.Map:FindFirstChild("Landmarks")
                    and Workspace.Map.Landmarks:FindFirstChild("ToolWorkshop")
                    and Workspace.Map.Landmarks.ToolWorkshop:FindFirstChild("Functional")
                    and Workspace.Map.Landmarks.ToolWorkshop.Functional:FindFirstChild("ToolBench")
                    and Workspace.Map.Landmarks.ToolWorkshop.Functional.ToolBench:FindFirstChild("Hammer")

                teleportToCFrame(anvil and anvil.CFrame)
            end
        })
    end)()
    ---------------------------------------------------------
    -- UPDATE FOCUSED TAB
    ---------------------------------------------------------
    ;(function()
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
            Callback=function(v)selectedOpt=v end
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
    end)()

    -- Inisialisasi karakter untuk semua sistem
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.4) -- Beri sedikit delay untuk stabilisasi
        -- Untuk Papi Dimz system
        humanoid = char:WaitForChild("Humanoid")
        rootPart = char:WaitForChild("HumanoidRootPart")
        defaultWalkSpeed = humanoid.WalkSpeed
        -- Untuk Bring Item system (variabel yang sama)
        Character = char
        HumanoidRootPart = rootPart
        print("[Character] Loaded.")
    end)

    if LocalPlayer.Character then
        humanoid = getHumanoid()
        rootPart = getRoot()
        if humanoid then
            defaultWalkSpeed = humanoid.WalkSpeed
        end
    end

    ---------------------------------------------------------
    -- WEBHOOK TAB CONTENT (SAMA dengan contekan.lua)
    ---------------------------------------------------------
    WebhookTab:Input({ Title = "Discord Webhook URL", Icon = "link", Placeholder = WebhookURL, Numeric = false, Finished = false, Callback = function(txt) local t = trim(txt or "") if t ~= "" then WebhookURL = t; WindUI:Notify({Title="Webhook", Content="URL disimpan.", Duration=3, Icon="link"}); print("WebhookURL set:", WebhookURL) end end })
    WebhookTab:Input({ Title = "Webhook Username (opsional)", Icon = "user", Placeholder = WebhookUsername, Numeric = false, Finished = false, Callback = function(txt) local t = trim(txt or "") if t ~= "" then WebhookUsername = t end; WindUI:Notify({Title="Webhook", Content="Username disimpan: " .. tostring(WebhookUsername), Duration=3, Icon="user"}) end })
    WebhookTab:Toggle({ Title = "Enable Webhook DayDisplay", Icon = "radio", Default = WebhookEnabled, Callback = function(state) WebhookEnabled = state; WindUI:Notify({Title="Webhook", Content=state and "Webhook diaktifkan." or "Webhook dimatikan.", Duration=3, Icon=state and "check-circle-2" or "x-circle"}) end })
    WebhookTab:Button({ Title = "Test Send Webhook", Icon = "flask-conical", Callback = function()
        if scriptDisabled then return end
        local players = Players:GetPlayers(); local names = {}
        for _, p in ipairs(players) do table.insert(names, p.Name) end
        local payload = { username = WebhookUsername, embeds = {{ title = "🧪 TEST - Webhook Aktif " .. tostring(WebhookUsername), description = ("**Webhook Aktif %s**\n\n**Progress:** `%s`\n\n**Pemain Aktif:**\n%s"):format(tostring(WebhookUsername), tostring(currentDayCached), namesToVerticalList(names)), color = 0x2ECC71, footer = { text = "Test sent: " .. os.date("%Y-%m-%d %H:%M:%S") }}}}
        local ok, msg = sendWebhookPayload(payload)
        if ok then WindUI:Notify({Title="Webhook Test", Content="Terkirim: " .. tostring(msg), Duration=5, Icon="check-circle-2"}); print("Webhook Test success:", msg)
        else WindUI:Notify({Title="Webhook Test Failed", Content=tostring(msg), Duration=8, Icon="alert-triangle"}); warn("Webhook Test failed:", msg) end
    end})

    ;(function()
        -- SECTION 1: REVEAL MAP
        FunTab:Paragraph({
            Title = "🌀 FRENESIS - 99 Night Explorer",
            Desc = "Fitur eksplorasi dan penanaman otomatis",
            Color = "Grey"
        })
        
        FunTab:Section({ Title = "🔍 Reveal Map", DefaultOpen = true })
        
        FunTab:Button({
            Title = "🌀 Start/Stop Spiral Flight",
            Description = "Terbang dengan pola spiral untuk melihat map",
            Callback = function()
                if spiralActive then 
                    stopSpiralFlight()
                    notifyUI("Spiral Flight", "Dihentikan", 3, "pause")
                else 
                    startSpiralFlight()
                    notifyUI("Spiral Flight", "Dimulai", 3, "play")
                end
            end
        })
        
        FunTab:Button({
            Title = "📍 Teleport to Ground",
            Description = "Teleport ke posisi ground",
            Callback = function()
                local r = getRoot()
                if r then 
                    r.CFrame = CFrame.new(groundPosition)
                    notifyUI("Teleport", "Ke ground position", 2, "navigation")
                end
            end
        })
        
        -- SECTION 2: OVERLAY SYSTEM
        FunTab:Section({ Title = "📐 Overlay System" })
        
        FunTab:Toggle({
            Title = "Show Overlay",
            Description = "Tampilkan overlay di workspace",
            Default = false,
            Callback = function(v)
                overlayVisible = v
                updateOverlay()
                notifyUI("Overlay", v and "Aktif" or "Nonaktif", 2, v and "eye" or "eye-off")
            end
        })
        
        FunTab:Dropdown({
            Title = "Select Shape",
            Values = overlayShapes,
            Default = "circle",
            Callback = function(v)
                overlayShape = v
                if overlayVisible then updateOverlay() end
                notifyUI("Overlay Shape", "Bentuk: " .. v, 2, "shapes")
            end
        })
        
        FunTab:Slider({
            Title = "Overlay Points",
            Description = "Jumlah titik overlay",
            Step = 1,
            Value = { Min = 10, Max = 500, Default = 50 },
            Callback = function(v)
                overlayPoints = math.floor(v)
                if overlayVisible then updateOverlay() end
            end
        })
        
        FunTab:Slider({
            Title = "Overlay Radius",
            Description = "Radius overlay (studs)",
            Step = 1,
            Value = { Min = 10, Max = 200, Default = 100 },
            Callback = function(v)
                overlayRadius = math.floor(v)
                if overlayVisible then updateOverlay() end
            end
        })
        
        -- SECTION 3: AUTO CHEST OPENER
        FunTab:Section({ Title = "🎁 Auto Chest Opener" })
        
        FunTab:Toggle({
            Title = "Auto Open All Chest",
            Description = "ON: Scan dan buka semua chest otomatis",
            Default = false,
            Callback = function(v)
                if v then
                    startAutoOpenChests()
                else
                    stopAutoOpenChests()
                end
            end
        })
        
        FunTab:Slider({
            Title = "Chest Open Delay",
            Description = "Delay antara membuka chest (detik)",
            Step = 0.1,
            Value = { Min = 0.1, Max = 1, Default = 0.3 },
            Callback = function(v) 
                chestOpeningSpeed = math.floor(v * 10) / 10
            end
        })
        
        FunTab:Button({
            Title = "🔍 Scan Chest Sekarang",
            Description = "Scan semua chest di map",
            Callback = function()
                local chests = findAllChests()
                notifyUI("Chest Scanner", "Ditemukan " .. #chests .. " chest!", 3, "search")
            end
        })
        
        -- SECTION 4: LOG WALL SYSTEM
        FunTab:Section({ Title = "🧱 Log Wall System" })
        
        FunTab:Button({
            Title = "🔍 Scan Log Wall Blueprint",
            Description = "Cari Log Wall Blueprint di inventory",
            Callback = function()
                -- Fungsi sederhana untuk mengecek blueprint
                local inventory = LocalPlayer:FindFirstChild("Inventory")
                local found = false
                if inventory then
                    for _, item in ipairs(inventory:GetChildren()) do
                        if string.find(item.Name:lower(), "log") and string.find(item.Name:lower(), "wall") then
                            found = true
                            break
                        end
                    end
                end
                
                if found then
                    notifyUI("Log Wall", "Blueprint ditemukan di inventory!", 3, "check-circle")
                else
                    notifyUI("Log Wall", "Blueprint TIDAK ditemukan", 3, "alert-triangle")
                end
            end
        })
        
        -- SECTION 5: INFO
        FunTab:Section({ Title = "ℹ️ FRENESIS Info" })
        
        FunTab:Label({
            Title = "🌀 FRENESIS - 99 Night Explorer",
            Description = "v1.0 | Integrasi ke Papi Dimz HUB"
        })
        
        FunTab:Label({
            Title = "Fitur yang tersedia:",
            Description = "• Spiral Flight untuk explore map\n• Overlay System dengan multiple shapes\n• Auto Chest Opener\n• Log Wall System (basic)"
        })
        
        FunTab:Label({
            Title = "Kontrol:",
            Description = "• F1: Toggle UI Visibility (jika diaktifkan)\n• Gunakan slider untuk mengatur parameter"
        })
    end)()
    ---------------------------------------------------------
    -- FINAL INITIALIZATION & ERROR SAFETY
    ---------------------------------------------------------
    -- 1. Pastikan remote events untuk farm system sudah diambil
    task.spawn(function()
        initRemoteEvents()
        -- Coba hook DayDisplay untuk webhook
        pcall(tryHookDayDisplay)
    end)

    task.spawn(function()
        tryHookDayDisplay() -- Pasang listener DayDisplay untuk webhook
    end)

    -- 2. Pastikan tidak ada konflik variabel ScrapperTarget
    -- (Pastikan Anda sudah mengganti semua 'ScrapperTarget' di farm system menjadi 'ScrapperTargetFarm')

    -- 3. Auto-sacrifice loop safety
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

    -- 4. Global shutdown handler yang lebih bersih
    local function globalShutdown()
        scriptDisabled = true
        GodmodeEnabled = false
        GodmodeLoopActive = false  -- ⬅️ INI PENTING
        print("[SHUTDOWN] Mematikan semua sistem...")
        
        -- Hentikan semua loops dengan ID
        CookLoopId += 1
        ScrapLoopId += 1
        
        -- Hentikan semua koneksi runtime
        if flyEnabled then stopFly() end
        if zoneEnabled then stopZone() end
        stopCoinAmmo()
        if auraHeartbeatConnection then
            auraHeartbeatConnection:Disconnect()
        end
        if DayDisplayConnection then
            DayDisplayConnection:Disconnect()
        end
        
        -- Hapus GUI
        pcall(function() fishingHideOverlay() end)
        if Window then
            Window:Destroy()
        end
        warn("[PapiDimz] SHUTDOWN COMPLETE")
    end

    -- Assign ke tombol shutdown di Main Tab (jika belum)
    -- mainTab:Button({ Title = "Shutdown Script", Callback = globalShutdown })

    ---------------------------------------------------------
    -- INISIALISASI GODMODE & ANTI-AFK
    ---------------------------------------------------------
    task.spawn(function()
        task.wait(2) -- Tunggu game load
        initRemoteEvents()
        
        -- Coba hook DayDisplay untuk webhook
        pcall(tryHookDayDisplay)
        
        -- Start GodMode loop jika diaktifkan default
        if GodmodeEnabled and DamagePlayerRemote then
            startGodmodeLoop()
        end
        
        -- Setup Anti-AFK
        LocalPlayer.Idled:Connect(function()
            if scriptDisabled then return end
            if not AntiAFKEnabled then return end
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            print("[Anti-AFK] Triggered anti-AFK")
        end)
    end)

    -- Inisialisasi overlay secara berkala
    task.spawn(function()
        while not scriptDisabled do
            task.wait(1)
            if overlayVisible then
                updateOverlay()
            end
        end
    end)

    -- Input handler untuk F1 (toggle UI)
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.F1 and Window then
            Window.Visible = not Window.Visible
            notifyUI("UI", "Window " .. (Window.Visible and "ditampilkan" or "disembunyikan"), 2, "monitor")
        end
    end)
    ---------------------------------------------------------
    -- LOADED NOTIFICATION (FINAL)
    ---------------------------------------------------------
    task.wait(1) -- Beri waktu untuk inisialisasi
    WindUI:Notify({
        Title = "✅ Papi Dimz Ultimate Hub Siap!",
        Content = "Semua sistem loaded. Periksa console untuk error.",
        Icon = "check-circle",
        Duration = 8
    })
    print([[
    [PapiDimz] MERGE COMPLETE
    ===========================
    - Bring Item System: READY
    - Teleport System: READY
    - Local Player Mods: READY
    - Fishing Macro: READY
    - Farm System: READY
    - Combat Aura: READY
    - Webhook: READY
    ===========================
    ]])

    ---------------------------------------------------------
    -- LOADED NOTIFICATION
    ---------------------------------------------------------
    WindUI:Notify({
        Title = "Papi Dimz Ultimate Hub Loaded!",
        Content = "All Features: Main + Local Player + Bring Item + Teleport + Update Focused + Fishing + Farm + Night Skip + Webhook",
        Icon = "sparkles",
        Duration = 10
    })
    end -- 🔥 Tutup fungsi main()
main() -- 🔥 Jalankan fungsi utama
