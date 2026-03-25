-- =============================================
-- RemoteSetup.lua (ModuleScript)
-- Creates all RemoteEvents, RemoteFunctions,
-- and BindableFunctions used by the game.
-- Returns a table of references.
-- =============================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteSetup = {}

function RemoteSetup.init()
	-- Helper: create or find a RemoteEvent
	local function getOrCreateRemote(name)
		local r = ReplicatedStorage:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = ReplicatedStorage
		end
		return r
	end

	-- Helper: create or find a RemoteFunction
	local function getOrCreateRemoteFunction(name)
		local r = ReplicatedStorage:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = ReplicatedStorage
		end
		return r
	end

	-- Helper: create or find a BindableFunction
	local function getOrCreateBindable(name)
		local b = ServerScriptService:FindFirstChild(name)
		if not b then
			b = Instance.new("BindableFunction")
			b.Name = name
			b.Parent = ServerScriptService
		end
		return b
	end

	-- =====================
	-- REMOTE EVENTS
	-- =====================
	local remotes = {
		-- Pickup / carry
		pickupEvent      = getOrCreateRemote("BrainrotPickup"),
		progressEvent    = getOrCreateRemote("BrainrotProgress"),
		depositEvent     = getOrCreateRemote("BrainrotDeposited"),

		-- Economy
		creditEvent      = getOrCreateRemote("CreditUpdate"),
		collectEvent     = getOrCreateRemote("CreditsCollected"),
		upgradeResult    = getOrCreateRemote("UpgradeResult"),

		-- Sell
		sellEvent        = getOrCreateRemote("SellRequested"),
		sellProgress     = getOrCreateRemote("SellProgress"),
		sellResult       = getOrCreateRemote("SellResult"),

		-- Speed / rebirth
		speedUpdate      = getOrCreateRemote("SpeedUpdate"),
		rebirthResult    = getOrCreateRemote("RebirthResult"),
		rebirthInfo      = getOrCreateRemote("RebirthInfo"),
		rebirthRequest   = getOrCreateRemote("RebirthRequested"),

		-- Spawn notifications
		spawnNotify      = getOrCreateRemote("SpawnNotify"),

		-- Admin
		adminCheck       = getOrCreateRemote("AdminCheck"),

		-- Collection
		collectionUpdate = getOrCreateRemote("CollectionUpdate"),

		-- Handbrake
		handbrakeEvent   = getOrCreateRemote("HandbrakeEvent"),

		-- =====================
		-- REMOTE FUNCTIONS
		-- =====================
		getRebirthInfo   = getOrCreateRemoteFunction("GetRebirthInfo"),
		getCollection    = getOrCreateRemoteFunction("GetCollection"),
		getGamepassStatus = getOrCreateRemoteFunction("GetGamepassStatus"),
		redeemCode       = getOrCreateRemoteFunction("RedeemCode"),
		getServerLuck    = getOrCreateRemoteFunction("GetServerLuck"),
		getDiscountInfo  = getOrCreateRemoteFunction("GetDiscountInfo"),

		-- =====================
		-- BINDABLE FUNCTIONS (for AdminServer communication)
		-- =====================
		adminSetCredits    = getOrCreateBindable("AdminSetCredits"),
		adminAddCredits    = getOrCreateBindable("AdminAddCredits"),
		adminSetRebirth    = getOrCreateBindable("AdminSetRebirth"),
		adminGiveRebirth   = getOrCreateBindable("AdminGiveRebirth"),
		adminSetSpeed      = getOrCreateBindable("AdminSetSpeed"),
		adminSpawnBrainrot = getOrCreateBindable("AdminSpawnBrainrot"),
		adminSetLuck       = getOrCreateBindable("AdminSetLuck"),
		adminGrantVIP      = getOrCreateBindable("AdminGrantVIP"),
	}

	return remotes
end

return RemoteSetup
