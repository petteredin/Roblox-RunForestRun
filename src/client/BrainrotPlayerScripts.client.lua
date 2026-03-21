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

local player = Players.LocalPlayer
local remoteEvent = game.ReplicatedStorage:WaitForChild("BrainrotPickup")
local progressEvent = game.ReplicatedStorage:WaitForChild("BrainrotProgress")
local collectEvent = game.ReplicatedStorage:WaitForChild("CreditsCollected")
local upgradeResultEvent = game.ReplicatedStorage:WaitForChild("UpgradeResult")
local sellEvent = game.ReplicatedStorage:WaitForChild("SellRequested")
local sellProgressEvent = game.ReplicatedStorage:WaitForChild("SellProgress")
local sellResultEvent = game.ReplicatedStorage:WaitForChild("SellResult")
local creditUpdateEvent = game.ReplicatedStorage:WaitForChild("CreditUpdate")

-- Tags must match server-side definitions
local TAG_SPAWNED_BRAINROT = "SpawnedBrainrot"
local TAG_STORED_BRAINROT  = "StoredBrainrot"

local PICKUP_DISTANCE = 8
local SELL_DISTANCE = 5
local HOLD_TIME = 3
local isHolding = false
local isSelling = false
local targetBrainrot = nil
local targetSellSlot = nil
local holdStartTime = nil
local sellStartTime = nil
local animConnection = nil
local sellAnimConnection = nil
local walletTotal = 0

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
	holdStartTime = tick()
	if animConnection then animConnection:Disconnect() end
	animConnection = RunService.RenderStepped:Connect(function()
		if not holdStartTime then resetBar() return end
		local elapsed = tick() - holdStartTime
		setProgress(math.min(elapsed / HOLD_TIME, 1), Color3.fromRGB(80, 200, 255))
	end)
end

local function startSellAnimation(sellPrice)
	container.Visible = true
	actionLabel.Text = "Selling for " .. tostring(sellPrice)
	setProgress(0, Color3.fromRGB(255, 80, 80))
	sellStartTime = tick()
	if sellAnimConnection then sellAnimConnection:Disconnect() end
	sellAnimConnection = RunService.RenderStepped:Connect(function()
		if not sellStartTime then resetBar() return end
		local elapsed = tick() - sellStartTime
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
	local startTime = tick()
	local duration = 1.8
	popupConnection = RunService.RenderStepped:Connect(function()
		local t = math.min((tick() - startTime) / duration, 1)
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

progressEvent.OnClientEvent:Connect(function(progress)
	if progress <= 0 then
		if not isSelling then resetBar() end
	end
end)

sellProgressEvent.OnClientEvent:Connect(function(active, progress, sellPrice, slotIndex)
	if not active then
		isSelling = false
		targetSellSlot = nil
		resetBar()
	else
		actionLabel.Text = "Selling for " .. sellPrice
	end
end)

sellResultEvent.OnClientEvent:Connect(function(slotIndex, sellPrice, newWallet)
	isSelling = false
	targetSellSlot = nil
	walletTotal = newWallet
	walletLabel.Text = "Credits: " .. walletTotal
	resetBar()
	showPopup("Sold for " .. sellPrice .. " credits!", Color3.fromRGB(255, 150, 50))
end)

-- =====================
-- REMOTE EVENTS
-- =====================

local speedUpdateEvent    = game.ReplicatedStorage:WaitForChild("SpeedUpdate")
local rebirthResultEvent  = game.ReplicatedStorage:WaitForChild("RebirthResult")
local rebirthInfoEvent    = game.ReplicatedStorage:WaitForChild("RebirthInfo")
local rebirthRequestEvent = game.ReplicatedStorage:WaitForChild("RebirthRequested")
local adminCheckEvent     = game.ReplicatedStorage:WaitForChild("AdminCheck", 10)
local getRebirthInfoFunc  = game.ReplicatedStorage:WaitForChild("GetRebirthInfo", 10)
local spawnNotifyEvent    = game.ReplicatedStorage:WaitForChild("SpawnNotify", 10)

-- =====================
-- SPAWN NOTIFICATION STACK (right side)
-- =====================

local RARITY_NOTIFY_COLORS = {
	COMMON    = Color3.fromRGB(180, 180, 180),
	UNCOMMON  = Color3.fromRGB(80, 160, 255),
	EPIC      = Color3.fromRGB(180, 100, 255),
	LEGENDARY = Color3.fromRGB(255, 160, 50),
	MYTHIC    = Color3.fromRGB(255, 80, 80),
	COSMIC    = Color3.fromRGB(100, 220, 255),
}

local spawnNotifyGui = Instance.new("ScreenGui")
spawnNotifyGui.Name = "SpawnNotifyGui"
spawnNotifyGui.ResetOnSpawn = false
spawnNotifyGui.Parent = player.PlayerGui

local NOTIFY_HEIGHT   = 32
local NOTIFY_PADDING  = 4
local NOTIFY_DURATION = 4
local NOTIFY_WIDTH    = 280
local activeNotifs    = {}

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

local function addSpawnNotif(brainrotName, rarity, zoneIndex)
	local yPos = 16 + #activeNotifs * (NOTIFY_HEIGHT + NOTIFY_PADDING)
	local rarityColor = RARITY_NOTIFY_COLORS[rarity] or RARITY_NOTIFY_COLORS.COMMON

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, NOTIFY_WIDTH, 0, NOTIFY_HEIGHT)
	frame.Position = UDim2.new(1, -(NOTIFY_WIDTH + 16), 0, yPos)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = spawnNotifyGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	-- Colored left accent bar
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, -8)
	accent.Position = UDim2.new(0, 4, 0, 4)
	accent.BackgroundColor3 = rarityColor
	accent.BorderSizePixel = 0
	accent.Parent = frame
	Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 2)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 14, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = brainrotName .. " spawned in Zone " .. zoneIndex
	label.TextColor3 = rarityColor
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
	spawnNotifyEvent.OnClientEvent:Connect(function(brainrotName, rarity, zoneIndex)
		addSpawnNotif(brainrotName, rarity, zoneIndex)
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

local walletLabel = Instance.new("TextLabel")
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
speedLabel.Text = "Speed: 1.00x"
speedLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.TextScaled = true
speedLabel.Font = Enum.Font.GothamBold
speedLabel.Parent = speedFrame

speedUpdateEvent.OnClientEvent:Connect(function(multiplier)
	speedLabel.Text = string.format("Speed: %.2fx", multiplier)
end)

-- Rebirth #
local rebirthFrame = Instance.new("Frame")
rebirthFrame.Size = UDim2.new(0, 190, 0, 34)
rebirthFrame.Position = UDim2.new(0, 16, 0, 102)
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
-- NEXT REBIRTH BOX (clickable)
-- =====================

local rebirthReqFrame = Instance.new("Frame")
rebirthReqFrame.Size = UDim2.new(0, 190, 0, 135)
rebirthReqFrame.Position = UDim2.new(0, 16, 0, 142)
rebirthReqFrame.BackgroundColor3 = Color3.fromRGB(25, 15, 50)
rebirthReqFrame.BackgroundTransparency = 0.1
rebirthReqFrame.BorderSizePixel = 0
rebirthReqFrame.Parent = walletGui
Instance.new("UICorner", rebirthReqFrame).CornerRadius = UDim.new(0, 10)

-- Stroke border
local rebirthStroke = Instance.new("UIStroke")
rebirthStroke.Color = Color3.fromRGB(80, 60, 120)
rebirthStroke.Thickness = 1.5
rebirthStroke.Parent = rebirthReqFrame

-- Title row: icon + "NEXT REBIRTH #X"
local rebirthReqTitle = Instance.new("TextLabel")
rebirthReqTitle.Size = UDim2.new(0.6, 0, 0, 20)
rebirthReqTitle.Position = UDim2.new(0, 8, 0, 6)
rebirthReqTitle.BackgroundTransparency = 1
rebirthReqTitle.Text = "NEXT REBIRTH #1"
rebirthReqTitle.TextColor3 = Color3.fromRGB(255, 200, 80)
rebirthReqTitle.TextXAlignment = Enum.TextXAlignment.Left
rebirthReqTitle.TextScaled = true
rebirthReqTitle.Font = Enum.Font.GothamBold
rebirthReqTitle.Parent = rebirthReqFrame

-- "CLICK TO REBIRTH" button (top right corner)
local clickToRebirthBtn = Instance.new("TextButton")
clickToRebirthBtn.Size = UDim2.new(0, 90, 0, 18)
clickToRebirthBtn.Position = UDim2.new(1, -94, 0, 7)
clickToRebirthBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 220)
clickToRebirthBtn.BackgroundTransparency = 0
clickToRebirthBtn.BorderSizePixel = 0
clickToRebirthBtn.Text = "CLICK TO REBIRTH"
clickToRebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clickToRebirthBtn.TextScaled = true
clickToRebirthBtn.Font = Enum.Font.GothamBold
clickToRebirthBtn.Parent = rebirthReqFrame
Instance.new("UICorner", clickToRebirthBtn).CornerRadius = UDim.new(0, 6)

-- Click handler: fire rebirth request to server
clickToRebirthBtn.MouseButton1Click:Connect(function()
	rebirthRequestEvent:FireServer()
end)

-- Requirement label (single line showing rarity requirement)
local rebirthReqLabels = {}
for i = 1, 3 do
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -16, 0, 16)
	lbl.Position = UDim2.new(0, 10, 0, 28 + (i - 1) * 18)
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
rebirthZoneLabel.Size = UDim2.new(1, -16, 0, 14)
rebirthZoneLabel.Position = UDim2.new(0, 10, 0, 84)
rebirthZoneLabel.BackgroundTransparency = 1
rebirthZoneLabel.Text = ""
rebirthZoneLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
rebirthZoneLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthZoneLabel.TextScaled = true
rebirthZoneLabel.Font = Enum.Font.Gotham
rebirthZoneLabel.Parent = rebirthReqFrame

-- Cost label
local rebirthCostLabel = Instance.new("TextLabel")
rebirthCostLabel.Size = UDim2.new(1, -10, 0, 20)
rebirthCostLabel.Position = UDim2.new(0, 8, 1, -24)
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
local bottomButtons = { "Store", "V.I.P", "Index" }
local bottomIcons   = { "\u{25A6}", "\u{1F464}", "\u{2630}" }
local bottomColors  = {
	Color3.fromRGB(40, 40, 50),
	Color3.fromRGB(40, 40, 50),
	Color3.fromRGB(40, 40, 50),
}

for i, btnName in ipairs(bottomButtons) do
	local btnFrame = Instance.new("Frame")
	btnFrame.Size = UDim2.new(0, 58, 0, 68)
	btnFrame.Position = UDim2.new(0, 12 + (i - 1) * 66, 1, -80)
	btnFrame.BackgroundColor3 = bottomColors[i]
	btnFrame.BackgroundTransparency = 0.2
	btnFrame.BorderSizePixel = 0
	btnFrame.Parent = bottomGui
	Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 12)

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(1, 0, 0, 36)
	iconLbl.Position = UDim2.new(0, 0, 0, 4)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = bottomIcons[i]
	iconLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLbl.TextScaled = true
	iconLbl.Font = Enum.Font.GothamBold
	iconLbl.Parent = btnFrame

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0, 16)
	nameLbl.Position = UDim2.new(0, 0, 1, -20)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = btnName
	nameLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.Gotham
	nameLbl.Parent = btnFrame

	-- V.I.P gets a red badge
	if btnName == "V.I.P" then
		local badge = Instance.new("Frame")
		badge.Size = UDim2.new(0, 14, 0, 14)
		badge.Position = UDim2.new(1, -10, 0, -4)
		badge.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
		badge.BorderSizePixel = 0
		badge.Parent = btnFrame
		Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)

		local badgeText = Instance.new("TextLabel")
		badgeText.Size = UDim2.new(1, 0, 1, 0)
		badgeText.BackgroundTransparency = 1
		badgeText.Text = "!"
		badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
		badgeText.TextScaled = true
		badgeText.Font = Enum.Font.GothamBold
		badgeText.Parent = badge
	end
end

-- Owner button removed - admin panel handled by AdminClient.client.lua

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
		clickToRebirthBtn.Visible = false
	end
end

-- Listen for rebirth info from server
rebirthInfoEvent.OnClientEvent:Connect(function(currentLevel, brainrots, cost, rarityText)
	rebirthLabel.Text = "Rebirth #" .. currentLevel
	rebirthReqTitle.Text = "NEXT REBIRTH #" .. (currentLevel + 1)
	updateRebirthReqDisplay(brainrots, cost, rarityText)
end)

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

-- Parent popup label to walletGui
popupLabel.Parent = walletGui

-- CharacterAdded: don't reset wallet/rebirth, server sends correct values

collectEvent.OnClientEvent:Connect(function(collected, newWalletTotal)
	walletTotal = newWalletTotal
	walletLabel.Text = "Credits: " .. walletTotal
	showPopup("+" .. collected .. " credits", Color3.fromRGB(100, 255, 100))
end)

upgradeResultEvent.OnClientEvent:Connect(function(success, data, newLevel, newWalletTotal)
	if success then
		walletTotal = newWalletTotal
		walletLabel.Text = "Credits: " .. walletTotal
		showPopup("Upgraded to Lvl " .. newLevel .. "!", Color3.fromRGB(100, 220, 255))
	else
		showPopup(tostring(data), Color3.fromRGB(255, 80, 80))
	end
end)

-- =====================
-- CREDIT UPDATE (from admin panel or other sources)
-- =====================
creditUpdateEvent.OnClientEvent:Connect(function(newWallet)
	walletTotal = newWallet
	walletLabel.Text = "Credits: " .. walletTotal
end)

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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end

	targetBrainrot = getClosestBrainrot()
	if targetBrainrot then
		isHolding = true
		startPickupAnimation()
		remoteEvent:FireServer(targetBrainrot, true)
	else
		local sellSlot, sellTarget = getClosestStoredBrainrot()
		if sellSlot then
			isSelling = true
			targetSellSlot = sellSlot
			startSellAnimation("...")
			sellEvent:FireServer(sellSlot, true)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if isSelling and targetSellSlot then
		sellEvent:FireServer(targetSellSlot, false)
		isSelling = false
		targetSellSlot = nil
		resetBar()
	end
	if isHolding and targetBrainrot then
		remoteEvent:FireServer(targetBrainrot, false)
	end
	isHolding = false
	targetBrainrot = nil
	if not isSelling then resetBar() end
end)
