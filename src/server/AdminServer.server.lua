-- =============================================
-- AdminServer.lua (ServerScript)
-- Main server script for the admin panel.
-- Handles all admin commands with security.
-- Placed in ServerScriptService.
-- =============================================

-- Set to true to enable verbose debug prints
local DEBUG = false
local function debugPrint(...)
	if DEBUG then print(...) end
end

-- Count entries in a dictionary-style table (no # operator for non-arrays)
local function tableCount(t)
	local c = 0
	for _ in pairs(t) do c = c + 1 end
	return c
end

debugPrint("[ADMIN SERVER] ====== AdminServer.lua starting ======")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ServerScriptService = game:GetService("ServerScriptService")

-- BindableFunctions fetched asynchronously so we don't block startup
local adminAddCredits      = nil
local adminSetCredits      = nil
local adminSetRebirth      = nil
local adminGiveRebirth     = nil
local adminSetSpeed        = nil
local adminSpawnBrainrot   = nil
local adminSetLuck         = nil

task.spawn(function()
	adminAddCredits      = ServerScriptService:WaitForChild("AdminAddCredits", 30)
	adminSetCredits      = ServerScriptService:WaitForChild("AdminSetCredits", 30)
	adminSetRebirth      = ServerScriptService:WaitForChild("AdminSetRebirth", 30)
	adminGiveRebirth     = ServerScriptService:WaitForChild("AdminGiveRebirth", 30)
	adminSetSpeed        = ServerScriptService:WaitForChild("AdminSetSpeed", 30)
	adminSpawnBrainrot   = ServerScriptService:WaitForChild("AdminSpawnBrainrot", 30)
	adminSetLuck         = ServerScriptService:WaitForChild("AdminSetLuck", 30)
	debugPrint("[ADMIN SERVER] BindableFunctions loaded:",
		adminAddCredits ~= nil, adminSetCredits ~= nil,
		adminSetRebirth ~= nil, adminGiveRebirth ~= nil,
		adminSetSpeed ~= nil, adminSpawnBrainrot ~= nil,
		adminSetLuck ~= nil)
end)

-- =====================
-- WHITELIST (hardcoded owners who are always admin)
-- =====================
local OWNER_IDS = {
	[8327644091] = true, -- Simpleson716
}

-- Unique counter for log keys to avoid collisions
local logCounter = 0

-- Runtime admin list (loaded from DataStore + owners)
local ADMINS = {}
for id in pairs(OWNER_IDS) do
	ADMINS[id] = true
end

-- Persistent admin storage
local adminStore = nil
pcall(function()
	adminStore = DataStoreService:GetDataStore("AdminList")
end)

local function loadAdminList()
	if not adminStore then
		warn("[ADMIN] adminStore is nil - DataStore not available (enable API access in Game Settings)")
		return
	end
	local ok, data = pcall(function()
		return adminStore:GetAsync("Admins")
	end)
	if ok and data and type(data) == "table" then
		for _, userId in ipairs(data) do
			ADMINS[userId] = true
		end
		debugPrint("[ADMIN] Loaded", #data, "admins from DataStore")
	elseif not ok then
		warn("[ADMIN] Failed to load admin list:", tostring(data))
	else
		debugPrint("[ADMIN] No saved admin list found (first run)")
	end
end

local function saveAdminList()
	if not adminStore then
		warn("[ADMIN] Cannot save - adminStore is nil")
		return
	end
	task.spawn(function()
		local list = {}
		for userId in pairs(ADMINS) do
			table.insert(list, userId)
		end
		local ok, err = pcall(function()
			adminStore:UpdateAsync("Admins", function(_old) return list end)
		end)
		if ok then
			debugPrint("[ADMIN] Saved admin list:", #list, "admins")
		else
			warn("[ADMIN] Failed to save admin list:", tostring(err))
		end
	end)
end

loadAdminList()

-- =====================
-- RATE LIMITING
-- =====================
local COOLDOWN_TIME = 0.5 -- seconds between commands
local lastCommandTime = {} -- [UserId] = os.clock()

local function checkCooldown(player)
	local now = os.clock()
	local last = lastCommandTime[player.UserId] or 0
	if now - last < COOLDOWN_TIME then
		return false
	end
	lastCommandTime[player.UserId] = now
	return true
end

-- =====================
-- ADMIN LOGGING (DataStore)
-- =====================
local adminLogStore = nil
pcall(function()
	adminLogStore = DataStoreService:GetDataStore("AdminLog")
end)

local function logAction(player, cmd, target, details)
	local entry = {
		admin = player.Name,
		adminId = player.UserId,
		command = cmd,
		target = target or "",
		details = details or "",
		timestamp = os.time(),
	}
	debugPrint(string.format("[ADMIN] %s (%d) -> %s | target: %s | %s",
		player.Name, player.UserId, cmd, target or "N/A", details or ""))

	-- Save to DataStore asynchronously
	if adminLogStore then
		task.spawn(function()
			pcall(function()
				logCounter = logCounter + 1
				local key = "log_" .. tostring(os.time()) .. "_" .. tostring(player.UserId) .. "_" .. tostring(logCounter)
				adminLogStore:SetAsync(key, entry)
			end)
		end)
	end
end

-- =====================
-- HELPER FUNCTIONS
-- =====================

--- Find a player by name or display name
local function findPlayer(name)
	if not name or type(name) ~= "string" or #name == 0 then
		return nil
	end
	local lowerName = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == lowerName or p.DisplayName:lower() == lowerName then
			return p
		end
	end
	-- Partial match as fallback
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(lowerName, 1, true) or
			p.DisplayName:lower():find(lowerName, 1, true) then
			return p
		end
	end
	return nil
end

--- Validate and sanitize string input
local function sanitizeString(str, maxLen)
	if type(str) ~= "string" then return nil end
	maxLen = maxLen or 50
	str = str:sub(1, maxLen)
	return str
end

--- Validate number input
local function sanitizeNumber(val)
	if type(val) == "string" then
		val = tonumber(val)
	end
	if type(val) ~= "number" or val ~= val then
		return nil
	end
	return val
end

-- =====================
-- BAN SYSTEM (global, persistent via DataStore)
-- =====================
local banStore = nil
pcall(function()
	banStore = DataStoreService:GetDataStore("BannedPlayers")
end)

-- Local cache of banned players (synced with DataStore)
local bannedPlayers = {} -- [UserId] = { name = "...", reason = "...", bannedBy = "...", timestamp = ... }

-- Load ban list from DataStore at startup
local function loadBanList()
	if not banStore then return end
	local ok, data = pcall(function()
		return banStore:GetAsync("BanList")
	end)
	if ok and data and type(data) == "table" then
		bannedPlayers = data
		debugPrint("[ADMIN] Loaded " .. tostring(tableCount(bannedPlayers)) .. " banned players")
	end
end

local function saveBanList()
	if not banStore then return end
	task.spawn(function()
		pcall(function()
			banStore:UpdateAsync("BanList", function(_old) return bannedPlayers end)
		end)
	end)
end

local function isPlayerBanned(userId)
	return bannedPlayers[tostring(userId)] ~= nil
end

local function banPlayer(targetUserId, targetName, reason, adminPlayer)
	local key = tostring(targetUserId)
	bannedPlayers[key] = {
		name = targetName,
		reason = reason or "No reason given",
		bannedBy = adminPlayer.Name,
		bannedById = adminPlayer.UserId,
		timestamp = os.time(),
	}
	saveBanList()

	-- Kick the player if they are online
	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		target:Kick("You have been banned: " .. (reason or "No reason given"))
	end

	-- Publish globally so other servers also kick
	pcall(function()
		local data = game:GetService("HttpService"):JSONEncode({
			cmd = "BanPlayer",
			args = { userId = targetUserId, name = targetName, reason = reason },
		})
		MessagingService:PublishAsync("AdminCommand", data)
	end)
end

local function unbanPlayer(targetUserId)
	local key = tostring(targetUserId)
	local entry = bannedPlayers[key]
	bannedPlayers[key] = nil
	saveBanList()

	-- Publish globally
	pcall(function()
		local data = game:GetService("HttpService"):JSONEncode({
			cmd = "UnbanPlayer",
			args = { userId = targetUserId },
		})
		MessagingService:PublishAsync("AdminCommand", data)
	end)

	return entry
end

-- Load ban list at startup
loadBanList()

-- Create AdminCheck event to show the Owner button
local adminCheckEvent = ReplicatedStorage:FindFirstChild("AdminCheck")
if not adminCheckEvent then
	adminCheckEvent = Instance.new("RemoteEvent")
	adminCheckEvent.Name = "AdminCheck"
	adminCheckEvent.Parent = ReplicatedStorage
end

-- Handle players on join: ban check or show admin button
Players.PlayerAdded:Connect(function(p)
	if isPlayerBanned(p.UserId) then
		local entry = bannedPlayers[tostring(p.UserId)]
		local reason = entry and entry.reason or "Banned"
		p:Kick("You are banned: " .. reason)
		return
	end

	-- Show Owner button for admins (with delay so the client script has time to start)
	if ADMINS[p.UserId] then
		task.delay(3, function()
			if p and p.Parent then
				adminCheckEvent:FireClient(p, true)
				debugPrint("[ADMIN] Fired AdminCheck for returning admin:", p.Name)
			end
		end)
	end
end)

-- RemoteFunction to fetch the ban list (admin only)
local getBanListFunc = ReplicatedStorage:FindFirstChild("GetBanList")
if not getBanListFunc then
	getBanListFunc = Instance.new("RemoteFunction")
	getBanListFunc.Name = "GetBanList"
	getBanListFunc.Parent = ReplicatedStorage
end

getBanListFunc.OnServerInvoke = function(requestingPlayer)
	if not ADMINS[requestingPlayer.UserId] then return {} end
	-- Return a list for the UI
	local list = {}
	for odId, entry in pairs(bannedPlayers) do
		table.insert(list, {
			userId = tonumber(odId),
			name = entry.name or "Unknown",
			reason = entry.reason or "",
			bannedBy = entry.bannedBy or "Unknown",
			timestamp = entry.timestamp or 0,
		})
	end
	-- Sort newest first
	table.sort(list, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
	return list
end

-- =====================
-- LIST CODES (RemoteFunction for admin panel)
-- =====================
local listCodesFunc = ReplicatedStorage:FindFirstChild("ListCodes")
if not listCodesFunc then
	listCodesFunc = Instance.new("RemoteFunction")
	listCodesFunc.Name = "ListCodes"
	listCodesFunc.Parent = ReplicatedStorage
end

listCodesFunc.OnServerInvoke = function(requestingPlayer)
	if not ADMINS[requestingPlayer.UserId] then return {} end

	local codeStore = nil
	pcall(function()
		codeStore = DataStoreService:GetDataStore("RedeemCodes")
	end)
	if not codeStore then return {} end

	local ok, index = pcall(function()
		return codeStore:GetAsync("code_index")
	end)

	if not ok or not index or type(index) ~= "table" then return {} end

	local list = {}
	for codeName, data in pairs(index) do
		-- Fetch current usage count
		local usedCount = 0
		pcall(function()
			local codeData = codeStore:GetAsync("code_" .. codeName)
			if codeData then
				usedCount = codeData.usedCount or 0
			end
		end)

		table.insert(list, {
			name = codeName,
			rewardType = data.rewardType or "credits",
			amount = data.amount or 0,
			maxUses = data.maxUses or 0,
			usedCount = usedCount,
			createdBy = data.createdBy or "Unknown",
			createdAt = data.createdAt or 0,
		})
	end

	-- Sort newest first
	table.sort(list, function(a, b) return (a.createdAt or 0) > (b.createdAt or 0) end)
	return list
end

-- =====================
-- ADMIN CHECK (RemoteFunction for the client to ask if it is admin)
-- =====================
local isAdminFunc = ReplicatedStorage:FindFirstChild("IsAdmin")
if not isAdminFunc then
	isAdminFunc = Instance.new("RemoteFunction")
	isAdminFunc.Name = "IsAdmin"
	isAdminFunc.Parent = ReplicatedStorage
end

isAdminFunc.OnServerInvoke = function(requestingPlayer)
	return ADMINS[requestingPlayer.UserId] == true
end

-- =====================
-- REMOTE EVENT
-- =====================
local adminRemote = ReplicatedStorage:FindFirstChild("AdminRemote")
if not adminRemote then
	adminRemote = Instance.new("RemoteEvent")
	adminRemote.Name = "AdminRemote"
	adminRemote.Parent = ReplicatedStorage
end

-- Response event for feedback to the client
local adminResponse = ReplicatedStorage:FindFirstChild("AdminResponse")
if not adminResponse then
	adminResponse = Instance.new("RemoteEvent")
	adminResponse.Name = "AdminResponse"
	adminResponse.Parent = ReplicatedStorage
end

-- Broadcast message event (server → all clients)
local adminMessageEvent = ReplicatedStorage:FindFirstChild("AdminMessage")
if not adminMessageEvent then
	adminMessageEvent = Instance.new("RemoteEvent")
	adminMessageEvent.Name = "AdminMessage"
	adminMessageEvent.Parent = ReplicatedStorage
end

-- =====================
-- GLOBAL SCOPE (MessagingService)
-- =====================
local function publishGlobal(cmd, args)
	pcall(function()
		local data = game:GetService("HttpService"):JSONEncode({
			cmd = cmd,
			args = args,
		})
		MessagingService:PublishAsync("AdminCommand", data)
	end)
end

-- Listen for global commands from other servers
pcall(function()
	MessagingService:SubscribeAsync("AdminCommand", function(message)
		local ok, data = pcall(function()
			return game:GetService("HttpService"):JSONDecode(message.Data)
		end)
		if not ok or not data then return end

		if data.cmd == "SpawnBrainrot" then
			warn("[ADMIN] SpawnBrainrot not yet implemented via BindableFunctions")
		elseif data.cmd == "SpawnWave" then
			warn("[ADMIN] SpawnWave not yet implemented via BindableFunctions")
		elseif data.cmd == "BanPlayer" then
			-- Another server banned a player - update local cache and kick if online
			local key = tostring(data.args.userId)
			bannedPlayers[key] = {
				name = data.args.name,
				reason = data.args.reason,
				bannedBy = "Remote",
				timestamp = os.time(),
			}
			local target = Players:GetPlayerByUserId(data.args.userId)
			if target then
				target:Kick("You have been banned: " .. (data.args.reason or ""))
			end
		elseif data.cmd == "UnbanPlayer" then
			bannedPlayers[tostring(data.args.userId)] = nil
		elseif data.cmd == "AddAdmin" then
			ADMINS[data.args.userId] = true
		elseif data.cmd == "RemoveAdmin" then
			if not OWNER_IDS[data.args.userId] then
				ADMINS[data.args.userId] = nil
			end
		elseif data.cmd == "SendMessage" then
			-- Broadcast from another server — display on all local clients
			adminMessageEvent:FireAllClients(data.args.text, data.args.duration)
		elseif data.cmd == "GrantLuck" then
			-- Apply luck from another server
			if adminSetLuck then
				adminSetLuck:Invoke(data.args.mult, data.args.duration)
			end
		end
	end)
end)

-- =====================
-- COMMAND HANDLING
-- =====================
debugPrint("[ADMIN SERVER] OnServerEvent handler registered on:", adminRemote:GetFullName(), "ClassName:", adminRemote.ClassName)

adminRemote.OnServerEvent:Connect(function(player, cmd, ...)
	debugPrint("[ADMIN SERVER RAW] Received ANY command:", tostring(cmd), "from:", player.Name, "UserId:", player.UserId)
	-- Security check: is the player admin?
	if not ADMINS[player.UserId] then
		warn(string.format("[ADMIN SECURITY] Unauthorized access by %s (%d) - cmd: %s",
			player.Name, player.UserId, tostring(cmd)))
		return
	end

	-- Rate limiting
	if not checkCooldown(player) then
		warn(string.format("[ADMIN RATE LIMIT] %s is sending commands too fast", player.Name))
		adminResponse:FireClient(player, false, "Please wait between commands (cooldown)")
		return
	end

	-- Validate cmd
	cmd = sanitizeString(cmd, 30)
	if not cmd then
		adminResponse:FireClient(player, false, "Invalid command")
		return
	end

	local args = {...}

	-- =====================
	-- ADD CREDITS
	-- =====================
	if cmd == "AddCredits" then
		local targetName = sanitizeString(args[1])
		local amount = sanitizeNumber(args[2])
		if not amount or amount <= 0 then
			adminResponse:FireClient(player, false, "Invalid amount")
			return
		end
		-- If no target specified, use admin self
		local target = player
		if targetName and #targetName > 0 then
			target = findPlayer(targetName)
			if not target then
				adminResponse:FireClient(player, false, "Player '" .. targetName .. "' not found")
				return
			end
		end
		if not adminAddCredits then
			adminResponse:FireClient(player, false, "Server not ready - try again")
			return
		end
		local ok, err, prevValue = adminAddCredits:Invoke(target, amount)
		logAction(player, cmd, target.Name, "amount=" .. tostring(amount))
		if ok then
			adminResponse:FireClient(player, true, "Added " .. amount .. " credits to " .. target.Name,
				{ undoCmd = "SetCredits", undoArgs = { target.Name, prevValue }, desc = "Undo: Restore credits to " .. tostring(prevValue) })
		else
			adminResponse:FireClient(player, false, err or "Unknown error")
		end

	-- =====================
	-- SET CREDITS
	-- =====================
	elseif cmd == "SetCredits" then
		local targetName = sanitizeString(args[1])
		local amount = sanitizeNumber(args[2])
		if not amount then
			adminResponse:FireClient(player, false, "Invalid amount")
			return
		end
		local target = player
		if targetName and #targetName > 0 then
			target = findPlayer(targetName)
			if not target then
				adminResponse:FireClient(player, false, "Player '" .. targetName .. "' not found")
				return
			end
		end
		if not adminSetCredits then
			adminResponse:FireClient(player, false, "Server not ready - try again")
			return
		end
		local ok, err, prevValue = adminSetCredits:Invoke(target, amount)
		logAction(player, cmd, target.Name, "amount=" .. tostring(amount))
		if ok then
			adminResponse:FireClient(player, true, "Set credits to " .. amount .. " for " .. target.Name,
				{ undoCmd = "SetCredits", undoArgs = { target.Name, prevValue }, desc = "Undo: Restore credits to " .. tostring(prevValue) })
		else
			adminResponse:FireClient(player, false, err or "Unknown error")
		end

	-- =====================
	-- SET REBIRTH
	-- =====================
	elseif cmd == "SetRebirth" then
		local targetName = sanitizeString(args[1])
		local amount = sanitizeNumber(args[2])
		if not amount then
			adminResponse:FireClient(player, false, "Invalid amount")
			return
		end
		local target = player
		if targetName and #targetName > 0 then
			target = findPlayer(targetName)
			if not target then
				adminResponse:FireClient(player, false, "Player not found")
				return
			end
		end
		if not adminSetRebirth then
			adminResponse:FireClient(player, false, "Server not ready - try again")
			return
		end
		local ok, err, prevValue = adminSetRebirth:Invoke(target, amount)
		logAction(player, cmd, target.Name, "amount=" .. tostring(amount))
		if ok then
			adminResponse:FireClient(player, true, "Set rebirth to " .. amount .. " for " .. target.Name,
				{ undoCmd = "SetRebirth", undoArgs = { target.Name, prevValue }, desc = "Undo: Restore rebirth to " .. tostring(prevValue) })
		else
			adminResponse:FireClient(player, false, err or "Unknown error")
		end

	-- =====================
	-- GIVE REBIRTH (+1)
	-- =====================
	elseif cmd == "GiveRebirth" then
		local targetName = sanitizeString(args[1])
		local target = player
		if targetName and #targetName > 0 then
			target = findPlayer(targetName)
			if not target then
				adminResponse:FireClient(player, false, "Player not found")
				return
			end
		end
		if not adminGiveRebirth then
			adminResponse:FireClient(player, false, "Server not ready - try again")
			return
		end
		local ok, err, prevValue = adminGiveRebirth:Invoke(target)
		logAction(player, cmd, target.Name)
		if ok then
			adminResponse:FireClient(player, true, "Gave rebirth to " .. target.Name,
				{ undoCmd = "SetRebirth", undoArgs = { target.Name, prevValue }, desc = "Undo: Restore rebirth to " .. tostring(prevValue) })
		else
			adminResponse:FireClient(player, false, err or "Unknown error")
		end

	-- =====================
	-- SET SPEED
	-- =====================
	elseif cmd == "SetSpeed" then
		local targetName = sanitizeString(args[1])
		local multiplier = sanitizeNumber(args[2])
		if not multiplier then
			adminResponse:FireClient(player, false, "Invalid multiplier")
			return
		end
		local target = player
		if targetName and #targetName > 0 then
			target = findPlayer(targetName)
			if not target then
				adminResponse:FireClient(player, false, "Player not found")
				return
			end
		end
		if not adminSetSpeed then
			adminResponse:FireClient(player, false, "Server not ready - try again")
			return
		end
		local ok, err, prevValue = adminSetSpeed:Invoke(target, multiplier)
		logAction(player, cmd, target.Name, "multiplier=" .. tostring(multiplier))
		if ok then
			adminResponse:FireClient(player, true, "Set speed to " .. multiplier .. "x for " .. target.Name,
				{ undoCmd = "SetSpeed", undoArgs = { target.Name, prevValue }, desc = "Undo: Restore speed to " .. string.format("%.2f", prevValue or 0) .. "x" })
		else
			adminResponse:FireClient(player, false, err or "Unknown error")
		end

	-- =====================
	-- SPAWN BRAINROT
	-- =====================
	elseif cmd == "SpawnBrainrot" then
		local brainrotName = sanitizeString(args[1])
		local mutation = sanitizeString(args[2]) or ""
		local scope = sanitizeString(args[3]) or "Server"
		if not brainrotName or #brainrotName == 0 then
			adminResponse:FireClient(player, false, "Enter a brainrot name")
			return
		end
		if scope == "Global" then
			publishGlobal("SpawnBrainrot", { name = brainrotName, mutation = mutation })
			logAction(player, cmd, brainrotName, "scope=Global mutation=" .. mutation)
			adminResponse:FireClient(player, true, "Spawned '" .. brainrotName .. "' globally")
		else
			if not adminSpawnBrainrot then
				adminResponse:FireClient(player, false, "Server not ready - try again")
				return
			end
			local ok, err, zoneIndex = adminSpawnBrainrot:Invoke(brainrotName, mutation)
			logAction(player, cmd, brainrotName, "scope=Server mutation=" .. mutation)
			if ok then
				adminResponse:FireClient(player, true, "Spawned '" .. brainrotName .. "' in zone " .. tostring(zoneIndex))
			else
				adminResponse:FireClient(player, false, err or "Unknown error")
			end
		end

	-- =====================
	-- SPAWN WAVE
	-- =====================
	elseif cmd == "SpawnWave" then
		local waveName = sanitizeString(args[1])
		local scope = sanitizeString(args[2]) or "Server"
		if not waveName or #waveName == 0 then
			adminResponse:FireClient(player, false, "Enter a wave name")
			return
		end
		if scope == "Global" then
			publishGlobal("SpawnWave", { waveName = waveName })
			logAction(player, cmd, waveName, "scope=Global")
			adminResponse:FireClient(player, true, "Triggered wave '" .. waveName .. "' globally")
		else
			warn("[ADMIN] SpawnWave (local) not yet implemented via BindableFunctions")
			logAction(player, cmd, waveName, "scope=Server")
			adminResponse:FireClient(player, false, "SpawnWave not yet implemented via BindableFunctions")
		end

	-- =====================
	-- KICK PLAYER
	-- =====================
	elseif cmd == "KickPlayer" then
		local targetName = sanitizeString(args[1])
		local reason = sanitizeString(args[2], 200) or "Kicked by admin"
		if not targetName or #targetName == 0 then
			adminResponse:FireClient(player, false, "Enter a player name to kick")
			return
		end
		local target = findPlayer(targetName)
		if not target then
			adminResponse:FireClient(player, false, "Player '" .. targetName .. "' not found")
			return
		end
		if ADMINS[target.UserId] then
			adminResponse:FireClient(player, false, "Cannot kick another admin")
			return
		end
		logAction(player, cmd, target.Name, "reason=" .. reason)
		target:Kick(reason)
		adminResponse:FireClient(player, true, "Kicked " .. targetName .. ": " .. reason)

	-- =====================
	-- TOGGLE ADMIN
	-- =====================
	elseif cmd == "ToggleAdmin" then
		local targetName = sanitizeString(args[1])
		debugPrint("[ADMIN SERVER] ToggleAdmin received, targetName:", targetName)
		if not targetName or #targetName == 0 then
			adminResponse:FireClient(player, false, "Enter a player name")
			return
		end
		-- Debug: show all players
		if DEBUG then
			debugPrint("[ADMIN SERVER] All players on server:")
			for _, p in ipairs(Players:GetPlayers()) do
				debugPrint("  -", p.Name, "UserId:", p.UserId)
			end
		end
		local target = findPlayer(targetName)
		debugPrint("[ADMIN SERVER] findPlayer('" .. targetName .. "') result:", target and target.Name or "NIL")
		if not target then
			adminResponse:FireClient(player, false, "Player '" .. targetName .. "' not found")
			return
		end
		debugPrint("[ADMIN SERVER] target.UserId:", target.UserId, "isAdmin:", ADMINS[target.UserId] or false, "isOwner:", OWNER_IDS[target.UserId] or false)
		if ADMINS[target.UserId] then
			-- Remove admin - owners can never be removed
			if OWNER_IDS[target.UserId] then
				adminResponse:FireClient(player, false, target.DisplayName .. " is an owner and cannot be removed as admin")
				return
			end
			ADMINS[target.UserId] = nil
			saveAdminList()
			logAction(player, cmd, target.Name, "removed admin")
			adminResponse:FireClient(player, true, "Removed admin: " .. target.DisplayName)

			-- Publish globally
			pcall(function()
				local data = game:GetService("HttpService"):JSONEncode({
					cmd = "RemoveAdmin", args = { userId = target.UserId },
				})
				MessagingService:PublishAsync("AdminCommand", data)
			end)
		else
			-- Add as admin
			ADMINS[target.UserId] = true
			saveAdminList()
			logAction(player, cmd, target.Name, "granted admin")
			adminResponse:FireClient(player, true, "Granted admin to: " .. target.DisplayName .. " (global, must rejoin for panel)")

			-- Show the Owner button for the new admin
			debugPrint("[ADMIN SERVER] Firing AdminCheck to", target.Name, "- Owner button should appear")
			adminCheckEvent:FireClient(target, true)

			-- Publish globally
			pcall(function()
				local data = game:GetService("HttpService"):JSONEncode({
					cmd = "AddAdmin", args = { userId = target.UserId },
				})
				MessagingService:PublishAsync("AdminCommand", data)
			end)
		end

	-- =====================
	-- BAN PLAYER
	-- =====================
	elseif cmd == "BanPlayer" then
		local targetName = sanitizeString(args[1])
		local reason = sanitizeString(args[2], 200) or "No reason given"
		if not targetName or #targetName == 0 then
			adminResponse:FireClient(player, false, "Enter a player name to ban")
			return
		end
		local target = findPlayer(targetName)
		if target then
			if ADMINS[target.UserId] then
				adminResponse:FireClient(player, false, "Cannot ban an admin")
				return
			end
			logAction(player, cmd, target.Name, "reason=" .. reason)
			banPlayer(target.UserId, target.Name, reason, player)
			adminResponse:FireClient(player, true, "Banned " .. target.DisplayName .. ": " .. reason,
				{ undoCmd = "UnbanPlayer", undoArgs = { tostring(target.UserId) }, desc = "Undo: Unban " .. target.DisplayName })
		else
			-- Player is not online - cannot ban by name (requires UserId)
			adminResponse:FireClient(player, false, "Player '" .. targetName .. "' not found (must be online)")
		end

	-- =====================
	-- UNBAN PLAYER
	-- =====================
	elseif cmd == "UnbanPlayer" then
		local userIdStr = sanitizeString(args[1])
		local userId = tonumber(userIdStr)
		if not userId then
			adminResponse:FireClient(player, false, "Invalid UserId")
			return
		end
		local entry = unbanPlayer(userId)
		if entry then
			logAction(player, cmd, entry.name or tostring(userId), "unbanned")
			adminResponse:FireClient(player, true, "Unbanned " .. (entry.name or tostring(userId)))
		else
			adminResponse:FireClient(player, false, "Player was not banned")
		end

	-- =====================
	-- CREATE CODE
	-- =====================
	elseif cmd == "CreateCode" then
		local codeName = sanitizeString(args[1], 30)
		local rewardType = sanitizeString(args[2], 20) or "credits"
		local amount = sanitizeNumber(args[3])
		local maxUses = sanitizeNumber(args[4]) or 0

		if not codeName or #codeName == 0 then
			adminResponse:FireClient(player, false, "Enter a code name")
			return
		end
		if not amount or amount <= 0 then
			adminResponse:FireClient(player, false, "Enter a valid amount")
			return
		end

		codeName = codeName:upper():gsub("%s+", "")

		local codeStore = nil
		pcall(function()
			codeStore = DataStoreService:GetDataStore("RedeemCodes")
		end)
		if not codeStore then
			adminResponse:FireClient(player, false, "DataStore unavailable")
			return
		end

		local codeData = {
			rewardType = rewardType,
			amount = amount,
			maxUses = maxUses,
			usedCount = 0,
			createdBy = player.Name,
			createdAt = os.time(),
		}

		-- Check if code already exists before creating
		local existingCode = nil
		pcall(function() existingCode = codeStore:GetAsync("code_" .. codeName) end)
		if existingCode then
			adminResponse:FireClient(player, false, "Code '" .. codeName .. "' already exists")
			return
		end

		local ok, err = pcall(function()
			codeStore:SetAsync("code_" .. codeName, codeData)
		end)

		if ok then
			-- Also save to code index for listing
			pcall(function()
				codeStore:UpdateAsync("code_index", function(old)
					local index = old or {}
					index[codeName] = {
						rewardType = rewardType,
						amount = amount,
						maxUses = maxUses,
						createdBy = player.Name,
						createdAt = os.time(),
					}
					return index
				end)
			end)
			logAction(player, cmd, codeName, "type=" .. rewardType .. " amount=" .. tostring(amount) .. " maxUses=" .. tostring(maxUses))
			adminResponse:FireClient(player, true, "Created code: " .. codeName .. " (" .. rewardType .. " x" .. amount .. ")")
		else
			adminResponse:FireClient(player, false, "Failed to create code: " .. tostring(err))
		end

	-- =====================
	-- DELETE CODE
	-- =====================
	elseif cmd == "DeleteCode" then
		local codeName = sanitizeString(args[1], 30)
		if not codeName or #codeName == 0 then
			adminResponse:FireClient(player, false, "Enter a code name")
			return
		end

		codeName = codeName:upper():gsub("%s+", "")

		local codeStore = nil
		pcall(function()
			codeStore = DataStoreService:GetDataStore("RedeemCodes")
		end)
		if not codeStore then
			adminResponse:FireClient(player, false, "DataStore unavailable")
			return
		end

		local ok, err = pcall(function()
			codeStore:RemoveAsync("code_" .. codeName)
		end)

		if ok then
			-- Remove from index
			pcall(function()
				codeStore:UpdateAsync("code_index", function(old)
					if not old then return old end
					old[codeName] = nil
					return old
				end)
			end)
			logAction(player, cmd, codeName, "deleted")
			adminResponse:FireClient(player, true, "Deleted code: " .. codeName)
		else
			adminResponse:FireClient(player, false, "Failed to delete code: " .. tostring(err))
		end

	-- =====================
	-- SEND MESSAGE (broadcast to all players)
	-- =====================
	elseif cmd == "SendMessage" then
		local messageText = sanitizeString(args[1], 200)
		local duration = sanitizeNumber(args[2]) or 5
		local scope = sanitizeString(args[3]) or "Server"
		if not messageText or #messageText == 0 then
			adminResponse:FireClient(player, false, "Enter a message")
			return
		end
		duration = math.clamp(duration, 1, 60)
		logAction(player, cmd, "", "msg=" .. messageText .. " scope=" .. scope)
		-- Broadcast to all players on this server
		adminMessageEvent:FireAllClients(messageText, duration)
		if scope == "Global" then
			publishGlobal("SendMessage", { text = messageText, duration = duration })
			adminResponse:FireClient(player, true, "Message sent globally: " .. messageText)
		else
			adminResponse:FireClient(player, true, "Message sent to server: " .. messageText)
		end

	-- =====================
	-- GRANT LUCK (server-wide luck boost)
	-- =====================
	elseif cmd == "GrantLuck" then
		local mult = sanitizeNumber(args[1])
		local duration = sanitizeNumber(args[2]) or 15
		local scope = sanitizeString(args[3]) or "Server"
		if not mult or mult < 1 then
			adminResponse:FireClient(player, false, "Invalid luck multiplier")
			return
		end
		duration = math.clamp(duration, 1, 240)
		local durationSeconds = duration * 60
		logAction(player, cmd, "", "mult=" .. mult .. "x duration=" .. duration .. "min scope=" .. scope)

		if scope == "Global" then
			-- Apply locally first
			if adminSetLuck then
				adminSetLuck:Invoke(mult, durationSeconds)
			end
			publishGlobal("GrantLuck", { mult = mult, duration = durationSeconds })
			adminResponse:FireClient(player, true, "Luck set to " .. mult .. "x for " .. duration .. " min globally")
		else
			if not adminSetLuck then
				adminResponse:FireClient(player, false, "Server not ready - try again")
				return
			end
			local ok, err = adminSetLuck:Invoke(mult, durationSeconds)
			if ok then
				adminResponse:FireClient(player, true, "Luck set to " .. mult .. "x for " .. duration .. " min on this server")
			else
				adminResponse:FireClient(player, false, err or "Unknown error")
			end
		end

	-- =====================
	-- UNKNOWN COMMAND
	-- =====================
	else
		warn("[ADMIN] Unknown command:", cmd, "from", player.Name)
		adminResponse:FireClient(player, false, "Unknown command: " .. tostring(cmd))
	end
end)

-- Clear cooldown data on disconnect
Players.PlayerRemoving:Connect(function(player)
	lastCommandTime[player.UserId] = nil
end)

debugPrint("[AdminServer] Loaded and ready. Admin count:", tableCount(ADMINS))
