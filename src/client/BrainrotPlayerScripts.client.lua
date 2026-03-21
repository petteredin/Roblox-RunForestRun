-- BrainrotPlayerScripts (LocalScript) v0.24
-- Blueberry Pie Games
-- Changelog v0.24:
--   - Sell detection: Uses CollectionService tags instead of name-matching
--     (fixes bug where model-based stored brainrots couldn't be sold)
--   - Pickup detection: Uses CollectionService tags instead of workspace:GetChildren()
--   - walletLabel: Now properly scoped as local
--   - General: Cleaner iteration, no more full-workspace scans

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
-- PROGRESS BAR
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
-- WALLET UI (top left)
-- =====================

local speedUpdateEvent   = game.ReplicatedStorage:WaitForChild("SpeedUpdate")
local rebirthResultEvent = game.ReplicatedStorage:WaitForChild("RebirthResult")
local rebirthInfoEvent   = game.ReplicatedStorage:WaitForChild("RebirthInfo")
local getRebirthInfoFunc = game.ReplicatedStorage:WaitForChild("GetRebirthInfo", 10)

local walletGui = Instance.new("ScreenGui")
walletGui.Name = "WalletGui"
walletGui.ResetOnSpawn = false
walletGui.Parent = player.PlayerGui

local walletFrame = Instance.new("Frame")
walletFrame.Size = UDim2.new(0, 200, 0, 55)
walletFrame.Position = UDim2.new(0, 16, 0, 16)
walletFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
walletFrame.BackgroundTransparency = 0.3
walletFrame.BorderSizePixel = 0
walletFrame.Parent = walletGui
Instance.new("UICorner", walletFrame).CornerRadius = UDim.new(0, 10)

local walletLabel = Instance.new("TextLabel")
walletLabel.Size = UDim2.new(1, -16, 1, 0)
walletLabel.Position = UDim2.new(0, 12, 0, 0)
walletLabel.BackgroundTransparency = 1
walletLabel.Text = "Credits: 0"
walletLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
walletLabel.TextXAlignment = Enum.TextXAlignment.Left
walletLabel.TextScaled = true
walletLabel.Font = Enum.Font.GothamBold
walletLabel.Parent = walletFrame

-- Speed-o-meter
local speedFrame = Instance.new("Frame")
speedFrame.Size = UDim2.new(0, 200, 0, 55)
speedFrame.Position = UDim2.new(0, 16, 0, 78)
speedFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
speedFrame.BackgroundTransparency = 0.3
speedFrame.BorderSizePixel = 0
speedFrame.Parent = walletGui
Instance.new("UICorner", speedFrame).CornerRadius = UDim.new(0, 10)

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -16, 1, 0)
speedLabel.Position = UDim2.new(0, 12, 0, 0)
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

-- Rebirth display
local rebirthFrame = Instance.new("Frame")
rebirthFrame.Size = UDim2.new(0, 200, 0, 55)
rebirthFrame.Position = UDim2.new(0, 16, 0, 140)
rebirthFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
rebirthFrame.BackgroundTransparency = 0.3
rebirthFrame.BorderSizePixel = 0
rebirthFrame.Parent = walletGui
Instance.new("UICorner", rebirthFrame).CornerRadius = UDim.new(0, 10)

local rebirthLabel = Instance.new("TextLabel")
rebirthLabel.Size = UDim2.new(1, -16, 1, 0)
rebirthLabel.Position = UDim2.new(0, 12, 0, 0)
rebirthLabel.BackgroundTransparency = 1
rebirthLabel.Text = "Rebirth #0"
rebirthLabel.TextColor3 = Color3.fromRGB(255, 180, 50)
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthLabel.TextScaled = true
rebirthLabel.Font = Enum.Font.GothamBold
rebirthLabel.Parent = rebirthFrame

-- Rebirth requirements box (below Rebirth #)
local rebirthReqFrame = Instance.new("Frame")
rebirthReqFrame.Size = UDim2.new(0, 200, 0, 120)
rebirthReqFrame.Position = UDim2.new(0, 16, 0, 202)
rebirthReqFrame.BackgroundColor3 = Color3.fromRGB(30, 15, 40)
rebirthReqFrame.BackgroundTransparency = 0.2
rebirthReqFrame.BorderSizePixel = 0
rebirthReqFrame.Parent = walletGui
Instance.new("UICorner", rebirthReqFrame).CornerRadius = UDim.new(0, 10)

-- Rebirth icon + title row
local rebirthReqTitle = Instance.new("TextLabel")
rebirthReqTitle.Size = UDim2.new(1, -10, 0, 22)
rebirthReqTitle.Position = UDim2.new(0, 8, 0, 4)
rebirthReqTitle.BackgroundTransparency = 1
rebirthReqTitle.Text = "\u{1F504} Next Rebirth"
rebirthReqTitle.TextColor3 = Color3.fromRGB(255, 180, 50)
rebirthReqTitle.TextXAlignment = Enum.TextXAlignment.Left
rebirthReqTitle.TextScaled = true
rebirthReqTitle.Font = Enum.Font.GothamBold
rebirthReqTitle.Parent = rebirthReqFrame

-- Brainrot requirement labels (3 lines)
local rebirthReqLabels = {}
for i = 1, 3 do
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -16, 0, 18)
	lbl.Position = UDim2.new(0, 12, 0, 24 + (i - 1) * 20)
	lbl.BackgroundTransparency = 1
	lbl.Text = ""
	lbl.TextColor3 = Color3.fromRGB(220, 220, 255)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Gotham
	lbl.Parent = rebirthReqFrame
	rebirthReqLabels[i] = lbl
end

-- Cost label
local rebirthCostLabel = Instance.new("TextLabel")
rebirthCostLabel.Size = UDim2.new(1, -10, 0, 22)
rebirthCostLabel.Position = UDim2.new(0, 8, 1, -26)
rebirthCostLabel.BackgroundTransparency = 1
rebirthCostLabel.Text = "Cost: ---"
rebirthCostLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
rebirthCostLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthCostLabel.TextScaled = true
rebirthCostLabel.Font = Enum.Font.GothamBold
rebirthCostLabel.Parent = rebirthReqFrame

-- Update rebirth requirements display
local function updateRebirthReqDisplay(brainrots, cost)
	for i = 1, 3 do
		if brainrots[i] then
			rebirthReqLabels[i].Text = "\u{25CF} " .. brainrots[i]
		else
			rebirthReqLabels[i].Text = ""
		end
	end
	if cost and cost > 0 then
		rebirthCostLabel.Text = "Cost: " .. tostring(cost) .. " credits"
	else
		rebirthCostLabel.Text = "MAX REBIRTH!"
	end
end

-- Find the rebirth station sign in workspace and update it per-player
local rebirthStationPart = nil
local rebirthSignLabel = nil

task.spawn(function()
	rebirthStationPart = workspace:WaitForChild("RebirthStation", 30)
	if rebirthStationPart then
		local billboard = rebirthStationPart:FindFirstChildWhichIsA("BillboardGui")
		if billboard then
			local bg = billboard:FindFirstChildWhichIsA("Frame")
			if bg then
				rebirthSignLabel = bg:FindFirstChild("InfoLabel")
			end
		end
	end
end)

local function updateRebirthSign(brainrots, cost)
	if not rebirthSignLabel then return end
	local lines = "Requires:\n"
	for i, name in ipairs(brainrots) do
		lines = lines .. "  " .. i .. ". " .. name .. "\n"
	end
	if cost and cost > 0 then
		lines = lines .. "\nCost: " .. tostring(cost) .. " credits"
	else
		lines = lines .. "\nMAX REBIRTH REACHED!"
	end
	rebirthSignLabel.Text = lines
end

-- Listen for rebirth info from server (push updates after rebirth)
rebirthInfoEvent.OnClientEvent:Connect(function(currentLevel, brainrots, cost)
	rebirthLabel.Text = "Rebirth #" .. currentLevel
	updateRebirthReqDisplay(brainrots, cost)
	updateRebirthSign(brainrots, cost)
end)

-- Pull initial rebirth requirements from server (client is ready now)
task.spawn(function()
	if not getRebirthInfoFunc then
		warn("[CLIENT] GetRebirthInfo RemoteFunction not found")
		return
	end
	local ok, level, brainrots, cost = pcall(function()
		return getRebirthInfoFunc:InvokeServer()
	end)
	if ok and brainrots then
		rebirthLabel.Text = "Rebirth #" .. (level or 0)
		updateRebirthReqDisplay(brainrots, cost)
		updateRebirthSign(brainrots, cost)
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

local popupLabel = Instance.new("TextLabel")
popupLabel.Size = UDim2.new(0, 220, 0, 30)
popupLabel.Position = UDim2.new(0, 16, 0, 330)
popupLabel.BackgroundTransparency = 1
popupLabel.Text = ""
popupLabel.TextXAlignment = Enum.TextXAlignment.Left
popupLabel.TextScaled = true
popupLabel.Font = Enum.Font.GothamBold
popupLabel.TextTransparency = 1
popupLabel.Parent = walletGui

local popupConnection = nil

-- FIX v0.24: showPopup is now local
local function showPopup(text, color)
	if popupConnection then
		popupConnection:Disconnect()
		popupConnection = nil
	end
	popupLabel.Text = text
	popupLabel.TextColor3 = color or Color3.fromRGB(100, 255, 100)
	popupLabel.TextTransparency = 0
	popupLabel.Position = UDim2.new(0, 16, 0, 202)
	local startTime = tick()
	local duration = 1.8
	popupConnection = RunService.RenderStepped:Connect(function()
		local t = math.min((tick() - startTime) / duration, 1)
		popupLabel.TextTransparency = t
		popupLabel.Position = UDim2.new(0, 16, 0, 330 - t * 24)
		if t >= 1 then
			popupConnection:Disconnect()
			popupConnection = nil
			popupLabel.Text = ""
		end
	end)
end

player.CharacterAdded:Connect(function()
	walletTotal = 0
	walletLabel.Text = "Credits: 0"
	rebirthLabel.Text = "Rebirth #0"
end)

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
-- CONTEXT DETECTION (v0.24: Uses CollectionService instead of workspace scan)
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

-- v0.24: Now uses CollectionService:GetTagged() instead of workspace:GetChildren()
-- This correctly finds both Part-based and Model-based spawned brainrots
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

-- v0.24: Now uses CollectionService:GetTagged() instead of workspace:GetChildren()
-- This correctly finds both Part-based AND Model-based stored brainrots
-- (fixes the bug where model brainrots couldn't be sold)
local function getClosestStoredBrainrot()
	local character = player.Character
	if not character then return nil, nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil, nil end

	local closest = nil
	local closestDist = SELL_DISTANCE
	local closestSlot = nil

	for _, obj in ipairs(CollectionService:GetTagged(TAG_STORED_BRAINROT)) do
		-- Only consider brainrots owned by this player
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

	-- Check for pickup FIRST (prevents accidental sell when trying to pick up nearby)
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
