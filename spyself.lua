-- FRENESIS Replicated Storage & Remote Monitor
-- Tempatkan di dalam LocalScript di StarterPlayerScripts atau jalankan via executor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = nil

-- Buat GUI utama
local function createGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FRENESIS_Monitor"
	screenGui.ResetOnSpawn = false

	-- Main Window
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 700, 0, 500)
	mainFrame.Position = UDim2.new(0.5, -350, 0.5, -250)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true

	-- Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 30)
	titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	titleBar.BorderSizePixel = 0

	local titleText = Instance.new("TextLabel")
	titleText.Name = "TitleText"
	titleText.Size = UDim2.new(1, -60, 1, 0)
	titleText.Position = UDim2.new(0, 10, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "FRENESIS Remote Monitor - Real-time"
	titleText.TextColor3 = Color3.fromRGB(220, 220, 255)
	titleText.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -30, 0, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)

	-- Tab Container
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(1, 0, 0, 40)
	tabContainer.Position = UDim2.new(0, 0, 0, 30)
	tabContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	tabContainer.BorderSizePixel = 0

	local tabs = {"ReplicatedStorage", "Remote Events/Functions", "Live Log"}
	local tabButtons = {}

	for i, tabName in ipairs(tabs) do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = tabName .. "Tab"
		tabButton.Size = UDim2.new(1 / #tabs, 0, 1, 0)
		tabButton.Position = UDim2.new((i - 1) / #tabs, 0, 0, 0)
		tabButton.BackgroundColor3 = (i == 1) and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(45, 45, 50)
		tabButton.BorderSizePixel = 0
		tabButton.Text = tabName
		tabButton.TextColor3 = Color3.fromRGB(200, 200, 220)
		tabButton.AutoButtonColor = true

		tabButtons[tabName] = tabButton
		tabButton.Parent = tabContainer
	end

	-- Content Area
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, 0, 1, -70)
	contentFrame.Position = UDim2.new(0, 0, 0, 70)
	contentFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	contentFrame.BorderSizePixel = 0

	-- Panel 1: ReplicatedStorage Tree View
	local rsTreeScroller = Instance.new("ScrollingFrame")
	rsTreeScroller.Name = "RSTreeScroller"
	rsTreeScroller.Size = UDim2.new(1, 0, 1, 0)
	rsTreeScroller.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	rsTreeScroller.BorderSizePixel = 0
	rsTreeScroller.ScrollBarThickness = 8
	rsTreeScroller.Visible = true

	local rsTreeList = Instance.new("UIListLayout")
	rsTreeList.Name = "RSTreeList"
	rsTreeList.Parent = rsTreeScroller

	-- Panel 2: Remote List
	local remoteScroller = Instance.new("ScrollingFrame")
	remoteScroller.Name = "RemoteScroller"
	remoteScroller.Size = UDim2.new(1, 0, 1, 0)
	remoteScroller.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	remoteScroller.BorderSizePixel = 0
	remoteScroller.ScrollBarThickness = 8
	remoteScroller.Visible = false

	local remoteListLayout = Instance.new("UIListLayout")
	remoteListLayout.Name = "RemoteListLayout"
	remoteListLayout.Parent = remoteScroller

	-- Panel 3: Live Log
	local logScroller = Instance.new("ScrollingFrame")
	logScroller.Name = "LogScroller"
	logScroller.Size = UDim2.new(1, 0, 1, 0)
	logScroller.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	logScroller.BorderSizePixel = 0
	logScroller.ScrollBarThickness = 8
	logScroller.Visible = false

	local logList = Instance.new("UIListLayout")
	logList.Name = "LogList"
	logList.Parent = logScroller

	-- Kontrol di bagian bawah
	local controlBar = Instance.new("Frame")
	controlBar.Name = "ControlBar"
	controlBar.Size = UDim2.new(1, 0, 0, 40)
	controlBar.Position = UDim2.new(0, 0, 1, -40)
	controlBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	controlBar.BorderSizePixel = 0

	local refreshButton = Instance.new("TextButton")
	refreshButton.Name = "RefreshButton"
	refreshButton.Size = UDim2.new(0, 120, 0, 30)
	refreshButton.Position = UDim2.new(0, 10, 0.5, -15)
	refreshButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
	refreshButton.BorderSizePixel = 0
	refreshButton.Text = "Refresh All"
	refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)

	local clearLogButton = Instance.new("TextButton")
	clearLogButton.Name = "ClearLogButton"
	clearLogButton.Size = UDim2.new(0, 120, 0, 30)
	clearLogButton.Position = UDim2.new(0, 140, 0.5, -15)
	clearLogButton.BackgroundColor3 = Color3.fromRGB(200, 80, 60)
	clearLogButton.BorderSizePixel = 0
	clearLogButton.Text = "Clear Log"
	clearLogButton.TextColor3 = Color3.fromRGB(255, 255, 255)

	local autoRefreshToggle = Instance.new("TextButton")
	autoRefreshToggle.Name = "AutoRefreshToggle"
	autoRefreshToggle.Size = UDim2.new(0, 150, 0, 30)
	autoRefreshToggle.Position = UDim2.new(1, -160, 0.5, -15)
	autoRefreshToggle.BackgroundColor3 = Color3.fromRGB(80, 160, 80)
	autoRefreshToggle.BorderSizePixel = 0
	autoRefreshToggle.Text = "Auto-Refresh: ON"
	autoRefreshToggle.TextColor3 = Color3.fromRGB(255, 255, 255)

	-- Parent Hierarchy
	titleText.Parent = titleBar
	closeButton.Parent = titleBar
	titleBar.Parent = mainFrame
	tabContainer.Parent = mainFrame
	contentFrame.Parent = mainFrame

	rsTreeScroller.Parent = contentFrame
	remoteScroller.Parent = contentFrame
	logScroller.Parent = contentFrame

	refreshButton.Parent = controlBar
	clearLogButton.Parent = controlBar
	autoRefreshToggle.Parent = controlBar
	controlBar.Parent = mainFrame

	mainFrame.Parent = screenGui
	screenGui.Parent = player:WaitForChild("PlayerGui")

	return screenGui, {
		MainFrame = mainFrame,
		RSTree = rsTreeScroller,
		RemoteList = remoteScroller,
		Log = logScroller,
		RefreshButton = refreshButton,
		ClearLogButton = clearLogButton,
		AutoRefreshToggle = autoRefreshToggle,
		TabButtons = tabButtons
	}
end

-- Variabel sistem
local gui, elements = createGUI()
local monitoredRemotes = {}
local logEntries = {}
local autoRefresh = true
local hookFunctions = {}

-- Fungsi utilitas
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

local function formatValue(value)
	local vType = typeof(value)
	if vType == "string" then
		return '"' .. value .. '"'
	elseif vType == "Instance" then
		return value:GetFullName()
	elseif vType == "table" then
		return "{table: " .. tostring(#value) .. " items}"
	else
		return tostring(value)
	end
end

-- Load hierarki ReplicatedStorage
local function loadRSTree(node, parentUI, depth)
	depth = depth or 0
	for _, child in ipairs(node:GetChildren()) do
		local item = Instance.new("TextButton")
		item.Size = UDim2.new(1, -10 - (depth * 20), 0, 25)
		item.Position = UDim2.new(0, 10 + (depth * 20), 0, #parentUI:GetChildren() * 25)
		item.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
		item.BorderSizePixel = 0
		item.Text = "  " .. child.Name .. " (" .. child.ClassName .. ")"
		item.TextColor3 = Color3.fromRGB(220, 220, 255)
		item.TextXAlignment = Enum.TextXAlignment.Left

		-- Warna berdasarkan kelas
		if child:IsA("RemoteEvent") then
			item.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
			item.TextColor3 = Color3.fromRGB(255, 150, 150)
		elseif child:IsA("RemoteFunction") then
			item.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
			item.TextColor3 = Color3.fromRGB(150, 255, 150)
		elseif child:IsA("Folder") then
			item.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		end

		item.MouseButton1Click:Connect(function()
			addLog("Selected: " .. child:GetFullName(), Color3.fromRGB(255, 255, 200))
		end)

		item.Parent = parentUI
		loadRSTree(child, parentUI, depth + 1)
	end
end

-- Kumpulkan dan hook RemoteEvent/RemoteFunction
local function collectRemotes()
	for _, child in ipairs(elements.RemoteList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	monitoredRemotes = {}
	hookFunctions = {}

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
			addLog("FIRE " .. remote:GetFullName() .. "(" .. argsStr .. ")", Color3.fromRGB(255, 120, 120))
			return oldFire(self, ...)
		end

		remote.FireServer = newFire
		hookFunctions[remote] = true
		table.insert(monitoredRemotes, remote)

		-- Tambah ke UI
		local remoteBtn = Instance.new("TextButton")
		remoteBtn.Size = UDim2.new(1, -10, 0, 30)
		remoteBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
		remoteBtn.BorderSizePixel = 0
		remoteBtn.Text = remote:GetFullName() .. " (RemoteEvent)"
		remoteBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
		remoteBtn.TextXAlignment = Enum.TextXAlignment.Left

		remoteBtn.MouseButton1Click:Connect(function()
			addLog("RemoteEvent Info: " .. remote:GetFullName() .. " | Hooked: YES", Color3.fromRGB(255, 200, 100))
		end)

		remoteBtn.Parent = elements.RemoteList
	end

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
			addLog("INVOKE " .. remote:GetFullName() .. "(" .. argsStr .. ")", Color3.fromRGB(120, 255, 120))
			local result = {oldInvoke(self, ...)}
			local resultStr = ""
			for i, res in ipairs(result) do
				resultStr = resultStr .. formatValue(res)
				if i < #result then resultStr = resultStr .. ", " end
			end
			addLog("RETURN " .. remote:GetFullName() .. " → " .. resultStr, Color3.fromRGB(180, 255, 180))
			return unpack(result)
		end

		remote.InvokeServer = newInvoke
		hookFunctions[remote] = true
		table.insert(monitoredRemotes, remote)

		local remoteBtn = Instance.new("TextButton")
		remoteBtn.Size = UDim2.new(1, -10, 0, 30)
		remoteBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
		remoteBtn.BorderSizePixel = 0
		remoteBtn.Text = remote:GetFullName() .. " (RemoteFunction)"
		remoteBtn.TextColor3 = Color3.fromRGB(180, 255, 180)
		remoteBtn.TextXAlignment = Enum.TextXAlignment.Left

		remoteBtn.MouseButton1Click:Connect(function()
			addLog("RemoteFunction Info: " .. remote:GetFullName() .. " | Hooked: YES", Color3.fromRGB(200, 255, 100))
		end)

		remoteBtn.Parent = elements.RemoteList
	end

	local function scanFolder(folder)
		for _, item in ipairs(folder:GetChildren()) do
			if item:IsA("RemoteEvent") then
				hookRemoteEvent(item)
			elseif item:IsA("RemoteFunction") then
				hookRemoteFunction(item)
			end
			scanFolder(item)
		end
	end

	scanFolder(ReplicatedStorage)
	elements.RemoteList.CanvasSize = UDim2.new(0, 0, 0, elements.RemoteList.UIListLayout.AbsoluteContentSize.Y)
end

-- Refresh UI
local function refreshAll()
	for _, child in ipairs(elements.RSTree:GetChildren()) do
		child:Destroy()
	end

	loadRSTree(ReplicatedStorage, elements.RSTree)
	elements.RSTree.CanvasSize = UDim2.new(0, 0, 0, elements.RSTree.UIListLayout.AbsoluteContentSize.Y)
	collectRemotes()
	addLog("System refreshed. Monitored remotes: " .. #monitoredRemotes, Color3.fromRGB(100, 200, 255))
end

-- Fungsi tab
local function showTab(tabName)
	elements.RSTree.Visible = false
	elements.RemoteList.Visible = false
	elements.Log.Visible = false

	if tabName == "ReplicatedStorage" then
		elements.RSTree.Visible = true
	elseif tabName == "Remote Events/Functions" then
		elements.RemoteList.Visible = true
	elseif tabName == "Live Log" then
		elements.Log.Visible = true
	end

	for name, btn in pairs(elements.TabButtons) do
		btn.BackgroundColor3 = (name == tabName) and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(45, 45, 50)
	end
end

-- Event handlers
elements.CloseButton.MouseButton1Click:Connect(function()
	gui:Destroy()
	addLog("Monitor closed by user.", Color3.fromRGB(255, 100, 100))
end)

elements.RefreshButton.MouseButton1Click:Connect(refreshAll)

elements.ClearLogButton.MouseButton1Click:Connect(function()
	for _, entry in ipairs(logEntries) do
		entry:Destroy()
	end
	logEntries = {}
	elements.Log.CanvasSize = UDim2.new(0, 0, 0, 0)
	addLog("Log cleared.", Color3.fromRGB(255, 200, 100))
end)

elements.AutoRefreshToggle.MouseButton1Click:Connect(function()
	autoRefresh = not autoRefresh
	elements.AutoRefreshToggle.Text = "Auto-Refresh: " .. (autoRefresh and "ON" or "OFF")
	elements.AutoRefreshToggle.BackgroundColor3 = autoRefresh and Color3.fromRGB(80, 160, 80) or Color3.fromRGB(160, 80, 80)
	addLog("Auto-Refresh " .. (autoRefresh and "enabled" or "disabled"), Color3.fromRGB(200, 200, 100))
end)

for tabName, btn in pairs(elements.TabButtons) do
	btn.MouseButton1Click:Connect(function()
		showTab(tabName)
	end)
end

-- Drag window
local dragging = false
local dragInput, dragStart, startPos

elements.TitleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = elements.MainFrame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

elements.TitleBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input == dragInput then
		local delta = input.Position - dragStart
		elements.MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Inisialisasi
refreshAll()
showTab("ReplicatedStorage")
addLog("FRENESIS Monitor aktif. Memantau ReplicatedStorage dan Remote...", Color3.fromRGB(100, 255, 100))

-- Auto-refresh loop
spawn(function()
	while gui and gui.Parent do
		if autoRefresh then
			refreshAll()
		end
		wait(5) -- Refresh setiap 5 detik
	end
end)
