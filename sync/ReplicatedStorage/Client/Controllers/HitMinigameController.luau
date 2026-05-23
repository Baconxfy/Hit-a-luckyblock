local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local HitMinigameController = Framework:CreateController("HitMinigameController")

function HitMinigameController:Initialize()
	self.Player = Players.LocalPlayer

	self.HitMinigame = nil
	self.HitButton = nil
	self.HitZone = nil

	self.TouchingParts = {}
	self.ButtonSuppressed = false

	self._connections = {}
end

function HitMinigameController:Start()
	self:_bindGui()
	self:_bindHitZone()
	self:_bindCharacterReset()
	self:_rescanCurrentTouches()
end

function HitMinigameController:_trackConnection(connection)
	table.insert(self._connections, connection)
	return connection
end

function HitMinigameController:_bindGui()
	local playerGui = self.Player:WaitForChild("PlayerGui")

	self.HitMinigame = playerGui:WaitForChild("HitMinigame")
	self.HitButton = self.HitMinigame:WaitForChild("HitButton")

	self.HitMinigame.Enabled = true
	self:RefreshHitButton()
end

function HitMinigameController:_bindHitZone()
	local zones = workspace:WaitForChild("Zones")
	self.HitZone = zones:WaitForChild("HitZone")

	self:_trackConnection(self.HitZone.Touched:Connect(function(hit)
		self:_onHitZoneTouched(hit)
	end))

	self:_trackConnection(self.HitZone.TouchEnded:Connect(function(hit)
		self:_onHitZoneTouchEnded(hit)
	end))
end

function HitMinigameController:_bindCharacterReset()
	self:_trackConnection(self.Player.CharacterAdded:Connect(function()
		self.TouchingParts = {}
		self.ButtonSuppressed = false
		self:RefreshHitButton()

		task.defer(function()
			self:_rescanCurrentTouches()
		end)
	end))
end

function HitMinigameController:_isLocalCharacterPart(hit)
	local character = self.Player.Character

	if not character then
		return false
	end

	return hit:IsDescendantOf(character)
end

function HitMinigameController:_rescanCurrentTouches()
	if not self.HitZone then
		return
	end

	self.TouchingParts = {}

	for _, part in ipairs(self.HitZone:GetTouchingParts()) do
		if self:_isLocalCharacterPart(part) then
			self.TouchingParts[part] = true
		end
	end

	self:RefreshHitButton()
end

function HitMinigameController:IsInHitZone()
	return next(self.TouchingParts) ~= nil
end

function HitMinigameController:SetHitButtonSuppressed(suppressed)
	self.ButtonSuppressed = suppressed == true
	self:RefreshHitButton()
end

function HitMinigameController:RefreshHitButton()
	if not self.HitButton then
		return
	end

	self.HitButton.Visible = self:IsInHitZone() and not self.ButtonSuppressed
end

function HitMinigameController:_onHitZoneTouched(hit)
	if not self:_isLocalCharacterPart(hit) then
		return
	end

	self.TouchingParts[hit] = true
	self:RefreshHitButton()
end

function HitMinigameController:_onHitZoneTouchEnded(hit)
	if not self:_isLocalCharacterPart(hit) then
		return
	end

	self.TouchingParts[hit] = nil
	self:RefreshHitButton()
end

function HitMinigameController:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end

	self._connections = {}
	self.TouchingParts = {}
end

return HitMinigameController
