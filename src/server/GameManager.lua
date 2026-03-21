-- =============================================
-- GameManager.lua (ModuleScript)
-- Centraliserad spellogik som delas mellan
-- AdminServer och det ordinarie spelet.
-- Placeras i ServerScriptService.
-- =============================================

local Players = game:GetService("Players")

local GameManager = {}

-- =====================
-- CREDITS / WALLET
-- =====================

--- Lägg till credits till en spelare
--- @param player Player
--- @param amount number
--- @return boolean, string?
function GameManager.addCredits(player, amount)
	if not player or not player:IsA("Player") then
		return false, "Ogiltig spelare"
	end
	if type(amount) ~= "number" or amount ~= amount then
		return false, "Ogiltigt belopp"
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return false, "Belopp måste vara positivt"
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Credits") then
		leaderstats.Credits.Value = leaderstats.Credits.Value + amount
		return true, nil
	end
	return false, "Leaderstats/Credits hittades inte"
end

--- Sätt exakt credits-värde
--- @param player Player
--- @param amount number
--- @return boolean, string?
function GameManager.setCredits(player, amount)
	if not player or not player:IsA("Player") then
		return false, "Ogiltig spelare"
	end
	if type(amount) ~= "number" or amount ~= amount then
		return false, "Ogiltigt belopp"
	end
	amount = math.floor(amount)
	if amount < 0 then
		return false, "Belopp kan inte vara negativt"
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Credits") then
		leaderstats.Credits.Value = amount
		return true, nil
	end
	return false, "Leaderstats/Credits hittades inte"
end

-- =====================
-- REBIRTH
-- =====================

--- Sätt rebirth-antal för en spelare
--- @param player Player
--- @param amount number
--- @return boolean, string?
function GameManager.setRebirth(player, amount)
	if not player or not player:IsA("Player") then
		return false, "Ogiltig spelare"
	end
	if type(amount) ~= "number" or amount ~= amount then
		return false, "Ogiltigt belopp"
	end
	amount = math.floor(amount)
	if amount < 0 or amount > 10 then
		return false, "Rebirth måste vara mellan 0 och 10"
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Rebirth") then
		leaderstats.Rebirth.Value = amount
		return true, nil
	end
	return false, "Leaderstats/Rebirth hittades inte"
end

--- Ge en rebirth till en spelare (öka med 1)
--- @param player Player
--- @return boolean, string?
function GameManager.giveRebirth(player)
	if not player or not player:IsA("Player") then
		return false, "Ogiltig spelare"
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Rebirth") then
		local current = leaderstats.Rebirth.Value
		if current >= 10 then
			return false, "Spelaren har redan max rebirth (10)"
		end
		leaderstats.Rebirth.Value = current + 1
		return true, nil
	end
	return false, "Leaderstats/Rebirth hittades inte"
end

-- =====================
-- SPEED
-- =====================

--- Sätt hastighetsmultiplier för en spelare
--- @param player Player
--- @param multiplier number
--- @return boolean, string?
function GameManager.setSpeed(player, multiplier)
	if not player or not player:IsA("Player") then
		return false, "Ogiltig spelare"
	end
	if type(multiplier) ~= "number" or multiplier ~= multiplier then
		return false, "Ogiltig multiplier"
	end
	if multiplier <= 0 or multiplier > 100 then
		return false, "Multiplier måste vara mellan 0 och 100"
	end

	local character = player.Character
	if not character then
		return false, "Spelaren har ingen karaktär"
	end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return false, "Humanoid hittades inte"
	end

	humanoid.WalkSpeed = multiplier * 16
	return true, nil
end

-- =====================
-- BRAINROT SPAWNING
-- =====================

--- Spawna en Brainrot NPC
--- @param name string - Brainrot-namn
--- @param mutation string - Mutationstyp
--- @param position Vector3? - Spawn-position (valfri)
--- @return boolean, string?
function GameManager.spawnBrainrot(name, mutation, position)
	if type(name) ~= "string" or #name == 0 then
		return false, "Ogiltigt brainrot-namn"
	end
	if #name > 50 then
		return false, "Namnet är för långt (max 50 tecken)"
	end

	-- Sök i ReplicatedStorage efter brainrot-mallar
	local brainrotFolder = game.ReplicatedStorage:FindFirstChild("Brainrots")
	if not brainrotFolder then
		return false, "Brainrots-mapp hittades inte i ReplicatedStorage"
	end

	local template = brainrotFolder:FindFirstChild(name)
	if not template then
		return false, "Brainrot '" .. name .. "' hittades inte"
	end

	local clone = template:Clone()
	if mutation and #mutation > 0 then
		clone:SetAttribute("Mutation", mutation)
	end
	if position then
		if clone:IsA("Model") and clone.PrimaryPart then
			clone:PivotTo(CFrame.new(position))
		elseif clone:IsA("BasePart") then
			clone.Position = position
		end
	end
	clone.Parent = workspace
	return true, nil
end

-- =====================
-- WAVE / EVENTS
-- =====================

--- Trigga en våg-event
--- @param waveName string
--- @return boolean, string?
function GameManager.triggerWave(waveName)
	if type(waveName) ~= "string" or #waveName == 0 then
		return false, "Ogiltigt vågnamn"
	end
	if #waveName > 50 then
		return false, "Vågnamnet är för långt (max 50 tecken)"
	end

	-- Skicka via BindableEvent om det finns, annars logga
	local waveEvent = game.ReplicatedStorage:FindFirstChild("WaveEvent")
	if waveEvent and waveEvent:IsA("BindableEvent") then
		waveEvent:Fire(waveName)
		return true, nil
	end

	-- Fallback: logga att systemet saknas
	warn("[GameManager] WaveEvent saknas i ReplicatedStorage, våg ej triggad:", waveName)
	return false, "WaveEvent-system ej konfigurerat"
end

-- =====================
-- EVENT COINS
-- =====================

--- Lägg till event coins till en spelare
--- @param player Player
--- @param amount number
--- @return boolean, string?
function GameManager.addEventCoins(player, amount)
	if not player or not player:IsA("Player") then
		return false, "Ogiltig spelare"
	end
	if type(amount) ~= "number" or amount ~= amount then
		return false, "Ogiltigt belopp"
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return false, "Belopp måste vara positivt"
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("EventCoins") then
		leaderstats.EventCoins.Value = leaderstats.EventCoins.Value + amount
		return true, nil
	end
	return false, "Leaderstats/EventCoins hittades inte"
end

return GameManager
