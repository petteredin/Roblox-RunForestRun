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
local collectionUpdateEvent = game.ReplicatedStorage:WaitForChild("CollectionUpdate", 10)
local getCollectionFunc = game.ReplicatedStorage:WaitForChild("GetCollection", 10)

-- Tags must match server-side definitions
local TAG_SPAWNED_BRAINROT = "SpawnedBrainrot"
local TAG_STORED_BRAINROT  = "StoredBrainrot"

-- Brainrot catalog for Index panel (must match server)
local INDEX_BRAINROTS = {
	{ name="Tralalero Tralala", icon="\u{1F988}", rarity="COMMON", baseEarn=10 },
	{ name="Chimpanzini Bananini", icon="\u{1F412}", rarity="COMMON", baseEarn=9 },
	{ name="Bobrito Bandito", icon="\u{1F32F}", rarity="COMMON", baseEarn=11 },
	{ name="Frulli Frulla", icon="\u{1F353}", rarity="COMMON", baseEarn=8 },
	{ name="Frigo Camelo", icon="\u{1F42A}", rarity="COMMON", baseEarn=12 },
	{ name="Ballerina Cappuccina", icon="\u{2615}", rarity="UNCOMMON", baseEarn=14 },
	{ name="Liril\195\172 Laril\195\160", icon="\u{1F335}", rarity="UNCOMMON", baseEarn=16 },
	{ name="Burbaloni Luliloli", icon="\u{1FAE7}", rarity="UNCOMMON", baseEarn=13 },
	{ name="Orangutini Ananasini", icon="\u{1F34D}", rarity="UNCOMMON", baseEarn=15 },
	{ name="Pot Hotspot", icon="\u{1F4F6}", rarity="UNCOMMON", baseEarn=17 },
	{ name="Cappuccino Assassino", icon="\u{2615}", rarity="EPIC", baseEarn=22 },
	{ name="Bombardiro Crocodilo", icon="\u{1F40A}", rarity="EPIC", baseEarn=28 },
	{ name="Brr Brr Patapim", icon="\u{1F438}", rarity="EPIC", baseEarn=25 },
	{ name="Il Cacto Hipopotamo", icon="\u{1F99B}", rarity="EPIC", baseEarn=20 },
	{ name="Espressona Signora", icon="\u{1F475}", rarity="EPIC", baseEarn=23 },
	{ name="Trippi Troppi", icon="\u{1F990}", rarity="LEGENDARY", baseEarn=40 },
	{ name="Bombombini Gusini", icon="\u{1FABF}", rarity="LEGENDARY", baseEarn=45 },
	{ name="La Vaca Saturno Saturnita", icon="\u{1F404}", rarity="LEGENDARY", baseEarn=50 },
	{ name="Glorbo Fruttodrillo", icon="\u{1F40A}", rarity="LEGENDARY", baseEarn=42 },
	{ name="Rhino Toasterino", icon="\u{1F98F}", rarity="LEGENDARY", baseEarn=38 },
	{ name="Tung Tung Tung Sahur", icon="\u{1FAB5}", rarity="MYTHIC", baseEarn=70 },
	{ name="Boneca Ambalabu", icon="\u{1F438}", rarity="MYTHIC", baseEarn=80 },
	{ name="Garamararamararaman", icon="\u{1F47E}", rarity="MYTHIC", baseEarn=75 },
	{ name="Ta Ta Ta Ta Ta Sahur", icon="\u{1F941}", rarity="MYTHIC", baseEarn=65 },
	{ name="Tric Trac Baraboom", icon="\u{1F4A5}", rarity="MYTHIC", baseEarn=72 },
	{ name="Girafa Celeste", icon="\u{1F992}", rarity="COSMIC", baseEarn=120 },
	{ name="Trulimero Trulicina", icon="\u{1F30C}", rarity="COSMIC", baseEarn=140 },
	{ name="Blueberrinni Octopussini", icon="\u{1F419}", rarity="COSMIC", baseEarn=130 },
	{ name="Graipussi Medussi", icon="\u{1F347}", rarity="COSMIC", baseEarn=110 },
	{ name="Zibra Zubra Zibralini", icon="\u{1F993}", rarity="COSMIC", baseEarn=135 },
}

local INDEX_RARITY_COLORS = {
	COMMON    = Color3.fromRGB(180, 180, 180),
	UNCOMMON  = Color3.fromRGB(80,  160, 255),
	EPIC      = Color3.fromRGB(180, 100, 255),
	LEGENDARY = Color3.fromRGB(255, 160, 50),
	MYTHIC    = Color3.fromRGB(255, 80,  80),
	COSMIC    = Color3.fromRGB(100, 220, 255),
}

local INDEX_MUTATIONS = {
	{ key = "NONE", label = "Normal", color = Color3.fromRGB(180, 180, 180) },
	{ key = "GOLD", label = "Gold", color = Color3.fromRGB(255, 200, 0) },
	{ key = "DIAMOND", label = "Diamond", color = Color3.fromRGB(100, 220, 255) },
	{ key = "RAINBOW", label = "Rainbow", color = Color3.fromRGB(255, 100, 200) },
}

local INDEX_RARITY_ORDER = { "COMMON", "UNCOMMON", "EPIC", "LEGENDARY", "MYTHIC", "COSMIC" }

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

-- =====================
-- INDEX PANEL
-- =====================

local localCollection = {}
local indexPanelOpen = false
local indexFilter = "ALL"

-- Main ScreenGui for Index panel
local indexGui = Instance.new("ScreenGui")
indexGui.Name = "IndexPanelGui"
indexGui.ResetOnSpawn = false
indexGui.DisplayOrder = 10
indexGui.Parent = player.PlayerGui

-- Overlay (darkens background)
local indexOverlay = Instance.new("Frame")
indexOverlay.Name = "Overlay"
indexOverlay.Size = UDim2.new(1, 0, 1, 0)
indexOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
indexOverlay.BackgroundTransparency = 0.5
indexOverlay.BorderSizePixel = 0
indexOverlay.Visible = false
indexOverlay.ZIndex = 50
indexOverlay.Parent = indexGui

-- Main panel frame
local indexPanel = Instance.new("Frame")
indexPanel.Name = "IndexPanel"
indexPanel.Size = UDim2.new(0, 700, 0, 520)
indexPanel.AnchorPoint = Vector2.new(0.5, 0.5)
indexPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
indexPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
indexPanel.BorderSizePixel = 0
indexPanel.Visible = false
indexPanel.ZIndex = 51
indexPanel.Parent = indexGui
Instance.new("UICorner", indexPanel).CornerRadius = UDim.new(0, 14)

-- Header bar
local indexHeader = Instance.new("Frame")
indexHeader.Name = "Header"
indexHeader.Size = UDim2.new(1, 0, 0, 48)
indexHeader.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
indexHeader.BorderSizePixel = 0
indexHeader.ZIndex = 52
indexHeader.Parent = indexPanel
local headerCorner = Instance.new("UICorner", indexHeader)
headerCorner.CornerRadius = UDim.new(0, 14)

-- Cover bottom corners of header
local headerBottomCover = Instance.new("Frame")
headerBottomCover.Size = UDim2.new(1, 0, 0, 14)
headerBottomCover.Position = UDim2.new(0, 0, 1, -14)
headerBottomCover.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
headerBottomCover.BorderSizePixel = 0
headerBottomCover.ZIndex = 52
headerBottomCover.Parent = indexHeader

-- Header title
local indexTitle = Instance.new("TextLabel")
indexTitle.Name = "Title"
indexTitle.Size = UDim2.new(1, -100, 1, 0)
indexTitle.Position = UDim2.new(0, 16, 0, 0)
indexTitle.BackgroundTransparency = 1
indexTitle.Text = "Index - All Brainrots"
indexTitle.TextColor3 = Color3.fromRGB(255, 180, 50)
indexTitle.TextScaled = true
indexTitle.Font = Enum.Font.GothamBold
indexTitle.TextXAlignment = Enum.TextXAlignment.Left
indexTitle.ZIndex = 53
indexTitle.Parent = indexHeader

-- Count label
local indexCountLabel = Instance.new("TextLabel")
indexCountLabel.Name = "CountLabel"
indexCountLabel.Size = UDim2.new(0, 80, 0, 28)
indexCountLabel.Position = UDim2.new(1, -140, 0, 10)
indexCountLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
indexCountLabel.BorderSizePixel = 0
indexCountLabel.Text = "0/120"
indexCountLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
indexCountLabel.TextScaled = true
indexCountLabel.Font = Enum.Font.GothamBold
indexCountLabel.ZIndex = 53
indexCountLabel.Parent = indexHeader
Instance.new("UICorner", indexCountLabel).CornerRadius = UDim.new(0, 6)

-- Close button
local indexCloseBtn = Instance.new("TextButton")
indexCloseBtn.Name = "CloseBtn"
indexCloseBtn.Size = UDim2.new(0, 40, 0, 40)
indexCloseBtn.Position = UDim2.new(1, -48, 0, 4)
indexCloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
indexCloseBtn.BorderSizePixel = 0
indexCloseBtn.Text = "X"
indexCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
indexCloseBtn.TextScaled = true
indexCloseBtn.Font = Enum.Font.GothamBold
indexCloseBtn.ZIndex = 53
indexCloseBtn.Parent = indexHeader
Instance.new("UICorner", indexCloseBtn).CornerRadius = UDim.new(0, 8)

-- Left sidebar (rarity filters)
local indexSidebar = Instance.new("Frame")
indexSidebar.Name = "Sidebar"
indexSidebar.Size = UDim2.new(0, 120, 1, -58)
indexSidebar.Position = UDim2.new(0, 0, 0, 50)
indexSidebar.BackgroundColor3 = Color3.fromRGB(35, 33, 45)
indexSidebar.BorderSizePixel = 0
indexSidebar.ZIndex = 52
indexSidebar.Parent = indexPanel
local sidebarCorner = Instance.new("UICorner", indexSidebar)
sidebarCorner.CornerRadius = UDim.new(0, 10)

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Padding = UDim.new(0, 4)
sidebarLayout.Parent = indexSidebar

local sidebarPadding = Instance.new("UIPadding")
sidebarPadding.PaddingTop = UDim.new(0, 8)
sidebarPadding.PaddingLeft = UDim.new(0, 6)
sidebarPadding.PaddingRight = UDim.new(0, 6)
sidebarPadding.Parent = indexSidebar

local sidebarFilterButtons = {}
local sidebarFilters = { { key = "ALL", label = "All", color = Color3.fromRGB(255, 255, 255) } }
for _, rarity in ipairs(INDEX_RARITY_ORDER) do
	table.insert(sidebarFilters, { key = rarity, label = rarity:sub(1, 1) .. rarity:sub(2):lower(), color = INDEX_RARITY_COLORS[rarity] })
end

for idx, filter in ipairs(sidebarFilters) do
	local filterBtn = Instance.new("TextButton")
	filterBtn.Name = "Filter_" .. filter.key
	filterBtn.Size = UDim2.new(1, 0, 0, 30)
	filterBtn.BackgroundColor3 = Color3.fromRGB(50, 48, 65)
	filterBtn.BorderSizePixel = 0
	filterBtn.Text = filter.label
	filterBtn.TextColor3 = filter.color
	filterBtn.TextScaled = true
	filterBtn.Font = Enum.Font.GothamBold
	filterBtn.LayoutOrder = idx
	filterBtn.ZIndex = 53
	filterBtn.Parent = indexSidebar
	Instance.new("UICorner", filterBtn).CornerRadius = UDim.new(0, 6)
	sidebarFilterButtons[filter.key] = filterBtn
end

-- Content area (scrolling grid)
local indexContent = Instance.new("ScrollingFrame")
indexContent.Name = "Content"
indexContent.Size = UDim2.new(1, -130, 1, -108)
indexContent.Position = UDim2.new(0, 126, 0, 50)
indexContent.BackgroundTransparency = 1
indexContent.BorderSizePixel = 0
indexContent.ScrollBarThickness = 6
indexContent.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
indexContent.CanvasSize = UDim2.new(0, 0, 0, 0)
indexContent.ZIndex = 52
indexContent.Parent = indexPanel

local contentGrid = Instance.new("UIGridLayout")
contentGrid.CellSize = UDim2.new(0, 128, 0, 110)
contentGrid.CellPadding = UDim2.new(0, 8, 0, 8)
contentGrid.SortOrder = Enum.SortOrder.LayoutOrder
contentGrid.FillDirection = Enum.FillDirection.Horizontal
contentGrid.Parent = indexContent

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 6)
contentPadding.PaddingLeft = UDim.new(0, 6)
contentPadding.Parent = indexContent

-- Bottom progress bar area
local indexBottom = Instance.new("Frame")
indexBottom.Name = "BottomBar"
indexBottom.Size = UDim2.new(1, -130, 0, 46)
indexBottom.Position = UDim2.new(0, 126, 1, -52)
indexBottom.BackgroundColor3 = Color3.fromRGB(35, 33, 45)
indexBottom.BorderSizePixel = 0
indexBottom.ZIndex = 52
indexBottom.Parent = indexPanel
Instance.new("UICorner", indexBottom).CornerRadius = UDim.new(0, 8)

local progressBarBg = Instance.new("Frame")
progressBarBg.Name = "ProgressBg"
progressBarBg.Size = UDim2.new(1, -16, 0, 12)
progressBarBg.Position = UDim2.new(0, 8, 0, 6)
progressBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
progressBarBg.BorderSizePixel = 0
progressBarBg.ZIndex = 53
progressBarBg.Parent = indexBottom
Instance.new("UICorner", progressBarBg).CornerRadius = UDim.new(0, 6)

local progressBarFill = Instance.new("Frame")
progressBarFill.Name = "ProgressFill"
progressBarFill.Size = UDim2.new(0, 0, 1, 0)
progressBarFill.BackgroundColor3 = Color3.fromRGB(255, 160, 50)
progressBarFill.BorderSizePixel = 0
progressBarFill.ZIndex = 54
progressBarFill.Parent = progressBarBg
Instance.new("UICorner", progressBarFill).CornerRadius = UDim.new(0, 6)

local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "ProgressLabel"
progressLabel.Size = UDim2.new(1, -16, 0, 18)
progressLabel.Position = UDim2.new(0, 8, 0, 22)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Collect 0% Normal Brainrots for +0.5x Base Multi"
progressLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
progressLabel.TextScaled = true
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.ZIndex = 53
progressLabel.Parent = indexBottom

-- Function to build/refresh the Index grid
local function refreshIndexGrid()
	-- Clear existing cards
	for _, child in ipairs(indexContent:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local totalCollected = 0
	local totalEntries = #INDEX_BRAINROTS * #INDEX_MUTATIONS
	local normalCollected = 0
	local normalTotal = #INDEX_BRAINROTS

	local layoutOrder = 0
	for _, rarity in ipairs(INDEX_RARITY_ORDER) do
		for _, brainrot in ipairs(INDEX_BRAINROTS) do
			if brainrot.rarity ~= rarity then continue end
			for _, mut in ipairs(INDEX_MUTATIONS) do
				-- Apply filter
				if indexFilter ~= "ALL" and brainrot.rarity ~= indexFilter then
					continue
				end

				local key = brainrot.name .. ":" .. mut.key
				local collected = localCollection[key] == true
				if collected then
					totalCollected = totalCollected + 1
					if mut.key == "NONE" then
						normalCollected = normalCollected + 1
					end
				end

				layoutOrder = layoutOrder + 1
				local card = Instance.new("Frame")
				card.Name = "Card_" .. layoutOrder
				card.LayoutOrder = layoutOrder
				card.BackgroundColor3 = collected and Color3.fromRGB(45, 43, 58) or Color3.fromRGB(28, 26, 35)
				card.BorderSizePixel = 0
				card.ZIndex = 53
				card.Parent = indexContent
				Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

				-- Rarity color border (left strip)
				local rarityStrip = Instance.new("Frame")
				rarityStrip.Size = UDim2.new(0, 4, 1, -8)
				rarityStrip.Position = UDim2.new(0, 3, 0, 4)
				rarityStrip.BackgroundColor3 = collected and INDEX_RARITY_COLORS[brainrot.rarity] or Color3.fromRGB(60, 60, 70)
				rarityStrip.BorderSizePixel = 0
				rarityStrip.ZIndex = 54
				rarityStrip.Parent = card
				Instance.new("UICorner", rarityStrip).CornerRadius = UDim.new(0, 2)

				-- Icon
				local iconLabel = Instance.new("TextLabel")
				iconLabel.Size = UDim2.new(1, -14, 0, 40)
				iconLabel.Position = UDim2.new(0, 12, 0, 4)
				iconLabel.BackgroundTransparency = 1
				iconLabel.Text = collected and brainrot.icon or "?"
				iconLabel.TextColor3 = collected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 90)
				iconLabel.TextScaled = true
				iconLabel.Font = Enum.Font.GothamBold
				iconLabel.ZIndex = 54
				iconLabel.Parent = card

				-- Name
				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(1, -14, 0, 26)
				nameLabel.Position = UDim2.new(0, 12, 0, 46)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = collected and brainrot.name or "???"
				nameLabel.TextColor3 = collected and Color3.fromRGB(220, 220, 240) or Color3.fromRGB(80, 80, 90)
				nameLabel.TextScaled = true
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
				nameLabel.ZIndex = 54
				nameLabel.Parent = card

				-- Mutation badge
				if mut.key ~= "NONE" then
					local mutBadge = Instance.new("Frame")
					mutBadge.Size = UDim2.new(0, 52, 0, 16)
					mutBadge.Position = UDim2.new(0, 12, 0, 74)
					mutBadge.BackgroundColor3 = collected and mut.color or Color3.fromRGB(50, 50, 60)
					mutBadge.BackgroundTransparency = collected and 0.3 or 0.6
					mutBadge.BorderSizePixel = 0
					mutBadge.ZIndex = 54
					mutBadge.Parent = card
					Instance.new("UICorner", mutBadge).CornerRadius = UDim.new(0, 4)

					local mutLabel = Instance.new("TextLabel")
					mutLabel.Size = UDim2.new(1, 0, 1, 0)
					mutLabel.BackgroundTransparency = 1
					mutLabel.Text = mut.label
					mutLabel.TextColor3 = collected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 90)
					mutLabel.TextScaled = true
					mutLabel.Font = Enum.Font.GothamBold
					mutLabel.ZIndex = 55
					mutLabel.Parent = mutBadge
				else
					-- Normal badge (subtle)
					local normalBadge = Instance.new("TextLabel")
					normalBadge.Size = UDim2.new(0, 52, 0, 16)
					normalBadge.Position = UDim2.new(0, 12, 0, 74)
					normalBadge.BackgroundTransparency = 1
					normalBadge.Text = "Normal"
					normalBadge.TextColor3 = collected and Color3.fromRGB(140, 140, 160) or Color3.fromRGB(60, 60, 70)
					normalBadge.TextScaled = true
					normalBadge.Font = Enum.Font.Gotham
					normalBadge.TextXAlignment = Enum.TextXAlignment.Left
					normalBadge.ZIndex = 54
					normalBadge.Parent = card
				end

				-- Rarity label bottom
				local rarityLabel = Instance.new("TextLabel")
				rarityLabel.Size = UDim2.new(1, -14, 0, 14)
				rarityLabel.Position = UDim2.new(0, 12, 1, -18)
				rarityLabel.BackgroundTransparency = 1
				rarityLabel.Text = brainrot.rarity
				rarityLabel.TextColor3 = collected and INDEX_RARITY_COLORS[brainrot.rarity] or Color3.fromRGB(60, 60, 70)
				rarityLabel.TextScaled = true
				rarityLabel.Font = Enum.Font.Gotham
				rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
				rarityLabel.ZIndex = 54
				rarityLabel.Parent = card
			end
		end
	end

	-- Recalculate totals (need full scan not just visible)
	totalCollected = 0
	normalCollected = 0
	for _, brainrot in ipairs(INDEX_BRAINROTS) do
		for _, mut in ipairs(INDEX_MUTATIONS) do
			local key = brainrot.name .. ":" .. mut.key
			if localCollection[key] then
				totalCollected = totalCollected + 1
				if mut.key == "NONE" then
					normalCollected = normalCollected + 1
				end
			end
		end
	end

	-- Update count label
	indexCountLabel.Text = totalCollected .. "/" .. totalEntries

	-- Update progress bar
	local normalPct = normalTotal > 0 and (normalCollected / normalTotal) or 0
	progressBarFill.Size = UDim2.new(normalPct, 0, 1, 0)
	local bonusMult = math.floor(normalPct * 100) / 100 * 0.5
	progressLabel.Text = "Collect " .. math.floor(normalPct * 100) .. "% Normal Brainrots for +" .. string.format("%.1f", bonusMult) .. "x Base Multi"

	-- Update canvas size for scroll
	local rows = math.ceil(layoutOrder / 4)
	indexContent.CanvasSize = UDim2.new(0, 0, 0, rows * 118 + 12)
end

-- Sidebar filter button connections
for key, btn in pairs(sidebarFilterButtons) do
	btn.MouseButton1Click:Connect(function()
		indexFilter = key
		-- Update button visuals
		for k, b in pairs(sidebarFilterButtons) do
			if k == key then
				b.BackgroundColor3 = Color3.fromRGB(70, 65, 90)
			else
				b.BackgroundColor3 = Color3.fromRGB(50, 48, 65)
			end
		end
		refreshIndexGrid()
	end)
end

-- Set initial filter highlight
if sidebarFilterButtons["ALL"] then
	sidebarFilterButtons["ALL"].BackgroundColor3 = Color3.fromRGB(70, 65, 90)
end

-- Toggle function
local function toggleIndexPanel()
	indexPanelOpen = not indexPanelOpen
	indexPanel.Visible = indexPanelOpen
	indexOverlay.Visible = indexPanelOpen
	if indexPanelOpen then
		-- Refresh collection from server
		if getCollectionFunc then
			local serverCollection = getCollectionFunc:InvokeServer()
			if serverCollection and type(serverCollection) == "table" then
				localCollection = serverCollection
			end
		end
		refreshIndexGrid()
	end
end

-- Close button
indexCloseBtn.MouseButton1Click:Connect(function()
	indexPanelOpen = false
	indexPanel.Visible = false
	indexOverlay.Visible = false
end)

-- Overlay click to close
local overlayBtn = Instance.new("TextButton")
overlayBtn.Size = UDim2.new(1, 0, 1, 0)
overlayBtn.BackgroundTransparency = 1
overlayBtn.Text = ""
overlayBtn.ZIndex = 50
overlayBtn.Parent = indexOverlay
overlayBtn.MouseButton1Click:Connect(function()
	indexPanelOpen = false
	indexPanel.Visible = false
	indexOverlay.Visible = false
end)

-- Listen for CollectionUpdate from server
if collectionUpdateEvent then
	collectionUpdateEvent.OnClientEvent:Connect(function(key)
		localCollection[key] = true
		if indexPanelOpen then
			refreshIndexGrid()
		end
	end)
end

-- Connect Index button from bottom bar
for _, gui in ipairs(bottomGui:GetChildren()) do
	if gui:IsA("Frame") then
		-- Check if this frame has a label with "Index" text
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("TextLabel") and child.Text == "Index" then
				local clickBtn = Instance.new("TextButton")
				clickBtn.Size = UDim2.new(1, 0, 1, 0)
				clickBtn.BackgroundTransparency = 1
				clickBtn.Text = ""
				clickBtn.ZIndex = 10
				clickBtn.Parent = gui
				clickBtn.MouseButton1Click:Connect(function()
					toggleIndexPanel()
				end)
				break
			end
		end
	end
end

-- =====================
-- STORE PANEL
-- =====================

local MarketplaceService = game:GetService("MarketplaceService")

local GAMEPASS_IDS = {
	ADMIN_PANEL = 0,           -- Replace with real ID from Creator Dashboard
	DOUBLE_MONEY = 0,          -- Replace with real ID
	VIP = 1763788455,          -- V.I.P Pass - 150 Robux
}

local LUCK_PRODUCT_IDS = {
	{ id = 0, mult = 2,   duration = 15, price = 249 },
	{ id = 0, mult = 5,   duration = 30, price = 499 },
	{ id = 0, mult = 10,  duration = 30, price = 999 },
	{ id = 0, mult = 25,  duration = 60, price = 1999 },
	{ id = 0, mult = 50,  duration = 60, price = 3999 },
	{ id = 0, mult = 100, duration = 120, price = 7999 },
}

local storePanelOpen = false
local storeActiveTab = "Gamepasses"

-- Remotes for store
local getGamepassStatusFunc = game.ReplicatedStorage:WaitForChild("GetGamepassStatus", 10)
local redeemCodeFunc = game.ReplicatedStorage:WaitForChild("RedeemCode", 10)
local getServerLuckFunc = game.ReplicatedStorage:WaitForChild("GetServerLuck", 10)

-- Main ScreenGui for Store panel
local storeGui = Instance.new("ScreenGui")
storeGui.Name = "StorePanelGui"
storeGui.ResetOnSpawn = false
storeGui.DisplayOrder = 10
storeGui.Parent = player.PlayerGui

-- Overlay (darkens background)
local storeOverlay = Instance.new("Frame")
storeOverlay.Name = "Overlay"
storeOverlay.Size = UDim2.new(1, 0, 1, 0)
storeOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
storeOverlay.BackgroundTransparency = 0.5
storeOverlay.BorderSizePixel = 0
storeOverlay.Visible = false
storeOverlay.ZIndex = 50
storeOverlay.Parent = storeGui

-- Main panel frame
local storePanel = Instance.new("Frame")
storePanel.Name = "StorePanel"
storePanel.Size = UDim2.new(0, 750, 0, 550)
storePanel.AnchorPoint = Vector2.new(0.5, 0.5)
storePanel.Position = UDim2.new(0.5, 0, 0.5, 0)
storePanel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
storePanel.BorderSizePixel = 0
storePanel.Visible = false
storePanel.ZIndex = 51
storePanel.Parent = storeGui
Instance.new("UICorner", storePanel).CornerRadius = UDim.new(0, 14)

-- Header bar
local storeHeader = Instance.new("Frame")
storeHeader.Name = "Header"
storeHeader.Size = UDim2.new(1, 0, 0, 48)
storeHeader.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
storeHeader.BorderSizePixel = 0
storeHeader.ZIndex = 52
storeHeader.Parent = storePanel
Instance.new("UICorner", storeHeader).CornerRadius = UDim.new(0, 14)

-- Cover bottom corners of header
local storeHeaderFill = Instance.new("Frame")
storeHeaderFill.Size = UDim2.new(1, 0, 0, 14)
storeHeaderFill.Position = UDim2.new(0, 0, 1, -14)
storeHeaderFill.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
storeHeaderFill.BorderSizePixel = 0
storeHeaderFill.ZIndex = 52
storeHeaderFill.Parent = storeHeader

-- Header title
local storeTitle = Instance.new("TextLabel")
storeTitle.Name = "Title"
storeTitle.Size = UDim2.new(0, 100, 1, 0)
storeTitle.Position = UDim2.new(0, 16, 0, 0)
storeTitle.BackgroundTransparency = 1
storeTitle.Text = "SHOP"
storeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
storeTitle.TextScaled = true
storeTitle.Font = Enum.Font.GothamBold
storeTitle.TextXAlignment = Enum.TextXAlignment.Left
storeTitle.ZIndex = 53
storeTitle.Parent = storeHeader

-- Tab buttons in header
local storeTabNames = { "V.I.P", "Server Luck", "Codes" }
local storeTabColors = {
	Color3.fromRGB(180, 50, 180),
	Color3.fromRGB(40, 120, 60),
	Color3.fromRGB(80, 80, 90),
}
local storeTabButtons = {}
local storeTabFrames = {}

for i, tabName in ipairs(storeTabNames) do
	local tabBtn = Instance.new("TextButton")
	tabBtn.Name = "Tab_" .. tabName
	tabBtn.Size = UDim2.new(0, 110, 0, 32)
	tabBtn.Position = UDim2.new(0, 100 + (i - 1) * 118, 0, 8)
	tabBtn.BackgroundColor3 = storeTabColors[i]
	tabBtn.BorderSizePixel = 0
	tabBtn.Text = tabName
	tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	tabBtn.TextScaled = true
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.ZIndex = 53
	tabBtn.Parent = storeHeader
	Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 8)
	storeTabButtons[tabName] = tabBtn
end

-- Close button
local storeCloseBtn = Instance.new("TextButton")
storeCloseBtn.Name = "CloseBtn"
storeCloseBtn.Size = UDim2.new(0, 40, 0, 40)
storeCloseBtn.Position = UDim2.new(1, -48, 0, 4)
storeCloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
storeCloseBtn.BorderSizePixel = 0
storeCloseBtn.Text = "X"
storeCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
storeCloseBtn.TextScaled = true
storeCloseBtn.Font = Enum.Font.GothamBold
storeCloseBtn.ZIndex = 53
storeCloseBtn.Parent = storeHeader
Instance.new("UICorner", storeCloseBtn).CornerRadius = UDim.new(0, 8)

-- Content area
local storeContent = Instance.new("Frame")
storeContent.Name = "Content"
storeContent.Size = UDim2.new(1, -20, 1, -68)
storeContent.Position = UDim2.new(0, 10, 0, 56)
storeContent.BackgroundTransparency = 1
storeContent.BorderSizePixel = 0
storeContent.ZIndex = 52
storeContent.ClipsDescendants = true
storeContent.Parent = storePanel

-- ==================
-- TAB 1: GAMEPASSES
-- ==================
local gamepassFrame = Instance.new("ScrollingFrame")
gamepassFrame.Name = "GamepassTab"
gamepassFrame.Size = UDim2.new(1, 0, 1, 0)
gamepassFrame.BackgroundTransparency = 1
gamepassFrame.BorderSizePixel = 0
gamepassFrame.ScrollBarThickness = 6
gamepassFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
gamepassFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
gamepassFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
gamepassFrame.Visible = true
gamepassFrame.ZIndex = 52
gamepassFrame.Parent = storeContent

local gpLayout = Instance.new("UIListLayout")
gpLayout.Padding = UDim.new(0, 10)
gpLayout.SortOrder = Enum.SortOrder.LayoutOrder
gpLayout.Parent = gamepassFrame

local gpPadding = Instance.new("UIPadding")
gpPadding.PaddingTop = UDim.new(0, 6)
gpPadding.PaddingLeft = UDim.new(0, 4)
gpPadding.PaddingRight = UDim.new(0, 4)
gpPadding.Parent = gamepassFrame

storeTabFrames["V.I.P"] = gamepassFrame

-- Gamepass card builder
local cachedGamepassStatus = {}

local function createGamepassCard(info)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(info.fullWidth and 1 or 0.485, 0, 0, 120)
	card.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
	card.BorderSizePixel = 0
	card.LayoutOrder = info.order or 1
	card.ZIndex = 53
	card.Parent = gamepassFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	-- Title
	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.65, -10, 0, 28)
	titleLbl.Position = UDim2.new(0, 14, 0, 10)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = info.title
	titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 54
	titleLbl.Parent = card

	-- Description
	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(0.65, -10, 0, 50)
	descLbl.Position = UDim2.new(0, 14, 0, 38)
	descLbl.BackgroundTransparency = 1
	descLbl.Text = info.desc
	descLbl.TextColor3 = Color3.fromRGB(180, 200, 180)
	descLbl.TextScaled = true
	descLbl.Font = Enum.Font.Gotham
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.TextYAlignment = Enum.TextYAlignment.Top
	descLbl.TextWrapped = true
	descLbl.ZIndex = 54
	descLbl.Parent = card

	-- Icon text (right side)
	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(0, 80, 0, 60)
	iconLbl.Position = UDim2.new(1, -140, 0, 10)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = info.icon or ""
	iconLbl.TextColor3 = Color3.fromRGB(200, 255, 200)
	iconLbl.TextScaled = true
	iconLbl.Font = Enum.Font.GothamBold
	iconLbl.ZIndex = 54
	iconLbl.Parent = card

	-- Price badge
	local priceBadge = Instance.new("Frame")
	priceBadge.Size = UDim2.new(0, 100, 0, 30)
	priceBadge.Position = UDim2.new(1, -115, 1, -40)
	priceBadge.BackgroundColor3 = Color3.fromRGB(40, 120, 40)
	priceBadge.BorderSizePixel = 0
	priceBadge.ZIndex = 54
	priceBadge.Parent = card
	Instance.new("UICorner", priceBadge).CornerRadius = UDim.new(0, 6)

	local priceLbl = Instance.new("TextLabel")
	priceLbl.Name = "PriceLabel"
	priceLbl.Size = UDim2.new(1, 0, 1, 0)
	priceLbl.BackgroundTransparency = 1
	priceLbl.Text = info.gpId > 0 and ("R$ " .. tostring(info.price)) or "Coming Soon"
	priceLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	priceLbl.TextScaled = true
	priceLbl.Font = Enum.Font.GothamBold
	priceLbl.ZIndex = 55
	priceLbl.Parent = priceBadge

	-- Check if owned
	if cachedGamepassStatus[info.gpKey] then
		priceBadge.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
		priceLbl.Text = "OWNED \u{2713}"
	end

	-- Click to purchase
	local clickBtn = Instance.new("TextButton")
	clickBtn.Size = UDim2.new(1, 0, 1, 0)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.ZIndex = 56
	clickBtn.Parent = card
	clickBtn.MouseButton1Click:Connect(function()
		if cachedGamepassStatus[info.gpKey] then return end
		if info.gpId > 0 then
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, info.gpId)
			end)
		end
	end)

	return card, priceBadge, priceLbl
end

-- Create gamepass cards
local gpCards = {
	{
		title = "ADMIN PANEL",
		desc = "Get Admin Commands\nType ;cmds in chat for\na list of commands!",
		icon = "AP",
		price = 7499,
		gpId = GAMEPASS_IDS.ADMIN_PANEL,
		gpKey = "ADMIN_PANEL",
		fullWidth = true,
		order = 1,
	},
}

-- Half-width cards in a row
local gpRowFrame = Instance.new("Frame")
gpRowFrame.Size = UDim2.new(1, 0, 0, 120)
gpRowFrame.BackgroundTransparency = 1
gpRowFrame.LayoutOrder = 2
gpRowFrame.ZIndex = 52
gpRowFrame.Parent = gamepassFrame

local gpRowLayout = Instance.new("UIListLayout")
gpRowLayout.FillDirection = Enum.FillDirection.Horizontal
gpRowLayout.Padding = UDim.new(0, 10)
gpRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
gpRowLayout.Parent = gpRowFrame

-- Admin Panel card (full width)
createGamepassCard(gpCards[1])

-- 2x Money card (in row)
do
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0.5, -5, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
	card.BorderSizePixel = 0
	card.LayoutOrder = 1
	card.ZIndex = 53
	card.Parent = gpRowFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(0.6, 0, 0, 28); t.Position = UDim2.new(0, 14, 0, 10)
	t.BackgroundTransparency = 1; t.Text = "2X MONEY"; t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.TextScaled = true; t.Font = Enum.Font.GothamBold; t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 54; t.Parent = card

	local d = Instance.new("TextLabel")
	d.Size = UDim2.new(0.6, 0, 0, 40); d.Position = UDim2.new(0, 14, 0, 38)
	d.BackgroundTransparency = 1; d.Text = "Earn twice as much\nmoney!"; d.TextColor3 = Color3.fromRGB(180, 200, 180)
	d.TextScaled = true; d.Font = Enum.Font.Gotham; d.TextXAlignment = Enum.TextXAlignment.Left
	d.TextYAlignment = Enum.TextYAlignment.Top; d.TextWrapped = true; d.ZIndex = 54; d.Parent = card

	local ic = Instance.new("TextLabel")
	ic.Size = UDim2.new(0, 50, 0, 50); ic.Position = UDim2.new(1, -70, 0, 8)
	ic.BackgroundTransparency = 1; ic.Text = "x2"; ic.TextColor3 = Color3.fromRGB(200, 255, 200)
	ic.TextScaled = true; ic.Font = Enum.Font.GothamBold; ic.ZIndex = 54; ic.Parent = card

	local pb = Instance.new("Frame")
	pb.Size = UDim2.new(0, 90, 0, 28); pb.Position = UDim2.new(1, -100, 1, -38)
	pb.BackgroundColor3 = cachedGamepassStatus["DOUBLE_MONEY"] and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(40, 120, 40)
	pb.BorderSizePixel = 0; pb.ZIndex = 54; pb.Parent = card
	Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 6)
	local pl = Instance.new("TextLabel")
	pl.Size = UDim2.new(1, 0, 1, 0); pl.BackgroundTransparency = 1
	pl.Text = cachedGamepassStatus["DOUBLE_MONEY"] and "OWNED \u{2713}" or (GAMEPASS_IDS.DOUBLE_MONEY > 0 and "R$ 299" or "Coming Soon")
	pl.TextColor3 = Color3.fromRGB(255, 255, 255); pl.TextScaled = true
	pl.Font = Enum.Font.GothamBold; pl.ZIndex = 55; pl.Parent = pb

	local cb = Instance.new("TextButton")
	cb.Size = UDim2.new(1, 0, 1, 0); cb.BackgroundTransparency = 1; cb.Text = ""
	cb.ZIndex = 56; cb.Parent = card
	cb.MouseButton1Click:Connect(function()
		if cachedGamepassStatus["DOUBLE_MONEY"] then return end
		if GAMEPASS_IDS.DOUBLE_MONEY > 0 then
			pcall(function() MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_IDS.DOUBLE_MONEY) end)
		end
	end)
end

-- VIP card (in row)
do
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0.5, -5, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
	card.BorderSizePixel = 0
	card.LayoutOrder = 2
	card.ZIndex = 53
	card.Parent = gpRowFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(0.6, 0, 0, 28); t.Position = UDim2.new(0, 14, 0, 10)
	t.BackgroundTransparency = 1; t.Text = "VIP"; t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.TextScaled = true; t.Font = Enum.Font.GothamBold; t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 54; t.Parent = card

	local d = Instance.new("TextLabel")
	d.Size = UDim2.new(0.6, 0, 0, 40); d.Position = UDim2.new(0, 14, 0, 38)
	d.BackgroundTransparency = 1; d.Text = "Many benefits\nincluding multi!"; d.TextColor3 = Color3.fromRGB(180, 200, 180)
	d.TextScaled = true; d.Font = Enum.Font.Gotham; d.TextXAlignment = Enum.TextXAlignment.Left
	d.TextYAlignment = Enum.TextYAlignment.Top; d.TextWrapped = true; d.ZIndex = 54; d.Parent = card

	local ic = Instance.new("TextLabel")
	ic.Size = UDim2.new(0, 50, 0, 50); ic.Position = UDim2.new(1, -70, 0, 8)
	ic.BackgroundTransparency = 1; ic.Text = "\u{2B50}"; ic.TextColor3 = Color3.fromRGB(255, 200, 50)
	ic.TextScaled = true; ic.Font = Enum.Font.GothamBold; ic.ZIndex = 54; ic.Parent = card

	local pb = Instance.new("Frame")
	pb.Size = UDim2.new(0, 90, 0, 28); pb.Position = UDim2.new(1, -100, 1, -38)
	pb.BackgroundColor3 = cachedGamepassStatus["VIP"] and Color3.fromRGB(40, 160, 40) or Color3.fromRGB(40, 120, 40)
	pb.BorderSizePixel = 0; pb.ZIndex = 54; pb.Parent = card
	Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 6)
	local pl = Instance.new("TextLabel")
	pl.Size = UDim2.new(1, 0, 1, 0); pl.BackgroundTransparency = 1
	pl.Text = cachedGamepassStatus["VIP"] and "OWNED \u{2713}" or (GAMEPASS_IDS.VIP > 0 and "R$ 150" or "Coming Soon")
	pl.TextColor3 = Color3.fromRGB(255, 255, 255); pl.TextScaled = true
	pl.Font = Enum.Font.GothamBold; pl.ZIndex = 55; pl.Parent = pb

	local cb = Instance.new("TextButton")
	cb.Size = UDim2.new(1, 0, 1, 0); cb.BackgroundTransparency = 1; cb.Text = ""
	cb.ZIndex = 56; cb.Parent = card
	cb.MouseButton1Click:Connect(function()
		if cachedGamepassStatus["VIP"] then return end
		if GAMEPASS_IDS.VIP > 0 then
			pcall(function() MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_IDS.VIP) end)
		end
	end)
end

-- ==================
-- TAB 2: SERVER LUCK
-- ==================
local luckFrame = Instance.new("ScrollingFrame")
luckFrame.Name = "LuckTab"
luckFrame.Size = UDim2.new(1, 0, 1, 0)
luckFrame.BackgroundTransparency = 1
luckFrame.BorderSizePixel = 0
luckFrame.ScrollBarThickness = 6
luckFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
luckFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
luckFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
luckFrame.Visible = false
luckFrame.ZIndex = 52
luckFrame.Parent = storeContent

storeTabFrames["Server Luck"] = luckFrame

-- Active luck status
local luckStatusLabel = Instance.new("TextLabel")
luckStatusLabel.Name = "LuckStatus"
luckStatusLabel.Size = UDim2.new(1, -12, 0, 36)
luckStatusLabel.Position = UDim2.new(0, 6, 0, 0)
luckStatusLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
luckStatusLabel.BorderSizePixel = 0
luckStatusLabel.Text = "No active luck boost"
luckStatusLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
luckStatusLabel.TextScaled = true
luckStatusLabel.Font = Enum.Font.GothamBold
luckStatusLabel.ZIndex = 53
luckStatusLabel.LayoutOrder = 0
luckStatusLabel.Parent = luckFrame
Instance.new("UICorner", luckStatusLabel).CornerRadius = UDim.new(0, 8)

local luckPadding = Instance.new("UIPadding")
luckPadding.PaddingTop = UDim.new(0, 6)
luckPadding.PaddingLeft = UDim.new(0, 4)
luckPadding.PaddingRight = UDim.new(0, 4)
luckPadding.Parent = luckFrame

local luckGridFrame = Instance.new("Frame")
luckGridFrame.Size = UDim2.new(1, 0, 0, 0)
luckGridFrame.AutomaticSize = Enum.AutomaticSize.Y
luckGridFrame.BackgroundTransparency = 1
luckGridFrame.LayoutOrder = 1
luckGridFrame.ZIndex = 52
luckGridFrame.Parent = luckFrame

local luckGrid = Instance.new("UIGridLayout")
luckGrid.CellSize = UDim2.new(0.32, 0, 0, 130)
luckGrid.CellPadding = UDim2.new(0.01, 0, 0, 10)
luckGrid.SortOrder = Enum.SortOrder.LayoutOrder
luckGrid.FillDirection = Enum.FillDirection.Horizontal
luckGrid.Parent = luckGridFrame

local luckLayout = Instance.new("UIListLayout")
luckLayout.Padding = UDim.new(0, 8)
luckLayout.SortOrder = Enum.SortOrder.LayoutOrder
luckLayout.Parent = luckFrame

for idx, luckInfo in ipairs(LUCK_PRODUCT_IDS) do
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 0, 0, 0) -- controlled by grid
	card.BackgroundColor3 = Color3.fromRGB(30, 70, 40)
	card.BorderSizePixel = 0
	card.LayoutOrder = idx
	card.ZIndex = 53
	card.Parent = luckGridFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	-- Clover icon
	local clover = Instance.new("TextLabel")
	clover.Size = UDim2.new(1, 0, 0, 36)
	clover.Position = UDim2.new(0, 0, 0, 6)
	clover.BackgroundTransparency = 1
	clover.Text = "\u{1F340}"
	clover.TextScaled = true
	clover.Font = Enum.Font.GothamBold
	clover.ZIndex = 54
	clover.Parent = card

	-- Multiplier label
	local multLbl = Instance.new("TextLabel")
	multLbl.Size = UDim2.new(1, 0, 0, 22)
	multLbl.Position = UDim2.new(0, 0, 0, 42)
	multLbl.BackgroundTransparency = 1
	multLbl.Text = "Server Luck 1x > " .. luckInfo.mult .. "x"
	multLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	multLbl.TextScaled = true
	multLbl.Font = Enum.Font.GothamBold
	multLbl.ZIndex = 54
	multLbl.Parent = card

	-- Duration label
	local durLbl = Instance.new("TextLabel")
	durLbl.Size = UDim2.new(1, 0, 0, 18)
	durLbl.Position = UDim2.new(0, 0, 0, 64)
	durLbl.BackgroundTransparency = 1
	durLbl.Text = "+" .. luckInfo.duration .. " minutes"
	durLbl.TextColor3 = Color3.fromRGB(180, 220, 180)
	durLbl.TextScaled = true
	durLbl.Font = Enum.Font.Gotham
	durLbl.ZIndex = 54
	durLbl.Parent = card

	-- Price badge
	local pBadge = Instance.new("Frame")
	pBadge.Size = UDim2.new(0.7, 0, 0, 26)
	pBadge.Position = UDim2.new(0.15, 0, 1, -34)
	pBadge.BackgroundColor3 = Color3.fromRGB(40, 120, 40)
	pBadge.BorderSizePixel = 0
	pBadge.ZIndex = 54
	pBadge.Parent = card
	Instance.new("UICorner", pBadge).CornerRadius = UDim.new(0, 6)

	local pLbl = Instance.new("TextLabel")
	pLbl.Size = UDim2.new(1, 0, 1, 0)
	pLbl.BackgroundTransparency = 1
	pLbl.Text = luckInfo.id > 0 and ("R$ " .. luckInfo.price) or "Coming Soon"
	pLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	pLbl.TextScaled = true
	pLbl.Font = Enum.Font.GothamBold
	pLbl.ZIndex = 55
	pLbl.Parent = pBadge

	-- Click to buy
	local clickBtn = Instance.new("TextButton")
	clickBtn.Size = UDim2.new(1, 0, 1, 0)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.ZIndex = 56
	clickBtn.Parent = card
	clickBtn.MouseButton1Click:Connect(function()
		if luckInfo.id > 0 then
			pcall(function()
				MarketplaceService:PromptProductPurchase(player, luckInfo.id)
			end)
		end
	end)
end

-- ==================
-- TAB 3: CODES
-- ==================
local codesFrame = Instance.new("Frame")
codesFrame.Name = "CodesTab"
codesFrame.Size = UDim2.new(1, 0, 1, 0)
codesFrame.BackgroundTransparency = 1
codesFrame.BorderSizePixel = 0
codesFrame.Visible = false
codesFrame.ZIndex = 52
codesFrame.Parent = storeContent

storeTabFrames["Codes"] = codesFrame

-- "REDEEM CODES" header
local codesTitle = Instance.new("TextLabel")
codesTitle.Size = UDim2.new(1, 0, 0, 40)
codesTitle.Position = UDim2.new(0, 0, 0, 30)
codesTitle.BackgroundTransparency = 1
codesTitle.Text = "REDEEM CODES"
codesTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
codesTitle.TextScaled = true
codesTitle.Font = Enum.Font.GothamBold
codesTitle.ZIndex = 53
codesTitle.Parent = codesFrame

-- Code input
local codeInputBox = Instance.new("TextBox")
codeInputBox.Size = UDim2.new(0.7, 0, 0, 50)
codeInputBox.Position = UDim2.new(0.15, 0, 0, 90)
codeInputBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
codeInputBox.BorderSizePixel = 0
codeInputBox.Text = ""
codeInputBox.PlaceholderText = "Code Here..."
codeInputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
codeInputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
codeInputBox.TextScaled = true
codeInputBox.Font = Enum.Font.GothamBold
codeInputBox.ClearTextOnFocus = false
codeInputBox.ZIndex = 53
codeInputBox.Parent = codesFrame
Instance.new("UICorner", codeInputBox).CornerRadius = UDim.new(0, 10)
local codeInputPad = Instance.new("UIPadding")
codeInputPad.PaddingLeft = UDim.new(0, 16)
codeInputPad.PaddingRight = UDim.new(0, 16)
codeInputPad.Parent = codeInputBox

-- Redeem button
local redeemBtn = Instance.new("TextButton")
redeemBtn.Size = UDim2.new(0.3, 0, 0, 44)
redeemBtn.Position = UDim2.new(0.35, 0, 0, 160)
redeemBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 40)
redeemBtn.BorderSizePixel = 0
redeemBtn.Text = "Redeem"
redeemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
redeemBtn.TextScaled = true
redeemBtn.Font = Enum.Font.GothamBold
redeemBtn.ZIndex = 53
redeemBtn.Parent = codesFrame
Instance.new("UICorner", redeemBtn).CornerRadius = UDim.new(0, 10)

-- Feedback label
local codeFeedbackLabel = Instance.new("TextLabel")
codeFeedbackLabel.Size = UDim2.new(0.7, 0, 0, 30)
codeFeedbackLabel.Position = UDim2.new(0.15, 0, 0, 220)
codeFeedbackLabel.BackgroundTransparency = 1
codeFeedbackLabel.Text = ""
codeFeedbackLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
codeFeedbackLabel.TextScaled = true
codeFeedbackLabel.Font = Enum.Font.GothamBold
codeFeedbackLabel.ZIndex = 53
codeFeedbackLabel.Parent = codesFrame

-- Redeem code logic
redeemBtn.MouseButton1Click:Connect(function()
	local code = codeInputBox.Text
	if code == "" then
		codeFeedbackLabel.Text = "Please enter a code!"
		codeFeedbackLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		return
	end
	codeFeedbackLabel.Text = "Redeeming..."
	codeFeedbackLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	if redeemCodeFunc then
		local ok, result = pcall(function()
			return redeemCodeFunc:InvokeServer(code)
		end)
		if ok and result then
			if result.success then
				codeFeedbackLabel.Text = result.message or "Code redeemed!"
				codeFeedbackLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
				codeInputBox.Text = ""
			else
				codeFeedbackLabel.Text = result.message or "Invalid code"
				codeFeedbackLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			end
		else
			codeFeedbackLabel.Text = "Failed to redeem code"
			codeFeedbackLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		end
	else
		codeFeedbackLabel.Text = "Code system not available"
		codeFeedbackLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	end
end)

-- ==================
-- STORE TAB SWITCHING
-- ==================
local function switchStoreTab(tabName)
	storeActiveTab = tabName
	for name, frame in pairs(storeTabFrames) do
		frame.Visible = (name == tabName)
	end
	for name, btn in pairs(storeTabButtons) do
		if name == tabName then
			btn.BackgroundTransparency = 0
		else
			btn.BackgroundTransparency = 0.5
		end
	end
end

for name, btn in pairs(storeTabButtons) do
	btn.MouseButton1Click:Connect(function()
		switchStoreTab(name)
	end)
end

-- Set initial tab
switchStoreTab("V.I.P")

-- ==================
-- STORE TOGGLE
-- ==================
local function toggleStorePanel()
	storePanelOpen = not storePanelOpen
	storePanel.Visible = storePanelOpen
	storeOverlay.Visible = storePanelOpen
	if storePanelOpen then
		-- Fetch gamepass status from server
		if getGamepassStatusFunc then
			local ok, status = pcall(function()
				return getGamepassStatusFunc:InvokeServer()
			end)
			if ok and status and type(status) == "table" then
				cachedGamepassStatus = status
			end
		end
		-- Fetch server luck status
		if getServerLuckFunc then
			local ok, mult, remaining = pcall(function()
				return getServerLuckFunc:InvokeServer()
			end)
			if ok and mult and mult > 1 and remaining and remaining > 0 then
				local mins = math.ceil(remaining / 60)
				luckStatusLabel.Text = "\u{1F340} Active: " .. mult .. "x Server Luck (" .. mins .. " min remaining)"
				luckStatusLabel.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
			else
				luckStatusLabel.Text = "No active luck boost"
				luckStatusLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
			end
		end
	end
end

-- Close button
storeCloseBtn.MouseButton1Click:Connect(function()
	storePanelOpen = false
	storePanel.Visible = false
	storeOverlay.Visible = false
end)

-- Overlay click to close
local storeOverlayBtn = Instance.new("TextButton")
storeOverlayBtn.Size = UDim2.new(1, 0, 1, 0)
storeOverlayBtn.BackgroundTransparency = 1
storeOverlayBtn.Text = ""
storeOverlayBtn.ZIndex = 50
storeOverlayBtn.Parent = storeOverlay
storeOverlayBtn.MouseButton1Click:Connect(function()
	storePanelOpen = false
	storePanel.Visible = false
	storeOverlay.Visible = false
end)

-- Connect Store and V.I.P buttons from bottom bar
for _, gui in ipairs(bottomGui:GetChildren()) do
	if gui:IsA("Frame") then
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("TextLabel") and (child.Text == "Store" or child.Text == "V.I.P") then
				local tabTarget = "V.I.P"
				local clickBtn = Instance.new("TextButton")
				clickBtn.Size = UDim2.new(1, 0, 1, 0)
				clickBtn.BackgroundTransparency = 1
				clickBtn.Text = ""
				clickBtn.ZIndex = 10
				clickBtn.Parent = gui
				clickBtn.MouseButton1Click:Connect(function()
					if not storePanelOpen then
						toggleStorePanel()
					end
					switchStoreTab(tabTarget)
				end)
				break
			end
		end
	end
end

-- Owner button (bottom right) - hidden by default, shown for admins
local ownerFrame = Instance.new("Frame")
ownerFrame.Name = "OwnerButton"
ownerFrame.Size = UDim2.new(0, 64, 0, 68)
ownerFrame.Position = UDim2.new(1, -76, 1, -80)
ownerFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ownerFrame.BackgroundTransparency = 0.2
ownerFrame.BorderSizePixel = 0
ownerFrame.Visible = false -- hidden until admin check
ownerFrame.Parent = bottomGui
Instance.new("UICorner", ownerFrame).CornerRadius = UDim.new(0, 12)

local ownerIcon = Instance.new("TextLabel")
ownerIcon.Size = UDim2.new(1, 0, 0, 36)
ownerIcon.Position = UDim2.new(0, 0, 0, 4)
ownerIcon.BackgroundTransparency = 1
ownerIcon.Text = "\u{2699}"
ownerIcon.TextColor3 = Color3.fromRGB(180, 180, 255)
ownerIcon.TextScaled = true
ownerIcon.Font = Enum.Font.GothamBold
ownerIcon.Parent = ownerFrame

local ownerNameLbl = Instance.new("TextLabel")
ownerNameLbl.Size = UDim2.new(1, 0, 0, 16)
ownerNameLbl.Position = UDim2.new(0, 0, 1, -20)
ownerNameLbl.BackgroundTransparency = 1
ownerNameLbl.Text = "Owner"
ownerNameLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
ownerNameLbl.TextScaled = true
ownerNameLbl.Font = Enum.Font.Gotham
ownerNameLbl.Parent = ownerFrame

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
