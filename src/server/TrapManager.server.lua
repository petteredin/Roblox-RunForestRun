-- TrapManager.server.lua
-- Initializes all traps in the game.
--   Zone 1 (Easy)   : Spinning Bar Traps
--   Zone 2 (Medium) : Mouse Traps
--   Zone 3 (Hard)   : UFO Abduction Trap
-- Creates workspace folder structure and trap models programmatically
-- so everything is managed via Rojo (no manual Studio placement needed).

local Players          = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- SHARED HELPERS
-- ============================================================

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function ensureRemoteEvent(name)
	local remoteFolder = ensureFolder(ReplicatedStorage, "RemoteEvents")
	local event = remoteFolder:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = remoteFolder
	end
	return event
end

-- ============================================================
-- WORKSPACE FOLDER STRUCTURE
-- ============================================================

local zonesFolder = ensureFolder(workspace, "Zones")

-- Zone 1
local zone1Folder     = ensureFolder(zonesFolder, "Zone1_Easy")
local zone1Traps      = ensureFolder(zone1Folder, "Traps")
local _zone1Path      = ensureFolder(zone1Folder, "Path")

-- Zone 2
local zone2Folder     = ensureFolder(zonesFolder, "Zone2_Medium")
local zone2Traps      = ensureFolder(zone2Folder, "Traps")
local _zone2Path      = ensureFolder(zone2Folder, "Path")

-- Zone 3
local zone3Folder     = ensureFolder(zonesFolder, "Zone3_Hard")
local zone3Traps      = ensureFolder(zone3Folder, "Traps")
local _zone3Path      = ensureFolder(zone3Folder, "Path")

-- ############################################################
--
--  ZONE 1 — SPINNING BAR TRAPS
--
-- ############################################################

local TAG_SPINTRAP = "SpinTrap"

local SPIN_CONFIG = {
	speed = 2,  -- Degrees per frame (~3 sec full rotation, Easy zone)
}

-- Zone 1 bounds: center (-235, 3.5, -4.5), size (150, 1, 155)
-- X range: -310 to -160, Z range: -82 to 73, ground Y = 1.0
-- Heights are above ground surface (Y=1.0)
local ZONE1_SPIN_PLACEMENTS = {
	-- Trap 1: Early — teaches the mechanic, torso height
	{ position = Vector3.new(-190, 6.0, -5),  barLength = 24, barHeight = 5 },
	-- Trap 2: Mid-zone — longer bar, shin height (must jump)
	{ position = Vector3.new(-230, 4.0, 0),   barLength = 28, barHeight = 3 },
	-- Trap 3: Near brainrot area — head height (can walk under)
	{ position = Vector3.new(-270, 8.0, -10), barLength = 24, barHeight = 7 },
	-- Trap 4: Narrow platform — shorter bar, less room to dodge
	{ position = Vector3.new(-300, 6.0, 15),  barLength = 20, barHeight = 5 },
}

-- ── Build Model ──

local function buildSpinTrapModel(placement)
	local trapModel = Instance.new("Model")
	trapModel.Name = "SpinTrap"

	local pos = placement.position

	-- Pivot (center axle — the rotation point)
	-- Cylinder stands upright (no extra rotation needed)
	local pivot = Instance.new("Part")
	pivot.Name       = "Pivot"
	pivot.Shape      = Enum.PartType.Cylinder
	pivot.Size       = Vector3.new(3, 2, 2) -- Height=3 (X for cylinders), diameter=2
	pivot.Material   = Enum.Material.Metal
	pivot.Color      = Color3.fromRGB(100, 100, 100)
	pivot.Anchored   = true
	pivot.CanCollide = false
	pivot.CFrame     = CFrame.new(pos)
	pivot.Parent     = trapModel
	trapModel.PrimaryPart = pivot

	-- Bar (the deadly spinning arm — unanchored so WeldConstraint works)
	local barLen = placement.barLength or 24
	local bar = Instance.new("Part")
	bar.Name       = "Bar"
	bar.Size       = Vector3.new(barLen, 2, 2)
	bar.Material   = Enum.Material.Metal
	bar.Color      = Color3.fromRGB(200, 50, 50)
	bar.Anchored   = false  -- Must be unanchored for WeldConstraint to drive it
	bar.CanCollide = true
	bar.Massless   = true   -- Prevent physics from dragging the pivot
	bar.CFrame     = CFrame.new(pos)
	bar.Parent     = trapModel

	-- Weld bar to pivot so they rotate together
	local weld = Instance.new("WeldConstraint")
	weld.Part0  = pivot
	weld.Part1  = bar
	weld.Parent = pivot

	-- Pole from ground to pivot (visual support)
	local poleHeight = pos.Y - 1.0  -- From ground to pivot center
	if poleHeight > 1 then
		local pole = Instance.new("Part")
		pole.Name       = "Pole"
		pole.Size       = Vector3.new(1, poleHeight, 1)
		pole.Material   = Enum.Material.Metal
		pole.Color      = Color3.fromRGB(80, 80, 80)
		pole.Anchored   = true
		pole.CanCollide = false
		pole.CFrame     = CFrame.new(pos.X, 1.0 + poleHeight / 2, pos.Z)
		pole.Parent     = trapModel
	end

	CollectionService:AddTag(trapModel, TAG_SPINTRAP)
	trapModel.Parent = zone1Traps
	return trapModel
end

-- ── Behavior ──

local function setupSpinTrap(model)
	local pivot = model.PrimaryPart
	if not pivot then
		warn("[TrapManager] SpinTrap missing PrimaryPart (Pivot):", model:GetFullName())
		return
	end

	local speed = SPIN_CONFIG.speed
	local recentlyHit = {}  -- Debounce per player

	-- Continuous horizontal rotation
	task.spawn(function()
		while pivot and pivot.Parent do
			pivot.CFrame = pivot.CFrame * CFrame.Angles(0, math.rad(speed), 0)
			task.wait()
		end
	end)

	-- Make all non-pivot parts deadly on touch
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= pivot and part.Name ~= "Pole" then
			part.Touched:Connect(function(hit)
				local character = hit.Parent
				local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then return end

				local player = Players:GetPlayerFromCharacter(character)
				if not player then return end

				-- Debounce: prevent rapid re-kills after respawn
				if recentlyHit[player.UserId] then return end
				recentlyHit[player.UserId] = true

				-- Shield check
				if player:GetAttribute("ShieldActive") ~= true then
					humanoid.Health = 0
				end

				-- Clear debounce after short delay
				task.delay(1, function()
					recentlyHit[player.UserId] = nil
				end)
			end)
		end
	end
end

-- ############################################################
--
--  ZONE 2 — MOUSE TRAPS
--
-- ############################################################

local MOUSE_RESET_TIME  = 3
local MOUSE_SNAP_ANGLE  = -120
local TAG_MOUSETRAP     = "MouseTrap"
local SNAP_SOUND_ID     = "rbxassetid://0"  -- Replace with real asset

-- Zone 2 bounds: center (-394, 3.5, -4.5), size (150, 1, 155)
-- Ground surface at Y = 1.0, base is 1 stud tall → Y = 4.0 sits on top
local ZONE2_TRAP_PLACEMENTS = {
	{ position = Vector3.new(-350, 1.0, -5),   rotation = 0   },
	{ position = Vector3.new(-380, 1.0, 25),   rotation = 45  },
	{ position = Vector3.new(-410, 1.0, -30),  rotation = -20 },
	{ position = Vector3.new(-440, 1.0, 10),   rotation = 10  },
	{ position = Vector3.new(-450, 1.0, -5),   rotation = -10 },
}

-- ── Build Model ──

local function buildMouseTrapModel(placement)
	local trapModel = Instance.new("Model")
	trapModel.Name = "MouseTrap"

	local baseCFrame = CFrame.new(placement.position)
		* CFrame.Angles(0, math.rad(placement.rotation or 0), 0)

	-- Base (wooden board)
	local base = Instance.new("Part")
	base.Name       = "Base"
	base.Size       = Vector3.new(12, 1, 20)
	base.Material   = Enum.Material.Wood
	base.BrickColor = BrickColor.new("Brown")
	base.Anchored   = true
	base.CanCollide = true
	base.CFrame     = baseCFrame
	base.Parent     = trapModel
	trapModel.PrimaryPart = base

	-- Trigger plate
	local triggerPlate = Instance.new("Part")
	triggerPlate.Name         = "TriggerPlate"
	triggerPlate.Size         = Vector3.new(4, 0.3, 4)
	triggerPlate.Material     = Enum.Material.SmoothPlastic
	triggerPlate.Color        = Color3.fromRGB(200, 180, 50)
	triggerPlate.Anchored     = true
	triggerPlate.CanCollide   = false
	triggerPlate.Transparency = 0
	triggerPlate.CFrame       = baseCFrame * CFrame.new(0, 0.65, 0)
	triggerPlate.Parent       = trapModel

	-- Snap bar
	local snapBar = Instance.new("Part")
	snapBar.Name       = "SnapBar"
	snapBar.Size       = Vector3.new(10, 0.5, 1)
	snapBar.Material   = Enum.Material.Metal
	snapBar.BrickColor = BrickColor.new("Medium stone grey")
	snapBar.Anchored   = true
	snapBar.CanCollide = false
	snapBar.CFrame     = baseCFrame * CFrame.new(0, 3, -8) * CFrame.Angles(math.rad(-30), 0, 0)
	snapBar.Parent     = trapModel

	local snapSound = Instance.new("Sound")
	snapSound.Name          = "SnapSound"
	snapSound.SoundId       = SNAP_SOUND_ID
	snapSound.Volume        = 1
	snapSound.PlaybackSpeed = 1.2
	snapSound.Parent        = snapBar

	-- Spring (decorative)
	local spring = Instance.new("Part")
	spring.Name       = "Spring"
	spring.Shape      = Enum.PartType.Cylinder
	spring.Size       = Vector3.new(1, 6, 1)
	spring.Material   = Enum.Material.Metal
	spring.BrickColor = BrickColor.new("Medium stone grey")
	spring.Anchored   = true
	spring.CanCollide = false
	spring.CFrame     = baseCFrame * CFrame.new(0, 1.5, -7) * CFrame.Angles(0, 0, math.rad(90))
	spring.Parent     = trapModel

	CollectionService:AddTag(trapModel, TAG_MOUSETRAP)
	trapModel.Parent = zone2Traps
	return trapModel
end

-- ── Behavior ──

local function setupMouseTrap(model)
	local snapBar      = model:FindFirstChild("SnapBar")
	local triggerPlate = model:FindFirstChild("TriggerPlate")
	if not model.PrimaryPart or not snapBar or not triggerPlate then
		warn("[TrapManager] MouseTrap missing parts:", model:GetFullName())
		return
	end

	local snapBarOrigin     = snapBar.CFrame
	local isArmed           = true
	local recentlyTriggered = {}

	triggerPlate.Touched:Connect(function(hit)
		if not isArmed then return end
		local character = hit.Parent
		local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		if recentlyTriggered[player.UserId] then return end
		recentlyTriggered[player.UserId] = true

		isArmed = false
		snapBar.CFrame = snapBarOrigin * CFrame.Angles(math.rad(MOUSE_SNAP_ANGLE), 0, 0)

		local snd = snapBar:FindFirstChild("SnapSound")
		if snd then snd:Play() end

		if player:GetAttribute("ShieldActive") ~= true then
			humanoid.Health = 0
		end

		task.delay(MOUSE_RESET_TIME, function()
			if snapBar and snapBar.Parent then
				snapBar.CFrame = snapBarOrigin
			end
			isArmed = true
			recentlyTriggered[player.UserId] = nil
		end)
	end)
end

-- ############################################################
--
--  ZONE 3 — UFO ABDUCTION TRAP
--
-- ############################################################

local TAG_UFO = "UFOTrap"

local UFO_CONFIG = {
	patrolSpeed       = 20,    -- Studs per second
	abductionTime     = 0.3,   -- Seconds in beam before abduction
	beamRadius        = 12,    -- Horizontal studs from beam center (was 10)
	beamCheckInterval = 0.05,  -- Seconds between detection ticks (was 0.1)
	pauseAtWaypoint   = 0.5,   -- Seconds UFO pauses at each waypoint
	liftSpeed         = 25,    -- Vertical studs/sec applied when lifting (was 10)
	warningThreshold  = 0.0,   -- Start warning + lifting immediately (was 0.5)
	ufoHeight         = 40,    -- Studs above ground the UFO hovers
	beamLength        = 38,    -- Visual length of the beam cylinder
}

-- Zone 3 bounds: center (-555, 3.5, -4.5), size (150, 1, 155)
-- X range: -630 to -480, Z range: -82 to 73, ground Y = 1.0
-- Waypoints at UFO hover height (Y = 1.0 + 40 = 41)
local ZONE3_UFO_WAYPOINTS = {
	Vector3.new(-490, 41, -20),
	Vector3.new(-520, 41,  30),
	Vector3.new(-555, 41, -10),
	Vector3.new(-590, 41,  20),
	Vector3.new(-620, 41,   0),
}

-- Remote event for client warning UI
local ufoWarningEvent = ensureRemoteEvent("UFOWarning")

-- ── Build UFO Model ──

local function buildUFOModel()
	local ufoModel = Instance.new("Model")
	ufoModel.Name = "UFOTrap"

	local startPos = ZONE3_UFO_WAYPOINTS[1]

	-- Body (flat metallic disc — cylinder rotated flat)
	local body = Instance.new("Part")
	body.Name         = "Body"
	body.Shape        = Enum.PartType.Cylinder
	body.Size         = Vector3.new(3, 30, 30)
	body.Material     = Enum.Material.Metal
	body.Color        = Color3.fromRGB(80, 80, 90)
	body.Anchored     = true
	body.CanCollide   = false
	body.CFrame       = CFrame.new(startPos) * CFrame.Angles(0, 0, math.rad(90))
	body.Parent       = ufoModel
	ufoModel.PrimaryPart = body

	-- Dome (glass half-sphere on top)
	local dome = Instance.new("Part")
	dome.Name         = "Dome"
	dome.Shape        = Enum.PartType.Ball
	dome.Size         = Vector3.new(12, 8, 12)
	dome.Material     = Enum.Material.Glass
	dome.Color        = Color3.fromRGB(100, 200, 255)
	dome.Transparency = 0.5
	dome.Anchored     = true
	dome.CanCollide   = false
	dome.CFrame       = CFrame.new(startPos + Vector3.new(0, 5, 0))
	dome.Parent       = ufoModel

	-- Beam (green neon cylinder extending downward)
	local beam = Instance.new("Part")
	beam.Name         = "Beam"
	beam.Shape        = Enum.PartType.Cylinder
	beam.Size         = Vector3.new(UFO_CONFIG.beamLength, 8, 8)
	beam.Material     = Enum.Material.Neon
	beam.Color        = Color3.fromRGB(0, 255, 100)
	beam.Transparency = 0.6
	beam.Anchored     = true
	beam.CanCollide   = false
	-- Vertical cylinder: rotate so height axis points down
	beam.CFrame       = CFrame.new(startPos - Vector3.new(0, UFO_CONFIG.beamLength / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	beam.Parent       = ufoModel

	-- PointLight inside beam
	local beamLight = Instance.new("PointLight")
	beamLight.Name       = "BeamLight"
	beamLight.Color      = Color3.fromRGB(0, 255, 100)
	beamLight.Brightness = 2
	beamLight.Range      = 30
	beamLight.Parent     = beam

	-- Waypoints folder (invisible anchors for patrol path)
	local wpFolder = Instance.new("Folder")
	wpFolder.Name   = "Waypoints"
	wpFolder.Parent = ufoModel

	for i, pos in ipairs(ZONE3_UFO_WAYPOINTS) do
		local wp = Instance.new("Part")
		wp.Name         = "Waypoint" .. i
		wp.Size         = Vector3.new(1, 1, 1)
		wp.Transparency = 1
		wp.CanCollide   = false
		wp.Anchored     = true
		wp.Position     = pos
		wp.Parent       = wpFolder
	end

	CollectionService:AddTag(ufoModel, TAG_UFO)
	ufoModel.Parent = zone3Traps
	return ufoModel
end

-- ── UFO Behavior ──

local function setupUFO(ufoModel)
	local body           = ufoModel.PrimaryPart
	local beamPart       = ufoModel:FindFirstChild("Beam")
	local dome           = ufoModel:FindFirstChild("Dome")
	local waypointsFolder = ufoModel:FindFirstChild("Waypoints")

	if not body or not beamPart or not waypointsFolder then
		warn("[TrapManager] UFOTrap missing parts:", ufoModel:GetFullName())
		return
	end

	-- Collect waypoints sorted by name
	local waypoints = {}
	for _, wp in ipairs(waypointsFolder:GetChildren()) do
		table.insert(waypoints, wp)
	end
	table.sort(waypoints, function(a, b) return a.Name < b.Name end)
	if #waypoints < 2 then
		warn("[TrapManager] UFOTrap needs at least 2 waypoints:", ufoModel:GetFullName())
		return
	end

	local waypointPositions = {}
	for _, wp in ipairs(waypoints) do
		table.insert(waypointPositions, wp.Position)
	end

	-- Per-player beam exposure tracking
	local playerBeamTime = {}

	-- Helper: reposition all UFO parts relative to the body
	local function moveUFO(newBodyPos)
		body.CFrame    = CFrame.new(newBodyPos) * CFrame.Angles(0, 0, math.rad(90))
		if dome then
			dome.CFrame = CFrame.new(newBodyPos + Vector3.new(0, 5, 0))
		end
		beamPart.CFrame = CFrame.new(newBodyPos - Vector3.new(0, UFO_CONFIG.beamLength / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90))
	end

	-- ── PATROL MOVEMENT ──
	task.spawn(function()
		local currentWP = 1
		while true do
			local targetPos = waypointPositions[currentWP]
			local startPos  = body.Position
			local direction = targetPos - startPos
			local distance  = direction.Magnitude

			if distance < 1 then
				currentWP = currentWP % #waypointPositions + 1
				task.wait(UFO_CONFIG.pauseAtWaypoint)
			else
				local unitDir  = direction.Unit
				local traveled = 0

				while traveled < distance do
					local dt   = task.wait()
					local step = UFO_CONFIG.patrolSpeed * dt
					traveled   = traveled + step

					if traveled >= distance then
						moveUFO(targetPos)
					else
						moveUFO(body.Position + unitDir * step)
					end
				end

				task.wait(UFO_CONFIG.pauseAtWaypoint)
				currentWP = currentWP % #waypointPositions + 1
			end
		end
	end)

	-- ── ABDUCTION DETECTION ──
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				if character then
					local rootPart = character:FindFirstChild("HumanoidRootPart")
					local humanoid = character:FindFirstChildOfClass("Humanoid")

					if rootPart and humanoid and humanoid.Health > 0 then
						-- Horizontal distance to beam center (ignore Y)
						local dx = rootPart.Position.X - body.Position.X
						local dz = rootPart.Position.Z - body.Position.Z
						local horizontalDist = math.sqrt(dx * dx + dz * dz)
						local isBelow = rootPart.Position.Y < body.Position.Y

						if horizontalDist <= UFO_CONFIG.beamRadius and isBelow then
							-- Player is in the beam
							local prevTime = playerBeamTime[player.UserId] or 0
							local newTime  = prevTime + UFO_CONFIG.beamCheckInterval
							playerBeamTime[player.UserId] = newTime

							local progress = math.clamp(newTime / UFO_CONFIG.abductionTime, 0, 1)

							-- Warning + lifting phase
							if progress >= UFO_CONFIG.warningThreshold then
								ufoWarningEvent:FireClient(player, progress)
								rootPart.AssemblyLinearVelocity = Vector3.new(
									0,
									UFO_CONFIG.liftSpeed * progress,
									0
								)
							end

							-- Fully abducted
							if progress >= 1.0 then
								if player:GetAttribute("ShieldActive") == true then
									-- Shield saves — reset
									playerBeamTime[player.UserId] = 0
									ufoWarningEvent:FireClient(player, 0)
								else
									-- ABDUCTED! Teleport into UFO then kill
									rootPart.CFrame = body.CFrame
									task.wait(0.3)
									humanoid.Health = 0
									playerBeamTime[player.UserId] = 0
									ufoWarningEvent:FireClient(player, 0)
								end
							end
						else
							-- Player is outside the beam — reset
							if playerBeamTime[player.UserId] and playerBeamTime[player.UserId] > 0 then
								playerBeamTime[player.UserId] = 0
								ufoWarningEvent:FireClient(player, 0)
							end
						end
					else
						-- Dead or missing character — reset
						playerBeamTime[player.UserId] = nil
					end
				end
			end

			task.wait(UFO_CONFIG.beamCheckInterval)
		end
	end)
end

-- ############################################################
--
--  INITIALIZATION
--
-- ############################################################

-- ── Zone 1: Spinning Bar Traps ──
for i, placement in ipairs(ZONE1_SPIN_PLACEMENTS) do
	local model = buildSpinTrapModel(placement)
	setupSpinTrap(model)
	print("[TrapManager] Built SpinTrap #" .. i .. " at " .. tostring(placement.position))
end

-- Pick up manually-placed spin traps from build.rbxlx
for _, child in ipairs(zone1Traps:GetChildren()) do
	if child.Name == "SpinTrap" and not CollectionService:HasTag(child, TAG_SPINTRAP) then
		CollectionService:AddTag(child, TAG_SPINTRAP)
		setupSpinTrap(child)
		print("[TrapManager] Initialized existing SpinTrap:", child:GetFullName())
	end
end

print("[TrapManager] Zone 1 spinning traps ready! Count:", #zone1Traps:GetChildren())

-- ── Zone 2: Mouse Traps ──
for i, placement in ipairs(ZONE2_TRAP_PLACEMENTS) do
	local model = buildMouseTrapModel(placement)
	setupMouseTrap(model)
	print("[TrapManager] Built MouseTrap #" .. i .. " at " .. tostring(placement.position))
end

-- Pick up manually-placed mouse traps from build.rbxlx
for _, child in ipairs(zone2Traps:GetChildren()) do
	if child.Name == "MouseTrap" and not CollectionService:HasTag(child, TAG_MOUSETRAP) then
		CollectionService:AddTag(child, TAG_MOUSETRAP)
		setupMouseTrap(child)
		print("[TrapManager] Initialized existing MouseTrap:", child:GetFullName())
	end
end

print("[TrapManager] Zone 2 mouse traps ready! Count:", #zone2Traps:GetChildren())

-- ── Zone 3: UFO Trap ──
local ufoModel = buildUFOModel()
setupUFO(ufoModel)
print("[TrapManager] Built UFO trap for Zone 3")

-- Pick up manually-placed UFO traps from build.rbxlx
for _, child in ipairs(zone3Traps:GetChildren()) do
	if child.Name == "UFOTrap" and not CollectionService:HasTag(child, TAG_UFO) then
		CollectionService:AddTag(child, TAG_UFO)
		setupUFO(child)
		print("[TrapManager] Initialized existing UFOTrap:", child:GetFullName())
	end
end

print("[TrapManager] Zone 3 UFO trap ready!")

-- ── Cleanup ──
Players.PlayerRemoving:Connect(function(_player)
	-- Per-player beam timers use UserId keys inside each UFO's closure.
	-- These are small integers and don't reference the Player object,
	-- so they won't leak memory. They reset naturally on next spawn.
end)

print("[TrapManager] All trap systems ready!")
