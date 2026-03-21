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
-- WHITELIST
-- Ersätt med riktiga UserId:n
-- =====================
local ADMINS = {
	[8327644091] = true, -- Simpleson716
}

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
