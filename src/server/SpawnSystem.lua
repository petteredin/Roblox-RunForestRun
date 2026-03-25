-- =============================================
-- SpawnSystem.lua (ModuleScript)
-- Handles brainrot spawning, despawning, rarity
-- rolling, mutation rolling, and the billboard
-- prompt UI for each spawned brainrot.
-- =============================================

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpawnSystem = {}

-- Injected dependencies (set by init)
local ZONES
local RARITIES
local BRAINROTS
local RARITY_COLORS
local RARITY_LABEL_COLORS
local MUTATIONS
local TAG_SPAWNED_BRAINROT
local DESPAWN_TIME
local spawnFolders
local carriedBrainrots
local spawnNotifyEvent
local getMutation
local debugWarn

-- Injected from orchestrator (uses counter-based tracking with self-healing)
local getZoneActiveCount

-- =====================
-- HELPER: pick a rarity from allowed list, weighted by luck
-- =====================
local function pickRarity(allowedRarities, serverLuckMult, serverLuckEndTime)
	local currentLuckMult = 1
	if serverLuckMult > 1 and serverLuckEndTime > os.time() then
		currentLuckMult = serverLuckMult
	end

	local totalWeight = 0
	local weights = {}
	for _, r in ipairs(allowedRarities) do
		local w = RARITIES[r].spawnWeight
		if currentLuckMult > 1 and w < 10 then
			w = w * currentLuckMult
		end
		weights[r] = w
		totalWeight = totalWeight + w
	end
	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, r in ipairs(allowedRarities) do
		cumulative = cumulative + weights[r]
		if roll <= cumulative then return r end
	end
	return allowedRarities[#allowedRarities]
end

-- =====================
-- HELPER: pick a random brainrot def from a rarity pool
-- =====================
local function pickBrainrotFromRarity(rarity)
	local pool = {}
	for _, b in ipairs(BRAINROTS) do
		if b.rarity == rarity then table.insert(pool, b) end
	end
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

-- =====================
-- HELPER: random position within a zone
-- =====================
local function getRandomPositionInZone(zone)
	local half = zone.size / 2
	local x = zone.position.X + math.random() * zone.size.X - half.X
	local z = zone.position.Z + math.random() * zone.size.Z - half.Z
	return Vector3.new(x, zone.position.Y + 2, z)
end

-- =====================
-- CREATE BILLBOARD PROMPT
-- =====================
local function createPrompt(brainrot, brainrotDef, _player, mutation)
	mutation = mutation or MUTATIONS.NONE

	local rarity = brainrotDef and brainrotDef.rarity or "COMMON"
	local rarityColor = RARITY_LABEL_COLORS[rarity] or Color3.fromRGB(255, 255, 255)

	local attachTo = brainrot
	if brainrot:IsA("Model") then
		attachTo = brainrot.PrimaryPart or brainrot:FindFirstChildWhichIsA("BasePart")
	end
	if not attachTo then return end

	local earnRate = brainrot:GetAttribute("EarnRate") or 0
	local creditsPerSec = string.format("%.1f credits/sec", earnRate)

	local billboard = Instance.new("BillboardGui")
	billboard.Name        = "PickupPrompt"
	billboard.Size        = UDim2.new(0, 80, 0, 62)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance  = 40
	billboard.Enabled     = true
	billboard.Parent      = attachTo

	-- Mutation badge (colored bar on top)
	local mutBadge = Instance.new("Frame")
	mutBadge.Name                   = "MutationBadge"
	mutBadge.Size                   = UDim2.new(1, 0, 0.16, 0)
	mutBadge.Position               = UDim2.new(0, 0, 0, 0)
	mutBadge.BackgroundColor3       = mutation.color
	mutBadge.BackgroundTransparency = 0.15
	mutBadge.BorderSizePixel        = 0
	mutBadge.Parent                 = billboard
	Instance.new("UICorner", mutBadge).CornerRadius = UDim.new(0, 5)

	local mutLabel = Instance.new("TextLabel")
	mutLabel.Size                   = UDim2.new(1, -4, 1, 0)
	mutLabel.Position               = UDim2.new(0, 2, 0, 0)
	mutLabel.BackgroundTransparency = 1
	mutLabel.Text                   = mutation.label
	mutLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	mutLabel.TextScaled             = true
	mutLabel.Font                   = Enum.Font.GothamBold
	mutLabel.Parent                 = mutBadge

	-- Main info box (Name, Rarity, Credits/sec)
	local nameTag = Instance.new("Frame")
	nameTag.Name                   = "NameTag"
	nameTag.Size                   = UDim2.new(1, 0, 0.52, 0)
	nameTag.Position               = UDim2.new(0, 0, 0.17, 0)
	nameTag.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
	nameTag.BackgroundTransparency = 0.25
	nameTag.BorderSizePixel        = 0
	nameTag.Parent                 = billboard
	Instance.new("UICorner", nameTag).CornerRadius = UDim.new(0, 5)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size                   = UDim2.new(1, -4, 0.36, 0)
	nameLabel.Position               = UDim2.new(0, 2, 0, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                   = (brainrotDef and brainrotDef.icon or "") .. " " .. (brainrotDef and brainrotDef.name or "Brainrot")
	nameLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled             = true
	nameLabel.Font                   = Enum.Font.GothamBold
	nameLabel.Parent                 = nameTag

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size                   = UDim2.new(1, -4, 0.30, 0)
	rarityLabel.Position               = UDim2.new(0, 2, 0.36, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text                   = rarity
	rarityLabel.TextColor3             = rarityColor
	rarityLabel.TextScaled             = true
	rarityLabel.Font                   = Enum.Font.GothamBold
	rarityLabel.Parent                 = nameTag

	local creditsLabel = Instance.new("TextLabel")
	creditsLabel.Size                   = UDim2.new(1, -4, 0.30, 0)
	creditsLabel.Position               = UDim2.new(0, 2, 0.68, 0)
	creditsLabel.BackgroundTransparency = 1
	creditsLabel.Text                   = creditsPerSec
	creditsLabel.TextColor3             = Color3.fromRGB(255, 220, 80)
	creditsLabel.TextScaled             = true
	creditsLabel.Font                   = Enum.Font.GothamBold
	creditsLabel.Parent                 = nameTag

	-- [E] pickup indicator
	local eFrame = Instance.new("Frame")
	eFrame.Name                   = "EFrame"
	eFrame.Size                   = UDim2.new(0.26, 0, 0.22, 0)
	eFrame.AnchorPoint            = Vector2.new(0.5, 1)
	eFrame.Position               = UDim2.new(0.5, 0, 1, -1)
	eFrame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	eFrame.BackgroundTransparency = 0.4
	eFrame.BorderSizePixel        = 0
	eFrame.Parent                 = billboard
	Instance.new("UICorner", eFrame).CornerRadius = UDim.new(1, 0)

	local eLabel = Instance.new("TextLabel")
	eLabel.Size                   = UDim2.new(1, 0, 1, 0)
	eLabel.BackgroundTransparency = 1
	eLabel.Text                   = "E"
	eLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	eLabel.TextScaled             = true
	eLabel.Font                   = Enum.Font.GothamBold
	eLabel.Parent                 = eFrame

	return billboard
end

-- =====================
-- INSTANTIATE a brainrot model at a position
-- =====================
local function instantiateBrainrot(brainrotDef, rarity, spawnPos, parentFolder)
	local brainrot
	if brainrotDef.modelName or brainrotDef.name then
		local template = ReplicatedStorage:FindFirstChild(brainrotDef.modelName or brainrotDef.name)
		if template then
			brainrot = template:Clone()
			if brainrot:IsA("Model") then
				if not brainrot.PrimaryPart then
					local firstPart = brainrot:FindFirstChildWhichIsA("BasePart")
					if firstPart then brainrot.PrimaryPart = firstPart end
				end
				brainrot:PivotTo(CFrame.new(spawnPos))
				for _, part in ipairs(brainrot:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored   = true
						part.CanCollide = false
					end
				end
			else
				brainrot.Position   = spawnPos
				brainrot.Anchored   = true
				brainrot.CanCollide = false
			end
			brainrot.Parent = parentFolder
		end
	end

	-- Fallback: no model found, create a generic neon block
	if not brainrot then
		brainrot = Instance.new("Part")
		brainrot.Name       = "Brainrot"
		brainrot.Size       = Vector3.new(2, 2, 2)
		brainrot.Position   = spawnPos
		brainrot.BrickColor = RARITY_COLORS[rarity]
		brainrot.Material   = Enum.Material.Neon
		brainrot.Anchored   = true
		brainrot.CanCollide = false
		brainrot.Parent     = parentFolder
	end

	return brainrot
end

-- =====================
-- SET ATTRIBUTES on a brainrot (Model or BasePart)
-- =====================
local function setAttributes(brainrot, earnRate, rarity, name, mutationKey)
	if brainrot:IsA("Model") then
		brainrot:SetAttribute("EarnRate", earnRate)
		brainrot:SetAttribute("Rarity", rarity)
		brainrot:SetAttribute("BrainrotName", name)
		brainrot:SetAttribute("Mutation", mutationKey)
		if brainrot.PrimaryPart then
			brainrot.PrimaryPart:SetAttribute("EarnRate", earnRate)
			brainrot.PrimaryPart:SetAttribute("Rarity", rarity)
			brainrot.PrimaryPart:SetAttribute("BrainrotName", name)
			brainrot.PrimaryPart:SetAttribute("Mutation", mutationKey)
		end
	else
		brainrot:SetAttribute("EarnRate", earnRate)
		brainrot:SetAttribute("Rarity", rarity)
		brainrot:SetAttribute("BrainrotName", name)
		brainrot:SetAttribute("Mutation", mutationKey)
	end
end

-- =====================
-- DESPAWN TIMER
-- =====================
local function scheduleDespawn(brainrot)
	task.delay(DESPAWN_TIME, function()
		if not (brainrot and brainrot.Parent and CollectionService:HasTag(brainrot, TAG_SPAWNED_BRAINROT)) then
			return
		end
		for _, carried in pairs(carriedBrainrots) do
			if carried == brainrot then return end
		end
		task.wait(0.5)
		if brainrot and brainrot.Parent and CollectionService:HasTag(brainrot, TAG_SPAWNED_BRAINROT) then
			for _, carried in pairs(carriedBrainrots) do
				if carried == brainrot then return end
			end
			if debugWarn then debugWarn("[DESPAWN] Destroying", brainrot.Name, "parent:", brainrot.Parent.Name) end
			CollectionService:RemoveTag(brainrot, TAG_SPAWNED_BRAINROT)
			brainrot:Destroy()
		end
	end)
end

-- =====================
-- SPAWN A BRAINROT IN A ZONE (natural spawn loop)
-- =====================
function SpawnSystem.spawnBrainrotInZone(zoneIndex, serverLuckMult, serverLuckEndTime)
	local zone = ZONES[zoneIndex]
	if getZoneActiveCount(zoneIndex) >= zone.cap then return end

	local rarity = pickRarity(zone.rarities, serverLuckMult, serverLuckEndTime)
	local brainrotDef = pickBrainrotFromRarity(rarity)
	if not brainrotDef then return end

	local spawnPos = getRandomPositionInZone(zone)
	local parentFolder = spawnFolders[zoneIndex]
	local brainrot = instantiateBrainrot(brainrotDef, rarity, spawnPos, parentFolder)

	local mutation, mutationKey = getMutation(nil)
	local mutationMult = mutation.mult or 1
	local earnRate = brainrotDef.baseEarn * RARITIES[rarity].mult * mutationMult

	setAttributes(brainrot, earnRate, rarity, brainrotDef.name, mutationKey)
	CollectionService:AddTag(brainrot, TAG_SPAWNED_BRAINROT)
	createPrompt(brainrot, brainrotDef, nil, mutation)

	local spawnName = brainrotDef.name or "Brainrot"
	spawnNotifyEvent:FireAllClients(spawnName, rarity, zoneIndex, mutationKey)

	scheduleDespawn(brainrot)
end

-- =====================
-- ADMIN SPAWN: spawn a specific brainrot by name
-- =====================
function SpawnSystem.adminSpawnBrainrot(brainrotName, forcedMutationKey)
	if type(brainrotName) ~= "string" or #brainrotName == 0 then
		return false, "Invalid brainrot name"
	end

	local brainrotDef = nil
	for _, b in ipairs(BRAINROTS) do
		if b.name:lower() == brainrotName:lower() then
			brainrotDef = b
			break
		end
	end
	if not brainrotDef then
		return false, "Brainrot '" .. brainrotName .. "' not found"
	end

	-- Find a zone that allows this rarity and has capacity
	local targetZone = nil
	for i, zone in ipairs(ZONES) do
		for _, r in ipairs(zone.rarities) do
			if r == brainrotDef.rarity and getZoneActiveCount(i) < zone.cap then
				targetZone = i
				break
			end
		end
		if targetZone then break end
	end
	if not targetZone then targetZone = 1 end

	local zone = ZONES[targetZone]
	local rarity = brainrotDef.rarity
	local spawnPos = getRandomPositionInZone(zone)
	local parentFolder = spawnFolders[targetZone]
	local brainrot = instantiateBrainrot(brainrotDef, rarity, spawnPos, parentFolder)

	local mutation, mutationKey
	if forcedMutationKey and forcedMutationKey ~= "" and MUTATIONS[forcedMutationKey] then
		mutation = MUTATIONS[forcedMutationKey]
		mutationKey = forcedMutationKey
	else
		mutation, mutationKey = getMutation(nil)
	end

	local mutationMult = mutation.mult or 1
	local earnRate = brainrotDef.baseEarn * RARITIES[rarity].mult * mutationMult

	setAttributes(brainrot, earnRate, rarity, brainrotDef.name, mutationKey)
	CollectionService:AddTag(brainrot, TAG_SPAWNED_BRAINROT)
	createPrompt(brainrot, brainrotDef, nil, mutation)

	spawnNotifyEvent:FireAllClients(brainrotDef.name, rarity, targetZone, mutationKey)
	scheduleDespawn(brainrot)

	return true, nil, targetZone
end

-- =====================
-- EXPOSED HELPERS (used by other systems)
-- =====================
SpawnSystem.createPrompt = createPrompt

-- =====================
-- INIT: receive dependencies from orchestrator
-- =====================
function SpawnSystem.init(deps)
	ZONES                = deps.ZONES
	RARITIES             = deps.RARITIES
	BRAINROTS            = deps.BRAINROTS
	RARITY_COLORS        = deps.RARITY_COLORS
	RARITY_LABEL_COLORS  = deps.RARITY_LABEL_COLORS
	MUTATIONS            = deps.MUTATIONS
	TAG_SPAWNED_BRAINROT = deps.TAG_SPAWNED_BRAINROT
	DESPAWN_TIME         = deps.DESPAWN_TIME
	spawnFolders         = deps.spawnFolders
	carriedBrainrots     = deps.carriedBrainrots
	spawnNotifyEvent     = deps.spawnNotifyEvent
	getMutation          = deps.getMutation
	debugWarn            = deps.debugWarn
	getZoneActiveCount   = deps.getZoneActiveCount
end

-- =====================
-- START SPAWN LOOPS
-- =====================
function SpawnSystem.startSpawnLoops(serverLuckMultFn, serverLuckEndTimeFn)
	for zoneIndex, zone in ipairs(ZONES) do
		for _, rarity in ipairs(zone.rarities) do
			local interval = RARITIES[rarity].spawnInterval
			task.spawn(function()
				while true do
					task.wait(interval)
					if getZoneActiveCount(zoneIndex) < zone.cap then
						SpawnSystem.spawnBrainrotInZone(zoneIndex, serverLuckMultFn(), serverLuckEndTimeFn())
					end
				end
			end)
		end
	end
end

return SpawnSystem
