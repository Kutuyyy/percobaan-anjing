--https://chatgpt.com/c/69874aeb-7038-8323-bb34-800c4e370f94
-- FRENESIS x HexaCore HUB (FINAL COMPLETE + AUTO RUN)
-- Reworked: semua variabel stateful dimasukkan ke `local state = {}` untuk mengurangi usage local registers
-- Struktur dirapikan: helpers / listeners / loops / platform builder / UI tetap sama alurnya
local DEBUG = false   -- true = console aktif | false = silent

do
    local _print = print
    local _warn  = warn

    local noop = function(...) end

    if not DEBUG then
        print = noop
        warn  = noop

        -- executor console
        rconsoleprint = noop
        rconsolewarn  = noop
        rconsoleerr   = noop
    end
end

------------------------------------------------------
-- HEXACORE INTRO (RGB PULSE, TRANSPARENT BG, NO HEX)
------------------------------------------------------
local ok, Intro = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Kutuyyy/obfuscate/refs/heads/main/intro.lua"
    ))()
end)

if ok and type(Intro) == "table" and Intro.Play then
    Intro:Play()
end
------------------------------------------------------

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

-- UI ELEMENT REFERENCES (untuk sinkronisasi setelah load)
state.UI_ELEMENTS = {}

local function safeSetUIElement(el, value)
    if not el then return end
    pcall(function()
        if el.SetValue then el:SetValue(value) return end
        if el.Set then el:Set(value) return end
        if el.SetEnabled then el:SetEnabled(value) return end
        if el.SetState then el:SetState(value) return end
        -- fallback: try direct property (rare)
        if el.Value ~= nil then el.Value = value end
    end)
end

-- wrapper untuk membuat Toggle dan menyimpan reference
local function createToggle(tab, params, key)
    local el = tab:Toggle(params)
    if key and el then state.UI_ELEMENTS[key] = el end
    return el
end
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
local HttpService = game:GetService("HttpService")
local userId = tostring(Players.LocalPlayer.UserId)



--Config save/load
local FIREBASE_URL = "https://hexacore-5455a-default-rtdb.asia-southeast1.firebasedatabase.app"
local GAME_NAME = "Escape Tsunami For Brainrot"

local function urlEncode(s)
    if not s then return "" end
    -- very small url-encoder for spaces (good enough for folder name)
    return tostring(s):gsub(" ", "%%20")
end

-- ===== CLOUD CONFIG HELPERS (SAFE + COMPAT) =====
local function isTablePlain(t)
    if type(t) ~= "table" then return false end
    for k,v in pairs(t) do
        if type(k) ~= "string" and type(k) ~= "number" then return false end
        local tt = type(v)
        if not (tt == "string" or tt == "number" or tt == "boolean" or tt == "table" or tt == "nil") then
            return false
        end
    end
    return true
end

local function vec3ToTable(v)
    if typeof and typeof(v) == "Vector3" then
        return { x = v.X, y = v.Y, z = v.Z }
    end
    return nil
end

local function tableToVec3(t)
    if type(t) == "table" and t.x and t.y and t.z then
        return Vector3.new(t.x, t.y, t.z)
    end
    return nil
end

-- whitelist keys yang boleh disimpan (only primitive / small tables)
local SAVABLE_KEYS = {
    "AutoCollect","AutoUpgrade","AutoBuySpeed","AutoRebirth","AutoBuyCarry",
    "AutoCollectRadioactive","AutoCollectUFO","AutoCollectGoldBar",
    "AutoCollectTicket","AutoCollectGamer","AutoCollectArcade","AutoCollectValentine",
    "CollectCoins","ActivateCollectCoin",
    "AutoSpinRadioactive","AutoSpinUFO","AutoSpinGoldBar",
    "AutoCollectTarget","AutoRunEnabled",
    "InstantGrabEnabled","InfiniteJumpEnabled","InfiniteZoomEnabled",
    "platformEnabled","AUTO_MOVE_SPEED_MULT","BRAINROT_PICK_COUNT",
    "selectedRarities","LuckyBlockTargets","TWEEN_SPEED","WALL_SAFE_DISTANCE",
    "MAX_SLOTS","SEND_TRADE_WAIT","POST_FILL_WAIT","LOOP_DELAY",
    "AutoTravelEnabled",
    -- tambahan agar toggle / UI lain terpersist:
    "BypassVIP","NoClipEnabled","AutoObbyGoldEnabled"
}


local function getSavableState()
    local out = {}
    for _,k in ipairs(SAVABLE_KEYS) do
        local v = state[k]
        if v ~= nil then
            -- copy simple tables shallowly (like selectedRarities / LuckyBlockTargets)
            if type(v) == "table" then
                local ok = true
                for kk,vv in pairs(v) do
                    if not (type(kk) == "string" or type(kk) == "number") or not (type(vv)=="boolean" or type(vv)=="string" or type(vv)=="number") then
                        ok = false; break
                    end
                end
                if ok then
                    out[k] = {}
                    for kk,vv in pairs(v) do out[k][kk] = vv end
                end
            elseif typeof and typeof(v) == "Vector3" then
                out[k] = vec3ToTable(v)
            else
                out[k] = v
            end
        end
    end

    -- simpan juga important positions (convert to table)
    out.START_POS = vec3ToTable(state.START_POS) or out.START_POS
    out.END_POS = vec3ToTable(state.END_POS) or out.END_POS

    -- metadata
    out._meta = { saved_at = os.time() }

    return out
end

local function applyLoadedConfig(data)
    if type(data) ~= "table" then return end

    --------------------------------------------------
    -- APPLY SAVED KEYS
    --------------------------------------------------
    for _,k in ipairs(SAVABLE_KEYS) do
        if data[k] ~= nil then
            state[k] = data[k]
        end
    end

    -- BACKWARD-COMPAT: jika config lama punya flags per-coin, convert ke CollectCoins
    if data.AutoCollectRadioactive or data.AutoCollectUFO or data.AutoCollectGoldBar
       or data.AutoCollectTicket or data.AutoCollectGamer or data.AutoCollectValentine then
        state.CollectCoins = state.CollectCoins or {}
        if data.AutoCollectRadioactive then state.CollectCoins["Radioactive Coin"] = true end
        if data.AutoCollectUFO       then state.CollectCoins["UFO Coin"] = true end
        if data.AutoCollectGoldBar   then state.CollectCoins["Gold Bar"] = true end
        -- arcade: ticket + game console (old keys might be Ticket / Gamer toggles)
        if data.AutoCollectTicket or data.AutoCollectGamer or data.AutoCollectArcade then
            state.CollectCoins["Arcade"] = true
        end
        -- valentine
        if data.AutoCollectValentine then state.CollectCoins["Valentine"] = true end

        -- if any old flag was true, enable ActivateCollectCoin to preserve behaviour
        state.ActivateCollectCoin = state.ActivateCollectCoin or (
            data.AutoCollectRadioactive or data.AutoCollectUFO or data.AutoCollectGoldBar
            or data.AutoCollectTicket or data.AutoCollectGamer or data.AutoCollectValentine
            or data.AutoCollectArcade
        )
    end

    -- If config has CollectCoins table saved directly, keep as is (already set above by SAVABLE_KEYS loop)
    if data.CollectCoins and type(data.CollectCoins) == "table" then
        state.CollectCoins = data.CollectCoins
    end
    if data.ActivateCollectCoin ~= nil then state.ActivateCollectCoin = data.ActivateCollectCoin end

    --------------------------------------------------
    -- RESTORE VECTOR POSITIONS
    --------------------------------------------------
    if data.START_POS then
        local v = tableToVec3(data.START_POS)
        if v then state.START_POS = v end
    end

    if data.END_POS then
        local v = tableToVec3(data.END_POS)
        if v then state.END_POS = v end
    end

    --------------------------------------------------
    -- RUNTIME ACTIONS (🔥 PENTING BANGET)
    --------------------------------------------------

    -- Bypass VIP
    if state.BypassVIP then
        pcall(function()
            enableSelectiveNoClip()
            enableVIPWallTouchBlock()
        end)
    else
        pcall(function()
            disableSelectiveNoClip()
            disableVIPWallTouchBlock()
        end)
    end

    -- Global NoClip
    if state.NoClipEnabled then
        pcall(enableNoClip)
    else
        pcall(disableNoClip)
    end

    -- Platform Builder
    if state.platformEnabled then
        pcall(enablePlatform)
    else
        pcall(disablePlatform)
    end

    -- Auto Obby Gold
    if state.AutoObbyGoldEnabled then
        pcall(function()
            setupObbyListener()
            startObbyGoldSequence()
        end)
    end

    -- Auto Travel (delay-safe start: tunggu sedikit & pastikan kondisi aman)
    do
        -- jika user ingin AutoTravel mati, stop langsung
        if not state.AutoTravelEnabled then
            pcall(stopAutoTravel)
        else
            -- spawn async supaya tidak block applyLoadedConfig
            task.spawn(function()
                -- tunggu sedikit agar character/map/platform/scan stabil
                task.wait(1.0)

                -- jika ada subsystem prioritas (target active) maka tunggu hingga clear
                local maxWait = 6.0
                local waited = 0
                while hasActiveTargets() and waited < maxWait do
                    if DEBUG then print("[AutoTravel][applyLoadedConfig] waiting for active targets to clear...") end
                    task.wait(0.5)
                    waited = waited + 0.5
                end

                -- final safety: pastikan Floors ada dan WindUI siap
                if not state.Floors or #state.Floors < 2 then
                    if DEBUG then print("[AutoTravel][applyLoadedConfig] Floors not ready, attempting refreshFloorsFromMap()") end
                    pcall(refreshFloorsFromMap)
                    task.wait(0.4)
                end

                -- jika user masih mau AutoTravel, mulai
                if state.AutoTravelEnabled then
                    if DEBUG then print("[AutoTravel][applyLoadedConfig] starting AutoTravel after checks") end
                    pcall(startAutoTravel)
                else
                    pcall(stopAutoTravel)
                end
            end)
        end
    end

    -- Instant / Jump / Zoom
    if state.InstantGrabEnabled then pcall(enableInstantGrab) else pcall(disableInstantGrab) end
    if state.InfiniteJumpEnabled then pcall(enableInfiniteJump) else pcall(disableInfiniteJump) end
    if state.InfiniteZoomEnabled then pcall(enableInfiniteZoom) else pcall(disableInfiniteZoom) end

    --------------------------------------------------
    -- AUTO COLLECT TARGET (PRIORITY SYSTEM)
    --------------------------------------------------
    if state.AutoCollectTarget then
        pcall(function()
            stopAutoMove()
            startAutoCollectTarget()
        end)
    elseif state.AutoCollect then
        if next(state.selectedRarities or {}) ~= nil then
            state.autoCollectEnabled = true
            pcall(startAutoCollectBrainrotByRarity)
        end
    end

    if state.AutoRunEnabled then
        state.autoMoveEnabled = true
        pcall(function()
            startAutoMoveToTarget(state.selectedFloorIndex or 1)
        end)
    end

    --------------------------------------------------
    -- NOTIFY
    --------------------------------------------------
    if state.WindUI then
        state.WindUI:Notify({
            Title = "Cloud Config",
            Content = "Config applied.",
            Duration = 2
        })
    end

    --------------------------------------------------
    -- SYNC UI VISUAL STATE
    --------------------------------------------------
    local function trySyncKey(k)
        local val = state[k]
        if val == nil then return end

        local el = nil
        if state.UI_ELEMENTS then
            el = state.UI_ELEMENTS[k]
                or state.UI_ELEMENTS[k:gsub("Enabled","")]
                or state.UI_ELEMENTS[k.."Enabled"]
        end

        -- dropdown brainrot
        if k == "selectedRarities" and el then
            local list = {}
            for name, enabled in pairs(state.selectedRarities or {}) do
                if enabled then table.insert(list, name) end
            end
            safeSetUIElement(el, list)
            return
        end

        if k == "CollectCoins" and el then
            local selected = {}
            for name, enabled in pairs(state.CollectCoins or {}) do
                if enabled then table.insert(selected, name) end
            end
            safeSetUIElement(el, selected)
            return
        end

        -- dropdown lucky block
        if k == "LuckyBlockTargets" and el then
            local list = {}
            for name, enabled in pairs(state.LuckyBlockTargets or {}) do
                if enabled then table.insert(list, name) end
            end
            safeSetUIElement(el, list)
            return
        end

        if el then
            safeSetUIElement(el, val)
        end
    end

    local keysToSync = {
        "AutoCollect","AutoUpgrade","AutoBuySpeed","AutoRebirth","AutoBuyCarry",
        "platformEnabled","AutoCollectTarget","AutoRunEnabled",
        "AutoCollectRadioactive","AutoCollectUFO","AutoCollectGoldBar",
        "AutoCollectTicket","AutoCollectGamer","AutoCollectArcade","AutoCollectValentine",
        "CollectCoins","ActivateCollectCoin",
        "InstantGrabEnabled","InfiniteJumpEnabled","InfiniteZoomEnabled",
        "BypassVIP","NoClipEnabled","AutoObbyGoldEnabled",
        "selectedRarities","LuckyBlockTargets",
        "AutoTravelEnabled"  -- <- tambahkan ini
    }

    for _,k in ipairs(keysToSync) do
        trySyncKey(k)
    end
end

-- ===== improved request / save / load with diagnostics & slot fallback =====
local function doRequest(reqConf)
    -- small wrapper that returns { Body = ..., StatusCode = ... } or nil, err
    local ok, res = pcall(function()
        -- prefer native request libs when available
        if type(request) == "function" then return request(reqConf) end
        if syn and syn.request then return syn.request(reqConf) end
        if http_request then return http_request(reqConf) end

        -- fallback to HttpService
        if reqConf.Method == "GET" then
            local body = HttpService:GetAsync(reqConf.Url, true)
            return { Body = body, StatusCode = 200 }
        else
            local body = HttpService:PostAsync(reqConf.Url, reqConf.Body or "", Enum.HttpContentType.ApplicationJson)
            return { Body = body, StatusCode = 200 }
        end
    end)

    if not ok then
        return nil, res
    end

    -- some request wrappers (native libs can return different shapes)
    if type(res) == "table" then
        -- ensure Body + StatusCode keys exist
        res.Body = res.Body or (res.body and res.body) or ""
        res.StatusCode = res.StatusCode or res.status or res.Status or 200
    else
        -- unexpected shape: coerce to table
        res = { Body = tostring(res), StatusCode = 200 }
    end

    if DEBUG then
        pcall(function()
            rconsoleprint(("[HTTP] %s %s -> %s\n"):format(reqConf.Method or "GET", reqConf.Url, tostring(res.StatusCode)))
            rconsoleprint(("[HTTP BODY] %s\n"):format(tostring(res.Body)))
        end)
    end

    return res
end

local function buildConfigPath(uid, slotName)
    local base = "/users/" .. urlEncode(GAME_NAME) .. "/" .. tostring(uid)
    if slotName and tostring(slotName) ~= "" then
        return base .. "/slots/" .. tostring(slotName) .. ".json"
    else
        return base .. "/config.json"
    end
end

local function saveConfigOnline(optUserId, slotName)
    local uid = tostring(optUserId or userId or (Players.LocalPlayer and Players.LocalPlayer.UserId) or "unknown")
    local data = getSavableState()
    local json = HttpService:JSONEncode(data)

    local targetPath = buildConfigPath(uid, slotName)
    local conf = {
        Url = FIREBASE_URL .. targetPath,
        Method = "PATCH",
        Headers = { ["Content-Type"] = "application/json" },
        Body = json
    }

    local res, err = doRequest(conf)
    if not res then
        warn("[CloudSave] request failed:", tostring(err))
        if state.WindUI then state.WindUI:Notify({ Title = "Cloud Save", Content = "Failed to send request.", Duration = 3 }) end
        return false
    end

    if tonumber(res.StatusCode) and tonumber(res.StatusCode) >= 200 and tonumber(res.StatusCode) < 300 then
        if state.WindUI then state.WindUI:Notify({ Title = "Cloud Save", Content = "Saved to cloud.", Duration = 2 }) end
        return true
    else
        warn("[CloudSave] unexpected response:", res.Body)
        if state.WindUI then state.WindUI:Notify({ Title = "Cloud Save", Content = "Save returned error.", Duration = 3 }) end
        return false
    end
end

local function loadConfigOnline(optUserId, slotName)
    local uid = tostring(optUserId or userId or (Players.LocalPlayer and Players.LocalPlayer.UserId) or "unknown")
    local targetPath = buildConfigPath(uid, slotName)
    local conf = { Url = FIREBASE_URL .. targetPath, Method = "GET" }

    local res, err = doRequest(conf)
    if not res then
        warn("[CloudLoad] request failed:", tostring(err))
        if state.WindUI then state.WindUI:Notify({ Title = "Cloud Load", Content = "Failed to fetch (request error).", Duration = 3 }) end
        return false
    end

    if not res.Body or res.Body == "null" then
        -- fallback for slots listing ONLY when no slotName provided
        if not slotName then
            local trySlotsConf = { Url = FIREBASE_URL .. "/users/" .. urlEncode(GAME_NAME) .. "/" .. uid .. "/slots.json", Method = "GET" }
            local res2 = doRequest(trySlotsConf)
            if res2 and res2.Body and res2.Body ~= "null" then
                local ok2, slots = pcall(function() return HttpService:JSONDecode(res2.Body) end)
                if ok2 and type(slots) == "table" then
                    for sname, sdata in pairs(slots) do
                        if type(sdata) == "table" then
                            applyLoadedConfig(sdata)
                            if state.WindUI then state.WindUI:Notify({ Title = "Cloud Load", Content = "Loaded from slot: "..tostring(sname), Duration = 3 }) end
                            return true
                        end
                    end
                end
            end
        end

        if state.WindUI then state.WindUI:Notify({ Title = "Cloud Load", Content = "No cloud config found.", Duration = 2 }) end
        return false
    end

    local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok or type(data) ~= "table" then
        warn("[CloudLoad] decode failed or not a table:", tostring(data))
        if state.WindUI then state.WindUI:Notify({ Title = "Cloud Load", Content = "Invalid data format.", Duration = 3 }) end
        return false
    end

    applyLoadedConfig(data)
    return true
end

-- Slot helpers (multi-config)
local function saveConfigToSlot(name) return saveConfigOnline(nil, name) end
local function loadConfigFromSlot(name) return loadConfigOnline(nil, name) end

local function deleteConfigOnline(optUserId, slotName)
    local uid = tostring(optUserId or userId or (Players.LocalPlayer and Players.LocalPlayer.UserId) or "unknown")
    local targetPath = buildConfigPath(uid, slotName)
    local conf = { Url = FIREBASE_URL .. targetPath, Method = "DELETE" }
    local res, err = doRequest(conf)
    return (res ~= nil)
end


-- compatibility: button callbacks call without args
-- adjust existing UI buttons to call saveConfigOnline() / loadConfigOnline()


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
state.AutoCollectValentine = false

-- misc features
state.InstantGrabEnabled = false
state.InfiniteZoomEnabled = false
state.InfiniteJumpEnabled = false

-- NEW
state.BypassVIP = false
state.NoClipEnabled = false

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
state.RARITIES = {
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
state.RemoteEventsFolder = nil

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
state.AutoCollectArcade = false

state.coinCache = {
    ["Radioactive Coin"] = {},
    ["UFO Coin"] = {},
    ["GoldBar"] = {},
    ["Ticket"] = {},
    ["Game Console"] = {},
    -- Valentine / Event
    ["HeartCandy1"] = {},
    ["HeartCandy2"] = {},
    ["HeartCandy3"] = {},
    ["lovetoken"] = {}
}
state.cachePointers = {
    ["Radioactive Coin"] = 1,
    ["UFO Coin"] = 1,
    ["GoldBar"] = 1,
    ["Ticket"] = 1,
    ["Game Console"] = 1,
    -- Valentine pointers
    ["HeartCandy1"] = 1,
    ["HeartCandy2"] = 1,
    ["HeartCandy3"] = 1,
    ["lovetoken"] = 1
}

-- Collect Coins (new unified dropdown)
state.CollectCoins = state.CollectCoins or {
    ["Radioactive Coin"] = false,
    ["UFO Coin"] = false,
    ["Gold Bar"] = false,
    ["Arcade"] = false,
    ["Valentine"] = false
}
state.ActivateCollectCoin = state.ActivateCollectCoin or false

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
state.vipWallListenerConn = nil

-- Auto Trade / Auto Gift state (diperlukan untuk fitur dari script2)
state.TargetPlayer = nil
state.BrainrotSet = {}         -- map rarity -> true (selections for giving/trading)
state.LuckySet = {}           -- map rarity -> true (selections for lucky blocks)

state.AutoGift = false
state.AutoGiftTask = nil

state.AutoTrade = false
state.AutoTradeTask = nil

-- timing / slot configs (default values sesuai script2)
state.MAX_SLOTS = 6
state.SEND_TRADE_WAIT = 5.0   -- waktu tunggu setelah SendTrade sebelum mulai fill slots
state.POST_FILL_WAIT = 4.0    -- waktu tunggu setelah fill slots sebelum tekan Accept
state.POST_ACCEPT_WAIT = 5.0  -- waktu tunggu setelah tekan Accept sebelum loop berikutnya
state.LOOP_DELAY = 2.0        -- delay tambahan di loop (tetap ada)

-- remotes placeholders (akan di-init di Block B)
state.SendGiftRF = nil
state.SendTradeRF = nil
state.SetSlotOfferRF = nil
state.ReadyTradeRE = nil
state.AutoTravelEnabled = false
state.autoTravelTask = nil
state.pendingRestartTravel = false

state._autoTravelPaused = false
state._autoTravelPausedByCollector = false
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

-- =============================================
-- AUTO TRAVEL: ambil CFrame floor asli dari map
-- =============================================
-- ============================
-- DYNAMIC FLOOR SCANNER (patch)
-- ============================
local function safeGetCenterAndSize(inst)
    -- returns centerX, sizeX, cframe, instRef
    if not inst then return nil end
    -- BasePart
    if inst:IsA("BasePart") then
        local cf = inst.CFrame
        local sizeX = (inst.Size and inst.Size.X) or 0
        return cf.Position.X, sizeX, cf, inst
    end

    -- Model -> try GetPivot / GetExtentsSize
    if inst:IsA("Model") then
        local ok, pivot = pcall(function() return inst:GetPivot() end)
        local ok2, extents = pcall(function() return inst:GetExtentsSize() end)
        if ok and pivot then
            local sizeX = (ok2 and extents and extents.X) or 0
            return pivot.Position.X, sizeX, pivot, inst
        end
    end

    return nil
end

local function refreshFloorsFromMap()
    local root = workspace:FindFirstChild("DefaultMap_SharedInstances")
    if not root then
        if DEBUG then print("[Floors] DefaultMap_SharedInstances not found") end
        return
    end
    local floorsFolder = root:FindFirstChild("Floors")
    if not floorsFolder then
        if DEBUG then print("[Floors] Floors folder not found") end
        return
    end

    local entries = {}
    local nameCount = {}

    for _, child in ipairs(floorsFolder:GetChildren()) do
        local ok, cx, sizeX, cf, ref = pcall(function()
            return safeGetCenterAndSize(child)
        end)

        if ok and cx then
            local baseName = tostring(child.Name or "Floor")
            nameCount[baseName] = (nameCount[baseName] or 0) + 1
            local uniqueName = baseName
            if nameCount[baseName] > 1 then
                uniqueName = baseName .. tostring(nameCount[baseName]) -- e.g. "Cosmic2" or "Secret3"
            end

            table.insert(entries, {
                name = uniqueName,
                originalName = baseName,
                x = cx,
                size = sizeX or 0,
                cframe = cf,
                partRef = child
            })
        end
    end

    -- sort by center X ascending
    table.sort(entries, function(a,b) return a.x < b.x end)

    -- preserve START as index 1 if previously defined (fallback to state.START_POS)
    local newFloors = {}
    if state.Floors and state.Floors[1] and state.Floors[1].name == "Start" then
        -- keep existing Start entry (so other code that expects Floors[1] = Start remains valid)
        table.insert(newFloors, state.Floors[1])
    else
        -- create Start from state.START_POS if present
        if state.START_POS then
            table.insert(newFloors, { name = "Start", x = state.START_POS.X, size = 0, cframe = CFrame.new(state.START_POS), partRef = nil })
        else
            -- fallback: insert dummy start at left-most - small offset
            if #entries > 0 then
                local leftmost = entries[1].x - 100
                table.insert(newFloors, { name = "Start", x = leftmost, size = 0, cframe = CFrame.new(leftmost, 0, 0), partRef = nil })
            else
                table.insert(newFloors, { name = "Start", x = 0, size = 0, cframe = CFrame.new(0,0,0), partRef = nil })
            end
        end
    end

    -- now append detected floors (avoid duplicating Start if a map child called "Start" exists near start X)
    for _, e in ipairs(entries) do
        local skip = false
        if newFloors[1] and math.abs((newFloors[1].x or 0) - (e.x or 0)) <= 1 then
            -- almost same as Start X -> skip
            skip = true
        end
        if not skip then table.insert(newFloors, e) end
    end

    state.Floors = newFloors

    if DEBUG then
        print("[Floors] refreshed, count=", #state.Floors)
        for i,f in ipairs(state.Floors) do
            print(("  [%d] %s -> x=%.3f size=%.1f"):format(i, tostring(f.name), tonumber(f.x) or 0, tonumber(f.size) or 0))
        end
    end
end

-- improved getFloorCFrame: use partRef when available
local function getFloorCFrame(floor)
    if type(floor) == "string" then
        -- accept name -> try find in state.Floors
        for _, f in ipairs(state.Floors or {}) do
            if f.name == floor or f.originalName == floor then
                floor = f
                break
            end
        end
    end

    if type(floor) == "table" then
        if floor.partRef and floor.partRef.Parent then
            local ok, cf = pcall(function()
                if floor.partRef:IsA("BasePart") then return floor.partRef.CFrame end
                return floor.partRef:GetPivot()
            end)
            if ok and cf then return cf end
        end

        -- fallback: if has name, try read from workspace map directly (legacy)
        if floor.name then
            local shared = workspace:FindFirstChild("DefaultMap_SharedInstances")
            if shared and shared:FindFirstChild("Floors") then
                local fobj = shared.Floors:FindFirstChild(floor.originalName or floor.name)
                if fobj then
                    local ok2, cf2 = pcall(function()
                        if fobj:IsA("BasePart") then return fobj.CFrame end
                        return fobj:GetPivot()
                    end)
                    if ok2 and cf2 then return cf2 end
                end
            end
        end
    end

    return nil
end

-- improved getFloorIndexByX: choose nearest floor by absolute distance on X
local function getFloorIndexByX(x)
    if not x then return 1 end
    local bestIndex = 1
    local bestDist = math.huge
    for i, f in ipairs(state.Floors or {}) do
        local fx = f and f.x or nil
        if fx then
            local d = math.abs(x - fx)
            if d < bestDist then bestDist = d bestIndex = i end
        end
    end
    return bestIndex
end

-- setup initial refresh + watcher (place after these function defs)
pcall(function() refreshFloorsFromMap() end)

-- install watcher so floor table updates when map changes
pcall(function()
    local root = workspace:FindFirstChild("DefaultMap_SharedInstances")
    if root and root:FindFirstChild("Floors") then
        local ff = root.Floors
        if not state.floorsWatcherConn then
            state.floorsWatcherConn = ff.ChildAdded:Connect(function() task.defer(refreshFloorsFromMap) end)
            ff.ChildRemoved:Connect(function() task.defer(refreshFloorsFromMap) end)
            -- optional: also react to property changes (size/cframe) using DescendantAdded? expensive so omitted
        end
    end
end)

local function getFloorCFrame(floorName)
    local shared = workspace:FindFirstChild("DefaultMap_SharedInstances")
    if not shared then return nil end
    local floors = shared:FindFirstChild("Floors")
    if not floors then return nil end
    local floorObj = floors:FindFirstChild(floorName)
    if not floorObj then return nil end

    -- Coba ambil pivot (untuk Model) atau CFrame (untuk Part)
    local ok, cf = pcall(function()
        if floorObj:IsA("BasePart") then
            return floorObj.CFrame
        else
            return floorObj:GetPivot()
        end
    end)
    return ok and cf or nil
end

-- Cek apakah Auto Collect Target sedang memiliki target aktif (benar-benar ada pekerjaan)
local function hasActiveTargets()
    -- Jika AutoCollectTarget tidak aktif => tidak ada prioritas
    if not state.AutoCollectTarget then return false end

    -- Lucky Block: aktif dan ada antrian nyata
    if state.autoCollectBlockEnabled and (#state.LuckyBlockQueue or 0) > 0 then
        return true
    end

    -- Brainrot: only count as active if collector enabled AND there are actually brainrots in cache
    if state.autoCollectEnabled and next(state.selectedRarities or {}) ~= nil then
        for rarity, list in pairs(state.brainrotCache or {}) do
            if state.selectedRarities[rarity] and list and #list > 0 then
                return true
            end
        end
    end

    return false
end

-- ============================
-- AUTO TRAVEL PAUSE / RESUME
-- ============================
-- Pause AutoTravel tanpa mengubah preferensi user (state.AutoTravelEnabled tetap utuh)
local function pauseAutoTravel()
    if state._autoTravelPaused then return end
    state._autoTravelPaused = true
    -- cancel running task (jangan set AutoTravelEnabled = false)
    if state.autoTravelTask then
        pcall(function() task.cancel(state.autoTravelTask) end)
        state.autoTravelTask = nil
    end
    -- hentikan tween yang mungkin masih berjalan
    cancelLastTween()
    if DEBUG then print("[AutoTravel] paused by system") end
end

local function resumeAutoTravel()
    if not state._autoTravelPaused then return end
    state._autoTravelPaused = false
    
    -- 🔥 FORCE NIL TASK REFERENCE (critical fix)
    if state.autoTravelTask then
        pcall(function() task.cancel(state.autoTravelTask) end)
        state.autoTravelTask = nil
    end
    
    -- restart tugas auto travel jika user masih menginginkan AutoTravel
    if state.AutoTravelEnabled then
        if DEBUG then print("[AutoTravel] force spawning new task on resume") end
        pcall(startAutoTravel)
    end
    
    if DEBUG then print("[AutoTravel] resumed by system") end
end

-- guard cooldown supaya tidak spam start/resume berulang
local _lastAutoTravelResume = 0
local _AUTO_TRAVEL_RESUME_COOLDOWN = 1.0 -- detik

-- helper: jika pause oleh collector tapi sekarang tidak ada target, resume AutoTravel
local function maybeResumeAutoTravelWhenIdle()
    -- only resume if AutoTravel was paused by collector AND user still wants AutoTravel
    if not state.AutoTravelEnabled then return end
    if state._autoTravelPaused and state._autoTravelPausedByCollector and not hasActiveTargets() then
        local now = tick()
        if now - _lastAutoTravelResume < _AUTO_TRAVEL_RESUME_COOLDOWN then
            if DEBUG then print("[AutoTravel] resume suppressed by cooldown") end
            return
        end
        _lastAutoTravelResume = now

        if DEBUG then print("[AutoTravel] Collector idle -> resuming AutoTravel (guarded)") end
        state._autoTravelPausedByCollector = false
        state._autoTravelPaused = false
        pcall(resumeAutoTravel)
    end
end

local SellState = {
    scanResults = {},
    chosenTypes = {},
    levelThreshold = 1,
}

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
        "Los Tralaleritos","La Vacca Saturno Saturnita","Pot Hotspot","Las Tralaleritas",
        "Chicleteira Bicicleteira"
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
        "Ballerino Lololo","Cocofanto Elefanto","Los Crocodillitos",
        "Piccione Macchina","Tigroligre Frutonni","Trenostruzzo Turbo 3000",
        "Trippi Troppi Troppa Trippa","Tukanno Bananno","Udin Din Din Dun",
        "Orcalero Orcala","Giraffa Celeste","Tralalero Tralala"
    },
    Rare = { 
        "Trulimero Trulicina","Ti Ti Ti Sahur","Salamino Penguino",
        "Perochello Lemonchello","Penguino Cocosino","Cappuccino Assassino",
        "Bananita Dolphinita","Bambini Crostini","Brr Brr Patapim","Avocadini Guffo"
    },
    Secret = { 
        "Bambooini Bombini","Eek Eek Eek Sahur","Marietti Frigo",
        "La Vacca Black Hole Goat","Fragola La La La","Aura Farma",
        "Los Tungtungtungcitos","Los Combinasionas","Espresso Signora",
        "Unclito Samito","Gattatino Neonino","Gatattino Donutino",
        "Statutino Libertino","Capybara Monitora","Tractoro Dinosauro",
        "Mastodontico Telepiedone","Patatino Astronauta","Matteo","Patito Dinerito",
        "Onionello Penguini","Sausaggini Sanitario","Rainbow 67"
    },
    Uncommon = { 
        "Trippi Troppi","Tric Tric Baraboom","Ta Ta Ta Sahur","Pipi Avocado",
        "Gangster Footera","Cacto Hipopotamo","Boneca Ambalabu","Bobrito Bandito",
        "67"
    },
    Common = { 
        "Tim Cheese","Talpa Di Fero","Svinino Bombondino","Pipi Kiwi",
        "Pipi Corni","Noobini Cakenini","Lirili Larila","Frulli Frulla"
    },
    Divine = { 
        "Strawberry Elephant","Burgerini Bearini","Bulbito Bandito Traktorito",
        "Martino Gravitino","Galactio Fantasma","Din Din Vaultero","Grappellino D'Oro",
        "Rubichetto Cubini","Glacierello Infernetti","Freezeti Cobretti"
    },
    Infinity = { 
        "Noobini Infeeny","Meta Technetta","Biscotti Macarotti",
        "Cioccolatone Draghettone","Tartarughi Attrezzini","Kissarini Heartini",
        "Polpo Semaforini","Cupitron Consoletron","Anububu","Gatti Marshmallini" }
}

local function buildLookups()
    SellState.BRAINROT_LOOKUP = {}
    for rarity, list in pairs(SellState.BRAINROT_LISTS) do
        local t = {}
        for _, name in ipairs(list) do t[string.lower(name)] = true end
        SellState.BRAINROT_LOOKUP[rarity] = t
    end
end

buildLookups() -- ← BUILD IMMEDIATELY

------------------------------------------------------
-- AUTO TRADE SECION CORE FUNCTIONS
------------------------------------------------------
-- <<===== ADD THIS BLOCK INTO HELPERS / CORE SECTION (before UI window creation) =====>>
-- Safe, robust helpers untuk fitur Auto Trade / Auto Gift
local function getRemote(path)
    if not path or type(path) ~= "table" then return nil end
    local cur = ReplicatedStorage
    for _, p in ipairs(path) do
        if not cur then return nil end
        cur = cur:FindFirstChild(p)
    end
    return cur
end

local function initTradeRemotes()
    -- initialize once, safe pcall
    state.SendGiftRF     = state.SendGiftRF     or getRemote({ "Packages","Net","RF/Trade.SendGift" })
    state.SendTradeRF    = state.SendTradeRF    or getRemote({ "Packages","Net","RF/Trade.SendTrade" })
    state.SetSlotOfferRF = state.SetSlotOfferRF or getRemote({ "Packages","Net","RF/Trade.SetSlotOffer" })
    state.ReadyTradeRE   = state.ReadyTradeRE   or getRemote({ "Packages","Net","RE/Trade.ReadyTrade" })
    -- fallback / older structure
    state.RemoteEventsFolder = state.RemoteEventsFolder or ReplicatedStorage:FindFirstChild("RemoteEvents")
end

local function getBackpack()
    return Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("Backpack")
end

local function getPlayerNames()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(out, p.Name) end
    end
    table.sort(out)
    return out
end

-- Build name->rarity map from SellState if available
local function ensureNameToRarityMap()
    if not state.BRAINROT_NAME_TO_RARITY or next(state.BRAINROT_NAME_TO_RARITY or {}) == nil then
        state.BRAINROT_NAME_TO_RARITY = state.BRAINROT_NAME_TO_RARITY or {}
        if type(SellState) == "table" and SellState.BRAINROT_LISTS then
            for rarity, list in pairs(SellState.BRAINROT_LISTS) do
                for _, name in ipairs(list) do
                    if name and type(name) == "string" then
                        state.BRAINROT_NAME_TO_RARITY[name] = rarity
                    end
                end
            end
        end
    end
end

-- Scan backpack for brainrots matching selectedSet (map rarity->true)
local function scanBrainrotsByRarity(selectedSet)
    local results = {}
    if not selectedSet or next(selectedSet or {}) == nil then return results end
    local bp = getBackpack()
    if not bp then return results end

    ensureNameToRarityMap()

    for _, tool in ipairs(bp:GetChildren()) do
        if tool and tool:IsA("Tool") then
            local rm = tool:FindFirstChild("RenderModel")
            if rm and rm.GetAttribute then
                local ok, name = pcall(function() return rm:GetAttribute("BrainrotName") end)
                name = ok and name and tostring(name) or nil

                local rarity = nil
                if name then
                    rarity = state.BRAINROT_NAME_TO_RARITY[name]
                end

                if not rarity then
                    local ok2, r2 = pcall(function() return rm:GetAttribute("Rarity") or rm:GetAttribute("BrainrotRarity") end)
                    rarity = ok2 and r2 and tostring(r2) or nil
                end

                if rarity and selectedSet[rarity] then
                    table.insert(results, {
                        uuid = tool.Name,
                        rarity = rarity,
                        brainrotName = name,
                        tool = tool,
                        type = "brainrot"
                    })
                end
            end
        end
    end

    return results
end

-- Scan backpack for lucky blocks matching selectedSet (map rarity->true)
local function scanLuckyBlocksByRarity(selectedSet)
    local results = {}
    if not selectedSet or next(selectedSet or {}) == nil then return results end
    local bp = getBackpack()
    if not bp then return results end

    for _, tool in ipairs(bp:GetChildren()) do
        if tool and tool:IsA("Tool") then
            local rig = tool:FindFirstChild("LuckyBlockRig")
            if rig and rig.GetAttribute then
                local ok, r = pcall(function() return rig:GetAttribute("LuckyBlockType") end)
                local rarity = ok and r and tostring(r) or nil
                if rarity and selectedSet[rarity] then
                    table.insert(results, {
                        uuid = tool.Name,
                        rarity = rarity,
                        tool = tool,
                        type = "lucky"
                    })
                end
            end
        end
    end

    return results
end

-- Collect items prioritized: lucky first then brainrot
local function collectItemsForTrade()
    local out = {}
    for _, v in ipairs(scanLuckyBlocksByRarity(state.LuckySet or {})) do table.insert(out, v) end
    for _, v in ipairs(scanBrainrotsByRarity(state.BrainrotSet or {})) do table.insert(out, v) end
    return out
end

-- perform a single gift to target player using entry (entry.tool must be in backpack)
-- returns ok(boolean), info(string)
local function performSingleGift(target, entry)
    if not target or not target.Parent then return false, "no_target" end
    if not entry or not entry.tool or not entry.tool.Parent then return false, "no_tool" end

    -- equip then attempt RF or fallback RemoteEvents
    local hum = getHumanoid()
    if hum then
        pcall(function() hum:EquipTool(entry.tool) end)
        task.wait(0.12)
    end

    initTradeRemotes()

    if state.SendGiftRF and state.SendGiftRF.InvokeServer then
        local ok, res = pcall(function() return state.SendGiftRF:InvokeServer(target) end)
        if ok then return true, res else return false, tostring(res) end
    end

    -- fallback: RemoteEvents PromptGift
    if state.RemoteEventsFolder and state.RemoteEventsFolder:FindFirstChild("PromptGift") then
        local fallback = state.RemoteEventsFolder:FindFirstChild("PromptGift")
        local ok, err = pcall(function() fallback:FireServer(target) end)
        return ok, ok and "fallback_prompt" or tostring(err)
    end

    return false, "no_method"
end

-- perform one trade iteration using state.* remotes. returns ok(boolean), info (string or number)
local function performTradeIteration(target)
    if not target or not target.Parent then return false, "no_target" end

    initTradeRemotes()

    local items = collectItemsForTrade()
    if not items or #items == 0 then return false, "no_items" end

    if state.SendTradeRF and state.SendTradeRF.InvokeServer then
        local ok, err = pcall(function() state.SendTradeRF:InvokeServer(target) end)
        if not ok then return false, tostring(err) end
    else
        return false, "no_sendtrade_rf"
    end

    -- tunggu sebelum mulai mengisi slot (biarkan server buka trade window)
    task.wait(tonumber(state.SEND_TRADE_WAIT) or 5.0)

    local toFill = math.min(#items, tonumber(state.MAX_SLOTS) or 6)
    local filled = 0
    for slot = 1, toFill do
        local entry = items[slot]
        if entry and entry.uuid and state.SetSlotOfferRF and state.SetSlotOfferRF.InvokeServer then
            pcall(function()
                -- server expects slot index string and uuid string in many implementations
                state.SetSlotOfferRF:InvokeServer(tostring(slot), tostring(entry.uuid))
            end)
            filled = filled + 1
            task.wait(0.12)
        end
    end

    if filled == 0 then
        return false, "no_slots_filled"
    end

    -- tunggu setelah fill sesuai keinginan (mis. 4 detik)
    task.wait(tonumber(state.POST_FILL_WAIT) or 4.0)

    -- tekan Accept / ReadyTrade (safe pcall)
    if state.ReadyTradeRE and state.ReadyTradeRE.FireServer then
        pcall(function() state.ReadyTradeRE:FireServer(true) end)
    end

    -- TUNGGU LAMA SETELAH ACCEPT agar trade sempat diproses (mis. 5 detik)
    task.wait(tonumber(state.POST_ACCEPT_WAIT) or 5.0)

    -- kembalikan sukses + jumlah slot terisi
    return true, filled
end

-- Export helpers into state for easier reuse by UI callbacks
state.initTradeRemotes = initTradeRemotes
state.getPlayerNames = getPlayerNames
state.collectItemsForTrade = collectItemsForTrade
state.performSingleGift = performSingleGift
state.performTradeIteration = performTradeIteration
-- <<===== END AUTO TRADE / GIFT HELPERS =====>>

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
            state.WindUI:Notify({ Title = "Obby Gold Error", Content = "Obby Not Found", Duration = 3 })
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
                    state.WindUI:Notify({ Title = "Obby Gold", Content = "Running...", Duration = 2 })
                else
                    print("[Obby Gold] Failed to teleport to", pair.start)
                    continue
                end
                task.wait(1)
                print("[Obby Gold] Teleporting to", pair.finish)
                if teleportToPart(endPart) then
                    state.WindUI:Notify({ Title = "Obby Gold", Content = "Running...", Duration = 2 })
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
    state.WindUI:Notify({ Title = "Obby Gold", Content = "Stopped.", Duration = 2 })
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
local DISTANCE_THRESHOLD = 5000 -- distance max untuk auto collect coin

local function isCoinEnabled(group)
    if not state.ActivateCollectCoin then return false end
    return state.CollectCoins and state.CollectCoins[group]
end

RunService.Heartbeat:Connect(function()

    if not state.ActivateCollectCoin then return end

    local hrp = getRoot()
    if not hrp then return end

    for coinName, cache in pairs(state.coinCache) do

        local enabled = false

        if coinName == "Radioactive Coin" then
            enabled = isCoinEnabled("Radioactive Coin")

        elseif coinName == "UFO Coin" then
            enabled = isCoinEnabled("UFO Coin")

        elseif coinName == "GoldBar" then
            enabled = isCoinEnabled("Gold Bar")

        elseif coinName == "Ticket" or coinName == "Game Console" then
            enabled = isCoinEnabled("Arcade")

        elseif coinName == "HeartCandy1"
            or coinName == "HeartCandy2"
            or coinName == "HeartCandy3"
            or coinName == "lovetoken" then
            enabled = isCoinEnabled("Valentine")
        end

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
                        pcall(function()
                            part.CFrame = hrp.CFrame * offset
                        end)
                    end
                    ptr += 1
                end
            end

            state.cachePointers[coinName] = ptr
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
    if not targetPosVec3 then return false end
    cancelLastTween()

    local hrp = getRoot()
    local hum = getHumanoid()
    if not hrp or not hum then return false end

    local startPos = hrp.Position
    local targetPos = Vector3.new(targetPosVec3.X, startPos.Y, targetPosVec3.Z)
    local distance = (startPos - targetPos).Magnitude
    if distance < 1 then return true end

    local speed = (state.TWEEN_SPEED or 400) * (speedMultiplier or 1)
    local duration = math.clamp(distance / speed, 0.12, 2.5)

    -- Set Physics state agar tween bisa berjalan
    local prevState = hum:GetState()
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
    state.lastTween = tween

    local completed = false
    local conn
    conn = tween.Completed:Connect(function()
        completed = true
        conn:Disconnect()
    end)

    tween:Play()

    -- Tunggu hingga tween selesai atau timeout
    local startTime = tick()
    local timeout = duration + 2.0
    while not completed and (tick() - startTime) < timeout do
        task.wait(0.05)
    end

    if not completed then
        pcall(function() tween:Cancel() end)
    end

    if conn and conn.Connected then
        conn:Disconnect()
    end

    state.lastTween = nil
    hum:ChangeState(prevState or Enum.HumanoidStateType.Running)

    -- ===== VALIDASI AKHIR =====
    local finalHrp = getRoot()
    if finalHrp then
        local finalDist = (finalHrp.Position - targetPos).Magnitude
        if finalDist > 8 then
            -- Jika masih jauh, teleport paksa
            pcall(function() finalHrp.CFrame = CFrame.new(targetPos) end)
            task.wait(0.05)
        end
    end

    return true
end

local function tweenToFloor(floor, isAutoMove)
    if not floor or not floor.name then return false end

    -- Ambil CFrame asli dari map
    local cf = getFloorCFrame(floor.name)
    local targetX = cf and cf.Position.X or floor.x
    local hrp = getRoot()
    if not hrp then return false end
    local hum = getHumanoid()
    if hum and hum.Health <= 0 then return false end

    -- Posisi target di platform (Y=0, Z sesuai konstanta)
    local targetZ = state.START_POS.Z
        - state.PLATFORM_WIDTH_Z/2
        - state.WALL_THICKNESS/2
        + state.WALL_IN_OUT_OFFSET
        - state.WALL_SAFE_DISTANCE

    local targetPos = Vector3.new(targetX, 0, targetZ)
    local speedMult = isAutoMove and state.AUTO_MOVE_SPEED_MULT or 1

    local success = pcall(function()
        moveHRPToPosition(targetPos, speedMult)
    end)
    return success
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

-- ============================
-- AUTO TRAVEL PAUSE / RESUME
-- ============================
-- Pause AutoTravel tanpa mengubah preferensi user (state.AutoTravelEnabled tetap utuh)
local function pauseAutoTravel()
    if state._autoTravelPaused then return end
    state._autoTravelPaused = true
    -- cancel running task (jangan set AutoTravelEnabled = false)
    if state.autoTravelTask then
        pcall(function() task.cancel(state.autoTravelTask) end)
        state.autoTravelTask = nil
    end
    -- hentikan tween yang mungkin masih berjalan
    cancelLastTween()
    if DEBUG then print("[AutoTravel] paused by system") end
end

local function resumeAutoTravel()
    if not state._autoTravelPaused then return end
    state._autoTravelPaused = false
    -- restart tugas auto travel jika user masih menginginkan AutoTravel
    if state.AutoTravelEnabled and not state.autoTravelTask then
        -- gunakan pcall agar aman
        pcall(startAutoTravel)
    end
    if DEBUG then print("[AutoTravel] resumed by system") end
end

-- =============================================
-- AUTO TRAVEL CORE
-- =============================================
local function startAutoTravel()
    -- allow resume if paused by collector but there are no active targets now
    if state._autoTravelPaused then
        if state._autoTravelPausedByCollector and not hasActiveTargets() and state.AutoTravelEnabled then
            if DEBUG then print("[AutoTravel] unpausing (collector idle) and proceeding to start") end
            state._autoTravelPaused = false
            state._autoTravelPausedByCollector = false
        else
            if DEBUG then print("[AutoTravel] start requested but currently paused; aborting start") end
            return
        end
    end

    if state.autoTravelTask then 
        if DEBUG then print("[AutoTravel] Task already exists, cancelling old one") end
        task.cancel(state.autoTravelTask)
        state.autoTravelTask = nil
    end

    if DEBUG then print("[AutoTravel] Starting... AutoTravelEnabled =", state.AutoTravelEnabled) end
    state.autoTravelTask = task.spawn(function()
        print("[AutoTravel] Task spawned")
        while state.AutoTravelEnabled do
            print("[AutoTravel] Loop - hasActiveTargets =", hasActiveTargets())
            
            if hasActiveTargets() then
                print("[AutoTravel] PAUSED due to active targets")
                task.wait(0.5)
                continue
            end

            -- 1. Pastikan di Start Floor
            local startFloor = state.Floors[1]
            local hrp = getRoot()
            if hrp then
                local distToStart = math.abs(hrp.Position.X - startFloor.x)
                print("[AutoTravel] Distance to Start:", distToStart)
                if distToStart > 8 then
                    print("[AutoTravel] Moving to Start...")
                    tweenToFloor(startFloor, true)
                    task.wait(0.6)
                end
            else
                print("[AutoTravel] HRP is nil")
            end

            -- 2. Maju dari Common sampai Celestial
            for i = 2, #state.Floors do
                if not state.AutoTravelEnabled then break end
                if hasActiveTargets() then 
                    print("[AutoTravel] PAUSED during travel")
                    break 
                end
                
                local floor = state.Floors[i]
                print("[AutoTravel] Moving to", floor.name)
                tweenToFloor(floor, true)
                task.wait(0.5)
            end

            -- 3. Kembali ke Start
            if state.AutoTravelEnabled and not hasActiveTargets() then
                print("[AutoTravel] Returning to Start")
                tweenToFloor(state.Floors[1], true)
                task.wait(0.5)
            end
        end
        print("[AutoTravel] Task ended")
        state.autoTravelTask = nil
    end)
end

local function stopAutoTravel()
    state.AutoTravelEnabled = false
    if state.autoTravelTask then
        task.cancel(state.autoTravelTask)
        state.autoTravelTask = nil
    end
    cancelLastTween()
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
    state.WindUI:Notify({ Title = "Auto Collect", Content = "Stopped.", Duration = 2 })
    print("[SYSTEM] All auto collect systems stopped (manual stop)")
end

local old_stopAllAutoCollect = stopAllAutoCollect
stopAllAutoCollect = function(...)
    if DEBUG then
        print("[DEBUG] stopAllAutoCollect called. stack:\n" .. (debug.traceback("",2) or "no traceback"))
    end
    return old_stopAllAutoCollect(...)
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
                        lastTry = 0,
                        queuedAt = tick()  -- Tambahkan timestamp untuk sorting
                    })
                end
            end
        end
    end
    
    -- sort queue setelah menambahkan
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

-- helper: pastikan kembali ke START dengan retry + fallback
local function ensureReturnToStart(maxRetries)
    maxRetries = tonumber(maxRetries) or 3
    local tries = 0
    local targetFloor = state.Floors[1]
    if not targetFloor then return end

    local function atStart()
        local hrp = getRoot()
        if not hrp then return false end
        return math.abs(hrp.Position.X - (targetFloor.x or 0)) <= 8 -- threshold bisa di-tune
    end

    while tries < maxRetries and not atStart() do
        tries = tries + 1
        -- gunakan pcall untuk menghindari error blocking
        pcall(function() tweenToFloor(targetFloor, true) end)
        task.wait(0.28) -- beri waktu tween + replication
        -- jika setelah tween masih belum dekat, coba langsung moveHRPToPosition ke base pos
        if not atStart() then
            local basePos = getBasePositionForFloor(targetFloor)
            if basePos then
                pcall(function() moveHRPToPosition(basePos, state.AUTO_MOVE_SPEED_MULT) end)
            end
            task.wait(0.22)
        end
    end

    -- final check: jika masih belum di start, lakukan satu kali respawn attempt (safer fallback)
    if not atStart() then
        if state.DEBUG_LUCKY then
            print("[LuckyFix] ensureReturnToStart: fallback teleporting to exact X")
        end
        local hrp = getRoot()
        local basePos = getBasePositionForFloor(targetFloor)
        if hrp and basePos then
            pcall(function() hrp.CFrame = CFrame.new(Vector3.new(targetFloor.x or basePos.X, hrp.Position.Y, basePos.Z)) end)
            task.wait(0.12)
        end
    end
end

-- PERBAIKAN: Fungsi startAutoCollectLuckyBlock - Pastikan karakter selalu kembali ke posisi start setelah mengolah block
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

                -- Jika masih kosong → exit lucky mode
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

            -- Jika block sudah hilang → sukses
            if not lb or not lb.Parent then
                table.remove(state.LuckyBlockQueue, 1)
                task.wait(0.1)
                continue
            end

            -- Retry delay
            if tick() - (blockData.lastTry or 0) < state.LUCKY_RETRY_DELAY then
                table.insert(state.LuckyBlockQueue, table.remove(state.LuckyBlockQueue, 1))
                task.wait(0.1)
                continue
            end

            -- Enable platform jika perlu
            if not state.platformEnabled then
                state.platformEnabled = true
                enablePlatform()
                task.wait(0.6)
            end

            blockData.lastTry = tick()
            blockData.attempts += 1

            ----------------------------------------------------------------
            -- STEP 1: START (floor 1) - PASTIKAN KARAKTER DI START
            ----------------------------------------------------------------
            local maxRetry = 3
            local retryCount = 0
            local startReached = false
            while retryCount < maxRetry and not startReached do
                retryCount = retryCount + 1
                tweenToFloor(state.Floors[1], true)
                task.wait(0.3)  -- beri waktu tween bekerja
                local hrpNow = getRoot()
                if hrpNow then
                    local distX = math.abs(hrpNow.Position.X - state.Floors[1].x)
                    if distX <= 8 then
                        startReached = true
                    end
                end
            end
            if not startReached then
                -- fallback: teleport paksa
                local hrp = getRoot()
                if hrp then
                    local basePos = getBasePositionForFloor(state.Floors[1])
                    if basePos then
                        pcall(function() hrp.CFrame = CFrame.new(basePos) end)
                    end
                end
                task.wait(0.2)
            end

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
            -- STEP 5: BALIK KE START - PASTIKAN KEMBALI KE START
            ----------------------------------------------------------------
            tweenToFloor(state.Floors[1], true)
            -- Tunggu hingga karakter benar-benar kembali ke start
            local waitBackTime = tick()
            local waitBackHrp = getRoot()
            local waitBackTargetX = state.Floors[1].x
            local waitBackTolerance = 5
            while waitBackHrp and (math.abs(waitBackHrp.Position.X - waitBackTargetX) > waitBackTolerance) and (tick() - waitBackTime < 3) do
                task.wait(0.05)
                waitBackHrp = getRoot()
            end
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

-- Tambahkan fungsi ini setelah fungsi refreshLuckyBlockQueueForTargets
local function refreshTargetQueueForAutoCollect()
    if not state.AutoCollectTarget then return end
    
    -- Refresh lucky block queue
    refreshLuckyBlockQueueForTargets()
    enqueueExistingLuckyBlocks()
    sortLuckyBlockQueue()
    
    -- Beri notifikasi
    state.WindUI:Notify({ Title = "Target", Content = "Updated.", Duration = 2 })
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

    -- Lepaskan listener
    detachLuckyBlockWatcher()

    -- Kosongkan queue dan cache
    state.LuckyBlockQueue = {}
    state.LuckyBlockSeen = {}
    state.brainrotCache = {}

    -- Reset semua pending flags
    state.pendingRestartCollectBlock = false
    state.pendingRestartCollectRarity = false
    state.pendingRestartCollectTarget = false

    -- 🔥 FORCE RESET FLAG (tambahan)
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

-- =============================================
-- FUNGSI TAMBAHAN UNTUK REFRESH QUEUE
-- =============================================
local function refreshLuckyBlockQueueForTargets()
    -- Jika targets kosong => artinya semua diizinkan
    if next(state.LuckyBlockTargets) == nil then 
        -- Kosongkan queue jika sebelumnya ada target
        if #state.LuckyBlockQueue > 0 then
            state.LuckyBlockQueue = {}
            state.LuckyBlockSeen = {}
            enqueueExistingLuckyBlocks()
        end
        return 
    end
    
    -- Hapus items yang tidak match targets
    local removedCount = 0
    for i = #state.LuckyBlockQueue, 1, -1 do
        local it = state.LuckyBlockQueue[i]
        if it and it.blockType then
            if not state.LuckyBlockTargets[it.blockType] then
                -- Hapus dari seen dan queue
                if it.model then
                    state.LuckyBlockSeen[it.model] = nil
                end
                table.remove(state.LuckyBlockQueue, i)
                removedCount = removedCount + 1
            end
        end
    end
    
    -- Tambahkan items yang sesuai target dari existing blocks
    local addedCount = 0
    local root = Workspace:FindFirstChild("ActiveLuckyBlocks")
    if root then
        for _, lb in ipairs(root:GetChildren()) do
            if lb and lb.Parent and not state.LuckyBlockSeen[lb] then
                local ok, pivotPos = pcall(function() return safeGetPivotPosition(lb) end)
                if ok and pivotPos then
                    local blockType = safeGetAttr(lb, "LuckyBlockType")
                    if blockType and state.LuckyBlockTargets[blockType] then
                        state.LuckyBlockSeen[lb] = true
                        table.insert(state.LuckyBlockQueue, {
                            model = lb,
                            pos = pivotPos,
                            spawnedFloor = trim(safeGetAttr(lb, "SpawnedFloor") or ""),
                            blockType = blockType,
                            attempts = 0,
                            lastTry = 0,
                            queuedAt = tick()
                        })
                        addedCount = addedCount + 1
                    end
                end
            end
        end
    end
    
    -- Sort queue setelah perubahan
    sortLuckyBlockQueue()
    
    if state.DEBUG_LUCKY then
        print(string.format("[Refresh Queue] Removed: %d, Added: %d, Total: %d", 
            removedCount, addedCount, #state.LuckyBlockQueue))
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
        state.WindUI:Notify({ Title = "Error", Content = "Select at least one target.", Duration = 3 })
        return
    end

    if not state.platformEnabled then
        state.WindUI:Notify({ Title = "Error", Content = "Platform must be enabled.", Duration = 3 })
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

    -- 🔥 TRACKING STATE UNTUK SMART PAUSE/RESUME
    local lastActiveState = false  -- track apakah ada target aktif di loop sebelumnya

    -- Inisialisasi hash untuk tracking perubahan target
    state.lastLuckyTargetsHash = game:GetService("HttpService"):JSONEncode(state.LuckyBlockTargets)
    state.lastBrainrotTargetsHash = game:GetService("HttpService"):JSONEncode(state.selectedRarities)

    -- Start scanner SEBELUM loop (tunggu sampai siap)
    if not state.scannerEnabled then
        startRealtimeScanner()
        task.wait(0.5)  -- 🔥 PENTING: tunggu scanner sempat scan
    end

    enqueueExistingLuckyBlocks()
    attachActiveLuckyBlocksWatcher()

    -- ===============================
    -- CONTROLLER TASK (FIXED ANTI-SPAM)
    -- ===============================
    state.autoCollectTargetTask = task.spawn(function()
        while state.AutoCollectTarget do
            -- =============================================
            -- DETEKSI PERUBAHAN TARGET (REALTIME MONITOR)
            -- =============================================
            local okA, currentLuckyHash = pcall(function() return HttpService:JSONEncode(state.LuckyBlockTargets) end)
            local okB, currentBrainrotHash = pcall(function() return HttpService:JSONEncode(state.selectedRarities) end)
            currentLuckyHash = okA and currentLuckyHash or ""
            currentBrainrotHash = okB and currentBrainrotHash or ""

            -- Jika ada perubahan pada target Lucky Block
            if currentLuckyHash ~= state.lastLuckyTargetsHash then
                state.lastLuckyTargetsHash = currentLuckyHash
                refreshLuckyBlockQueueForTargets()
                if state.autoCollectBlockEnabled then
                    stopAutoCollectLuckyBlock()
                    task.wait(0.08)
                    if #state.LuckyBlockQueue > 0 then
                        state.autoCollectBlockEnabled = true
                        startAutoCollectLuckyBlock()
                    else
                        state.autoCollectBlockEnabled = false
                    end
                end
                if state.WindUI then state.WindUI:Notify({ Title = "Lucky Block", Content = "Updated.", Duration = 2 }) end
            end

            -- Jika ada perubahan pada target Brainrot
            if currentBrainrotHash ~= state.lastBrainrotTargetsHash then
                state.lastBrainrotTargetsHash = currentBrainrotHash
                if state.autoCollectEnabled then
                    stopAutoCollect()
                    task.wait(0.08)
                    if next(state.selectedRarities) ~= nil then
                        state.autoCollectEnabled = true
                        startAutoCollectBrainrotByRarity()
                    else
                        state.autoCollectEnabled = false
                    end
                end
                if state.WindUI then state.WindUI:Notify({ Title = "Brainrot", Content = "Target updated.", Duration = 2 }) end
            end

            -- =============================================
            -- 🔥 CEK APAKAH ADA TARGET AKTIF (REAL CHECK)
            -- =============================================
            local hasActiveNow = false

            -- Cek Lucky Block Queue
            if #state.LuckyBlockQueue > 0 then
                hasActiveNow = true
            end

            -- Cek Brainrot Cache (HARUS ADA BRAINROT NYATA, BUKAN HANYA selectedRarities)
            if next(state.selectedRarities) ~= nil then
                for rarity, list in pairs(state.brainrotCache or {}) do
                    if state.selectedRarities[rarity] and list and #list > 0 then
                        hasActiveNow = true
                        break
                    end
                end
            end

            -- =============================================
            -- 🔥 SMART PAUSE/RESUME (ANTI-SPAM)
            -- =============================================
            if hasActiveNow and not lastActiveState then
                -- 🔴 TRANSITION: IDLE → ACTIVE (ada target baru)
                if DEBUG then print("[AutoCollectTarget] Target detected -> pausing AutoTravel") end
                
                if state.AutoTravelEnabled and not state._autoTravelPaused then
                    state._autoTravelPausedByCollector = true
                    pauseAutoTravel()
                    ensureReturnToStart(4)
                    task.wait(0.35)
                end
                
                lastActiveState = true

            elseif not hasActiveNow and lastActiveState then
                -- 🟢 TRANSITION: ACTIVE → IDLE (target habis)
                if DEBUG then print("[AutoCollectTarget] No targets -> resuming AutoTravel") end
                
                if state._autoTravelPausedByCollector and state.AutoTravelEnabled then
                    state._autoTravelPausedByCollector = false
                    resumeAutoTravel()
                end
                
                lastActiveState = false
            end
            -- ⚪ NO TRANSITION: state sama → tidak perlu pause/resume lagi

            -- =============================================
            -- LOGIKA PRIORITAS UTAMA (Lucky Block > Brainrot)
            -- =============================================
            if #state.LuckyBlockQueue > 0 then
                -- Start lucky collector jika belum jalan
                if not state.autoCollectBlockEnabled then
                    stopAutoCollect()
                    state.autoCollectBlockEnabled = true
                    startAutoCollectLuckyBlock()
                end
                task.wait(0.25)
                continue

            elseif next(state.selectedRarities) ~= nil then
                -- Cek apakah ada brainrot nyata
                local hasBrainrotFound = false
                for rarity, list in pairs(state.brainrotCache or {}) do
                    if state.selectedRarities[rarity] and list and #list > 0 then
                        hasBrainrotFound = true
                        break
                    end
                end

                if hasBrainrotFound then
                    -- Start brainrot collector jika belum jalan
                    if not state.autoCollectEnabled then
                        stopAutoCollectLuckyBlock()
                        state.autoCollectEnabled = true
                        startAutoCollectBrainrotByRarity()
                    end
                else
                    -- Tidak ada brainrot nyata -> stop collector
                    if state.autoCollectEnabled then
                        stopAutoCollect()
                    end
                end
                
                task.wait(0.25)
                continue

            else
                -- TIDAK ADA TARGET SAMA SEKALI
                task.wait(0.4)
            end
            
            task.wait(0.25)
        end  -- ⬅️ INI PENUTUP while state.AutoCollectTarget do
        
        -- =============================================
        -- CLEANUP KETIKA CONTROLLER BERHENTI
        -- =============================================
        if DEBUG then print("[AutoCollectTarget] Controller task ending, running cleanup...") end
        
        pcall(function()
            stopAutoCollectLuckyBlock()
            stopAllAutoCollect()
            stopRealtimeScanner()
        end)
        
        state.autoCollectTargetTask = nil

        -- 🔥 FORCE RESUME AUTO TRAVEL (CRITICAL FIX)
        -- Pastikan AutoTravel resume bahkan kalau ada respawn
        if state._autoTravelPausedByCollector then
            if DEBUG then print("[AutoCollectTarget] Force resuming AutoTravel on cleanup") end
            state._autoTravelPausedByCollector = false
            state._autoTravelPaused = false
            
            -- Tunggu sedikit kalau karakter baru respawn
            task.wait(0.5)
            
            if state.AutoTravelEnabled and not state.autoTravelTask then
                pcall(startAutoTravel)
            end
        end
    end)
    
    state.WindUI:Notify({ Title = "Auto Collect", Content = "Active.", Duration = 3 })
end

-- =============================================
-- UPDATE DROPDOWN CALLBACK (DI TAB RUN)
-- =============================================
-- Di dalam RunTab, pastikan dropdown Target Lucky Block memiliki callback ini:
-- (Tambahkan setelah fungsi startAutoCollectTarget)

local function updateLuckyBlockDropdownCallback(selectedList)
    state.LuckyBlockTargets = {}
    for _, v in ipairs(selectedList) do 
        state.LuckyBlockTargets[tostring(v)] = true 
    end

    -- Jika Auto Collect Target aktif, refresh queue
    if state.AutoCollectTarget then
        -- Hash akan terdeteksi otomatis oleh controller
        state.WindUI:Notify({ Title = "Target", Content = "Targets will update automatically.", Duration = 2 })
    -- Jika hanya auto collect lucky block biasa
    elseif state.autoCollectBlockEnabled then
        refreshLuckyBlockQueueForTargets()
        state.WindUI:Notify({ Title = "Lucky Block", Content = "Targets updated and ready.", Duration = 2 })
    end
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

    -- Ambil karakter pemain dan semua descendant-nya
    local character = LocalPlayer.Character
    local playerParts = {}
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                playerParts[part] = true
            end
        end
    end

    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            -- Lewati part milik platform/wall
            if table.find(state.platformParts, v) or table.find(state.wallParts, v) then
                continue
            end

            -- ❗ LEWATI PART MILIK KARAKTER PEMAIN
            if playerParts[v] then
                continue
            end

            local p = v.Position
            if p.X >= minX and p.X <= maxX and math.abs(p.Z - state.START_POS.Z) <= zPad and p.Y > topY then
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

-- Fungsi untuk menghapus part VIP/VIP_PLUS/Wall
-- ====================================================================
-- UPDATED: removeVIPAndWalls (now also deletes Wall & RightWalls in OG)
-- ====================================================================
local function removeVIPAndWalls()
    for _, v in ipairs(Workspace:GetDescendants()) do
        -- 1) Hapus VIP dan VIP_PLUS di dalam VIPWalls
        if v:IsA("BasePart") and v.Parent and v.Parent.Name == "VIPWalls" and (v.Name == "VIP" or v.Name == "VIP_PLUS") then
            pcall(function() v:Destroy() end)
        
        -- 2) Hapus Wall (Model) di dalam Walls
        elseif v:IsA("Model") and v.Parent and v.Parent.Name == "Walls" and v.Name == "Wall" then
            pcall(function() v:Destroy() end)
        
        -- 3) Hapus semua model di dalam RightWalls (RightWall1 .. RightWall7)
        elseif v:IsA("Model") and v.Parent and v.Parent.Name == "RightWalls" then
            pcall(function() v:Destroy() end)
        
        -- 4) Hapus model Wall dan RightWall* yang berada di folder OG
        elseif v:IsA("Model") and v.Parent and v.Parent.Name == "OG" then
            local name = v.Name
            -- Hapus jika namanya "Wall" atau diawali "RightWall" diikuti angka
            if name == "Wall" or name:match("^RightWall[0-9]+$") then
                pcall(function() v:Destroy() end)
            end
        end
    end
end

-- Fungsi untuk memulai listener VIP/Wall
-- ====================================================================
-- UPDATED: startVIPWallListener (now also removes OG Wall & RightWalls)
-- ====================================================================
local function startVIPWallListener()
    if state.vipWallListenerConn then return end

    state.vipWallListenerConn = Workspace.DescendantAdded:Connect(function(descendant)
        -- 1) Hapus VIP/VIP_PLUS baru di VIPWalls
        if descendant:IsA("BasePart") and descendant.Parent and descendant.Parent.Name == "VIPWalls"
           and (descendant.Name == "VIP" or descendant.Name == "VIP_PLUS") then
            pcall(function() descendant:Destroy() end)
        
        -- 2) Hapus Wall (Model) baru di Walls
        elseif descendant:IsA("Model") and descendant.Parent and descendant.Parent.Name == "Walls"
               and descendant.Name == "Wall" then
            pcall(function() descendant:Destroy() end)
        
        -- 3) Hapus semua model baru di RightWalls
        elseif descendant:IsA("Model") and descendant.Parent and descendant.Parent.Name == "RightWalls" then
            pcall(function() descendant:Destroy() end)
        
        -- 4) Hapus model Wall dan RightWall* baru yang muncul di OG
        elseif descendant:IsA("Model") and descendant.Parent and descendant.Parent.Name == "OG" then
            local name = descendant.Name
            if name == "Wall" or name:match("^RightWall[0-9]+$") then
                pcall(function() descendant:Destroy() end)
            end
        end
    end)
end

-- Fungsi untuk menghentikan listener VIP/Wall
local function stopVIPWallListener()
    if state.vipWallListenerConn then
        state.vipWallListenerConn:Disconnect()
        state.vipWallListenerConn = nil
    end
end

local function enablePlatform()
    if not getRoot() then print("[ERROR] enablePlatform: No character found"); return end
    clearClientParts()
    removeMapWalls()
    
    -- Hapus VIP/Wall/RightWalls yang ada dan mulai listener
    removeVIPAndWalls()       -- <-- sekarang sudah hapus RightWalls juga
    startVIPWallListener()    -- <-- sekarang sudah delete RightWalls otomatis
    
    buildPlatform()
    removePartsAbovePlatform()
end

local function disablePlatform()
    clearClientParts()
    disableVIP_PB()
    stopVIPWallListener()
end

-- respawn / tween cancel handling (platform builder)
local function onCharacterDied_PB()
    local isForceDeath = state.platformBooting
    cancelLastTween()

    -- SIMPAN STATE UNTUK RESTART
    state.pendingRestartMove = state.autoMoveEnabled
    state.pendingRestartCollectRarity = state.autoCollectEnabled
    state.pendingRestartCollect = state.autoCollectEnabled
    state.pendingRestartCollectBlock = state.autoCollectBlockEnabled
    state.pendingRestartCollectTarget = state.AutoCollectTarget
    -- 🔥 TAMBAHAN UNTUK AUTO TRAVEL
    state.pendingRestartTravel = state.AutoTravelEnabled

    state._autoTravelPausedByCollector = state._autoTravelPausedByCollector or false
    state._autoTravelPaused = state._autoTravelPaused or false

    -- Cancel semua task
    if state.autoMoveTask then task.cancel(state.autoMoveTask); state.autoMoveTask = nil end
    if state.autoCollectTask then task.cancel(state.autoCollectTask); state.autoCollectTask = nil end
    if state.autoCollectBlockTask then task.cancel(state.autoCollectBlockTask); state.autoCollectBlockTask = nil end
    if state.autoCollectTargetTask then task.cancel(state.autoCollectTargetTask); state.autoCollectTargetTask = nil end
    -- 🔥 TAMBAHAN UNTUK AUTO TRAVEL
    -- guard: jika task sudah jalan, jangan cancel & restart — cukup return
    if state.autoTravelTask then
        if DEBUG then print("[AutoTravel] Task already running, ignoring start request") end
        return
    end

    --print("[DEATH] Character died. Saved states for restart.")
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
        
        --state.WindUI:Notify({ Title = "Auto Collect", Content = "Resumed after respawn.", Duration = 2 })
        
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
    -- 🔥 RESTART AUTO TRAVEL (FIXED)
    --------------------------------------------------
    if state.pendingRestartTravel then
        state.pendingRestartTravel = false
        
        if DEBUG then print("[AutoTravel][Respawn] Attempting to restart AutoTravel...") end
        
        task.wait(1.2)  -- tunggu platform & karakter stabil
        state.AutoTravelEnabled = true
        
        -- 🔥 CRITICAL FIX: Cek apakah collector benar-benar punya target
        local actuallyHasTargets = false
        if state.AutoCollectTarget then
            -- Cek lucky block queue
            if #state.LuckyBlockQueue > 0 then
                actuallyHasTargets = true
            end
            
            -- Cek brainrot cache (harus ada brainrot nyata)
            if next(state.selectedRarities) ~= nil then
                for rarity, list in pairs(state.brainrotCache or {}) do
                    if state.selectedRarities[rarity] and list and #list > 0 then
                        actuallyHasTargets = true
                        break
                    end
                end
            end
        end
        
        -- Kalau collector pause tapi TIDAK ADA target nyata -> force resume
        if state._autoTravelPausedByCollector and not actuallyHasTargets then
            if DEBUG then print("[AutoTravel][Respawn] Collector idle, force resuming AutoTravel") end
            state._autoTravelPausedByCollector = false
            state._autoTravelPaused = false
        end
        
        -- Start AutoTravel jika tidak di-pause oleh collector (atau collector idle)
        if state._autoTravelPausedByCollector then
            if DEBUG then print("[AutoTravel][Respawn] Suppressed by active collector") end
        else
            if DEBUG then print("[AutoTravel][Respawn] Starting AutoTravel task") end
            pcall(startAutoTravel)
        end
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
-- UI WINDOW (MAIN Hub) - WindUI (wrapped toggles + UI refs)
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
local infoTab = Window:Tab({ Title = "Information", Icon = "info" })
infoTab:Paragraph({ Title = "Welcome To HexaCore Hub Official", Desc = "Youtube Official : Hexacore-OFFICIAL" })
infoTab:Button({ Title = "Copy Discord Link", Callback = function() if setclipboard then setclipboard("https://discord.gg/Wcfqwy6Mdn") end end })
infoTab:Keybind({ Title = "HexaCore Keybind", Value = "p", Callback = function(v) Window:SetToggleKey(Enum.KeyCode[v]) end })

-- MAIN TAB
local MainTab = Window:Tab({ Title = "Main", Icon = "settings-2" })
MainTab:Section({ Title = "Automation" })

-- Auto Collect (wrapped)
createToggle(MainTab, {
    Title = "Auto Collect",
    Default = true,
    Callback = function(v)
        state.AutoCollect = v
        SnapshotUUIDsOnce()
        if v then
            state.autoCollectEnabled = true
            if next(state.selectedRarities) ~= nil then
                pcall(startAutoCollectBrainrotByRarity)
            end
        else
            pcall(stopAllAutoCollect)
            state.autoCollectEnabled = false
        end
    end
}, "AutoCollect")

-- Other automation toggles
createToggle(MainTab, { Title = "Auto Upgrade", Callback = function(v) state.AutoUpgrade = v; SnapshotUUIDsOnce() end }, "AutoUpgrade")
createToggle(MainTab, { Title = "Auto Buy Speed", Callback = function(v) state.AutoBuySpeed = v end }, "AutoBuySpeed")
createToggle(MainTab, { Title = "Auto Rebirth", Callback = function(v) state.AutoRebirth = v end }, "AutoRebirth")
createToggle(MainTab, { Title = "Auto Buy Carry", Callback = function(v) state.AutoBuyCarry = v end }, "AutoBuyCarry")

-- No Clip (kept original behavior, but still store ref)
createToggle(MainTab, {
    Title = "No Clip",
    Callback = function(v)
        state.NoClipEnabled = v
        if v then enableNoClip() else disableNoClip() end
    end
}, "NoClipEnabled")

-- RUN TAB
local RunTab = Window:Tab({ Title = "Run", Icon = "activity" })
RunTab:Section({ Title = "Premium Bypass" })

-- Bypass VIP (set state.BypassVIP supaya tersave)
createToggle(RunTab, {
    Title = "Bypass VIP",
    Callback = function(v)
        state.BypassVIP = v
        -- juga set selective no-clip state (mirror)
        state.SelectiveNoClipEnabled = v
        if v then
            enableSelectiveNoClip()
            enableVIPWallTouchBlock()
        else
            disableSelectiveNoClip()
            disableVIPWallTouchBlock()
        end
    end
}, "BypassVIP")

createToggle(RunTab, {
    Title = "Auto Obby Gold",
    Default = false,
    Callback = function(v)
        state.AutoObbyGoldEnabled = v
        if v then
            stopAutoMove(); stopAutoCollect(); stopAutoCollectLuckyBlock()
            setupObbyListener()
            state.WindUI:Notify({ Title = "Obby Gold", Content = "Starting Auto Obby Gold sequence...", Duration = 2 })
            task.wait(0.5); pcall(startObbyGoldSequence)
        else
            pcall(stopObbyGold)
        end
    end
}, "AutoObbyGoldEnabled")

RunTab:Section({ Title = "Platform Builder" })
createToggle(RunTab, {
    Title = "Platform Builder",
    Description = "ON = Build Platform | OFF = Remove Platform",
    Callback = function(v)
        state.platformEnabled = v
        if v then
            state.platformBooting = true
            stopAutoMove(); stopAutoCollect(); stopAutoCollectLuckyBlock()
            if not getRoot() then waitCharacterReady(); task.wait(1) end
            local success = pcall(function() tweenToFloor(state.Floors[1], true) end)
            if not success then
                state.WindUI:Notify({ Title = "Movement", Content = "Move failed, retrying...", Duration = 2 })
                task.wait(0.5); pcall(function() tweenToFloor(state.Floors[1], true) end)
            end
            task.wait(0.8)
            pcall(enablePlatform)
            state.platformBooting = false
            state.WindUI:Notify({ Title = "Platform", Content = "Platform is ready.", Duration = 2 })
        else
            stopAutoMove(); stopAutoCollect(); stopAutoCollectLuckyBlock()
            pcall(disablePlatform)
            state.WindUI:Notify({ Title = "Platform", Content = "Platform disabled.", Duration = 2 })
        end
    end
}, "platformEnabled")

-- Tween Speed slider (kept)
RunTab:Slider({ Title = "Tween Speed", Value = { Min = 100, Max = 1200, Default = state.TWEEN_SPEED, Step = 10 }, Callback = function(v) state.TWEEN_SPEED = v end })

state.selectedRarities = {
    Infinity = true,
    Divine   = true
}

state.LuckyBlockTargets = {
    Admin       = true,
    Divine      = true,
    Celestial   = true,
    Gamer       = true,
    Radioactive = true,
    Void        = true,
    UFO         = true,
    Alien       = true,
    Jackpot     = true,
    Money       = true
}

-- Floor Navigation
RunTab:Section({ Title = "Auto Collect Brainrot / Block" })
-- =============================================
-- 2. DROPDOWN TARGET BRAINROT
-- =============================================
RunTab:Dropdown({
    Title = "Target Brainrot",
    Values = state.BRAINROT_PRIORITY_ORDER,
    Multi = true,
    Value = {"Infinity", "Divine"},  -- ✅ PAKAI Value, BUKAN Default
    Callback = function(selectedList)
        state.selectedRarities = {}
        for _, rarity in ipairs(selectedList) do 
            state.selectedRarities[rarity] = true 
        end
    end
})

-- =============================================
-- 3. DROPDOWN TARGET LUCKY BLOCK
-- =============================================
RunTab:Dropdown({
    Title = "Target Lucky Block",
    Values = state.LUCKY_PRIORITY_ORDER,
    Multi = true,
    Value = {  -- ✅ SESUAI CONTEKAN: Value = table
        "Admin", "Divine", "Celestial", "Gamer", "Radioactive",
        "Void", "UFO", "Alien", "Jackpot", "Money"
    },
    Callback = function(selectedList)
        state.LuckyBlockTargets = {}
        for _, v in ipairs(selectedList) do 
            state.LuckyBlockTargets[tostring(v)] = true 
        end

        if state.AutoCollectTarget then
            refreshTargetQueueForAutoCollect()
        elseif state.autoCollectBlockEnabled then
            refreshLuckyBlockQueueForTargets()
            enqueueExistingLuckyBlocks()
            sortLuckyBlockQueue()
            state.WindUI:Notify({
                Title = "Lucky Block",
                Content = "Targets updated and ready.",
                Duration = 2
            })
        end
    end
})

RunTab:Slider({ Title = "Jumlah Brainrot per Loop", Description = "Berapa banyak brainrot yang diambil tiap loop (1..6)", Value = { Min = 1, Max = 6, Default = state.BRAINROT_PICK_COUNT, Step = 1 }, Callback = function(v) state.BRAINROT_PICK_COUNT = v end })

createToggle(RunTab, {
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
}, "AutoCollectTarget")

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

createToggle(RunTab, {
    Title = "Auto Move To Target",
    Description = "Bergerak 1 per 1 floor menuju target (melewati tiap floor)",
    Default = false,
    Callback = function(v)
        state.AutoRunEnabled = v
        if v then
            stopAutoCollect()
            state.autoMoveEnabled = true
            pcall(function() startAutoMoveToTarget(state.selectedFloorIndex) end)
        else
            state.autoMoveEnabled = false
            pcall(stopAutoMove)
        end
    end
}, "AutoRunEnabled")

-- EVENT TAB
local EventTab = Window:Tab({ Title = "Event", Icon = "radio" })
EventTab:Section({ Title = "Auto Travel" })
createToggle(EventTab, {
    Title = "Auto Travel",
    Description = "Berjalan otomatis dari Start → Common → ... → Celestial → Start (loop). Prioritas lebih rendah dari Auto Collect Target.",
    Default = false,
    Callback = function(v)
        state.AutoTravelEnabled = v
        if v then
            startAutoTravel()
        else
            stopAutoTravel()
        end
    end
}, "AutoTravelEnabled")

EventTab:Section({ Title = "Event Collect Coins" })

local COIN_OPTIONS = {
    "Radioactive Coin",
    "UFO Coin",
    "Gold Bar",
    "Arcade",
    "Valentine"
}

-- 🔥 FIXED: SIMPAN KE VARIABEL
local CoinDropdown = EventTab:Dropdown({
    Title = "Select Coin",
    Values = COIN_OPTIONS,
    Multi = true,
    Value = (function()
        local selected = {}
        for name, enabled in pairs(state.CollectCoins or {}) do
            if enabled then
                table.insert(selected, name)
            end
        end
        return selected
    end)(),
    Callback = function(selectedList)
        state.CollectCoins = {}
        for _, v in ipairs(selectedList) do
            state.CollectCoins[tostring(v)] = true
        end
        state.WindUI:Notify({
            Title = "Select Coin",
            Content = "Updated.",
            Duration = 1.5
        })
    end
})

-- simpan reference supaya bisa sync saat load config
state.UI_ELEMENTS = state.UI_ELEMENTS or {}
state.UI_ELEMENTS["CollectCoins"] = CoinDropdown

-- Toggle Activation
createToggle(EventTab, {
    Title = "Activate Collect Coin",
    Description = "Enable coin collection from selected coins",
    Default = state.ActivateCollectCoin,
    Callback = function(v)
        state.ActivateCollectCoin = v
        state.WindUI:Notify({
            Title = "Collect Coin",
            Content = v and "Activated" or "Deactivated",
            Duration = 2
        })
    end
}, "ActivateCollectCoin")

EventTab:Section({ Title = "Auto Spin Wheel" })
createToggle(EventTab, { Title = "Auto Spin Radioactive", Callback = function(v) state.AutoSpinRadioactive = v end }, "AutoSpinRadioactive")
createToggle(EventTab, { Title = "Auto Spin UFO", Callback = function(v) state.AutoSpinUFO = v end }, "AutoSpinUFO")
createToggle(EventTab, { Title = "Auto Spin Gold Bar", Callback = function(v) state.AutoSpinGoldBar = v end }, "AutoSpinGoldBar")

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
    SellTab:Input({ Title = "Level (below)", Placeholder = tostring(SellState.levelThreshold), Callback = function(v) local n = tonumber(v); if n and n >= 0 then SellState.levelThreshold = n; state.WindUI:Notify({ Title = "Settings", Content = "Threshold updated.", Duration = 1 }) else state.WindUI:Notify({ Title = "Error", Content = "Please enter a valid number.", Duration = 1 }) end end })
    SellTab:Button({ Title = "Sell Brainrot", Description = "Scan inventory lalu jual semua brainrot yang cocok (type + level below).", Callback = function()
        local found = scanInventory()
        if found == 0 then state.WindUI:Notify({ Title = "Inventory", Content = "No items found.", Duration = 2 }) return end
        local matches = collectMatchesFromScan()
        if #matches == 0 then state.WindUI:Notify({ Title = "Result", Content = "No matching items found.", Duration = 2 }) return end
        state.WindUI:Notify({ Title = "Selling", Content = ("Selling %d items..."):format(#matches), Duration = 2 })
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
        state.WindUI:Notify({ Title = "Done", Content = string.format("Sold %d of %d items.", sold, #matches), Duration = 3 })
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
        if not bp then state.WindUI:Notify({ Title = "Error", Content = "Backpack not found.", Duration = 2 }) return end
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

-- <<===== ADD AUTO TRADE TAB UI (paste after EventTab creation, before Sell Tab) =====>>
local AutoTradeTab = Window:Tab({ Title = "Auto Trade", Icon = "repeat" })
AutoTradeTab:Section({ Title = "Auto Trade Settings" })

-- Target Player dropdown (UI element)
local PlayerDropdown = nil
PlayerDropdown = AutoTradeTab:Dropdown({
    Title = "Target Player",
    Values = getPlayerNames(),
    Callback = function(name)
        state.TargetPlayer = Players:FindFirstChild(name)
    end
})

-- Refresh button (under the dropdown)
AutoTradeTab:Button({
    Title = "🔄 Refresh Player List",
    Callback = function()
        local names = getPlayerNames()

        if PlayerDropdown then
            PlayerDropdown:Refresh(names)
        end
    end
})


-- auto-update when players join/leave (ke UI dropdown)
Players.PlayerAdded:Connect(function()
    if PlayerDropdown and PlayerDropdown.SetValues then PlayerDropdown:SetValues(getPlayerNames()) end
end)
Players.PlayerRemoving:Connect(function()
    if PlayerDropdown and PlayerDropdown.SetValues then PlayerDropdown:SetValues(getPlayerNames()) end
end)

-- Brainrot filter
AutoTradeTab:Dropdown({
    Title = "Brainrot Rarity Filter",
    Description = "Multi-select (empty = ignore brainrots)",
    Values = state.RARITIES or { "Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Celestial","Divine","Infinity" },
    Multi = true,
    Default = {},
    Callback = function(selected)
        state.BrainrotSet = {}
        for _, v in ipairs(selected) do state.BrainrotSet[tostring(v)] = true end
    end
})

-- Lucky Block filter
AutoTradeTab:Dropdown({
    Title = "Lucky Block Rarity Filter",
    Description = "Multi-select (empty = ignore lucky blocks)",
    Values = state.RARITIES or { "Common","Uncommon","Rare","Epic","Legendary","Mythical","Cosmic","Secret","Celestial","Divine","Infinity" },
    Multi = true,
    Default = {},
    Callback = function(selected)
        state.LuckySet = {}
        for _, v in ipairs(selected) do state.LuckySet[tostring(v)] = true end
    end
})

-- Auto Gift toggle (wrapped)
createToggle(AutoTradeTab, {
    Title = "Auto Gift",
    Description = "Send gifts repeatedly using first valid item",
    Default = false,
    Callback = function(v)
        state.AutoGift = v

        if v then
            if not state.TargetPlayer then
                state.WindUI:Notify({ Title = "Auto Gift", Content = "Please select a target player first", Duration = 2 })
                state.AutoGift = false
                return
            end

            if state.AutoGiftTask then return end

            state.AutoGiftTask = task.spawn(function()
                state.WindUI:Notify({ Title = "Auto Gift", Content = "Started", Duration = 1.2 })

                while state.AutoGift do
                    local items = collectItemsForTrade()
                    if #items > 0 then
                        local ok, res = performSingleGift(state.TargetPlayer, items[1])
                        state.WindUI:Notify({ Title = "Auto Gift", Content = ok and ("Gift sent: " .. items[1].uuid) or ("Gift failed: " .. tostring(res)), Duration = 1.4 })
                    else
                        state.WindUI:Notify({ Title = "Auto Gift", Content = "No matching items found", Duration = 1.6 })
                    end
                    task.wait(1.25)
                end

                state.AutoGiftTask = nil
            end)
        else
            if state.AutoGiftTask then
                task.cancel(state.AutoGiftTask)
                state.AutoGiftTask = nil
            end
            state.WindUI:Notify({ Title = "Auto Gift", Content = "Stopped", Duration = 1.2 })
        end
    end
}, "AutoGift")

-- Auto Trade toggle (wrapped)
createToggle(AutoTradeTab, {
    Title = "Auto Trade Loop",
    Description = "Automatically trade selected items repeatedly",
    Default = false,
    Callback = function(v)
        state.AutoTrade = v

        if v then
            if not state.TargetPlayer then
                state.WindUI:Notify({ Title = "Auto Trade", Content = "Please select a target player first", Duration = 2 })
                state.AutoTrade = false
                return
            end

            if state.AutoTradeTask then return end

            state.AutoTradeTask = task.spawn(function()
                state.WindUI:Notify({ Title = "Auto Trade", Content = "Started", Duration = 1.2 })

                while state.AutoTrade do
                    local ok, info = performTradeIteration(state.TargetPlayer)
                    state.WindUI:Notify({ Title = "Auto Trade", Content = ok and ("Trade completed (" .. info .. " slots)") or ("Skipped: " .. tostring(info)), Duration = 1.6 })
                    task.wait(state.LOOP_DELAY or 2.0)
                end

                state.AutoTradeTask = nil
                state.WindUI:Notify({ Title = "Auto Trade", Content = "Stopped", Duration = 1.2 })
            end)
        else
            if state.AutoTradeTask then
                task.cancel(state.AutoTradeTask)
                state.AutoTradeTask = nil
            end
            state.WindUI:Notify({ Title = "Auto Trade", Content = "Disabled", Duration = 1.2 })
        end
    end
}, "AutoTrade")

-- MISC TAB
local MiscTab = Window:Tab({ Title = "Misc", Icon = "sparkles" })
MiscTab:Section({ Title = "I dont know but i know u need this features" })

createToggle(MiscTab, { Title = "Instant Grab", Callback = function(v) if v then enableInstantGrab() else disableInstantGrab() end end }, "InstantGrabEnabled")
createToggle(MiscTab, { Title = "Infinite Zoom Out", Callback = function(v) if v then enableInfiniteZoom() else disableInfiniteZoom() end end }, "InfiniteZoomEnabled")
createToggle(MiscTab, { Title = "Infinite Jump", Callback = function(v) if v then enableInfiniteJump() else disableInfiniteJump() end end}, "InfiniteJumpEnabled")
----------------------------------------------------------------
-- CONFIG TAB (Cloud Config Manager)
----------------------------------------------------------------
local ConfigTab = Window:Tab({
    Title = "Config",
    Icon = "database"
})

ConfigTab:Section({ Title = "Cloud Configuration" })

ConfigTab:Button({
    Title = "💾 Save Cloud Config",
    Description = "Save current configuration to cloud",
    Callback = function()
        local ok = saveConfigOnline()
        if ok then
            state.WindUI:Notify({
                Title = "Cloud Save",
                Content = "Configuration saved successfully.",
                Duration = 3
            })
        else
            state.WindUI:Notify({
                Title = "Cloud Save",
                Content = "Failed to save configuration.",
                Duration = 3
            })
        end
    end
})

ConfigTab:Button({
    Title = "📥 Load Cloud Config",
    Description = "Load configuration from cloud",
    Callback = function()
        local ok = loadConfigOnline()
        if not ok then
            state.WindUI:Notify({
                Title = "Cloud Load",
                Content = "No config found or load failed.",
                Duration = 4
            })
        end
    end
})

ConfigTab:Button({
    Title = "🗑 Delete Cloud Config",
    Description = "Delete your cloud configuration permanently",
    Callback = function()
        local ok = deleteConfigOnline()
        if ok then
            state.WindUI:Notify({
                Title = "Cloud Delete",
                Content = "Cloud configuration deleted.",
                Duration = 3
            })
        else
            state.WindUI:Notify({
                Title = "Cloud Delete",
                Content = "Failed to delete config.",
                Duration = 3
            })
        end
    end
})

-- initial cloud load (kept)
task.spawn(function()
    task.wait(1.5)
    loadConfigOnline(userId)
end)

-- READY
state.WindUI:Notify({ Title = "HexaCore Hub", Content = "Loaded and ready.", Duration = 4 })
