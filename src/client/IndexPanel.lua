-- =============================================
-- IndexPanel.lua (ModuleScript)
-- Brainrot collection index panel with rarity
-- filtering and mutation badge display.
-- Extracted from BrainrotPlayerScripts.client.lua
-- =============================================

local IndexPanel = {}

function IndexPanel.init(player, config)
	-- config fields:
	--   GameConfig         (shared config module)
	--   getCollectionFunc  (RemoteFunction or nil)
	--   collectionUpdateEvent (RemoteEvent or nil)
	--   bottomGui          (ScreenGui for bottom bar button wiring)

	local GameConfig = config.GameConfig
	local getCollectionFunc = config.getCollectionFunc
	local collectionUpdateEvent = config.collectionUpdateEvent
	local bottomGui = config.bottomGui

	local INDEX_BRAINROTS     = GameConfig.BRAINROTS
	local INDEX_RARITY_COLORS = GameConfig.RARITY_COLORS
	local INDEX_MUTATIONS     = GameConfig.MUTATIONS
	local INDEX_RARITY_ORDER  = GameConfig.RARITY_ORDER

	local localCollection = {}
	local indexPanelOpen = false
	local indexFilter = "ALL"

	-- Main ScreenGui
	local indexGui = Instance.new("ScreenGui")
	indexGui.Name = "IndexPanelGui"
	indexGui.ResetOnSpawn = false
	indexGui.DisplayOrder = 10
	indexGui.Parent = player.PlayerGui

	-- Overlay
	local indexOverlay = Instance.new("Frame")
	indexOverlay.Name = "Overlay"
	indexOverlay.Size = UDim2.new(1, 0, 1, 0)
	indexOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	indexOverlay.BackgroundTransparency = 0.5
	indexOverlay.BorderSizePixel = 0
	indexOverlay.Visible = false
	indexOverlay.ZIndex = 50
	indexOverlay.Parent = indexGui

	-- Main panel
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
	Instance.new("UICorner", indexHeader).CornerRadius = UDim.new(0, 14)

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
	Instance.new("UICorner", indexSidebar).CornerRadius = UDim.new(0, 10)

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

	-- Bottom progress bar
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

	-- =====================
	-- REFRESH GRID
	-- =====================
	local function refreshIndexGrid()
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

					-- Rarity color strip
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

					-- Rarity label
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

		-- Full scan for totals
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

		indexCountLabel.Text = totalCollected .. "/" .. totalEntries

		local normalPct = normalTotal > 0 and (normalCollected / normalTotal) or 0
		progressBarFill.Size = UDim2.new(normalPct, 0, 1, 0)
		local bonusMult = math.floor(normalPct * 100) / 100 * 0.5
		progressLabel.Text = "Collect " .. math.floor(normalPct * 100) .. "% Normal Brainrots for +" .. string.format("%.1f", bonusMult) .. "x Base Multi"

		local rows = math.ceil(layoutOrder / 4)
		indexContent.CanvasSize = UDim2.new(0, 0, 0, rows * 118 + 12)
	end

	-- Sidebar filter connections
	for key, btn in pairs(sidebarFilterButtons) do
		btn.MouseButton1Click:Connect(function()
			indexFilter = key
			for k, b in pairs(sidebarFilterButtons) do
				b.BackgroundColor3 = k == key and Color3.fromRGB(70, 65, 90) or Color3.fromRGB(50, 48, 65)
			end
			refreshIndexGrid()
		end)
	end

	if sidebarFilterButtons["ALL"] then
		sidebarFilterButtons["ALL"].BackgroundColor3 = Color3.fromRGB(70, 65, 90)
	end

	-- Close handlers
	indexCloseBtn.MouseButton1Click:Connect(function()
		indexPanelOpen = false
		indexPanel.Visible = false
		indexOverlay.Visible = false
	end)

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

	-- CollectionUpdate listener
	if collectionUpdateEvent then
		collectionUpdateEvent.OnClientEvent:Connect(function(key)
			localCollection[key] = true
			if indexPanelOpen then
				refreshIndexGrid()
			end
		end)
	end

	-- Wire bottom bar Index button
	if bottomGui then
		local indexBtn = bottomGui:FindFirstChild("IndexButton")
		if indexBtn and indexBtn:IsA("ImageButton") then
			indexBtn.MouseButton1Click:Connect(function()
				indexPanelOpen = not indexPanelOpen
				indexPanel.Visible = indexPanelOpen
				indexOverlay.Visible = indexPanelOpen
				if indexPanelOpen then
					if getCollectionFunc then
						local serverCollection = getCollectionFunc:InvokeServer()
						if serverCollection and type(serverCollection) == "table" then
							localCollection = serverCollection
						end
					end
					refreshIndexGrid()
				end
			end)
		end
	end

	-- Return public API
	return {
		open = function()
			indexPanelOpen = true
			indexPanel.Visible = true
			indexOverlay.Visible = true
			if getCollectionFunc then
				local serverCollection = getCollectionFunc:InvokeServer()
				if serverCollection and type(serverCollection) == "table" then
					localCollection = serverCollection
				end
			end
			refreshIndexGrid()
		end,
		close = function()
			indexPanelOpen = false
			indexPanel.Visible = false
			indexOverlay.Visible = false
		end,
		refresh = function(collection)
			if collection then
				localCollection = collection
			end
			refreshIndexGrid()
		end,
	}
end

return IndexPanel
