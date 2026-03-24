-- UFOWarningUI.client.lua
-- Shows a warning overlay when the player is in the UFO's tractor beam.
-- Listens to the UFOWarning RemoteEvent fired by TrapManager on the server.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- BUILD THE WARNING GUI (all programmatic, no Studio placement needed)
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name                 = "UFOWarningGui"
screenGui.ResetOnSpawn         = false
screenGui.IgnoreGuiInset       = true
screenGui.DisplayOrder         = 100
screenGui.Parent               = playerGui

-- Full-screen red overlay (starts invisible)
local overlay = Instance.new("Frame")
overlay.Name                   = "WarningOverlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.fromRGB(255, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel        = 0
overlay.ZIndex                 = 100
overlay.Parent                 = screenGui

-- Warning text
local warningText = Instance.new("TextLabel")
warningText.Name                   = "WarningText"
warningText.Text                   = "UFO BEAM - MOVE!"
warningText.Font                   = Enum.Font.GothamBold
warningText.TextSize               = 36
warningText.TextColor3             = Color3.fromRGB(255, 50, 50)
warningText.BackgroundTransparency = 1
warningText.Size                   = UDim2.new(0.8, 0, 0.1, 0)
warningText.Position               = UDim2.new(0.5, 0, 0.15, 0)
warningText.AnchorPoint            = Vector2.new(0.5, 0.5)
warningText.Visible                = false
warningText.ZIndex                 = 101
warningText.Parent                 = screenGui

-- Progress bar background
local progressBar = Instance.new("Frame")
progressBar.Name                   = "ProgressBar"
progressBar.BackgroundColor3       = Color3.fromRGB(50, 50, 50)
progressBar.Size                   = UDim2.new(0.3, 0, 0.03, 0)
progressBar.Position               = UDim2.new(0.5, 0, 0.22, 0)
progressBar.AnchorPoint            = Vector2.new(0.5, 0.5)
progressBar.Visible                = false
progressBar.ZIndex                 = 101
progressBar.BorderSizePixel        = 0
progressBar.Parent                 = screenGui
Instance.new("UICorner", progressBar).CornerRadius = UDim.new(0, 4)

-- Progress bar fill
local progressFill = Instance.new("Frame")
progressFill.Name                   = "Fill"
progressFill.BackgroundColor3       = Color3.fromRGB(255, 200, 0)
progressFill.Size                   = UDim2.new(0, 0, 1, 0)
progressFill.BorderSizePixel        = 0
progressFill.ZIndex                 = 102
progressFill.Parent                 = progressBar
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 4)

-- ============================================================
-- PULSING ANIMATION
-- ============================================================

local pulseConnection = nil

local function startPulse()
	if pulseConnection then return end
	pulseConnection = RunService.Heartbeat:Connect(function()
		local alpha = (math.sin(tick() * 8) + 1) / 2  -- Fast 0-1 pulse
		warningText.TextTransparency = alpha * 0.5
	end)
end

local function stopPulse()
	if pulseConnection then
		pulseConnection:Disconnect()
		pulseConnection = nil
	end
	warningText.TextTransparency = 0
end

-- ============================================================
-- REMOTE EVENT HANDLER
-- ============================================================

local remoteFolder   = ReplicatedStorage:WaitForChild("RemoteEvents", 30)
local ufoWarningEvent = remoteFolder and remoteFolder:WaitForChild("UFOWarning", 30)

if not ufoWarningEvent then
	warn("[UFOWarningUI] UFOWarning RemoteEvent not found")
	return
end

ufoWarningEvent.OnClientEvent:Connect(function(progress)
	if type(progress) ~= "number" then return end

	if progress <= 0 then
		-- Safe — hide everything
		overlay.BackgroundTransparency = 1
		warningText.Visible            = false
		progressBar.Visible            = false
		stopPulse()
		return
	end

	-- In danger — show warning
	warningText.Visible = true
	progressBar.Visible = true
	startPulse()

	-- Red overlay gets more opaque as abduction approaches
	local overlayAlpha = 1 - (progress * 0.6)
	overlay.BackgroundTransparency = math.clamp(overlayAlpha, 0.4, 1)

	-- Update progress bar fill
	progressFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)

	-- Fill color: yellow -> red
	local g = math.floor(255 * (1 - progress))
	progressFill.BackgroundColor3 = Color3.fromRGB(255, g, 0)

	-- Text urgency
	if progress >= 0.85 then
		warningText.Text     = "ABDUCTION IMMINENT!"
		warningText.TextSize = 42
	else
		warningText.Text     = "UFO BEAM - MOVE!"
		warningText.TextSize = 36
	end
end)

-- Clear warning on respawn (in case player died while in beam)
player.CharacterAdded:Connect(function()
	overlay.BackgroundTransparency = 1
	warningText.Visible            = false
	progressBar.Visible            = false
	stopPulse()
end)

print("[UFOWarningUI] UFO warning system ready!")
