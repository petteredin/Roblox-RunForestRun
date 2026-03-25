-- =============================================
-- AdminClient.lua (LocalScript)
-- Admin panel with tabs: Members, Brainrots, Admin, Logs
-- Placed in StarterPlayerScripts.
-- =============================================

print("[AdminClient] Script starting...")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
print("[AdminClient] Waiting for GameConfig...")
local gameConfigModule = ReplicatedStorage:WaitForChild("GameConfig", 30)
print("[AdminClient] GameConfig found:", gameConfigModule ~= nil)
if not gameConfigModule then
	warn("[AdminClient] GameConfig module not found - admin panel may not work correctly")
end
local GameConfig = gameConfigModule and require(gameConfigModule) or {
	BRAINROTS = {}, MUTATIONS = {}, MUTATIONS_BY_KEY = {},
	RARITY_ORDER = {}, RARITY_COLORS = {}, LUCK_PRODUCTS = {}, GAMEPASS_IDS = {}
}
print("[AdminClient] GameConfig loaded. Player:", Players.LocalPlayer.Name, "UserId:", Players.LocalPlayer.UserId)

local player = Players.LocalPlayer

-- =====================
-- ADMIN CHECK (client-side, GUI display only)
-- Asks the server if the player is admin instead of using a hardcoded list
-- =====================
local ADMIN_IDS = {
	[8327644091] = true, -- Simpleson716 (fallback)
}

-- Check with the server if we are admin and get role
local isAdminFunc = ReplicatedStorage:WaitForChild("IsAdmin", 10)
local isAdmin = ADMIN_IDS[player.UserId] -- fallback
local adminRole = ADMIN_IDS[player.UserId] and "owner" or nil
if isAdminFunc then
	local ok, resultAdmin, resultRole = pcall(isAdminFunc.InvokeServer, isAdminFunc)
	if ok then
		isAdmin = resultAdmin
		adminRole = resultRole
	end
end

if not isAdmin then
	warn("[AdminClient] NOT admin. UserId:", player.UserId, "Name:", player.Name, "isAdminFunc found:", isAdminFunc ~= nil)
	return
end

local isOwner = (adminRole == "owner")

-- =====================
-- REMOTE EVENTS
-- =====================
local adminRemote = ReplicatedStorage:WaitForChild("AdminRemote", 10)
local adminResponse = ReplicatedStorage:WaitForChild("AdminResponse", 10)

if not adminRemote or not adminResponse then
	warn("[AdminClient] Could not find AdminRemote/AdminResponse")
	return
end

-- =====================
-- COLOR THEME
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
-- CREATE GUI
-- =====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminPanelGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Forward declarations
local togglePanel
local refreshBanList

-- =====================
-- ADMIN BUTTON (finds the Owner button from BrainrotPlayerScripts)
-- =====================
-- Create an invisible clickable button placed on top of the Owner button
local adminBtn = nil
task.spawn(function()
	-- Wait for the Owner button to be created by BrainrotPlayerScripts
	local playerGui = player:WaitForChild("PlayerGui")
	local bottomGui = nil
	for i = 1, 30 do
		for _, gui in ipairs(playerGui:GetChildren()) do
			if gui:IsA("ScreenGui") then
				local ownerBtn = gui:FindFirstChild("OwnerButton", true)
				if ownerBtn then
					bottomGui = gui
					-- We already know we are admin (IsAdmin check passed)
					-- Make the Owner button visible immediately
					ownerBtn.Visible = true
					-- Place a transparent TextButton on top of the Owner button
					adminBtn = Instance.new("TextButton")
					adminBtn.Name = "AdminToggleOverlay"
					adminBtn.Size = UDim2.new(1, 0, 1, 0)
					adminBtn.BackgroundTransparency = 1
					adminBtn.Text = ""
					adminBtn.Parent = ownerBtn
					adminBtn.MouseButton1Click:Connect(function()
						togglePanel()
					end)
					print("[AdminClient] Owner button found and visible")
					return
				end
			end
		end
		task.wait(0.5)
	end
	-- Fallback: create our own button if Owner button not found
	adminBtn = Instance.new("TextButton")
	adminBtn.Name = "AdminToggle"
	adminBtn.Size = UDim2.new(0, 50, 0, 50)
	adminBtn.Position = UDim2.new(1, -60, 1, -60)
	adminBtn.BackgroundColor3 = COLORS.header
	adminBtn.Text = "ADM"
	adminBtn.TextColor3 = COLORS.text
	adminBtn.TextSize = 14
	adminBtn.Font = Enum.Font.GothamBold
	adminBtn.Parent = screenGui
	Instance.new("UICorner", adminBtn).CornerRadius = UDim.new(0, 8)
	adminBtn.MouseButton1Click:Connect(function()
		togglePanel()
	end)
end)

-- =====================
-- ADMIN PANEL (main window)
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
-- Tabs visible based on role
local ALL_TAB_NAMES = { "Members", "Brainrots", "Admin", "Banned", "Logs" }
local ADMIN_TAB_NAMES = { "Members", "Brainrots" } -- Admins only see Members + Brainrots (for luck)
local TAB_NAMES = isOwner and ALL_TAB_NAMES or ADMIN_TAB_NAMES
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
	-- Refresh ban list when switching to Banned tab
	if name == "Banned" and refreshBanList then
		task.spawn(refreshBanList)
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
-- GUI BUILDERS (helpers)
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
-- TAB 1: MEMBERS - list all players with stats
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

	local nameBtn = Instance.new("TextButton")
	nameBtn.Name = "NameLabel"
	nameBtn.Size = UDim2.new(0.30, 0, 1, 0)
	nameBtn.Position = UDim2.new(0, 6, 0, 0)
	nameBtn.BackgroundTransparency = 1
	nameBtn.Text = p.DisplayName
	nameBtn.TextColor3 = COLORS.text
	nameBtn.TextSize = 12
	nameBtn.Font = Enum.Font.GothamBold
	nameBtn.TextXAlignment = Enum.TextXAlignment.Left
	nameBtn.TextTruncate = Enum.TextTruncate.AtEnd
	nameBtn.Parent = row

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

	-- Clickable name -> selects player and switches to Admin tab
	nameBtn.MouseButton1Click:Connect(function()
		if targetInput then
			targetInput.Text = p.Name
		end
		switchTab("Admin")
		showStatus("Selected: " .. p.DisplayName, true)
	end)

	-- Action buttons — VIP for all admins, Admin+Kick for owners only
	do
		local btnX = 0.68 -- starting X position for action buttons

		-- VIP button (all admins can grant)
		-- Check both the attribute and the crown billboard (attribute may not be set in Studio)
		local isVIP = p:GetAttribute("Own_VIP")
		if not isVIP and p.Character then
			local head = p.Character:FindFirstChild("Head")
			if head and head:FindFirstChild("VIPCrown") then
				isVIP = true
			end
		end
		local vipBtn = Instance.new("TextButton")
		vipBtn.Name = "VIPBtn"
		vipBtn.Size = UDim2.new(0.10, -2, 0, 22)
		vipBtn.Position = UDim2.new(btnX, 2, 0.5, -11)
		vipBtn.BackgroundColor3 = isVIP and Color3.fromRGB(255, 180, 0) or Color3.fromRGB(80, 80, 40)
		vipBtn.Text = isVIP and "VIP" or "VIP"
		vipBtn.TextColor3 = isVIP and COLORS.textDark or Color3.fromRGB(255, 215, 0)
		vipBtn.TextSize = 10
		vipBtn.Font = Enum.Font.GothamBold
		vipBtn.Parent = row
		Instance.new("UICorner", vipBtn).CornerRadius = UDim.new(0, 4)
		btnX = btnX + 0.10

		vipBtn.MouseButton1Click:Connect(function()
			if isVIP then
				showStatus(p.DisplayName .. " already has VIP", false)
				return
			end
			adminRemote:FireServer("GrantVIP", p.Name)
			-- Mark as VIP immediately (optimistic)
			isVIP = true
			vipBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
			vipBtn.TextColor3 = COLORS.textDark
			showStatus("Granted VIP to " .. p.DisplayName, true)
		end)

		-- Admin + Kick buttons (owner only)
		if isOwner then
			local isPlayerAdmin = ADMIN_IDS[p.UserId]

			local adminToggleBtn = Instance.new("TextButton")
			adminToggleBtn.Name = "AdminBtn"
			adminToggleBtn.Size = UDim2.new(0.10, -2, 0, 22)
			adminToggleBtn.Position = UDim2.new(btnX, 2, 0.5, -11)
			adminToggleBtn.BackgroundColor3 = isPlayerAdmin and COLORS.header or COLORS.tabInactive
			adminToggleBtn.Text = "Admin"
			adminToggleBtn.TextColor3 = isPlayerAdmin and COLORS.textDark or COLORS.dimText
			adminToggleBtn.TextSize = 10
			adminToggleBtn.Font = Enum.Font.GothamBold
			adminToggleBtn.Parent = row
			Instance.new("UICorner", adminToggleBtn).CornerRadius = UDim.new(0, 4)
			btnX = btnX + 0.10

			local kickBtn = Instance.new("TextButton")
			kickBtn.Name = "KickBtn"
			kickBtn.Size = UDim2.new(0.10, -2, 0, 22)
			kickBtn.Position = UDim2.new(btnX, 2, 0.5, -11)
			kickBtn.BackgroundColor3 = COLORS.btnRed
			kickBtn.Text = "Kick"
			kickBtn.TextColor3 = COLORS.text
			kickBtn.TextSize = 10
			kickBtn.Font = Enum.Font.GothamBold
			kickBtn.Parent = row
			Instance.new("UICorner", kickBtn).CornerRadius = UDim.new(0, 4)

		adminToggleBtn.MouseButton1Click:Connect(function()
			debugPrint("[ADMIN CLIENT] Toggle admin clicked for:", p.Name, "UserId:", p.UserId)
			showStatus("Sending ToggleAdmin for " .. p.Name .. "...", true)
			local ok, err = pcall(function()
				adminRemote:FireServer("ToggleAdmin", p.Name)
			end)
			if not ok then
				showStatus("FireServer failed: " .. tostring(err), false)
				return
			end
			local wasAdmin = adminToggleBtn.BackgroundColor3 == COLORS.header
			if wasAdmin then
				adminToggleBtn.BackgroundColor3 = COLORS.tabInactive
				adminToggleBtn.TextColor3 = COLORS.dimText
			else
				adminToggleBtn.BackgroundColor3 = COLORS.header
				adminToggleBtn.TextColor3 = COLORS.textDark
			end
			task.delay(3, function()
				if statusLabel.Text == "  Sending ToggleAdmin for " .. p.Name .. "..." then
					showStatus("No response from server - check server logs", false)
				end
			end)
		end)

		kickBtn.MouseButton1Click:Connect(function()
			adminRemote:FireServer("KickPlayer", p.Name, "Kicked by admin")
			flashButton(kickBtn, true)
		end)
		end -- end if isOwner (Admin + Kick)
	end -- end do block (action buttons)

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
					local sl = row:FindFirstChild("SpeedLabel")
					if sl then sl.Text = string.format("%.1fx", speedMult) end

					-- Credits & rebirth from leaderstats if available
					local ls = p:FindFirstChild("leaderstats")
					if ls then
						local credits = ls:FindFirstChild("Credits")
						local cl = row:FindFirstChild("CreditsLabel")
						if credits and cl then cl.Text = tostring(credits.Value) end
						local rebirth = ls:FindFirstChild("Rebirth")
						local rl = row:FindFirstChild("RebirthLabel")
						if rebirth and rl then rl.Text = "#" .. tostring(rebirth.Value) end
					end
				end
			end
		end
	end
end)

refreshMembers()

-- =====================================================
-- TAB 2: BRAINROTS - Spawn Brainrot (dropdown) + Broadcast Message + Grant Luck
-- =====================================================
local brainrotsTab = tabFrames["Brainrots"]

-- =====================
-- SPAWN BRAINROT (Owner only)
-- =====================
-- Spawn Brainrot section (all admins — Server only for non-owners)
do
local brainrotSection = createSection("Spawn Brainrot", brainrotsTab, "Brainrots")

-- Selected state
local selectedBrainrot = nil
local selectedMutation = "NONE"

-- Label showing current selection
local selectionLabel = Instance.new("TextLabel")
selectionLabel.Size = UDim2.new(1, 0, 0, 22)
selectionLabel.BackgroundTransparency = 1
selectionLabel.Text = "Selected: (none)  |  Mutation: Normal"
selectionLabel.TextColor3 = COLORS.dimText
selectionLabel.TextScaled = true
selectionLabel.Font = Enum.Font.Gotham
selectionLabel.TextXAlignment = Enum.TextXAlignment.Left
selectionLabel.LayoutOrder = 1
selectionLabel.Parent = brainrotSection

local function updateSelectionLabel()
	local bName = selectedBrainrot and selectedBrainrot.name or "(none)"
	local mLabel = "Normal"
	for _, m in ipairs(GameConfig.MUTATIONS) do
		if m.key == selectedMutation then mLabel = m.label break end
	end
	selectionLabel.Text = "Selected: " .. bName .. "  |  Mutation: " .. mLabel
	selectionLabel.TextColor3 = selectedBrainrot and COLORS.success or COLORS.dimText
end

-- Brainrot list (scrollable)
local brainrotListLabel = Instance.new("TextLabel")
brainrotListLabel.Size = UDim2.new(1, 0, 0, 18)
brainrotListLabel.BackgroundTransparency = 1
brainrotListLabel.Text = "Choose Brainrot:"
brainrotListLabel.TextColor3 = COLORS.text
brainrotListLabel.TextScaled = true
brainrotListLabel.Font = Enum.Font.GothamBold
brainrotListLabel.TextXAlignment = Enum.TextXAlignment.Left
brainrotListLabel.LayoutOrder = 2
brainrotListLabel.Parent = brainrotSection

local brainrotScroll = Instance.new("ScrollingFrame")
brainrotScroll.Size = UDim2.new(1, 0, 0, 160)
brainrotScroll.BackgroundColor3 = COLORS.input
brainrotScroll.BorderSizePixel = 0
brainrotScroll.ScrollBarThickness = 5
brainrotScroll.ScrollBarImageColor3 = COLORS.border
brainrotScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
brainrotScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
brainrotScroll.LayoutOrder = 3
brainrotScroll.Parent = brainrotSection
Instance.new("UICorner", brainrotScroll).CornerRadius = UDim.new(0, 6)

local brainrotListLayout = Instance.new("UIListLayout")
brainrotListLayout.Padding = UDim.new(0, 2)
brainrotListLayout.SortOrder = Enum.SortOrder.LayoutOrder
brainrotListLayout.Parent = brainrotScroll

local brainrotListPadding = Instance.new("UIPadding")
brainrotListPadding.PaddingTop = UDim.new(0, 2)
brainrotListPadding.PaddingLeft = UDim.new(0, 2)
brainrotListPadding.PaddingRight = UDim.new(0, 2)
brainrotListPadding.Parent = brainrotScroll

local brainrotRowButtons = {}
for i, b in ipairs(GameConfig.BRAINROTS) do
	local rarityColor = GameConfig.RARITY_COLORS[b.rarity] or COLORS.dimText
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 26)
	btn.BackgroundColor3 = (i % 2 == 0) and COLORS.rowEven or COLORS.rowOdd
	btn.BorderSizePixel = 0
	btn.Text = "  " .. b.icon .. "  " .. b.name
	btn.TextColor3 = rarityColor
	btn.TextScaled = true
	btn.Font = Enum.Font.Gotham
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.LayoutOrder = i
	btn.Parent = brainrotScroll
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

	brainrotRowButtons[i] = btn

	btn.MouseButton1Click:Connect(function()
		selectedBrainrot = b
		-- Highlight selected row, dim others
		for j, otherBtn in ipairs(brainrotRowButtons) do
			if j == i then
				otherBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
			else
				otherBtn.BackgroundColor3 = (j % 2 == 0) and COLORS.rowEven or COLORS.rowOdd
			end
		end
		updateSelectionLabel()
	end)
end

-- Mutation selector (row of buttons)
local mutationLabel = Instance.new("TextLabel")
mutationLabel.Size = UDim2.new(1, 0, 0, 18)
mutationLabel.BackgroundTransparency = 1
mutationLabel.Text = "Choose Mutation:"
mutationLabel.TextColor3 = COLORS.text
mutationLabel.TextScaled = true
mutationLabel.Font = Enum.Font.GothamBold
mutationLabel.TextXAlignment = Enum.TextXAlignment.Left
mutationLabel.LayoutOrder = 4
mutationLabel.Parent = brainrotSection

local mutationRow = Instance.new("Frame")
mutationRow.Size = UDim2.new(1, 0, 0, 30)
mutationRow.BackgroundTransparency = 1
mutationRow.LayoutOrder = 5
mutationRow.Parent = brainrotSection

local mutRowLayout = Instance.new("UIListLayout")
mutRowLayout.FillDirection = Enum.FillDirection.Horizontal
mutRowLayout.Padding = UDim.new(0, 4)
mutRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
mutRowLayout.Parent = mutationRow

local mutationButtons = {}
for i, m in ipairs(GameConfig.MUTATIONS) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 80, 1, 0)
	btn.BackgroundColor3 = m.color
	btn.BorderSizePixel = 0
	btn.Text = m.label
	btn.TextColor3 = (m.key == "GOLD") and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.LayoutOrder = i
	btn.Parent = mutationRow
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	-- Highlight default
	if m.key == "NONE" then
		btn.BackgroundTransparency = 0
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = COLORS.success
		stroke.Name = "SelectStroke"
		stroke.Parent = btn
	else
		btn.BackgroundTransparency = 0.3
	end

	mutationButtons[i] = { btn = btn, key = m.key }

	btn.MouseButton1Click:Connect(function()
		selectedMutation = m.key
		for _, mb in ipairs(mutationButtons) do
			mb.btn.BackgroundTransparency = (mb.key == selectedMutation) and 0 or 0.3
			local existingStroke = mb.btn:FindFirstChild("SelectStroke")
			if existingStroke then existingStroke:Destroy() end
		end
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = COLORS.success
		stroke.Name = "SelectStroke"
		stroke.Parent = btn
		updateSelectionLabel()
	end)
end

-- Spawn buttons: admins get Server only, owners get Server + Global
local spawnBtnDefs = {
	{ text = "Server", color = COLORS.btnGreen },
}
if isOwner then
	table.insert(spawnBtnDefs, { text = "Global", color = COLORS.btnRed })
end
local spawnBtns = createButtonRow(brainrotSection, spawnBtnDefs, 6)

spawnBtns["Server"].MouseButton1Click:Connect(function()
	if not selectedBrainrot then showStatus("Select a brainrot first", false) return end
	adminRemote:FireServer("SpawnBrainrot", selectedBrainrot.name, selectedMutation, "Server")
	flashButton(spawnBtns["Server"], true)
end)

if isOwner and spawnBtns["Global"] then
	spawnBtns["Global"].MouseButton1Click:Connect(function()
		if not selectedBrainrot then showStatus("Select a brainrot first", false) return end
		adminRemote:FireServer("SpawnBrainrot", selectedBrainrot.name, selectedMutation, "Global")
		flashButton(spawnBtns["Global"], true)
	end)
end

end -- end do block (Spawn Brainrot)

-- =====================
-- BROADCAST MESSAGE (Owner only)
-- =====================
if isOwner then
	local msgSection = createSection("Broadcast Message", brainrotsTab, "Brainrots")
	local msgInput = createInput(msgSection, "Enter message text", 1)
	local msgDurationInput = createInput(msgSection, "Duration in seconds (default: 5)", 2)
	local msgBtns = createButtonRow(msgSection, {
		{ text = "Server", color = COLORS.btnGreen },
		{ text = "Global", color = COLORS.btnRed },
	}, 3)

	msgBtns["Server"].MouseButton1Click:Connect(function()
		if #msgInput.Text == 0 then showStatus("Enter a message", false) return end
		local dur = tonumber(msgDurationInput.Text) or 5
		adminRemote:FireServer("SendMessage", msgInput.Text, dur, "Server")
		flashButton(msgBtns["Server"], true)
	end)

	msgBtns["Global"].MouseButton1Click:Connect(function()
		if #msgInput.Text == 0 then showStatus("Enter a message", false) return end
		local dur = tonumber(msgDurationInput.Text) or 5
		adminRemote:FireServer("SendMessage", msgInput.Text, dur, "Global")
		flashButton(msgBtns["Global"], true)
	end)
end -- end if isOwner (Broadcast Message)

-- ── Grant Luck ──
local luckSection = createSection("Grant Luck", brainrotsTab, "Brainrots")

-- Build a lookup: mult -> product info (price, id, duration)
local luckProductLookup = {}
for _, prod in ipairs(GameConfig.LUCK_PRODUCTS or {}) do
	luckProductLookup[prod.mult] = prod
end

-- Luck multiplier selector (scrollable list of buttons with prices)
local selectedLuckMult = 1
local luckMultLabel = Instance.new("TextLabel")
luckMultLabel.Size = UDim2.new(1, -8, 0, 22)
luckMultLabel.Position = UDim2.new(0, 4, 0, 4)
luckMultLabel.BackgroundTransparency = 1
luckMultLabel.Text = "Multiplier: 1x (Reset)"
luckMultLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
luckMultLabel.TextScaled = true
luckMultLabel.Font = Enum.Font.GothamBold
luckMultLabel.TextXAlignment = Enum.TextXAlignment.Left
luckMultLabel.LayoutOrder = 1
luckMultLabel.Parent = luckSection

local luckBtnFrame = Instance.new("Frame")
luckBtnFrame.Size = UDim2.new(1, -8, 0, 80)
luckBtnFrame.Position = UDim2.new(0, 4, 0, 28)
luckBtnFrame.BackgroundTransparency = 1
luckBtnFrame.LayoutOrder = 2
luckBtnFrame.Parent = luckSection

local luckGrid = Instance.new("UIGridLayout")
luckGrid.CellSize = UDim2.new(0, 75, 0, 34)
luckGrid.CellPadding = UDim2.new(0, 4, 0, 4)
luckGrid.FillDirection = Enum.FillDirection.Horizontal
luckGrid.SortOrder = Enum.SortOrder.LayoutOrder
luckGrid.Parent = luckBtnFrame

local allLuckTiers = GameConfig.LUCK_TIERS or { 1, 5, 10, 25, 50, 100, 250, 500, 1000 }
-- Admins can only access 5x-250x; Owners get all tiers
local luckTiers = {}
if isOwner then
	luckTiers = allLuckTiers
else
	for _, tier in ipairs(allLuckTiers) do
		if tier >= 5 and tier <= 250 then
			table.insert(luckTiers, tier)
		end
	end
end
local luckButtons = {}
for i, tier in ipairs(luckTiers) do
	local prod = luckProductLookup[tier]
	local priceText = tier == 1 and "Reset" or (prod and ("R$ " .. prod.price) or "N/A")

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 75, 0, 34)
	btn.BackgroundColor3 = tier == selectedLuckMult and Color3.fromRGB(80, 160, 60) or Color3.fromRGB(50, 55, 65)
	btn.BorderSizePixel = 0
	btn.Text = tier .. "x\n" .. priceText
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.LayoutOrder = i
	btn.Parent = luckBtnFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

	btn.MouseButton1Click:Connect(function()
		selectedLuckMult = tier
		local info = luckProductLookup[tier]
		if tier == 1 then
			luckMultLabel.Text = "Multiplier: 1x (Reset)"
		elseif info then
			luckMultLabel.Text = "Multiplier: " .. tier .. "x | R$ " .. info.price .. " | " .. info.duration .. " min"
		else
			luckMultLabel.Text = "Multiplier: " .. tier .. "x"
		end
		for _, b in pairs(luckButtons) do
			b.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
		end
		btn.BackgroundColor3 = Color3.fromRGB(80, 160, 60)
	end)
	luckButtons[tier] = btn
end

local luckDurInput = createInput(luckSection, "Duration in minutes (default: 15)", 3)

-- Button row: admins only get Server grant, owners get all
local luckButtonDefs = {
	{ text = "Grant (Server)", color = COLORS.btnGreen },
}
if isOwner then
	table.insert(luckButtonDefs, { text = "Grant (Global)", color = COLORS.btnRed })
	table.insert(luckButtonDefs, { text = "Buy (R$)", color = Color3.fromRGB(50, 120, 200) })
end

local luckBtns = createButtonRow(luckSection, luckButtonDefs, 4)

luckBtns["Grant (Server)"].MouseButton1Click:Connect(function()
	local dur = tonumber(luckDurInput.Text) or 15
	adminRemote:FireServer("GrantLuck", selectedLuckMult, dur, "Server")
	flashButton(luckBtns["Grant (Server)"], true)
end)

if isOwner and luckBtns["Grant (Global)"] then
	luckBtns["Grant (Global)"].MouseButton1Click:Connect(function()
		local dur = tonumber(luckDurInput.Text) or 15
		adminRemote:FireServer("GrantLuck", selectedLuckMult, dur, "Global")
		flashButton(luckBtns["Grant (Global)"], true)
	end)
end

if isOwner and luckBtns["Buy (R$)"] then
	luckBtns["Buy (R$)"].MouseButton1Click:Connect(function()
		local prod = luckProductLookup[selectedLuckMult]
		if not prod or prod.id == 0 then
			flashButton(luckBtns["Buy (R$)"], false)
			return
		end
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, prod.id)
		end)
		flashButton(luckBtns["Buy (R$)"], true)
	end)
end

-- =====================================================
-- TAB 3: ADMIN - Target Player, Credits, Rebirth, Speed, Kick
-- =====================================================
local adminTab = tabFrames["Admin"]

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
	if not amount then showStatus("Enter a valid number", false) return end
	adminRemote:FireServer("AddCredits", targetInput.Text, amount)
	flashButton(creditsBtns["Add"], true)
end)

creditsBtns["Set"].MouseButton1Click:Connect(function()
	local amount = tonumber(creditsInput.Text)
	if not amount then showStatus("Enter a valid number", false) return end
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
	if not amount then showStatus("Enter a valid number", false) return end
	adminRemote:FireServer("SetRebirth", targetInput.Text, amount)
	flashButton(rebirthBtns["Set"], true)
end)

-- Speed
local speedSection = createSection("Speed", adminTab, "Admin")
local speedInput = createInput(speedSection, "Enter multiplier (e.g. 2.5)", 1)
local speedBtn = createButton(speedSection, "Set", COLORS.btnBlue, 2)

speedBtn.MouseButton1Click:Connect(function()
	local mult = tonumber(speedInput.Text)
	if not mult then showStatus("Enter a valid multiplier", false) return end
	adminRemote:FireServer("SetSpeed", targetInput.Text, mult)
	flashButton(speedBtn, true)
end)

-- Kick Player
local kickSection = createSection("Kick Player", adminTab, "Admin")
local kickReasonInput = createInput(kickSection, "Reason (optional)", 1)
local kickBtn = createButton(kickSection, "Kick", COLORS.btnRed, 2)

kickBtn.MouseButton1Click:Connect(function()
	local target = targetInput.Text
	if #target == 0 then showStatus("Enter a player name in the Target field", false) return end
	adminRemote:FireServer("KickPlayer", target, kickReasonInput.Text)
	flashButton(kickBtn, true)
end)

-- =====================================================
-- CODES MANAGEMENT (in Admin tab)
-- =====================================================
local codesSection = createSection("Redeem Codes", adminTab, "Admin")

local codeNameInput = createInput(codesSection, "Code name", 1)
local codeRewardTypeInput = createInput(codesSection, "Reward type (credits/luck)", 2)
local codeAmountInput = createInput(codesSection, "Amount", 3)
local codeMaxUsesInput = createInput(codesSection, "Max uses (0 = unlimited)", 4)

local codeBtns = createButtonRow(codesSection, {
	{ text = "Create Code", color = COLORS.btnGreen },
	{ text = "Delete Code", color = COLORS.btnRed },
	{ text = "List Codes", color = COLORS.btnBlue },
}, 5)

codeBtns["Create Code"].MouseButton1Click:Connect(function()
	local name = codeNameInput.Text
	if #name == 0 then showStatus("Enter a code name", false) return end
	local rewardType = codeRewardTypeInput.Text
	if #rewardType == 0 then rewardType = "credits" end
	local amount = tonumber(codeAmountInput.Text)
	if not amount then showStatus("Enter a valid amount", false) return end
	local maxUses = tonumber(codeMaxUsesInput.Text) or 0
	adminRemote:FireServer("CreateCode", name, rewardType, amount, maxUses)
	flashButton(codeBtns["Create Code"], true)
end)

codeBtns["Delete Code"].MouseButton1Click:Connect(function()
	local name = codeNameInput.Text
	if #name == 0 then showStatus("Enter a code name to delete", false) return end
	adminRemote:FireServer("DeleteCode", name)
	flashButton(codeBtns["Delete Code"], true)
end)

-- Code list display
local codeListFrame = Instance.new("Frame")
codeListFrame.Size = UDim2.new(1, 0, 0, 0)
codeListFrame.AutomaticSize = Enum.AutomaticSize.Y
codeListFrame.BackgroundTransparency = 1
codeListFrame.LayoutOrder = 6
codeListFrame.Parent = codesSection

local codeListLayout = Instance.new("UIListLayout")
codeListLayout.Padding = UDim.new(0, 4)
codeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
codeListLayout.Parent = codeListFrame

local listCodesFunc = ReplicatedStorage:WaitForChild("ListCodes", 10)

codeBtns["List Codes"].MouseButton1Click:Connect(function()
	-- Clear existing list
	for _, child in ipairs(codeListFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	if not listCodesFunc then
		showStatus("ListCodes remote not found", false)
		return
	end

	flashButton(codeBtns["List Codes"], true)
	showStatus("Fetching codes...", true)

	local ok, list = pcall(function()
		return listCodesFunc:InvokeServer()
	end)

	if not ok or not list or type(list) ~= "table" then
		showStatus("Failed to fetch codes", false)
		return
	end

	if #list == 0 then
		local emptyLbl = Instance.new("TextLabel")
		emptyLbl.Size = UDim2.new(1, 0, 0, 24)
		emptyLbl.BackgroundColor3 = COLORS.rowEven
		emptyLbl.Text = "  No codes found"
		emptyLbl.TextColor3 = COLORS.dimText
		emptyLbl.TextSize = 11
		emptyLbl.Font = Enum.Font.Gotham
		emptyLbl.TextXAlignment = Enum.TextXAlignment.Left
		emptyLbl.LayoutOrder = 1
		emptyLbl.Parent = codeListFrame
		Instance.new("UICorner", emptyLbl).CornerRadius = UDim.new(0, 4)
		showStatus("No codes found", true)
		return
	end

	for i, entry in ipairs(list) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundColor3 = (i % 2 == 0) and COLORS.rowEven or COLORS.rowOdd
		row.LayoutOrder = i
		row.Parent = codeListFrame
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -8, 1, 0)
		lbl.Position = UDim2.new(0, 6, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = entry.name .. " | " .. entry.rewardType .. " x" .. tostring(entry.amount) .. " | Uses: " .. tostring(entry.usedCount) .. "/" .. (entry.maxUses > 0 and tostring(entry.maxUses) or "Unlimited") .. " | By: " .. entry.createdBy
		lbl.TextColor3 = COLORS.text
		lbl.TextSize = 10
		lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Parent = row
	end

	showStatus("Found " .. #list .. " codes", true)
end)

-- =====================================================
-- TAB 4: BANNED - banned players with unban functionality
-- =====================================================
local bannedTab = tabFrames["Banned"]
local getBanListFunc = ReplicatedStorage:WaitForChild("GetBanList", 10)
local bannedRows = {}

-- Ban from Members tab (add ban button to kick section)
local banSection = createSection("Ban Player", bannedTab, "Banned")
local banReasonInput = createInput(banSection, "Reason for ban", 1)

-- Info text
local banInfoLabel = Instance.new("TextLabel")
banInfoLabel.Size = UDim2.new(1, 0, 0, 20)
banInfoLabel.BackgroundTransparency = 1
banInfoLabel.Text = "Select a player in Members tab first, then ban here"
banInfoLabel.TextColor3 = COLORS.dimText
banInfoLabel.TextSize = 11
banInfoLabel.Font = Enum.Font.Gotham
banInfoLabel.TextWrapped = true
banInfoLabel.LayoutOrder = 2
banInfoLabel.Parent = banSection

local banBtn = createButton(banSection, "Ban Selected Player", COLORS.btnRed, 3)
banBtn.MouseButton1Click:Connect(function()
	local target = targetInput.Text
	if #target == 0 then showStatus("Select a player first (Members -> click name)", false) return end
	local reason = banReasonInput.Text
	if #reason == 0 then reason = "No reason given" end
	adminRemote:FireServer("BanPlayer", target, reason)
	flashButton(banBtn, true)
	-- Refresh the list after a short delay
	task.delay(1, function() refreshBanList() end)
end)

-- Banned players header
local bannedHeader = Instance.new("Frame")
bannedHeader.Size = UDim2.new(1, 0, 0, 28)
bannedHeader.BackgroundColor3 = COLORS.btnRed
bannedHeader.LayoutOrder = nextOrder("Banned")
bannedHeader.Parent = bannedTab
local bhCorner = Instance.new("UICorner")
bhCorner.CornerRadius = UDim.new(0, 6)
bhCorner.Parent = bannedHeader

local banCols = { { "Player", 0.25 }, { "Reason", 0.30 }, { "Banned By", 0.20 }, { "Date", 0.15 }, { "", 0.10 } }
local bxOff = 0
for _, col in ipairs(banCols) do
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(col[2], 0, 1, 0)
	lbl.Position = UDim2.new(bxOff, 4, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = col[1]
	lbl.TextColor3 = COLORS.text
	lbl.TextSize = 11
	lbl.Font = Enum.Font.GothamBold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = bannedHeader
	bxOff = bxOff + col[2]
end

local banListOrder = nextOrder("Banned")

local function clearBanRows()
	for _, row in ipairs(bannedRows) do
		row:Destroy()
	end
	bannedRows = {}
end

refreshBanList = function()
	clearBanRows()
	if not getBanListFunc then return end

	local ok, list = pcall(function()
		return getBanListFunc:InvokeServer()
	end)
	if not ok or not list or type(list) ~= "table" then return end

	if #list == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 0, 30)
		emptyLabel.BackgroundColor3 = COLORS.section
		emptyLabel.Text = "  No banned players"
		emptyLabel.TextColor3 = COLORS.dimText
		emptyLabel.TextSize = 12
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
		emptyLabel.LayoutOrder = banListOrder
		emptyLabel.Parent = bannedTab
		local ec = Instance.new("UICorner")
		ec.CornerRadius = UDim.new(0, 4)
		ec.Parent = emptyLabel
		table.insert(bannedRows, emptyLabel)
		return
	end

	for i, entry in ipairs(list) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = (i % 2 == 0) and COLORS.rowEven or COLORS.rowOdd
		row.LayoutOrder = banListOrder + i
		row.Parent = bannedTab
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 4)
		rc.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.25, 0, 1, 0)
		nameLbl.Position = UDim2.new(0, 6, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = entry.name or "?"
		nameLbl.TextColor3 = COLORS.text
		nameLbl.TextSize = 11
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = row

		local reasonLbl = Instance.new("TextLabel")
		reasonLbl.Size = UDim2.new(0.30, 0, 1, 0)
		reasonLbl.Position = UDim2.new(0.25, 4, 0, 0)
		reasonLbl.BackgroundTransparency = 1
		reasonLbl.Text = entry.reason or ""
		reasonLbl.TextColor3 = COLORS.dimText
		reasonLbl.TextSize = 11
		reasonLbl.Font = Enum.Font.Gotham
		reasonLbl.TextXAlignment = Enum.TextXAlignment.Left
		reasonLbl.TextTruncate = Enum.TextTruncate.AtEnd
		reasonLbl.Parent = row

		local byLbl = Instance.new("TextLabel")
		byLbl.Size = UDim2.new(0.20, 0, 1, 0)
		byLbl.Position = UDim2.new(0.55, 4, 0, 0)
		byLbl.BackgroundTransparency = 1
		byLbl.Text = entry.bannedBy or "?"
		byLbl.TextColor3 = COLORS.dimText
		byLbl.TextSize = 11
		byLbl.Font = Enum.Font.Gotham
		byLbl.TextXAlignment = Enum.TextXAlignment.Left
		byLbl.Parent = row

		local dateLbl = Instance.new("TextLabel")
		dateLbl.Size = UDim2.new(0.15, 0, 1, 0)
		dateLbl.Position = UDim2.new(0.75, 4, 0, 0)
		dateLbl.BackgroundTransparency = 1
		dateLbl.Text = entry.timestamp and os.date("%m/%d", entry.timestamp) or "?"
		dateLbl.TextColor3 = COLORS.dimText
		dateLbl.TextSize = 11
		dateLbl.Font = Enum.Font.Gotham
		dateLbl.TextXAlignment = Enum.TextXAlignment.Left
		dateLbl.Parent = row

		local unbanBtn = Instance.new("TextButton")
		unbanBtn.Size = UDim2.new(0.09, -2, 0, 22)
		unbanBtn.Position = UDim2.new(0.90, 2, 0.5, -11)
		unbanBtn.BackgroundColor3 = COLORS.btnGreen
		unbanBtn.Text = "Unban"
		unbanBtn.TextColor3 = COLORS.text
		unbanBtn.TextSize = 10
		unbanBtn.Font = Enum.Font.GothamBold
		unbanBtn.Parent = row
		local uc = Instance.new("UICorner")
		uc.CornerRadius = UDim.new(0, 4)
		uc.Parent = unbanBtn

		unbanBtn.MouseButton1Click:Connect(function()
			adminRemote:FireServer("UnbanPlayer", tostring(entry.userId))
			flashButton(unbanBtn, true)
			task.delay(0.5, function() refreshBanList() end)
		end)

		table.insert(bannedRows, row)
	end
end

-- Refresh ban list when switching to Banned tab
-- (handled in switchTab below)

-- =====================================================
-- TAB 5: LOGS - admin action log
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

togglePanel = function()
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

-- adminBtn click is connected in the task.spawn above
closeBtn.MouseButton1Click:Connect(function()
	if panelOpen then togglePanel() end
end)

-- =====================
-- UNDO SYSTEM
-- =====================
local lastUndoData = nil -- { undoCmd = "...", undoArgs = {...}, desc = "..." }

-- Undo button (next to the status bar, at the bottom)
local undoBtn = Instance.new("TextButton")
undoBtn.Name = "UndoButton"
undoBtn.Size = UDim2.new(0, 80, 0, 24)
undoBtn.Position = UDim2.new(1, -88, 1, -28)
undoBtn.BackgroundColor3 = Color3.fromRGB(220, 160, 40)
undoBtn.Text = "↩ Undo"
undoBtn.TextColor3 = COLORS.textDark
undoBtn.TextSize = 12
undoBtn.Font = Enum.Font.GothamBold
undoBtn.Visible = false
undoBtn.Parent = panelFrame
local undoCorner = Instance.new("UICorner")
undoCorner.CornerRadius = UDim.new(0, 6)
undoCorner.Parent = undoBtn

-- Adjust the status bar so it doesn't overlap the undo button
statusLabel.Size = UDim2.new(1, -108, 0, 24)

undoBtn.MouseButton1Click:Connect(function()
	if not lastUndoData then return end
	local data = lastUndoData
	lastUndoData = nil
	undoBtn.Visible = false
	showStatus("Undoing: " .. (data.desc or "..."), true)
	if type(data.undoArgs) == "table" then
		adminRemote:FireServer(data.undoCmd, unpack(data.undoArgs))
	else
		adminRemote:FireServer(data.undoCmd)
	end
end)

-- =====================
-- RESPONSE FROM SERVER
-- =====================
adminResponse.OnClientEvent:Connect(function(success, message, undoData)
	showStatus(message or (success and "OK" or "Error"), success)
	addLogEntry(message or (success and "OK" or "Error"), not success)

	-- Show undo button if the server sent undo data
	if success and undoData and type(undoData) == "table" and undoData.undoCmd then
		lastUndoData = undoData
		undoBtn.Visible = true
		-- Auto-hide undo after 30 seconds
		local currentData = undoData
		task.delay(30, function()
			if lastUndoData == currentData then
				lastUndoData = nil
				undoBtn.Visible = false
			end
		end)
	else
		-- Non-undoable action (kick, etc.) - keep any existing undo
	end
end)

-- Start on Members tab
switchTab("Members")

print("[AdminClient] Admin panel with tabs loaded for", player.Name)
