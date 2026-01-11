-- FRENESIS | 99 Night Explorer
-- COMPLETE SCRIPT WITH AUTO CHEST OPENER (WindUI Notifications)

---------------------------------------------------------
-- SERVICES
---------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------
-- CORE STATE
---------------------------------------------------------
local scriptActive = true

-- POSITION
local groundPosition = Vector3.new(0, 6, 0)

-- SPIRAL
local spiralActive = false
local spiralThread
local spiralCenter = Vector3.new(0, 50, 0)
local flySpeed = 300

-- OVERLAY
local overlayVisible = false
local overlayParts = {}
local overlayRadius = 100
local overlayHeight = 3
local overlayCenter = Vector3.new(1, overlayHeight, 1)
local overlayPoints = 50

-- OVERLAY SHAPE SYSTEM
local overlayShape = "circle"
local overlayShapes = {"circle", "square", "triangle", "star", "hexagon", "spiral", "diamond"}

-- SAPLING
local plantingActive = false
local plantingThread
local plantingMode = "character"
local plantInterval = 0.5
local infiniteSaplingEnabled = false
local plantSequenceIndex = 1
local totalPlanted = 0
local maxPlantPoints = 0
local plantingCompleted = false

-- [TAMBAHKAN DI CORE STATE] setelah variabel sapling
local logWallActive = false
local logWallThread = nil
local placeStructureRemote = nil
-- local logWallBlueprint = nil
local allBlueprints = {} -- Array untuk menyimpan semua blueprint
local blueprintIndex = 1 -- Index blueprint yang sedang digunakan

-- Tambahkan di CORE STATE
local angleIncrement = 2  -- Default 2 layer
local radiusIncrement = 10  -- +10 per layer

-- INFINITE SAPLING SETTINGS
local INFINITE_SHOW_MARKER = true
local INFINITE_MARKER_LIFETIME = 3
local characterPlantHistory = {}

-- AUTO CHEST OPENER
local isOpeningChests = false
local chestOpeningThread = nil
local chestOpeningSpeed = 0.3 -- default delay
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
local openedChests = {} -- Untuk menyimpan chest yang sudah dibuka

-- WindUI Global
local WindUI

---------------------------------------------------------
-- WINDUI NOTIFICATION HELPER
---------------------------------------------------------
local function showWindUINotification(title, message, notificationType, duration)
    if not WindUI then return end
    
    -- Validasi parameter
    title = title or "FRENESIS"
    message = message or ""
    notificationType = notificationType or "Info"
    duration = duration or 3
    
    -- Tampilkan notifikasi menggunakan WindUI
    WindUI:Notify({
        Title = title,
        Content = message,
        Duration = duration,
        Type = notificationType  -- "Success", "Error", "Warning", "Info"
    })
end

---------------------------------------------------------
-- REMOTES
---------------------------------------------------------
local function findPlantRemote()
    if ReplicatedStorage:FindFirstChild("RemoteEvents") then
        local r = ReplicatedStorage.RemoteEvents:FindFirstChild("RequestPlantItem")
        if r then return r end
    end
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.Name:lower() == "requestplantitem" then
            return v
        end
    end
end

local PlantRemote = findPlantRemote()

-- [TAMBAHKAN DI BAGIAN REMOTES] setelah PlantRemote
local function findPlaceStructureRemote()
    if ReplicatedStorage:FindFirstChild("RemoteEvents") then
        local r = ReplicatedStorage.RemoteEvents:FindFirstChild("RequestPlaceStructure")
        if r then return r end
    end
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.Name:lower() == "requestplacestructure" then
            return v
        end
    end
end

placeStructureRemote = findPlaceStructureRemote()

-- [FUNGSI UNTUK MENDAPATKAN LOG WALL BLUEPRINT DARI INVENTORY SAJA]
local function findLogWallBlueprint()
    local player = LocalPlayer
    local inventory = player:FindFirstChild("Inventory")
    
    if not inventory then
        warn("[FRENESIS] Inventory tidak ditemukan!")
        return nil
    end
    
    -- Kumpulkan SEMUA blueprint yang ada
    local allBlueprints = {}
    
    -- Cari dengan nama tepat
    for _, item in ipairs(inventory:GetChildren()) do
        if item.Name == "Log Wall Blueprint" then
            table.insert(allBlueprints, item)
        end
    end
    
    -- Jika tidak ditemukan dengan nama tepat, cari dengan pola
    if #allBlueprints == 0 then
        for _, item in ipairs(inventory:GetChildren()) do
            if string.find(item.Name:lower(), "log") and string.find(item.Name:lower(), "wall") then
                table.insert(allBlueprints, item)
            end
        end
    end
    
    -- Kembalikan blueprint pertama yang ditemukan
    if #allBlueprints > 0 then
        return allBlueprints[1]
    end
    
    return nil
end

local function countLogWallBlueprints()
    local player = LocalPlayer
    local inventory = player:FindFirstChild("Inventory")
    local count = 0
    
    if inventory then
        -- Hitung dengan nama tepat
        for _, item in ipairs(inventory:GetChildren()) do
            if item.Name == "Log Wall Blueprint" then
                count = count + 1
            end
        end
        
        -- Jika tidak ada dengan nama tepat, hitung dengan pola
        if count == 0 then
            for _, item in ipairs(inventory:GetChildren()) do
                if string.find(item.Name:lower(), "log") and string.find(item.Name:lower(), "wall") then
                    count = count + 1
                end
            end
        end
    end
    
    return count
end

-- [FUNGSI UNTUK MENEMPATKAN LOG WALL]
local function placeLogWallAtPosition(position, index, totalPoints)
    if not placeStructureRemote then
        warn("[FRENESIS] RequestPlaceStructure remote tidak ditemukan!")
        return false
    end
    
    local blueprint = findLogWallBlueprint()
    if not blueprint then
        warn("[FRENESIS] Log Wall Blueprint tidak ditemukan di inventory!")
        return false
    end
    
    -- HITUNG ROTASI BERDASARKAN POSISI DALAM OVERLAY
    local rotationY = 0
    
    if overlayShape == "circle" then
        -- Untuk lingkaran: hitung sudut berdasarkan posisi
        local angle = (index / totalPoints) * math.pi * 2
        rotationY = angle
        
    elseif overlayShape == "square" then
        -- Untuk persegi: tentukan sisi mana
        local localPos = position - overlayCenter
        local side = ""
        
        if math.abs(localPos.X) > math.abs(localPos.Z) then
            -- Sisi kiri/kanan
            side = localPos.X > 0 and "right" or "left"
            rotationY = (side == "right") and math.rad(90) or math.rad(270)
        else
            -- Sisi atas/bawah
            side = localPos.Z > 0 and "top" or "bottom"
            rotationY = (side == "top") and math.rad(0) or math.rad(180)
        end
        
    elseif overlayShape == "triangle" then
        -- Untuk segitiga: 3 sisi dengan rotasi berbeda
        local angle = (index % 3) * math.rad(120)
        rotationY = angle
        
    elseif overlayShape == "star" then
        -- Untuk bintang: pattern khusus
        rotationY = (index * math.rad(72)) % math.rad(360)
        
    else
        -- Default: menghadap keluar dari pusat
        local direction = (position - overlayCenter)
        direction = Vector3.new(direction.X, 0, direction.Z)
        if direction.Magnitude > 0 then
            rotationY = math.atan2(-direction.Z, direction.X)
        end
    end
    
    -- Buat CFrame dengan rotasi yang tepat
    local cframe = CFrame.new(position) * CFrame.Angles(0, rotationY, 0)
    
    -- Buat table argument sesuai dengan yang dibutuhkan remote
    local argsTable = {
        CFrame = cframe,
        Position = position,
        Valid = true
    }
    
    -- Argumen ketiga: CFrame rotasi saja (tanpa posisi)
    local rotOnly = CFrame.new(0, 0, 0, cframe.RightVector, cframe.UpVector, cframe.LookVector)
    
    -- Coba panggil remote
    local success, result = pcall(function()
        return placeStructureRemote:InvokeServer(blueprint, argsTable, rotOnly)
    end)
    
    if success then
        return true
    else
        warn("[FRENESIS] Gagal menempatkan Log Wall:", result)
        return false
    end
end

-- [FUNGSI AUTO PLACE LOG WALL]
local function startAutoLogWall()
    if logWallActive then return end
    
    if #overlayParts == 0 then
        showWindUINotification(
            "Log Wall System",
            "⚠ Overlay tidak aktif/tidak ada titik!\n" ..
            "Aktifkan overlay terlebih dahulu.",
            "Warning",
            3
        )
        return
    end
    
    -- Hitung blueprint yang tersedia
    local blueprintCount = countLogWallBlueprints()
    if blueprintCount == 0 then
        showWindUINotification(
            "Log Wall System",
            "✗ Tidak ada Log Wall Blueprint di inventory!",
            "Error",
            5
        )
        return
    end
    
    local totalPoints = #overlayParts
    local maxPlaceable = math.min(blueprintCount, totalPoints)
    
    logWallActive = true
    local placedCount = 0
    local failedCount = 0
    
    showWindUINotification(
        "Log Wall System",
        "▶ Memulai penempatan Log Wall...\n" ..
        "Titik overlay: " .. totalPoints .. "\n" ..
        "Blueprint tersedia: " .. blueprintCount .. "\n" ..
        "Bentuk: " .. overlayShape,
        "Info",
        4
    )
    
    logWallThread = task.spawn(function()
        for i, overlayPart in ipairs(overlayParts) do
            if not logWallActive then break end
            
            -- Cek apakah masih ada blueprint
            if countLogWallBlueprints() == 0 then
                showWindUINotification(
                    "Log Wall System",
                    "⚠ Blueprint habis, menghentikan...",
                    "Warning",
                    3
                )
                break
            end
            
            -- KIRIM INDEX i dan totalPoints untuk perhitungan rotasi
            local success = placeLogWallAtPosition(overlayPart.Position, i, totalPoints)
            
            if success then
                placedCount = placedCount + 1
                -- Ubah warna part overlay untuk menandai sudah ditempati
                overlayPart.Color = Color3.fromRGB(255, 100, 100)
                overlayPart.Transparency = 0.1
                
                -- Tampilkan notifikasi setiap 5 log wall yang berhasil
                if placedCount % 5 == 0 then
                    local remaining = countLogWallBlueprints()
                    local progress = math.floor((i / totalPoints) * 100)
                    showWindUINotification(
                        "Log Wall Progress",
                        "Progress: " .. progress .. "%\n" ..
                        "Berhasil: " .. placedCount .. " / " .. maxPlaceable .. "\n" ..
                        "Blueprint tersisa: " .. remaining,
                        "Success",
                        2
                    )
                end
            else
                failedCount = failedCount + 1
            end
            
            -- Delay antar penempatan
            task.wait(0.3)
        end
        
        -- Selesai
        logWallActive = false
        
        -- Tampilkan summary
        local summary = "✅ Penempatan Log Wall selesai!\n" ..
                       "Berhasil: " .. placedCount .. "\n" ..
                       "Gagal: " .. failedCount .. "\n" ..
                       "Blueprint tersisa: " .. countLogWallBlueprints()
        
        showWindUINotification(
            "Log Wall System - Selesai",
            summary,
            "Success",
            6
        )
        
        -- Reset warna overlay setelah selesai
        task.wait(2)
        if overlayVisible then
            updateOverlay()
        end
    end)
end

local function getRotationForShape(position, index, totalPoints, shape)
    if shape == "circle" then
        -- Lingkaran: menghadap keluar dari pusat
        local direction = (position - overlayCenter)
        direction = Vector3.new(direction.X, 0, direction.Z)
        if direction.Magnitude > 0 then
            return math.atan2(-direction.Z, direction.X)
        end
        
    elseif shape == "square" then
        -- Persegi: menghadap tegak lurus sisi
        local localPos = position - overlayCenter
        if math.abs(localPos.X) > math.abs(localPos.Z) then
            -- Sisi kiri/kanan: menghadap ke atas/bawah
            return (localPos.X > 0) and math.rad(90) or math.rad(270)
        else
            -- Sisi atas/bawah: menghadap ke kiri/kanan
            return (localPos.Z > 0) and math.rad(0) or math.rad(180)
        end
        
    elseif shape == "triangle" then
        -- Segitiga: 120 derajat per sisi
        return (index % 3) * math.rad(120)
        
    elseif shape == "hexagon" then
        -- Hexagon: 60 derajat per sisi
        return (index % 6) * math.rad(60)
        
    elseif shape == "star" then
        -- Bintang: pattern 72 derajat
        return (index * math.rad(72)) % math.rad(360)
        
    elseif shape == "diamond" then
        -- Diamond: 45 derajat offset
        local angle = (index % 8) * math.rad(45)
        return angle + math.rad(22.5)  -- Offset untuk diamond
    end
    
    return 0
end

-- [FUNGSI STOP AUTO LOG WALL]
local function stopAutoLogWall()
    logWallActive = false
    if logWallThread then
        task.cancel(logWallThread)
        logWallThread = nil
    end
    showWindUINotification(
        "Log Wall System",
        "⏹ Penempatan Log Wall dihentikan",
        "Info",
        3
    )
end

-- Remote untuk chest
local RequestOpenItemChest
if ReplicatedStorage:FindFirstChild("RemoteEvents") then
    RequestOpenItemChest = ReplicatedStorage.RemoteEvents:WaitForChild("RequestOpenItemChest")
end

---------------------------------------------------------
-- AUTO CHEST OPENER FUNCTIONS (with WindUI Notifications)
---------------------------------------------------------
local function findAllChests()
    local foundChests = {}
    
    -- Cari di folder Items
    local itemsFolder = Workspace:FindFirstChild("Items")
    if itemsFolder then
        for _, chestType in ipairs(chestTypes) do
            local chests = itemsFolder:GetChildren()
            for _, chest in ipairs(chests) do
                if chest:IsA("Model") and chest.Name == chestType then
                    -- Periksa apakah ini benar chest dengan melihat adanya ChestLid
                    local hasLid = false
                    for _, child in ipairs(chest:GetChildren()) do
                        if child:IsA("Model") and child.Name == "ChestLid" then
                            hasLid = true
                            break
                        end
                    end
                    
                    if hasLid then
                        table.insert(foundChests, {
                            instance = chest,
                            name = chest.Name,
                            parent = "Items",
                            position = chest:GetPivot().Position
                        })
                    end
                end
            end
        end
    end
    
    -- Cari di seluruh workspace untuk chest lain
    for _, chestType in ipairs(chestTypes) do
        local allChests = Workspace:GetDescendants()
        for _, obj in ipairs(allChests) do
            if obj:IsA("Model") and obj.Name == chestType then
                -- Skip jika sudah ditemukan di Items
                local alreadyFound = false
                for _, found in ipairs(foundChests) do
                    if found.instance == obj then
                        alreadyFound = true
                        break
                    end
                end
                
                if not alreadyFound then
                    -- Periksa apakah ini chest dengan melihat anaknya atau namanya
                    local hasLid = false
                    for _, child in ipairs(obj:GetChildren()) do
                        if child:IsA("Model") and (child.Name == "ChestLid" or string.find(child.Name:lower(), "lid")) then
                            hasLid = true
                            break
                        end
                    end
                    
                    -- Untuk ChristmasPresent1, terima saja sebagai chest
                    if hasLid or chestType == "ChristmasPresent1" then
                        table.insert(foundChests, {
                            instance = obj,
                            name = obj.Name,
                            parent = obj.Parent and obj.Parent.Name or "Workspace",
                            position = obj:GetPivot().Position
                        })
                    end
                end
            end
        end
    end
    
    -- Juga cari dengan nama yang mengandung "Chest" tapi tidak sesuai dengan tipe yang diketahui
    local allObjects = Workspace:GetDescendants()
    for _, obj in ipairs(allObjects) do
        if obj:IsA("Model") and (string.find(obj.Name:lower(), "chest") or string.find(obj.Name:lower(), "present")) then
            -- Skip jika sudah ditemukan
            local alreadyFound = false
            for _, found in ipairs(foundChests) do
                if found.instance == obj then
                    alreadyFound = true
                    break
                end
            end
            
            if not alreadyFound then
                -- Periksa apakah ada ChestLid sebagai anak
                for _, child in ipairs(obj:GetChildren()) do
                    if child:IsA("Model") and (child.Name == "ChestLid" or string.find(child.Name:lower(), "lid")) then
                        table.insert(foundChests, {
                            instance = obj,
                            name = obj.Name,
                            parent = obj.Parent and obj.Parent.Name or "Workspace",
                            position = obj:GetPivot().Position
                        })
                        break
                    end
                end
            end
        end
    end
    
    -- Urutkan berdasarkan jarak ke karakter (terdekat ke terjauh)
    local charPos = LocalPlayer.Character and LocalPlayer.Character:GetPivot().Position or Vector3.new(0,0,0)
    table.sort(foundChests, function(a, b)
        return (a.position - charPos).Magnitude < (b.position - charPos).Magnitude
    end)
    
    return foundChests
end

local function openSingleChest(chestInstance)
    if chestInstance and chestInstance.Parent then
        local args = {chestInstance}
        local success, errorMsg = pcall(function()
            if RequestOpenItemChest then
                RequestOpenItemChest:FireServer(unpack(args))
                return true
            end
            return false
        end)
        
        if success then
            -- Tandai sebagai sudah dibuka
            openedChests[chestInstance] = true
            return true, "Berhasil membuka: " .. chestInstance.Name
        else
            return false, "Gagal membuka " .. chestInstance.Name .. ": " .. tostring(errorMsg)
        end
    else
        return false, "Chest tidak valid atau sudah dihapus"
    end
end

local function rescanChests()
    chestQueue = findAllChests()
    openedChests = {} -- Reset daftar chest yang dibuka
    return #chestQueue
end

local function startAutoOpenChests()
    if isOpeningChests then return end
    
    -- Pastikan queue terisi
    if #chestQueue == 0 then
        rescanChests()
    end
    
    if #chestQueue == 0 then
        showWindUINotification(
            "Chest Opener",
            "Tidak ada chest yang ditemukan!",
            "Warning",
            3
        )
        return
    end
    
    isOpeningChests = true
    local totalChests = #chestQueue
    local openedCount = 0
    local failedCount = 0
    
    showWindUINotification(
        "Chest Opener",
        "Memulai membuka " .. totalChests .. " chest...",
        "Info",
        2
    )
    
    chestOpeningThread = task.spawn(function()
        for i, chestInfo in ipairs(chestQueue) do
            if not isOpeningChests then break end
            
            -- Skip jika sudah dibuka
            if openedChests[chestInfo.instance] then
                continue
            end
            
            local success, message = openSingleChest(chestInfo.instance)
            
            if success then
                openedCount = openedCount + 1
                showWindUINotification(
                    "Chest Opener",
                    "✓ " .. chestInfo.name .. " (" .. i .. "/" .. totalChests .. ")",
                    "Success",
                    1
                )
            else
                failedCount = failedCount + 1
                showWindUINotification(
                    "Chest Opener",
                    "✗ " .. chestInfo.name .. " - Gagal",
                    "Error",
                    1
                )
            end
            
            task.wait(chestOpeningSpeed)
        end
        
        -- Tampilkan ringkasan dengan WindUI Notification
        local summary = "Selesai!\nChest terbuka: " .. openedCount .. "/" .. totalChests .. "\nGagal: " .. failedCount
        
        if openedCount > 0 then
            showWindUINotification(
                "Chest Opener - Selesai",
                summary,
                "Success",
                5
            )
        else
            showWindUINotification(
                "Chest Opener - Selesai",
                summary,
                "Warning",
                5
            )
        end
        
        isOpeningChests = false
        chestOpeningThread = nil
    end)
end

local function stopAutoOpenChests()
    isOpeningChests = false
    if chestOpeningThread then
        task.cancel(chestOpeningThread)
        chestOpeningThread = nil
    end
    showWindUINotification(
        "Chest Opener",
        "Membuka chest dihentikan",
        "Info",
        2
    )
end

---------------------------------------------------------
-- HELPER FUNCTIONS (Sapling)
---------------------------------------------------------
local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getFootPosition()
    local root = getRoot()
    if not root then return nil end
    
    -- Mendapatkan posisi tepat di bawah kaki karakter
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

local function findSaplingInstance()
    local items = workspace:FindFirstChild("Items")
    if items then
        for _, v in ipairs(items:GetChildren()) do
            if v.Name:lower():find("sapling") then
                return v
            end
        end
    end
    
    for _, c in ipairs(ReplicatedStorage:GetDescendants()) do
        if (c:IsA("Model") or c:IsA("Tool")) and c.Name:lower():find("sapling") then
            return c
        end
    end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local inv = LocalPlayer:FindFirstChild("Inventory")
    local containers = { backpack, inv }
    
    for _, cont in ipairs(containers) do
        if cont then
            for _, c in ipairs(cont:GetChildren()) do
                if c.Name:lower():find("sapling") then
                    return c
                end
            end
        end
    end
    return "Sapling"
end

local function tryCallRemote(remote, argTable)
    if not remote then return false end
    
    if remote.ClassName == "RemoteFunction" or remote.InvokeServer then
        local ok = pcall(function()
            remote:InvokeServer(unpack(argTable))
        end)
        return ok
    end
    
    if remote.ClassName == "RemoteEvent" or remote.FireServer then
        local ok = pcall(function()
            remote:FireServer(unpack(argTable))
        end)
        return ok
    end
    return false
end

local function robustPlantCall(remote, saplingArg, position)
    if not remote then return false end
    
    local attempts = {
        { saplingArg, position },
        { position, saplingArg },
        { tostring(saplingArg), position },
        { position, tostring(saplingArg) },
    }
    
    for _, args in ipairs(attempts) do
        if tryCallRemote(remote, args) then
            return true
        end
        task.wait(0.03)
    end
    return false
end

---------------------------------------------------------
-- MARKER SYSTEM
---------------------------------------------------------
local function createMarker(pos)
    if not INFINITE_SHOW_MARKER then return end
    
    local p = Instance.new("Part")
    p.Size = Vector3.new(1, 1, 1)
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 0.3
    p.Color = Color3.fromRGB(50, 255, 50)
    p.Material = Enum.Material.Neon
    p.Name = "SaplingMarker"
    p.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0))
    p.Parent = workspace
    Debris:AddItem(p, INFINITE_MARKER_LIFETIME)
    
    table.insert(characterPlantHistory, {
        position = pos,
        time = tick(),
        marker = p
    })
    
    if #characterPlantHistory > 50 then
        local oldest = table.remove(characterPlantHistory, 1)
        if oldest.marker and oldest.marker.Parent then
            oldest.marker:Destroy()
        end
    end
end

local function clearOldMarkers()
    local currentTime = tick()
    for i = #characterPlantHistory, 1, -1 do
        local record = characterPlantHistory[i]
        if currentTime - record.time > INFINITE_MARKER_LIFETIME then
            if record.marker and record.marker.Parent then
                record.marker:Destroy()
            end
            table.remove(characterPlantHistory, i)
        end
    end
end

---------------------------------------------------------
-- INFINITE SAPLING LOGIC (CHARACTER FOLLOW)
---------------------------------------------------------
local function plantInfiniteCycle()
    if not infiniteSaplingEnabled then return end
    
    local sapInst = findSaplingInstance()
    local firstArg = sapInst or "Sapling"
    
    if plantingMode == "character" then
        for i = 1, overlayPoints do
            if not plantingActive then break end
            
            local footPos = getFootPosition()
            if footPos then
                createMarker(footPos)
                robustPlantCall(PlantRemote, firstArg, footPos)
                totalPlanted = totalPlanted + 1
                
                task.wait(0.05)
                
                if i < overlayPoints then
                    footPos = getFootPosition()
                end
            end
        end
    else
        if #overlayParts > 0 then
            -- Untuk infinite mode di overlay, tanam semua titik sekali lalu berhenti
            for _, overlayPart in ipairs(overlayParts) do
                if not plantingActive then break end
                
                createMarker(overlayPart.Position)
                robustPlantCall(PlantRemote, firstArg, overlayPart.Position)
                totalPlanted = totalPlanted + 1
                task.wait(0.05)
            end
            
            -- Setelah selesai, auto stop
            plantingCompleted = true
            stopPlanting()
            
            showWindUINotification(
                "Infinite Planting",
                "✅ Cycle selesai!\n" ..
                "Total ditanam: " .. totalPlanted .. " pohon\n" ..
                "Mode: Infinite (satu cycle)",
                "Success",
                5
            )
        end
    end
    
    clearOldMarkers()
end

---------------------------------------------------------
-- NORMAL PLANTING (single)
---------------------------------------------------------
-- Ganti fungsi plantSingle() dengan:
local function plantSingle()
    -- Cek apakah sudah mencapai batas titik
    if plantingMode == "overlay" and #overlayParts > 0 then
        if plantSequenceIndex > #overlayParts then
            plantingCompleted = true
            stopPlanting()
            
            -- Tampilkan notifikasi WindUI
            showWindUINotification(
                "Planting System",
                "✅ Penanaman selesai!\n" ..
                "Total ditanam: " .. totalPlanted .. " pohon\n" ..
                "Titik overlay: " .. #overlayParts,
                "Success",
                5
            )
            return
        end
    end
    
    local pos
    
    if plantingMode == "overlay" then
        if #overlayParts > 0 then
            -- Sequential planting
            pos = overlayParts[plantSequenceIndex].Position
            plantSequenceIndex = plantSequenceIndex + 1
        else
            local footPos = getFootPosition()
            if not footPos then return end
            pos = footPos
        end
    else
        pos = getFootPosition()
        if not pos then return end
    end
    
    local sapInst = findSaplingInstance()
    local firstArg = sapInst or "Sapling"
    
    -- Coba tanam dan hitung jika berhasil
    local success = robustPlantCall(PlantRemote, firstArg, pos)
    if success then
        totalPlanted = totalPlanted + 1
        createMarker(pos)
    end
    
    -- Update progress jika dalam mode overlay
    if plantingMode == "overlay" and #overlayParts > 0 then
        local progress = math.floor((plantSequenceIndex - 1) / #overlayParts * 100)
        if progress <= 100 then
            -- Tampilkan notifikasi progress setiap 25%
            if progress % 25 == 0 and progress > 0 then
                showWindUINotification(
                    "Planting Progress",
                    "Progress: " .. progress .. "%\n" ..
                    "(" .. (plantSequenceIndex - 1) .. "/" .. #overlayParts .. " titik)",
                    "Info",
                    2
                )
            end
        end
    end
end

---------------------------------------------------------
-- PLANTING LOGIC TERPADU
---------------------------------------------------------
local function startPlanting()
    if plantingActive then 
        showWindUINotification(
            "Planting System",
            "Penanaman sudah aktif!",
            "Warning",
            2
        )
        return 
    end
    
    -- Reset variabel tracking
    plantingActive = true
    plantingCompleted = false
    totalPlanted = 0
    plantSequenceIndex = 1
    
    -- Hitung maksimal titik tanam
    if plantingMode == "overlay" then
        maxPlantPoints = #overlayParts
        if maxPlantPoints == 0 then
            showWindUINotification(
                "Planting System",
                "⚠ Overlay tidak aktif/tidak ada titik!\n" ..
                "Beralih ke mode karakter...",
                "Warning",
                3
            )
            plantingMode = "character"
        else
            showWindUINotification(
                "Planting System",
                "▶ Memulai penanaman...\n" ..
                "Mode: " .. plantingMode .. "\n" ..
                "Titik: " .. maxPlantPoints .. "\n" ..
                "Shape: " .. overlayShape .. "\n" ..
                "Layer: " .. angleIncrement,
                "Info",
                4
            )
        end
    else
        maxPlantPoints = overlayPoints
        showWindUINotification(
            "Planting System",
            "▶ Memulai penanaman...\n" ..
            "Mode: Character\n" ..
            "Target: " .. maxPlantPoints .. " pohon",
            "Info",
            4
        )
    end
    
    plantingThread = task.spawn(function()
        while plantingActive and not plantingCompleted do
            if infiniteSaplingEnabled then
                plantInfiniteCycle()
                -- Untuk infinite, tunggu interval setelah selesai satu cycle
                task.wait(plantInterval)
            else
                plantSingle()
                -- Untuk non-infinite, tunggu interval antar pohon
                task.wait(plantInterval)
            end
        end
    end)
end

local function stopPlanting()
    plantingActive = false
    if plantingThread then 
        task.cancel(plantingThread) 
        plantingThread = nil
    end
    
    -- Hanya tampilkan summary jika bukan auto-stop dari completion
    if not plantingCompleted then
        showWindUINotification(
            "Planting System",
            "⏹ Penanaman dihentikan\n" ..
            "Total ditanam: " .. totalPlanted .. " pohon\n" ..
            "Progress: " .. (plantSequenceIndex - 1) .. "/" .. maxPlantPoints,
            "Info",
            4
        )
    end
    
    -- Clear markers
    for _, record in ipairs(characterPlantHistory) do
        if record.marker and record.marker.Parent then
            record.marker:Destroy()
        end
    end
    characterPlantHistory = {}
end

local function resetPlantingProgress()
    plantSequenceIndex = 1
    totalPlanted = 0
    plantingCompleted = false
    
    showWindUINotification(
        "Planting System",
        "🔄 Progress penanaman direset\n" ..
        "Sequence kembali ke titik awal",
        "Info",
        3
    )
end
---------------------------------------------------------
-- SPIRAL FLIGHT
---------------------------------------------------------
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

---------------------------------------------------------
-- OVERLAY SYSTEM
---------------------------------------------------------
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
        createOverlay()  -- PASTIKAN INI createOverlay(), BUKAN createShapeOverlay()
    else 
        clearOverlay() 
    end
end

---------------------------------------------------------
-- LOAD WINDUI
---------------------------------------------------------
do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(
            "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
        ))()
    end)
    if ok then
        WindUI = res
        WindUI:SetTheme("Dark")
        WindUI.TransparencyValue = 0.2
    else
        warn("[FRENESIS] Gagal memuat WindUI")
    end
end

---------------------------------------------------------
-- UI WITH AUTO CHEST OPENER TAB (WindUI Notifications)
---------------------------------------------------------
local function createUI()
    if not WindUI then
        warn("[FRENESIS] WindUI tidak tersedia, UI tidak dibuat")
        return
    end
    
    local Window = WindUI:CreateWindow({
        Title = "🌀 FRENESIS - Complete System",
        Size = UDim2.fromOffset(520, 520),
        Acrylic = true,
        Transparent = true
    })

    -- TAB UTAMA FUN
    local funTab = Window:Tab({ Title = "Fun", Icon = "gamepad-2" }) -- Icon game controller

    -- SECTION 1: REVEAL MAP (dari Main Tab)
    funTab:Section({ Title = "🔍 Reveal Map" })

    funTab:Button({
        Title = "🌀 Start/Stop Spiral Flight",
        Description = "Terbang dengan pola spiral untuk melihat map",
        Callback = function()
            if spiralActive then stopSpiralFlight()
            else startSpiralFlight() end
        end
    })

    funTab:Button({
        Title = "📍 Teleport to Ground",
        Description = "Teleport ke posisi ground",
        Callback = function()
            local r = getRoot()
            if r then r.CFrame = CFrame.new(groundPosition) end
        end
    })

    -- SECTION 2: SAPLING SYSTEM
    funTab:Section({ Title = "🌱 Sapling System" })

    -- Plant Mode Section
    funTab:Dropdown({
        Title = "Plant Mode",
        Values = { "character", "overlay" },
        Default = "overlay",  -- Default overlay
        Callback = function(v) 
            plantingMode = v 
            plantSequenceIndex = 1
        end
    })

    funTab:Dropdown({
        Title = "Select Shape",
        Values = overlayShapes,
        Default = "circle",  -- Default circle
        Callback = function(v)
            overlayShape = v
            if overlayVisible then updateOverlay() end
        end
    })

    funTab:Toggle({
        Title = "Show Overlay",
        Description = "Tampilkan overlay di workspace",
        Default = true,
        Callback = function(v)
            overlayVisible = v
            updateOverlay()
        end
    })

    funTab:Toggle({
        Title = "Infinite Sapling Mode",
        Description = "ON: Tanam banyak pohon sekaligus | OFF: Tanam satu per satu",
        Default = false,
        Callback = function(v) 
            infiniteSaplingEnabled = v 
        end
    })

    -- Plant Settings Section
    funTab:Section({ Title = "📊 Plant Settings" })

    funTab:Slider({
        Title = "Plant Count",
        Description = "Total titik tanam untuk semua layer",
        Step = 1,
        Value = { Min = 50, Max = 1000, Default = 250 },
        Callback = function(v)
            overlayPoints = math.floor(v)
            if overlayVisible then updateOverlay() end
        end
    })

    funTab:Slider({
        Title = "Angle Increment",
        Description = "Jumlah layer konsentris",
        Step = 1,
        Value = { Min = 1, Max = 10, Default = 2 },
        Callback = function(v)
            angleIncrement = math.floor(v)
            if overlayVisible then updateOverlay() end
        end
    })

    funTab:Slider({
        Title = "Overlay Radius",
        Description = "Radius layer pertama",
        Step = 1,
        Value = { Min = 10, Max = 200, Default = 40 },
        Callback = function(v)
            overlayRadius = math.floor(v)
            if overlayVisible then updateOverlay() end
        end
    })

    funTab:Slider({
        Title = "Overlay Height",
        Description = "Ketinggian overlay dari ground",
        Step = 0.5,
        Value = { Min = 0, Max = 50, Default = 3 },
        Callback = function(v)
            overlayHeight = v
            overlayCenter = Vector3.new(1, v, 1)
            if overlayVisible then updateOverlay() end
        end
    })

    funTab:Slider({
        Title = "Plant Interval",
        Description = "Detik antar tanam",
        Step = 0.05,
        Value = { Min = 0.05, Max = 2, Default = 0.1 },
        Callback = function(v) 
            plantInterval = math.floor(v * 100) / 100
        end
    })

    -- Control Buttons
    funTab:Section({ Title = "🎮 Plant Controls" })

    funTab:Button({
        Title = "▶ Start Planting",
        Description = "Mulai penanaman otomatis",
        Callback = function()
            if plantingActive then 
                stopPlanting()
            else 
                startPlanting()
            end
        end
    })

    funTab:Button({
        Title = "⏹ Stop Planting",
        Description = "Hentikan penanaman",
        Callback = function()
            stopPlanting()
        end
    })

    funTab:Button({
        Title = "🔄 Reset Progress",
        Description = "Reset urutan penanaman ke titik awal",
        Callback = function()
            resetPlantingProgress()
        end
    })

    -- SECTION 3: LOG WALL SYSTEM
    funTab:Section({ Title = "🧱 Log Wall System" })

    funTab:Toggle({
        Title = "Auto Rotate Log Wall",
        Description = "Rotasi otomatis mengikuti bentuk overlay",
        Default = true,
        Callback = function(v)
            autoRotateLogWall = v
        end
    })
    
    funTab:Button({
        Title = "🔍 Scan Log Wall Blueprint",
        Description = "Cari Log Wall Blueprint di inventory",
        Callback = function()
            local count = countLogWallBlueprints()
            if count > 0 then
                showWindUINotification(
                    "Log Wall System",
                    "✅ Ditemukan " .. count .. " Log Wall Blueprint!",
                    "Success",
                    4
                )
            else
                showWindUINotification(
                    "Log Wall System",
                    "✗ Tidak ada Log Wall Blueprint di inventory!",
                    "Error",
                    4
                )
            end
        end
    })

    funTab:Button({
        Title = "▶ Start Auto Place Log Wall",
        Description = "Mulai menempatkan Log Wall di semua titik overlay",
        Callback = function()
            if logWallActive then
                stopAutoLogWall()
            else
                startAutoLogWall()
            end
        end
    })

    funTab:Button({
        Title = "⏹ Stop Auto Place Log Wall",
        Description = "Hentikan penempatan Log Wall",
        Callback = function()
            stopAutoLogWall()
        end
    })

    -- SECTION 4: OPEN CHEST SYSTEM
    funTab:Section({ Title = "🎁 Open Chest System" })

    funTab:Toggle({
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

    funTab:Slider({
        Title = "Delay Chest",
        Description = "Delay antara membuka chest (detik)",
        Step = 0.1,
        Value = { Min = 0.3, Max = 1, Default = chestOpeningSpeed },
        Callback = function(v) 
            chestOpeningSpeed = math.floor(v * 10) / 10
        end
    })

    funTab:Button({
        Title = "🔍 Scan Chest Sekarang",
        Description = "Scan semua chest di map",
        Callback = function()
            local count = rescanChests()
            if count > 0 then
                showWindUINotification(
                    "Chest Scanner",
                    "Ditemukan " .. count .. " chest!",
                    "Success",
                    3
                )
            else
                showWindUINotification(
                    "Chest Scanner",
                    "Tidak ada chest ditemukan",
                    "Warning",
                    3
                )
            end
        end
    })

    funTab:Button({
        Title = "▶ Mulai Buka Chest",
        Description = "Mulai membuka semua chest yang ditemukan",
        Callback = function()
            if not isOpeningChests then
                startAutoOpenChests()
            else
                showWindUINotification(
                    "Chest Opener",
                    "Sedang membuka chest...",
                    "Info",
                    2
                )
            end
        end
    })

    funTab:Button({
        Title = "⏹ Berhenti",
        Description = "Hentikan proses membuka chest",
        Callback = function()
            stopAutoOpenChests()
        end
    })

    -- Label untuk menampilkan info chest
    local chestInfoLabel = funTab:Label({
        Title = "Chest Ditemukan: 0",
        Description = "Status: Tidak aktif"
    })

    -- Update chest info secara berkala
    task.spawn(function()
        while scriptActive do
            task.wait(2)
            local statusText = isOpeningChests and "Sedang membuka chest..." or "Tidak aktif"
            local chestCount = #chestQueue
            chestInfoLabel:UpdateTitle("Chest Ditemukan: " .. chestCount)
            chestInfoLabel:UpdateDescription("Status: " .. statusText)
        end
    end)

    -- SECTION 5: INFO
    funTab:Section({ Title = "ℹ️ System Info" })

    funTab:Label({
        Title = "🌀 FRENESIS - Complete System",
        Description = "v2.0 | Sapling + Chest Opener"
    })

    funTab:Label({
        Title = "Fitur Sapling:",
        Description = "• Mode Character: Tanam di bawah kaki\n• Mode Overlay: Tanam di titik overlay\n• Infinite: Tanam banyak sekaligus"
    })

    funTab:Label({
        Title = "Fitur Chest Opener:",
        Description = "• Auto scan semua chest\n• Buka dari terdekat ke terjauh\n• Notifikasi WindUI untuk setiap chest"
    })

    funTab:Label({
        Title = "Fitur Log Wall:",
        Description = "• Auto rotate mengikuti shape\n• Gunakan blueprint dari inventory\n• Auto stop setelah selesai"
    })

    funTab:Label({
        Title = "Kontrol:",
        Description = "• F1: Toggle UI Visibility\n• Plant Count: Jumlah pohon infinite\n• Delay: Kontrol kecepatan"
    })
    
    -- Contoh notifikasi WindUI saat startup
    task.wait(1)
    showWindUINotification(
        "FRENESIS",
        "Sistem berhasil dimuat!\nTekan F1 untuk toggle UI",
        "Success",
        4
    )
end

---------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------
-- Tunggu WindUI siap
task.spawn(function()
    if WindUI then
        createUI()
        
        -- Auto scan chest saat startup
        task.wait(3)
        local initialCount = rescanChests()
        if initialCount > 0 then
            warn("[FRENESIS] Found " .. initialCount .. " chests on startup")
        end
    end
end)

-- Update overlay berkala
task.spawn(function()
    while scriptActive do
        task.wait(1)
        if overlayVisible then
            updateOverlay()
        end
    end
end)

warn("[FRENESIS] Complete System loaded successfully!")
warn("[FRENESIS] Features: Sapling + Chest Opener + Spiral Flight")
warn("[FRENESIS] Press F1 to toggle UI")

-- Toggle UI dengan F1
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F1 and WindUI then
        if WindUI.Window then
            local window = WindUI.Window
            window.Visible = not window.Visible
        end
    end
end)
