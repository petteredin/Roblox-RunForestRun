-- Brainrot Spawn Engine v0.34
-- Blueberry Pie Games
-- Changelog v0.34:
--   - DataStore: Replaced GetAsync+SetAsync with UpdateAsync (race-condition fix)
--   - Organization: Brainrots spawn into dedicated Folders per zone + StoredBrainrots folder
--   - Sell bug fix: Model-based brainrots now tagged with CollectionService for sell detection
--   - Rate limiting: Sell/pickup requests have per-player cooldowns
--   - Mutation system: weighted random roll (75% Normal, 12% Gold, 8% Diamond, 5% Rainbow)
--   - walletLabel scope: N/A (server-side, was client issue)
--   - General: Minor cleanup and comments

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

-- Set to true to enable verbose debug prints in server output
local DEBUG = false
local function debugPrint(...)
	if DEBUG then print(...) end
end
local function debugWarn(...)
	if DEBUG then warn(...) end
end

-- =====================
-- SHARED CONFIG (single source of truth)
-- =====================
local gameConfigModule = game:GetService("ReplicatedStorage"):WaitForChild("GameConfig", 30)
if not gameConfigModule then
	error("[BrainrotSpawnEngine] FATAL: GameConfig module not found in ReplicatedStorage after 30s")
end
local GameConfig = require(gameConfigModule)

-- =====================
-- MUTATION SYSTEM
-- =====================

local MUTATIONS = GameConfig.MUTATIONS_BY_KEY

-- Forward declarations for luck variables (defined later with other server state)
-- These must be declared here so getMutation() can reference them.
local serverLuckMult    = 1
local serverLuckEndTime = 0

-- Roll a random mutation based on configured weights (75% Normal, 12% Gold, 8% Diamond, 5% Rainbow)
-- Server luck boosts non-Normal mutation weights (same pattern as pickRarity)
local function getMutation(_player)
	local currentLuckMult = 1
	if serverLuckMult > 1 and serverLuckEndTime > os.time() then
		currentLuckMult = serverLuckMult
	end

	local totalWeight = 0
	local weights = {}
	for _, m in ipairs(GameConfig.MUTATIONS) do
		local w = m.weight
		-- Luck boosts non-Normal mutations
		if currentLuckMult > 1 and m.key ~= "NONE" then
			w = w * currentLuckMult
		end
		weights[m.key] = w
		totalWeight = totalWeight + w
	end
	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, m in ipairs(GameConfig.MUTATIONS) do
		cumulative = cumulative + weights[m.key]
		if roll <= cumulative then
			return MUTATIONS[m.key], m.key
		end
	end
	return MUTATIONS.NONE, "NONE"
end

-- Force a specific mutation by key (used by admin spawn)
local function getMutationByKey(key)
	if key and key ~= "" and MUTATIONS[key] then
		return MUTATIONS[key], key
	end
	return nil
end

-- =====================
-- MARKETPLACE / GAMEPASSES
-- =====================

local MarketplaceService = game:GetService("MarketplaceService")

local GAMEPASS_IDS = GameConfig.GAMEPASS_IDS

-- Server uses duration in seconds, GameConfig stores minutes
local LUCK_PRODUCT_IDS = {}
for i, product in ipairs(GameConfig.LUCK_PRODUCTS) do
	LUCK_PRODUCT_IDS[i] = { id = product.id, mult = product.mult, duration = product.duration * 60 }
end

local playerGamepasses = {} -- [player] = { ADMIN_PANEL = true, DOUBLE_MONEY = true, ... }

-- =====================
-- DISCOUNT SYSTEM (VIP 30%, Group 15%)
-- =====================
local GROUP_ID = 0 -- Replace with actual Roblox Group ID

local DISCOUNT_RATES = {
	VIP = 0.30,     -- 30% discount for VIP Pass holders
	Group = 0.15,   -- 15% discount for Group members
	Default = 0.00,
}

-- Value multipliers (bonus value instead of lower price - Roblox doesn't support per-player pricing)
local VALUE_MULTIPLIERS = {
	VIP = 1.43,     -- ~43% more value (equivalent to 30% off)
	Group = 1.18,   -- ~18% more value (equivalent to 15% off)
	Default = 1.0,
}

local STACK_MULTIPLIERS = false -- true = stack VIP + Group discounts

-- Get the best multiplier for a player
local function getPlayerMultiplier(player)
	if not player then return VALUE_MULTIPLIERS.Default end
	local isVIP = playerGamepasses[player] and playerGamepasses[player]["VIP"]
	local inGroup = false
	if GROUP_ID > 0 then
		pcall(function()
			inGroup = player:IsInGroup(GROUP_ID)
		end)
	end

	if STACK_MULTIPLIERS and isVIP and inGroup then
		return VALUE_MULTIPLIERS.VIP * VALUE_MULTIPLIERS.Group
	elseif isVIP then
		return VALUE_MULTIPLIERS.VIP
	elseif inGroup then
		return VALUE_MULTIPLIERS.Group
	else
		return VALUE_MULTIPLIERS.Default
	end
end

-- Get discount info for a player (used by client)
local function getPlayerDiscountInfo(player)
	if not player then return { rate = 0, label = "", multiplier = 1.0 } end
	local isVIP = playerGamepasses[player] and playerGamepasses[player]["VIP"]
	local inGroup = false
	if GROUP_ID > 0 then
		pcall(function()
			inGroup = player:IsInGroup(GROUP_ID)
		end)
	end

	if isVIP then
		return { rate = DISCOUNT_RATES.VIP, label = "30% OFF - VIP!", multiplier = VALUE_MULTIPLIERS.VIP, isVIP = true, inGroup = inGroup }
	elseif inGroup then
		return { rate = DISCOUNT_RATES.Group, label = "15% OFF - GROUP!", multiplier = VALUE_MULTIPLIERS.Group, isVIP = false, inGroup = true }
	else
		return { rate = DISCOUNT_RATES.Default, label = "", multiplier = VALUE_MULTIPLIERS.Default, isVIP = false, inGroup = false }
	end
end

-- Server Luck state (declared near top of file, before getMutation)

-- Redeem Codes DataStore
local codeStore = nil
pcall(function()
	codeStore = DataStoreService:GetDataStore("RedeemCodes")
end)

-- Track which codes each player has used (in-memory, keyed by UserId)
local playerUsedCodes = {} -- [UserId] = { ["CODE_NAME"] = true }

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

local RARITY_LABEL_COLORS = GameConfig.RARITY_COLORS

-- Use shared catalog; modelName defaults to name (all current models match)
local BRAINROTS = GameConfig.BRAINROTS

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
-- Must be defined BEFORE getZoneActiveCount which references them
local TAG_SPAWNED_BRAINROT = "SpawnedBrainrot"
local TAG_STORED_BRAINROT  = "StoredBrainrot"

-- Per-zone spawn counter for O(1) cap checks (instead of iterating all tagged objects)
local zoneSpawnCount = {}
for i = 1, #ZONES do
	zoneSpawnCount[i] = 0
end

local function getZoneActiveCount(zoneIndex)
	return zoneSpawnCount[zoneIndex] or 0
end

-- Helper: increment/decrement zone counter when spawning/removing brainrots
local function incrementZoneCount(zoneIndex)
	zoneSpawnCount[zoneIndex] = (zoneSpawnCount[zoneIndex] or 0) + 1
end

local function decrementZoneCount(zoneIndex)
	zoneSpawnCount[zoneIndex] = math.max(0, (zoneSpawnCount[zoneIndex] or 0) - 1)
end

-- Determine which zone a brainrot belongs to by checking its parent folder
local function getZoneIndexForBrainrot(brainrot)
	if not brainrot or not brainrot.Parent then return nil end
	for i, folder in ipairs(spawnFolders) do
		if brainrot.Parent == folder then return i end
	end
	return nil
end

-- Auto-track zone counts via CollectionService tag events
-- This catches ALL AddTag/RemoveTag calls without modifying each site
CollectionService:GetInstanceAddedSignal(TAG_SPAWNED_BRAINROT):Connect(function(obj)
	local zi = getZoneIndexForBrainrot(obj)
	if zi then incrementZoneCount(zi) end
end)

CollectionService:GetInstanceRemovedSignal(TAG_SPAWNED_BRAINROT):Connect(function(obj)
	local zi = getZoneIndexForBrainrot(obj)
	if zi then decrementZoneCount(zi) end
end)

-- Periodic self-heal: reconcile counters with actual tags (every 60s)
task.spawn(function()
	while true do
		task.wait(60)
		for i, folder in ipairs(spawnFolders) do
			local actual = 0
			for _, obj in ipairs(CollectionService:GetTagged(TAG_SPAWNED_BRAINROT)) do
				if obj.Parent == folder then actual += 1 end
			end
			zoneSpawnCount[i] = actual
		end
	end
end)

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
local playerRebirth                 = {}    -- rebirth count per player

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
		debugPrint("[REBIRTH] Req for", player.Name, "level", nextLevel, ":",
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
-- playerRebirth declared earlier (needed by initRebirthReq)
local playerDepositing = {}
local playerBaseIndex  = {}
local playerCollection = {} -- [player] = { ["BrainrotName:MUTATION"] = true }
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
			debugPrint(player.Name .. " assigned to base " .. i)
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
-- REMOTES (created via RemoteSetup module)
-- =====================
local RemoteSetup = require(script.Parent:WaitForChild("RemoteSetup", 10))
local R = RemoteSetup.init()

-- Local aliases for backward compatibility with existing code
local remoteEvent           = R.pickupEvent
local progressEvent         = R.progressEvent
local creditEvent           = R.creditEvent
local depositEvent          = R.depositEvent
local collectEvent          = R.collectEvent
local upgradeResultEvent    = R.upgradeResult
local sellProgressEvent     = R.sellProgress
local sellResultEvent       = R.sellResult
local sellEvent             = R.sellEvent
local speedUpdateEvent      = R.speedUpdate
local rebirthResultEvent    = R.rebirthResult
local rebirthInfoEvent      = R.rebirthInfo
local rebirthRequestEvent   = R.rebirthRequest
local spawnNotifyEvent      = R.spawnNotify
local adminCheckEvent       = R.adminCheck
local getRebirthInfoFunc    = R.getRebirthInfo
local collectionUpdateEvent = R.collectionUpdate
local getCollectionFunc     = R.getCollection

getCollectionFunc.OnServerInvoke = function(requestingPlayer)
	return playerCollection[requestingPlayer] or {}
end

-- Store remotes (from RemoteSetup)
local getGamepassStatusFunc = R.getGamepassStatus
local redeemCodeFunc        = R.redeemCode
local getServerLuckFunc     = R.getServerLuck

getGamepassStatusFunc.OnServerInvoke = function(requestingPlayer)
	return playerGamepasses[requestingPlayer] or {}
end

-- Discount info remote (from RemoteSetup)
local getDiscountInfoFunc = R.getDiscountInfo
getDiscountInfoFunc.OnServerInvoke = function(requestingPlayer)
	return getPlayerDiscountInfo(requestingPlayer)
end

getServerLuckFunc.OnServerInvoke = function(_requestingPlayer)
	local now = os.time()
	if serverLuckMult > 1 and serverLuckEndTime > now then
		return serverLuckMult, serverLuckEndTime - now
	end
	return 1, 0
end

redeemCodeFunc.OnServerInvoke = function(requestingPlayer, codeInput)
	if type(codeInput) ~= "string" or #codeInput == 0 or #codeInput > 50 then
		return { success = false, message = "Invalid code" }
	end

	local codeName = codeInput:upper():gsub("%s+", "")

	if not codeStore then
		return { success = false, message = "Code system unavailable" }
	end

	-- Check if player already used this code (in-memory fast check)
	local userId = requestingPlayer.UserId
	if playerUsedCodes[userId] and playerUsedCodes[userId][codeName] then
		return { success = false, message = "You already used this code!" }
	end

	-- Atomic DataStore check: prevent race condition on server-hop
	-- Uses per-player-per-code key so redemption is tracked immediately
	local usedKey = "usedcode_" .. userId .. "_" .. codeName
	local alreadyUsed = false
	pcall(function()
		local val = codeStore:GetAsync(usedKey)
		if val then alreadyUsed = true end
	end)
	if alreadyUsed then
		-- Sync in-memory cache
		if not playerUsedCodes[userId] then playerUsedCodes[userId] = {} end
		playerUsedCodes[userId][codeName] = true
		return { success = false, message = "You already used this code!" }
	end

	-- Fetch code data from DataStore
	local ok, codeData = pcall(function()
		return codeStore:GetAsync("code_" .. codeName)
	end)

	if not ok or not codeData or type(codeData) ~= "table" then
		return { success = false, message = "Invalid code" }
	end

	-- Check max uses
	if codeData.maxUses and codeData.maxUses > 0 and (codeData.usedCount or 0) >= codeData.maxUses then
		return { success = false, message = "Code has expired (max uses reached)" }
	end

	-- Mark code as used BEFORE applying reward (atomic — survives server-hop)
	pcall(function()
		codeStore:SetAsync(usedKey, true)
	end)
	if not playerUsedCodes[userId] then
		playerUsedCodes[userId] = {}
	end
	playerUsedCodes[userId][codeName] = true

	-- Apply reward
	local rewardType = codeData.rewardType or "credits"
	local amount = codeData.amount or 0

	if rewardType == "credits" then
		playerWallet[requestingPlayer] = (playerWallet[requestingPlayer] or 0) + amount
		creditEvent:FireClient(requestingPlayer, playerWallet[requestingPlayer])
	elseif rewardType == "luck" then
		-- Temporary server luck boost — consistent with ProcessReceipt logic
		local duration = codeData.duration or 300
		local now = os.time()
		if serverLuckMult > 1 and serverLuckEndTime > now and amount < serverLuckMult then
			-- Current luck is better — only extend duration
			serverLuckEndTime = math.max(serverLuckEndTime, now + duration)
		else
			serverLuckMult = amount
			serverLuckEndTime = now + duration
		end
	end

	-- Increment global usage count
	pcall(function()
		codeStore:UpdateAsync("code_" .. codeName, function(old)
			if not old then return old end
			old.usedCount = (old.usedCount or 0) + 1
			return old
		end)
	end)

	return { success = true, message = "Redeemed! +" .. amount .. " " .. rewardType }
end

-- Client can pull rebirth requirements when ready
getRebirthInfoFunc.OnServerInvoke = function(player)
	local req = playerRebirthReq[player]
	if not req then
		req = initRebirthReq(player)
	end
	if req then
		local nextLvl = (playerRebirth[player] or 0) + 1
		local rarityText = getRebirthRarityText(nextLvl)
		return playerRebirth[player] or 0, req.brainrots, req.cost, rarityText
	else
		return playerRebirth[player] or 0, {}, 0, ""
	end
end

-- =====================
-- REBIRTH MULTIPLIER (needed by admin handlers below)
-- =====================

local function getEvoMult(player)
	local rebirths = playerRebirth[player] or 0
	return REBIRTH_MULT ^ rebirths
end

-- =====================
-- SPEED CONSTANTS (needed by admin handlers)
-- =====================
local BASE_WALK_SPEED      = 16
local SPEED_INCREMENT      = 1 / 100  -- +1% per second (100s = double speed)
local playerSpeedTime      = {}       -- tracks seconds spent in game

-- Speed cap per rebirth level: rebirth 0 = 10x, rebirth 1 = 20x, ... rebirth 9+ = 100x
local function getSpeedCap(player)
	local rebirth = playerRebirth[player] or 0
	local cap = math.min(10 + rebirth * 10, 100)
	return cap
end

-- =====================
-- ADMIN BINDABLE EVENTS
-- Listens for commands from AdminServer
-- =====================

-- Admin BindableFunctions (from RemoteSetup)
local adminSetCredits      = R.adminSetCredits
local adminAddCredits      = R.adminAddCredits
local adminSetRebirth      = R.adminSetRebirth
local adminGiveRebirth     = R.adminGiveRebirth
local adminSetSpeed        = R.adminSetSpeed
local adminSpawnBrainrot   = R.adminSpawnBrainrot
local adminSetLuck         = R.adminSetLuck

adminAddCredits.OnInvoke = function(player, amount)
	if not player or type(amount) ~= "number" then return false, "Invalid arguments" end
	amount = math.floor(amount)
	local prevCredits = playerWallet[player] or 0
	playerWallet[player] = prevCredits + amount
	creditEvent:FireClient(player, playerWallet[player])
	return true, nil, prevCredits
end

adminSetCredits.OnInvoke = function(player, amount)
	if not player or type(amount) ~= "number" then return false, "Invalid arguments" end
	amount = math.floor(math.max(0, amount))
	local prevCredits = playerWallet[player] or 0
	playerWallet[player] = amount
	creditEvent:FireClient(player, playerWallet[player])
	return true, nil, prevCredits
end

adminSetRebirth.OnInvoke = function(player, amount)
	if not player or type(amount) ~= "number" then return false, "Invalid arguments" end
	amount = math.floor(amount)
	if amount < 0 or amount > MAX_REBIRTHS then return false, "Rebirth must be 0-" .. MAX_REBIRTHS end
	local prevRebirth = playerRebirth[player] or 0
	playerRebirth[player] = amount
	local req = initRebirthReq(player)
	if req then
		local rarityText = getRebirthRarityText(amount + 1)
		rebirthInfoEvent:FireClient(player, amount, req.brainrots, req.cost, rarityText)
	else
		rebirthInfoEvent:FireClient(player, amount, {}, 0, "")
	end
	return true, nil, prevRebirth
end

adminGiveRebirth.OnInvoke = function(player)
	if not player then return false, "Invalid player" end
	local current = playerRebirth[player] or 0
	if current >= MAX_REBIRTHS then return false, "Max rebirth (" .. MAX_REBIRTHS .. ")" end
	local nextLvl = current + 1
	playerRebirth[player] = nextLvl
	local req = initRebirthReq(player)
	if req then
		local rarityText = getRebirthRarityText(nextLvl + 1)
		rebirthInfoEvent:FireClient(player, nextLvl, req.brainrots, req.cost, rarityText)
	else
		rebirthInfoEvent:FireClient(player, nextLvl, {}, 0, "")
	end
	rebirthResultEvent:FireClient(player, true, nextLvl, playerWallet[player] or 0)
	return true, nil, current
end

adminSetSpeed.OnInvoke = function(player, multiplier)
	if not player or type(multiplier) ~= "number" then return false, "Invalid arguments" end
	if multiplier <= 0 or multiplier > 100 then return false, "Multiplier must be between 0 and 100" end
	local rebirthMult = getEvoMult(player)
	local prevSpeedMult = 1 + (playerSpeedTime[player] or 0) * SPEED_INCREMENT
	local prevTotalMult = prevSpeedMult * rebirthMult
	local targetSpeedMult = multiplier / rebirthMult
	local newTime = math.max(0, (targetSpeedMult - 1) / SPEED_INCREMENT)
	playerSpeedTime[player] = newTime
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = BASE_WALK_SPEED * multiplier
		end
	end
	speedUpdateEvent:FireClient(player, multiplier)
	return true, nil, prevTotalMult
end

adminSetLuck.OnInvoke = function(mult, durationSeconds)
	if type(mult) ~= "number" or mult < 1 then return false, "Invalid multiplier" end
	local prevMult = serverLuckMult
	local prevRemaining = math.max(0, serverLuckEndTime - os.time())
	if mult <= 1 then
		-- Reset luck to off
		serverLuckMult = 1
		serverLuckEndTime = 0
		debugPrint("[LUCK] Admin reset luck to 1x (off)")
	else
		if type(durationSeconds) ~= "number" or durationSeconds <= 0 then return false, "Invalid duration" end
		serverLuckMult = mult
		serverLuckEndTime = os.time() + math.floor(durationSeconds)
		debugPrint("[LUCK] Admin set luck:", mult .. "x for", math.floor(durationSeconds), "seconds")
	end
	return true, nil, prevMult, prevRemaining
end

-- =====================
-- SPEED ACCELERATOR
-- =====================

local playerRebirthInfoSent = {}      -- tracks if rebirth info was sent to client
local lastSentSpeedMult    = {}      -- tracks last speed sent to client (throttle updates)

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
			local totalMult = math.min(speedMult * rebirthMult, getSpeedCap(p))
			humanoid.WalkSpeed = BASE_WALK_SPEED * totalMult

			-- Only fire speed update to client when the rounded value changes
			local rounded = math.floor(totalMult * 100 + 0.5) / 100
			if rounded ~= lastSentSpeedMult[p] then
				lastSentSpeedMult[p] = rounded
				speedUpdateEvent:FireClient(p, totalMult)
			end

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
	-- Apply server luck: boost rare spawn weights
	local currentLuckMult = 1
	if serverLuckMult > 1 and serverLuckEndTime > os.time() then
		currentLuckMult = serverLuckMult
	end

	local totalWeight = 0
	local weights = {}
	for _, r in ipairs(allowedRarities) do
		local w = RARITIES[r].spawnWeight
		-- Luck multiplier boosts rarer rarities (lower base weight = bigger boost)
		if currentLuckMult > 1 and w < 10 then
			w = w * currentLuckMult
		end
		weights[r] = w
		totalWeight += w
	end
	local roll       = math.random() * totalWeight
	local cumulative = 0
	for _, r in ipairs(allowedRarities) do
		cumulative += weights[r]
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
					debugWarn("[UPGRADE] playerSlots is nil for player")
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
					debugWarn("[UPGRADE] No brainrot in slot", capturedSlot, "| Filled slots:", table.concat(filled, ","))
					upgradeResultEvent:FireClient(capturedPlayer, false, "No brainrot in this slot!")
					return
				end
				if not slotUpgrades[capturedPlayer] then
					slotUpgrades[capturedPlayer] = {}
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
				local newLevel = level + 1
				slotUpgrades[capturedPlayer][capturedSlot] = newLevel
				updateUpgradeSign(capturedPlayer, capturedSlot)
				upgradeResultEvent:FireClient(
					capturedPlayer, true,
					capturedSlot,
					newLevel,
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

	debugPrint("Slots created for", player.Name, "at base", playerBaseIndex[player])
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
			-- Calculate bonus multiplier BEFORE the plate loop so plates show correct values
			local bonusMult = 1
			if playerGamepasses[player] then
				if playerGamepasses[player]["DOUBLE_MONEY"] then bonusMult = bonusMult * 2 end
				if playerGamepasses[player]["VIP"] then bonusMult = bonusMult * VALUE_MULTIPLIERS.VIP end
			end

			local totalEarned = 0
			for i = 1, BASE_SLOTS do
				if playerSlots[player][i] ~= nil then
					local rate = math.floor(getSlotEarnRate(player, i) * bonusMult)
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
			-- Sync leaderstats with current wallet/rebirth values
			local ls = player:FindFirstChild("leaderstats")
			if ls then
				local cv = ls:FindFirstChild("Credits")
				if cv then cv.Value = playerWallet[player] or 0 end
				local rv = ls:FindFirstChild("Rebirth")
				if rv then rv.Value = playerRebirth[player] or 0 end
			end
		end
	end
end)

-- =====================
-- SELL SYSTEM (with rate limiting)
-- =====================

sellEvent.OnServerEvent:Connect(function(player, slotIndex, isSelling)
	-- Rate limit check
	local now = os.clock()
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
		if (os.clock() - slotDepositTime[player][slotIndex]) < SELL_GRACE_PERIOD then
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
					debugWarn("[SELL] Destroying brainrot in slot", slotIndex, "name:", slot.block.Name)
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

-- Rebirth is now handled via the HUD button (RebirthRequested RemoteEvent)
-- No physical sign or click detector needed

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

-- Remove ALL brainrots from base (used on disconnect etc.)
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

-- Remove only the required brainrots (by rarity) for rebirth, keep the rest
local function consumeRebirthBrainrots(player, spec)
	if not playerSlots[player] or not spec then return end

	-- Build a remaining-need counter per rarity
	local needed = {}
	for _, group in ipairs(spec) do
		needed[group.rarity] = (needed[group.rarity] or 0) + group.count
	end

	-- Find brainrot rarity by name
	local function getBrainrotRarity(brainrotName)
		for _, b in ipairs(BRAINROTS) do
			if b.name == brainrotName then return b.rarity end
		end
		return nil
	end

	-- Pass 1: identify which slots to consume
	local slotsToRemove = {}
	for i = 1, BASE_SLOTS do
		local slot = playerSlots[player][i]
		if slot and slot.block and slot.block.Parent then
			local bName = slot.block:GetAttribute("BrainrotName") or slot.block.Name
			local rarity = getBrainrotRarity(bName)
			if rarity and needed[rarity] and needed[rarity] > 0 then
				table.insert(slotsToRemove, i)
				needed[rarity] = needed[rarity] - 1
			end
		end
	end

	-- Pass 2: destroy only the consumed slots
	for _, slotIndex in ipairs(slotsToRemove) do
		local slot = playerSlots[player][slotIndex]
		if slot and slot.block and slot.block.Parent then
			CollectionService:RemoveTag(slot.block, TAG_STORED_BRAINROT)
			slot.block:Destroy()
		end
		playerSlots[player][slotIndex] = nil
		if slotUpgrades[player] then slotUpgrades[player][slotIndex] = 0 end
		if creditPlates[player] and creditPlates[player][slotIndex] then
			creditPlates[player][slotIndex].credits = 0
			creditPlates[player][slotIndex].label.Text = ""
			if creditPlates[player][slotIndex].billboard then
				creditPlates[player][slotIndex].billboard.Enabled = false
			end
		end
		setSlotFilled(player, slotIndex, nil)
	end
end

local playerRebirthing = {} -- debounce lock to prevent double-rebirth exploit

local function processRebirth(clickingPlayer)
	-- Debounce: prevent multiple simultaneous rebirth requests
	if playerRebirthing[clickingPlayer] then return end
	playerRebirthing[clickingPlayer] = true

	local currentRebirth = playerRebirth[clickingPlayer] or 0
	if currentRebirth >= MAX_REBIRTHS then
		playerRebirthing[clickingPlayer] = nil
		rebirthResultEvent:FireClient(clickingPlayer, false, "Max rebirths reached! (10/10)")
		return
	end

	local req = playerRebirthReq[clickingPlayer]
	if not req then
		playerRebirthing[clickingPlayer] = nil
		rebirthResultEvent:FireClient(clickingPlayer, false, "No requirements found, try rejoining.")
		return
	end

	-- Check credits
	local wallet = playerWallet[clickingPlayer] or 0
	if wallet < req.cost then
		playerRebirthing[clickingPlayer] = nil
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
		playerRebirthing[clickingPlayer] = nil
		rebirthResultEvent:FireClient(clickingPlayer, false,
			"Missing: " .. table.concat(missing, ", "))
		return
	end

	-- All requirements met! Execute rebirth - only consume required brainrots
	playerWallet[clickingPlayer] = wallet - req.cost
	consumeRebirthBrainrots(clickingPlayer, req.spec)
	local nextLevel = currentRebirth + 1
	playerRebirth[clickingPlayer] = nextLevel

	-- Notify client
	rebirthResultEvent:FireClient(clickingPlayer, true, nextLevel, playerWallet[clickingPlayer])

	-- Set requirements for NEXT rebirth
	playerRebirthInfoSent[clickingPlayer] = false
	if nextLevel <= MAX_REBIRTHS then
		local nextReq = initRebirthReq(clickingPlayer)
		if nextReq then
			local rarityText = getRebirthRarityText(nextLevel + 1)
			rebirthInfoEvent:FireClient(clickingPlayer, nextLevel, nextReq.brainrots, nextReq.cost, rarityText)
		end
	else
		playerRebirthReq[clickingPlayer] = nil
		rebirthInfoEvent:FireClient(clickingPlayer, nextLevel, {}, 0, "")
	end

	playerRebirthing[clickingPlayer] = nil
end

-- RemoteEvent from client HUD button
rebirthRequestEvent.OnServerEvent:Connect(processRebirth)

-- Admin check is now handled exclusively by AdminServer.server.lua

-- =====================
-- PROMPT / NAME TAG
-- =====================

local function createPrompt(brainrot, brainrotDef, player, mutation)
	mutation = mutation or MUTATIONS.NONE
	local rarity      = brainrotDef and brainrotDef.rarity or "COMMON"
	local rarityColor = RARITY_LABEL_COLORS[rarity] or Color3.fromRGB(255, 255, 255)

	local attachTo = brainrot
	if brainrot:IsA("Model") then
		attachTo = brainrot.PrimaryPart or brainrot:FindFirstChildWhichIsA("BasePart")
	end
	if not attachTo then return end

	-- Read earn rate from attribute (set before createPrompt is called)
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

	-- ── Mutation badge (colored bar on top) ──
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

	-- ── Main info box (Name, Rarity, Credits/sec) ──
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

	-- ── [E] pickup indicator ──
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

	-- Track collection
	local bName = brainrot:GetAttribute("BrainrotName") or brainrot.Name
	local mutation = brainrot:GetAttribute("Mutation") or "NONE"
	if not playerCollection[player] then playerCollection[player] = {} end
	local key = bName .. ":" .. mutation
	if not playerCollection[player][key] then
		playerCollection[player][key] = true
		collectionUpdateEvent:FireClient(player, key)
	end

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
		debugWarn("[DETACH] Destroying carried brainrot:", brainrot.Name)
		CollectionService:RemoveTag(brainrot, TAG_SPAWNED_BRAINROT)
		brainrot:Destroy()
	end
	carriedBrainrots[player] = nil
end

local function spawnBrainrotInZone(zoneIndex)
	local zone = ZONES[zoneIndex]
	if getZoneActiveCount(zoneIndex) >= zone.cap then return end

	local rarity      = pickRarity(zone.rarities)
	local brainrotDef = pickBrainrotFromRarity(rarity)
	if not brainrotDef then return end

	local spawnPos = getRandomPositionInZone(zone)
	local brainrot
	local parentFolder = spawnFolders[zoneIndex]

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

	-- Roll mutation and apply both rarity and mutation multipliers
	local mutation, mutationKey = getMutation(nil)
	local mutationMult = mutation.mult or 1
	local earnRate = brainrotDef.baseEarn * RARITIES[rarity].mult * mutationMult

	if brainrot:IsA("Model") then
		brainrot:SetAttribute("EarnRate",     earnRate)
		brainrot:SetAttribute("Rarity",       rarity)
		brainrot:SetAttribute("BrainrotName", brainrotDef.name)
		brainrot:SetAttribute("Mutation",     mutationKey)
		if brainrot.PrimaryPart then
			brainrot.PrimaryPart:SetAttribute("EarnRate",     earnRate)
			brainrot.PrimaryPart:SetAttribute("Rarity",       rarity)
			brainrot.PrimaryPart:SetAttribute("BrainrotName", brainrotDef.name)
			brainrot.PrimaryPart:SetAttribute("Mutation",     mutationKey)
		end
	else
		brainrot:SetAttribute("EarnRate",     earnRate)
		brainrot:SetAttribute("Rarity",       rarity)
		brainrot:SetAttribute("BrainrotName", brainrotDef.name)
		brainrot:SetAttribute("Mutation",     mutationKey)
	end

	-- Tag for CollectionService-based detection
	CollectionService:AddTag(brainrot, TAG_SPAWNED_BRAINROT)

	createPrompt(brainrot, brainrotDef, nil, mutation)
	-- Zone count is now derived from CollectionService tags (no manual increment needed)

	-- Notify all players about the new spawn
	local spawnName = brainrotDef and brainrotDef.name or "Brainrot"
	local spawnRarity = rarity or "COMMON"
	spawnNotifyEvent:FireAllClients(spawnName, spawnRarity, zoneIndex, mutationKey)

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
			debugWarn("[DESPAWN] Destroying", brainrot.Name, "parent:", brainrot.Parent.Name)
			CollectionService:RemoveTag(brainrot, TAG_SPAWNED_BRAINROT)
			brainrot:Destroy()
			-- Zone count is derived from CollectionService tags (no manual decrement needed)
		end
	end)
end

-- Admin spawn: spawn a specific brainrot by name in a random zone
-- mutationKey can be "NONE", "GOLD", "DIAMOND", "RAINBOW" or nil (random roll)
adminSpawnBrainrot.OnInvoke = function(brainrotName, mutationKey)
	if type(brainrotName) ~= "string" or #brainrotName == 0 then
		return false, "Invalid brainrot name"
	end

	-- Find the brainrot definition
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

	if not targetZone then
		-- Fallback: spawn in zone 1 regardless of rarity match
		targetZone = 1
	end

	local zone = ZONES[targetZone]
	local rarity = brainrotDef.rarity
	local spawnPos = getRandomPositionInZone(zone)
	local parentFolder = spawnFolders[targetZone]

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
						part.Anchored = true
						part.CanCollide = false
					end
				end
			else
				brainrot.Position = spawnPos
				brainrot.Anchored = true
				brainrot.CanCollide = false
			end
			brainrot.Parent = parentFolder
		end
	end

	if not brainrot then
		brainrot = Instance.new("Part")
		brainrot.Name = "Brainrot"
		brainrot.Size = Vector3.new(2, 2, 2)
		brainrot.Position = spawnPos
		brainrot.BrickColor = RARITY_COLORS[rarity]
		brainrot.Material = Enum.Material.Neon
		brainrot.Anchored = true
		brainrot.CanCollide = false
		brainrot.Parent = parentFolder
	end

	-- Determine mutation: use forced key from admin or roll randomly
	local mutation
	if mutationKey and mutationKey ~= "" and MUTATIONS[mutationKey] then
		mutation = MUTATIONS[mutationKey]
	else
		mutation, mutationKey = getMutation(nil)
	end

	local mutationMult = mutation.mult or 1
	local earnRate = brainrotDef.baseEarn * RARITIES[rarity].mult * mutationMult
	if brainrot:IsA("Model") then
		brainrot:SetAttribute("EarnRate", earnRate)
		brainrot:SetAttribute("Rarity", rarity)
		brainrot:SetAttribute("BrainrotName", brainrotDef.name)
		brainrot:SetAttribute("Mutation", mutationKey)
		if brainrot.PrimaryPart then
			brainrot.PrimaryPart:SetAttribute("EarnRate", earnRate)
			brainrot.PrimaryPart:SetAttribute("Rarity", rarity)
			brainrot.PrimaryPart:SetAttribute("BrainrotName", brainrotDef.name)
			brainrot.PrimaryPart:SetAttribute("Mutation", mutationKey)
		end
	else
		brainrot:SetAttribute("EarnRate", earnRate)
		brainrot:SetAttribute("Rarity", rarity)
		brainrot:SetAttribute("BrainrotName", brainrotDef.name)
		brainrot:SetAttribute("Mutation", mutationKey)
	end

	CollectionService:AddTag(brainrot, TAG_SPAWNED_BRAINROT)
	createPrompt(brainrot, brainrotDef, nil, mutation)

	spawnNotifyEvent:FireAllClients(brainrotDef.name, rarity, targetZone, mutationKey)

	-- Auto-despawn after DESPAWN_TIME
	task.delay(DESPAWN_TIME, function()
		if brainrot and brainrot.Parent and CollectionService:HasTag(brainrot, TAG_SPAWNED_BRAINROT) then
			for _, carried in pairs(carriedBrainrots) do
				if carried == brainrot then return end
			end
			task.wait(0.5)
			if brainrot and brainrot.Parent and CollectionService:HasTag(brainrot, TAG_SPAWNED_BRAINROT) then
				for _, carried in pairs(carriedBrainrots) do
					if carried == brainrot then return end
				end
				CollectionService:RemoveTag(brainrot, TAG_SPAWNED_BRAINROT)
				brainrot:Destroy()
			end
		end
	end)

	return true, nil, targetZone
end

for zoneIndex, zone in ipairs(ZONES) do
	for _, rarity in ipairs(zone.rarities) do
		local interval = RARITIES[rarity].spawnInterval
		task.spawn(function()
			while true do
				task.wait(interval)
				if getZoneActiveCount(zoneIndex) < zone.cap then
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
		debugWarn("[DEPOSIT] brainrot is NIL for slot", freeSlot)
	elseif not brainrot.Parent then
		debugWarn("[DEPOSIT] brainrot DESTROYED before deposit for slot", freeSlot, brainrot.ClassName, brainrot.Name)
	else
		debugPrint("[DEPOSIT] Slot", freeSlot, "class:", brainrot.ClassName, "name:", brainrot.Name)
	end

	-- Scale factor for slot display (shrink brainrots to fit neatly in slots)
	local SLOT_SCALE = 0.5

	if brainrot and brainrot.Parent and brainrot:IsA("Model") then
		-- Re-find PrimaryPart if it was lost during carry
		if not brainrot.PrimaryPart then
			local firstPart = brainrot:FindFirstChildWhichIsA("BasePart")
			if firstPart then brainrot.PrimaryPart = firstPart end
		end
		carriedBrainrots[player] = nil
		playerHasPickup[player]  = false
		-- Scale down all parts in the model
		for _, part in ipairs(brainrot:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size       = part.Size * SLOT_SCALE
				part.Anchored   = true
				part.CanCollide = false
			end
		end
		-- Remove the pickup prompt billboard so it doesn't overlap slot UI
		local prompt = brainrot:FindFirstChild("PickupPrompt", true)
		if prompt then prompt:Destroy() end
		-- Slots 1-5 (front row) face the wrong direction; rotate 180° around Y
		local placeCFrame = CFrame.new(slotPad.Position + Vector3.new(0, 1.5, 0))
		if freeSlot <= 5 then
			placeCFrame = placeCFrame * CFrame.Angles(0, math.rad(180), 0)
		end
		brainrot:PivotTo(placeCFrame)
		brainrot.Parent = storedFolder
		storedBlock = brainrot
		debugPrint("[DEPOSIT] Model path OK for slot", freeSlot, "(scaled to", SLOT_SCALE, ")")
	elseif brainrot and brainrot.Parent and brainrot:IsA("BasePart") then
		-- Reuse the original part (preserves MeshParts / SpecialMesh children)
		carriedBrainrots[player] = nil
		playerHasPickup[player]  = false
		brainrot.Size       = brainrot.Size * SLOT_SCALE
		brainrot.Anchored   = true
		brainrot.CanCollide = false
		brainrot.Position   = slotPad.Position + Vector3.new(0, 1.5, 0)
		-- Remove the pickup prompt billboard so it doesn't overlap slot UI
		local prompt = brainrot:FindFirstChild("PickupPrompt")
		if prompt then prompt:Destroy() end
		brainrot.Parent = storedFolder
		storedBlock = brainrot
		debugPrint("[DEPOSIT] BasePart path OK for slot", freeSlot, "(scaled to", SLOT_SCALE, ")")
	else
		debugWarn("[DEPOSIT] FALLBACK (block) for slot", freeSlot, "brainrot:", brainrot and brainrot.Name or "nil")
		carriedBrainrots[player] = nil
		playerHasPickup[player]  = false
		if brainrot and brainrot.Parent then brainrot:Destroy() end
		storedBlock = Instance.new("Part")
		storedBlock.Name       = "StoredBrainrot"
		storedBlock.Size       = Vector3.new(1.5 * SLOT_SCALE, 1.5 * SLOT_SCALE, 1.5 * SLOT_SCALE)
		storedBlock.BrickColor = color
		storedBlock.Material   = Enum.Material.Neon
		storedBlock.Anchored   = true
		storedBlock.CanCollide = false
		storedBlock.Position   = slotPad.Position + Vector3.new(0, 1.5, 0)
		storedBlock.Parent     = storedFolder
	end

	if not storedBlock then
		warn("[DEPOSIT] storedBlock is nil after deposit paths for slot", freeSlot, "player:", player.Name)
		return
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
			debugWarn("[STORED-DESTROYED] Slot", watchSlot, "name:", watchBlock.Name, "class:", watchBlock.ClassName)
			if DEBUG then warn(debug.traceback()) end
		end
	end)

	if not slotDepositTime[player] then slotDepositTime[player] = {} end
	slotDepositTime[player][freeSlot] = os.clock()
	playerSlots[player][freeSlot] = { color = color, block = storedBlock, earnRate = earnRate }
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

-- Server-side: find closest spawned brainrot to the player (secure - no client Instance trust)
local function findClosestSpawnedBrainrot(player)
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local closest = nil
	local closestDist = PICKUP_DISTANCE

	for _, obj in ipairs(CollectionService:GetTagged(TAG_SPAWNED_BRAINROT)) do
		local pos = nil
		if obj:IsA("Model") then
			local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if primary then pos = primary.Position end
		elseif obj:IsA("BasePart") then
			pos = obj.Position
		end
		if pos then
			local dist = (root.Position - pos).Magnitude
			if dist < closestDist then
				closestDist = dist
				closest = obj
			end
		end
	end

	return closest
end

remoteEvent.OnServerEvent:Connect(function(player, _clientRef, isHolding)
	-- Rate limit check
	local now = os.clock()
	if isHolding then
		if lastPickupTime[player] and (now - lastPickupTime[player]) < PICKUP_COOLDOWN then
			return
		end
		lastPickupTime[player] = now
	end

	if playerHolding[player] and isHolding then return end
	if playerHasPickup[player] then return end

	-- Server finds the closest brainrot instead of trusting client Instance
	local brainrot = findClosestSpawnedBrainrot(player)
	if not brainrot then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local checkPart = getPrimaryPart(brainrot)
	if not checkPart then return end

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

					-- Zone count is derived from CollectionService tags
				-- (tag was already removed at pickup start, so count is already correct)

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

local allTimeStore, playerDataStore
pcall(function()
	allTimeStore = DataStoreService:GetDataStore("AllTimeEarnings_v1")
	playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
end)
if not allTimeStore or not playerDataStore then
	warn("[BrainrotSpawnEngine] DataStore unavailable - player data will NOT persist this session")
end

-- =====================
-- PLAYER DATA PERSISTENCE
-- =====================

local function savePlayerData(player)
	local data = {
		wallet     = playerWallet[player] or 0,
		speedTime  = playerSpeedTime[player] or 0,
		rebirth    = playerRebirth[player] or 0,
		credits    = playerCredits[player] or 0,
		slots      = {},
		upgrades   = {},
		plateCredits = {},
	}

	-- Save slot data (brainrot name, rarity, earnRate, accumulated plate credits)
	if playerSlots[player] then
		for i = 1, BASE_SLOTS do
			local slot = playerSlots[player][i]
			if slot and slot.block and slot.block.Parent then
				local bName = slot.block:GetAttribute("BrainrotName") or slot.block.Name
				local rarity = slot.block:GetAttribute("Rarity") or "COMMON"
				local earnRate = slot.block:GetAttribute("EarnRate") or (slot.earnRate or 1)
				data.slots[tostring(i)] = {
					name     = bName,
					rarity   = rarity,
					earnRate = earnRate,
				}
			end
		end
	end

	-- Save slot upgrades
	if slotUpgrades[player] then
		for i = 1, BASE_SLOTS do
			data.upgrades[tostring(i)] = slotUpgrades[player][i] or 0
		end
	end

	-- Save accumulated credit plate credits
	if creditPlates[player] then
		for i = 1, BASE_SLOTS do
			if creditPlates[player][i] then
				data.plateCredits[tostring(i)] = creditPlates[player][i].credits or 0
			end
		end
	end

	-- Save collection
	local collList = {}
	if playerCollection[player] then
		for key in pairs(playerCollection[player]) do
			table.insert(collList, key)
		end
	end
	data.collection = collList

	-- Save used codes so players can't redeem the same code across servers
	local usedCodesList = {}
	if playerUsedCodes[player.UserId] then
		for codeName in pairs(playerUsedCodes[player.UserId]) do
			table.insert(usedCodesList, codeName)
		end
	end
	data.usedCodes = usedCodesList

	-- Use UpdateAsync to prevent race conditions on rapid server hops
	local ok, err = pcall(function()
		playerDataStore:UpdateAsync("player_" .. player.UserId, function(_oldData)
			return data
		end)
	end)
	if not ok then
		warn("[SAVE] Failed to save data for", player.Name, ":", err)
	else
		debugPrint("[SAVE] Saved data for", player.Name)
	end
end

local function loadPlayerData(player)
	local ok, data = pcall(function()
		return playerDataStore:GetAsync("player_" .. player.UserId)
	end)
	if not ok or not data then
		return nil
	end
	debugPrint("[LOAD] Loaded data for", player.Name)
	return data
end

-- Restore a brainrot model into a slot from saved data
local function restoreBrainrotToSlot(player, slotIndex, savedSlot)
	local slotPad = slotParts[player] and slotParts[player][slotIndex]
	if not slotPad then return false end

	local brainrotDef = nil
	for _, b in ipairs(BRAINROTS) do
		if b.name == savedSlot.name then
			brainrotDef = b
			break
		end
	end

	local storedBlock
	local rarity = savedSlot.rarity or "COMMON"
	local color = RARITY_COLORS[rarity] or RARITY_COLORS["COMMON"]
	local earnRate = savedSlot.earnRate or 1

	-- Try to clone the model from ReplicatedStorage
	if brainrotDef and (brainrotDef.modelName or brainrotDef.name) then
		local template = ReplicatedStorage:FindFirstChild(brainrotDef.modelName or brainrotDef.name)
		if template then
			storedBlock = template:Clone()
			if storedBlock:IsA("Model") then
				if not storedBlock.PrimaryPart then
					local firstPart = storedBlock:FindFirstChildWhichIsA("BasePart")
					if firstPart then storedBlock.PrimaryPart = firstPart end
				end
				-- Slots 1-5 (front row) face the wrong direction; rotate 180° around Y
				local placeCFrame = CFrame.new(slotPad.Position + Vector3.new(0, 2, 0))
				if slotIndex <= 5 then
					placeCFrame = placeCFrame * CFrame.Angles(0, math.rad(180), 0)
				end
				storedBlock:PivotTo(placeCFrame)
				for _, part in ipairs(storedBlock:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored   = true
						part.CanCollide = false
					end
				end
			else
				storedBlock.Position   = slotPad.Position + Vector3.new(0, 1.5, 0)
				storedBlock.Anchored   = true
				storedBlock.CanCollide = false
			end
			storedBlock.Parent = storedFolder
		end
	end

	-- Fallback: create a colored block
	if not storedBlock then
		storedBlock = Instance.new("Part")
		storedBlock.Name       = savedSlot.name or "StoredBrainrot"
		storedBlock.Size       = Vector3.new(2, 2, 2)
		storedBlock.BrickColor = color
		storedBlock.Material   = Enum.Material.Neon
		storedBlock.Anchored   = true
		storedBlock.CanCollide = false
		storedBlock.Position   = slotPad.Position + Vector3.new(0, 1.5, 0)
		storedBlock.Parent     = storedFolder
	end

	-- Set attributes
	storedBlock:SetAttribute("BrainrotName", savedSlot.name)
	storedBlock:SetAttribute("Rarity", rarity)
	storedBlock:SetAttribute("EarnRate", earnRate)
	storedBlock:SetAttribute("OwnerUserId", player.UserId)
	storedBlock:SetAttribute("SlotIndex", slotIndex)
	if storedBlock:IsA("Model") and storedBlock.PrimaryPart then
		storedBlock.PrimaryPart:SetAttribute("BrainrotName", savedSlot.name)
		storedBlock.PrimaryPart:SetAttribute("Rarity", rarity)
		storedBlock.PrimaryPart:SetAttribute("EarnRate", earnRate)
	end

	CollectionService:AddTag(storedBlock, TAG_STORED_BRAINROT)

	playerSlots[player][slotIndex] = { color = color, block = storedBlock, earnRate = earnRate }
	setSlotFilled(player, slotIndex, color)

	return true
end

-- LeaderboardWall: Pos (-51, 12, 4.5), Size (2, 22, 59), Orientation (0, -180, 0)
-- Players approach from +X side, so boards go on the +X face
local WALL_CENTER = Vector3.new(-51, 12, 4.5)
local BOARD_X     = WALL_CENTER.X + 1.2  -- flush with +X face (towards houses)

local function createLedBoard(posX, posY, posZ, title)
	local board = Instance.new("Part")
	board.Name        = title .. "Board"
	board.Size        = Vector3.new(0.3, 20, 27)
	board.Position    = Vector3.new(posX, posY, posZ)
	board.Anchored    = true
	board.CanCollide  = false
	board.BrickColor  = BrickColor.new("Really black")
	board.Material    = Enum.Material.SmoothPlastic
	board.Parent      = workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face           = Enum.NormalId.Right
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

-- Place boards on the LeaderboardWall, side by side (wall is 59 studs wide on Z)
local allTimeRows = createLedBoard(BOARD_X, WALL_CENTER.Y, WALL_CENTER.Z - 14.5, "ALL TIME")
local sessionRows = createLedBoard(BOARD_X, WALL_CENTER.Y, WALL_CENTER.Z + 14.5, "THIS SESSION")

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
		local isVIP = playerGamepasses[p] and playerGamepasses[p]["VIP"]
		local displayName = isVIP and ("\u{1F451} " .. p.Name) or p.Name
		table.insert(entries, {
			name  = displayName,
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
			local displayName = allTimeCache[i].name
			if allTimeCache[i].vip then
				displayName = "\u{1F451} " .. displayName
			end
			row.name.Text  = displayName
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

	local isVIP = playerGamepasses[player] and playerGamepasses[player]["VIP"] or false

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
					entry.vip = isVIP  -- always update VIP status
					found = true
					break
				end
			end
			if not found then
				table.insert(entries, {
					userId = player.UserId,
					name   = player.Name,
					score  = totalEarned,
					vip    = isVIP,
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

	-- Load saved data (or start fresh)
	local savedData = loadPlayerData(player)

	playerCredits[player]          = savedData and savedData.credits or 0
	playerWallet[player]           = savedData and savedData.wallet or 0
	playerRebirth[player]          = savedData and savedData.rebirth or 0
	playerSpeedTime[player]        = savedData and savedData.speedTime or 0
	playerSlots[player]            = {}
	playerSelling[player]          = nil
	playerDepositing[player]       = false
	sessionEarnings[player.UserId] = 0
	slotUpgrades[player]           = {}
	lastSellTime[player]           = 0
	lastPickupTime[player]         = 0

	for i = 1, BASE_SLOTS do
		playerSlots[player][i]  = nil
		slotUpgrades[player][i] = savedData and savedData.upgrades
			and savedData.upgrades[tostring(i)] or 0
	end

	-- Create leaderstats for admin Members tab and Roblox leaderboard
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local creditsVal = Instance.new("IntValue")
	creditsVal.Name  = "Credits"
	creditsVal.Value = playerWallet[player] or 0
	creditsVal.Parent = ls
	local rebirthVal = Instance.new("IntValue")
	rebirthVal.Name  = "Rebirth"
	rebirthVal.Value = playerRebirth[player] or 0
	rebirthVal.Parent = ls

	createSlotParts(player)

	-- Restore saved brainrots into slots
	if savedData and savedData.slots then
		for slotStr, savedSlot in pairs(savedData.slots) do
			local slotIndex = tonumber(slotStr)
			if slotIndex and savedSlot and savedSlot.name then
				restoreBrainrotToSlot(player, slotIndex, savedSlot)
			end
		end
	end

	-- Restore accumulated credit plate credits
	if savedData and savedData.plateCredits then
		for slotStr, credits in pairs(savedData.plateCredits) do
			local slotIndex = tonumber(slotStr)
			if slotIndex and creditPlates[player] and creditPlates[player][slotIndex] then
				creditPlates[player][slotIndex].credits = credits
				if credits > 0 then
					creditPlates[player][slotIndex].label.Text = tostring(credits)
					if creditPlates[player][slotIndex].billboard then
						creditPlates[player][slotIndex].billboard.Enabled = true
					end
				end
			end
		end
	end

	-- Restore collection
	if savedData and savedData.collection then
		playerCollection[player] = {}
		for _, key in ipairs(savedData.collection) do
			playerCollection[player][key] = true
		end
	end

	-- Restore used codes so players can't redeem the same code across servers
	if savedData and savedData.usedCodes then
		playerUsedCodes[player.UserId] = {}
		for _, codeName in ipairs(savedData.usedCodes) do
			playerUsedCodes[player.UserId][codeName] = true
		end
	end

	-- Check gamepass ownership
	playerGamepasses[player] = {}
	for name, gpId in pairs(GAMEPASS_IDS) do
		if gpId > 0 then
			local gpOk, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gpId)
			end)
			if gpOk and owns then
				playerGamepasses[player][name] = true
			end
		end
	end

	-- Set VIP/Group attributes for client to read
	local discountInfo = getPlayerDiscountInfo(player)
	player:SetAttribute("Own_VIP", discountInfo.isVIP or false)
	player:SetAttribute("InGroup", discountInfo.inGroup or false)
	player:SetAttribute("DiscountRate", discountInfo.rate or 0)
	player:SetAttribute("DiscountLabel", discountInfo.label or "")

	startCreditTick(player)

	-- Add VIP crown above player head
	local function addVIPCrown(character)
		if not (playerGamepasses[player] and playerGamepasses[player]["VIP"]) then return end
		local head = character:WaitForChild("Head", 5)
		if not head then return end
		-- Remove existing crown if any (e.g. respawn)
		local existing = head:FindFirstChild("VIPCrown")
		if existing then existing:Destroy() end

		local crown = Instance.new("BillboardGui")
		crown.Name = "VIPCrown"
		crown.Size = UDim2.new(0, 80, 0, 70)
		crown.StudsOffset = Vector3.new(0, 2.5, 0)
		crown.AlwaysOnTop = true
		crown.MaxDistance = 50
		crown.Parent = head

		local crownLabel = Instance.new("TextLabel")
		crownLabel.Size = UDim2.new(1, 0, 0.65, 0)
		crownLabel.Position = UDim2.new(0, 0, 0, 0)
		crownLabel.BackgroundTransparency = 1
		crownLabel.Text = "\u{1F451}"
		crownLabel.TextScaled = true
		crownLabel.Font = Enum.Font.GothamBold
		crownLabel.Parent = crown

		local vipLabel = Instance.new("TextLabel")
		vipLabel.Size = UDim2.new(1, 0, 0.35, 0)
		vipLabel.Position = UDim2.new(0, 0, 0.65, 0)
		vipLabel.BackgroundTransparency = 1
		vipLabel.Text = "V.I.P"
		vipLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		vipLabel.TextStrokeTransparency = 0.3
		vipLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		vipLabel.TextScaled = true
		vipLabel.Font = Enum.Font.GothamBold
		vipLabel.Parent = crown
	end

	-- Initialize rebirth requirements
	local req = initRebirthReq(player)

	if savedData then
		debugPrint("[LOAD] Restored player", player.Name, "- wallet:", playerWallet[player],
			"rebirth:", playerRebirth[player], "speedTime:", playerSpeedTime[player])
	end

	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then return end
		local basePos = getPlayerBasePosition(player)
		if root and basePos then
			root.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
		end
		createSlotParts(player)
		addVIPCrown(character)

		-- Send rebirth info and wallet sync after character loads
		task.delay(2, function()
			if not player.Parent then return end -- player left
			local req = playerRebirthReq[player]
			if req then
				local nextLvl = (playerRebirth[player] or 0) + 1
				local rarityText = getRebirthRarityText(nextLvl)
				rebirthInfoEvent:FireClient(player, playerRebirth[player] or 0, req.brainrots, req.cost, rarityText)
			end
			-- Sync wallet to client
			collectEvent:FireClient(player, 0, playerWallet[player] or 0)
		end)
	end)

	local character = player.Character
	if character then
		task.wait(1)
		if not player.Parent then return end -- player left during wait
		local root = character:FindFirstChild("HumanoidRootPart")
		local basePos = getPlayerBasePosition(player)
		if root and basePos then
			root.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
		end
		addVIPCrown(character)
		-- Send rebirth info and wallet sync for initial join
		task.delay(2, function()
			if not player.Parent then return end -- player left
			local req = playerRebirthReq[player]
			if req then
				local nextLvl = (playerRebirth[player] or 0) + 1
				local rarityText = getRebirthRarityText(nextLvl)
				rebirthInfoEvent:FireClient(player, playerRebirth[player] or 0, req.brainrots, req.cost, rarityText)
			end
			collectEvent:FireClient(player, 0, playerWallet[player] or 0)
		end)
	end

	-- Admin status is now sent by AdminServer.server.lua
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	-- Save player data before cleanup
	savePlayerData(player)

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
	playerCollection[player] = nil
	playerGamepasses[player] = nil
	playerUsedCodes[player.UserId] = nil
	playerRebirthing[player] = nil
	lastSentSpeedMult[player] = nil
	playerRebirthInfoSent[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Save all player data on server shutdown
-- Save all players concurrently on shutdown (BindToClose has 30s timeout)
game:BindToClose(function()
	local players = Players:GetPlayers()
	if #players == 0 then return end

	local finished = 0
	for _, p in ipairs(players) do
		task.spawn(function()
			savePlayerData(p)
			finished = finished + 1
		end)
	end

	-- Wait until all saves complete or timeout approaches
	local waitStart = os.clock()
	while finished < #players and (os.clock() - waitStart) < 25 do
		task.wait(0.1)
	end
end)

-- =====================
-- PROCESS RECEIPT (Developer Products: Server Luck)
-- =====================

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local player = Players:GetPlayerByUserId(playerId)

	-- Get multiplier for VIP/Group bonus
	local multiplier = 1.0
	if player then
		multiplier = getPlayerMultiplier(player)
	end

	-- Check if this is a luck product
	for _, luckProduct in ipairs(LUCK_PRODUCT_IDS) do
		if luckProduct.id > 0 and productId == luckProduct.id then
			-- Apply server luck boost (multiplier extends duration for VIP/Group)
			-- Never downgrade: only apply if new mult >= current active mult
			local finalDuration = math.floor(luckProduct.duration * multiplier)
			local now = os.time()
			if serverLuckMult > 1 and serverLuckEndTime > now and luckProduct.mult < serverLuckMult then
				-- Current luck is better — extend the current luck's duration instead
				serverLuckEndTime = math.max(serverLuckEndTime, now + finalDuration)
			else
				serverLuckMult = luckProduct.mult
				serverLuckEndTime = now + finalDuration
			end
			debugPrint("[STORE] Server Luck activated:", luckProduct.mult .. "x for", finalDuration, "seconds by player", playerId, "(multiplier:", multiplier .. ")")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	-- Unknown product
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- =====================
-- GAMEPASS PURCHASE LISTENER
-- =====================

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(thePlayer, gamePassId, wasPurchased)
	if wasPurchased then
		for name, gpId in pairs(GAMEPASS_IDS) do
			if gpId == gamePassId then
				if not playerGamepasses[thePlayer] then
					playerGamepasses[thePlayer] = {}
				end
				playerGamepasses[thePlayer][name] = true
				debugPrint("[STORE] Player", thePlayer.Name, "purchased gamepass:", name)
				break
			end
		end
	end
end)
