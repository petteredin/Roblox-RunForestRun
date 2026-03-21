-- =============================================
-- AdminClient.lua (LocalScript)
-- Admin-panel med flikar: Members, Brainrots, Admin, Logs
-- Placeras i StarterPlayerScripts.
-- =============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- =====================
-- ADMIN-KONTROLL (klient-sida, enbart för GUI-visning)
-- =====================
local ADMIN_IDS = {
	[8327644091] = true, -- Simpleson716
}

if not ADMIN_IDS[player.UserId] then
	return
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
	bg         = Color3.fromRGB(30, 30, 40),
	header     = Color3.fromRGB(255, 165, 0),
	tabBg      = Color3.fromRGB(35, 35, 48),
	tabActive  = Color3.fromRGB(255, 165, 0),
	tabInactive = Color3.fromRGB(55, 55, 70),
	btnGreen   = Color3.fromRGB(80, 200, 80),
	btnRed     = Color3.fromRGB(200, 80, 80),
	btnBlue    = Color3.fromRGB(80, 130, 220),
	text       = Color3.fromRGB(255, 255, 255),
	textDark   = Color3.fromRGB(40, 40, 40),
	input      = Color3.fromRGB(50, 50, 60),
	section    = Color3.fromRGB(40, 40, 55),
	border     = Color3.fromRGB(70, 70, 85),
	success    = Color3.fromRGB(80, 220, 80),
	error      = Color3.fromRGB(220, 80, 80),
	dimText    = Color3.fromRGB(180, 180, 180),
	rowEven    = Color3.fromRGB(38, 38, 52),
	rowOdd     = Color3.fromRGB(45, 45, 60),
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
local PANEL_WIDTH = 700
local PANEL_HEIGHT = 520
local TAB_HEIGHT = 32
local HEADER_HEIGHT = 44

local panelFrame = Instance.new("Frame")
panelFrame.Name = "AdminPanel"
panelFrame.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panelFrame.Position = UDim2.new(0.5, 0, 1.5, 0)
panelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
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
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.BackgroundColor3 = COLORS.header
header.BorderSizePixel = 0
header.Parent = panelFrame
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header
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
headerTitle.TextColor3 = COLORS.textDark
headerTitle.TextSize = 20
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = header

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

-- =====================
-- TAB BAR
-- =====================
local TAB_NAMES = { "Members", "Brainrots", "Admin", "Logs" }
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, TAB_HEIGHT)
tabBar.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
tabBar.BackgroundColor3 = COLORS.tabBg
tabBar.BorderSizePixel = 0
tabBar.Parent = panelFrame

local tabBarLayout = Instance.new("UIListLayout")
tabBarLayout.FillDirection = Enum.FillDirection.Horizontal
tabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabBarLayout.Parent = tabBar

local tabButtons = {}
local tabFrames = {}
local activeTab = nil

for i, name in ipairs(TAB_NAMES) do
	local btn = Instance.new("TextButton")
	btn.Name = "Tab_" .. name
	btn.Size = UDim2.new(1 / #TAB_NAMES, 0, 1, 0)
	btn.BackgroundColor3 = COLORS.tabInactive
	btn.Text = name
	btn.TextColor3 = COLORS.dimText
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamBold
	btn.LayoutOrder = i
	btn.BorderSizePixel = 0
	btn.Parent = tabBar
	tabButtons[name] = btn
end

-- =====================
-- CONTENT AREA (under tab bar)
-- =====================
local CONTENT_TOP = HEADER_HEIGHT + TAB_HEIGHT + 4
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -16, 1, -CONTENT_TOP - 32)
contentFrame.Position = UDim2.new(0, 8, 0, CONTENT_TOP)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true
contentFrame.Parent = panelFrame

-- Status bar (bottom)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 24)
statusLabel.Position = UDim2.new(0, 8, 1, -28)
statusLabel.BackgroundColor3 = COLORS.section
statusLabel.Text = ""
statusLabel.TextColor3 = COLORS.dimText
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextWrapped = true
statusLabel.Parent = panelFrame
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
-- TAB FRAME BUILDER
-- =====================
local function createTabFrame(name)
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "Tab_" .. name
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.ScrollBarThickness = 3
	frame.ScrollBarImageColor3 = COLORS.border
	frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Visible = false
	frame.Parent = contentFrame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	tabFrames[name] = frame
	return frame
end

-- Create all tab frames
for _, name in ipairs(TAB_NAMES) do
	createTabFrame(name)
end

-- Tab switching
local function switchTab(name)
	if activeTab == name then return end
	activeTab = name
	for tabName, frame in pairs(tabFrames) do
		frame.Visible = (tabName == name)
	end
	for tabName, btn in pairs(tabButtons) do
		if tabName == name then
			btn.BackgroundColor3 = COLORS.tabActive
			btn.TextColor3 = COLORS.textDark
		else
			btn.BackgroundColor3 = COLORS.tabInactive
			btn.TextColor3 = COLORS.dimText
		end
	end
end

for name, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function()
		switchTab(name)
	end)
end

-- =====================
-- GUI-BYGGARE (helpers)
-- =====================
local layoutOrders = {}

local function nextOrder(tabName)
	layoutOrders[tabName] = (layoutOrders[tabName] or 0) + 1
	return layoutOrders[tabName]
end

local function createSection(title, parent, tabName)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = COLORS.section
	frame.BorderSizePixel = 0
	frame.LayoutOrder = nextOrder(tabName)
	frame.Parent = parent
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

local function createButton(parent, text, color, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 30)
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

local function flashButton(btn, success)
	local original = btn.BackgroundColor3
	btn.BackgroundColor3 = success and COLORS.success or COLORS.error
	task.delay(0.3, function()
		btn.BackgroundColor3 = original
	end)
end

-- =====================================================
-- TAB 1: MEMBERS - lista alla spelare med stats
-- =====================================================
local membersTab = tabFrames["Members"]

local membersHeader = Instance.new("Frame")
membersHeader.Size = UDim2.new(1, 0, 0, 28)
membersHeader.BackgroundColor3 = COLORS.header
membersHeader.LayoutOrder = 0
membersHeader.Parent = membersTab
local mhCorner = Instance.new("UICorner")
mhCorner.CornerRadius = UDim.new(0, 6)
mhCorner.Parent = membersHeader

-- Column headers
local cols = { { "Player", 0.30 }, { "Credits", 0.17 }, { "Speed", 0.15 }, { "Rebirth", 0.15 }, { "Actions", 0.23 } }
local xOff = 0
for _, col in ipairs(cols) do
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(col[2], 0, 1, 0)
	lbl.Position = UDim2.new(xOff, 4, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = col[1]
	lbl.TextColor3 = COLORS.textDark
	lbl.TextSize = 11
	lbl.Font = Enum.Font.GothamBold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = membersHeader
	xOff = xOff + col[2]
end

local memberRows = {} -- playerName -> rowFrame

local function createMemberRow(p, order)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundColor3 = (order % 2 == 0) and COLORS.rowEven or COLORS.rowOdd
	row.LayoutOrder = order
	row.Parent = membersTab
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 4)
	rc.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.30, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 6, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = p.DisplayName
	nameLabel.TextColor3 = COLORS.text
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = row

	local creditsLabel = Instance.new("TextLabel")
	creditsLabel.Name = "CreditsLabel"
	creditsLabel.Size = UDim2.new(0.17, 0, 1, 0)
	creditsLabel.Position = UDim2.new(0.30, 4, 0, 0)
	creditsLabel.BackgroundTransparency = 1
	creditsLabel.Text = "0"
	creditsLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	creditsLabel.TextSize = 12
	creditsLabel.Font = Enum.Font.Gotham
	creditsLabel.TextXAlignment = Enum.TextXAlignment.Left
	creditsLabel.Parent = row

	local speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "SpeedLabel"
	speedLabel.Size = UDim2.new(0.15, 0, 1, 0)
	speedLabel.Position = UDim2.new(0.47, 4, 0, 0)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Text = "1.00x"
	speedLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
	speedLabel.TextSize = 12
	speedLabel.Font = Enum.Font.Gotham
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Parent = row

	local rebirthLabel = Instance.new("TextLabel")
	rebirthLabel.Name = "RebirthLabel"
	rebirthLabel.Size = UDim2.new(0.15, 0, 1, 0)
	rebirthLabel.Position = UDim2.new(0.62, 4, 0, 0)
	rebirthLabel.BackgroundTransparency = 1
	rebirthLabel.Text = "#0"
	rebirthLabel.TextColor3 = Color3.fromRGB(255, 120, 180)
	rebirthLabel.TextSize = 12
	rebirthLabel.Font = Enum.Font.Gotham
	rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthLabel.Parent = row

	-- Action buttons
	local selectBtn = Instance.new("TextButton")
	selectBtn.Name = "SelectBtn"
	selectBtn.Size = UDim2.new(0.11, -2, 0, 22)
	selectBtn.Position = UDim2.new(0.77, 4, 0.5, -11)
	selectBtn.BackgroundColor3 = COLORS.btnBlue
	selectBtn.Text = "Select"
	selectBtn.TextColor3 = COLORS.text
	selectBtn.TextSize = 10
	selectBtn.Font = Enum.Font.GothamBold
	selectBtn.Parent = row
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 4)
	sc.Parent = selectBtn

	local kickBtn = Instance.new("TextButton")
	kickBtn.Name = "KickBtn"
	kickBtn.Size = UDim2.new(0.11, -2, 0, 22)
	kickBtn.Position = UDim2.new(0.88, 4, 0.5, -11)
	kickBtn.BackgroundColor3 = COLORS.btnRed
	kickBtn.Text = "Kick"
	kickBtn.TextColor3 = COLORS.text
	kickBtn.TextSize = 10
	kickBtn.Font = Enum.Font.GothamBold
	kickBtn.Parent = row
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(0, 4)
	kc.Parent = kickBtn

	-- Target player input reference (set when Admin tab exists)
	selectBtn.MouseButton1Click:Connect(function()
		if targetInput then
			targetInput.Text = p.Name
		end
		switchTab("Admin")
		showStatus("Selected: " .. p.DisplayName, true)
	end)

	kickBtn.MouseButton1Click:Connect(function()
		adminRemote:FireServer("KickPlayer", p.Name, "Kicked by admin")
		flashButton(kickBtn, true)
	end)

	memberRows[p.Name] = row
	return row
end

-- Refresh member list
local function refreshMembers()
	-- Remove old rows
	for name, row in pairs(memberRows) do
		row:Destroy()
		memberRows[name] = nil
	end
	-- Add current players
	for i, p in ipairs(Players:GetPlayers()) do
		createMemberRow(p, i)
	end
end

-- Auto-refresh on join/leave
Players.PlayerAdded:Connect(function() task.wait(0.5); refreshMembers() end)
Players.PlayerRemoving:Connect(function() task.wait(0.1); refreshMembers() end)

-- Periodic stats update for members tab
task.spawn(function()
	while true do
		task.wait(2)
		if activeTab == "Members" then
			for _, p in ipairs(Players:GetPlayers()) do
				local row = memberRows[p.Name]
				if row then
					local char = p.Character
					local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
					local speed = humanoid and humanoid.WalkSpeed or 16
					local speedMult = speed / 16
					row:FindFirstChild("SpeedLabel").Text = string.format("%.1fx", speedMult)

					-- Credits & rebirth from leaderstats if available
					local ls = p:FindFirstChild("leaderstats")
					if ls then
						local credits = ls:FindFirstChild("Credits")
						if credits then row:FindFirstChild("CreditsLabel").Text = tostring(credits.Value) end
						local rebirth = ls:FindFirstChild("Rebirth")
						if rebirth then row:FindFirstChild("RebirthLabel").Text = "#" .. tostring(rebirth.Value) end
					end
				end
			end
		end
	end
end)

refreshMembers()

-- =====================================================
-- TAB 2: BRAINROTS - Spawn Brainrot, Wave, Event
-- =====================================================
local brainrotsTab = tabFrames["Brainrots"]

-- Spawn Brainrot
local brainrotSection = createSection("Spawn Brainrot", brainrotsTab, "Brainrots")
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

-- Spawn Wave
local waveSection = createSection("Spawn Wave", brainrotsTab, "Brainrots")
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

-- Spawn Event
local eventSection = createSection("Spawn Event", brainrotsTab, "Brainrots")
local eventInput = createInput(eventSection, "Enter event name", 1)
local eventBtns = createButtonRow(eventSection, {
	{ text = "Server", color = COLORS.btnGreen },
	{ text = "Global", color = COLORS.btnRed },
}, 2)

eventBtns["Server"].MouseButton1Click:Connect(function()
	if #eventInput.Text == 0 then showStatus("Ange event-namn", false) return end
	adminRemote:FireServer("SpawnWave", eventInput.Text, "Server")
	flashButton(eventBtns["Server"], true)
end)

eventBtns["Global"].MouseButton1Click:Connect(function()
	if #eventInput.Text == 0 then showStatus("Ange event-namn", false) return end
	adminRemote:FireServer("SpawnWave", eventInput.Text, "Global")
	flashButton(eventBtns["Global"], true)
end)

-- =====================================================
-- TAB 3: ADMIN - Target Player, Credits, Rebirth, Speed, Kick
-- =====================================================
local adminTab = tabFrames["Admin"]

-- Use two columns inside Admin tab
local adminLeftCol = Instance.new("Frame")
adminLeftCol.Size = UDim2.new(0.5, -4, 0, 0)
adminLeftCol.AutomaticSize = Enum.AutomaticSize.Y
adminLeftCol.BackgroundTransparency = 1
adminLeftCol.LayoutOrder = 1
adminLeftCol.Parent = adminTab

local adminLeftLayout = Instance.new("UIListLayout")
adminLeftLayout.Padding = UDim.new(0, 6)
adminLeftLayout.SortOrder = Enum.SortOrder.LayoutOrder
adminLeftLayout.Parent = adminLeftCol

local adminRightCol = Instance.new("Frame")
adminRightCol.Size = UDim2.new(0.5, -4, 0, 0)
adminRightCol.Position = UDim2.new(0.5, 4, 0, 0)
adminRightCol.AutomaticSize = Enum.AutomaticSize.Y
adminRightCol.BackgroundTransparency = 1
adminRightCol.LayoutOrder = 1
adminRightCol.Parent = adminTab

local adminRightLayout = Instance.new("UIListLayout")
adminRightLayout.Padding = UDim.new(0, 6)
adminRightLayout.SortOrder = Enum.SortOrder.LayoutOrder
adminRightLayout.Parent = adminRightCol

-- Actually, use single column with full width for cleaner layout
-- Remove the two-column approach, use the tab scrollframe directly

adminLeftCol:Destroy()
adminRightCol:Destroy()

-- Target Player
local targetSection = createSection("Target Player", adminTab, "Admin")
local targetInput = createInput(targetSection, "Player name (blank = yourself)", 1)

-- Autocomplete
local autocompleteFrame = Instance.new("Frame")
autocompleteFrame.Name = "AutocompleteDropdown"
autocompleteFrame.Size = UDim2.new(1, -20, 0, 0)
autocompleteFrame.AutomaticSize = Enum.AutomaticSize.Y
autocompleteFrame.BackgroundColor3 = COLORS.input
autocompleteFrame.BorderSizePixel = 0
autocompleteFrame.Visible = false
autocompleteFrame.ZIndex = 100
autocompleteFrame.LayoutOrder = 2
autocompleteFrame.Parent = targetSection
local acCorner = Instance.new("UICorner")
acCorner.CornerRadius = UDim.new(0, 6)
acCorner.Parent = autocompleteFrame
local acStroke = Instance.new("UIStroke")
acStroke.Color = COLORS.header
acStroke.Thickness = 1
acStroke.Parent = autocompleteFrame
local acLayout = Instance.new("UIListLayout")
acLayout.Padding = UDim.new(0, 0)
acLayout.SortOrder = Enum.SortOrder.LayoutOrder
acLayout.Parent = autocompleteFrame

local MAX_SUGGESTIONS = 5

local function clearAutocomplete()
	for _, child in ipairs(autocompleteFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	autocompleteFrame.Visible = false
end

local function updateAutocomplete(query)
	clearAutocomplete()
	if query == "" then return end
	local lowerQuery = query:lower()
	local matches = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local name = p.Name:lower()
		local display = p.DisplayName:lower()
		if name:find(lowerQuery, 1, true) or display:find(lowerQuery, 1, true) then
			table.insert(matches, p)
		end
		if #matches >= MAX_SUGGESTIONS then break end
	end
	if #matches == 0 then return end
	if #matches == 1 and (matches[1].Name:lower() == lowerQuery or matches[1].DisplayName:lower() == lowerQuery) then
		return
	end
	for i, matchPlayer in ipairs(matches) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 28)
		btn.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(55, 55, 70) or Color3.fromRGB(45, 45, 60)
		btn.Text = "  " .. matchPlayer.DisplayName .. " (@" .. matchPlayer.Name .. ")"
		btn.TextColor3 = COLORS.text
		btn.TextSize = 12
		btn.Font = Enum.Font.Gotham
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.LayoutOrder = i
		btn.ZIndex = 101
		btn.Parent = autocompleteFrame
		if i == 1 or i == #matches then
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(0, 6)
			bc.Parent = btn
		end
		btn.MouseButton1Click:Connect(function()
			targetInput.Text = matchPlayer.Name
			clearAutocomplete()
		end)
	end
	autocompleteFrame.Visible = true
end

targetInput:GetPropertyChangedSignal("Text"):Connect(function()
	updateAutocomplete(targetInput.Text)
end)
targetInput.Focused:Connect(function()
	if targetInput.Text ~= "" then updateAutocomplete(targetInput.Text) end
end)
targetInput.FocusLost:Connect(function()
	task.delay(0.15, function() clearAutocomplete() end)
end)

-- Credits
local creditsSection = createSection("Credits", adminTab, "Admin")
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

-- Rebirth
local rebirthSection = createSection("Rebirth", adminTab, "Admin")
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

-- Speed
local speedSection = createSection("Speed", adminTab, "Admin")
local speedInput = createInput(speedSection, "Enter multiplier (e.g. 2.5)", 1)
local speedBtn = createButton(speedSection, "Set", COLORS.btnBlue, 2)

speedBtn.MouseButton1Click:Connect(function()
	local mult = tonumber(speedInput.Text)
	if not mult then showStatus("Ange en giltig multiplier", false) return end
	adminRemote:FireServer("SetSpeed", targetInput.Text, mult)
	flashButton(speedBtn, true)
end)

-- Kick Player
local kickSection = createSection("Kick Player", adminTab, "Admin")
local kickReasonInput = createInput(kickSection, "Reason (optional)", 1)
local kickBtn = createButton(kickSection, "Kick", COLORS.btnRed, 2)

kickBtn.MouseButton1Click:Connect(function()
	local target = targetInput.Text
	if #target == 0 then showStatus("Ange spelarnamn i Target-fältet", false) return end
	adminRemote:FireServer("KickPlayer", target, kickReasonInput.Text)
	flashButton(kickBtn, true)
end)

-- =====================================================
-- TAB 4: LOGS - admin action log
-- =====================================================
local logsTab = tabFrames["Logs"]
local logEntries = {}
local MAX_LOG_ENTRIES = 50

local function addLogEntry(text, isError)
	local entry = Instance.new("TextLabel")
	entry.Size = UDim2.new(1, 0, 0, 0)
	entry.AutomaticSize = Enum.AutomaticSize.Y
	entry.BackgroundColor3 = (#logEntries % 2 == 0) and COLORS.rowEven or COLORS.rowOdd
	entry.Text = "  " .. os.date("%H:%M:%S") .. "  " .. text
	entry.TextColor3 = isError and COLORS.error or COLORS.dimText
	entry.TextSize = 11
	entry.Font = Enum.Font.Gotham
	entry.TextXAlignment = Enum.TextXAlignment.Left
	entry.TextWrapped = true
	entry.LayoutOrder = 9999 - #logEntries -- Newest on top
	entry.Parent = logsTab
	local ec = Instance.new("UICorner")
	ec.CornerRadius = UDim.new(0, 4)
	ec.Parent = entry
	local ep = Instance.new("UIPadding")
	ep.PaddingTop = UDim.new(0, 4)
	ep.PaddingBottom = UDim.new(0, 4)
	ep.PaddingLeft = UDim.new(0, 6)
	ep.PaddingRight = UDim.new(0, 6)
	ep.Parent = entry

	table.insert(logEntries, 1, entry)

	-- Trim old entries
	while #logEntries > MAX_LOG_ENTRIES do
		local old = table.remove(logEntries)
		if old then old:Destroy() end
	end
end

-- =====================
-- PANEL TOGGLE
-- =====================
local panelOpen = false
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function togglePanel()
	panelOpen = not panelOpen
	local targetPos
	if panelOpen then
		targetPos = UDim2.new(0.5, 0, 0.5, 0)
	else
		targetPos = UDim2.new(0.5, 0, 1.5, 0)
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
	addLogEntry(message or (success and "OK" or "Fel"), not success)
end)

-- Start on Members tab
switchTab("Members")

print("[AdminClient] Admin-panel med flikar laddad för", player.Name)
