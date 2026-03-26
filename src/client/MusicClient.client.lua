-- =============================================
-- MusicClient.client.lua (LocalScript)
-- Plays zone-based music on the client.
-- Each zone has its own track. Volume fades
-- based on player distance to zone center.
-- =============================================

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- =====================
-- MUSIC ZONES
-- =====================
-- Each zone defines a bounding box and a sound asset.
-- Player gets the music of whichever zone they are inside.
-- If outside all zones, music fades out.

local MUSIC_ZONES = {
	{
		name = "Base",
		soundId = "rbxassetid://71649299775733",
		volume = 0.4,
		-- Bounding box: covers all bases + spawn point
		-- Bases: Z from -60 to +32, X from -30 to +25
		minCorner = Vector3.new(-30, -5, -65),
		maxCorner = Vector3.new(25, 25, 35),
	},
	-- Future zones can be added here:
	-- {
	--     name = "Zone1",
	--     soundId = "rbxassetid://...",
	--     volume = 0.4,
	--     minCorner = Vector3.new(...),
	--     maxCorner = Vector3.new(...),
	-- },
}

-- =====================
-- SOUND SETUP
-- =====================
-- Create a Sound for each zone, parented to SoundService (plays locally)

local zoneSounds = {}
for i, zone in ipairs(MUSIC_ZONES) do
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. zone.name
	sound.SoundId = zone.soundId
	sound.Volume = 0
	sound.Looped = true
	sound.Parent = SoundService

	-- Wait for load in background
	task.spawn(function()
		if not sound.IsLoaded then
			sound.Loaded:Wait()
		end
		sound:Play()
		print("[MUSIC] Loaded and started: " .. zone.name)
	end)

	zoneSounds[i] = {
		sound = sound,
		zone = zone,
		targetVolume = 0,
		currentVolume = 0,
	}
end

-- =====================
-- POSITION CHECK LOOP
-- =====================
-- Every 0.5s, check which zone the player is in and fade music accordingly

local FADE_SPEED = 2 -- volume change per second (0 to 0.4 in ~0.2s)
local currentZone = nil

local function isInsideBox(pos, minC, maxC)
	return pos.X >= minC.X and pos.X <= maxC.X
		and pos.Y >= minC.Y and pos.Y <= maxC.Y
		and pos.Z >= minC.Z and pos.Z <= maxC.Z
end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local playerPos = rootPart.Position

	-- Determine which zone the player is in
	local activeZoneIndex = nil
	for i, entry in ipairs(zoneSounds) do
		if isInsideBox(playerPos, entry.zone.minCorner, entry.zone.maxCorner) then
			activeZoneIndex = i
			break
		end
	end

	-- Set target volumes
	for i, entry in ipairs(zoneSounds) do
		if i == activeZoneIndex then
			entry.targetVolume = entry.zone.volume
		else
			entry.targetVolume = 0
		end

		-- Smoothly fade towards target
		if entry.currentVolume < entry.targetVolume then
			entry.currentVolume = math.min(entry.currentVolume + FADE_SPEED * dt, entry.targetVolume)
		elseif entry.currentVolume > entry.targetVolume then
			entry.currentVolume = math.max(entry.currentVolume - FADE_SPEED * dt, entry.targetVolume)
		end

		entry.sound.Volume = entry.currentVolume
	end
end)

print("[MusicClient] Zone music system ready!")
