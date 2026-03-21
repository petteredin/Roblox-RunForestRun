-- Brainrot Spawn Engine v0.34
-- Blueberry Pie Games
-- Changelog v0.34:
--   - DataStore: Replaced GetAsync+SetAsync with UpdateAsync (race-condition fix)
--   - Organization: Brainrots spawn into dedicated Folders per zone + StoredBrainrots folder
--   - Sell bug fix: Model-based brainrots now tagged with CollectionService for sell detection
--   - Rate limiting: Sell/pickup requests have per-player cooldowns
--   - Mutation system: getMutation() left as stub, dead code clarified
--   - walletLabel scope: N/A (server-side, was client issue)
--   - General: Minor cleanup and comments

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

-- =====================
-- MUTATION SYSTEM (stub - not yet implemented)
-- =====================

local MUTATIONS = {
	NONE    = { label = "None",      color = Color3.fromRGB(180, 180, 180) },
	GOLD    = { label = "Gold",      color = Color3.fromRGB(255, 200, 0)   },
	DIAMOND = { label = "Diamond",   color = Color3.fromRGB(100, 220, 255) },
	RAINBOW = { label = "Rainbow",   color = Color3.fromRGB(255, 100, 200) },
}

-- TODO: Implement mutation rolls based on player gamepasses/rebirths
local function getMutation(_player)
	return MUTATIONS.NONE
end

-- =====================
-- BRAINROT DEFINITIONS
-- =====================

local RARITIES = {
	COMMON    = { mult = 1,   spawnWeight = 60,  spawnInterval = 8   },
	UNCOMMON  = { mult = 2.5, spawnWeight = 25,  spawnInterval = 15  },
	EPIC      = { mult = 7,   spawnWeight = 10,  spawnInterval = 30  },
	LEGENDARY = { mult = 20,  spawnWeight = 4,   spawnInterval = 60  },
	MYTHIC    = { mult = 60,  spawnWeight = 1,   spawnInterval = 120 },
	COSMIC    = { mult = 200, spawnWeight = 0.3, spawnInterval = 240 },
}

local RARITY_LABEL_COLORS = {
	COMMON    = Color3.fromRGB(180, 180, 180),
	UNCOMMON  = Color3.fromRGB(80,  160, 255),
	EPIC      = Color3.fromRGB(180, 100, 255),
	LEGENDARY = Color3.fromRGB(255, 160, 50),
	MYTHIC    = Color3.fromRGB(255, 80,  80),
	COSMIC    = Color3.fromRGB(100, 220, 255),
}

local BRAINROTS = {
	{ name="Tralalero Tralala",         icon="🦈", rarity="COMMON",    baseEarn=10,  modelName="Tralalero Tralala"         },
	{ name="Chimpanzini Bananini",      icon="🐒", rarity="COMMON",    baseEarn=9,   modelName="Chimpanzini Bananini"      },
	{ name="Bobrito Bandito",           icon="🌯", rarity="COMMON",    baseEarn=11,  modelName="Bobrito Bandito"           },
	{ name="Frulli Frulla",             icon="🍓", rarity="COMMON",    baseEarn=8,   modelName="Frulli Frulla"             },
	{ name="Frigo Camelo",              icon="🐪", rarity="COMMON",    baseEarn=12,  modelName="Frigo Camelo"              },
	{ name="Ballerina Cappuccina",      icon="☕", rarity="UNCOMMON",  baseEarn=14,  modelName="Ballerina Cappuccina"      },
	{ name="Lirilì Larilà",            icon="🌵", rarity="UNCOMMON",  baseEarn=16,  modelName="Lirilì Larilà"            },
	{ name="Burbaloni Luliloli",        icon="🫧", rarity="UNCOMMON",  baseEarn=13,  modelName="Burbaloni Luliloli"        },
	{ name="Orangutini Ananasini",      icon="🍍", rarity="UNCOMMON",  baseEarn=15,  modelName="Orangutini Ananasini"      },
	{ name="Pot Hotspot",               icon="📶", rarity="UNCOMMON",  baseEarn=17,  modelName="Pot Hotspot"               },
	{ name="Cappuccino Assassino",      icon="☕", rarity="EPIC",      baseEarn=22,  modelName="Cappuccino Assassino"      },
	{ name="Bombardiro Crocodilo",      icon="🐊", rarity="EPIC",      baseEarn=28,  modelName="Bombardiro Crocodilo"      },
	{ name="Brr Brr Patapim",           icon="🐸", rarity="EPIC",      baseEarn=25,  modelName="Brr Brr Patapim"           },
	{ name="Il Cacto Hipopotamo",       icon="🦛", rarity="EPIC",      baseEarn=20,  modelName="Il Cacto Hipopotamo"       },
	{ name="Espressona Signora",        icon="👵", rarity="EPIC",      baseEarn=23,  modelName="Espressona Signora"        },
	{ name="Trippi Troppi",             icon="🦐", rarity="LEGENDARY", baseEarn=40,  modelName="Trippi Troppi"             },
	{ name="Bombombini Gusini",         icon="🪿", rarity="LEGENDARY", baseEarn=45,  modelName="Bombombini Gusini"         },
	{ name="La Vaca Saturno Saturnita", icon="🐄", rarity="LEGENDARY", baseEarn=50,  modelName="La Vaca Saturno Saturnita" },
	{ name="Glorbo Fruttodrillo",       icon="🐊", rarity="LEGENDARY", baseEarn=42,  modelName="Glorbo Fruttodrillo"       },
	{ name="Rhino Toasterino",          icon="🦏", rarity="LEGENDARY", baseEarn=38,  modelName="Rhino Toasterino"          },
	{ name="Tung Tung Tung Sahur",      icon="🪵", rarity="MYTHIC",    baseEarn=70,  modelName="Tung Tung Tung Sahur"      },
	{ name="Boneca Ambalabu",           icon="🐸", rarity="MYTHIC",    baseEarn=80,  modelName="Boneca Ambalabu"           },
	{ name="Garamararamararaman",       icon="👾", rarity="MYTHIC",    baseEarn=75,  modelName="Garamararamararaman"       },
	{ name="Ta Ta Ta Ta Ta Sahur",      icon="🥁", rarity="MYTHIC",    baseEarn=65,  modelName="Ta Ta Ta Ta Ta Sahur"      },
	{ name="Tric Trac Baraboom",        icon="💥", rarity="MYTHIC",    baseEarn=72,  modelName="Tric Trac Baraboom"        },
	{ name="Girafa Celeste",            icon="🦒", rarity="COSMIC",    baseEarn=120, modelName="Girafa Celeste"            },
	{ name="Trulimero Trulicina",       icon="🌌", rarity="COSMIC",    baseEarn=140, modelName="Trulimero Trulicina"       },
	{ name="Blueberrinni Octopussini",  icon="🐙", rarity="COSMIC",    baseEarn=130, modelName="Blueberrinni Octopussini"  },
	{ name="Graipussi Medussi",         icon="🍇", rarity="COSMIC",    baseEarn=110, modelName="Graipussi Medussi"         },
	{ name="Zibra Zubra Zibralini",     icon="🦓", rarity="COSMIC",    baseEarn=135, modelName="Zibra Zubra Zibralini"     },
}

local RARITY_COLORS = {
	COMMON    = BrickColor.new("Medium stone grey"),
	UNCOMMON  = BrickColor.new("Bright blue"),
	EPIC      = BrickColor.new("Bright violet"),
	LEGENDARY = BrickColor.new("Bright orange"),
	MYTHIC    = BrickColor.new("Bright red"),
	COSMIC    = BrickColor.new("Cyan"),
}

-- =====================
-- SPAWN ZONES
-- =====================

local ZONES = {
	{
		name     = "Zone1",
		position = Vector3.new(-235, 3.5, -4.5),
		size     = Vector3.new(150, 1, 155),
		cap      = 10,
		rarities = { "COMMON", "UNCOMMON" },
	},
	{
		name     = "Zone2",
		position = Vector3.new(-394, 3.5, -4.5),
		size     = Vector3.new(150, 1, 155),
		cap      = 10,
		rarities = { "COMMON", "UNCOMMON", "EPIC", "LEGENDARY" },
	},
	{
		name     = "Zone3",
		position = Vector3.new(-555, 3.5, -4.5),
		size     = Vector3.new(150, 1, 155),
		cap      = 10,
		rarities = { "COMMON", "UNCOMMON", "EPIC", "LEGENDARY", "MYTHIC", "COSMIC" },
	},
}

local zoneActive = { 0, 0, 0 }

-- =====================
-- WORKSPACE FOLDERS (new in v0.34)
-- =====================
-- All spawned and stored brainrots go into dedicated folders
-- instead of cluttering workspace root. This makes iteration
-- on both server and client much cheaper.

local spawnFolders = {}
for i, zone in ipairs(ZONES) do
	local folder = Instance.new("Folder")
	folder.Name = "BrainrotZone_" .. i
	folder.Parent = workspace
	spawnFolders[i] = folder
end

local storedFolder = Instance.new("Folder")
storedFolder.Name = "StoredBrainrots"
storedFolder.Parent = workspace

-- CollectionService tags used for reliable detection
local TAG_SPAWNED_BRAINROT = "SpawnedBrainrot"
local TAG_STORED_BRAINROT  = "StoredBrainrot"

-- =====================
-- BASE LAYOUT
-- =====================

local MAX_PLAYERS = 2
local BASE_SIZE   = Vector3.new(39, 1, 35)

local BASES = {
	{
		position = Vector3.new(2, 4.433, -59.392),
		size     = BASE_SIZE,
		owner    = nil,
	},
	{
		position = Vector3.new(2, 4.433, -13.446),
		size     = BASE_SIZE,
		owner    = nil,
	},
}

-- =====================
-- CONSTANTS
-- =====================

local DESPAWN_TIME                  = 30
local PICKUP_DISTANCE               = 8
local HOLD_TIME                     = 3
local MOVE_TOLERANCE                = 1
local BASE_SLOTS                    = 10
local CREDIT_PLATE_COLLECT_DISTANCE = 4
local MAX_UPGRADE_LEVEL             = 10
local SELL_DISTANCE                 = 5
local SELL_GRACE_PERIOD             = 5  -- seconds after deposit before sell is allowed
local REBIRTH_MULT                  = 2.25
local MAX_REBIRTHS                  = 10

local playerRebirthReq              = {}    -- per-player current rebirth requirements

-- Fixed rebirth requirements per level (same for all players)
local REBIRTH_REQUIREMENTS = {
	[1]  = { cost = 500,    brainrots = { { rarity = "UNCOMMON", count = 3 } } },
	[2]  = { cost = 1125,   brainrots = { { rarity = "UNCOMMON", count = 2 }, { rarity = "EPIC", count = 1 } } },
	[3]  = { cost = 2531,   brainrots = { { rarity = "EPIC", count = 3 } } },
	[4]  = { cost = 5695,   brainrots = { { rarity = "EPIC", count = 2 }, { rarity = "LEGENDARY", count = 1 } } },
	[5]  = { cost = 12814,  brainrots = { { rarity = "LEGENDARY", count = 3 } } },
	[6]  = { cost = 28831,  brainrots = { { rarity = "LEGENDARY", count = 2 }, { rarity = "MYTHIC", count = 1 } } },
	[7]  = { cost = 64870,  brainrots = { { rarity = "MYTHIC", count = 3 } } },
	[8]  = { cost = 145957, brainrots = { { rarity = "MYTHIC", count = 2 }, { rarity = "COSMIC", count = 1 } } },
	[9]  = { cost = 328402, brainrots = { { rarity = "COSMIC", count = 3 } } },
	[10] = { cost = 739000, brainrots = { { rarity = "COSMIC", count = 3 } } },
}

-- Build display names for a rebirth requirement (picks random examples from rarity pool)
local function getRebirthRequirement(rebirthLevel)
	local req = REBIRTH_REQUIREMENTS[rebirthLevel]
	if not req then return nil end

	local names = {}
	for _, group in ipairs(req.brainrots) do
		local pool = {}
		for _, b in ipairs(BRAINROTS) do
			if b.rarity == group.rarity then
				table.insert(pool, b.name)
			end
		end
		for i = 1, group.count do
			if #pool > 0 then
				local idx = math.random(1, #pool)
				table.insert(names, pool[idx])
			end
		end
	end

	return { brainrots = names, cost = req.cost, spec = req.brainrots }
end

-- Build a rarity summary string for display (e.g. "3x UNCOMMON" or "2x EPIC + 1x LEGENDARY")
local function getRebirthRarityText(rebirthLevel)
	local req = REBIRTH_REQUIREMENTS[rebirthLevel]
	if not req then return "" end
	local parts = {}
	for _, group in ipairs(req.brainrots) do
		table.insert(parts, group.count .. "x " .. group.rarity)
	end
	return table.concat(parts, " + ")
end

-- Initialize rebirth requirements for a player
local function initRebirthReq(player)
	local nextLevel = (playerRebirth[player] or 0) + 1
	if nextLevel > MAX_REBIRTHS then
		playerRebirthReq[player] = nil
		return nil
	end
	local req = getRebirthRequirement(nextLevel)
	playerRebirthReq[player] = req
	if req then
		print("[REBIRTH] Req for", player.Name, "level", nextLevel, ":",
			getRebirthRarityText(nextLevel), "| Cost:", req.cost)
	end
	return req
end

-- Rate limiting (seconds between actions)
local SELL_COOLDOWN   = 0.5
local PICKUP_COOLDOWN = 0.5

-- =====================
-- PLAYER STATE
-- =====================

local playerHolding    = {}
local playerHasPickup  = {}
local carriedBrainrots = {}
local playerCredits    = {}
local playerWallet     = {}
local playerSlots      = {}
local slotParts        = {}
local creditPlates     = {}
local slotCredits      = {}
local upgradeSigns     = {}
local slotUpgrades     = {}
local playerSelling    = {}
local playerRebirth    = {}
local playerDepositing = {}
local playerBaseIndex  = {}
local sessionEarnings  = {}
local slotDepositTime  = {}  -- tracks when each slot was last deposited (grace period for sell)

-- Rate limit trackers
local lastSellTime   = {}
local lastPickupTime = {}

-- =====================
-- BASE ASSIGNMENT
-- =====================

local function assignBase(player)
	for i, base in ipairs(BASES) do
		if base.owner == nil then
			base.owner = player
			playerBaseIndex[player] = i
			print(player.Name .. " assigned to base " .. i)
			return i
		end
	end
	return nil
end

local function releaseBase(player)
	local idx = playerBaseIndex[player]
	if idx then
		BASES[idx].owner = nil
		playerBaseIndex[player] = nil
	end
end

local function getPlayerBasePosition(player)
	local idx = playerBaseIndex[player]
	if not idx then return nil end
	return BASES[idx].position
end

-- =====================
-- REMOTES
-- =====================

local remoteEvent   = ReplicatedStorage:WaitForChild("BrainrotPickup")
local progressEvent = ReplicatedStorage:WaitForChild("BrainrotProgress")

local function getOrCreateRemoteFunction(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end

local function getOrCreateRemote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end

local creditEvent        = getOrCreateRemote("CreditUpdate")
local depositEvent       = getOrCreateRemote("BrainrotDeposited")
local collectEvent       = getOrCreateRemote("CreditsCollected")
local upgradeResultEvent = getOrCreateRemote("UpgradeResult")
local sellProgressEvent  = getOrCreateRemote("SellProgress")
local sellResultEvent    = getOrCreateRemote("SellResult")
local sellEvent          = getOrCreateRemote("SellRequested")
local speedUpdateEvent   = getOrCreateRemote("SpeedUpdate")
local rebirthResultEvent = getOrCreateRemote("RebirthResult")
local rebirthInfoEvent   = getOrCreateRemote("RebirthInfo")
local getRebirthInfoFunc = getOrCreateRemoteFunction("GetRebirthInfo")

-- Client can pull rebirth requirements when ready
getRebirthInfoFunc.OnServerInvoke = function(player)
	local req = playerRebirthReq[player]
	if not req then
		req = initRebirthReq(player)
	end
	-- Also update the physical sign billboard
	updateRebirthSign(player)
	if req then
		local nextLvl = (playerRebirth[player] or 0) + 1
		local rarityText = getRebirthRarityText(nextLvl)
		return playerRebirth[player] or 0, req.brainrots, req.cost, rarityText
	else
		return playerRebirth[player] or 0, {}, 0, ""
	end
end

-- =====================
-- REBIRTH MULTIPLIER
-- =====================

local function getEvoMult(player)
	local rebirths = playerRebirth[player] or 0
	return REBIRTH_MULT ^ rebirths
end

-- =====================
-- SPEED ACCELERATOR
-- =====================

local BASE_WALK_SPEED      = 16
local SPEED_INCREMENT      = 1 / 100  -- +1% per second (100s = double speed)
local playerSpeedTime      = {}       -- tracks seconds spent in game
local playerRebirthInfoSent = {}      -- tracks if rebirth info was sent to client

task.spawn(function()
	while true do
		task.wait(1)
		for _, p in ipairs(Players:GetPlayers()) do
			local character = p.Character
			if not character then continue end
			local humanoid = character:FindFirstChildWhichIsA("Humanoid")
			if not humanoid then continue end

			playerSpeedTime[p] = (playerSpeedTime[p] or 0) + 1
			local speedMult = 1 + playerSpeedTime[p] * SPEED_INCREMENT
			local rebirthMult = getEvoMult(p)
			local totalMult = speedMult * rebirthMult
			humanoid.WalkSpeed = BASE_WALK_SPEED * totalMult
			speedUpdateEvent:FireClient(p, totalMult)

			-- Send rebirth info if not yet delivered (piggyback on working speed loop)
			if not playerRebirthInfoSent[p] then
				local req = playerRebirthReq[p]
				if req then
					local nextLvl = (playerRebirth[p] or 0) + 1
					local rarityText = getRebirthRarityText(nextLvl)
					rebirthInfoEvent:FireClient(p, playerRebirth[p] or 0, req.brainrots, req.cost, rarityText)
					playerRebirthInfoSent[p] = true
				end
			end
		end
	end
end)

-- =====================
-- EARN RATE HELPERS
-- =====================

local function getSlotEarnRate(player, slotIndex)
	if not playerSlots[player] or not playerSlots[player][slotIndex] then return 0 end
	local slot     = playerSlots[player][slotIndex]
	local level    = slotUpgrades[player] and slotUpgrades[player][slotIndex] or 0
	local baseRate = slot.earnRate or 1
	return baseRate * (2 ^ level) * getEvoMult(player)
end

local function getUpgradeCost(player, slotIndex)
	return getSlotEarnRate(player, slotIndex) * 20
end

local function getSellPrice(player, slotIndex)
	return getSlotEarnRate(player, slotIndex) * 10
end

-- =====================
-- WEIGHTED RARITY PICKER
-- =====================

local function pickRarity(allowedRarities)
	local totalWeight = 0
	for _, r in ipairs(allowedRarities) do
		totalWeight += RARITIES[r].spawnWeight
	end
	local roll       = math.random() * totalWeight
	local cumulative = 0
	for _, r in ipairs(allowedRarities) do
		cumulative += RARITIES[r].spawnWeight
		if roll <= cumulative then return r end
	end
	return allowedRarities[#allowedRarities]
end

local function pickBrainrotFromRarity(rarity)
	local pool = {}
	for _, b in ipairs(BRAINROTS) do
		if b.rarity == rarity then table.insert(pool, b) end
	end
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

-- =====================
-- UPGRADE SIGN
-- =====================

local function updateUpgradeSign(player, slotIndex)
	if not upgradeSigns[player] then return end
	local sign = upgradeSigns[player][slotIndex]
	if not sign then return end

	local level = slotUpgrades[player] and slotUpgrades[player][slotIndex] or 0
	local slot  = playerSlots[player] and playerSlots[player][slotIndex]

	if not slot then
		sign.part.Transparency = 1
		sign.label.Text = ""
		return
	end

	sign.part.Transparency = 0.3

	if level >= MAX_UPGRADE_LEVEL then
		sign.part.BrickColor = BrickColor.new("Bright green")
		sign.label.Text = "MAX\nLvl " .. level
	else
		local cost = getUpgradeCost(player, slotIndex)
		local rate = getSlotEarnRate(player, slotIndex)
		sign.part.BrickColor = BrickColor.new("Cyan")
		sign.label.Text = "Upgrade\nLvl " .. level .. " -> " .. (level + 1) .. "\n" .. cost .. " | +" .. rate .. "/s"
	end
end

-- =====================
-- SLOT VISUALS
-- =====================

local function createSlotParts(player)
	if slotParts[player] then
		for _, part in ipairs(slotParts[player]) do
			if part and part.Parent then part:Destroy() end
		end
	end
	if creditPlates[player] then
		for _, plate in ipairs(creditPlates[player]) do
			if plate and plate.part and plate.part.Parent then plate.part:Destroy() end
		end
	end
	if upgradeSigns[player] then
		for _, sign in ipairs(upgradeSigns[player]) do
			if sign and sign.part and sign.part.Parent then sign.part:Destroy() end
		end
	end

	local basePos = getPlayerBasePosition(player)
	if not basePos then return end

	local slots  = {}
	local plates = {}
	local signs  = {}

	local cols              = 5
	local rows              = 2
	local slotSize          = 4
	local colSpacing        = 5
	local rowSpacing        = 16
	local creditPlateWidth  = 2.5
	local creditPlateOffset = slotSize / 2 + 0.5 + creditPlateWidth / 2
	local signWidth         = 2
	local signOffset        = slotSize / 2 + 0.5 + signWidth / 2

	local gridWidth = (cols - 1) * colSpacing
	local gridDepth = (rows - 1) * rowSpacing
	local startX    = basePos.X - gridWidth / 2
	local startZ    = basePos.Z - gridDepth / 2
	local y         = basePos.Y + 0.6

	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local slotIndex = row * cols + col + 1
			local slotPos   = Vector3.new(
				startX + col * colSpacing,
				y,
				startZ + row * rowSpacing
			)

			local slotPart = Instance.new("Part")
			slotPart.Name       = "Slot_" .. player.UserId .. "_" .. slotIndex
			slotPart.Size       = Vector3.new(slotSize, 0.2, slotSize)
			slotPart.Position   = slotPos
			slotPart.Anchored   = true
			slotPart.CanCollide = false
			slotPart.BrickColor = BrickColor.new("Medium stone grey")
			slotPart.Material   = Enum.Material.SmoothPlastic
			slotPart.Parent     = workspace

			local slotSurface = Instance.new("SurfaceGui")
			slotSurface.Face          = Enum.NormalId.Top
			slotSurface.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
			slotSurface.PixelsPerStud = 50
			slotSurface.Parent        = slotPart

			local label = Instance.new("TextLabel")
			label.Size                   = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text                   = tostring(slotIndex)
			label.TextColor3             = Color3.fromRGB(255, 255, 255)
			label.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
			label.TextStrokeTransparency = 0
			label.TextScaled             = true
			label.Font                   = Enum.Font.GothamBold
			label.Rotation               = 180
			label.Parent                 = slotSurface

			slots[slotIndex] = slotPart

			-- Credit plate
			local plateZ = row == 0
				and slotPos.Z + creditPlateOffset
				or  slotPos.Z - creditPlateOffset

			local platePart = Instance.new("Part")
			platePart.Name         = "CreditPlate_" .. player.UserId .. "_" .. slotIndex
			platePart.Size         = Vector3.new(slotSize, 0.2, creditPlateWidth)
			platePart.Position     = Vector3.new(slotPos.X, y, plateZ)
			platePart.Anchored     = true
			platePart.CanCollide   = false
			platePart.BrickColor   = BrickColor.new("Bright yellow")
			platePart.Material     = Enum.Material.Neon
			platePart.Transparency = 0.5
			platePart.Parent       = workspace

			local plateSurface = Instance.new("SurfaceGui")
			plateSurface.Face          = Enum.NormalId.Top
			plateSurface.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
			plateSurface.PixelsPerStud = 50
			plateSurface.Enabled       = false  -- hidden until credits > 0
			plateSurface.Parent        = platePart

			local plateLabel = Instance.new("TextLabel")
			plateLabel.Size                   = UDim2.new(1, 0, 1, 0)
			plateLabel.BackgroundTransparency = 1
			plateLabel.Text                   = ""
			plateLabel.TextColor3             = Color3.fromRGB(255, 220, 50)
			plateLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
			plateLabel.TextStrokeTransparency = 0
			plateLabel.TextScaled             = true
			plateLabel.Font                   = Enum.Font.GothamBold
			plateLabel.Rotation               = 180
			plateLabel.Parent                 = plateSurface

			plates[slotIndex] = { part = platePart, label = plateLabel, billboard = plateSurface, credits = 0 }

			-- Upgrade sign
			local signZ = row == 0
				and slotPos.Z - signOffset
				or  slotPos.Z + signOffset

			local signPart = Instance.new("Part")
			signPart.Name         = "UpgradeSign_" .. player.UserId .. "_" .. slotIndex
			signPart.Size         = Vector3.new(slotSize, 0.2, signWidth)
			signPart.Position     = Vector3.new(slotPos.X, y, signZ)
			signPart.Anchored     = true
			signPart.CanCollide   = false
			signPart.BrickColor   = BrickColor.new("Cyan")
			signPart.Material     = Enum.Material.Neon
			signPart.Transparency = 1
			signPart.Parent       = workspace

			local signBillboard = Instance.new("BillboardGui")
			signBillboard.Size        = UDim2.new(0, 140, 0, 70)
			signBillboard.StudsOffset = Vector3.new(0, 2.5, 0)
			signBillboard.AlwaysOnTop = false
			signBillboard.MaxDistance = 30
			signBillboard.Parent      = signPart

			local signLabel = Instance.new("TextLabel")
			signLabel.Size                   = UDim2.new(1, 0, 1, 0)
			signLabel.BackgroundTransparency = 1
			signLabel.Text                   = ""
			signLabel.TextColor3             = Color3.fromRGB(100, 220, 255)
			signLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
			signLabel.TextStrokeTransparency = 0.3
			signLabel.TextScaled             = true
			signLabel.Font                   = Enum.Font.GothamBold
			signLabel.Parent                 = signBillboard

			local clickDetector = Instance.new("ClickDetector")
			clickDetector.MaxActivationDistance = 50
			clickDetector.Parent                = signPart

			local capturedPlayer = player
			local capturedSlot   = slotIndex
			clickDetector.MouseClick:Connect(function(clickingPlayer)
				if clickingPlayer ~= capturedPlayer then return end
				if not playerSlots[capturedPlayer] then
					warn("[UPGRADE] playerSlots is nil for player")
					return
				end
				if not playerSlots[capturedPlayer][capturedSlot] then
					-- Debug: show which slots ARE filled
					local filled = {}
					for i = 1, BASE_SLOTS do
						if playerSlots[capturedPlayer][i] then
							table.insert(filled, i)
						end
					end
					warn("[UPGRADE] No brainrot in slot", capturedSlot, "| Filled slots:", table.concat(filled, ","))
					upgradeResultEvent:FireClient(capturedPlayer, false, "No brainrot in this slot!")
					return
				end
				local level = slotUpgrades[capturedPlayer][capturedSlot] or 0
				if level >= MAX_UPGRADE_LEVEL then
					upgradeResultEvent:FireClient(capturedPlayer, false, "Max level reached!")
					return
				end
				local cost   = getUpgradeCost(capturedPlayer, capturedSlot)
				local wallet = playerWallet[capturedPlayer] or 0
				if wallet < cost then
					upgradeResultEvent:FireClient(capturedPlayer, false, "Need " .. cost .. " credits! You have " .. wallet)
					return
				end
				playerWallet[capturedPlayer] = wallet - cost
				slotUpgrades[capturedPlayer][capturedSlot] = level + 1
				updateUpgradeSign(capturedPlayer, capturedSlot)
				upgradeResultEvent:FireClient(
					capturedPlayer, true,
					capturedSlot,
					slotUpgrades[capturedPlayer][capturedSlot],
					playerWallet[capturedPlayer]
				)
			end)

			signs[slotIndex] = { part = signPart, label = signLabel }
		end
	end

	slotParts[player]    = slots
	creditPlates[player] = plates
	upgradeSigns[player] = signs
	slotCredits[player]  = {}
	slotUpgrades[player] = slotUpgrades[player] or {}
	for i = 1, BASE_SLOTS do
		slotCredits[player][i] = 0
		if not slotUpgrades[player][i] then
			slotUpgrades[player][i] = 0
		end
	end

	print("Slots created for", player.Name, "at base", playerBaseIndex[player])
end

local function setSlotFilled(player, slotIndex, brainrotColor)
	local parts = slotParts[player]
	if not parts then return end
	local part = parts[slotIndex]
	if not part then return end
	if brainrotColor then
		part.BrickColor = brainrotColor
		part.Material   = Enum.Material.Neon
	else
		part.BrickColor = BrickColor.new("Medium stone grey")
		part.Material   = Enum.Material.SmoothPlastic
	end
	-- Hide/show slot number label to avoid overlapping with brainrot
	local gui = part:FindFirstChildWhichIsA("SurfaceGui") or part:FindFirstChildWhichIsA("BillboardGui")
	if gui then
		gui.Enabled = not brainrotColor
	end
	updateUpgradeSign(player, slotIndex)
end

local function removeSlotParts(player)
	if slotParts[player] then
		for _, part in ipairs(slotParts[player]) do
			if part and part.Parent then part:Destroy() end
		end
		slotParts[player] = nil
	end
	if creditPlates[player] then
		for _, plate in ipairs(creditPlates[player]) do
			if plate and plate.part and plate.part.Parent then plate.part:Destroy() end
		end
		creditPlates[player] = nil
	end
	if upgradeSigns[player] then
		for _, sign in ipairs(upgradeSigns[player]) do
			if sign and sign.part and sign.part.Parent then sign.part:Destroy() end
		end
		upgradeSigns[player] = nil
	end
end

-- =====================
-- CREDIT TICK
-- =====================

local function startCreditTick(player)
	task.spawn(function()
		while player and player.Parent do
			task.wait(1)
			if not playerSlots[player] then break end
			local totalEarned = 0
			for i = 1, BASE_SLOTS do
				if playerSlots[player][i] ~= nil then
					local rate = getSlotEarnRate(player, i)
					totalEarned += rate
					if creditPlates[player] and creditPlates[player][i] then
						local plate = creditPlates[player][i]
						plate.credits += rate
						plate.label.Text = tostring(plate.credits)
						if plate.billboard then plate.billboard.Enabled = true end
					end
				end
			end
			if totalEarned > 0 then
				playerCredits[player] = (playerCredits[player] or 0) + totalEarned
				sessionEarnings[player.UserId] = (sessionEarnings[player.UserId] or 0) + totalEarned
			end
		end
	end)
end

-- =====================
-- CREDIT PLATE COLLECTION
-- =====================

task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if not character then continue end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then continue end
			if not creditPlates[player] then continue end
			for i, plate in ipairs(creditPlates[player]) do
				if not plate or not plate.part then continue end
				local dx = root.Position.X - plate.part.Position.X
				local dz = root.Position.Z - plate.part.Position.Z
				local horizDist = math.sqrt(dx * dx + dz * dz)
				if horizDist <= CREDIT_PLATE_COLLECT_DISTANCE and plate.credits > 0 then
					local collected = plate.credits
					plate.credits = 0
					plate.label.Text = ""
					if plate.billboard then plate.billboard.Enabled = false end
					playerWallet[player] = (playerWallet[player] or 0) + collected
					plate.part.BrickColor = BrickColor.new("White")
					task.delay(0.3, function()
						if plate and plate.part and plate.part.Parent then
							plate.part.BrickColor = BrickColor.new("Bright yellow")
						end
					end)
					collectEvent:FireClient(player, collected, playerWallet[player])
				end
			end
		end
	end
end)

-- =====================
-- SELL SYSTEM (with rate limiting)
-- =====================

sellEvent.OnServerEvent:Connect(function(player, slotIndex, isSelling)
	-- Rate limit check
	local now = tick()
	if isSelling then
		if lastSellTime[player] and (now - lastSellTime[player]) < SELL_COOLDOWN then
			return
		end
		lastSellTime[player] = now
	end

	if not playerSlots[player] then return end
	if type(slotIndex) ~= "number" then return end
	slotIndex = math.floor(slotIndex)
	if slotIndex < 1 or slotIndex > BASE_SLOTS then return end
	if not playerSlots[player][slotIndex] then return end

	-- Block sell during grace period after deposit
	if slotDepositTime[player] and slotDepositTime[player][slotIndex] then
		if (tick() - slotDepositTime[player][slotIndex]) < SELL_GRACE_PERIOD then
			sellProgressEvent:FireClient(player, false, 0, 0, 0)
			return
		end
	end

	if not isSelling then
		playerSelling[player] = nil
		sellProgressEvent:FireClient(player, false, 0, 0, 0)
		return
	end

	if playerSelling[player] then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local slotPad = slotParts[player] and slotParts[player][slotIndex]
	if not slotPad then return end
	if (root.Position - slotPad.Position).Magnitude > SELL_DISTANCE then return end

	playerSelling[player] = slotIndex
	local sellPrice = getSellPrice(player, slotIndex)
	sellProgressEvent:FireClient(player, true, 0, sellPrice, slotIndex)

	task.spawn(function()
		local elapsed  = 0
		local startPos = root.Position
		while playerSelling[player] == slotIndex do
			task.wait(0.1)
			elapsed += 0.1
			if not playerSlots[player] or not playerSlots[player][slotIndex] then
				playerSelling[player] = nil
				sellProgressEvent:FireClient(player, false, 0, 0, 0)
				return
			end
			if (root.Position - startPos).Magnitude > MOVE_TOLERANCE then
				playerSelling[player] = nil
				sellProgressEvent:FireClient(player, false, 0, 0, 0)
				return
			end
			if (root.Position - slotPad.Position).Magnitude > SELL_DISTANCE then
				playerSelling[player] = nil
				sellProgressEvent:FireClient(player, false, 0, 0, 0)
				return
			end
			sellProgressEvent:FireClient(player, true, math.min(elapsed / HOLD_TIME, 1), sellPrice, slotIndex)
			if elapsed >= HOLD_TIME then
				local slot = playerSlots[player][slotIndex]
				if slot and slot.block and slot.block.Parent then
					warn("[SELL] Destroying brainrot in slot", slotIndex, "name:", slot.block.Name)
					CollectionService:RemoveTag(slot.block, TAG_STORED_BRAINROT)
					slot.block:Destroy()
				end
				if creditPlates[player] and creditPlates[player][slotIndex] then
					creditPlates[player][slotIndex].credits = 0
					creditPlates[player][slotIndex].label.Text = ""
					if creditPlates[player][slotIndex].billboard then
						creditPlates[player][slotIndex].billboard.Enabled = false
					end
				end
				playerSlots[player][slotIndex]  = nil
				slotUpgrades[player][slotIndex] = 0
				setSlotFilled(player, slotIndex, nil)
				playerWallet[player] = (playerWallet[player] or 0) + sellPrice
				playerSelling[player] = nil
				sellResultEvent:FireClient(player, slotIndex, sellPrice, playerWallet[player])
				return
			end
		end
	end)
end)

-- =====================
-- REBIRTH STATION
-- =====================

local REBIRTH_SIGN_POS = Vector3.new(-35.308, 9.002, 74.893)

-- Invisible click part near the HappyStone (no purple box)
local rebirthPart = Instance.new("Part")
rebirthPart.Name         = "RebirthStation"
rebirthPart.Size         = Vector3.new(6, 8, 6)
rebirthPart.Position     = REBIRTH_SIGN_POS + Vector3.new(0, -3, -18)
rebirthPart.Anchored     = true
rebirthPart.CanCollide   = false
rebirthPart.Transparency = 1
rebirthPart.Parent       = workspace

local rebirthBillboard = Instance.new("BillboardGui")
rebirthBillboard.Size        = UDim2.new(0, 280, 0, 200)
rebirthBillboard.StudsOffset = Vector3.new(0, 6, 0)
rebirthBillboard.AlwaysOnTop = false
rebirthBillboard.MaxDistance  = 50
rebirthBillboard.Parent      = rebirthPart

local rebirthBg = Instance.new("Frame")
rebirthBg.Size                   = UDim2.new(1, 0, 1, 0)
rebirthBg.BackgroundColor3       = Color3.fromRGB(15, 10, 30)
rebirthBg.BackgroundTransparency = 0.15
rebirthBg.BorderSizePixel        = 0
rebirthBg.Parent                 = rebirthBillboard
Instance.new("UICorner", rebirthBg).CornerRadius = UDim.new(0, 10)

local rebirthTitle = Instance.new("TextLabel")
rebirthTitle.Size                   = UDim2.new(1, 0, 0.18, 0)
rebirthTitle.Position               = UDim2.new(0, 0, 0, 0)
rebirthTitle.BackgroundTransparency = 1
rebirthTitle.Text                   = "REBIRTH STATION"
rebirthTitle.TextColor3             = Color3.fromRGB(255, 180, 50)
rebirthTitle.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
rebirthTitle.TextStrokeTransparency = 0
rebirthTitle.TextScaled             = true
rebirthTitle.Font                   = Enum.Font.GothamBold
rebirthTitle.Parent                 = rebirthBg

local rebirthInfo = Instance.new("TextLabel")
rebirthInfo.Name                    = "InfoLabel"
rebirthInfo.Size                    = UDim2.new(1, -10, 0.72, 0)
rebirthInfo.Position                = UDim2.new(0, 5, 0.2, 0)
rebirthInfo.BackgroundTransparency  = 1
rebirthInfo.Text                    = ""
rebirthInfo.TextColor3              = Color3.fromRGB(220, 220, 255)
rebirthInfo.TextStrokeColor3        = Color3.fromRGB(0, 0, 0)
rebirthInfo.TextStrokeTransparency  = 0.3
rebirthInfo.TextScaled              = true
rebirthInfo.TextYAlignment          = Enum.TextYAlignment.Top
rebirthInfo.TextXAlignment          = Enum.TextXAlignment.Left
rebirthInfo.Font                    = Enum.Font.GothamBold
rebirthInfo.Parent                  = rebirthBg

-- Server-side function to update the rebirth sign billboard directly
local function updateRebirthSign(player)
	local nextLevel = (playerRebirth[player] or 0) + 1
	if nextLevel > MAX_REBIRTHS then
		rebirthInfo.Text = "MAX REBIRTH\nREACHED!"
		return
	end
	local req = playerRebirthReq[player]
	if not req then
		rebirthInfo.Text = "No requirements yet..."
		return
	end
	local rarityText = getRebirthRarityText(nextLevel)
	local lines = "REBIRTH #" .. nextLevel .. "\n"
	lines = lines .. "──────────────\n"
	lines = lines .. rarityText .. "\n\n"
	lines = lines .. "Cost: " .. tostring(req.cost) .. " credits"
	rebirthInfo.Text = lines
end
rebirthInfo.Text = ""

local rebirthClick = Instance.new("ClickDetector")
rebirthClick.MaxActivationDistance = 12
rebirthClick.Parent = rebirthPart

local function getPlayerBrainrotNames(player)
	local names = {}
	if not playerSlots[player] then return names end
	for i = 1, BASE_SLOTS do
		local slot = playerSlots[player][i]
		if slot and slot.block and slot.block.Parent then
			local bName = slot.block:GetAttribute("BrainrotName") or slot.block.Name
			names[bName] = (names[bName] or 0) + 1
		end
	end
	return names
end

local function clearPlayerBase(player)
	if not playerSlots[player] then return end
	for i = 1, BASE_SLOTS do
		local slot = playerSlots[player][i]
		if slot and slot.block and slot.block.Parent then
			CollectionService:RemoveTag(slot.block, TAG_STORED_BRAINROT)
			slot.block:Destroy()
		end
		playerSlots[player][i] = nil
		if slotUpgrades[player] then slotUpgrades[player][i] = 0 end
		if creditPlates[player] and creditPlates[player][i] then
			creditPlates[player][i].credits = 0
			creditPlates[player][i].label.Text = ""
			if creditPlates[player][i].billboard then
				creditPlates[player][i].billboard.Enabled = false
			end
		end
		setSlotFilled(player, i, nil)
	end
	-- Drop any carried brainrot
	if carriedBrainrots[player] then
		local carried = carriedBrainrots[player]
		if carried and carried.Parent then
			CollectionService:RemoveTag(carried, TAG_SPAWNED_BRAINROT)
			carried:Destroy()
		end
		carriedBrainrots[player] = nil
		playerHasPickup[player] = false
	end
end

rebirthClick.MouseClick:Connect(function(clickingPlayer)
	local currentRebirth = playerRebirth[clickingPlayer] or 0
	if currentRebirth >= MAX_REBIRTHS then
		rebirthResultEvent:FireClient(clickingPlayer, false, "Max rebirths reached! (10/10)")
		return
	end

	local req = playerRebirthReq[clickingPlayer]
	if not req then
		rebirthResultEvent:FireClient(clickingPlayer, false, "No requirements found, try rejoining.")
		return
	end

	-- Check credits
	local wallet = playerWallet[clickingPlayer] or 0
	if wallet < req.cost then
		rebirthResultEvent:FireClient(clickingPlayer, false,
			"Need " .. req.cost .. " credits (you have " .. wallet .. ")")
		return
	end

	-- Rarity-based validation: count brainrots by rarity in player's base
	local ownedByRarity = {}
	local ownedNames = getPlayerBrainrotNames(clickingPlayer)
	for brainrotName, count in pairs(ownedNames) do
		for _, b in ipairs(BRAINROTS) do
			if b.name == brainrotName then
				ownedByRarity[b.rarity] = (ownedByRarity[b.rarity] or 0) + count
				break
			end
		end
	end

	-- Check each rarity group requirement
	local missing = {}
	for _, group in ipairs(req.spec) do
		local owned = ownedByRarity[group.rarity] or 0
		if owned < group.count then
			local shortage = group.count - owned
			table.insert(missing, shortage .. "x " .. group.rarity)
		end
		-- Subtract used count so same brainrot isn't counted twice
		ownedByRarity[group.rarity] = math.max(0, (ownedByRarity[group.rarity] or 0) - group.count)
	end

	if #missing > 0 then
		rebirthResultEvent:FireClient(clickingPlayer, false,
			"Missing: " .. table.concat(missing, ", "))
		return
	end

	-- All requirements met! Execute rebirth
	playerWallet[clickingPlayer] = wallet - req.cost
	clearPlayerBase(clickingPlayer)
	local nextLevel = currentRebirth + 1
	playerRebirth[clickingPlayer] = nextLevel

	-- Notify client
	rebirthResultEvent:FireClient(clickingPlayer, true, nextLevel, playerWallet[clickingPlayer])

	-- Set requirements for NEXT rebirth
	playerRebirthInfoSent[clickingPlayer] = false
	if nextLevel < MAX_REBIRTHS then
		local nextReq = initRebirthReq(clickingPlayer)
		if nextReq then
			local rarityText = getRebirthRarityText(nextLevel + 1)
			rebirthInfoEvent:FireClient(clickingPlayer, nextLevel, nextReq.brainrots, nextReq.cost, rarityText)
		end
		updateRebirthSign(clickingPlayer)
	else
		playerRebirthReq[clickingPlayer] = nil
		rebirthInfoEvent:FireClient(clickingPlayer, nextLevel, {}, 0)
		rebirthInfo.Text = "MAX REBIRTH REACHED!"
	end
end)

-- =====================
-- PROMPT / NAME TAG
-- =====================

local function createPrompt(brainrot, brainrotDef, player)
	local mutation    = getMutation(player)
	local rarity      = brainrotDef and brainrotDef.rarity or "COMMON"
	local rarityColor = RARITY_LABEL_COLORS[rarity] or Color3.fromRGB(255, 255, 255)

	local attachTo = brainrot
	if brainrot:IsA("Model") then
		attachTo = brainrot.PrimaryPart or brainrot:FindFirstChildWhichIsA("BasePart")
	end
	if not attachTo then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name        = "PickupPrompt"
	billboard.Size        = UDim2.new(0, 80, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled     = true
	billboard.Parent      = attachTo

	local nameTag = Instance.new("Frame")
	nameTag.Name                   = "NameTag"
	nameTag.Size                   = UDim2.new(1, 0, 0.62, 0)
	nameTag.Position               = UDim2.new(0, 0, 0, 0)
	nameTag.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
	nameTag.BackgroundTransparency = 0.25
	nameTag.BorderSizePixel        = 0
	nameTag.Parent                 = billboard
	Instance.new("UICorner", nameTag).CornerRadius = UDim.new(0, 5)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size                   = UDim2.new(1, -4, 0.38, 0)
	nameLabel.Position               = UDim2.new(0, 2, 0, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                   = (brainrotDef and brainrotDef.icon or "") .. " " .. (brainrotDef and brainrotDef.name or "Brainrot")
	nameLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled             = true
	nameLabel.Font                   = Enum.Font.GothamBold
	nameLabel.Parent                 = nameTag

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size                   = UDim2.new(1, -4, 0.3, 0)
	rarityLabel.Position               = UDim2.new(0, 2, 0.38, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text                   = rarity
	rarityLabel.TextColor3             = rarityColor
	rarityLabel.TextScaled             = true
	rarityLabel.Font                   = Enum.Font.GothamBold
	rarityLabel.Parent                 = nameTag

	local mutationLabel = Instance.new("TextLabel")
	mutationLabel.Size                   = UDim2.new(1, -4, 0.28, 0)
	mutationLabel.Position               = UDim2.new(0, 2, 0.70, 0)
	mutationLabel.BackgroundTransparency = 1
	mutationLabel.Text                   = mutation.label
	mutationLabel.TextColor3             = mutation.color
	mutationLabel.TextScaled             = true
	mutationLabel.Font                   = Enum.Font.Gotham
	mutationLabel.Parent                 = nameTag

	local eFrame = Instance.new("Frame")
	eFrame.Name                   = "EFrame"
	eFrame.Size                   = UDim2.new(0.32, 0, 0.32, 0)
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
-- SPAWN SYSTEM (now uses Folders + CollectionService tags)
-- =====================

local function getRandomPositionInZone(zone)
	local x = zone.position.X + math.random() * zone.size.X - zone.size.X / 2
	local z = zone.position.Z + math.random() * zone.size.Z - zone.size.Z / 2
	return Vector3.new(x, zone.position.Y + 1, z)
end

local function getPrimaryPart(obj)
	if obj:IsA("Model") then
		return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
	end
	return obj
end

local function attachBrainrotToPlayer(player, brainrot)
	local character = player.Character
	if not character then return end

	-- Remove spawned tag since it's now being carried
	CollectionService:RemoveTag(brainrot, TAG_SPAWNED_BRAINROT)

	if brainrot:IsA("Model") then
		if not brainrot.PrimaryPart then
			local firstPart = brainrot:FindFirstChildWhichIsA("BasePart")
			if firstPart then brainrot.PrimaryPart = firstPart end
		end
		for _, part in ipairs(brainrot:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Anchored   = true
			end
		end
	else
		brainrot.CanCollide = false
		brainrot.Anchored   = true
	end

	carriedBrainrots[player] = brainrot

	task.spawn(function()
		while carriedBrainrots[player] == brainrot and brainrot and brainrot.Parent do
			local char = player.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart")
				if root then
					local targetCFrame = root.CFrame * CFrame.new(0, 2, -4)
					if brainrot:IsA("Model") then
						brainrot:PivotTo(targetCFrame)
					else
						brainrot.CFrame = targetCFrame
					end
				end
			end
			task.wait(0.03)
		end
	end)
end

local function detachBrainrotFromPlayer(player)
	local brainrot = carriedBrainrots[player]
	if brainrot and brainrot.Parent then
		warn("[DETACH] Destroying carried brainrot:", brainrot.Name)
		CollectionService:RemoveTag(brainrot, TAG_SPAWNED_BRAINROT)
		brainrot:Destroy()
	end
	carriedBrainrots[player] = nil
end

local function spawnBrainrotInZone(zoneIndex)
	local zone = ZONES[zoneIndex]
	if zoneActive[zoneIndex] >= zone.cap then return end

	local rarity      = pickRarity(zone.rarities)
	local brainrotDef = pickBrainrotFromRarity(rarity)
	if not brainrotDef then return end

	local spawnPos = getRandomPositionInZone(zone)
	local brainrot
	local parentFolder = spawnFolders[zoneIndex]

	if brainrotDef.modelName then
		local template = ReplicatedStorage:FindFirstChild(brainrotDef.modelName)
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

	local earnRate = brainrotDef.baseEarn * RARITIES[rarity].mult
	if brainrot:IsA("Model") then
		brainrot:SetAttribute("EarnRate",     earnRate)
		brainrot:SetAttribute("Rarity",       rarity)
		brainrot:SetAttribute("BrainrotName", brainrotDef.name)
		if brainrot.PrimaryPart then
			brainrot.PrimaryPart:SetAttribute("EarnRate",     earnRate)
			brainrot.PrimaryPart:SetAttribute("Rarity",       rarity)
			brainrot.PrimaryPart:SetAttribute("BrainrotName", brainrotDef.name)
		end
	else
		brainrot:SetAttribute("EarnRate",     earnRate)
		brainrot:SetAttribute("Rarity",       rarity)
		brainrot:SetAttribute("BrainrotName", brainrotDef.name)
	end

	-- Tag for CollectionService-based detection
	CollectionService:AddTag(brainrot, TAG_SPAWNED_BRAINROT)

	createPrompt(brainrot, brainrotDef, nil)
	zoneActive[zoneIndex] += 1

	task.delay(DESPAWN_TIME, function()
		if not (brainrot and brainrot.Parent and CollectionService:HasTag(brainrot, TAG_SPAWNED_BRAINROT)) then
			return
		end
		-- Don't despawn if someone is carrying this brainrot (race with pickup event)
		for _, carried in pairs(carriedBrainrots) do
			if carried == brainrot then return end
		end
		-- Brief re-check to handle network-latency race with pickup
		task.wait(0.5)
		if brainrot and brainrot.Parent and CollectionService:HasTag(brainrot, TAG_SPAWNED_BRAINROT) then
			-- Final check: not being carried
			for _, carried in pairs(carriedBrainrots) do
				if carried == brainrot then return end
			end
			warn("[DESPAWN] Destroying", brainrot.Name, "parent:", brainrot.Parent.Name)
			CollectionService:RemoveTag(brainrot, TAG_SPAWNED_BRAINROT)
			brainrot:Destroy()
			zoneActive[zoneIndex] = math.max(0, zoneActive[zoneIndex] - 1)
		end
	end)
end

for zoneIndex, zone in ipairs(ZONES) do
	for _, rarity in ipairs(zone.rarities) do
		local interval = RARITIES[rarity].spawnInterval
		task.spawn(function()
			while true do
				task.wait(interval)
				if zoneActive[zoneIndex] < zone.cap then
					spawnBrainrotInZone(zoneIndex)
				end
			end
		end)
	end
end

-- =====================
-- DEPOSIT SYSTEM (now tags stored brainrots + uses storedFolder)
-- =====================

local function isNearBase(player)
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local basePos = getPlayerBasePosition(player)
	if not basePos then return false end
	local relX = math.abs(root.Position.X - basePos.X)
	local relZ = math.abs(root.Position.Z - basePos.Z)
	return relX <= BASE_SIZE.X / 2 and relZ <= BASE_SIZE.Z / 2
end

local function depositBrainrot(player)
	if not playerHasPickup[player] then return end
	if not playerSlots[player] then return end

	local freeSlot = nil
	for i = 1, BASE_SLOTS do
		if playerSlots[player][i] == nil then
			freeSlot = i
			break
		end
	end
	if not freeSlot then return end

	local brainrot = carriedBrainrots[player]
	local color    = RARITY_COLORS["COMMON"]
	local earnRate = 1

	if brainrot then
		local rarity = brainrot:GetAttribute("Rarity")
		if rarity and RARITY_COLORS[rarity] then
			color = RARITY_COLORS[rarity]
		end
		earnRate = brainrot:GetAttribute("EarnRate") or 1
	end

	local slotPad = slotParts[player] and slotParts[player][freeSlot]
	if not slotPad then return end

	local storedBlock

	-- DEBUG: log which deposit path is taken
	if not brainrot then
		warn("[DEPOSIT] brainrot is NIL for slot", freeSlot)
	elseif not brainrot.Parent then
		warn("[DEPOSIT] brainrot DESTROYED before deposit for slot", freeSlot, brainrot.ClassName, brainrot.Name)
	else
		print("[DEPOSIT] Slot", freeSlot, "class:", brainrot.ClassName, "name:", brainrot.Name)
	end

	if brainrot and brainrot.Parent and brainrot:IsA("Model") then
		-- Re-find PrimaryPart if it was lost during carry
		if not brainrot.PrimaryPart then
			local firstPart = brainrot:FindFirstChildWhichIsA("BasePart")
			if firstPart then brainrot.PrimaryPart = firstPart end
		end
		carriedBrainrots[player] = nil
		playerHasPickup[player]  = false
		for _, part in ipairs(brainrot:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored   = true
				part.CanCollide = false
			end
		end
		-- Remove the pickup prompt billboard so it doesn't overlap slot UI
		local prompt = brainrot:FindFirstChild("PickupPrompt", true)
		if prompt then prompt:Destroy() end
		brainrot:PivotTo(CFrame.new(slotPad.Position + Vector3.new(0, 2, 0)))
		brainrot.Parent = storedFolder
		storedBlock = brainrot
		print("[DEPOSIT] Model path OK for slot", freeSlot)
	elseif brainrot and brainrot.Parent and brainrot:IsA("BasePart") then
		-- Reuse the original part (preserves MeshParts / SpecialMesh children)
		carriedBrainrots[player] = nil
		playerHasPickup[player]  = false
		brainrot.Anchored   = true
		brainrot.CanCollide = false
		brainrot.Position   = slotPad.Position + Vector3.new(0, 1.5, 0)
		-- Remove the pickup prompt billboard so it doesn't overlap slot UI
		local prompt = brainrot:FindFirstChild("PickupPrompt")
		if prompt then prompt:Destroy() end
		brainrot.Parent = storedFolder
		storedBlock = brainrot
		print("[DEPOSIT] BasePart path OK for slot", freeSlot)
	else
		warn("[DEPOSIT] FALLBACK (block) for slot", freeSlot, "brainrot:", brainrot and brainrot.Name or "nil")
		carriedBrainrots[player] = nil
		playerHasPickup[player]  = false
		if brainrot and brainrot.Parent then brainrot:Destroy() end
		storedBlock = Instance.new("Part")
		storedBlock.Name       = "StoredBrainrot"
		storedBlock.Size       = Vector3.new(1.5, 1.5, 1.5)
		storedBlock.BrickColor = color
		storedBlock.Material   = Enum.Material.Neon
		storedBlock.Anchored   = true
		storedBlock.CanCollide = false
		storedBlock.Position   = slotPad.Position + Vector3.new(0, 1.5, 0)
		storedBlock.Parent     = storedFolder
	end

	-- Tag stored brainrot so client can find it via CollectionService
	CollectionService:AddTag(storedBlock, TAG_STORED_BRAINROT)
	-- Store ownerUserId and slotIndex as attributes for client-side sell detection
	storedBlock:SetAttribute("OwnerUserId", player.UserId)
	storedBlock:SetAttribute("SlotIndex", freeSlot)

	-- DEBUG: watch for unexpected destruction of stored brainrot
	local watchSlot = freeSlot
	local watchBlock = storedBlock
	storedBlock.AncestryChanged:Connect(function(_, newParent)
		if not newParent then
			warn("[STORED-DESTROYED] Slot", watchSlot, "name:", watchBlock.Name, "class:", watchBlock.ClassName)
			warn(debug.traceback())
		end
	end)

	playerSlots[player][freeSlot] = { color = color, block = storedBlock, earnRate = earnRate }
	if not slotDepositTime[player] then slotDepositTime[player] = {} end
	slotDepositTime[player][freeSlot] = tick()
	setSlotFilled(player, freeSlot, color)
	depositEvent:FireClient(player, freeSlot)
end

task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in ipairs(Players:GetPlayers()) do
			if playerHasPickup[player] and isNearBase(player) and not playerDepositing[player] then
				playerDepositing[player] = true
				task.spawn(function()
					depositBrainrot(player)
					playerDepositing[player] = false
				end)
			end
		end
	end
end)

-- =====================
-- PICKUP REMOTE (with rate limiting)
-- =====================

remoteEvent.OnServerEvent:Connect(function(player, brainrot, isHolding)
	-- Rate limit check
	local now = tick()
	if isHolding then
		if lastPickupTime[player] and (now - lastPickupTime[player]) < PICKUP_COOLDOWN then
			return
		end
		lastPickupTime[player] = now
	end

	if playerHolding[player] and isHolding then return end
	if playerHasPickup[player] then return end
	if not brainrot or not brainrot.Parent then return end

	-- Walk up to find the tagged ancestor (handles any hierarchy depth)
	local obj = brainrot
	while obj do
		if CollectionService:HasTag(obj, TAG_SPAWNED_BRAINROT) then break end
		obj = obj.Parent
	end
	if not obj then return end
	-- Resolve to the Model if the clicked part is inside one
	if obj and obj.Parent and obj.Parent:IsA("Folder") and obj:IsA("Model") then
		brainrot = obj
	elseif obj and obj:IsA("Model") then
		brainrot = obj
	end

	-- Verify this is actually a spawned brainrot
	if not CollectionService:HasTag(brainrot, TAG_SPAWNED_BRAINROT) then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local checkPart = getPrimaryPart(brainrot)
	if not checkPart then return end
	if (root.Position - checkPart.Position).Magnitude > PICKUP_DISTANCE then return end

	if isHolding then
		playerHolding[player] = true
		local startPosition = root.Position

		-- Remove spawned tag immediately to prevent despawn timer from destroying
		-- the brainrot during the 3-second pickup hold
		CollectionService:RemoveTag(brainrot, TAG_SPAWNED_BRAINROT)

		-- Track which zone it came from before pickup starts
		local fromZoneIndex = nil
		for zi, folder in ipairs(spawnFolders) do
			if brainrot.Parent == folder then
				fromZoneIndex = zi
				break
			end
		end

		task.spawn(function()
			local elapsed = 0
			while playerHolding[player] do
				task.wait(0.1)
				elapsed += 0.1
				if not brainrot or not brainrot.Parent then
					playerHolding[player] = false
					progressEvent:FireClient(player, 0)
					return
				end
				if (root.Position - startPosition).Magnitude > MOVE_TOLERANCE then
					-- Cancelled: re-add tag so it can despawn normally
					CollectionService:AddTag(brainrot, TAG_SPAWNED_BRAINROT)
					playerHolding[player] = false
					progressEvent:FireClient(player, 0)
					return
				end
				if (root.Position - checkPart.Position).Magnitude > PICKUP_DISTANCE then
					CollectionService:AddTag(brainrot, TAG_SPAWNED_BRAINROT)
					playerHolding[player] = false
					progressEvent:FireClient(player, 0)
					return
				end
				progressEvent:FireClient(player, math.min(elapsed / HOLD_TIME, 1))
				if elapsed >= HOLD_TIME then
					if playerHasPickup[player] then
						CollectionService:AddTag(brainrot, TAG_SPAWNED_BRAINROT)
						playerHolding[player] = false
						progressEvent:FireClient(player, 0)
						return
					end
					playerHolding[player]   = false
					playerHasPickup[player] = true
					progressEvent:FireClient(player, 0)

					-- Decrement zone count when picked up
					if fromZoneIndex then
						zoneActive[fromZoneIndex] = math.max(0, zoneActive[fromZoneIndex] - 1)
					end

					attachBrainrotToPlayer(player, brainrot)
					return
				end
			end
			-- Player released E early: re-add tag
			if brainrot and brainrot.Parent then
				CollectionService:AddTag(brainrot, TAG_SPAWNED_BRAINROT)
			end
		end)
	else
		playerHolding[player] = false
		progressEvent:FireClient(player, 0)
	end
end)

-- =====================
-- LEADERBOARDS (now uses UpdateAsync for safety)
-- =====================

local allTimeStore = DataStoreService:GetDataStore("AllTimeEarnings_v1")

local BOARD_WALL_X  = 33.5
local BOARD_WALL_Y  = 28
local BOARD_Z_LEFT  = -26
local BOARD_Z_RIGHT = 26

local function createLedBoard(posX, posY, posZ, title)
	local board = Instance.new("Part")
	board.Name        = title .. "Board"
	board.Size        = Vector3.new(0.3, 24, 38)
	board.Position    = Vector3.new(posX, posY, posZ)
	board.Anchored    = true
	board.CanCollide  = false
	board.BrickColor  = BrickColor.new("Really black")
	board.Material    = Enum.Material.SmoothPlastic
	board.Parent      = workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face           = Enum.NormalId.Left
	gui.CanvasSize     = Vector2.new(600, 800)
	gui.AlwaysOnTop    = false
	gui.LightInfluence = 0
	gui.Brightness     = 1
	gui.Parent         = board

	local bg = Instance.new("Frame")
	bg.Size             = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(15, 20, 15)
	bg.BorderSizePixel  = 0
	bg.Parent           = gui
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft   = UDim.new(0, 20)
	padding.PaddingRight  = UDim.new(0, 20)
	padding.PaddingTop    = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.Parent        = bg

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size                   = UDim2.new(1, 0, 0, 50)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text                   = title
	titleLabel.TextColor3             = Color3.fromRGB(255, 220, 50)
	titleLabel.TextScaled             = true
	titleLabel.Font                   = Enum.Font.GothamBold
	titleLabel.Parent                 = bg

	local headerRow = Instance.new("Frame")
	headerRow.Size                   = UDim2.new(1, 0, 0, 30)
	headerRow.Position               = UDim2.new(0, 0, 0, 56)
	headerRow.BackgroundTransparency = 1
	headerRow.BorderSizePixel        = 0
	headerRow.Parent                 = bg

	local hRank = Instance.new("TextLabel")
	hRank.Size                   = UDim2.new(0.12, 0, 1, 0)
	hRank.BackgroundTransparency = 1
	hRank.Text                   = "#"
	hRank.TextColor3             = Color3.fromRGB(160, 160, 160)
	hRank.TextScaled             = true
	hRank.Font                   = Enum.Font.GothamBold
	hRank.Parent                 = headerRow

	local hName = Instance.new("TextLabel")
	hName.Size                   = UDim2.new(0.55, 0, 1, 0)
	hName.Position               = UDim2.new(0.14, 0, 0, 0)
	hName.BackgroundTransparency = 1
	hName.Text                   = "PLAYER"
	hName.TextColor3             = Color3.fromRGB(160, 160, 160)
	hName.TextScaled             = true
	hName.Font                   = Enum.Font.GothamBold
	hName.TextXAlignment         = Enum.TextXAlignment.Left
	hName.Parent                 = headerRow

	local hScore = Instance.new("TextLabel")
	hScore.Size                   = UDim2.new(0.28, 0, 1, 0)
	hScore.Position               = UDim2.new(0.72, 0, 0, 0)
	hScore.BackgroundTransparency = 1
	hScore.Text                   = "CREDITS"
	hScore.TextColor3             = Color3.fromRGB(160, 160, 160)
	hScore.TextScaled             = true
	hScore.Font                   = Enum.Font.GothamBold
	hScore.TextXAlignment         = Enum.TextXAlignment.Right
	hScore.Parent                 = headerRow

	local divider = Instance.new("Frame")
	divider.Size             = UDim2.new(1, 0, 0, 2)
	divider.Position         = UDim2.new(0, 0, 0, 88)
	divider.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
	divider.BorderSizePixel  = 0
	divider.Parent           = bg

	local rowContainer = Instance.new("Frame")
	rowContainer.Name                   = "Rows"
	rowContainer.Size                   = UDim2.new(1, 0, 1, -96)
	rowContainer.Position               = UDim2.new(0, 0, 0, 96)
	rowContainer.BackgroundTransparency = 1
	rowContainer.BorderSizePixel        = 0
	rowContainer.Parent                 = bg

	local rowLabels = {}
	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Size                   = UDim2.new(1, 0, 0.1, 0)
		row.Position               = UDim2.new(0, 0, (i - 1) * 0.1, 0)
		row.BackgroundTransparency = 1
		row.BorderSizePixel        = 0
		row.Parent                 = rowContainer

		local rankLabel = Instance.new("TextLabel")
		rankLabel.Size                   = UDim2.new(0.12, 0, 1, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Text                   = "#" .. i
		rankLabel.TextColor3             = i == 1 and Color3.fromRGB(255, 215, 0)
			or i == 2 and Color3.fromRGB(200, 200, 200)
			or i == 3 and Color3.fromRGB(220, 150, 60)
			or Color3.fromRGB(140, 140, 140)
		rankLabel.TextScaled             = true
		rankLabel.Font                   = Enum.Font.GothamBold
		rankLabel.Parent                 = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size                   = UDim2.new(0.55, 0, 1, 0)
		nameLabel.Position               = UDim2.new(0.14, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text                   = "---"
		nameLabel.TextColor3             = Color3.fromRGB(230, 230, 230)
		nameLabel.TextScaled             = true
		nameLabel.Font                   = Enum.Font.Gotham
		nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
		nameLabel.Parent                 = row

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Size                   = UDim2.new(0.28, 0, 1, 0)
		scoreLabel.Position               = UDim2.new(0.72, 0, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Text                   = "0"
		scoreLabel.TextColor3             = Color3.fromRGB(100, 255, 100)
		scoreLabel.TextScaled             = true
		scoreLabel.Font                   = Enum.Font.GothamBold
		scoreLabel.TextXAlignment         = Enum.TextXAlignment.Right
		scoreLabel.Parent                 = row

		rowLabels[i] = { name = nameLabel, score = scoreLabel, rank = rankLabel }
	end

	return rowLabels
end

local allTimeRows = createLedBoard(BOARD_WALL_X, BOARD_WALL_Y, BOARD_Z_LEFT,  "ALL TIME")
local sessionRows = createLedBoard(BOARD_WALL_X, BOARD_WALL_Y, BOARD_Z_RIGHT, "THIS SESSION")

local function formatScore(n)
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n))
end

local function updateSessionBoard()
	local entries = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(entries, {
			name  = p.Name,
			score = sessionEarnings[p.UserId] or 0,
		})
	end
	table.sort(entries, function(a, b) return a.score > b.score end)
	for i = 1, 10 do
		local row = sessionRows[i]
		if entries[i] then
			row.name.Text  = entries[i].name
			row.score.Text = formatScore(entries[i].score)
		else
			row.name.Text  = "---"
			row.score.Text = "0"
		end
	end
end

local allTimeCache = {}

local function refreshAllTimeBoard()
	table.sort(allTimeCache, function(a, b) return a.score > b.score end)
	for i = 1, 10 do
		local row = allTimeRows[i]
		if allTimeCache[i] then
			row.name.Text  = allTimeCache[i].name
			row.score.Text = formatScore(allTimeCache[i].score)
		else
			row.name.Text  = "---"
			row.score.Text = "0"
		end
	end
end

local function loadAllTimeBoard()
	local ok, data = pcall(function()
		return allTimeStore:GetAsync("TopEarners")
	end)
	if ok and data then
		allTimeCache = data
	end
	refreshAllTimeBoard()
end

-- v0.34: Replaced GetAsync+SetAsync with UpdateAsync to prevent race conditions
local function saveAllTimeScore(player, totalEarned)
	if totalEarned <= 0 then return end

	local ok, updatedEntries = pcall(function()
		return allTimeStore:UpdateAsync("TopEarners", function(oldData)
			local entries = oldData or {}

			local found = false
			for _, entry in ipairs(entries) do
				if entry.userId == player.UserId then
					if totalEarned > entry.score then
						entry.score = totalEarned
						entry.name  = player.Name
					end
					found = true
					break
				end
			end
			if not found then
				table.insert(entries, {
					userId = player.UserId,
					name   = player.Name,
					score  = totalEarned,
				})
			end

			table.sort(entries, function(a, b) return a.score > b.score end)
			while #entries > 10 do table.remove(entries) end

			return entries
		end)
	end)

	if ok and updatedEntries then
		allTimeCache = updatedEntries
		refreshAllTimeBoard()
	end
end

task.spawn(loadAllTimeBoard)

task.spawn(function()
	while true do
		task.wait(5)
		updateSessionBoard()
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, p in ipairs(Players:GetPlayers()) do
			local earned = playerCredits[p] or 0
			if earned > 0 then
				task.spawn(function()
					saveAllTimeScore(p, earned)
				end)
			end
		end
	end
end)

-- =====================
-- PLAYER ADDED / REMOVED
-- =====================

local function onPlayerAdded(player)
	if #Players:GetPlayers() > MAX_PLAYERS then
		player:Kick("This server is full! Maximum " .. MAX_PLAYERS .. " players allowed.")
		return
	end

	local baseIdx = assignBase(player)
	if not baseIdx then
		player:Kick("No free base available. Please try another server.")
		return
	end

	playerCredits[player]          = 0
	playerWallet[player]           = 0
	playerRebirth[player]          = 0
	playerSlots[player]            = {}
	playerSelling[player]          = nil
	playerDepositing[player]       = false
	sessionEarnings[player.UserId] = 0
	slotUpgrades[player]           = {}
	lastSellTime[player]           = 0
	lastPickupTime[player]         = 0

	for i = 1, BASE_SLOTS do
		playerSlots[player][i]  = nil
		slotUpgrades[player][i] = 0
	end

	createSlotParts(player)
	startCreditTick(player)

	-- Initialize rebirth requirements and update the physical sign
	initRebirthReq(player)
	updateRebirthSign(player)

	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		local root = character:WaitForChild("HumanoidRootPart")
		local basePos = getPlayerBasePosition(player)
		if root and basePos then
			root.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
		end
		createSlotParts(player)

		-- Send rebirth info after character loads (client script is ready by now)
		task.delay(2, function()
			local req = playerRebirthReq[player]
			if req then
				local nextLvl = (playerRebirth[player] or 0) + 1
				local rarityText = getRebirthRarityText(nextLvl)
				rebirthInfoEvent:FireClient(player, playerRebirth[player] or 0, req.brainrots, req.cost, rarityText)
			end
		end)
	end)

	local character = player.Character
	if character then
		task.wait(1)
		local root = character:FindFirstChild("HumanoidRootPart")
		local basePos = getPlayerBasePosition(player)
		if root and basePos then
			root.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
		end
		-- Send rebirth info for initial join (Character already exists)
		task.delay(2, function()
			local req = playerRebirthReq[player]
			if req then
				local nextLvl = (playerRebirth[player] or 0) + 1
				local rarityText = getRebirthRarityText(nextLvl)
				rebirthInfoEvent:FireClient(player, playerRebirth[player] or 0, req.brainrots, req.cost, rarityText)
			end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local totalEarned = playerCredits[player] or 0
	if totalEarned > 0 then
		task.spawn(function()
			saveAllTimeScore(player, totalEarned)
		end)
	end
	sessionEarnings[player.UserId] = nil

	if playerSlots[player] then
		for _, slot in pairs(playerSlots[player]) do
			if slot and slot.block and slot.block.Parent then
				CollectionService:RemoveTag(slot.block, TAG_STORED_BRAINROT)
				slot.block:Destroy()
			end
		end
	end
	detachBrainrotFromPlayer(player)
	removeSlotParts(player)
	releaseBase(player)
	playerHolding[player]    = nil
	playerHasPickup[player]  = nil
	playerCredits[player]    = nil
	playerWallet[player]     = nil
	playerRebirth[player]    = nil
	playerSlots[player]      = nil
	playerSelling[player]    = nil
	playerDepositing[player] = nil
	slotCredits[player]      = nil
	slotUpgrades[player]     = nil
	lastSellTime[player]     = nil
	slotDepositTime[player]  = nil
	lastPickupTime[player]   = nil
	playerSpeedTime[player]  = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
