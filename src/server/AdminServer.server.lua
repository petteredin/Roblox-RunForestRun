-- =============================================
-- AdminServer.lua (ServerScript)
-- Huvud-serverscript för admin-panelen.
-- Hanterar alla admin-kommandon med säkerhet.
-- Placeras i ServerScriptService.
-- =============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ServerScriptService = game:GetService("ServerScriptService")

-- BindableFunctions som BrainrotSpawnEngine lyssnar på
local function waitForBindable(name)
	return ServerScriptService:WaitForChild(name, 15)
end

local adminAddCredits  = waitForBindable("AdminAddCredits")
local adminSetCredits  = waitForBindable("AdminSetCredits")
local adminSetRebirth  = waitForBindable("AdminSetRebirth")
local adminGiveRebirth = waitForBindable("AdminGiveRebirth")
local adminSetSpeed    = waitForBindable("AdminSetSpeed")

-- =====================
-- WHITELIST (hardkodade ägare som alltid är admin)
-- =====================
local OWNER_IDS = {
	[8327644091] = true, -- Simpleson716
}

-- Runtime admin-lista (laddas från DataStore + owners)
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
		print("[ADMIN] Loaded", #data, "admins from DataStore")
	elseif not ok then
		warn("[ADMIN] Failed to load admin list:", tostring(data))
	else
		print("[ADMIN] No saved admin list found (first run)")
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
			adminStore:SetAsync("Admins", list)
		end)
		if ok then
			print("[ADMIN] Saved admin list:", #list, "admins")
		else
			warn("[ADMIN] Failed to save admin list:", tostring(err))
		end
	end)
end

loadAdminList()

-- =====================
-- RATE LIMITING
-- =====================
local COOLDOWN_TIME = 0.5 -- sekunder mellan kommandon
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
	print(string.format("[ADMIN] %s (%d) -> %s | target: %s | %s",
		player.Name, player.UserId, cmd, target or "N/A", details or ""))

	-- Spara till DataStore asynkront
	if adminLogStore then
		task.spawn(function()
			pcall(function()
				local key = "log_" .. tostring(os.time()) .. "_" .. tostring(player.UserId)
				adminLogStore:SetAsync(key, entry)
			end)
		end)
	end
end

-- =====================
-- HJÄLPFUNKTIONER
-- =====================

--- Hitta en spelare via namn eller displaynamn
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
	-- Partiell matchning som fallback
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(lowerName, 1, true) or
			p.DisplayName:lower():find(lowerName, 1, true) then
			return p
		end
	end
	return nil
end

--- Validera och sanera sträng-input
local function sanitizeString(str, maxLen)
	if type(str) ~= "string" then return nil end
	maxLen = maxLen or 50
	str = str:sub(1, maxLen)
	return str
end

--- Validera nummer-input
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

-- Lokal cache av bannade spelare (synkas med DataStore)
local bannedPlayers = {} -- [UserId] = { name = "...", reason = "...", bannedBy = "...", timestamp = ... }

-- Ladda ban-lista från DataStore vid start
local function loadBanList()
	if not banStore then return end
	local ok, data = pcall(function()
		return banStore:GetAsync("BanList")
	end)
	if ok and data and type(data) == "table" then
		bannedPlayers = data
		print("[ADMIN] Loaded " .. tostring(#(function() local c = 0; for _ in pairs(bannedPlayers) do c = c + 1 end; return c end)()) .. " banned players")
	end
end

local function saveBanList()
	if not banStore then return end
	task.spawn(function()
		pcall(function()
			banStore:SetAsync("BanList", bannedPlayers)
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
		reason = reason or "Ingen anledning angiven",
		bannedBy = adminPlayer.Name,
		bannedById = adminPlayer.UserId,
		timestamp = os.time(),
	}
	saveBanList()

	-- Kick spelaren om de är online
	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		target:Kick("Du har blivit bannad: " .. (reason or "Ingen anledning angiven"))
	end

	-- Publicera globalt så andra servrar också kickar
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

	-- Publicera globalt
	pcall(function()
		local data = game:GetService("HttpService"):JSONEncode({
			cmd = "UnbanPlayer",
			args = { userId = targetUserId },
		})
		MessagingService:PublishAsync("AdminCommand", data)
	end)

	return entry
end

-- Ladda ban-lista vid uppstart
loadBanList()

-- Skapa AdminCheck event för att visa Owner-knappen
local adminCheckEvent = ReplicatedStorage:FindFirstChild("AdminCheck")
if not adminCheckEvent then
	adminCheckEvent = Instance.new("RemoteEvent")
	adminCheckEvent.Name = "AdminCheck"
	adminCheckEvent.Parent = ReplicatedStorage
end

-- Hantera spelare vid join: banna eller visa admin-knappen
Players.PlayerAdded:Connect(function(p)
	if isPlayerBanned(p.UserId) then
		local entry = bannedPlayers[tostring(p.UserId)]
		local reason = entry and entry.reason or "Bannad"
		p:Kick("Du är bannad: " .. reason)
		return
	end

	-- Visa Owner-knappen för admins (med delay så klient-scriptet hinner starta)
	if ADMINS[p.UserId] then
		task.delay(3, function()
			if p and p.Parent then
				adminCheckEvent:FireClient(p, true)
				print("[ADMIN] Fired AdminCheck for returning admin:", p.Name)
			end
		end)
	end
end)

-- RemoteFunction för att hämta ban-listan (admin only)
local getBanListFunc = ReplicatedStorage:FindFirstChild("GetBanList")
if not getBanListFunc then
	getBanListFunc = Instance.new("RemoteFunction")
	getBanListFunc.Name = "GetBanList"
	getBanListFunc.Parent = ReplicatedStorage
end

getBanListFunc.OnServerInvoke = function(requestingPlayer)
	if not ADMINS[requestingPlayer.UserId] then return {} end
	-- Returnera en lista för UI:n
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
	-- Sortera nyast först
	table.sort(list, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
	return list
end

-- =====================
-- ADMIN CHECK (RemoteFunction för klienten att fråga om den är admin)
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

-- Respons-event för feedback till klienten
local adminResponse = ReplicatedStorage:FindFirstChild("AdminResponse")
if not adminResponse then
	adminResponse = Instance.new("RemoteEvent")
	adminResponse.Name = "AdminResponse"
	adminResponse.Parent = ReplicatedStorage
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

-- Lyssna på globala kommandon från andra servrar
pcall(function()
	MessagingService:SubscribeAsync("AdminCommand", function(message)
		local ok, data = pcall(function()
			return game:GetService("HttpService"):JSONDecode(message.Data)
		end)
		if not ok or not data then return end

		if data.cmd == "SpawnBrainrot" then
			GameManager.spawnBrainrot(data.args.name, data.args.mutation)
		elseif data.cmd == "SpawnWave" then
			GameManager.triggerWave(data.args.waveName)
		elseif data.cmd == "BanPlayer" then
			-- Annan server bannade en spelare - uppdatera lokal cache och kicka om online
			local key = tostring(data.args.userId)
			bannedPlayers[key] = {
				name = data.args.name,
				reason = data.args.reason,
				bannedBy = "Remote",
				timestamp = os.time(),
			}
			local target = Players:GetPlayerByUserId(data.args.userId)
			if target then
				target:Kick("Du har blivit bannad: " .. (data.args.reason or ""))
			end
		elseif data.cmd == "UnbanPlayer" then
			bannedPlayers[tostring(data.args.userId)] = nil
		elseif data.cmd == "AddAdmin" then
			ADMINS[data.args.userId] = true
		elseif data.cmd == "RemoveAdmin" then
			if not OWNER_IDS[data.args.userId] then
				ADMINS[data.args.userId] = nil
			end
		end
	end)
end)

-- =====================
-- KOMMANDOHANTERING
-- =====================
adminRemote.OnServerEvent:Connect(function(player, cmd, ...)
	-- Säkerhetskontroll: är spelaren admin?
	if not ADMINS[player.UserId] then
		warn(string.format("[ADMIN SECURITY] Obehörig åtkomst av %s (%d) - cmd: %s",
			player.Name, player.UserId, tostring(cmd)))
		return
	end

	-- Rate limiting
	if not checkCooldown(player) then
		warn(string.format("[ADMIN RATE LIMIT] %s skickar kommandon för snabbt", player.Name))
		adminResponse:FireClient(player, false, "Vänta lite mellan kommandon (cooldown)")
		return
	end

	-- Validera cmd
	cmd = sanitizeString(cmd, 30)
	if not cmd then
		adminResponse:FireClient(player, false, "Ogiltigt kommando")
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
			adminResponse:FireClient(player, false, "Ogiltigt belopp")
			return
		end
		-- Om inget mål angivet, använd admin själv
		local target = player
		if targetName and #targetName > 0 then
			target = findPlayer(targetName)
			if not target then
				adminResponse:FireClient(player, false, "Spelaren '" .. targetName .. "' hittades inte")
				return
			end
		end
		if adminAddCredits then
			local ok, err = adminAddCredits:Invoke(target, amount)
			logAction(player, cmd, target.Name, "amount=" .. tostring(amount))
			if ok then
				adminResponse:FireClient(player, true, "Lade till " .. amount .. " credits till " .. target.Name)
			else
				adminResponse:FireClient(player, false, err or "Okänt fel")
			end
		else
			adminResponse:FireClient(player, false, "AdminAddCredits ej tillgänglig")
		end

	-- =====================
	-- SET CREDITS
	-- =====================
	elseif cmd == "SetCredits" then
		local targetName = sanitizeString(args[1])
		local amount = sanitizeNumber(args[2])
		if not amount then
			adminResponse:FireClient(player, false, "Ogiltigt belopp")
			return
		end
		local target = player
		if targetName and #targetName > 0 then
			target = findPlayer(targetName)
			if not target then
				adminResponse:FireClient(player, false, "Spelaren '" .. targetName .. "' hittades inte")
				return
			end
		end
		if adminSetCredits then
			local ok, err = adminSetCredits:Invoke(target, amount)
			logAction(player, cmd, target.Name, "amount=" .. tostring(amount))
			if ok then
				adminResponse:FireClient(player, true, "Satte credits till " .. amount .. " för " .. target.Name)
			else
				adminResponse:FireClient(player, false, err or "Okänt fel")
			end
		else
			adminResponse:FireClient(player, false, "AdminSetCredits ej tillgänglig")
		end

	-- =====================
	-- SET REBIRTH
	-- =====================
	elseif cmd == "SetRebirth" then
		local targetName = sanitizeString(args[1])
		local amount = sanitizeNumber(args[2])
		if not amount then
			adminResponse:FireClient(player, false, "Ogiltigt belopp")
			return
		end
		local target = player
		if targetName and #targetName > 0 then
			target = findPlayer(targetName)
			if not target then
				adminResponse:FireClient(player, false, "Spelaren hittades inte")
				return
			end
		end
		if adminSetRebirth then
			local ok, err = adminSetRebirth:Invoke(target, amount)
			logAction(player, cmd, target.Name, "amount=" .. tostring(amount))
			if ok then
				adminResponse:FireClient(player, true, "Satte rebirth till " .. amount .. " för " .. target.Name)
			else
				adminResponse:FireClient(player, false, err or "Okänt fel")
			end
		else
			adminResponse:FireClient(player, false, "AdminSetRebirth ej tillgänglig")
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
				adminResponse:FireClient(player, false, "Spelaren hittades inte")
				return
			end
		end
		if adminGiveRebirth then
			local ok, err = adminGiveRebirth:Invoke(target)
			logAction(player, cmd, target.Name)
			if ok then
				adminResponse:FireClient(player, true, "Gav rebirth till " .. target.Name)
			else
				adminResponse:FireClient(player, false, err or "Okänt fel")
			end
		else
			adminResponse:FireClient(player, false, "AdminGiveRebirth ej tillgänglig")
		end

	-- =====================
	-- SET SPEED
	-- =====================
	elseif cmd == "SetSpeed" then
		local targetName = sanitizeString(args[1])
		local multiplier = sanitizeNumber(args[2])
		if not multiplier then
			adminResponse:FireClient(player, false, "Ogiltig multiplier")
			return
		end
		local target = player
		if targetName and #targetName > 0 then
			target = findPlayer(targetName)
			if not target then
				adminResponse:FireClient(player, false, "Spelaren hittades inte")
				return
			end
		end
		if adminSetSpeed then
			local ok, err = adminSetSpeed:Invoke(target, multiplier)
			logAction(player, cmd, target.Name, "multiplier=" .. tostring(multiplier))
			if ok then
				adminResponse:FireClient(player, true, "Satte speed till " .. multiplier .. "x för " .. target.Name)
			else
				adminResponse:FireClient(player, false, err or "Okänt fel")
			end
		else
			adminResponse:FireClient(player, false, "AdminSetSpeed ej tillgänglig")
		end

	-- =====================
	-- SPAWN BRAINROT
	-- =====================
	elseif cmd == "SpawnBrainrot" then
		local brainrotName = sanitizeString(args[1])
		local mutation = sanitizeString(args[2]) or ""
		local scope = sanitizeString(args[3]) or "Server"
		if not brainrotName or #brainrotName == 0 then
			adminResponse:FireClient(player, false, "Ange ett brainrot-namn")
			return
		end
		if scope == "Global" then
			publishGlobal("SpawnBrainrot", { name = brainrotName, mutation = mutation })
			logAction(player, cmd, brainrotName, "scope=Global mutation=" .. mutation)
			adminResponse:FireClient(player, true, "Spawnade '" .. brainrotName .. "' globalt")
		else
			local ok, err = GameManager.spawnBrainrot(brainrotName, mutation)
			logAction(player, cmd, brainrotName, "scope=Server mutation=" .. mutation)
			if ok then
				adminResponse:FireClient(player, true, "Spawnade '" .. brainrotName .. "' på servern")
			else
				adminResponse:FireClient(player, false, err)
			end
		end

	-- =====================
	-- SPAWN WAVE
	-- =====================
	elseif cmd == "SpawnWave" then
		local waveName = sanitizeString(args[1])
		local scope = sanitizeString(args[2]) or "Server"
		if not waveName or #waveName == 0 then
			adminResponse:FireClient(player, false, "Ange ett vågnamn")
			return
		end
		if scope == "Global" then
			publishGlobal("SpawnWave", { waveName = waveName })
			logAction(player, cmd, waveName, "scope=Global")
			adminResponse:FireClient(player, true, "Triggade våg '" .. waveName .. "' globalt")
		else
			local ok, err = GameManager.triggerWave(waveName)
			logAction(player, cmd, waveName, "scope=Server")
			if ok then
				adminResponse:FireClient(player, true, "Triggade våg '" .. waveName .. "'")
			else
				adminResponse:FireClient(player, false, err)
			end
		end

	-- =====================
	-- KICK PLAYER
	-- =====================
	elseif cmd == "KickPlayer" then
		local targetName = sanitizeString(args[1])
		local reason = sanitizeString(args[2], 200) or "Kickad av admin"
		if not targetName or #targetName == 0 then
			adminResponse:FireClient(player, false, "Ange ett spelarnamn att kicka")
			return
		end
		local target = findPlayer(targetName)
		if not target then
			adminResponse:FireClient(player, false, "Spelaren '" .. targetName .. "' hittades inte")
			return
		end
		if ADMINS[target.UserId] then
			adminResponse:FireClient(player, false, "Kan inte kicka en annan admin")
			return
		end
		logAction(player, cmd, target.Name, "reason=" .. reason)
		target:Kick(reason)
		adminResponse:FireClient(player, true, "Kickade " .. targetName .. ": " .. reason)

	-- =====================
	-- TOGGLE ADMIN
	-- =====================
	elseif cmd == "ToggleAdmin" then
		local targetName = sanitizeString(args[1])
		print("[ADMIN SERVER] ToggleAdmin received, targetName:", targetName)
		if not targetName or #targetName == 0 then
			adminResponse:FireClient(player, false, "Ange ett spelarnamn")
			return
		end
		local target = findPlayer(targetName)
		print("[ADMIN SERVER] findPlayer result:", target and target.Name or "NIL")
		if not target then
			adminResponse:FireClient(player, false, "Spelaren '" .. targetName .. "' hittades inte")
			return
		end
		print("[ADMIN SERVER] target.UserId:", target.UserId, "isAdmin:", ADMINS[target.UserId] or false, "isOwner:", OWNER_IDS[target.UserId] or false)
		if ADMINS[target.UserId] then
			-- Ta bort admin - ägare kan aldrig tas bort
			if OWNER_IDS[target.UserId] then
				adminResponse:FireClient(player, false, target.DisplayName .. " är ägare och kan inte tas bort som admin")
				return
			end
			ADMINS[target.UserId] = nil
			saveAdminList()
			logAction(player, cmd, target.Name, "removed admin")
			adminResponse:FireClient(player, true, "Tog bort admin: " .. target.DisplayName)

			-- Publicera globalt
			pcall(function()
				local data = game:GetService("HttpService"):JSONEncode({
					cmd = "RemoveAdmin", args = { userId = target.UserId },
				})
				MessagingService:PublishAsync("AdminCommand", data)
			end)
		else
			-- Lägg till som admin
			ADMINS[target.UserId] = true
			saveAdminList()
			logAction(player, cmd, target.Name, "granted admin")
			adminResponse:FireClient(player, true, "Gav admin till: " .. target.DisplayName .. " (globalt, måste rejoina för panel)")

			-- Visa Owner-knappen för den nya adminen
			adminCheckEvent:FireClient(target, true)

			-- Publicera globalt
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
		local reason = sanitizeString(args[2], 200) or "Ingen anledning angiven"
		if not targetName or #targetName == 0 then
			adminResponse:FireClient(player, false, "Ange ett spelarnamn att banna")
			return
		end
		local target = findPlayer(targetName)
		if target then
			if ADMINS[target.UserId] then
				adminResponse:FireClient(player, false, "Kan inte banna en admin")
				return
			end
			logAction(player, cmd, target.Name, "reason=" .. reason)
			banPlayer(target.UserId, target.Name, reason, player)
			adminResponse:FireClient(player, true, "Bannade " .. target.DisplayName .. ": " .. reason)
		else
			-- Spelaren är inte online - försök banna via namn (kräver UserId)
			adminResponse:FireClient(player, false, "Spelaren '" .. targetName .. "' hittades inte (måste vara online)")
		end

	-- =====================
	-- UNBAN PLAYER
	-- =====================
	elseif cmd == "UnbanPlayer" then
		local userIdStr = sanitizeString(args[1])
		local userId = tonumber(userIdStr)
		if not userId then
			adminResponse:FireClient(player, false, "Ogiltigt UserId")
			return
		end
		local entry = unbanPlayer(userId)
		if entry then
			logAction(player, cmd, entry.name or tostring(userId), "unbanned")
			adminResponse:FireClient(player, true, "Avbannade " .. (entry.name or tostring(userId)))
		else
			adminResponse:FireClient(player, false, "Spelaren var inte bannad")
		end

	-- =====================
	-- OKÄNT KOMMANDO
	-- =====================
	else
		warn("[ADMIN] Okänt kommando:", cmd, "från", player.Name)
		adminResponse:FireClient(player, false, "Okänt kommando: " .. tostring(cmd))
	end
end)

-- Rensa cooldown-data vid disconnect
Players.PlayerRemoving:Connect(function(player)
	lastCommandTime[player.UserId] = nil
end)

print("[AdminServer] Laddat och redo. Antal admins:", #(function()
	local t = {}
	for k in pairs(ADMINS) do table.insert(t, k) end
	return t
end)())
