-- StorePanel.lua
-- ModuleScript: Store panel UI (V.I.P, Server Luck, Codes tabs)
-- Extracted from BrainrotPlayerScripts.client.lua

local MarketplaceService = game:GetService("MarketplaceService")

local StorePanel = {}

function StorePanel.init(player, config)
	local GameConfig = config.GameConfig
	local luckDisplayLabel = config.luckDisplayLabel
	local luckFrame = config.luckFrame
	local bottomGui = config.bottomGui
	local RunService = config.RunService

	local GAMEPASS_IDS = GameConfig.GAMEPASS_IDS
	local LUCK_PRODUCT_IDS = GameConfig.LUCK_PRODUCTS

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
	local storeTabNames = { "Gamepasses", "Server Luck", "Codes" }
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
		tabBtn.Position = UDim2.new(0, 140 + (i - 1) * 118, 0, 8)
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

	storeTabFrames["Gamepasses"] = gamepassFrame

	-- Gamepass card builder
	local cachedGamepassStatus = {}

	-- Fetch real gamepass info from Roblox (title, description, icon)
	local function fetchGamepassInfo(passId)
		if passId == 0 then return nil end
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
		end)
		if ok and info then
			return {
				name = info.Name or "",
				description = info.Description or "",
				iconImageAssetId = info.IconImageAssetId or 0,
				priceInRobux = info.PriceInRobux or 0,
			}
		end
		return nil
	end

	local function createGamepassCard(info)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(info.fullWidth and 1 or 0.485, 0, 0, 120)
		card.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
		card.BorderSizePixel = 0
		card.LayoutOrder = info.order or 1
		card.ZIndex = 53
		card.Parent = info.parentFrame or gamepassFrame
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

		-- Title
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Name = "TitleLabel"
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
		descLbl.Name = "DescLabel"
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

		-- Icon: use ImageLabel if we have an asset ID, otherwise TextLabel fallback
		if info.iconImageId and info.iconImageId > 0 then
			local iconImg = Instance.new("ImageLabel")
			iconImg.Name = "IconImage"
			iconImg.Size = UDim2.new(0, 80, 0, 80)
			iconImg.AnchorPoint = Vector2.new(1, 0)
			iconImg.Position = UDim2.new(1, -10, 0, 5)
			iconImg.BackgroundTransparency = 1
			iconImg.Image = "rbxassetid://" .. tostring(info.iconImageId)
			iconImg.ScaleType = Enum.ScaleType.Fit
			iconImg.ZIndex = 54
			iconImg.Parent = card
		else
			local iconLbl = Instance.new("TextLabel")
			iconLbl.Size = UDim2.new(0, 80, 0, 60)
			iconLbl.AnchorPoint = Vector2.new(1, 0)
			iconLbl.Position = UDim2.new(1, -10, 0, 10)
			iconLbl.BackgroundTransparency = 1
			iconLbl.Text = info.icon or ""
			iconLbl.TextColor3 = Color3.fromRGB(200, 255, 200)
			iconLbl.TextScaled = true
			iconLbl.Font = Enum.Font.GothamBold
			iconLbl.ZIndex = 54
			iconLbl.Parent = card
		end

		-- Price badge
		local priceBadge = Instance.new("Frame")
		priceBadge.Size = UDim2.new(0, 100, 0, 30)
		priceBadge.AnchorPoint = Vector2.new(1, 1)
		priceBadge.Position = UDim2.new(1, -10, 1, -10)
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
				-- PromptGamePassPurchase silently fails in Studio and for
				-- game owners (you already own everything as the creator).
				if RunService:IsStudio() then
					warn("[Store] GamePass purchases don't work in Studio. PassId:", info.gpId, "Key:", info.gpKey, "- Test in a live server.")
				end
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, info.gpId)
				end)
			end
		end)

		return card, priceBadge, priceLbl, titleLbl, descLbl
	end

	-- Fetch real VIP pass info from Roblox for title, description, icon
	local vipPassInfo = fetchGamepassInfo(GAMEPASS_IDS.VIP)
	local vipTitle = (vipPassInfo and vipPassInfo.name ~= "") and vipPassInfo.name or "V.I.P PASS"
	local vipDesc  = (vipPassInfo and vipPassInfo.description ~= "") and vipPassInfo.description or "Many benefits\nincluding multi!"
	local vipIcon  = vipPassInfo and vipPassInfo.iconImageAssetId or 0
	local vipPrice = (vipPassInfo and vipPassInfo.priceInRobux > 0) and vipPassInfo.priceInRobux or 150

	-- VIP Pass card (full width, featured at top -- order 1)
	createGamepassCard({
		title = vipTitle,
		desc = vipDesc,
		icon = "\u{2B50}",
		iconImageId = vipIcon,
		price = vipPrice,
		gpId = GAMEPASS_IDS.VIP,
		gpKey = "VIP",
		fullWidth = true,
		order = 1,
	})

	-- Half-width cards in a row (order 2)
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

	-- Admin Panel card (half-width, in row) — fetch real info from Roblox
	local apInfo = fetchGamepassInfo(GAMEPASS_IDS.ADMIN_PANEL)
	local apTitle = (apInfo and apInfo.name ~= "") and apInfo.name or "ADMIN PANEL"
	local apDesc  = (apInfo and apInfo.description ~= "") and apInfo.description or "Grant Server Luck\nand manage your server!"
	local apIcon  = apInfo and apInfo.iconImageAssetId or 0
	local apPrice = (apInfo and apInfo.priceInRobux and apInfo.priceInRobux > 0) and apInfo.priceInRobux or 30000

	createGamepassCard({
		title = apTitle,
		desc = apDesc,
		icon = "AP",
		iconImageId = apIcon,
		price = apPrice,
		gpId = GAMEPASS_IDS.ADMIN_PANEL,
		gpKey = "ADMIN_PANEL",
		fullWidth = false,
		order = 1,
		parentFrame = gpRowFrame,
	})

	-- 2x Money card (half-width, in row) — fetch real info from Roblox
	local dmInfo = fetchGamepassInfo(GAMEPASS_IDS.DOUBLE_MONEY)
	local dmTitle = (dmInfo and dmInfo.name ~= "") and dmInfo.name or "2X MONEY"
	local dmDesc  = (dmInfo and dmInfo.description ~= "") and dmInfo.description or "Earn twice as much\nmoney!"
	local dmIcon  = dmInfo and dmInfo.iconImageAssetId or 0
	local dmPrice = (dmInfo and dmInfo.priceInRobux and dmInfo.priceInRobux > 0) and dmInfo.priceInRobux or 125

	createGamepassCard({
		title = dmTitle,
		desc = dmDesc,
		icon = "x2",
		iconImageId = dmIcon,
		price = dmPrice,
		gpId = GAMEPASS_IDS.DOUBLE_MONEY,
		gpKey = "DOUBLE_MONEY",
		fullWidth = false,
		order = 2,
		parentFrame = gpRowFrame,
	})

	-- ==================
	-- TAB 2: SERVER LUCK
	-- ==================
	local luckTabFrame = Instance.new("ScrollingFrame")
	luckTabFrame.Name = "LuckTab"
	luckTabFrame.Size = UDim2.new(1, 0, 1, 0)
	luckTabFrame.BackgroundTransparency = 1
	luckTabFrame.BorderSizePixel = 0
	luckTabFrame.ScrollBarThickness = 6
	luckTabFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
	luckTabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	luckTabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	luckTabFrame.Visible = false
	luckTabFrame.ZIndex = 52
	luckTabFrame.Parent = storeContent

	storeTabFrames["Server Luck"] = luckTabFrame

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
	luckStatusLabel.Parent = luckTabFrame
	Instance.new("UICorner", luckStatusLabel).CornerRadius = UDim.new(0, 8)

	local luckPadding = Instance.new("UIPadding")
	luckPadding.PaddingTop = UDim.new(0, 6)
	luckPadding.PaddingLeft = UDim.new(0, 4)
	luckPadding.PaddingRight = UDim.new(0, 4)
	luckPadding.Parent = luckTabFrame

	local luckGridFrame = Instance.new("Frame")
	luckGridFrame.Size = UDim2.new(1, 0, 0, 0)
	luckGridFrame.AutomaticSize = Enum.AutomaticSize.Y
	luckGridFrame.BackgroundTransparency = 1
	luckGridFrame.LayoutOrder = 1
	luckGridFrame.ZIndex = 52
	luckGridFrame.Parent = luckTabFrame

	local luckGrid = Instance.new("UIGridLayout")
	luckGrid.CellSize = UDim2.new(0.32, 0, 0, 130)
	luckGrid.CellPadding = UDim2.new(0.01, 0, 0, 10)
	luckGrid.SortOrder = Enum.SortOrder.LayoutOrder
	luckGrid.FillDirection = Enum.FillDirection.Horizontal
	luckGrid.Parent = luckGridFrame

	local luckLayout = Instance.new("UIListLayout")
	luckLayout.Padding = UDim.new(0, 8)
	luckLayout.SortOrder = Enum.SortOrder.LayoutOrder
	luckLayout.Parent = luckTabFrame

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
	switchStoreTab("Gamepasses")

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
					-- Update HUD luck display
					luckDisplayLabel.Text = "\u{1F340} Luck " .. mult .. "x (" .. mins .. "m)"
					luckFrame.BackgroundColor3 = Color3.fromRGB(60, 100, 20)
				else
					luckStatusLabel.Text = "No active luck boost"
					luckStatusLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
					-- Update HUD luck display
					luckDisplayLabel.Text = "\u{1F340} Luck 1x"
					luckFrame.BackgroundColor3 = Color3.fromRGB(40, 50, 20)
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

	-- Connect Store button from bottom bar
	local storeBtn = bottomGui:FindFirstChild("StoreButton")
	if storeBtn and storeBtn:IsA("ImageButton") then
		storeBtn.MouseButton1Click:Connect(function()
			if not storePanelOpen then
				toggleStorePanel()
			end
			switchStoreTab("Gamepasses")
		end)
	end

	-- ==================
	-- PUBLIC API
	-- ==================
	local api = {}

	function api.open(tab)
		if not storePanelOpen then
			toggleStorePanel()
		end
		if tab then
			switchStoreTab(tab)
		end
	end

	function api.close()
		storePanelOpen = false
		storePanel.Visible = false
		storeOverlay.Visible = false
	end

	function api.refresh()
		-- Re-fetch gamepass status
		if getGamepassStatusFunc then
			local ok, status = pcall(function()
				return getGamepassStatusFunc:InvokeServer()
			end)
			if ok and status and type(status) == "table" then
				cachedGamepassStatus = status
			end
		end
		-- Re-fetch server luck status
		if getServerLuckFunc then
			local ok, mult, remaining = pcall(function()
				return getServerLuckFunc:InvokeServer()
			end)
			if ok and mult and mult > 1 and remaining and remaining > 0 then
				local mins = math.ceil(remaining / 60)
				luckStatusLabel.Text = "\u{1F340} Active: " .. mult .. "x Server Luck (" .. mins .. " min remaining)"
				luckStatusLabel.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
				luckDisplayLabel.Text = "\u{1F340} Luck " .. mult .. "x (" .. mins .. "m)"
				luckFrame.BackgroundColor3 = Color3.fromRGB(60, 100, 20)
			else
				luckStatusLabel.Text = "No active luck boost"
				luckStatusLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
				luckDisplayLabel.Text = "\u{1F340} Luck 1x"
				luckFrame.BackgroundColor3 = Color3.fromRGB(40, 50, 20)
			end
		end
	end

	return api
end

return StorePanel
