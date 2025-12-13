-- =====================================================
-- UI.lua
-- Papi Dimz | HUB
-- WINDUI ONLY (NO GAME LOGIC)
-- =====================================================

---------------------------------------------------------
-- REQUIRE LOGIC
---------------------------------------------------------
local Logic = require(script.Parent:WaitForChild("logic"))

---------------------------------------------------------
-- LOAD WINDUI
---------------------------------------------------------
local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

---------------------------------------------------------
-- INJECT NOTIFY (BRIDGE)
---------------------------------------------------------
Logic.notify = function(title, message)
    pcall(function()
        WindUI:Notify({
            Title = title or "Info",
            Content = message or "",
            Duration = 4,
            Icon = "info"
        })
    end)
end

---------------------------------------------------------
-- CREATE WINDOW
---------------------------------------------------------
local Window = WindUI:CreateWindow({
    Title = "Papi Dimz | HUB",
    Author = "Bang Dimz",
    Icon = "gamepad-2",
    Folder = "PapiDimz_HUB",
    Size = UDim2.fromOffset(600, 420),
    Theme = "Dark",
    Transparent = true,
    Acrylic = true,
    SideBarWidth = 180,
    HasOutline = true
})

Window:EditOpenButton({
    Title = "Papi Dimz | HUB",
    Icon = "sparkles",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Draggable = true,
    Enabled = true
})

---------------------------------------------------------
-- TABS
---------------------------------------------------------
local mainTab     = Window:Tab({ Title = "Main", Icon = "settings" })
local playerTab   = Window:Tab({ Title = "Local Player", Icon = "user" })
local bringTab    = Window:Tab({ Title = "Bring Item", Icon = "hand" })
local fishingTab  = Window:Tab({ Title = "Fishing", Icon = "fish" })
local farmTab     = Window:Tab({ Title = "Farm", Icon = "flame" })
local combatTab   = Window:Tab({ Title = "Combat", Icon = "swords" })
local nightTab    = Window:Tab({ Title = "Night", Icon = "moon" })

---------------------------------------------------------
-- MAIN TAB
---------------------------------------------------------
mainTab:Paragraph({
    Title = "Papi Dimz HUB",
    Desc = "All-in-One Script (Logic terpisah, UI stabil)",
    Color = "Grey"
})

mainTab:Toggle({
    Title = "Godmode",
    Default = false,
    Callback = function(v)
        Logic.state.GodmodeEnabled = v
    end
})

mainTab:Toggle({
    Title = "Anti AFK",
    Default = true,
    Callback = function(v)
        Logic.state.AntiAFKEnabled = v
    end
})

mainTab:Button({
    Title = "Reset All & Close",
    Variant = "Destructive",
    Callback = function()
        Logic.resetAll()
        Window:Destroy()
    end
})

---------------------------------------------------------
-- LOCAL PLAYER TAB
---------------------------------------------------------
playerTab:Toggle({
    Title = "Fly",
    Callback = function(v)
        if v then
            Logic.startFly()
        else
            Logic.stopFly()
        end
    end
})

playerTab:Slider({
    Title = "Fly Speed",
    Step = 1,
    Value = { Min = 16, Max = 200, Default = 50 },
    Callback = function(v)
        Logic.state.FlySpeed = v
    end
})

playerTab:Toggle({
    Title = "Infinite Jump",
    Callback = function(v)
        Logic.setInfiniteJump(v)
    end
})

playerTab:Toggle({
    Title = "TP Walk",
    Callback = function(v)
        if v then
            Logic.startTPWalk(5)
        else
            Logic.stopTPWalk()
        end
    end
})

---------------------------------------------------------
-- BRING ITEM TAB
---------------------------------------------------------
local bringSetting = bringTab:Section({
    Title = "Bring Setting",
    DefaultOpen = true
})

bringSetting:Dropdown({
    Title = "Location",
    Values = { "Player", "Workbench", "Fire" },
    Value = "Player",
    Callback = function(v)
        Logic.state.BringLocation = v
    end
})

bringSetting:Input({
    Title = "Bring Height",
    Placeholder = "20",
    Default = "20",
    Numeric = true,
    Callback = function(v)
        Logic.state.BringHeight = tonumber(v) or 20
    end
})

local foodList = {
    "All","Carrot","Corn","Apple","Cake","Steak","Morsel"
}
local selectedFood = { "All" }

bringTab:Dropdown({
    Title = "Food",
    Values = foodList,
    Multi = true,
    Value = { "All" },
    Callback = function(v)
        selectedFood = v or { "All" }
    end
})

bringTab:Button({
    Title = "Bring Food",
    Callback = function()
        Logic.bringItems(foodList, selectedFood)
    end
})

---------------------------------------------------------
-- FISHING TAB
---------------------------------------------------------
fishingTab:Toggle({
    Title = "Auto Click Fishing",
    Callback = function(v)
        Logic.state.FishingEnabled = v
    end
})

fishingTab:Input({
    Title = "Click Delay (s)",
    Default = "5",
    Callback = function(v)
        local n = tonumber(v)
        if n then Logic.setFishingDelay(n) end
    end
})

fishingTab:Button({
    Title = "Set Fishing Position",
    Callback = function()
        Logic.notify("Fishing", "Klik layar untuk set posisi")
        local UIS = game:GetService("UserInputService")
        local conn
        conn = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local pos = UIS:GetMouseLocation()
                Logic.setFishingPosition(math.floor(pos.X), math.floor(pos.Y))
                conn:Disconnect()
            end
        end)
    end
})

---------------------------------------------------------
-- FARM TAB
---------------------------------------------------------
farmTab:Toggle({
    Title = "Auto Crockpot",
    Callback = function(v)
        if v then Logic.startAutoCook() else Logic.stopAutoCook() end
    end
})

farmTab:Toggle({
    Title = "Auto Scrapper",
    Callback = function(v)
        if v then Logic.startAutoScrap() else Logic.stopAutoScrap() end
    end
})

farmTab:Toggle({
    Title = "Auto Sacrifice Lava",
    Callback = function(v)
        Logic.state.AutoSacEnabled = v
    end
})

farmTab:Toggle({
    Title = "Ultra Coin & Ammo",
    Callback = function(v)
        if v then Logic.startCoinAmmo() else Logic.stopCoinAmmo() end
    end
})

---------------------------------------------------------
-- COMBAT TAB
---------------------------------------------------------
combatTab:Toggle({
    Title = "Kill Aura",
    Callback = function(v)
        Logic.state.KillAuraEnabled = v
    end
})

combatTab:Toggle({
    Title = "Chop Aura",
    Callback = function(v)
        Logic.state.ChopAuraEnabled = v
    end
})

---------------------------------------------------------
-- NIGHT TAB
---------------------------------------------------------
nightTab:Toggle({
    Title = "Auto Skip Night",
    Callback = function(v)
        Logic.state.AutoTemporalEnabled = v
    end
})

nightTab:Button({
    Title = "Trigger Temporal (Manual)",
    Callback = function()
        Logic.notify("Temporal", "Manual trigger")
        -- logic otomatis dipanggil oleh DayDisplay
    end
})

---------------------------------------------------------
-- HOTKEY
---------------------------------------------------------
game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.P then
        Window:Toggle()
    end
end)

---------------------------------------------------------
-- FINAL
---------------------------------------------------------
Logic.notify("UI", "UI Loaded & Connected")
