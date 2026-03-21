-- =============================================
-- AdminClient.lua (LocalScript)
-- Hanterar admin-panelens GUI och skickar
-- kommandon till servern via RemoteEvent.
-- Placeras i StarterPlayerScripts.
-- =============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- =====================
-- ADMIN-KONTROLL (klient-sida, enbart för GUI-visning)
-- Servern tar alla säkerhetsbeslut.
-- =====================
local ADMIN_IDS = {
	[8327644091] = true, -- Simpleson716
}

if not ADMIN_IDS[player.UserId] then
	return -- Avsluta scriptet för icke-admins, ingen GUI skapas
end

-- =====================
-- REMOTE EVENTS
-- =====================
local adminRemote = ReplicatedStorage:WaitForChild("AdminRemote", 10)
local adminResponse = ReplicatedStorage:WaitForChild("AdminResponse", 10)

if not adminRemote or not adminResponse then
	warn("[AdminClient] Kunde inte hitta AdminRemote/AdminResponse")
	return
end

-- =====================
-- FÄRGTEMA
-- =====================
local COLORS = {
	bg        = Color3.fromRGB(30, 30, 40),
	header    = Color3.fromRGB(255, 165, 0),
	btnGreen  = Color3.fromRGB(80, 200, 80),
	btnRed    = Color3.fromRGB(200, 80, 80),
	btnBlue   = Color3.fromRGB(80, 130, 220),
	text      = Color3.fromRGB(255, 255, 255),
	input     = Color3.fromRGB(50, 50, 60),
	section   = Color3.fromRGB(40, 40, 55),
	border    = Color3.fromRGB(70, 70, 85),
	success   = Color3.fromRGB(80, 220, 80),
	error     = Color3.fromRGB(220, 80, 80),
	dimText   = Color3.fromRGB(180, 180, 180),
}

-- =====================
-- SKAPA GUI
-- =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminPanelGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- =====================
-- ADMIN-KNAPP (öppna panelen)
-- =====================
local adminBtn = Instance.new("TextButton")
adminBtn.Name = "AdminToggle"
adminBtn.Size = UDim2.new(0, 50, 0, 50)
adminBtn.Position = UDim2.new(1, -60, 1, -60)
adminBtn.AnchorPoint = Vector2.new(0, 0)
adminBtn.BackgroundColor3 = COLORS.header
adminBtn.Text = "ADM"
adminBtn.TextColor3 = COLORS.text
adminBtn.TextSize = 14
adminBtn.Font = Enum.Font.GothamBold
adminBtn.Parent = screenGui

local adminBtnCorner = Instance.new("UICorner")
adminBtnCorner.CornerRadius = UDim.new(0, 8)
adminBtnCorner.Parent = adminBtn

local adminBadge = Instance.new("TextLabel")
adminBadge.Size = UDim2.new(0, 40, 0, 16)
adminBadge.Position = UDim2.new(0.5, 0, 0, -10)
adminBadge.AnchorPoint = Vector2.new(0.5, 0)
adminBadge.BackgroundColor3 = COLORS.btnRed
adminBadge.Text = "ADMIN"
adminBadge.TextColor3 = COLORS.text
adminBadge.TextSize = 9
adminBadge.Font = Enum.Font.GothamBold
adminBadge.Parent = adminBtn
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 4)
badgeCorner.Parent = adminBadge

-- =====================
-- ADMIN-PANEL (huvudfönster)
-- =====================
local PANEL_WIDTH = 340
local PANEL_HEIGHT = 620

local panelFrame = Instance.new("Frame")
panelFrame.Name = "AdminPanel"
panelFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panelFrame.Position = UDim2.new(1, PANEL_WIDTH + 20, 0.5, 0) -- Startar utanför skärmen
panelFrame.AnchorPoint = Vector2.new(0, 0.5)
panelFrame.BackgroundColor3 = COLORS.bg
panelFrame.BorderSizePixel = 0
panelFrame.Visible = true
panelFrame.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panelFrame

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.border
panelStroke.Thickness = 1
panelStroke.Parent = panelFrame

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = COLORS.header
header.BorderSizePixel = 0
header.Parent = panelFrame
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header
-- Täck nedre hörnen
local headerFill = Instance.new("Frame")
headerFill.Size = UDim2.new(1, 0, 0, 14)
headerFill.Position = UDim2.new(0, 0, 1, -14)
headerFill.BackgroundColor3 = COLORS.header
headerFill.BorderSizePixel = 0
headerFill.Parent = header

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, -40, 1, 0)
headerTitle.Position = UDim2.new(0, 12, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "Admin Panel"
headerTitle.TextColor3 = Color3.fromRGB(40, 40, 40)
headerTitle.TextSize = 20
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = header

-- Stäng-knapp
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.text
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = header
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

-- Scrollbar för innehåll
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -16, 1, -52)
scrollFrame.Position = UDim2.new(0, 8, 0, 48)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = COLORS.border
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Uppdateras dynamiskt
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = panelFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- =====================
-- STATUS-RUTAN (feedback)
-- =====================
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 28)
statusLabel.BackgroundColor3 = COLORS.section
statusLabel.Text = ""
statusLabel.TextColor3 = COLORS.dimText
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextWrapped = true
statusLabel.LayoutOrder = 0
statusLabel.Parent = scrollFrame
local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 6)
statusCorner.Parent = statusLabel

local function showStatus(msg, isSuccess)
	statusLabel.Text = "  " .. msg
	statusLabel.TextColor3 = isSuccess and COLORS.success or COLORS.error
	task.delay(5, function()
		if statusLabel.Text == "  " .. msg then
			statusLabel.Text = ""
			statusLabel.TextColor3 = COLORS.dimText
		end
	end)
end

-- =====================
-- GUI-BYGGARE
-- =====================

local layoutOrder = 0
local function nextOrder()
	layoutOrder = layoutOrder + 1
	return layoutOrder
end

--- Skapa en sektion med titel
local function createSection(title)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = COLORS.section
	frame.BorderSizePixel = 0
	frame.LayoutOrder = nextOrder()
	frame.Parent = scrollFrame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 18)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = COLORS.header
	titleLabel.TextSize = 14
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.LayoutOrder = 0
	titleLabel.Parent = frame

	return frame
end

--- Skapa en TextBox (input-fält)
local function createInput(parent, placeholder, order)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 30)
	box.BackgroundColor3 = COLORS.input
	box.Text = ""
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
	box.TextColor3 = COLORS.text
	box.TextSize = 13
	box.Font = Enum.Font.Gotham
	box.ClearTextOnFocus = false
	box.LayoutOrder = order or 1
	box.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = box
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 8)
	p.PaddingRight = UDim.new(0, 8)
	p.Parent = box
	return box
end

--- Skapa en knapp
local function createButton(parent, text, color, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.48, 0, 0, 30)
	btn.BackgroundColor3 = color or COLORS.btnGreen
	btn.Text = text
	btn.TextColor3 = COLORS.text
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamBold
	btn.LayoutOrder = order or 2
	btn.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn
	return btn
end

--- Skapa en rad med knappar
local function createButtonRow(parent, buttons, order)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order or 3
	row.Parent = parent

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row

	local result = {}
	for i, info in ipairs(buttons) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1 / #buttons, -4, 1, 0)
		btn.BackgroundColor3 = info.color or COLORS.btnGreen
		btn.Text = info.text
		btn.TextColor3 = COLORS.text
		btn.TextSize = 13
		btn.Font = Enum.Font.GothamBold
		btn.LayoutOrder = i
		btn.Parent = row
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = btn
		result[info.text] = btn
	end
	return result
end

--- Visuell knapp-feedback
local function flashButton(btn, success)
	local original = btn.BackgroundColor3
	btn.BackgroundColor3 = success and COLORS.success or COLORS.error
	task.delay(0.3, function()
		btn.BackgroundColor3 = original
	end)
end

-- =====================
-- SEKTION: Target Player (global input)
-- =====================
local targetSection = createSection("Target Player")
local targetInput = createInput(targetSection, "Player name (blank = yourself)", 1)

-- =====================
-- SEKTION 1: Credits
-- =====================
local creditsSection = createSection("Credits")
local creditsInput = createInput(creditsSection, "Enter amount", 1)
local creditsBtns = createButtonRow(creditsSection, {
	{ text = "Add", color = COLORS.btnGreen },
	{ text = "Set", color = COLORS.btnBlue },
}, 2)

creditsBtns["Add"].MouseButton1Click:Connect(function()
	local amount = tonumber(creditsInput.Text)
	if not amount then showStatus("Ange ett giltigt nummer", false) return end
	adminRemote:FireServer("AddCredits", targetInput.Text, amount)
	flashButton(creditsBtns["Add"], true)
end)

creditsBtns["Set"].MouseButton1Click:Connect(function()
	local amount = tonumber(creditsInput.Text)
	if not amount then showStatus("Ange ett giltigt nummer", false) return end
	adminRemote:FireServer("SetCredits", targetInput.Text, amount)
	flashButton(creditsBtns["Set"], true)
end)

-- =====================
-- SEKTION 2: Rebirth
-- =====================
local rebirthSection = createSection("Rebirth")
local rebirthInput = createInput(rebirthSection, "Enter amount (0-10)", 1)
local rebirthBtns = createButtonRow(rebirthSection, {
	{ text = "Give +1", color = COLORS.btnGreen },
	{ text = "Set", color = COLORS.btnBlue },
}, 2)

rebirthBtns["Give +1"].MouseButton1Click:Connect(function()
	adminRemote:FireServer("GiveRebirth", targetInput.Text)
	flashButton(rebirthBtns["Give +1"], true)
end)

rebirthBtns["Set"].MouseButton1Click:Connect(function()
	local amount = tonumber(rebirthInput.Text)
	if not amount then showStatus("Ange ett giltigt nummer", false) return end
	adminRemote:FireServer("SetRebirth", targetInput.Text, amount)
	flashButton(rebirthBtns["Set"], true)
end)

-- =====================
-- SEKTION 3: Event Coins
-- =====================
local eventSection = createSection("Event Coins")
local eventInput = createInput(eventSection, "Enter amount to add", 1)
local eventBtn = createButton(eventSection, "Add", COLORS.btnGreen, 2)
eventBtn.Size = UDim2.new(1, 0, 0, 30)

eventBtn.MouseButton1Click:Connect(function()
	local amount = tonumber(eventInput.Text)
	if not amount then showStatus("Ange ett giltigt nummer", false) return end
	adminRemote:FireServer("AddEventCoins", targetInput.Text, amount)
	flashButton(eventBtn, true)
end)

-- =====================
-- SEKTION 4: Speed
-- =====================
local speedSection = createSection("Speed")
local speedInput = createInput(speedSection, "Enter multiplier (e.g. 2.5)", 1)
local speedBtn = createButton(speedSection, "Set", COLORS.btnBlue, 2)
speedBtn.Size = UDim2.new(1, 0, 0, 30)

speedBtn.MouseButton1Click:Connect(function()
	local mult = tonumber(speedInput.Text)
	if not mult then showStatus("Ange en giltig multiplier", false) return end
	adminRemote:FireServer("SetSpeed", targetInput.Text, mult)
	flashButton(speedBtn, true)
end)

-- =====================
-- SEKTION 5: Spawn Brainrot
-- =====================
local brainrotSection = createSection("Spawn Brainrot")
local brainrotNameInput = createInput(brainrotSection, "Enter brainrot name", 1)
local brainrotMutInput = createInput(brainrotSection, "Enter mutation (optional)", 2)
local brainrotBtns = createButtonRow(brainrotSection, {
	{ text = "Server", color = COLORS.btnGreen },
	{ text = "Global", color = COLORS.btnRed },
}, 3)

brainrotBtns["Server"].MouseButton1Click:Connect(function()
	if #brainrotNameInput.Text == 0 then showStatus("Ange brainrot-namn", false) return end
	adminRemote:FireServer("SpawnBrainrot", brainrotNameInput.Text, brainrotMutInput.Text, "Server")
	flashButton(brainrotBtns["Server"], true)
end)

brainrotBtns["Global"].MouseButton1Click:Connect(function()
	if #brainrotNameInput.Text == 0 then showStatus("Ange brainrot-namn", false) return end
	adminRemote:FireServer("SpawnBrainrot", brainrotNameInput.Text, brainrotMutInput.Text, "Global")
	flashButton(brainrotBtns["Global"], true)
end)

-- =====================
-- SEKTION 6: Spawn Wave
-- =====================
local waveSection = createSection("Spawn Wave")
local waveInput = createInput(waveSection, "Enter wave name", 1)
local waveBtns = createButtonRow(waveSection, {
	{ text = "Server", color = COLORS.btnGreen },
	{ text = "Global", color = COLORS.btnRed },
}, 2)

waveBtns["Server"].MouseButton1Click:Connect(function()
	if #waveInput.Text == 0 then showStatus("Ange vågnamn", false) return end
	adminRemote:FireServer("SpawnWave", waveInput.Text, "Server")
	flashButton(waveBtns["Server"], true)
end)

waveBtns["Global"].MouseButton1Click:Connect(function()
	if #waveInput.Text == 0 then showStatus("Ange vågnamn", false) return end
	adminRemote:FireServer("SpawnWave", waveInput.Text, "Global")
	flashButton(waveBtns["Global"], true)
end)

-- =====================
-- SEKTION 7: Spawn Event
-- =====================
local spawnEventSection = createSection("Spawn Event")
local spawnEventInput = createInput(spawnEventSection, "Enter event name", 1)
local spawnEventBtns = createButtonRow(spawnEventSection, {
	{ text = "Server", color = COLORS.btnGreen },
	{ text = "Global", color = COLORS.btnRed },
}, 2)

spawnEventBtns["Server"].MouseButton1Click:Connect(function()
	if #spawnEventInput.Text == 0 then showStatus("Ange event-namn", false) return end
	adminRemote:FireServer("SpawnWave", spawnEventInput.Text, "Server") -- Samma som wave
	flashButton(spawnEventBtns["Server"], true)
end)

spawnEventBtns["Global"].MouseButton1Click:Connect(function()
	if #spawnEventInput.Text == 0 then showStatus("Ange event-namn", false) return end
	adminRemote:FireServer("SpawnWave", spawnEventInput.Text, "Global")
	flashButton(spawnEventBtns["Global"], true)
end)

-- =====================
-- SEKTION 8: Kick Player
-- =====================
local kickSection = createSection("Kick Player")
local kickReasonInput = createInput(kickSection, "Reason (optional)", 1)
local kickBtn = createButton(kickSection, "Kick", COLORS.btnRed, 2)
kickBtn.Size = UDim2.new(1, 0, 0, 30)

kickBtn.MouseButton1Click:Connect(function()
	local target = targetInput.Text
	if #target == 0 then showStatus("Ange spelarnamn i Target-fältet", false) return end
	adminRemote:FireServer("KickPlayer", target, kickReasonInput.Text)
	flashButton(kickBtn, true)
end)

-- =====================
-- PANEL TOGGLE-ANIMATION
-- =====================
local panelOpen = false
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function togglePanel()
	panelOpen = not panelOpen
	local targetPos
	if panelOpen then
		targetPos = UDim2.new(1, -PANEL_WIDTH - 12, 0.5, 0)
	else
		targetPos = UDim2.new(1, PANEL_WIDTH + 20, 0.5, 0)
	end
	local tween = TweenService:Create(panelFrame, tweenInfo, { Position = targetPos })
	tween:Play()
end

adminBtn.MouseButton1Click:Connect(togglePanel)
closeBtn.MouseButton1Click:Connect(function()
	if panelOpen then togglePanel() end
end)

-- =====================
-- RESPONS FRÅN SERVERN
-- =====================
adminResponse.OnClientEvent:Connect(function(success, message)
	showStatus(message or (success and "OK" or "Fel"), success)
end)

print("[AdminClient] Admin-panel laddad för", player.Name)
