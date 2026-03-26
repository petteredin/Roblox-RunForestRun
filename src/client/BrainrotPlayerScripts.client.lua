-- BrainrotPlayerScripts (LocalScript) v0.30
-- Blueberry Pie Games
-- Changelog v0.30:
--   - Redesigned HUD to match new UI spec
--   - "Next Rebirth" box is now clickable (CLICK TO REBIRTH)
--   - Added bottom bar: Store, V.I.P, Index, Trade
--   - Added Owner button (bottom right) for admins only
--   - Rebirth triggered via RemoteEvent instead of ClickDetector

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local RS = game.ReplicatedStorage

-- Safe WaitForChild wrapper: warns if timeout is hit, returns nil safely
local function safeWait(parent, name, timeout)
	local child = parent:WaitForChild(name, timeout or 15)
	if not child then
		warn("[BrainrotPlayerScripts] Missing remote: " .. name)
	end
	return child
end

local remoteEvent          = safeWait(RS, "BrainrotPickup")
local progressEvent        = safeWait(RS, "BrainrotProgress")
local collectEvent         = safeWait(RS, "CreditsCollected")
local upgradeResultEvent   = safeWait(RS, "UpgradeResult")
local sellEvent            = safeWait(RS, "SellRequested")
local sellProgressEvent    = safeWait(RS, "SellProgress")
local sellResultEvent      = safeWait(RS, "SellResult")
local creditUpdateEvent    = safeWait(RS, "CreditUpdate")
local collectionUpdateEvent = safeWait(RS, "CollectionUpdate")
local getCollectionFunc    = safeWait(RS, "GetCollection")

-- Tags must match server-side definitions
local TAG_SPAWNED_BRAINROT = "SpawnedBrainrot"
local TAG_STORED_BRAINROT  = "StoredBrainrot"

-- Shared config (single source of truth for brainrots, gamepasses, colors)
local GameConfig = require(game.ReplicatedStorage:WaitForChild("GameConfig", 10))

local INDEX_BRAINROTS    = GameConfig.BRAINROTS
local INDEX_RARITY_COLORS = GameConfig.RARITY_COLORS
local INDEX_MUTATIONS    = GameConfig.MUTATIONS
local INDEX_RARITY_ORDER = GameConfig.RARITY_ORDER

-- Extracted modules (loaded later after bottomGui is created)
local IndexPanel = require(script.Parent:WaitForChild("IndexPanel", 10))
local StorePanel = require(script.Parent:WaitForChild("StorePanel", 10))

local PICKUP_DISTANCE = 8
local SELL_DISTANCE = 5
local HOLD_TIME = 3
local isHolding = false
local isSelling = false
local targetBrainrot = nil
local targetSellSlot = nil
local walletLabel = nil  -- forward declaration, created later in HUD setup
local walletTotal = 0
local holdStartTime = nil
local sellStartTime = nil
local animConnection = nil
local sellAnimConnection = nil

-- =====================
-- PROGRESS BAR (center screen)
-- =====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PickupProgressGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player.PlayerGui

local container = Instance.new("Frame")
container.Size = UDim2.new(0, 200, 0, 45)
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.new(0.5, 0, 0.6, 0)
container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
container.BackgroundTransparency = 0.3
container.BorderSizePixel = 0
container.Visible = false
container.Parent = screenGui
Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)

local actionLabel = Instance.new("TextLabel")
actionLabel.Size = UDim2.new(1, -8, 0, 20)
actionLabel.AnchorPoint = Vector2.new(0.5, 0)
actionLabel.Position = UDim2.new(0.5, 0, 0, 4)
actionLabel.BackgroundTransparency = 1
actionLabel.Text = "Hold E to collect"
actionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
actionLabel.TextScaled = true
actionLabel.Font = Enum.Font.GothamBold
actionLabel.Parent = container

local bgBar = Instance.new("Frame")
bgBar.Size = UDim2.new(1, -8, 0, 12)
bgBar.AnchorPoint = Vector2.new(0.5, 1)
bgBar.Position = UDim2.new(0.5, 0, 1, -4)
bgBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
bgBar.BorderSizePixel = 0
bgBar.Parent = container
Instance.new("UICorner", bgBar).CornerRadius = UDim.new(0, 6)

local fillBar = Instance.new("Frame")
fillBar.Size = UDim2.new(0, 0, 1, 0)
fillBar.BackgroundColor3 = Color3.fromRGB(80, 200, 255)
fillBar.BorderSizePixel = 0
fillBar.Parent = bgBar
Instance.new("UICorner", fillBar).CornerRadius = UDim.new(0, 6)

local function setProgress(progress, color)
	fillBar.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
	if color then fillBar.BackgroundColor3 = color end
end

local function resetBar()
	container.Visible = false
	setProgress(0, Color3.fromRGB(80, 200, 255))
	actionLabel.Text = "Hold E to collect"
	if animConnection then
		animConnection:Disconnect()
		animConnection = nil
	end
	if sellAnimConnection then
		sellAnimConnection:Disconnect()
		sellAnimConnection = nil
	end
	holdStartTime = nil
	sellStartTime = nil
end

local function startPickupAnimation()
	container.Visible = true
	actionLabel.Text = "Hold E to collect"
	setProgress(0, Color3.fromRGB(80, 200, 255))
	holdStartTime = os.clock()
	if animConnection then animConnection:Disconnect() end
	animConnection = RunService.RenderStepped:Connect(function()
		if not holdStartTime then resetBar() return end
		local elapsed = os.clock() - holdStartTime
		setProgress(math.min(elapsed / HOLD_TIME, 1), Color3.fromRGB(80, 200, 255))
	end)
end

local function startSellAnimation(sellPrice)
	container.Visible = true
	actionLabel.Text = "Selling for " .. tostring(sellPrice)
	setProgress(0, Color3.fromRGB(255, 80, 80))
	sellStartTime = os.clock()
	if sellAnimConnection then sellAnimConnection:Disconnect() end
	sellAnimConnection = RunService.RenderStepped:Connect(function()
		if not sellStartTime then resetBar() return end
		local elapsed = os.clock() - sellStartTime
		setProgress(math.min(elapsed / HOLD_TIME, 1), Color3.fromRGB(255, 80, 80))
	end)
end

-- =====================
-- POPUP LABEL (must be defined before event handlers)
-- =====================

local popupLabel = Instance.new("TextLabel")
popupLabel.Size = UDim2.new(0, 220, 0, 30)
popupLabel.Position = UDim2.new(0, 16, 0, 380)
popupLabel.BackgroundTransparency = 1
popupLabel.Text = ""
popupLabel.TextXAlignment = Enum.TextXAlignment.Left
popupLabel.TextScaled = true
popupLabel.Font = Enum.Font.GothamBold
popupLabel.TextTransparency = 1
-- Parent set later after walletGui

local popupConnection = nil

local function showPopup(text, color)
	if popupConnection then
		popupConnection:Disconnect()
		popupConnection = nil
	end
	popupLabel.Text = text
	popupLabel.TextColor3 = color or Color3.fromRGB(100, 255, 100)
	popupLabel.TextTransparency = 0
	popupLabel.Position = UDim2.new(0, 16, 0, 380)
	local startTime = os.clock()
	local duration = 1.8
	popupConnection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - startTime) / duration, 1)
		popupLabel.TextTransparency = t
		popupLabel.Position = UDim2.new(0, 16, 0, 380 - t * 24)
		if t >= 1 then
			popupConnection:Disconnect()
			popupConnection = nil
			popupLabel.Text = ""
		end
	end)
end

-- =====================
-- EVENT HANDLERS (use showPopup - now defined above)
-- =====================

if progressEvent then
	progressEvent.OnClientEvent:Connect(function(progress)
		if progress <= 0 then
			if not isSelling then resetBar() end
		end
	end)
end

if sellProgressEvent then
	sellProgressEvent.OnClientEvent:Connect(function(active, progress, sellPrice, slotIndex)
		if not active then
			isSelling = false
			targetSellSlot = nil
			resetBar()
		else
			actionLabel.Text = "Selling for " .. sellPrice
		end
	end)
end

if sellResultEvent then
	sellResultEvent.OnClientEvent:Connect(function(slotIndex, sellPrice, newWallet)
		isSelling = false
		targetSellSlot = nil
		walletTotal = newWallet
		if walletLabel then
			walletLabel.Text = "Credits: " .. walletTotal
		end
		resetBar()
		showPopup("Sold for " .. sellPrice .. " credits!", Color3.fromRGB(255, 150, 50))
	end)
end

-- =====================
-- REMOTE EVENTS
-- =====================

local speedUpdateEvent    = game.ReplicatedStorage:WaitForChild("SpeedUpdate", 10)
local rebirthResultEvent  = game.ReplicatedStorage:WaitForChild("RebirthResult", 10)
local rebirthInfoEvent    = game.ReplicatedStorage:WaitForChild("RebirthInfo", 10)
local rebirthRequestEvent = game.ReplicatedStorage:WaitForChild("RebirthRequested", 10)
local adminCheckEvent     = game.ReplicatedStorage:WaitForChild("AdminCheck", 10)
local getRebirthInfoFunc  = game.ReplicatedStorage:WaitForChild("GetRebirthInfo", 10)
local spawnNotifyEvent    = game.ReplicatedStorage:WaitForChild("SpawnNotify", 10)

-- =====================
-- SPAWN NOTIFICATION STACK (right side)
-- =====================

local RARITY_NOTIFY_COLORS = GameConfig.RARITY_COLORS

local spawnNotifyGui = Instance.new("ScreenGui")
spawnNotifyGui.Name = "SpawnNotifyGui"
spawnNotifyGui.ResetOnSpawn = false
spawnNotifyGui.Parent = player.PlayerGui

local NOTIFY_HEIGHT   = 22
local NOTIFY_PADDING  = 3
local NOTIFY_DURATION = 4
local NOTIFY_WIDTH    = 240
local activeNotifs    = {}

local MUTATION_COLORS = {}
for _, m in ipairs(GameConfig.MUTATIONS) do
	MUTATION_COLORS[m.key] = m.color
end

local function repositionNotifs()
	for i, notif in ipairs(activeNotifs) do
		local targetY = 16 + (i - 1) * (NOTIFY_HEIGHT + NOTIFY_PADDING)
		notif.frame.Position = UDim2.new(1, -(NOTIFY_WIDTH + 16), 0, targetY)
	end
end

local function removeNotif(notif)
	for i, n in ipairs(activeNotifs) do
		if n == notif then
			table.remove(activeNotifs, i)
			break
		end
	end
	if notif.frame and notif.frame.Parent then
		notif.frame:Destroy()
	end
	repositionNotifs()
end

local function addSpawnNotif(brainrotName, rarity, zoneIndex, mutationKey)
	mutationKey = mutationKey or "NONE"
	local yPos = 16 + #activeNotifs * (NOTIFY_HEIGHT + NOTIFY_PADDING)
	local rarityColor = RARITY_NOTIFY_COLORS[rarity] or RARITY_NOTIFY_COLORS.COMMON
	local mutColor = MUTATION_COLORS[mutationKey] or MUTATION_COLORS.NONE or Color3.fromRGB(180, 180, 180)

	-- Build display text: "Gold Bombardiro Crocodilo · Zone 2"
	local mutLabel = ""
	if mutationKey ~= "NONE" then
		for _, m in ipairs(GameConfig.MUTATIONS) do
			if m.key == mutationKey then mutLabel = m.label .. " " break end
		end
	end
	local displayText = mutLabel .. brainrotName .. " · Zone " .. zoneIndex

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, NOTIFY_WIDTH, 0, NOTIFY_HEIGHT)
	frame.Position = UDim2.new(1, -(NOTIFY_WIDTH + 16), 0, yPos)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = spawnNotifyGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

	-- Colored left accent bar (mutation color for mutated, rarity color for normal)
	local accentColor = mutationKey ~= "NONE" and mutColor or rarityColor
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 3, 1, -6)
	accent.Position = UDim2.new(0, 3, 0, 3)
	accent.BackgroundColor3 = accentColor
	accent.BorderSizePixel = 0
	accent.Parent = frame
	Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 2)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = displayText
	label.TextColor3 = mutationKey ~= "NONE" and mutColor or rarityColor
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	local notif = { frame = frame }
	table.insert(activeNotifs, notif)

	-- Fade out and remove after duration
	task.delay(NOTIFY_DURATION, function()
		if not frame or not frame.Parent then return end
		-- Quick fade out
		for t = 0, 0.3, 0.03 do
			if not frame or not frame.Parent then return end
			frame.BackgroundTransparency = 0.2 + t * 2.5
			label.TextTransparency = t * 3.3
			accent.BackgroundTransparency = t * 3.3
			task.wait(0.03)
		end
		removeNotif(notif)
	end)
end

if spawnNotifyEvent then
	spawnNotifyEvent.OnClientEvent:Connect(function(brainrotName, rarity, zoneIndex, mutationKey)
		addSpawnNotif(brainrotName, rarity, zoneIndex, mutationKey)
	end)
end

-- =====================
-- HUD - TOP LEFT PANEL
-- =====================

local walletGui = Instance.new("ScreenGui")
walletGui.Name = "WalletGui"
walletGui.ResetOnSpawn = false
walletGui.Parent = player.PlayerGui

-- Credits
local walletFrame = Instance.new("Frame")
walletFrame.Size = UDim2.new(0, 190, 0, 40)
walletFrame.Position = UDim2.new(0, 16, 0, 16)
walletFrame.BackgroundColor3 = Color3.fromRGB(40, 120, 20)
walletFrame.BackgroundTransparency = 0.15
walletFrame.BorderSizePixel = 0
walletFrame.Parent = walletGui
Instance.new("UICorner", walletFrame).CornerRadius = UDim.new(0, 8)

walletLabel = Instance.new("TextLabel")
walletLabel.Size = UDim2.new(1, -12, 1, 0)
walletLabel.Position = UDim2.new(0, 8, 0, 0)
walletLabel.BackgroundTransparency = 1
walletLabel.Text = "Credits: 0"
walletLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
walletLabel.TextXAlignment = Enum.TextXAlignment.Left
walletLabel.TextScaled = true
walletLabel.Font = Enum.Font.GothamBold
walletLabel.Parent = walletFrame

-- Speed
local speedFrame = Instance.new("Frame")
speedFrame.Size = UDim2.new(0, 190, 0, 34)
speedFrame.Position = UDim2.new(0, 16, 0, 62)
speedFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
speedFrame.BackgroundTransparency = 0.25
speedFrame.BorderSizePixel = 0
speedFrame.Parent = walletGui
Instance.new("UICorner", speedFrame).CornerRadius = UDim.new(0, 8)

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -12, 1, 0)
speedLabel.Position = UDim2.new(0, 8, 0, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed: 16"
speedLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.TextScaled = true
speedLabel.Font = Enum.Font.GothamBold
speedLabel.Parent = speedFrame

-- Speed selector buttons (4 buttons at 25%/50%/75%/100% of max speed)
local speedBtnFrame = Instance.new("Frame")
speedBtnFrame.Size = UDim2.new(0, 190, 0, 26)
speedBtnFrame.Position = UDim2.new(0, 16, 0, 98)
speedBtnFrame.BackgroundTransparency = 1
speedBtnFrame.BorderSizePixel = 0
speedBtnFrame.Parent = walletGui

local speedBtnLayout = Instance.new("UIListLayout")
speedBtnLayout.FillDirection = Enum.FillDirection.Horizontal
speedBtnLayout.Padding = UDim.new(0, 2)
speedBtnLayout.SortOrder = Enum.SortOrder.LayoutOrder
speedBtnLayout.Parent = speedBtnFrame

local currentMaxSpeed = 32 -- default rebirth 0 cap (16 * 2)
local selectedSpeedLimit = 0 -- 0 = no limit (full speed)
local speedLimitEvent = safeWait(game.ReplicatedStorage, "SpeedLimitEvent")
local speedBtns = {}

local SPEED_FRACTIONS = { 0.25, 0.50, 0.75, 1.0 }
local SPEED_BTN_COLORS = {
	Color3.fromRGB(60, 130, 60),   -- 25% green
	Color3.fromRGB(140, 140, 40),  -- 50% yellow
	Color3.fromRGB(180, 100, 40),  -- 75% orange
	Color3.fromRGB(100, 180, 220), -- 100% blue (full)
}
local SPEED_BTN_ACTIVE = Color3.fromRGB(255, 255, 255)

local function updateSpeedButtons()
	for i, btn in ipairs(speedBtns) do
		local fraction = SPEED_FRACTIONS[i]
		local targetSpeed = math.floor(currentMaxSpeed * fraction)
		btn.Text = tostring(targetSpeed)
		if selectedSpeedLimit == targetSpeed or (fraction == 1.0 and selectedSpeedLimit == 0) then
			btn.BackgroundColor3 = SPEED_BTN_COLORS[i]
			btn.BackgroundTransparency = 0.1
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
			btn.BackgroundTransparency = 0.3
			btn.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end
end

for i, fraction in ipairs(SPEED_FRACTIONS) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 46, 0, 26)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	btn.BackgroundTransparency = 0.3
	btn.BorderSizePixel = 0
	btn.Text = tostring(math.floor(currentMaxSpeed * fraction))
	btn.TextColor3 = Color3.fromRGB(150, 150, 150)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.LayoutOrder = i
	btn.Parent = speedBtnFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function()
		local targetSpeed = math.floor(currentMaxSpeed * fraction)
		if fraction == 1.0 then
			selectedSpeedLimit = 0 -- no limit
		else
			selectedSpeedLimit = targetSpeed
		end
		if speedLimitEvent then
			speedLimitEvent:FireServer(selectedSpeedLimit)
		end
		updateSpeedButtons()
	end)

	speedBtns[i] = btn
end

-- Default: full speed selected
selectedSpeedLimit = 0
updateSpeedButtons()

if speedUpdateEvent then
	speedUpdateEvent.OnClientEvent:Connect(function(displaySpeed, maxSpeed)
		speedLabel.Text = string.format("Speed: %.1f", displaySpeed)
		if maxSpeed and maxSpeed ~= currentMaxSpeed then
			currentMaxSpeed = maxSpeed
			updateSpeedButtons()
		end
	end)
end

-- Rebirth #
local rebirthFrame = Instance.new("Frame")
rebirthFrame.Size = UDim2.new(0, 190, 0, 34)
rebirthFrame.Position = UDim2.new(0, 16, 0, 130)
rebirthFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
rebirthFrame.BackgroundTransparency = 0.25
rebirthFrame.BorderSizePixel = 0
rebirthFrame.Parent = walletGui
Instance.new("UICorner", rebirthFrame).CornerRadius = UDim.new(0, 8)

local rebirthLabel = Instance.new("TextLabel")
rebirthLabel.Size = UDim2.new(1, -12, 1, 0)
rebirthLabel.Position = UDim2.new(0, 8, 0, 0)
rebirthLabel.BackgroundTransparency = 1
rebirthLabel.Text = "Rebirth #0"
rebirthLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthLabel.TextScaled = true
rebirthLabel.Font = Enum.Font.GothamBold
rebirthLabel.Parent = rebirthFrame

-- =====================
-- LUCK DISPLAY (between Rebirth and Next Rebirth)
-- =====================

local luckFrame = Instance.new("Frame")
luckFrame.Size = UDim2.new(0, 190, 0, 28)
luckFrame.Position = UDim2.new(0, 16, 0, 168)
luckFrame.BackgroundColor3 = Color3.fromRGB(40, 50, 20)
luckFrame.BackgroundTransparency = 0.25
luckFrame.BorderSizePixel = 0
luckFrame.Parent = walletGui
Instance.new("UICorner", luckFrame).CornerRadius = UDim.new(0, 8)

local luckDisplayLabel = Instance.new("TextLabel")
luckDisplayLabel.Size = UDim2.new(1, -12, 1, 0)
luckDisplayLabel.Position = UDim2.new(0, 8, 0, 0)
luckDisplayLabel.BackgroundTransparency = 1
luckDisplayLabel.Text = "\u{1F340} Luck 1x"
luckDisplayLabel.TextColor3 = Color3.fromRGB(180, 220, 80)
luckDisplayLabel.TextXAlignment = Enum.TextXAlignment.Left
luckDisplayLabel.TextScaled = true
luckDisplayLabel.Font = Enum.Font.GothamBold
luckDisplayLabel.Parent = luckFrame

-- =====================
-- NEXT REBIRTH BOX (clickable)
-- =====================

local rebirthReqFrame = Instance.new("TextButton")
rebirthReqFrame.Size = UDim2.new(0, 190, 0, 95)
rebirthReqFrame.Position = UDim2.new(0, 16, 0, 202)
rebirthReqFrame.BackgroundColor3 = Color3.fromRGB(25, 15, 50)
rebirthReqFrame.BackgroundTransparency = 0.1
rebirthReqFrame.BorderSizePixel = 0
rebirthReqFrame.Text = ""
rebirthReqFrame.AutoButtonColor = false
rebirthReqFrame.Parent = walletGui
Instance.new("UICorner", rebirthReqFrame).CornerRadius = UDim.new(0, 10)

-- Stroke border
local rebirthStroke = Instance.new("UIStroke")
rebirthStroke.Color = Color3.fromRGB(80, 60, 120)
rebirthStroke.Thickness = 1.5
rebirthStroke.Parent = rebirthReqFrame

-- Click handler: entire frame triggers rebirth
rebirthReqFrame.MouseButton1Click:Connect(function()
	rebirthRequestEvent:FireServer()
end)

-- Title row: "NEXT REBIRTH #X"
local rebirthReqTitle = Instance.new("TextLabel")
rebirthReqTitle.Size = UDim2.new(1, -12, 0, 18)
rebirthReqTitle.Position = UDim2.new(0, 8, 0, 4)
rebirthReqTitle.BackgroundTransparency = 1
rebirthReqTitle.Text = "NEXT REBIRTH #1"
rebirthReqTitle.TextColor3 = Color3.fromRGB(255, 200, 80)
rebirthReqTitle.TextXAlignment = Enum.TextXAlignment.Left
rebirthReqTitle.TextScaled = true
rebirthReqTitle.Font = Enum.Font.GothamBold
rebirthReqTitle.Parent = rebirthReqFrame

-- Requirement labels
local rebirthReqLabels = {}
for i = 1, 3 do
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -16, 0, 14)
	lbl.Position = UDim2.new(0, 10, 0, 22 + (i - 1) * 15)
	lbl.BackgroundTransparency = 1
	lbl.Text = ""
	lbl.TextColor3 = Color3.fromRGB(220, 220, 255)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Gotham
	lbl.Parent = rebirthReqFrame
	rebirthReqLabels[i] = lbl
end

-- Zone hint label
local rebirthZoneLabel = Instance.new("TextLabel")
rebirthZoneLabel.Size = UDim2.new(1, -16, 0, 12)
rebirthZoneLabel.Position = UDim2.new(0, 10, 0, 68)
rebirthZoneLabel.BackgroundTransparency = 1
rebirthZoneLabel.Text = ""
rebirthZoneLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
rebirthZoneLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthZoneLabel.TextScaled = true
rebirthZoneLabel.Font = Enum.Font.Gotham
rebirthZoneLabel.Parent = rebirthReqFrame

-- Cost label
local rebirthCostLabel = Instance.new("TextLabel")
rebirthCostLabel.Size = UDim2.new(1, -10, 0, 16)
rebirthCostLabel.Position = UDim2.new(0, 8, 1, -19)
rebirthCostLabel.BackgroundTransparency = 1
rebirthCostLabel.Text = "Cost: ---"
rebirthCostLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
rebirthCostLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthCostLabel.TextScaled = true
rebirthCostLabel.Font = Enum.Font.GothamBold
rebirthCostLabel.Parent = rebirthReqFrame

-- =====================
-- BOTTOM BAR
-- =====================

local bottomGui = Instance.new("ScreenGui")
bottomGui.Name = "BottomBarGui"
bottomGui.ResetOnSpawn = false
bottomGui.Parent = player.PlayerGui

-- Bottom left buttons
local bottomButtons  = { "Store", "Index" }
local bottomImageIds = { 105656954644211, 140599087132503 }
local bottomBtnRefs  = {}

for i, btnName in ipairs(bottomButtons) do
	local iconBtn = Instance.new("ImageButton")
	iconBtn.Name = btnName .. "Button"
	iconBtn.Size = UDim2.new(0, 68, 0, 68)
	iconBtn.Position = UDim2.new(0, 12 + (i - 1) * 76, 1, -80)
	iconBtn.BackgroundTransparency = 1
	iconBtn.BorderSizePixel = 0
	iconBtn.Image = "rbxassetid://" .. tostring(bottomImageIds[i])
	iconBtn.ScaleType = Enum.ScaleType.Fit
	iconBtn.Parent = bottomGui
	bottomBtnRefs[btnName] = iconBtn
end

-- =====================
-- INDEX PANEL (extracted to IndexPanel.lua module)
-- =====================
local indexPanelModule = IndexPanel.init(player, {
	GameConfig = GameConfig,
	getCollectionFunc = getCollectionFunc,
	collectionUpdateEvent = collectionUpdateEvent,
	bottomGui = bottomGui,
})

-- =====================
-- STORE PANEL (extracted to StorePanel.lua module)
-- =====================
local storePanelModule = StorePanel.init(player, {
	GameConfig = GameConfig,
	luckDisplayLabel = luckDisplayLabel,
	luckFrame = luckFrame,
	bottomGui = bottomGui,
	RunService = RunService,
})

-- Keep getServerLuckFunc reference for the luck poll loop
local getServerLuckFunc = game.ReplicatedStorage:WaitForChild("GetServerLuck", 10)

-- (old store UI code removed — now in StorePanel.lua module)

-- Admin button (bottom right) - hidden by default, shown for admins
local ownerFrame = Instance.new("Frame")
ownerFrame.Name = "OwnerButton"
ownerFrame.Size = UDim2.new(0, 68, 0, 68)
ownerFrame.Position = UDim2.new(1, -80, 1, -80)
ownerFrame.BackgroundTransparency = 1
ownerFrame.BorderSizePixel = 0
ownerFrame.Visible = false -- hidden until admin check
ownerFrame.Parent = bottomGui

local ownerIconImg = Instance.new("ImageLabel")
ownerIconImg.Name = "Icon"
ownerIconImg.Size = UDim2.new(1, 0, 1, 0)
ownerIconImg.BackgroundTransparency = 1
ownerIconImg.Image = "rbxassetid://140339347541759"
ownerIconImg.ScaleType = Enum.ScaleType.Fit
ownerIconImg.Parent = ownerFrame

-- ADMIN badge on owner button
local adminBadge = Instance.new("Frame")
adminBadge.Size = UDim2.new(0, 36, 0, 16)
adminBadge.Position = UDim2.new(1, -16, 0, -8)
adminBadge.AnchorPoint = Vector2.new(0.5, 0)
adminBadge.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
adminBadge.BorderSizePixel = 0
adminBadge.Parent = ownerFrame
Instance.new("UICorner", adminBadge).CornerRadius = UDim.new(0, 4)

local adminBadgeText = Instance.new("TextLabel")
adminBadgeText.Size = UDim2.new(1, 0, 1, 0)
adminBadgeText.BackgroundTransparency = 1
adminBadgeText.Text = "ADMIN"
adminBadgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
adminBadgeText.TextScaled = true
adminBadgeText.Font = Enum.Font.GothamBold
adminBadgeText.Parent = adminBadge

-- Admin check from server
if adminCheckEvent then
	adminCheckEvent.OnClientEvent:Connect(function(isAdmin)
		ownerFrame.Visible = isAdmin
	end)
end

-- =====================
-- REBIRTH DISPLAY LOGIC
-- =====================

local function updateRebirthReqDisplay(brainrots, cost, rarityText)
	if rarityText and rarityText ~= "" then
		-- Parse rarity text for multi-line display
		local lines = {}
		for line in rarityText:gmatch("[^\n]+") do
			table.insert(lines, line)
		end
		for i = 1, 3 do
			if lines[i] then
				rebirthReqLabels[i].Text = "\u{2022} " .. lines[i]
				rebirthReqLabels[i].TextColor3 = Color3.fromRGB(255, 200, 100)
			else
				rebirthReqLabels[i].Text = ""
			end
		end
	else
		for i = 1, 3 do
			if brainrots and brainrots[i] then
				rebirthReqLabels[i].Text = "\u{2022} " .. brainrots[i]
				rebirthReqLabels[i].TextColor3 = Color3.fromRGB(220, 220, 255)
			else
				rebirthReqLabels[i].Text = ""
			end
		end
	end
	if cost and cost > 0 then
		rebirthCostLabel.Text = "Cost: " .. tostring(cost) .. " credits"
	else
		rebirthCostLabel.Text = "MAX REBIRTH!"
		rebirthReqFrame.Visible = false
	end
end

-- Listen for rebirth info from server
if rebirthInfoEvent then
	rebirthInfoEvent.OnClientEvent:Connect(function(currentLevel, brainrots, cost, rarityText)
		rebirthLabel.Text = "Rebirth #" .. currentLevel
		rebirthReqTitle.Text = "NEXT REBIRTH #" .. (currentLevel + 1)
		updateRebirthReqDisplay(brainrots, cost, rarityText)
	end)
end

-- Pull initial rebirth info from server
task.spawn(function()
	if not getRebirthInfoFunc then
		warn("[CLIENT] GetRebirthInfo RemoteFunction not found")
		return
	end
	local ok, level, brainrots, cost, rarityText = pcall(function()
		return getRebirthInfoFunc:InvokeServer()
	end)
	if ok and brainrots then
		rebirthLabel.Text = "Rebirth #" .. (level or 0)
		rebirthReqTitle.Text = "NEXT REBIRTH #" .. ((level or 0) + 1)
		updateRebirthReqDisplay(brainrots, cost, rarityText)
	else
		warn("[CLIENT] Failed to get rebirth info:", level)
	end
end)

if rebirthResultEvent then
	rebirthResultEvent.OnClientEvent:Connect(function(success, dataOrLevel, newWallet)
		if success then
			rebirthLabel.Text = "Rebirth #" .. dataOrLevel
			walletTotal = newWallet
			walletLabel.Text = "Credits: " .. walletTotal
			showPopup("REBIRTH #" .. dataOrLevel .. "! 2.25x boost!", Color3.fromRGB(255, 180, 50))
		else
			showPopup(tostring(dataOrLevel), Color3.fromRGB(255, 80, 80))
		end
	end)
end

-- Parent popup label to walletGui
popupLabel.Parent = walletGui

-- CharacterAdded: don't reset wallet/rebirth, server sends correct values

if collectEvent then
	collectEvent.OnClientEvent:Connect(function(collected, newWalletTotal)
		walletTotal = newWalletTotal
		walletLabel.Text = "Credits: " .. walletTotal
		showPopup("+" .. collected .. " credits", Color3.fromRGB(100, 255, 100))
	end)
end

if upgradeResultEvent then
	upgradeResultEvent.OnClientEvent:Connect(function(success, data, newLevel, newWalletTotal)
		if success then
			walletTotal = newWalletTotal
			walletLabel.Text = "Credits: " .. walletTotal
			showPopup("Upgraded to Lvl " .. newLevel .. "!", Color3.fromRGB(100, 220, 255))
		else
			showPopup(tostring(data), Color3.fromRGB(255, 80, 80))
		end
	end)
end

-- =====================
-- CREDIT UPDATE (from admin panel or other sources)
-- =====================
if creditUpdateEvent then
	creditUpdateEvent.OnClientEvent:Connect(function(newWallet)
		walletTotal = newWallet
		walletLabel.Text = "Credits: " .. walletTotal
	end)
end

-- =====================
-- CONTEXT DETECTION
-- =====================

local function getPositionOf(obj)
	if obj:IsA("Model") then
		local primary = obj.PrimaryPart
		if primary then return primary.Position end
		local part = obj:FindFirstChildWhichIsA("BasePart")
		if part then return part.Position end
		return nil
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return nil
end

local function getClosestBrainrot()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local closest = nil
	local closestDist = PICKUP_DISTANCE

	for _, obj in ipairs(CollectionService:GetTagged(TAG_SPAWNED_BRAINROT)) do
		local pos = getPositionOf(obj)
		if pos then
			local dist = (root.Position - pos).Magnitude
			if dist <= closestDist then
				closestDist = dist
				closest = obj
			end
		end
	end

	return closest
end

local function getClosestStoredBrainrot()
	local character = player.Character
	if not character then return nil, nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil, nil end

	local closest = nil
	local closestDist = SELL_DISTANCE
	local closestSlot = nil

	for _, obj in ipairs(CollectionService:GetTagged(TAG_STORED_BRAINROT)) do
		local ownerUserId = obj:GetAttribute("OwnerUserId")
		if ownerUserId == player.UserId then
			local pos = getPositionOf(obj)
			if pos then
				local dist = (root.Position - pos).Magnitude
				if dist <= closestDist then
					local slotIdx = obj:GetAttribute("SlotIndex")
					if slotIdx then
						closestDist = dist
						closest = obj
						closestSlot = slotIdx
					end
				end
			end
		end
	end

	return closestSlot, closest
end

-- =====================
-- INPUT HANDLING
-- =====================

-- E key: pickup only
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end

	if not remoteEvent then return end
	targetBrainrot = getClosestBrainrot()
	if targetBrainrot then
		isHolding = true
		startPickupAnimation()
		remoteEvent:FireServer(nil, true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if isHolding and targetBrainrot and remoteEvent then
		remoteEvent:FireServer(nil, false)
	end
	isHolding = false
	targetBrainrot = nil
	resetBar()
end)

-- F key: sell only (own base, slotted brainrots)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F then return end

	local sellSlot, sellTarget = getClosestStoredBrainrot()
	if sellSlot then
		isSelling = true
		targetSellSlot = sellSlot
		if not sellEvent then return end
		startSellAnimation("...")
		sellEvent:FireServer(sellSlot, true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.F then return end
	if isSelling and targetSellSlot and sellEvent then
		sellEvent:FireServer(targetSellSlot, false)
		isSelling = false
		targetSellSlot = nil
		resetBar()
	end
end)

-- =====================
-- LUCK HUD UPDATE LOOP (polls server every 10 seconds)
-- =====================
task.spawn(function()
	while true do
		task.wait(10)
		if getServerLuckFunc then
			local ok, mult, remaining = pcall(function()
				return getServerLuckFunc:InvokeServer()
			end)
			if ok and mult and mult > 1 and remaining and remaining > 0 then
				local mins = math.ceil(remaining / 60)
				luckDisplayLabel.Text = "\u{1F340} Luck " .. mult .. "x (" .. mins .. "m)"
				luckFrame.BackgroundColor3 = Color3.fromRGB(60, 100, 20)
			else
				luckDisplayLabel.Text = "\u{1F340} Luck 1x"
				luckFrame.BackgroundColor3 = Color3.fromRGB(40, 50, 20)
			end
		end
	end
end)

-- =====================
-- ADMIN BROADCAST MESSAGE DISPLAY
-- =====================
local adminMessageEvent = game.ReplicatedStorage:WaitForChild("AdminMessage", 10)
if adminMessageEvent then
	-- ScreenGui for admin messages (top-center of screen)
	local msgGui = Instance.new("ScreenGui")
	msgGui.Name = "AdminMessageGui"
	msgGui.ResetOnSpawn = false
	msgGui.DisplayOrder = 100
	msgGui.Parent = player.PlayerGui

	adminMessageEvent.OnClientEvent:Connect(function(messageText, duration)
		if not messageText or messageText == "" then return end
		duration = duration or 5

		-- Remove any existing message
		local existing = msgGui:FindFirstChild("AdminBroadcast")
		if existing then existing:Destroy() end

		-- Container frame
		local container = Instance.new("Frame")
		container.Name = "AdminBroadcast"
		container.Size = UDim2.new(0, 500, 0, 50)
		container.Position = UDim2.new(0.5, 0, 0, -60)
		container.AnchorPoint = Vector2.new(0.5, 0)
		container.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		container.BackgroundTransparency = 0.15
		container.BorderSizePixel = 0
		container.Parent = msgGui
		Instance.new("UICorner", container).CornerRadius = UDim.new(0, 12)

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(255, 165, 0)
		stroke.Parent = container

		-- Message text
		local msgLabel = Instance.new("TextLabel")
		msgLabel.Size = UDim2.new(1, -20, 1, 0)
		msgLabel.Position = UDim2.new(0, 10, 0, 0)
		msgLabel.BackgroundTransparency = 1
		msgLabel.Text = messageText
		msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		msgLabel.TextScaled = true
		msgLabel.Font = Enum.Font.GothamBold
		msgLabel.TextWrapped = true
		msgLabel.Parent = container

		-- Slide in from top
		local tweenIn = TweenService:Create(container, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, 40)
		})
		tweenIn:Play()

		-- Fade out after duration
		task.delay(duration, function()
			if container and container.Parent then
				local tweenOut = TweenService:Create(container, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0, -60),
					BackgroundTransparency = 1,
				})
				TweenService:Create(msgLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
				TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				tweenOut:Play()
				tweenOut.Completed:Wait()
				if container and container.Parent then container:Destroy() end
			end
		end)
	end)
end
