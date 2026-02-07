-- FRENESIS Replicated Storage & Remote Monitor - FIXED
-- Tempatkan di LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = nil

-- Variabel sistem
local monitoredRemotes = {}
local logEntries = {}
local autoRefresh = true
local hookFunctions = {}
local elements = {}

-- Fungsi log
local function addLog(message, color)
    color = color or Color3.fromRGB(220, 220, 255)
    local logEntry = Instance.new("TextLabel")
    logEntry.Size = UDim2.new(1, -10, 0, 0)
    logEntry.AutomaticSize = Enum.AutomaticSize.Y
    logEntry.BackgroundTransparency = 1
    logEntry.Text = "[" .. os.date("%H:%M:%S") .. "] " .. message
    logEntry.TextColor3 = color
    logEntry.TextXAlignment = Enum.TextXAlignment.Left
    logEntry.TextYAlignment = Enum.TextYAlignment.Top
    logEntry.TextWrapped = true
    logEntry.Parent = elements.Log

    table.insert(logEntries, logEntry)
    elements.Log.CanvasSize = UDim2.new(0, 0, 0, elements.Log.UIListLayout.AbsoluteContentSize.Y)
    elements.Log.CanvasPosition = Vector2.new(0, elements.Log.UIListLayout.AbsoluteContentSize.Y)
end

-- Format nilai
local function formatValue(value)
    local vType = typeof(value)
    if vType == "string" then
        return '"' .. value .. '"'
    elseif vType == "Instance" then
        return value.Name .. " (" .. value.ClassName .. ")"
    elseif vType == "table" then
        return "Table [" .. tostring(#value) .. "]"
    elseif vType == "number" then
        return string.format("%.3f", value)
    else
        return tostring(value)
    end
end

-- Buat UI Tree
local function createTreeItem(name, className, depth, parent)
    local item = Instance.new("TextButton")
    item.Name = name
    item.Size = UDim2.new(1, -10 - (depth * 20), 0, 25)
    item.Position = UDim2.new(0, 10 + (depth * 20), 0, #parent:GetChildren() * 25)
    item.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    item.BorderSizePixel = 0
    item.Text = "  " .. name .. " (" .. className .. ")"
    item.TextColor3 = Color3.fromRGB(220, 220, 255)
    item.TextXAlignment = Enum.TextXAlignment.Left

    if className == "RemoteEvent" then
        item.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
        item.TextColor3 = Color3.fromRGB(255, 180, 180)
    elseif className == "RemoteFunction" then
        item.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        item.TextColor3 = Color3.fromRGB(180, 255, 180)
    elseif className == "Folder" then
        item.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    end

    item.MouseButton1Click:Connect(function()
        addLog("Selected: " .. name .. " [" .. className .. "]", Color3.fromRGB(255, 255, 200))
    end)

    return item
end

-- Muat hierarki ReplicatedStorage
local function loadRSTree()
    for _, child in ipairs(elements.RSTree:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local function scanFolder(folder, depth, parentUI)
        for _, child in ipairs(folder:GetChildren()) do
            local item = createTreeItem(child.Name, child.ClassName, depth, parentUI)
            item.Parent = parentUI
            if child:IsA("Folder") then
                scanFolder(child, depth + 1, parentUI)
            end
        end
    end

    scanFolder(ReplicatedStorage, 0, elements.RSTree)
    elements.RSTree.CanvasSize = UDim2.new(0, 0, 0, #elements.RSTree:GetChildren() * 25)
end

-- Hook RemoteEvent
local function hookRemoteEvent(remote)
    if hookFunctions[remote] then return end

    local oldFire = remote.FireServer
    local newFire = function(self, ...)
        local args = {...}
        local argsStr = ""
        for i, arg in ipairs(args) do
            argsStr = argsStr .. formatValue(arg)
            if i < #args then argsStr = argsStr .. ", " end
        end
        addLog("🔥 FIRE " .. remote.Name .. "(" .. argsStr .. ")", Color3.fromRGB(255, 120, 120))
        return oldFire(self, ...)
    end
    remote.FireServer = newFire
    hookFunctions[remote] = true

    -- Tambah ke UI Remote List
    local remoteBtn = Instance.new("TextButton")
    remoteBtn.Size = UDim2.new(1, -10, 0, 30)
    remoteBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    remoteBtn.BorderSizePixel = 0
    remoteBtn.Text = remote.Name .. " (RemoteEvent)"
    remoteBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
    remoteBtn.TextXAlignment = Enum.TextXAlignment.Left
    remoteBtn.Parent = elements.RemoteList
end

-- Hook RemoteFunction
local function hookRemoteFunction(remote)
    if hookFunctions[remote] then return end

    local oldInvoke = remote.InvokeServer
    local newInvoke = function(self, ...)
        local args = {...}
        local argsStr = ""
        for i, arg in ipairs(args) do
            argsStr = argsStr .. formatValue(arg)
            if i < #args then argsStr = argsStr .. ", " end
        end
        addLog("⚡ INVOKE " .. remote.Name .. "(" .. argsStr .. ")", Color3.fromRGB(120, 255, 120))
        local results = {oldInvoke(self, ...)}
        local resultStr = ""
        for i, res in ipairs(results) do
            resultStr = resultStr .. formatValue(res)
            if i < #results then resultStr = resultStr .. ", " end
        end
        addLog("📤 RETURN " .. remote.Name .. " → " .. resultStr, Color3.fromRGB(180, 255, 180))
        return unpack(results)
    end
    remote.InvokeServer = newInvoke
    hookFunctions[remote] = true

    local remoteBtn = Instance.new("TextButton")
    remoteBtn.Size = UDim2.new(1, -10, 0, 30)
    remoteBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
    remoteBtn.BorderSizePixel = 0
    remoteBtn.Text = remote.Name .. " (RemoteFunction)"
    remoteBtn.TextColor3 = Color3.fromRGB(180, 255, 180)
    remoteBtn.TextXAlignment = Enum.TextXAlignment.Left
    remoteBtn.Parent = elements.RemoteList
end

-- Kumpulkan semua remote
local function collectRemotes()
    for _, child in ipairs(elements.RemoteList:GetChildren()) do
        child:Destroy()
    end

    local function scanForRemotes(folder)
        for _, item in ipairs(folder:GetChildren()) do
            if item:IsA("RemoteEvent") then
                hookRemoteEvent(item)
            elseif item:IsA("RemoteFunction") then
                hookRemoteFunction(item)
            end
            scanForRemotes(item)
        end
    end

    scanForRemotes(ReplicatedStorage)
    elements.RemoteList.CanvasSize = UDim2.new(0, 0, 0, #elements.RemoteList:GetChildren() * 32)
end

-- Refresh semua data
local function refreshAll()
    loadRSTree()
    collectRemotes()
    addLog("🔄 System refreshed. Monitored remotes: " .. #elements.RemoteList:GetChildren(), Color3.fromRGB(100, 200, 255))
end

-- Buat GUI
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FRENESIS_Monitor"
    screenGui.ResetOnSpawn = false

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 700, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -350, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    mainFrame.BorderSizePixel = 0

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    titleBar.Parent = mainFrame

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -60, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "FRENESIS Remote Monitor - Real-time"
    titleText.TextColor3 = Color3.fromRGB(220, 220, 255)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar

    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -30, 0, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.new(1,1,1)
    closeButton.Parent = titleBar

    -- Tabs
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, 0, 0, 40)
    tabContainer.Position = UDim2.new(0, 0, 0, 30)
    tabContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    tabContainer.Parent = mainFrame

    local tabs = {"ReplicatedStorage", "Remote Events/Functions", "Live Log"}
    local tabButtons = {}

    for i, tabName in ipairs(tabs) do
        local tabButton = Instance.new("TextButton")
        tabButton.Name = tabName
        tabButton.Size = UDim2.new(1 / #tabs, 0, 1, 0)
        tabButton.Position = UDim2.new((i - 1) / #tabs, 0, 0, 0)
        tabButton.BackgroundColor3 = i == 1 and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(45, 45, 50)
        tabButton.Text = tabName
        tabButton.TextColor3 = Color3.fromRGB(200, 200, 220)
        tabButton.Parent = tabContainer
        tabButtons[tabName] = tabButton
    end

    -- Content Area
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, -70)
    contentFrame.Position = UDim2.new(0, 0, 0, 70)
    contentFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    contentFrame.Parent = mainFrame

    -- Panel 1: ReplicatedStorage
    local rsTreeScroller = Instance.new("ScrollingFrame")
    rsTreeScroller.Size = UDim2.new(1, 0, 1, 0)
    rsTreeScroller.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    rsTreeScroller.ScrollBarThickness = 8
    rsTreeScroller.Visible = true
    rsTreeScroller.Parent = contentFrame
    elements.RSTree = rsTreeScroller

    -- Panel 2: Remote List
    local remoteScroller = Instance.new("ScrollingFrame")
    remoteScroller.Size = UDim2.new(1, 0, 1, 0)
    remoteScroller.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    remoteScroller.ScrollBarThickness = 8
    remoteScroller.Visible = false
    remoteScroller.Parent = contentFrame
    elements.RemoteList = remoteScroller

    -- Panel 3: Live Log
    local logScroller = Instance.new("ScrollingFrame")
    logScroller.Size = UDim2.new(1, 0, 1, 0)
    logScroller.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    logScroller.ScrollBarThickness = 8
    logScroller.Visible = false
    logScroller.Parent = contentFrame
    elements.Log = logScroller

    local logLayout = Instance.new("UIListLayout")
    logLayout.Parent = logScroller

    -- Control Bar
    local controlBar = Instance.new("Frame")
    controlBar.Size = UDim2.new(1, 0, 0, 40)
    controlBar.Position = UDim2.new(0, 0, 1, -40)
    controlBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    controlBar.Parent = mainFrame

    local refreshButton = Instance.new("TextButton")
    refreshButton.Size = UDim2.new(0, 120, 0, 30)
    refreshButton.Position = UDim2.new(0, 10, 0.5, -15)
    refreshButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    refreshButton.Text = "Refresh All"
    refreshButton.TextColor3 = Color3.new(1,1,1)
    refreshButton.Parent = controlBar
    elements.RefreshButton = refreshButton

    local clearLogButton = Instance.new("TextButton")
    clearLogButton.Size = UDim2.new(0, 120, 0, 30)
    clearLogButton.Position = UDim2.new(0, 140, 0.5, -15)
    clearLogButton.BackgroundColor3 = Color3.fromRGB(200, 80, 60)
    clearLogButton.Text = "Clear Log"
    clearLogButton.TextColor3 = Color3.new(1,1,1)
    clearLogButton.Parent = controlBar

    local autoRefreshToggle = Instance.new("TextButton")
    autoRefreshToggle.Size = UDim2.new(0, 150, 0, 30)
    autoRefreshToggle.Position = UDim2.new(1, -160, 0.5, -15)
    autoRefreshToggle.BackgroundColor3 = Color3.fromRGB(80, 160, 80)
    autoRefreshToggle.Text = "Auto-Refresh: ON"
    autoRefreshToggle.TextColor3 = Color3.new(1,1,1)
    autoRefreshToggle.Parent = controlBar
    elements.AutoRefreshToggle = autoRefreshToggle

    screenGui.Parent = player:WaitForChild("PlayerGui")
    gui = screenGui

    -- Setup event handlers
    closeButton.MouseButton1Click:Connect(function()
        gui:Destroy()
        addLog("❌ Monitor closed", Color3.fromRGB(255, 100, 100))
    end)

    refreshButton.MouseButton1Click:Connect(refreshAll)

    clearLogButton.MouseButton1Click:Connect(function()
        for _, entry in ipairs(logEntries) do
            entry:Destroy()
        end
        logEntries = {}
        addLog("📝 Log cleared", Color3.fromRGB(255, 200, 100))
    end)

    autoRefreshToggle.MouseButton1Click:Connect(function()
        autoRefresh = not autoRefresh
        autoRefreshToggle.Text = "Auto-Refresh: " .. (autoRefresh and "ON" or "OFF")
        autoRefreshToggle.BackgroundColor3 = autoRefresh and Color3.fromRGB(80, 160, 80) or Color3.fromRGB(160, 80, 80)
        addLog("🔄 Auto-Refresh " .. (autoRefresh and "enabled" or "disabled"), Color3.fromRGB(200, 200, 100))
    end)

    -- Tab switching
    local function showTab(tabName)
        rsTreeScroller.Visible = false
        remoteScroller.Visible = false
        logScroller.Visible = false

        if tabName == "ReplicatedStorage" then
            rsTreeScroller.Visible = true
        elseif tabName == "Remote Events/Functions" then
            remoteScroller.Visible = true
        elseif tabName == "Live Log" then
            logScroller.Visible = true
        end

        for name, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = name == tabName and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(45, 45, 50)
        end
    end

    for tabName, btn in pairs(tabButtons) do
        btn.MouseButton1Click:Connect(function()
            showTab(tabName)
        end)
    end

    return screenGui
end

-- Inisialisasi
createGUI()
refreshAll()
addLog("✅ FRENESIS Monitor aktif", Color3.fromRGB(100, 255, 100))

-- Auto-refresh
while wait(5) do
    if autoRefresh and gui and gui.Parent then
        refreshAll()
    end
end
